-- Loads the REAL miner under a mock CC:Tweaked environment and asserts the two
-- properties the redesign claims: nothing is ever dropped into the world, and a
-- field restart never re-stages or cleans.
--
-- The mock counts worldDrops every time a drop lands somewhere that is not a
-- confirmed inventory. That counter is the whole point: it measures the bug
-- directly rather than trusting that the code looks right.

local TARGET = arg[1] or "mining/geo_scanner_ore_mining_bot.lua"

local ENDER     = "enderstorage:ender_chest"
local HASH_WARP = "059ada3ad2e70e2bc43dcd9eeb0f95ca"
local HASH_DEPO = "470db3a18c6e1b98f579261f3bce12ef"
local HASH_FUEL = "d4ac434678cee65f5c34a6abca08db6e"
local SCANNER   = "advancedperipherals:geo_scanner"
local CHATBOX   = "advancedperipherals:chat_box"
local PLATE     = "waystones:warp_plate"
local HOPPER    = "mob_grinding_utils:absorption_hopper"
local PICKAXE   = "minecraft:diamond_pickaxe"

local CONTAINERS = { [ENDER] = true, ["minecraft:chest"] = true }

-- A full, correctly-sorted kit as it sits after staging.
local function fullKit()
    return {
        [10] = { name = CHATBOX, count = 1 },
        [11] = { name = ENDER, nbt = HASH_WARP, displayName = "Ender Chest", count = 1 },
        [12] = { name = HOPPER, count = 1 },
        [13] = { name = PLATE,  count = 1 },
        [14] = { name = ENDER, nbt = HASH_DEPO, displayName = "Ender Chest", count = 1 },
        [15] = { name = SCANNER, count = 1 },
        [16] = { name = ENDER, nbt = HASH_FUEL, displayName = "Ender Chest", count = 1 },
    }
end

