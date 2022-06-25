-- @description trs_Convert active take MIDI to region
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
local d = '• trs_Convert active take MIDI to region •'
console = false -- true/false: display debug messages in the console
-- Msg("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")

-- Display a message in the console for debugging
function Msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end
-- END OF USER CONFIG AREA --
r.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
r.PreventUIRefresh(-1);
--=====================

r.Main_OnCommand(40685, 0); -- View: Clear all peak indicators
-- r.Main_OnCommand(r.NamedCommandLookup("_SWS_SAVETIME1"), 0);

--=====================
r.PreventUIRefresh(0);
r.Undo_EndBlock(d, -1) -- для того, чтобы можно было отменить действие