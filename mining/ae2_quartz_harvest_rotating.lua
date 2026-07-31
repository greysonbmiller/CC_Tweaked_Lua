while true do
    local success, inspectdata = turtle.inspect()
    if inspectdata.name == "ae2:quartz_cluster" then
        turtle.dig()
        turtle.dropUp()
    end
    turtle.turnRight()
end

