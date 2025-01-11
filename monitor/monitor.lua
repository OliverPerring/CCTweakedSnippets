-- Open rednet on the "bottom" side
rednet.open("bottom")

-- Initialize the advanced monitor
local monitor = peripheral.wrap("right") -- Change "right" to the side your monitor is connected to
monitor.setTextScale(1) -- Adjust text size as needed
monitor.clear()

-- Function to draw a graphical border using paintutils
local function drawBorder()
    local width, height = monitor.getSize()
    monitor.clear()

    -- Draw the border rectangle
    paintutils.drawBox(1, 1, width, height, colors.gray)

    -- Fill the inside with a different color for contrast
    paintutils.drawFilledBox(2, 2, width - 1, height - 1, colors.black)

    -- Add a title at the top center
    local title = " Monitoring System "
    monitor.setCursorPos(math.floor((width - #title) / 2) + 1, 1)
    monitor.setBackgroundColor(colors.gray)
    monitor.setTextColor(colors.white)
    monitor.write(title)
    monitor.setBackgroundColor(colors.black) -- Reset background
    monitor.setTextColor(colors.white) -- Reset text color
end

-- Function to display messages inside the border
local messages = {}
local function displayMessages()
    local width, height = monitor.getSize()
    local messageYStart = 3 -- Start below the title and border

    drawBorder()

    -- Print messages within the bordered area
    for i = #messages, math.max(#messages - (height - 3), 1), -1 do
        local message = messages[i]
        monitor.setCursorPos(3, messageYStart) -- Start inside the border
        monitor.write(message)
        messageYStart = messageYStart + 1
        if messageYStart >= height then
            break
        end
    end
end

-- Main loop to receive messages and update the monitor
while true do
    local senderID, message = rednet.receive("monitoring")
    local formattedMessage = "From " .. senderID .. ": " .. tostring(message)

    -- Add the new message to the list
    table.insert(messages, formattedMessage)

    -- Remove oldest messages if exceeding the monitor's height
    local _, height = monitor.getSize()
    if #messages > (height - 3) then
        table.remove(messages, 1)
    end

    -- Update the monitor display
    displayMessages()

    -- Also print the message to the console
    print(formattedMessage)
end
