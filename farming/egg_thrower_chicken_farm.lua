while true do
    redstone.setAnalogOutput("front",15)
    print("true")
    if turtle.suckDown() then
        item = turtle.getItemDetail()
        if item.name == "minecraft:egg" then
            turtle.drop()
        else
            turtle.dropUp()
        end
    end
    redstone.setAnalogOutput("front",0)
    print("false")
    os.sleep(1)
end

