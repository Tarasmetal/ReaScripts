-- @description trs_Set_Startup_Action
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
local d_text = 'Set Startup Action'
local d = d_text

if d_text ~= '' then
  d_text = string.format('• ' .. p_text .. d_text .. ' •')
else
  d_text = string.format('• ' .. p_text .. 'T@RvZ Test Script' .. ' •')
end

console = false -- true/false: display debug messages in the console
-- msg("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")

-- Display a message in the console for debugging
function msg(value)
  if console then
    r.ShowConsoleMsg('♦ '.. tostring(value) .. " ♦" .. "\n")
  end
end
msg(''..d_text..'')

-- function trs_Set_Startup_Action()
   r.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
   r.PreventUIRefresh(0);

	under_items = r.NamedCommandLookup("_BR_OPTIONS_GRID_Z_UNDER_ITEMS"); -- Get non-native action command_name
	r.Main_OnCommand(under_items, 0); -- MAIN section action "Sel track with selected Item"
	r.Main_OnCommand(r.NamedCommandLookup"_SWS_AWTBASEBEATALL", 0); -- SWS/AW: Set project timebase to beats (position, length, rate)
	r.Main_OnCommand("40457", 0); -- Screenset: Load window set #04
	r.Main_OnCommand("42328", -1); -- Regions View
	-- r.Main_OnCommand("41691", 0); -- Dockers: Compact when small and single tab
	-- r.Main_OnCommand("40101", 0); -- Item: Set all media online

   --=====================
   r.PreventUIRefresh(0);
   r.Undo_EndBlock(d_text, -1) -- для того, чтобы можно было отменить действие
	msg(''..d_text..'')
-- trs_Set_Startup_Action() --Выполняем функцию
r.UpdateTimeline()
r.UpdateArrange()


