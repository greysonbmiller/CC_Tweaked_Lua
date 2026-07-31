function extract(slot)
    turtle.select(slot)
    count = turtle.getItemCount()
    while count < 64 do
        turtle.suckDown(64-count)
        count = turtle.getItemCount()
        os.sleep(2)
    end
end


    
function craft()
    turtle.select(1)
    turtle.craft(64)
    turtle.transferTo(2,16)
    turtle.transferTo(5,16)
    turtle.transferTo(7,16)
    turtle.transferTo(10,16)
    turtle.select(1)
    turtle.craft(16)
    turtle.transferTo(2,4)
    turtle.transferTo(5,4)
    turtle.transferTo(7,4)
    turtle.transferTo(10,4)
    turtle.select(1)
    turtle.craft(4)
    turtle.transferTo(2,1)
    turtle.transferTo(5,1)
    turtle.transferTo(7,1)
    turtle.transferTo(10,1)
    turtle.select(1)
    turtle.craft(1)
    turtle.dropUp()
end    

while true do
    extract(2)
    extract(5)
    extract(7)
    extract(10)
    craft()
end
    
    
    
    
