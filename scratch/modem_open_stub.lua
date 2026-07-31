local chest = peripheral.wrap("right")
local modem = peripheral.wrap("left")

modem.open(123)

print("wrapping done network open")

while true do
    os.sleep(5)
end
