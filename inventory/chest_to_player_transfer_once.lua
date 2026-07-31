local CHANNEL = 123
local modem = peripheral.wrap("top")
local inventoryManager = peripheral.wrap("right")

modem.open(CHANNEL)

local chestName = "right"    -- chest peripheral as seen on the wireless network (the turtle's right side)
local playerInventory = "player"  -- your player memory card reference

-- Get the chest size by calling remotely through the Inventory Manager
-- Unfortunately Inventory Manager doesn't expose getInventorySize, so we must know slot count or hardcode
local chestSize = 27 -- typical vanilla chest size, adjust if you know differently

-- Pull all items slot by slot
for slot = 1, chestSize do
  -- Try to pull max stack (64) from chest slot to player inventory slot 1 (destinationSlot = 1 means "any slot")
  local moved, err = inventoryManager.pullItem(chestName, playerInventory, slot, 64, 1)
  if moved then
    print(string.format("Pulled %d items from slot %d", moved, slot))
  else
    print(string.format("Failed to pull from slot %d: %s", slot, err or "unknown error"))
  end
end
