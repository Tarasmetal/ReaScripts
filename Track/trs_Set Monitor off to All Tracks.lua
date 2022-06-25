-- @description trs_Set Monitor off to All Tracks
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies

-- USER CONFIG AREA --
local r = reaper
local p_text = 'trs'..'_'
local d_text = 'Set Monitor off to All Tracks'
local f_text = string.format('• ' .. p_text .. d_text .. ' •')
console = true -- true/false: display debug messages in the console
-- msg("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")

-- Display a message in the console for debugging
function msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end
-- END OF USER CONFIG AREA --
r.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
r.PreventUIRefresh(0);
--=====================

-- r.Main_OnCommand(40527, 0); -- View: Clear all peak indicators
r.Main_OnCommand(r.NamedCommandLookup('_trs_unsel_all_remove_time_sel'), 0);
r.Main_OnCommand(40296, 0) -- Выделить все треки --------------------------------
r.Main_OnCommand(40492, 0) -- Track: Set track record monitor to off
r.Main_OnCommand(r.NamedCommandLookup('_trs_unsel_all_remove_time_sel'), 0);
r.Main_OnCommand(r.NamedCommandLookup('_trs_unsel_all_remove_time_sel'), 0);

--=====================
r.PreventUIRefresh(-1);
r.Undo_EndBlock(f_text, -1) -- для того, чтобы можно было отменить действие
