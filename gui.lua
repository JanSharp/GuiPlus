
local gui_tags_hack = require("gui-tags-hack")

local function build(parent, structure)
  -- no more hacks, we got the real 1.1 !!!
  -- -- gui_tags_hack.hook(parent) -- since this is in a lib anyway, this can be replaced by a more performant version

  local elem = parent.add(structure)

  -- -- gui tags hack hooking, needed because the parent might not be hooked
  -- -- this is a better way to do it because the root parents (gui.center for example) never get hooked
  -- -- and them getting hooked is bad because those hooked elements - LuaObjects/tables - would never get cleaned up
  -- -- because they never go away, unless the player gets deleted (probably)
  -- if not gui_tags_hack.is_hooked(elem) then
  --   gui_tags_hack.hook(elem)
  --   local tags = structure.tags
  --   if tags then
  --     elem.tags = tags
  --   end
  -- end

  do
    local style_mods = elem.style_mods
    if style_mods then
      for k, v in pairs(style_mods) do
        elem[k] = v
      end
    end
  end

  do
    local style_mods = structure.style_mods
    if style_mods then
      local style = elem.style
      for k, v in pairs(style_mods) do
        style[k] = v
      end
    end
  end

  do
    local children = structure.children
    if children then
      for _, child_structure in pairs(children) do
        build(elem, child_structure)
      end
    end
  end

  return elem
end

return {
  build = build,
}
