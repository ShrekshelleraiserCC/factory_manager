local pixelbox = require("libs.pixelbox_lite")
local tw, th = term.getSize()
local nodes_win = window.create(term.current(), 1, 1, tw, th)
local gui_win = window.create(term.current(), 1, 1, tw, th)
return {
    box = pixelbox.new(nodes_win),
    nodes_win = nodes_win,
    gui_win = gui_win,
    root_x = 1,
    root_y = 1,

    ---@type Node|Connector? Last selected Node or Connector for editing
    last_selected = nil,

    ---@type boolean Whether the user is currently connecting nodes togther
    connecting = false,
    ---@type Connector
    connection_connector = nil,
    ---@type integer Connecting line source
    connection_sx = nil,
    ---@type integer Connecting line source
    connection_sy = nil,

    ---@type integer Connecting line destination
    connection_dx = nil,
    ---@type integer Connecting line destination
    connection_dy = nil,
}
