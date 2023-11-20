local arg = ({ ... })[1]
return function(packet)
    return packet.item.name == arg
end
