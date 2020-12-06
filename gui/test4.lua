
local gui = require("gui-plus")
local dynamic_gui = require("dynamic-gui")
local enums = require("enums")
local state_change = enums.state_change

return gui.register_class{
  name = "test4",

  type = "frame",
  direction = "vertical",
  caption = "test4",

  children = {
    {
      type = "table",
      name = "table",
      column_count = 3,
      children = {
        gui.dynamic_list{
          name = "list",
          list = "state.list",
          -- scope = list .. "[any]"
          -- on = list

          update = function(self, sub_definitions, scopes, state)
            local list = scopes[1].parent -- parent and key might as well exist for everything, except for the lowest scope, which is equal to the root state and therefore has no parent
            local data = self.data

            if dynamic_gui.is_new(list) then

              -- create all children
              for key, value in pairs(list) do
                value.any_key = key
                local elem_insts = {}
                data[key] = elem_insts
                local inst_count = 0
                for _, definition in pairs(sub_definitions) do
                  inst_count = inst_count + 1
                  elem_insts[inst_count] = dynamic_gui.build(self, definition)
                end
              end

            elseif list == nil then

              -- remove all children
              for _, elem_insts in pairs(data) do
                for _, inst in pairs(elem_insts) do
                  dynamic_gui.destroy(inst)
                end
              end

            else

              -- create new elements
              -- remove old elements
              -- update indexes

              local changes = dynamic_gui.get_changes(list)
              local removed = {}
              local added = {}
              local sub_definition_count = #sub_definitions

              for _, change in pairs(changes) do
                local change_type = change.type
                if change_type == state_change.assigned then -- probably the most common

                  -- this can both remove and add stuff, smile deal with it last

                elseif change_type == state_change.inserted then -- second most common?

                  -- TODO: check if it's removed
                  added[change.new] = change.key

                else -- removed

                  local elem = change.old
                  local added_key = added[elem]
                  if added_key ~= nil then -- it got relocated!
                    local key = change.key
                    if added_key ~= key then
                      -- move it, somehow?
                      local elem_instns = data[key]
                      -- change their index in the parent gui element
                      local target_base_index = (added_key - 1) * sub_definition_count
                      -- TODO: continue here
                      dynamic_gui.set_index()
                    end
                    added[elem] = nil
                  else
                    removed[elem] = change.key
                  end

                end

                -- now lets make this even more fun
                -- someone can have the same instance of a table
                -- as the value for multiple keys in the list
                -- what does THAT even mean for me now?
                -- i think i actually just don't care
                -- becase as a matter of fact
                -- well i was going to say if i find the same instance as both being added and removed
                -- that means the elements look the same
                -- but no! they could look completely differently, because the index was different for them
                -- and they can use that to look different
                -- that means i'd have to mark their index as "updated"
                -- that would be ideal
                -- but i initially said that the dynamic objects are not allowed to modify the state anymore
                -- well they aren't modifying the state in this case actually
                -- they would be modifyihng the _changes_, which is different
                -- but changes are updated from lowest to highest level (state comes before state.list, and so on)
                -- that means dynamic_objects are only allowed to modify the changes of states above them
                -- i don't think i can validate that without wasting performance though, so the programmer would just
                -- have to read the docs and not be stupid
                -- so how to mark something as changed?
                -- ha, funny, it's not just marking it as changed, it's literally changing the index
                -- no need for extra syntax for it
                -- but that only applies if i don't do something about the current any_key implementation
                -- so i guess i have to deal with that now


                local old, new = change.old, change.new

                -- example
                local example_list
                local example_chanages

                example_list = {
                  [1] = {text = "hello", any_key = 1},
                  [2] = {text = "world", any_key = 2},
                  [3] = {text = "foo  ", any_key = 3},
                  [4] = {text = "bar  ", any_key = 4},
                }
                example_chanages = {}

                gui.table.remove(example_list, 2)

                example_list = {
                  [1] = {text = "hello", any_key = 1},
                  [2] = {text = "foo  ", any_key = 3},
                  [3] = {text = "bar  ", any_key = 4},
                }
                example_chanages = {
                  {
                    type = state_change.removed,
                    key = 2,
                    old = {text = "world", any_key = 2},
                  },
                }

                example_list[2] = {text = "other"}

                example_list = {
                  [1] = {text = "hello", any_key = 1},
                  [2] = {text = "other"},
                  [3] = {text = "bar  ", any_key = 4},
                }
                example_chanages = {
                  {
                    type = state_change.removed,
                    key = 2,
                    old = {text = "world", any_key = 2},
                  },
                  {
                    type = state_change.assigned,
                    key = 2,
                    old = {text = "foo  ", any_key = 3},
                    new = {text = "other"},
                  },
                }

                -- there is basically no way to be smart about this and group changes together into a single change
                -- then again how common is it going to be for someone to assign a value to the same key twice between redraws

                -- where is the problem...
                -- 2) is it possible for dynamic_list update to be smart and detect moves?
                -- i can't think of a way to do that elegantly. i'll just have to resort to requrieing the programmer to use gui.table.move()
                -- but i really don't like that.

                -- for example
                example_list[2], example_list[3] = example_list[3], example_list[2]
                -- is the common way to swap elements
                example_list[3] = example_list[2]
                example_list[2] = nil
                -- of that to move the last element up and remove the second last one
                example_list[4] = example_list[2]
                gui.table.remove(example_list, 2)
                -- or that
                -- it doesn't matter what you're doing, introducing new functions to do the same thing you're alreadly used to doing
                -- in some other way is just bad. it forces the programmer to solve the same problem they already solved again
                -- just bad, bad, bad.
                -- so even if i hate it, i need to detect element relocation
                -- the other option is to just delete and recreate the elements, but what's the point in that.
                -- that is explicitly not using the new and amazing api features (being able to set the index of LuaGuiElements)

                -- alright, all cool and all, but there is one thing missing
                -- change detection
                -- the key might change through gui.table.insert or remove calls
                -- however, those functions only ever affect all elements after them
                -- this is detectable by storing the lowest key on the internal table, which gets set by those functions
                -- then the framework has to go through every single one and check if the index for the element changed
                -- how does it know the previous index?
                -- it might have to update all dynamic values dependent on the key
                -- but is there some way?
                -- i really don't think there is
                -- besides, if you use remove or insert, the index/key usually changed, so it would in most cases actually
                -- be a waste of performance to compare it with the previous index
                -- every other index change is tracked through the __newindex metamethod

                -- can i just say that lists are really annoying? because they are
                -- but without them this framework is useless
                -- but i'm getting there

              end

            end
          end,

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
              -- this won't compare, because it's probably faster that way
              -- would require testing, but the difference would be tiny if even measurable
            },
            {
              type = "textfield",
              name = "value",
              lose_focus_on_confirm = true,
              clear_and_focus_on_right_click = true,
              text = gui.dynamic{
                on = "scopes[1].value.text", -- expands to "state.list[any].text"
                set = function(scopes, state)
                  return scopes[1].value.text
                end,
                compare_before_updating = true,
              },
              events = {
                on_text_changed = function(event, scopes, state)
                  scopes[1].value.text = event.text
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
                  local list_scope = scopes[1]
                  gui.table.remove(list_scope.parent, list_scope.key)
                  gui.redraw(state)
                end,
              },
            },
            -- gui.dynamic_switch{
            --   name = "lol",
            --   on = "scopes[1]",
            --   switch = function(scopes, state)
            --     local list_scope = scopes[1]
            --     local key = list_scope.key
            --     if key == 1 then
            --       if key == #list_scope.parent then
            --         return "single"
            --       else
            --         return "first"
            --       end
            --     elseif key == #list_scope.parent then
            --       return "last"
            --     else
            --       return "middle"
            --     end
            --   end,
            --   children = {
            --     {name = "single"},
            --     {name = "first"},
            --     {name = "middle"},
            --     {name = "last"},
            --   },
            -- },
          },
        },
      },
    },
    {
      type = "button",
      name = "add",
      caption = "add",
      events = {
        on_click = function(event, scopes, state)
          local list = state.list
          list[#list+1] = {
            text = "new",
          }
          gui.redraw(state)
        end,
      },
    },
  },
}
