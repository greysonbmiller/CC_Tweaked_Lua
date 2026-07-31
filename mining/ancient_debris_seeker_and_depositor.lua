print("sleeping for 3 seconds before start")
print("TURTLE MUST BE FACING NORTH")

os.sleep(3)



--allmod = "allthemodium:allthemodium_slate_ore"
allmod = "minecraft:ancient_debris"
range = 10 --change to 16
function dropWaystone()
    turtle.dig()
    turtle.digDown()
    turtle.dig()
end

function readyToDig()
    turtle.select(16)
    if turtle.getItemCount() > 0 then
    local detail = turtle.getItemDetail()
    if detail.name == "minecraft:diamond_pickaxe" then
        turtle.equipLeft()
    end
    end
end

function readyToScan()
    turtle.select(16)
    if turtle.getItemCount() == 1 then
    local detail = turtle.getItemDetail()
    if detail.name ~= "minecraft:diamond_pixkaxe" then
        turtle.equipLeft()
    end
    end
end

function getCost(range)
    local cost = g.cost(range)
    print("cost will be: " ..cost.. ".")
    return cost
end

function getFuelLvl()
    local fuel = turtle.getFuelLevel()
    print("fuel left = " ..fuel.. ".")
    return fuel
end
    

function needFuelTF(range)
    local cost = getCost(range)
    local remainingfuel = getFuelLvl()
    if cost > remainingfuel then
        return true
    else
        return false
    end
end



function scan(range)
    local currentlowest = 999999
    local results = g.scan(range)
    if results ~= nil then
    for _, blockdata in ipairs(results) do
        if blockdata.name == allmod then
            local x = blockdata.x
            local y = blockdata.y
            local z = blockdata.z
            local distance = math.sqrt(x^2+y^2+z^2)
            if distance < currentlowest then
                currentlowest = distance
                lowx = x
                lowy = y
                lowz = z
            end
        end
    end
    end
    
    --print(lowx)
    --print(lowy)
    --print(lowz)
    --print("from scan function")
    --print(currentlowest)
    if currentlowest < 999999 then
        return lowx, lowy, lowz, currentlowest
    end
end


function movementy(value) --this function needs to be changed for allthemodium
    local disttomove = math.abs(value)--1
    if value < 0 then
        for i=1,disttomove do turtle.digDown() turtle.dig() turtle.down() end
    else
        for i=1,disttomove do turtle.digUp() turtle.dig() turtle.up() end
    end
end


function movementx(value)
    local dist = math.abs(value)
    if value > 0 then turtle.turnRight()
        for i=1,dist do turtle.digUp() turtle.dig() turtle.forward() end
        turtle.turnLeft()
    else 
        turtle.turnLeft()
        for i=1,dist do turtle.digUp() turtle.dig() turtle.forward() end
        turtle.turnRight()
    end
end

function movementz(value)
    local dist = math.abs(value)
    if value > 0 then
        turtle.turnRight()
        turtle.turnRight()
        for i=1,dist do turtle.digUp() turtle.dig() turtle.forward() end
        turtle.turnLeft()
        turtle.turnLeft()
    else
        for i=1,dist do turtle.digUp() turtle.dig() turtle.forward() end
    end
end

function chat()
    turtle.select(13)
    turtle.equipLeft()
    c = peripheral.wrap("left")
    c.sendMessage("Found Debris BOIIII", "Debris_Seeker <3")
    turtle.equipLeft()
end

function deposit()
    turtle.select(10)
    if true then -- commented out check to deposit turtle.getItemCount() ~= 0 then
        print("placing chest")
        turtle.dig()
        turtle.select(15) -- BlueEnd
        turtle.place()
        for i=1,12 do
            turtle.select(i)
            turtle.drop()
        end
        turtle.select(15) --BlueEnd
        turtle.dig()
    end
    turtle.select(1)
end

function refuelEnd()
    turtle.select(1)
    turtle.dig()
    turtle.select(14)
    turtle.place()
    turtle.suck()
    turtle.refuel()
    turtle.drop()
    turtle.dig()
    print(tostring(turtle.getFuelLevel()))
end
    


function scanAndDig(range)
        local x,y,z,distance = scan(range)
        if distance then
            readyToDig()
            print("ore found, pause")
            if range < 5 then
                chat()
            end
            print(x)
            if x ~= nil then
                movementx(x)
            end
            print(y)
            if z ~= nil then
                movementz(z)
            end
            print(z)
            if y ~= nil then
                movementy(y)
            end
            print(distance)
            readyToScan()
            scanAndDig(2)
            --only sleep for manual allthemodium
            --os.sleep(10)
        else
            readyToDig()
            print("depositing")
            deposit()
            print("refueling, twice")
            refuelEnd()
            os.sleep(5)
            refuelEnd()
            for i=1,16 do turtle.dig() turtle.digUp() turtle.digUp() turtle.forward() end
            readyToScan()
        end
end

     

readyToScan()
g = peripheral.wrap("left")
while true do
    scanAndDig(range)
end   


--scan(6)
