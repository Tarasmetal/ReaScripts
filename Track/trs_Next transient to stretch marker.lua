-- @description trs_Next transient to stretch marker
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
local d = '• trs_Next transient to stretch marker •'
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
r.PreventUIRefresh(0);
--=====================

-- r.Main_OnCommand(40527, 0); -- View: Clear all peak indicators
-- r.Main_OnCommand(r.NamedCommandLookup('_SWS_SAVETIME1'), 0);

r.Main_OnCommand(40769, 0); -- Unselect all tracks/items/envelope points
r.Main_OnCommand(40530, 0); -- Item: Toggle selection of item under mouse cursor
r.Main_OnCommand(40514, 0); -- View: Move edit cursor to mouse cursor (no snapping)
r.Main_OnCommand(40375, 0); -- Item navigation: Move cursor to next transient in items
r.Main_OnCommand(41842, 0); -- Item: Add stretch marker at cursor
r.Main_OnCommand(40530, 0); -- Item: Toggle selection of item under mouse cursor

--=====================
r.PreventUIRefresh(-1);
r.Undo_EndBlock(d, -1) -- для того, чтобы можно было отменить действие
