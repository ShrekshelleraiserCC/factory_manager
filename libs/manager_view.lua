local disp_context = require("libs.disp_context")
local manager_data = require("libs.manager_data")
local registered_connectors = manager_data.registered_connectors
local nodes_win = disp_context.nodes_win
local box = disp_context.box
local d = require("draw")
local line_func = require("libs.line_func")


local show_packets = true -- TODO swap this out


local function render_connection()
    if disp_context.connecting then
        line_func(disp_context.connection_sx, disp_context.connection_sy, disp_context.connection_dx,
            disp_context.connection_dy)
    end
end

local function render_nodes_start(nodes)
    d.set_col(colors.white, colors.black)
    nodes_win.clear()
    box:clear(colors.black)
    for k, v in pairs(nodes) do
        v:draw_lines()
    end
end

---@param nodes NodeT
local function render_nodes_content(nodes)
    for k, v in pairs(nodes) do
        v:draw()
    end
end

local function render_box()
    box:render()
end

---@class Node
local node__index = manager_data.node__index
---@param x integer
---@param y integer
---@return integer
---@return integer
function node__index:local_pos_to_screen(x, y)
    local wx, wy = nodes_win.getPosition()
    return x + self.x - 2 + disp_context.root_x + wx, y + self.y - 2 + disp_context.root_y + wy
end

---@param x integer
---@param y integer
---@return integer
---@return integer
function node__index:screen_pos_to_local(x, y)
    local wx, wy = nodes_win.getPosition()
    return x - self.x + 2 - disp_context.root_x - wx, y - self.y + 2 - disp_context.root_y - wy
end

function node__index:update_window()
    self.window.reposition(disp_context.root_x + self.x, disp_context.root_y + self.y, self.w, self.h)
end

---Get a connector's position in screen space
---@param con Connector
function node__index:get_con_root_pos(con)
    return self.x + disp_context.root_x, self.y + con.y - 1 + disp_context.root_y
end

---Draw the node lines
function node__index:draw_lines()
    for k, v in pairs(self.outputs) do
        if v.link then
            if v.sent_a_packet and show_packets then
                d.set_col(colors.orange, nil, nodes_win)
            else
                d.set_col(v.color or colors.white, nil, nodes_win)
            end
            line_func(
                self.x + self.w + disp_context.root_x,
                self.y + v.y - 1 + disp_context.root_y,
                v.link_parent.x + disp_context.root_x - 1,
                v.link.parent.y + v.link.y + disp_context.root_y - 1
            )
        end
    end
    d.set_col(colors.white, nil, nodes_win)
end

---@param node Node
---@param connectors Connector[]
---@param side "right"|"left"
local function draw_connectors(node, connectors, side)
    for k, v in pairs(connectors) do
        local def_icon = registered_connectors[v.con_type].char or "\007"
        local icon = (disp_context.last_selected == v and not node.locked and "\127") or def_icon
        if disp_context.last_selected == v and node.locked then
            d.set_col(colors.white, colors.black, node.window)
            node.window.setCursorPos(1, 1)
            node.window.write("\127")
        end
        if v.sent_a_packet and show_packets then
            d.set_col(colors.orange, nil, node.window)
            icon = "!"
        else
            d.set_col(v.color or colors.white, nil, node.window)
        end
        if side == "left" then
            d.invert(node.window)
        end
        local str, x
        if side == "right" then
            str = ("%s%s"):format(v.label or "", icon)
            x = node.w - #str + 1
        else
            str = ("%s%s"):format(icon, v.label or "")
            x = 1
        end
        d.text(x, v.y, str, node.window)
        if side == "left" then
            d.invert(node.window)
        end
    end
end

--- Draw the node contents from scratch
function node__index:draw()
    self.window.setVisible(false)
    self.window.clear()
    d.square(1, 1, self.w, self.h, self.window)
    if disp_context.last_selected == self then
        self.window.setCursorPos(1, 1)
        self.window.write("\127")
    end
    d.text(2, 2, self.label or "", self.window)
    draw_connectors(self, self.inputs, "left")
    draw_connectors(self, self.outputs, "right")
    d.set_col(colors.white, nil, self.window)
    self.window.setVisible(true)
end

return {
    render_nodes_content = render_nodes_content,
    render_nodes_start = render_nodes_start,
    render_connection = render_connection,
    render_box = render_box
}
