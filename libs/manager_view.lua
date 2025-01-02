local disp_context = require("libs.disp_context")
local nodes_win = disp_context.nodes_win
local box = disp_context.box
local d = require("draw")
local line_func = require("libs.line_func")

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

return {
    render_nodes_content = render_nodes_content,
    render_nodes_start = render_nodes_start,
    render_connection = render_connection,
    render_box = render_box
}
