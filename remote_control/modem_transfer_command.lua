local modem = peripheral.wrap("top")

modem.open(123)

modem.transmit(123,123,{cmd = "transfer"})

--wait
local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
if message and message.status == "done" then
    print("turtle finished transfer")
end
