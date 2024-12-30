rs = peripheral.find("rsBridge")
monitor = peripheral.find('monitor')

term.redirect(monitor)

selectedItem = nil

charMap = {
    ["A"] = {
        "0110",
        "1001",
        "1111",
        "1001",
        "1001"
    },
    ["B"] = {
        "1110",
        "1001",
        "1110",
        "1001",
        "1110"
    },
    ["C"] = {
        "0111",
        "1000",
        "1000",
        "1000",
        "0111"
    },
    ["D"] = {
        "1110",
        "1001",
        "1001",
        "1001",
        "1110"
    },
    ["E"] = {
        "1111",
        "1000",
        "1111",
        "1000",
        "1111"
    },
    ["F"] = {
        "1111",
        "1000",
        "1111",
        "1000",
        "1000"
    },
    ["G"] = {
        "0111",
        "1000",
        "1011",
        "1001",
        "0111"
    },
    ["H"] = {
        "1001",
        "1001",
        "1111",
        "1001",
        "1001"
    },
    ["I"] = {
        "111",
        "010",
        "010",
        "010",
        "111"
    },
    ["J"] = {
        "111",
        "001",
        "001",
        "101",
        "010"
    },
    ["K"] = {
        "1001",
        "1010",
        "1100",
        "1010",
        "1001"
    },
    ["L"] = {
        "1000",
        "1000",
        "1000",
        "1000",
        "1111"
    },
    ["M"] = {
        "10001",
        "11011",
        "10101",
        "10001",
        "10001"
    },
    ["N"] = {
        "10001",
        "11001",
        "10101",
        "10011",
        "10001"
    },
    ["O"] = {
        "0110",
        "1001",
        "1001",
        "1001",
        "0110"
    },
    ["P"] = {
        "1110",
        "1001",
        "1110",
        "1000",
        "1000"
    },
    ["Q"] = {
        "0110",
        "1001",
        "1011",
        "1001",
        "0111"
    },
    ["R"] = {
        "1110",
        "1001",
        "1110",
        "1010",
        "1001"
    },
    ["S"] = {
        "0111",
        "1000",
        "0110",
        "0001",
        "1110"
    },
    ["T"] = {
        "11111",
        "00100",
        "00100",
        "00100",
        "00100"
    },
    ["U"] = {
        "1001",
        "1001",
        "1001",
        "1001",
        "0110"
    },
    ["V"] = {
        "1001",
        "1001",
        "1001",
        "0101",
        "0010"
    },
    ["W"] = {
        "10001",
        "10001",
        "10101",
        "11011",
        "10001"
    },
    ["X"] = {
        "10001",
        "01010",
        "00100",
        "01010",
        "10001"
    },
    ["Y"] = {
        "10001",
        "01010",
        "00100",
        "00100",
        "00100"
    },
    ["Z"] = {
        "1111",
        "0001",
        "0010",
        "0100",
        "1111"
    },
    ["0"] = {
        "0110",
        "1001",
        "1001",
        "1001",
        "0110"
    },
    ["1"] = {
        "010",
        "110",
        "010",
        "010",
        "111"
    },
    ["2"] = {
        "1110",
        "0001",
        "0110",
        "1000",
        "1111"
    },
    ["3"] = {
        "1110",
        "0001",
        "0110",
        "0001",
        "1110"
    },
    ["4"] = {
        "1001",
        "1001",
        "1111",
        "0001",
        "0001"
    },
    ["5"] = {
        "1111",
        "1000",
        "1110",
        "0001",
        "1110"
    },
    ["6"] = {
        "0111",
        "1000",
        "1110",
        "1001",
        "0110"
    },
    ["7"] = {
        "1111",
        "0001",
        "0010",
        "0100",
        "0100"
    },
    ["8"] = {
        "0110",
        "1001",
        "0110",
        "1001",
        "0110"
    },
    ["9"] = {
        "0110",
        "1001",
        "0111",
        "0001",
        "0110"
    },
    [":"] = {
        "0",
        "1",
        "0",
        "1",
        "0"
    },
    [" "] = {
        "0",
        "0",
        "0",
        "0",
        "0"
    }
}

-- Calculate dynamic scaling based on monitor size
function calculateScaling()
    monitorWidth, monitorHeight = monitor.getSize()

    targetWidth = 9
    targetHeight = 5

    local textScaleX = monitorWidth / (targetWidth * 6)
    local textScaleY = monitorHeight / (targetHeight * 3)

    scale = math.min(textScaleX, textScaleY)
    scale = math.max(0.75, math.min(1, scale))
    monitor.setTextScale(scale)

    w, h = monitor.getSize()

    boxWidth = math.floor(w / targetWidth)
    boxHeight = math.floor(h / targetHeight)
    boxesPerRow = math.floor(w / boxWidth)
    rows = math.floor(h / boxHeight) - 1  -- Leave room for ticker
end

-- Render a character at (x,y) using a 5x7 grid
function drawChar(x, y, char, size, color)
    local pixels = charMap[char]
    if not pixels then return end  -- Skip if character isn't mapped

    term.setBackgroundColor(color)

    for row = 1, #pixels do
        for col = 1, #pixels[row] do
            if pixels[row]:sub(col, col) == "1" then
                paintutils.drawBox(
                    x + (col - 1) * size,
                    y + (row - 1) * size,
                    x + col * size - 1,
                    y + row * size - 1
                )
            end
        end
    end
end

-- Draw text using the char map
function drawLargeText(x, y, text, size, color)
    for i = 1, #text do
        local char = text:sub(i, i)
        drawChar(x + (i - 1) * (6 * size), y, char, size, color)
    end
