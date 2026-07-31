gathered = 0
while true do
    turtle.place()
    turtle.placeUp()
    turtle.digUp()
    turtle.select(2)
    turtle.dropDown()
    turtle.select(1)
    gathered = gathered + 1
    print(tostring(gathered))
    os.sleep(130)
end
