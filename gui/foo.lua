
local gui = require("gui-plus")

return gui.register_class{
  name = "foo",

  type = "frame",
  direction = "vertical",
  children = {
    {
      type = "label",
      name = "label",
      caption = gui.dynamic{
        on = "state.count",
        set = function(scopes, state)
          return "count: " .. state.count
        end,
      },
    },
    {
      type = "flow",
      name = "flow",
      direction = "horizontal",
      children = {
        {
          type = "button",
          name = "decr",
          caption = "decr",
          events = {
            on_click = function(event, scopes, state)
              state.count = state.count - 1
              gui.redraw(state)
            end,
          },
        },
        {
          type = "button",
          name = "incr",
          caption = "incr",
          events = {
            on_click = function(event, scopes, state)
              state.count = state.count + 1
              gui.redraw(state)
            end,
          },
        },
      },
    },
  },
}
