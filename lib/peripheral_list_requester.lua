local modem = peripheral.wrap("top")
local CHANNEL = 123

modem.open(CHANNEL)

-- Send request to all clients on the channel
modem.transmit(CHANNEL, CHANNEL, {type = "request_peripheral_list"})

-- Collect responses
local peripheralLists = {}

-- Listen for responses for 3 seconds
local start = os.clock()
while os.clock() - start < 3 do
  local event, side, channel, replyChannel, message, distance = os.pullEventTimeout("modem_message", 1)
  if message and type(message) == "table" and message.type == "peripheral_list" then
    peripheralLists[message.id] = message.peripherals
  end
end

-- Print all received peripherals
for id, peripherals in pairs(peripheralLists) do
  print("Computer ID:", id)
  for _, pname in ipairs(peripherals) do
    print("  " .. pname)
  end
end
