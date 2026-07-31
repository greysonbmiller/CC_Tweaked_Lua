local item_table = {
    ["bd1cda511ce2e0eab47114c078331bfd"] = 11,          --warp plate chest
    ["e8cd9eb49d8937b8fb01eb8168d5dfa4"] = 14,          --deposit chest
    ["5ebb53ada9faf3195b5b112dcc9bf624"] = 16,          --refuel chest
    ["mob_grinding_utils:absorption_hopper"] = 12,       --vacuum hopper
    ["waystones:warp_plate"] = 13,                      --warp plate
    ["advancedperipherals:geo_scanner"] = 15,             -- geo scanner
    ["advancedperipherals:chat_box"] = 10                  --chat box
}

local VACUUM_HOPPER_ITEM_NAME = "mob_grinding_utils:absorption_hopper" -- Example: adjust if your mod uses a different ID

print("Starting inventory scan and item distribution...")

-- Loop through all 16 inventory slots of the turtle
for slotNum = 1, 16 do
    print("--- Processing slot " .. slotNum .. " ---")
    turtle.select(slotNum) -- Select the current slot

    local itemDetails = turtle.getItemDetail(slotNum) -- Get detailed information about the item in this slot

    if itemDetails then -- Check if there's actually an item in the slot
        if itemDetails.name == VACUUM_HOPPER_ITEM_NAME then
            print("Found a Vacuum Hopper ('" .. itemDetails.name .. "') in slot " .. slotNum .. ".")
            print("Attempting to place one Vacuum Hopper in front...")
            local success, reason = turtle.place() -- Attempt to place one item from the selected stack

            if success then
                print("Successfully placed one Vacuum Hopper.")
            else
                print("Failed to place Vacuum Hopper: " .. (reason or "Unknown reason, block in front might be occupied."))
            end

            -- After attempting to place, check if any items (including the placed hopper if placement failed)
            -- are still in the slot. If so, drop the rest.
            if turtle.getItemCount(slotNum) > 0 then
                print("Remaining items found in slot " .. slotNum .. ". Dropping remaining stack.")
                local dropSuccess, dropReason = turtle.drop() -- Drop the entire remaining stack
                if dropSuccess then
                    print("Successfully dropped remaining items from slot " .. slotNum .. ".")
                else
                    print("Failed to drop remaining items: " .. (dropReason or "Unknown reason, inventory in front might be full."))
                end
            end
        else
            -- If it's not a Vacuum Hopper, just drop all items in the slot
            print("Found item '" .. itemDetails.name .. "' in slot " .. slotNum .. ". Dropping entire stack.")
            local success, reason = turtle.drop() -- Drop the entire stack
            if success then
                print("Successfully dropped all items from slot " .. slotNum .. ".")
            else
                print("Failed to drop items: " .. (reason or "Unknown reason, inventory in front might be full."))
            end
        end
    else
        print("Slot " .. slotNum .. " is empty. Skipping.")
    end
    print("") -- Add a blank line for readability between slots
end

print("Inventory scan and item distribution complete.")

local function checkitem(name, nbt)
    print(name)
    if item_table[name] == nil and item_table[nbt] == nil then
        turtle.select(1)
        turtle.suck()
    end
    if item_table[name] ~= nil then
        print(name)
        if item_table[name] > 9 then
            print("name" .. item_table[name])
            turtle.select(item_table[name])
            turtle.suck(1)
        end
    end
    if item_table[nbt] ~= nil then
        print(nbt)
        if item_table[nbt] > 9 then
            print("nbt" .. item_table[nbt])
            turtle.select(item_table[nbt])
            turtle.suck(1)
        end
    end
end

-- This script inspects the inventory of a chest placed directly in front of the turtle.

-- Try to wrap the peripheral in front of the turtle.
-- Make sure there is a chest (or any inventory peripheral) directly in front of the turtle.
local chest = peripheral.wrap("front")

-- Check if the peripheral was successfully wrapped.
if chest then

    local numSlots = 17 -- Standard chest inventory size

    print("--- Inspecting Front Chest Inventory ---")

    for slotNum = 1, numSlots do
        --print("--- Processing slot " .. slotNum .. " ---")

        -- Use peripheral.call to get the item details from the chest peripheral.
        -- The function name for getting item details from a peripheral is typically 'getItemDetail'.
        -- It returns nil if the slot is empty, or a table of details if an item is present.
        local itemDetails = chest.getItemDetail(slotNum)

        if itemDetails then
            -- If itemDetails is not nil, an item exists in this slot.
            checkitem(itemDetails.name,itemDetails.nbt)
            --print("  Name: " .. itemDetails.name)
            --print("  Count: " .. itemDetails.count)
            --print("  Damage/Metadata: " .. (itemDetails.nbt or "N/A"))
            -- You can print more details if itemDetails contains them (e.g., displayName)
            --if itemDetails.displayName then
            --    print("  Display Name: " .. itemDetails.displayName)
            --end
        --else
            -- If itemDetails is nil, the slot is empty.
            --print("  Slot is empty.")
        end
    end

    print("--- Inventory inspection complete ---")
    turtle.select(12)
    turtle.dig()
else
    -- If no peripheral was found, inform the user.
    print("No inventory peripheral (like a chest) found directly in front.")
    print("Please place a chest in front of the turtle and try again.")
end