-- Ensure the turtle has the necessary peripheral
local side = "bottom" -- Adjust this to the correct side where your chest is placed
if not peripheral.isPresent(side) then
  print("No peripheral found on the " .. side .. " side.")
  return
end

local chest = peripheral.wrap(side)

-- Get the list of items in the chest
local items = chest.list()

-- Count the total number of items
local totalCount = 0
for slot, item in pairs(items) do
  totalCount = totalCount + item.count
end

-- Output the total count
print("Total number of items in the chest: " .. totalCount)
