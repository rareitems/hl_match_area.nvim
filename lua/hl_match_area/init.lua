---@mod hl_match_area.introduction Introduction
---@brief [[
---Provides a highlighting of the area between matching delimiters.
---The delimiters are specificed by |matchpairs| vim option.
---If you want to highlight specific characters and not rely on |matchpairs|, see |hl_match_area.Config|
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

---@private
---@type integer
local NSID = vim.api.nvim_create_namespace("hl_match_area")
---@private
---@type string
local HIGHLIGHT_NAME = "MatchArea"
---@private
---@type uv_timer_t?
local TIMER = nil

---@class Config
---@field delay number Delay in miliseconds to highlight
---@field highlight_in_insert_mode boolean If true highlight will also be done in insert mode
---@field matchpairs string[]|nil If you want to highlight specific characters and not rely on `vim.opt.matchpairs`. This should follow the same structure as `vim.opt.matchpairs:get` (example: `{"(:)", "{:}"}`)

---@mod hl_match_area.default_config Default Config
---@brief [[
---Default config values are as follows
--->
---  highlight_in_insert_mode = true,
---  delay = 100,
---<
---@brief ]]

local SHOULD_CLEAR_HL = false
local CACHED_MATCHPAIRS = {}

-- local valid_chars_forward_search = {
--     ["("] = true,
--     ["["] = true,
--     ["{"] = true,
--     ["<"] = true,
-- }
--
-- local valid_chars_backward_search = {
--     [")"] = true,
--     ["]"] = true,
--     ["}"] = true,
--     [">"] = true,
-- }
--
-- local opposites = {
--     ["{"] = "}",
--     ["}"] = "{",
--
--     ["["] = [[\]] .. "]",
--     ["]"] = [[\]] .. "[",
--
--     ["("] = ")",
--     [")"] = "(",
--
--     ["<"] = ">",
--     [">"] = "<",
-- }
--
-- local function find2()
--     local pos_to_hl, start_row, start_col, end_row, end_col
--     local pos = vim.api.nvim_win_get_cursor(0)
--
--     -- pos is (1,0)-indexed and set_extmark is 0 indexed
--     local row = pos[1] - 1
--     local col = pos[2]
--
--     local cur_char = vim.api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]
--
--     if valid_chars_forward_search[cur_char] then
--         local end_char = opposites[cur_char]
--         pos_to_hl = { 0, 0 }
--
--         start_row = row
--         start_col = col
--         end_row = pos_to_hl[1] - 1
--         end_col = pos_to_hl[2] -- -1 + 1 - searchpairpos is (1,1)-indexed, but end_col is exclusive
--     elseif valid_chars_backward_search[cur_char] then
--         local start_char = opposites[cur_char]
--         pos_to_hl = { 0, 0 }
--
--         start_row = pos_to_hl[1] - 1 -- searchpairpos is (1,1)-indexed
--         start_col = pos_to_hl[2] - 1 -- searchpairpos is (1,1)-indexed
--         end_row = row
--         end_col = col + 1 -- end_col is exclusive
--     else
--         return
--     end
--
--     return pos_to_hl, start_row, start_col, end_row, end_col
-- end

local function find()
    local pos_to_hl, start_row, start_col, end_row, end_col
    local pos = vim.api.nvim_win_get_cursor(0)

    -- pos is (1,0)-indexed and set_extmark is 0 indexed
    local row = pos[1] - 1
    local col = pos[2]

    local cur_char = vim.api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]

    for _, v in ipairs(CACHED_MATCHPAIRS) do
        local first = v:sub(1, 1)
        local opposite = v:sub(3, 3)

        if cur_char == first then
            local end_char = opposite
            if cur_char == "[" then
                cur_char = "\\["
                end_char = "\\]"
            end

            pos_to_hl = vim.fn.searchpairpos(cur_char, "", end_char, "nW", "", 0, 25)

            if pos_to_hl == nil then
                goto continue
            end

            start_row = row
            start_col = col
            end_row = pos_to_hl[1] - 1
            end_col = pos_to_hl[2] -- -1 + 1 - searchpairpos is (1,1)-indexed, but end_col is exclusive
            break
        elseif cur_char == opposite then
            local start_char = first
            if cur_char == "]" then
                cur_char = "\\]"
                end_char = "\\["
            end

            pos_to_hl = vim.fn.searchpairpos(start_char, "", cur_char, "nbW", "", 0, 25)

            if pos_to_hl == nil then
                goto continue
            end

            start_row = pos_to_hl[1] - 1 -- searchpairpos is (1,1)-indexed
            start_col = pos_to_hl[2] - 1 -- searchpairpos is (1,1)-indexed
            end_row = row
            end_col = col + 1            -- end_col is exclusive
            break
        end
        ::continue::
    end

    return pos_to_hl, start_row, start_col, end_row, end_col
