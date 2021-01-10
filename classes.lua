
---@alias StateFake State
---@alias StateAllLocations table<StateLocation, StateLocation>

---@class State
---@field __internal StateInternal

---@class StateCore
---@field internal_tables table<StateInternal, true>
---@field fake_to_internal table<State, StateFake>
---@field changed_tables talbe<StateInternal, true>
---@field __internal StateCoreInternalHack

---@class StateCoreInternalHack
---@field all_locations StateAllLocations
---@field data table<string, StateFake> @ contains a single key value pair. the value is the root of the entire state

---@class StateInternal
---@field core StateCore
---@field all_locations StateAllLocations
---@field data table @ any table keys or values are StateFakes
---@field child_tables table<any, StateFake>
---@field changes StateChange[]
---@field change_count integer
---@field fake StateFake
---@field unhook_flag boolean | nil @ should this table be unhooked as soon as it is no longer referenced anywhere. Either true or nil

---@class StateLocation @ also acts as an any[] where the keys are the level/depth in the state and the value are the keys used at that level/depth
---@field parent_location StateLocation
---@field children table<any, StateLocation> @ the key is the key used in the actual state for that location

---@class StateChange
---@field type EnumStateChange
---@field key any
---@field old any | nil
---@field new any | nil
