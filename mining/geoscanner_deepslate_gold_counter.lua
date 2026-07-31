orename = "allthemodium:allthemodium_slate_ore"
orename2 = "minecraft:deepslate_gold_ore"
g = peripheral.wrap("left")
results, reason = g.chunkAnalyze()

count = results[orename2]
print(tostring(count))
--print(reason)
while count < 30  do
    for i=1,16 do turtle.forward() end
    result = g.chunkAnalyze()
    count = result[orename2]
    print(tostring(count))
end
