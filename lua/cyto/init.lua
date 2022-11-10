M = {}

-- local utility functions
table.unpack = table.unpack or unpack -- 5.1 compatibility

-- TODO WHEN EXPANDING LANGUAGE: Refactor to be more modular and add language specifics to a module
-- TODO Something to run a script and drop into python repl
local function getCellLines(start_delim,  end_delim)
  -- gets the line numbers of the current or cell aboves deliminators
  -- get the current cursor position to jump back to later
  local saved_cursor_row, saved_cursor_col = table.unpack(vim.api.nvim_win_get_cursor(0))
  -- adding 1 back to the col because nvim_* decided to 0 index cols for this method
  local saved_cursor_pos = {saved_cursor_row, saved_cursor_col + 1}
  vim.fn.cursor({0, 9999})
  local start_line = vim.fn.search(start_delim, 'bW')
  local end_line = vim.fn.search(end_delim, 'Wn')
  vim.fn.cursor(saved_cursor_pos)
  return {start_line, end_line}
end

local function getCell(start_delim, end_delim)
  --[[
  Takes a start delimintator and end deliminator for a cell,
  and returns each line between the deliminators as a table of strings.
  returns an empty table if no cells were found.
  ]]--
  local start_line, end_line = table.unpack(getCellLines(start_delim, end_delim))
  if start_line == 0 or end_line == 0 then
   return {}
  end
  start_line = start_line + 1 --inc. to exclude cell header
  end_line = end_line -1 -- dec. to exclude cell footer
  return vim.fn.getline(start_line, end_line)

end

local function stringIsEmpty(input_string)
  if string.find(input_string, '^ *$') then
    return true
  else
    return false
  end
end

local function cleanDataForIPython(data)
  local clean_table = {}
  for _, line in pairs(data) do
    if not stringIsEmpty(line) then
      table.insert(clean_table, line)
    end
  end
  return clean_table
end

local function sendToTmux(data, panel_id)
  -- Takes a table data(lines) and tmux panel id, and sends the keys to tmux with necessary \r
  -- remove null or blank lines from data table, escape stuff that needs escaping
  local clean_data = cleanDataForIPython(data)
  local num_lines = #clean_data
  if num_lines <= 0 then
    return 1
  else
    if num_lines == 1 then
      local line = clean_data[1]
      -- escape double quotes for tmux send keys quotes. 
      -- TODO REFACTOR this block that is repeated
      line = string.gsub(line, '"', '\\"')
      os.execute('tmux send-keys -t '..panel_id..' -l "'..line..'"')
      os.execute('tmux send-keys -t '..panel_id..' Enter')
      return 0

    else
      -- we have multiple lines to send
      -- send C-o to ipython to specify multiline
      os.execute('tmux send-keys -t '..panel_id..' C-o')
      for _, line in pairs(clean_data) do
        line = string.gsub(line, '"', '\\"')
        os.execute('tmux send-keys -t '..panel_id..' "'..line..'"')
        os.execute('tmux send-keys -t '..panel_id..' Enter')
      end
      os.execute('tmux send-keys -t 1 Enter')
      return 0
    end
  end
end

function M.setup(start_delim, end_delim)
  --takes start_delim and end_delim and returns cell functions with start_delim and end_delim bound
  local tmux_id
  local cyto_funcs = {}

  local function getTmuxId()
    vim.ui.input({prompt = 'Enter Target Tmux Panel ID: '}, function (input) tmux_id = input end)
  end

  vim.api.nvim_create_user_command('SetTMuxTarget', getTmuxId, {})

  function cyto_funcs.sendCellToTmux()
    --[[
    Gets a cell under the cursor and then sends cell contents, line by line to a tmux pane.
    ]]--
    --TODO: prompt user for -t value when first called in session
    if tmux_id == nil then
      getTmuxId()
    end
    local cell = getCell(start_delim, end_delim)
    if sendToTmux(cell, tmux_id) == 1 then
      print('No lines were received to send.')
      return 1
    end
  end

  function cyto_funcs.makeCell()
    local start_line, end_line = table.unpack(getCellLines(start_delim, end_delim))
    local current_line = vim.fn.line('.')
    local on_cell = ((start_line > 0 and end_line > 0) and (start_line <= current_line and current_line <= end_line))
    if on_cell then
      vim.fn.append(end_line, {'', start_delim, '', end_delim})
      vim.fn.cursor({end_line+3, 1})
    else
      vim.fn.append(current_line, {start_delim, '', end_delim, ''})
      vim.fn.cursor({current_line+2, 1})
    end
    return 0
  end

  function cyto_funcs.sendAndMakeCell()
    -- do not make a new cell if there was no cell to send
    if cyto_funcs.sendCellToTmux() == 1 then
      print('No cells were found to execute.')
      return 1
    end
    cyto_funcs.makeCell()
    return 0
  end

  function cyto_funcs.sendVisualSelection()
    if tmux_id == nil then
      getTmuxId()
    end
    -- yank to visual selection into 9 register,
    vim.fn.feedkeys('"9y', 'x')
    -- send the register to tmux
    local yanked_contents = vim.fn.getreg('9')
    local lines = vim.fn.split(yanked_contents, '\n')
    sendToTmux(lines, tmux_id)
  end

  return cyto_funcs

end

return M
