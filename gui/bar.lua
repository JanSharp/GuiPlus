
-- -- new variables

-- local foo = "foo\nbar"
-- foo2 = 'foo\nbar'

-- local function bar() end
-- local bar2 = function() end

-- function baz() end
-- baz2 = function() end

-- -- using variables and parameters

-- local function do_stuff(number, func, ...)
--   local r = func(
--     foo,
--     foo2,
--     bar(),
--     baz(),
--     number,
--     string.dump(bar2, number),
--     ...)

--   if r == r then
--   elseif r ~= r then
--     for i = 1, 10, 1 do local _ = i end

--     for k, v in pairs(r) do local _ end

--     while true do local _ end
--   end

--   return r + r - r / r * r ^ r or r and not r
-- end
-- do_stuff()

-- -- tables

-- local tab = {
--   foo = 1,
--   bar = string.gsub,
--   ["other"] = false,
--   baz = {},
--   test = _G,
-- }

-- function tab.foo()
-- end

-- function tab:thing()
-- end

-- function tab.baz:bar()
--   local _ = self
-- end

-- -- indexing and calling

-- tab.foo(foo, bar)
-- tab.baz:bar()
-- tab.other.baz:bar()

-- --[[ other and multiline comment ]]

-- local str = "font ligatures => == ~= != >="
-- str = [===[ huge string ]===]



local gui = require("gui-plus")

local tostring = tostring

return gui.register_class{
  name = "bar",

  type = "frame",
  direction = "vertical",
  children = {
    {
      type = "table",
      name = "table",
      column_count = 2,
      children = {
        {
          type = "label",
          name = "key",
          caption = "key",
        },
        {
          type = "label",
          name = "value",
          caption = "value",
        },
        gui.dynamic_list{
          name = "list",
          list = "state.list",
          children = {
            {
              type = "label",
              name = "key",
              caption = gui.dynamic{
                on = "scopes[1].key",
                set = function(scopes, state)
                  return tostring(scopes[1].key)
                end,
              },
            },
            {
              type = "label",
              name = "value",
              caption = gui.dynamic{
                on = "scopes[1].value",
                set = function(scopes, state)
                  return scopes[1].value
                end,
              },
            },
          },
        },
      },
    },
  },
}
