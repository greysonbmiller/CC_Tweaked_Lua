
reference_ore = "minecraft:deepslate_lapis_ore"
reference2 = "minecraft:lapis_ore"

-- Staging map: what the turtle pulls out of the chest in front of it, and which
-- slot each thing goes to. Keys are matched against an item's display name
-- first, then its item id, then its NBT hash.
--
-- The three chests are matched by DISPLAY NAME. Rename them in an anvil to
-- exactly these strings - they are all the same item id, so the id alone cannot
-- tell them apart. (This replaced three hardcoded NBT hashes from the world
-- this was written in, which cannot be reproduced anywhere else.)
item_table = {
     ["Warp"]    = 11,                                        -- anvil-rename the warp plate chest to this
     ["Deposit"] = 14,                                        -- anvil-rename the deposit chest to this
     ["Refuel"]  = 16,                                        -- anvil-rename the refuel chest to this
     ["mob_grinding_utils:absorption_hopper"] = 12,           -- vacuum hopper (item name)
     ["waystones:warp_plate"] = 13,                           -- warp plate (item name)
     ["advancedperipherals:geo_scanner"] = 15,                -- geo scanner (item name)
     ["advancedperipherals:chat_box"] = 10                    -- chat box (item name)
 }

 local my_vacuum_hopper_id = "mob_grinding_utils:absorption_hopper"

 local function digReady()
    --turtle.select(15)
    for i=1,16 do
        count = turtle.getItemCount(i)
        if count == 1 then
            details = turtle.getItemDetail(i)
            if details.name == "minecraft:diamond_pickaxe" then
                turtle.select(i)
                turtle.transferTo(15,1)
                turtle.select(15)
                turtle.equipLeft()
            end
        end
    end
    turtle.select(1)
end

local function scanReady()
    --turtle.select(15)
    for i=1,16 do
        count = turtle.getItemCount(i)
        if count == 1 then
            details = turtle.getItemDetail(i)
            if details.name == "advancedperipherals:geo_scanner" then
                turtle.select(i)
                turtle.transferTo(15,1)
                turtle.select(15)
                turtle.equipLeft()
            end
        end
    end
    turtle.select(1)
    p=peripheral.wrap("left")
end

 local function runTurtleLogistics(item_mapping, vacuum_hopper_item_name)
    digReady()
    turtle.dig()
    turtle.digUp()
    print("Starting turtle logistics operation...")

    --- Cleans the turtle's inventory by placing one vacuum hopper (if found)
    --- and dropping all other items.
    local function cleanTurtleInventory()
        print("--- Cleaning turtle inventory ---")
        -- Loop through all 16 inventory slots of the turtle
        for slotNum = 1, 16 do
            print("Processing turtle slot " .. slotNum .. ".")
            turtle.select(slotNum) -- Select the current slot

            local itemDetails = turtle.getItemDetail(slotNum) -- Get detailed information about the item in this slot

            if itemDetails then -- Check if there's actually an item in the slot
                if itemDetails.name == vacuum_hopper_item_name then
                    print("Found Vacuum Hopper ('" .. itemDetails.name .. "') in slot " .. slotNum .. ". Attempting to place one.")
                    local success, reason = turtle.place() -- Attempt to place one item from the selected stack

                    if success then
                        print("Successfully placed one Vacuum Hopper.")
                    else
                        print("Failed to place Vacuum Hopper: " .. (reason or "Block in front might be occupied."))
                    end

                    -- After attempting to place, check if any items (including the placed hopper if placement failed)
                    -- are still in the slot. If so, drop the rest.
                    if turtle.getItemCount(slotNum) > 0 then
                        print("Remaining items found in slot " .. slotNum .. ". Dropping remaining stack.")
                        local dropSuccess, dropReason = turtle.drop() -- Drop the entire remaining stack
                        if dropSuccess then
                            print("Successfully dropped remaining items from slot " .. slotNum .. ".")
                        else
                            print("Failed to drop remaining items: " .. (dropReason or "Inventory in front might be full."))
                        end
                    end
                else
                    -- If it's not a Vacuum Hopper, just drop all items in the slot
                    print("Found item '" .. itemDetails.name .. "' in slot " .. slotNum .. ". Dropping entire stack.")
                    local success, reason = turtle.drop() -- Drop the entire stack
                    if success then
                        print("Successfully dropped all items from slot " .. slotNum .. ".")
                    else
                        print("Failed to drop items: " .. (reason or "Inventory in front might be full."))
                    end
                end
            else
                print("Turtle slot " .. slotNum .. " is empty. Skipping.")
            end
            print("") -- Add a blank line for readability between slots
        end
        print("--- Turtle inventory cleaning complete ---")
    end

    --- Inspects the inventory of a chest placed directly in front of the turtle
    --- and sucks items into the turtle's inventory based on the item_mapping.
    local function transferFromFrontChest()
        print("--- Inspecting and transferring from front chest ---")

        -- Try to wrap the peripheral in front of the turtle.
        local chest = peripheral.wrap("front")

        -- Check if the peripheral was successfully wrapped.
        if chest then
            -- turtle.suck() cannot be pointed at a chest slot: it always draws
            -- from the chest's LOWEST-numbered non-empty slot. The original code
            -- walked slots 2..17 in order and relied on the inspected slot and
            -- the sucked slot staying in lockstep, which only held when every
            -- staged item was a single item in one contiguous run starting at
            -- slot 2. Re-reading the lowest occupied slot each pass drops that
            -- assumption, and chest.list() means no hardcoded chest size either.
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
                    -- display name first, so the anvil-renamed chests beat the
                    -- shared item id they all have; then item id; then NBT hash
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
            
            -- Original code also included a dig operation after chest inspection
            turtle.select(12) -- Select slot 12
            turtle.dig()     -- Attempt to dig the block in front
            print("Selected slot 12 and attempted to dig the block in front.")

        else
            -- If no peripheral was found, inform the user.
            print("No inventory peripheral (like a chest) found directly in front. Cannot transfer items.")
            print("Please place a chest in front of the turtle and try again.")
        end
    end

    -- Execute the two main logistics steps
    cleanTurtleInventory()
    transferFromFrontChest()

    print("Turtle logistics operation complete.")
    scanReady()
