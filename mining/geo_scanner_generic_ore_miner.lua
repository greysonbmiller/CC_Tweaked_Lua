-- ore_miner.lua
-- Runs on a turtle equipped with an Advanced Peripherals Geo Scanner.
-- Scans the surrounding area for ores, walks to each one, mines it, and
-- returns to its starting point when the inventory fills or the area is dry.
--
-- Setup:
--   1. Craft a Geo Scanner and equip it to the turtle (place scanner in the
--      turtle crafting grid, or run `equip left` with the scanner in hand).
--   2. Keep a pickaxe equipped on the other side.
--   3. Put coal/charcoal in any slot for fuel.
--   4. Optional: place a chest UNDER the turtle's starting block - the turtle
--      returns there and dumps its haul when full.
--   5. IMPORTANT: set START_FACING below to the direction the turtle faces
--      (press F3 in game and read "Facing"). Wrong value = it walks the wrong
--      way. If a GPS cluster is in range it auto-detects and ignores this.
--
-- Usage:
--   ore_miner            -- uses SCAN_RADIUS below
--   ore_miner 12         -- override the scan radius

-- ============================ CONFIG ============================

local SCAN_RADIUS   = 8        -- geo scanner radius (bigger = more fuel/cooldown)
local START_FACING  = "north"  -- north | east | south | west
local USE_GPS       = true     -- auto-detect facing when a GPS cluster is in range

local MIN_FUEL      = 600      -- refuel from inventory below this
local FUEL_RESERVE  = 80       -- always keep this much on top of the trip home

local MAX_DEPTH     = 40       -- never go more than this many blocks BELOW start
local MAX_HEIGHT    = 20       -- never go more than this many blocks ABOVE start

local DUMP_DIR      = "down"   -- where the chest is at home: down | up | front
local RELOCATE_STEP = 10       -- blocks to travel forward when a scan finds nothing
local MAX_RELOCATES = 5        -- give up and go home after this many empty scans

-- Only mine these (substring match). Leave empty to mine everything ore-like.
local TARGETS = {
    -- "diamond", "ancient_debris", "allthemodium",
}

-- Never mine these, even if they look like ores.
local BLACKLIST = {
    ["minecraft:infested_stone"] = true,
}

-- Ore-like blocks whose name does not contain "_ore".
local EXTRA_ORES = {
    ["minecraft:ancient_debris"] = true,
}

-- Kept when dumping into the chest.
local FUEL_ITEMS = {
    ["minecraft:coal"]       = true,
    ["minecraft:charcoal"]   = true,
    ["minecraft:coal_block"] = true,
}

-- Refuse to move into these.
local HAZARDS = {
    ["minecraft:lava"]         = true,
    ["minecraft:flowing_lava"] = true,
    ["minecraft:bedrock"]      = true,
}

-- ============================ STATE =============================

local DIRS = {
    [0] = { x =  0, z = -1, name = "north" },
    [1] = { x =  1, z =  0, name = "east"  },
    [2] = { x =  0, z =  1, name = "south" },
    [3] = { x = -1, z =  0, name = "west"  },
}
local NAME_TO_DIR = { north = 0, east = 1, south = 2, west = 3 }

-- Position is tracked relative to the starting block, on world axes:
-- +x = east, +z = south, +y = up. The geo scanner reports the same axes.
local pos    = { x = 0, y = 0, z = 0 }
local facing = NAME_TO_DIR[START_FACING] or 0
local mined  = 0

local MOVES = {
    forward = { move = turtle.forward, dig = turtle.dig,     detect = turtle.detect,     attack = turtle.attack,     inspect = turtle.inspect     },
    up      = { move = turtle.up,      dig = turtle.digUp,   detect = turtle.detectUp,   attack = turtle.attackUp,   inspect = turtle.inspectUp   },
    down    = { move = turtle.down,    dig = turtle.digDown, detect = turtle.detectDown, attack = turtle.attackDown, inspect = turtle.inspectDown },
}

-- ========================== MOVEMENT ============================

local function turnTo(target)
    target = target % 4
    while facing ~= target do
        if (facing + 1) % 4 == target then
            turtle.turnRight()
            facing = (facing + 1) % 4
        else
            turtle.turnLeft()
            facing = (facing - 1) % 4
        end
    end
end

