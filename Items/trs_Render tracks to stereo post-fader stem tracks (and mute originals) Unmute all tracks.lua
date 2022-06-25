-- @description trs_Render tracks to stereo post-fader stem tracks (and mute originals) Unmute all tracks
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


--"66351e18119cba4081430a856005031e" "Custom: Track: Render tracks to stereo post-fader stem tracks (and mute originals) +
--Item: Select all items in track + Item edit: Move items/envelope points down one track/a bit + Track: Remove tracks + Track: Unmute all tracks"
--40405 40421 40118 40005 40339
local d = "• trs_Render tracks to stereo post-fader stem tracks (and mute originals) Unmute all tracks •"
local r = reaper

r.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
r.PreventUIRefresh(-1);

function Render_trk_to_streo_p_fader_unmute()
   r.Main_OnCommand(40405, 0);
   r.Main_OnCommand(40421, 0);
   r.Main_OnCommand(40118, 0);
   r.Main_OnCommand(40005, 0);
   r.Main_OnCommand(40339, 0);
end

Render_trk_to_streo_p_fader_unmute() --Выполняем функцию
r.UpdateArrange() -- на всякий случай обновляет аранж
r.UpdateTimeline()

r.PreventUIRefresh(-1);
r.Undo_EndBlock(d, -1)
