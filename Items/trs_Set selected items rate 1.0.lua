-- @description trs_Set selected items rate 1.0
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
d = 'trs_Set selected items rate 1.0'
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
      -- Undo_BeginBlock();
  -- PreventUIRefresh(0);
    -- item_mouse, mouse_pos  = r.BR_ItemAtMouseCursor() -- Get item under mouse
  -- if item_mouse ~= nil then -- If no item under mouse
  --r.Main_OnCommand( 40035, 0); -- Set all
  -- r.Main_OnCommand( 40652, 0); -- Set item 1.0
  r.Main_OnCommand( r.NamedCommandLookup("_XENAKIOS_RESETITEMPITCHANDRATE"), 0); -- Set item rate 1.0
  r.Main_OnCommand( 40769, 0); -- UnSelect All items
  -- end -- ENDIF no item under mouse
  r.PreventUIRefresh(-1);
  r.Undo_EndBlock(d .. " • ON", 1)
end
-- Set ToolBar Button OFF
function SetButtonOFF()
  -- Undo_BeginBlock();
  -- PreventUIRefresh(0);
      -- item_mouse, mouse_pos  = r.BR_ItemAtMouseCursor() -- Get item under mouse
  -- if item_mouse ~= nil then -- If no item under mouse

      r.Main_OnCommand( 40769, 0); -- UnSelect All items
      r.Main_OnCommand( 40769, 0); -- UnSelect All items
    -- r.Main_OnCommand( 41887, 0);
    -- r.Main_OnCommand( r.NamedCommandLookup("_SWS_TOGZOOMIONLYHIDE"), 1);
    -- r.Main_OnCommand( r.NamedCommandLookup("_BR_OPTIONS_GRID_Z_UNDER_ITEMS"), 1);
  -- end
   r.PreventUIRefresh(-1);
   r.Undo_EndBlock(d .. " • OFF", 1)
end
-- RUN
SetButtonON()
r.atexit(SetButtonOFF)

