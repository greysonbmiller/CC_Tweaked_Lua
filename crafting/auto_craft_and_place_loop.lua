local inputSlots = {1,2,3,5,6,7,9,10,11}

local function isFirstSlotEmpty()
    local item = turtle.getItemDetail(1)
    return item == nil
end

local function suckItems()
    for _, slot in ipairs(inputSlots) do
        turtle.select(slot)
        turtle.suckDown(64)
    end
    turtle.select(1)
end

local function craftItems()
    if turtle.craft() then
        print("succcessSS")
    else
        print("scuffed")
    end
end

local function placeCraftedItems()
    while not isFirstSlotEmpty() do
        turtle.place()
        turtle.placeUp()
    end
end

while true do
    if isFirstSlotEmpty() then
        suckItems()
        craftItems()
    end
    placeCraftedItems()
end
