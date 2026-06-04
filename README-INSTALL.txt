Crazy Craft Updated 0.12.9 installer
====================================

Pack:
- Minecraft 1.16.5
- Forge 36.2.35
- Launcher profile: Crazy Craft Updated Forge
- Server entry: Crazy Craft Updated - 192.3.179.150:25565

Client install on Windows
-------------------------

1. Extract the minimal-pack zip from the GitHub Release.
2. Double-click Install-Minecraft-Pack.bat.
3. Let the installer download and verify pack-assets from the release.
4. The installer will install Forge 1.16.5-36.2.35, configure 8G max / 4G min launcher memory, back up old mods/configs/defaultconfigs/kubejs, copy the Crazy Craft client files, and add the multiplayer server entry.
5. Open Minecraft Launcher and launch:

   Crazy Craft Updated Forge
   1.16.5-forge-36.2.35

Verify an existing client without reinstalling:

  powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -VerifyOnly

Install without shaderpacks:

  powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -NoShader

Override launcher memory:

  powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -ClientMemoryMax 10G -ClientMemoryMin 4G

Linux server install
--------------------

The minimal-pack zip includes Install-CrazyCraft-Server.sh. Run it from the extracted minimal-pack folder on the server:

  chmod +x ./Install-CrazyCraft-Server.sh
  sudo ./Install-CrazyCraft-Server.sh

Defaults:
- SERVER_DIR=/opt/minecraft/server
- SERVICE_NAME=minecraft
- WIPE_WORLD=1
- START_SERVICE=1
- JAVA_ARGS="-Xms1G -Xmx4G -XX:+UseG1GC"

Override example:

  sudo SERVER_DIR=/srv/minecraft SERVICE_NAME=crazycraft WIPE_WORLD=0 ./Install-CrazyCraft-Server.sh

The script downloads pack-assets from the GitHub Release URL in .pack-manifest.json, verifies SHA-256, backs up the existing server, removes old pack files, copies the release Server payload, accepts eula.txt, clears level-seed, writes start-server.sh, updates systemd when run as root, and starts the service unless START_SERVICE=0.

Manual server launch command:

  cd /opt/minecraft/server
  java -Xms1G -Xmx4G -XX:+UseG1GC -jar forge.jar nogui

Release source hashes
---------------------

- Client CurseForge pack file ID 8069957:
  6940b0862291366a0f5d102f5dc1dc9e64dcedbb72024ff26bed0b867ca9fe1b
- Server pack file ID 8070007:
  0c7b14464dd659f2d11166822b146f2ab755d3992b4fb0ea029bd1a097991ad3

Notes
-----

The client payload is built from the exact CurseForge manifest file IDs. The server payload is the official Crazy Craft Updated server pack with `enhanced_boss_bars` removed because it loads client-only Minecraft classes on a dedicated server. Optimization/stability mods already included by the pack include ModernFix, FerriteCore, AI Improvements, Clumps, Connectivity, MemoryLeakFix, PacketFixer, Performant, FastWorkbench, FastFurnace, and FastAsyncWorldSave.
