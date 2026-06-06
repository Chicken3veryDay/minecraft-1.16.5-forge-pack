#!/usr/bin/env python3
import argparse
import getpass
import hashlib
import json
import os
import sys
import uuid

import paramiko


def read_password(args: argparse.Namespace) -> str | None:
    if args.password_env:
        value = os.environ.get(args.password_env)
        if value:
            return value
        raise RuntimeError(f"Missing password env var: {args.password_env}")

    if args.password_stdin:
        value = sys.stdin.readline().rstrip("\r\n")
        if not value:
            raise RuntimeError("Missing SSH password on stdin.")
        return value

    if args.password:
        return args.password

    if args.identity_file or args.allow_agent or args.look_for_keys:
        return None

    return getpass.getpass("SSH password: ")


def connect(args: argparse.Namespace, password: str | None) -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        args.host,
        port=args.port,
        username=args.user,
        password=password,
        key_filename=args.identity_file,
        timeout=args.timeout,
        banner_timeout=args.timeout,
        auth_timeout=args.timeout,
        look_for_keys=args.look_for_keys,
        allow_agent=args.allow_agent,
    )
    return client


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Grant or refresh a Minecraft operator entry directly in ops.json. "
            "Works even when the server is not running."
        )
    )
    parser.add_argument("name", help="Operator username to grant/refresh.")
    parser.add_argument("--host", default="192.3.179.150", help="SSH host.")
    parser.add_argument("-u", "--user", default="root", help="SSH username.")
    parser.add_argument("-p", "--port", type=int, default=22, help="SSH port.")
    parser.add_argument("--password", help="SSH password.")
    parser.add_argument("--password-env", help="Environment variable containing the SSH password.")
    parser.add_argument("--password-stdin", action="store_true", help="Read SSH password from stdin.")
    parser.add_argument("--uuid", help="Explicit UUID for the operator.")
    parser.add_argument("--level", type=int, default=4, help="Operator level to assign (default: 4).")
    parser.add_argument("--ops-path", default="/opt/minecraft/server/ops.json", help="Remote ops.json path.")
    parser.add_argument("--identity-file", "-i", help="Private key file for key-based SSH auth.")
    parser.add_argument("--allow-agent", action="store_true", help="Allow Paramiko to use SSH agent keys.")
    parser.add_argument("--look-for-keys", action="store_true", help="Allow Paramiko to discover user SSH keys.")
    parser.add_argument("--timeout", type=float, default=20.0)

    bypass_group = parser.add_mutually_exclusive_group()
    bypass_group.set_defaults(bypass_player_limit=True)
    bypass_group.add_argument(
        "--bypass-player-limit",
        dest="bypass_player_limit",
        action="store_true",
        help="Set bypassesPlayerLimit to true in ops.json (default).",
    )
    bypass_group.add_argument(
        "--no-bypass-player-limit",
        dest="bypass_player_limit",
        action="store_false",
        help="Set bypassesPlayerLimit to false in ops.json.",
    )

    return parser.parse_args()


def offline_uuid(name: str) -> str:
    return str(uuid.UUID(bytes=hashlib.md5(f"OfflinePlayer:{name}".encode("utf-8")).digest()))


def parse_ops(raw: str) -> list[dict]:
    data = json.loads(raw)
    if not isinstance(data, list):
        raise ValueError("ops.json is expected to be a JSON list.")
    return data


def load_ops(sftp: paramiko.SFTPClient, path: str) -> list[dict]:
    try:
        with sftp.open(path, "r") as handle:
            return parse_ops(handle.read().decode("utf-8", errors="replace"))
    except FileNotFoundError:
        return []


def write_ops(sftp: paramiko.SFTPClient, path: str, entries: list[dict]) -> None:
    payload = json.dumps(entries, indent=2, ensure_ascii=False) + "\n"
    with sftp.open(path, "w") as handle:
        handle.write(payload)


def main() -> int:
    args = parse_args()
    password = read_password(args)
    client = connect(args, password)
    sftp = client.open_sftp()
    changed = False

    try:
        entries = load_ops(sftp, args.ops_path)
        name_key = args.name.lower()
        by_name = None
        by_uuid = None
        requested_uuid = args.uuid.lower() if args.uuid else None

        for entry in entries:
            if not isinstance(entry, dict):
                continue
            value_uuid = str(entry.get("uuid", "")).lower()
            if requested_uuid and value_uuid == requested_uuid:
                by_uuid = entry
            if str(entry.get("name", "")).lower() == name_key:
                by_name = entry

        existing = by_uuid or by_name
        effective_uuid = requested_uuid or (str(existing.get("uuid")).lower() if isinstance(existing, dict) else None) or offline_uuid(args.name)
        desired = {
            "uuid": effective_uuid,
            "name": args.name,
            "level": args.level,
            "bypassesPlayerLimit": args.bypass_player_limit,
        }

        if existing is None:
            existing = desired.copy()
            entries.append(existing)
            changed = True
            print(f"added-op: {args.name} -> {args.ops_path}")
        elif existing != desired:
            existing.update(desired)
            changed = True
            print(f"updated-op: {args.name} -> {args.ops_path}")

        if by_uuid and by_name and by_uuid is not by_name:
            entries = [entry for entry in entries if entry is by_uuid or entry is not by_name]
            changed = True

        if changed:
            write_ops(sftp, args.ops_path, entries)

        print(json.dumps(existing, indent=2, sort_keys=True))
        return 0
    finally:
        sftp.close()
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
