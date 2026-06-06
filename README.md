# Forge 1.20.1 ProjectE Chaos Pack

This repository is now the packaging and verification workspace for a fresh-world Minecraft `1.20.1` `Forge` private friend-server pack centered on `ProjectE`, hard mobs, bosses, dungeons, structures, dimensions, loot pressure, and chaotic adventure content.

The old Fabric scaffold and the older Crazy Craft Updated `1.16.5` deployment are no longer the default path. New contributor defaults are:

- Platform: `Forge`
- Minecraft version: `1.20.1`
- World policy: `fresh`
- Audience: `private friends`
- Required identity: `ProjectE`
- Content priority: mobs, bosses, dungeons, structures, dimensions, loot, difficulty
- Live cutover / remote actions: require explicit approval

## Repo Direction

The repo now builds client and server deliverables from `pack-sources/` using real downloaded public mods plus a bundled Forge server installer. The default workflow is:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Resolve-ForgePack.ps1
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-ForgePackAssets.ps1
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-PackRelease.ps1 -Tag v2026.06.04
```

Primary release artifacts remain:

- `pack-assets*.zip`
- `minimal-pack*.zip`
- `.pack-manifest.json`

## Installed Content Shape

The seeded pack resolves real public Forge `1.20.1` mods in these categories:

- `ProjectE` exchange progression
- major mobs and bosses: `Alex's Mobs`, `Mowzie's Mobs`, `L_Ender's Cataclysm`
- dimensions: `The Twilight Forest`, `Blue Skies`, `The Bumblezone`
- structures and dungeons: `When Dungeons Arise`, `Repurposed Structures`, `YUNG's Better Dungeons`, `YUNG's Better Strongholds`, `Dungeon Crawl`
- QoL: `Waystones`, `Corail Tombstone`, `JEI`, `Jade`, `AppleSkin`, `Simple Voice Chat`, `Xaero's` maps
- lightweight performance: `spark`, `ModernFix`, `FerriteCore`, `Chunky`, `Clumps`, `Embeddium`, `Entity Culling`, `ImmediatelyFast`

No large automation pillar mods such as `Create`, `Mekanism`, `Applied Energistics`, or `Refined Storage` are seeded.

## Primary Files

- [SPEC.md](C:\Users\micha\Desktop\Mods\SPEC.md): pack intent and constraints
- [GOAL.md](C:\Users\micha\Desktop\Mods\GOAL.md): execution contract and verification gates
- [README-INSTALL.txt](C:\Users\micha\Desktop\Mods\README-INSTALL.txt): client/server staging instructions
- [MODLIST.md](C:\Users\micha\Desktop\Mods\MODLIST.md): generated installed mod inventory
- [docs/OPS-NOTES.md](C:\Users\micha\Desktop\Mods\docs\OPS-NOTES.md): runtime posture and operational notes
- [pack-sources/pack-blueprint.json](C:\Users\micha\Desktop\Mods\pack-sources\pack-blueprint.json): pack metadata, seed list, resolved mods, and Forge installer metadata

## Install Flow

- Windows client staging: `Install-Minecraft-Pack.ps1`
- Linux server staging: `Install-Forge-Server.sh`
- Compatibility wrappers: `Install-Fabric-Server.sh`, `Install-CrazyCraft-Server.sh`

The server payload includes real shared/server mod jars plus a bundled Forge installer jar for generating local launcher files during server staging or verification.

## Resource Warning

The planning target for this pack is still a dedicated Linux host with `12-16 GB` RAM and `6` fast CPU cores. A `4 GB` VPS is below the intended envelope for this content mix and should be treated as underpowered unless the pack is reduced further.

## Deferred Legacy Surfaces

Legacy Crazy Craft-specific remote helpers and older Fabric-named wrappers still exist under `tools/` and a few top-level files. They are intentionally deprecated compatibility surfaces, not the default operating path for this pack.
