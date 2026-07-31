-- Function to check if the turtle has enough blocks
function hasEnoughBlocks(requiredBlocks)
    local totalBlocks = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            totalBlocks = totalBlocks + item.count
        end
    end
    return totalBlocks >= requiredBlocks
end

-- Function to select the next slot with blocks
function selectNextSlotWithBlocks()
    for i = 1, 16 do
        if turtle.getItemCount(i) > 0 then
            turtle.select(i)
            return true
        end
    end
    return false
end

-- Function to place a block below the turtle
function placeBlockBelow()
    if not turtle.detectDown() then
        turtle.placeDown()
    end
end

-- Function to move the turtle and place blocks
function moveAndPlace()
    placeBlockBelow()
    if not turtle.forward() then
        turtle.dig()
        turtle.forward()
    end
end

-- Main function to build the platform
function buildPlatform(size)
    local totalBlocksNeeded = size * size

    if not hasEnoughBlocks(totalBlocksNeeded) then
        print("Not enough blocks in inventory.")
        return
    end

    -- Start building the platform
    for i = 1, size do
        for j = 1, size do
            if not selectNextSlotWithBlocks() then
                print("Ran out of blocks.")
                return
            end
            moveAndPlace()
        end

        if i < size then
            if i % 2 == 1 then
                turtle.turnRight()
                moveAndPlace()
                turtle.turnRight()
            else
                turtle.turnLeft()
                moveAndPlace()
                turtle.turnLeft()
            end
        end
    end

    -- Move back to the starting position
    if size % 2 == 1 then
        turtle.turnRight()
        for i = 1, size - 1 do
            turtle.forward()
        end
        turtle.turnRight()
    else
        turtle.turnLeft()
        for i = 1, size - 1 do
            turtle.forward()
        end
        turtle.turnLeft()
    end
end

-- Get the size of the platform from the user
print("Enter the size of the platform (x by x):")
local size = tonumber(read())

-- Start building the platform
if size and size > 0 then
    buildPlatform(size)
else
    print("Invalid size entered.")
end