-- Move one block, digging and attacking whatever gets in the way.
-- Returns false plus a reason if the way stays blocked.
local function step(dir)
    local m = MOVES[dir]

    for _ = 1, 12 do
        if m.detect() then
            local ok, data = m.inspect()
            if ok and HAZARDS[data.name] then
                return false, data.name
            end
            if not m.dig() then
                sleep(0.4)  -- gravel falling, or an unbreakable block
            end
        end

        if m.move() then
            if dir == "forward" then
                pos.x = pos.x + DIRS[facing].x
                pos.z = pos.z + DIRS[facing].z
            elseif dir == "up" then
                pos.y = pos.y + 1
            else
                pos.y = pos.y - 1
            end
            return true
        end

        m.attack()  -- something alive is standing there
        sleep(0.2)
    end

    return false, "blocked"
end

-- Walk to a coordinate relative to home. Climbs before travelling and drops
-- last, so the turtle tunnels through terrain rather than under it.
local function goTo(tx, ty, tz)
    while pos.y < ty do
        local ok, why = step("up")
        if not ok then return false, why end
    end

    while pos.x ~= tx do
        turnTo(tx > pos.x and 1 or 3)
        local ok, why = step("forward")
        if not ok then return false, why end
    end

    while pos.z ~= tz do
        turnTo(tz > pos.z and 2 or 0)
        local ok, why = step("forward")
        if not ok then return false, why end
    end

    while pos.y > ty do
        local ok, why = step("down")
        if not ok then return false, why end
    end

    return true
end

local function distanceHome()
    return math.abs(pos.x) + math.abs(pos.y) + math.abs(pos.z)
end

-- =========================== UPKEEP =============================

local function fuelLevel()
    local level = turtle.getFuelLevel()
    if level == "unlimited" then return math.huge end
    return level
end

local function refuel()
    if fuelLevel() >= MIN_FUEL then return true end

    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.refuel(0) then       -- is this slot burnable?
            turtle.refuel()            -- burn the stack
            if fuelLevel() >= MIN_FUEL then break end
        end
    end
    turtle.select(1)

    return fuelLevel() > distanceHome() + FUEL_RESERVE
end

local function freeSlots()
    local free = 0
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then free = free + 1 end
    end
    return free
end

local function dumpInventory()
    local dropFn = turtle.drop
    if DUMP_DIR == "down" then dropFn = turtle.dropDown
    elseif DUMP_DIR == "up" then dropFn = turtle.dropUp end

    local dropped = 0
    for slot = 1, 16 do
        turtle.select(slot)
        local item = turtle.getItemDetail()
        if item and not FUEL_ITEMS[item.name] then
            if dropFn() then dropped = dropped + 1 end
        end
    end
    turtle.select(1)

    if dropped == 0 and freeSlots() == 0 then
        print("[home] No chest found - inventory still full.")
        return false
    end
    return true
end

local function goHome(reason)
    print("[home] Returning (" .. reason .. ")")
    if not goTo(0, 0, 0) then
        print("[home] Path home blocked at " .. pos.x .. "," .. pos.y .. "," .. pos.z)
        return false
    end
    turnTo(NAME_TO_DIR[START_FACING] or 0)
    return true
end

-- =========================== SCANNING ===========================

local scanner = peripheral.find("geoScanner")

local function isOre(block)
    local name = block.name or ""
    if BLACKLIST[name] then return false end

    local oreLike = name:find("_ore") ~= nil or EXTRA_ORES[name] == true

    if not oreLike and block.tags then
        -- tags come back as a list in some versions, a map in others
        for key, value in pairs(block.tags) do
            local tag = type(key) == "string" and key or value
            if type(tag) == "string" and (tag:find("forge:ores") or tag:find("c:ores")) then
                oreLike = true
                break
            end
        end
    end

    if not oreLike then return false end
    if #TARGETS == 0 then return true end

    for _, want in ipairs(TARGETS) do
        if name:find(want, 1, true) then return true end
    end
    return false
end

local function scan()
    if scanner.getScanCooldown then
        local cooldown = scanner.getScanCooldown() or 0
        if cooldown > 0 then sleep(cooldown / 1000 + 0.1) end
    end

    local blocks, err
    for attempt = 1, 5 do
        local ok, result, reason = pcall(scanner.scan, SCAN_RADIUS)
        if ok and result then
            blocks = result
            break
        end
        err = (ok and reason) or result
        print("[scan] " .. tostring(err) .. " (retry " .. attempt .. "/5)")
        sleep(2)
    end
    if not blocks then return nil, err end

    local found = {}
    for _, block in ipairs(blocks) do
        if isOre(block) then
            local ty = pos.y + block.y
            -- scanner coords are relative to the turtle, so convert to home-relative
            if ty <= MAX_HEIGHT and ty >= -MAX_DEPTH then
                found[#found + 1] = {
                    name = block.name,
                    x    = pos.x + block.x,
                    y    = ty,
                    z    = pos.z + block.z,
                }
            end
        end
    end
    return found
