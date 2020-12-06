
local enums = require("enums")
local state_change = enums.state_change

local meta
local hook

local function initial_hook(source)
  local core = {
    tables = {},
    changed_tables = {},
    __internal = { -- HACK: i do not like this one bit
      data = {
        state = source, -- TODO: define this key dynamically
      },
    },
  }
  return hook(source, core, {}, "state")
end

function hook(source, core, parent_location, key)
  local location = {}
  do -- copy parent_location
    local size = #parent_location
    for i = 1, size do
      location[i] = parent_location[i]
    end
    location[size+1] = key -- add latest key to the end
  end

  local internal_data = {}
  local internal = {
    core = core,
    location = location, -- location doesn't even make sense anymore. i don't even think i need it
    data = internal_data,
    -- lowest_changed_index = nil,
    changes = {},
    change_count = 0,
    fake = source, -- source will become the fake table
  }

  -- the fact that it's using the location table as the key is very questionable
  core.tables[location] = internal

  -- move data to internal_data
  local k, v = next(source)
  while k do
    local nk, nv = next(source, k)
    source[k] = nil
    internal_data[k] = v
    if type(v) == "table" then
      hook(v, core, location, k)
    end
    k, v = nk, nv
  end
  -- source is now the fake table

  source.__internal = internal
  setmetatable(source, meta)
  return source
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

  if type(value) == "table" then
    hook(value, internal.core, internal.location, pos)
  end

  local changes = internal.changes
  local change_count = internal.change_count + 1
  internal.change_count = change_count
  changes[change_count] = {
    type = state_change.inserted,
    key = pos,
    new = value,
  }
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

    if type(new_value) == "table" then
      hook(new_value, core, internal.location, key)
    end

    core.changed_tables[internal] = true

    local changes = internal.changes
    local change_count = internal.change_count + 1
    internal.change_count = change_count
    local internal_data = internal.data
    changes[change_count] = {
      type = state_change.inserted,
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
