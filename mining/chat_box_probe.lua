-- CHAT BOX PROBE
--
-- Answers, in sixty seconds, why the bot is not hearing $ commands. It equips
-- the chat box and prints EVERY event it receives, with every parameter, so
-- there is no guessing about which of these is true:
--
--   * the chat event never fires at all      -> nothing prints
--   * it only fires when you stand close     -> prints near, silent far away
--   * the $ prefix is stripped by the mod    -> message shows as "ore 3"
--   * the username is not what we filter on  -> name differs from PLAYER below
--   * the event is not called "chat"         -> a different event name prints
--
--   pastebin get <code> probe.lua
--   probe
--
-- Then, while it runs: say something in chat with a $ prefix, say something
-- without one, and if you can, walk a long way off and say something else.

local PLAYER  = "SKAAAAL"
local CHATBOX = "advancedperipherals:chat_box"
local LISTEN  = 60

local function findSlot(name)
    for i = 1, 16 do
        local ok, d = pcall(turtle.getItemDetail, i)
        if ok and d and d.name == name then return i end
    end
    return nil
end

print("=== chat box probe ===")

-- Equip the chat box, unless it is already on the arm.
local restoreSlot = nil
if peripheral.getType("left") == CHATBOX then
    print("chat box already equipped on the left")
else
    local slot = findSlot(CHATBOX)
    if not slot then
        print("NO CHAT BOX FOUND in any inventory slot.")
        print("Put one in the turtle and run this again.")
        return
    end
    print("equipping chat box from slot " .. slot)
    turtle.select(slot)
    turtle.equipLeft()
    restoreSlot = slot
    os.sleep(1)
end

local box = peripheral.wrap("left")
if not box then
    print("FAILED: nothing wrapped on the left after equipping.")
    return
end

print("wrapped OK. methods available:")
local names = {}
for k in pairs(box) do names[#names + 1] = k end
table.sort(names)
print("  " .. table.concat(names, ", "))

-- Prove the OUTBOUND direction works, so that a silent probe means the inbound
-- direction is at fault rather than the peripheral being dead.
if box.sendMessageToPlayer then
    local ok, err = pcall(box.sendMessageToPlayer, "Probe listening for 60s.", PLAYER)
    print("sendMessageToPlayer -> " .. (ok and "sent" or ("FAILED: " .. tostring(err))))
    print("(if that did not appear in your chat, PLAYER is wrong: " .. PLAYER .. ")")
end

print("")
print("LISTENING " .. LISTEN .. "s - every event prints below.")
print("Say: $ore 1     then: hello     then walk far and say: $ore 1")
print("")

local deadline = os.startTimer(LISTEN)
local heard = 0
while true do
    local e = { os.pullEvent() }
    if e[1] == "timer" and e[2] == deadline then break end

    -- Timers fire constantly; everything else is worth seeing.
    if e[1] ~= "timer" then
        heard = heard + 1
        local parts = {}
        for i = 1, #e do parts[#parts + 1] = tostring(e[i]) end
        print(heard .. ": " .. table.concat(parts, " | "))

        if e[1] == "chat" then
            local who, msg = tostring(e[2]), tostring(e[3])
            print("   username=[" .. who .. "]  matches PLAYER? " ..
                  tostring(who == PLAYER) ..
                  "  (case-insensitive? " .. tostring(who:lower() == PLAYER:lower()) .. ")")
            print("   message =[" .. msg .. "]  starts with $? " ..
                  tostring(msg:sub(1, 1) == "$"))
        end
    end
end

print("")
if heard == 0 then
    print("HEARD NOTHING. The chat event is not reaching this turtle at all.")
    print("That rules out parsing and the username filter - the problem is")
    print("upstream: range, a config option, or this build not firing the event.")
else
    print("heard " .. heard .. " event(s). Compare the username and message")
    print("lines above against what the miner filters on.")
end

if restoreSlot then
    turtle.select(restoreSlot)
    turtle.equipLeft()
    turtle.select(1)
    print("chat box returned to slot " .. restoreSlot)
end
