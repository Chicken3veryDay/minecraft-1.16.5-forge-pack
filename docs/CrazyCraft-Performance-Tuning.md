# Crazy Craft Updated Server Performance Tuning

This document completes the performance-planning draft for the actual pack in this repo:

- Pack: Crazy Craft Updated `0.12.9`
- Minecraft: `1.16.5`
- Loader: Forge `36.2.35`
- Current server launch in this repo: `-Xms1G -Xmx2816M`
- Current deployment notes: [OPS-NOTES.md](C:\Users\micha\Desktop\Mods\docs\OPS-NOTES.md)

## Executive Summary

For this specific pack, the generic answer is no longer enough: Crazy Craft Updated `0.12.9` is a 331-mod Forge 1.16.5 pack with multiple heavy dimensions, strong worldgen pressure, AI-heavy mobs, chunk-loading tools, and late-game factory mods such as Mekanism, Create, Flux Networks, AE2, Draconic Evolution, Easy Villagers, FTB Chunks, Twilight Forest, Blue Skies, Alex's Mobs, and Ice and Fire.

The current VPS profile in this repo is materially undersized for normal multiplayer use. A host capped around `4 GB` total RAM and `-Xmx2816M` is a short-term survival configuration, not a healthy production target for this pack. It can be workable only with very low concurrency, very low simulation pressure, strict forced-chunk discipline, and reduced exploration.

For a server that is meant to stay responsive under real play, the practical bottleneck order is:

1. Main-thread CPU time
2. Forced-chunk and automation load
3. New chunk generation and dimension exploration
4. Heap pressure and GC churn

Extra RAM helps, but it does not solve a bad tick budget. The winning pattern for this pack is high single-thread CPU performance, enough total RAM to keep the heap out of constant pressure, pregenerated terrain, and strict operational controls around always-loaded activity.

## What Makes This Pack Expensive

This pack is not "331 mods of equal weight." It contains several categories that stress different parts of the server:

- Worldgen and dimension load: `twilightforest`, `blue_skies`, `iceandfire`, `alexsmobs`, multiple structure mods, biome mods, dungeon mods
- Automation and always-loaded bases: `Mekanism`, `Create`, `FluxNetworks`, `appliedenergistics2`, `Draconic Evolution`, `BotanyPots`, `cagedmobs`
- Entity and AI pressure: `alexsmobs`, `iceandfire`, `guardvillagers`, `easy_villagers`, mob-heavy exploration content
- Forced chunk risk: `ftb-chunks`

That mix means this pack suffers from both burst load and steady-state load:

- Burst load: first-time exploration, new dimension entry, structure discovery
- Steady-state load: chunk-loaded factories, farms, villager systems, mob-heavy bases

## Current State

The repo currently documents these relevant runtime choices:

- JVM: `-Xms1G -Xmx2816M -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC`
- Existing server.properties tuning script: [remote_apply_perf_optimizations.sh](C:\Users\micha\Desktop\Mods\tools\remote_apply_perf_optimizations.sh)
- Existing pack optimizers already included: `ModernFix`, `FerriteCore`, `AI Improvements`, `Clumps`, `Connectivity`, `MemoryLeakFix`, `PacketFixer`, `Performant`, `FastWorkbench`, `FastFurnace`, `FastAsyncWorldSave`

That optimization baseline is helpful, but it does not change the central conclusion: the pack is heavier than the current host budget.

## Capacity Guidance For This Exact Pack

These are planning bands for Crazy Craft Updated `0.12.9`, not generic modded-Minecraft numbers.

| Scenario | Active players | CPU target | Heap target | Host RAM target | Notes |
|---|---:|---|---|---|---|
| Emergency / temporary | 1-2 | 2-4 fast vCPU | `3-4 GB` | `4-6 GB` | Only viable with tight view/sim distance and limited exploration |
| Small practical | 3-6 | 4-6 fast vCPU | `6-8 GB` | `10-14 GB` | Minimum reasonable production tier |
| Comfortable small group | 6-10 | 6 fast cores | `8-10 GB` | `12-16 GB` | Good target if players build tech bases and explore regularly |
| Medium active server | 10-15 | 6-8 fast cores | `10-14 GB` | `16-24 GB` | Needs pregeneration and strict chunk-loader governance |
| Large active server | 15-25 | 8-10 fast cores | `14-20 GB` | `24-32 GB` | Requires serious operational discipline |

