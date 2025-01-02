local lib = require "libs.manager_data"

---@class InventoryConnector : Connector
---@field con_type "inventory"
---@field inventory string?
---@field mode "first"|"all"?
local inv_con__index = setmetatable({}, lib.con_meta)
---@class InvPacket : Packet
---@field inventory string
---@field slot integer
---@field item table?


---Pass an inventory into this input connector
---@param packet InvPacket
function inv_con__index:recieve_packet(packet)
    if not self.inventory then return end
    peripheral.call(self.inventory, "pullItems", packet.inventory, packet.slot)
end

---Iterate over all items and pass them along to the attached connector
function inv_con__index:tick()
    if not (self.link_parent and self.link) then
        return
    end
    if not self.inventory then
        return
    end
    local func = {}
    local listing = peripheral.call(self.inventory, "list")
    if self.mode == "first" then
        -- only send the first availble
        local slot = 1
        if next(listing) then
            while not listing[slot] do
                slot = slot + 1
            end
        end
        if listing[slot] then
            func[1] = function()
                lib.send_packet_to_link(self, { inventory = self.inventory, slot = slot, item = listing[slot] })
            end
        end
    else
        for slot, item in pairs(listing) do
            func[#func + 1] = function()
                lib.send_packet_to_link(self, { inventory = self.inventory, slot = slot, item = item })
            end
        end
    end
    return func
end

local inv_con_meta = { __index = inv_con__index }

---Create a new inventory connector
---@return InventoryConnector
local function new_inventory_connector()
    local con = lib.new_connector() --[[@as InventoryConnector]]
    con.con_type = "inventory"
    con.color = colors.green
    return setmetatable(con, inv_con_meta)
end

local function serialize(con)

end

local function unserialize(con)
    setmetatable(con, inv_con_meta)
end

local configurable_fields = {
    inventory = {
        type = "peripheral",
        peripheral = { "inventory" }
    },
    mode = {
        type = { "all", "first" },
        description = "How to transmit items from this inventory"
    }
}

local function set_field(con, key, value)
    if key == "inventory" then
        con.inventory = value
    elseif key == "mode" then
        con.mode = value
    else
        error(("Attempt to set field %s on inventory."):format(key))
    end
end

lib.register_connector("inventory", new_inventory_connector, serialize, unserialize, configurable_fields, set_field,
    colors.green)
