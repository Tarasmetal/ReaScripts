-- @description Render tracks to stereo post-fader stem tracks (and mute originals)
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


--Custom: Track: Render tracks to stereo post-fader stem tracks (and mute originals) + Item: Select all items in track + Item edit: Move items/envelope points down one track/a bit + Track: Go to next track + Track: Toggle FX bypass for selected tracks + Track: Mute/unmute tracks"

local d = "• Render tracks to stereo post-fader stem tracks (and mute originals) •"
local r = reaper

r.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
r.PreventUIRefresh(-1);

function Render_trk_to_streo_p_fader()
   -- r.Main_OnCommand(r.NamedCommandLookup"_SWS_AWITEMTBASEBEATALL", 0); -- MAIN section action "Sel track with selected Item"
   r.Main_OnCommand(40405, 0);
   r.Main_OnCommand(40421, 0);
   r.Main_OnCommand(40118, 0);
   r.Main_OnCommand(40285, 0);
   r.Main_OnCommand(8, 0);
   r.Main_OnCommand(40280, 0);

   -- ME_Active = r.MIDIEditor_GetActive(); --get MIDI editor ID
   -- r.MIDIEditor_OnCommand(ME_Active, 40006); -- ME action: "Sel all Events"
   -- r.MIDIEditor_OnCommand(ME_Active, 41623); -- ME action: "Set Note Length 1/32"
   -- r.MIDIEditor_OnCommand(ME_Active, 2); -- ME action: "Close MEditor"
end

Render_trk_to_streo_p_fader() --Выполняем функцию
r.UpdateArrange() -- на всякий случай обновляет аранж
r.UpdateTimeline()

r.PreventUIRefresh(-1);
r.Undo_EndBlock(d, -1)
