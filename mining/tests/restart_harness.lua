-- Asserts the two properties the restart-safety redesign claims: nothing is
-- ever dropped into the world, and a field restart never re-stages or cleans.
--
-- The mock (ccmock.lua) counts worldDrops every time a drop lands somewhere
-- that is not a confirmed inventory. That counter is the whole point: it
-- measures the bug directly rather than trusting that the code looks right.
--
--   luajit mining/tests/restart_harness.lua [path/to/miner.lua]

local TARGET = arg[1] or "mining/geo_scanner_ore_mining_bot.lua"

local here = (arg[0] or ""):match("^(.*[/\\])") or ""
local mock = dofile(here .. "ccmock.lua")

local ENDER, PLATE, PICKAXE = mock.ENDER, mock.PLATE, mock.PICKAXE
local HASH_DEPO = mock.HASH_DEPO
local fullKit = mock.fullKit
local function run(opts) return mock.run(TARGET, opts) end

local pass, fail = 0, 0
local function assertThat(label, cond, detailMsg)
    if cond then pass = pass + 1; print(string.format("  %-52s PASS", label))
    else fail = fail + 1; print(string.format("  %-52s FAIL", label))
         if detailMsg then print("        " .. detailMsg) end end
end

print("target: " .. TARGET)
print(string.rep("=", 64))

-- 1. Happy path from base: stages, deploys, and never throws anything away.
print("\n[1] first run at base, healthy")
local supply = {}
for _, it in pairs(fullKit()) do supply[#supply + 1] = it end
supply[#supply + 1] = { name = PICKAXE, count = 1 }
local r = run{ preInv = {}, frontChest = supply, budget = 3000 }
assertThat("staged from the supply chest", r.staged)
assertThat("state.txt was written", r.files["state.txt"] ~= nil)
assertThat("deployed flag recorded",
           (r.files["state.txt"] or ""):find("deployed") and
           (r.files["state.txt"] or ""):find("true") ~= nil)
assertThat("startup.lua installed", r.files["startup.lua"] ~= nil)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 2. Field restart: deployed, no supply chest anywhere near.
print("\n[2] field restart in a cave, no chest in front")
local st = '{["deployed"]=true,["phase"]="mining",["cycles"]=2,["placed"]={},}'
r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = st },
         frontChest = nil, budget = 3000 }
assertThat("did NOT try to stage", not r.staged)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)
-- The run is cut at an arbitrary point, so a chest may legitimately be on the
-- ground mid-cycle. The invariant that actually matters is that none is LOST:
-- all three must be somewhere we can still get at.
local function enderCount(rep)
    local n = 0
    for i = 1, 16 do
        if rep.inv[i] and rep.inv[i].name == ENDER then n = n + 1 end
    end
    for _, face in ipairs({ "front", "up", "down" }) do
        if rep.world[face] == ENDER then n = n + 1 end
    end
    return n
end
assertThat("all 3 ender chests accounted for", enderCount(r) == 3,
           "found " .. enderCount(r))

-- 3. Crash mid-deposit: an ender chest of ours is still on the ground.
print("\n[3] restart with our ender chest left placed in front")
local st3 = '{["deployed"]=true,["phase"]="depositing",["cycles"]=1,' ..
            '["placed"]={["front"]=14,},}'
local kitNoDeposit = fullKit(); kitNoDeposit[14] = nil
r = run{ preInv = kitNoDeposit, preFiles = { ["state.txt"] = st3 },
         world = { front = ENDER }, worldNbt = { front = HASH_DEPO },
         frontChest = nil, budget = 3000 }
assertThat("recovered the chest and re-filed it to slot 14",
           r.inv[14] ~= nil and r.inv[14].name == ENDER,
           "slot 14 = " .. tostring(r.inv[14] and r.inv[14].name))
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 4. Front face unusable (lava). The fallback ladder must find another face
--    rather than dropping, and the run must continue.
print("\n[4] front face blocked, fallback ladder")
r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = st },
         blockedFaces = { front = true }, frontChest = nil, budget = 3000 }
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)
assertThat("did not abort on the blocked face",
           not (r.err or ""):find("Could not place the deposit chest"),
           r.err)

-- 5. Every face unusable. Must keep the items and stop - never drop.
print("\n[5] all faces blocked")
r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = st },
         blockedFaces = { front = true, up = true, down = true },
         frontChest = nil, budget = 3000 }
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)
assertThat("stopped rather than continuing", not r.ok)

