---@mod hl_match_area
---@brief [[
---Provides a highlighting of the area between matching delimiters.
---The supported delimiters are '{}' '[]' '()' '<>'
---
---For example given this piece of "code" and cursor positioned on the first curly bracket plugin would highlight
---the whole are between '{' and '}'
--->
--- { 1, 2, 3, 4, 5 }
--- ^_______________^
---<
---
---The case of delimiters not being on the same line is also handled
---For example
--->
--- {
--- ^
---   1,
---_____
---   2,
---_____
---   3,
---_____
---   4,
---_____
---   5
---____
--- }
----^
---<
---@brief ]]

---@mod hl_match_area.Highlight
---@brief [[
---Highlight name is 'MatchArea' can be changed through 'vim.api.set_hl'
--->
---vim.api.nvim_set_hl(0, 'MatchArea', {bg = "#FFFFFF"})
---<
---@brief ]]

local NSID = vim.api.nvim_create_namespace("hl_match_area")
local HIGHLIGHT_NAME = "MatchArea"
local TIMER = nil

local should_clear_hl = false

local valid_chars_forward_search = {
  ["("] = true,
  ["["] = true,
  ["{"] = true,
  ["<"] = true,
}

local valid_chars_backward_search = {
  [")"] = true,
  ["]"] = true,
  ["}"] = true,
  [">"] = true,
}

local opposites = {
  ["{"] = "}",
  ["}"] = "{",

  ["["] = [[\]] .. "]",
  ["]"] = [[\]] .. "[",

  ["("] = ")",
  [")"] = "(",

  ["<"] = ">",
  [">"] = "<",
}

local function check(highlight_in_insert_mode, delay)
  if should_clear_hl then
    vim.api.nvim_buf_clear_namespace(0, NSID, 0, -1)
    should_clear_hl = false
  end

  if TIMER then
    TIMER:stop()
    TIMER = nil
  end

  if vim.fn.mode() == "i" and not highlight_in_insert_mode then
    return
  end

  local pos_to_hl, start_row, start_col, end_row, end_col
  local pos = vim.api.nvim_win_get_cursor(0)

  -- pos is (1,0)-indexed and set_extmark is 0 indexed
  local row = pos[1] - 1
  local col = pos[2]

  local cur_char = vim.api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]

  if valid_chars_forward_search[cur_char] then
    local end_char = opposites[cur_char]
    pos_to_hl = vim.fn.searchpairpos(cur_char, "", end_char, "nW")

    start_row = row
    start_col = col
    end_row = pos_to_hl[1] - 1
    end_col = pos_to_hl[2]
  elseif valid_chars_backward_search[cur_char] then
    local start_char = opposites[cur_char]
    pos_to_hl = vim.fn.searchpairpos(start_char, "", cur_char, "nbW")

    start_row = pos_to_hl[1] - 1
    start_col = pos_to_hl[2]
    end_row = row
    end_col = col
  else
    return
  end

  if vim.deep_equal(pos_to_hl, { 0, 0 }) then
    return
  end

  should_clear_hl = true
  TIMER = vim.loop.new_timer()

  TIMER:start(
    delay,
    0,
    vim.schedule_wrap(function()
      vim.api.nvim_buf_set_extmark(0, NSID, start_row, start_col, {
        end_row = end_row,
        end_col = end_col,
        hl_group = HIGHLIGHT_NAME,
      })
    end)
  )
end

local hl_match_area = {}

local DEFAULT_CONFIG = {
  delay = 100, -- in ms
  highlight_in_insert_mode = true,
}

---Setups and enables the plugin plugin with the provided config.
---Config has a following structure and purpose
--->
---{
---  n_lines_to_search: number -- how many lines should be searched for a matching delimiter
---  highlight_in_insert_mode: boolean, -- should highlighting also be done in insert mode
---  dealy: 100, -- delay in miliseconds to highlight
---}
---<
---
---Any of the values can be empty if so default config values are used.
---Default config values are as follows
--->
---  n_lines_to_search = 100,
---  highlight_in_insert_mode = true,
---  delay = 100,
---<
---@param user_config table
hl_match_area.setup = function(user_config)
  local augroup = "hl_match_area_augroup"
  local config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, user_config or {})

  if vim.fn.hlexists(HIGHLIGHT_NAME) == 0 then
    vim.api.nvim_set_hl(0, HIGHLIGHT_NAME, { bg = "#222277" })
  end

  vim.api.nvim_create_augroup(augroup, { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = augroup,
    callback = function()
      check(config.highlight_in_insert_mode, config.delay)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    group = augroup,
    callback = function()
      if should_clear_hl then
        TIMER:stop()
        TIMER = nil
        vim.api.nvim_buf_clear_namespace(0, NSID, 0, -1)
        should_clear_hl = false
      end
    end,
  })
end

return hl_match_area
