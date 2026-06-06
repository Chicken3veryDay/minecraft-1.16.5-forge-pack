# Notes

## 2026-06-04

- The repo still contains large legacy asset trees under top-level `Client/`, `Config/`, `Root/`, `Server/`, and `Shaderpacks`; the new build flow ignores them and uses `pack-sources` instead.
- README had local modifications before this conversion run; it was replaced because the repo identity change required a full rewrite.
- Crazy Craft-specific remote scripts remain under `tools/` and are intentionally treated as deferred leftovers rather than active defaults.
- The old `-Xmx2816M` VPS posture was removed from primary docs and installers and replaced with a dedicated-host baseline.

## 2026-06-05

- User clarified the desired pack is for friends and should be content-first: ProjectE/exchange progression, hard chaotic adventure, huge mobs, dungeons, creatures, dimensions, and minimal admin overhead.
- `packwiz` is not installed in this workspace, so the implemented acquisition path reuses the repo's public CurseForge downloader pattern rather than inventing a private jar-sync workflow.
- CurseForge file metadata sometimes omits `Forge` entirely or lists both `Forge` and `NeoForge` on the same valid file. The resolver now treats those cases as Forge-compatible when the file still advertises the requested Minecraft version.
- The resolved Forge installer is `forge-1.20.1-47.2.32-installer.jar` from Forge Maven.
- The resolved Forge performance baseline settled on `spark`, `ModernFix`, `FerriteCore`, `Chunky`, and `Clumps`. `ImmediatelyFast` resolved to a jar named for `1.20.4` but was selected from a file tagged `1.20.1`; keep that in mind if startup or client launch verification flags it later.
- The currently shown Ubuntu `24.04` VPS has only `4 GB` RAM and `2 GB` swap. That is below the intended `12-16 GB` planning envelope for this pack and should be treated as underpowered for normal use.
- `Alex's Mobs` required `Citadel 2.6.0+` during real server boot. Even though CurseForge dependency data was inconsistent across resolution passes, explicitly seeding `Citadel` resolved the missing-dependency startup failure.
- The local workstation's default `java` is Java `8`, and the Minecraft Launcher-managed modern runtime is Java `25`. Forge `1.20.1` with this mod stack booted successfully only after a temporary Microsoft OpenJDK `17` runtime was downloaded into `_InstallCache`.
