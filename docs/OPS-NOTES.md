# Operations Notes

These notes keep non-secret server details available for future Codex threads working in this repo.

## Minecraft Server

- Public Minecraft endpoint: `192.3.179.150:25565`
- Pack: Crazy Craft Updated `0.12.9`
- Minecraft: `1.16.5`
- Forge: `36.2.35`
- Server install path on VPS: `/opt/minecraft/server`
- systemd service: `minecraft`
- Server log path: `/opt/minecraft/server/logs/latest.log`
- Server properties path: `/opt/minecraft/server/server.properties`
- Current MOTD after migration: `Crazy Craft Updated 0.12.9`
- Fresh world seed after migration: `4996086032965686551`
- Pre-migration safety backup: `/opt/minecraft/server-backups/pre-crazycraft-20260604-013948/server.tar.gz`

## Source Artifacts

- CurseForge project: <https://www.curseforge.com/minecraft/modpacks/crazy-craft-updated>
- Client pack file ID `8069957`, SHA-256 `6940b0862291366a0f5d102f5dc1dc9e64dcedbb72024ff26bed0b867ca9fe1b`
- Server pack file ID `8070007`, SHA-256 `0c7b14464dd659f2d11166822b146f2ab755d3992b4fb0ea029bd1a097991ad3`
- Official server start command from `start.bat`: `java -Xmx8192M -Xms8192M -jar forge.jar nogui`
- VPS server launch command: `java -Xms1G -Xmx4G -XX:+UseG1GC -jar forge.jar nogui`

## VPS Access

- SSH target: `root@192.3.179.150:22`
- Do not commit the VPS password, RCON password, or live `server.properties`.
- Prefer `tools/ssh_ops.py` with a secure prompt wrapper. Do not pass secrets inline or through command-line environment setup.

## Migration Runbook

1. Verify SSH access.
2. Run read-only preflight:
   `python tools/ssh_ops.py 192.3.179.150 -u root --password-env CODEX_SSH_PASSWORD exec --command-file tools/remote_preflight_crazycraft.sh`
3. Stop `minecraft` and create a timestamped backup before destructive changes.
4. Wipe old world folders and previous pack folders.
5. Install the official Crazy Craft Updated server pack.
6. Preserve important `server.properties` choices such as `server-ip`, `server-port`, `online-mode`, RCON, whitelist, difficulty, and gamemode.
7. Clear `level-seed` before first startup so the map regenerates.
8. Start `minecraft`, wait for a fresh `Done (...)! For help` log line, record the generated seed, and ping `192.3.179.150:25565`.

The local migration helper for the current VPS is:

`tools/remote_install_crazycraft.sh`

The release-side Linux installer is:

`Install-CrazyCraft-Server.sh`

It installs from the GitHub Release `pack-assets` archive rather than from ForgeCDN.

## Optimization Notes

Crazy Craft Updated already includes several optimization/stability mods for 1.16.5 Forge, including ModernFix, FerriteCore, AI Improvements, Clumps, Connectivity, MemoryLeakFix, PacketFixer, Performant, FastWorkbench, FastFurnace, and FastAsyncWorldSave. Do not add unrelated content mods. Add more optimization mods only after verifying exact 1.16.5 Forge compatibility and server startup.

## Brandon Windows Client

- SSH target: `brandon@100.86.27.44:22`
- SSH key on Michael's machine: `C:\Users\micha\.ssh\brandon_admin_ed25519`
- Remote repair/update helper: `tools\Repair-RemoteWindowsMinecraftClient.ps1`
- Only update Brandon's client after the GitHub release and repo push are complete.
