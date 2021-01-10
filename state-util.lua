
local enums = require("enums")
local state_change = enums.state_change

local table_remove = table.remove
local table_insert = table.insert

local meta
local hook_table
local hook_value
local unhook_internal

-- this is slow-ish because it has to copy the parent location tables
-- what? why is the main loop so much slower
-- and why is it showing 180 while the actual copy only copied 80 times
-- i think it's 20 + 80 + 80
-- and it's slow because... because next() probably

---@param internal StateInternal
---@param parent_locations StateAllLocations
---@param key any
local function add_locations(internal, parent_locations, key)
  local all_locations = internal.all_locations
  local new_locataions = {}

  for parent_location in next, parent_locations do
    local location = {
      parent_location = parent_location,
      children = {},
    }
    do -- copy parent_location
      local size = #parent_location
      for i = 1, size do
        location[i] = parent_location[i]
      end
      location[size+1] = key -- add latest key to the end
    end

    all_locations[location] = location
    new_locataions[location] = location
    parent_location.children[key] = location
  end

  -- add the new location to all sub tables as well
  for child_key, child_table in next, internal.child_tables do
    add_locations(child_table.__internal, new_locataions, child_key)
  end
end

---@param internal StateInternal
---@param parent_locations StateAllLocations
---@param key any
local function remove_locations(internal, parent_locations, key)
  local all_locations = internal.all_locations
  local locations_to_remove = {}
  for parent_location in next, parent_locations do
    local children = parent_location.children
    local location = children[key]
    locations_to_remove[location] = location
    children[key] = nil
    all_locations[location] = nil
  end

  for child_key, child_table in next, internal.child_tables do
    remove_locations(child_table.__internal, locations_to_remove, child_key)
  end

  if internal.unhook_flag then
    unhook_internal(internal.fake, internal)
  end
end

---@param location StateLocation
---@param level_to_update integer
---@param new_key any
local function update_child_locations(location, level_to_update, new_key)
  for _, child_location in next, location.children do
    child_location[level_to_update] = new_key
    update_child_locations(child_location, level_to_update, new_key)
  end
end

---@param source table
---@param source_name string
---@return StateFake
local function initial_hook(source, source_name)
  local location = {children = {}}
  local all_locations = {[location] = location}
  local core = {
    internal_tables = {},
    fake_to_internal = {},
    changed_tables = {},

    __internal = { -- HACK: i do not like this one bit, but it helps keep things generic
      all_locations = all_locations,
      data = {
        [source_name] = source,
      },
    },
  }
  return hook_table(source, core, all_locations, source_name)
end

