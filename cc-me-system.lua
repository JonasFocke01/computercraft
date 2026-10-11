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

function storeAllItems(storageChests, turtleModem)
    local x, y = term.getCursorPos()
    local pullProcesses = {}
    local targetChest = mostEmptyStorageChest(storageChests, 16)


    for i = 1, 16 do
        table.insert(pullProcesses,
            function ()
                term.setCursorPos(x, y)
                term.write("Storing back items " .. i .. "/16 ")

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

function indexStorage(storageChests, TERM_HEIGHT)
    local chestProcesses = {}

    local x, y = term.getCursorPos()
    for k, chest in pairs(storageChests) do
        table.insert(chestProcesses,
            function ()
                term.setCursorPos(x, y)
                term.write("indexing " .. k .. "/" ..#storageChests .. "  ")

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

    return storageChests
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

function main()
    local TERM_WIDTH, TERM_HEIGHT = term.getSize()

    term.clear()
    term.setCursorPos(1, 1)
    term.write("ComputerCraft ME System")
    term.setCursorPos(1, 3)
    term.write("Booting...")

    local modem = peripheral.find("modem")

    term.setCursorPos(1, 4)
    term.write("Found modem")

    local storageChests = initStorage(modem)

    term.setCursorPos(1, 5)
    term.write("Initialized storage")
    term.setCursorPos(1, 6)

    local storageChests = indexStorage(storageChests)

    term.setCursorPos(1, 7)
    term.write("Done")

    local turtleModem = modem

    while true do
        term.clear()
        term.setCursorPos(1, 1)
        term.write("ComputerCraft ME System")

        term.setCursorPos(1, 5)
        term.write("Search for: ")
        term.setCursorPos(1, 6)
        term.write("(empty to upload all)")
        term.setCursorPos(13, 5)

        local input = read()

        if not (input == "") then
            term.write("Searching for " .. input .. "               ")
            collectItemsFrom(storageChests, input, turtleModem)

            term.setCursorPos(1, 10)
            term.write("Press any key to try again...")

            while true do
                _, key = os.pullEvent("key")
                if not (key == keys.leftShift) then
                    break
                end
            end
        else
            term.write("Clearing input box...")
        end

        term.setCursorPos(1, 11)
        storeAllItems(storageChests, turtleModem)

        term.setCursorPos(1, 12)
        storageChests = indexStorage(storageChests)
    end
end

main()
