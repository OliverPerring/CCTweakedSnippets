-- configs
local borderColour = 128
local chartBGColour = 128
local inputChartColour = 32
local outputChartColour = 16384
local batteryChargeColour = 8
local idleColour = 16
local sectionTitleColour = 1
local baseTextColour = 1

local screenRefreshRate = 0.2 -- how often to display new data in seconds.
local unitFormatCaps = true -- true = X.X KRF. false = X.XkRF
local dataCorrection = 2.5 -- value to divide IM data by.

-- setup
local m = peripheral.find("monitor")
local im = peripheral.find("inductionPort")
local w, h = nil

function fromBlit(hex)
    if #hex ~= 1 then return nil end
    local value = tonumber(hex, 16)
    if not value then return nil end

    return 2 ^ value
end

function draw(xStart, xLen, yStart, yLen, c, target)
    target = target or m
    local ob = target.getBackgroundColour()
    target.setBackgroundColor(c)
    target.setCursorPos(xStart, yStart)
    if xLen > 1 then
        for i = 1, xLen do
            target.write(" ")
            target.setCursorPos(xStart+i, yStart)
        end
    elseif xLen ~= 0 and yLen ~= 0 then
        target.write(" ")
    end

    if yLen > 1 then
        for k = 1, yLen-1 do
            target.setCursorPos(xStart, yStart+k)
            target.write(" ")
        end
    end
    
    target.setBackgroundColor(ob)
end

function drawBar(xmin, xmax, y, r, c)
    for i=1, r, 1 do    
        draw(xmin, xmax, y+i-1, 1, c)
    end
end

function writeAt(x, y, t, c, b, target)
    target = target or m
    local oc = target.getTextColour()
    local ob = target.getBackgroundColour()
    target.setTextColour(c or oc)
    target.setBackgroundColour(b or ob)
    target.setCursorPos(x, y)
    target.write(t)
    target.setTextColour(oc)
    target.setBackgroundColour(ob)
end

function newWindow(target, x, y, w, h, bg)
    local win = window.create(target, x, y, w, h) -- create window
    win.setBackgroundColor(bg or 32768)
    win.clear()
    return win
end

-- error screen
function displayError(index)
    local x, y = m.getSize()
    local errorText = "ERROR"
    local errors = {
        "The Induction Matrix has been tampered with.",
        "Induction Port not connected.",
        "The Induction Matrix is incomplete."
    }

    m.clear()
    -- error
    m.setTextColour(16384)
    m.setCursorPos((x/2) - (string.len(errorText)/2), (y/2)-1)
    m.write(errorText)
    -- msg
    writeAt((x/2) - (string.len(errors[index])/2), y/2, errors[index], baseTextColour)
    printError("ERROR: " .. errors[index])

    local timer = 10
    while timer > -1 do
        local countdownStr = "Next attempt in " .. timer
        draw((x/2) - (string.len(countdownStr)/2), string.len(countdownStr) + 1, (y/2)+2, 1, 32768) -- remove leftover data
        writeAt((x/2) - (string.len(countdownStr)/2), (y/2)+2, countdownStr, baseTextColour)
        print(countdownStr)

        timer = timer -1
        os.sleep(1)
    end

    os.reboot()
end

-- monitor check
if m ~= nil then
    m.setTextScale(0.5) -- 100 x 38
    local x, y = m.getSize()
    if x ~= 100 or y ~= 38 then
        print("ERROR: Incorrect monitor size. Monitor should be 5 wide and 3 tall.")
        return
    end

    w, h = m.getSize()
    m.setBackgroundColor(32768)
    m.clear()
    m.setTextColour(1)
else
    print("No monitor found.")
    return
end

-- matrix check
while not im or not im.isFormed() do
    if not im then
        print("not im")
        displayError(2)
    elseif not im.isFormed() then
        print("not formed")
        displayError(3)
    end
end

function removeOverflow(tableToEdit, maxDataCount)  -- delete old data
    while #tableToEdit >= maxDataCount do
        table.remove(tableToEdit, 1)
    end
    return tableToEdit
end

function getRange(input)
    local max = 0
    local min = 0
    for i = 1, #input do
        if i == 1 then
            max = input[i]
            min = input[i]
        end
        if(input[i] > max) then max = input[i] end
        if(input[i] < min) then min = input[i] end
    end
    return min, max
