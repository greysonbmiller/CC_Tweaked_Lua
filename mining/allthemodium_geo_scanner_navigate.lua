--[[
  TurtleCraft Radius Scanner with Allthemodium Navigation (Relative Coords Only)

  This program uses the 'geoscanner' advanced peripheral to scan a
  specified radius around the Computer/Turtle. If it finds
  'allthemodium:deepslate_allthemodium_ore', the turtle will attempt to
  move directly above that ore block based on the *relative* coordinates
  provided by the geoscanner.

  Requirements:
  - A ComputerCraft Turtle or Computer.
  - An 'Advanced Peripherals' geoscanner block placed adjacent to the Turtle/Computer.
  - The geoscanner peripheral must be wrapped (e.g., 'peripheral.wrap("geoscanner")').
  - Ensure the turtle has a pickaxe in an active slot if it might encounter
    blocks it needs to dig through (e.g., dirt, stone).

  Usage:
  1. Place the geoscanner next to your ComputerCraft device.
  2. Run this program on your ComputerCraft device.
]]

-- Define the scan radius
local SCAN_RADIUS = 6

-- Define the target block ID
local TARGET_ORE_ID = "allthemodium:allthemodium_slate_ore"

-- Function to print a separator line for better readability
local function printSeparator()
    print("----------------------------------------")
end

-- Helper function to ensure the turtle faces a specific direction (0:North, 1:East, 2:South, 3:West)
-- This uses turtle.getDirection() which is a world-relative direction, but it's consistent
-- for turtle movement functions.
local function faceDirection(targetDirection)
    while turtle.getDirection() ~= targetDirection do
        turtle.turnRight()
        sleep(0.05) -- Small delay for stability
    end
end

-- Function to move the turtle by a specific relative displacement
-- dx, dy, dz are the relative distances the turtle needs to travel from its current spot.
local function moveToRelativeCoords(dx, dy, dz)
    print(string.format("Attempting to move relatively by X:%d, Y:%d, Z:%d", dx, dy, dz))

    -- Move along X and Z first
    while dx ~= 0 or dz ~= 0 do
        if math.abs(dx) >= math.abs(dz) and dx ~= 0 then
            -- Move along X axis
            if dx > 0 then
                faceDirection(1) -- Face East (positive X)
                dx = dx - 1 -- Decrement remaining X distance
            else
                faceDirection(3) -- Face West (negative X)
                dx = dx + 1 -- Increment remaining X distance (moving towards 0)
            end
            if not turtle.forward() then
                turtle.dig() -- Try to dig if blocked
                sleep(0.1)
                if not turtle.forward() then
                    print("Failed to move forward in X. Path blocked or unbreakable block?")
                    return false
                end
            end
        elseif dz ~= 0 then
            -- Move along Z axis
            if dz > 0 then
                faceDirection(2) -- Face South (positive Z)
                dz = dz - 1 -- Decrement remaining Z distance
            else
                faceDirection(0) -- Face North (negative Z)
                dz = dz + 1 -- Increment remaining Z distance (moving towards 0)
            end
            if not turtle.forward() then
                turtle.dig() -- Try to dig if blocked
                sleep(0.1)
                if not turtle.forward() then
                    print("Failed to move forward in Z. Path blocked or unbreakable block?")
                    return false
                end
            end
        end
        sleep(0.1) -- Small delay between movements
    end

    -- Now adjust Y (vertical movement)
    while dy ~= 0 do
        if dy > 0 then
            if not turtle.up() then
                turtle.digUp() -- Try to dig if blocked
                sleep(0.1)
                if not turtle.up() then
                    print("Failed to move up. Path blocked or unbreakable block?")
                    return false
                end
            end
            dy = dy - 1 -- Decrement remaining Y distance (moving towards 0)
        else
            if not turtle.down() then
                turtle.digDown() -- Try to dig if blocked
                sleep(0.1)
                if not turtle.down() then
                    print("Failed to move down. Path blocked or unbreakable block?")
                    return false
                end
            end
            dy = dy + 1 -- Increment remaining Y distance (moving towards 0)
        end
        sleep(0.1) -- Small delay between vertical movements
    end

    print("Successfully moved to relative target.")
    return true
end

print("Starting Radius Scan (Radius: " .. SCAN_RADIUS .. " blocks)...")
printSeparator()

-- Try to wrap the geoscanner peripheral
local geoscanner = peripheral.wrap("left") -- Or "left" if that's your custom name

-- Check if geoscanner was successfully wrapped
if not geoscanner then
    print("Error: Geoscanner peripheral not found or not wrapped.")
    print("Please ensure a geoscanner block is placed next to the Computer/Turtle.")
    print("And that 'geoscanner' is its correct peripheral name.")
    printSeparator()
    return
end

print("Geoscanner found. Performing scan...")
printSeparator()

local foundTargetOre = false
local relativeTargetX, relativeTargetY, relativeTargetZ

-- Attempt to perform the scan
local success, scanResultsOrReason = pcall(geoscanner.scan, SCAN_RADIUS)

if not success then
    print("Error during scan: " .. tostring(scanResultsOrReason))
    print("The geoscanner might be on cooldown, out of power, or encountered an issue.")
    printSeparator()
    return
end

-- Process the scan results
if scanResultsOrReason and type(scanResultsOrReason) == "table" then
    local blockCount = 0
    if #scanResultsOrReason > 0 then
        print("Found blocks:")
        for i, blockData in ipairs(scanResultsOrReason) do
            blockCount = blockCount + 1
            print(string.format("  %d. Name: %s, Relative X: %d, Y: %d, Z: %d",
                                i, blockData.name, blockData.x, blockData.y, blockData.z))

            -- Check if this is the target ore and we haven't found one yet
            if blockData.name == TARGET_ORE_ID and not foundTargetOre then
                printSeparator()
                print(string.format("!!! Found %s at Relative X:%d, Y:%d, Z:%d !!!", TARGET_ORE_ID, blockData.x, blockData.y, blockData.z))

                -- Store the relative coordinates of the target ore
                relativeTargetX = blockData.x
                relativeTargetY = blockData.y + 1 -- Move one block above the ore
                relativeTargetZ = blockData.z

                foundTargetOre = true
                -- We break here to only move to the first one found.
                -- Remove 'break' if you want to scan all and then move to the last one found.
                break
            end
        end
        printSeparator()
        print(string.format("Total blocks found in radius %d: %d", SCAN_RADIUS, blockCount))
    else
        print("No blocks found in the scanned radius.")
    end
else
    print("Scan returned an unexpected result type.")
end

printSeparator()

-- If target ore was found, attempt to move to it
if foundTargetOre then
    if moveToRelativeCoords(relativeTargetX, relativeTargetY, relativeTargetZ) then
        print("Turtle is now positioned above the " .. TARGET_ORE_ID .. ".")
    else
        print("Failed to reach the target " .. TARGET_ORE_ID .. " location.")
    end
else
    print("No " .. TARGET_ORE_ID .. " found to navigate to.")
end

printSeparator()
print("Scan and navigation complete.")
