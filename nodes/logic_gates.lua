local lib = require "libs.manager_data"

local logic_gate_node__index = setmetatable({}, lib.node_meta)
local logic_gate_meta = { __index = logic_gate_node__index }

---@class LogicGateNode : Node
---@field gate_type string

---@alias LogicGateInfo {func:fun(...:boolean):boolean,number,number}
---@type table<string,LogicGateInfo>
local logic_gate_types = {}

function logic_gate_node__index:tick()
    local info = logic_gate_types[self.gate_type]
    local inputs = {}
    for i = 1, info[2] do
        inputs[i] = not not self.inputs[i].value
    end

    local result = { info[1](table.unpack(inputs, 1, info[2])) }

    for i = 1, info[3] do
        ---@diagnostic disable-next-line: inject-field
        self.outputs[i].value = result[i]
        lib.send_packet_to_link(self.outputs[i], { value = result[i] })
    end
end

local function new_logic_node(registry_name, label)
    local node = lib.new_node() --[[@as LogicGateNode]]
    node.locked = true
    node.node_type = registry_name
    node.gate_type = label
    node.label = label
    local info = logic_gate_types[label]
    local input_count = info[2]
    local output_count = info[3]

    setmetatable(node, logic_gate_meta)
    for i = 1, input_count do
        local input_connector = lib.get_connector("boolean").new()
        node:add_input(input_connector)
    end
    for i = 1, output_count do
        local output_connector = lib.get_connector("boolean").new()
        node:add_output(output_connector)
    end

    return node
end

---@class SerializedLogicGateNode : LogicGateNode

---@param node FilteringNode
local function serialize(node)
    node = node --[[@as SerializedFilteringNode]]
end

local function unserialize(node)
    setmetatable(node, logic_gate_meta)
end

---@param registry_name string
---@param type string
---@param func fun(...:boolean):...:boolean
---@param input_count number
local function register(registry_name, type, func, input_count, output_count)
    logic_gate_types[type] = {
        func,
        input_count,
        output_count or 1
    }
    lib.register_node(registry_name, function()
        return new_logic_node(registry_name, type)
    end, serialize, unserialize)
end



register("logic_and", "AND", function(a, b)
    return a and b
end, 2)
register("logic_or", "OR", function(a, b)
    return a or b
end, 2)
register("logic_xor", "XOR", function(a, b)
    return (a or b) and not (a and b)
end, 2)
register("logic_not", "NOT", function(a)
    return not a
end, 1)
register("logic_split", "SPLIT", function(a)
    return a, a
end, 1, 2)


local switch_node__index = setmetatable({}, lib.node_meta)
local switch_meta = { __index = switch_node__index }

function switch_node__index:mouse_click(b, x, y)
    local sx, sy = self:screen_pos_to_local(x, y)
    if sx == 2 and sy == 3 then
        ---@diagnostic disable-next-line: inject-field
        self.outputs[1].value = not self.outputs[1].value
        lib.send_packet_to_link(self.outputs[1], { value = self.outputs[1].value })
        return true
    end
    return lib.node__index.mouse_click(self, b, x, y)
end

function switch_node__index:draw()
    lib.node__index.draw(self)
    self.window.setCursorPos(2, 3)
    self.window.write("\007")
end

---@class SwitchNode : Node

local function new_switch_node()
    local node = lib.new_node() --[[@as LogicGateNode]]
    node.locked = true
    node.node_type = "switch_node"
    node.label = "Switch"

    setmetatable(node, switch_meta)
    local output_connector = lib.get_connector("boolean").new()
    node:add_output(output_connector)

    return node
end

---@param node FilteringNode
local function serialize_switch(node)
    node = node --[[@as SerializedFilteringNode]]
end

local function unserialize_switch(node)
    setmetatable(node, logic_gate_meta)
end

lib.register_node("switch_node", new_switch_node, serialize_switch, unserialize_switch)