-- opts: preInv, preFiles, world, blockedFaces, frontChest, budget, fuelRises
local function makeEnv(opts)
    local inv = {}
    for s, it in pairs(opts.preInv or {}) do inv[s] = { name = it.name, count = it.count or 1,
                                                        nbt = it.nbt, displayName = it.displayName } end
    local selected, leftTool = 1, PICKAXE
    local fuel = 500
    local world = {}
    for k, v in pairs(opts.world or {}) do world[k] = v end
    local blocked = opts.blockedFaces or {}
    local contents = { front = {}, up = {}, down = {} }   -- what placed containers hold
    local files = {}
    for k, v in pairs(opts.preFiles or {}) do files[k] = v end

    local report = { worldDrops = 0, staged = false, budgetHit = false,
                     platePlaced = false, safeDrops = 0, world = world }
    local budget, steps = opts.budget or 4000, 0
    local function tick()
        steps = steps + 1
        if steps > budget then report.budgetHit = true; error("__BUDGET__", 0) end
    end

    -- The supply chest in front, present only on a genuine base start.
    local supply = opts.frontChest

    local turtle = {}
    function turtle.select(s) selected = s return true end
    function turtle.getItemCount(s)
        local it = inv[s or selected]; return it and it.count or 0
    end
    function turtle.getItemDetail(s, detailed)
        local it = inv[s or selected]
        if not it then return nil end
        local d = { name = it.name, count = it.count }
        if detailed then d.nbt = it.nbt; d.displayName = it.displayName end
        return d
    end
    function turtle.transferTo(dest, n)
        local src = inv[selected]
        if not src then return false end
        if inv[dest] then return false end
        inv[dest] = src; inv[selected] = nil
        return true
    end
    function turtle.equipLeft()
        local held = inv[selected]
        inv[selected] = leftTool and { name = leftTool, count = 1 } or nil
        leftTool = held and held.name or nil
        return true
    end
    function turtle.getFuelLevel() return fuel end
    function turtle.getFuelLimit() return 20000 end
    function turtle.refuel()
        if opts.fuelRises ~= false then fuel = fuel + 800 end
        return true
    end

    local function digFace(face)
        tick()
        if not world[face] then return false end
        -- Digging a container spills whatever is inside onto the ground.
        for _ in pairs(contents[face]) do end
        local block = world[face]
        world[face] = nil
        contents[face] = {}
        -- Real turtle.dig() fills the SELECTED slot first, then spills over.
        local dest
        if not inv[selected] then dest = selected
        else for i = 1, 16 do if not inv[i] then dest = i break end end end
        if dest then inv[dest] = { name = block, count = 1,
                                   nbt = opts.worldNbt and opts.worldNbt[face] } end
        return true
    end
    local function placeFace(face)
        tick()
        if blocked[face] then return false end
        if world[face] then return false end
        local it = inv[selected]
        if not it then return false end
        world[face] = it.name
        if it.name == PLATE then report.platePlaced = true end
        contents[face] = {}
        it.count = it.count - 1
        if it.count <= 0 then inv[selected] = nil end
        return true
    end
    local function dropFace(face)
        tick()
        local it = inv[selected]
        if not it then return false end
        if world[face] and CONTAINERS[world[face]] then
            table.insert(contents[face], it)      -- landed safely
            report.safeDrops = report.safeDrops + it.count
        else
            report.worldDrops = report.worldDrops + it.count   -- THE BUG
        end
        inv[selected] = nil
        return true
    end
    local function suckFace(face)
        tick()
        -- The supply chest at base is modelled separately from placed blocks.
        if face == "front" and supply then
            local first
            for s in pairs(supply) do if not first or s < first then first = s end end
            if not first then return false end
            if inv[selected] then return false end
            inv[selected] = supply[first]; supply[first] = nil
            return true
        end
        if world[face] and CONTAINERS[world[face]] then
            local it = table.remove(contents[face])
            if not it then return false end
            if inv[selected] then return false end
            inv[selected] = it
            return true
        end
        return false
    end
    local function inspectFace(face)
        if not world[face] then return false, nil end
        return true, { name = world[face] }
    end

    turtle.dig       = function() return digFace("front") end
    turtle.digUp     = function() return digFace("up")    end
    turtle.digDown   = function() return digFace("down")  end
    turtle.place     = function() return placeFace("front") end
    turtle.placeUp   = function() return placeFace("up")    end
    turtle.placeDown = function() return placeFace("down")  end
    turtle.drop      = function() return dropFace("front") end
    turtle.dropUp    = function() return dropFace("up")    end
    turtle.dropDown  = function() return dropFace("down")  end
    turtle.suck      = function() return suckFace("front") end
    turtle.suckUp    = function() return suckFace("up")    end
    turtle.suckDown  = function() return suckFace("down")  end
    turtle.inspect     = function() return inspectFace("front") end
    turtle.inspectUp   = function() return inspectFace("up")    end
    turtle.inspectDown = function() return inspectFace("down")  end
    turtle.forward = function() tick() return true end
    turtle.up = function() tick() return true end
    turtle.down = function() tick() return true end
    turtle.turnLeft = function() tick() return true end
    turtle.turnRight = function() tick() return true end

    local function wrap(side)
        if side == "left" then
            if leftTool == SCANNER then
                return { scan = function() return {} end }
            elseif leftTool == CHATBOX then
                return { sendMessageToPlayer = function() return true end }
            end
            return nil
        end
        if side == "front" and supply then
            report.staged = true
            return {
                list = function()
                    local out = {}
                    for s, it in pairs(supply) do out[s] = { count = it.count or 1 } end
                    return out
                end,
                getItemDetail = function(s) return supply[s] end,
            }
        end
        if world[side] and CONTAINERS[world[side]] then
            return { list = function() return {} end }
        end
        return nil
    end
    local function getType(side)
        if side == "left" then
            if leftTool == SCANNER then return SCANNER end
            if leftTool == CHATBOX then return CHATBOX end
            return nil
        end
        return nil
    end

    -- Minimal fs / textutils so state.txt genuinely round-trips.
    local function ser(v)
        if type(v) == "table" then
            local out = {"{"}
            for k, val in pairs(v) do
                local key = type(k) == "string" and ("[" .. string.format("%q", k) .. "]")
                                                 or ("[" .. tostring(k) .. "]")
                out[#out+1] = key .. "=" .. ser(val) .. ","
            end
            out[#out+1] = "}"
            return table.concat(out)
        elseif type(v) == "string" then return string.format("%q", v)
        else return tostring(v) end
    end
    local textutils = {
        serialize = ser,
        unserialize = function(s)
            local f = loadstring("return " .. s)
            if not f then return nil end
            local ok, v = pcall(f)
            return ok and v or nil
        end,
    }
    local fsmock = {
        exists = function(p) return files[p] ~= nil end,
        delete = function(p) files[p] = nil end,
        move = function(a, b) files[b] = files[a]; files[a] = nil end,
        open = function(p, mode)
            if mode == "r" then
                if not files[p] then return nil end
                return { readAll = function() return files[p] end, close = function() end }
            end
            local buf = {}
            return {
                write = function(s) buf[#buf+1] = s end,
                close = function() files[p] = table.concat(buf) end,
            }
        end,
    }

    local env = {
        turtle = turtle,
        peripheral = { wrap = wrap, getType = getType },
        fs = fsmock,
        textutils = textutils,
        shell = { getRunningProgram = function() return TARGET end },
        os = setmetatable({ sleep = function() end }, { __index = os }),
        -- The ATM variant waits on io.read() at a warp point by design.
        io = { read = function() return "" end },
        print = function() end,
        string = string, table = table, math = math, pairs = pairs, ipairs = ipairs,
        type = type, tostring = tostring, tonumber = tonumber, error = error,
        pcall = pcall, select = select, unpack = unpack, loadstring = loadstring,
        setmetatable = setmetatable, next = next, rawget = rawget,
    }
    env._G = env
    return env, report, files, inv
end

local function run(opts)
    local chunk, loadErr = loadfile(TARGET)
    if not chunk then error("LOAD: " .. tostring(loadErr)) end
    local env, report, files, inv = makeEnv(opts)
    setfenv(chunk, env)
    local ok, err = pcall(chunk)
    report.ok, report.err = ok, tostring(err)
    report.files, report.inv = files, inv
    return report
end

local pass, fail = 0, 0
local function assertThat(label, cond, detailMsg)
    if cond then pass = pass + 1; print(string.format("  %-52s PASS", label))
    else fail = fail + 1; print(string.format("  %-52s FAIL", label))
         if detailMsg then print("        " .. detailMsg) end end
end

print("target: " .. TARGET)
print(string.rep("=", 64))

-- 1. Happy path from base: stages, deploys, and never throws anything away.
print("\n[1] first run at base, healthy")
local supply = {}
for _, it in pairs(fullKit()) do supply[#supply + 1] = it end
supply[#supply + 1] = { name = PICKAXE, count = 1 }
local r = run{ preInv = {}, frontChest = supply, budget = 3000 }
assertThat("staged from the supply chest", r.staged)
assertThat("state.txt was written", r.files["state.txt"] ~= nil)
assertThat("deployed flag recorded",
           (r.files["state.txt"] or ""):find("deployed") and
           (r.files["state.txt"] or ""):find("true") ~= nil)
assertThat("startup.lua installed", r.files["startup.lua"] ~= nil)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 2. Field restart: deployed, no supply chest anywhere near.
print("\n[2] field restart in a cave, no chest in front")
local st = '{["deployed"]=true,["phase"]="mining",["cycles"]=2,["placed"]={},}'
r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = st },
         frontChest = nil, budget = 3000 }
assertThat("did NOT try to stage", not r.staged)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)
-- The run is cut at an arbitrary point, so a chest may legitimately be on the
-- ground mid-cycle. The invariant that actually matters is that none is LOST:
-- all three must be somewhere we can still get at.
local function enderCount(rep)
    local n = 0
    for i = 1, 16 do
        if rep.inv[i] and rep.inv[i].name == ENDER then n = n + 1 end
    end
    for _, face in ipairs({ "front", "up", "down" }) do
        if rep.world[face] == ENDER then n = n + 1 end
    end
    return n
end
assertThat("all 3 ender chests accounted for", enderCount(r) == 3,
           "found " .. enderCount(r))

-- 3. Crash mid-deposit: an ender chest of ours is still on the ground.
print("\n[3] restart with our ender chest left placed in front")
local st3 = '{["deployed"]=true,["phase"]="depositing",["cycles"]=1,' ..
            '["placed"]={["front"]=14,},}'
local kitNoDeposit = fullKit(); kitNoDeposit[14] = nil
r = run{ preInv = kitNoDeposit, preFiles = { ["state.txt"] = st3 },
         world = { front = ENDER }, worldNbt = { front = HASH_DEPO },
         frontChest = nil, budget = 3000 }
assertThat("recovered the chest and re-filed it to slot 14",
           r.inv[14] ~= nil and r.inv[14].name == ENDER,
           "slot 14 = " .. tostring(r.inv[14] and r.inv[14].name))
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 4. Front face unusable (lava). The fallback ladder must find another face
--    rather than dropping, and the run must continue.
print("\n[4] front face blocked, fallback ladder")
r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = st },
         blockedFaces = { front = true }, frontChest = nil, budget = 3000 }
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)
assertThat("did not abort on the blocked face",
           not (r.err or ""):find("Could not place the deposit chest"),
           r.err)

