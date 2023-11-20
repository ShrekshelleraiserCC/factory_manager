local lib = require "manager_lib"


term.setCursorPos(1, 2)

require("connectors.inventory")
require("connectors.redstone")
require("nodes.filtering")

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
