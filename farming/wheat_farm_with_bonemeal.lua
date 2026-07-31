-- Configuration
local WHEAT_SEED_NAME = "minecraft:wheat_seeds"
local BONEMEAL_NAME = "minecraft:bone_meal"
local WHEAT_NAME = "minecraft:wheat"

-- Find item in inventory
local function findItem(itemName)
    for i = 1, 16 do
        local detail = turtle.getItemDetail(i)
        if detail and detail.name == itemName then
            return i
        end
    end
    return nil
end

-- Main farming loop
while true do
    print("Farm: Start")

    -- 1. Plant seeds
    local seedSlot = findItem(WHEAT_SEED_NAME)
    if seedSlot then
        turtle.select(seedSlot)
        print("Seeds: Place")
        if not turtle.place() then
            print("Seeds: Fail")
        end
    else
        print("Seeds: None")
        sleep(5)
        goto continue_loop
    end

    sleep(0.5)

    -- 2. Apply bonemeal
    local bonemealSlot = findItem(BONEMEAL_NAME)
    if bonemealSlot then
        turtle.select(bonemealSlot)
        print("Bone: Apply")
        while turtle.place() do
            if turtle.getItemCount(bonemealSlot) == 0 then
                print("Bone: Empty")
                break
            end
            sleep(0.1)
        end
    else
        print("Bone: None")
    end

    sleep(1)

    -- 3. Harvest
    print("Dig: Collect")
    if not turtle.dig() then
        print("Dig: Fail")
    end

    sleep(0.5)

    -- 4. Replant (if seeds available)
    seedSlot = findItem(WHEAT_SEED_NAME)
    if seedSlot then
        turtle.select(seedSlot)
        print("Seeds: Replant")
        if not turtle.place() then
            print("Seeds: Fail")
        end
    else
        print("Seeds: No")
    end

    -- 5. Drop extras
    print("Drop: Extras")
    for i = 1, 16 do
        turtle.select(i)
        local detail = turtle.getItemDetail(i)
        if detail and (detail.name == WHEAT_SEED_NAME or detail.name == WHEAT_NAME) then
            print("Drop: Item")
            turtle.dropUp()
        end
    end
    print("Drop: Done")

    print("Cycle: Done")
    sleep(5)

    ::continue_loop::
end
