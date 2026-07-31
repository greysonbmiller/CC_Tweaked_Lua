-- quarry.lua
-- A CC:Tweaked turtle program to dig a quarry of a specified size down to bedrock.
-- The turtle will deposit materials when full and fill holes with cobblestone.
-- This version operates WITHOUT a GPS modem and assumes a chest is pre-placed behind the turtle.

-- --- Configuration ---
local FUEL_THRESHOLD = 500 -- Refuel if fuel level drops below this.
local INVENTORY_FULL_SLOTS = 14 -- Consider inventory full if this many slots have items (excluding bucket in slot 16).
local CHEST_FULL_WAIT_TIME = 10 -- Seconds to wait if deposit chest is full.
local BUCKET_SLOT = 16 -- The slot reserved for the bucket.

-- --- Global Variables (Managed by the program) ---
-- local chestPlacedDown = false -- This variable is no longer needed as chest is always assumed to be behind.
local currentQuarryYOffset = 0 -- How many blocks down from the initial quarry start point.
local originalQuarryStartY -- The Y-level where the turtle starts the quarry.

-- --- Helper Functions ---

-- Converts a facing string ("north", "east", etc.) to a numeric representation (0-3).
-- This is used for consistent turning logic.
local NORTH = 0
local EAST = 1
local SOUTH = 2
local WEST = 3
function getNumericFacing()
    local facing = turtle.getFacing()
    if facing == "north" then return NORTH
    elseif facing == "east" then return EAST
    elseif facing == "south" then return SOUTH
    elseif facing == "west" then return WEST
    end
    return -1 -- Error
end

-- Turns the turtle to face a specific numeric direction.
function turnToFacing(targetFacing)
    local currentFacing = getNumericFacing()
    if currentFacing == -1 then error("Unknown current facing.") end

    while currentFacing ~= targetFacing do
        turtle.turnLeft() -- Prefer turning left as it's generally more efficient for arbitrary turns
        currentFacing = (currentFacing - 1 + 4) % 4
    end
end

-- Finds and returns the slot number of cobblestone in the turtle's inventory.
-- Returns nil if not found.
function findCobblestoneSlot()
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and item.name == "minecraft:cobblestone" then
            return i
        end
    end
    return nil
end

-- This function is now simplified as the chest is assumed to be pre-placed behind the turtle.
function setupDepositChest()
    print("Assuming deposit chest is pre-placed behind the turtle.")
    -- No need to place a chest, just set the initial Y-level for the quarry.
    originalQuarryStartY = turtle.getY() -- Record the Y-level of the turtle's starting position.
end

-- Digs the block in front, above, and below the turtle.
-- Then attempts to move forward, handling hole filling and liquid handling if necessary.
function digBlockAndMove()
    local originalSelectedSlot = turtle.getSelectedSlot()

    -- --- Liquid Handling ---
    -- Select the bucket slot (16) and try to suck.
    turtle.select(BUCKET_SLOT)
    local success, item = turtle.suck() -- Attempt to suck up a block or liquid

    if success and item then
        if item.name == "minecraft:lava_bucket" then
            print("Picked up lava bucket. Attempting to refuel.")
            turtle.refuel(1) -- Use one lava bucket for fuel
            -- Lava bucket leaves an empty bucket, which is fine in slot 16
        elseif item.name == "minecraft:water_bucket" then
            print("Picked up water bucket. Attempting to destroy water source.")
            turtle.place() -- Place the water back
            local cobblestoneSlot = findCobblestoneSlot()
            if cobblestoneSlot then
                turtle.select(cobblestoneSlot)
                if turtle.place() then -- Place a block (cobblestone) on the water source
                    turtle.dig() -- Dig the block (this destroys the water source)
                    print("Water source destroyed.")
                else
                    print("Warning: Could not place block to destroy water source!")
                end
            else
                print("Warning: No cobblestone found to destroy water source!")
            end
        end
    end
    turtle.select(originalSelectedSlot) -- Restore original slot

    -- --- Normal Digging ---
    if turtle.detect() then turtle.dig() end
    if turtle.detectUp() then turtle.digUp() end
    if turtle.detectDown() then turtle.digDown() end

    -- Check inventory and deposit if full
    checkInventoryAndDeposit()

    -- Attempt to move forward. If it fails, check if it's a hole and fill it.
    if not turtle.forward() then
        -- If turtle.forward() fails, it could be an obstruction or a hole.
        -- If it's an air block (a hole), place cobblestone.
        if not turtle.detect() then -- If there's no block in front (after digging)
            print("Detected a hole in front, attempting to fill with cobblestone.")
            local cobblestoneSlot = findCobblestoneSlot()
            if cobblestoneSlot then
                turtle.select(cobblestoneSlot)
                turtle.place() -- Place cobblestone forward
                turtle.select(originalSelectedSlot) -- Restore original slot
                if not turtle.forward() then
                    print("Error: Still stuck after placing cobblestone. Aborting.")
                    error("Turtle stuck after hole filling.")
                end
            else
                print("Error: No cobblestone found to fill hole! Aborting.")
                error("No cobblestone for hole filling.")
            end
        else
            -- It failed to move forward, but there's a block there. This means it's stuck on an undiggable block.
            print("Error: Turtle stuck on an undiggable block. Aborting.")
            error("Turtle stuck on obstruction.")
        end
    end
