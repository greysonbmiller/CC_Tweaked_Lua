local inventoryManager = peripheral.wrap("right")
local modem = peripheral.wrap("top")

local CHANNEL = 123
modem.open(CHANNEL)

local sourceInventory = "right"  -- chest on turtle wrapped on its right side
local targetInventory = "player" -- player inventory, verify name with peripheral.getNames()

local function transferAllItems()
  local size = inventoryManager.getInventorySize(sourceInventory)
  for slot=1,size do
    local moved = inventoryManager.pullItem(sourceInventory, targetInventory, slot, 64, 1)
    if moved and moved > 0 then
      print("Moved " .. moved .. " items from slot " .. slot)
    end
  end
end

print("Starting transfer from chest to player inventory")

while true do
  transferAllItems()
  os.sleep(2)
end
