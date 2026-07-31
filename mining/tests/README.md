# Miner test harnesses

These load the **real** miner files under a mock CC:Tweaked environment
(`setfenv`, Lua 5.1) and run them. They deliberately do not re-implement any of
the logic they check — a test that rebuilds the thing it is verifying passes
even when the real code drifts.

Run from the repository root, with LuaJIT (Lua 5.1 — CC:Tweaked is Cobalt 5.1,
so 5.4 would accept syntax the turtle rejects):

```sh
luajit mining/tests/restart_harness.lua mining/geo_scanner_ore_mining_bot.lua
luajit mining/tests/restart_harness.lua mining/allthemodium_ore_scanner_miner.lua
```

The target file is `arg[1]`; it defaults to the geo scanner miner. Exit status
is non-zero if anything fails.

## What restart_harness proves

Fourteen scenarios, 44 assertions per file, covering the two properties the
redesign is built on:

1. **Nothing is ever dropped into the world.** The mock increments `worldDrops`
   every time a drop lands somewhere that is not a confirmed inventory. That
   counter measures the bug directly rather than trusting that the code reads
   correctly. It must be zero in every scenario — including all faces blocked,
   which is the case where the naive fix is to drop anyway.
2. **A field restart never re-stages or cleans.** The pre-redesign code opened
   by dropping all sixteen slots on the assumption it was parked at base; run
   after a crash in a cave, that threw the entire kit down a hole.

Scenarios include: first run at base, restart mid-cycle, corrupt state file,
scratch-file-only recovery (`state.tmp` present, `state.txt` missing), state
file deleted while deployed, every container face blocked, an empty supply
chest, and a supply chest missing the refuel ender chest.

## Note on the mocks

Two mock behaviours are load-bearing and easy to get wrong, because both hide
real bugs when modelled lazily:

- `turtle.dig()` fills the **selected** slot first, then spills over.
- `turtle.suck()` always draws the container's **lowest-numbered** occupied
  slot; it cannot target a slot.

An earlier version of the mock got both wrong and produced four failures that
looked like production bugs but were not.
