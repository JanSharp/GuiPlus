
local enums = require("enums")
local state_change = enums.state_change

local meta
local hook_table
local hook_value
local unhook_internal

-- HACK: for debugging
local variables = require("__debugadapter__/variables.lua")
local vdescribe = variables.describe
local num = 0

local function add_locations(internal, parent_locations, key)
  for parent_location in pairs(parent_locations) do
    local location = {
      parent_location = parent_location,
    }
    do -- HACK: for debugging
      num = num + 1
      local num_str = "<" .. tostring(num) .. ">"
      local location_meta
      location_meta = {
        __debugline = function(_, short)
          if short then
            return num_str
          end
          setmetatable(location, nil)
          local lineitem = vdescribe(location)
          setmetatable(location, location_meta)
          return lineitem
        end,
      }
      setmetatable(location, location_meta)
    end
    do -- copy parent_location
      local size = #parent_location
      for i = 1, size do
        location[i] = parent_location[i]
      end
      location[size+1] = key -- add latest key to the end
    end

    local locations_for_parent_locations = internal.locations_for_parent_locations
    local locations_for_parent_location = locations_for_parent_locations[parent_location]
    if locations_for_parent_location then
      locations_for_parent_location[#locations_for_parent_location+1] = location
    else
      locations_for_parent_locations[parent_location] = {location}
    end

    internal.all_locations[location] = location
  end
end

local function remove_locations(internal, parent_locations, key)
  local all_locations = internal.all_locations
  local locations_to_remove = {}
  for parent_location in pairs(parent_locations) do
    local locations_for_parent_locations = internal.locations_for_parent_locations
    local locations = locations_for_parent_locations[parent_location]
    local count = #locations
    for i = count, 1, -1 do
      local location = locations[i]
      -- TODO: i'm pretty sure this can be imporived because you can't have the key twice,
      -- but it's so complex that i can't paint the whole picture in my head right now
      if location[#location] == key then
        locations_to_remove[location] = location
        all_locations[location] = nil
        table.remove(locations, i)
        count = count - 1
        if count == 0 then
          locations_for_parent_locations[parent_location] = nil
        end
      end
    end
  end

  local fake_to_internal = internal.core.fake_to_internal
  for child_key, child in pairs(internal.data) do
    local child_internal = fake_to_internal[child]
    if child_internal then
      remove_locations(child_internal, locations_to_remove, child_key)
    end
  end

  if internal.unhook_flag then
    unhook_internal(internal.fake, internal)
  end
end

local function initial_hook(source)
  -- local fake_parent = {}
  local core = {
    internal_tables = {}, -- interanl => true
    fake_to_internal = {}, -- fake => internal
    changed_tables = {}, -- internal => true
    __internal = { -- HACK: i do not like this one bit
      -- fake = fake_parent, -- even more disgusting
      data = {
        state = source, -- TODO: define this key dynamically
      },
    },
  }
  local location = {}
  return hook_table(source, core, {[location] = location}, "state")
end

function hook_table(source, core, all_parent_locations, key)
  local internal_data = {}
  local all_locations = {}
  local internal = {
    core = core,
    all_locations = {},
    locations_for_parent_locations = {},
    data = internal_data,
    -- lowest_changed_index = nil,
    changes = {},
    change_count = 0,
    fake = source, -- source will become the fake table
  }

  core.internal_tables[internal] = true
  core.fake_to_internal[source] = internal

  add_locations(internal, all_parent_locations, key)

  -- move data to internal_data
  local k, v = next(source)
  while k do
    local nk, nv = next(source, k)
    source[k] = nil
    internal_data[k] = v
    hook_value(v, core, source, all_locations, k)
    k, v = nk, nv
  end
  -- source is now the fake table

  source.__internal = internal
  setmetatable(source, meta)
  return source
end

function hook_value(value, core, all_parent_locations, key)
  local internal = core.fake_to_internal[value]
  if internal then
    return add_locations(internal, all_parent_locations, key)
  elseif type(value) == "table" then
    return hook_table(value, core, all_parent_locations, key)
  end
end

function unhook_internal(fake, internal)
  if not next(internal.all_locations) then
    local core = internal.core
    core.internal_tables[internal] = nil
    core.changed_tables[internal] = nil
    local fake_to_internal = core.fake_to_internal
    fake_to_internal[fake] = nil

    setmetatable(fake, nil)
    fake.__internal = nil

    -- move data back
    for k, v in pairs(internal.data) do
      fake[k] = v
      local child_internal = fake_to_internal[v]
      if child_internal then
        unhook_internal(v, child_internal) -- also unhook children
      end
    end
  else
    internal.unhook_flag = true
  end
end

local function unhook_table(fake)
  return unhook_internal(fake, fake.__internal)
end

-- TODO: maybe make pos optional, but it would be a waste of performace imo
-- because you can literally jsut use fake_list[#fake_list] = nil
-- or fake_list[#fake_list+1] = value instead

local table_remove = table.remove
local function remove(fake_list, pos)
end

local table_insert = table.insert
local function insert(fake_list, pos, value)
  local internal = fake_list.__internal
  do
    local lowest_changed_index = internal.lowest_changed_index
    if not lowest_changed_index or pos < lowest_changed_index then
      internal.lowest_changed_index = pos
    end
  end

  local core = internal.core

  hook_value(value, core, internal.all_locations, pos)

  local changes = internal.changes
  local change_count = internal.change_count + 1
  internal.change_count = change_count
  changes[change_count] = {
    type = state_change.inserted,
    key = pos,
    new = value,
  }

  local data = internal.data
  table_insert(data, pos, value)

  -- TODO: update to properly use locations_for_parent_locations

  -- update all locations past this key.
  -- this is as performant as it's going to get
  local tables = core.fake_to_internal
  for i = pos + 1, #data do
    local child = data[i]
    local child_internal = tables[child] -- this both checks if it's a table and gets the interanl table if it is one. it's beautiful
    if child_internal then
      local locations_for_parent_locations = child_internal.locations_for_parent_locations
      local location = locations_for_parent_locations[fake_list]
      location[#location] = i
    end
  end
  -- TODO: move this to gui.redraw, where the location is actually used/needed
end

local function detect_moves(changes) -- TODO: either this takes a changes table or a fake table
end

meta = {
  __len = function(current)
    return #current.__internal.data
  end,
  __pairs = function(current)
    return next, current.__internal.data, nil
  end,
  __index = function(current, key) -- can optimize this to use a table as the __index
    -- which would requrie a new metatable for every internal table
    -- might be worth doing, not sure yet
    return current.__internal.data[key]
    -- don't even need to check if it's a table because the itnernal data is storing tables as fake tables
  end,
  __newindex = function(current, key, new_value)
    local internal = current.__internal
    local core = internal.core

    local internal_data = internal.data
    local old_value = internal_data[key]
    if new_value ~= old_value then
      local all_locations = internal.all_locations
      hook_value(new_value, core, all_locations, key)

      local fake_to_internal = core.fake_to_internal
      local old_internal = fake_to_internal[old_value]
      if old_internal then
        remove_locations(old_internal, all_locations, key)
      end
    end

    core.changed_tables[internal] = true

    local changes = internal.changes
    local change_count = internal.change_count + 1
    internal.change_count = change_count
    changes[change_count] = {
      type = state_change.assigned,
      key = key,
      old = old_value,
      new = new_value, -- if it's a table, it's a fake table
    }
    internal_data[key] = new_value
  end,
}

local function create_state(initial_state)
  local state = initial_state or {}
  initial_hook(state)
  return state, state.__internal.core
end

local function restore_metatables(state)
  for _, internal in pairs(state.__internal.core.tables) do
    setmetatable(internal.fake, meta)
  end
end

-- undo the debugger being smart and using pairs, therefore __pairs for debugchildren
-- helps debugging the actual state while working on gui-plus
if __DebugAdapter and script.mod_name == "GuiPlus" then
  local variables = require("__debugadapter__/variables.lua")
  local vdescribe = variables.describe
  local vcreate = variables.create

  function meta.__debugline(current)
    setmetatable(current, nil)
    local lineitem = vdescribe(current)
    setmetatable(current, meta)
    return lineitem
  end

  function meta.__debugchildren(current)
    local children = {}
    local count = 1
    for k, v in next, current, nil do
      count = count + 1
      children[count] = vcreate(vdescribe(k), v)
    end
    return children
  end
end

return {
  create_state = create_state,
  restore_metatables = restore_metatables,
  unhook_table = unhook_table,
  remove = remove,
  insert = insert,
  detect_moves = detect_moves,
}
