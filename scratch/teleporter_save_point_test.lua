teleport = peripheral.wrap("left")

teleport.savePoint("nothome")

points = teleport.points()

print(points)
