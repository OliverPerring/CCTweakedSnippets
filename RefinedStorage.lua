-- Sleep to let the pack start fully
sleep(5)
local monitors = {peripheral.find("monitor")}

local topMonitor = monitors[1]  -- Main top monitor
local rightMonitor = monitors[2]  -- Modem-connected right monitor
local leftMonitor = monitors[3]  -- Left monitor (if needed later)

-- Set up peripherals
local rs = nil  -- Explicitly define rs to avoid nil errors
while not rs do
    rs = peripheral.find("rsBridge")
    if not rs then
        if topMonitor then
            term.redirect(topMonitor)
            term.setBackgroundColor(colors.black)
            term.clear()
            term.setCursorPos(1, 1)
            term.setTextColor(colors.red)
            term.write("Waiting for Refined Storage...")
        end
        sleep(2)
    end
end

-- Clear right and left monitors if they exist
if rightMonitor then
    term.redirect(rightMonitor)
    term.setBackgroundColor(colors.black)
    term.clear()
end

if leftMonitor then
    term.redirect(leftMonitor)
    term.setBackgroundColor(colors.black)
    term.clear()
end

-- Default to top monitor for now
term.redirect(topMonitor)

-- Color Palette
local backgroundColor = colors.black
local borderColor = colors.cyan
local itemColor = colors.lightGray
local amountColor = colors.orange
local lowStockColor = colors.red
local headerColor = colors.blue
local increaseColor = colors.green
local decreaseColor = colors.red
local batteryColor = colors.green
local batteryLowColor = colors.red
local batteryFrameColor = colors.gray
local fluidBarColor = colors.blue
local fluidEmptyColor = colors.gray

local itemHistory = {}
local arrowHistory = {}
local arrowColorHistory = {}

-- Scaling and Layout
function calculateScaling()
    topMonitor.setTextScale(1.8)  -- Increased text scale for better readability
    w, h = topMonitor.getSize()
end

