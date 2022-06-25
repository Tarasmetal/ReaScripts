function sel_notes_ME()
   local function Msg(str)
      reaper.ShowConsoleMsg(tostring(str).."\n")
   end

   reaper.Undo_BeginBlock()

   local num_items = reaper.CountSelectedMediaItems(0)

   for i = 0, num_items - 1 do

      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)

      if reaper.TakeIsMIDI(take) then
         reaper.MIDI_SelectAll(take, 1)
      end

   end
end

function trs_Set_sel_notes_length_16()

   reaper.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
   reaper.PreventUIRefresh(1);

   reaper.Main_OnCommand(reaper.NamedCommandLookup"_SWS_AWITEMTBASEBEATALL", 0); -- MAIN section action "Sel track with selected Item"
   reaper.Main_OnCommand(40153, 0); -- MAIN section action "open selected item in MIDI editor"
   ME_Active = reaper.MIDIEditor_GetActive(); --get MIDI editor ID
   reaper.MIDIEditor_OnCommand(ME_Active, 40006); -- ME action: "Sel all Events"
   reaper.MIDIEditor_OnCommand(ME_Active, 41626); -- ME action: "Set Note Length 1/16"
   -- reaper.MIDIEditor_LastFocused_OnCommand(40450,0); -- ME action: "Show events as diamonds"
   reaper.MIDIEditor_OnCommand(ME_Active, 2); -- ME action: "Close MEditor"

   reaper.PreventUIRefresh(-1);
   reaper.Undo_EndBlock("trs_Set note length 16 •", 0)
end

sel_notes_ME()
trs_Set_sel_notes_length_16() --Выполняем функцию
reaper.UpdateArrange() -- на всякий случай обновляет аранж
reaper.UpdateTimeline()