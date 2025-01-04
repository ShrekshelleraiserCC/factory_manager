local lib = require "libs.manager_data"
---@class ModemConnector : Connector
---@field con_type "modem"
---@field port integer?
---@field peripheral string?
---@field message_queue ModemPacket[]
local modem_con__index = setmetatable({}, lib.con_meta)
---@class ModemPacket : Packet
---@field peripheral string
---@field port integer
---@field reply_port integer
---@field distance integer
---@field message any

local modem_con_meta = { __index = modem_con__index }

---Pass redstone into this connector
---@param packet ModemPacket
function modem_con__index:recieve_packet(packet)
    if self.peripheral then
        peripheral.call(self.peripheral, "transmit", self.port or packet.reply_port, self.reply_port or packet.port,
            packet.message)
    end
end

function modem_con__index:tick()
    return {
        function()
            for _, v in ipairs(self.message_queue) do
                lib.send_packet_to_link(self, v)
            end
            self.message_queue = {}
        end
    }
end

function modem_con__index:on_event(e)
    if e[1] == "modem_message" and e[2] == self.peripheral and e[3] == self.port then
        self.message_queue[#self.message_queue + 1] = {
            peripheral = e[2],
            port = e[3],
            reply_port = e[4],
            message = e[5],
            distance = e[6],
        }
    end
end

local function close(con)
    if con.peripheral and con.port then
        peripheral.call(con.peripheral, "close", con.port)
    end
end

local function open(con)
    if con.peripheral and con.port then
        peripheral.call(con.peripheral, "open", con.port)
    end
end

local function serialize(con)
    con.message_queue = {}
    close(con)
end

local function unserialize(con)
    setmetatable(con, modem_con_meta)
    open(con)
end

---Create a new redstone connector
---@return ModemConnector
local function new_modem_connector()
    ---@type ModemConnector
    local con = lib.new_connector() --[[@as ModemConnector]]
    con.con_type = "modem"
    con.color = colors.yellow
    con.message_queue = {}
    return setmetatable(con, modem_con_meta)
end

local configurable_fields = {
    port = {
        type = "number",
    },
    reply_port = {
        type = "number",
    },
    peripheral = {
        type = "peripheral",
        peripheral = { "modem" },
    }
}

local function set_field(con, key, value)
    if key == "port" then
        close(con)
        con.port = value
        open(con)
    elseif key == "reply_port" then
        con.reply_port = value
    elseif key == "peripheral" then
        close(con)
        con.peripheral = value
        open(con)
    else
        error(("Attempt to set field %s on modem."):format(key))
    end
end

lib.register_packet("modem", colors.yellow)
lib.register_connector("modem", "modem", new_modem_connector, serialize, unserialize, configurable_fields, set_field)
