-- This program allows a ComputerCraft/TurtleCraft turtle to receive messages
-- over a wireless modem on a specified channel.

-- Define the network channel to listen on.
local CHANNEL = 420

-- Initialize the modem.
-- We assume the modem is placed on top of the turtle.
-- 'peripheral.wrap("top")' attempts to connect to a peripheral on the top side.
local modem = peripheral.wrap("top")

-- Check if the modem was successfully wrapped.
if not modem then
    print("Error: No modem found on top. Please place a wireless modem on top of the turtle.")
    return -- Exit the program if no modem is found.
end

-- Open the specified channel to start listening for messages.
-- This is crucial for the modem to receive data on this channel.
modem.open(CHANNEL)

print("Turtle Modem Receiver")
print("---------------------")
print("Modem initialized on top. Ready to receive messages.")
print("Listening on channel: " .. CHANNEL)
print("Waiting for incoming messages...")

-- Main loop to listen for modem messages.
while true do
    -- os.pullEvent() waits for any event.
    -- We are specifically interested in "modem_message" events.
    -- The parameters returned by "modem_message" are:
    -- eventName, peripheralName, channel, replyChannel, message, distance
    local event, peripheralName, channel, replyChannel, message, distance = os.pullEvent("modem_message")

    -- Check if the event is a modem message and if it's on our desired channel.
    if event == "modem_message" and channel == CHANNEL then
        print("--------------------------------------------------")
        print("Received Message!")
        print("  From Peripheral: " .. peripheralName) -- The name of the peripheral that sent it (e.g., "modem_0")
        print("  On Channel:      " .. channel)
        print("  Message:         " .. message)
        -- The 'dista