#!/usr/bin/env python3
import argparse
import ctypes
import ctypes.wintypes
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys
import time
import uuid
import hashlib

import minecraft_launcher_lib
from minecraft_launcher_lib import microsoft_account
import paramiko


MINECRAFT_VERSION = "1.16.5-forge-36.2.42"
MINECRAFT_LAUNCHER_CLIENT_ID = "00000000402b5328"
PACK_ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST_PATH = PACK_ROOT / ".pack-manifest.json"


def read_password(args: argparse.Namespace) -> str | None:
    if args.remote_password_stdin:
        value = sys.stdin.readline().rstrip("\r\n")
        if value:
            return value
        raise RuntimeError("Missing remote password on stdin.")

    if args.remote_password_env:
        value = os.environ.get(args.remote_password_env)
        if value:
            return value
        raise RuntimeError(f"Missing password env var: {args.remote_password_env}")

    if args.remote_identity_file or args.remote_allow_agent or args.remote_look_for_keys:
        return None

    return None


def connect_ssh(args: argparse.Namespace, password: str | None, timeout: float) -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        args.remote_host,
        port=args.remote_port,
        username=args.remote_user,
        password=password,
        key_filename=args.remote_identity_file,
        timeout=timeout,
        banner_timeout=timeout,
        auth_timeout=timeout,
        look_for_keys=args.remote_look_for_keys,
        allow_agent=args.remote_allow_agent,
    )
    return client


def remote_exec(client: paramiko.SSHClient, command: str) -> str:
    stdin, stdout, stderr = client.exec_command(command)
    stdin.close()
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    code = stdout.channel.recv_exit_status()
    if code != 0:
        raise RuntimeError(f"remote command failed ({code}): {err.strip()}")
    return out


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def file_sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_manifest_section(manifest: dict, section: str) -> dict[str, str]:
    return {str(item["name"]): item["sha256"].lower() for item in manifest.get(section, [])}


def verify_client_modset(minecraft_dir: pathlib.Path) -> None:
    if not MANIFEST_PATH.exists():
        print(f"warn: manifest missing ({MANIFEST_PATH}); skipping pack integrity pre-check.")
        return

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8-sig"))
    expected = expected_manifest_section(manifest, "client")
    mods_dir = minecraft_dir / "mods"
    if not mods_dir.exists():
        raise RuntimeError(f"Client mods folder is missing: {mods_dir}")

    actual_mods = {path.name: path for path in mods_dir.glob("*.jar")}
    mismatches: list[str] = []
    extras: list[str] = []

    for name, expected_hash in expected.items():
        if name not in actual_mods:
            mismatches.append(f"missing required mod {name}")
            continue
        actual_hash = file_sha256(actual_mods[name]).lower()
        if actual_hash != expected_hash.lower():
            mismatches.append(f"hash mismatch {name}: expected {expected_hash}, found {actual_hash}")

    extras = sorted(path for path in actual_mods if path not in expected)

    if mismatches or extras:
        installer = PACK_ROOT / "Install-Minecraft-Pack.ps1"
        message = ["Local client mods do not match this pack's manifest and will fail Forge handshake."]
        if mismatches:
            message.append("  mismatches:")
            message.extend([f"   - {item}" for item in mismatches[:80]])
        if extras:
            message.append("  extra jars (not in manifest):")
            message.extend([f"   - {item}" for item in extras[:40]])
            if len(extras) > 40:
                message.append("   - ...")

        message.append("")
        message.append(
            f'Run "powershell -NoProfile -ExecutionPolicy Bypass -File \"{installer}\" -Force" '
            "to rebuild the local client mods from manifest."
        )
        raise RuntimeError("\\n".join(message))


class DataBlob(ctypes.Structure):
    _fields_ = [
        ("cbData", ctypes.wintypes.DWORD),
        ("pbData", ctypes.POINTER(ctypes.c_ubyte)),
    ]


