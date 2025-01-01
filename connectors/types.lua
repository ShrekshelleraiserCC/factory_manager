local lib = require "manager_lib"

---@class NumberConnector : Connector
---@field con_type "number"
local number_con__index = setmetatable({}, lib.con_meta)
---@class NumberPacket : Packet
---@field value number



---@param packet NumberPacket
function number_con__index:recieve_packet(packet)
end

function number_con__index:tick()
end

local number_con_meta = { __index = number_con__index }

local function new_connector_factory(type, color)
    return function()
        local con = lib.new_connector() --[[@as NumberConnector]]
        con.con_type = type
        con.color = color
        return setmetatable(con, number_con_meta)
    end
end
---Create a new number connector
---@return NumberConnector

local function serialize(con)

end

local function unserialize(con)
    setmetatable(con, number_con_meta)
end

local function register_connector(con_type, color, char)
    lib.register_connector(con_type, new_connector_factory(con_type, color), serialize, unserialize, nil, nil,
        color, char)
end

register_connector("number", colors.blue, "#")
register_connector("string", colors.lime, "\"")
register_connector("boolean", colors.lime, "?")
