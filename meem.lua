local FIRST_ITEM_LINE_ON_TURTLE_SCREEN_FROM_CENTER = -6

local TERMINAL_WIDTH, TERMINAL_HEIGHT = term.getSize()

local function drawStatusline()
    local statusLine = ""

    local name = os.getComputerLabel()
    if name ~= nil then
        statusLine = statusLine .. os.getComputerLabel() .. " | "
    end

    statusLine = statusLine .. "ID: " .. os.getComputerID()

    if turtle ~= nil then
        statusLine = statusLine .. " | Fuel: " .. turtle.getFuelLevel()
    end

    term.setCursorPos(1, TERMINAL_HEIGHT)

    term.write(statusLine)
end

local function refuel(all)
    term.clear()
    drawStatusline()

    term.setCursorPos(2, 1)

    print("Press any button to refuel...")
    os.pullEvent("key")

    if all then
        turtle.refuel()
    else
        turtle.refuel(1)
    end
end

local function requireTool(requiredTool, requiredSlot)
    local MAX_TRIES = 10
    local tries = 0

    term.clear()
    drawStatusline()

    local equippedTool
    if requiredSlot == "right" then
        equippedTool = turtle.getEquippedRight()
    elseif requiredSlot == "left" then
        equippedTool = turtle.getEquippedLeft()
    else
        print("Unknown toolslot required. Please report bug to Jonas")
    end

    while (equippedTool == nil or equippedTool.name ~= requiredTool) and MAX_TRIES > tries do
        tries = tries + 1

        term.setCursorPos(2, 1)
        print("No or wrong tool in the required slot equiped.")
        print()
        print("Expecting " .. requiredTool .. " in " .. requiredSlot .. " slot. Try " .. tries .. "/" .. MAX_TRIES)
        print()

        print("Press any button to recheck...")
        os.pullEvent("key")

        if requiredSlot == "right" then
            equippedTool = turtle.getEquippedRight()
        elseif requiredSlot == "left" then
            equippedTool = turtle.getEquippedLeft()
        else
            print("Unknown toolslot required. Please report bug to Jonas")
        end
    end

    if MAX_TRIES == tries then
        return nil
    elseif tries == 0 then
        return true
    else
        return false
    end
end

local function printCentered(line, str)
    local x = math.floor((TERMINAL_WIDTH - string.len(str)) / 2)
    term.setCursorPos(x, line)
    term.clearLine()
    term.write(str)
end

local function drawMenuItem(itemNum, itemName, selected, menuItemMaxLength)
    local heightCenter = math.floor(TERMINAL_HEIGHT / 2)
    local lineOffset = FIRST_ITEM_LINE_ON_TURTLE_SCREEN_FROM_CENTER + itemNum
    local drawLine = heightCenter + lineOffset

    if selected then
        local len = itemName:len()
        if len % 2 == 0 then
            itemName = itemName .. " "
        else
            itemName = " " .. itemName .. " "
        end
        len = len - 2

        while len + 2 < menuItemMaxLength + 1 do
            itemName = " " .. itemName .. " "
            len = len + 2
        end

        itemName = "[" .. itemName .. "]"
    end

    printCentered(drawLine, itemName)
end

local function maxStringLength(table)
    local max = 0

    for _, item in ipairs(table) do
        if item:len() > max then
            max = item:len()
        end
    end

    return max
end

local function drawMenu(menuName, menuItems, menuIndex)
    local menu = { "", menuName, "" }
    local menuSize = #menu

    for i, itemName in ipairs(menuItems) do
        table.insert(menu, i + menuSize, itemName)
    end

    if #menu + 1 >= TERMINAL_HEIGHT then
        term.clear()
        term.setCursorPos(1, 1)
        print("Unable to draw menu: Terminal window to small")
        return
    end

    local longestNameLength = maxStringLength(menuItems)

    for i, itemName in ipairs(menu) do
        local selected = menuIndex + menuSize == i

        drawMenuItem(i, itemName, selected, longestNameLength)
    end
end


local function menu(menuName, menuItems)
    local menuIndex = 1

    while true do
        term.clear()
        drawMenu(menuName, menuItems, menuIndex)
        drawStatusline()

        local event, eventKey = os.pullEvent()
        if event == "key" then
            if eventKey == keys.up then
                if menuIndex > 1 then
                    menuIndex = menuIndex - 1
                end
            elseif eventKey == keys.down then
                if menuIndex < #menuItems then
                    menuIndex = menuIndex + 1
                end
            elseif eventKey == keys.enter then
                return menuItems[menuIndex]
            end
        end
    end
end

