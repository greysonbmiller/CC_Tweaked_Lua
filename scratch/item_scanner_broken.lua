local weakAutomata = peripheral.wrap("right")


local items, err = weakAutomata.scanItems()

if not items then
    print("failed to scan")
    return
end

if #items == 0 then
    print("no nearby items")
    return
end

if #items != 0 then
    print("items detected nearby")
    return
end
