local modem = peripheral.wrap("top") -- modem on top of computer
local CHANNEL = 123

modem.open(CHANNEL)

-- Ask the modem for all peripheral names on this channel
local peripherals = modem.callRemote("peripheral.getNames")

if peripherals then
  print("Peripherals on channel " .. CHANNEL .. ":")
  for _, name in ipairs(peripherals) do
    print(name)
  end
else
  print("No peripherals found on channel " .. CHANNEL)
end
