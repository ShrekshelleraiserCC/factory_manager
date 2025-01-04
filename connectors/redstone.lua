local lib = require "libs.manager_data"
---@class RedstoneConnector : Connector
---@field type "redstone"
---@field side string?
---@field peripheral string?
---@field last_level integer?
---@field mode "always"|"on_change"?
local redstone_con__index = setmetatable({}, lib.con_meta)
---@class RedstonePacket : Packet
---@field level integer

local redstone_con_meta = { __index = redstone_con__index }

---Pass redstone into this connector
---@param packet RedstonePacket
function redstone_con__index:recieve_packet(packet)
    if not self.peripheral and self.side then
        redstone.setAnalogOutput(self.side, packet.level)
        return
    end
    if self.side then
        peripheral.call(self.peripheral, "setAnalogOutput", self.side, packet.level)
    end
end

function redstone_con__index:tick()
    return {
        function()
            local level
            if not self.peripheral and self.side then
                level = redstone.getAnalogInput(self.side)
            elseif self.side then
                level = peripheral.call(self.peripheral, "getAnalogInput", self.side)
            end
            if level ~= self.last_level or self.mode == "always" then
                lib.send_packet_to_link(self, { level = level })
                self.last_level = level
            end
        end
    }
end

---Create a new redstone connector
---@return RedstoneConnector
local function new_redstone_connector()
    ---@type RedstoneConnector
    local con = lib.new_connector() --[[@as RedstoneConnector]]
    con.con_type = "redstone"
    return setmetatable(con, redstone_con_meta)
end

local configurable_fields = {
    side = {
        type = "string",
    },
    peripheral = {
        type = "peripheral",
        peripheral = { "redstoneIntegrator" },
        description = "Optional peripheral for redstone I/O"
    },
    mode = {
        type = { "always", "on_change" },
        description = "When to send redstone packets"
    }
}

local function set_field(con, key, value)
    if key == "side" then
        con.side = value
    elseif key == "peripheral" then
        con.peripheral = value
    elseif key == "mode" then
        con.mode = value
    else
        error(("Attempt to set field %s on redstone."):format(key))
    end
end

lib.register_packet("redstone", colors.red)
lib.register_connector("redstone", "redstone", new_redstone_connector):set_config(configurable_fields, set_field)
    :set_default_unserializer(redstone_con_meta)
