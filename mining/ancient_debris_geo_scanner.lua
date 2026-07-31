-- geo_debris_scanner.lua

-- Configuration
local SCAN_RADIUS = 50 -- Scan radius. The documentation shows '100 blocks' but this is a spherical radius.
                       -- A radius of 50 covers a 101x101x101 cube centered on the turtle.
                       -- Be aware larger radii cost more FE and might be laggy.
local FUEL_SLOT = 16   -- Inventory slot where fuel (e.g., coal, charcoal, etc.) is located for the turtle itself.
                       -- Not for the Geo Scanner's internal fuel.
local POWER_BLOCK_SLOT = 1 -- Inventory slot where you keep items to fuel the Geo Scanner (e.g., Coal Blocks, Redstone Blocks for FE)
local DEBUG_MODE = true -- Set to true to print more detailed messages

-- --- Peripheral Setup ---
local geoScanner = peripheral.wrap("right") -- Assumes the Geo Scanner is directly wrapped as "geoScanner"
                                                -- If it's on a specific side, e.g., "right", use peripheral.wrap("right")

-- --- Helper Functions ---

-- Function to print debug messages
local function debugPrint(msg)
    if DEBUG_MODE then
        print("[DEBUG] " .. msg)
    end
end

-- Function to refuel the turtle itself
local function refuelTurtle()
    debugPrint("Checking turtle fuel...")
    if turtle.getFuelLevel() == "unlimited" then
        debugPrint("Turtle has unlimited fuel.")
        return true
    end

    if turtle.getFuelLevel() < 1000 then -- Refuel if below 1000 units
        debugPrint("Turtle fuel low (" .. turtle.getFuelLevel() .. "). Attempting to refuel...")
        local originalSlot = turtle.getSelectedSlot()
        turtle.select(FUEL_SLOT)
        local success, message = turtle.refuel(64) -- Try to refuel a full stack
        turtle.select(originalSlot)
        if success then
            print("Turtle refueled! Current fuel: " .. turtle.getFuelLevel())
            return true
        else
            print("Failed to refuel turtle: " .. (message or "Unknown error"))
            return false
        end
    end
    debugPrint("Turtle fuel sufficient: " .. turtle.getFuelLevel())
    return true
end

-- Function to refuel the Geo Scanner (if it uses FE from items)
-- Note: Advanced Peripherals Geo Scanner uses its own internal FE,
-- which might be charged by placing FE-generating blocks next to it,
-- or by manually inserting fuel items. This program assumes it is
-- auto-charging or you are managing its FE externally.
-- The doc says 'getFuelLevel()' for scanner, meaning it likely has an internal buffer.
-- This function is a placeholder/example if it *could* consume items.
local function chargeGeoScanner()
    if not geoScanner then print("no scanner") return false end

    local scannerFuel = geoScanner.getFuelLevel()
    local scannerMaxFuel = geoScanner.getMaxFuelLevel()
    --local costForScan = geoScanner.cost(SCAN_RADIUS)

    --debugPrint("Geo Scanner Fuel: " .. scannerFuel .. "/" .. scannerMaxFuel .. " FE. Cost for " .. SCAN_RADIUS .. " radius: " .. costForScan .. " FE.")

    --if scannerFuel < costForScan * 1.5 then -- Try to ensure enough for current scan and a bit more
        --print("Geo Scanner fuel might be low. Please ensure it is powered externally.")
        -- The Geo Scanner peripheral itself usually gets power from an adjacent power source
        -- or by right-clicking it with a filled power source (like a battery, or FE storing block).
        -- ComputerCraft programs generally can't 'insert' FE into other mod's peripherals directly via code.
        -- This part needs manual player intervention or an adjacent FE transfer block.
        -- For example, you might place a Redstone Block next to it, which provides FE.
        -- If you have a way to place an FE-generating block in the world and then break it,
        -- that would be done here using turtle.place() and turtle.dig().
        -- For this program, we'll assume it's powered externally.
        --return true -- Assume external powering is sufficient or handled
    --end
    --return true
--end


-- Main scanning function
function scanForAncientDebris()
    if not geoScanner then
        print("Error: Geo Scanner peripheral not found. Make sure it's placed and connected.")
        return
    end

    print("Starting Ancient Debris scan with radius " .. SCAN_RADIUS .. "...")

    while true do
        -- 1. Check turtle's own fuel
        if not refuelTurtle() then
            print("Cannot refuel turtle. Exiting.")
            return
        end

        -- 2. Check Geo Scanner's internal fuel
        --if not chargeGeoScanner() then
            --print("Cannot ensure Geo Scanner has enough fuel. Exiting.")
            --return
        --end

        -- 3. Check cooldown
        local cooldown = geoScanner.getScanCooldown()
        if cooldown > 0 then
            print("Geo Scanner on cooldown. Waiting " .. cooldown .. " seconds...")
            sleep(cooldown + 1) -- Wait slightly longer than the cooldown
        end

        -- 4. Perform the scan
        print("Performing scan...")
        local scanData, errorMessage = geoScanner.scan(SCAN_RADIUS)

        if not scanData then
            print("Scan failed: " .. (errorMessage or "Unknown error"))
            if errorMessage == "Not enough energy" then
                print("Geo Scanner ran out of energy. Please provide more FE.")
                sleep(10) -- Wait a bit for external power to flow
            elseif errorMessage == "Cooldown not finished" then
                -- This shouldn't happen if we sleep() for cooldown, but good to catch
                print("Still on cooldown, retrying after delay.")
                sleep(5)
            else
                print("Unrecoverable scan error. Exiting.")
                return
            end
            goto continue_loop -- Lua's goto for looping
        end

        -- 5. Process scan results
        local foundDebris = false
        for _, block in ipairs(scanData) do
            if block.name == "minecraft:ancient_debris" then
                print("!!! Found Ancient Debris at X:" .. block.x .. " Y:" .. block.y .. " Z:" .. block.z .. " !!!")
                foundDebris = true
                -- You could add logic here to dig towards it, mark it on a map, etc.
            end
        end

        if not foundDebris then
            print("No Ancient Debris found in this scan area.")
        end

        print("Scan complete. Preparing for next scan...")
        sleep(2) -- Small delay before the next loop iteration (optional)

        ::continue_loop:: -- Label for goto
    end
end

-- --- Start the program ---
print("scuffed")
scanForAncientDebris()
