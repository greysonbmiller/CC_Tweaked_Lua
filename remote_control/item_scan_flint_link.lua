-- Wrap the weakAutomata peripheral
local weakAutomata = peripheral.find("weakAutomata")
if not weakAutomata then
  print("Error: weakAutomata peripheral not found.")
  return
end

-- Mapping from item name to turtle function and description
local actionMap = {
  ["minecraft:cobblestone"] = { action = turtle.turnLeft, desc = "Turn Left" },
  ["minecraft:dirt"]        = { action = turtle.turnRight, desc = "Turn Right" },
  ["minecraft:stone"]       = { action = turtle.up,        desc = "Move Up" },
  ["minecraft:gravel"]      = { action = turtle.down,      desc = "Move Down" },
  ["minecraft:diamond"]     = { action = turtle.forward,   desc = "Move Forward" },
  ["minecraft:emerald"]     = { action = turtle.back,      desc = "Move Back" },
}

-- Routine for the sand action
local function sandRoutine()
  print("Executing: Sand IO Routine")
  for i = 1, 16 do
    turtle.select(i)
    turtle.suck()
  end

  turtle.turnLeft()
  turtle.turnLeft()

  for i = 1, 16 do
    turtle.select(i)
    turtle.drop()
  end

  turtle.turnLeft()
  turtle.turnLeft()
end

-- Routine for the flint action: linking front and back inventories
local function linkRoutine()
  print("Executing: Link Routine")

  local frontPeripheral = peripheral.wrap("front")
  if not frontPeripheral or not frontPeripheral.list then
    print("Error: No inventory found in front.")
    return
  end

  local backPeripheral = peripheral.wrap("back")
  if not backPeripheral or not backPeripheral.pullItems then
    print("Error: No inventory found behind.")
    return
  end

  local frontName = peripheral.getName(frontPeripheral)
  local backName = peripheral.getName(backPeripheral)

  -- Pull from front, push to back
  for slot, item in pairs(frontPeripheral.list()) do
    local pulled = backPeripheral.pullItems(frontName, slot)
    print(string.format("Transferred %d of %s from front slot %d to back.", pulled or 0, item.name, slot))
  end
end

-- Helper for safe turtle calls
local function safeCall(fn)
  local ok, err = pcall(fn)
  if not ok then
    print("Action failed: " .. tostring(err))
  end
end

-- Poll loop
while true do
  local items, err = weakAutomata.scanItems()
  if not items then
    print("Scan error: " .. (err or "unknown"))
  else
    local clayCount = 0
    local instructions = {}
    local sawSand = false
    local sawFlint = false

    for _, item in ipairs(items) do
      local name = item.name
      local count = item.count or 1

      if name == "minecraft:clay" or name == "minecraft:clay_ball" then
        clayCount = clayCount + count
      elseif actionMap[name] then
        table.insert(instructions, actionMap[name])
      elseif name == "minecraft:sand" then
        sawSand = true
      elseif name == "minecraft:flint" then
        sawFlint = true
      end
    end

    if clayCount > 0 then
      if #instructions > 0 then
        for _, instr in ipairs(instructions) do
          print("Executing: " .. instr.desc .. " x" .. clayCount)
          for i = 1, clayCount do
            safeCall(instr.action)
          end
        end
      end

      if sawSand then
        sandRoutine()
      end

      if sawFlint then
        linkRoutine()
      end
    else
      print("No clay block detected. Ignoring all actions.")
    end
  end

  os.sleep(2)
end
