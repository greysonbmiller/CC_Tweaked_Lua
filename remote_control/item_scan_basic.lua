-- Wrap the weakAutomata peripheral
local weakAutomata = peripheral.wrap("right")
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

    for _, item in ipairs(items) do
      local name = item.name
      local count = item.count or 1

      if name == "minecraft:clay" or name == "minecraft:clay_ball" then
        clayCount = clayCount + count
      elseif actionMap[name] then
        -- Add to instruction list if it's a valid trigger item
        table.insert(instructions, actionMap[name])
      end
    end

    if clayCount > 0 and #instructions > 0 then
      for _, instr in ipairs(instructions) do
        print("Executing: " .. instr.desc .. " x" .. clayCount)
        for i = 1, clayCount do
          safeCall(instr.action)
        end
      end
    else
      print("No valid action: clay or instruction block missing.")
    end
  end

  os.sleep(2)
end