end





local function deposit()
    digReady()
    turtle.dig()
    turtle.select(14)
    turtle.place()
    for i=1,9 do
        turtle.select(i)
        turtle.drop()
    end
    turtle.select(14)
    turtle.dig()
    turtle.select(1)
end

  
local function chat(message)
    turtle.select(10) --chatbox slot
    turtle.equipLeft()
    os.sleep(1)
    p = peripheral.wrap("left")
    p.sendMessageToPlayer(message, "veganradiation")
    turtle.equipLeft()
    turtle.select(1)
end


local function warpPlate()
    digReady()
    deposit() -- clear inv
    turtle.select(1)
    turtle.dig() -- make way for warp plate
    turtle.digUp()
    turtle.up()
    turtle.dig()
    turtle.down()
    turtle.select(13)   -- slot for the warp plate
    turtle.place()  -- place warp plate
    turtle.select(1)
    turtle.digUp()  -- make way for vacuum hopper
    turtle.select(12)   -- slot for the vacuum hopper
    turtle.placeUp()
    turtle.down()
    os.sleep(1)
    turtle.up()
    for i=1,9 do turtle.select(i) turtle.suckUp() end  --get everything from the hopper
    turtle.select(12)   --select vacuum hopper
    turtle.digUp() -- retreive vacuum hopper
    turtle.select(11) --chest for the activated warp stone
    turtle.placeUp()  -- put down the activated warp stone chest up
    for i=1,9 do turtle.select(i) turtle.dropUp() end -- put all the items (including warp stone) into chest
    chat("You have 30 seconds to come collect the bot...")
    print("pausing functionality")
    --for i=1,30 do chat(tostring(30-i)) os.sleep(0.5) end
    --local input = io.read() -- Wait for user input
    print("resuming functionality")
    chat("The bot has resumed!")
    turtle.select(13) --select warp plate slot
    turtle.dig() -- get the warp plate
    turtle.select(11)       -- select the warp chest slot
    turtle.digUp()              -- get the warp stone chest
end


local function move(distance)
    for i=1,distance do turtle.dig() turtle.digUp() turtle.forward() end
end

local function refuel()
    digReady()
    turtle.dig()
    turtle.select(16)
    turtle.place()
    turtle.suck()
    os.sleep(1)
    turtle.refuel()
    turtle.drop()
    turtle.dig()
    fuel = turtle.getFuelLevel()
    print("Fuel Level is now... " .. fuel)
end

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
        for i=1,math.abs(y) do 
            turtle.digUp()
            turtle.dig() --accessibility 2x1
            turtle.up()
        end
    elseif y < 0 then 
        for i=1,math.abs(y) do
            turtle.digDown()
            turtle.dig() --accessibility 2x1
            turtle.down()
        end
    end
end

local function calcDist(x,y,z)
    distance = math.sqrt(x^2+y^2+z^2)
    return distance
end
        

local function scan_and_search(radius)
    scanReady()
    p=peripheral.wrap("left")
    scan_data = p.scan(radius)
    digReady()
    local closest_block = 99999
    for _ , item_data in pairs(scan_data) do
        if item_data.name == reference_ore or item_data.name == reference2 then 
            block_distance = calcDist(item_data.x, item_data.y, item_data.z)
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


local function scan_loop()
    success = scan_and_search(8)
    print("full scan")
    while success ~= nil do
        success = scan_and_search(3)
        print("miniscan")
    end
end

--actual code that runs on the bot
digReady()
-- was runTurtleLogistics(my_item_table, ...) - my_item_table was never defined
-- anywhere, so the mapping arrived nil and only worked because the function
-- ignored its own parameter and read the global. It now uses the parameter.
runTurtleLogistics(item_table,my_vacuum_hopper_id)
scanReady()
p = peripheral.wrap("left")
refuel()
cycles = 0
while true do
    if cycles > 3 then 
        refuel()
        warpPlate()
        cycles =0
    end
    cycles = cycles +1
    scan_loop()
    move(15)
    --os.sleep(5)
    deposit()
end





    




