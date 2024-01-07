local arg = ({ ... })[1]
return "inventory", 5, function(packet)
    return packet.item.name == arg
end
