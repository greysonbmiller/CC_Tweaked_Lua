local c = 1
local n = turtle.getItemCount(1)

while turtle.getItemCount(2) > 0 do
turtle.select(1) 
 if turtle.compare(true) then 
  turtle.dig()
  turtle.forward()
 end
  while turtle.compareUp(true) do
   turtle.digUp()
   turtle.up()
   c = c + 1
  end
  for r = 1, c do
  turtle.down()
 end
  turtle.back()
  turtle.turnRight()
 
 while turtle.getItemCount(1) > 1 do
  turtle.drop(1)
 end
 turtle.turnRight()
 turtle.select(2)
 turtle.suck()
 turtle.turnLeft()
 turtle.turnLeft()
 turtle.place()
  if turtle.getFuelLevel() < 200 then
    turtle.select(3)
    turtle.suckUp()
    turtle.refuel()
    turtle.select(1)
   end
  
end    
         
             
       
