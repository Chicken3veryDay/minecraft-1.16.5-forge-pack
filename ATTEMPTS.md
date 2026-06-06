# Attempts

## 2026-06-04

- Attempted to preserve the old install/build scripts in place. Rejected because they were deeply tied to Forge `1.16.5`, CurseForge imports, and Crazy Craft naming.
- Pivoted to a smaller generic scaffold that keeps client/server deliverables, manifest generation, and release packaging while removing old platform assumptions from the primary entrypoints.
- Left Crazy Craft-specific remote automation deferred instead of performing unsafe live-deployment rewrites without an approved host plan.

## 2026-06-05

- Goal-forged a replacement execution contract for the user's clarified pack intent: private friend server, Forge `1.20.1`, ProjectE required, chaotic mobs/bosses/dungeons/dimensions focus, no large tech automation stack beyond ProjectE.
- Chose Forge `1.20.1` for execution because the user accepted pivoting away from Fabric and prioritized ProjectE plus large adventure content over the previous performance-first scaffold.
- Replaced the placeholder Fabric blueprint with a Forge-first resolver/build/install pipeline using `tools/Resolve-ForgePack.ps1`, `tools/Build-ForgePackAssets.ps1`, and `Install-Forge-Server.sh`.
- First resolver pass downloaded the real mod jars but failed to persist metadata because the blueprint writer attempted to set missing JSON properties directly; fixed by adding explicit property creation before serialization.
- Second resolver pass still dropped valid Forge files from `ProjectE` and `Blue Skies` because CurseForge tagged some files with both `NeoForge` and `Forge`; fixed the loader-tag logic to accept Forge-tagged files even when NeoForge is also present.
- Final resolver pass succeeded and staged real Forge `1.20.1` client/server payloads including `ProjectE`, `Blue Skies`, `The Twilight Forest`, `The Bumblezone`, `Alex's Mobs`, `Mowzie's Mobs`, `L_Ender's Cataclysm`, YUNG structure mods, Waystones, Tombstone, JEI, Jade, Xaero's maps, ModernFix, FerriteCore, Chunky, Clumps, and spark.
- First local server boot attempt with the launcher-managed OpenJDK `25` runtime failed after mod loading because the staged server snapshot did not yet include the newer explicit `Citadel` seed and because the Java `25` runtime is outside the expected compatibility band for this Forge/Mixin stack.
- Added `Citadel` explicitly to the seed list, regenerated the manifest, downloaded a temporary Microsoft OpenJDK `17` runtime into `_InstallCache`, and reran the startup attempt.
- Local Forge server startup reached `Done (15.835s)!` under Microsoft OpenJDK `17`; the process then continued normally until manually stopped for verification purposes.
