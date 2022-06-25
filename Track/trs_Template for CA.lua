-- @description trs_Template for CA
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
local d_text = ''

if d_text ~= '' then
	local f_text = string.format('• ' .. p_text .. d_text .. ' •')
else
	local f_text = string.format('• ' .. p_text .. 'T@RvZ Test Script' .. ' •')
end

console = true -- true/false: display debug messages in the console
-- MSG("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")

-- Display a message in the console for debugging
function MSG(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end
-- END OF USER CONFIG AREA --
r.Undo_BeginBlock(d_text,-1) -- для того, чтобы можно было отменить действие
r.PreventUIRefresh(-1);
--=====================

-- r.Main_OnCommand(40527, 0); -- View: Clear all peak indicators
r.Main_OnCommand(r.NamedCommandLookup('_trs_trackrenametools'), 0);

--=====================
r.PreventUIRefresh(-1);
r.Undo_EndBlock(d_text, 0) -- для того, чтобы можно было отменить действие