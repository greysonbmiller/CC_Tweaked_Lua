local modem = peripheral.wrap("left") -- turtle's wireless modem side
local chestSide = "right"
local targetSide = "back"

modem.open(123)

local chest = peripheral.wrap(chestSide)
local target = peripheral.wrap(targetSide)

local chestSize = 27 -- assume standard chest size, or scan dynamically

while true do
  local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
  if channel == 123 then
    if type(message) == "table" and message.cmd == "transfer" then
      for slot=1, chestSize do
        local moved = chest.pushItems(targetSide, slot, 64)
        print("Moved", moved, "items from slot", slot)
      end
      modem.transmit(replyChannel, channel, {status = "done"})
    end
  end
end
