
-- test code used to see what happens when a style prototype currently used for
-- a LuaGuiElement no longer exists
-- result:
-- it resets the style to the default style, i'm assuming any control time modifications
-- to the style also get reset but this is not something i need to find out

-- local styles = data.raw["gui-style"]["default"]

-- default_glow_color = {225, 177, 106, 255}
-- default_shadow_color = {0, 0, 0, 0.35}

-- function default_glow(tint_value, scale_value)
--   return
--   {
--     position = {200, 128},
--     corner_size = 8,
--     tint = tint_value,
--     scale = scale_value,
--     draw_type = "outer"
--   }
-- end

-- default_shadow = default_glow(default_shadow_color, 0.5)

-- styles.GuiPlus_test2 = {
--   type = "button_style",
--   width = 20,
--   height = 12,
--   padding = 0,
--   default_graphical_set =
--   {
--     base = {position = {64, 48}, size = {40, 24}},
--     shadow = default_shadow
--   },
--   hovered_graphical_set =
--   {
--     base = {position = {144, 48}, size = {40, 24}},
--     glow = default_glow(default_glow_color, 0.5)
--   },
--   clicked_graphical_set =
--   {
--     base = {position = {184, 48}, size = {40, 24}},
--     shadow = default_shadow
--   },
--   disabled_graphical_set =
--   {
--     base = {position = {104, 48}, size = {40, 24}},
--     shadow = default_shadow
--   },
--   left_click_sound = {{ filename = "__core__/sound/gui-click.ogg", volume = 1 }}
-- }
