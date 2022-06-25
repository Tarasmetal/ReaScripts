-- @description trs_Zoom and inline Edit Item Toggle
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


local r = reaper
console = false

function msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

-- Set ToolBar Button ON
function SetButtonON()
	--      Undo_BeginBlock();
	-- PreventUIRefresh(0);
	item_mouse, mouse_pos  = r.BR_ItemAtMouseCursor() -- Get item under mouse
	if item_mouse ~= nil then -- If no item under mouse
		-- r.Main_OnCommand(r.NamedCommandLookup("_SWS_TOGZOOMIONLYHIDE"), 0);
		r.Main_OnCommand(r.NamedCommandLookup("_BR_OPTIONS_GRID_Z_THROUGH_ITEMS"), 0);
	end -- ENDIF no item under mouse
	r.Main_OnCommand(40847, 0); -- Item: Open item inline editors
	r.SetToggleCommandState( sec, cmd, 0) -- Set ON
	-- PreventUIRefresh(-1);
	-- Undo_EndBlock("Zoom and inline edit item ON", 0);
end
-- Set ToolBar Button OFF
function SetButtonOFF()
	-- Undo_BeginBlock();
	-- PreventUIRefresh(0);
	item_mouse, mouse_pos  = r.BR_ItemAtMouseCursor() -- Get item under mouse
	if item_mouse ~= nil then -- If no item under mouse
		-- r.Main_OnCommand(r.NamedCommandLookup("_SWS_TOGZOOMIONLYHIDE"), 1);
		r.Main_OnCommand(r.NamedCommandLookup("_BR_OPTIONS_GRID_Z_UNDER_ITEMS"), 1);
	end
	r.Main_OnCommand(41887, 0); -- Item: Close item inline editors
  	r.SetToggleCommandState( sec, cmd, 1) -- Set ON
	-- PreventUIRefresh(-1);
	-- Undo_EndBlock("Zoom and inline edit item OFF", 0);
end
-- Main Function (which loop in background)
function main()
	r.defer( main )
end
-- RUN
SetButtonON()
main()
r.atexit(SetButtonOFF)

--  -- Set ToolBar Button ON
-- function SetButtonON()
--   is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
--   state = r.GetToggleCommandStateEx( sec, cmd )
--   r.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
--   r.RefreshToolbar2( sec, cmd )
-- end

-- -- Set ToolBar Button OFF
-- function SetButtonOFF()
--   is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
--   state = r.GetToggleCommandStateEx( sec, cmd )
--   r.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
--   r.RefreshToolbar2( sec, cmd )
-- end


-- -- Main Function (which loop in background)
-- function main()

--   r.defer( main )

-- end


-- -- RUN
-- SetButtonON()
-- main()
-- r.atexit( SetButtonOFF )
