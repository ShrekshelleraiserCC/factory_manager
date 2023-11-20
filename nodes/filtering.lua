local lib = require "manager_lib"

local node__index = setmetatable({}, lib.node_meta)


---@diagnostic disable-next-line: duplicate-set-field
function node__index:transfer(connector, packet)
    if not self.filter_func then
        return
    end
    if connector ~= self.input_connector then
        return
    end
    if self.filter_func(packet) then
        lib.send_packet_to_link(self.true_connector, packet)
    else
        lib.send_packet_to_link(self.false_connector, packet)
    end
end

---@class FilteringNode : Node
---@field input_connector Connector
---@field true_connector Connector
---@field false_connector Connector
---@field filter string?
---@field filter_func function?
---@field arg string?

---Create a node to filter packets
---@return FilteringNode
local function new_filtering_node()
    local node = lib.new_node() --[[@as FilteringNode]]
    node.locked = true
    node.node_type = "filtering"
    setmetatable(node, { __index = node__index })
    local input_connector = lib.new_connector()
    node:add_input(input_connector)
    node.input_connector = input_connector

    local true_connector = lib.new_connector()
    true_connector.label = "TRUE"
    node:add_output(true_connector)
    node.true_connector = true_connector
    local false_connector = lib.new_connector()
    false_connector.label = "FALSE"
    node:add_output(false_connector)
    node.false_connector = false_connector

    return node
end

---@class SerializedFilteringNode : FilteringNode
---@field input_connector string
---@field true_connector string
---@field false_connector string

---@param node FilteringNode
local function load_filter(node)
    if node.filter then
        local f = fs.open(node.filter, "r")
        if not f then return end
        local t = f.readAll() --[[@as string]]
        f.close()
        node.filter_func = load(t)(node.arg)
    end
end

---@param node FilteringNode
local function serialize(node)
    node = node --[[@as SerializedFilteringNode]]
    node.input_connector = node.input_connector.id
    node.true_connector = node.true_connector.id
    node.false_connector = node.false_connector.id
    node.filter_func = nil
end

local function unserialize(node)
    node.input_connector = node.inputs[1]
    node.true_connector = node.outputs[1]
    node.false_connector = node.outputs[2]
    setmetatable(node, { __index = node__index })
    load_filter(node)
end

local configurable_fields = {
    type = {
        type = "con_type",
    },
    filter = {
        type = "file",
        description = "File returning a filter function of fun(packet):boolean"
    },
    arg = {
        type = "string",
        description = "Argument passed into function file when loaded"
    }
}

---@param node FilteringNode
---@param key string
---@param value any
local function set_field(node, key, value)
    if key == "type" then
        value                         = value or "DEFAULT"
        local color                   = lib.get_connector(value).color
        node.input_connector.color    = color
        node.false_connector.color    = color
        node.true_connector.color     = color
        node.input_connector.con_type = value
        node.false_connector.con_type = value
        node.true_connector.con_type  = value
        lib.unlink(node.inputs)
        lib.unlink(node.outputs)
    elseif key == "filter" then
        node.filter = value
        load_filter(node)
    elseif key == "arg" then
        node.arg = value
        load_filter(node)
    else
        error(("Attempt to set field %s on filtering node."):format(key))
    end
end

lib.register_node("filtering", new_filtering_node, serialize, unserialize, configurable_fields, set_field)
