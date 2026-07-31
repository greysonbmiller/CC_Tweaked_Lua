print("setup")
print("13 = chatbox, 14 = trash")
print("15 = blueEnd, 16 = yellowEnd")
os.sleep(2)

turtle.select(13)
slot13 = turtle.getItemDetail()
if slot13.name == "minecraft:diamond_pickaxe" then
    turtle.equipLeft()
end


turtle.select(16)
turtle.digDown()
turtle.select(15)
turtle.digUp()
turtle.select(14)
turtle.dig()
turtle.select(1)

function chatmsg(message)
    turtle.select(13)
    turtle.equipLeft()
    chat = peripheral.wrap("left")
    chat.sendMessage(message)
    turtle.equipLeft()
end

while true do
    turtle.select(1)
    i = 0
    while i< 12 do
        --turtle.select(16)
        --turtle.place()
        --turtle.refuel()
        turtle.select(1)
--        turtle.inspect()
        turtle.dig()
        turtle.forward()
        turtle.digUp()
        turtle.digUp()
        turtle.digUp()
        turtle.digDown()
        turtle.turnRight()
        turtle.dig()
        turtle.turnRight()
        turtle.turnRight()
        turtle.dig()
        turtle.turnRight()
        i = i+1
    end
    print("placing")
    turtle.dig()
    turtle.select(14)
    turtle.place() --places trash
    turtle.select(1) --resets incase block obstructed
    turtle.digUp()
    turtle.select(15)
    turtle.placeUp() --places blueEnd
    for i=1,10 do
        count = turtle.getItemCount(i)
        turtle.select(i)
        if count ~= 0 then
            item = turtle.getItemDetail(i)
            if item.name == "minecraft:ancient_debris" then
                turtle.dropUp()
                chatmsg("Found Ancient Debris") 
                
            else
               turtle.drop() 
            end
        end
        --turtle.select(i) turtle.dropUp() end
    end
    print("deposited")
    turtle.select(1) --resets to clear obstruction
    turtle.digDown() -- make space for yellowEnd
    turtle.select(16)
    turtle.placeDown()
    turtle.suckDown()
    turtle.refuel()
    turtle.dropDown()
    turtle.digDown() --this points takes up yellowEnd
    turtle.select(15)
    turtle.digUp() -- collects blueEnd
    turtle.select(14)
    turtle.dig() -- collects trash
    print("recollected")
    fuel = turtle.getFuelLevel()
    chatmsg(tostring(fuel))
    --chatmsg("recollected")
    
end
    
    

