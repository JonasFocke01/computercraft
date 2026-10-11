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

    for i = 1, contentSize do
        table.insert(pullProcesses,
            function ()
                local targetChest = mostEmptyStorageChest(storageChests, contentSize)

                if dgb then term.setCursorPos(x, y) end
                if dgb then term.write("Storing back items " .. i .. "/" .. contentSize .. " ") end

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

function indexStorage(storageChests, TERM_HEIGHT, dbg)
    local chestProcesses = {}

    local x, y = term.getCursorPos()
    local sumOfUsedSlots = 0
    local sumOfMaxSlots = 0

    for k, chest in pairs(storageChests) do
        table.insert(chestProcesses,
            function ()
                if dgb then term.setCursorPos(x, y) end
                if dgb then term.write("indexing " .. k .. "/" ..#storageChests .. "  ") end

                chest.cachedList = chest.list()
                chest.maxSize = chest.size()

                sumOfUsedSlots = sumOfUsedSlots + #chest.cachedList
                sumOfMaxSlots = sumOfMaxSlots + chest.maxSize
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

function main(args)

    local dbg = args[1] == "dbg"

    if dbg then
        print("debug mode")
    else
        print("release mode")
    end

    local TERM_WIDTH, TERM_HEIGHT = term.getSize()

    term.clear()
    if dbg then term.setCursorPos(1, 1) end
    if dbg then term.write("ComputerCraft ME System") end
    if dgb then term.setCursorPos(1, 3) end
    if dgb then term.write("Booting...") end

    local modem = peripheral.find("modem")

    if dgb then term.setCursorPos(1, 4) end
    if dgb then term.write("Found modem") end

    local storageChests = initStorage(modem)

    if dgb then term.setCursorPos(1, 5) end
    if dgb then term.write("Initialized storage") end
    if dgb then term.setCursorPos(1, 6) end

    local storageChests, sumOfUsedSlots, sumOfMaxSlots = indexStorage(storageChests)

    if dgb then term.setCursorPos(1, 7) end
    if dgb then term.write("Done") end

    local turtleModem = modem

    while true do
        term.clear()
        term.setCursorPos(1, 1)
        term.setTextColor(math.random(1, 16))
        textWithRainbow("ComputerCraft ME System")

        term.setTextColor(colors.gray)
        term.setCursorPos(1, TERM_HEIGHT)
        term.write(sumOfUsedSlots .. "/" .. sumOfMaxSlots .. " used slots")


        term.setCursorPos(1, 6)
        term.setTextColor(colors.lightGray)
        term.write("Search for: ")
        term.setCursorPos(1, 7)
        term.setTextColor(colors.gray)
        term.write("(empty to upload all)")
        term.setTextColor(colors.white)
        term.setCursorPos(13, 6)

        local input = read()

        if not (input == "") then
            term.clearLine()
            collectItemsFrom(storageChests, input, turtleModem)

            term.setCursorPos(1, 10)
            term.setTextColor(colors.gray)
            term.write("Press any key to try again...")
            term.setTextColor(colors.white)

            while true do
                _, key = os.pullEvent("key")
                if not (key == keys.leftShift) then
                    break
                end
            end
        else
            if dbg then term.setTextColor(colors.orange) end
            if dbg then term.write("Clearing input box...") end
            if dbg then term.setTextColor(colors.white) end
        end

        if dgb then term.setCursorPos(1, 11) end
        storeAllItems(storageChests, turtleModem, dbg)

        if dgb then term.setCursorPos(1, 12) end
        storageChests, sumOfUsedSlots, sumOfMaxSlots = indexStorage(storageChests, dbg)
    end
end

local tArgs = { ... }
main(tArgs)
