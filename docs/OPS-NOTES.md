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

