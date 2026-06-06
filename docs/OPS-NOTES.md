# Operations Notes

These notes define the runtime posture for the Forge `1.20.1` private friend-server pack. They no longer describe the Fabric scaffold as the production baseline.

## Target Runtime

- Minecraft target: `1.20.1`
- Loader default: `Forge`
- World policy: fresh world
- Audience: private friends
- Planning envelope: `12-16 GB` host RAM, `6` fast CPU cores, Linux + NVMe
- Starting dedicated-server JVM target: `-Xms4G -Xmx8G`

The currently shown Ubuntu `24.04` VPS with `4 GB` RAM is below the intended envelope for this content mix. It may be usable only for a reduced pack or as a temporary validation surface.

## Required Baseline Mods And Tools

- `ProjectE`
- `spark`
- `ModernFix`
- `FerriteCore`
- `Chunky`
- `Clumps`

Client-side optional performance surfaces include `Embeddium`, `Entity Culling`, and `ImmediatelyFast`. They are not copied into the dedicated server payload.

## Deployment Model

1. Resolve public mod jars with `tools/Resolve-ForgePack.ps1`.
2. Build release artifacts from `pack-sources/`.
3. Stage the client with `Install-Minecraft-Pack.ps1`.
4. Stage the server with `Install-Forge-Server.sh` or `Install-Minecraft-Pack.ps1 -Server`.
5. Run the bundled Forge installer in the staged server directory before first boot if the launcher files do not already exist.
6. Pregenerate likely early-game dimensions before normal play.
7. Use `spark` during local or remote validation to capture startup and join behavior.

## Governance Rules

- Keep chunk loaders, villager-heavy bases, and permanently active mob farms under explicit friend-group rules.
- Treat aggressive exploration and boss farming as operational load, not just gameplay flavor.
- Prefer pregeneration and simulation-distance discipline before trying to solve everything with more RAM.

## Fresh-World Policy

This project does not assume migration of the old Crazy Craft world. Any live cutover or remote/server-touching work still requires explicit approval first, as captured in [CONTROL.md](C:\Users\micha\Desktop\Mods\CONTROL.md).

## Deferred Legacy Surfaces

The repo still contains Crazy Craft-specific remote scripts and Fabric-named wrappers. They are intentionally deprecated leftovers, not the default path for this pack.
