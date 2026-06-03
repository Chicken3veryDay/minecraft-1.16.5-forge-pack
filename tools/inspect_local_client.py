#!/usr/bin/env python3
import json
import os
import re
from pathlib import Path


PATTERN = re.compile(
    r"Unexpected custom data|fml:handshake|connect|disconnect|forge|modloading|FML|Rejected|Channels|ERROR|WARN|Missing|Mismatch",
    re.IGNORECASE,
)


def tail_matching(path: Path, limit: int = 250) -> list[str]:
    if not path.exists():
        return [f"missing: {path}"]

    matches = []
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if PATTERN.search(line):
                matches.append(line.rstrip("\n"))
    return matches[-limit:]


def inspect_profiles(minecraft_dir: Path) -> list[str]:
    profiles_path = minecraft_dir / "launcher_profiles.json"
    if not profiles_path.exists():
        return [f"missing: {profiles_path}"]

    data = json.loads(profiles_path.read_text(encoding="utf-8-sig"))
    lines = [f"profiles: {profiles_path}", f"selectedProfile={data.get('selectedProfile', '')}"]
    profiles = data.get("profiles", {})
    for key, profile in profiles.items():
        version = str(profile.get("lastVersionId", ""))
        name = str(profile.get("name", ""))
        if "1.16.5" in version or "forge" in version.lower() or "forge" in key.lower() or "forge" in name.lower():
            lines.append(
                "profile="
                + key
                + " name="
                + name
                + " version="
                + version
                + " gameDir="
                + str(profile.get("gameDir", ""))
            )
    return lines


def inspect_versions(minecraft_dir: Path) -> list[str]:
    versions_dir = minecraft_dir / "versions"
    if not versions_dir.exists():
        return [f"missing: {versions_dir}"]

    values = sorted(
        path.name
        for path in versions_dir.iterdir()
        if path.is_dir() and ("1.16.5" in path.name or "forge" in path.name.lower())
    )
    return ["versions:"] + values


def main() -> int:
    minecraft_dir = Path(os.environ["APPDATA"]) / ".minecraft"
    latest_log = minecraft_dir / "logs" / "latest.log"

    print("== local minecraft ==")
    print(minecraft_dir)
    print("== launcher profiles ==")
    print("\n".join(inspect_profiles(minecraft_dir)))
    print("== versions ==")
    print("\n".join(inspect_versions(minecraft_dir)))
    print("== latest.log notable lines ==")
    print("\n".join(tail_matching(latest_log)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
