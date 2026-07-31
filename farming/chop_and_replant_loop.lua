local function remove()
    if turtle.detect() == true then
        return true
    else
        sleep(1)
        return false
    end
end



while true do    
    
    if remove()  == true then
    
        turtle.dig()
        turtle.select(1)
        turtle.drop()
        turtle.up()
        turtle.select(2)
        turtle.place()
        turtle.down() 
    end
end
