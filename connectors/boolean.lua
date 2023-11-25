local lib = require "manager_lib"

---@class BooleanConnector : Connector
---@field con_type "boolean"
local bool_con__index = setmetatable({}, lib.con_meta)
---@class BoolPacket : Packet
---@field value boolean


---@param packet BoolPacket
function bool_con__index:recieve_packet(packet)
end

function bool_con__index:tick()
end

local bool_con_meta = { __index = bool_con__index }

---Create a new boolean connector
---@return BooleanConnector
local function new_boolean_connector()
    local con = lib.new_connector() --[[@as BooleanConnector]]
    con.con_type = "boolean"
    con.color = colors.lime
    con.char = "?"
    return setmetatable(con, bool_con_meta)
end

local function serialize(con)

end

local function unserialize(con)
    setmetatable(con, bool_con_meta)
end

lib.register_connector("boolean", new_boolean_connector, serialize, unserialize, nil, nil, colors.lime)
