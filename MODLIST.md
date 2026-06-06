# Forge 1.20.1 ProjectE Chaos Pack

Generated inventory date: `2026-06-05`

## Pack Identity

- Project: Forge 1.20.1 ProjectE Chaos Pack
- Loader default: `Forge`
- Minecraft version: `1.20.1`
- Forge version: `47.4.0`
- Audience: private friends
- World policy: fresh
- Required identity: `ProjectE`
- Content strategy: ProjectE-centered chaotic adventure
- Disallowed pack pillars: `Create`, `Mekanism`, `Applied Energistics`, `Refined Storage`
- Host target: dedicated Linux + NVMe + `12-16 GB` RAM + `6 fast cores`

## Resolver Workflow

- Resolver: CurseForge API via curse.tools
- Why not packwiz here: The repo already has a public-source downloader pattern, while packwiz is not installed in this workspace.

## Required Baseline Mods

| Mod / Tool | Side | Status | Purpose |
|---|---|---|---|
| `spark` | shared | required | profiling and verification |
| `ModernFix` | shared | required | startup and memory pressure reduction |
| `FerriteCore` | shared | required | heap reduction |
| `Chunky` | server | required | pregeneration |

## Installed Mods

| Name | Category | Installed sides | File | Role |
|---|---|---|---|---|
| `Architectury API` | accessories | Client, Server | `architectury-9.2.14-forge.jar` | dependency |
| `Artifacts` | accessories | Client, Server | `artifacts-forge-9.5.19.jar` | Terraria-like accessories with active and gameplay-changing effects |
| `Cloth Config API (Fabric/Forge/NeoForge)` | accessories | Client, Server | `cloth-config-11.1.136-forge.jar` | dependency |
| `Curios API (Forge/NeoForge)` | bosses | Client, Server | `curios-forge-5.14.1+1.20.1.jar` | dependency |
| `GeckoLib` | bosses | Client, Server | `geckolib-forge-1.20.1-4.8.3.jar` | dependency |
| `L_Ender 's Cataclysm` | bosses | Client, Server | `L_Enders_Cataclysm-3.29.jar` | raid-scale bosses and dangerous structures |
| `Lionfish API` | bosses | Client, Server | `lionfishapi-3.0.jar` | dependency |
| `Mowzie's Mobs` | bosses | Client, Server | `mowziesmobs-1.8.2.jar` | boss encounters and hostile mobs |
| `Mutant Monsters` | bosses | Client, Server | `MutantMonsters-v8.0.8-1.20.1-Forge.jar` | boss-like mutant vanilla mobs with unique drops and combat encounters |
| `Puzzles Lib` | bosses | Client, Server | `PuzzlesLib-v8.1.33-1.20.1-Forge.jar` | dependency |
| `Embeddium` | client-performance | Client | `embeddium-0.3.31+mc1.20.1.jar` | render performance |
| `Entity Culling Fabric/Forge` | client-performance | Client | `entityculling-forge-1.10.2-mc1.20.1.jar` | visibility culling |
| `ImmediatelyFast` | client-performance | Client | `ImmediatelyFast-Forge-1.5.4+1.20.4.jar` | UI and rendering optimization |
| `AppleSkin` | client-qol | Client | `appleskin-forge-mc1.20.1-2.5.1.jar` | food value HUD |
| `Jade 🔍` | client-qol | Client | `Jade-1.20.1-Forge-11.13.2.jar` | block and entity tooltips |
| `Just Enough Items (JEI)` | client-qol | Client | `jei-1.20.1-forge-15.20.0.112.jar` | recipe browsing |
| `Xaero's Minimap` | client-qol | Client | `xaerominimap-forge-1.20.1-25.3.13.jar` | navigation |
| `Xaero's World Map` | client-qol | Client | `xaeroworldmap-forge-1.20.1-1.40.16.jar` | full map |
| `Advent of Ascension (Nevermine)` | dimensions | Client, Server | `AoA3-1.20.1-3.7.1-all.jar` | large old-school adventure expansion with bosses, dimensions, mobs, and loot |
| `Blue Skies` | dimensions | Client, Server | `blue_skies-1.20.1-1.3.31.jar` | additional dimensions and bosses |
| `Deeper and Darker` | dimensions | Client, Server | `deeperdarker-forge-1.20.1-1.3.3.jar` | deep dark adventure dimension with mobs, structures, and boss progression |
| `Structure Gel API` | dimensions | Client, Server | `structure_gel-1.20.1-2.16.2.jar` | dependency |
| `The Bumblezone (NeoForge/Forge)` | dimensions | Client, Server | `the_bumblezone-7.12.0+1.20.1-forge.jar` | hostile dimension exploration |
| `The Twilight Forest` | dimensions | Client, Server | `twilightforest-1.20.1-4.3.2508-universal.jar` | major adventure dimension |
| `The Undergarden` | dimensions | Client, Server | `The_Undergarden-1.20.1-0.8.14.jar` | underground dimension with hostile mobs, loot, and exploration progression |
| `Dungeon Crawl` | dungeons | Server | `Dungeon Crawl-1.20.1-2.3.15.jar` | additional dungeon generation |
| `Dungeon Now Loading 2%` | dungeons | Client, Server | `Dungeon Now Loading-forge-1.20.1-2.2.jar` | additional dungeon structures and exploration rewards |
| `YUNG's Better Dungeons (Forge/NeoForge)` | dungeons | Client, Server | `YungsBetterDungeons-1.20-Forge-4.0.4.jar` | more substantial dungeons |
| `YUNG's Better Strongholds (Forge/NeoForge)` | dungeons | Client, Server | `YungsBetterStrongholds-1.20-Forge-4.0.3.jar` | improved strongholds |
| `ProjectE` | exchange | Client, Server | `ProjectE-1.20.1-PE1.0.1.jar` | required progression identity |
| `Apotheosis` | loot | Client, Server | `Apotheosis-1.20.1-7.4.8.jar` | boss-style affix mobs, gem systems, stronger loot, and deeper enchantment progression |
| `Apothic Attributes` | loot | Client, Server | `ApothicAttributes-1.20.1-1.3.7.jar` | dependency |
| `Patchouli` | loot | Client, Server | `Patchouli-1.20.1-85-FORGE.jar` | dependency |
| `Placebo` | loot | Client, Server | `Placebo-1.20.1-8.6.3.jar` | dependency |
| `Alex's Caves` | mobs | Client, Server | `alexscaves-2.0.2.jar` | large exploration biomes with dangerous mobs, set-piece loot, and adventure gear |
| `Alex's Mobs` | mobs | Client, Server | `alexsmobs-1.22.9.jar` | creatures and combat variety |
| `Born in Chaos` | mobs | Client, Server | `born_in_chaos_[Forge]1.20.1_1.7.5.jar` | OreSpawn-like hostile mobs, mini-bosses, gear, and chaotic encounters |
| `Citadel` | mobs | Client, Server | `citadel-2.6.3-1.20.1.jar` | Alex's Mobs dependency pinned explicitly for server compatibility |
| `Illager Invasion` | mobs | Client, Server | `IllagerInvasion-v8.0.7-1.20.1-Forge.jar` | expanded hostile illagers and raid-style combat variety |
| `The Graveyard (FORGE/NEOFORGE)` | mobs | Client, Server | `The_Graveyard_3.1_(FORGE)_for_1.20.1.jar` | undead mobs, graveyard structures, bosses, and spooky exploration loot |
| `Chunky (Forge/NeoForge)` | performance | Server | `Chunky-1.3.146.jar` | pregeneration |
| `Clumps` | performance | Client, Server | `Clumps-forge-1.20.1-12.0.0.4.jar` | XP orb consolidation |
| `FerriteCore ((Neo)Forge)` | performance | Client, Server | `ferritecore-6.0.1-forge.jar` | memory reduction |
| `ModernFix` | performance | Client, Server | `modernfix-forge-5.27.44+mc1.20.1.jar` | startup and memory fixes |
| `spark` | performance | Client, Server | `spark-1.10.53-forge.jar` | profiling |
| `Balm` | qol | Client, Server | `balm-forge-1.20.1-7.3.38-all.jar` | dependency |
| `Corail Tombstone` | qol | Client, Server | `tombstone-1.20.1-9.0.10.jar` | death recovery |
| `Simple Voice Chat` | qol | Client, Server | `voicechat-forge-1.20.1-2.6.18.jar` | social feature |
| `Waystones` | qol | Client, Server | `waystones-forge-1.20.1-14.1.20.jar` | travel and regrouping |
| `It Takes a Pillage` | structures | Client, Server | `takesapillage-1.0.3-1.20.1.jar` | pillager camps, patrol structures, hostile encounters, and loot |
| `Repurposed Structures (Neoforge/Forge)` | structures | Client, Server | `repurposed_structures-7.1.23+1.20.1-forge.jar` | overworld and dimension structure density |
| `When Dungeons Arise - Forge!` | structures | Client, Server | `DungeonsArise-1.20.x-2.1.58-release.jar` | large exploration structures |
| `When Dungeons Arise - Seven Seas` | structures | Client, Server | `DungeonsAriseSevenSeas-1.20.x-1.0.2-forge.jar` | large ocean structures and sea adventure loot |
| `YUNG's API (Forge/NeoForge)` | structures | Client, Server | `YungsApi-1.20-Forge-4.0.6.jar` | dependency base for YUNG structure mods |
| `Iron's Lib` | weapons | Client, Server | `irons_lib-1.20.1-1.0.2.1.jar` | dependency |
| `Iron's Spells 'n Spellbooks` | weapons | Client, Server | `irons_spellbooks-1.20.1-3.16.0.jar` | active spell weapons, spell loot, progression gear, and magical combat |
| `playerAnimator` | weapons | Client, Server | `player-animation-lib-forge-1.0.2-rc1+1.20.jar` | dependency |

## Forge Server Bootstrap

- Bundled installer: `forge-1.20.1-47.4.0-installer.jar`
- Source: Forge Maven
- URL: https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.4.0/forge-1.20.1-47.4.0-installer.jar

## Notes

- Shared mods are copied into both client and server deliverables.
- Client-only mods stay out of the dedicated server staging path.
- No large automation pillars such as Create, Mekanism, Applied Energistics, or Refined Storage are seeded in this pack.
