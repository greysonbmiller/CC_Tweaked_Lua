-- Ore selection: the catalogue of blocks the scanner has actually seen, and
-- targeting several ores at once.
--
-- The turtle has no block registry, so a mistyped block id can never be
-- rejected - it just silently matches nothing forever. The catalogue is what
-- replaces that missing registry: it records the exact ids the scanner really
-- returned, so ids are picked from observed reality rather than typed from
-- memory.
--
--   luajit mining/tests/ore_harness.lua [path/to/miner.lua]

local TARGET = arg[1] or "mining/geo_scanner_ore_mining_bot.lua"

local here = (arg[0] or ""):match("^(.*[/\\])") or ""
local mock = dofile(here .. "ccmock.lua")

local PICKAXE = mock.PICKAXE
local fullKit = mock.fullKit
local function run(opts) return mock.run(TARGET, opts) end

local LAPIS      = "minecraft:lapis_ore"
local LAPIS_DEEP = "minecraft:deepslate_lapis_ore"
local REDSTONE   = "minecraft:deepslate_redstone_ore"
local DIAMOND    = "minecraft:deepslate_diamond_ore"
local DEBRIS     = "minecraft:ancient_debris"

-- A deployed field state, so runs skip staging and go straight to mining.
local function deployedState(targets)
    local list = {}
    for _, id in ipairs(targets or { LAPIS, LAPIS_DEEP }) do
        list[#list + 1] = string.format("%q", id)
    end
    return '{["deployed"]=true,["phase"]="mining",["cycles"]=1,["placed"]={},' ..
           '["targets"]={' .. table.concat(list, ",") .. ',},}'
end

local function block(name, x, y, z)
    return { name = name, x = x or 0, y = y or 0, z = z or 0 }
end

local pass, fail = 0, 0
local function assertThat(label, cond, detailMsg)
    if cond then pass = pass + 1; print(string.format("  %-52s PASS", label))
    else fail = fail + 1; print(string.format("  %-52s FAIL", label))
         if detailMsg then print("        " .. detailMsg) end end
end

local function catalogue(r) return r.files["ores.txt"] or "" end

-- Pull the id out of a catalogue line regardless of what else is on it, so
-- these tests check the ids recorded rather than the exact column layout.
local function idFromLine(line)
    if line:match("^%s*#") then return nil end
    return line:match("([%w_%-%.]+:[%w_%-%./]+)")
end
local function hasEntry(r, id)
    for line in catalogue(r):gmatch("[^\r\n]+") do
        if idFromLine(line) == id then return true end
    end
    return false
end
local function entryIndex(r, id)
    local i = 0
    for line in catalogue(r):gmatch("[^\r\n]+") do
        local name = idFromLine(line)
        if name then
            i = i + 1
            if name == id then return i end
        end
    end
    return nil
end
local function writeCount(r, path)
    local n = 0
    for _, p in ipairs(r.writes) do if p == path then n = n + 1 end end
    return n
end

print("target: " .. TARGET)
print(string.rep("=", 64))

-- 1. The catalogue records what the scanner returned, and only the ore-like
--    part of it. Recording every block would bury the list under stone.
print("\n[1] records ore-like blocks, ignores the rest")
local r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = deployedState() },
               scans = { { block("minecraft:stone", 1, 0, 0),
                           block(REDSTONE, 0, 1, 0),
                           block("minecraft:dirt", 2, 0, 0),
                           block(DEBRIS, 0, 0, 1) } },
               budget = 3000 }
assertThat("recorded the redstone ore", hasEntry(r, REDSTONE), catalogue(r))
assertThat("recorded ancient debris", hasEntry(r, DEBRIS), catalogue(r))
assertThat("did NOT record stone", not hasEntry(r, "minecraft:stone"), catalogue(r))
assertThat("did NOT record dirt", not hasEntry(r, "minecraft:dirt"), catalogue(r))

-- 2. Entries are appended in discovery order and never reordered. That is what
--    makes the line number a stable handle: a number picked from an older
--    listing must still mean the same ore later.
print("\n[2] append-only, in discovery order")
r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = deployedState() },
         scans = { { block(REDSTONE, 0, 1, 0) }, { block(DIAMOND, 0, 1, 0) } },
         budget = 3000 }
local iR, iD = entryIndex(r, REDSTONE), entryIndex(r, DIAMOND)
assertThat("both recorded", iR ~= nil and iD ~= nil, catalogue(r))
assertThat("first seen has the lower number", (iR or 99) < (iD or 0),
           "redstone=" .. tostring(iR) .. " diamond=" .. tostring(iD))

-- 3. scan_loop scans in a tight loop, so rewriting the file every scan would
--    hammer the filesystem for no reason. It must only be written when the set
--    actually grew.
print("\n[3] only written when the set grows")
r = run{ preInv = fullKit(),
         preFiles = { ["state.txt"] = deployedState(),
                      ["ores.txt"]  = LAPIS .. "\n" .. LAPIS_DEEP .. "\n" .. REDSTONE .. "\n" },
         scans = { { block(REDSTONE, 0, 1, 0) }, { block(REDSTONE, 0, 1, 0) },
                   { block(REDSTONE, 0, 1, 0) } },
         budget = 3000 }
