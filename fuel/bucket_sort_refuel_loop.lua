while true do
turtle.suck()
if turtle.getItemCount() ~= 0 then
    data = turtle.getItemDetail()
    
    if data.name == "minecraft:bucket" then
        turtle.turnRight()
        turtle.turnRight()
        turtle.place()
        turtle.turnLeft()
        turtle.turnLeft()
    else
        turtle.drop()
        os.sleep(10)
    end
end
end
