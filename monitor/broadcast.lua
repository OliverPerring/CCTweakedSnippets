local moduleName = "Your Module Name Here" -- Replace with the desired module name

function broadcastStatus(message)
    rednet.open("bottom")
    local time = os.time()
    rednet.broadcast("[" .. textutils.formatTime(time, true) .. "] " .. message, "monitoring")
    print("Broadcasted: [" .. textutils.formatTime(time, true) .. "] " .. message)
end

broadcastStatus("Module Loaded [" .. moduleName .. "]")
