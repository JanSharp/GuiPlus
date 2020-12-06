
local enums = require("enums")
local state_change = enums.state_change

local meta
local hook_table
local hook_value

local function add_location(internal, parent_fake, parent_location, key)
  local location = {}
  do -- copy parent_location
    local size = #parent_location
    for i = 1, size do
      location[i] = parent_location[i]
    end
    location[size+1] = key -- add latest key to the end
  end

  local locations_for_parent_fakes = internal.locations_for_parent_fakes
  local locations_for_parent_fake = locations_for_parent_fakes[parent_fake]
  if locations_for_parent_fake then
    locations_for_parent_fake[#locations_for_parent_fake+1] = location
  else
    locations_for_parent_fakes[parent_fake] = {location}
  end

  local all_locations = internal.all_locations
  all_locations[#all_locations+1] = location
  return location
end

local function initial_hook(source)
  local fake_parent = {}
  local core = {
    internal_tables = {}, -- interanl => true
    fake_to_internal = {}, -- fake => internal
    changed_tables = {}, -- internal => true
    __internal = { -- HACK: i do not like this one bit
      fake = fake_parent, -- even more disgusting
      data = {
        state = source, -- TODO: define this key dynamically
      },
    },
  }
  return hook_table(source, core, fake_parent, {}, "state")
end

function hook_table(source, core, parent_fake, parent_location, key)
  local internal_data = {}
  local internal = {
    core = core,
    all_locations = {},
    locations_for_parent_fakes = {},
    data = internal_data,
    -- lowest_changed_index = nil,
    changes = {},
    change_count = 0,
    fake = source, -- source will become the fake table
  }

  core.internal_tables[internal] = true
  core.fake_to_internal[source] = internal

  local location = add_location(internal, parent_fake, parent_location, key)

  -- move data to internal_data
  local k, v = next(source)
  while k do
    local nk, nv = next(source, k)
    source[k] = nil
    internal_data[k] = v
    hook_value(v, core, source, location, k)
    k, v = nk, nv
  end
  -- source is now the fake table

  source.__internal = internal
  setmetatable(source, meta)
  return source
end

function hook_value(value, core, parent_fake, parent_location, key)
  local internal = core.fake_to_internal[value]
  if internal then
    return add_location(internal, parent_fake, parent_location, key)
  elseif type(value) == "table" then
    return hook_table(value, core, parent_fake, parent_location, key)
  end
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

  -- HACK: using the first parent_location for now, but this won't actually do the trick
  hook_value(value, core, fake_list, internal.all_location[1], pos)

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

  -- TODO: update to properly use locations_for_parent_fakes

  -- update all locations past this key.
  -- this is as performant as it's going to get
  local tables = core.fake_to_internal
  for i = pos + 1, #data do
    local child = data[i]
    local child_internal = tables[child] -- this both checks if it's a table and gets the interanl table if it is one. it's beautiful
    if child_internal then
      local locations_for_parent_fakes = child_internal.locations_for_parent_fakes
      local location = locations_for_parent_fakes[fake_list]
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

    -- HACK: using the first parent_location for now, but this won't actually do the trick
    hook_value(new_value, core, current, internal.all_locations[1], key)

    core.changed_tables[internal] = true

    -- TODO: reminder to update locations of existing tables

    local changes = internal.changes
    local change_count = internal.change_count + 1
    internal.change_count = change_count
    local internal_data = internal.data
    changes[change_count] = {
      type = state_change.assigned,
      key = key,
      old = internal_data[key],
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
  remove = remove,
  insert = insert,
  detect_moves = detect_moves,
}
