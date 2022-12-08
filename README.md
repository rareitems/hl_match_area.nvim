<h1 align='center'>hl_match_area.nvim</h1>
Neovim plugin that allows highlighting the whole area between matching delimiters ('{}' '[]' '()' '<>')

![demo](https://user-images.githubusercontent.com/83038443/197796655-b1ff0a7a-ed5b-4922-96d4-3acc7b87e1b5.gif)

## Installation

- With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use { 'rareitems/hl_match_area.nvim' }
```

## Usage

Simply call the following function somewhere in your config

```lua
  require("hl_match_area").setup()
```

If you don't provide any arguments to the setup function, default values will be used, which are as follows (obviously you can also change them)

```lua
{
    n_lines_to_search = 100 -- how many lines should be searched for a matching delimiter
    highlight_in_insert_mode = true, -- should highlighting also be done in insert mode
    delay = 100, -- delay before the highglight
}
```

Changing the highglight can be done through Neovim API. For example:

```lua
vim.api.nvim_set_hl(0, 'MatchArea', {bg = "#FFFFFF"})
```
