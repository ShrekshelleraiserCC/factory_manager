local lib = require "manager_lib"


term.setCursorPos(1, 2)

local connector_files = fs.list("connectors")
for _, f in ipairs(connector_files) do
    require("connectors." .. f:match("^(%a+)%.lua$"))
end
local node_files = fs.list("nodes")
for _, f in ipairs(node_files) do
    require("nodes." .. f:match("^([%a_]+)%.lua$"))
end

local args = { ... }
if args[1] then
    local f = fs.open(args[1], "r")
    if f then
        local t = f.readAll()
        f.close()
        if t then
            lib.unserialize(t)
        end
    end
end


lib.start()
