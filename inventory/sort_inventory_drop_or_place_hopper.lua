
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