
---@class State
---@field __internal StateInternal

---@alias StateFake State

---@class StateCore
---@field internal_tables table<StateInternal, true>
---@field fake_to_internal table<State, StateFake>
---@field changed_tables talbe<StateInternal, true>
---@field __internal StateCoreInternalHack

---@class StateCoreInternalHack
---@field all_locations table<StateLocation, StateLocation>
---@field data table<string, StateFake> @ contains a single key value pair. the value is the root of the entire state

---@class StateInternal
---@field core StateCore
---@field all_locations table<StateLocation, StateLocation>
---@field data table @ any table keys or values are StateFakes
---@field child_tables table<any, StateFake>
---@field changes StateChange[]
---@field change_count integer
---@field fake StateFake
---@field unhook_flag boolean @ should this table be unhooked as soon as it is no longer referenced anywhere

---@class StateLocation
---@field parent_location StateLocation
---@field children table<any, StateLocation> @ the key is the key used in the actual state for that location
