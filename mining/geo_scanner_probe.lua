-- GEO SCANNER PROBE
--
-- Answers, on YOUR pack and YOUR config, the three things the Advanced
-- Peripherals docs do not publish:
--
--   1. the largest radius scan() will actually accept
--   2. what a scan of each radius costs in turtle fuel
--   3. how long the cooldown between scans really is
--
-- The miner currently uses radius 8 for its wide scan and radius 3 for the
-- miniscans that follow a vein. Those numbers were inherited from the original
-- script and have never been checked against what the hardware allows or what
-- it charges. This is what checks them.
--
--   pastebin get <code> geoprobe    (or wget the raw file)
--   geoprobe
--   edit geoprobe.txt               <- everything it printed, after the fact
--
-- Every line goes to the screen AND to geoprobe.txt, written as it goes rather
-- than at the end, so an interrupted or failed run still leaves whatever it had
-- got to. The turtle screen holds only a few lines and this prints far more.
--
-- Safe to run: it only scans. It does not move, dig or place anything.

local SCANNER      = "advancedperipherals:geo_scanner"
local LOG          = "geoprobe.txt"
local MAX_TRY      = 64        -- stop looking for a ceiling past this
local COOLDOWN_MAX = 20000     -- give up waiting for a cooldown after 20s

local USED_WIDE, USED_MINI = 8, 3   -- what the miner asks for today

----------------------------------------------------------------------------
-- Output: screen and file together
----------------------------------------------------------------------------

local logFile = fs.open(LOG, "w")

local function say(line)
    line = tostring(line)
    print(line)
    if logFile then
        logFile.write(line .. "\n")
        -- Flush per line where the build supports it, so the file is useful
        -- even if the run is interrupted half way through.
        if logFile.flush then pcall(logFile.flush) end
    end
end

local function closeLog()
    if logFile then
        logFile.close()
        logFile = nil
    end
end

local function now() return os.epoch("utc") end

local function findSlot(name)
    for i = 1, 16 do
        local ok, d = pcall(turtle.getItemDetail, i)
        if ok and d and d.name == name then return i end
    end
    return nil
end

local restoreSlot = nil

local function restore()
    if restoreSlot then
        turtle.select(restoreSlot)
        turtle.equipLeft()
        turtle.select(1)
        say("scanner returned to slot " .. restoreSlot)
        restoreSlot = nil
    end
end

----------------------------------------------------------------------------

local function main()
    say("=== geo scanner probe ===")

    -- Equip the scanner, unless it is already on the arm.
    if peripheral.getType("left") == SCANNER then
        say("scanner already equipped on the left")
    else
        local slot = findSlot(SCANNER)
        if not slot then
            say("NO GEO SCANNER FOUND in any inventory slot.")
            return
        end
        say("equipping scanner from slot " .. slot)
        turtle.select(slot)
        turtle.equipLeft()
        restoreSlot = slot
        os.sleep(1)
    end

    local scanner = peripheral.wrap("left")
    if not scanner or not scanner.scan then
        say("FAILED: nothing scannable wrapped on the left.")
        return
    end

    local fuelIsNumber = type(turtle.getFuelLevel()) == "number"
    if fuelIsNumber then
        say("fuel at start: " .. tostring(turtle.getFuelLevel()))
    else
        say("NOTE: fuel is 'unlimited' here, so fuel costs cannot be measured.")
    end

    ------------------------------------------------------------------------
    -- 1. Cooldown, measured first because everything after it needs to wait.
    ------------------------------------------------------------------------

    say("")
    say("--- cooldown ---")

    local cooldown = 0
    scanner.scan(1)                       -- start a cooldown deliberately
    local t0 = now()
    while true do
        local d = scanner.scan(1)
        if d then
            cooldown = now() - t0
            break
        end
        if now() - t0 > COOLDOWN_MAX then
            say("still refusing after " .. COOLDOWN_MAX .. "ms - giving up")
            break
        end
        os.sleep(0.05)
    end
    say(string.format("next scan accepted after ~%dms (~%.2fs)",
                      cooldown, cooldown / 1000))
    say(string.format("so 25 back-to-back miniscans would take ~%.0fs",
                      (cooldown / 1000) * 25))

    -- Wait out a cooldown politely between every later scan.
    local function settle()
        os.sleep(math.max(0.1, (cooldown / 1000) + 0.1))
    end

    ------------------------------------------------------------------------
    -- 2. What cost() reports, if it reports anything useful on a turtle.
    ------------------------------------------------------------------------

    say("")
    say("--- cost(radius), as reported ---")
    if not scanner.cost then
        say("  no cost() method on this build")
    else
        for _, r in ipairs({ 1, 2, 3, 4, 8, 12, 16, 24, 32 }) do
            local ok, c = pcall(scanner.cost, r)
            say(string.format("  cost(%2d) = %s", r,
                              ok and tostring(c) or ("error: " .. tostring(c))))
        end
    end

    ------------------------------------------------------------------------
    -- 3. The real ceiling, and the real fuel price, by actually scanning.
    ------------------------------------------------------------------------

    say("")
    say("--- scan(radius): blocks returned, fuel spent ---")

    local maxOk, lastErr = 0, nil
    for r = 1, MAX_TRY do
        settle()
        local before = fuelIsNumber and turtle.getFuelLevel() or 0
        local data, err = scanner.scan(r)
        local after  = fuelIsNumber and turtle.getFuelLevel() or 0

        if not data then
            lastErr = tostring(err)
            say(string.format("  scan(%2d) REJECTED: %s", r, lastErr))
            break
        end

        maxOk = r
        say(string.format("  scan(%2d) -> %6d blocks, fuel spent %s%s",
                          r, #data,
                          fuelIsNumber and tostring(before - after) or "n/a",
                          (r == USED_WIDE or r == USED_MINI)
                              and "   <-- used by the miner" or ""))

        -- Radii climb in cubes; past a point the list is huge and slow rather
        -- than interesting, so stop before it becomes unpleasant.
        if #data > 200000 then
            say("  (stopping: result sets are getting very large)")
            break
        end
    end

    ------------------------------------------------------------------------

    say("")
    say("=== summary ===")
    say(string.format("largest radius accepted : %d", maxOk))
    if lastErr then say("rejection message       : " .. lastErr) end
    say(string.format("cooldown between scans  : ~%dms", cooldown))
    say(string.format("miner currently uses    : %d wide, %d mini",
                      USED_WIDE, USED_MINI))
    if fuelIsNumber then
        say("fuel at end             : " .. tostring(turtle.getFuelLevel()))
    end
    say("")
    say("If the ceiling is well above 8, a wider wide-scan finds veins the bot")
    say("currently walks past - but cost climbs with the CUBE of the radius, so")
    say("read the fuel column before raising it.")
end

local ok, err = pcall(main)
if not ok then
    say("")
    say("PROBE ERROR: " .. tostring(err))
end

restore()
closeLog()
print("")
print("saved to " .. LOG .. "  -  read it with:  edit " .. LOG)
