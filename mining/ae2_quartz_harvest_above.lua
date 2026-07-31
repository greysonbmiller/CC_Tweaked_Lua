while true do
    local success, inspectdata = turtle.inspectUp()
    if inspectdata.name == "ae2:quartz_cluster" then
        turtle.digUp()
        turtle.dropDown()
    end
    --turtle.turnRight()
end

