local lib = require "manager_lib"

local node__index = setmetatable({}, lib.node_meta)

-- Not really sure what state this is in. And I don't have time to test it at the moment.
-- Use at your own risk.

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

---@class RoutingNode : Node
---@field router string?
---@field router_func function?
---@field arg string?
---@field max_output integer
---@field connector_type string?

---@param node RoutingNode
local function protected_unlink(node)
    local old_number_con = node.outputs[#node.outputs]
    node.outputs[#node.outputs] = nil
    lib.unlink(node.outputs)
    node.outputs[#node.outputs + 1] = old_number_con
    node:update_size()
end

local function set_type(node, value, bypass)
    value = value or "DEFAULT"
    if value == node.inputs[1].con_type and not bypass then
        return
    end
    local color = lib.get_connector(value).color
    for i = 1, node.max_output do
        node.outputs[i].con_type = value
        node.outputs[i].color    = color
    end
    node.inputs[1].color    = color
    node.inputs[1].con_type = value
    node.conector_type      = value
    lib.unlink(node.inputs)
    protected_unlink(node)
end

---@param node RoutingNode
local function generate_outputs(node)
    if node.max_output == (#node.outputs - 1) then
        return
    end
    local old_number_con = node.outputs[#node.outputs]
    node.outputs[#node.outputs] = nil
    lib.unlink(node.outputs)
    for i = 1, node.max_output do
        local con = lib.new_connector()
        node:add_output(con)
        con.label = tostring(i)
    end
    node.outputs[#node.outputs + 1] = old_number_con
    set_type(node, node.connector_type, true)
end

---@param node RoutingNode
local function load_router(node)
    if node.router then
        local f = fs.open(node.router, "r")
        if not f then
            node.max_output = 0
            return
        end
        local t = f.readAll() --[[@as string]]
        f.close()
        local type, max_output, router_func = load(t)(node.arg)
        term.setCursorPos(1, 1)
        node.router_func = router_func
        node.connector_type = type
        generate_outputs(node)
        node.max_output = max_output
    else
        node.max_output = 0
    end
end

---Create a node to filter packets
---@return RoutingNode
local function new_routing_node()
    local node = lib.new_node() --[[@as RoutingNode]]
    node.locked = true
    node.node_type = "routing"
    setmetatable(node, { __index = node__index })
    local input_connector = lib.new_connector()
    node:add_input(input_connector)

    local num_output = lib.get_connector("number").new()
    node:add_output(num_output)

    load_router(node)
    generate_outputs(node)
    return node
end

---@class SerializedRoutingNode : RoutingNode


---@param node RoutingNode
local function serialize(node)
    node = node --[[@as SerializedRoutingNode]]
    node.router_func = nil
end

local function unserialize(node)
    setmetatable(node, { __index = node__index })
    load_router(node)
end

local configurable_fields = {
    router = {
        type = "file",
        description = "File returning con_type,max_output,fun(packet):boolean"
    },
    arg = {
        type = "string",
        description = "Argument passed into function file when loaded"
    }
}

---@param node RoutingNode
---@param key string
---@param value any
local function set_field(node, key, value)
    if key == "router" then
        node.router = value
        load_router(node)
    elseif key == "arg" then
        node.arg = value
        load_router(node)
    else
        error(("Attempt to set field %s on routing node."):format(key))
    end
end

lib.register_node("routing", new_routing_node, serialize, unserialize, configurable_fields, set_field)