Two practical conclusions follow from that table:

- The official server pack's `-Xmx8192M` default is closer to reality than the current `-Xmx2816M` VPS override.
- For this pack, upgrading CPU quality is usually more valuable than blindly pushing heap size upward.

## Recommended Operating Targets

If the goal is "feels stable under load" rather than "barely boots," use these targets:

- Typical MSPT target under representative play: `< 40-45 ms`
- Warning band: `45-50 ms`
- Unhealthy sustained state: `> 50 ms`
- Hard ceiling for `17.5 TPS`: about `57.1 ms`

The important point is that a server can average below the ceiling while still feeling bad due to spikes. Exploration spikes, autosaves, chunk loads, and factory bursts are what usually break playability first.

## Pack-Specific Bottlenecks To Control First

For Crazy Craft Updated, fix these in priority order before you start deleting random mods:

1. New chunk generation in the Overworld and major custom dimensions
2. FTB Chunks forced chunks and permanently loaded bases
3. Mekanism factories, Create contraptions, Flux Networks hubs, and AE2-heavy storage bases
4. Villager clusters from `easy_villagers` and `guardvillagers`
5. AI-heavy mob regions from `alexsmobs` and `iceandfire`
6. Farm hotspots, XP-orb piles, and mob-breeder concentrations

This pack can tolerate a lot of content. It does not tolerate ungoverned always-loaded activity.

## Recommended Server Properties

For this specific pack on a constrained or midrange host, these are sound starting values:

```properties
view-distance=4
simulation-distance=4
entity-broadcast-range-percentage=50
sync-chunk-writes=false
network-compression-threshold=512
max-tick-time=180000
enable-jmx-monitoring=true
use-native-transport=true
```

Notes:

- `view-distance=4` and `simulation-distance=4` are justified on the current VPS tier.
- On a stronger host, raise `view-distance` first only if the CPU headroom is real.
- `simulation-distance` is the more important CPU knob.
- `entity-broadcast-range-percentage=50` is aggressive but appropriate for dense modded bases.

The existing helper script already applies most of these settings: [remote_apply_perf_optimizations.sh](C:\Users\micha\Desktop\Mods\tools\remote_apply_perf_optimizations.sh).

## JVM Guidance

G1GC is the right default collector for this pack unless profiling proves GC is the main problem.

Recommended starting patterns:

- Keep `-Xms` and `-Xmx` equal on stable hosts
- Leave memory outside the heap for OS and native overhead
- Prefer a simple, conservative G1 baseline over large flag cargo-culting

Example small-production baseline:

```bash
java -Xms8G -Xmx8G \
  -XX:+UseG1GC \
  -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=150 \
  -XX:+DisableExplicitGC \
  -Xlog:gc*:logs/gc.log:time,uptime:filecount=5,filesize=10M \
  -jar forge.jar nogui
```

For the current VPS, do not expect flags to compensate for inadequate RAM and CPU. The limiting factor there is host size, not missing JVM cleverness.

## Optimization Stack For Forge 1.16.5

The generic draft mentioned some newer-loader optimization mods that are not the right answer for this pack branch. For this actual repo:

- Keep and validate the optimizers already in the pack
- Add `spark` for profiling if it is not already installed server-side
- Do not assume Fabric-only tools such as `Lithium` or `C2ME` apply here
- Do not assume modern NeoForge-only guidance applies to Forge `1.16.5`

The current pack already includes most of the low-risk "keep the server alive" optimizers you would normally want on old Forge:

