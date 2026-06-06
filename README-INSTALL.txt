Forge 1.20.1 ProjectE chaos pack installer
==========================================

Target assumptions
------------------

- Minecraft: `1.20.1`
- Loader: `Forge`
- World policy: fresh world
- Audience: private friends
- Pack identity: `ProjectE` + hard adventure chaos
- Host target: dedicated Linux with NVMe
- Planning target: `12-16 GB` RAM, `6` fast CPU cores
- Starting dedicated-server JVM target: `-Xms4G -Xmx8G`

Windows client staging
----------------------

1. Extract the `minimal-pack` zip from the release.
2. Run `Install-Minecraft-Pack.bat` or:

   `powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1`

3. The installer stages the client files into a dedicated instance directory, installs Forge `1.20.1-47.2.32` into the Minecraft Launcher root, verifies hashes from `.pack-manifest.json`, and writes a connection note if a multiplayer endpoint is provided.
4. The installer also creates or updates a launcher profile for this pack and points it at:

   `%APPDATA%\.minecraft\forge-projecte-chaos-1.20.1`

Useful flags:

- Verify only:

  `powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -VerifyOnly`

- Stage to a custom directory:

  `powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -ClientPath D:\Minecraft\forge-projecte-chaos-1.20.1`

- Stage only the server payload:

  `powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -Server -ServerPath D:\Minecraft\forge-projecte-chaos-server`

Linux server staging
--------------------

The minimal-pack zip includes `Install-Forge-Server.sh`. Run it from the extracted folder on the host:

  chmod +x ./Install-Forge-Server.sh
  sudo ./Install-Forge-Server.sh

Defaults:

- `SERVER_DIR=/opt/minecraft/server`
- `SERVICE_NAME=minecraft`
- `WIPE_WORLD=1`
- `START_SERVICE=1`
- `JAVA_ARGS="-Xms4G -Xmx8G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC"`

Override example:

  sudo SERVER_DIR=/srv/minecraft/projecte-chaos SERVICE_NAME=projecte-chaos WIPE_WORLD=0 ./Install-Forge-Server.sh

The script stages the server payload, copies shared/server mods, preserves selected `server.properties` keys when possible, clears `level-seed` for a fresh world, runs the bundled Forge installer when Java is available, and writes `start-server.sh`.

Operational expectations
------------------------

- `ProjectE` is part of the pack identity.
- Dimensions, bosses, and worldgen content make pregeneration strongly recommended before inviting players.
- `spark`, `ModernFix`, `FerriteCore`, `Chunky`, and `Clumps` are part of the lightweight reliability baseline.
- Do not reuse the old Forge `1.16.5` world.
- Do not expect a `4 GB` VPS to be comfortable for this pack without reducing the content set.

Notes
-----

This repo intentionally defaults to a Forge `1.20.1` friends-only adventure pack. The Fabric-named wrappers remain only as compatibility redirects to the Forge installer path.
