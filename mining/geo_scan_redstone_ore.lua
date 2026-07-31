local radius = 15

local geoscanner = peripheral.wrap("right")

local scanData = geoscanner.scan(radius)

local foundDebris = false

for _, block in ipairs(scanData) do
    if block.name == "minecraft:deepslate_redstone_ore" then
        print("Found at x: " .. block.x .. "Y: " .. block.y .. "Z: " .. block.z .. " !!!")
        foundDebris = true
    end
end
if not foundDebris then
    print("nothing")
end

