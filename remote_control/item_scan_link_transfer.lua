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

-- Separate routine for the sand action
local function sandRoutine()
  print("Executing: Sand IO Routine")
  -- Suck into all slots
  for i = 1, 16 do
    turtle.select(i)
    turtle.suck()
  end

  -- Turn around
  turtle.turnLeft()
  turtle.turnLeft()

  -- Drop from all slots
  for i = 1, 16 do
    turtle.select(i)
    turtle.drop()
  end

  -- Turn back around
  turtle.turnLeft()
  turtle.turnLeft()
end

-- "Link" routine: transfer from front chest to back turtle
local function linkRoutine()
  print("Executing: Link Routine")

  -- Wrap front block as inventory
  local frontPeripheral = peripheral.wrap("front")
  if not frontPeripheral or not frontPeripheral.list then
    print("Error: No inventory in front or cannot wrap as inventory.")
    return
  end

  -- Wrap back block as turtle
  local backPeripheral = peripheral.wrap("right")

  -- Transfer all items from front inventory to back turtle
  for slot, item in pairs(frontPeripheral.list()) do
    local success, err = pcall(function()
      frontPeripheral.pushItems(peripheral.getName(backPeripheral), slot)
    end)
    if not success then
      print("Failed to push slot " .. slot .. ": " .. tostring(err))
    else
      print("Transferred slot " .. slot .. " to back turtle.")
    end
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
