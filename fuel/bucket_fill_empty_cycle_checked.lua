-- CC: Tweaked Lua Program for Turtle Automation
-- This program is designed to run indefinitely, automating the process
-- of filling and emptying buckets (or picking up and dropping items).

-- IMPORTANT ASSUMPTION:
-- When 'turtle.suck()' is successful, this program assumes it has
-- either picked up an item (like an empty bucket) or filled an
-- existing empty bucket from a fluid source (like water or lava).
-- The 'drop()' actions are interpreted as first emptying the filled
-- bucket, and then dropping the now-empty bucket item.

-- Main loop: This loop will run forever until the program is terminated.
print("started")
while true do
    --print("Attempting to suck an item or fill a bucket...")

    -- Attempt to suck an item from the block directly in front of the turtle.
    -- If there's an item entity, it picks it up. If there's a fluid source
    -- and the turtle has an empty bucket in its inventory, it fills the bucket.
    local success = turtle.suck()
    print("time to get slot info")
    local slotinfo = turtle.getItemDetail()
    print(slotinfo)
    --print(turtle.getItemCount())
    if turtle.getItemCount() ~= 0 then
    -- Check if the 'suck' operation was successful.
        if slotinfo.name == "minecraft:bucket" then
        --print("Suck successful! Proceeding with bucket handling.")

        -- Turn the turtle 180 degrees (two right turns).
        -- This is often used to face a different location for dropping.
        --print("Turning 180 degrees...")
            turtle.turnRight()
            turtle.turnRight()

        -- Drop the item from the currently selected slot.
        -- If the turtle just filled a bucket, this will empty the fluid.
        -- The empty bucket will remain in the turtle's inventory.
        --print("Dropping first item (e.g., emptying bucket)...")
            turtle.place()
        --print("First drop complete.")

        -- Turn the turtle 180 degrees again, returning it to its original orientation.
        --print("Turning 180 degrees back to original orientation...")
            turtle.turnRight()
            turtle.turnRight()

        -- Drop the item again.
        -- If the previous 'drop' emptied a bucket, this will now drop the
        -- empty bucket item itself onto the block in front.
        --print("Dropping second item (e.g., dropping empty bucket)...")
            turtle.drop()
        --print("Second drop complete.")

        -- The program will then loop back to the start, ready to suck again.
        -- This creates a cycle: suck fluid, drop fluid, drop empty bucket,
        -- and then potentially suck the empty bucket back up to repeat.

        else
        -- If the 'suck' operation was not successful (e.g., no item or fluid source).
        --print("nosleep")
        --print("Suck failed. No item or fluid detected. Waiting 2 seconds...")
        --sleep(2) -- Wait for 2 seconds before attempting to suck again.
    end
    end
end

