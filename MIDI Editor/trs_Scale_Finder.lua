-- @description trs_Scale_Finder
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


-- USER CONFIG AREA --
local r = reaper
local p_text = 'trs'..'_'
local d_text = 'trs_Scale_Finder'
local d = d_text

console = false -- true/false: display debug messages in the console
function msg(value)
  if console then
    r.ShowConsoleMsg('♦ '.. tostring(value) .. " ♦" .. "\n")
  end
end

msg(''..d_text..'')
if d_text ~= '' then
  d_text = string.format('• ' .. p_text .. d_text .. ' •')
else
  d_text = string.format('• ' .. p_text .. 'Scale Finder' .. ' •')
end

-- END OF USER CONFIG AREA --
r.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
r.PreventUIRefresh(-1);
--=====================

r.Main_OnCommand(40301, 0);
-- r.Main_OnCommand(r.NamedCommandLookup('_trs_trackrenametools'), 0);

--=====================
r.PreventUIRefresh(0);
r.Undo_EndBlock(d, -1) -- для того, чтобы можно было отменить действие