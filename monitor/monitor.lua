-- Open rednet on the "bottom" side
rednet.open("bottom")

-- Initialize the monitor
local monitor = peripheral.wrap("top") -- Change "right" to the side your monitor is connected to
monitor.setTextScale(1) -- Adjust text size as needed
monitor.clear()
monitor.setCursorPos(1, 1)

-- Function to display messages on the monitor
local messages = {}
local maxMessages = 10 -- Adjust based on the size of your monitor

local function displayMessages()
    monitor.clear()
    monitor.setCursorPos(1, 1)
    for _, message in ipairs(messages) do
        monitor.write(message)
        local x, y = monitor.getCursorPos()
        monitor.setCursorPos(1, y + 1)
    end
end

-- Main loop to receive messages and update the monitor
while true do
    local senderID, message = rednet.receive("monitoring")
    local time = textutils.formatTime(os.time(), true)
    local formattedMessage = "[" .. time .. "] " .. tostring(message)

    -- Add the new message to the list
    table.insert(messages, "From " .. senderID .. ": " .. formattedMessage)

    -- Remove oldest messages if exceeding maxMessages
    if #messages > maxMessages then
        table.remove(messages, 1)
    end

    -- Update the monitor display
    displayMessages()

    -- Also print the message to the console
    print(formattedMessage)
end
