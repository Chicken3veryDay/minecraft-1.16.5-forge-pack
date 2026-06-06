#!/usr/bin/env python3
import argparse
import getpass
import os
import sys
from pathlib import Path

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
    parser = argparse.ArgumentParser(description="Set difficulty in a remote server.properties file over SSH.")
    parser.add_argument("difficulty", nargs="?", default="hard", choices=["peaceful", "easy", "normal", "hard"], help="Target difficulty.")
    parser.add_argument("--host", default="192.3.179.150", help="SSH host.")
    parser.add_argument("-u", "--user", default="root", help="SSH username.")
    parser.add_argument("-p", "--port", type=int, default=22, help="SSH port.")
    parser.add_argument("--password", help="SSH password.")
    parser.add_argument("--password-env", help="Environment variable containing the SSH password.")
    parser.add_argument("--password-stdin", action="store_true", help="Read SSH password from stdin.")
    parser.add_argument("--properties", default="/opt/minecraft/server/server.properties", help="Remote server.properties path.")
    parser.add_argument("--identity-file", "-i", help="Private key file for key-based SSH auth.")
    parser.add_argument("--allow-agent", action="store_true", help="Allow Paramiko to use SSH agent keys.")
    parser.add_argument("--look-for-keys", action="store_true", help="Allow Paramiko to discover user SSH keys.")
    parser.add_argument("--timeout", type=float, default=20.0)
    return parser.parse_args()


def read_remote_lines(sftp: paramiko.SFTPClient, path: str) -> list[str]:
    with sftp.open(path, "r") as handle:
        return handle.read().decode("utf-8", errors="replace").splitlines()


def write_remote_lines(sftp: paramiko.SFTPClient, path: str, lines: list[str]) -> None:
    payload = "\n".join(lines) + "\n"
    with sftp.open(path, "w") as handle:
        handle.write(payload)


def main() -> int:
    args = parse_args()
    password = read_password(args)
    client = connect(args, password)
    sftp = client.open_sftp()

    try:
        lines = read_remote_lines(sftp, args.properties)
        matched = False
        updated: list[str] = []

        for line in lines:
            if line.startswith("difficulty="):
                if line.strip() != f"difficulty={args.difficulty}":
                    updated.append(f"difficulty={args.difficulty}")
                else:
                    updated.append(line)
                matched = True
            else:
                updated.append(line)

        if not matched:
            updated.append(f"difficulty={args.difficulty}")

        old = next((line for line in lines if line.startswith("difficulty=")), "<missing>")
        new = f"difficulty={args.difficulty}"

        if old == new:
            print(f"difficulty already {args.difficulty}")
        else:
            write_remote_lines(sftp, args.properties, updated)
            print(f"updated difficulty: {old} -> {new}")

        return 0
    finally:
        sftp.close()
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
