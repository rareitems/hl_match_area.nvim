<h1 align='center'>hl_match_area.nvim</h1>
Neovim plugin that allows highlighting the whole area between matching delimiters ('{}' '[]' '()' '<>')

## Installation

- With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use { 'rareitems/hl_match_area.nvim' }
```

## Usage

Simply call the following function somewhere in your config

```lua
  require("hl_match_area").setup({
        highlight = { bg = "#222277" }, -- what highlight should be used see
                                        -- this is a default value
  })
```

If you don't provide any arguments to the setup function, default values will be used, which are as follows (obviously you can also change them)

```lua
{
    n_lines_to_search = 100 -- how many lines should be searched for a matching delimiter
    highlight = { bg = "#222277" }, -- what highlight should be used see
    highlight_in_insert_mode = true, -- should highlighting also be done in insert mode
}
```
