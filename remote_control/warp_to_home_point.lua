teleport = peripheral.wrap("left")

--teleport.savePoint("home")
teleport.warpToPoint("home")

points = teleport.points()

print(points)
