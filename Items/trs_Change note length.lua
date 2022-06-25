-- @description Change note length (mousewheel)
-- @version 1.21
-- @changelog
--   bug fix
-- @author Stephan Römer
-- @provides [main=midi_editor] .
-- @about
--    # Description
--    * This script changes the note length via mousewheel
--    * When there is no note selection, only the note under the mouse cursor is altered
--    * This script only works in the MIDI Editor
-- @link https://forums.cockos.com/showthread.php?p=1923923

if reaper.CountSelectedMediaItems(0) == 0 then
 reaper.ShowMessageBox("• Пожалуйста, выберите MIDI item! •", "• ERROR •", 0)
 return false
else
      for i = 0, reaper.CountSelectedMediaItems(0)-1 do -- петля через все выбранные пункты
    local item = reaper.GetSelectedMediaItem(0, i) -- получите текущий выбранный пункт
    local take = reaper.GetActiveTake(item)
  -- _, _, _ = reaper.BR_GetMouseCursorContext() -- initiate "get mouse cursor context"
  -- _, _, note_row, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI() -- get note row under mouse cursor
  -- mouse_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.BR_GetMouseCursorContext_Position()) -- get mouse position in project time and convert to PPQ
  -- notes_count, _, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take

  -- are there selected notes?
--  if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then -- check, if there are selected notes

   if reaper.TakeIsMIDI(take, -1) ~= 1 then -- удостоверьтесь, который взятие - MIDI
      notes_sel = true -- set notes_sel to true
    notes_count_max, notes_count, _, _ = reaper.MIDI_CountEvts(take) -- посчитайте ноты и сохраните сумму к notes_count
    for n = 0, notes_count_max - 1 do
      _, selected_out, _, startppqpos_out, endppqpos_out, _, pitch, _ = reaper.MIDI_GetNote(take, n) -- get note selection status, start/end position and pitch
      if notes_sel == true then -- if there are selected notes
            reaper.MIDI_SetNote(take, n, nil, nil, nil, 40, nil, nil, nil, true) -- increase note length by val
            if notes_sel == true then -- is current note selected?
           --if val > 0 then -- if mousewhe
--            else      -- if mousewheel down
            reaper.MIDI_SetNote(take, n, nil, nil, nil, 40, nil, nil, nil, true) -- decrease note length by val
          end
        end
      end
    end
  end
end

-- reaper.MIDI_Sort(take)
reaper.Undo_OnStateChange2(proj, "• Change note length •")
reaper.UpdateTimeline()
reaper.UpdateArrange()

