#!/usr/bin/env python3
import argparse
import pathlib
import sys
import tempfile

import nbtlib
from nbtlib import tag
import paramiko


def read_password(args: argparse.Namespace) -> str:
    if args.password_stdin:
        value = sys.stdin.readline().rstrip("\r\n")
        if value:
            return value
        raise RuntimeError("Missing SSH password on stdin.")
    raise RuntimeError("Use --password-stdin to provide the SSH password.")


def connect_ssh(args: argparse.Namespace, password: str) -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        args.host,
        username=args.user,
        password=password,
        timeout=args.timeout,
        banner_timeout=args.timeout,
        auth_timeout=args.timeout,
        look_for_keys=False,
        allow_agent=False,
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


def patch_player(path: pathlib.Path, args: argparse.Namespace) -> None:
    player = nbtlib.load(path)
    player["Dimension"] = tag.String(args.dimension)
    player["Pos"] = tag.List[tag.Double]([tag.Double(args.x), tag.Double(args.y), tag.Double(args.z)])
    player["Motion"] = tag.List[tag.Double]([tag.Double(0.0), tag.Double(0.0), tag.Double(0.0)])
    player["FallDistance"] = tag.Float(0.0)
    player["Fire"] = tag.Short(0)
    player["Health"] = tag.Float(args.health)
    player["DeathTime"] = tag.Short(0)
    player["HurtTime"] = tag.Short(0)
    player.save(path)


def main() -> int:
    parser = argparse.ArgumentParser(description="Reset a remote Minecraft playerdata position safely over SSH/SFTP.")
    parser.add_argument("host")
    parser.add_argument("--user", default="root")
    parser.add_argument("--password-stdin", action="store_true")
    parser.add_argument("--timeout", type=float, default=20)
    parser.add_argument("--server-dir", default="/opt/minecraft/server")
    parser.add_argument("--uuid", required=True)
    parser.add_argument("--dimension", default="minecraft:overworld")
    parser.add_argument("--x", type=float, default=250.5)
    parser.add_argument("--y", type=float, default=90.0)
    parser.add_argument("--z", type=float, default=131.5)
    parser.add_argument("--health", type=float, default=20.0)
    args = parser.parse_args()

    password = read_password(args)
    remote_path = f"{args.server_dir}/world/playerdata/{args.uuid}.dat"

    client = connect_ssh(args, password)
    try:
        remote_exec(client, f"test -f {shell_quote(remote_path)}")
        with tempfile.TemporaryDirectory() as temp_dir:
            local_path = pathlib.Path(temp_dir) / f"{args.uuid}.dat"
            sftp = client.open_sftp()
            try:
                sftp.get(remote_path, str(local_path))
                patch_player(local_path, args)
                sftp.put(str(local_path), remote_path)
            finally:
                sftp.close()

        remote_exec(client, f"chown minecraft:minecraft {shell_quote(remote_path)}")
        print(f"reset {args.uuid} to {args.dimension} @ {args.x:.1f} {args.y:.1f} {args.z:.1f}")
    finally:
        client.close()

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
