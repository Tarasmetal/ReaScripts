-- @description trs_Set note Len 32
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


local d = "• trs_Set note Len 32 •"

reaper.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
reaper.PreventUIRefresh(-1);

function trs_Set_sel_notes_length_32()
   reaper.Main_OnCommand(reaper.NamedCommandLookup"_SWS_AWITEMTBASEBEATALL", 0); -- MAIN section action "Sel track with selected Item"
   reaper.Main_OnCommand(40153, 0); -- MAIN section action "open selected item in MIDI editor"
   ME_Active = reaper.MIDIEditor_GetActive(); --get MIDI editor ID
   reaper.MIDIEditor_OnCommand(ME_Active, 40006); -- ME action: "Sel all Events"
   reaper.MIDIEditor_OnCommand(ME_Active, 41623); -- ME action: "Set Note Length 1/32"
   reaper.MIDIEditor_OnCommand(ME_Active, 2); -- ME action: "Close MEditor"
end

trs_Set_sel_notes_length_32() --Выполняем функцию
reaper.UpdateArrange() -- на всякий случай обновляет аранж
reaper.UpdateTimeline()

reaper.PreventUIRefresh(-1);
reaper.Undo_EndBlock(d, -1)
