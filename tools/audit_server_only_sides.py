#!/usr/bin/env python3
import re
import zipfile
from pathlib import Path


def read_mods_toml(path: Path) -> str:
    with zipfile.ZipFile(path) as jar:
        return jar.read("META-INF/mods.toml").decode("utf-8", errors="replace")


client_jars = {path.name for path in Path("Client").glob("*.jar")}
for path in sorted(Path("Server").glob("*.jar"), key=lambda value: value.name.lower()):
    if path.name in client_jars:
        continue

    text = read_mods_toml(path)
    mod_ids = re.findall(r'modId\s*=\s*"([^"]+)"', text)
    sides = sorted(set(re.findall(r'side\s*=\s*"([^"]+)"', text)))
    display_tests = re.findall(r'displayTest\s*=\s*"([^"]+)"', text)
    print(path.name)
    print("  modIds: " + ", ".join(mod_ids[:3]))
    print("  dependency sides: " + (", ".join(sides) if sides else "(none)"))
    print("  displayTest: " + (", ".join(display_tests) if display_tests else "(default)"))
