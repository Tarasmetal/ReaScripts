-- @description trs_Free item positions mouse
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
  item_mouse, mouse_pos = reaper.BR_ItemAtMouseCursor() -- Get item under mouse
  if item_mouse ~= nil then -- If no item under mouse
    reaper.Undo_BeginBlock()
    --
    reaper.Main_OnCommand(40751, 0) -- Set free item positioning
    -- reaper.Main_OnCommand(40507, 0) -- Options: Show overlapping media items in lanes
    is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
    state = reaper.GetToggleCommandStateEx( sec, cmd )
    reaper.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
    reaper.RefreshToolbar2( sec, cmd )
    --
    reaper.Undo_EndBlock("un.mouse.Set.Btn.ON", 0);
    Msg("ON ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")
  end
end

-- Set ToolBar Button OFF
function SetButtonOFF()
  item_mouse, mouse_pos  = reaper.BR_ItemAtMouseCursor() -- Get item under mouse
  if item_mouse ~= nil then -- If no item under mouse
   reaper.Undo_BeginBlock()
   --
   reaper.Main_OnCommand(40752, 0) -- Unset free item positioning
   is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
   state = reaper.GetToggleCommandStateEx( sec, cmd )
   reaper.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
   reaper.RefreshToolbar2( sec, cmd )
   --
   reaper.Undo_EndBlock("un.mouse.Set.Btn.OFF", 0);
   Msg("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")
 end
end

-- Main Function (which loop in background)
function main_pause()
  reaper.defer( main_pause )
end

-- RUN
SetButtonON()
main_pause()
reaper.atexit(SetButtonOFF)

