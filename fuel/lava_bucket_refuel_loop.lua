local function isEmptyBucket(slot)
    local item = turtle.getItemDetail(slot)
    return item and item.name == "minecraft:bucket"
end

local function isLavaBucket(slot)
    local item = turtle.getItemDetail(slot)
    return item and item.name == "minecraft:lava_bucket"
end

while true do
    turtle.select(1)
    turtle.drop()
    
    turtle.suck()
    
    if isEmptyBucket(1) then
        turtle.turnLeft()
        turtle.turnLeft()
        turtle.place()
        turtle.turnLeft()
        turtle.turnLeft()
        turtle.drop()
    elseif isLavaBucket(1) then
        turtle.drop()
        os.sleep(30)
    else
        turtle.drop()
        os.sleep(5)
    end
end
