local utils = require('music.utils')
local M = {}

local radio_paradise = 'http://stream.radioparadise.com/'
local radio_player_pid = nil

vim.api.nvim_set_hl(0, 'Heading', { fg = '#BAD7F2' })
vim.api.nvim_set_hl(0, 'Channel', { fg = '#FAF3DD' })

M.get_channel = function()
  vim.api.nvim_echo({
    { 'List of the Radio Channel we support:\n', 'Heading' },
    { '\t1.\tThe Main Mix\n', 'Channel' },
    { '\t2.\tMellow Mix\n', 'Channel' },
    { '\t3.\tRockIt\n', 'Channel' },
    { '\t4.\tThe Globe\n', 'Channel' },
    { '\t5.\tBeyond...\n', 'Channel' },
    { '\t6.\tSerenity\n', 'Channel' },
    { '\t7.\tKFAT\n', 'Channel' },
    { '\t8.\tRadio 2050\n', 'Channel' },
  }, false, {})
end

local get_stream = function(index)
  if index == 1 then
    return radio_paradise .. 'flac'
  elseif index == 2 then
    return radio_paradise .. 'mellow-flac'
  elseif index == 3 then
    return radio_paradise .. 'rock-flac'
  elseif index == 4 then
    return radio_paradise .. 'global-flac'
  elseif index == 5 then
    return radio_paradise .. 'beyond-flac'
  elseif index == 6 then
    return radio_paradise .. 'serenity'
  elseif index == 7 then
    return radio_paradise .. 'radio2050-flac'
  elseif index == 8 then
    return radio_paradise .. 'kfat-flac'
  else
    vim.notify('Please ender a valid channel id. To know the channel id run :RadioChannel', vim.log.levels.ERROR)
    M.get_channel()
    return nil
  end
end

M.play_radio = function(index)
  local stop = M.stop_radio()
  local stream = get_stream(index)

  --Return if the stream is null
  if stream == nil then
    return
  end

  -- If cant kill the previous playing radio return
  if stop == false then
    return
  end

  -- Run the radio on a different process
  vim.fn.jobstart({ 'mpv', tostring(stream) }, { detach = true })

  -- Fetch the pid after some moment
  vim.defer_fn(function()
    local pid = M.find_player_pid()
    if pid == nil then
      vim.notify(
        'Failed to get the pid of the player. The player is now running on its own. Need to kill the process manually. You can simply run "pkill mpv" to do so',
        vim.log.levels.ERROR
      )
    end
    radio_player_pid = pid
  end, 500)
end

M.stop_radio = function()
  -- If no radio was playing before do nothing
  if radio_player_pid == nil then
    return true
  end

  local player_pid = M.find_player_pid()

  -- If the proecess kill by the user manually
  if player_pid == nil or player_pid ~= radio_player_pid then
    radio_player_pid = nil
    return true
  end

  -- Stop the radio
  local trimmed_pid = vim.trim and vim.trim(tostring(player_pid)) or tostring(player_pid):gsub('%s+', '')
  local _, err = utils.exec_command({ 'kill', trimmed_pid })
  if err then
    vim.notify('Failed to stop the radio:' .. err, vim.log.levels.ERROR)
    return false
  else
    radio_player_pid = nil
    return true
  end
end

M.find_player_pid = function()
  local result, err = utils.exec_command({ 'pgrep', 'mpv' })

  if err then
    return nil
  else
    return result
  end
end

return M
