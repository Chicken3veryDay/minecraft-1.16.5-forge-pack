# Operations Notes

These notes keep non-secret server details available for future Codex threads working in this repo.

## Minecraft Server

- Public Minecraft endpoint: `192.3.179.150:25565`
- Version: Minecraft `1.16.5`, Forge `36.2.42`
- Expected MOTD: `RackNerd Forge 1.16.5`
- Authentication mode: `online-mode=false` so offline/unofficial accounts can join.
- Server install path on VPS: `/opt/minecraft/server`
- Server log path on VPS: `/opt/minecraft/server/logs/latest.log`
- Server properties path on VPS: `/opt/minecraft/server/server.properties`

## VPS Access

- SSH target: `root@192.3.179.150:22`
- Do not commit the VPS password, RCON password, or live `server.properties`.
- Use `tools/ssh_ops.py` for password/key based SSH and SFTP operations when Paramiko is available.

## Operator Permissions

- `Chicken3veryDay` is already present in `/opt/minecraft/server/ops.json` with `level: 4` and `bypassesPlayerLimit: true`.
- Server operator permission level is `op-permission-level=4`.
- Latest verification (2026-06-03 21:00 UTC): latest server log shows `Chicken3veryDay` joined the game as a connected player and is tracked in ops.
- To verify quickly from this repo:
  - `python tools/ssh_ops.py 192.3.179.150 -u root exec "cat /opt/minecraft/server/ops.json"` (use the usual auth method).
  - `python tools/ssh_ops.py 192.3.179.150 -u root exec "grep -n \"op-permission-level\\|online-mode\\|enable-rcon\\|rcon.port\" /opt/minecraft/server/server.properties"`.

## Brandon Windows Client

- SSH target: `brandon@100.86.27.44:22`
- SSH key on Michael's machine: `C:\Users\micha\.ssh\brandon_admin_ed25519`
- Remote repair/update helper: `tools\Repair-RemoteWindowsMinecraftClient.ps1`
- Only update Brandon's client after the GitHub release and repo push are complete.

## Last Known Connection Fix

The working fix for the Forge disconnect was replacing the client/server Inventory Pets jar with the VPS server version:

- File: `inventorypets-1.16.5-2.2.jar`
- SHA-256: `8bbb68cf77855e560406bf9d646a32b2452857709f41cf6c997d4a99210e99b1`
- Failure signature before the fix: `Channels [inventorypets:channel] rejected their client side version number` followed by `mismatched mod channel list`.
- Current live check (2026-06-03 22:00 UTC): pack hashes are aligned (`check_pack_state.py` passes), but join attempts that still fail with:
  - `rejected their client side version number` / `mismatched mod list`
  - `Disconnecting VANILLA connection attempt`
  indicate the joining client is not running the matching Forge clientmodset. Re-run the installer on that machine:
  `powershell -NoProfile -ExecutionPolicy Bypass -File ..\Install-Minecraft-Pack.ps1 -Force`.
- Client installs now include a hard local launch gate: the installer fails unless `ChickenEveryDay Forge` is selected for `1.16.5-forge-36.2.42` and the installed `mods` jars exactly match `.pack-manifest.json`. To validate a friend's already-installed client without changing files, run:
  `powershell -NoProfile -ExecutionPolicy Bypass -File ..\Install-Minecraft-Pack.ps1 -VerifyOnly`.
