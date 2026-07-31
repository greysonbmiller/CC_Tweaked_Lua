local function isBlazeRods(slot)
    local item = turtle.getItemDetail(slot)
    if item and item.name == "minecraft:blaze_rod" then
        return true
    end
    return false
end

print("starting")
--while turtle.inspect() do
--    turtle.turnLeft()
--end


while true do
    for i=1,16 do
        turtle.select(i)
        turtle.suckDown()
        if isBlazeRods(i) then
            print("Found, dropping left")
            turtle.turnLeft()
            turtle.drop()
            turtle.turnRight()
        else
            print("Other, drop right")
            turtle.turnRight()
            turtle.drop()
            turtle.turnLeft()
        end
    
    end
end

