-- Open the modem on the right side
local modem = peripheral.open("right", "modem")

-- Main loop to listen for commands
while true do
    -- Pull modem_message events
    local event, peripheralName, channel, replyChannel, message = os.pullEvent("modem_message")

    -- Check if the message is on the designated channel (420)
    if channel == 420 then
        -- Extract the command character (X) and the count string (YY)
        local commandChar = string.sub(message, 1, 1)
        local countStr = string.sub(message, 2)
        -- Convert count string to a number, default to 1 if not provided or invalid
        local count = tonumber(countStr) or 1

        local success = false -- Flag to track if a command was executed

        -- Execute the command based on the character
        for i = 1, count do
            if commandChar == "u" then
                success = turtle.up()
            elseif commandChar == "d" then
                success = turtle.down()
            elseif commandChar == "l" then
                success = turtle.turnLeft()
            elseif commandChar == "r" then
                success = turtle.turnRight()
            elseif commandChar == "f" then
                success = turtle.forward()
            elseif commandChar == "b" then
                success = turtle.back()
            -- Add more commands here if needed, following the pattern
            -- elseif commandChar == "s" then
            --     success = turtle.suck()
            -- elseif commandChar == "p" then
            --     success = turtle.place()
            end

            -- If a command failed (e.g., blocked), break the loop for this command
            if not success then
                break
            end
        end
    end
end
