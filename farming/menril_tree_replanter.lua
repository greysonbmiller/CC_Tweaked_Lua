turtle.back()
turtle.back()
turtle.select(1)
while true do
    if turtle.detect() == false then
        sleep(1)
        turtle.forward()
        turtle.place()
        turtle.back()
        sleep(5)
    end
end
