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

---Create a new number connector
---@return NumberConnector
local function new_number_connector()
    local con = lib.new_connector() --[[@as NumberConnector]]
    con.con_type = "number"
    con.color = colors.lime
    con.char = "#"
    return setmetatable(con, number_con_meta)
end

local function serialize(con)

end

local function unserialize(con)
    setmetatable(con, number_con_meta)
end

lib.register_connector("number", new_number_connector, serialize, unserialize, nil, nil, colors.lime)
