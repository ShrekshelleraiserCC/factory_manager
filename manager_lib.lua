local disp_context = require("libs.disp_context")
local manager_data = require("libs.manager_data")
local manager_control = require("libs.manager_control")

local registered_connectors = manager_data.registered_connectors
local registered_nodes = manager_data.registered_nodes

local clear_packet_recieved = manager_data.clear_packet_recieved

local start_connection = manager_control.start_connection

local tw, th = term.getSize()
local nodes_win = disp_context.nodes_win
local gui_win = disp_context.gui_win

local mbar = require("libs.mbar")
mbar.setWindow(nodes_win)

local d = require "draw"
d.set_default(nodes_win)

---@type Factory
local factory = manager_data.new_factory()

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

    --- Adds an action to trigger when a key is pressed.
    ---@param key number The key to trigger on, from `keys.*`
    ---@param action function|string A function to call when clicked, or a string to use as a key for a `run` return event
    function PrimeUI.keyAction(key, action)
        expect(1, key, "number")
        expect(2, action, "function", "string")
        PrimeUI.addTask(function()
            while true do
                local _, param1 = os.pullEvent("key") -- wait for key
                if param1 == key then
                    if type(action) == "string" then
                        PrimeUI.resolve("keyAction", action)
                    else
                        action()
                    end
                end
            end
        end)
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
                local event, key = os.pullEvent()
                local move_down = (event == "key" and key == keys.down) or (event == "mouse_scroll" and key == 1)
                local move_up = (event == "key" and key == keys.up) or (event == "mouse_scroll" and key == -1)
                if move_down and selection < #entries then
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
                elseif move_up and selection > 1 then
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
                elseif event == "key" and key == keys.enter then
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

local function save_to_file(fn)
    local f = fs.open(fn, "w")
    if not f then return false end
    f.write(factory:serialize())
    f.close()
    return true
end

