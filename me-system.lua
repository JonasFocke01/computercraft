-- A working me-system running on turtles on a wired network.
-- This is only wired to require no additional mods besides ComputerCraft.
-- All storage on the network is done unsorted and could require refinement to make optimal use of the available space.
--
-- Ingame shematic:
--
-- A network of wired modems (full blocks) are connected via cables and activated by rightclicking on them.
-- At least one chest is then placed besides a modem. There is theoretically a limit of about 256 chests. (untested)
-- A GOLDEN turtle WITHOUT equipment is placed besides a wired network.
--
-- MODES:
--
-- All modes are contained in this script and can be switched by starting a turtle and then pressing the mode button in the lower right corner.
--
-- 1. me-access-terminal
--
-- The user can type in search querys for blocks or types of blocks that are then pulled from the storage and placed in the turtle inventory.
-- Each time a new query is typed in, the turtle sends back all items in the most free-space chest.
--
-- 2. me-auto-upload
--
-- This script also has a auto-uploader build in, where the search prompt disappears.
-- Every item then put into the turtle inventory is directly send to storage.
-- This function makes turtles most usefull to funnel farms directly into the storage system.
--
--      Limit Items while auto-uploading:
--
--      This function also comes with a limiter for items.
--      Uppon each upload, the to-upload item gets checked by amount in the storage and send to garbage when overflowing.
--      To enable this feature, place one, or multiple for auto-loadbalancing, DROPPERS with a auto-dispose redstone circuit on the network.
--      Edit the constant `MAX_UNIQUE_ITEM_COUNT` to configure the maximum amount of any unique item in the storage.
--
-- 3. me-auto-download
--
-- The turtle will accept one item in the 16nth slot and searches the storage system for that item.
-- When more than `MIN_DOWNLOADABLE_ITEM_COUNT` is found, some items are pulled into the turtle and dropped BELLOW.
-- To process any of that items further, one would need to place a chest bellow the turtle, where the items then get put into.
-- The items are dropped otherwhise.
-- Warning: Hoppers will pull out ALL items from the turtle. Use a chest to be safe.
--
-- Hint: Do not refuel the turtle to prevent accidents

MAX_UNIQUE_ITEM_COUNT = 15000 -- 4.5 double chest worth of stacks
MIN_DOWNLOADABLE_ITEM_COUNT = 576 -- 9 stacks aka one inventory row

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
    for i = 1, 15 do
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

function collectItemsFrom(storageChests, query, turtleModem, limit)
    if limit == nil then
        limit = 1024 -- Max turtle inv.
    end

    local collectProcesses = {}
    for k, chest in pairs(storageChests) do
        for ic, item in pairs(chest.cachedList) do
            for ik, itemContent in pairs(item) do
                if ik == "name" and string.find(itemContent, query) and limit > 0 then
                    table.insert(collectProcesses,
                        {
                            ["chest"] = chest,
                            ["limit"] = limit,
                            ["ic"] = ic
                        }
                    )
                    limit = limit - item.count
                end
            end
        end
    end

    parallel.waitForAll(
        function (spawn)
            for _, collectProcess in pairs(collectProcesses) do
                spawn(
                    function()
                        collectProcess.chest.pushItems(
                            turtleModem.getNameLocal(),
                            collectProcess.ic,
                            collectProcess.limit
                        )
                    end
                )
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
        elseif operationalMode == "autoDownload" then
        term.setCursorPos(TERM_WIDTH - 18, TERM_HEIGHT - 1)
            term.write("mode: auto download")
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
    term.setTextColor(colors.lightGray)
    local items = items(storageChests)

    if operationalMode == "autoUpload" then
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
    elseif operationalMode == "autoDownload" then
        if #items == 0 then
            term.write("No items found")
            return
        end

        local needleItem = turtle.getItemDetail(16)

        if needleItem == nil then
            term.setTextColor(colors.red)
            term.setCursorPos(1,5)
            term.write("Please put the item to download")
            term.setCursorPos(1,6)
            term.write(" in the 16th slot")
            return
        end

        local haystackItem = nil
        for _, sitem in pairs(items) do
            if sitem.name == needleItem.name then
                haystackItem = sitem
            end
        end

        term.setCursorPos(1,5)
        term.write("Watching on ")
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.white)
        if haystackItem == nil then
            term.write(needleItem.name)
        else
            term.write(haystackItem.name)
        end
        term.setBackgroundColor(colors.black)
        term.setCursorPos(1,7)
        term.setTextColor(colors.lightGray)
        if haystackItem == nil then
            term.write("0 in storage")
        else
            term.write(tostring(haystackItem.count) .. " in storage")
        end
        term.setCursorPos(1,8)
        term.write(tostring(MIN_DOWNLOADABLE_ITEM_COUNT) .. " threshold")
    end
end

function drawFixedInterface(sumOfUsedSlots, sumOfMaxSlots, storageChests)
    term.clear()
    term.setCursorBlink(false)
    local text = "ComputerCraft ME System"
    term.setCursorPos((TERM_WIDTH / 2) - (#text / 2), 1)
    textWithRainbow(text)

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
    elseif operationalMode == "autoDownload" then
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
    elseif label == "me-autoDownload" then
        operationalMode = "autoDownload"
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

                        if y == TERM_HEIGHT - 1 and x > TERM_WIDTH - 18 then
                            killRead = true

                            if operationalMode == "terminal" then
                                os.setComputerLabel("me-autoUploader")
                                operationalMode = "autoUpload"
                            elseif operationalMode == "autoUpload" then
                                os.setComputerLabel("me-autoDownload")
                                operationalMode = "autoDownload"
                            elseif operationalMode == "autoDownload" then
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

                            if haystackItem.count < MAX_UNIQUE_ITEM_COUNT then
                                storeAllItems(storageChests, turtleModem, dbg)
                            else
                                sendAllItemsToTrash(trashCans, turtleModem)
                            end
                        end

                        ::continue::
                        os.sleep()
                    end
                end
            )

            spawn(
                function ()
                    while true do
                        if operationalMode == "autoDownload" then

                            storageChests, trashCans, sumOfUsedSlots, sumOfMaxSlots, turtleModem =
                                awaitInit(sumOfUsedSlots, sumOfMaxSlots, storageChests, dbg, turtleModem)

                            local needleItem = turtle.getItemDetail(16)
                            local items = items(storageChests)

                            if needleItem == nil then
                                goto continue
                            end

                            local haystackItem = nil
                            for _, sitem in pairs(items) do
                                if sitem.name == needleItem.name then
                                    haystackItem = sitem
                                end
                            end

                            if haystackItem == nil then
                                goto continue
                            end

                            if haystackItem.count > MIN_DOWNLOADABLE_ITEM_COUNT then
                                collectItemsFrom(storageChests, haystackItem.name, turtleModem, haystackItem.count - MIN_DOWNLOADABLE_ITEM_COUNT)
                                dropAllItems()
                            end
                        end

                        ::continue::
                        os.sleep(1)
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
-- - "autoDownload":   Download one unique item from storage when there are more than N available
operationalMode = "terminal"

-- This should only stop the current "read" in the search function
killRead = false


main(tArgs)
