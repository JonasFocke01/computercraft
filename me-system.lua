-- A working me-system
-- This is only wired to require no additional mods besides ComputerCraft
--
-- Ingame shematic:
-- ONE golden turtle without equipment sits ontop of a wired modem (full block).
-- The wired modem is then connected to a wire and ACTIVATED (by rightclicking on it).
-- The wire is then connected to a network of other modems with chests attached
--
-- There is virtually no limit to the amount of chests.
-- All long lasting actions are done im parallel.
-- Download this script onto the golden turtle, give it a label and DO NOT REFUEL!

STORAGE_NAME_REFIX = "minecraft:chest_"

function initStorage(modem)
    local remoteModules = modem.getNamesRemote()

    local storageChests = {}

    for _, peri in pairs(remoteModules) do
        if string.find(peri, STORAGE_NAME_REFIX) then
            table.insert(storageChests, peripheral.wrap(peri))
        end
    end

    return storageChests
end

function mostEmptyStorageChest(storageChests, minFreeSpace)
    local smallestNum = 100
    local smallest = nil

    for k, chest in pairs(storageChests) do
        local contentSize = #chest.cachedList
        local maxSize = chest.maxSize

        if contentSize + minFreeSpace < maxSize and contentSize < smallestNum then
            smallestNum = contentSize
            smallest = chest
        end
    end

    if smallest == 100 then
        return nil
    else
        return smallest, contentSize
    end

end

function storeAllItems(storageChests, turtleModem, dbg)
    local x, y = term.getCursorPos()
    local pullProcesses = {}

    local contentSize = 0
    for i = 1, 16 do
        if turtle.getItemDetail(i) then
            contentSize = contentSize + 1
        end
    end

    for i = 1, 16 do
        table.insert(pullProcesses,
            function ()
                local targetChest = mostEmptyStorageChest(storageChests, contentSize)

                if targetChest == nil then
                    return
                end

                if dgb then term.setCursorPos(x, y) end
                if dgb then term.write("Storing back items " .. i .. "/16") end

                targetChest.pullItems(turtleModem.getNameLocal(), i)
            end
        )
    end

    parallel.waitForAll(
        function (spawn)
            for _, pullProcess in pairs(pullProcesses) do
                spawn(pullProcess)
            end

        end
    )
end