local function init_ui(header)
    d.set_col(colors.white, colors.black, gui_win)
    gui_win.clear()
    PrimeUI.clear()
    PrimeUI.label(gui_win, 3, 2, header)
    PrimeUI.horizontalLine(gui_win, 3, 3, #header + 2)
    PrimeUI.button(gui_win, 3, th - 2, "Cancel (tab)", "cancel")
    PrimeUI.keyAction(keys.tab, "cancel")
end

local function generic_selection(title, options)
    init_ui(title)
    local box_w, box_h = tw - 8, th - 10
    PrimeUI.borderBox(gui_win, 4, 6, box_w, box_h)
    PrimeUI.selectionBox(gui_win, 4, 6, box_w, box_h, options, "enter")

    local _, action, selection = PrimeUI.run()
    if action == "enter" then
        return selection
    end
end

local function get_con_type(label)
    local node_types = {}
    for k, v in pairs(registered_connectors) do
        node_types[#node_types + 1] = k
    end
    return generic_selection(label, node_types)
end

local function get_text_menu(heading, label)
    init_ui(heading)
    PrimeUI.label(gui_win, 4, 6, label)
    PrimeUI.horizontalLine(gui_win, 3, 3, #heading + 2)
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

local function save_settings()
    local f = assert(fs.open("manager_settings", "w"))
    f.write(textutils.serialize({
        show_packets = show_packets,
        tick_delay = tick_delay
    }, { compact = true }))
    f.close()
end
local function load_settings()
    local f = fs.open("manager_settings", "r")
    if not f then
        return
    end
    local t = f.readAll()
    f.close()
    if not t then
        return
    end
    local settings = textutils.unserialise(t)
    if type(settings) == "table" then
        show_packets = settings.show_packets
        tick_delay = settings.tick_delay
    end
end
load_settings()

local function settings_menu()
    init_ui("Settings")
    PrimeUI.horizontalLine(gui_win, 3, 3, 6)
    local packet_visual_text = ("[%s] Packet Visuals"):format(show_packets and "\4" or " ")
    local tick_delay_text = ("[%.2f] Tick Delay"):format(tick_delay)
    local entries = {
        packet_visual_text,
        tick_delay_text
    }
    local box_w, box_h = tw - 8, th - 10
    PrimeUI.borderBox(gui_win, 4, 6, box_w, box_h)
    PrimeUI.selectionBox(gui_win, 4, 6, box_w, box_h, entries, "enter")
    local _, action, selection = PrimeUI.run()
    if action == "enter" then
        if selection == packet_visual_text then
            show_packets = not show_packets
        elseif selection == tick_delay_text then
            local input = tonumber(get_text_menu("Tick Delay", "Enter a sleep delay:"))
            if input then
                tick_delay = input
            end
        end
    end
    save_settings()
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
    local entries_lut = {}
    local descriptions = {}
    for k, v in pairs(field_info) do
        local t = ("[%s] %s"):format(tostring(obj[k]), k)
        entries[#entries + 1] = t
        entries_lut[t] = k
        descriptions[#descriptions + 1] = v.description or ""
    end
    init_ui(("Editing Fields for %s"):format(obj.label or obj.id))
    local box_w, box_h = tw - 8, th - 15
    PrimeUI.borderBox(gui_win, 4, 6, box_w, box_h)
    local redraw = PrimeUI.textBox(gui_win, 4, th - 7, box_w, 3, descriptions[1])
    PrimeUI.borderBox(gui_win, 4, th - 7, box_w, 3)
    PrimeUI.selectionBox(gui_win, 4, 6, box_w, box_h, entries, "enter", function(option) redraw(descriptions[option]) end)
    local _, action, selection = PrimeUI.run()
    if action == "enter" then
        -- editing a field
        selection = entries_lut[selection] -- perform translation of labels
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
        elseif type(field_type) == "table" then
            set_field(obj, selection, generic_selection(editing_str, field_type))
        end
    end
end


local render_nodes = true

local renderTimerID
local insertConnectorButton
local deleteButton, fieldsButton, labelButton
local bar

local function unserialize(t)
    factory = manager_data.unserialize(t)
end

local function initMenubar()
    --- File Menu
    local quitButton = mbar.button("Quit", function(entry)
        term.clear()
        term.setCursorPos(1, 1)
        error("Goodbye", 0)
    end)
    local saveAsButton = mbar.button("Save As", function(entry)
        render_nodes = false
        nodes_win.setVisible(true)
        local fn = mbar.popupRead("Save As", 15)
        render_nodes = true
        if fn and fn ~= "" then
            save_to_file(fn)
        end
    end)
    local settingsButton = mbar.button("Settings", function(entry)
        render_nodes = false
        settings_menu()
        render_nodes = true
    end)
    local resetViewButton = mbar.button("Reset View", function(entry)
        disp_context.root_x, disp_context.root_y = 1, 1
        for k, v in pairs(factory.nodes) do
            v:update_window()
        end
    end)
    local openButton = mbar.button("Open", function(entry)
        local complete = require("cc.shell.completion")
        render_nodes = false
        nodes_win.setVisible(true)
        local fn = mbar.popupRead("Open File", 15, nil, function(str)
            local list = complete.file(shell, str)
            for i = #list, 1, -1 do
                if not (list[i]:match("/$") or list[i]:match("%.fact$")) then
                    table.remove(list, i)
                end
            end
            return list
        end)
        render_nodes = true
        if fn and fn ~= "" then
            term.setCursorPos(1, 1)
            local f = assert(fs.open(fn, "r"))
            unserialize(f.readAll() --[[@as string]])
            f.close()
        end
    end)
    local testButton = mbar.button("Sort Factory", function(entry)
        factory:sort()
    end)
    local fileMenu = mbar.buttonMenu {
        settingsButton,
        resetViewButton,
        saveAsButton,
        openButton,
        quitButton,
        testButton
    }
    local fileButton = mbar.button("File", nil, fileMenu)



    --- Insert Menu

    ---@param button Button
    local function newNodeButtonPressedCallback(button)
        local node = registered_nodes[button.label]
        if node then
            factory:add_node(node.new())
        end
    end
    local newNodeTypeButtons = {}
    for k, v in pairs(registered_nodes) do
        newNodeTypeButtons[#newNodeTypeButtons + 1] =
            mbar.button(k, newNodeButtonPressedCallback)
    end
    local nodeTypeMenu = mbar.buttonMenu(newNodeTypeButtons)

    ---@type "input"|"output"
    local connectorSide = "input"
    ---@param button Button
    local function newConnectorButtonPressedCallback(button)
        if disp_context.last_selected and disp_context.last_selected.node_type then
            local connector = registered_connectors[button.label]
            if connector then
                local func = connectorSide == "input" and "add_input" or "add_output"
                disp_context.last_selected[func](disp_context.last_selected, connector.new())
            end
        end
    end
    local newConnectorTypeButtons = {}
    for k, v in pairs(registered_connectors) do
        newConnectorTypeButtons[#newConnectorTypeButtons + 1] =
            mbar.button(k, newConnectorButtonPressedCallback)
    end
    local inputConnectorTypeMenu = mbar.buttonMenu(newConnectorTypeButtons)
    local outputConnectorTypeMenu = mbar.buttonMenu(newConnectorTypeButtons)
    local newInputConnectorButton = mbar.button("Input", function(entry)
        connectorSide = "input"
    end, inputConnectorTypeMenu)
    local newOutputConnectorButton = mbar.button("Output", function(entry)
        connectorSide = "output"
    end, outputConnectorTypeMenu)

    local insertConnectorMenu = mbar.buttonMenu { newInputConnectorButton, newOutputConnectorButton }
    insertConnectorButton = mbar.button("Connector", nil, insertConnectorMenu)
    local insertNodeButton = mbar.button("Node", nil, nodeTypeMenu)

    local insertMenu = mbar.buttonMenu {
        insertNodeButton,
        insertConnectorButton
    }
    local insertButton = mbar.button("Insert", nil, insertMenu)

    --- Edit Menu

    labelButton = mbar.button("Label", function(entry)
        if disp_context.last_selected then
            render_nodes = false
            nodes_win.setVisible(true)
            local newLabel = mbar.popupRead("Label", 15, nil, nil, disp_context.last_selected.label)
            render_nodes = true
            if newLabel == nil then return end
            if newLabel == "" then newLabel = nil end
            disp_context.last_selected.label = newLabel
            if disp_context.last_selected.con_type then
                disp_context.last_selected.parent:update_size()
            else
                disp_context.last_selected:update_size()
            end
        end
    end)

    deleteButton = mbar.button("Delete", function(entry)
        if disp_context.last_selected then
            if disp_context.last_selected.node_type then
                factory:remove_node(disp_context.last_selected)
                disp_context.last_selected = nil
            elseif disp_context.last_selected.con_type then
                local con = assert(disp_context.last_selected)
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
                disp_context.last_selected = nil
            end
        end
    end)

    fieldsButton = mbar.button("Fields", function(entry)
        if disp_context.last_selected then
            if disp_context.last_selected.node_type then
                local node = assert(disp_context.last_selected)
                local registered_node = registered_nodes[node.node_type]
                render_nodes = false
                editing_fields_menu(node, registered_node.set_field, registered_node.configurable_fields)
                render_nodes = true
            else
                local con = assert(disp_context.last_selected)
                local registered_connector = registered_connectors[con.con_type]
                render_nodes = false
                editing_fields_menu(con, registered_connector.set_field, registered_connector.configurable_fields)
                render_nodes = true
            end
        end
    end)

    local editMenu = mbar.buttonMenu { labelButton, deleteButton, fieldsButton }
    local editButton = mbar.button("Edit", nil, editMenu)

    bar = mbar.bar({ fileButton, insertButton, editButton })

    bar.shortcut(quitButton, keys.q, true)
    bar.shortcut(deleteButton, keys.delete)
end

local dragging_root = false
local drag_sx, drag_sy
local drag_root_x, drag_root_y
local function node_interface()
    while true do
        local e = { os.pullEvent() }
        local event_absorbed = bar.onEvent(e)
        if event_absorbed then
            os.cancelTimer(renderTimerID)
            os.queueEvent("timer", renderTimerID)
        else
            if e[1] == "mouse_drag" then
                if disp_context.connecting then
                    local wx, wy = nodes_win.getPosition()
                    disp_context.connection_dx, disp_context.connection_dy = e[3] - wx + 1, e[4] - wy + 1
                elseif disp_context.last_selected and disp_context.last_selected.con_type then
                    -- The last selected thing is a connector
                    disp_context.last_selected = disp_context.last_selected --[[@as Connector]]
                    if disp_context.last_selected.direction == "input" and disp_context.last_selected.link then
                        start_connection(
                            disp_context.last_selected.link_parent,
                            disp_context.last_selected.link,
                            disp_context.last_selected.link_parent:local_pos_to_screen(
                                disp_context.last_selected.link_parent.w + 1,
                                disp_context.last_selected.link.y)
                        )
                    elseif disp_context.last_selected.direction == "output" then
                        start_connection(disp_context.last_selected.parent,
                            disp_context.last_selected --[[@as Connector]],
                            disp_context.last_selected.parent:local_pos_to_screen(
                                disp_context.last_selected.parent.w + 1, disp_context.last_selected.y))
                    end
                else
                    event_absorbed = factory:distribute_event(e)
                end
            elseif e[1] == "mouse_click" or e[1] == "mouse_up" then
                event_absorbed = factory:distribute_event(e)
            end
            if e[1] == "mouse_up" then
                disp_context.connecting = false
                dragging_root = false
            end
        end
        if not event_absorbed then
            if e[1] == "mouse_click" then
                drag_sx, drag_sy = e[3], e[4]
                drag_root_x, drag_root_y = disp_context.root_x, disp_context.root_y
                dragging_root = true
                disp_context.last_selected = nil
            elseif e[1] == "mouse_drag" and dragging_root then
                disp_context.root_x = drag_root_x + e[3] - drag_sx
                disp_context.root_y = drag_root_y + e[4] - drag_sy
                for k, v in pairs(factory.nodes) do
                    v:update_window()
                end
            elseif e[1] == "key" then
                if e[2] == keys.space then
                    active = not active
                end
            else
                for _, v in ipairs(factory.nodes) do
                    v:on_event(e)
                end
            end
        end
        insertConnectorButton.enabled = not not (disp_context.last_selected and disp_context.last_selected.node_type)
        deleteButton.enabled = not not disp_context.last_selected
        labelButton.enabled = not not disp_context.last_selected
        if disp_context.last_selected then
            if disp_context.last_selected.con_type then
                local registered_connector = registered_connectors[disp_context.last_selected.con_type]
                fieldsButton.enabled = not not registered_connector.configurable_fields
            else
                local registered_node = registered_nodes[disp_context.last_selected.node_type]
                fieldsButton.enabled = not not registered_node.configurable_fields
            end
        else
            fieldsButton.enabled = false
        end
    end
end

local function draw_ui()
    d.text(disp_context.root_x, disp_context.root_y, "X", nodes_win)
    bar.render()
    local t
    if active then
        t = "(Space) \16"
    else
        t = "(Space) \143"
    end
    d.set_col(colors.white, colors.gray)
    d.text(tw - 8, 1, t, nodes_win)
    d.invert(nodes_win)
end

local manager_view = require("libs.manager_view")

local function draw()
    renderTimerID = os.startTimer(0.1)
    while true do
        if render_nodes then
            manager_view.render_nodes_start(factory.nodes)
            manager_control.render_connection()
            manager_view.render_box()
            manager_view.render_nodes_content(factory.nodes)
            draw_ui()
            nodes_win.setVisible(true)
            nodes_win.setVisible(false)
        end
        for k, v in pairs(factory.nodes) do
            clear_packet_recieved(v)
        end
        while true do
            local _, tid = os.pullEvent("timer")
            if tid == renderTimerID then break end
        end
        renderTimerID = os.startTimer(0.1)
    end
end

local function start()
    initMenubar()
    ---@type thread[] array of functions to run all the modules
    local coroList = {
        coroutine.create(node_interface),
        coroutine.create(function() factory:start_ticking() end),
        coroutine.create(draw)
    }
    local coroLabels = {
        "node_interface",
        "handle_ticks",
        "draw"
    }
    ---@type table<thread,string|nil>
    local coroFilters = {}

    while true do
        local timerId = os.startTimer(0)
        local e = table.pack(os.pullEventRaw())
        os.cancelTimer(timerId)
        if e[1] == "terminate" then
            print("Terminated.")
            return
        end
        for i, co in ipairs(coroList) do
            if not coroFilters[co] or coroFilters[co] == "" or coroFilters[co] == e[1] then
                local ok, filter = coroutine.resume(co, table.unpack(e, 1, e.n))
                if not ok then
                    term.setTextColor(colors.red)
                    term.setBackgroundColor(colors.black)
                    term.setCursorPos(1, 1)
                    term.clear()
                    print(("Error in %s"):format(coroLabels[i]))
                    print(filter)
                    error(debug.traceback(co), 0)
                    return
                end
                coroFilters[co] = filter
            end
        end
    end
end


return {
    start = start,
    unserialize = unserialize,
}
