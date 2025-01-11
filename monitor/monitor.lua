rednet.open("bottom")
while true do
    local senderID, message = rednet.receive("monitoring")
    print("Received from: " .. senderID .. " - Message: " .. tostring(message))
end
