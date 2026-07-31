local modem = peripheral.find("modem")
modem.open(42)

while true do

    local slot = inv.getSelectedSlot()
    print(slot)
    modem.transmit(42,0,slot)
    sleep(0.5)
end