def crypt_unprotect_data(data: bytes) -> bytes:
    if os.name != "nt":
        raise RuntimeError("DPAPI launcher credential decryption is only available on Windows.")

    in_buffer = ctypes.create_string_buffer(data)
    in_blob = DataBlob(len(data), ctypes.cast(in_buffer, ctypes.POINTER(ctypes.c_ubyte)))
    out_blob = DataBlob()

    if not ctypes.windll.crypt32.CryptUnprotectData(
        ctypes.byref(in_blob),
        None,
        None,
        None,
        None,
        0,
        ctypes.byref(out_blob),
    ):
        error = ctypes.get_last_error()
        raise ctypes.WinError(error)

    try:
        return ctypes.string_at(out_blob.pbData, out_blob.cbData)
    finally:
        ctypes.windll.kernel32.LocalFree(out_blob.pbData)


def find_value_by_key(value: object, keys: set[str]) -> str | None:
    if isinstance(value, dict):
        for key, child in value.items():
            if key.lower() in keys and isinstance(child, str) and child:
                return child
        for child in value.values():
            found = find_value_by_key(child, keys)
            if found:
                return found
    elif isinstance(value, list):
        for child in value:
            found = find_value_by_key(child, keys)
            if found:
                return found
    return None


def read_launcher_refresh_token(minecraft_dir: pathlib.Path) -> str | None:
    names = [
        "launcher_msa_credentials_microsoft_store.bin",
        "launcher_msa_credentials.bin",
    ]
    for name in names:
        credential_path = minecraft_dir / name
        if not credential_path.exists():
            continue

        plaintext = crypt_unprotect_data(credential_path.read_bytes())
        text = plaintext.decode("utf-8-sig", errors="replace").strip("\x00\r\n ")
        try:
            data = json.loads(text)
            token = find_value_by_key(data, {"refreshtoken", "refresh_token"})
            if token:
                print(f"auth: using DPAPI launcher credential from {credential_path.name}")
                return token
        except json.JSONDecodeError:
            pass

        match = re.search(r'"(?:refreshToken|refresh_token)"\s*:\s*"([^"]+)"', text)
        if match:
            print(f"auth: using DPAPI launcher credential from {credential_path.name}")
            return match.group(1)

    return None


def refresh_minecraft_account(refresh_token: str, fallback_name: str | None, fallback_uuid: str | None) -> dict[str, str]:
    refreshed = microsoft_account.complete_refresh(
        MINECRAFT_LAUNCHER_CLIENT_ID,
        None,
        None,
        refresh_token,
    )
    token = refreshed.get("access_token")
    name = refreshed.get("name") or fallback_name
    uuid = refreshed.get("id") or fallback_uuid
    if not token or not name or not uuid:
        raise RuntimeError("Microsoft refresh succeeded but did not return a complete Minecraft profile.")

    return {"username": name, "uuid": uuid, "token": token}


def read_launcher_account(minecraft_dir: pathlib.Path) -> dict[str, str]:
    account_path = minecraft_dir / "launcher_accounts_microsoft_store.json"
    if not account_path.exists():
        account_path = minecraft_dir / "launcher_accounts.json"
    if not account_path.exists():
        raise RuntimeError("No Minecraft Launcher account file was found. Open Minecraft Launcher and sign in first.")

    data = json.loads(account_path.read_text(encoding="utf-8-sig"))
    account_id = data.get("activeAccountLocalId")
    accounts = data.get("accounts") or {}
    account = accounts.get(account_id) if account_id else None
    if account is None and accounts:
        account = next(iter(accounts.values()))

    if not account:
        raise RuntimeError("No active Minecraft Launcher account was found.")

    profile = account.get("minecraftProfile") or {}
    token = account.get("accessToken")
    name = profile.get("name") or account.get("username")
    uuid = profile.get("id") or account.get("remoteId")
    if not token:
        refresh_token = read_launcher_refresh_token(minecraft_dir)
        if refresh_token:
            return refresh_minecraft_account(refresh_token, name, uuid)
    if not token or not name or not uuid:
        raise RuntimeError(
            "Launcher account is missing a usable Minecraft access token. "
            "Open Minecraft Launcher, sign in, and press Play once to refresh the local session."
        )

    return {"username": name, "uuid": uuid, "token": token}