assertThat("nothing new seen -> file never rewritten", writeCount(r, "ores.txt") == 0,
           "writes=" .. writeCount(r, "ores.txt"))

-- 4. Targeting several ores at once. netUp > 0 can only come from seek(), so it
--    proves the bot actually travelled to the ore rather than merely logging it.
print("\n[4] matches ANY id in the target set")
r = run{ preInv = fullKit(),
         preFiles = { ["state.txt"] = deployedState({ LAPIS, DIAMOND }) },
         scans = { { block(DIAMOND, 0, 3, 0) } }, budget = 3000 }
assertThat("went for the second id in the set", (r.ups - r.downs) >= 3,
           "ups=" .. r.ups .. " downs=" .. r.downs)

-- 5. Control for [4]: an ore that is NOT selected must be catalogued but never
--    travelled to. Without this, [4] would pass even if the bot chased
--    everything it saw.
print("\n[5] ignores an ore that is not selected")
r = run{ preInv = fullKit(),
         preFiles = { ["state.txt"] = deployedState({ LAPIS }) },
         scans = { { block(DIAMOND, 0, 3, 0) } }, budget = 3000 }
assertThat("did not travel to it", (r.ups - r.downs) <= 0,
           "ups=" .. r.ups .. " downs=" .. r.downs)
assertThat("but did catalogue it", hasEntry(r, DIAMOND), catalogue(r))

-- 6. The selection has to survive a reboot, or a server crash silently reverts
--    a days-old run to whatever the file was shipped with.
print("\n[6] selection persists to state.txt")
r = run{ preInv = fullKit(),
         preFiles = { ["state.txt"] = deployedState({ LAPIS, DIAMOND }) },
         scans = { { block(DIAMOND, 0, 1, 0) } }, budget = 3000 }
local stateText = r.files["state.txt"] or ""
assertThat("state.txt still names both targets",
           stateText:find(LAPIS, 1, true) ~= nil and stateText:find(DIAMOND, 1, true) ~= nil,
           stateText)

-- 7. The catalogue is a convenience bolted onto a program whose failure mode is
--    a stranded turtle. A damaged ores.txt must never be able to stop mining.
print("\n[7] a corrupt catalogue cannot stop the bot")
r = run{ preInv = fullKit(),
         preFiles = { ["state.txt"] = deployedState(), ["ores.txt"] = "\1\2\255 not text\n\n#" },
         scans = { { block(REDSTONE, 0, 1, 0) } }, budget = 3000 }
assertThat("ran on to the step budget rather than dying",
           r.budgetHit, r.err)
assertThat("still recorded the new ore", hasEntry(r, REDSTONE), catalogue(r))

-- 8. Regression: with no state file at all, a fresh install must behave exactly
--    as the shipped file always has - lapis, both variants.
print("\n[8] fresh install still defaults to the lapis pair")
local supply = {}
for _, it in pairs(fullKit()) do supply[#supply + 1] = it end
supply[#supply + 1] = { name = PICKAXE, count = 1 }
r = run{ preInv = {}, preFiles = {}, frontChest = supply,
         scans = { { block(LAPIS_DEEP, 0, 3, 0) } }, budget = 3000 }
stateText = r.files["state.txt"] or ""
assertThat("targets both lapis variants by default",
           stateText:find(LAPIS, 1, true) ~= nil and
           stateText:find(LAPIS_DEEP, 1, true) ~= nil, stateText)
assertThat("and goes for lapis without being told", (r.ups - r.downs) >= 3,
           "ups=" .. r.ups .. " downs=" .. r.downs)

-- 9. DENSE ORE MUST NOT STARVE THE CYCLE.
--
--    scan_loop miniscans for as long as it keeps finding ore. refuel(),
--    deposit() and the warp announce all live AFTER it in the main loop, so a
--    vein that never runs out meant none of them ever ran: the bot burned fuel
--    seeking ore, filled its loot slots, went silent, and would eventually
--    strand itself - while apparently working perfectly.
--
--    Measured before the fix: 3,999 scans, zero announces, zero refuels.
--
--    Selecting several common ores at once makes this far more likely, so it
--    matters more now than when the bot hunted one rare ore.
print("\n[9] endless ore must not starve refuel or the announce")
local endless = {}
for i = 1, 4000 do endless[i] = { block(LAPIS, 0, 1, 0) } end
r = run{ preInv = fullKit(),
         preFiles = { ["state.txt"] = deployedState({ LAPIS }) },
         scans = endless, burnFuel = true, budget = 12000 }
local announces = 0
for _, m in ipairs(r.sent) do
    local msg = tostring(m.msg)
    if msg:find("Warp plate is down", 1, true) or msg:find("Listening for", 1, true) then
        announces = announces + 1
    end
end
assertThat("still refuelled", r.refuels > 0, "refuels=" .. r.refuels)
assertThat("never ran out of fuel", not r.ranDry,
           "minFuel=" .. tostring(r.minFuel))
assertThat("still announced", announces > 0, "announces=" .. announces)

print("\n" .. string.rep("=", 64))
print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
