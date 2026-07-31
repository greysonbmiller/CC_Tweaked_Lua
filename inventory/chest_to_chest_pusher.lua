-- Wrap the chest on the right side
local chest = peripheral.wrap("right")
if not chest then
  error("No chest found on right side")
end

-- Define the target side — where the other turtle/inventory is
local targetSide = "left"

-- Get number of slots in the chest
local chestSize = 10

-- Move items from the chest to the adjacent inventory
for slot = 1, chestSize do
  local item = chest.getItemDetail(slot)
  if item then
    local moved = chest.pushItems(targetSide, slot, item.count)
    print(("Moved %d of %s from chest slot %d"):format(moved, item.name, slot))
  end
end
