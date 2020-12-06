
local gui_events = {}

for event_name, event_id in pairs(defines.events) do
  if string.find(event_name, "^on_gui") then
    gui_events[string.gsub(event_name, "^on_gui", "on", 1)] = event_id
  end
end

return gui_events
