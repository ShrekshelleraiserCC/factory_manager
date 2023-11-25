local tw, th = term.getSize()
local nodes_win = window.create(term.current(), 1, 1, tw, th - 1)
local button_win = window.create(term.current(), 1, th, tw, 1)
local gui_win = window.create(term.current(), 1, 1, tw, th)

local d = require "draw"
d.set_default(nodes_win)
local line_func = d.aligned_cubic_line

--- Root coordinate to draw the field in relation to
local root_x = 1
local root_y = 1

---@type boolean Whether the user is currently connecting nodes togther
local connecting = false
---@type Connector
local connection_connector
---@type integer Connecting line source
local connection_sx
---@type integer Connecting line source
local connection_sy

---@type integer Connecting line destination
local connection_dx
---@type integer Connecting line destination
local connection_dy

---@type Node|Connector? Last selected Node or Connector for editing
local last_selected

local function uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

---@class Node Generic Node
---@field label string?
---@field id string
---@field node_type string
---@field inputs Connector[]
---@field outputs Connector[]
---@field window Window
---@field dragging boolean
---@field drag_x integer
---@field drag_y integer
---@field locked boolean? Whether editing the connectors is allowed
---@field x integer
---@field y integer
---@field w integer
---@field h integer
local node__index = {}
local node_meta = { __index = node__index }

---@param x integer
---@param y integer
---@return integer
---@return integer
function node__index:local_pos_to_screen(x, y)
    local wx, wy = nodes_win.getPosition()
    return x + self.x - 2 + root_x + wx, y + self.y - 2 + root_y + wy
end

---@param x integer
---@param y integer
---@return integer
---@return integer
function node__index:screen_pos_to_local(x, y)
    local wx, wy = nodes_win.getPosition()
    return x - self.x + 2 - root_x - wx, y - self.y + 2 - root_y - wy
end

function node__index:update_window()
    self.window.reposition(root_x + self.x, root_y + self.y, self.w, self.h)
end

function node__index:on_event(e)
    for _, con in ipairs(self.inputs) do
        con:on_event(e)
    end
    for _, con in ipairs(self.outputs) do
        con:on_event(e)
    end
end

