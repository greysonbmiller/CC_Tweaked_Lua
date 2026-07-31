-- inventory_sender.lua
-- Requires: Ender Modem + Advanced Peripherals Inventory Manager
--
-- Watches the item in your hand and sends its first letter + quantity
-- to a target turtle every 2 seconds.

local MODEM_SIDE   = "top"   -- side ender modem is attached
local MANAGER_SIDE = "left"  -- side inventory manager peripheral is attached
local TURTLE_ID    = 0       -- run `id` on the turtle and set that number here

local manager = peripheral.wrap(MANAGER_SIDE)
if not manager then
    error("No inventory manager found on side: " .. MANAGER_SIDE)
end

rednet.open(MODEM_SIDE)
print("Sending inventory data to turtle #" .. TURTLE_ID .. " every 2s...")

while true do
    local item = manager.getItemInHand()

    local message
    if item and item.displayName then
        local letter   = string.upper(string.sub(item.displayName, 1, 1))
        local quantity = item.count or 0
        message = letter .. ":" .. quantity
        print("Sent: " .. message .. "  (" .. item.displayName .. " x" .. quantity .. ")")
    else
        message = "none:0"
        print("Sent: none:0  (empty hand)")
    end

    rednet.send(TURTLE_ID, message)
    sleep(2)
end
