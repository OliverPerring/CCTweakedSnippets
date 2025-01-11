-- Open rednet on the "bottom" side
rednet.open("bottom")

-- Function to broadcast a structured packet
local function broadcastPacket(senderName, messageType, messageBody)
    local packet = {
        sender = senderName,
        type = messageType,
        body = messageBody,
    }
    rednet.broadcast(packet, "monitoring")
    print("Broadcasted packet: ", textutils.serialize(packet))
end

-- Example usage
broadcastPacket("Test1", "Info", "System started")
broadcastPacket("Test2", "Warning", "Power usage has gone negative")
broadcastPacket("Test3", "Error", "System failure detected!")
