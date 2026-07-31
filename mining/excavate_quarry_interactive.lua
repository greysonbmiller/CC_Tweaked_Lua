-- Excavation script with corrected traversal and chest placement logic

function placeChest()
    -- Clear the way in front of the turtle to place the chest
    turtle.dig()
    turtle.select(16)
    turtle.place()
    for i=1,15 do
        turtle.select(i)
        turtle.drop()
    end
    turtle.select(16)
    turtle.dig()
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

function excavate(width, length, height)
    local direction = true  -- true = forward, false = backward

    for y = 1, height do
        for row = 1, width do
            for col = 1, length - 1 do
                digAndInspect()
                moveForward()
                if inventoryAlmostFull() then
                    placeChest()
                end
            end

            -- Prepare for next row
            if row < width then
                if direction then
                    turtle.turnRight()
                    digAndInspect()
                    moveForward()
                    turtle.turnRight()
                else
                    turtle.turnLeft()
                    digAndInspect()
                    moveForward()
                    turtle.turnLeft()
                end
                if inventoryAlmostFull() then
                    placeChest()
                end
                direction = not direction
            end
        end

        -- Return to start of next layer
        if not direction then
            turtle.turnLeft()
            turtle.turnLeft()
            for i = 1, length - 1 do
                moveForward()
            end
            turtle.turnLeft()
            for i = 1, width - 1 do
                moveForward()
            end
            turtle.turnLeft()
        end

        -- Descend
        if y < height then
            turtle.digDown()
            turtle.down()
        end
        direction = true
    end
end

-- User input
print("Enter width of quarry:")
local width = tonumber(read())

print("Enter length of quarry:")
local length = tonumber(read())

print("Enter height 315")
local height = 315

excavate(width, length, height)