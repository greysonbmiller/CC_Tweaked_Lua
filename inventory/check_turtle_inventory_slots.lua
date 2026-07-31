for i = 1, 16 do
    turtle.select(i)
    local item = turtle.getItemDetail()

    if item then
        print("Slot " .. i .. ": " .. item.name)
    else
        print("Slot " .. i .. ": Empty")
    end
end

turtle.select(1)
