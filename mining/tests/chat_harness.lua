-- The chat command window: picking ores remotely during the warp-plate hold.
--
-- The turtle has two peripheral slots and both are spoken for, so nothing can
-- sit attached waiting for events - a message sent while the chat box is stowed
-- is lost, not queued. The window therefore rides the 30 second pause that
-- warpPlate() already takes, which is the one moment the bot is idle, already
-- announcing itself, and has a reason to have the box on its arm.
--
--   luajit mining/tests/chat_harness.lua [path/to/miner.lua]

local TARGET = arg[1] or "mining/geo_scanner_ore_mining_bot.lua"

local here = (arg[0] or ""):match("^(.*[/\\])") or ""
local mock = dofile(here .. "ccmock.lua")

local fullKit = mock.fullKit
local function run(opts) return mock.run(TARGET, opts) end

local LAPIS      = "minecraft:lapis_ore"
local LAPIS_DEEP = "minecraft:deepslate_lapis_ore"
local REDSTONE   = "minecraft:deepslate_redstone_ore"
local DIAMOND    = "minecraft:deepslate_diamond_ore"

-- A known catalogue, so pick numbers in these tests are stable and meaningful.
--   1 = lapis   2 = deepslate lapis   3 = redstone   4 = diamond
local CATALOGUE = table.concat({
    "# Ore blocks this turtle has scanned",
    "1\t" .. LAPIS,
    "2\t" .. LAPIS_DEEP,
    "3\t" .. REDSTONE,
    "4\t" .. DIAMOND,
}, "\n") .. "\n"