end

-- Shorten item names
function shortenItemName(name)
    name = name:gsub("[%[%]]", "")

    if name:match("Ingot") then
        return name:gsub("Ingot", "I")
    elseif name:match("Raw") then
        return name:gsub("Raw", "R")
    elseif name:match("Ore") then
        return name:gsub("Ore", "O")
    elseif name:match("Essence") then
        return name:gsub("Essence", "E")
    elseif name:match("Nether") then
        return name:gsub("Nether", "N")
    elseif name:match("Seeds") or name:match("Seed") then
        return name:gsub("Seed[s]?", "S")
    elseif name:match("Log") then
        return name:gsub("Log", "L")
    else
        return name:match("^[^ ]+") or name
    end
end

-- Shorten long text to fit within a box
function dynamicallyShorten(text, maxWidth)
    while #text > maxWidth do
        if text:find(" ") then
            firstWord = text:match("^[^ ]+")
            rest = text:match(" .+") or ""

            if firstWord and #firstWord > 2 then
                text = string.sub(firstWord, 1, #firstWord - 1) .. rest
            else
                text = string.sub(text, 1, #text - 1)
            end
        else
            if #text > 2 then
                text = string.sub(text, 1, #text - 1)
            else
                break
            end
        end
    end
    return text
end

-- Draw item box
function drawBox(x, y, width, height, innerColor, borderColor)
    paintutils.drawFilledBox(x - 1, y - 1, x + width, y + height, borderColor)
    paintutils.drawFilledBox(x, y, x + width - 2, y + height - 2, innerColor)
end

-- Print left-aligned text in the box
function printLeft(x, y, text, color)
    displayText = dynamicallyShorten(text, boxWidth - 2)
    term.setTextColor(color)
    term.setCursorPos(x + 1, y)
    term.write(displayText)
end

-- Display item in fullscreen with large canvas text
function displayFullScreen(item)
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Draw full-screen box
    drawBox(1, 1, w, h - 1, colors.lightGray, colors.green)

    -- Determine text color based on item count
    local textColor
    if item.amount > 5000 then
        textColor = colors.red
    elseif item.amount > 2000 then
        textColor = colors.orange
    else
        textColor = colors.white
    end

    -- Draw item name in large text
    centerX = math.floor(w / 4)
    centerY = math.floor(h / 4)

    -- Draw item count below
    drawLargeText(centerX - 2, centerY, tostring(item.amount), 2, textColor)

    -- Print exit instruction at the bottom
    term.setCursorPos(math.floor(w / 2) - 10, h - 3)
    term.setTextColor(colors.white)
    term.write("Tap anywhere to return")
end

function scrollTicker(lowestItems)
    local tickerText = ""
    for _, item in ipairs(lowestItems) do
        tickerText = tickerText .. shortenItemName(item.displayName) .. ":" .. item.amount .. "  "
    end

    local pos = 1
    while true do
        term.setCursorPos(1, h)
        term.clearLine()
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)  -- Force ticker text to be white
        term.write(string.sub(tickerText, pos, pos + w))

        pos = pos + 1
        if pos > #tickerText then
            pos = 1
        end
        sleep(0.2)
    end
end

-- Detect which box was clicked
function detectClick(x, y)
    local boxX = math.floor((x - 2) / boxWidth) + 1
    local boxY = math.floor((y - 2) / boxHeight)
    local index = (boxY * boxesPerRow) + boxX
    return index
end

calculateScaling()

parallel.waitForAny(
    function()
        filteredItems = {}
        local refreshTimer = os.startTimer(5)  -- Start a timer for auto-refresh
        while true do
            term.setBackgroundColor(colors.green)
            term.clear()
            term.setCursorPos(1, 1)
            rsitems = rs.listItems()

            filteredItems = {}  -- Rebuild filtered list each refresh
            for _, item in pairs(rsitems) do
                if item.amount >= 32 then
                    table.insert(filteredItems, item)
                end
            end

            table.sort(filteredItems, function(a, b)
                return a.amount > b.amount
            end)

            -- Display grid or zoomed item
            if selectedItem then
                displayFullScreen(selectedItem)
            else
                for i, item in ipairs(filteredItems) do
                    col = ((i - 1) % boxesPerRow) * boxWidth + 2
                    row = math.floor((i - 1) / boxesPerRow) * boxHeight + 2

                    if row + boxHeight > h - 1 then
                        break
                    end

                    -- Color logic for counts
                    local textColor
                    if item.amount > 5000 then
                        textColor = colors.red
                    elseif item.amount > 2000 then
                        textColor = colors.orange
                    else
                        textColor = colors.white
                    end

                    drawBox(col, row, boxWidth, boxHeight, colors.lightGray, colors.green)
                    printLeft(col, row + 1, shortenItemName(item.displayName), textColor)
                    printLeft(col, row + 3, tostring(item.amount), textColor)
                end
            end

            -- Wait for touch or timer event
            local event, param1, param2, param3 = os.pullEvent()

            if event == "monitor_touch" then
                local index = detectClick(param2, param3)
                if selectedItem then
                    selectedItem = nil
                elseif filteredItems[index] then
                    selectedItem = filteredItems[index]
                end
            elseif event == "timer" and param1 == refreshTimer then
                -- Timer event: refresh the grid and restart the timer
                refreshTimer = os.startTimer(5)
            end
        end
    end,
    function()
        while true do
            if #filteredItems > 0 then
                scrollTicker(filteredItems)
            else
                sleep(1)
            end
        end
    end
)