function indexStorage(storageChests, dbg)
    local chestProcesses = {}

    local x, y = term.getCursorPos()

    for k, chest in pairs(storageChests) do
        table.insert(chestProcesses,
            function ()
                if dgb then term.setCursorPos(x, y) end
                if dgb then term.write("indexing " .. k .. "/" ..#storageChests .. "  ") end

                chest.cachedList = chest.list()
                chest.maxSize = chest.size()
            end
        )
    end

    parallel.waitForAll(
        function (spawn)
            for _, chestProcess in pairs(chestProcesses) do
                spawn(chestProcess)
            end

        end
    )

    local sumOfUsedSlots = 0
    local sumOfMaxSlots = 0
    for k, chest in pairs(storageChests) do
        sumOfUsedSlots = sumOfUsedSlots + #chest.cachedList
        sumOfMaxSlots = sumOfMaxSlots + chest.maxSize
    end


    return storageChests, sumOfUsedSlots, sumOfMaxSlots
end

function collectItemsFrom(storageChests, query, turtleModem)
    local collectProcesses = {}
    for k, chest in pairs(storageChests) do
        for ic, item in pairs(chest.cachedList) do
            table.insert(collectProcesses,
                function ()
                    for ik, itemContent in pairs(item) do
                        if ik == "name" and string.find(itemContent, query) then
                            chest.pushItems(turtleModem.getNameLocal(), ic)
                        end
                    end
                end
            )
        end
    end

    parallel.waitForAll(
        function (spawn)
            for _, collectProcess in pairs(collectProcesses) do
                spawn(collectProcess)
            end

        end
    )

end

function textWithRainbow(text)
    for i = 1, #text do
        local rColor = math.random(0, 10)
        local char = text:sub(i, i)

        if rColor == 0 then
            term.setTextColor(colors.orange)
        elseif rColor == 1 then
            term.setTextColor(colors.magenta)
        elseif rColor == 2 then
            term.setTextColor(colors.lightBlue)
        elseif rColor == 3 then
            term.setTextColor(colors.yellow)
        elseif rColor == 4 then
            term.setTextColor(colors.lime)
        elseif rColor == 5 then
            term.setTextColor(colors.pink)
        elseif rColor == 6 then
            term.setTextColor(colors.cyan)
        elseif rColor == 7 then
            term.setTextColor(colors.purple)
        elseif rColor == 8 then
            term.setTextColor(colors.blue)
        elseif rColor == 9 then
            term.setTextColor(colors.green)
        elseif rColor == 10 then
            term.setTextColor(colors.red)
        end

        term.write(char)
    end
end

function storeAndResetCursor(callback)
    local x, y = term.getCursorPos()
    local tcolor = term.getTextColor()
    local bcolor = term.getBackgroundColor()
    callback()
    term.setCursorPos(x, y)
    term.setTextColor(tcolor)
    term.setBackgroundColor(bcolor)
end

function drawAutoUploadButton()
    function drawButton()
        term.setCursorPos(TERM_WIDTH - 12, 2)
        term.setTextColor(colors.black)
        if autoUpload then
            term.setBackgroundColor(colors.green)
            term.write("autouploading")
        else
            term.setBackgroundColor(colors.red)
            term.write("autouploading")
        end
    end
    storeAndResetCursor(drawButton)
end

function drawShowTopItemsButton(showTopItems)
    function drawButton()
        term.setCursorPos(TERM_WIDTH - 13, 3)
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.lightGray)
        if showTopItems then
            term.write("hide top items")
        else
            term.write("show top items")
        end
    end
    storeAndResetCursor(drawButton)
end

function drawSearchPrompt()
    term.setCursorPos(1, 6)
    term.setTextColor(colors.lightGray)
    term.write("Search for: ")
    term.setCursorPos(1, 7)
    term.setTextColor(colors.gray)
    term.write("(arrow keys for suggestions)")
    term.setCursorPos(13, 6)
    term.setTextColor(colors.white)
    term.setCursorBlink(true)
end

function topItems(storageChests)
    local items = {}

    for _, chest in pairs(storageChests) do
        for _, item in pairs(chest.cachedList) do
            local needleItem = nil
            for _, haystackItem in pairs(items) do
                if haystackItem.name == item.name then
                    needleItem = item
                end
            end

            if needleItem then
                for _, haystackItem in pairs(items) do
                    if haystackItem.name == item.name then
                        haystackItem.count = haystackItem.count + item.count
                    end
                end
            else
                table.insert(items, {count = item.count, name = item.name})
            end
        end
    end

    return items
end