---@param source table
---@param core StateCore
---@param all_parent_locations StateAllLocations
---@param key any
---@return StateFake @ the table source gets modified to become this return value
function hook_table(source, core, all_parent_locations, key)
  local internal_data = {}
  local all_locations = {}
  local internal = {
    core = core,
    all_locations = all_locations,
    data = internal_data,
    child_tables = {},
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
    hook_value(v, core, internal, all_locations, k)
    k, v = nk, nv
  end
  -- source is now the fake table

  source.__internal = internal
  setmetatable(source, meta)
  return source
end

---@param value any
---@param core StateCore
---@param parent StateInternal
---@param all_parent_locations StateAllLocations
---@param key any
---@return nil | StateFake
function hook_value(value, core, parent, all_parent_locations, key)
  local internal = core.fake_to_internal[value]
  if internal then
    parent.child_tables[key] = value
    return add_locations(internal, all_parent_locations, key)
  elseif type(value) == "table" then
    parent.child_tables[key] = value
    return hook_table(value, core, all_parent_locations, key)
  end
end

---@param fake StateFake
---@param internal StateInternal
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
    for k, v in next, internal.data do
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

---@param fake StateFake
---@return nil
local function unhook_table(fake)
  return unhook_internal(fake, fake.__internal)
end

---@param internal StateInternal
---@param start_pos integer
---@param end_pos integer
---@param direction integer | "1" | "-1" @ iteration direction
local function update_positions_in_child_tables_and_location_children(internal, start_pos, end_pos, direction)
  -- maybe all of this can be done in gui.redraw where locations are actually used
  -- but i don't really think so
  local child_tables = internal.child_tables
  local all_locations = internal.all_locations
  for i = start_pos, end_pos, direction do
    local target_i = i - direction
    child_tables[target_i] = child_tables[i]

    for location in next, all_locations do
      local children = location.children
      local child_location = children[i]
      if child_location then
        children[target_i] = child_location
        local level_to_update = #location+1
        child_location[level_to_update] = target_i
        update_child_locations(child_location, level_to_update, target_i)
      else
        children[target_i] = nil
      end
    end
  end
  for location in next, all_locations do
    location.children[end_pos] = nil
  end
end

---@param fake_list StateFake
---@param pos integer
---@return any @ the removed value
local function remove(fake_list, pos)
  local internal = fake_list.__internal
  do
    local lowest_changed_index = internal.lowest_changed_index
    if not lowest_changed_index or pos < lowest_changed_index then
      internal.lowest_changed_index = pos
    end
  end
  local data = internal.data

  -- add change
  local changes = internal.changes
  local change_count = internal.change_count + 1
  internal.change_count = change_count
  changes[change_count] = {
    type = state_change.removed,
    key = pos,
    old = data[pos],
  }

  update_positions_in_child_tables_and_location_children(internal, pos + 1, #data, 1)

  return table_remove(data, pos)
end

---@param fake_list StateFake
---@param pos integer
---@param value any
---@return nil
local function insert(fake_list, pos, value)
  local internal = fake_list.__internal
  do
    local lowest_changed_index = internal.lowest_changed_index
    if not lowest_changed_index or pos < lowest_changed_index then
      internal.lowest_changed_index = pos
    end
  end
  local data = internal.data

  -- add change
  local changes = internal.changes
  local change_count = internal.change_count + 1
  internal.change_count = change_count
  changes[change_count] = {
    type = state_change.inserted,
    key = pos,
    new = value,
  }

  update_positions_in_child_tables_and_location_children(internal, #data, pos, -1)

  hook_value(value, internal.core, internal, internal.all_locations, pos)

  return table_insert(data, pos, value)
end

---@param fake StateFake
---@return StateChange
---@return integer @ change_count
local function get_changes(fake)
  local internal = fake.__internal
  return internal.changes, internal.change_count
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
    -- don't even need to check if it's a table because the internal data is storing tables as fake tables
  end,
  __newindex = function(current, key, new_value)
    local internal = current.__internal
    local core = internal.core

    local internal_data = internal.data
    local old_value = internal_data[key]
    if new_value ~= old_value then
      local all_locations = internal.all_locations
      hook_value(new_value, core, internal, all_locations, key)

      local fake_to_internal = core.fake_to_internal
      local old_internal = fake_to_internal[old_value]
      if old_internal then
        internal.child_tables[key] = nil
        remove_locations(old_internal, all_locations, key)
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
    end
  end,
}

---@param initial_state table
---@param state_name string @ the name associated with the root of the state/initial_state
---@return StateFake
---@return StateCore
local function create_state(initial_state, state_name)
  local state = initial_state or {}
  initial_hook(state, state_name or "state")
  return state, state.__internal.core
end

---@param state StateFake
local function restore_metatables(state)
  for _, internal in next, state.__internal.core.tables do
    setmetatable(internal.fake, meta)
  end
end

-- undo the debugger being smart and using pairs, therefore __pairs for debugchildren
-- helps debugging the actual state while working on gui-plus
if __DebugAdapter and script.mod_name == "GuiPlus" then
  local variables = require("__debugadapter__.variables")
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
    for k, v in next, current do
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
  get_changes = get_changes,
}
