local detector = peripheral.wrap("right")
local player = "SKAAAAL"

while true do

    local inv = detector.getPlayerInventory(player)
    if inv then
        local s1 = inv[1]
        local s2 = inv[2]
        if s1 and s1.name == "minecraft:cobblestone" then
            turtle.up()
        elseif s2 and s2.name == "minecraft:cobblestone" then
            turtle.down()
        end
    end
    sleep(0.5)
end