end

-- Checks if the turtle's inventory is nearly full and triggers item deposit if so.
function checkInventoryAndDeposit()
    local fullSlots = 0
    -- Iterate through all slots except the bucket slot (16)
    for i = 1, 15 do
        if turtle.getItemCount(i) > 0 then
            fullSlots = fullSlots + 1
        end
    end

    if fullSlots >= INVENTORY_FULL_SLOTS then
        print("Inventory almost full. Returning to deposit items.")
        depositItems()
    end
end

-- Returns to the initial starting position (above the chest) to deposit items.
-- Then navigates back to the position where it left off.
function depositItems()
    print("Depositing items...")
    local currentFacing = turtle.getFacing() -- Store current facing

    -- Move up to the Y-level of the initial quarry start point (above the chest)
    for i = 1, currentQuarryYOffset do
        if not turtle.up() then
            print("Error: Failed to move up to deposit level. Obstruction?")
            error("Failed to move up for deposit.")
        end
    end

    -- Now at the Y-level of the initial quarry start.
    -- Move onto the chest (which is behind the turtle).
    turtle.turnRight()
    turtle.turnRight() -- Turn 180 degrees to face the chest
    if not turtle.forward() then -- Move onto the chest block
        print("Error: Failed to move onto pre-placed chest. Obstruction?")
        error("Failed to move to chest.")
    end

    -- Now on the chest. Deposit items.
    for slot = 1, 16 do
        turtle.select(slot)
        local item = turtle.getItemDetail(slot)
        -- Only deposit non-essential items (keep cobblestone, fuel, and the bucket in slot 16)
        if item and item.name ~= "minecraft:cobblestone" and
           item.name ~= "minecraft:coal" and
           item.name ~= "minecraft:charcoal" and
           item.name ~= "minecraft:lava_bucket" and
           slot ~= BUCKET_SLOT then -- Do not deposit the bucket itself
            local success = false
            repeat
                -- Transfer to the first slot of the chest (slot 1 of the inventory below/behind)
                success = turtle.transferTo(1)
                if not success then
                    print("Chest is full. Waiting " .. CHEST_FULL_WAIT_TIME .. " seconds...")
                    sleep(CHEST_FULL_WAIT_TIME)
                end
            until success
        end
    end

    -- Move off the chest and re-orient
    if not turtle.back() then -- Move off the chest
        print("Error: Failed to move off pre-placed chest. Obstruction?")
        error("Failed to move off chest.")
    end
    turtle.turnRight()
    turtle.turnRight() -- Turn back to original facing

    -- Move back down to the current quarry layer
    for i = 1, currentQuarryYOffset do
        if not turtle.down() then
            print("Error: Failed to move down to resume quarry. Obstruction?")
            error("Failed to move down to resume quarry.")
        end
    end

    -- Restore original facing before resuming quarrying
    turnToFacing(currentFacing)
    print("Items deposited. Resuming quarry.")
end

-- Checks fuel level and refuels if necessary.
function refuel()
    if turtle.getFuelLevel() < FUEL_THRESHOLD then
        print("Low fuel. Attempting to refuel.")
        local originalSlot = turtle.getSelectedSlot()
        local foundFuel = false
        for i = 1, 16 do
            local item = turtle.getItemDetail(i)
            if item and (item.name == "minecraft:coal" or item.name == "minecraft:charcoal") then
                turtle.select(i)
                turtle.refuel(64) -- Refuel a stack
                foundFuel = true
                break
            elseif item and item.name == "minecraft:lava_bucket" then
                -- If lava bucket is found, it would have been handled by digBlockAndMove already,
                -- but this is a fallback if fuel runs low outside of digging.
                turtle.select(i)
                turtle.refuel(1) -- Use one lava bucket
                foundFuel = true
                break
            end
        end
        turtle.select(originalSlot)
        if not foundFuel then
            print("Warning: No fuel found in inventory. May run out of fuel!")
        else
            print("Refueled. Current fuel level: " .. turtle.getFuelLevel())
        end
    end
