
local enums = require("enums")
local gui_definition = enums.gui_definition
local gui_scope_level = enums.gui_scope_level
local gui_events = require("gui-events")
local ids = require("identifiers")
local state_util = require("state-util")

local mod_name = script.mod_name

local classes = {}
local class_cores = {}

local script_data
local instances




local function dynamic_list(raw_definition)
  -- TODO: probably needs changing
  raw_definition.definition_type = gui_definition.dynamic_list
  local list = raw_definition.list
  raw_definition.scope = list .. "[any]"
  raw_definition.on = list
  return raw_definition
end

local function dynamic(raw)
  -- TODO: impl
  raw.is_dynamic = true
  return raw
end



local parse_child

local function create_class_definition(class_core, child, parent_name, scopes_stack)
  local name = parent_name .. "." .. child.name
  local dynamic_values = {}
  local children = child.children or {}
  local events = child.events or {}
  local handlers = {}
  local tags = {
    class_name = name,
  }

  local class_definition = {
    name = name,
    definition_type = gui_definition.class,
    gui_element_definition = child,
    dynamic_values = dynamic_values,
    children = children,
    style_mods = child.style_mods,
    elem_mods = child.elem_mods,
    events = events,
    handlers = handlers,
    tags = tags,
    scopes_stack = scopes_stack,
  }
  classes[name] = class_definition

  for i = 1, #children do
    children[i] = parse_child(class_core, children[i], name, scopes_stack)
  end

  class_core.handlers[name] = handlers
  for event_name, handler in pairs(events) do
    handlers[gui_events[event_name]] = handler
  end

  -- remove data from the class just so the game has less to parse
  -- when creating the property tree when creating a new gui element
  child.name = nil
  child.children = nil
  child.style_mods = nil
  child.elem_mods = nil
  child.events = nil

  -- find all dynamic values
  do
    local key, value = next(child)
    while key do
      local nk, nv = next(child, key)
      if type(value) == "table" and value.is_dynamic then
        -- TODO: do something with it
        dynamic_values[key] = value
        child[key] = nil
      end
      key, value = nk, nv
    end
  end

  -- add tags for event handling
  child.tags = {
    __gui_plus = {
      [mod_name] = tags
    }
  }

  return class_definition
end

