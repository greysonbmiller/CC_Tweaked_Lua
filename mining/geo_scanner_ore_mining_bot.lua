
-- PERIPHERAL SLOTS - both are spoken for, permanently.
--
-- RIGHT: chunk loader. Reserved. Never unequip it while the bot is running.
--   Away from a player the chunk loader is the only thing keeping the chunk
--   loaded, so unequipping it unloads the chunk, kills the running program and
--   strands the bot where it stands until someone walks out to it.
-- LEFT:  time-shared three ways - diamond pickaxe (digReady), geo scanner
--   (scanReady) and chat box (chat). Only one is attached at a time.
--
-- Consequence: there is no free slot for a permanently-attached listener, so
-- the bot cannot sit and wait on chat or rednet events. Anything sent to it
-- while the relevant peripheral is stowed is lost, not queued.
--
--
-- TWO RULES THIS FILE IS BUILT AROUND
--
-- 1. NOTHING IS EVER DROPPED INTO THE WORLD.
--    turtle.drop() into thin air RETURNS TRUE and throws the items on the
--    ground. Underground that means they scatter down a ravine or burn in lava,
--    and the return value gives no hint it happened. So there is not one bare
--    turtle.drop() in this file. Every item that leaves the turtle goes through
--    withContainer(), which places a chest, CONFIRMS with peripheral.wrap that
--    a real inventory is there, and only then hands the caller a drop function.
--    If no face works, the items stay in the turtle and the bot stops. Holding
--    ore is always recoverable; throwing it never is.
--
-- 2. THE BOT CAN BE RESTARTED AT ANY MOMENT.
--    A server crash reboots the computer. Inventory, fuel, position and
--    equipped upgrades survive; Lua state does not. So progress lives in
--    state.txt, written BEFORE each world-changing action and cleared after,
--    and startup reconciles against what it can actually observe rather than
--    assuming it is parked at base. The old code assumed base unconditionally
--    and opened by dropping all sixteen slots - which, restarted in a cave,
--    threw the entire kit down a hole.

-- WHICH ORES THE BOT LOOKS FOR
--
-- The bot targets ANY NUMBER of block ids at once, not a fixed pair. This list
-- is only the starting point for a turtle with no state file; from then on the
-- selection lives in state.txt, so a reboot keeps whatever was last chosen
-- rather than silently reverting to this line three days into a run.
--
-- There is no name-to-id table anywhere in this file, on purpose. The turtle
-- has no block registry, so a mistyped id can never be rejected - it just
-- matches nothing, quietly, forever. Instead the bot records the ids the
-- scanner really returns (see ores.txt below) and you pick from those, so an
-- id can only be selected if it has actually been observed to exist.
local DEFAULT_TARGETS = {
    "minecraft:lapis_ore",
    "minecraft:deepslate_lapis_ore",
}

-- How long warpPlate() leaves the warp plate on the ground for you to reach it.
-- The announcement text is built from this number, so the two can never drift
-- apart again - previously the bot said "30 seconds" while the pause itself was
-- commented out, so the plate was down for about two seconds and you could not
-- possibly get to it. warpPlate() runs every 4th cycle (see the main loop).
local WARP_HOLD_SECONDS = 30

-- HOW MANY MINISCANS MAY FOLLOW ONE WIDE SCAN
--
-- scan_loop() chases ore for as long as it keeps finding some. refuel(),
-- deposit() and the warp announce all live AFTER scan_loop in the main loop, so
-- a vein that never runs out meant none of them ever ran: the bot burned fuel
-- seeking ore, filled its loot slots, went silent, and would eventually strand
-- itself - all while apparently working perfectly. Measured against the real
-- file: 3,999 scans, zero announces, zero refuels.
--
-- Targeting several common ores at once makes this far likelier than it was
-- when the bot hunted a single rare ore, so the chain is now bounded.
--
-- Ore left behind is not lost. The next cycle's wide scan picks the vein back
-- up, and the bot only moves 15 blocks between cycles.
local MAX_MINISCANS = 25

-- Below this, break out of a scan chain and refuel rather than chasing one more
-- ore, so a rich vein cannot outrun the refuel schedule even within one bounded
-- cycle. A full move() is 15 blocks and seeking costs more, so this leaves a
-- wide margin over what a single cycle can burn.
local FUEL_FLOOR = 500

-- WARP PLATES ARE DISABLED. Do not turn this on without reading why.
--
-- Waystones' WaystoneBlockBase.setPlacedBy() syncs waystone data to whoever
-- placed the block. A turtle acts through a fake player that carries the owner's
-- identity but has NO network connection, so the channel lookup dereferences
-- null and throws inside the server tick. That does not kill the turtle - it
-- kills THE SERVER:
--
--   TurtlePlaceCommand.doDeployOnBlock -> BlockItem.place
--     -> WaystoneBlockBase.setPlacedBy -> WaystoneSyncManager.sendWaystoneGroups
--       -> BalmNetworking.sendTo -> NetworkRegistry.hasChannel
--         -> ChannelAttributes.getPayloadSetup   *** crash ***
--
-- And because startup.lua relaunches this program on boot, the world crashes
-- again the moment the turtle ticks: an unrecoverable crash loop that has to be
-- broken by deleting startup.lua from the save on disk.
--
-- Observed on Waystones 21.1.37 / Balm 21.0.63 / NeoForge 21.1.241 / MC 1.21.1
-- with CC:Tweaked 1.120.0. It worked on an older combination, so it is a
-- regression somewhere in that stack rather than anything inherent - but until
-- it is confirmed fixed, THE BOT MUST NOT PLACE A PLATE. Placing one costs the
-- whole server; not placing one costs only the rescue mechanism.
--
-- The cost is real and worth stating plainly: with this off, a bot that halts
-- in the field cannot be reached. distress() now says so honestly instead of
-- promising a rescue it cannot deliver.
local WARP_PLATE_ENABLED = false

