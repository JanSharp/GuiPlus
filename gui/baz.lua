
local gui = require("gui-plus")

return gui.register_class{
  class_name = "baz",

  type = "frame",
  direction = "vertical",
  children = {
    {
      type = "table",
      name = "table",
      column_count = 2,
      children = {
        gui.scope{
          name = "foo",
          scope = "state.foo",
          children = {
            {
              type = "label",
              name = "value",
              caption = gui.dynamic{
                on = "scopes[1].text",
                set = function(scopes, state, player_state)
                  return scopes[1].text
                end,
              }
            },
          },
        },
        gui.dynamic_list{
          name = "list",
          scope = "state.foo.list[index]",
          on = "state.foo.list",
          children = {
            {
              type = "textfield",
              name = "value",
              lose_focus_on_confirm = true,
              clear_and_focus_on_right_click = true,
              text = gui.dynamic{
                on = "scopes[1].text", -- expands to "state.foo.list[current_index_of_the_element_in_the_list].text"
                set = function(scopes, state)
                  return scopes[1].text
                end,
                compare_before_updating = true,
              },
              events = {
                on_text_changed = function(event, scopes, state)
                  scopes[1].text = event.text
                  gui.redraw(state)
                end,
              },
            },
            {
              type = "button",
              name = "remove",
              caption = "remove",
              events = {
                on_click = function(event, scopes, state)
                  gui.table.remove(state.foo.list, scopes[1].index)
                  gui.redraw(state)
                end,
              },
            },
          },
        },
      },
    },
    gui.dynamic_optional_child{
      on = gui.logical_or{
        "player_state.can_add",
        "state.foo.list",
      },
      condition = function(scopes, state, player_state)
        return player_state.can_add
          and (#state.foo.list < 10)
      end,
      child = {
        type = "button",
        name = "add",
        caption = "add",
        events = {
          on_click = function(event, scopes, state)
            local list = state.foo.list
            list[#list+1] = {
              text = "new",
            }
            gui.redraw(state)
          end,
        },
      },
    },
  },
}
