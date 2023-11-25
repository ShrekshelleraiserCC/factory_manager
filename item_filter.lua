local arg = ({ ... })[1]
return "inventory", function(packet)
    return packet.item.name == arg
end
