-- Shortcuts sent by the pen tablet's keys through OpenTabletDriver
-- (modules/hardware/drawing-tablet): key 2 = Alt+M, key 3 = Alt+C.

local colors = {
  pen = { 0x000000, 0x3333cc, 0xff0000, 0x008000 },                   -- black, blue, red, green
  highlighter = { 0xffff00, 0x00ff00, 0xff00ff, 0x00c0ff, 0xff8000 }, -- yellow, green, pink, light blue, orange
}
local index = { pen = 1, highlighter = 1 }

function initUi()
  app.registerUi({ menu = "Toggle pen / highlighter", callback = "toggleMark", accelerator = "<Alt>m" })
  app.registerUi({ menu = "Next colour", callback = "nextColor", accelerator = "<Alt>c" })
end

local function isHighlighter()
  return app.getActionState("select-tool") == app.C.Tool_highlighter
end

function toggleMark()
  if isHighlighter() then
    app.changeActionState("select-tool", app.C.Tool_pen)
  else
    app.changeActionState("select-tool", app.C.Tool_highlighter)
  end
end

-- Each tool keeps its own place in its own list, so marking never turns the pen yellow.
function nextColor()
  local tool = isHighlighter() and "highlighter" or "pen"
  index[tool] = index[tool] % #colors[tool] + 1
  app.changeToolColor({ color = colors[tool][index[tool]], tool = tool })
end