end

local function check(highlight_in_insert_mode, delay)
    if SHOULD_CLEAR_HL then
        vim.api.nvim_buf_clear_namespace(0, NSID, 0, -1)
        SHOULD_CLEAR_HL = false
    end

    if TIMER then
        TIMER:stop()
        TIMER = nil
    end

    if vim.fn.mode() == "i" and not highlight_in_insert_mode then
        return
    end

    local pos_to_hl, start_row, start_col, end_row, end_col = find()

    if
        pos_to_hl == nil
        or start_row == nil -- if start_row is nill then rest is also nil
        or (pos_to_hl[1] == 0 and pos_to_hl[2] == 0)
    then
        return
    end

    TIMER = vim.loop.new_timer()
    TIMER:start(
        delay,
        0,
        vim.schedule_wrap(function()
            local status, err =
                pcall(vim.api.nvim_buf_set_extmark, 0, NSID, start_row, start_col, {
                    end_row = end_row,
                    end_col = end_col,
                    hl_group = HIGHLIGHT_NAME,
                })
            if not status then
                -- error(err)
            end
        end)
    )
    SHOULD_CLEAR_HL = true
end

local hl_match_area = {}

---Setups and enables the plugin plugin with the provided config. See |hl_match_area.Config| for structure of the config
---@param user_config table
hl_match_area.setup = function(user_config)
    local default_config = {
        delay = 100, -- in ms
        highlight_in_insert_mode = true,
    }
    user_config = user_config or {}
    local config = vim.tbl_deep_extend("force", default_config, user_config)

    if vim.fn.hlexists(HIGHLIGHT_NAME) == 0 then
        vim.api.nvim_set_hl(0, HIGHLIGHT_NAME, { bg = "#222277" })
    end

    local augroup = "hl_match_area_augroup"
    vim.api.nvim_create_augroup(augroup, { clear = true })

    if user_config.matchpairs then
        CACHED_MATCHPAIRS = user_config.matchpairs
    else
        CACHED_MATCHPAIRS = vim.opt.matchpairs:get()
        vim.api.nvim_create_autocmd("OptionSet", {
            pattern = "matchpairs",
            callback = function()
                CACHED_MATCHPAIRS = vim.opt.matchpairs:get()
            end,
        })
    end

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = augroup,
        callback = function()
            check(config.highlight_in_insert_mode, config.delay)
        end,
    })

    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
        group = augroup,
        callback = function()
            if SHOULD_CLEAR_HL then
                assert(TIMER)
                TIMER:stop()
                TIMER = nil
                vim.api.nvim_buf_clear_namespace(0, NSID, 0, -1)
                SHOULD_CLEAR_HL = false
            end
        end,
    })
end

---Forcibly recache cached matchpairs inside the plugin
hl_match_area.recache_matchpairs = function()
    CACHED_MATCHPAIRS = vim.opt.matchpairs:get()
end

return hl_match_area
