-- @description trs_Recording
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


local d = "• trs_Recording •"

reaper.Undo_BeginBlock(0) -- для того, чтобы можно было отменить действие
reaper.PreventUIRefresh(-1);
--=====================

reaper.Main_OnCommand(40527, 0); -- View: Clear all peak indicators
reaper.Main_OnCommand(1013, 0); -- View: REC
-- reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SAVETIME1"), 0);

--=====================
reaper.PreventUIRefresh(-1);
reaper.Undo_EndBlock(d, -1) -- для того, чтобы можно было отменить действие
