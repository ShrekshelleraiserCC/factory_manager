local lib = require "libs.manager_data"

local node__index = setmetatable({}, lib.node_meta)


---@diagnostic disable-next-line: duplicate-set-field
function node__index:transfer(connector, packet)
    if not self.filter_func then
        return
    end
    if connector ~= self.inputs[1] then
        return
    end
    local state = self.filter_func(packet)
    if state then
        lib.send_packet_to_link(self.outputs[1], packet)
    else
        lib.send_packet_to_link(self.outputs[2], packet)
    end
    lib.send_packet_to_link(self.outputs[3], { value = state })
end

---@class FilteringNode : Node
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

    local true_connector = lib.new_connector()
    true_connector.label = "TRUE"
    node:add_output(true_connector)

    local false_connector = lib.new_connector()
    false_connector.label = "FALSE"
    node:add_output(false_connector)

    local bool_output = lib.get_connector("boolean").new()
    node:add_output(bool_output)

    return node
end

---@class SerializedFilteringNode : FilteringNode

local function set_type(node, value)
    value = value or "DEFAULT"
    if value == node.inputs[1].con_type then
        return
    end
    node.inputs[1].con_type  = value
    node.outputs[2].con_type = value
    node.outputs[1].con_type = value
    lib.unlink(node.inputs)
    lib.unlink(node.outputs)
end

---@param node FilteringNode
local function load_filter(node)
    if node.filter then
        local f = fs.open(node.filter, "r")
        if not f then return end
        local t = f.readAll() --[[@as string]]
        f.close()
        local type, filter_func = load(t)(node.arg)
        term.setCursorPos(1, 1)
        node.filter_func = filter_func
        set_type(node, type)
    end
end

---@param node FilteringNode
local function serialize(node)
    node = node --[[@as SerializedFilteringNode]]
    node.filter_func = nil
end

local function unserialize(node)
    setmetatable(node, { __index = node__index })
    load_filter(node)
end

local configurable_fields = {
    filter = {
        type = "file",
        description = "File returning node_type,fun(packet):boolean"
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
    if key == "filter" then
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
