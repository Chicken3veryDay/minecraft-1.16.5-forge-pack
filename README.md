# Minecraft 1.16.5 Forge Pack Installer Assets

This repository hosts release assets for the minimal installer ZIP and hosted pack archive.

- Current release: https://github.com/Chicken3veryDay/minecraft-1.16.5-forge-pack/releases/tag/v2026.06.03
- Full mod list and SHA-256 hashes: MODLIST.md
- Minecraft: 1.16.5
- Forge: 36.2.42

Crafting fix candidates in the current pack: Polymorph was removed from client and server because it hooks recipe manager/workbench/result synchronization and matched the many-crafting-UI ghost-result symptom. Client Crafting was also removed from the client pack because it modifies client-side crafting behavior and is unnecessary for server play.

Boot fix in the current pack: Chaos Awakens was removed because it requires Geckolib below 3.0.98, while Dungeons Gear requires Geckolib 3.0.103 or newer. Craziniess Awakened remains installed.

Server side fix in the current pack: Legendary Tooltips, Iceberg, and Prism are client-only here. They stay in Client, but were removed from Server after Legendary Tooltips loaded Minecraft client classes on the dedicated server.

Connection fix in the current pack: Inventory Pets now matches the VPS server jar (`inventorypets-1.16.5-2.2.jar`, SHA-256 `8bbb68cf77855e560406bf9d646a32b2452857709f41cf6c997d4a99210e99b1`) on both client and server, resolving the Forge mismatched mod channel disconnect.
