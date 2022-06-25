-- @description trs_Free item positions Sort on all Tracks
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


-- r.Main_OnCommand(40752, 0)  Unset free item positioning
-- r.Main_OnCommand(40751, 0)  Set free item positioning

-- USER CONFIG AREA ---------------------------------------------------------

local r = reaper
local d = 'trs_Set free item pos Sort'
console = false -- true/false: display debug messages in the console

----------------------------------------------------- END OF USER CONFIG AREA

-- Display a message in the console for debugging
function Msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end


 -- Set ToolBar Button ON
function SetButtonON()
  r.Undo_BeginBlock()

r.Main_OnCommand(r.NamedCommandLookup('_SWS_SAVEALLSELITEMS1'), 0) -- Save Pos
r.Main_OnCommand(r.NamedCommandLookup('_BR_FOCUS_TRACKS'), 0)
r.Main_OnCommand(40035, 0) -- Select All Tracks

r.Main_OnCommand(40751, 0) -- Set free item positioning

  -- r.Main_OnCommand(40507, 0) -- Options: Show overlapping media items in lanes
  is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  state = r.GetToggleCommandStateEx( sec, cmd )
  r.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
  r.RefreshToolbar2( sec, cmd )

  r.Undo_EndBlock(d .. " • ON", 1)

  Msg("ON ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")

end
--
-- SORT SORT SORT
function SetButtonCEN()
  for i = 0, count_selected_items - 1 do

   item = r.GetSelectedMediaItem(0, i)
   item_free_y = r.GetMediaItemInfo_Value(item, "F_FREEMODE_Y")
   item_free_h = r.GetMediaItemInfo_Value(item, "F_FREEMODE_H")

   Msg("SORT ♦ "..(count_selected_items).." • "..(i).." • "..(item_free_y).." • "..(item_free_h).." ♦ ")

   item_free_h = r.SetMediaItemInfo_Value(item, "F_FREEMODE_H", 1/count_selected_items)
   item_free_y = r.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", i * (1/count_selected_items))

 end
end
--
-- Set ToolBar Button OFF
function SetButtonOFF()
  r.Undo_BeginBlock()

  r.Main_OnCommand(40752, 0) -- Unset free item positioning
  is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  state = r.GetToggleCommandStateEx( sec, cmd )
  r.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
  r.RefreshToolbar2( sec, cmd )

  r.Undo_EndBlock(d .. " • OFF", 0)

  Msg("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")

	r.Main_OnCommand(r.NamedCommandLookup('_BR_FOCUS_ARRANGE_WND'), 0)
	r.Main_OnCommand(r.NamedCommandLookup('_SWS_UNSELALL'), 0)
	r.Main_OnCommand(r.NamedCommandLookup('_SWS_RESTALLSELITEMS1'), 0) -- Restore Pos

end



-- Основная функция (какой цикл в фоновом режиме)
function item_free()
  r.defer(item_free)
end

-- function item_free_1()
--   r.defer(item_free_1)
-- end

-- RUN
SetButtonON()
item_free()
count_selected_items = r.CountSelectedMediaItems(0)
if count_selected_items > 0 then
  SetButtonCEN()
  -- item_free_1()
  -- r.atexit( SetButtonCEN )
end
r.atexit( SetButtonOFF )
-- END


-- r.atexit(r.Main_OnCommand(40752, 0))
-- r.Main_OnCommand(40752, 1) -- Unset free item positioning
-- r.Main_OnCommand(40507, 1) -- Options: Show overlapping media items in lanes


-- if r.CountSelectedTracks(0) == 0 then
--  r.ShowMessageBox("• Пожалуйста, выберите TRACK! •", "• ERROR •", 0)
--  return false

-- function item_sort()
--   for i = 0, count_selected_items - 1 do

--     item = r.GetSelectedMediaItem(0, i)
--     item_free_y = r.GetMediaItemInfo_Value(item, "F_FREEMODE_Y")
--     item_free_h = r.GetMediaItemInfo_Value(item, "F_FREEMODE_H")

--     Msg(i)
--     Msg(item_free_y)
--     Msg(item_free_h)

--     item_free_h = r.SetMediaItemInfo_Value(item, "F_FREEMODE_H", 1/count_selected_items)
--     item_free_y = r.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", i * (1/count_selected_items))

--   end
-- end

-- function Msg(value)
--   r.ShowConsoleMsg(tostring(value).."\n")
-- end

-- count_selected_items = r.CountSelectedMediaItems(0)
-- if count_selected_items > 0 then
--   item_sort()
-- end


