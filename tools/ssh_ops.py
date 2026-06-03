#!/usr/bin/env python3
import argparse
import getpass
import os
import posixpath
import stat
import sys

import paramiko


sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")


def read_password(args: argparse.Namespace) -> str | None:
    if args.password_env:
        value = os.environ.get(args.password_env)
        if value:
            return value

    if args.password_stdin:
        return sys.stdin.readline().rstrip("\r\n")

    if args.identity_file or args.allow_agent or args.look_for_keys:
        return None

    return getpass.getpass("SSH password: ")


def connect(args: argparse.Namespace) -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        args.host,
        port=args.port,
        username=args.user,
        password=read_password(args),
        key_filename=args.identity_file,
        timeout=args.timeout,
        banner_timeout=args.timeout,
        auth_timeout=args.timeout,
        look_for_keys=args.look_for_keys,
        allow_agent=args.allow_agent,
    )
    return client


def run_exec(client: paramiko.SSHClient, command: str) -> int:
    stdin, stdout, stderr = client.exec_command(command)
    stdin.close()

    for line in stdout:
        print(line, end="")
    for line in stderr:
        print(line, end="", file=sys.stderr)

    return stdout.channel.recv_exit_status()


def ensure_remote_dir(sftp: paramiko.SFTPClient, path: str) -> None:
    parts = [part for part in path.split("/") if part]
    current = "/" if path.startswith("/") else ""
    for part in parts:
        current = posixpath.join(current, part) if current else part
        try:
            mode = sftp.stat(current).st_mode
            if not stat.S_ISDIR(mode):
                raise RuntimeError(f"Remote path is not a directory: {current}")
        except FileNotFoundError:
            sftp.mkdir(current)


def put_path(sftp: paramiko.SFTPClient, local: str, remote: str) -> None:
    if os.path.isdir(local):
        ensure_remote_dir(sftp, remote)
        for root, _, files in os.walk(local):
            rel = os.path.relpath(root, local)
            remote_root = remote if rel == "." else posixpath.join(remote, rel.replace(os.sep, "/"))
            ensure_remote_dir(sftp, remote_root)
            for name in files:
                local_file = os.path.join(root, name)
                remote_file = posixpath.join(remote_root, name)
                print(f"put {local_file} -> {remote_file}")
                sftp.put(local_file, remote_file)
        return

    parent = posixpath.dirname(remote)
    if parent:
        ensure_remote_dir(sftp, parent)
    print(f"put {local} -> {remote}")
    sftp.put(local, remote)


def run_put(client: paramiko.SSHClient, pairs: list[list[str]]) -> int:
    sftp = client.open_sftp()
    try:
        for local, remote in pairs:
            put_path(sftp, local, remote)
    finally:
        sftp.close()
    return 0


def get_path(sftp: paramiko.SFTPClient, remote: str, local: str) -> None:
    mode = sftp.stat(remote).st_mode
    if stat.S_ISDIR(mode):
        os.makedirs(local, exist_ok=True)
        for item in sftp.listdir_attr(remote):
            remote_child = posixpath.join(remote, item.filename)
            local_child = os.path.join(local, item.filename)
            get_path(sftp, remote_child, local_child)
        return

    parent = os.path.dirname(local)
    if parent:
        os.makedirs(parent, exist_ok=True)
    print(f"get {remote} -> {local}")
    sftp.get(remote, local)


def run_get(client: paramiko.SSHClient, pairs: list[list[str]]) -> int:
    sftp = client.open_sftp()
    try:
        for remote, local in pairs:
            get_path(sftp, remote, local)
    finally:
        sftp.close()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run SSH commands or SFTP uploads.")
    parser.add_argument("host")
    parser.add_argument("-u", "--user", default="root")
    parser.add_argument("-p", "--port", type=int, default=22)
    parser.add_argument("--timeout", type=float, default=20)
    parser.add_argument("--password-env", help="Environment variable containing the SSH password.")
    parser.add_argument("--password-stdin", action="store_true", help="Read the SSH password from stdin.")
    parser.add_argument("-i", "--identity-file", help="Private key file for key-based SSH auth.")
    parser.add_argument("--allow-agent", action="store_true", help="Allow Paramiko to use keys from the SSH agent.")
    parser.add_argument("--look-for-keys", action="store_true", help="Allow Paramiko to discover keys from the user's SSH directory.")

    subparsers = parser.add_subparsers(dest="action", required=True)
    exec_parser = subparsers.add_parser("exec")
    exec_source = exec_parser.add_mutually_exclusive_group(required=True)
    exec_source.add_argument("command", nargs="?")
    exec_source.add_argument("--command-file")

    put_parser = subparsers.add_parser("put")
    put_parser.add_argument("pairs", nargs="+", help="Upload pairs: local remote [local remote ...]")

    get_parser = subparsers.add_parser("get")
    get_parser.add_argument("pairs", nargs="+", help="Download pairs: remote local [remote local ...]")

    args = parser.parse_args()
    if args.action in ("put", "get") and len(args.pairs) % 2 != 0:
        parser.error(f"{args.action} needs source/destination pairs")

    client = connect(args)
    try:
        if args.action == "exec":
            command = args.command
            if args.command_file:
                with open(args.command_file, "r", encoding="utf-8") as handle:
                    command = handle.read()
            return run_exec(client, command)

        pairs = [args.pairs[i : i + 2] for i in range(0, len(args.pairs), 2)]
        if args.action == "put":
            return run_put(client, pairs)
        return run_get(client, pairs)
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