-- 6. THE ONE THAT MATTERS FOR "COME AND GET ME". A field failure must leave a
--    warp plate ON THE GROUND and send the warp stone home, otherwise the
--    message is telling you to walk to a place you cannot reach.
print("\n[6] field failure must leave a usable warp point")
local kitNoRefuel = fullKit(); kitNoRefuel[16] = nil   -- incomplete kit on restart
-- Stand in for the activated warp stone the hopper would have picked up: it has
-- to reach the warp chest, or you have a plate you cannot warp to.
kitNoRefuel[1] = { name = "waystones:warp_stone", count = 1 }
r = run{ preInv = kitNoRefuel, preFiles = { ["state.txt"] = st },
         frontChest = nil, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("a warp plate was placed", r.platePlaced)
assertThat("plate LEFT in the world, not picked back up",
           r.world.front == PLATE or r.world.down == PLATE,
           "front=" .. tostring(r.world.front) .. " down=" .. tostring(r.world.down))
assertThat("warp stone sent home (something reached a chest)", r.safeDrops > 0,
           "safeDrops=" .. r.safeDrops)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 7. Refuel failure is the classic stranding case: it must also leave a plate.
print("\n[7] refuel takes on nothing -> must still leave a warp point")
r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = st },
         frontChest = nil, fuelRises = false, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("a warp plate was placed", r.platePlaced)
assertThat("plate LEFT in the world", r.world.front == PLATE or r.world.down == PLATE,
           "front=" .. tostring(r.world.front) .. " down=" .. tostring(r.world.down))
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 8. Honesty check: with no plate in the kit it must NOT claim to be reachable.
print("\n[8] no warp plate in kit -> must not promise a rescue")
local kitNoPlate = fullKit(); kitNoPlate[13] = nil; kitNoPlate[16] = nil
r = run{ preInv = kitNoPlate, preFiles = { ["state.txt"] = st },
         frontChest = nil, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("no plate placed (there was none to place)", not r.platePlaced)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 9. RISK 1a: state.txt exists but is truncated garbage (crash mid-write).
--    Must NOT be read as "first run" - staging in a cave is the disaster.
print("\n[9] corrupt state.txt must not trigger staging")
r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = '{["deploy' },
         frontChest = nil, budget = 3000 }
assertThat("did NOT try to stage", not r.staged)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)
assertThat("all 3 ender chests accounted for", enderCount(r) == 3,
           "found " .. enderCount(r))

-- 10. RISK 1b: crashed in the delete/move window - only the scratch file is
--     left. It must be picked up rather than ignored.
print("\n[10] only state.tmp survives -> resume from it")
r = run{ preInv = fullKit(), preFiles = { ["state.tmp"] = st },
         frontChest = nil, budget = 3000 }
assertThat("did NOT try to stage", not r.staged)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 11. RISK 1c: state file DELETED outright while deployed. The parse check
--     cannot catch this, so the carried kit is what has to give it away - and
--     the bot must leave a warp point rather than just shrugging.
print("\n[11] state file lost entirely while deployed")
r = run{ preInv = fullKit(), preFiles = {}, frontChest = nil, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("a warp plate was placed", r.platePlaced)
assertThat("plate LEFT in the world", r.world.front == PLATE or r.world.down == PLATE,
           "front=" .. tostring(r.world.front) .. " down=" .. tostring(r.world.down))
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 12. Regression: a genuine first run at base must STILL stage normally, and
--     must not be misread as a lost-state-file distress case.
print("\n[12] genuine first run at base still stages")
local supply2 = {}
for _, it in pairs(fullKit()) do supply2[#supply2 + 1] = it end
supply2[#supply2 + 1] = { name = PICKAXE, count = 1 }
r = run{ preInv = {}, preFiles = {}, frontChest = supply2, budget = 3000 }
assertThat("staged from the supply chest", r.staged)
-- Not "no plate was ever placed" - a healthy run legitimately places one at its
-- scheduled 4th-cycle warp. The thing that must NOT happen is mistaking a first
-- run for a deployed bot that lost its state file.
assertThat("did not take the lost-state distress path",
           not (r.err or ""):find("carrying a full kit"), r.err)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 13. Staging guard: a supply chest that is present but EMPTY. The bot is at
--     base with a player standing there, so the right answer is to refuse
--     loudly and cheaply rather than set off with no kit.
print("\n[13] empty supply chest -> refuses to start")
r = run{ preInv = {}, preFiles = {}, frontChest = {}, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("said staging incomplete", (r.err or ""):find("staging incomplete") ~= nil, r.err)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 14. The single most dangerous omission: everything staged EXCEPT the refuel
--     chest. Missing it means no fuel and a stranded bot, so the error has to
--     name the slot rather than just failing.
print("\n[14] refuel chest absent from supply -> names slot 16")
local partial = {}
for s, it in pairs(fullKit()) do
    if s ~= 16 then partial[#partial + 1] = it end
end
partial[#partial + 1] = { name = PICKAXE, count = 1 }
r = run{ preInv = {}, preFiles = {}, frontChest = partial, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("named slot 16 specifically",
           (r.err or ""):find("slot 16 (refuel ender chest)", 1, true) ~= nil, r.err)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

print("\n" .. string.rep("=", 64))
print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
