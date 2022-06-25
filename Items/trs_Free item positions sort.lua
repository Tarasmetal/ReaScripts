-- @description trs_Free item positions sort
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies

-- reaper.Main_OnCommand(40752, 0)  Unset free item positioning
-- reaper.Main_OnCommand(40751, 0)  Set free item positioning

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

  reaper.Main_OnCommand(40751, 0) -- Set free item positioning
  -- reaper.Main_OnCommand(40507, 0) -- Options: Show overlapping media items in lanes
  is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  state = reaper.GetToggleCommandStateEx( sec, cmd )
  reaper.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
  reaper.RefreshToolbar2( sec, cmd )

  reaper.Undo_EndBlock("SetButtonON", 0);
  Msg("ON ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")
end
--
-- SORT SORT SORT
function SetButtonCEN()
  for i = 0, count_selected_items - 1 do

   item = reaper.GetSelectedMediaItem(0, i)
   item_free_y = reaper.GetMediaItemInfo_Value(item, "F_FREEMODE_Y")
   item_free_h = reaper.GetMediaItemInfo_Value(item, "F_FREEMODE_H")

   Msg("SORT ♦ "..(count_selected_items).." • "..(i).." • "..(item_free_y).." • "..(item_free_h).." ♦ ")

   item_free_h = reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_H", 1/count_selected_items)
   item_free_y = reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", i * (1/count_selected_items))

 end
end
--
-- Set ToolBar Button OFF
function SetButtonOFF()
  reaper.Undo_BeginBlock()

  reaper.Main_OnCommand(40752, 0) -- Unset free item positioning
  is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  state = reaper.GetToggleCommandStateEx( sec, cmd )
  reaper.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
  reaper.RefreshToolbar2( sec, cmd )

  reaper.Undo_EndBlock("SetButtonOFF", 0);
  Msg("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")
end


-- Основная функция (какой цикл в фоновом режиме)
function item_free()
  reaper.defer(item_free)
end

-- function item_free_1()
--   reaper.defer(item_free_1)
-- end

-- RUN
SetButtonON()
item_free()
count_selected_items = reaper.CountSelectedMediaItems(0)
if count_selected_items > 0 then
  SetButtonCEN()
  -- item_free_1()
  -- reaper.atexit( SetButtonCEN )
end
reaper.atexit( SetButtonOFF )
-- END


-- reaper.atexit(reaper.Main_OnCommand(40752, 0))
-- reaper.Main_OnCommand(40752, 1) -- Unset free item positioning
-- reaper.Main_OnCommand(40507, 1) -- Options: Show overlapping media items in lanes


-- if reaper.CountSelectedTracks(0) == 0 then
--  reaper.ShowMessageBox("• Пожалуйста, выберите TRACK! •", "• ERROR •", 0)
--  return false

-- function item_sort()
--   for i = 0, count_selected_items - 1 do

--     item = reaper.GetSelectedMediaItem(0, i)
--     item_free_y = reaper.GetMediaItemInfo_Value(item, "F_FREEMODE_Y")
--     item_free_h = reaper.GetMediaItemInfo_Value(item, "F_FREEMODE_H")

--     Msg(i)
--     Msg(item_free_y)
--     Msg(item_free_h)

--     item_free_h = reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_H", 1/count_selected_items)
--     item_free_y = reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", i * (1/count_selected_items))

--   end
-- end

-- function Msg(value)
--   reaper.ShowConsoleMsg(tostring(value).."\n")
-- end

-- count_selected_items = reaper.CountSelectedMediaItems(0)
-- if count_selected_items > 0 then
--   item_sort()
-- end


