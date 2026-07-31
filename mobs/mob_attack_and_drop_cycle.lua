local slot = 1

while true do
    turtle.attack()
    turtle.select(slot)
    turtle.dropDown()
    slot = slot + 1
    turtle.dropDown()
    if slot >= 17 then
        slot = 1
    end
end
