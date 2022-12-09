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
local AUGROUP = "hl_match_area_augroup"
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

  ["["] = "]",
  ["]"] = "[",

  ["("] = ")",
  [")"] = "(",

  ["<"] = ">",
  [">"] = "<",
}

local function check(lines_to_search, highlight_in_insert_mode, delay)
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

  local pos = vim.api.nvim_win_get_cursor(0)
  local row = pos[1] - 1 -- pos is (1,0)-indexed and nvim_buf_get_text is 0 indexed
  local col = pos[2]

  local pos_to_hl = {}
  local has_found_match = false

  local char_under_cursor = vim.api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]

  if valid_chars_forward_search[char_under_cursor] then
    local opposite = opposites[char_under_cursor]
    local dont_count_next_n = 0

    local lines = vim.api.nvim_buf_get_lines(0, row, row + lines_to_search, false)
    assert(#lines <= lines_to_search, "too much " .. #lines)

    -- first line
    local not_has_found_on_first_line = true
    local first_line = lines[1]
    if first_line == nil then
      return
    end
    local x = first_line:sub(col + 1, col + 1)
    assert(x == char_under_cursor, "not the same char, had " .. x)

    for i = col + 2, #first_line do
      local cur_char = first_line:sub(i, i)

      if cur_char == char_under_cursor then
        dont_count_next_n = dont_count_next_n + 1
        goto continue
      end

      if cur_char == opposite and dont_count_next_n == 0 then
        table.insert(pos_to_hl, { row, col, i })
        not_has_found_on_first_line = false
        has_found_match = true
        break
      end

      if cur_char == opposite and dont_count_next_n ~= 0 then
        dont_count_next_n = dont_count_next_n - 1
      end

      ::continue::
    end

    if not_has_found_on_first_line then
      table.insert(pos_to_hl, { row, col, #first_line })
      for i = 2, #lines do
        local cur_line_index = row + i
        -- local start_pos = nil
        local end_pos = nil

        local cur_line = lines[i]

        for j = 1, #cur_line do
          local cur_char = cur_line:sub(j, j)

          if cur_char == char_under_cursor then
            dont_count_next_n = dont_count_next_n + 1
            goto continue
          end

          if cur_char == opposite and dont_count_next_n == 0 then
            end_pos = j
            has_found_match = true
            break
          end

          if cur_char == opposite and dont_count_next_n ~= 0 then
            dont_count_next_n = dont_count_next_n - 1
          end

          ::continue::
        end

        if end_pos == nil then
          table.insert(pos_to_hl, { cur_line_index - 1, 0, #cur_line })
        else
          table.insert(pos_to_hl, { cur_line_index - 1, 0, end_pos })
        end

        if has_found_match then
          break
        end
      end
    end
  end

  if valid_chars_backward_search[char_under_cursor] then
    local opposite = opposites[char_under_cursor]
    local dont_count_next_n = 0

    local lines
    if row - lines_to_search + 1 < 0 then
      lines = vim.api.nvim_buf_get_lines(0, 0, row + 1, false)
    else
      lines = vim.api.nvim_buf_get_lines(0, row - lines_to_search + 1, row + 1, false)
    end
    assert(#lines <= lines_to_search, "too much " .. #lines)

    -- first line
    local not_has_found_on_first_line = true
    local first_line = lines[#lines]
    local x = first_line:sub(col + 1, col + 1)
    assert(x == char_under_cursor, "not the same char, had " .. x)

    for i = col, 1, -1 do
      local cur_char = first_line:sub(i, i)

      if cur_char == char_under_cursor then
        dont_count_next_n = dont_count_next_n + 1
        goto continue
      end

      if cur_char == opposite then
        if dont_count_next_n == 0 then
          table.insert(pos_to_hl, { row, i - 1, col + 1 })
          not_has_found_on_first_line = false
          has_found_match = true
          break
        else
          dont_count_next_n = dont_count_next_n - 1
        end
      end

      ::continue::
    end

    if not_has_found_on_first_line then
      table.insert(pos_to_hl, { row, 0, col }) -- highlighting the line the cursor is currently on

      local line_offset = -1 -- -1 because of 0 indexing later in nvim_buf_add_highlight
      for i = #lines - 1, 1, -1 do
        line_offset = line_offset + 1
        local cur_line_index = row - line_offset
        local start_pos = nil
        -- local end_pos = nil

        local cur_line = lines[i]

        for j = #cur_line, 1, -1 do
          local cur_char = cur_line:sub(j, j)

          if cur_char == char_under_cursor then
            dont_count_next_n = dont_count_next_n + 1
            goto continue
          end

          if cur_char == opposite then
            if dont_count_next_n == 0 then
              start_pos = j
              has_found_match = true
              break
            else
              dont_count_next_n = dont_count_next_n - 1
            end
          end

          ::continue::
        end

        if start_pos == nil then
          table.insert(pos_to_hl, { cur_line_index - 1, 0, #cur_line })
        else
          table.insert(pos_to_hl, { cur_line_index - 1, start_pos - 1, #cur_line })
        end

        if has_found_match then
          break
        end
      end
    end
  end

  if has_found_match and #pos_to_hl ~= 0 then
    should_clear_hl = true
    TIMER = vim.loop.new_timer()
    TIMER:start(
      delay,
      0,
      vim.schedule_wrap(function()
        for _, it in ipairs(pos_to_hl) do
          vim.api.nvim_buf_add_highlight(0, NSID, HIGHLIGHT_NAME, it[1], it[2], it[3])
        end
      end)
    )
  end
end

local hl_match_area = {}

local DEFAULT_CONFIG = {
  n_lines_to_search = 100,
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
  local config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, user_config or {})

  if vim.fn.hlexists(HIGHLIGHT_NAME) == 0 then
    vim.api.nvim_set_hl(0, HIGHLIGHT_NAME, { bg = "#222277" })
  end

  vim.api.nvim_create_augroup(AUGROUP, { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = AUGROUP,
    callback = function()
      check(config.n_lines_to_search, config.highlight_in_insert_mode, config.delay)
    end,
  })

  vim.api.nvim_create_autocmd({ "WinLeave" }, {
    group = AUGROUP,
    callback = function()
      if should_clear_hl then
        vim.api.nvim_buf_clear_namespace(0, NSID, 0, -1)
        should_clear_hl = false
      end
    end,
  })
end

return hl_match_area
