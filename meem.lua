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

local function refuel()
    term.clear()
    drawStatusline()

    term.setCursorPos(2, 1)

    print("Place some fuel in my inventory")
    print("")
    print("Press any button to refuel")
    os.pullEvent("key")
end

local function requireFuel(requiredLevel)
    local MAX_TRIES = 10
    local tries = 0

    term.clear()
    drawStatusline()

    local fuelLevel = turtle.getFuelLevel()


    while fuelLevel < requiredLevel and MAX_TRIES > tries do
        tries = tries + 1

        term.clear()
        term.setCursorPos(2, 1)
        print("only " .. fuelLevel .. "/" .. requiredLevel .. " required fuel. Try " .. tries .. "/" .. MAX_TRIES)
        os.sleep(2)

        refuel()
    end
    if MAX_TRIES == tries then
        return nil
    else
        return true
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
        os.sleep(2)
    end
    if MAX_TRIES == tries then
        return nil
    else
        return true
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


-- @return selected item number
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

local function fuelNeededToExcavate(dimensions)
    return (2 * (dimensions * dimensions + 64 * 2)) * 1.5
end

local function excavate()
    local MAX_TRIES = 3
    local tries = 0
    local validInput = false

    local selectedSize = menu("Hole size", { "3x3", "5x5", "10x10", "15x15", "20x20", "custom", "back" })

    if selectedSize == "3x3" then
        if requireFuel(fuelNeededToExcavate(3)) == nil then
            return
        end
        if requireTool("minecraft:diamond_pickaxe") == nil then
            return
        end
        shell.run("excavate " .. 3)
    elseif selectedSize == "5x5" then
        if requireFuel(fuelNeededToExcavate(5)) == nil then
            return
        end
        if requireTool("minecraft:diamond_pickaxe") == nil then
            return
        end
        shell.run("excavate " .. 5)
    elseif selectedSize == "10x10" then
        if requireFuel(fuelNeededToExcavate(10)) == nil then
            return
        end
        if requireTool("minecraft:diamond_pickaxe") == nil then
            return
        end
        shell.run("excavate " .. 10)
    elseif selectedSize == "15x15" then
        if requireFuel(fuelNeededToExcavate(15)) == nil then
            return
        end
        if requireTool("minecraft:diamond_pickaxe") == nil then
            return
        end
        shell.run("excavate " .. 15)
    elseif selectedSize == "20x20" then
        if requireFuel(fuelNeededToExcavate(20)) == nil then
            return
        end
        if requireTool("minecraft:diamond_pickaxe") == nil then
            return
        end
        shell.run("excavate " .. 20)
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
                if requireFuel(fuelNeededToExcavate(dimensions)) == nil then
                    return
                end
                if requireTool("minecraft:diamond_pickaxe") == nil then
                    return
                end
                shell.run("excavate " .. dimensions)
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
                    refuel()
                end
            elseif menuContent[1] == "Programs" then
                if selectedMenuItem == "excavate" then
                    excavate()
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
                elseif selectedMenuItem == "Why am i not missbehaving?" then
                    term.clear()
                    term.setCursorPos(1, 1)

                    if turtle.getFuelLevel() == 0 then
                        print("No fuel")
                    elseif turtle.getEquippedRight() == nil then
                        print("Tool is missing")
                    else
                        print("I dont know, ask Jonas")
                    end

                    print("")
                    print("Press any key to return...")
                    os.pullEvent("key")
                elseif selectedMenuItem == "back" then
                    break
                end
            end
        end
    end
end

main()
