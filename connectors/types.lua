local lib = require "libs.manager_data"

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

---@class BooleanConnector : Connector
---@field con_type "boolean"
---@field value boolean
local boolean_con__index = setmetatable({}, lib.con_meta)
---@class BooleanPacket : Packet
---@field value boolean

---@param packet BooleanPacket
function boolean_con__index:recieve_packet(packet)
    self.value = packet.value
end

function boolean_con__index:tick()
end

local boolean_con_meta = { __index = boolean_con__index }

local function new_connector_factory(type, color)
    return function()
        local con = lib.new_connector() --[[@as NumberConnector]]
        con.con_type = type
        con.color = color
        if type == "boolean" then
            return setmetatable(con, boolean_con_meta)
        end
        return setmetatable(con, number_con_meta)
    end
end
---Create a new number connector
---@return NumberConnector

local function serialize(con)

end

local function unserialize(con)
    if con.con_type == "boolean" then
        setmetatable(con, boolean_con_meta)
        return
    end
    setmetatable(con, number_con_meta)
end

---@param sent_color color?
---@param sent_icon string?
---@param on_render packetRenderCallback?
local function register_connector(con_type, color, char, sent_color, sent_icon, on_render)
    lib.register_packet(con_type, color, char, sent_color, sent_icon, on_render)
    lib.register_connector(con_type, con_type, new_connector_factory(con_type, color), serialize, unserialize)
end

register_connector("number", colors.blue, "#")
register_connector("string", colors.lime, "\"")
register_connector("boolean", colors.lime, "?", nil, nil, function(con)
    local col = con.value and colors.lime or colors.gray
    return col, "?"
end)
