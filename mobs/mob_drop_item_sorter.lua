-- Function to check if an item has NBT data
local function hasNBTData(item)
    return item and item.nbt
end

while true do
    -- Clear slots 4 and beyond to ensure no items are there
    for slot = 4, 16 do
        turtle.select(slot)
        turtle.drop()
    end

    -- Loop through slots 1, 2, and 3 to suck items from the inventory above
    for slot = 1, 3 do
        turtle.select(slot)
        turtle.suckUp(1)

        -- Inspect the item in the current slot
        local itemDetail = turtle.getItemDetail(slot)

        if itemDetail then
            if hasNBTData(itemDetail) then
                -- If item has NBT data, drop it up
                turtle.place(1)
            else
                -- If item doesn't have NBT data, place it back in the front inventory
                turtle.dropUp()
            end
        end
    end

    -- Wait for 3 seconds before repeating
    sleep(3)
end
