
local enums = {
  gui_definition = {
    class_core = 1,
    class = 2,
    scope = 3,
    dynamic_list = 4,
  },
  gui_scope_level = {
    identifier = 1,
    any = 2,
  },
  state_change = {
    assigned = 1,
    removed = 2,
    inserted = 3,
    moved = 4,
  },
}

-- replace numbers with tables with metamethods to display
-- enum names instead of raw numbers
if __DebugAdapter then
  __DebugAdapter.defineGlobal("enums")
  _ENV["enums"..""] = enums -- for the variables view and debug console
  -- concat for it to not be considered a defined global

  for enum_name, values in pairs(enums) do
    local lookup = {}
    for k, v in pairs(values) do
      lookup[v] = k
    end
    local meta = {
      __debugline = function(enum_value)
        return "enums." .. enum_name .. "." .. lookup[enum_value.__value]
      end,
      __debugchildren = false,
      __debugtype = "number",
    }
    for value_name, value in pairs(values) do
      values[value_name] = setmetatable(
        {
          __value = value,
        },
        meta
      )
    end
  end
end

return enums