end

-- Digs one horizontal layer of the quarry in a snake pattern.
-- Assumes turtle starts at (0,0) of the layer, facing 'forward' (e.g., North).
-- Quarry extends in 'forward' (+Z) and 'left' (-X) directions.
function digCurrentLayer(size)
    print("Clearing a " .. size .. "x" .. size .. " layer.")
    local initialLayerFacing = turtle.getFacing() -- Store initial facing for this layer

    for x_offset = 0, size - 1 do -- Iterate through columns (moving left/right)
        if x_offset % 2 == 0 then -- Even column: dig forward (positive Z)
            for z_offset = 0, size - 1 do
                digBlockAndMove()
            end
            if x_offset < size - 1 then
                turtle.turnLeft() -- Turn left (to face -X)
                digBlockAndMove() -- Move one step left (along X)
                turtle.turnLeft() -- Turn left again (to face backward, -Z)
            end
        else -- Odd column: dig backward (negative Z)
            for z_offset = 0, size - 1 do
                digBlockAndMove()
            end
            if x_offset < size - 1 then
                turtle.turnRight() -- Turn right (to face -X)
                digBlockAndMove() -- Move one step left (along X)
                turtle.turnRight() -- Turn right again (to face forward, +Z)
            end
        end
    end

    print("Finished clearing layer. Returning to layer start.")
    -- After completing a layer, the turtle will be at the end of the last column.
    -- Need to navigate back to the starting corner of the layer.

    -- 1. Turn to face the initial facing for the layer.
    turnToFacing(initialLayerFacing)

    -- 2. Move back along the X-axis (left/right direction) to the initial X-coordinate of the layer.
    -- The turtle is currently at the end of the last column. It needs to move `size - 1` steps right.
    turtle.turnRight() -- Turn to face the positive X direction (right)
    for i = 1, size - 1 do
        if not turtle.forward() then
            print("Error: Failed to return to layer start (X-axis). Obstruction?")
            error("Failed to return to layer start.")
        end
    end
    turtle.turnLeft() -- Turn back to initial facing (e.g., North)

    -- 3. Move back along the Z-axis (forward direction) to the initial Z-coordinate of the layer.
    -- The turtle is currently at the end of the last row/column. It needs to move `size - 1` steps backward.
    for i = 1, size - 1 do
        if not turtle.back() then
            print("Error: Failed to return to layer start (Z-axis). Obstruction?")
            error("Failed to return to layer start.")
        end
    end

    -- Ensure it's facing the initial direction for the next layer
    turnToFacing(initialLayerFacing)
    print("Returned to layer start.")
end

-- --- Main Program ---
function main()
    -- Get quarry size from command line argument
    local quarry_size = tonumber(arg[1])
    if not quarry_size or quarry_size < 1 then
        print("Usage: quarry <size>")
        print("  <size>: The length of one side of the square quarry (must be a positive integer).")
        error("Invalid argument.")
    end

    print("Starting quarry operation with size: " .. quarry_size .. "x" .. quarry_size)

    -- Set up deposit chest (now just acknowledges pre-placed chest)
    setupDepositChest()

    -- Ensure there's a block beneath the turtle before starting to dig down.
    print("Waiting for a block beneath the turtle to start digging...")
    while not turtle.detectDown() do
        sleep(1)
    end
    print("Block detected. Starting quarry.")

    -- Dig down to bedrock, layer by layer
    while true do
        print("Digging layer at Y-level offset: " .. currentQuarryYOffset .. " (relative to quarry start)")

        refuel() -- Refuel before digging a new layer
        digCurrentLayer(quarry_size)
        checkInventoryAndDeposit() -- Check inventory after each layer

        -- Move down to the next layer if bedrock is not yet reached
        if turtle.detectDown() then
            print("Moving to next layer...")
            if not turtle.down() then
                print("Error: Failed to move down to next layer. Obstruction?")
                error("Failed to move down to next layer.")
            end
            currentQuarryYOffset = currentQuarryYOffset + 1
        else
            print("Reached bedrock or void. Quarry complete.")
            break
        end
    end
    print("Quarry operation finished successfully!")
end

-- Run the main program
main()
