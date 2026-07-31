local modem = peripheral.wrap("top")
local CHANNEL = 123

modem.open(CHANNEL)
modem.transmit(CHANNEL, CHANNEL, {type = "request_peripheral_list"})

local function pullEventTimeout(eventName, timeout)
  local timer = os.startTimer(timeout)
  while true do
    local ev = {os.pullEvent()}
    if ev[1] == eventName then
      os.cancelTimer(timer)
      return table.unpack(ev)
    elseif ev[1] == "timer" and ev[2] == timer then
      return nil
    end
  end
end

local peripheralLists = {}
local start = os.clock()
local totalTimeout = 3 -- seconds

while os.clock() - start < totalTimeout do
  local eventData = {pullEventTimeout("modem_message", 1)}
  if eventData[1] then
    local _, _, _, _, message = table.unpack(eventData)
    if type(message) == "table" and message.type == "peripheral_list" then
      peripheralLists[message.id] = message.peripherals
    end
  end
end

for id, peripherals in pairs(peripheralLists) do
  print("Computer ID:", id)
  for _, pname in ipairs(peripherals) do
    print("  " .. pname)
  end
end
