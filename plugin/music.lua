if vim.g.loaded_music_controls then
  return
end

if vim.fn.executable('playerctl') == 0 then
  vim.api.nvim_err_writeln('playerctl is not installed')
  return
end

require('music').setup()
require('music.commands').setup()

vim.g.loaded_music_controls = true