--- Recalculate width/height and resize the window
function node__index:update_size()
    local w = #(self.label or "") + 2
    local h = 3
    local connection_height = math.max(#self.inputs, #self.outputs)
    if connection_height > 0 then
        h = h + 1
    end
    for i = 1, connection_height do
        local layer_w = 4
        local input, output = self.inputs[i], self.outputs[i]
        if input then
            layer_w = layer_w + #(input.label or "")
            input.y = h
        end
        if output then
            layer_w = layer_w + #(output.label or "")
            output.y = h
        end
        h = h + 2
        w = math.max(w, layer_w)
    end
    self.h = h
    self.w = w
    self:update_window()
end

function node__index:has_con(con)
    for i, v in ipairs(self.outputs) do
        if v == con then
            return true
        end
    end
    for i, v in ipairs(self.outputs) do
        if v == con then
            return true
        end
    end
    return false
end

---@param connections Connector[]
local function validate_connections(connections)
    for i, con in ipairs(connections) do
        if con.link and not con.link_parent:has_con(con.link) then
            -- this link is not valid
            con.link = nil
            con.link_parent = nil
        end
    end
end

--- Remove any invalid connections
function node__index:validate_connections()
    validate_connections(self.inputs)
    validate_connections(self.outputs)
end

---Get a connector's position in screen space
---@param con Connector
function node__index:get_con_root_pos(con)
    return self.x + root_x, self.y + con.y - 1 + root_y
end

---Draw the node lines
function node__index:draw_lines()
    for k, v in pairs(self.outputs) do
        d.set_col(v.color or colors.white, nil, nodes_win)
        if v.link then
            line_func(
                self.x + self.w + root_x,
                self.y + v.y - 1 + root_y,
                v.link_parent.x + root_x - 1,
                v.link.parent.y + v.link.y + root_y - 1,
                nodes_win
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
        local def_icon = v.char or "\007"
        local icon = (last_selected == v and not node.locked and "\127") or def_icon
        if last_selected == v and node.locked then
            d.set_col(colors.white, colors.black, node.window)
            node.window.setCursorPos(1, 1)
            node.window.write("\127")
        end
        d.set_col(v.color or colors.white, nil, node.window)
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
    if last_selected == self then
        self.window.setCursorPos(1, 1)
        self.window.write("\127")
    end
    d.text(2, 2, self.label or "", self.window)
    draw_connectors(self, self.inputs, "left")
    draw_connectors(self, self.outputs, "right")
    d.set_col(colors.white, nil, self.window)
    self.window.setVisible(true)
end

---Add an input connector
---@param con Connector
function node__index:add_input(con)
    con.direction = "input"
    con.parent = self
    self.inputs[#self.inputs + 1] = con
    self:update_size()
end

---Add an output connector
---@param con Connector
function node__index:add_output(con)
    con.direction = "output"
    con.parent = self
    self.outputs[#self.outputs + 1] = con
    self:update_size()
end

---@param connections Connector[]
local function unlink(connections)
    for i, con in ipairs(connections) do
        if con.link then
            con.link.link = nil
            con.link.link_parent = nil
            con.link = nil
            con.link_parent = nil
        end
    end
end

--- Delete all connections to this node
function node__index:unlink()
    unlink(self.inputs)
    unlink(self.outputs)
end

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
    connecting = true
    connection_connector = connector
    local wx, wy = nodes_win.getPosition()
    connection_sx, connection_sy = x - wx + 1, y - wy + 1
    connection_dx = connection_sx
    connection_dy = connection_sy
end

---Finish a connection
---@param node Node?
---@param connector Connector?
local function connection_end(node, connector)
    connecting = false
    if node and connector then
        connector:unlink()
        connection_connector:set_link(node, connector)
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
                last_selected = v
                return true
            end
        end
    elseif x == self.w then
        -- on the right side
        for k, v in ipairs(self.outputs) do
            if v.y > y then break end
            if y == v.y then
                last_selected = v
                return true
            end
        end
    end
    if y > 0 and y <= self.h and x > 0 and x <= self.w then
        local wx, wy  = nodes_win.getPosition()
        self.drag_x   = x + wx - 1
        self.drag_y   = y + wy - 1
        self.dragging = true
        last_selected = self
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
    if connecting and x == 1 then
        -- on the left side
        for k, v in ipairs(self.inputs) do
            if v.y > y then break end
            if y == v.y and v.con_type == connection_connector.con_type then
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
        self.x = x - root_x - self.drag_x + 1
        self.y = y - root_y - self.drag_y + 1
        self:update_window()
        return true
    end
end

local function merge_into(from, to)
    for _, func in ipairs(from) do
        to[#to + 1] = func
    end
end

---Tick all outgoing connections of this node
---@return function[]?
function node__index:tick()
    local funcs = {}
    for _, v in ipairs(self.outputs) do
        local funcs_l = v:tick()
        merge_into(funcs_l or {}, funcs)
    end
    return funcs
end

---@class Packet

--- Transfer data to a connector on this node
---@param connector Connector
---@param packet Packet
function node__index:transfer(connector, packet)
    connector:recieve_packet(packet)
end

---@return Node
local function new_node()
    local cx, cy = -root_x + math.floor(tw / 2), -root_y + math.floor(th / 2)
    ---@type Node
    local node = setmetatable(
        { x = cx, y = cy, inputs = {}, outputs = {}, id = uuid(), node_type = "DEFAULT" },
        node_meta)
    node.window = window.create(nodes_win, node.x, node.y, 1, 1)
    node:update_size()
    return node
end

---@class Connector
---@field link Connector?
---@field link_parent Node?
---@field parent Node
---@field con_type string
---@field direction "input"|"output"
---@field label string?
---@field color color?
---@field y integer
---@field char string?
---@field id string
---@field recieve_packet fun(self:Connector,packet:Packet)
---@field tick fun(self:Connector):function[]? Run on a frequent basis
local con__index = {}

function con__index:unlink()
    if self.link then
        self.link.link = nil
        self.link.link_parent = nil
    end
    self.link = nil
    self.link_parent = nil
end

---@param node Node
---@param con Connector
function con__index:set_link(node, con)
    self.link = con
    self.link_parent = node
    con.link = self
    con.link_parent = self.parent
end

function con__index:on_event(e)

end

---Default no-op
function con__index:tick() end

---Default no-op
function con__index:recieve_packet(packet) end

---Create a new default connector
---@return Connector
local function new_connector()
    local connector = {
        con_type = "DEFAULT",
        id = uuid(),
    }
    return setmetatable(connector, { __index = con__index })
end

local function send_packet_to_link(connector, packet)
    if connector.link and connector.link_parent then
        connector.link_parent:transfer(connector.link, packet)
    end
end

---@return Connector|Node?
local function get_thing_selected_for_editing()
    if not last_selected then
        return
    end
    if last_selected.con_type and not last_selected.parent.locked then
        return last_selected
    end
    if last_selected.con_type then
        return last_selected.parent
    end
    return last_selected
end

---@return string?
local function get_last_selected_label()
    if not last_selected then
        return
    end
    if last_selected.con_type and not last_selected.parent.locked then
        return ("Connector %s"):format(last_selected.label or last_selected.id)
    end
    local label = last_selected.label or last_selected.id
    if last_selected.con_type then
        label = last_selected.parent.label or last_selected.parent.id
    end
    return ("Node %s"):format(label)
end

---@type NodeT
local nodes = {}
local function draw_nodes()
    nodes_win.clear()
    if connecting then
        line_func(connection_sx, connection_sy, connection_dx, connection_dy, nodes_win)
    end
    for k, v in pairs(nodes) do
        v:draw()
        v:draw_lines()
    end
    d.text(root_x, root_y, "X", nodes_win)
    nodes_win.setVisible(true)
    nodes_win.setVisible(false)
    d.set_col(colors.black, colors.white, button_win)
    button_win.clear()
    local t = "^^^ %s ^^^"
    if last_selected == nil then
        t = t:format("MENU")
    else
        t = t:format(("Edit %s"):format(get_last_selected_label()))
    end
    d.center_text(1, t, button_win)
    button_win.setVisible(true)
    button_win.setVisible(false)
end

---@param node Node
local function add_node(node)
    nodes[#nodes + 1] = node
end

---@param node Node
local function remove_node(node)
    for i, node_i in ipairs(nodes) do
        if node_i == node then
            table.remove(nodes, i)
            break
        end
    end
    unlink(node.inputs)
    unlink(node.outputs)
end

local executeLimit = 128 -- limit of functions to run in parallel
---Execute a table of functions in batches
---@param func function[]
---@param skipPartial? boolean Only do complete batches and skip the remainder.
---@return function[] skipped Functions that were skipped as they didn't fit.
local function batch_execute(func, skipPartial)
    -- for _, v in ipairs(func) do
    -- v()
    -- end
    local batches = #func / executeLimit
    batches = skipPartial and math.floor(batches) or math.ceil(batches)
    for batch = 1, batches do
        local start = ((batch - 1) * executeLimit) + 1
        local batch_end = math.min(start + executeLimit - 1, #func)
        parallel.waitForAll(table.unpack(func, start, batch_end))
    end
    return table.pack(table.unpack(func, 1 + executeLimit * batches))
end

local tick_delay = 0.1
local function handle_ticks()
    while true do
        sleep(tick_delay)
        local funcs = {}
        for _, v in ipairs(nodes) do
            local funcs_l = v:tick()
            merge_into(funcs_l or {}, funcs)
        end
        batch_execute(funcs)
    end
end

local function distribute_event(e)
    for k, v in pairs(nodes) do
        if v[e[1]](v, table.unpack(e, 2, 5)) then return true end
    end
end


local expect = require "cc.expect".expect

--- PrimeUI stuff https://github.com/MCJack123/PrimeUI
-- Initialization code
local PrimeUI = {}
do
    local coros = {}
    local restoreCursor

    --- Adds a task to run in the main loop.
    ---@param func function The function to run, usually an `os.pullEvent` loop
    function PrimeUI.addTask(func)
        expect(1, func, "function")
        local t = { coro = coroutine.create(func) }
        coros[#coros + 1] = t
        _, t.filter = coroutine.resume(t.coro)
    end

    --- Sends the provided arguments to the run loop, where they will be returned.
    ---@param ... any The parameters to send
    function PrimeUI.resolve(...)
        coroutine.yield(coros, ...)
    end

    --- Clears the screen and resets all components. Do not use any previously
    --- created components after calling this function.
    function PrimeUI.clear()
        -- Reset the screen.
        term.setCursorPos(1, 1)
        term.setCursorBlink(false)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        -- Reset the task list and cursor restore function.
        coros = {}
        restoreCursor = nil
    end

    --- Sets or clears the window that holds where the cursor should be.
    ---@param win Window|nil The window to set as the active window
    function PrimeUI.setCursorWindow(win)
        expect(1, win, "table", "nil")
        restoreCursor = win and win.restoreCursor
    end

    --- Gets the absolute position of a coordinate relative to a window.
    ---@param win Window The window to check
    ---@param x number The relative X position of the point
    ---@param y number The relative Y position of the point
    ---@return number x The absolute X position of the window
    ---@return number y The absolute Y position of the window
    function PrimeUI.getWindowPos(win, x, y)
        if win == term then return x, y end
        while win ~= term.native() and win ~= term.current() do
            if not win.getPosition then return x, y end
            local wx, wy = win.getPosition()
            x, y = x + wx - 1, y + wy - 1
            _, win = debug.getupvalue(select(2, debug.getupvalue(win.isColor, 1)), 1) -- gets the parent window through an upvalue
        end
        return x, y
    end

    --- Runs the main loop, returning information on an action.
    ---@return any ... The result of the coroutine that exited
    function PrimeUI.run()
        while true do
            -- Restore the cursor and wait for the next event.
            if restoreCursor then restoreCursor() end
            local ev = table.pack(os.pullEvent())
            -- Run all coroutines.
            for _, v in ipairs(coros) do
                if v.filter == nil or v.filter == ev[1] then
                    -- Resume the coroutine, passing the current event.
                    local res = table.pack(coroutine.resume(v.coro, table.unpack(ev, 1, ev.n)))
                    -- If the call failed, bail out. Coroutines should never exit.
                    if not res[1] then error(res[2], 2) end
                    -- If the coroutine resolved, return its values.
                    if res[2] == coros then return table.unpack(res, 3, res.n) end
                    -- Set the next event filter.
                    v.filter = res[2]
                end
            end
        end
    end

    --- Draws a line of text at a position.
    ---@param win Window The window to draw on
    ---@param x number The X position of the left side of the text
    ---@param y number The Y position of the text
    ---@param text string The text to draw
    ---@param fgColor color|nil The color of the text (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    function PrimeUI.label(win, x, y, text, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, text, "string")
        fgColor = expect(5, fgColor, "number", "nil") or colors.white
        bgColor = expect(6, bgColor, "number", "nil") or colors.black
        win.setCursorPos(x, y)
        win.setTextColor(fgColor)
        win.setBackgroundColor(bgColor)
        win.write(text)
    end

    --- Creates a text input box.
    ---@param win Window The window to draw on
    ---@param x number The X position of the left side of the box
    ---@param y number The Y position of the box
    ---@param width number The width/length of the box
    ---@param action function|string A function or `run` event to call when the enter key is pressed
    ---@param fgColor color|nil The color of the text (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    ---@param replacement string|nil A character to replace typed characters with
    ---@param history string[]|nil A list of previous entries to provide
    ---@param completion function|nil A function to call to provide completion
    ---@param default string|nil A string to return if the box is empty
    function PrimeUI.inputBox(win, x, y, width, action, fgColor, bgColor, replacement, history, completion, default)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        expect(5, action, "function", "string")
        fgColor = expect(6, fgColor, "number", "nil") or colors.white
        bgColor = expect(7, bgColor, "number", "nil") or colors.black
        expect(8, replacement, "string", "nil")
        expect(9, history, "table", "nil")
        expect(10, completion, "function", "nil")
        expect(11, default, "string", "nil")
        -- Create a window to draw the input in.
        local box = window.create(win, x, y, width, 1)
        box.setTextColor(fgColor)
        box.setBackgroundColor(bgColor)
        box.clear()
        -- Call read() in a new coroutine.
        PrimeUI.addTask(function()
            -- We need a child coroutine to be able to redirect back to the window.
            local coro = coroutine.create(read)
            -- Run the function for the first time, redirecting to the window.
            local old = term.redirect(box)
            local ok, res = coroutine.resume(coro, replacement, history, completion, default)
            term.redirect(old)
            -- Run the coroutine until it finishes.
            while coroutine.status(coro) ~= "dead" do
                -- Get the next event.
                local ev = table.pack(os.pullEvent())
                -- Redirect and resume.
                old = term.redirect(box)
                ok, res = coroutine.resume(coro, table.unpack(ev, 1, ev.n))
                term.redirect(old)
                -- Pass any errors along.
                if not ok then error(res) end
            end
            -- Send the result to the receiver.
            if type(action) == "string" then
                PrimeUI.resolve("inputBox", action, res)
            else
                action(res)
            end
            -- Spin forever, because tasks cannot exit.
            while true do os.pullEvent() end
        end)
    end

    --- Draws a horizontal line at a position with the specified width.
    ---@param win Window The window to draw on
    ---@param x number The X position of the left side of the line
    ---@param y number The Y position of the line
    ---@param width number The width/length of the line
    ---@param fgColor color|nil The color of the line (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    function PrimeUI.horizontalLine(win, x, y, width, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        fgColor = expect(5, fgColor, "number", "nil") or colors.white
        bgColor = expect(6, bgColor, "number", "nil") or colors.black
        -- Use drawing characters to draw a thin line.
        win.setCursorPos(x, y)
        win.setTextColor(fgColor)
        win.setBackgroundColor(bgColor)
        win.write(("\x8C"):rep(width))
    end

    --- Draws a thin border around a screen region.
    ---@param win Window The window to draw on
    ---@param x number The X coordinate of the inside of the box
    ---@param y number The Y coordinate of the inside of the box
    ---@param width number The width of the inner box
    ---@param height number The height of the inner box
    ---@param fgColor color|nil The color of the border (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    function PrimeUI.borderBox(win, x, y, width, height, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        expect(5, height, "number")
        fgColor = expect(6, fgColor, "number", "nil") or colors.white
        bgColor = expect(7, bgColor, "number", "nil") or colors.black
        -- Draw the top-left corner & top border.
        win.setBackgroundColor(bgColor)
        win.setTextColor(fgColor)
        win.setCursorPos(x - 1, y - 1)
        win.write("\x9C" .. ("\x8C"):rep(width))
        -- Draw the top-right corner.
        win.setBackgroundColor(fgColor)
        win.setTextColor(bgColor)
        win.write("\x93")
        -- Draw the right border.
        for i = 1, height do
            win.setCursorPos(win.getCursorPos() - 1, y + i - 1)
            win.write("\x95")
        end
        -- Draw the left border.
        win.setBackgroundColor(bgColor)
        win.setTextColor(fgColor)
        for i = 1, height do
            win.setCursorPos(x - 1, y + i - 1)
            win.write("\x95")
        end
        -- Draw the bottom border and corners.
        win.setCursorPos(x - 1, y + height)
        win.write("\x8D" .. ("\x8C"):rep(width) .. "\x8E")
    end

    --- Creates a list of entries that can each be selected.
    ---@param win Window The window to draw on
    ---@param x number The X coordinate of the inside of the box
    ---@param y number The Y coordinate of the inside of the box
    ---@param width number The width of the inner box
    ---@param height number The height of the inner box
    ---@param entries string[] A list of entries to show, where the value is whether the item is pre-selected (or `"R"` for required/forced selected)
    ---@param action function|string A function or `run` event that's called when a selection is made
    ---@param selectChangeAction function|string|nil A function or `run` event that's called when the current selection is changed
    ---@param fgColor color|nil The color of the text (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    function PrimeUI.selectionBox(win, x, y, width, height, entries, action, selectChangeAction, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        expect(5, height, "number")
        expect(6, entries, "table")
        expect(7, action, "function", "string")
        expect(8, selectChangeAction, "function", "string", "nil")
        fgColor = expect(9, fgColor, "number", "nil") or colors.white
        bgColor = expect(10, bgColor, "number", "nil") or colors.black
        -- Create container window.
        local entrywin = window.create(win, x, y, width - 1, height)
        local selection, scroll = 1, 1
        -- Create a function to redraw the entries on screen.
        local function drawEntries()
            -- Clear and set invisible for performance.
            entrywin.setVisible(false)
            entrywin.setBackgroundColor(bgColor)
            entrywin.clear()
            -- Draw each entry in the scrolled region.
            for i = scroll, scroll + height - 1 do
                -- Get the entry; stop if there's no more.
                local e = entries[i]
                if not e then break end
                -- Set the colors: invert if selected.
                entrywin.setCursorPos(2, i - scroll + 1)
                if i == selection then
                    entrywin.setBackgroundColor(fgColor)
                    entrywin.setTextColor(bgColor)
                else
                    entrywin.setBackgroundColor(bgColor)
                    entrywin.setTextColor(fgColor)
                end
                -- Draw the selection.
                entrywin.clearLine()
                entrywin.write(#e > width - 1 and e:sub(1, width - 4) .. "..." or e)
            end
            -- Draw scroll arrows.
            entrywin.setCursorPos(width, 1)
            entrywin.write(scroll > 1 and "\30" or " ")
            entrywin.setCursorPos(width, height)
            entrywin.write(scroll < #entries - height + 1 and "\31" or " ")
            -- Send updates to the screen.
            entrywin.setVisible(true)
        end
        -- Draw first screen.
        drawEntries()
        -- Add a task for selection keys.
        PrimeUI.addTask(function()
            while true do
                local _, key = os.pullEvent("key")
                if key == keys.down and selection < #entries then
                    -- Move selection down.
                    selection = selection + 1
                    if selection > scroll + height - 1 then scroll = scroll + 1 end
                    -- Send action if necessary.
                    if type(selectChangeAction) == "string" then
                        PrimeUI.resolve("selectionBox", selectChangeAction, selection)
                    elseif selectChangeAction then
                        selectChangeAction(selection)
                    end
                    -- Redraw screen.
                    drawEntries()
                elseif key == keys.up and selection > 1 then
                    -- Move selection up.
                    selection = selection - 1
                    if selection < scroll then scroll = scroll - 1 end
                    -- Send action if necessary.
                    if type(selectChangeAction) == "string" then
                        PrimeUI.resolve("selectionBox", selectChangeAction, selection)
                    elseif selectChangeAction then
                        selectChangeAction(selection)
                    end
                    -- Redraw screen.
                    drawEntries()
                elseif key == keys.enter then
                    -- Select the entry: send the action.
                    if type(action) == "string" then
                        PrimeUI.resolve("selectionBox", action, entries[selection])
                    else
                        action(entries[selection])
                    end
                end
            end
        end)
    end

    --- Creates a text box that wraps text and can have its text modified later.
    ---@param win Window The parent window of the text box
    ---@param x number The X position of the box
    ---@param y number The Y position of the box
    ---@param width number The width of the box
    ---@param height number The height of the box
    ---@param text string The initial text to draw
    ---@param fgColor color|nil The color of the text (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    ---@return function redraw A function to redraw the window with new contents
    function PrimeUI.textBox(win, x, y, width, height, text, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        expect(5, height, "number")
        expect(6, text, "string")
        fgColor = expect(7, fgColor, "number", "nil") or colors.white
        bgColor = expect(8, bgColor, "number", "nil") or colors.black
        -- Create the box window.
        local box = window.create(win, x, y, width, height)
        -- Override box.getSize to make print not scroll.
        ---@diagnostic disable-next-line: duplicate-set-field
        function box.getSize()
            return width, math.huge
        end

        -- Define a function to redraw with.
        local function redraw(_text)
            expect(1, _text, "string")
            -- Set window parameters.
            box.setBackgroundColor(bgColor)
            box.setTextColor(fgColor)
            box.clear()
            box.setCursorPos(1, 1)
            -- Redirect and draw with `print`.
            local old = term.redirect(box)
            print(_text)
            term.redirect(old)
        end
        redraw(text)
        return redraw
    end

    --- Creates a clickable button on screen with text.
    ---@param win Window The window to draw on
    ---@param x number The X position of the button
    ---@param y number The Y position of the button
    ---@param text string The text to draw on the button
    ---@param action function|string A function to call when clicked, or a string to send with a `run` event
    ---@param fgColor color|nil The color of the button text (defaults to white)
    ---@param bgColor color|nil The color of the button (defaults to light gray)
    ---@param clickedColor color|nil The color of the button when clicked (defaults to gray)
    function PrimeUI.button(win, x, y, text, action, fgColor, bgColor, clickedColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, text, "string")
        expect(5, action, "function", "string")
        fgColor = expect(6, fgColor, "number", "nil") or colors.white
        bgColor = expect(7, bgColor, "number", "nil") or colors.gray
        clickedColor = expect(8, clickedColor, "number", "nil") or colors.lightGray
        -- Draw the initial button.
        win.setCursorPos(x, y)
        win.setBackgroundColor(bgColor)
        win.setTextColor(fgColor)
        win.write(" " .. text .. " ")
        -- Get the screen position and add a click handler.
        PrimeUI.addTask(function()
            local buttonDown = false
            while true do
                local event, button, clickX, clickY = os.pullEvent()
                local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
                if event == "mouse_click" and button == 1 and clickX >= screenX and clickX < screenX + #text + 2 and clickY == screenY then
                    -- Initiate a click action (but don't trigger until mouse up).
                    buttonDown = true
                    -- Redraw the button with the clicked background color.
                    win.setCursorPos(x, y)
                    win.setBackgroundColor(clickedColor)
                    win.setTextColor(fgColor)
                    win.write(" " .. text .. " ")
                elseif event == "mouse_up" and button == 1 and buttonDown then
                    -- Finish a click event.
                    if clickX >= screenX and clickX < screenX + #text + 2 and clickY == screenY then
                        -- Trigger the action.
                        if type(action) == "string" then
                            PrimeUI.resolve("button", action)
                        else
                            action()
                        end
                    end
                    -- Redraw the original button state.
                    win.setCursorPos(x, y)
                    win.setBackgroundColor(bgColor)
                    win.setTextColor(fgColor)
                    win.write(" " .. text .. " ")
                end
            end
        end)
    end
end


local serialize
local function save_to_file(fn)
    local f = fs.open(fn, "w")
    if not f then return false end
    f.write(serialize())
    f.close()
    return true
end
---@type table<string,RegisteredNode>
local registered_nodes = {}
---@type table<string,RegisteredConnector>
local registered_connectors = {}

local function init_ui(header)
    d.set_col(colors.white, colors.black, gui_win)
    gui_win.clear()
    PrimeUI.clear()
    PrimeUI.label(gui_win, 3, 2, header)
    PrimeUI.horizontalLine(gui_win, 3, 3, #header + 2)
end

local function generic_selection(title, options)
    init_ui(title)
    local box_w, box_h = tw - 8, th - 10
    PrimeUI.borderBox(gui_win, 4, 6, box_w, box_h)
    PrimeUI.selectionBox(gui_win, 4, 6, box_w, box_h, options, "enter")
    PrimeUI.button(gui_win, 3, th - 2, "Cancel", "cancel")

    local _, action, selection = PrimeUI.run()
    if action == "enter" then
        return selection
    end
end

local function get_node_type(label)
    local node_types = {}
    for k, v in pairs(registered_nodes) do
        node_types[#node_types + 1] = k
    end
    return generic_selection(label, node_types)
end

local function get_con_type(label)
    local node_types = {}
    for k, v in pairs(registered_connectors) do
        node_types[#node_types + 1] = k
    end
    return generic_selection(label, node_types)
end

local function new_connector_menu()
    local selection = get_con_type("New Connector")
    if selection then
        return registered_connectors[selection].new()
    end
end

local function new_node_menu()
    local selection = get_node_type("New Node")
    if not selection then return end
    add_node(registered_nodes[selection].new())
end

local function get_text_menu(heading, label)
    init_ui(heading)
    PrimeUI.label(gui_win, 4, 6, label)
    PrimeUI.horizontalLine(gui_win, 3, 3, #heading + 2)
    PrimeUI.button(gui_win, 3, th - 2, "Cancel", "cancel")
    local box_w, box_h = tw - 8, 1
    PrimeUI.borderBox(gui_win, 4, 8, box_w, box_h)
    PrimeUI.inputBox(gui_win, 4, 8, box_w, "enter")
    local _, action, selection = PrimeUI.run()
    if action == "enter" then
        return selection
    end
end

local function save_menu()
    local selection = get_text_menu("Saving", "Filename:")
    if selection == "" then return end
    if not selection then return end
    save_to_file(selection)
end

local function get_file_menu(title)
    local path = "/"
    while true do
        local files = fs.list(path)
        if path == "" then
            path = "/"
        end
        for i, f in ipairs(files) do
            if fs.isDir(fs.combine(path, f)) then
                files[i] = f .. "/"
            end
        end
        if path ~= "/" then
            table.insert(files, 1, "..")
        end
        init_ui(title)
        PrimeUI.label(gui_win, 3, 6, path)
        local box_w, box_h = tw - 8, th - 12
        PrimeUI.borderBox(gui_win, 4, 8, box_w, box_h)
        PrimeUI.selectionBox(gui_win, 4, 8, box_w, box_h, files, "enter")
        PrimeUI.button(gui_win, 3, th - 2, "Cancel", "cancel")
        local _, action, selection = PrimeUI.run()
        if action == "enter" then
            path = fs.combine(path, selection)
            if not fs.isDir(path) then
                return path
            end
        else
            return -- cancelled
        end
    end
end

local unserialize
local function load_menu()
    local path = get_file_menu("Loading")
    if not path then return end
    term.setCursorPos(1, 1)
    local f = assert(fs.open(path, "r"))
    unserialize(f.readAll() --[[@as string]])
    f.close()
end

local function main_menu()
    init_ui("Menu")
    PrimeUI.horizontalLine(gui_win, 3, 3, 6)
    local entries = {
        "Add Node",
        "Reset View",
        "Save",
        "Load",
        "New",
        "Quit",
    }
    local box_w, box_h = tw - 8, th - 10
    PrimeUI.borderBox(gui_win, 4, 6, box_w, box_h)
    PrimeUI.selectionBox(gui_win, 4, 6, box_w, box_h, entries, "enter")
    PrimeUI.button(gui_win, 3, th - 2, "Cancel", "cancel")
    local _, action, selection = PrimeUI.run()
    if action == "enter" then
        if selection == "Add Node" then
            new_node_menu()
        elseif selection == "Quit" then
            term.clear()
            term.setCursorPos(1, 1)
            error("Goodbye", 0)
        elseif selection == "Save" then
            save_menu()
        elseif selection == "Load" then
            load_menu()
        elseif selection == "Reset View" then
            root_x, root_y = 1, 1
            for k, v in pairs(nodes) do
                v:update_window()
            end
        elseif selection == "New" then
            nodes = {}
        end
    end
end

local function get_label_menu()
    local selection = get_text_menu("Label", "Label:")
    if selection == "" then return end
    return selection
end

local function check_filter(name, filters)
    for _, v in ipairs(filters) do
        if peripheral.hasType(name, v) then return true end
    end
end

local function get_peripheral(filters)
    local options = {}
    for _, name in ipairs(peripheral.getNames()) do
        if (not filters) or check_filter(name, filters) then
            options[#options + 1] = name
        end
    end
    return generic_selection("Select Peripheral", options)
end

---@param obj Node|Connector
---@param set_field NodeFieldSetter|ConFieldSetter
---@param field_info ConfigFieldInfo
local function editing_fields_menu(obj, set_field, field_info)
    local entries = {}
    local descriptions = {}
    for k, v in pairs(field_info) do
        entries[#entries + 1] = k
        descriptions[#descriptions + 1] = v.description or ""
    end
    init_ui(("Editing Fields for %s"):format(obj.label or obj.id))
    local box_w, box_h = tw - 8, th - 15
    PrimeUI.borderBox(gui_win, 4, 6, box_w, box_h)
    local redraw = PrimeUI.textBox(gui_win, 4, th - 7, box_w, 3, descriptions[1])
    PrimeUI.borderBox(gui_win, 4, th - 7, box_w, 3)
    PrimeUI.selectionBox(gui_win, 4, 6, box_w, box_h, entries, "enter", function(option) redraw(descriptions[option]) end)
    PrimeUI.button(gui_win, 3, th - 2, "Cancel", "cancel")
    local _, action, selection = PrimeUI.run()
    if action == "enter" then
        -- editing a field
        local field_type = field_info[selection].type
        local editing_str = ("Editing field %s"):format(selection)
        if field_type == "string" then
            set_field(obj, selection, get_text_menu(editing_str, "Value:"))
        elseif field_type == "con_type" then
            set_field(obj, selection, get_con_type(editing_str))
        elseif field_type == "file" then
            set_field(obj, selection, get_file_menu(editing_str))
        elseif field_type == "number" then
            set_field(obj, selection, tonumber(get_text_menu(editing_str, "Value #:")))
        elseif field_type == "peripheral" then
            set_field(obj, selection, get_peripheral(field_info[selection].peripheral))
        end
    end
end

local function editing_node_menu(node)
    local registered_node = registered_nodes[node.node_type]
    local label = ("Editing Node %s"):format(node.label or node.id)
    init_ui(label)
    local entries = {
        "Set Label",
        "Delete",
    }
    if registered_node.configurable_fields then
        entries[#entries + 1] = "Edit Fields"
    end
    if not node.locked then
        entries[#entries + 1] = "Add Input"
        entries[#entries + 1] = "Add Output"
    end
    local box_w, box_h = tw - 8, th - 10
    PrimeUI.borderBox(gui_win, 4, 6, box_w, box_h)
    PrimeUI.selectionBox(gui_win, 4, 6, box_w, box_h, entries, "enter")
    PrimeUI.button(gui_win, 3, th - 2, "Cancel", "cancel")
    local _, action, selection = PrimeUI.run()
    if action == "enter" then
        if selection == "Set Label" then
            node.label = get_label_menu()
            node:update_size()
        elseif selection == "Delete" then
            remove_node(node)
            last_selected = nil
        elseif selection == "Add Input" then
            local connector = new_connector_menu()
            if connector then
                node:add_input(connector)
            end
        elseif selection == "Add Output" then
            local connector = new_connector_menu()
            if connector then
                node:add_output(connector)
            end
        elseif selection == "Edit Fields" then
            editing_fields_menu(node, registered_node.set_field, registered_node.configurable_fields)
        end
    end
end
---@param con Connector
local function editing_connector_menu(con)
    local label = ("Editing Connector %s"):format(con.label or con.id)
    init_ui(label)
    local entries = {
        "Set Label",
        "Delete",
    }
    local registered_connector = registered_connectors[con.con_type]
    if registered_connector.configurable_fields then
        entries[#entries + 1] = "Edit Fields"
    end
    local box_w, box_h = tw - 8, th - 10
    PrimeUI.borderBox(gui_win, 4, 6, box_w, box_h)
    PrimeUI.selectionBox(gui_win, 4, 6, box_w, box_h, entries, "enter")
    PrimeUI.button(gui_win, 3, th - 2, "Cancel", "cancel")
    local _, action, selection = PrimeUI.run()
    if action == "enter" then
        if selection == "Set Label" then
            con.label = get_label_menu()
            con.parent:update_size()
        elseif selection == "Delete" then
            local tab = (con.direction == "input" and con.parent.inputs) or con.parent.outputs
            for i, c in ipairs(tab) do
                if c == con then
                    term.setCursorPos(1, 2)
                    c:unlink()
                    table.remove(tab, i)
                    con.parent:update_size()
                    break
                end
            end
            last_selected = nil
        elseif selection == "Edit Fields" then
            editing_fields_menu(con, registered_connector.set_field, registered_connector.configurable_fields)
        end
    end
end

local function gui_button_clicked()
    local editing = get_thing_selected_for_editing()
    if not editing then
        return main_menu()
    elseif editing.node_type then
        return editing_node_menu(editing)
    elseif editing.con_type then
        return editing_connector_menu(editing --[[@as Connector]])
    end
end



local dragging_root = false
local drag_sx, drag_sy
local drag_root_x, drag_root_y
local function node_interface()
    while true do
        draw_nodes()
        local e = { os.pullEvent() }
        local event_absorbed
        if e[1] == "mouse_drag" then
            if connecting then
                local wx, wy = nodes_win.getPosition()
                connection_dx, connection_dy = e[3] - wx + 1, e[4] - wy + 1
            elseif last_selected and last_selected.con_type then
                -- The last selected thing is a connector
                last_selected = last_selected --[[@as Connector]]
                if last_selected.direction == "input" and last_selected.link then
                    start_connection(
                        last_selected.link_parent,
                        last_selected.link,
                        last_selected.link_parent:local_pos_to_screen(last_selected.link_parent.w + 1,
                            last_selected.link.y)
                    )
                elseif last_selected.direction == "output" then
                    start_connection(last_selected.parent, last_selected --[[@as Connector]],
                        last_selected.parent:local_pos_to_screen(last_selected.parent.w + 1, last_selected.y))
                end
            else
                event_absorbed = distribute_event(e)
            end
        elseif e[1] == "mouse_click" or e[1] == "mouse_up" then
            event_absorbed = distribute_event(e)
        end
        if e[1] == "mouse_up" then
            connecting = false
            dragging_root = false
        end
        if not event_absorbed then
            if e[1] == "mouse_click" then
                if e[4] == th then
                    gui_button_clicked()
                else
                    drag_sx, drag_sy = e[3], e[4]
                    drag_root_x, drag_root_y = root_x, root_y
                    dragging_root = true
                    last_selected = nil
                end
            elseif e[1] == "mouse_drag" and dragging_root then
                root_x = drag_root_x + e[3] - drag_sx
                root_y = drag_root_y + e[4] - drag_sy
                for k, v in pairs(nodes) do
                    v:update_window()
                end
            else
                for _, v in ipairs(nodes) do
                    v:on_event(e)
                end
            end
        end
    end
end

local function start()
    parallel.waitForAny(node_interface, handle_ticks)
end

---@alias ConfigType "string"|"con_type"|"file"|"peripheral"|"number"

---@alias ConfigFieldInfo table<string,{type: ConfigType,description:string?, peripheral:peripheralType[]?}>
---@alias ConFieldSetter fun(con: Connector, key: string, value: any)
---@alias SerializeConFun fun(con: Connector)
---@alias NewConnectorFun fun():Connector
---@alias RegisteredConnector {name:string,new:NewConnectorFun,serialize:SerializeConFun,unserialize:SerializeConFun,configurable_fields:ConfigFieldInfo?,set_field:ConFieldSetter?}


---Register a new type of connector
---@param name string
---@param new fun(): Connector
---@param serialize SerializeConFun
---@param unserialize SerializeConFun
---@param configurable_fields ConfigFieldInfo?
---@param set_field ConFieldSetter?
---@param color color
local function register_connector(name, new, serialize, unserialize, configurable_fields, set_field, color)
    registered_connectors[name] = {
        new = new,
        serialize = serialize,
        unserialize = unserialize,
        configurable_fields = configurable_fields,
        set_field = set_field,
        color = color
    }
end

register_connector("DEFAULT", new_connector, function() end, function() end, nil, nil, colors.white)
---@param name string
---@return RegisteredConnector
local function get_connector(name)
    return registered_connectors[name]
end


---@alias NodeFieldSetter fun(con: Node, key: string, value: any)
---@alias SerializeNodeFun fun(con: Node)
---@alias NewNodeFun fun():Node
---@alias RegisteredNode {name:string,new:NewNodeFun,serialize:SerializeNodeFun,unserialize:SerializeNodeFun,configurable_fields:ConfigFieldInfo?,set_field:NodeFieldSetter?}


---@param name string
---@param new NewNodeFun
---@param serialize SerializeNodeFun
---@param unserialize SerializeNodeFun
---@param configurable_fields ConfigFieldInfo?
---@param set_field NodeFieldSetter?
local function register_node(name, new, serialize, unserialize, configurable_fields, set_field)
    registered_nodes[name] = {
        new = new,
        serialize = serialize,
        unserialize = unserialize,
        configurable_fields = configurable_fields,
        set_field = set_field
    }
end

register_node("DEFAULT", new_node, function() end, function() end, nil, nil)

---@param name string
---@return RegisteredNode
local function get_node(name)
    return registered_nodes[name]
end

--- Thanks 9551 https://github.com/9551-Dev/libC3D-dev/blob/dev/common/table_util.lua#L56-L85
local function deepcopy(tbl, keep, seen)
    local instance_seen = seen or {}
    local out = {}
    instance_seen[tbl] = out
    for copied_key, copied_value in pairs(tbl) do
        local is_table = type(copied_value) == "table" and not (keep and keep[copied_key])

        if type(copied_key) == "table" then
            if instance_seen[copied_key] then
                copied_key = instance_seen[copied_key]
            else
                local new_instance = deepcopy(copied_key, keep, instance_seen)
                instance_seen[copied_key] = new_instance
                copied_key = new_instance
            end
        end

        if is_table and not instance_seen[copied_value] then
            local new_instance = deepcopy(copied_value, keep, instance_seen)
            instance_seen[copied_value] = new_instance
            out[copied_key] = new_instance
        elseif is_table and instance_seen[copied_value] then
            out[copied_key] = instance_seen[copied_value]
        else
            out[copied_key] = copied_value
        end
    end

    return setmetatable(out, getmetatable(tbl))
end

---@class Serialized_Connector : Connector
---@field link string?
---@field link_parent string?
---@field parent string

---@param con Connector
local function serialize_connector(con)
    con = con --[[@as Serialized_Connector]]
    if con.link then
        con.link = con.link.id
        con.link_parent = con.link_parent.id
    end
    con.parent = con.parent.id
    registered_connectors[con.con_type].serialize(con)
end

---@param node Node
local function serialize_node(node)
    for _, con in ipairs(node.inputs) do
        serialize_connector(con)
    end
    for _, con in ipairs(node.outputs) do
        serialize_connector(con)
    end
end

local function search_for_connector_link(con_array, con)
    for _, con_child in ipairs(con_array) do
        if con_child.id == con.link then
            con.link = con_child
            return true
        end
    end
end

---@param nodes Node[] Table of nodes currently being unserialized
---@param con Connector
local function unserialize_connector(nodes, con)
    if con.link then
        for _, node in ipairs(nodes) do
            if node.id == con.link_parent then
                con.link_parent = node
                break
            end
        end
        if type(con.link_parent) == "string" then
            error(("Unable to find connector parent %s"):format(con.link_parent))
        end
        local found_link = search_for_connector_link(con.link_parent.inputs, con) or
            search_for_connector_link(con.link_parent.outputs, con)
        if not found_link then
            error(("Unable to find connector link %s"):format(con.link))
        end
    end
    if registered_connectors[con.con_type] then
        registered_connectors[con.con_type].unserialize(con)
    else
        error(("Unrecognized connectory type %s"):format(con.con_type))
    end
end

---@param nodes Node[] Table of nodes currently being unserialized
---@param node Node
local function unserialize_node(nodes, node)
    for _, con in ipairs(node.inputs) do
        con.parent = node
        unserialize_connector(nodes, con)
    end
    for _, con in ipairs(node.outputs) do
        con.parent = node
        unserialize_connector(nodes, con)
    end
    node.window = window.create(nodes_win, node.x, node.y, 1, 1)
    setmetatable(node, node_meta)
    node:update_size()
end

function serialize()
    local serializing_nodes = deepcopy(nodes) --[[@as NodeT]]
    for _, node in ipairs(serializing_nodes) do
        node.window = nil
        serialize_node(node)
        if node.node_type then
            registered_nodes[node.node_type].serialize(node)
        end
    end
    return textutils.serialise(serializing_nodes, { compact = false })
end

---@alias NodeT Node[]

---@param text string
function unserialize(text)
    local unserialized_nodes = textutils.unserialise(text) --[[@as NodeT]]
    for _, node in ipairs(unserialized_nodes) do
        unserialize_node(unserialized_nodes, node)
        if node.node_type then
            registered_nodes[node.node_type].unserialize(node)
        end
    end
    nodes = unserialized_nodes
    debug.debug()
end

return {
    send_packet_to_link = send_packet_to_link,
    node_meta = node_meta,
    new_node = new_node,
    con_meta = { __index = con__index },
    new_connector = new_connector,
    draw_nodes = draw_nodes,
    start = start,
    register_connector = register_connector,
    get_connector = get_connector,
    add_node = add_node,
    serialize = serialize,
    unserialize = unserialize,
    remove_node = remove_node,
    register_node = register_node,
    get_node = get_node,
    unlink = unlink
}
