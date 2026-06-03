#!/usr/bin/env python3
import argparse
import json
import socket
import struct
import time


PROTOCOL_VERSION_1_16_5 = 754


def encode_varint(value: int) -> bytes:
    out = bytearray()
    value &= 0xFFFFFFFF
    while True:
        part = value & 0x7F
        value >>= 7
        if value:
            part |= 0x80
        out.append(part)
        if not value:
            return bytes(out)


def read_varint(sock: socket.socket) -> int:
    value = 0
    shift = 0
    for _ in range(5):
        raw = sock.recv(1)
        if not raw:
            raise EOFError("Socket closed while reading varint.")
        byte = raw[0]
        value |= (byte & 0x7F) << shift
        if (byte & 0x80) == 0:
            return value
        shift += 7
    raise ValueError("Varint is too long.")


def read_exact(sock: socket.socket, length: int) -> bytes:
    chunks = bytearray()
    while len(chunks) < length:
        chunk = sock.recv(length - len(chunks))
        if not chunk:
            raise EOFError("Socket closed before enough data was read.")
        chunks.extend(chunk)
    return bytes(chunks)


def encode_string(value: str) -> bytes:
    encoded = value.encode("utf-8")
    return encode_varint(len(encoded)) + encoded


def packet(packet_id: int, payload: bytes = b"") -> bytes:
    body = encode_varint(packet_id) + payload
    return encode_varint(len(body)) + body


def status_ping(host: str, port: int, timeout: float) -> tuple[dict, float]:
    start = time.perf_counter()
    with socket.create_connection((host, port), timeout=timeout) as sock:
        sock.settimeout(timeout)
        handshake = (
            encode_varint(PROTOCOL_VERSION_1_16_5)
            + encode_string(host)
            + struct.pack(">H", port)
            + encode_varint(1)
        )
        sock.sendall(packet(0, handshake))
        sock.sendall(packet(0))

        packet_length = read_varint(sock)
        packet_data = read_exact(sock, packet_length)
        offset = 0

        def read_packet_varint() -> int:
            nonlocal offset
            value = 0
            shift = 0
            for _ in range(5):
                byte = packet_data[offset]
                offset += 1
                value |= (byte & 0x7F) << shift
                if (byte & 0x80) == 0:
                    return value
                shift += 7
            raise ValueError("Packet varint is too long.")

        response_id = read_packet_varint()
        if response_id != 0:
            raise RuntimeError(f"Unexpected status response packet id: {response_id}")

        json_length = read_packet_varint()
        response_json = packet_data[offset : offset + json_length].decode("utf-8")
        elapsed_ms = (time.perf_counter() - start) * 1000
        return json.loads(response_json), elapsed_ms


def motd_text(description: object) -> str:
    if isinstance(description, str):
        return description
    if isinstance(description, dict):
        pieces = []
        if isinstance(description.get("text"), str):
            pieces.append(description["text"])
        for child in description.get("extra") or []:
            child_text = motd_text(child)
            if child_text:
                pieces.append(child_text)
        return "".join(pieces)
    if isinstance(description, list):
        return "".join(motd_text(item) for item in description)
    return ""


def main() -> int:
    parser = argparse.ArgumentParser(description="Check a Minecraft Java server with the status protocol.")
    parser.add_argument("host")
    parser.add_argument("-p", "--port", type=int, default=25565)
    parser.add_argument("--timeout", type=float, default=10)
    parser.add_argument("--json", action="store_true", help="Print the raw status JSON.")
    args = parser.parse_args()

    status, elapsed_ms = status_ping(args.host, args.port, args.timeout)
    if args.json:
        print(json.dumps(status, indent=2, sort_keys=True))

    version = status.get("version") or {}
    players = status.get("players") or {}
    print(f"status: online")
    print(f"target: {args.host}:{args.port}")
    print(f"latency_ms: {elapsed_ms:.0f}")
    print(f"version: {version.get('name', 'unknown')} protocol {version.get('protocol', 'unknown')}")
    print(f"players: {players.get('online', 'unknown')}/{players.get('max', 'unknown')}")

    text = motd_text(status.get("description")).strip()
    if text:
        print(f"motd: {text}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