local function create_dynamic_list_definition(class_core, child, parent_name, scopes_stack)
  local name = parent_name .. "." .. child.name
  local scope = child.scope
  local scopes = {}
  local children = child.children or {}

  local dynamic_list_definition = {
    name = name,
    definition_type = gui_definition.dynamic_list,
    scope = scope,
    scopes = scopes,
    trigger = child.on,
    children = children,
  }

  local scopes_count = 0
  for id, special in string.gmatch(scope, ids.pattern) do
    local current_scope_level
    if special == ids.is_special then
      if id == "any" then
        current_scope_level = {
          scope_level_type = gui_scope_level.any,
        }
      else
        error("Unknown special id '" .. id .. "'.")
      end
    else
      current_scope_level = {
        scope_level_type = gui_scope_level.identifier,
        id = id,
      }
    end
    scopes_count = scopes_count + 1
    scopes[scopes_count] = current_scope_level
  end

  -- -- TODO: what was i even thinking
  -- -- i mean i know is was super distracted but what kind of mess is this?
  -- local scope_level = class_core.scopes
  -- for id, special in string.gmatch(scope, ids.pattern) do
  --   if special == ids.is_special then
  --     if id == "any" then
  --       local any = scope_level.any
  --       local new_scope_level = any
  --       if not new_scope_level then
  --         new_scope_level = {
  --           whatever = {},
  --           any = {
  --             whatever = {},
  --           },
  --           names = {},
  --         }
  --         any[id] = new_scope_level
  --       end
  --       scope_level = new_scope_level
  --     else
  --       error("Unknown special id '" .. id .. "'.")
  --     end
  --   else
  --     local names = scope_level.names
  --     local new_scope_level = names[id]
  --     if not new_scope_level then
  --       new_scope_level = {
  --         whatever = {},
  --         any = {
  --           whatever = {},
  --         },
  --         names = {},
  --       }
  --       names[id] = new_scope_level
  --     end
  --     scope_level = new_scope_level
  --   end

  --   scope_level.whatever[#scope_level.whatever+1] = dynamic_list_definition
  -- end

  local new_scope_stack = {}
  local scopes_stack_depth = #scopes_stack
  for i = 1, scopes_stack_depth do
    new_scope_stack[i] = scopes_stack[i]
  end
  new_scope_stack[scopes_stack_depth+1] = scopes

  for i = 1, #children do
    children[i] = parse_child(class_core, children[i], name, new_scope_stack)
  end

  return dynamic_list_definition
end

local function do_something_with_sub_classes(class_core, child, parent_name, scopes_stack)
  -- "child" is actually a sub class_core
  -- TODO: impl
  return child
end

local parse_child_definition_functions = {
  [gui_definition.dynamic_list] = create_dynamic_list_definition,
  [gui_definition.class_core] = do_something_with_sub_classes,
}

function parse_child(class_core, child, parent_name, scopes_stack)
  local definition_type = child.definition_type
  if definition_type then
    return parse_child_definition_functions[definition_type](
      class_core, child, parent_name, scopes_stack)
  end
  return create_class_definition(class_core, child, parent_name, scopes_stack)
end

local function register_class(class)
  local name = class.name
  local class_core = {
    name = name,
    definition_type = gui_definition.class_core,
    handlers = {},
    scopes = {
      -- whatever = {},
      -- any = {},
      names = {},
    },
  }
  class_cores[name] = class_core

  local scopes_stack = { -- stack
    { -- scopes
      { -- scope level
        scope_level_type = gui_scope_level.identifier,
        id = "state",
      },
    },
  }
  class_core.main_definition = create_class_definition(
    class_core,
    class,
    "sub_class",
    scopes_stack)

  return class_core
end

local build_child

local function build_class(instance, parent_element, class_definition)
  local gui_element_definition = class_definition.gui_element_definition

  -- TODO: add resolved dynamic values to the gui_element_definition

  -- modifying tags here is fine because nothing refers to it
  -- so we are desync save.
  class_definition.tags.instance_id = instance.instance_id

  local elem = parent_element.add(gui_element_definition)

  do
    local elem_mods = class_definition.elem_mods
    if elem_mods then
      for k, v in next, elem_mods do
        elem[k] = v
      end
    end
  end

  do
    local style_mods = class_definition.style_mods
    if style_mods then
      local style = elem.style
      for k, v in next, style_mods do
        style[k] = v
      end
    end
  end

  do
    local children = class_definition.children
    for i = 1, #children do
      build_child(instance, elem, children[i])
    end
  end

  return elem
end

local function build_dynamic_list(instance, parent_element, dynamic_list_definition)

end

local build_child_functions = {
  [gui_definition.class] = build_class,
  [gui_definition.dynamic_list] = build_dynamic_list,
}

function build_child(instance, parent_element, child_definition)
  -- TODO: convert this into a table lookup for the right build function
  -- continue here
  local definition_type = child_definition.definition_type
  if definition_type == gui_definition.class then
    return build_class(instance, parent_element, child_definition)
  elseif definition_type == gui_definition.dynamic_list then
    return build_dynamic_list(instance, parent_element, child_definition)
  end
end

local function instantiate(parent_elem, class_core, initial_state)
  local state, state_core = state_util.create_state(initial_state)
  local main_definition = class_core.main_definition
  local instance_id = #instances + 1
  local instance = {
    instance_id = instance_id,
    state = state,
    state_core = state_core,
    class_core_name = class_core.name,
    class_name = main_definition.name,
    -- elem = nil,
  }
  state_core.instance = instance
  instance.elem = build_class(instance, parent_elem, main_definition)
  instances[instance_id] = instance
  return instance
end

local function get_tags(elem)
  local tags = elem.tags
  local gui_plus = tags.__gui_plus
  return gui_plus and gui_plus[mod_name]
end

-- event handling

local function create_scopes(scopes_stack, state_core)
  local result = {}
  for _, scopes in pairs(scopes_stack) do
    local current_value_in_state = state_core
    for _, scope_level in pairs(scopes) do
      local scope_level_type = scope_level.scope_level_type
      if scope_level_type == gui_scope_level.identifier then
        current_value_in_state = current_value_in_state.__internal.data[scope_level.id]
        if not current_value_in_state then break end
      elseif scope_level_type == gui_scope_level.any then
        error("any is not supported yet") -- TODO: impl
      end
    end
    result[#result+1] = current_value_in_state
  end
  return result
end

local function handle_event(event)
  local elem = event.element
  if not elem then return end
  local tags = get_tags(elem)
  if not tags then return end

  local class_definition = classes[tags.class_name]
  local handler = class_definition.handlers[event.name]
  if not handler then return end

  -- TODO: get the scopes

  local instance = instances[tags.instance_id]
  local state = instance.state

  local scopes_stack = class_definition.scopes_stack
  local scopes = create_scopes(scopes_stack, instance.state_core)

  return handler(event, scopes, state)
end

local function register_event_handlers()
  local on_event = script.on_event
  for _, event_id in pairs(gui_events) do
    on_event(event_id, handle_event)
  end
end

local function on_init()
  instances = {}
  script_data = {
    instances = instances,
  }
  global.__gui_plus = script_data
end

local function on_load()
  script_data = global.__gui_plus
  instances = script_data.instances

  -- restore state metatables
  local restore_metatables = state_util.restore_metatables
  for _, instance in pairs(instances) do
    restore_metatables(instance.state)
  end
end

return {
  register_class = register_class,
  instantiate = instantiate,

  on_init = on_init,
  on_load = on_load,

  handle_event = handle_event,
  register_event_handlers = register_event_handlers,

  dynamic = dynamic,
  dynamic_list = dynamic_list,

  temp = {
    classes = classes,
    class_cores = class_cores,
  },
}
