p = peripheral.wrap("right")
while true do
    p.useOnBlock()
    os.sleep(1)
    print(tostring(turtle.getFuelLevel()))
end
