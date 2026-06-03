#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import posixpath
import sys
from pathlib import Path

import paramiko


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_by_name(manifest: dict, section: str) -> dict[str, str]:
    return {item["name"]: item["sha256"].lower() for item in manifest.get(section, [])}


def compare_local(label: str, folder: Path, expected: dict[str, str]) -> bool:
    actual_files = {path.name: path for path in folder.glob("*.jar")} if folder.exists() else {}
    extras = sorted(set(actual_files) - set(expected))
    missing = sorted(set(expected) - set(actual_files))
    mismatches = []

    for name in sorted(set(actual_files) & set(expected)):
        actual_hash = file_sha256(actual_files[name])
        if actual_hash != expected[name]:
            mismatches.append(name)

    print(f"== {label} ==")
    print(f"path: {folder}")
    print(f"expected jars: {len(expected)}")
    print(f"actual jars: {len(actual_files)}")
    print_list("extra", extras)
    print_list("missing", missing)
    print_list("hash mismatches", mismatches)
    ok = not extras and not missing and not mismatches
    print(f"result: {'OK' if ok else 'DIFF'}")
    return ok


def print_list(label: str, values: list[str]) -> None:
    print(f"{label}: {len(values)}")
    for value in values:
        print(f"  {value}")


def connect(host: str, user: str, password: str, timeout: float) -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        host,
        username=user,
        password=password,
        timeout=timeout,
        banner_timeout=timeout,
        auth_timeout=timeout,
        look_for_keys=False,
        allow_agent=False,
    )
    return client


def remote_sha256s(client: paramiko.SSHClient, remote_mods: str) -> dict[str, str]:
    command = f"cd {shell_quote(remote_mods)} && sha256sum *.jar"
    stdin, stdout, stderr = client.exec_command(command)
    stdin.close()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    code = stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", errors="replace")
    if code != 0:
        raise RuntimeError(f"remote sha256sum failed ({code}): {err}")

    result = {}
    for line in out.splitlines():
        if not line.strip():
            continue
        hash_value, name = line.split(None, 1)
        result[posixpath.basename(name.strip())] = hash_value.lower()
    return result


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def read_password(password_env: str, password_stdin: bool) -> str:
    if password_stdin:
        password = sys.stdin.readline().rstrip("\r\n")
        if password:
            return password
        raise RuntimeError("Missing password on stdin.")

    password = os.environ.get(password_env)
    if password:
        return password

    raise RuntimeError(f"Missing password env var: {password_env}")


def compare_remote(host: str, user: str, password: str, remote_mods: str, expected: dict[str, str], timeout: float) -> bool:
    client = connect(host, user, password, timeout)
    try:
        actual = remote_sha256s(client, remote_mods)
    finally:
        client.close()

    extras = sorted(set(actual) - set(expected))
    missing = sorted(set(expected) - set(actual))
    mismatches = sorted(name for name in set(actual) & set(expected) if actual[name] != expected[name])

    print("== remote server mods ==")
    print(f"host: {host}")
    print(f"path: {remote_mods}")
    print(f"expected jars: {len(expected)}")
    print(f"actual jars: {len(actual)}")
    print_list("extra", extras)
    print_list("missing", missing)
    print_list("hash mismatches", mismatches)
    ok = not extras and not missing and not mismatches
    print(f"result: {'OK' if ok else 'DIFF'}")
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare installed Minecraft pack state against .pack-manifest.json.")
    parser.add_argument("--root", default=Path(__file__).resolve().parents[1], type=Path)
    parser.add_argument("--client-dir", type=Path)
    parser.add_argument("--remote-host")
    parser.add_argument("--remote-user", default="root")
    parser.add_argument("--remote-password-env", default="SSHPASS")
    parser.add_argument("--remote-password-stdin", action="store_true")
    parser.add_argument("--remote-mods", default="/opt/minecraft/server/mods")
    parser.add_argument("--timeout", type=float, default=20)
    args = parser.parse_args()

    root = args.root.resolve()
    manifest = json.loads((root / ".pack-manifest.json").read_text(encoding="utf-8-sig"))
    client_dir = args.client_dir or Path(os.environ["APPDATA"]) / ".minecraft" / "mods"

    checks = [
        compare_local("local client mods", client_dir, expected_by_name(manifest, "client")),
        compare_local("repo server mods", root / "Server", expected_by_name(manifest, "server")),
    ]
    if args.remote_host:
        password = read_password(args.remote_password_env, args.remote_password_stdin)
        checks.append(
            compare_remote(
                args.remote_host,
                args.remote_user,
                password,
                args.remote_mods,
                expected_by_name(manifest, "server"),
                args.timeout,
            )
        )

    return 0 if all(checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
