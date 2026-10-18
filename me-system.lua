-- A working me-system
-- This is only wired to require no additional mods besides ComputerCraft
--
-- Ingame shematic:
-- Multiple golden turtle without equipment sit besides connected wired modems (full blocks).
-- The wired modem must be ACTIVATED (by rightclicking on it).
-- The wire is then connected to a network of other modems with chests attached
--
-- There is virtually no limit to the amount of chests.
-- All long lasting actions are done im parallel.
-- Download this script onto the golden turtle, give it a label and DO NOT REFUEL!
--
-- The turtle can also be used as a auto-uploader into the storage network.
-- You only need to set the operational mode to "autouploading" in the interface (click the button)
--
-- The turtle also checks and limits the total amount of an item in the storage uppon autouploading.
-- To enable this feature, just place a droper besides a modem like any other chest and build a simple redstone cirquit to auto-dispose anything stored. The dropper gets autodetected by the system
-- When the feature is enabled: All unique items above the `MAX_ITEM_COUNT` threshhold go directly to that dropper.
-- To increase the disposable buffer (because turtles are way faster than droppers), place multiple droppers in the system.
-- The turtles then try to load balance between them.

MAX_ITEM_COUNT = 15000

STORAGE_NAME_REFIX = "minecraft:chest_"
TRASH_NAME_PREFIX = "minecraft:dropper_"

function initStorage(modem)
    local remoteModules = modem.getNamesRemote()

    local storageChests = {}
    local trashCans = {}

    for _, peri in pairs(remoteModules) do
        if string.find(peri, STORAGE_NAME_REFIX) then
            table.insert(storageChests, peripheral.wrap(peri))
        elseif string.find(peri, TRASH_NAME_PREFIX) then
            table.insert(trashCans, peripheral.wrap(peri))
        end
    end

    return storageChests, trashCans
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

function mostEmptyTrashCan(trashCans)
    local smallestNum = 9
    local smallest = nil

    for k, trashCan in pairs(trashCans) do
        local contentSize = #trashCan.list()

        if contentSize < 9 and contentSize < smallestNum then
            smallestNum = contentSize
            smallest = trashCan
        end
    end

    if smallest == 9 then
        return nil
    else
        return smallest
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

function dropAllItems()
    for i = 1, 16 do
        if turtle.getItemCount(i) > 0 then
            turtle.select(i)
            turtle.dropDown()
        end
    end
end

