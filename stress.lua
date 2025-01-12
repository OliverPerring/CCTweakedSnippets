-- Find the stressometer and monitor
local stressometer = peripheral.find("Create_Stressometer")
local monitor = peripheral.find("monitor")

if not stressometer or not monitor then
    error("Stressometer or Monitor not found!")
end

-- Set the monitor size and clear it
monitor.setTextScale(0.5) -- Adjust text scale for better resolution
monitor.clear()
monitor.setCursorPos(1, 1)
term.redirect(monitor) 

-- Monitor dimensions
local monitorWidth, monitorHeight = monitor.getSize()

-- Gauge parameters
local gaugeWidth = monitorWidth - 2
local gaugeHeight = monitorHeight - 2
local gaugeXStart = 2
local gaugeYStart = 2

-- Function to draw a gauge
local function drawGauge(current, max)
    local percentage = current / max
    local filledWidth = math.floor(gaugeWidth * percentage)

    -- Redirect to monitor for paintutils
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)

    -- Draw the outline of the gauge
    paintutils.drawBox(gaugeXStart, gaugeYStart, gaugeXStart + gaugeWidth, gaugeYStart + gaugeHeight, colors.white)

    -- Fill the gauge proportionally to the current stress
    paintutils.drawFilledBox(gaugeXStart + 1, gaugeYStart + 1, gaugeXStart + filledWidth, gaugeYStart + gaugeHeight - 1, colors.red)

    -- Write the percentage text in the center of the gauge
    local percentageText = string.format("Stress: %.2f%%", percentage * 100)
    local textX = math.floor((monitorWidth - #percentageText) / 2)
    local textY = math.floor(monitorHeight / 2)
    monitor.setCursorPos(textX, textY)
    monitor.write(percentageText)
end

-- Main loop
while true do
    local currentStress = stressometer.getStress()
    local maxStress = stressometer.getStressCapacity()

    if maxStress > 0 then
        monitor.clear() -- Clear monitor before drawing
        drawGauge(currentStress, maxStress)
    else
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.write("No stress capacity detected!")
    end

    sleep(1) -- Update every second
end
