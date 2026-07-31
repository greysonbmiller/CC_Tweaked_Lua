local weakAutomata = peripheral.wrap("right")
if not weakAutomata then
  print("Error: weakAutomata peripheral not found.")
  return
end

local function safeCall(func, ...)
  local ok, err = pcall(func, ...)
  if not ok then
    print("Error during turtle action: " .. tostring(err))
  end
end

while true do
  local items, err = weakAutomata.scanItems()
  if not items then
    print("Error scanning items: " .. (err or "unknown"))
  else
    local clayCount = 0

    for _, item in ipairs(items) do
      local name = item.name
      local count = item.count or 1

      if name == "minecraft:cobblestone" then
        print("Cobblestone detected, turning left")
        safeCall(turtle.turnLeft)
      elseif name == "minecraft:dirt" then
        print("Dirt detected, turning right")
        safeCall(turtle.turnRight)
      elseif name == "minecraft:stone" then
        print("Stone detected, moving up")
        safeCall(turtle.up)
      elseif name == "minecraft:gravel" then
        print("Gravel detected, moving down")
        safeCall(turtle.down)
      elseif name == "minecraft:diamond" then
        print("Diamond detected, moving forward")
        safeCall(turtle.forward)
      elseif name == "minecraft:emerald" then
        print("Emerald detected, moving back")
        safeCall(turtle.back)
      elseif name == "minecraft:clay_ball" or name == "minecraft:clay" then
        -- Accept both clay balls and clay blocks (adjust if needed)
        clayCount = clayCount + count
      end
    end

    if clayCount > 0 then
      print("Clay detected x" .. clayCount .. ", executing up/down/left/right that many times.")
      for i = 1, clayCount do
        safeCall(turtle.up)
        safeCall(turtle.down)
        safeCall(turtle.turnLeft)
        safeCall(turtle.turnRight)
      end
    end
  end

  os.sleep(2)
end