-- Staging map: what the turtle pulls out of the chest in front of it, and which
-- slot each thing goes to. Keys are matched against an item's display name
-- first, then its item id, then its NBT hash.
--
-- ALL THREE CHESTS ARE ENDERSTORAGE ENDER CHESTS, on three different
-- frequencies. That is why they share one item id and differ only in NBT - the
-- frequency lives in the NBT - and it is why the code can place a chest, use it
-- and break it again a moment later without losing anything: the contents live
-- in the ender network, not in the block. Consequences worth knowing:
--   * deposit() sends loot home instantly, from any distance or dimension.
--   * refuel() draws from home, so the bot can be restocked mid-run without
--     anyone travelling to it.
--   * The DEPOSIT chest is drained into an ME system at home. It is a one-way
--     exit, NOT a scratch container - anything put in is gone the moment it
--     lands, so it can never be used to park items and pick them up again.
--
-- THE THREE CHESTS ARE MATCHED BY NBT HASH, and must be. Do NOT switch back to
-- matching them by display name. That was tried and it failed: this server
-- strips anvil names, and once stripped all three report the identical display
-- name "Ender Chest". Since display name is tried FIRST, a single
-- ["Ender Chest"] key would send whichever chest came out of the supply chest
-- first to that slot and leave the other two unstaged - after which refuel()
-- places nothing, sucks nothing, and the bot runs its fuel to zero and strands
-- wherever it happens to be standing.
--
-- The hashes below are derived from the FREQUENCY, not from the item stack, so
-- they survive name-stripping and are stable across relogs and restarts
-- (confirmed by running the probe before and after a restart and diffing).
-- They change only if a chest is re-keyed to a different frequency; if that
-- happens, re-run mining/ender_chest_probe.lua to read the new ones.
--
-- THE FREQUENCY IS THE THREE COLOURED DOTS on the front of the chest, so you
-- can identify any of these by eye, with the chest in your hand, without
-- running anything:
--
--     Warp      blue  / white / white   -> slot 11
--     Deposit   black / black / black   -> slot 14   (the default frequency)
--     Refuel    red   / white / white   -> slot 16
--
-- Those dots are also how you CHECK the table below. The hash-to-slot pairing
-- was taken from the order the chests happened to be loaded into the supply
-- chest, and a Deposit/Refuel swap is the one mistake none of the runtime
-- guards can catch: loot would be sent to the fuel frequency, refuel() would
-- suck ore instead of coal, the fuel level would not rise, and the bot would
-- deploy a warp point and stop a very long way from home. Nothing would be
-- lost, but the run would be over. Worth comparing the dots against this table
-- before sending it out for a long shift.
item_table = {
     -- Ender chests, keyed by frequency NBT hash. Read off the probe on
     -- day 193, in the name-stripped state, loaded Warp -> Deposit -> Refuel.
     ["059ada3ad2e70e2bc43dcd9eeb0f95ca"] = 11,               -- Warp    blue/white/white   - receives the activated warp stone
     ["470db3a18c6e1b98f579261f3bce12ef"] = 14,               -- Deposit black/black/black  - mined loot goes home (drained to ME)
     ["d4ac434678cee65f5c34a6abca08db6e"] = 16,               -- Refuel  red/white/white    - fuel comes from home
     -- Everything below is unique by item id and needs no NBT.
     ["mob_grinding_utils:absorption_hopper"] = 12,           -- vacuum hopper (item name)
     ["waystones:warp_plate"] = 13,                           -- warp plate (item name)
     ["advancedperipherals:geo_scanner"] = 15,                -- geo scanner (item name)
     ["advancedperipherals:chat_box"] = 10                    -- chat box (item name)
 }

-- Slot map. Nothing below refers to a slot by a bare number; change the layout
-- here and the whole file follows. Slots 1-9 are loot, everything else is kit.
local SLOT = {
    chat    = 10,
    warp    = 11,
    hopper  = 12,
    plate   = 13,
    deposit = 14,
    tool    = 15,   -- holds whichever tool is NOT currently on the left arm
    refuel  = 16,
}
local LOOT_FIRST, LOOT_LAST = 1, 9

local PICKAXE = "minecraft:diamond_pickaxe"
local SCANNER = "advancedperipherals:geo_scanner"
local ENDER   = "enderstorage:ender_chest"
local PLATE   = "waystones:warp_plate"
local HOPPER  = "mob_grinding_utils:absorption_hopper"

local PLAYER = "SKAAAAL"

local STATE_FILE = "state.txt"
local STATE_TMP  = "state.tmp"

-- The catalogue of ore ids the scanner has actually returned. See the block of
-- catalogue functions further down for why this exists.
local ORE_FILE = "ores.txt"
local ORE_TMP  = "ores.tmp"
local ORE_LIMIT = 500

-- How long withContainer waits for a just-placed container to show up as a
-- peripheral before believing it is not one. Five quarter-second retries.
local WRAP_RETRIES     = 5
local WRAP_RETRY_SLEEP = 0.25


----------------------------------------------------------------------------
-- Persistent state
----------------------------------------------------------------------------

-- deployed : has this bot already been staged and sent out? This is the single
--            fact that separates "first run, at base, safe to stage" from
--            "restarted in the field, do NOT touch the kit". Inferring it from
--            surroundings is what the old code got wrong.
-- phase    : what it was doing when it was last interrupted.
-- placed   : face -> slot for every block currently sitting in the world that
--            belongs to us. Written BEFORE placing and cleared after breaking,
--            so a crash mid-action leaves a record to clean up.
-- targets  : the block ids currently being mined. Persisted so that a reboot
--            resumes the selection instead of reverting to DEFAULT_TARGETS.
local state = { deployed = false, phase = "startup", cycles = 0, placed = {},
                targets = {} }

-- Membership set rebuilt from state.targets. The scan loop tests thousands of
-- blocks a minute, so this is a hash lookup rather than a walk down a list.
local TARGETS = {}

