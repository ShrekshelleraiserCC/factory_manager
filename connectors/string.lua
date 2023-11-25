local lib = require "manager_lib"

---@class StringConnector : Connector
---@field con_type "string"
local string_con__index = setmetatable({}, lib.con_meta)
---@class StringPacket : Packet
---@field value string

---@param packet StringPacket
function string_con__index:recieve_packet(packet)
end

function string_con__index:tick()
end

local string_con_meta = { __index = string_con__index }

---Create a new string connector
---@return StringConnector
local function new_number_connector()
    local con = lib.new_connector() --[[@as StringConnector]]
    con.con_type = "string"
    con.color = colors.lime
    con.char = "\""
    return setmetatable(con, string_con_meta)
end

local function serialize(con)

end

local function unserialize(con)
    setmetatable(con, string_con_meta)
end

lib.register_connector("string", new_number_connector, serialize, unserialize, nil, nil, colors.lime)