-- 5. Every face unusable. Must keep the items and stop - never drop.
print("\n[5] all faces blocked")
r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = st },
         blockedFaces = { front = true, up = true, down = true },
         frontChest = nil, budget = 3000 }
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)
assertThat("stopped rather than continuing", not r.ok)

-- 6. THE ONE THAT MATTERS FOR "COME AND GET ME". A field failure must leave a
--    warp plate ON THE GROUND and send the warp stone home, otherwise the
--    message is telling you to walk to a place you cannot reach.
print("\n[6] field failure must leave a usable warp point")
local kitNoRefuel = fullKit(); kitNoRefuel[16] = nil   -- incomplete kit on restart
-- Stand in for the activated warp stone the hopper would have picked up: it has
-- to reach the warp chest, or you have a plate you cannot warp to.
kitNoRefuel[1] = { name = "waystones:warp_stone", count = 1 }
r = run{ preInv = kitNoRefuel, preFiles = { ["state.txt"] = st },
         frontChest = nil, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("a warp plate was placed", r.platePlaced)
assertThat("plate LEFT in the world, not picked back up",
           r.world.front == PLATE or r.world.down == PLATE,
           "front=" .. tostring(r.world.front) .. " down=" .. tostring(r.world.down))
assertThat("warp stone sent home (something reached a chest)", r.safeDrops > 0,
           "safeDrops=" .. r.safeDrops)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 7. Refuel failure is the classic stranding case: it must also leave a plate.
print("\n[7] refuel takes on nothing -> must still leave a warp point")
r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = st },
         frontChest = nil, fuelRises = false, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("a warp plate was placed", r.platePlaced)
