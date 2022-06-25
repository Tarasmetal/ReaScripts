-- @description trs_Label Processor
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


function trs_Label_Processor(LP)

   reaper.Undo_BeginBlock(-1) -- для того, чтобы можно было отменить действие
   reaper.PreventUIRefresh(0);

   local LP = '/T /e[1]./k'
   reaper.CF_SetClipboard(LP)

   -- reaper.Main_OnCommand(reaper.NamedCommandLookup"_IX_LABEL_PROC","xxx", 0); -- /T /e[1]./k
   reaper.Main_OnCommand(reaper.NamedCommandLookup"_IX_LABEL_PROC", 0, LP); -- /T /e[1]./k

   reaper.CF_GetClipboard(LP)

   reaper.PreventUIRefresh(0);
   reaper.Undo_EndBlock("trs_Label Processor •", -1)
end


trs_Label_Processor(LP) --Выполняем функцию

-- reaper.UpdateArrange() -- на всякий случай обновляет аранж
-- reaper.UpdateTimeline()
