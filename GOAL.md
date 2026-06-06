<goal>
Install a playable private friend server modpack into this repository by replacing the current Fabric scaffold direction with a Minecraft `1.20.1` + `Forge` Crazy Craft-style pack centered on `ProjectE`, hard mobs, bosses, dungeons, dimensions, loot, and chaotic adventure content. The run must download or otherwise acquire real compatible public mods, stage client and server deliverables, regenerate manifests and release artifacts, and verify local staging/startup as far as the workstation allows.
</goal>

<context>
Read these files first:
- `SPEC.md`
- `CONTROL.md`
- `PLAN.md`
- `ATTEMPTS.md`
- `NOTES.md`
- `README.md`
- `README-INSTALL.txt`
- `MODLIST.md`
- `docs/OPS-NOTES.md`
- `Build-PackRelease.ps1`
- `Install-Minecraft-Pack.ps1`
- `Install-Forge-Server.sh`
- `Install-Fabric-Server.sh`
- `Install-CrazyCraft-Server.sh`
- `tools/Resolve-ForgePack.ps1`
- `tools/Build-ForgePackAssets.ps1`
- `tools/Build-FabricPackAssets.ps1`
- `tools/Update-ModList.ps1`
- `pack-sources/pack-blueprint.json`
- `C:\Users\micha\Downloads\deep-research-report.md`

Use these discovery commands as needed:
- `rtk rg --files`
- `rtk rg -n "Fabric|Forge|NeoForge|ProjectE|packwiz|1\\.20\\.1|Create|Mekanism|Applied Energistics|Refined Storage|Crazy Craft|Install-Fabric|Build-Fabric" .`
- `rtk rg -n "Resolve-ForgePack|Build-ForgePackAssets|Install-Forge-Server|pack-sources|\\.pack-manifest|assetArchive|client|server|shaderpacks" .`
- `rtk powershell -NoProfile -Command "[void][scriptblock]::Create((Get-Content -LiteralPath '.\Build-PackRelease.ps1' -Raw)); [void][scriptblock]::Create((Get-Content -LiteralPath '.\Install-Minecraft-Pack.ps1' -Raw)); [void][scriptblock]::Create((Get-Content -LiteralPath '.\tools\Resolve-ForgePack.ps1' -Raw))"`
</context>

<constraints>
- Default target is Minecraft `1.20.1` on `Forge`.
- This is a private friend server, not public infrastructure.
- The pack must be fresh-world oriented; do not design around migrating the old Crazy Craft world.
- Preserve support for both client and server deliverables.
- `ProjectE` is the required progression identity. If ProjectE cannot be installed, document the exact blocker and choose a true exchange-style equivalent only if it is compatible and public.
- Content must emphasize mobs, bosses, dungeons, dimensions, structures, loot, and difficulty.
- Do not add large tech automation stacks beyond ProjectE/exchange gameplay. Specifically avoid making `Create`, `Mekanism`, `Applied Energistics`, or `Refined Storage` pack pillars.
- Keep operations light: include practical friend-server performance and startup reliability, but do not build production dashboards, Prometheus, JMX exporter setup, public moderation infrastructure, or heavy admin systems.
- Prefer commonly used public mods and tooling before custom download systems.
- Prefer `packwiz` for mod locking/acquisition if it can handle the needed Forge + CurseForge/Modrinth sources cleanly. If packwiz is not viable for this workspace, document the reason and use the repo's existing public-source-compatible downloader pattern instead.
- Respect mod redistribution/download restrictions. Do not smuggle private or prohibited jars into the repo.
- No live remote server deployment, SSH, RCON, or production cutover without explicit approval.
- Preserve unrelated user changes in the dirty worktree.
</constraints>

<scorecard>
Primary checklist:
- Repo defaults and primary docs/scripts point to a Forge `1.20.1` Crazy Craft-style friend server pack.
- Real compatible mods are resolved and staged, not placeholder README files.
- `ProjectE` is present or a documented true equivalent is present with the ProjectE blocker recorded.
- The installed mod list includes multiple major mobs/bosses/dungeons/dimensions/structure mods.
- The installed mod list does not include large tech automation stacks beyond ProjectE/exchange gameplay.
- Client-only and server/shared mods are separated enough to avoid dedicated server wrong-side startup crashes.
- Manifest, release build, client staging, and server staging all run successfully.
- Local server startup is attempted when launcher/server files are available; failures are exact and documented.

Passing threshold:
- Every `done_when` item passes, or an item that cannot pass due to external mod-source restrictions has a concrete blocker in `ATTEMPTS.md` and a practical fallback documented in `NOTES.md`.

Regression checks:
- No default drift back to Fabric for this pack.
- No default drift back to Crazy Craft Updated Forge `1.16.5`.
- No accidental inclusion of `Create`, `Mekanism`, `Applied Energistics`, or `Refined Storage` as content pillars.
- No live server or remote action performed without explicit approval.
- No silent wrong-side client mod copied into the server deliverable when it is known client-only.

Scoring path:
- Inspect `SPEC.md`, `CONTROL.md`, `README.md`, `README-INSTALL.txt`, `MODLIST.md`, `docs/OPS-NOTES.md`, `pack-sources`, `.pack-manifest.json`, release artifacts, and install/build command outputs.

Stop condition:
- A new contributor would understand this repo as a Forge `1.20.1` private friend server pack with ProjectE, heavy adventure chaos, real staged mods, buildable release artifacts, and documented verification status.
</scorecard>

<done_when>
- `README.md`, `README-INSTALL.txt`, `docs/OPS-NOTES.md`, `MODLIST.md`, `SPEC.md`, `GOAL.md`, and `CONTROL.md` consistently describe the default pack as Minecraft `1.20.1` + `Forge` for a private Crazy Craft-style friend server.
- The primary build/install entrypoints are renamed, rewritten, or clearly redirected so the default path is not Fabric-specific.
- `pack-sources` or the chosen equivalent source tree contains real resolved mod files and no longer consists only of placeholder README files.
- `ProjectE` is installed in the pack, or `ATTEMPTS.md` records the exact ProjectE blocker and the selected true exchange-style equivalent.
- The installed mod list includes multiple major compatible mods for mobs/bosses/dungeons/dimensions/structures from the candidate families in `SPEC.md`.
- The installed mod list excludes `Create`, `Mekanism`, `Applied Energistics`, and `Refined Storage` unless one appears only as a non-content dependency with a documented reason.
- `MODLIST.md` is regenerated from the installed pack and lists actual installed mods with side/client/server notes where practical.
- `.pack-manifest.json` is regenerated from the staged files.
- `Build-PackRelease.ps1` succeeds.
- `Install-Minecraft-Pack.ps1` succeeds for a temp client stage.
- `Install-Minecraft-Pack.ps1 -Server` succeeds for a temp server stage.
- A local Forge server startup is attempted if Forge server launcher files can be installed; any startup failure is documented with exact missing dependency, wrong-side mod, memory issue, or launcher issue.
- Remaining Crazy Craft/Fabric legacy files are migrated, deprecated, or listed as intentionally deferred in `NOTES.md`.
</done_when>
