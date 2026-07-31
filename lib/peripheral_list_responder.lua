local modem = peripheral.wrap("left") -- or whatever side
local chest = peripheral.wrap("right")
local CHANNEL = 123
modem.open(CHANNEL)

local function sendPeripheralList()
  local peripherals = peripheral.getNames()
  modem.transmit(CHANNEL, CHANNEL, {type = "peripheral_list", peripherals = peripherals, id = os.getComputerID()})
end

while true do
  local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
  if channel == CHANNEL and type(message) == "table" and message.type == "request_peripheral_list" then
    sendPeripheralList()
  end
end
