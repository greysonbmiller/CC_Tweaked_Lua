-- ender_chest_probe.lua
--
-- One-off diagnostic for the geo scanner mining bots. Does not move, dig or
-- place anything - it only reads.
--
-- WHY THIS EXISTS
-- The miner stages three EnderStorage ender chests (Warp, Deposit, Refuel) out
-- of a supply chest. All three share one item id, so something has to tell them
-- apart. Anvil display names were tried and this server drops them. The
-- remaining discriminator is the NBT hash, which is derived from the chest's
-- frequency and is therefore stable for as long as the frequency is - and is
-- functional data, so a server that strips cosmetic names will not touch it.
--
-- HOW TO USE
-- 1. Park the turtle facing the supply chest, exactly as it sits when staging.
-- 2. Put the three ender chests in it. Ideally load them in a known order -
--    Warp, then Deposit, then Refuel - so the output lines up with what you
--    expect and you can tell which hash is which.
-- 3. Run this. It prints every item in the chest and writes the same text to
--    chest_probe.txt.
-- 4. IMPORTANT: run it a second time after a relog or server restart and
--    compare. If a chest's hash is identical both times it is safe to key
--    item_table on. If it changes between runs, the hash is not stable here
--    either and we fall back to identifying the chests by load order.
--
-- Probe the chests in the state they will actually be in. If the anvil names
-- have not dropped off yet, the name is part of the NBT and the hash you read
-- now will not match the hash after the server strips it.

local OUT = "chest_probe.txt"

local chest = peripheral.wrap("front")
if not chest then
    print("No inventory in front of the turtle.")
    print("Face the supply chest and run this again.")
    return
end

local lines = {}
local function emit(s)
    print(s)
    lines[#lines + 1] = s
end

emit(string.format("--- probe: day %d, time %.2f ---", os.day(), os.time()))

local slots = {}
for slot in pairs(chest.list()) do
    slots[#slots + 1] = slot
end
table.sort(slots)

if #slots == 0 then
    emit("Chest is empty - nothing to probe.")
end

for _, slot in ipairs(slots) do
    local d = chest.getItemDetail(slot)
    if d then
        emit(string.format("slot %-3d %s", slot, d.name))
        emit(string.format("         display : %s", tostring(d.displayName)))
        emit(string.format("         nbt     : %s", tostring(d.nbt)))
        emit(string.format("         count   : %d", d.count or 0))
    end
end

-- Ready-to-paste fragment, so the 32-character hashes never have to be copied
-- out by hand. Only items that actually carry an NBT hash can be keyed this
-- way; everything else in the staging chest is already unique by item id.
local seen = {}
local found = 0
emit("")
emit("-- paste into item_table and set each slot number:")
emit("--   11 = Warp, 14 = Deposit, 16 = Refuel")
for _, slot in ipairs(slots) do
    local d = chest.getItemDetail(slot)
    if d and d.nbt and not seen[d.nbt] then
        seen[d.nbt] = true
        found = found + 1
        emit(string.format('     ["%s"] = ??,   -- chest slot %d (%s)',
                           d.nbt, slot, d.displayName or d.name))
    end
end
if found == 0 then
    emit("-- Nothing in this chest carries an NBT hash.")
    emit("-- If that includes the ender chests, the frequency is not exposed")
    emit("-- to CC here and we identify them by load order instead.")
end

local f = fs.open(OUT, "w")
if f then
    f.write(table.concat(lines, "\n") .. "\n")
    f.close()
    print("")
    print("Written to " .. OUT)
end
