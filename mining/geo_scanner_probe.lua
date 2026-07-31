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
--
-- Safe to run: it only scans. It does not move, dig or place anything.

local SCANNER    = "advancedperipherals:geo_scanner"
local MAX_TRY    = 64        -- stop looking for a ceiling past this
local COOLDOWN_MAX = 20000   -- give up waiting for a cooldown after 20s

local USED_WIDE, USED_MINI = 8, 3   -- what the miner asks for today

local function now() return os.epoch("utc") end

local function findSlot(name)
    for i = 1, 16 do
        local ok, d = pcall(turtle.getItemDetail, i)
        if ok and d and d.name == name then return i end
    end
    return nil
end

print("=== geo scanner probe ===")

-- Equip the scanner, unless it is already on the arm.
local restoreSlot = nil
if peripheral.getType("left") == SCANNER then
    print("scanner already equipped on the left")
else
    local slot = findSlot(SCANNER)
    if not slot then
        print("NO GEO SCANNER FOUND in any inventory slot.")
        return
    end
    print("equipping scanner from slot " .. slot)
    turtle.select(slot)
    turtle.equipLeft()
    restoreSlot = slot
    os.sleep(1)
end

local scanner = peripheral.wrap("left")
if not scanner or not scanner.scan then
    print("FAILED: nothing scannable wrapped on the left.")
    return
end

local function restore()
    if restoreSlot then
        turtle.select(restoreSlot)
        turtle.equipLeft()
        turtle.select(1)
        print("scanner returned to slot " .. restoreSlot)
    end
end

local fuelIsNumber = type(turtle.getFuelLevel()) == "number"
if not fuelIsNumber then
    print("NOTE: fuel is 'unlimited' here, so fuel costs cannot be measured.")
end

----------------------------------------------------------------------------
-- 1. Cooldown, measured first because everything after it needs to wait.
----------------------------------------------------------------------------

print("")
print("--- cooldown ---")

local cooldown = 0
do
    scanner.scan(1)                       -- start a cooldown deliberately
    local t0 = now()
    while true do
        local d = scanner.scan(1)
        if d then cooldown = now() - t0 break end
        if now() - t0 > COOLDOWN_MAX then
            print("still refusing after " .. COOLDOWN_MAX .. "ms - giving up")
            break
        end
        os.sleep(0.05)
    end
end
print(string.format("next scan accepted after ~%dms", cooldown))
print(string.format("that is ~%.2fs, so %d back-to-back miniscans take ~%.0fs",
                    cooldown / 1000, 25, (cooldown / 1000) * 25))

-- Wait out a cooldown politely between every later scan.
local function settle()
    os.sleep(math.max(0.1, (cooldown / 1000) + 0.1))
end

----------------------------------------------------------------------------
-- 2. What cost() reports, if it reports anything useful on a turtle.
----------------------------------------------------------------------------

print("")
print("--- cost(radius), as reported ---")
if not scanner.cost then
    print("no cost() method on this build")
else
    for _, r in ipairs({ 1, 2, 3, 4, 8, 12, 16, 24, 32 }) do
        local ok, c = pcall(scanner.cost, r)
        print(string.format("  cost(%2d) = %s", r, ok and tostring(c) or ("error: " .. tostring(c))))
    end
end

----------------------------------------------------------------------------
-- 3. The real ceiling, and the real fuel price, by actually scanning.
----------------------------------------------------------------------------

print("")
print("--- scan(radius): blocks returned, fuel spent ---")

local maxOk, lastErr = 0, nil
for r = 1, MAX_TRY do
    settle()
    local before = fuelIsNumber and turtle.getFuelLevel() or 0
    local data, err = scanner.scan(r)
    local after  = fuelIsNumber and turtle.getFuelLevel() or 0

    if not data then
        lastErr = tostring(err)
        print(string.format("  scan(%2d) REJECTED: %s", r, lastErr))
        break
    end

    maxOk = r
    local spent = before - after
    print(string.format("  scan(%2d) -> %5d blocks, fuel %s%s",
                        r, #data,
                        fuelIsNumber and tostring(spent) or "n/a",
                        (r == USED_WIDE or r == USED_MINI) and "   <-- used by the miner" or ""))

    -- Radii climb in cubes; past a point the list is huge and slow rather than
    -- interesting, so stop before it becomes unpleasant.
    if #data > 200000 then
        print("  (stopping: result sets are getting very large)")
        break
    end
end

----------------------------------------------------------------------------
-- Verdict
----------------------------------------------------------------------------

print("")
print("=== summary ===")
print(string.format("largest radius accepted : %d", maxOk))
if lastErr then print("rejection message       : " .. lastErr) end
print(string.format("cooldown between scans  : ~%dms", cooldown))
print(string.format("miner currently uses    : %d wide, %d mini", USED_WIDE, USED_MINI))
print("")
print("If the ceiling is well above 8, a wider wide-scan finds veins the bot")
print("currently walks past - but every extra block of radius costs fuel and")
print("the cost climbs with the CUBE of the radius, so read the fuel column")
print("before raising it.")

restore()
