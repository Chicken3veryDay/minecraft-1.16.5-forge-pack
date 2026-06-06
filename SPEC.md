# Spec: Crazy Craft-Style Friend Server Pack Install

## Goal

Turn the current pack scaffold into an execution-ready goal for installing a playable private friend server pack built around **Minecraft `1.20.1` + Forge**.

The pack should feel chaotic and content-dense in the spirit of Crazy Craft: hard mobs, bosses, dungeons, dimensions, loot, and ProjectE-style exchange progression. It should not become a tech automation pack.

## Product Direction

- **Minecraft version:** `1.20.1`
- **Loader:** `Forge`
- **Server type:** private friend server, not public infrastructure
- **World policy:** fresh world
- **Primary progression identity:** `ProjectE`
- **Content strategy:** chaotic adventure pack
- **Main content pressure:** mobs, bosses, dungeons, structures, dimensions, loot, difficulty
- **Avoided content:** Create, Mekanism, Applied Energistics, Refined Storage, industrial automation, factory tech stacks
- **Operational posture:** practical friends-only reliability, not production monitoring
- **Remote/live cutover:** out of scope without explicit approval

## Why This Overrides The Previous Fabric Direction

The earlier Fabric `1.20.x` direction came from the research report's performance-oriented default. The user's clarified intent is content-first:

- ProjectE or true exchange-style progression is required.
- The pack should have a Crazy Craft-like amount of chaos and large content.
- Huge mobs, bosses, dungeons, dimensions, and difficulty matter more than the strongest Fabric optimization stack.
- The server is for friends, so admin tooling and production observability should stay light.

For this specific intent, Forge `1.20.1` is the more practical default because it has stronger overlap with ProjectE and the large adventure/content ecosystem.

## In Scope

- Replace the current Fabric scaffold defaults with Forge `1.20.1` defaults.
- Create an executable `GOAL.md` for downloading and staging real compatible mods.
- Require `ProjectE` or a documented true equivalent if ProjectE cannot be installed.
- Use a public mod acquisition workflow, preferably `packwiz` if it handles the needed Forge + CurseForge/Modrinth sources cleanly.
- Populate `pack-sources` or an equivalent source tree with real client/server pack files.
- Separate client-only mods from server/shared mods where practical.
- Regenerate `.pack-manifest.json`, `MODLIST.md`, and release zips.
- Stage local client and server directories.
- Attempt local server startup if the Forge launcher/server files can be installed.
- Document incompatibilities, substitutions, deferred nice-to-haves, and remaining legacy files.

## Out Of Scope

- Live server deployment or SSH work.
- Public-server moderation and monitoring stacks.
- Production dashboards, Prometheus, JMX exporter setup, or long-term ops infrastructure.
- Preserving the old Crazy Craft world.
- Preserving Fabric as the default for this pack.
- Adding large tech automation stacks beyond ProjectE/exchange gameplay.
- Installing mods that are only compatible through unsafe or private redistribution paths.

## Candidate Mod Families

The implementation goal should prefer public, mature Forge `1.20.1` releases from CurseForge, Modrinth, GitHub releases, or other official project download pages.

Required identity:

- `ProjectE`

Major mobs, bosses, and creatures:

- `Mowzie's Mobs`
- `Alex's Mobs`
- `L_Ender's Cataclysm`
- comparable Forge `1.20.1` boss or creature mods if a candidate cannot resolve

Dungeons and structures:

- `When Dungeons Arise`
- YUNG's structure mods
- `Repurposed Structures`
- `Integrated Dungeons and Structures`
- `Dungeon Crawl` or compatible alternatives

Dimensions and worldgen:

- `The Twilight Forest`
- `Blue Skies`
- `The Bumblezone`
- `Terralith`
- `Incendium`
- `Nullscape`
- compatible alternatives when a target mod does not resolve

Difficulty and reward pressure:

- scaling difficulty, elite mobs, harder nights, improved AI, loot/reward mods, and combat modifiers that increase adventure chaos without adding industrial automation

Friend-server QoL:

- `JEI`
- `Jade`
- `AppleSkin`
- `Waystones`
- gravestone/death recovery
- minimap/map
- `Simple Voice Chat` if compatible

Lightweight performance:

- `spark`
- `ModernFix`
- `FerriteCore`
- `ServerCore` if compatible
- `Chunky`
- `Clumps`
- client-side options such as `Embeddium`, `Oculus`, `Entity Culling`, and `ImmediatelyFast` when compatible

## Risks

- Some desired huge content mods may not all overlap cleanly on Forge `1.20.1`.
- Some mods may be CurseForge-only and may require a workflow that respects download restrictions.
- Client-only mods can crash a dedicated server if staged incorrectly.
- The repo currently has Fabric-named scripts and docs from the previous scaffold; the execution goal must migrate or rename primary surfaces carefully.
- The pack may become heavy enough that local startup is slower or requires more memory than the current machine defaults.

## Scorecard

- Primary metric: a reproducible Forge `1.20.1` mod acquisition, staging, manifest, and release build pipeline for a playable Crazy Craft-style friend pack.
- Passing threshold:
  - `GOAL.md` is executable without reopening loader/version/product-intent decisions
  - `done_when` includes concrete file artifacts, commands, and startup/staging checks
  - the pack direction explicitly requires ProjectE and multiple large mobs/dungeons/dimensions
  - the pack direction explicitly forbids large tech automation stacks beyond ProjectE
- Regression checks:
  - no default drift back to Fabric for this pack
  - no default drift back to legacy Crazy Craft `1.16.5`
  - no accidental inclusion of Create/Mekanism/AE2/Refined Storage as content pillars
  - no live server work without approval
- Scoring path: inspect `SPEC.md`, `GOAL.md`, `CONTROL.md`, current docs/scripts, and the generated pack/source artifacts.
- Stop condition: the goal contract is detailed enough that a future `/goal` run can install the real pack and verify staging/build/startup without asking product-direction questions.

## Feedback Loop

- Fast check:
  - read `SPEC.md`, `GOAL.md`, and `CONTROL.md`
  - expected runtime: under 10 seconds
  - cadence: after every goal/spec/control edit
  - proxy validity: enough for goal-forging because these files define the execution contract
- Slower check:
  - scan for stale Fabric defaults and forbidden tech content assumptions
  - inspect whether `done_when`, scorecard, workflow, and verification are command/file-artifact based

## Verification

- Confirm `SPEC.md` explicitly chooses:
  - `Minecraft 1.20.1`
  - `Forge`
  - private friend server
  - fresh world
  - ProjectE required
  - chaotic mobs/dungeons/bosses/dimensions focus
  - no tech automation stacks beyond ProjectE
- Confirm `GOAL.md` includes:
  - scorecard
  - measurable `done_when`
  - fast and final verification loops
  - working memory files
  - human control surface
  - explicit no-live-server constraint
- Confirm `CONTROL.md` reflects the new pack identity and approval gates.

## Done When

- `SPEC.md` defines a Forge `1.20.1` Crazy Craft-style private friend server pack install goal.
- `GOAL.md` exists as an executable `/goal` contract for installing the real mods, staging client/server files, building release artifacts, and attempting local startup.
- `CONTROL.md` reflects Forge `1.20.1`, ProjectE-required, adventure-chaos content, no large automation stacks, and no live remote actions without approval.
- `PLAN.md`, `ATTEMPTS.md`, and `NOTES.md` record the shift from Fabric performance-pack scaffold to Forge content-first friend server goal.
- The goal contract does not require another product-direction interview before execution.
