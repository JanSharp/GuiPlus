
local enums = {
  ---@class EnumGuiDefinition
  gui_definition = {
    class_core = 1,
    class = 2,
    scope = 3,
    dynamic_list = 4,
  },
  ---@class EnumGuiScopeLevel
  gui_scope_level = {
    identifier = 1,
    any = 2,
  },
  ---@class EnumStateChange
  state_change = {
    assigned = 1,
    removed = 2,
    inserted = 3,
    moved = 4,
  },
}

-- replaces numbers with tables with metamethods to display enum names instead of raw numbers
-- puts the enums_table in global to make it accessible in the variables view and debug console
if __DebugAdapter and script.active_mods["JanSharpDevEnv"] then
  require("__JanSharpDevEnv__.enum-debug-util").hook_enums(enums, "enums")
end

return enums
