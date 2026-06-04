# Crazy Craft Updated Installer Assets

This repository hosts the installer and release assets for the Crazy Craft Updated server/client pack used on `192.3.179.150:25565`.

- Current target release: `v2026.06.04`
- Modpack: Crazy Craft Updated `0.12.9`
- Official source: <https://www.curseforge.com/minecraft/modpacks/crazy-craft-updated>
- Minecraft: `1.16.5`
- Forge: `36.2.35`
- Server launch on the VPS: `java -Xms1G -Xmx4G -XX:+UseG1GC -jar forge.jar nogui`

## Source Files

- Client CurseForge pack: `Crazy Craft Updated-0.12.9.zip`
  - CurseForge file ID: `8069957`
  - SHA-256: `6940b0862291366a0f5d102f5dc1dc9e64dcedbb72024ff26bed0b867ca9fe1b`
- Server pack: `CCU Server Pack Bat - 0.12.9.zip`
  - CurseForge file ID: `8070007`
  - SHA-256: `0c7b14464dd659f2d11166822b146f2ab755d3992b4fb0ea029bd1a097991ad3`

## Release Contents

Each GitHub Release should contain only:

- `minimal-pack-<hash>.zip`: installer package containing:
  - `Install-Minecraft-Pack.bat`
  - `Install-Minecraft-Pack.ps1`
  - `Install-CrazyCraft-Server.sh`
  - `.pack-manifest.json`
  - `README-INSTALL.txt`
- `pack-assets-<hash>.zip`: verified payload containing:
  - `Client/`: 331 exact client mod jars from the CurseForge manifest
  - `Config/`: client config overrides
  - `Root/`: root-level client overrides such as `defaultconfigs`, `kubejs`, and `mods/hats`
  - `Server/`: official Crazy Craft Updated server pack tree, with server-incompatible `enhanced_boss_bars` files removed
  - `Shaderpacks/`: empty unless a future Crazy Craft release ships shaderpacks

No backups, screenshots, caches, old custom-pack zips, or duplicate stale assets belong on the release page.

## Build Flow

```powershell
.\tools\Build-CrazyCraftAssets.ps1
.\Build-PackRelease.ps1 -Tag v2026.06.04
```

Use `-Upload -VerifyHostedRelease` only after the live server migration is verified.
