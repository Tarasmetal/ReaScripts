-- @description trs_Set_grid_over_or_under
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


-- USER CONFIG AREA ---------------------------------------------------------

local r = reaper
local d = 'trs_Set Grid Over & Under'
console = true -- true/false: display debug messages in the console

----------------------------------------------------- END OF USER CONFIG AREA
-- Msg("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")
-- Display a message in the console for debugging
function Msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

 -- Set ToolBar Button ON
function SetButtonON()
  reaper.Undo_BeginBlock() -- отменить действие

  r.Main_OnCommand(r.NamedCommandLookup('_BR_OPTIONS_GRID_Z_OVER_ITEMS'), 1)
  r.Main_OnCommand(42328, 0); -- Ruler: Display project regions/markers as gridlines in arrange view

  is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  state = r.GetToggleCommandStateEx( sec, cmd )
  r.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
  r.RefreshToolbar2( sec, cmd )

reaper.Undo_EndBlock(d .. " • ON", 1)
end

-- Set ToolBar Button OFF
function SetButtonOFF()
  reaper.Undo_BeginBlock() -- отменить действие

  r.Main_OnCommand(r.NamedCommandLookup('_BR_OPTIONS_GRID_Z_UNDER_ITEMS'), 1)
  r.Main_OnCommand(42328, 1); -- Ruler: Display project regions/markers as gridlines in arrange view

  is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  state = r.GetToggleCommandStateEx( sec, cmd )
  r.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
  r.RefreshToolbar2( sec, cmd )

reaper.Undo_EndBlock(d .. " • OFF", 0)
end

-- Main Function (which loop in background)
function main()
  r.defer( main )
end

-- RUN
SetButtonON()
main()
r.atexit( SetButtonOFF )
