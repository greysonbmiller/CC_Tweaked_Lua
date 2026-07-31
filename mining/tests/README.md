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
luajit mining/tests/ore_harness.lua     mining/geo_scanner_ore_mining_bot.lua
luajit mining/tests/chat_harness.lua    mining/geo_scanner_ore_mining_bot.lua
```

The target file is `arg[1]`; it defaults to the geo scanner miner. Exit status
is non-zero if anything fails. `ccmock.lua` is the shared mock world — there is
deliberately only one, because two mocks drifting apart is how the old guard
harness quietly stopped testing anything.

Note that `ore_harness` and `chat_harness` apply to the geo scanner miner only;
remote ore selection was not added to the allthemodium twin.

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

## What ore_harness proves

The catalogue records the ore-like ids the scanner really returned, skips
everything else, is append-only (an entry's position is the handle used to pick
it, so it must never move), and is rewritten only when it actually grows.
Targeting works on a set, so several ores can be mined at once, and the
selection survives a reboot.

The mock counts net vertical movement, which only `seek()` produces — the
hopper pass is one `down` and one `up` and nets to zero. That proves the bot
actually *travelled* to an ore rather than merely logging it, with a control
asserting it stays put for an ore that is not selected. Without that control
the match test would pass even if the bot chased everything it saw.

## What chat_harness proves

Commands are obeyed only from the owner, numbers resolve against the catalogue,
literal ids are accepted but flagged as never-scanned, and nonsense changes
nothing and says so. The window ends on its own and gives the plate back —
asserted as "warped more than once", since the bot cannot place a plate it never
picked up, rather than "no plate on the ground at the end", which a
budget-truncated run can fail legitimately.

Scenario 10 is the one worth keeping: a `sendMessageToPlayer` that throws
because the recipient is offline must not end the run. Before the fix it did,
mid-warp, with the plate already on the ground.

## Note on the mocks

Two mock behaviours are load-bearing and easy to get wrong, because both hide
real bugs when modelled lazily:

- `turtle.dig()` fills the **selected** slot first, then spills over.
- `turtle.suck()` always draws the container's **lowest-numbered** occupied
  slot; it cannot target a slot.

An earlier version of the mock got both wrong and produced four failures that
looked like production bugs but were not.
