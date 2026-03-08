local M = {}

local player = require('music.player')
local control = require('music.controls')
local plugin_config = require('music.config')

-- UI Config
local ui_config = {
  window = {
    width = 30,
    border = 'rounded',
  },

  keybindings = {
    toggle_play = '<Space>',
    next_track = 'n',
    prev_track = 'p',
    shuffle = 's',
    loop = 'r',
    quit = 'q',
    help = 'h',
  },
}

-- UI State
local state = {
  buf = nil,
  win = nil,
  is_open = false,
  player = nil,
  timer = nil,
}

local function truncate_display(text, max_width)
  local input = tostring(text or '')
  local out = ''
  local used = 0
  local chars = vim.fn.strchars(input)

  for i = 0, chars - 1 do
    local ch = vim.fn.strcharpart(input, i, 1)
    local ch_width = vim.fn.strdisplaywidth(ch)
    if used + ch_width > max_width then
      break
    end

    out = out .. ch
    used = used + ch_width
  end

  return out
end

local function pad_display(text, width)
  local clipped = truncate_display(text, width)
  local used = vim.fn.strdisplaywidth(clipped)
  local pad = math.max(0, width - used)
  return clipped .. string.rep(' ', pad)
end

-- Current Player
local function resolve_player(requested_player)
  -- If there is some requested player return it
  if requested_player and requested_player ~= '' then
    return requested_player
  end

  -- Else return the default player if set
  local default_player = plugin_config.config.default_player
  if default_player and default_player ~= '' then
    return default_player
  end

  -- Else return the first player which is currently playing
  local players = player.get_all() or {}
  for _, p in ipairs(players) do
    if p and p ~= '' then
      return p
    end
  end

  return nil
end

-- Create a floating window
function M.create_window(height)
  local win_cfg = ui_config.window

  local width = vim.o.columns
  local editor_height = vim.o.lines

  local win_width = math.min(win_cfg.width, width - 4)
  local win_height = math.min(height, editor_height - 4)

  local row = editor_height - win_height - 2
  local col = width - win_width - 2

  -- Create buffer
  state.buf = vim.api.nvim_create_buf(false, true) -- Create scratch buffer

  -- Buffer options
  vim.api.nvim_buf_set_option(state.buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(state.buf, 'filetype', 'music')
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)

  -- Window options
  local opts = {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = 'minimal',
    border = win_cfg.border,
  }

  -- Create window
  state.win = vim.api.nvim_open_win(state.buf, true, opts)
  vim.api.nvim_win_set_option(state.win, 'winhl', 'Normal:Normal')

  return state.buf, state.win
end

-- Render the UI
function M.render()
  local playback_state, title, artist, album = control.current(state.player)

  local status = {
    state = playback_state,
    title = title,
    artist = artist,
    album = album,
  }

  -- TODO: drawing album art isnt working for now need tocheck it out

  -- Draw album art (separate from buffer rendering)
  -- local function draw_album_art()
  --   local art = vim.fn.system('playerctl metadata mpris:artUrl'):gsub('\n', '')
  --   if art == '' then
  --     return
  --   end
  --
  --   -- Avoid re-downloading every render
  --   if state.last_art == art then
  --     return
  --   end
  --
  --   state.last_art = art
  --
  --   vim.fn.system('kitty +kitten icat --clear')
  --
  --   local tmp = '/tmp/music.nvim.art.jpg'
  --   vim.fn.system("curl -L -s '" .. art .. "' -o " .. tmp)
  --
  --   local cmd = string.format('kitty +kitten icat --transfer-mode=stream --place 20x10@2x4 %s', tmp)
  --
  --   vim.fn.system(cmd)
  -- end

  -- Window size
  local total_width = ui_config.window.width
  local inner_width = total_width - 2

  local function border(top)
    if top then
      return '╔' .. string.rep('═', inner_width) .. '╗'
    end
    return '╚' .. string.rep('═', inner_width) .. '╝'
  end

  local function divider()
    return '╠' .. string.rep('═', inner_width) .. '╣'
  end

  local function line(text)
    return '║' .. pad_display(text, inner_width) .. '║'
  end

  local function center(text)
    local w = vim.fn.strdisplaywidth(text)
    local left = math.floor((inner_width - w) / 2)
    return string.rep(' ', math.max(left, 0)) .. text
  end

  -- Build UI
  local lines = {
    border(true),
    line(center('🎵 ' .. ((state.player and state.player:sub(1, 1):upper() .. state.player:sub(2)) or 'Unknown'))),
    divider(),
    line(''),
    line('Status: ' .. (status.state or 'Unknown')),
    line('Track:  ' .. (status.title or 'No track')),
    line('Artist: ' .. (status.artist or 'Unknown')),
    line('Album:  ' .. (status.album or 'Unknown')),
    line(''),
    divider(),
    line('Keybindings:'),
    line('  <Space> - Play/Pause'),
    line('  n       - Next track'),
    line('  p       - Previous track'),
    line('  s       - Toggle shuffle'),
    line('  r       - Toggle loop'),
    line('  q       - Quit'),
    border(false),
  }

  -- Create window dynamcally
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    M.create_window(#lines)
    M.keybindings()
  end

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  -- Update buffer
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)

  -- TODO: Need to fix this too
  -- Draw image after text render
  -- vim.defer_fn(draw_album_art, 50)
end

-- Keybindings
function M.keybindings()
  local keys = ui_config.keybindings

  local function map(key, callback)
    vim.api.nvim_buf_set_keymap(state.buf, 'n', key, '', {
      nowait = true,
      noremap = true,
      silent = true,
      callback = callback,
    })
  end

  map(keys.toggle_play, function()
    control.play(state.player) -- Toggle play music
    M.render()
  end)

  map(keys.next_track, function()
    control.next(state.player) -- Play the next Track
    vim.defer_fn(M.render, 100)
  end)

  map(keys.prev_track, function()
    control.previous(state.player) -- Play the previous Track
    vim.defer_fn(M.render, 100)
  end)

  map(keys.shuffle, function()
    control.shuffle(state.player) -- Toggle shuffle
    vim.defer_fn(M.render, 100)
  end)

  map(keys.loop, function()
    control.toggle_loop(state.player) -- Toggle Loop
    vim.defer_fn(M.render, 100)
  end)

  map(keys.quit, function()
    M.close() -- Quit
  end)

  map(keys.help, function()
    -- TODO:  Need to be done
    M.render()
  end)
end

-- Open the TUI
function M.open(_player)
  if state.is_open then
    return
  end

  state.player = resolve_player(_player)
  if not state.player then
    vim.api.nvim_err_writeln('No player found! Please set a default player ot start a media player.')
    return
  end

  -- state.buf = vim.api.nvim_create_buf(false, true)

  M.render()

  state.is_open = true

  -- Auto Refresh
  state.timer = vim.loop.new_timer()
  state.timer:start(
    1000,
    1000,
    vim.schedule_wrap(function()
      if state.is_open and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        M.render()
      else
        if state.timer then
          state.timer:stop()
          state.timer:close()
          state.timer = nil
        end
      end
    end)
  )

  -- Auto-close handler
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = state.buf,
    callback = function()
      M.close()
    end,
  })
end

-- Close the TUI
function M.close()
  -- Stop the timer
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end

  -- Close the window
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  -- Clear all the values
  state.buf = nil
  state.win = nil
  state.player = nil
  state.is_open = false
end

return M