def offline_account(username: str, offline_uuid: str | None) -> dict[str, str]:
    if not re.fullmatch(r"[A-Za-z0-9_]{3,16}", username):
        raise RuntimeError("Offline verifier username must be 3-16 characters: letters, numbers, and underscore only.")

    profile_uuid = offline_uuid
    if not profile_uuid:
        profile_uuid = uuid.uuid3(uuid.NAMESPACE_DNS, f"OfflinePlayer:{username}").hex
    else:
        profile_uuid = profile_uuid.replace("-", "")

    if not re.fullmatch(r"[0-9a-fA-F]{32}", profile_uuid):
        raise RuntimeError("Offline verifier UUID must be 32 hex characters, with or without dashes.")

    # 1.16.x greys out Multiplayer for legacy users before any server handshake.
    # Offline-mode servers do not validate the session token, so keep the offline
    # UUID/token but use a multiplayer-capable client user type.
    return {"username": username, "uuid": profile_uuid.lower(), "token": "0", "user_type": "mojang"}


def find_java() -> str:
    roots = [
        pathlib.Path(os.environ.get("ProgramFiles", "")) / "Minecraft Launcher" / "runtime",
        pathlib.Path(os.environ.get("APPDATA", "")) / ".minecraft" / "runtime",
        pathlib.Path(os.environ.get("ProgramFiles", "")) / "Java",
        pathlib.Path(os.environ.get("ProgramFiles(x86)", "")) / "Java",
        pathlib.Path(os.environ.get("ProgramFiles(x86)", "")) / "Common Files" / "Oracle" / "Java",
    ]
    candidates: list[pathlib.Path] = []
    for root in roots:
        if root.exists():
            candidates.extend(root.rglob("java.exe"))

    if not candidates:
        raise RuntimeError("Could not find java.exe.")

    candidates.sort(key=lambda path: path.stat().st_mtime, reverse=True)
    return str(candidates[0])


def build_command(minecraft_dir: pathlib.Path, account: dict[str, str], java: str, host: str, port: int) -> list[str]:
    options = {
        "username": account["username"],
        "uuid": account["uuid"],
        "token": account["token"],
        "executablePath": java,
        "gameDirectory": str(minecraft_dir),
        "jvmArguments": ["-Xmx8G", "-Xms4G"],
        "launcherName": "CodexPackVerifier",
        "launcherVersion": "1",
        "server": host,
        "port": str(port),
        "customResolution": True,
        "resolutionWidth": "854",
        "resolutionHeight": "480",
    }
    command = minecraft_launcher_lib.command.get_minecraft_command(MINECRAFT_VERSION, minecraft_dir, options)
    if account.get("user_type") and "--userType" in command:
        command[command.index("--userType") + 1] = account["user_type"]
    server_args = ["--server", host, "--port", str(port)]
    if "--server" in command:
        server_index = command.index("--server")
        del command[server_index : server_index + 4]
    if "--launchTarget" in command:
        command[command.index("--launchTarget") : command.index("--launchTarget")] = server_args
    else:
        command.extend(server_args)
    return command


def read_text(path: pathlib.Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def terminate(proc: subprocess.Popen) -> None:
    if proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=20)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=20)