- `ModernFix`
- `FerriteCore`
- `AI Improvements`
- `Clumps`
- `Connectivity`
- `MemoryLeakFix`
- `PacketFixer`
- `Performant`
- `FastWorkbench`
- `FastFurnace`
- `FastAsyncWorldSave`

That means future gains will come more from profiling, world prep, and governance than from piling on more optimization mods.

## Pregeneration Strategy

If the server is meant to support exploration, pregeneration is mandatory.

Minimum recommended sequence:

1. Pregenerate the Overworld spawn region and the first major play radius
2. Pregenerate early-use custom dimensions before public launch
3. Benchmark join, teleport, and travel behavior after pregeneration

For this pack, the priority dimensions are:

- Overworld
- Twilight Forest
- Blue Skies
- Any other dimension players are expected to enter early

Without pregeneration, exploration will remain the easiest way to tank TPS.

## Profiling Workflow

Install `spark` on the server if absent, then use a repeatable profiling pass:

1. Idle baseline after boot and warmup
2. One-player exploration run
3. Two-to-four-player split exploration run
4. Base soak in the heaviest Mekanism/Create/AE2 area
5. Villager and farm hotspot test
6. Mixed-load session with real chunk loaders enabled

Useful command set:

```bash
/spark tps
/spark health --upload --memory --network
/spark profiler start --timeout 600
/spark profiler start --alloc --timeout 300
/spark tickmonitor --threshold-tick 75
/spark gc
/spark heapsummary
```

The output you care about most:

- MSPT under mixed load
- Outlier tick spikes
- Time spent on the server thread
- Allocation hotspots
- Whether chunk generation, block entities, entities, or one specific mod dominates samples

## Operational Policy That Will Matter More Than Hardware Alone

For this pack, these policies have high leverage:

- Cap or review all forced-chunk usage from `ftb-chunks`
- Forbid permanently running industrial bases unless justified
- Reduce villager density
- Keep mob farms bounded and test them under load
- Do not leave multiple dimensions active "just because"
- Treat player exploration on ungenerated terrain as a scheduled load event on weak hosts

If the server is still struggling after that, remove behavior first and content second. Cutting one bad always-loaded factory can be worth more than removing ten decorative mods.

## Practical Recommendation For The Current Repo

If the server stays on the current VPS class, the realistic target is:

- 1-3 active players
- Low view and simulation distance
- Strict forced-chunk control
- Minimal simultaneous new exploration
- Profiling before every major configuration change

If the goal is a normal small multiplayer server for this pack, the upgrade path should be:

1. Move to at least `12-16 GB` host RAM
2. Use `6` fast CPU cores or equivalent high-performance vCPU
3. Run `-Xms8G -Xmx8G` as the starting production heap
4. Pregenerate major terrain before public use
5. Enforce chunk-loader and villager/farm policy

That is the first tier where this pack starts to behave like a real service instead of a rescue scenario.

## Sources

Official references used to ground this version-specific writeup:

- Crazy Craft Updated CurseForge project: <https://www.curseforge.com/minecraft/modpacks/crazy-craft-updated>
- Paper server.properties reference: <https://docs.papermc.io/paper/reference/server-properties/>
- spark documentation: <https://spark.lucko.me/docs>
- Paper JVM guidance / Aikar flags reference: <https://docs.papermc.io/paper/aikars-flags/>
- Oracle G1 GC tuning documentation: <https://docs.oracle.com/en/java/javase/21/gctuning/garbage-first-garbage-collector-tuning.html>

Repo-local evidence for this pack and runtime:

- [README.md](C:\Users\micha\Desktop\Mods\README.md)
- [MODLIST.md](C:\Users\micha\Desktop\Mods\MODLIST.md)
- [OPS-NOTES.md](C:\Users\micha\Desktop\Mods\docs\OPS-NOTES.md)
- [remote_apply_perf_optimizations.sh](C:\Users\micha\Desktop\Mods\tools\remote_apply_perf_optimizations.sh)
- [remote_fix_crazycraft_heap.sh](C:\Users\micha\Desktop\Mods\tools\remote_fix_crazycraft_heap.sh)
