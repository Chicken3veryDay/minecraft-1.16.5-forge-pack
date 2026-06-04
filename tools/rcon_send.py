#!/usr/bin/env python3
import argparse
import os
import socket
import struct
import sys


SERVERDATA_AUTH = 3
SERVERDATA_EXECCOMMAND = 2
SERVERDATA_RESPONSE_VALUE = 0


def packet(request_id: int, packet_type: int, payload: str) -> bytes:
    body = struct.pack("<ii", request_id, packet_type) + payload.encode("utf-8") + b"\x00\x00"
    return struct.pack("<i", len(body)) + body


def recv_packet(sock: socket.socket):
    size_bytes = sock.recv(4)
    if len(size_bytes) != 4:
        raise RuntimeError("RCON response was truncated before size.")
    size = struct.unpack("<i", size_bytes)[0]
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise RuntimeError("RCON response ended early.")
        data += chunk
    request_id, packet_type = struct.unpack("<ii", data[:8])
    payload = data[8:-2].decode("utf-8", errors="replace")
    return request_id, packet_type, payload


def send_command(host: str, port: int, password: str, command: str, timeout: float) -> str:
    with socket.create_connection((host, port), timeout=timeout) as sock:
        sock.settimeout(timeout)
        sock.sendall(packet(1, SERVERDATA_AUTH, password))
        request_id, _, _ = recv_packet(sock)
        if request_id == -1:
            raise RuntimeError("RCON authentication failed.")

        sock.sendall(packet(2, SERVERDATA_EXECCOMMAND, command))
        _, packet_type, payload = recv_packet(sock)
        if packet_type not in (SERVERDATA_RESPONSE_VALUE, SERVERDATA_EXECCOMMAND):
            raise RuntimeError(f"Unexpected RCON packet type {packet_type}.")
        return payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Send one Minecraft RCON command.")
    parser.add_argument("host")
    parser.add_argument("port", type=int)
    parser.add_argument("command")
    password_group = parser.add_mutually_exclusive_group(required=True)
    password_group.add_argument("--password-env", help="Environment variable containing the RCON password.")
    password_group.add_argument("--password-stdin", action="store_true", help="Read the RCON password from stdin.")
    parser.add_argument("--timeout", type=float, default=10)
    args = parser.parse_args()

    if args.password_stdin:
        password = sys.stdin.readline().rstrip("\r\n")
        if not password:
            raise RuntimeError("Missing RCON password on stdin.")
    else:
        password = os.environ.get(args.password_env)
        if not password:
            raise RuntimeError(f"Missing RCON password env var: {args.password_env}")

    print(send_command(args.host, args.port, password, args.command, args.timeout))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
