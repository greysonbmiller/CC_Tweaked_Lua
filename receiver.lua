-- receiver.lua
-- Runs on the turtle. Receives item letter + quantity from inventory_sender.lua
-- and performs the mapped turtle action that many times.
--
-- Bindings:
--   D  Dirt        = Forward
--   C  Cobblestone = Back
--   S  Sand        = Up
--   G  Gravel      = Down
--   N  Netherrack  = Turn Left
--   O  Oak Planks  = Turn Right
--   F  Flint       = Suck Front
--   I  Iron Ingot  = Suck Up
--   T  Torch       = Suck Down
--   B  Bone        = Drop All Slots

local MODEM_SIDE = "top"  -- side ender modem is attached

local BINDINGS = {
    D = { label = "Forward",    fn = turtle.forward   },  -- Dirt
    C = { label = "Back",       fn = turtle.back      },  -- Cobblestone
    S = { label = "Up",         fn = turtle.up        },  -- Sand
    G = { label = "Down",       fn = turtle.down      },  -- Gravel
    N = { label = "Turn Left",  fn = turtle.turnLeft  },  -- Netherrack
    O = { label = "Turn Right", fn = turtle.turnRight },  -- Oak Planks
    F = { label = "Suck Front", fn = turtle.suck      },  -- Flint
    I = { label = "Suck Up",    fn = turtle.suckUp    },  -- Iron Ingot
    T = { label = "Suck Down",  fn = turtle.suckDown  },  -- Torch
    B = { label = "Drop All",   fn = nil              },  -- Bone (special case)
}

local function dropAll()
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemDetail() then
            turtle.drop()
        end
    end
    turtle.select(1)
end

local function execute(letter, quantity)
    local binding = BINDINGS[letter]
    if not binding then return end

    print("[" .. letter .. " x" .. quantity .. "] -> " .. binding.label)

    if letter == "B" then
        dropAll()
    else
        for i = 1, quantity do
            binding.fn()
        end
    end
end

rednet.open(MODEM_SIDE)
print("Turtle #" .. os.getComputerID() .. " ready.")
print("-----------------------------")
print("  D  Dirt        = Forward")
print("  C  Cobblestone = Back")
print("  S  Sand        = Up")
print("  G  Gravel      = Down")
print("  N  Netherrack  = Turn Left")
print("  O  Oak Planks  = Turn Right")
print("  F  Flint       = Suck Front")
print("  I  Iron Ingot  = Suck Up")
print("  T  Torch       = Suck Down")
print("  B  Bone        = Drop All Slots")
print("-----------------------------")

while true do
    local _, message = rednet.receive()
    local letter, quantity = string.match(message, "^(%a+):(%d+)$")

    if letter and BINDINGS[letter] then
        execute(letter, tonumber(quantity))
    elseif message ~= "none:0" then
        print("No binding for: " .. message)
    end
end
