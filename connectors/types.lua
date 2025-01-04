local lib = require "libs.manager_data"

---@class NumberConnector : Connector
---@field con_type "number"
local data_con__index = setmetatable({}, lib.con_meta)
---@class DataPacket<T>:{["value"]:T}

---@generic T
---@param packet DataPacket<T>
function data_con__index:recieve_packet(packet)
    self.value = packet.value
end

local data_con_meta = { __index = data_con__index }

local function new_connector_factory(type, color)
    return function()
        local con = lib.new_connector() --[[@as NumberConnector]]
        con.con_type = type
        return setmetatable(con, data_con_meta)
    end
end

---@param sent_color color?
---@param sent_icon string?
---@param on_render packetRenderCallback?
local function register_connector(con_type, color, char, sent_color, sent_icon, on_render)
    lib.register_packet(con_type, color, char, sent_color, sent_icon, on_render)
    lib.register_connector(con_type, con_type, new_connector_factory(con_type, color))
        :set_default_unserializer(data_con_meta)
end

register_connector("number", colors.blue, "#")
register_connector("string", colors.lime, "\"")
register_connector("boolean", colors.lime, "?", nil, nil, function(con)
    local col = con.value and colors.lime or colors.gray
    return col, "?"
end)
