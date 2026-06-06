# Fabric 1.20.x Performance Baseline

This document captures the default operating posture for the new small-heavy curated pack.

## Baseline Assumptions

- `5-10` active players
- dedicated Linux host
- NVMe storage
- `12-16 GB` host RAM
- `6` fast CPU cores
- fresh world
- `Fabric` default loader
- `NeoForge` fallback only if content requirements force it

## Required Optimization Stack

- `spark` for profiling
- `ModernFix` for startup and memory pressure
- `FerriteCore` for heap reduction
- `Lithium` for steady-state tick improvements
- `Noisium` for worldgen acceleration
- `C2ME` for Fabric multicore chunk work
- `ServerCore` for Paper-like operational controls
- `Chunky` for pregeneration
- `Clumps` for XP-orb consolidation

## Operational Policy

- Pregeneration is mandatory before normal exploration.
- Chunk loaders must be governed explicitly.
- Always-loaded automation should be treated as a quota-managed resource.
- Profiling with `spark` is required during multiplayer shakedown and after major content additions.
- If Fabric compatibility falls apart because of required content, pivot to `NeoForge`, not legacy Forge.