end

-- Order targets nearest-first, re-measuring from each stop.
local function nearest(targets, from)
    local bestIndex, bestDist
    for i, t in ipairs(targets) do
        local dist = math.abs(t.x - from.x) + math.abs(t.y - from.y) + math.abs(t.z - from.z)
        if not bestDist or dist < bestDist then
            bestIndex, bestDist = i, dist
        end
    end
    return bestIndex, bestDist
end

-- ============================= MAIN =============================

local args = { ... }
if args[1] then SCAN_RADIUS = tonumber(args[1]) or SCAN_RADIUS end

if not scanner then
    error("No geo scanner found. Equip an Advanced Peripherals Geo Scanner to the turtle.", 0)
end
if not turtle.dig then
    error("This turtle has no pickaxe equipped.", 0)
end

if USE_GPS then
    -- A GPS fix before and after one step tells us which way we really face,
    -- which beats trusting START_FACING.
    local x1, _, z1 = gps.locate(2)
    if x1 then
        local moved, turns = false, 0
        for _ = 1, 4 do
            if turtle.forward() then
                moved = true
                break
            end
            turtle.turnRight()
            turns = turns + 1
        end
        if moved then
            local x2, _, z2 = gps.locate(2)
            if x2 then
                for dir, vec in pairs(DIRS) do
                    if vec.x == (x2 - x1) and vec.z == (z2 - z1) then
                        facing = (dir - turns) % 4  -- undo the probing turns
                        print("[gps] Facing detected: " .. DIRS[facing].name)
                    end
                end
            end
            if not turtle.back() then
                -- stuck out here, so home is one block behind us now
                pos.x = pos.x + DIRS[(facing + turns) % 4].x
                pos.z = pos.z + DIRS[(facing + turns) % 4].z
            end
        end
        turnTo(facing)
    end
end

print("=================================")
print(" Ore Miner - turtle #" .. os.getComputerID())
print(" Radius: " .. SCAN_RADIUS .. "   Facing: " .. DIRS[facing].name)
print(" Fuel:   " .. tostring(turtle.getFuelLevel()))
print("=================================")

local relocates = 0

while true do
    if not refuel() then
        print("[fuel] Too low to continue.")
        goHome("out of fuel")
        break
    end

    if freeSlots() == 0 then
        if not goHome("inventory full") then break end
        if not dumpInventory() then break end
    end

    local targets, err = scan()
    if not targets then
        print("[scan] Failed: " .. tostring(err))
        goHome("scanner error")
        break
    end

    if #targets == 0 then
        relocates = relocates + 1
        if relocates > MAX_RELOCATES then
            print("[scan] Nothing left nearby.")
            goHome("area exhausted")
            break
        end

        print("[scan] No ores in range - moving " .. RELOCATE_STEP .. " blocks on.")
        for _ = 1, RELOCATE_STEP do
            if not step("forward") then break end
        end
    else
        local minedBefore = mined
        print("[scan] " .. #targets .. " ore blocks in range.")

        while #targets > 0 do
            if freeSlots() == 0 or fuelLevel() < distanceHome() + FUEL_RESERVE then
                break  -- head back up top, then rescan
            end

            local index = nearest(targets, pos)
            local target = table.remove(targets, index)

            local ok, why = goTo(target.x, target.y, target.z)
            if ok then
                mined = mined + 1
                print("[dig] " .. target.name:gsub("^.*:", "") .. "  (" .. mined .. " total)")
            else
                print("[skip] " .. target.name:gsub("^.*:", "") .. " - " .. tostring(why))
            end
        end

        if mined > minedBefore then
            relocates = 0
        else
            -- everything in range was unreachable (lava, bedrock, walled off)
            relocates = relocates + 1
            if relocates > MAX_RELOCATES then
                print("[scan] Nothing reachable here.")
                goHome("area exhausted")
                break
            end
        end
    end
end

if distanceHome() > 0 then goHome("finished") end
print("=================================")
print(" Done. Mined " .. mined .. " ore blocks.")
print(" Fuel left: " .. tostring(turtle.getFuelLevel()))
print("=================================")
