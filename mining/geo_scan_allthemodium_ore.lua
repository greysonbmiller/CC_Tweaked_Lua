counter = 0
g = peripheral.wrap("left")
range = 10
function scancost(range)
    fuelcost = g.cost(range)
    return fuelcost
end
print("cost will be: " ..scancost(range).. ".")
--print(scancost(3))    
result = g.scan(range)

for i,data in ipairs(result) do
    if data.name == "allthemodium:allthemodium_slate_ore" then
        counter = counter + 1
        --print(data.name)
        --print(tostring(counter))
        --print(data.x)
        --print(data.y)
        --print(data.z)
    end
end
