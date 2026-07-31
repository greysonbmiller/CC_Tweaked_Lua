-- The "scuttle" command: abandon the kit.
--
-- Thousands of blocks from any player, the chunk loader on the right arm is
-- the ONLY thing keeping the turtle's chunk loaded. The instant it comes off,
-- the chunk becomes eligible to unload, which freezes the running program
-- mid-execution - and if that freeze lands between equipRight() and the
-- loader hitting the deposit chest, the loader is stuck inside a frozen
-- turtle at coordinates nobody can find, and nothing will ever load that
-- chunk again to let it finish. So the gap between "the loader leaves the
-- arm" and "the loader lands in the chest" has to contain NOTHING - no
-- select, no dig, no place, no print - because every operation in that gap
-- is one more tick in which the freeze can land.
--
-- This feature does not exist in the production file yet. This harness is
-- expected to FAIL, and to fail on the BEHAVIOUR (chest never placed, items
-- still in inventory, no shutdown) rather than on a Lua error.
--
-- COMMAND CONTRACT (pinned exactly - an implementation agent codes to this
-- same text in parallel):
--   "scuttle now" (bare word stripped by AdvancedPeripherals from "$scuttle
--                  now") actually performs the scuttle.
--   "scuttle"     alone does NOT scuttle - AdvancedPeripherals strips the "$"
--                  before the event fires, so the bot cannot otherwise tell
--                  "$scuttle" apart from SKAAAAL just saying the word in
--                  conversation. It replies with a warning containing the
--                  exact substring "say scuttle now" and touches nothing.
--   The goodbye chat on a real scuttle contains "Scuttling now".
--   The abort message when the deposit chest will not place contains
--   "cannot scuttle".
--
--   luajit mining/tests/scuttle_harness.lua [path/to/miner.lua]

local TARGET = arg[1] or "mining/geo_scanner_ore_mining_bot.lua"

local here = (arg[0] or ""):match("^(.*[/\\])") or ""
local mock = dofile(here .. "ccmock.lua")

local fullKit = mock.fullKit
local function run(opts) return mock.run(TARGET, opts) end

local SCANNER, CHATBOX, PICKAXE = mock.SCANNER, mock.CHATBOX, mock.PICKAXE
local ENDER, HOPPER, PLATE, CHUNKY = mock.ENDER, mock.HOPPER, mock.PLATE, mock.CHUNKY

local REDSTONE = "minecraft:deepslate_redstone_ore"

local pass, fail = 0, 0
local function assertThat(label, cond, detailMsg)
    if cond then pass = pass + 1; print(string.format("  %-58s PASS", label))
    else fail = fail + 1; print(string.format("  %-58s FAIL", label))
         if detailMsg then print("        " .. detailMsg) end end
end

-- A deployed, mid-cycle field state - already staged, already mining, exactly
-- the situation the bot is actually in when someone decides to scuttle it.
local function deployedState()
    return '{["deployed"]=true,["phase"]="mining",["cycles"]=0,["placed"]={},' ..
           '["targets"]={"' .. REDSTONE .. '",},}'
end

-- opts: chats (required), plus any of the base fields to override.
local function scuttleOpts(chats, extra)
    extra = extra or {}
    return {
        preInv        = extra.preInv or fullKit(),
        preFiles      = extra.preFiles or { ["state.txt"] = deployedState() },
        chats         = chats,
        scans         = extra.scans or { { { name = REDSTONE, x = 0, y = 1, z = 0 } } },
        budget        = extra.budget or 2500,
        blockedFaces  = extra.blockedFaces,
        blockFacesAfterChat = extra.blockFacesAfterChat,
        rightArmSticks = extra.rightArmSticks,
        rightTool     = extra.rightTool,
    }
end

----------------------------------------------------------------------------
-- eventLog helpers - every ordering assertion below is built on these.
----------------------------------------------------------------------------

local function indexOf(log, entry)
    for i, v in ipairs(log) do if v == entry then return i end end
    return nil
end
-- Matches by prefix rather than exact string, so callers do not have to know
-- an item's full name up front - used for "any drop of this kind of thing"
-- (e.g. every "drop:enderstorage:ender_chest", whichever NBT it carried).
local function lastIndexOfPrefix(log, prefix)
    for i = #log, 1, -1 do
        if log[i]:sub(1, #prefix) == prefix then return i end
    end
    return nil
end
local function countPrefix(log, prefix)
    local n = 0
    for _, v in ipairs(log) do
        if v:sub(1, #prefix) == prefix then n = n + 1 end
    end
    return n
end
local function sliceStr(log, a, b)
    local out = {}
    for i = a, b do out[#out + 1] = log[i] end
    return "[" .. table.concat(out, ", ") .. "]"
end
-- A bounded diagnostic for "this event never happened" failures. A full-log
-- dump sounds more thorough but a healthy run's log runs to thousands of
-- entries (one per dig/select), which buries the useful signal - the tail is
-- what shows whether the run even got as far as it needed to.
local function logSummary(log)
    local n = #log
    if n == 0 then return "eventLog is empty" end
    local from = math.max(1, n - 14)
    return string.format("%d entries; last %d: %s", n, n - from + 1, sliceStr(log, from, n))
end

----------------------------------------------------------------------------
-- Inventory / chat helpers
----------------------------------------------------------------------------

local function invHas(r, name)
    for i = 1, 16 do
        if r.inv[i] and r.inv[i].name == name then return true end
    end
    return false
end
local function lootEmpty(r)
    for i = 1, 9 do
        if r.inv[i] then return false end
    end
    return true
end
local function invDump(r)
    local out = {}
    for i = 1, 16 do
        out[i] = r.inv[i] and r.inv[i].name or "-"
    end
    return table.concat(out, ",")
end
-- Whichever face the deposit chest ended up on, if it is still standing.
local function depositFace(r)
    for _, face in ipairs({ "front", "up", "down" }) do
        if r.world[face] == ENDER then return face end
    end
    return nil
end
-- Case-SENSITIVE on purpose: the command contract pins exact substrings
-- ("Scuttling now", "cannot scuttle", "say scuttle now") that an
-- implementation agent is coding against in parallel, so the anchors below
-- have to match that exact wording, not merely the same word in some case.
-- Also deliberately specific rather than a loose "scuttl" match - the
-- pre-existing deposit() distress message already says "Could not place the
-- deposit chest...", and a bare "scuttl" needle would have matched the
-- no-confirmation warning too, which is a DIFFERENT reply from the abort
-- message and must not be allowed to satisfy the wrong assertion.
local function saidAny(r, needle)
    for _, m in ipairs(r.sent) do
        if tostring(m.msg):find(needle, 1, true) then return true end
    end
    return false
end
-- Bounded, like logSummary: a scuttle-less run repeats the same announce every
-- listen window, so the full transcript is mostly noise. The count plus the
-- tail is what actually shows whether the bot kept talking after it should
-- have gone quiet.
local function sentSummary(r)
    local n = #r.sent
    if n == 0 then return "nothing sent" end
    local out = {}
    for i = math.max(1, n - 5), n do out[#out + 1] = tostring(r.sent[i].msg) end
    return string.format("%d messages sent; last %d:\n   | %s",
                         n, #out, table.concat(out, "\n   | "))
end

print("target: " .. TARGET)
print(string.rep("=", 64))

----------------------------------------------------------------------------
-- The canonical scuttle run, reused by scenarios 1-12: an authorised
-- "scuttle now" during the startup listening window.
----------------------------------------------------------------------------

-- 1. The whole point of leaving the deposit chest down: the loader has
--    somewhere to land. withContainer's usual place-use-dig cycle must NOT be
--    reused here, or the chest would come back up with nothing to receive it.
print("\n[1] the deposit chest is placed and LEFT STANDING")
local r = run(scuttleOpts({ { msg = "scuttle now" } }))
local face = depositFace(r)
assertThat("deposit chest left placed in the world", face ~= nil,
           "world: front=" .. tostring(r.world.front) .. " up=" .. tostring(r.world.up) ..
           " down=" .. tostring(r.world.down))

-- 2. Loot must not be abandoned along with the tools.
print("\n[2] all loot slots (1-9) are empty")
r = run(scuttleOpts({ { msg = "scuttle now" } }))
assertThat("slots 1-9 empty", lootEmpty(r), "inv: " .. invDump(r))

-- 3. Every piece of kit has to actually leave, not just get shuffled around.
print("\n[3] scanner, chat box, pickaxe and every staged item have left the inventory")
r = run(scuttleOpts({ { msg = "scuttle now" } }))
assertThat("scanner gone", not invHas(r, SCANNER), "inv: " .. invDump(r))
assertThat("chat box gone", not invHas(r, CHATBOX), "inv: " .. invDump(r))
assertThat("pickaxe gone", not invHas(r, PICKAXE), "inv: " .. invDump(r))
-- Covers the warp AND refuel ender chests. The deposit chest is not in this
-- inventory either, but for the opposite reason - it is placed in the world,
-- not held - which is exactly what [1] already checks.
assertThat("no ender chest left in inventory", not invHas(r, ENDER), "inv: " .. invDump(r))
assertThat("hopper gone", not invHas(r, HOPPER), "inv: " .. invDump(r))
assertThat("plate gone", not invHas(r, PLATE), "inv: " .. invDump(r))

-- 4. The loader itself: off the arm (it was unequipped) and nowhere in the
--    turtle either (it was then dropped, not merely parked in a slot).
print("\n[4] the chunk loader is off the right arm and not in the inventory")
r = run(scuttleOpts({ { msg = "scuttle now" } }))
assertThat("right arm was unequipped", indexOf(r.eventLog, "equipRight") ~= nil,
           logSummary(r.eventLog))
assertThat("loader was dropped, not just moved to a slot",
           indexOf(r.eventLog, "drop:" .. CHUNKY) ~= nil, logSummary(r.eventLog))
assertThat("loader not sitting in inventory", not invHas(r, CHUNKY), "inv: " .. invDump(r))

-- 5. Nothing may ever be thrown into the void - the deposit chest is the only
--    legal destination for everything that leaves.
print("\n[5] everything that left landed in the placed deposit chest")
r = run(scuttleOpts({ { msg = "scuttle now" } }))
face = depositFace(r)
local landed = face and #(r.contents[face] or {}) or 0
assertThat("deposit chest actually received items", face ~= nil and landed > 0,
           "face=" .. tostring(face) .. " itemsInChest=" .. landed)
assertThat("NOTHING dropped into the world", r.worldDrops == 0, "worldDrops=" .. r.worldDrops)

-- 6. The rescue-mechanism kill switch. If the turtle freezes holding the
--    loader, it must be inert when someone eventually finds it years later,
--    not wake up and mine with no tools.
print("\n[6] startup.lua and state.txt no longer exist")
r = run(scuttleOpts({ { msg = "scuttle now" } }))
assertThat("startup.lua deleted", r.files["startup.lua"] == nil,
           "startup.lua=" .. tostring(r.files["startup.lua"]))
assertThat("state.txt deleted", r.files["state.txt"] == nil,
           "state.txt=" .. tostring(r.files["state.txt"]))

-- 7. The bot must actually power itself off.
print("\n[7] the bot shut down")
r = run(scuttleOpts({ { msg = "scuttle now" } }))
assertThat("report.shutdown is true", r.shutdown == true, "shutdown=" .. tostring(r.shutdown))

-- 8. Scuttling has to be the end of the story - not a detour the bot recovers
--    from and goes back to work after. A control run with no scuttle command
--    proves the harness setup genuinely mines under these scans/budget, so
--    "zero scans" in the scuttle run cannot be explained by the scenario
--    simply never getting that far.
print("\n[8] scuttling ends the run - no more scanning or chatting afterwards")
local endlessOre = {}
for i = 1, 200 do endlessOre[i] = { { name = REDSTONE, x = 0, y = 1, z = 0 } } end
local control = run(scuttleOpts({}, { scans = endlessOre, budget = 8000 }))
assertThat("sanity: the control run actually scans", control.scanCount > 0,
           "control scanCount=" .. control.scanCount)
r = run(scuttleOpts({ { msg = "scuttle now" } }, { scans = endlessOre, budget = 8000 }))
-- The positive half: a control that never leaves is worthless if the "no
-- more scanning" checks below would ALSO pass on a run that simply never
-- reached the goodbye at all. Pinning that a farewell was actually said is
-- what proves the silence afterwards is deliberate, not incidental.
assertThat("a farewell is said before the bot goes quiet",
           saidAny(r, "Scuttling now"), sentSummary(r))
assertThat("no scanning happens once scuttled", r.scanCount == 0,
           "scanCount=" .. r.scanCount)
assertThat("never resumes ordinary chatter after the goodbye",
           not saidAny(r, "resumed"), sentSummary(r))

-- 9. The chunk loader's drop is the very last drop of the whole sequence, and
--    the pickaxe - the other tool that has to come off an arm - drops before
--    it, not after.
print("\n[9] the loader's drop is the LAST drop, and the pickaxe drops before it")
r = run(scuttleOpts({ { msg = "scuttle now" } }))
local loaderDropIdx = indexOf(r.eventLog, "drop:" .. CHUNKY)
local lastDropIdx = lastIndexOfPrefix(r.eventLog, "drop:")
assertThat("loader drop is the last drop in the log",
           loaderDropIdx ~= nil and loaderDropIdx == lastDropIdx,
           "loader drop @ " .. tostring(loaderDropIdx) .. ", last drop @ " .. tostring(lastDropIdx))
local pickaxeDropIdx = indexOf(r.eventLog, "drop:" .. PICKAXE)
assertThat("pickaxe drop happens before the loader drop",
           pickaxeDropIdx ~= nil and loaderDropIdx ~= nil and pickaxeDropIdx < loaderDropIdx,
           "pickaxe drop @ " .. tostring(pickaxeDropIdx) .. ", loader drop @ " .. tostring(loaderDropIdx))

-- 10. The loader must be the very last thing off the turtle, after every
--     other tool and every ender chest.
print("\n[10] the loader drop comes after the scanner, chat box and ender chest drops")
r = run(scuttleOpts({ { msg = "scuttle now" } }))
loaderDropIdx = indexOf(r.eventLog, "drop:" .. CHUNKY)
local scannerDropIdx = indexOf(r.eventLog, "drop:" .. SCANNER)
local chatboxDropIdx = indexOf(r.eventLog, "drop:" .. CHATBOX)
-- Matched by prefix: the warp and refuel chests share one item id
-- (enderstorage:ender_chest) and differ only by NBT, which is not part of
-- the logged string, so this catches every ender-chest drop regardless of
-- which frequency it was.
local enderLastDropIdx = lastIndexOfPrefix(r.eventLog, "drop:" .. ENDER)
assertThat("loader drop after the scanner drop",
           loaderDropIdx ~= nil and scannerDropIdx ~= nil and loaderDropIdx > scannerDropIdx,
           "scanner @ " .. tostring(scannerDropIdx) .. ", loader @ " .. tostring(loaderDropIdx))
assertThat("loader drop after the chat box drop",
           loaderDropIdx ~= nil and chatboxDropIdx ~= nil and loaderDropIdx > chatboxDropIdx,
           "chat box @ " .. tostring(chatboxDropIdx) .. ", loader @ " .. tostring(loaderDropIdx))
assertThat("loader drop after every ender chest drop",
           loaderDropIdx ~= nil and enderLastDropIdx ~= nil and loaderDropIdx > enderLastDropIdx,
           "last ender-chest drop @ " .. tostring(enderLastDropIdx) ..
           ", loader @ " .. tostring(loaderDropIdx))

-- 11. startup.lua is deleted BEFORE the loader ever comes off, so a turtle
--     that freezes holding it is inert rather than relaunching on reboot.
print("\n[11] delete:startup.lua happens before equipRight")
r = run(scuttleOpts({ { msg = "scuttle now" } }))
local delIdx = indexOf(r.eventLog, "delete:startup.lua")
local equipRightIdx = indexOf(r.eventLog, "equipRight")
assertThat("startup.lua deleted before the right arm is touched",
           delIdx ~= nil and equipRightIdx ~= nil and delIdx < equipRightIdx,
           "delete:startup.lua @ " .. tostring(delIdx) .. ", equipRight @ " .. tostring(equipRightIdx))

-- 12. THE RACE INVARIANT - the single most important assertion in this file.
--
--     Once the loader is off the arm, the chunk can unload on any tick, which
--     freezes the program wherever it happens to be. If that freeze lands
--     inside the gap between "off the arm" and "safely in the chest", the
--     loader is stuck in a turtle nobody can ever reach again. The only
--     mitigation is for that gap to contain NOTHING: the destination slot
--     must already be selected before equipRight() runs, and drop() must be
--     the VERY NEXT event afterwards - no select, no dig, no place, no print,
--     no state write in between.
print("\n[12] THE RACE INVARIANT: nothing happens between equipRight and the loader's drop")
r = run(scuttleOpts({ { msg = "scuttle now" } }))
equipRightIdx = indexOf(r.eventLog, "equipRight")
loaderDropIdx = indexOf(r.eventLog, "drop:" .. CHUNKY)
local raceDetail
if not equipRightIdx then
    raceDetail = "equipRight never appears in eventLog - the loader was never unequipped"
elseif not loaderDropIdx then
    raceDetail = "the loader's drop never appears in eventLog"
elseif loaderDropIdx <= equipRightIdx then
    raceDetail = string.format("loader drop (@%d) happens at or before equipRight (@%d)",
                               loaderDropIdx, equipRightIdx)
else
    raceDetail = string.format("gap between equipRight(@%d) and loader drop(@%d): %s",
                               equipRightIdx, loaderDropIdx,
                               sliceStr(r.eventLog, equipRightIdx + 1, loaderDropIdx - 1))
end
assertThat("loader drop is the IMMEDIATE next event after equipRight",
           equipRightIdx ~= nil and loaderDropIdx ~= nil and loaderDropIdx == equipRightIdx + 1,
           raceDetail)

----------------------------------------------------------------------------
-- Scenarios needing a different mock setup each.
----------------------------------------------------------------------------

-- 13. A chunk loader that will not come off must not strand the rest of the
--     kit. Everything else still has to reach the chest, the kill switch
--     still has to be pulled, and the bot still has to shut down.
print("\n[13] a stuck right arm (rightArmSticks) does not strand the rest of the kit")
r = run(scuttleOpts({ { msg = "scuttle now" } }, { rightArmSticks = true }))
assertThat("run still ends cleanly", r.ok == true, "ok=" .. tostring(r.ok) .. " err=" .. tostring(r.err))
face = depositFace(r)
landed = face and #(r.contents[face] or {}) or 0
assertThat("the rest of the kit still reached the deposit chest",
           face ~= nil and landed > 0, "face=" .. tostring(face) .. " itemsInChest=" .. landed)
assertThat("startup.lua still deleted", r.files["startup.lua"] == nil,
           "startup.lua=" .. tostring(r.files["startup.lua"]))
assertThat("the bot still shut down", r.shutdown == true, "shutdown=" .. tostring(r.shutdown))

-- 14. ABORT SAFETY. Losing the kit into the void is far worse than simply not
--     scuttling, so if the deposit chest cannot go down anywhere, nothing may
--     be touched at all.
--
--     blockFacesAfterChat (not blockedFaces from tick zero) is what makes
--     this scenario actually reach the scuttle attempt: blocking every face
--     from the start also blocks the startup refuel() long before any chat
--     is heard, so the run used to die via the PRE-EXISTING refuel distress
--     path and never got near scuttle code at all - every assertion below
--     passed for a reason that had nothing to do with this feature. Deferring
--     the block until the "scuttle" chat is actually delivered models the
--     honest scenario (walled in by bedrock/lava by the time it is scuttled)
--     and lets startup, refuel and the listen window all proceed normally.
print("\n[14] abort safety: deposit chest unplaceable on any face -> scuttle drops nothing")
r = run(scuttleOpts({ { msg = "scuttle now" } },
                     { blockedFaces = { front = true, up = true, down = true },
                       blockFacesAfterChat = true }))
-- The positive anchor. Every assertion below this line is negative and would
-- also pass for a "scuttle" that was never implemented at all - this is the
-- one check that proves the abort path actually ran and deliberately chose
-- to keep the kit, rather than the command doing nothing whatsoever.
assertThat("the bot said it could not scuttle",
           saidAny(r, "cannot scuttle"), sentSummary(r))
assertThat("NOTHING dropped into the world", r.worldDrops == 0, "worldDrops=" .. r.worldDrops)
assertThat("no drops appear in the event log at all",
           countPrefix(r.eventLog, "drop:") == 0, logSummary(r.eventLog))
assertThat("chunk loader kept equipped (never touched)",
           indexOf(r.eventLog, "equipRight") == nil, logSummary(r.eventLog))
assertThat("startup.lua NOT deleted", r.files["startup.lua"] ~= nil,
           "startup.lua=" .. tostring(r.files["startup.lua"]))
assertThat("did NOT shut down", r.shutdown ~= true, "shutdown=" .. tostring(r.shutdown))

-- 15. AUTHORISATION. Anyone else on the server saying "scuttle" must be a
--     no-op, or any player could abandon the kit.
--
--     A run of negative assertions alone cannot distinguish "correctly
--     refused the stranger" from "scuttle does not exist for anyone yet" -
--     both look identical from outside. The fix is a CONTROL: the identical
--     "scuttle" message, identical options, but from SKAAAAL. That run has
--     to show the feature actually firing (shutdown, chest left placed) so
--     the contrast with the stranger's run is what proves authorisation is
--     the reason for the difference, not a missing feature.
print("\n[15] scuttle from anyone but SKAAAAL is ignored entirely")
local authorized = run(scuttleOpts({ { msg = "scuttle now" } }))       -- default who = SKAAAAL
assertThat("control: SKAAAAL's own command shuts the bot down",
           authorized.shutdown == true, "shutdown=" .. tostring(authorized.shutdown))
assertThat("control: SKAAAAL's own command leaves a chest placed",
           depositFace(authorized) ~= nil,
           "world: front=" .. tostring(authorized.world.front) ..
           " up=" .. tostring(authorized.world.up) .. " down=" .. tostring(authorized.world.down))

r = run(scuttleOpts({ { msg = "scuttle now", who = "someone_else" } }))
assertThat("the stranger's identical command does NOT shut the bot down",
           r.shutdown ~= true, "shutdown=" .. tostring(r.shutdown))
assertThat("the stranger's identical command leaves no chest placed",
           depositFace(r) == nil,
           "world: front=" .. tostring(r.world.front) .. " up=" .. tostring(r.world.up) ..
           " down=" .. tostring(r.world.down))
assertThat("startup.lua not deleted for the stranger", r.files["startup.lua"] ~= nil,
           "startup.lua=" .. tostring(r.files["startup.lua"]))

-- 16. CONFIRMATION WORD. AdvancedPeripherals strips the "$" before the event
--     fires (see chat_harness.lua [14]), so the bot cannot tell "$scuttle"
--     apart from SKAAAAL merely saying the word "scuttle" in conversation.
--     Without a confirmation word, one stray sentence irreversibly destroys
--     the turtle - so a BARE "scuttle" must be a no-op that asks for
--     confirmation, and only "scuttle now" may actually do it.
print("\n[16] a bare 'scuttle' asks for confirmation instead of scuttling")
r = run(scuttleOpts({ { msg = "scuttle" } }))
-- The positive anchor: the exact confirmation wording the contract requires.
-- Without this, every assertion below is negative and would pass just as
-- happily for a command that silently does nothing at all.
assertThat("replies asking for the confirmation word",
           saidAny(r, "say scuttle now"), sentSummary(r))
assertThat("no chest left placed", depositFace(r) == nil,
           "world: front=" .. tostring(r.world.front) .. " up=" .. tostring(r.world.up) ..
           " down=" .. tostring(r.world.down))
assertThat("NOTHING dropped into the world", r.worldDrops == 0, "worldDrops=" .. r.worldDrops)
assertThat("no drops appear in the event log at all",
           countPrefix(r.eventLog, "drop:") == 0, logSummary(r.eventLog))
assertThat("startup.lua still exists", r.files["startup.lua"] ~= nil,
           "startup.lua=" .. tostring(r.files["startup.lua"]))
assertThat("state.txt still exists", r.files["state.txt"] ~= nil,
           "state.txt=" .. tostring(r.files["state.txt"]))
assertThat("did NOT shut down", r.shutdown ~= true, "shutdown=" .. tostring(r.shutdown))
assertThat("chunk loader still on the right arm (never touched)",
           indexOf(r.eventLog, "equipRight") == nil, logSummary(r.eventLog))

-- The control: the identical message PLUS the confirmation word DOES
-- scuttle. The pair is what proves the difference is the confirmation word,
-- not the feature being absent altogether.
local confirmed = run(scuttleOpts({ { msg = "scuttle now" } }))
assertThat("control: 'scuttle now' does shut the bot down",
           confirmed.shutdown == true, "shutdown=" .. tostring(confirmed.shutdown))

print("\n" .. string.rep("=", 64))
print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
