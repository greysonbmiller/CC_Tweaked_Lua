
-- Function to check the first slot for an empty bucket
function checkFirstSlotForBucket()
    local item = turtle.getItemDetail(1)
    if item and item.name == "minecraft:bucket" then
         return true
     end
     return false
 end
 
 function useBucketOnLavaTank()
     turtle.select(1)
     local success = turtle.place()
     if success then 
         print("Bucket filled")
     else
         print("Failed to use bucket, waiting")
     end
 end
 
 while true do
     if checkFirstSlotForBucket() then
         useBucketOnLavaTank()
     else
         print("No empty bucket found")
     end
     sleep(5)
 end
 
 
