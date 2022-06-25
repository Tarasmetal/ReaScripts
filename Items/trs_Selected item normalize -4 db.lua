 -- @description trs_Selected item normalize -4 db
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


 -- Set ToolBar Button ON
 function SetButtonON()
    item_mouse, mouse_pos = reaper.BR_ItemAtMouseCursor() -- Get item under mouse
  if item_mouse ~= nil then -- If no item under mouse
	reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_TOGGLETAKENORMALIZE"), 0); -- Set item rate 1.0
	reaper.Main_OnCommand(41924, 0); -- Set item -1 dB
	reaper.Main_OnCommand(41924, 0); -- Set item -1 dB
end
--///////////////////////
--///////////////////////
end
-- Set ToolBar Button OFF
function SetButtonOFF()
	item_mouse, mouse_pos  = reaper.BR_ItemAtMouseCursor() -- Get item under mouse
  if item_mouse ~= nil then -- If no item under mouse
	-- reaper.Main_OnCommand( reaper.NamedCommandLookup("_XENAKIOS_TOGGLETAKENORMALIZE"), 0); -- Set item rate 1.0
	reaper.Main_OnCommand(40938, 0); -- Unnormalaze vol item = 0 db
	reaper.Main_OnCommand(41923, 0); -- Unnormalaze vol item = 0 db
end
end
-- Main Function (which loop in background)
function main()
	reaper.defer( main )
end
-- RUN
SetButtonON()
main()
reaper.atexit(SetButtonOFF)

