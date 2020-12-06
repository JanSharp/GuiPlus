
local pattern = "%.?%[?([a-zA-Z_][a-zA-Z0-9_]*)(%]?)"
local is_special = "]"

return {
  pattern = pattern,
  is_special = is_special,
}
