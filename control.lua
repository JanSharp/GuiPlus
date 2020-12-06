
local gui = require("gui-plus")

require("gui.register-classes")

local foo = require("gui.foo")
local test4 = require("gui.test4")

gui.register_event_handlers()

script.on_init(function()
  gui.on_init()
end)

script.on_load(function()
  gui.on_load()
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)

  local state = {
    list = {},
  }

  gui.instantiate(player.gui.screen, test4, state)

  gui.instantiate(player.gui.screen, foo, {count = 10})

  local test = {
    "hello",
    "world",
  }
  state.test = test
  test[1], test[2] = test[2], test[1]
  state.foo = test
  local breakpoint
  -- creating states is alarmingly slow
  -- creating 2 states, in the process hooking 4 tables and adding locations 5 times
  -- took almost as much time as creating 8 whole gui elements
  -- that's freaking terrible, is it not?
  -- and the reason it's so slow is just because it does so extremely much and creates so many tables
  -- to make it do less and therefore be faster
  -- i'd have to take away metatables and make the programmer use function calls for every single state manipulation,
  -- and it would still not make a huge difference. the biggest one would be that it doesn't have to do type checks
  -- anymore, but the __newindex itself doesn't even do all that much
  -- so no, that wouldn't even make it faster, especially not worth the trade off
  -- it might just be that state tracking like this is just not the way to go
  -- BUT, __newindex will have to do more in the future to detect tables no longer being used
  -- because right now as soon as a table is hooked it will never be released
  -- => memory leak
  -- and it will have to update locations... if it's not already doing that... i know it's partially doing it
  -- this will make everything even slower
end)

-- script.on_event(defines.events.on_player_created, function(event)
--   local player = game.get_player(event.player_index)

--   global.frame = gui.build(player.gui.screen, {
--     type = "frame",
--     name = "my_frame",
--     direction = "vertical",
--     caption = "test",
--     tags = {
--       foo = 100,
--     },
--     children = {
--       {
--         type = "label",
--         name = "my_label",
--         caption = "test",
--         tags = {
--           bar = 200,
--         },
--       },
--     },
--   })
-- end)

-- script.on_event(defines.events.on_tick, function(event)
--   local frame = global.frame
--   -- reading and writing tags
--   local frame_tags = frame.tags
--   frame_tags.foo = frame_tags.foo + 1
--   frame.tags = frame_tags

--   local label_tags = frame.my_label.tags -- even through child indexing

--   local breakpoint
-- end)

-- --[[
--   basically, as soon as a LuaGuiElement is hooked, it's stored in global
--   and will forever be hooked. Works with save load.

--   (It should work in multiplayer unless accessing LuaGuiElement.index
--   during on_load is not allowed - if tags_hack.ensure_hooks() is called
--   in on_load.)

--   Once hooked tags are available on it, and every LuaGuiElement gotten from
--   the element will also be hooked.

--   And calling .add() on a hooked elemnt allows settings tags as well

--   And it's only 150 lines, where 50 are copy pasted from my script_data setup thing
-- ]]