function sendAllItemsToTrash(trashCans, turtleModem)
    local procs = {}

    for i = 1, 16 do
        table.insert(procs,
            function ()
                -- local randomTrashCanIndex = math.random(1, (#trashCans - 1))
                local trashCan = mostEmptyTrashCan(trashCans)

                if trashCan == nil then
                    return
                end

                trashCan.pullItems(turtleModem.getNameLocal(), i)
            end
        )
    end

    parallel.waitForAll(
        function (spawn)
            for _, proc in pairs(procs) do
                spawn(proc)
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
    term.setBackgroundColor(colors.black)

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
    print() -- flush output
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

function drawOperationalModeToggleButton()
    function drawButton()
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.gray)
        term.clearLine(TERM_HEIGHT - 1)
        if operationalMode == "terminal" then
        term.setCursorPos(TERM_WIDTH - 13, TERM_HEIGHT - 1)
            term.write("mode: terminal")
        elseif operationalMode == "autoUpload" then
        term.setCursorPos(TERM_WIDTH - 16, TERM_HEIGHT - 1)
            term.write("mode: auto upload")
        elseif operationalMode == "trashCan" then
        term.setCursorPos(TERM_WIDTH - 14, TERM_HEIGHT - 1)
            term.write("mode: trash can")
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

function items(storageChests)
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
    local items = items(storageChests)
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

function drawStats(storageChests, sumOfUsedSlots)
    term.setCursorPos(1, 3)
    term.setTextColor(colors.gray)
    local items = items(storageChests)
    table.sort(items, function (a, b) return a.count > b.count end)

    local totalItems = 0
    for _, item in pairs(items) do
        totalItems = totalItems + item.count
    end

    if #items == 0 then term.write("No items found") end
    if #items >= 1 then term.write(tostring(totalItems) .. " total items") end
    if #items >= 1 then term.setCursorPos(1, 4) term.write(tostring(sumOfUsedSlots) .. " stacks") end
    if #items >= 1 then term.setCursorPos(1, 5) term.write(tostring(#items) .. " unique items") end
    if #items >= 1 then term.setCursorPos(1, 7) term.write(tostring(items[1].count) .. "x " .. items[1].name) end
    if #items >= 2 then term.setCursorPos(1, 8) term.write(tostring(items[2].count) .. "x " .. items[2].name) end
    if #items >= 3 then term.setCursorPos(1, 9) term.write(tostring(items[3].count) .. "x " .. items[3].name) end
    if #items >= 4 then term.setCursorPos(1, 10) term.write(tostring(items[4].count) .. "x " .. items[4].name) end
    if #items >= 5 then term.setCursorPos(1, 11) term.write("...") end
end

function drawFixedInterface(sumOfUsedSlots, sumOfMaxSlots, storageChests)
    term.clear()
    term.setCursorBlink(false)
    term.setCursorPos(1, 1)
    textWithRainbow("ComputerCraft ME System")

    drawOperationalModeToggleButton()

    if math.floor(sumOfMaxSlots * 0.9) <= sumOfUsedSlots then
        term.setTextColor(colors.red)
    elseif math.floor(sumOfMaxSlots * 0.7) <= sumOfUsedSlots then
        term.setTextColor(colors.pink)
    else
        term.setTextColor(colors.gray)
    end

    if operationalMode == "terminal" then
        drawSearchPrompt()
    elseif operationalMode == "autoUpload" then
        drawStats(storageChests, sumOfUsedSlots)
    elseif operationalMode == "trashCan" then
        drawStats(storageChests, sumOfUsedSlots)
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

    local storageChests, trashCans = initStorage(modem)

    if #storageChests == 0 then
        term.clear()
        term.setCursorPos(1, 1)
        print("No chests attached to modem")
        return;
    end

    if dgb then term.setCursorPos(1, 5) end
    if dgb then term.write("Initialized storage") end
    if dgb then term.setCursorPos(1, 6) end

    return storageChests, trashCans, modem
end

function checkInitialized(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)
    return not (sumOfUsedSlots == nil or sumOfMaxSlots == nil or storageChests == nil or turtleModem == nil)
end

-- TODO: Make faster
function awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)
    ::check::
    storageChests, trashCans, turtleModem = init()
    if not (storageChests == nil and turtleModem == nil) then
        storageChests, sumOfUsedSlots, sumOfMaxSlots = indexStorage(storageChests, dbg)
    end
    if not checkInitialized(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem) then
        os.sleep()
        goto check
    end

    return storageChests, trashCans, sumOfUsedSlots, sumOfMaxSlots, turtleModem
end

function manualItemSearch(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem, cachedSearch)
    storageChests, trashCans, sumOfUsedSlots, sumOfMaxSlots, turtleModem =
        awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)

    drawFixedInterface(sumOfUsedSlots, sumOfMaxSlots, storageChests)

    local input = nil
    local function completeMe(text) return completeMeState(text, storageChests) end

    local function prompt()
        if not (cachedSearch == nil or cachedSearch == "") then
            input = read(nil, nil, completeMe, cachedSearch)
        else
            input = read(nil, nil, completeMe)
        end

        storageChests, trashCans, sumOfUsedSlots, sumOfMaxSlots, turtleModem =
        awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)

        storeAllItems(storageChests, turtleModem, dbg)

        storageChests, trashCans, sumOfUsedSlots, sumOfMaxSlots, turtleModem =
        awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)

        if not (input == "") then
            collectItemsFrom(storageChests, input, turtleModem)
        end
    end

    local function killPrompt()
        while not killRead do
            os.sleep()
        end
        killRead = false
    end

    parallel.waitForAny(prompt, killPrompt)

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

    local label = os.getComputerLabel()

    if label == "me-autoUploader" then
        operationalMode = "autoUpload"
    elseif label == "me-terminal" then
        operationalMode = "terminal"
    elseif label == "me-trashCan" then
        operationalMode = "trashCan"
    end

    parallel.waitForAll(
        function (spawn)
            spawn(
                function()
                    local cachedSearch
                    while true do
                        if operationalMode == "terminal" then
                            cachedSearch = manualItemSearch(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, modem, cachedSearch)
                        else
                            storageChests, trashCans, sumOfUsedSlots, sumOfMaxSlots, turtleModem =
                                awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)

                            drawFixedInterface(sumOfUsedSlots, sumOfMaxSlots, storageChests)
                        end
                    end
                end
            )

            spawn(
                function ()
                    while true do
                        local event, button, x, y = os.pullEvent("mouse_click")

                        if y == TERM_HEIGHT - 1 and x > TERM_WIDTH - 16 then
                            killRead = true

                            if operationalMode == "terminal" then
                                os.setComputerLabel("me-autoUploader")
                                operationalMode = "autoUpload"
                            elseif operationalMode == "autoUpload" then
                                os.setComputerLabel("me-trashCan")
                                operationalMode = "trashCan"
                            elseif operationalMode == "trashCan" then
                                os.setComputerLabel("me-terminal")
                                operationalMode = "terminal"
                            end
                        end

                        os.sleep()
                    end
                end
            )

            spawn(
                function ()
                    local passNum = 0
                    while true do
                        passNum = passNum + 1
                        os.pullEvent("turtle_inventory")

                        storageChests, trashCans, sumOfUsedSlots, sumOfMaxSlots, turtleModem =
                            awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)

                        if operationalMode == "autoUpload" then
                            local needleItem = turtle.getItemDetail(1)

                            if needleItem == nil then
                                storeAllItems(storageChests, turtleModem, dbg)
                                goto continue
                            end

                            local needleItemName = needleItem.name

                            local storedItems = items(storageChests)
                            local haystackItem = nil

                            for _, sitem in pairs(storedItems) do
                                if sitem.name == needleItemName then
                                    haystackItem = sitem
                                end
                            end

                            if haystackItem == nil then
                                storeAllItems(storageChests, turtleModem, dbg)
                                goto continue
                            end

                            if haystackItem.count < MAX_ITEM_COUNT then
                                print("storing all")
                                storeAllItems(storageChests, turtleModem, dbg)
                            else
                                print("sending to trash")
                                sendAllItemsToTrash(trashCans, turtleModem)
                            end
                        elseif operationalMode == "trashCan" then
                            dropAllItems()
                        end

                        ::continue::
                        os.sleep()
                    end
                end
            )
        end
    )
end

TERM_WIDTH, TERM_HEIGHT = term.getSize()

local tArgs = { ... }

-- OpterationalMode:
-- - "terminal":   Everyone can search for items in the storage
-- - "autoUpload": Upload every item put into the turtle via steve, hoppers or other means into storage
-- - "trashCan":   Advertise as "trashCan" on the network, so other turtles can send unwanted items. All items received are dropped bellow, where ideally a lava bucket was placed
operationalMode = "terminal"

-- This should only stop the current "read" in the search function
killRead = false


main(tArgs)
