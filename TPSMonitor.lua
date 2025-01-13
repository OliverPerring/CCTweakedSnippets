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

-- Function to display TPS
local function displayTPS(tps)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("Minecraft TPS Monitor")
    monitor.setCursorPos(1, 3)
    monitor.write("Current TPS: " .. string.format("%.2f", tps))

    if tps >= 19.0 then
        monitor.setCursorPos(1, 5)
        monitor.write("Status: Excellent")
    elseif tps >= 15.0 then
        monitor.setCursorPos(1, 5)
        monitor.write("Status: Good")
    elseif tps >= 10.0 then
        monitor.setCursorPos(1, 5)
        monitor.write("Status: Fair")
    else
        monitor.setCursorPos(1, 5)
        monitor.write("Status: Poor")
    end
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
