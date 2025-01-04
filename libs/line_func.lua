local disp_context = require("libs.disp_context")
local box = disp_context.box
local nodes_win = disp_context.nodes_win
return function(x1, y1, x2, y2)
    local d = require("draw")
    local sx1, sy1, sx2, sy2 = x1 * 2 - 1, (y1 - 1) * 3 + 2, x2 * 2 + 1, (y2 - 1) * 3 + 2
    if x2 - 4 > x1 or (x2 - 4 <= x1 and x2 > x1 and math.abs(y1 - y2) < 10) then
        d.smooth_step_line_box(sx1, sy1, sx2, sy2, box, nodes_win.getTextColor())
    else
        d.aligned_cubic_line_box(sx1, sy1, sx2, sy2, box, nodes_win.getTextColor())
    end
end
