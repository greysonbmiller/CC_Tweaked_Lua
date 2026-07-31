local function getItemCount()
    local side = "bottom" --where the chest is
    if not peripheral.isPresent(side) then
        print("wrong chest location")
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

local function getTurtleSlotCount()
    local details = turtle.getItemDetail(1)
    return details and details.count or 0
end

local previousItemCount = getItemCount()
local previousSlotCount = getTurtleSlotCount()

if previousItemCount == nil then
    return
end


local previousSlotCount = getTurtleSlotCount()

while true do
    local currentItemCount = getItemCount()
    local currentSlotCount = getTurtleSlotCount()

            
    if currentItemCount == nil then
        return
    end
    
    if currentItemCount ~= previousItemCount then
        turtle.select(1)
        turtle.drop(1)
        print("Item dropped due to change in chest count")
        
        previousItemCount = currentItemCount
    end
    
    if previousSlotCount == 0 and currentSlotCount > 0 then
        turtle.select(1)
        turtle.drop(1)
        print("Item dropped due to change in turtle slot 1")
        
        previousSlotCount = currentSlotCount
    end
    
    os.sleep(1)
end