def main() -> int:
    parser = argparse.ArgumentParser(description="Launch the installed Forge client into a server and verify the join.")
    parser.add_argument("--host", default="192.3.179.150")
    parser.add_argument("--port", type=int, default=25565)
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--minecraft-dir", type=pathlib.Path, default=pathlib.Path(os.environ["APPDATA"]) / ".minecraft")
    parser.add_argument("--offline-username", help="Use an offline-mode verifier identity instead of a launcher token.")
    parser.add_argument("--offline-uuid", help="Optional UUID for --offline-username. Defaults to the standard offline UUID.")
    parser.add_argument("--skip-pack-check", action="store_true", help="Skip client mod hash verification before launch.")
    parser.add_argument("--remote-host")
    parser.add_argument("--remote-port", type=int, default=22)
    parser.add_argument("--remote-user", default="root")
    parser.add_argument("--remote-password-env")
    parser.add_argument("--remote-password-stdin", action="store_true")
    parser.add_argument("--remote-identity-file")
    parser.add_argument("--remote-allow-agent", action="store_true")
    parser.add_argument("--remote-look-for-keys", action="store_true")
    parser.add_argument("--remote-log", default="/opt/minecraft/server/logs/latest.log")
    args = parser.parse_args()

    minecraft_dir = args.minecraft_dir.resolve()
    if not args.skip_pack_check:
        verify_client_modset(minecraft_dir)

    if args.offline_username:
        account = offline_account(args.offline_username, args.offline_uuid)
        print("auth: using explicit offline-mode verifier identity")
    else:
        account = read_launcher_account(minecraft_dir)
    java = find_java()
    command = build_command(minecraft_dir, account, java, args.host, args.port)
    print(f"player: {account['username']}")
    print(f"version: {MINECRAFT_VERSION}")
    print(f"java: {java}")
    print(f"target: {args.host}:{args.port}")

    remote_client = None
    remote_offset = 0
    if args.remote_host:
        password = read_password(args)
        if not password and not (args.remote_identity_file or args.remote_allow_agent or args.remote_look_for_keys):
            raise RuntimeError(
                "Remote verification needs --remote-password-stdin, --remote-password-env, "
                "or key auth via --remote-identity-file/--remote-allow-agent/--remote-look-for-keys."
            )
        remote_client = connect_ssh(args, password, 20)
        remote_offset = int(remote_exec(remote_client, f"wc -c < {shell_quote(args.remote_log)}").strip() or "0")
        print(f"remote log offset: {remote_offset}")

    launch_log = minecraft_dir / "codex-client-connect-verify.log"
    start_time = time.time()
    previous_crashes = {path.name for path in (minecraft_dir / "crash-reports").glob("*.txt")} if (minecraft_dir / "crash-reports").exists() else set()
    proc = subprocess.Popen(command, cwd=minecraft_dir, stdout=launch_log.open("w", encoding="utf-8", errors="replace"), stderr=subprocess.STDOUT)
    print(f"launched pid: {proc.pid}")

    success_patterns = [
        re.compile(rf"\b{re.escape(account['username'])}\b.* logged in with entity id", re.IGNORECASE),
        re.compile(rf"\b{re.escape(account['username'])}\b joined the game", re.IGNORECASE),
    ]
    failure_patterns = [
        re.compile(r"Unexpected custom data from client", re.IGNORECASE),
        re.compile(r"mismatched mod channel list", re.IGNORECASE),
        re.compile(r"fatally missing registry entries", re.IGNORECASE),
        re.compile(r"Failed to connect|Disconnected|Internal Exception", re.IGNORECASE),
        re.compile(r"NoSuchFieldError|Exception in thread|Crash report", re.IGNORECASE),
    ]

    try:
        last_status = 0.0
        while time.time() - start_time < args.timeout:
            elapsed = int(time.time() - start_time)
            if time.time() - last_status >= 30:
                print(f"waiting for client/server join... {elapsed}s")
                last_status = time.time()

            if proc.poll() is not None:
                local_log = read_text(minecraft_dir / "logs" / "latest.log")[-12000:]
                launch_tail = read_text(launch_log)[-12000:]
                raise RuntimeError(f"Minecraft exited before verified join (code {proc.returncode}).\n{local_log}\n{launch_tail}")

            local_log = read_text(minecraft_dir / "logs" / "latest.log")[-12000:]
            if any(pattern.search(local_log) for pattern in failure_patterns):
                raise RuntimeError("Local client log contains a connection/crash failure marker.")

            crash_dir = minecraft_dir / "crash-reports"
            if crash_dir.exists():
                new_crashes = [path for path in crash_dir.glob("*.txt") if path.name not in previous_crashes]
                if new_crashes:
                    newest = max(new_crashes, key=lambda path: path.stat().st_mtime)
                    raise RuntimeError(f"New client crash report was created: {newest}")

            if remote_client:
                command_text = (
                    f"tail -c +{remote_offset + 1} {shell_quote(args.remote_log)} "
                    f"| grep -E {shell_quote(account['username'] + '|Unexpected custom data|mismatched mod channel|fatally missing|lost connection|Disconnecting')} || true"
                )
                remote_tail = remote_exec(remote_client, command_text)
                if any(pattern.search(remote_tail) for pattern in success_patterns):
                    print("verified remote join:")
                    print(remote_tail.strip()[-4000:])
                    return 0
                if any(pattern.search(remote_tail) for pattern in failure_patterns):
                    raise RuntimeError(f"Remote server log contains a join failure marker:\n{remote_tail.strip()[-4000:]}")

            time.sleep(5)

        raise RuntimeError(f"Timed out after {args.timeout}s waiting for verified join.")
    finally:
        terminate(proc)
        if remote_client:
            remote_client.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
