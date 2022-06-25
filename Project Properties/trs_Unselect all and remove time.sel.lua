-- @description trs_Unselect all and remove time.sel
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

console = false -- true/false: display debug messages in the console

----------------------------------------------------- END OF USER CONFIG AREA

-- Display a message in the console for debugging
function Msg(value)
  if console then
    reaper.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

 -- Set ToolBar Button ON
 function SetButtonON()
    reaper.Undo_BeginBlock()
    --
    reaper.Main_OnCommand(40769, 0) -- Unselect all tracks/items/envelope points
    is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
    state = reaper.GetToggleCommandStateEx( sec, cmd )
    reaper.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
    reaper.RefreshToolbar2( sec, cmd )
    --
    reaper.Undo_EndBlock("trs_ReSel. All tr/it/env.points", 0);
    Msg("ON ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")
  end

-- Set ToolBar Button OFF
function SetButtonOFF()
   reaper.Undo_BeginBlock()
   --
   reaper.Main_OnCommand(40020, 0) -- Time selection: Remove time selection and loop points
   is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
   state = reaper.GetToggleCommandStateEx( sec, cmd )
   reaper.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
   reaper.RefreshToolbar2( sec, cmd )
   --
   reaper.Undo_EndBlock("trs_ReSel. time sel. & loop points", 0);
   Msg("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")
 end

-- Основная функция (какой цикл в фоновом режиме)
function main_pause()
  reaper.defer( main_pause )
end

-- БЕЖАТЬ
SetButtonON()
main_pause()
reaper.atexit(SetButtonOFF)