-- cycles = 4 so the very first pass through the main loop reaches warpPlate(),
-- which is where the listening window lives.
local function warpingState(targets)
    local list = {}
    for _, id in ipairs(targets or { LAPIS, LAPIS_DEEP }) do
        list[#list + 1] = string.format("%q", id)
    end
    return '{["deployed"]=true,["phase"]="mining",["cycles"]=4,["placed"]={},' ..
           '["targets"]={' .. table.concat(list, ",") .. ',},}'
end

local function base(chats, targets)
    return { preInv = fullKit(),
             preFiles = { ["state.txt"] = warpingState(targets), ["ores.txt"] = CATALOGUE },
             scans = { { { name = REDSTONE, x = 0, y = 1, z = 0 } } },
             chats = chats, budget = 4000 }
end

local pass, fail = 0, 0
local function assertThat(label, cond, detailMsg)
    if cond then pass = pass + 1; print(string.format("  %-52s PASS", label))
    else fail = fail + 1; print(string.format("  %-52s FAIL", label))
         if detailMsg then print("        " .. detailMsg) end end
end

local function stateOf(r) return r.files["state.txt"] or "" end
local function targets(r, id) return stateOf(r):find(id, 1, true) ~= nil end
local function saidAny(r, needle)
    for _, m in ipairs(r.sent) do
        if tostring(m.msg):find(needle, 1, true) then return true end
    end
    return false
end
local function allSaid(r)
    local out = {}
    for _, m in ipairs(r.sent) do out[#out + 1] = tostring(m.msg) end
    return table.concat(out, "\n   | ")
end

print("target: " .. TARGET)
print(string.rep("=", 64))

-- 1. The point of the whole feature.
print("\n[1] $ore <number> retargets from the catalogue")
local r = run(base({ { msg = "$ore 3" } }))
assertThat("now targets catalogue entry 3", targets(r, REDSTONE), stateOf(r))
assertThat("dropped the old lapis targets", not targets(r, LAPIS_DEEP), stateOf(r))
assertThat("acknowledged the change", saidAny(r, "redstone"), allSaid(r))

-- 2. Several ores at once, which is the reason picks are numbers.
print("\n[2] $ore takes several numbers at once")
r = run(base({ { msg = "$ore 3 4" } }))
assertThat("targets redstone", targets(r, REDSTONE), stateOf(r))
assertThat("targets diamond", targets(r, DIAMOND), stateOf(r))

-- 3. Anyone else on the server must not be able to retask the bot.
print("\n[3] only SKAAAAL is obeyed")
r = run(base({ { msg = "$ore 4", who = "someone_else" } }))
assertThat("ignored the stranger", not targets(r, DIAMOND), stateOf(r))
assertThat("kept the original targets", targets(r, LAPIS), stateOf(r))

-- 4. The escape hatch: an id the bot has never scanned. It must be accepted -
--    the bot may simply not have been near one - but flagged, because this is
--    the only input that cannot be checked against anything.
print("\n[4] a literal id is accepted but flagged as unseen")
r = run(base({ { msg = "$ore minecraft:emerald_ore" } }))
assertThat("adopted the literal id", targets(r, "minecraft:emerald_ore"), stateOf(r))
assertThat("warned that it has never seen one", saidAny(r, "never"), allSaid(r))

-- 5. Garbage must change nothing. A silently-ignored typo would leave the bot
--    mining a block that does not exist for as long as it is left running.
print("\n[5] nonsense changes nothing and says so")
r = run(base({ { msg = "$ore zzz" } }))
assertThat("targets untouched", targets(r, LAPIS) and not targets(r, DIAMOND), stateOf(r))
assertThat("said it did not understand", saidAny(r, "zzz"), allSaid(r))

-- 6. Out-of-range numbers are the likeliest slip when reading a list back.
print("\n[6] an out-of-range number is refused")
r = run(base({ { msg = "$ore 99" } }))
assertThat("targets untouched", targets(r, LAPIS), stateOf(r))
assertThat("said so", saidAny(r, "99"), allSaid(r))

-- 7. Reading the list back.
print("\n[7] $ores lists the catalogue with pick numbers")
r = run(base({ { msg = "$ores" } }))
assertThat("listed redstone", saidAny(r, REDSTONE), allSaid(r))
assertThat("listed diamond", saidAny(r, DIAMOND), allSaid(r))
-- One ore per line. Packing several onto a line saves messages but makes the
-- list unreadable in chat, and misreading a number off it is exactly the
-- mistake the catalogue exists to prevent.
local crowded = nil
for _, m in ipairs(r.sent) do
    local n = 0
    for _ in tostring(m.msg):gmatch("[%w_%-%.]+:[%w_%-%./]+") do n = n + 1 end
    if n > 1 then crowded = tostring(m.msg) end
end
assertThat("no message carries more than one ore", crowded == nil,
           "crowded line: " .. tostring(crowded))

-- 8. The announce has to carry what you need to act, at the moment you can act.
print("\n[8] the announce states the target and how to change it")
r = run(base({}))
assertThat("named what it is mining", saidAny(r, "lapis"), allSaid(r))
assertThat("advertised the command", saidAny(r, "$ore"), allSaid(r))
-- One selected ore per line, matching $ores. Both targets must appear, and no
-- single message may carry more than one id.
assertThat("listed both selected ores",
           saidAny(r, LAPIS) and saidAny(r, LAPIS_DEEP), allSaid(r))
local packed = nil
for _, m in ipairs(r.sent) do
    local n = 0
    for _ in tostring(m.msg):gmatch("[%w_%-%.]+:[%w_%-%./]+") do n = n + 1 end
    if n > 1 then packed = tostring(m.msg) end
end
assertThat("no announce line carries two ores", packed == nil,
           "packed line: " .. tostring(packed))

-- 9. The window must end on its own and give the plate back. Not "no plate is
--    on the ground at the end" - the run is cut at an arbitrary point and may
--    legitimately be mid-hold. What proves recovery is that the bot warps
--    REPEATEDLY: it cannot place a plate it never picked up again.
print("\n[9] the window ends by itself, cycle after cycle")
local opts9 = base({ { msg = "$ore 3" } })
opts9.budget = 12000     -- needs room for several full cycles, not just one
r = run(opts9)
-- The window must NOT depend on a plate going down. It used to live inside the
-- successful-warp path, so disabling warp plates would have silently disabled
-- the only way to retarget the bot along with them.
assertThat("no plate placed, and the window ran anyway", not r.platePlaced)
assertThat("window closed and mining resumed", saidAny(r, "resumed"), allSaid(r))
local resumes = 0
for _, m in ipairs(r.sent) do
    if tostring(m.msg):find("resumed", 1, true) then resumes = resumes + 1 end
end
assertThat("warped more than once, so the plate came back", resumes > 1,
           "resumes=" .. resumes)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 10. The bot is unattended nearly all the time, so the recipient is usually
--     offline. A send that fails must not be able to end the run - least of all
--     here, where the plate is already on the ground.
print("\n[10] a failing send cannot kill the run")
local opts = base({ { msg = "$ore 3" } })
opts.sendFails = true
r = run(opts)
assertThat("ran on rather than dying at the announce", r.budgetHit, r.err)
assertThat("still processed the command", targets(r, REDSTONE), stateOf(r))
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 11. Chat boxes have been observed reporting names in a different case than
--     the player typed. Being deaf over capitalisation is not acceptable when
--     the only symptom is silence.
print("\n[11] the username filter is case-insensitive")
r = run(base({ { msg = "$ore 3", who = "skaaaal" } }))
assertThat("obeyed the same player in lower case", targets(r, REDSTONE), stateOf(r))

-- 12. Some builds strip the hidden-message prefix before firing the event, so
--     the bot would see "ore 3" and match nothing. Accept both spellings.
print("\n[12] a command still works with the $ stripped")
r = run(base({ { msg = "ore 3" } }))
assertThat("obeyed the bare command", targets(r, REDSTONE), stateOf(r))

-- 13. The other half of [12]: accepting bare commands must NOT turn every
--     sentence the owner types into a command, or the bot answers back at all
--     ordinary conversation.
print("\n[13] ordinary chat is not answered")
r = run(base({ { msg = "hello there, nice weather" } }))
assertThat("targets untouched", targets(r, LAPIS), stateOf(r))
assertThat("did not reply to it",
           not saidAny(r, "I only understand"), allSaid(r))

-- 14. CONFIRMED BY PROBE: AdvancedPeripherals strips the $ before firing the
--     event, so every real command arrives bare. That means the prefix cannot
--     be used to tell a command from conversation - and in particular, a
--     mistyped pick number must STILL be reported, because that is precisely
--     when silence is most misleading.
print("\n[14] a bad pick number is reported even with no prefix")
r = run(base({ { msg = "ore 99" } }))
assertThat("targets untouched", targets(r, LAPIS), stateOf(r))
assertThat("told the operator about 99", saidAny(r, "99"), allSaid(r))

-- 15. The other side of [14]: sentences that merely begin with the word must
--     not trigger anything, or the bot talks over ordinary conversation.
print("\n[15] sentences beginning 'ore'/'ores' are ignored")
r = run(base({ { msg = "ores are great in this pack" } }))
assertThat("did not list the catalogue", not saidAny(r, REDSTONE), allSaid(r))
r = run(base({ { msg = "ore is the best thing to mine" } }))
assertThat("targets untouched", targets(r, LAPIS), stateOf(r))
assertThat("stayed quiet", not saidAny(r, "I do not know"), allSaid(r))

-- 16. A retargeting window on every start and every recovery. Without it the
--     first chance to retask the bot is its first scheduled warp - four
--     completed cycles away, and much longer in dense ore. A reboot is exactly
--     when someone is most likely to be standing there wanting to change
--     something, and exactly when the bot is about to walk off for an hour.
print("\n[16] a retargeting window opens at startup")
r = run{ preInv = fullKit(),
         preFiles = { ["state.txt"] = warpingState(), ["ores.txt"] = CATALOGUE },
         scans = {}, chats = { { msg = "$ore 4" } }, budget = 4000 }
assertThat("announced that it was starting up", saidAny(r, "Starting up"), allSaid(r))
assertThat("took a command before mining", targets(r, DIAMOND), stateOf(r))

-- 17. $radius. Measured on the real hardware: free to radius 8, 330 fuel at 9,
--     5274 at 16, and 16 is the ceiling. A lava bucket is 1000 fuel, so radius
--     16 is over five buckets PER SCAN - the difference between radii is the
--     difference between sustainable and not, and the bot has to say so.
print("\n[17] $radius sets the wide-scan radius")
local opts17 = base({ { msg = "$radius 9" } })
opts17.budget = 12000    -- must get past startup and into an actual scan
r = run(opts17)
assertThat("recorded the new radius", (stateOf(r)):find("9", 1, true) ~= nil, stateOf(r))
local usedNine = false
for _, rad in ipairs(r.scanRadii) do if rad == 9 then usedNine = true end end
assertThat("actually scanned at 9", usedNine,
           "radii used: " .. table.concat(r.scanRadii, ","))
assertThat("quoted the fuel cost", saidAny(r, "330"), allSaid(r))

print("\n[18] $radius refuses a radius the scanner cannot do")
r = run(base({ { msg = "$radius 99" } }))
local used99 = false
for _, rad in ipairs(r.scanRadii) do if rad == 99 then used99 = true end end
assertThat("never scanned at 99", not used99,
           "radii used: " .. table.concat(r.scanRadii, ","))
assertThat("said what the ceiling is", saidAny(r, "16"), allSaid(r))

print("\n[19] $radius alone reports the current setting and its price")
r = run(base({ { msg = "$radius" } }))
assertThat("named the radius", saidAny(r, "8"), allSaid(r))
assertThat("mentioned fuel", saidAny(r, "fuel"), allSaid(r))

-- 20. A cooldown rejection returns nil, exactly as "found nothing" does. Read
--     as "no ore", it abandons a vein the bot is standing in. The scanner has a
--     measured 120ms cooldown and the chase fires scans back to back, so this
--     is not hypothetical.
--
--     Every other scan is rejected here, so a miner that gives up on nil can
--     never chase a vein at all, while one that retries is unaffected. A single
--     one-off miss would not show the difference - the bot recovers on the next
--     cycle either way, which is why the first version of this test passed
--     against code that had no retry.
print("\n[20] a cooldown rejection is not read as 'no ore'")
local endlessOre = {}
for i = 1, 400 do endlessOre[i] = { { name = REDSTONE, x = 0, y = 3, z = 0 } } end
r = run{ preInv = fullKit(),
         preFiles = { ["state.txt"] = warpingState({ REDSTONE }), ["ores.txt"] = CATALOGUE },
         scans = endlessOre, scanMissAlternate = true, budget = 6000 }
--     Measured on the same budget and terrain: 1646 net-up with no rejections,
--     303 when every other scan is rejected and the miner gives up on nil. The
--     threshold sits between the two, so it fails loudly if the retry is lost.
assertThat("saw rejections at all", r.cooldownMisses > 0,
           "misses=" .. tostring(r.cooldownMisses))
assertThat("kept chasing at close to full rate", (r.ups - r.downs) >= 1000,
           "netUp=" .. (r.ups - r.downs) .. " (no-rejection baseline is ~1646," ..
           " give-up-on-nil is ~303) misses=" .. tostring(r.cooldownMisses))

-- 21. FACING. The scanner reports offsets in WORLD axes; seek() steers by
--     turning relative to the turtle. Converting one to the other is only
--     possible if the bot knows which way it faces, and the original code
--     silently assumed north. Set down facing south, every move went the wrong
--     way - the bot walked directly away from ore it had correctly detected,
--     which reads as "the scanner is broken".
--
--     An ore three blocks SOUTH: facing north that is behind the turtle and
--     needs a 180, facing south it is straight ahead and needs no turn at all.
local function seekTurns(facing)
    local oreSouth = {}
    for i = 1, 60 do oreSouth[i] = { { name = REDSTONE, x = 0, y = 0, z = 3 } } end
    local rr = run{ preInv = fullKit(),
                    preFiles = { ["state.txt"] =
                        '{["deployed"]=true,["phase"]="mining",["cycles"]=0,' ..
                        '["placed"]={},["facing"]="' .. facing .. '",' ..
                        '["targets"]={"' .. REDSTONE .. '",},}' },
                    scans = oreSouth, budget = 900 }
    return rr.turns
end

print("\n[21] seek respects the turtle's facing")
local turnsNorth, turnsSouth = seekTurns("north"), seekTurns("south")
assertThat("facing south needs fewer turns than facing north",
           turnsSouth < turnsNorth,
           "north=" .. turnsNorth .. " south=" .. turnsSouth)

print("\n[22] $facing sets it, and refuses nonsense")
r = run(base({ { msg = "$facing east" } }))
assertThat("recorded the facing", stateOf(r):find("east", 1, true) ~= nil, stateOf(r))
r = run(base({ { msg = "$facing sideways" } }))
assertThat("refused a non-direction",
           stateOf(r):find("sideways", 1, true) == nil, stateOf(r))
assertThat("listed the valid directions", saidAny(r, "north"), allSaid(r))

print("\n" .. string.rep("=", 64))
print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