assertThat("plate LEFT in the world", r.world.front == PLATE or r.world.down == PLATE,
           "front=" .. tostring(r.world.front) .. " down=" .. tostring(r.world.down))
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 8. Honesty check: with no plate in the kit it must NOT claim to be reachable.
print("\n[8] no warp plate in kit -> must not promise a rescue")
local kitNoPlate = fullKit(); kitNoPlate[13] = nil; kitNoPlate[16] = nil
r = run{ preInv = kitNoPlate, preFiles = { ["state.txt"] = st },
         frontChest = nil, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("no plate placed (there was none to place)", not r.platePlaced)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 9. RISK 1a: state.txt exists but is truncated garbage (crash mid-write).
--    Must NOT be read as "first run" - staging in a cave is the disaster.
print("\n[9] corrupt state.txt must not trigger staging")
r = run{ preInv = fullKit(), preFiles = { ["state.txt"] = '{["deploy' },
         frontChest = nil, budget = 3000 }
assertThat("did NOT try to stage", not r.staged)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)
assertThat("all 3 ender chests accounted for", enderCount(r) == 3,
           "found " .. enderCount(r))

-- 10. RISK 1b: crashed in the delete/move window - only the scratch file is
--     left. It must be picked up rather than ignored.
print("\n[10] only state.tmp survives -> resume from it")
r = run{ preInv = fullKit(), preFiles = { ["state.tmp"] = st },
         frontChest = nil, budget = 3000 }
assertThat("did NOT try to stage", not r.staged)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 11. RISK 1c: state file DELETED outright while deployed. The parse check
--     cannot catch this, so the carried kit is what has to give it away - and
--     the bot must leave a warp point rather than just shrugging.
print("\n[11] state file lost entirely while deployed")
r = run{ preInv = fullKit(), preFiles = {}, frontChest = nil, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("a warp plate was placed", r.platePlaced)
assertThat("plate LEFT in the world", r.world.front == PLATE or r.world.down == PLATE,
           "front=" .. tostring(r.world.front) .. " down=" .. tostring(r.world.down))
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 12. Regression: a genuine first run at base must STILL stage normally, and
--     must not be misread as a lost-state-file distress case.
print("\n[12] genuine first run at base still stages")
local supply2 = {}
for _, it in pairs(fullKit()) do supply2[#supply2 + 1] = it end
supply2[#supply2 + 1] = { name = PICKAXE, count = 1 }
r = run{ preInv = {}, preFiles = {}, frontChest = supply2, budget = 3000 }
assertThat("staged from the supply chest", r.staged)
-- Not "no plate was ever placed" - a healthy run legitimately places one at its
-- scheduled 4th-cycle warp. The thing that must NOT happen is mistaking a first
-- run for a deployed bot that lost its state file.
assertThat("did not take the lost-state distress path",
           not (r.err or ""):find("carrying a full kit"), r.err)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 13. Staging guard: a supply chest that is present but EMPTY. The bot is at
--     base with a player standing there, so the right answer is to refuse
--     loudly and cheaply rather than set off with no kit.
print("\n[13] empty supply chest -> refuses to start")
r = run{ preInv = {}, preFiles = {}, frontChest = {}, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("said staging incomplete", (r.err or ""):find("staging incomplete") ~= nil, r.err)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

-- 14. The single most dangerous omission: everything staged EXCEPT the refuel
--     chest. Missing it means no fuel and a stranded bot, so the error has to
--     name the slot rather than just failing.
print("\n[14] refuel chest absent from supply -> names slot 16")
local partial = {}
for s, it in pairs(fullKit()) do
    if s ~= 16 then partial[#partial + 1] = it end
end
partial[#partial + 1] = { name = PICKAXE, count = 1 }
r = run{ preInv = {}, preFiles = {}, frontChest = partial, budget = 3000 }
assertThat("halted", not r.ok)
assertThat("named slot 16 specifically",
           (r.err or ""):find("slot 16 (refuel ender chest)", 1, true) ~= nil, r.err)
assertThat("NOTHING dropped into the world", r.worldDrops == 0,
           "worldDrops=" .. r.worldDrops)

print("\n" .. string.rep("=", 64))
print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
