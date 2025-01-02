local manager_data = require("libs.manager_data")
local manager_view = require("libs.manager_view")
local disp_context = require("libs.disp_context")
local nodes_win = disp_context.nodes_win
---@class Node
local node__index = manager_data.node__index




---Start a connection
---@param node Node
---@param connector Connector
---@param x integer
---@param y integer
local function start_connection(node, connector, x, y)
    if connector.link then
        connector.link:unlink()
        connector:unlink()
    end
    disp_context.connecting = true
    disp_context.connection_connector = connector
    local wx, wy = nodes_win.getPosition()
    disp_context.connection_sx, disp_context.connection_sy = x - wx + 1, y - wy + 1
    disp_context.connection_dx = disp_context.connection_sx
    disp_context.connection_dy = disp_context.connection_sy
end

---Finish a connection
---@param node Node?
---@param connector Connector?
local function connection_end(node, connector)
    disp_context.connecting = false
    if node and connector then
        connector:unlink()
        disp_context.connection_connector:set_link(node, connector)
    end
end

---Provide x,y in screen space
---@param b integer
---@param x integer
---@param y integer
function node__index:mouse_click(b, x, y)
    x, y = self:screen_pos_to_local(x, y)
    if x == 1 then
        -- on the left side
        for k, v in ipairs(self.inputs) do
            if v.y > y then break end
            if y == v.y then
                disp_context.last_selected = v
                return true
            end
        end
    elseif x == self.w then
        -- on the right side
        for k, v in ipairs(self.outputs) do
            if v.y > y then break end
            if y == v.y then
                disp_context.last_selected = v
                return true
            end
        end
    end
    if y > 0 and y <= self.h and x > 0 and x <= self.w then
        local wx, wy               = nodes_win.getPosition()
        self.drag_x                = x + wx - 1
        self.drag_y                = y + wy - 1
        self.dragging              = true
        disp_context.last_selected = self
        return true
    end
end

---Provide x,y in screen space
---@param b integer
---@param x integer
---@param y integer
function node__index:mouse_up(b, x, y)
    x, y = self:screen_pos_to_local(x, y)
    if self.dragging then
        self.dragging = false
        self:update_window()
    end
    if disp_context.connecting and x == 1 then
        -- on the left side
        for k, v in ipairs(self.inputs) do
            if v.y > y then break end
            if y == v.y and v.con_type == disp_context.connection_connector.con_type then
                connection_end(self, v)
                return true
            end
        end
    end
end

---Provide x,y in screen space
---@param b integer
---@param x integer
---@param y integer
function node__index:mouse_drag(b, x, y)
    if self.dragging then
        self.x = x - disp_context.root_x - self.drag_x + 1
        self.y = y - disp_context.root_y - self.drag_y + 1
        self:update_window()
        return true
    end
end

local function render_connection()
    manager_view.render_connection()
end

return {
    start_connection = start_connection,
    render_connection = render_connection
}
