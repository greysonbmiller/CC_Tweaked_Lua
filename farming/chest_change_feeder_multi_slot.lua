local function feed()
    local slot1 = turtle.getItemDetail(1)
    local slot2 = turtle.getItemDetail(2)
    if slot1 ~= 0 and slot2 ~= 0 then
        turtle.select(1)
        turtle.drop(1)
        turtle.select(2)
        turtle.drop(1)
        turtle.select(3)
        turtle.drop(1)
        turtle.select(4)
        turtle.drop(1)
        turtle.select(5)
        turtle.drop(1)
        turtle.select(6)
        turtle.drop(1)
        print("dropped slots 1 and 2")
    else
        turtle.select(1)
        turtle.drop(1)
    end
end



-- Function to count the total number of items in the chest below the turtle
local function getItemCount()
    local side = "bottom" -- The chest is below the turtle
    if not peripheral.isPresent(side) then
        print("No peripheral found on the " .. side .. " side.")
        return nil
    end
    
    local chest = peripheral.wrap(side)
    local items = chest.list()
    
    local totalCount = 0
    for slot, item in pairs(items) do
        totalCount = totalCount + item.count
    end
    
    return totalCount
end

-- Function to count the number of items in the turtle's first slot
local function getTurtleSlotCount()
    local details = turtle.getItemDetail(1)
    return details and details.count or 0
end

-- Main loop
local previousItemCount = getItemCount()
local previousSlotCount = getTurtleSlotCount()

if previousItemCount == nil then
    return
end

-- Initial check for startup based on first slot
while previousSlotCount == 0 do
    print("Waiting for items in the first slot to start...")
    os.sleep(1)
    previousSlotCount = getTurtleSlotCount()
end

print("Startup detected: Items found in the first slot.")

while true do
    local currentItemCount = getItemCount()
    local currentSlotCount = getTurtleSlotCount()
    
    if currentItemCount == nil then
        return
    end

    -- Check for changes in the chest below the turtle
    if currentItemCount ~= previousItemCount then
        -- Change detected in chest, drop an item in the inventory in front
        feed()
        print("Item dropped due to change in chest count.")
        
        previousItemCount = currentItemCount
    end

    -- Check for changes in the turtle's first slot
    if previousSlotCount == 0 and currentSlotCount > 0 then
        -- Slot went from 0 to any number, drop an item in the inventory in front
        feed()
        print("Item dropped due to change in first slot count.")
    end
    
    previousSlotCount = currentSlotCount
    os.sleep(1) -- Wait for 1 second before checking again
end
