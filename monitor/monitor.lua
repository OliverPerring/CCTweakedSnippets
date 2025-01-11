-- Open rednet on the "bottom" side
rednet.open("bottom")

-- Initialize the advanced monitor
local monitor = peripheral.wrap("top") -- Adjust to your setup
monitor.setTextScale(1)
monitor.clear()

-- Redirect drawing to the monitor
local function setMonitorRedirect()
    term.redirect(monitor)
end

-- Reset redirection back to the PC
local function resetTerminalRedirect()
    term.redirect(term.native())
end

-- Function to draw a graphical border
local function drawBorder()
    local width, height = monitor.getSize()
    setMonitorRedirect()
    paintutils.drawBox(1, 1, width, height, colors.gray)
    paintutils.drawFilledBox(2, 2, width - 1, height - 1, colors.black)
    term.setCursorPos(math.floor((width - #("Monitoring System")) / 2) + 1, 1)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.write("Monitoring System")
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    resetTerminalRedirect()
end

-- Function to display messages on the monitor
local messages = {}
local function displayMessages()
    local width, height = monitor.getSize()
    local messageYStart = 3 -- Start below the title and border

    drawBorder()
    setMonitorRedirect()
    for i = #messages, math.max(#messages - (height - 3), 1), -1 do
        local message = messages[i]
        term.setCursorPos(3, messageYStart)
        term.write(message)
        messageYStart = messageYStart + 1
        if messageYStart >= height then
            break
        end
    end
    resetTerminalRedirect()
end

-- Main loop to receive and process packets
while true do
    local senderID, packet = rednet.receive("monitoring")

    -- Decode the packet
    if type(packet) == "table" then
        local formattedMessage = "[" .. packet.type .. "] From " .. packet.sender .. ": " .. packet.body
        table.insert(messages, formattedMessage)

        -- Limit the number of messages displayed
        local _, height = monitor.getSize()
        if #messages > (height - 3) then
            table.remove(messages, 1)
        end

        -- Update the monitor
        displayMessages()

        -- Print the message to the console for debugging
        print("Received packet from " .. senderID .. ": " .. textutils.serialize(packet))
    else
        print("Received invalid message from " .. senderID)
    end
end
