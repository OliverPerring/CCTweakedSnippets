-- Script to monitor TPS (Ticks Per Second) in Minecraft using CC:Tweaked
-- Ensure this script is run on a Computer or Advanced Computer

-- Configuration
local updateInterval = 5 -- Time in seconds between TPS updates

-- Attach to the monitor
local monitor = peripheral.find("monitor")
if not monitor then
    error("No monitor found on side " .. monitorSide)
end

monitor.setTextScale(1)
monitor.clear()
term.redirect(monitor)

-- Function to draw a horizontal bar using paintutils
local function drawHorizontalBar(x, y, width, percentage, color)
    paintutils.drawLine(x, y, x + width - 1, y, colors.black) -- Clear the bar
    local filledWidth = math.floor(width * percentage)
    if filledWidth > 0 then
        paintutils.drawLine(x, y, x + filledWidth - 1, y, color)
    end
end

-- Function to display TPS
local function displayTPS(tps)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.white)
    monitor.write("Minecraft TPS Monitor")

    monitor.setCursorPos(1, 3)
    monitor.write("Current TPS: " .. string.format("%.2f", tps))

    local status, color
    if tps >= 19.0 then
        status = "Excellent"
        color = colors.green
    elseif tps >= 15.0 then
        status = "Good"
        color = colors.yellow
    elseif tps >= 10.0 then
        status = "Fair"
        color = colors.orange
    else
        status = "Poor"
        color = colors.red
    end

    monitor.setCursorPos(1, 5)
    monitor.write("Status: " .. status)

    -- Draw the horizontal bar to visually represent TPS
    local barWidth = 30 -- Adjust the width to fit your monitor size
    local x, y = 2, 7 -- Starting position of the bar
    local percentage = math.min(tps / 20, 1)
    drawHorizontalBar(x, y, barWidth, percentage, color)
end

-- Function to fetch TPS
local function getTPS()
    local tps = commands.exec("/forge tps")
    if tps then
        local line = tps[2] -- Adjust this index if needed to capture the correct line
        local extractedTPS = line:match("Overall: (%d+%.?%d*)")
        return tonumber(extractedTPS) or 0
    end
    return 0
end

-- Main loop
while true do
    local tps = getTPS()
    displayTPS(tps)
    sleep(updateInterval)
end
