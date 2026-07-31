-- TurtleCraft piston simulation loop
-- Place block for 60s, remove it for 10s

-- Ensure turtle has at least 1 placeable block in slot 1
local function selectBlock()
    turtle.select(1)
    if turtle.getItemCount() == 0 then
        print("Out of blocks!")
        turtle.dig()
    end
    return true
end

while true do
    -- PLACE block (simulate piston retracted / block in place)
    if selectBlock() then
        turtle.place()
    end
    sleep(30)

    -- REMOVE block (simulate piston extended / block gone)
    turtle.dig()
    sleep(5)
end
