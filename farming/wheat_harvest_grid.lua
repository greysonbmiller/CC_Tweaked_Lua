
 function row1()
   turtle.forward()
   turtle.digDown()
 end
  
 function row2()
   turtle.turnLeft()
   turtle.forward()
   turtle.turnLeft()
   turtle.digDown()
  end
  
  function row3()
   turtle.turnRight()
   turtle.forward()
   turtle.turnRight()
   turtle.digDown()
  end
 
 for i = 1, 1 do
  for x = 1, 42 do
   row1()
  end
   row2()
  for y = 1, 41 do
   row1()
  end
   row3()
  for u = 1, 41 do
   row1()
  end
   row2()
  for e = 1, 41 do
   row1()
  end
  turtle.turnLeft()
  turtle.forward()
  turtle.forward()
  turtle.forward()
  turtle.turnRight()
  turtle.forward()
  turtle.turnRight()
  turtle.turnRight()
 end
 
