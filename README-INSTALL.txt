Minecraft 1.16.5 Forge Install
==============================

This bundle includes an automatic installer and manual install folders.

Requirements
------------
- Windows
- Minecraft Java Edition
- Minecraft Launcher
- Minecraft Launcher opened at least once and logged in
- Internet access the first time Forge is installed

Automatic client install
------------------------
Use this when you just want to join an existing server.

1. Close Minecraft Launcher if it is open. The installer also closes any running Minecraft Launcher or Minecraft Java process before it edits launcher profiles and replaces mods.
2. Double-click Install-Minecraft-Pack.bat.
3. Let the installer download and verify the pack assets if needed, install Forge 1.16.5-36.2.42, set the Forge launcher and Forge version memory to 8G max / 4G min, back up your old mods/configs, copy the client mods, config, and shaderpack, and add the multiplayer server entry.
4. Open Minecraft Launcher and launch the `ChickenEveryDay Forge` profile:
   1.16.5-forge-36.2.42

The minimal package only contains the installer, README, and .pack-manifest.json. It downloads the hosted pack asset archive automatically, verifies it with SHA-256, and caches it under _DownloadCache. If a hosted zip was rebuilt with different zip metadata but contains the same files, the installer verifies every contained file hash before continuing.

Before installing the pack, the installer backs up any existing `%appdata%\.minecraft\mods` and `%appdata%\.minecraft\config` folders, then clears them so old mods/configs do not conflict with this pack. Backups are saved under `%appdata%\.minecraft\_PackBackups`. Each backup includes `Restore-Previous-Mods-And-Configs.bat`; double-click it to put the previous mods/configs back.

At the end, the installer prints a status report showing which steps passed or failed. It also checks whether the configured Minecraft server answers TCP connections and whether Minecraft Launcher has an active account. If the server check passes but `Detect launcher account` fails, open Minecraft Launcher, sign in to the Java Edition account, close the launcher, and then launch the `ChickenEveryDay Forge` profile.

The installer adds this server to Multiplayer automatically:
  ChickenEveryDay Modded - 192.3.179.150:25565

The installer also changes the Java play profile to `ChickenEveryDay Forge`, writes the Store launcher profile file when needed, and sets the Forge JVM memory because this pack can run out of heap at the default launcher allocation. To override it:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -ClientMemoryMax 10G -ClientMemoryMin 4G

To install only the client files without changing Multiplayer, run:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -SkipServerEntry

To skip the final server/account checks, run:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -SkipConnectionCheck

If you are using your own hosted loose-file mirror instead of the manifest's asset archive, provide a base URL:

 powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -AssetBaseUrl "https://example.com/pack"

The installer tries each file in manifest order:
- local bundled file, if this is a full pack folder
- hosted asset archive from .pack-manifest.json
- direct `url` field in manifest entry (if present)
- `-AssetBaseUrl` + item path

Downloaded files are cached under `_DownloadCache` and verified with manifest SHA-256 hashes.
You can also put a top-level `assetBaseUrl` in `.pack-manifest.json` to avoid passing the flag for loose-file mirrors.

For joining someone else's server, you only need the Client mods, Config folder, and Shaderpacks folder. The Server folder is not needed.

Automatic server mod copy
-------------------------
Use this only when you are preparing your own Forge server.

Run this from PowerShell, replacing the path with your server folder:

  powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -Server -ServerPath "C:\Path\To\ForgeServer"

This copies the bundled Server mods into that server's mods folder. It does not create a server, accept the EULA, or start the server.

Manual client install
---------------------
You can manually download the full modpack files from:
  https://github.com/Chicken3veryDay/minecraft-1.16.5-forge-pack/releases/tag/v2026.06.03

1. Install Forge 1.16.5-36.2.42 in Minecraft Launcher.
2. Open your Minecraft folder:
   - Press Win+R
   - Type %appdata%\.minecraft
   - Press Enter
3. Copy everything from this bundle's Client folder into:
   %appdata%\.minecraft\mods
4. Copy everything from this bundle's Config folder into:
   %appdata%\.minecraft\config
5. Copy the shader zip from this bundle's Shaderpacks folder into:
   %appdata%\.minecraft\shaderpacks
6. Launch the Forge 1.16.5 profile.

If a friend gets "Disconnected" or the server logs show `Disconnecting VANILLA connection attempt` / `mismatched mod list`, they are still on a non-matching client (vanilla or wrong jar versions). Have them:

1. Close Minecraft Launcher.
2. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Minecraft-Pack.ps1 -Force`.
3. Start the `ChickenEveryDay Forge` profile.

Manual server install
---------------------
1. Install or prepare a Forge 1.16.5-36.2.42 server.
2. Copy everything from this bundle's Server folder into the server's mods folder.
3. Start the server normally.

Folder guide
------------
- Client: mods for a player's Minecraft client
- Config: packaged config files for this pack
- Server: mods for a Forge server
- Shaderpacks: optional client shader zip
- .pack-manifest.json: file list and SHA-256 hashes used by the installer
- Install-Minecraft-Pack.bat / Install-Minecraft-Pack.ps1: automatic installer
- Build-PackRelease.ps1: rebuilds pack-assets.zip, .pack-manifest.json, and minimal-pack.zip for GitHub Releases
- tools\minecraft_status_ping.py: live Minecraft Java status ping for server reachability evidence
- tools\Repair-RemoteWindowsMinecraftClient.ps1: uploads the current minimal pack to a Windows client over SSH and reruns the installer

Release build/upload
--------------------
When updating a GitHub Release, rebuild and upload both release assets from the same local build:

  powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-PackRelease.ps1 -Owner Chicken3veryDay -Repo minecraft-1.16.5-forge-pack -Tag v2026.06.03 -Upload -VerifyHostedRelease

The script uploads hash-named release assets by default, deletes stale same-name release assets, and checks GitHub's hosted SHA-256 digests after upload so the minimal installer and hosted asset archive cannot point at different builds silently. Use `-StaticAssetNames` only if you intentionally need the legacy `minimal-pack.zip` and `pack-assets.zip` release asset names.
