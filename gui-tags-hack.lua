
local script_data, is_script_data_initialized = {}, nil
do
  -- define name of the key this script_data is linked to in global
  local __global_sub_table_key = "__gui_tags_hack"

  local function __setup_sub_table()
    global[__global_sub_table_key] = global[__global_sub_table_key]
      or { -- define initial data format here
        hooked_elems = {},
        hooked_elem_indexes = {},
        all_tags = {},
      }
    script_data = global[__global_sub_table_key]
  end

  -- set a metatable on script_data, which will when accessed for the
  -- first time after a save got loaded/created replace script_data with
  -- a reference to the actual table in global.

  -- if that table in global does not exist yet, it will be initialized.
  -- this means scrip_data is only allowed to be accessed when
  -- modifying the game state is allowed

  -- there should be no references to this metatabled table
  -- other than in this file level local script_data
  -- because those would not get replaced, so every use of them
  -- results in a metatable lookup -> bad.
  setmetatable(script_data, {
    __index = function(_, k)
      __setup_sub_table()
      return script_data[k]
    end,
    __newindex = function(_, k, v)
      __setup_sub_table()
      script_data[k] = v
    end,
    __pairs = function(_) -- nobody needs this
      __setup_sub_table()
      return next, script_data, nil
    end,
  })

  -- have to check if it has been initialized before accessing script_data
  -- anywhere where modifying the game state/global is not allowed.
  -- for example in on_load
  function is_script_data_initialized()
    return global[__global_sub_table_key] ~= nil
  end
end
-- end script_data setup

-- locals

local util = require("util")

local next = next
local pairs = pairs
local type = type
local debug_getmetatable = debug.getmetatable
local debug_setmetatable = debug.setmetatable
local string_match = string.match
local util_copy = util.copy

-- general

local function is_lua_gui_element(value)
  return type(value) == "table" and value.object_name == "LuaGuiElement"
end

local function shallow_copy(t)
  local result = {}
  for k, v in pairs(t) do
    result[k] = v
  end
  return result
end

-- hooking

local function is_hooked(elem)
  return script_data.hooked_elems[elem] ~= nil
end

local function hook(elem)
  if not (elem and elem.valid) then return elem end

  local old_meta = debug_getmetatable(elem)
  if old_meta.__gui_tags_hack_hooked then return elem end -- do not double hook

  local elem_index = elem.index
  script_data.hooked_elems[elem] = elem -- have to set the value to the elem too, because
  -- when loading a save lua objects don't seem to get restored if they are a key of a table
  script_data.hooked_elem_indexes[elem] = elem_index -- required for unhook

  local meta = shallow_copy(old_meta)
  meta.__raw = old_meta
  meta.__gui_tags_hack_hooked = true

  meta.__index = function(t, k)
    if k == "tags" then
      return util_copy(script_data.all_tags[elem_index]) -- copy to better simulate game behavior
    elseif k == "add" then
      local add = old_meta.__index(t, k)
      return function(definition)
        local tags = definition.tags
        local new_elem = hook(add(definition))
        if tags then
          new_elem.tags = tags
        end
        return new_elem
      end
    elseif k == "children" then -- children require extra help because they are an array
      local children = old_meta.__index(t, k)
      for i = 1, #children do
        hook(children[i])
      end
      return children
    else
      local result = old_meta.__index(t, k)
      -- handle "parent", "drag_target" and [child_name] indexing
      if is_lua_gui_element(result) then
        return hook(result)
      end
      return result
    end
  end

  meta.__newindex = function(t, k, v)
    if k == "tags" then
      script_data.all_tags[elem_index] = util_copy(v) -- copy to better simulate game behavior
    else
      old_meta.__newindex(t, k, v)
    end
  end

  return debug_setmetatable(elem, meta)
end

-- also deletes tags on the element if it's invalid
local function unhook(elem)
  if elem then
    if not elem.valid then
      local index = script_data.hooked_elem_indexes[elem]
      script_data.all_tags[index] = nil
    end
    script_data.hooked_elems[elem] = nil
    script_data.hooked_elem_indexes[elem] = nil
  end
end

-- to be called every time when entering an event handler
-- for save load compatability
local function ensure_hooks()
  if is_script_data_initialized() then -- might be called in on_load
    local hooked_elems = script_data.hooked_elems
    local first_elem = next(hooked_elems)
    if first_elem and not debug_getmetatable(first_elem).__gui_tags_hack_hooked then
      for elem in pairs(hooked_elems) do
        hook(elem)
      end
    end
  end
end

-- remove invalid gui elements from script_data.hooked_elems
-- no way to automate this other than by periodically calling this function
local function cleanup()
  local hooked_elems = script_data.hooked_elems
  local elem = next(hooked_elems)
  while elem do
    if elem.valid then
      elem = next(hooked_elems, elem)
    else
      local prev = elem
      elem = next(hooked_elems, elem)
      unhook(prev)
    end
  end
end

-- script overrides

local gui_events = {}
for event_name, event_id in pairs(defines.events) do
  if string_match(event_name, "^on_gui") then
    gui_events[event_id] = true
  end
end

local on_event = script.on_event
script.on_event = function(event, handler, filters)
  if not handler then
    on_event(event, nil)
  end

  if gui_events[event] then -- gui events get elements that need to get hooked

    on_event(event, function(event_data)
      ensure_hooks()
      hook(event_data.element) -- hook handles nil
      return handler(event_data) -- tail call
    end, filters)

  else -- no other events get gui elements, so just ensure_hooks() and done

    on_event(event, function(event_data)
      ensure_hooks()
      return handler(event_data) -- tail call
    end, filters)

  end
end

local on_init = script.on_init
script.on_init = function(handler)
  if handler then
    on_init(function()
      ensure_hooks()
      return handler() -- tail call
    end)
  else
    on_init(nil)
  end
end

local on_load = script.on_load
script.on_load = function(handler)
  if handler then
    on_load(function()
      ensure_hooks()
      return handler() -- tail call
    end)
  else
    on_load(nil)
  end
end

local on_configuration_changed = script.on_configuration_changed
script.on_configuration_changed = function(handler)
  if handler then
    on_configuration_changed(function()
      ensure_hooks()
      return handler() -- tail call
    end)
  else
    on_configuration_changed(nil)
  end
end

-- HACK: this periodic cleanup is going to cause lag spikes
-- it should be spread out accross multiple ticks but that's
-- quite a bit more annoying to implement
local cleanup_interval = 60 * 60
local on_nth_tick = script.on_nth_tick
on_nth_tick(cleanup_interval, cleanup)

script.on_nth_tick = function(tick, handler)
  if handler then
    if tick == cleanup_interval then
      on_nth_tick(tick, function(event)
        cleanup()
        ensure_hooks()
        return handler(event) -- tail call
      end)
    else
      on_nth_tick(tick, function(event)
        ensure_hooks()
        return handler(event) -- tail call
      end)
    end
  else
    if tick == cleanup_interval then
      on_nth_tick(tick, cleanup)
    else
      on_nth_tick(tick, nil)
    end
  end
end

-- done

if __DebugAdapter then
  __DebugAdapter.stepIgnoreAll{
    is_script_data_initialized,
    is_lua_gui_element,
    shallow_copy,
    is_hooked,
    hook,
    unhook,
    ensure_hooks,
    cleanup,
    script.on_event,
    script.on_init,
    script.on_load,
    script.on_configuration_changed,
    script.on_nth_tick,
  }
end

return {
  is_hooked = is_hooked,
  hook = hook,
  unhook = unhook,
  ensure_hooks = ensure_hooks,
  cleanup = cleanup,
}