local function requireFuel(requiredLevel)
    local MAX_TRIES = 10
    local tries = 0

    local fuelLevel = turtle.getFuelLevel()

    while fuelLevel < requiredLevel and MAX_TRIES > tries do
        tries = tries + 1

        local selected = menu("Not enough fuel ( " .. fuelLevel .. "/" .. requiredLevel .. " )",
            { "refuel all", "refuel single", "Cancel" })

        if selected == "refuel single" then
            refuel(false)
        elseif selected == "refuel all" then
            refuel(true)
        end

        fuelLevel = turtle.getFuelLevel()
    end

    if MAX_TRIES == tries then
        return nil
    elseif tries == 0 then
        return true
    else
        return false
    end
end


local function fuelNeededToExcavate(dimensions)
    return (2 * (dimensions * dimensions + 64 * 2)) * 1.5
end

local function debugTurtle(requiredFuel, requiredTool, requiredToolSlot)
    local TEST_COUNT = 2
    local successfullTestCount = 0

    local requireFuelResult = requireFuel(requiredFuel)
    if requireFuelResult == nil then
        return false
    elseif requireFuelResult then
        successfullTestCount = successfullTestCount + 1
    end

    if requiredTool == nil or requiredToolSlot == nil then
        print("Required tool or slot is not set. Please report bug to Jonas")
        os.sleep(10)
        return false
    else
        local requireToolResult = requireTool(requiredTool, requiredToolSlot)
        if requireToolResult == nil then
            return false
        elseif requireToolResult then
            successfullTestCount = successfullTestCount + 1
        end
    end

    return successfullTestCount == TEST_COUNT
end

local function checkInventoryFull()
    for i = 1, 16 do
        if turtle.getItemCount(i) > 0 then
            return true
        end
    end
    return false
end

local function digUpDownPath(length)
    for _ = 1, length do
        while true do
            local fwdResult, _ = turtle.forward()
            if not fwdResult then
                local _, block = turtle.inspect()
                if block.name == "minecraft:bedrock" then
                    return false
                else
                    turtle.dig()
                end
            else
                break
            end
        end
        turtle.digUp()
        turtle.digDown()
    end
    return true
end

local function unload(level)
    turtle.turnLeft()
    turtle.turnLeft()
    for m = 1, level do
        turtle.up()
    end
    for slot = 1, 16 do
        turtle.select(slot)
        turtle.drop()
    end
    turtle.turnLeft()
    turtle.turnLeft()
    for m = 1, level do
        turtle.down()
    end
end


local function returnHome(facing, initDimensions, level)
    for m = 1, facing % 4 do
        turtle.turnLeft()
    end

    turtle.turnLeft()
    turtle.turnLeft()
    local meem = 0
    if initDimensions % 2 == 0 then
        meem = initDimensions / 2 - 1
    else
        meem = initDimensions / 2
    end
    for n = 1, meem do
        turtle.forward()
    end
    turtle.turnRight()
    for n = 1, initDimensions / 2 do
        turtle.forward()
    end
    turtle.turnRight()
end

local function excavate(initDimensions)
    if initDimensions < 3 then
        print("Excavatedimensions must be at least 3")
        return
    end

    local level = 0
    local passOne = true

    while true do
        local facing = 0
        local dimensions = initDimensions


        turtle.digDown()
        if turtle.down() then
            level = level + 1
        end
        turtle.digDown()
        if turtle.down() then
            level = level + 1
        end
        turtle.digDown()
        if passOne then
            passOne = false
        else
            if turtle.down() then
                level = level + 1
            end
            turtle.digDown()
        end

        if not digUpDownPath(dimensions - 1) then
            for m = 1, level do
                turtle.up()
            end
            return
        end

        turtle.turnRight()
        facing = facing + 1

        while dimensions > 1 do
            for _ = 1, 2 do
                if not digUpDownPath(dimensions - 1) then
                    for m = 1, level do
                        turtle.up()
                    end
                    return
                end

                turtle.turnRight()
                facing = facing + 1
            end
            dimensions = dimensions - 1
        end

        returnHome(facing, initDimensions, level)

        if checkInventoryFull() then
            unload(level)
        end
    end

    -- turtle.turnRight()
    -- for n = 1, initDimensions / 2 do
    --     turtle.forward()
    -- end
    -- turtle.turnRight()
    -- turtle.down()
    -- end

    -- for x = 1, dimensions / 3 do
    --     for i = 1, 3 do
    --         turtle.dig()
    --         for j = 1, dimensions - (1 + x) do
    --             turtle.forward()
    --             turtle.dig()
    --             turtle.digUp()
    --             turtle.digDown()
    --         end
    --
    --         turtle.forward()
    --         turtle.digUp()
    --         turtle.digDown()
    --
    --         turtle.turnRight()
    --     end
    -- end
end

