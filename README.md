# Minecraft 1.16.5 Forge Pack Installer Assets

This repository hosts release assets for the minimal installer ZIP and hosted pack archive.

- Current release: https://github.com/Chicken3veryDay/minecraft-1.16.5-forge-pack/releases/tag/v2026.06.01
- Full mod list and SHA-256 hashes: MODLIST.md
- Minecraft: 1.16.5
- Forge: 36.2.42

Crafting fix candidate in the current pack: Polymorph was removed from client and server because it hooks recipe manager/workbench/result synchronization and matched the many-crafting-UI ghost-result symptom.

Boot fix in the current pack: Chaos Awakens was removed because it requires Geckolib below 3.0.98, while Dungeons Gear requires Geckolib 3.0.103 or newer. Craziniess Awakened remains installed.