function completeMeState(needleText, storageChests)
    local items = topItems(storageChests)
    local resultItemNames = {}

    for _, item in pairs(items) do
        local prefixLength = string.find(item.name, ":") + 1
        local haystackItemName = string.sub(item.name, prefixLength, prefixLength + # needleText - 1)
        if string.find(haystackItemName, needleText) then
            table.insert(resultItemNames, string.sub(item.name, prefixLength + #needleText))
        end
    end

    return resultItemNames
end


function drawFixedInterface(sumOfUsedSlots, sumOfMaxSlots, showTopItems, storageChests)
    term.clear()
    term.setCursorBlink(false)
    term.setCursorPos(1, 1)
    textWithRainbow("ComputerCraft ME System")

    drawAutoUploadButton()
    drawShowTopItemsButton(showTopItems)

    if math.floor(sumOfMaxSlots * 0.9) <= sumOfUsedSlots then
        term.setTextColor(colors.red)
    elseif math.floor(sumOfMaxSlots * 0.7) <= sumOfUsedSlots then
        term.setTextColor(colors.pink)
    else
        term.setTextColor(colors.gray)
    end

    term.setCursorPos(1, TERM_HEIGHT)
    term.write(sumOfUsedSlots .. "/" .. sumOfMaxSlots .. " used slots")

    if not (autoUpload or showTopItems) then
        drawSearchPrompt()
    elseif showTopItems then
        term.setCursorPos(1, 3)
        local items = topItems(storageChests)
        for k, item in pairs(items) do
            print(tostring(item.count) .. "x " .. item.name)
        end
    end

end

function init()
    local modem = peripheral.find("modem")

    if not modem then
        term.clear()
        term.setCursorPos(1, 1)
        print("No modem connected")
        return;
    end

    if dgb then term.setCursorPos(1, 4) end
    if dgb then term.write("Found modem") end

    local storageChests = initStorage(modem)

    if #storageChests == 0 then
        term.clear()
        term.setCursorPos(1, 1)
        print("No chests attached to modem")
        return;
    end

    if dgb then term.setCursorPos(1, 5) end
    if dgb then term.write("Initialized storage") end
    if dgb then term.setCursorPos(1, 6) end

    return storageChests, modem
end

function checkInitialized(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)
    return not (sumOfUsedSlots == nil or sumOfMaxSlots == nil or storageChests == nil or turtleModem == nil)
end

function awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)
    ::check::
    storageChests, turtleModem = init()
    if not (storageChests == nil and turtleModem == nil) then
        storageChests, sumOfUsedSlots, sumOfMaxSlots = indexStorage(storageChests, dbg)
    end
    if not checkInitialized(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem) then
        os.sleep()
        goto check
    end

    return storageChests, sumOfUsedSlots, sumOfMaxSlots, turtleModem
end

function manualItemSearch(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem, cachedSearch)
    storageChests, sumOfUsedSlots, sumOfMaxSlots, turtleModem =
        awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)

    drawFixedInterface(sumOfUsedSlots, sumOfMaxSlots, autoUpload, storageChests)

    local input = nil
    function completeMe(text) return completeMeState(text, storageChests) end
    if not (cachedSearch == nil or cachedSearch == "") then
        input = read(nil, nil, completeMe, cachedSearch)
    else
        input = read(nil, nil, completeMe)
    end

    autoUpload = false

    storageChests, sumOfUsedSlots, sumOfMaxSlots, turtleModem =
        awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)

    if dgb then term.setCursorPos(1, 11) end
    storeAllItems(storageChests, turtleModem, dbg)

    if not (input == "") then
        collectItemsFrom(storageChests, input, turtleModem)
    end

    return input
end

function main(args)
    local dbg = args[1] == "dbg"

    if dbg then
        print("debug mode")
    else
        print("release mode")
    end

    local storageChests, modem, storageChests, sumOfUsedSlots, sumOfMaxSlots = nil

    parallel.waitForAll(
        function (spawn)
            spawn(
                function()
                    local cachedSearch
                    while true do
                        cachedSearch = manualItemSearch(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, modem, cachedSearch)
                    end
                end
            )

            spawn(
                function ()
                    local showTopItems = false

                    while true do
                        local event, button, x, y = os.pullEvent("mouse_click")

                        if x > TERM_WIDTH - 12 and y == 2 then
                            autoUpload = not autoUpload
                        end
                        if x > TERM_WIDTH - 13 and y == 3 then
                            showTopItems = not showTopItems
                        end

                        storageChests, sumOfUsedSlots, sumOfMaxSlots, turtleModem =
                            awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)

                        drawFixedInterface(sumOfUsedSlots, sumOfMaxSlots, showTopItems, storageChests)

                        os.sleep()
                    end
                end
            )

            spawn(
                function ()
                    while true do
                        os.pullEvent("turtle_inventory")

                        if autoUpload then
                            storageChests, sumOfUsedSlots, sumOfMaxSlots, turtleModem =
                                awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)

                            storeAllItems(storageChests, turtleModem, dbg)

                            drawFixedInterface(sumOfUsedSlots, sumOfMaxSlots, storageChests)
                        end

                        os.sleep()
                    end
                end
            )
        end
    )
end

TERM_WIDTH, TERM_HEIGHT = term.getSize()

local tArgs = { ... }
autoUpload = false

main(tArgs)