end

function round(x, decimal)
    local m = 10^(decimal or 0)
    local result = math.floor(x * m + 0.5) / m
    return string.format("%." .. (decimal or 0) .. "f", result)
end

function roundD(exact, quantum)
    local quant,frac = math.modf(exact/quantum)
    return quantum * (quant + (frac > 0.5 and 1 or 0))
end

-- format time
local timeUnits = {
    {threshold = 8553600, unit = "99+ days"},
    {threshold = 86400, unit = "days", divisor = 86400},
    {threshold = 3600, unit = "hours", divisor = 3600},
    {threshold = 60, unit = "min", divisor = 60},
    {threshold = 1, unit = "sec", divisor = 1}
}
function adjustTime(time)
    for _, unitData in ipairs(timeUnits) do
        if time >= unitData.threshold then
            local adjustedTime
            if unitData.divisor and unitData.divisor ~= 1 then
                adjustedTime = string.format("%.1f", time / unitData.divisor)
            elseif unitData.divisor then
                adjustedTime = math.floor(time / unitData.divisor)
            else
                adjustedTime = ""
            end
            return string.format("%s %s", adjustedTime, unitData.unit)
        end
    end
    return "0 sec."  -- fallback, if time is 0 or negative
end

function conversion(exact, text, addPlus, afterDecimalPoint)
    afterDecimalPoint = afterDecimalPoint or 0.1
    addPlus = addPlus or false

    local units = unitFormatCaps and {"", "K", "M", "G", "T", "P", "E", "Z", "Y"} or {"", "k", "m", "g", "t", "p", "e", "z", "y"}
    local pot = 1
    local absExact = math.abs(exact)

    while absExact >= (1000^pot) do
        pot = pot + 1
    end

    local value = roundD(exact / (1000^(pot - 1)), afterDecimalPoint)
    local out = tostring(value)
    
    if addPlus and value > 0 then out = "+" .. out end
    if text then out = out .. (unitFormatCaps and " " .. units[pot] or units[pot]) end

    return out
end

function protCall(func, errIndex)
    local success, result = pcall(func)
    if success and result then
        -- Function executed successfully, process the result
        return result
    else
        -- Function encountered an error
        displayError(errIndex)
    end
end

local energy, maxEnergy, installedCells, installedProviders, lastInput, lastOutput, filledPercentage, maxTransfer, lowBatAlarmEnabled = nil
local inputHistory, outputHistory, flowHistory = {}, {}, {}

function drawStaticElements()
    local p = 2
    local chartBGColour = 256
    draw(p, w-3, p, 1, borderColour) -- top
    draw(p, w-3, h-1, 1, borderColour) -- bottom
    draw(p, 1, p, h-p, borderColour) -- left
    draw(w-1, 1, p, h-p, borderColour) -- right
    draw(27, 1, p, h-p, borderColour) -- vertical divider
    draw(28, 71, h/2+2, 1, borderColour) -- horizontal divider
    draw(63, 1, h/2+3, 15, borderColour) -- small vertical divider
    draw(2, 25, 28, 1, borderColour) -- small horizontal divider

    writeAt(5, 2, "  BATTERY  ", sectionTitleColour)
    writeAt(30, 2, "  ENERGY FLOW:  ", sectionTitleColour)
    writeAt(5, 28, "  STATISTICS  ", sectionTitleColour)
    writeAt(30, 21, "  INPUT:  ", sectionTitleColour)
    writeAt(66, 21, "  OUTPUT:  ", sectionTitleColour)
end

