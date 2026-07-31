-- A mock CC:Tweaked environment, good enough to LOAD AND RUN the real miner
-- files under (setfenv, Lua 5.1). Shared by every harness in this directory so
-- there is exactly one model of the turtle to keep honest - two mocks drifting
-- apart is how the previous guard harness quietly stopped testing anything.
--
-- The mock measures behaviour rather than describing it. worldDrops counts every
-- drop that lands somewhere which is not a confirmed inventory, so the no-drop
-- invariant is checked directly instead of by reading the code and agreeing
-- with it.
--
-- Two mock behaviours are load-bearing and easy to get wrong. Both hid real
-- bugs when they were first modelled lazily:
--   * turtle.dig() fills the SELECTED slot first, then spills over.
--   * turtle.suck() always draws the container's LOWEST-numbered occupied slot;
--     it cannot be pointed at a slot.

local M = {}

M.ENDER     = "enderstorage:ender_chest"
M.HASH_WARP = "059ada3ad2e70e2bc43dcd9eeb0f95ca"
M.HASH_DEPO = "470db3a18c6e1b98f579261f3bce12ef"
M.HASH_FUEL = "d4ac434678cee65f5c34a6abca08db6e"
M.SCANNER   = "advancedperipherals:geo_scanner"
M.CHATBOX   = "advancedperipherals:chat_box"
M.PLATE     = "waystones:warp_plate"
M.HOPPER    = "mob_grinding_utils:absorption_hopper"
M.PICKAXE   = "minecraft:diamond_pickaxe"
-- The right-arm chunk loader. Reserved permanently in the real bot - the only
-- thing keeping its chunk loaded while it works thousands of blocks from any
-- player - so it needs its own identity here the same way PICKAXE/SCANNER do.
M.CHUNKY    = "advancedperipherals:chunky_turtle"

M.CONTAINERS = { [M.ENDER] = true, ["minecraft:chest"] = true }

-- A full, correctly-sorted kit as it sits after staging.
function M.fullKit()
    return {
        [10] = { name = M.CHATBOX, count = 1 },
        [11] = { name = M.ENDER, nbt = M.HASH_WARP, displayName = "Ender Chest", count = 1 },
        [12] = { name = M.HOPPER, count = 1 },
        [13] = { name = M.PLATE,  count = 1 },
        [14] = { name = M.ENDER, nbt = M.HASH_DEPO, displayName = "Ender Chest", count = 1 },
        [15] = { name = M.SCANNER, count = 1 },
        [16] = { name = M.ENDER, nbt = M.HASH_FUEL, displayName = "Ender Chest", count = 1 },
    }
end