--- Point the bot at a set of block ids. Returns the list actually adopted.
---
--- Anything without a namespace colon is dropped: it cannot be a block id, and
--- letting it through would mean silently mining nothing. An empty result falls
--- back to DEFAULT_TARGETS rather than leaving the bot with nothing to look
--- for, since a bot targeting nothing walks and burns fuel forever.
local function setTargets(list)
    local clean, seen = {}, {}
    for _, id in ipairs(list or {}) do
        if type(id) == "string" and id:find(":", 1, true) and not seen[id] then
            seen[id] = true
            clean[#clean + 1] = id
        end
    end
    if #clean == 0 then
        for _, id in ipairs(DEFAULT_TARGETS) do clean[#clean + 1] = id end
    end
    state.targets = clean
    TARGETS = {}
    for _, id in ipairs(clean) do TARGETS[id] = true end
    return clean
end

setTargets(DEFAULT_TARGETS)

-- Write to a scratch file and swap it in, rather than writing over the live one.
--
-- fs.open(path, "w") truncates immediately, so writing in place leaves a window
-- the whole length of the write in which state.txt is empty or half-formed. A
-- crash there used to read back as "no state" - which meant "first run", which
-- meant staging and cleaning IN A CAVE. The record of being deployed is the one
-- fact this program cannot afford to lose, so it is never overwritten directly.
local function saveState()
    if not fs then return false end
    local f = fs.open(STATE_TMP, "w")
    if not f then return false end
    f.write(textutils.serialize(state))
    f.close()
    if fs.exists(STATE_FILE) then fs.delete(STATE_FILE) end
    fs.move(STATE_TMP, STATE_FILE)
    return true
end

local function readFile(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local raw = f.readAll()
    f.close()
    return raw
end

local function loadState()
    if not fs then return false end

    -- Prefer the live file; fall back to the scratch file, which is what
    -- survives a crash in the one-operation window between delete and move.
    local raw = readFile(STATE_FILE)
    if raw == nil or raw == "" then
        raw = readFile(STATE_TMP)
    end
    if raw == nil then
        return false                     -- genuinely nothing: a real first run
    end

    local data = textutils.unserialize(raw)
    if type(data) ~= "table" then
        -- A state file EXISTS but will not parse, so this bot has been deployed
        -- at some point and the write was interrupted. Do NOT fall through to
        -- "first run": staging in the field is the disaster this whole file is
        -- built to avoid, whereas wrongly resuming while parked at base costs
        -- nothing. When in doubt, assume deployed.
        print("State file is corrupt - assuming DEPLOYED and resuming.")
        state.deployed = true
        state.phase    = "unknown"
        state.cycles   = 0
        state.placed   = {}
        setTargets(DEFAULT_TARGETS)
        return true
    end

    state.deployed = data.deployed and true or false
    state.phase    = data.phase or "startup"
    state.cycles   = tonumber(data.cycles) or 0
    state.placed   = type(data.placed) == "table" and data.placed or {}
    setTargets(type(data.targets) == "table" and data.targets or DEFAULT_TARGETS)
    return true
end

local function setPhase(phase)
    state.phase = phase
    saveState()
end


----------------------------------------------------------------------------
-- The ore catalogue
----------------------------------------------------------------------------

-- The turtle cannot ask "is minecraft:diamnod_ore a real block?" - there is no
-- registry to ask. So a typo cannot be rejected; it just matches nothing and
-- the bot mines air for an hour. This replaces that missing registry with
-- observation: every ore-like id the scanner really returns is written down,
-- and ids are chosen from that list. An id can only be picked if the bot has
-- seen one with its own scanner.
--
-- APPEND-ONLY. An entry's position is the handle used to pick it, so entries
-- must never be reordered or removed - a number written down during one warp
-- window has to still mean the same ore at the next one.
local catalogue = {}          -- ordered ids, index = pick number
local catalogueSet = {}       -- id -> its pick number, for O(1) lookups

-- The most recent scan result, kept so the warp-window announce can say what is
-- visible without swapping the scanner back onto the arm. During the window the
-- chat box is equipped, and swapping it off to scan would drop any message sent
-- in the meantime.
local lastScan = {}

-- Pull the id out of a catalogue line, whatever else is on it. Matching the
-- namespaced token rather than the whole line means the file can carry pick
-- numbers and comments without the parser caring.
local function idFromLine(line)
    if line:match("^%s*#") then return nil end
    return line:match("([%w_%-%.]+:[%w_%-%./]+)")
end

-- Ore-like, rather than everything. Recording every block would bury the list
-- under stone and deepslate within one scan. Kept deliberately loose: an ore
-- this misses is invisible to the picker, so a few odd blocks slipping in costs
-- far less than one real ore being excluded. Widen it freely.
local function looksLikeOre(name)
    return name:find("_ore") ~= nil
        or name:find("ore_") ~= nil
        or name:match("ore$") ~= nil
        or name:find("debris") ~= nil
        or name:find("raw_") ~= nil
end

local function loadCatalogue()
    catalogue, catalogueSet = {}, {}
    local raw = readFile(ORE_FILE)
    if not raw then return end
    for line in raw:gmatch("[^\r\n]+") do
        local id = idFromLine(line)
        if id and not catalogueSet[id] then
            catalogue[#catalogue + 1] = id
            catalogueSet[id] = #catalogue
        end
    end
end

local function saveCatalogue()
    local f = fs.open(ORE_TMP, "w")
    if not f then return false end
    f.write("# Ore blocks this turtle has scanned, in the order it first saw\n")
    f.write("# them. Pick by the number on the left:   $ore 3 7\n")
    for i, id in ipairs(catalogue) do
        f.write(string.format("%d\t%s\n", i, id))
    end
    f.close()
    if fs.exists(ORE_FILE) then fs.delete(ORE_FILE) end
    fs.move(ORE_TMP, ORE_FILE)
    return true
end

--- Fold one scan result into the catalogue. Returns true if anything was new.
---
--- Written ONLY when the set actually grew. scan_loop scans in a tight loop, so
--- saving every time would rewrite the file several times a second to say the
--- same thing. New discoveries tail off quickly once the bot settles into an
--- area, so in practice this writes a few times on arriving somewhere new and
--- then goes quiet.
local function recordScan(scan_data)
    local grew = false
    for _, b in pairs(scan_data) do
        local name = b.name
        if type(name) == "string" and not catalogueSet[name] and looksLikeOre(name) then
            if #catalogue >= ORE_LIMIT then break end
            catalogue[#catalogue + 1] = name
            catalogueSet[name] = #catalogue
            grew = true
        end
    end
    if grew then saveCatalogue() end
    return grew
end

-- Names were once shortened to "deepslate_lapis_ore" so several would fit on a
-- chat row. Everything is one-per-line now, so the full id is always printed:
-- it is the exact string you would retype, and abbreviating it only ever served
-- the packing that no longer happens.

--- Ores from the most recent scan that have a pick number, most useful first.
--- These are the ones within reach of where the bot is standing right now,
--- which is exactly the set worth offering at a warp window.
local function visibleOres()
    local seen, out = {}, {}
    for _, b in pairs(lastScan) do
        local name = b.name
        if type(name) == "string" and catalogueSet[name] and not seen[name] then
            seen[name] = true
            out[#out + 1] = { n = catalogueSet[name], id = name }
        end
    end
    table.sort(out, function(a, b) return a.n < b.n end)
    return out
end

local function notePlaced(slot, face)
    state.placed[face] = slot
    saveState()
end

local function noteRemoved(face)
    state.placed[face] = nil
    saveState()
end

-- Re-launch automatically after a reboot. Without this the rest is academic:
-- a server restart brings the computer back to an idle prompt and the bot sits
-- there with a perfectly good state file it never reads.
local function installStartup()
    if not fs or not shell then return end
    if fs.exists("startup.lua") then return end
    local this = shell.getRunningProgram()
    if not this then return end
    local f = fs.open("startup.lua", "w")
    if not f then return end
    f.write(string.format("shell.run(%q)\n", this))
    f.close()
    print("Installed startup.lua -> " .. this)
end


----------------------------------------------------------------------------
-- Faces
----------------------------------------------------------------------------

-- The turtle API spells every direction as a separate function. Grouping them
-- lets one piece of code try front, then up, then down without three copies of
-- itself - which is what makes the "somewhere else worked" fallback cheap.
local FACE = {
    front = { dig = turtle.dig,     place = turtle.place,
              inspect = turtle.inspect,     suck = turtle.suck,     drop = turtle.drop     },
    up    = { dig = turtle.digUp,   place = turtle.placeUp,
              inspect = turtle.inspectUp,   suck = turtle.suckUp,   drop = turtle.dropUp   },
    down  = { dig = turtle.digDown, place = turtle.placeDown,
              inspect = turtle.inspectDown, suck = turtle.suckDown, drop = turtle.dropDown },
}
local FACE_ORDER = { "front", "up", "down" }


----------------------------------------------------------------------------
-- Inventory helpers
----------------------------------------------------------------------------

-- The plain form of getItemDetail does not carry the NBT hash, and the ender
-- chests can only be told apart by it. Ask for the detailed form, but survive
-- a CC build that does not accept the second argument.
local function detail(slot)
    local ok, d = pcall(turtle.getItemDetail, slot, true)
    if ok and d then return d end
    return turtle.getItemDetail(slot)
end

local function findItem(name)
    for i = 1, 16 do
        local d = turtle.getItemDetail(i)
        if d and d.name == name then return i end
    end
    return nil
end

local function firstEmptySlot()
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then return i end
    end
    return nil
end

-- Where does whatever is in `slot` belong? Ender chests answer on NBT, every
-- other staged item answers on item id.
local function homeSlotFor(slot)
    local d = detail(slot)
    if not d then return nil end
    return (d.nbt and item_table[d.nbt]) or item_table[d.name]
end

-- Put one slot's contents where item_table says they go. Used both after
-- staging and after digging a block back out of the world, which is why it has
-- to work from the item itself rather than from any remembered position.
local function sortSlot(slot)
    local target = homeSlotFor(slot)
    if not target or target == slot then return false end
    if turtle.getItemCount(target) > 0 then return false end
    turtle.select(slot)
    return turtle.transferTo(target)
end


----------------------------------------------------------------------------
-- Tools
----------------------------------------------------------------------------

-- equipLeft swaps the selected slot with whatever is on the left arm, so
-- "equip X" is: find X in the inventory, select it, swap. If X is not in the
-- inventory it is already on the arm and there is nothing to do.
local function equipLeft(name)
    local slot = findItem(name)
    if not slot then return false end
    turtle.select(slot)
    turtle.equipLeft()
    turtle.select(1)
    return true
end

local function digReady()
    equipLeft(PICKAXE)
end

local function scanReady()
    equipLeft(SCANNER)
    p = peripheral.wrap("left")
    return p
end

--- Put the chat box on, run `action(send)`, and take it back off again.
---
--- Everything that talks goes through here so that one equip covers a whole
--- conversation. The warp announce alone is several lines, and the old code
--- swapped the arm twice per message.
---
--- Nothing in here is allowed to throw. sendMessageToPlayer fails when the
--- recipient is not logged in, which for an unattended bot is most of the time,
--- and an error escaping this function during warpPlate() would end the run with
--- the plate already on the ground. Being unable to talk is not a reason to stop
--- mining.
local function withChatBox(action)
    if turtle.getItemCount(SLOT.chat) == 0 then return false end
    turtle.select(SLOT.chat)
    turtle.equipLeft()
    os.sleep(1)

    local box = peripheral.wrap("left")
    local ran = false
    if box and box.sendMessageToPlayer then
        local function send(message)
            pcall(box.sendMessageToPlayer, message, PLAYER)
        end
        ran = pcall(action, send)
    end

    turtle.select(SLOT.chat)
    turtle.equipLeft()
    turtle.select(1)
    return ran
end

local function chat(message)
    return withChatBox(function(send) send(message) end)
end


----------------------------------------------------------------------------
-- Remote ore selection
----------------------------------------------------------------------------

-- Commands are only heard during the warp window (see warpWindow). Both
-- peripheral slots are permanently spoken for, so nothing can sit attached
-- waiting for events, and a message sent while the chat box is stowed is lost
-- rather than queued. The window rides the hold warpPlate() already takes: the
-- one moment the bot is idle, already announcing itself, and has a reason to be
-- wearing the chat box.

local CHAT_PREFIX = "$"        -- AdvancedPeripherals' hidden-message prefix:
                               -- these reach chat boxes without appearing in
                               -- public chat.
-- Whether the announce spells out the pick list every window. Three lines every
-- fourth cycle adds up if you are not using it; set false for the single line.
local ANNOUNCE_MENU = true

--- Resolve one token of a $ore command to a block id.
--- A number indexes the catalogue. Anything containing a namespace colon is
--- taken literally, which is the escape hatch for an ore the bot has not
--- scanned yet - without it, a missing catalogue entry would mean editing this
--- file while the turtle is ten thousand blocks away.
--- Returns id, wasLiteral.
local function resolvePick(token)
    local n = tonumber(token)
    if n then return catalogue[n], false end
    if token:find(":", 1, true) then return token, true end
    return nil, false
end

--- One ore per chat line. Packing several onto a line saved messages but made
--- the list unreadable in the chat window, and reading a number off it wrongly
--- is the mistake this whole catalogue exists to prevent.
local function listCatalogue(send)
    if #catalogue == 0 then
        send("I have not catalogued any ores yet - I write them down as I scan them.")
        return
    end
    send(string.format("%d ores scanned so far:", #catalogue))
    for i, id in ipairs(catalogue) do
        send(string.format("%d  %s", i, id))
    end
    send(string.format("Pick with %sore <numbers>, e.g. %sore 1 3",
                       CHAT_PREFIX, CHAT_PREFIX))
end

--- Full ids, deliberately: this is the confirmation that what got selected is
--- what was meant, so it is the one place worth spending the characters.
local function reportTargets(send)
    local visible = 0
    for _, b in pairs(lastScan) do
        if b.name and TARGETS[b.name] then visible = visible + 1 end
    end
    send("Mining: " .. table.concat(state.targets, ", "))
    send(string.format("%d of those visible in my last scan.", visible))
end

--- Apply a $ore command.
---
--- An unscanned id is accepted rather than refused - the bot may simply not
--- have stood near one yet - but it is called out, because it is the only input
--- that cannot be checked against anything. There is no block registry to ask,
--- so a typo can never be rejected; it just matches nothing, quietly, for as
--- long as the bot is left running.
local function selectOres(rest, send)
    local picked, unknown, unseen = {}, {}, {}
    for token in rest:gmatch("[^%s,]+") do
        local id, literal = resolvePick(token)
        if not id then
            unknown[#unknown + 1] = token
        else
            picked[#picked + 1] = id
            if literal and not catalogueSet[id] then unseen[#unseen + 1] = id end
        end
    end

    if #unknown > 0 then
        send(string.format("I do not know %s. Say %sores for the %d I have found.",
                           table.concat(unknown, ", "), CHAT_PREFIX, #catalogue))
    end
    if #picked == 0 then return false end

    setTargets(picked)
    saveState()
    reportTargets(send)
    if #unseen > 0 then
        send("Careful: I have never scanned " .. table.concat(unseen, ", ") ..
             ". Set anyway, but check the spelling if nothing turns up.")
    end
    return true
end

--- Returns true if this was a command from the owner. Anyone else on the server
--- is ignored outright - otherwise any player could retask the bot.
--- Returns true if this was a command from the owner. Anyone else on the server
--- is ignored outright - otherwise any player could retask the bot.
---
--- The name is compared case-insensitively; being deaf over capitalisation is
--- not a defensible failure when the only symptom is silence.
---
--- THE PREFIX ARRIVES STRIPPED. You type "$ore 3", AdvancedPeripherals treats
--- the $ as its hidden-message marker - which is what keeps the command out of
--- public chat - and fires the event with just "ore 3". Confirmed with
--- chat_box_probe.lua. So the prefix cannot be required, and equally cannot be
--- used to tell a command from conversation, because it is never there.
---
--- Commands are recognised by SHAPE instead. "ore 3" and "ore 99" are commands
--- because the first argument looks like a pick; "ore is the best" is not, and
--- is ignored in silence. That distinction matters in both directions: without
--- it the bot either answers back at ordinary conversation, or - worse - goes
--- quiet on a mistyped pick number, which is exactly when you need to be told.
local function looksLikePick(token)
    return token ~= nil
       and (tonumber(token) ~= nil or token:find(":", 1, true) ~= nil)
end

local function handleCommand(who, message, send)
    if type(who) ~= "string" or type(message) ~= "string" then return false end
    if who:lower() ~= PLAYER:lower() then return false end

    local body = message:match("^%s*%" .. CHAT_PREFIX .. "(.*)$")
    local prefixed = body ~= nil
    if not body then body = message:match("^%s*(.-)%s*$") end
    if not body or body == "" then return false end

    local verb, rest = body:match("^(%S+)%s*(.*)$")
    if not verb then return false end
    verb = verb:lower()

    if verb == "ores" then
        -- Bare "ores" is a command; "ores are great" is a sentence.
        if rest ~= "" and not prefixed then return false end
        listCatalogue(send)
    elseif verb == "ore" then
        if rest == "" then
            reportTargets(send)
        elseif prefixed or looksLikePick(rest:match("^([^%s,]+)")) then
            selectOres(rest, send)
        else
            return false
        end
    elseif prefixed then
        send(string.format("I only understand %sore and %sores.",
                           CHAT_PREFIX, CHAT_PREFIX))
    else
        return false                       -- ordinary conversation; stay quiet
    end
    return true
end

-- At most this many visible ores are offered in an announce. The announce fires
-- every fourth cycle whether or not anyone is reading it, and with one ore per
-- line an unbounded list would be a wall of chat. $ores has no such cap.
local ANNOUNCE_VISIBLE_MAX = 8

--- The part of an announce that is the same whoever opened the window: what is
--- being mined, what is worth picking here, and how to pick it.
---
--- One ore per line throughout, matching $ores. Full ids rather than shortened
--- ones now that each has a line to itself: the exact id is what you would
--- retype, and abbreviating it was only ever a way to fit several on a row.
local function announceMenu(send)
    send("Mining:")
    for _, id in ipairs(state.targets) do
        send("  " .. id)
    end
    if not ANNOUNCE_MENU then return end

    -- What is in reach of where the bot is standing, which is the set actually
    -- worth picking from here. The full catalogue can run to hundreds and stays
    -- behind $ores.
    local vis = visibleOres()
    if #vis > 0 then
        send("Visible here:")
        for i, v in ipairs(vis) do
            if i > ANNOUNCE_VISIBLE_MAX then
                send(string.format("  ...and %d more, say %sores",
                                   #vis - ANNOUNCE_VISIBLE_MAX, CHAT_PREFIX))
                break
            end
            send(string.format("  %d  %s", v.n, v.id))
        end
    end
    send(string.format("Pick with %sore <numbers> - %sores lists all %d I have found.",
                       CHAT_PREFIX, CHAT_PREFIX, #catalogue))
end

--- Open a listening window: announce, then take commands until the time is up.
---
--- os.sleep() CANNOT be used here. It is implemented as pull-events-until-my-
--- timer, and os.pullEvent(filter) discards everything that does not match, so
--- every chat message arriving during the hold would be pulled off the queue
--- and thrown away. The window would look right and hear nothing.
local function listenWindow(headline)
    local listened = withChatBox(function(send)
        send(headline)
        announceMenu(send)
        local deadline = os.startTimer(WARP_HOLD_SECONDS)
        while true do
            local event, a, b = os.pullEvent()
            if event == "timer" and a == deadline then
                break
            elseif event == "chat" then
                -- Printed unconditionally, before any filtering. If commands
                -- are not working, this is the line that says whether the
                -- event is arriving at all - which separates "the bot cannot
                -- hear you" from "the bot heard you and rejected it".
                print(string.format("chat [%s]: %s", tostring(a), tostring(b)))
                handleCommand(a, b, send)
            end
        end
        send("The bot has resumed!")
    end)

    -- No chat box, or it would not equip. The hold still has to happen: someone
    -- may be walking towards the plate right now.
    if not listened then os.sleep(WARP_HOLD_SECONDS) end
end

-- Drive the left arm back to a known state after a restart. Whatever the bot
-- was holding when the server died, it comes back holding the pickaxe with the
-- scanner stowed - which is what every other function assumes.
local function normalizeTools()
    -- If a peripheral is attached, it is the scanner or the chat box; swap it
    -- off into a free slot so the pickaxe can go on.
    if peripheral.getType("left") then
        local free = firstEmptySlot() or SLOT.tool
        turtle.select(free)
        turtle.equipLeft()
    end
    -- Send the scanner and chat box back to their slots wherever they landed.
    for i = 1, 16 do
        sortSlot(i)
    end
    digReady()
    turtle.select(1)
end


----------------------------------------------------------------------------
-- The only way items leave the turtle
----------------------------------------------------------------------------

--- Place the container from `slot`, prove it is a real inventory, run `action`,
--- then break the container and take it back.
---
--- action(f, face, slot) is handed the face's function table, so it drops with
--- f.drop() and sucks with f.suck() without caring which direction it got.
---
--- Tries front, then up, then down. A lava pool or an unbreakable block in
--- front no longer costs a cycle. `faces` narrows that list - warpPlate passes
--- {"up","down"} so the fallback cannot dig up the warp plate it just placed.
---
--- Returns false having moved NOTHING if no face worked. Callers must treat
--- that as "keep the items", never as "drop them anyway".
local function withContainer(slot, action, faces)
    faces = faces or FACE_ORDER
    if turtle.getItemCount(slot) == 0 then return false end

    for _, face in ipairs(faces) do
        local f = FACE[face]
        f.dig()                       -- best effort; failure is fine
        turtle.select(slot)
        if f.place() then
            notePlaced(slot, face)
            -- The confirmation that makes this whole file safe. Air wraps as
            -- nil, so there is no way to drop into nothing from here.
            --
            -- But a block that WAS just placed does not attach as a peripheral
            -- the instant place() returns - the block entity has to come up and
            -- CC has to notice it. Wrapping once and reading nil as "that is not
            -- an inventory" dug perfectly good ender chests straight back up,
            -- tried the next face, failed the same way, and reported "could not
            -- place on any face" at a turtle with room all around it. On the
            -- refuel path that failure calls distress(), so a timing hiccup
            -- became a halted bot.
            --
            -- Since place() only succeeds here when OUR container went down, a
            -- persistent nil means something is genuinely wrong; the retries
            -- cost nothing in the normal case because the first wrap works.
            local inv = peripheral.wrap(face)
            for _ = 1, WRAP_RETRIES do
                if inv then break end
                os.sleep(WRAP_RETRY_SLEEP)
                inv = peripheral.wrap(face)
            end
            if inv then
                local ok = action(f, face, slot)
                turtle.select(slot)
                f.dig()
                noteRemoved(face)
                turtle.select(1)
                return ok ~= false, face
            end
            -- Placed something that is not an inventory. Take it back and move
            -- on rather than dropping beside it.
            turtle.select(slot)
            f.dig()
            noteRemoved(face)
        end
    end
    turtle.select(1)
    return false
end

-- Failure at BASE. There is a player and a supply chest right here, so saying
-- so and stopping is the whole job. Do not use this in the field - see
-- distress() below for why.
local function abort(what, why)
    print("")
    print(what)
    print(why)
    -- pcall: a warning must never crash ahead of the halt it is warning about.
    pcall(chat, what)
    error(what .. " " .. why, 0)
end

--- Put a warp point on the ground and send the warp stone home.
---
--- Returns the face the plate went on (nil if it could not be placed), plus
--- whether the stone made it into the warp chest. Callers do their own
--- announcing and their own hold, because the normal cycle wants the plate back
--- afterwards and a distress call does not.
local function deployWarpPoint()
    if not WARP_PLATE_ENABLED then return nil, false end
    if turtle.getItemCount(SLOT.plate) == 0 then return nil, false end

    turtle.select(1)
    FACE.front.dig()
    FACE.up.dig()

    -- Front for preference, floor as a fallback. Never up: the hopper pass
    -- needs that face, and a plate overhead is no use to anyone anyway.
    local plateFace = nil
    for _, face in ipairs({ "front", "down" }) do
        FACE[face].dig()
        turtle.select(SLOT.plate)
        if FACE[face].place() then
            plateFace = face
            notePlaced(SLOT.plate, face)
            break
        end
    end
    if not plateFace then return nil, false end

    -- Hopper pass. KEPT deliberately. It looks like a net for items scattered
    -- on the ground, which this file no longer creates - but the original code
    -- calls slot 11 "the chest for the activated warp stone" and fills it from
    -- whatever the hopper picked up. That means something real is being
    -- collected off the floor here, and removing it would quietly break the one
    -- mechanism that lets you reach the bot. Sucking into the turtle costs
    -- nothing, so it stays until the mod behaviour is confirmed either way.
    if turtle.getItemCount(SLOT.hopper) > 0 then
        turtle.select(1)
        FACE.up.dig()
        turtle.select(SLOT.hopper)
        if FACE.up.place() then
            notePlaced(SLOT.hopper, "up")
            turtle.down()
            os.sleep(1)
            turtle.up()
            for i = LOOT_FIRST, LOOT_LAST do
                turtle.select(i)
                FACE.up.suck()
            end
            turtle.select(SLOT.hopper)
            FACE.up.dig()
            noteRemoved("up")
        end
    end

    -- The warp chest is what actually gets the stone to you - it is an ender
    -- chest, so the contents are home the instant they land and the block can
    -- be picked straight back up. Never on the plate's own face.
    local chestFaces = {}
    for _, face in ipairs(FACE_ORDER) do
        if face ~= plateFace then chestFaces[#chestFaces + 1] = face end
    end
    local sent = withContainer(SLOT.warp, function(f)
        for i = LOOT_FIRST, LOOT_LAST do
            if turtle.getItemCount(i) > 0 then
                turtle.select(i)
                f.drop()
            end
        end
        return true
    end, chestFaces)

    turtle.select(1)
    return plateFace, sent
end

local function recoverWarpPlate(plateFace)
    if not plateFace then return end
    turtle.select(SLOT.plate)
    FACE[plateFace].dig()
    noteRemoved(plateFace)
    turtle.select(1)
end

--- Failure in the FIELD, thousands of blocks from anyone.
---
--- Telling you to come and collect the bot is worthless unless there is
--- something to come to: the plate has to be on the ground and the warp stone
--- has to reach you. So deploy a warp point FIRST, then halt - and leave the
--- plate down, because the bot is not going to need it again.
---
--- If the plate cannot be placed, say that plainly instead. A bot that claims
--- to be reachable when it is not is worse than one that admits it is lost.
local function distress(what, why)
    print("")
    print(what)
    print(why)
    pcall(chat, what .. " " .. why)

    local ok, plateFace, sent = pcall(deployWarpPoint)
    local msg
    if not WARP_PLATE_ENABLED then
        -- Do not say "I could not place a plate", which reads as a failure to
        -- be investigated. Nothing was attempted: placing one crashes the
        -- server, so the rescue mechanism is switched off on purpose.
        msg = "Warp plates are OFF (placing one crashes the server), so I cannot " ..
              "leave you a way to reach me. Note where I am."
    elseif ok and plateFace then
        msg = sent
            and "Warp plate is DOWN and the warp stone is on its way to you - come and get me."
            or  "Warp plate is DOWN, but I could not send the warp stone home."
    else
        msg = "I could NOT place a warp plate - there is no way to reach me from here."
    end
    print(msg)
    pcall(chat, msg)

    error(what .. " " .. why, 0)
end


----------------------------------------------------------------------------
-- Cycle operations
----------------------------------------------------------------------------

-- Send the loot home. The deposit chest is an EnderStorage chest drained into
-- the ME system, so this is instant and works from any distance or dimension -
-- and breaking the block afterwards loses nothing, because the items were never
-- in the block to begin with.
local function deposit()
    digReady()
    setPhase("depositing")
    local ok = withContainer(SLOT.deposit, function(f)
        for i = LOOT_FIRST, LOOT_LAST do
            if turtle.getItemCount(i) > 0 then
                turtle.select(i)
                f.drop()
            end
        end
        return true
    end)
    if not ok then
        distress("Could not place the deposit chest on any face.",
                 "Holding the loot rather than throwing it away.")
    end
    setPhase("mining")
end

--- Is fuel low enough to stop what we are doing and go and get some?
---
--- getFuelLevel() returns the STRING "unlimited" when fuel is disabled
--- server-side, so this must not compare numerically without checking.
local function lowFuel()
    local f = turtle.getFuelLevel()
    return type(f) == "number" and f < FUEL_FLOOR
end

local function refuel()
    digReady()
    setPhase("refueling")
    local before = turtle.getFuelLevel()

    local ok = withContainer(SLOT.refuel, function(f, _, slot)
        turtle.select(slot)
        f.suck()
        os.sleep(1)
        turtle.refuel()
        -- Anything that was not burned goes back where it came from. Without
        -- this the slot is still full and the chest cannot be recovered into it.
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            f.drop()
        end
        return true
    end)
    if not ok then
        distress("Could not place the refuel chest on any face.",
                 "Stopping with the fuel I have rather than pressing on.")
    end

    fuel = turtle.getFuelLevel()
    print("Fuel Level is now... " .. tostring(fuel))

    -- Did it actually work? place(), suck() and refuel() all return false on
    -- failure and none of those returns were ever read by the old code, so the
    -- bot could take on nothing for cycle after cycle and only find out at zero.
    --
    -- Two legitimate reasons the level might not rise, neither of them a fault:
    --   * Fuel is disabled server-side and getFuelLevel() returns the STRING
    --     "unlimited" - comparing that numerically would throw.
    --   * The tank is already full, so there is nothing left to gain.
    if type(before) == "number" and type(fuel) == "number" then
        local limit = turtle.getFuelLimit()
        local isFull = type(limit) == "number" and fuel >= limit
        if fuel <= before and not isFull then
            -- The single most dangerous condition there is: still mobile now,
            -- immobile shortly. Spend some of the remaining fuel putting a warp
            -- point down while it can still be done.
            distress(string.format("REFUEL FAILED - fuel stuck at %d.", fuel),
                     "Stopping before I strand.")
        end
    end
    setPhase("mining")
end

local function move(distance)
    for _ = 1, distance do
        turtle.dig()
        turtle.digUp()
        turtle.forward()
    end
end

-- The scheduled every-4th-cycle warp point: same deployment a distress call
-- uses, but announced, held open long enough for you to walk in, and then
-- picked back up so the bot can carry on mining.
local function warpPlate()
    digReady()
    deposit()                    -- clear the loot slots first
    setPhase("warping")

    local plateFace, sent = deployWarpPoint()

    -- The listening window runs whether or not a plate went down. It used to be
    -- inside the success path, which meant that disabling warp plates silently
    -- disabled the only chance to retarget the bot as well - a config flag on
    -- one feature quietly switching off an unrelated one.
    print("pausing functionality - listening for commands")
    if plateFace then
        listenWindow(string.format("Warp plate is down%s - %d seconds to collect me.",
                                   sent and " and the warp stone is on its way to you" or "",
                                   WARP_HOLD_SECONDS))
    else
        listenWindow(string.format("Listening for %d seconds.", WARP_HOLD_SECONDS))
    end
    print("resuming functionality")

    if plateFace then recoverWarpPlate(plateFace) end
    setPhase("mining")
end


----------------------------------------------------------------------------
-- Startup reconciliation
----------------------------------------------------------------------------

-- Pick our own blocks back up off the ground. Runs from the state file first,
-- then sweeps every face regardless - a crash BETWEEN placing and writing
-- leaves no record, so the sweep is what covers that window.
local function recoverPlacedBlocks()
    local recovered = 0

    local function recoverFace(face)
        local f = FACE[face]
        local present, info = f.inspect()
        if not present or not info then return end
        if info.name ~= ENDER and info.name ~= PLATE and info.name ~= HOPPER then
            return
        end
        local free = firstEmptySlot()
        if not free then
            print("No free slot to recover " .. info.name .. " from " .. face)
            return
        end
        turtle.select(free)
        if f.dig() then
            -- Which ender chest did we just pick up? We cannot know until it is
            -- in hand and its NBT can be read - which is exactly what sortSlot
            -- does, so the bot re-files its own chests without being told.
            sortSlot(free)
            noteRemoved(face)
            recovered = recovered + 1
            print("Recovered " .. info.name .. " from " .. face)
        end
    end

    for face in pairs(state.placed) do recoverFace(face) end
    for _, face in ipairs(FACE_ORDER) do recoverFace(face) end

    turtle.select(1)
    if recovered > 0 then
        print("Recovered " .. recovered .. " placed block(s).")
    end
    state.placed = {}
    saveState()
end

-- Reconcile the inventory against item_table: everything that has a home slot
-- gets moved to it, then the three chests that stand between the bot and being
-- lost are checked. This REPLACES the old cleanTurtleInventory(), which
-- "normalised" the turtle by dropping all sixteen slots on the floor.
local function verifyKit()
    for i = 1, 16 do sortSlot(i) end
    turtle.select(1)

    local required = {
        { slot = SLOT.warp,    what = "warp ender chest"    },
        { slot = SLOT.deposit, what = "deposit ender chest" },
        { slot = SLOT.refuel,  what = "refuel ender chest"  },
    }
    local missing = {}
    for _, req in ipairs(required) do
        if turtle.getItemCount(req.slot) == 0 then
            missing[#missing + 1] = string.format("slot %d (%s)", req.slot, req.what)
        end
    end
    return missing
end


----------------------------------------------------------------------------
-- Staging (first run only)
----------------------------------------------------------------------------

local function runTurtleLogistics(item_mapping)
    digReady()
    setPhase("staging")
    print("Starting turtle logistics operation...")

    local chest = peripheral.wrap("front")
    if not chest then
        -- Two very different situations reach this line, and they need opposite
        -- responses. A genuine first run has the kit still sitting in the supply
        -- chest, so the turtle is empty and a player is standing right here. But
        -- a deployed bot whose state file was DELETED outright - not corrupt,
        -- so the parse check above cannot catch it - arrives here carrying a
        -- full kit, thousands of blocks from anyone. Carrying the warp plate is
        -- what tells the two apart, and the second one needs a warp point, not
        -- an instruction to go and stand somewhere.
        if turtle.getItemCount(SLOT.plate) > 0 then
            distress("No supply chest here, but I am carrying a full kit.",
                     "My state file must have been lost - deploying a warp point.")
        end
        abort("No supply chest in front of me.",
              "Park me facing the supply chest and run this again.")
    end

    -- turtle.suck() cannot be pointed at a chest slot: it always draws from the
    -- chest's LOWEST-numbered non-empty slot. Re-reading the lowest occupied
    -- slot each pass drops the old assumption that the inspected slot and the
    -- sucked slot stay in lockstep, and chest.list() means no hardcoded size.
    local guard = 0
    while true do
        guard = guard + 1
        if guard > 128 then
            print("Staging guard tripped; stopping to avoid a spin.")
            break
        end

        local contents = chest.list()
        local first = nil
        for slot in pairs(contents) do
            if first == nil or slot < first then first = slot end
        end
        if first == nil then break end

        local itemDetails = chest.getItemDetail(first)
        local label, target = "?", nil
        if itemDetails then
            label = itemDetails.displayName or itemDetails.name
            -- Display name, then item id, then NBT hash. Nothing is keyed by
            -- display name any more (see item_table) - the lookup is kept only
            -- so a future one-off can be matched that way. The ender chests
            -- resolve on the NBT branch; everything else on the item id branch.
            target = item_mapping[itemDetails.displayName]
                  or item_mapping[itemDetails.name]
                  or item_mapping[itemDetails.nbt]
        end

        if target ~= nil and target > 9 then
            print(string.format("chest %d: %s -> slot %d", first, label, target))
            turtle.select(target)
            if not turtle.suck(1) then
                print("Could not pull " .. label .. " into slot " .. target .. "; stopping.")
                break
            end
        else
            print(string.format("chest %d: %s -> bulk", first, label))
            turtle.select(1)
            if not turtle.suck() then
                print("Turtle inventory full; stopping.")
                break
            end
        end
    end

    print("--- Chest item transfer complete ---")

    -- Fail here, parked in front of the supply chest, where recovery is free.
    -- Out in the field a missing chest is not recoverable: slot 16 means no
    -- fuel and a stranded bot, slot 14 means mining stalls with full loot
    -- slots, slot 11 means no way to send the warp stone home and no way for
    -- anyone to reach the bot at all.
    local missing = verifyKit()
    if #missing > 0 then
        print("")
        print("STAGING FAILED - refusing to start the run.")
        for _, m in ipairs(missing) do print("  missing: " .. m) end
        print("")
        print("Check the supply chest really holds all three ender chests,")
        print("and that their NBT hashes still match item_table. If a")
        print("frequency was re-keyed, re-run ender_chest_probe.lua to")
        print("read the new hashes.")
        -- Deliberately not chat(): if staging failed, slot 10 may be empty, and
        -- equipping from an empty slot would unequip the pickaxe and crash on a
        -- nil peripheral instead of printing any of the above.
        error("staging incomplete: " .. table.concat(missing, ", "), 0)
    end

    print("Turtle logistics operation complete.")
end


----------------------------------------------------------------------------
-- Scanning and seeking
----------------------------------------------------------------------------

local function seek(x,y,z)
    if x > 0 then
        turtle.turnRight()
        move(math.abs(x))
        turtle.turnLeft()
    elseif x < 0 then
        turtle.turnLeft()
        move(math.abs(x))
        turtle.turnRight()
    end
    if z < 0 then
        move(math.abs(z))
    elseif z > 0 then
        turtle.turnRight()
        turtle.turnRight()
        move(math.abs(z))
        turtle.turnLeft()
        turtle.turnLeft()
    end
    if y > 0 then
        for _ = 1, math.abs(y) do
            turtle.digUp()
            turtle.dig() --accessibility 2x1
            turtle.up()
        end
    elseif y < 0 then
        for _ = 1, math.abs(y) do
            turtle.digDown()
            turtle.dig() --accessibility 2x1
            turtle.down()
        end
    end
end

local function calcDist(x,y,z)
    return math.sqrt(x^2 + y^2 + z^2)
end

local function scan_and_search(radius)
    scanReady()
    local scanner = peripheral.wrap("left")
    if not scanner or not scanner.scan then return nil end
    local scan_data = scanner.scan(radius)
    digReady()
    if not scan_data then return nil end

    -- Catalogue everything ore-like BEFORE filtering, so ores the bot is not
    -- currently looking for still become pickable later. This is a convenience
    -- bolted onto a program whose failure mode is a stranded turtle, so it runs
    -- under pcall: a full disk or a damaged ores.txt must never stop mining.
    pcall(recordScan, scan_data)
    lastScan = scan_data

    local closest_block = 99999
    local closest_x, closest_y, closest_z, closest_name
    for _, item_data in pairs(scan_data) do
        if TARGETS[item_data.name] then
            local block_distance = calcDist(item_data.x, item_data.y, item_data.z)
            if block_distance < closest_block then
                closest_block = block_distance
                closest_x = item_data.x
                closest_y = item_data.y
                closest_z = item_data.z
                closest_name = item_data.name
            end
        end
    end
    if closest_block < 999 then
        seek(closest_x, closest_y, closest_z)
        return closest_name
    end
end

--- One wide scan, then a BOUNDED chain of miniscans following the vein.
---
--- The bound is what guarantees the cycle completes. Everything that keeps the
--- bot alive and reachable - refuel, deposit, the warp announce - runs after
--- this function returns, so an unbounded chase silently disabled all three.
local function scan_loop()
    local success = scan_and_search(8)
    print("full scan")
    local n = 0
    while success ~= nil and n < MAX_MINISCANS do
        if lowFuel() then
            print("fuel low - ending the scan chain to go and refuel")
            break
        end
        success = scan_and_search(3)
        n = n + 1
        print("miniscan " .. n)
    end
    if n >= MAX_MINISCANS then
        print("miniscan limit reached - completing the cycle")
    end
end


----------------------------------------------------------------------------
-- Main
----------------------------------------------------------------------------

installStartup()
loadState()
-- Never fatal: a bot with no catalogue simply has nothing to offer as a
-- pick-list yet, and rebuilds one from its next scan.
pcall(loadCatalogue)

-- Always do these two first, whatever kind of start this is. Both are safe to
-- run when there is nothing to do.
normalizeTools()
recoverPlacedBlocks()

if not state.deployed then
    -- First run. There is no state file, so the bot has never been sent out and
    -- must be parked at base - runTurtleLogistics() proves that by requiring a
    -- supply chest in front, and aborts if there is not one.
    print("First run - staging from the supply chest.")
    runTurtleLogistics(item_table)
    state.deployed = true
    state.cycles = 0
    setPhase("mining")
else
    -- Restarted in the field. Do NOT clean, do NOT stage, do not go looking for
    -- a supply chest that is thousands of blocks away. Reconcile and carry on.
    print("Resuming - interrupted during: " .. tostring(state.phase))
    local missing = verifyKit()
    if #missing > 0 then
        print("Kit is incomplete after a restart:")
        for _, m in ipairs(missing) do print("  missing: " .. m) end
        distress("Cannot continue with an incomplete kit.",
                 "Putting a warp point down so you can reach me.")
    end
    -- Every phase is written to be safe to re-enter from the top, so recovery
    -- is simply "run the phase again" rather than a step-by-step resume. One
    -- redundant scan or one chest placed twice costs nothing; a half-finished
    -- state machine would cost correctness.
    print("Kit verified. Resuming the cycle.")
end

scanReady()
refuel()

-- Always offer a retargeting window before going back to work, on a first run
-- and on every recovery alike.
--
-- Without this the first chance to retask the bot is its first scheduled warp,
-- which is four completed cycles away and can be much longer in dense ore. A
-- reboot is exactly when you are most likely to be standing there wanting to
-- change something, and exactly when the bot is about to walk off for an hour.
--
-- Deliberately after refuel(): a full tank first, then conversation.
listenWindow(string.format(
    "Starting up%s. Listening %d seconds - retarget me now if you want to.",
    state.deployed and " again" or "", WARP_HOLD_SECONDS))

while true do
    -- Refuel on the schedule OR whenever fuel is low, whichever comes first.
    -- Tying refuelling to the warp schedule alone meant a hungry cycle had to
    -- wait up to four more cycles for a top-up; the bot can burn a lot of fuel
    -- in four cycles of chasing ore.
    local due = state.cycles > 3
    if due or lowFuel() then
        refuel()
    end
    if due then
        warpPlate()
        state.cycles = 0
    end
    state.cycles = state.cycles + 1
    saveState()
    scan_loop()
    move(15)
    deposit()
end
