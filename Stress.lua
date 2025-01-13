-- Find the stressometer and monitor
local stressometer = peripheral.find("Create_Stressometer")
local monitor = peripheral.find("monitor")

if not stressometer or not monitor then
    error("Stressometer or Monitor not found!")
end

-- Redirect term to monitor
term.redirect(monitor)

-- Set the monitor size and clear it
monitor.setTextScale(0.5) -- Adjust text scale for better resolution
monitor.clear()
monitor.setCursorPos(1, 1)

-- Monitor dimensions
local monitorWidth, monitorHeight = monitor.getSize()

-- Gauge parameters
local gaugeWidth = monitorWidth - 4 -- Leave padding for the border
local gaugeXStart = 3 -- Start slightly inside the edges
local gaugeYStart = math.floor(monitorHeight / 2) -- Move down to accommodate the title
local gaugeHeight = 3 -- Height of the gauge

-- Function to draw the title
local function drawTitle()
    local title = "Current System Stress"
    local textX = math.floor((monitorWidth - #title) / 2)
    local textY = gaugeYStart - 4 -- Position above the gauge

    monitor.setCursorPos(textX, textY)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.write(title)
end

-- Function to draw a gauge
local function drawGauge(current, max)
    -- Check for invalid data
    if max <= 0 then
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.write("Invalid stress capacity!")
        return
    end

    local percentage = current / max
    if percentage > 1 then percentage = 1 end -- Cap at 100%
    if percentage < 0 then percentage = 0 end -- Ensure no negative values

    local filledWidth = math.floor(gaugeWidth * percentage)

    -- Clear the area (gauge only)
    paintutils.drawBox(gaugeXStart, gaugeYStart, gaugeXStart + gaugeWidth, gaugeYStart + gaugeHeight, colors.black)

    -- Draw the gauge border in light grey
    paintutils.drawBox(gaugeXStart, gaugeYStart, gaugeXStart + gaugeWidth, gaugeYStart + gaugeHeight, colors.lightGray)

    -- Fill the gauge proportionally to the current stress
    if filledWidth > 0 then
        paintutils.drawFilledBox(
            gaugeXStart + 1,
            gaugeYStart + 1,
            gaugeXStart + filledWidth,
            gaugeYStart + gaugeHeight - 1,
            colors.red
        )
    end

    -- Write the percentage text slightly below the gauge
    local percentageText = string.format("Stress: %.2f%%", percentage * 100)
    local textX = math.floor((monitorWidth - #percentageText) / 2)
    local textY = gaugeYStart + gaugeHeight + 2 -- Adjusted position for text
    monitor.setCursorPos(textX, textY)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.write(percentageText)
end

-- Main loop
while true do
    local currentStress = stressometer.getStress()
    local maxStress = stressometer.getStressCapacity()

    if maxStress > 0 then
        monitor.clear()
        drawTitle()
        drawGauge(currentStress, maxStress)
    else
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.write("No stress capacity detected!")
    end

    sleep(1) -- Update every second
end
