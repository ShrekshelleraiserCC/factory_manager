local expect = require "cc.expect".expect

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

    --- Creates a list of entries with toggleable check boxes.
    ---@param win Window The window to draw on
    ---@param x number The X coordinate of the inside of the box
    ---@param y number The Y coordinate of the inside of the box
    ---@param width number The width of the inner box
    ---@param height number The height of the inner box
    ---@param selections {string: string|boolean} A list of entries to show, where the value is whether the item is pre-selected (or `"R"` for required/forced selected)
    ---@param action function|string|nil A function or `run` event that's called when a selection is made
    ---@param fgColor color|nil The color of the text (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    function PrimeUI.checkSelectionBox(win, x, y, width, height, selections, action, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        expect(5, height, "number")
        expect(6, selections, "table")
        expect(7, action, "function", "string", "nil")
        fgColor = expect(8, fgColor, "number", "nil") or colors.white
        bgColor = expect(9, bgColor, "number", "nil") or colors.black
        -- Calculate how many selections there are.
        local nsel = 0
        for _ in pairs(selections) do nsel = nsel + 1 end
        -- Create the outer display box.
        local outer = window.create(win, x, y, width, height)
        outer.setBackgroundColor(bgColor)
        outer.clear()
        -- Create the inner scroll box.
        local inner = window.create(outer, 1, 1, width - 1, nsel)
        inner.setBackgroundColor(bgColor)
        inner.setTextColor(fgColor)
        inner.clear()
        -- Draw each line in the window.
        local lines = {}
        local nl, selected = 1, 1
        for k, v in pairs(selections) do
            inner.setCursorPos(1, nl)
            inner.write((v and (v == "R" and "[-] " or "[\xD7] ") or "[ ] ") .. k)
            lines[nl] = { k, not not v }
            nl = nl + 1
        end
        -- Draw a scroll arrow if there is scrolling.
        if nsel > height then
            outer.setCursorPos(width, height)
            outer.setBackgroundColor(bgColor)
            outer.setTextColor(fgColor)
            outer.write("\31")
        end
        -- Set cursor blink status.
        inner.setCursorPos(2, selected)
        inner.setCursorBlink(true)
        PrimeUI.setCursorWindow(inner)
        -- Get screen coordinates & add run task.
        local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
        PrimeUI.addTask(function()
            local scrollPos = 1
            while true do
                -- Wait for an event.
                local ev = table.pack(os.pullEvent())
                -- Look for a scroll event or a selection event.
                local dir
                if ev[1] == "key" then
                    if ev[2] == keys.up then
                        dir = -1
                    elseif ev[2] == keys.down then
                        dir = 1
                    elseif ev[2] == keys.space and selections[lines[selected][1]] ~= "R" then
                        -- (Un)select the item.
                        lines[selected][2] = not lines[selected][2]
                        inner.setCursorPos(2, selected)
                        inner.write(lines[selected][2] and "\xD7" or " ")
                        -- Call the action if passed; otherwise, set the original table.
                        if type(action) == "string" then
                            PrimeUI.resolve("checkSelectionBox", action, lines[selected][1], lines[selected][2])
                        elseif action then
                            action(lines[selected][1], lines[selected][2])
                        else
                            selections[lines[selected][1]] = lines[selected][2]
                        end
                        -- Redraw all lines in case of changes.
                        for i, v in ipairs(lines) do
                            local vv = selections[v[1]] == "R" and "R" or v[2]
                            inner.setCursorPos(2, i)
                            inner.write((vv and (vv == "R" and "-" or "\xD7") or " "))
                        end
                        inner.setCursorPos(2, selected)
                    end
                elseif ev[1] == "mouse_scroll" and ev[3] >= screenX and ev[3] < screenX + width and ev[4] >= screenY and ev[4] < screenY + height then
                    dir = ev[2]
                end
                -- Scroll the screen if required.
                if dir and (selected + dir >= 1 and selected + dir <= nsel) then
                    selected = selected + dir
                    if selected - scrollPos < 0 or selected - scrollPos >= height then
                        scrollPos = scrollPos + dir
                        inner.reposition(1, 2 - scrollPos)
                    end
                    inner.setCursorPos(2, selected)
                end
                -- Redraw scroll arrows and reset cursor.
                outer.setCursorPos(width, 1)
                outer.write(scrollPos > 1 and "\30" or " ")
                outer.setCursorPos(width, height)
                outer.write(scrollPos < nsel - height + 1 and "\31" or " ")
                inner.restoreCursor()
            end
        end)
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

    --- Creates a progress bar, which can be updated by calling the returned function.
    ---@param win Window The window to draw on
    ---@param x number The X position of the left side of the bar
    ---@param y number The Y position of the bar
    ---@param width number The width of the bar
    ---@param fgColor color|nil The color of the activated part of the bar (defaults to white)
    ---@param bgColor color|nil The color of the inactive part of the bar (defaults to black)
    ---@param useShade boolean|nil Whether to use shaded areas for the inactive part (defaults to false)
    ---@return function redraw A function to call to update the progress of the bar, taking a number from 0.0 to 1.0
    function PrimeUI.progressBar(win, x, y, width, fgColor, bgColor, useShade)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        fgColor = expect(5, fgColor, "number", "nil") or colors.white
        bgColor = expect(6, bgColor, "number", "nil") or colors.black
        expect(7, useShade, "boolean", "nil")
        local function redraw(progress)
            expect(1, progress, "number")
            if progress < 0 or progress > 1 then error("bad argument #1 (value out of range)", 2) end
            -- Draw the active part of the bar.
            win.setCursorPos(x, y)
            win.setBackgroundColor(bgColor)
            win.setBackgroundColor(fgColor)
            win.write((" "):rep(math.floor(progress * width)))
            -- Draw the inactive part of the bar, using shade if desired.
            win.setBackgroundColor(bgColor)
            win.setTextColor(fgColor)
            win.write((useShade and "\x7F" or " "):rep(width - math.floor(progress * width)))
        end
        redraw(0)
        return redraw
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
end

PrimeUI.clear()
term.clear()
local w, h = term.getSize()
local t = term.current() --[[@as Window]]
PrimeUI.label(t, 2, 2, "Factory Manager Setup")
PrimeUI.horizontalLine(t, 2, 3, 23)
PrimeUI.label(t, 3, 4, "Select files to install")
PrimeUI.borderBox(t, 3, 7, w - 6, h - 10)
local selections = {
    ["connectors/inventory.lua"] = true,
    ["connectors/redstone.lua"] = false,
    ["nodes/filtering.lua"] = false,
    ["item_filter.lua"] = false,
    ["draw.lua"] = "R",
    ["manager_lib.lua"] = "R",
    ["manager.lua"] = "R",
}
PrimeUI.checkSelectionBox(t, 3, 7, w - 6, h - 10, selections)
PrimeUI.button(t, 3, h - 1, "Cancel", "cancel")
PrimeUI.button(t, math.floor(w / 2), h - 1, "Install", "install")
PrimeUI.keyAction(keys.enter, "install")
local _, action = PrimeUI.run()
term.clear()
term.setCursorPos(1, 1)
if action == "cancel" then
    return
end

local function downloadFile(path, url)
    local response = assert(http.get(url, nil, true), "Failed to get " .. url)
    local resp = response.readAll()
    response.close()
    local f = assert(fs.open(path, "wb"), "Cannot open file " .. path)
    f.write(resp)
    f.close()
end

local file_count = 0
for _, f in pairs(selections) do
    if f then
        file_count = file_count + 1
    end
end

PrimeUI.clear()
PrimeUI.label(t, 2, 2, "Installing...")
PrimeUI.horizontalLine(t, 2, 3, 15)
local mh = math.floor(h / 2)
local redraw = PrimeUI.progressBar(t, 3, mh, w - 6)
PrimeUI.borderBox(t, 3, mh, w - 6, 1)
local repository_url = "https://raw.githubusercontent.com/MasonGulu/cc_factory_manager/main/"
PrimeUI.addTask(function()
    local progress = 0
    for fn, f in pairs(selections) do
        if f then
            downloadFile(fn, repository_url .. fn)
            progress = progress + 1
            redraw(progress / file_count)
            os.queueEvent("fake")
            os.pullEvent("fake")
        end
    end
    PrimeUI.resolve()
end)
PrimeUI.run()

term.clear()
term.setCursorPos(1, 1)
print("Factory manager installed.\nRun manager.lua")