-- Draw battery status on bottom monitor
function drawBattery()
    if leftMonitor then
        term.redirect(leftMonitor)
        leftMonitor.setTextScale(1.0)  -- Reset to ensure correct scaling
        local lw, lh = leftMonitor.getSize()
        term.redirect(leftMonitor)
        term.setBackgroundColor(colors.black)
        
        local energy = rs.getEnergyStorage()
        local maxEnergy = rs.getMaxEnergyStorage()
        local energyUsage = rs.getEnergyUsage()
        
        -- Display battery status text
        local statusText = string.format("FE Status: %d FE / %d FE Usage: %d FE", energy, maxEnergy, energyUsage)
        local startX = math.floor((lw - #statusText) / 2) + 1
        term.setCursorPos(startX, 1)
        term.setTextColor(colors.white)
        term.write(statusText)
        
        local barWidth = 35
        local barHeight = 2
        local fill = math.floor((energy / maxEnergy) * barWidth)
        local batteryX = math.floor(lw / 2) - math.floor(barWidth / 2)
        local batteryY = math.floor(lh / 2)

        -- Draw battery frame
        paintutils.drawBox(batteryX, batteryY, batteryX + barWidth, batteryY + barHeight, batteryFrameColor)
        
        -- Draw battery fill
        local color = energy / maxEnergy < 0.2 and batteryLowColor or batteryColor
        paintutils.drawBox(batteryX + 1, batteryY + 1, batteryX + fill, batteryY + barHeight - 1, color)
        paintutils.drawBox(batteryX + fill + 1, batteryY + 1, batteryX + barWidth - 1, batteryY + barHeight - 1, batteryLowColor)
               
        end
end

-- Draw Item monitoring on right monitor
local itemHistoryGraph = {}
local barColorHistory = {}
local previousItemCount = 0
local maxGraphHeight = 6  -- Max height for right monitor graph

function drawItemGraph()
    if rightMonitor then
        term.redirect(rightMonitor)
        rightMonitor.setTextScale(0.6)
        local rw, rh = rightMonitor.getSize()
        term.setBackgroundColor(colors.black)
        term.clear()
        
        -- Get total item count
        local totalItemCount = 0
        local rsitems = rs.listItems() or {}
        for _, item in pairs(rsitems) do
            totalItemCount = totalItemCount + item.amount
        end
        
        -- Calculate difference from previous total
        local difference = totalItemCount - previousItemCount
        previousItemCount = totalItemCount
        
        -- Store item count and bar color in history
        local scaleFactor = 10  -- Adjust scaling for better visibility
        local scaledDifference = math.floor(difference * scaleFactor)
        
        -- Insert into history and apply color based on direction
        table.insert(itemHistoryGraph, scaledDifference)
        table.insert(barColorHistory, difference >= 0 and increaseColor or decreaseColor)

        if #itemHistoryGraph > rw then
            table.remove(barColorHistory, 1)
            table.remove(itemHistoryGraph, 1)
        end
        
        -- Draw graph bars
        local maxAmount = math.max(10, unpack(itemHistoryGraph))
        local barSpacing = math.max(1, math.floor(rw / maxGraphHeight))
        for i = math.max(1, #itemHistoryGraph - rw + 1), #itemHistoryGraph do
            local barX = rw - (#itemHistoryGraph - i) + 1
            local barHeight = math.floor((itemHistoryGraph[i] / maxAmount) * (rh * 0.8))
            local barColor = barColorHistory[i - math.max(1, #itemHistoryGraph - rw + 1) + 1] or increaseColor
            term.setBackgroundColor(barColor)  -- Cap at 80% height
            
            for y = rh, rh - barHeight + 1, -1 do
                term.setCursorPos(barX, y)
                term.write(" ")
            end
        end

        
        -- Display total item count
        term.setCursorPos(1, 1)
        term.setTextColor(colors.white)
    end
end

-- Draw header
function drawHeader(text)
    term.setBackgroundColor(headerColor)
    term.clearLine()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    term.write(text)
end

-- Draw footer
function drawFooter()
    term.setBackgroundColor(headerColor)
    term.setCursorPos(1, h)
    term.clearLine()
    term.setTextColor(colors.white)
    term.write(" Updated: " .. os.date("%X"))
end

-- Draw separator line
function drawSeparator(y)
    paintutils.drawLine(1, y, w, y, borderColor)
end

-- Draw item row with persistent up/down indicator and color
function drawItemRow(y, itemName, itemAmount)
    if y < h then  -- Prevent overwriting the footer
        local previousAmount = itemHistory[itemName] or itemAmount
        local arrow = arrowHistory[itemName] or " "
        local textColor = itemColor
        local arrowColor = arrowColorHistory[itemName] or amountColor

        if itemAmount < 100 then
            textColor = lowStockColor
        end

        if itemAmount > previousAmount then
            arrow = "^"
            arrowColor = increaseColor
        elseif itemAmount < previousAmount then
            arrow = "v"
            arrowColor = decreaseColor
        end

        itemHistory[itemName] = itemAmount
        arrowHistory[itemName] = arrow
        arrowColorHistory[itemName] = arrowColor

        term.setCursorPos(2, y)
        term.setBackgroundColor(backgroundColor)
        term.clearLine()
        term.setTextColor(textColor)
        term.write(itemName:gsub("[%[%]]", ""))  -- Remove brackets

        term.setCursorPos(w - #tostring(itemAmount) - 3, y)
        term.setTextColor(amountColor)
        term.write(tostring(itemAmount) .. " ")
        term.setTextColor(arrowColor)
        term.write(arrow)
    end
end

-- Display items in list format with smooth scrolling
function displayList()
	term.redirect(topMonitor)
    term.setBackgroundColor(backgroundColor)
    term.clear()

    drawHeader(" Storage Overview ")
    drawSeparator(2)

    local scrollOffset = 0
    local visibleRows = h - 4  -- Ensure footer space is not overwritten

    while true do
		term.redirect(topMonitor)
        rsitems = rs.listItems()  -- Refresh items every loop
        local filteredItems = {}

        for _, item in pairs(rsitems) do
            if item.amount >= 32 then
                table.insert(filteredItems, item)
            end
        end
        table.sort(filteredItems, function(a, b) return a.amount > b.amount end)

        term.setBackgroundColor(backgroundColor)
        term.clear()
        drawHeader(" Storage Overview ")
        drawSeparator(2)
        drawFooter()

        local y = 3
        for i = 1 + scrollOffset, #filteredItems + scrollOffset do
            local index = ((i - 1) % #filteredItems) + 1  -- Loop smoothly
            if y < h then  -- Ensure rows stop before footer
                drawItemRow(y, filteredItems[index].displayName, filteredItems[index].amount)
            end
            y = y + 1
            if y >= h then  -- Stop drawing when footer is reached
                break
            end
        end

        drawFooter()

        sleep(0.35)  -- Faster scroll speed
        scrollOffset = scrollOffset + 1

		drawBattery()
        drawItemGraph()
    end
end

-- Main execution loop
function refreshDisplay()
    calculateScaling()
    displayList()
end

-- Start display
refreshDisplay()