-- opts: preInv, preFiles, world, worldNbt, blockedFaces, blockFacesAfterChat,
--       frontChest, budget, fuelRises, scans, chats, player, rightTool,
--       rightArmSticks
function M.makeEnv(opts)
    local SCANNER, CHATBOX = M.SCANNER, M.CHATBOX
    local PLATE, PICKAXE, CONTAINERS = M.PLATE, M.PICKAXE, M.CONTAINERS
    local CHUNKY = M.CHUNKY

    local inv = {}
    for s, it in pairs(opts.preInv or {}) do inv[s] = { name = it.name, count = it.count or 1,
                                                        nbt = it.nbt, displayName = it.displayName } end
    local selected, leftTool = 1, PICKAXE
    -- The chunk loader sits on the right arm from the moment the turtle is
    -- deployed - unlike the left arm, nothing time-shares this slot. Defaults
    -- to the real chunk loader but is swappable via opts.rightTool so a test
    -- can model whatever is actually on the arm.
    local rightTool = opts.rightTool or CHUNKY
    local fuel = 500
    local world = {}
    for k, v in pairs(opts.world or {}) do world[k] = v end
    local blocked = opts.blockedFaces or {}
    -- Normally `blocked` applies from the very first tick. But some scenarios
    -- need the WORLD to be fine at startup and only become impassable later -
    -- e.g. "the turtle has wandered somewhere walled in by bedrock or lava by
    -- the time it is scuttled". opts.blockFacesAfterChat defers activation
    -- until the first chat event is actually delivered (see pullEvent below),
    -- so the ordinary startup sequence - including the always-runs refuel()
    -- - completes normally, and only a placement attempted AFTER a chat
    -- command has been heard runs into the blocked faces.
    local blockingActive = not opts.blockFacesAfterChat
    local contents = { front = {}, up = {}, down = {} }   -- what placed containers hold
    local pendingWrap = {}    -- face -> wrap calls still to be answered with nil
    -- NBT of blocks WE placed, so digging one back up returns the same item.
    -- Without this an ender chest loses its frequency the first time it is
    -- picked up, and every later placement is a generic chest - which silently
    -- breaks refuelling several cycles later, a long way from the cause.
    local placedNbt = {}
    local files = {}
    for k, v in pairs(opts.preFiles or {}) do files[k] = v end

    local report = { worldDrops = 0, staged = false, budgetHit = false,
                     platePlaced = false, safeDrops = 0, world = world,
                     -- `contents` is the same table the mock mutates internally
                     -- (see placeFace/dropFace below), exposed by reference so a
                     -- test can inspect what actually landed in a placed
                     -- container without reaching into the mock's closure.
                     contents = contents,
                     scanCount = 0, sent = {}, writes = {}, ups = 0, downs = 0,
                     refuels = 0, ranDry = false, fuel = fuel, minFuel = fuel,
                     scanRadii = {}, cooldownMisses = 0,
                     turns = 0, turnLeft = 0, turnRight = 0,
                     shutdown = false,
                     -- Every sendMessageToPlayer call that found the chat box
                     -- already swapped off the left arm - see the CHATBOX
                     -- branch of wrap() below. A message going missing is
                     -- invisible by itself (report.sent just has one fewer
                     -- entry, same as if nothing had ever tried to send it);
                     -- this is what lets a test assert the stronger, more
                     -- useful claim "the code TRIED to talk with the box off
                     -- the arm", instead of only noticing an absence.
                     detachedSends = 0,
                     -- One ordered log of everything notable the mock saw,
                     -- appended to as it happens rather than reconstructed
                     -- afterwards. This is what lets a test assert ORDER - e.g.
                     -- "nothing at all happens between equipRight() and the
                     -- loader's drop()" - without every scenario having to
                     -- invent its own bespoke tracking.
                     eventLog = {} }
    local budget, steps = opts.budget or 4000, 0
    local function tick()
        steps = steps + 1
        if steps > budget then report.budgetHit = true; error("__BUDGET__", 0) end
    end

    -- The supply chest in front, present only on a genuine base start.
    local supply = opts.frontChest

    local turtle = {}
    function turtle.select(s)
        selected = s
        -- Logged unconditionally, same as every other event below - which
        -- slot was selected right before an equip/drop/place is exactly what
        -- lets a test reconstruct WHAT moved, not just that something did.
        report.eventLog[#report.eventLog + 1] = "select:" .. tostring(s)
        return true
    end
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
        report.eventLog[#report.eventLog + 1] = "equipLeft"
        return true
    end
    -- RIGHT ARM: the chunk loader, permanently reserved. Same swap semantics
    -- as equipLeft on purpose - whatever the production code ends up doing to
    -- take it off is going to be the identical "select a slot, swap with the
    -- arm" pattern, since that is the only equip primitive CC exposes.
    --
    -- opts.rightArmSticks models the one failure this arm actually needs to
    -- survive: a chunk loader that will not come off. It has to be a no-op
    -- that returns false, not an error, because the real API call behaves
    -- the same way when an unequip is refused.
    function turtle.equipRight()
        if opts.rightArmSticks then return false end
        local held = inv[selected]
        inv[selected] = rightTool and { name = rightTool, count = 1 } or nil
        rightTool = held and held.name or nil
        report.eventLog[#report.eventLog + 1] = "equipRight"
        return true
    end
    function turtle.getFuelLevel() return fuel end
    function turtle.getFuelLimit() return 20000 end
    -- Real refuelling burns what is in the SELECTED slot, and only if it is
    -- actually fuel. The old mock added fuel unconditionally, even with an
    -- empty slot, which quietly hid the whole mechanic: a refuel that drew
    -- nothing still looked like a success.
    --
    -- Lava buckets are the stock in this bot's refuel chest. They do not stack,
    -- so one draw is one bucket, and burning one leaves an EMPTY BUCKET behind -
    -- which the bot then puts back in the chest and can draw again.
    function turtle.refuel()
        report.refuels = report.refuels + 1
        local it = inv[selected]
        if not it then return false end
        if opts.fuelRises == false then return true end

        if it.name == "minecraft:lava_bucket" then
            fuel = fuel + 1000
            inv[selected] = { name = "minecraft:bucket", count = 1 }
        elseif it.name == "minecraft:coal" then
            fuel = fuel + 80 * (it.count or 1)
            inv[selected] = nil
        else
            return false                    -- not fuel; it stays put
        end
        report.fuel = fuel
        return true
    end

    -- Movement costs fuel only when a test asks for it. Off by default so that
    -- scenarios about placement and restart are not perturbed by running dry;
    -- on, it is what lets a test prove the bot cannot strand itself.
    local function burn()
        if not opts.burnFuel then return true end
        if fuel <= 0 then report.ranDry = true; return false end
        fuel = fuel - 1
        report.fuel = fuel
        if fuel < (report.minFuel or math.huge) then report.minFuel = fuel end
        return true
    end

    local function digFace(face)
        tick()
        -- Logged before the outcome is known, same as a real dig attempt: the
        -- turtle swings whether or not there is a block there.
        report.eventLog[#report.eventLog + 1] = "dig"
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
        if dest then
            inv[dest] = { name = block, count = 1,
                          nbt = placedNbt[face]
                             or (opts.worldNbt and opts.worldNbt[face]),
                          displayName = placedNbt[face] and "Ender Chest" or nil }
        end
        placedNbt[face] = nil
        return true
    end
    local function placeFace(face)
        tick()
        if blockingActive and blocked[face] then return false end
        if world[face] then return false end
        local it = inv[selected]
        if not it then return false end
        world[face] = it.name
        -- Only on an actual placement - a blocked or already-occupied face
        -- moved nothing, so there is nothing worth putting in the log.
        report.eventLog[#report.eventLog + 1] = "place:" .. it.name
        placedNbt[face] = it.nbt
        pendingWrap[face] = opts.wrapDelay or 0
        if it.name == PLATE then report.platePlaced = true end
        contents[face] = {}
        -- The refuel ender chest is stocked from home, so placing it exposes
        -- fuel. Without this the chest is empty and no refuel can ever succeed,
        -- which is not a model of anything real.
        if it.name == M.ENDER and it.nbt == M.HASH_FUEL then
            for i = 1, (opts.refuelStock or 8) do
                contents[face][i] = { name = "minecraft:lava_bucket", count = 1 }
            end
        end
        it.count = it.count - 1
        if it.count <= 0 then inv[selected] = nil end
        return true
    end
    local function dropFace(face)
        tick()
        local it = inv[selected]
        if not it then return false end
        -- Every drop, whatever its destination - this is deliberately logged
        -- before the safe/world branch below so a test can see EVERY item
        -- that left the turtle in the exact order it left, not just the ones
        -- that landed safely.
        report.eventLog[#report.eventLog + 1] = "drop:" .. it.name
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
    -- detect() answers "is there a block there", which is how the bot tells a
    -- cleared space from one that a falling gravel column has just refilled.
    -- Only placed blocks exist in this world model, so an untouched face is
    -- air - which is the right default: it makes clear() a no-op everywhere a
    -- test has not deliberately put something in the way.
    local function detectFace(face) return world[face] ~= nil end
    turtle.detect     = function() return detectFace("front") end
    turtle.detectUp   = function() return detectFace("up")    end
    turtle.detectDown = function() return detectFace("down")  end
    turtle.forward = function() tick() return burn() end
    -- ups/downs exist so a test can prove the bot actually went for an ore.
    -- seek() is the only thing that moves vertically by more than it comes
    -- back: the hopper pass is exactly one down and one up, so it nets to
    -- zero, and netUp > 0 means an upward seek and nothing else.
    turtle.up = function() tick() report.ups = report.ups + 1 return burn() end
    turtle.down = function() tick() report.downs = report.downs + 1 return burn() end
    -- Turn counts expose which way seek() decided to go, which is the only
    -- outward sign that its world-axis to turtle-relative conversion is right.
    turtle.turnLeft = function()
        tick(); report.turns = report.turns + 1; report.turnLeft = report.turnLeft + 1
        return true
    end
    turtle.turnRight = function()
        tick(); report.turns = report.turns + 1; report.turnRight = report.turnRight + 1
        return true
    end

    -- Successive scan results. Each scan() call consumes the next entry; once
    -- they run out the scanner sees nothing, which is what stops a test run
    -- rather than letting it spin until the step budget trips.
    local scans = opts.scans or {}
    local scanIndex = 0
    local scanCalls = 0

    local function wrap(side)
        if side == "left" then
            if leftTool == SCANNER then
                -- No tick(): scanning is not a step. Runs are bounded by the
                -- scans list running out, not by the step budget.
                return {
                    scan = function(r)
                        scanCalls = scanCalls + 1
                        report.scanRadii[#report.scanRadii + 1] = r
                        -- A cooldown rejection returns nil, NOT an empty list.
                        -- Modelling that is what lets a test prove the miner
                        -- does not read "wait a moment" as "no ore here".
                        --
                        -- scanMissAlternate rejects every other call, so only a
                        -- miner that RETRIES gets anything done; one that gives
                        -- up on nil merely limps, which a one-off miss would
                        -- not have revealed.
                        local miss = (opts.scanCooldownMisses or 0) > 0
                                  or (opts.scanMissAlternate and scanCalls % 2 == 1)
                        if miss then
                            if (opts.scanCooldownMisses or 0) > 0 then
                                opts.scanCooldownMisses = opts.scanCooldownMisses - 1
                            end
                            report.cooldownMisses = (report.cooldownMisses or 0) + 1
                            return nil, "You need to wait before scanning again"
                        end
                        scanIndex = scanIndex + 1
                        report.scanCount = scanIndex
                        return scans[scanIndex] or {}
                    end,
                    -- Measured on the real hardware: free to radius 8, then
                    -- about 0.17 fuel per block of the cube beyond it. Fits the
                    -- observed 330 at r=9 and 5274 at r=16.
                    cost = function(r)
                        if r <= 8 then return 0 end
                        return math.floor(0.17 * (((2 * r + 1) ^ 3) - (17 ^ 3)))
                    end,
                }
            elseif leftTool == CHATBOX then
                -- The left arm has exactly one slot shared between pickaxe,
                -- geo scanner and chat box - unlike the permanently-reserved
                -- right arm, nothing here sits still. A caller that wraps the
                -- chat box once and holds onto the returned handle across a
                -- later digReady()/scanReady() is trusting that the box is
                -- still what's mounted - and on real hardware it usually
                -- isn't, because either of those swaps it straight off the
                -- arm. CC does not let a detached peripheral's methods
                -- silently no-op: they throw "Terminated: peripheral
                -- detached". The old version of this branch was a bare
                -- closure over `report` that never looked at leftTool again,
                -- so it went on recording "sent" messages forever - which let
                -- a test watch a chat message "succeed" that the player could
                -- never actually have received in game. Re-checking leftTool
                -- HERE, inside the returned function rather than in wrap()
                -- itself, is what makes the handle behave like the real
                -- stale one: wrap() ran once and returned a snapshot, but the
                -- arm keeps moving underneath it.
                return { sendMessageToPlayer = function(msg, who)
                    if leftTool ~= CHATBOX then
                        report.detachedSends = report.detachedSends + 1
                        error("Terminated: peripheral detached", 0)
                    end
                    report.sent[#report.sent + 1] = { msg = msg, who = who }
                    -- Models the chat box refusing when the recipient is not
                    -- logged in, which for an unattended bot is most of the time.
                    if opts.sendFails then error("player not found", 0) end
                    return true
                end }
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
            -- A freshly placed block is not attached as a peripheral the instant
            -- place() returns - the block entity has to come up and CC has to
            -- notice it. wrapDelay models that: the first N wrap calls after a
            -- placement see nothing, exactly as the real turtle does.
            if pendingWrap[side] and pendingWrap[side] > 0 then
                pendingWrap[side] = pendingWrap[side] - 1
                return nil
            end
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
        -- The right arm only ever carries the chunk loader (or nothing, once
        -- scuttle takes it off), so there is only one thing to report.
        if side == "right" then
            if rightTool == CHUNKY then return CHUNKY end
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
        delete = function(p)
            files[p] = nil
            report.eventLog[#report.eventLog + 1] = "delete:" .. p
        end,
        move = function(a, b) files[b] = files[a]; files[a] = nil end,
        open = function(p, mode)
            if mode == "r" then
                if not files[p] then return nil end
                return { readAll = function() return files[p] end, close = function() end }
            end
            local buf = {}
            return {
                write = function(s) buf[#buf+1] = s end,
                close = function()
                    files[p] = table.concat(buf)
                    -- Every completed write, in order, so a test can prove a
                    -- file is only rewritten when it actually changed.
                    report.writes[#report.writes + 1] = p
                end,
            }
        end,
    }

    -- Queued chat events, delivered to os.pullEvent in order. Anything the
    -- miner pulls after they run out gets its own timer back, which is what
    -- ends a listening window.
    local pending = {}
    for _, c in ipairs(opts.chats or {}) do pending[#pending + 1] = c end
    local nextTimer = 0
    local liveTimers = {}

    local mockOs = setmetatable({
        -- Deliberately does NOT tick: sleeping is not a step, and charging the
        -- budget for it starves scenarios that legitimately sleep a lot.
        sleep = function() end,
        startTimer = function()
            nextTimer = nextTimer + 1
            liveTimers[#liveTimers + 1] = nextTimer
            return nextTimer
        end,
        pullEvent = function(filter)
            tick()
            -- A queued chat is only visible while the chat box is on the arm,
            -- exactly as the real peripheral behaves.
            if leftTool == CHATBOX and #pending > 0 and (not filter or filter == "chat") then
                local c = table.remove(pending, 1)
                -- The deferred-blocking trigger: the world only turns hostile
                -- once a chat command has actually been heard, so a scenario
                -- can prove "the abort path runs when placement fails AFTER
                -- the command arrives" without that same blockage killing the
                -- unrelated startup refuel() first.
                blockingActive = true
                return "chat", c.who or opts.player or "SKAAAAL", c.msg, "uuid", true
            end
            -- Once the queue drains, keep handing back the most recent timer id
            -- so a listening loop always eventually sees its own deadline. A
            -- zero here would spin forever instead.
            local t = table.remove(liveTimers, 1)
            return "timer", t or nextTimer
        end,
        time = function() return 0 end,
        -- The real os.shutdown() never returns: the computer just goes dark
        -- mid-chunk. Modelled as a special error so it unwinds the whole
        -- program exactly like the budget guard's "__BUDGET__" does, but
        -- M.run below treats THIS one as a CLEAN finish rather than a run
        -- that had to be cut off - shutting down mid-scuttle is success.
        shutdown = function()
            report.shutdown = true
            report.eventLog[#report.eventLog + 1] = "shutdown"
            error("__SHUTDOWN__", 0)
        end,
        clock = os.clock,
        -- CC-only; not part of stock Lua's os table, so the probes would blow
        -- up on a nil call without it.
        epoch = function() return 0 end,
    }, { __index = os })

    local env = {
        turtle = turtle,
        peripheral = { wrap = wrap, getType = getType },
        fs = fsmock,
        textutils = textutils,
        shell = { getRunningProgram = function() return opts.target end },
        os = mockOs,
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

--- Load and run the real miner file under a fresh mock world.
function M.run(target, opts)
    opts = opts or {}
    opts.target = target
    local chunk, loadErr = loadfile(target)
    if not chunk then error("LOAD: " .. tostring(loadErr)) end
    local env, report, files, inv = M.makeEnv(opts)
    setfenv(chunk, env)
    local ok, err = pcall(chunk)
    -- os.shutdown() unwinds the chunk via the same error() mechanism the
    -- budget guard uses, but it means the opposite thing: the program ended
    -- itself on purpose, so this must read as success, not as a run that ran
    -- out of budget.
    if not ok and err == "__SHUTDOWN__" then ok = true end
    report.ok, report.err = ok, tostring(err)
    report.files, report.inv = files, inv
    return report
end

return M
