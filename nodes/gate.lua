local lib = require "libs.manager_data"

local node__index = setmetatable({}, lib.node_meta)

---@param self GateNode
---@diagnostic disable-next-line: duplicate-set-field
function node__index:transfer(connector, packet)
    if connector == self.inputs[2] then
        self.active = packet.value
        return
    end
    if self.active then
        lib.send_packet_to_link(self.output_connector, packet)
    end
end

local node_meta = { __index = node__index }

---@class GateNode : Node
---@field input_connector Connector
---@field active boolean
---@field output_connector Connector
---@field filter string?
---@field filter_func function?
---@field arg string?

---Create a node to filter packets
---@return GateNode
local function new_gate_node()
    local node = lib.new_node() --[[@as GateNode]]
    node.locked = true
    node.node_type = "gate"
    node.active = false
    setmetatable(node, node_meta)
    local input_connector = lib.new_connector()
    node:add_input(input_connector)
    node.input_connector = input_connector

    local bool_connector = lib.get_connector("boolean").new()
    node:add_input(bool_connector)

    local true_connector = lib.new_connector()
    node:add_output(true_connector)
    node.output_connector = true_connector

    return node
end

---@class SerializedGateNode : GateNode
---@field input_connector string
---@field output_connector string

local function set_type(node, value)
    value = value or "DEFAULT"
    if value == node.input_connector.con_type then
        return
    end
    local color                    = lib.get_connector(value).color
    node.input_connector.color     = color
    node.output_connector.color    = color
    node.input_connector.con_type  = value
    node.output_connector.con_type = value
    lib.unlink(node.inputs)
    lib.unlink(node.outputs)
end

---@param node GateNode
local function serialize(node)
    node = node --[[@as SerializedGateNode]]
    node.input_connector = node.input_connector.id
    node.output_connector = node.output_connector.id
    node.active = nil
end

local function unserialize(node)
    node.input_connector = node.inputs[1]
    node.output_connector = node.outputs[1]
    setmetatable(node, node_meta)
end

local configurable_fields = {
    con_type = {
        type = "con_type"
    }
}

---@param node FilteringNode
---@param key string
---@param value any
local function set_field(node, key, value)
    if key == "con_type" then
        set_type(node, value)
    else
        error(("Attempt to set field %s on gate node."):format(key))
    end
end

lib.register_node("gate", new_gate_node, serialize, unserialize, configurable_fields, set_field)
