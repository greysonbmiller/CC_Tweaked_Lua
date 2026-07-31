local digsize = ...

local function dig(size)
    for i=1,size do
        while not turtle.forward() do
            turtle.dig()
        end
    end
end
local function digDown(size)
    for i=1,size do
        while not turtle.down() do
            turtle.digDown()
        end
    end
end
local function refuel()
    turtle.select(15)
    turtle.digUp()
    turtle.placeUp()
    turtle.select(1)
    turtle.suckUp()
    turtle.refuel()
    turtle.dropUp()
    turtle.select(15)
    turtle.digUp()
    turtle.select(1)
end
local function deposit()
    turtle.select(16)
    turtle.digUp()
    turtle.placeUp()
    for i=1,14 do turtle.select(i) turtle.dropUp() end
    turtle.select(16)
    turtle.digUp()
    turtle.select(1)
    refuel()
end

local function shiftR()
    turtle.turnRight()
    dig(1)
    turtle.forward()
    turtle.turnRight()
end
local function shiftL()
    turtle.turnLeft()
    dig(1)
    turtle.forward()
    turtle.turnLeft()
end

function digSquarePlaneR(dimension)
    for row = 1, dimension do
        for i = 1, dimension - 1 do
            dig(1)
        end
        deposit()               --deposits materials here into ender chest blue blue white
        if row < dimension then
            if row % 2 == 1 then
                turtle.turnRight()
                dig(1)
                turtle.turnRight()
            else
                turtle.turnLeft()
                dig(1)
                turtle.turnLeft()
            end
        end
    end
    turtle.turnRight()
    turtle.turnRight()
    digDown(1)
end

function digSquarePlaneL(dimension)
    for row = 1, dimension do
        for i = 1, dimension - 1 do
            dig(1)
        end
        if row < dimension then
            if row % 2 == 1 then
                turtle.turnLeft()
                dig(1)
                turtle.turnLeft()
            else
                turtle.turnRight()
                dig(1)
                turtle.turnRight()
            end
        end
    end
    turtle.turnLeft()
    turtle.turnLeft()
    digDown(1)
end

local function twoplanes(size)
    digSquarePlaneR(size)
    digSquarePlaneL(size)
end

totalDepth = 126
    

for i=1,totalDepth do
    twoplanes(tonumber(digsize))
end