local function initExcavate()
    local MAX_TRIES = 3
    local tries = 0
    local validInput = false

    local selectedSize = menu("Hole size", { "3x3", "5x5", "10x10", "15x15", "20x20", "custom", "back" })

    if selectedSize == "3x3" then
        if requireFuel(fuelNeededToExcavate(3)) == nil then
            return
        end
        if requireTool("minecraft:diamond_pickaxe", "right") == nil then
            return
        end
        -- shell.run("excavate " .. 3)
        excavate(3)
    elseif selectedSize == "5x5" then
        if requireFuel(fuelNeededToExcavate(5)) == nil then
            return
        end
        if requireTool("minecraft:diamond_pickaxe", "right") == nil then
            return
        end
        -- shell.run("excavate " .. 5)
        excavate(5)
    elseif selectedSize == "10x10" then
        if requireFuel(fuelNeededToExcavate(10)) == nil then
            return
        end
        if requireTool("minecraft:diamond_pickaxe", "right") == nil then
            return
        end
        -- shell.run("excavate " .. 10)
        excavate(10)
    elseif selectedSize == "15x15" then
        if requireFuel(fuelNeededToExcavate(15)) == nil then
            return
        end
        if requireTool("minecraft:diamond_pickaxe", "right") == nil then
            return
        end
        -- shell.run("excavate " .. 15)
        excavate(15)
    elseif selectedSize == "20x20" then
        if requireFuel(fuelNeededToExcavate(20)) == nil then
            return
        end
        if requireTool("minecraft:diamond_pickaxe", "right") == nil then
            return
        end
        -- shell.run("excavate " .. 20)
        excavate(20)
    elseif selectedSize == "custom" then
        term.clear()
        term.setCursorPos(1, 1)
        print("Please give the edge length of the hole i should dig (only squares are supported)")

        while not validInput and tries < MAX_TRIES do
            local dimensions = tonumber(read())
            if dimensions == nil then
                print("Please insert a valid number")
                tries = tries + 1
            else
                if debugTurtle(fuelNeededToExcavate(dimensions), "minecraft:diamond_pickaxe", "right") == nil then
                    return
                end
                -- shell.run("excavate " .. dimensions)
                excavate(dimensions)
            end
        end
    end
end

local function rwCall(value)
    local host = "192.168.2.152"
    local port = 4000
    local key = 86
    local module_identifier = 4294967295

    http.get("http://" ..
        host .. ":" .. port .. "/keyevent?input_id=" .. key .. "&module_identifier=" .. module_identifier .. "&value=" ..
        value)
end

local function main()
    while true do
        local menuContent = { "Start", { "programs", "help", "terminal", "refuel" } }

        while true do
            local selectedMenuItem = menu(menuContent[1], menuContent[2])

            if menuContent[1] == "Start" then
                if selectedMenuItem == "programs" then
                    menuContent = { "Programs", { "excavate", "Ahorn", "back" } }
                elseif selectedMenuItem == "help" then
                    menuContent = { "Help", { "Who am i?", "Why am i missbehaving?", "back" } }
                elseif selectedMenuItem == "terminal" then
                    term.clear()
                    term.setCursorPos(1, 1)
                    return
                elseif selectedMenuItem == "refuel" then
                    refuel(true)
                end
            elseif menuContent[1] == "Programs" then
                if selectedMenuItem == "excavate" then
                    initExcavate()
                    break
                elseif selectedMenuItem == "Ahorn" then
                    menuContent = { "Set AHORN color", { "RED", "GREEN", "BLUE", "back" } }
                elseif selectedMenuItem == "back" then
                    break
                end
            elseif menuContent[1] == "Set AHORN color" then
                if selectedMenuItem == "RED" then
                    rwCall(0)
                elseif selectedMenuItem == "GREEN" then
                    rwCall(1)
                elseif selectedMenuItem == "BLUE" then
                    rwCall(2)
                elseif selectedMenuItem == "back" then
                    menuContent = { "Programs", { "excavate", "Ahorn", "back" } }
                end
            elseif menuContent[1] == "Help" then
                if selectedMenuItem == "Who am i?" then
                    term.clear()
                    term.setCursorPos(1, 1)
                    print(math.floor(os.time()) .. ":" .. (math.floor(os.time() % 1 * 60)) .. " Uhr")
                    print("OS: " .. os.version())
                    print("Name: " .. (os.getComputerLabel() or "NOT GIVEN"))
                    print("ID: " .. os.getComputerID())
                    print("Fuel: " .. turtle.getFuelLevel())

                    print("")
                    print("Press any key to return...")
                    os.pullEvent("key")
                elseif selectedMenuItem == "Why am i missbehaving?" then
                    local dbgResult = debugTurtle(1, "minecraft:diamond_pickaxe", "right")
                    if dbgResult then
                        term.clear()
                        term.setCursorPos(1, 1)
                        print("I dont know whats wrong. Ask Jonas")
                        print("")
                        print("Press any key to return...")
                        os.pullEvent("key")
                    end
                elseif selectedMenuItem == "back" then
                    break
                end
            end
        end
    end
end

main()
turtle.turnRight()
