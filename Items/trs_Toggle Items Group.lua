-- @description trs_Toggle Items Group
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

r = reaper
d = 'trs_Toggle Items Group'
console = true -- true/false: display debug messages in the console

----------------------------------------------------- END OF USER CONFIG AREA

-- Display a message in the console for debugging
function Msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

 -- Set ToolBar Button ON
function SetButtonON()
  r.Undo_BeginBlock() -- отменить действие

  reaper.Main_OnCommand(40032, 0)
  -- r.Main_OnCommand(r.NamedCommandLookup('_BR_OPTIONS_GRID_Z_OVER_ITEMS'), 1)

  is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  state = r.GetToggleCommandStateEx( sec, cmd )
  r.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
  r.RefreshToolbar2( sec, cmd )

  r.Undo_EndBlock(d .. " • ON", 1)
end

-- Set ToolBar Button OFF
function SetButtonOFF()
  r.Undo_BeginBlock() -- отменить действие

  reaper.Main_OnCommand(40033, 0)
  -- r.Main_OnCommand(r.NamedCommandLookup('_BR_OPTIONS_GRID_Z_OVER_ITEMS'), 1)

  is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  state = r.GetToggleCommandStateEx( sec, cmd )
  r.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
  r.RefreshToolbar2( sec, cmd )

  r.Undo_EndBlock(d .. " • OFF", 0)
end

-- Main Function (which loop in background)
function main()
  r.defer( main )
end

-- RUN
SetButtonON()
main()
r.atexit( SetButtonOFF )
