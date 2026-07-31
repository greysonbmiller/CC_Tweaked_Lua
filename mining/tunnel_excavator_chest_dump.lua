-- Excavation script with corrected traversal and chest placement logic
function refuel()
    turtle.select(15)
    turtle.digUp()
    turtle.placeUp()
    turtle.suckUp()
    turtle.refuel()
    turtle.dropUp()
    turtle.digUp()
    print(tostring(turtle.getFuelLevel()))
end


function placeChest()
    -- Clear the way in front of the turtle to place the chest
    turtle.dig()
    turtle.select(16)
    turtle.place()
    for i=1,14 do
        turtle.select(i)
        turtle.drop()
    end
    turtle.select(16)
    turtle.dig()
    refuel()
end

function digAndInspect()
    while turtle.detect() do
        turtle.dig()
        sleep(0.4)
    end
end

function moveForward()
    while not turtle.forward() do
        turtle.dig()
        sleep(0.4)
    end
    refuel()
end

function inventoryAlmostFull()
    local count = 0
    for i = 1, 15 do
        if turtle.getItemCount(i) > 0 then
            count = count + 1
        end
    end
    return count >= 10
end

function excavate()
    local segmentDepth = 315
    local segmentCount = 0
    while true do
        --dig down
        for i=1,segmentDepth do
            while turtle.detectDown() do
                turtle.digDown()
            end
            if inventoryAlmostFull() then
                placeChest()
            end
            if not turtle.down() then
                return --hitbedrock
            end
        end
        --move forward
        digAndInspect()
        if not turtle.forward() then
            return
        end
        
        --Dig up
        for i=1,segmentDepth do
            while turtle.detectUp() do
                turtle.digUp()
            end
            if inventoryAlmostFull() then
                placeChest()
            end
            if not turtle.up() then
                return
            end
        end
        --move forward one
        digAndInspect()
        if not turtle.forward() then
            return
        end
        segmentCount = segmentCount + 1
    end
end
                

excavate(width, length, height)