function drawInputGraph()
    table.insert(inputHistory, lastInput)
    removeOverflow(inputHistory, 34)

    local inGraph = newWindow(m, 29, 23, 33, 13, chartBGColour)
    local ox, oy = inGraph.getSize()
    local graph_min = 0
    local graph_max = 13
    local rf_min, rf_max = getRange(inputHistory)
    
    for i = 0, #inputHistory do
        local value = inputHistory[#inputHistory-i]
        if not value then break end
        local result = math.floor(math.min(math.max((value * (graph_max - graph_min) / rf_max) + graph_min, graph_min), graph_max) + 0.5)
        if result ~= result then result = 0 end -- NaN check
        draw(ox-i, 1, oy-result+1, result, inputChartColour, inGraph)
    end

    local maxRf = conversion(rf_max, true, true) .. "RF/t"
    local txt, fg, bg = inGraph.getLine(1)
    for i = 0, #maxRf do
        local char = maxRf:sub(1+i, 1+i)
        local bg = fromBlit(bg:sub(1+i, 1+i)) or chartBGColour
        writeAt(1+i, 1, char, baseTextColour, bg, inGraph)
    end

    local maxPercent = tostring(round((rf_max/maxTransfer)*100) .. "%")
    for i = 0, #maxPercent do
        local c = ox-#maxPercent+i+1
        local char = maxPercent:sub(1+i, 1+i)
        local bg = fromBlit(bg:sub(c, c)) or chartBGColour
        writeAt(c, 1, char, baseTextColour, bg, inGraph)
    end

    local minRf = "0RF/t"
    local txt, fg, bg = inGraph.getLine(oy) -- get info about the line at y=3
    for i = 0, #minRf do
        local char = minRf:sub(1+i, 1+i)
        local bg = fromBlit(bg:sub(1+i, 1+i)) or chartBGColour
        writeAt(1+i, oy, char, baseTextColour, bg, inGraph)
    end

    local minPercent = "0%"
    for i = 0, #minPercent do
        local c = ox-#minPercent+i+1
        local char = minPercent:sub(1+i, 1+i)
        local bg = fromBlit(bg:sub(c, c)) or chartBGColour
        writeAt(c, oy, char, baseTextColour, bg, inGraph)
    end

    draw(39, 22, 21, 1, borderColour) -- erase leftover data on title bar
    local rf_tick = conversion(lastInput, true, true) .. "RF/t "
    writeAt(39, 21, rf_tick, (lastInput > 0 and inputChartColour or idleColour))
    writeAt(39+#rf_tick, 21, "(" .. tostring(round((lastInput/maxTransfer)*100) .. "%)  "))

    if lastInput == maxTransfer then
        local maxStrings = {
            "MAX INPUT!",
            "Add / Upgrade",
            "Providers."
        }
        drawBar(46-(math.max(#maxStrings[1], #maxStrings[2], #maxStrings[3])/2)-1, #maxStrings[2]+2, 27, #maxStrings+2, 1)
        writeAt(46-(#maxStrings[1]/2), 28, maxStrings[1], outputChartColour, 1)
        writeAt(46-(#maxStrings[2]/2), 29, maxStrings[2], outputChartColour, 1)
        writeAt(46-(#maxStrings[3]/2), 30, maxStrings[3], outputChartColour, 1)
    end
end

function drawOutputGraph()
    table.insert(outputHistory, lastOutput)
    removeOverflow(outputHistory, 34)
    
    local outGraph = newWindow(m, 65, 23, 33, 13, chartBGColour)
    local ox, oy = outGraph.getSize()
    local graph_min = 0
    local graph_max = 13
    local rf_min, rf_max = getRange(outputHistory)
    
    for i = 0, #outputHistory do
        local value = outputHistory[#outputHistory-i]
        if not value then break end
        local result = math.floor(math.min(math.max((value * (graph_max - graph_min) / rf_max) + graph_min, graph_min), graph_max) + 0.5)
        if result ~= result then result = 0 end -- NaN check
        draw(ox-i, 1, oy-result+1, result, outputChartColour, outGraph)
    end

    local maxRf = conversion(rf_max*-1, true, true) .. "RF/t"
    local txt, fg, bg = outGraph.getLine(1) -- get info about the line at y=3
    for i = 0, # maxRf do
        local char = maxRf:sub(1+i, 1+i)
        local bg = fromBlit(bg:sub(1+i, 1+i)) or chartBGColour
        writeAt(1+i, 1, char, baseTextColour, bg, outGraph)
    end

    local maxPercent = tostring(round((rf_max/maxTransfer)*100) .. "%")
    for i = 0, #maxPercent do
        local c = ox-#maxPercent+i+1
        local char = maxPercent:sub(1+i, 1+i)
        local bg = fromBlit(bg:sub(c, c)) or chartBGColour
        writeAt(c, 1, char, baseTextColour, bg, outGraph)
    end

    local minRf = "0RF/t"
    local txt, fg, bg = outGraph.getLine(oy) -- get info about the line at y=3
    for i = 0, #minRf do
        local char = minRf:sub(1+i, 1+i)
        local bg = fromBlit(bg:sub(1+i, 1+i)) or chartBGColour
        writeAt(1+i, oy, char, baseTextColour, bg, outGraph)
    end

    local minPercent = "0%"
    for i = 0, #minPercent do
        local c = ox-#minPercent+i+1
        local char = minPercent:sub(1+i, 1+i)
        local bg = fromBlit(bg:sub(c, c)) or chartBGColour
        writeAt(c, oy, char, baseTextColour, bg, outGraph)
    end

    draw(76, 22, 21, 1, borderColour) -- erase leftover data on title bar
    local rf_tick = conversion(lastOutput*-1, true) .. "RF/t "
    writeAt(76, 21, rf_tick, (lastOutput > 0 and outputChartColour or idleColour))
    writeAt(76+#rf_tick, 21, "(" .. tostring(round((lastOutput/maxTransfer)*100) .. "%)  "))

    if lastOutput == maxTransfer then
        local maxStrings = {
            "MAX OUTPUT!",
            "Add / Upgrade",
            "Providers."
        }
        drawBar(82-(math.max(#maxStrings[1], #maxStrings[2], #maxStrings[3])/2)-1, #maxStrings[2]+2, 27, #maxStrings+2, 1)
        writeAt(82-(#maxStrings[1]/2), 28, maxStrings[1], outputChartColour, 1)
        writeAt(82-(#maxStrings[2]/2), 29, maxStrings[2], outputChartColour, 1)
        writeAt(82-(#maxStrings[3]/2), 30, maxStrings[3], outputChartColour, 1)
    end
end

function drawFlowGraph()
    table.insert(flowHistory, lastInput-lastOutput)
    removeOverflow(flowHistory, 70)
    
    local flowGraph = newWindow(m, 29, 4, 69, 16, chartBGColour)
    local fx, fy = flowGraph.getSize()
    local graph_min = 0
    local graph_max = 8
    local rf_min, rf_max = getRange(flowHistory)
    local scale = math.max(math.abs(rf_min), rf_max) -- scale
    
    for i = 0, #flowHistory do
        local value = flowHistory[#flowHistory-i]
        if not value then break end
        value = math.abs(value)
        local result = math.floor(math.min(math.max((value * (graph_max - graph_min) / scale) + graph_min, graph_min), graph_max) + 0.5)
        if result ~= result then result = 0 end -- NaN check
        
        if result == 0 then
            writeAt(fx-i, 8, "_", 32768, chartBGColour, flowGraph)
        elseif flowHistory[#flowHistory-i] < 0 then
            draw(fx-i, 1, 9, result, outputChartColour, flowGraph)
        else
            draw(fx-i, 1, 9-result, result, inputChartColour, flowGraph)
        end
    end

    local lastFlow = flowHistory[#flowHistory]
    draw(45, 15, 2, 1, borderColour) -- erase leftover data 
    writeAt(45, 2, conversion(lastFlow, true, true) .. "RF/t  ", (lastFlow == 0 and idleColour or (lastFlow > 0 and inputChartColour or outputChartColour)))

    local positiveRf = conversion(scale, true, true) .. "RF/t"
    local txt, fg, bg = flowGraph.getLine(1) -- get info about the line at y=3
    for i = 0, #positiveRf do
        local char = positiveRf:sub(1+i, 1+i)
        local bg = fromBlit(bg:sub(1+i, 1+i)) or chartBGColour
        writeAt(1+i, 1, char, baseTextColour, bg, flowGraph)
    end

    local noRF = "0 RF/t"
    local txt, fg, bg = flowGraph.getLine(8) -- get info about the line at y=3
    for i = 0, #noRF do
        local char = noRF:sub(1+i, 1+i)
        local bg = fromBlit(bg:sub(1+i, 1+i)) or chartBGColour
        writeAt(1+i, 8, char, baseTextColour, bg, flowGraph)
    end

    local negativeRf = conversion(scale*-1, true, true) .. "RF/t"
    local txt, fg, bg = flowGraph.getLine(16) -- get info about the line at y=3
    for i = 0, #negativeRf do
        local char = negativeRf:sub(1+i, 1+i)
        local bg = fromBlit(bg:sub(1+i, 1+i)) or chartBGColour
        writeAt(1+i, 16, char, baseTextColour, bg, flowGraph)
    end

    -- writeAt(29, 19, , baseTextColour, chartBGColour)
    -- writeAt(29, 11, , baseTextColour, chartBGColour)
end

function drawBattery()
    drawBar(4, 22, 4, 23, chartBGColour) -- battery background
    
    chargeHeight = round(filledPercentage*23)
    drawBar(4, 22, 27-chargeHeight, chargeHeight, batteryChargeColour)

    local percent = tostring(round((energy/maxEnergy)*100, 2)) .. "%"
    local percentPos = (22/2) - (string.len(percent)/2) + 4
    writeAt(percentPos, 15, percent, baseTextColour, chartBGColour)

    local stored = "STORED: " .. conversion(energy, true, false, 0.01) .. "RF"
    local storedPos = (22/2) - (string.len(stored)/2) + 4
    writeAt(storedPos, 5, stored, baseTextColour, chartBGColour)

    local flow = lastInput - lastOutput
    local chargeStatus = "Idle"
    local timeStatus = ""
    local statusColour = 16
    local time = "Inf."
    if (flow < 0) then
        statusColour = 16384
        chargeStatus = "Depleting"
        timeStatus = "Empty In:"
        time = adjustTime(energy / (lastOutput - lastInput) / 20)
    elseif flow > 0 then
        statusColour = 32
        chargeStatus = "Charging"
        timeStatus = "Full In:"
        time = adjustTime((maxEnergy - energy) / (lastInput - lastOutput) / 20)
    end
    local timeString = timeStatus ~= "" and timeStatus .. " " .. time or time
    local timePos = (22/2) - (string.len(timeString)/2) + 4
    writeAt((22/2) - (string.len(chargeStatus)/2) + 4, 24, chargeStatus, baseTextColour, chartBGColour)
    writeAt(timePos, 25, timeString, baseTextColour, chartBGColour)
end

function drawStatistics()
    writeAt(4, 30, "Size: " .. imWidth .. " x " .. imHeight .. " x " .. imLength, baseTextColour)
    writeAt(4, 31, "Cells: " .. installedCells, baseTextColour)
    writeAt(4, 32, "Providers: " .. installedProviders, baseTextColour)
    writeAt(4, 33, "Empty Slots: " .. tostring(((imWidth - 2) * (imLength - 2) * (imHeight - 2))) - installedCells - installedProviders, baseTextColour)
    writeAt(4, 34, "MaxTransfer: " .. conversion(maxTransfer, true) .. "/t", baseTextColour)
    writeAt(4, 35, "MaxCapacity: " .. conversion(maxEnergy, true), baseTextColour)
end

installedCells = protCall(im.getInstalledCells, 1)
installedProviders = protCall(im.getInstalledProviders, 1)
maxEnergy = protCall(im.getMaxEnergy, 1)
maxEnergy = maxEnergy/dataCorrection
maxTransfer = protCall(im.getTransferCap, 1)
maxTransfer = maxTransfer/dataCorrection
imWidth = protCall(im.getWidth, 1)
imLength = protCall(im.getLength, 1)
imHeight = protCall(im.getHeight, 1)

drawStaticElements()
drawStatistics()
while true do
    energy = protCall(im.getEnergy, 1)
    energy = energy/dataCorrection
    lastInput = protCall(im.getLastInput, 1)
    lastInput = lastInput/dataCorrection
    lastOutput = protCall(im.getLastOutput, 1)
    lastOutput = lastOutput/dataCorrection
    filledPercentage = protCall(im.getEnergyFilledPercentage, 1)

    drawInputGraph()
    drawOutputGraph()
    drawFlowGraph()
    drawBattery()

    local activeTransfer = math.max(lastInput, lastOutput)
    local provUsage = round((activeTransfer/maxTransfer)*100, 2)

    os.sleep(screenRefreshRate)
end
