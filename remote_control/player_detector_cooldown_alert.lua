-- Config
local DETECTION_RANGE = 20
local COOLDOWN_MINUTES = 30
local COOLDOWN_SECONDS = COOLDOWN_MINUTES * 60

-- Peripherals
local detector = peripheral.find("playerDetector")

-- Stores {username = {lastDetectedTimeMillis = <epoch_ms>}}
local detectedPlayers = {}

-- Formats seconds to M:SS
local function formatTime(totalSeconds)
    if totalSeconds < 0 then totalSeconds = 0 end
    local minutes = math.floor(totalSeconds / 60)
    local remainingSeconds = math.floor(totalSeconds % 60)
    return string.format("%d:%02d", minutes, remainingSeconds)
end

if not detector then
    print("Player Detector not found!")
    return
end


-- Tracks real-world time of last scan (milliseconds)
local lastScanTimeMillis = os.epoch()

while true do
    term.clear()
    term.setCursorPos(1,1)

    local currentTimeMillis = os.epoch()

    -- Check if enough real time passed for a full scan
    if (currentTimeMillis - lastScanTimeMillis) / 1000 >= LOOP_INTERVAL_SECONDS then
        print("--- Scanning for players ---")
        local currentPlayersInRange = detector.getPlayersInRange(DETECTION_RANGE)

        if #currentPlayersInRange > 0 then
            print("Players in range:")
            for _, playerTable in ipairs(currentPlayersInRange) do -- Renamed to playerTable for clarity
                local username = playerTable.username -- Extract username from table

                print(string.format("- %s", username))

                if detectedPlayers[username] then
                    -- Player seen before
                    local lastDetected = detectedPlayers[username].lastDetectedTimeMillis
                    local timeElapsed = (currentTimeMillis - lastDetected) / 1000

                    if timeElapsed < COOLDOWN_SECONDS then
                        -- On cooldown
                        local remaining = COOLDOWN_SECONDS - timeElapsed
                        print(string.format("  -> %s must wait %s for re-alert.", username, formatTime(remaining)))
                    else
                        -- Cooldown expired, update time
                        print(string.format("  -> %s detected again! Updating time.", username))
                        detectedPlayers[username].lastDetectedTimeMillis = currentTimeMillis
                    end
                else
                    -- New player
                    print(string.format("  -> NEW player: %s! Storing time.", username))
                    detectedPlayers[username] = {
                        lastDetectedTimeMillis = currentTimeMillis
                    }
                end
            end
        else
            print("No players detected.")
        end

        lastScanTimeMillis = currentTimeMillis -- Update last scan time
    else
        -- Waiting for next scan
        local remainingForNextScan = LOOP_INTERVAL_SECONDS - ((currentTimeMillis - lastScanTimeMillis) / 1000)
        print("Waiting for next scan in " .. math.ceil(remainingForNextScan) .. " seconds...")
    end

    -- Display tracked players
    print("\n--- Tracked players ---")
    if next(detectedPlayers) then
        for username, data in pairs(detectedPlayers) do
            local timeSinceLastDetection = (currentTimeMillis - data.lastDetectedTimeMillis) / 1000
            print(string.format("- %s: Last detected %s ago", username, formatTime(timeSinceLastDetection)))
        end
    else
        print("No players tracked.")
    end

    -- Wait for 1 tick or termination
    local timerID = os.startTimer(1)
    local event, p1 = os.pullEvent()
    if event == "timer" and p1 == timerID then
        -- Continue loop
    elseif event == "terminate" then
        print("\nProgram terminated.")
        break
    end
end