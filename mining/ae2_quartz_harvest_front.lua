while true do
    local success, data = turtle.inspect()
    --if success then
    --    print(data.name)
    --end
    if data.name == "ae2:quartz_cluster" then
        turtle.dig()
        turtle.dropUp()
    end
end
