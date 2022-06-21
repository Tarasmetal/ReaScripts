-- @description trs_ Set Marker =END
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
-- + trs_ Set Marker =END
-- @changelog
--  + Code Fixies

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
local pos = reaper.GetCursorPosition()
for i=1,0,1 do
	reaper.DeleteProjectMarker(0, 0, 0)
end
local color = reaper.ColorToNative(255,0,255)|0x1000000
reaper.AddProjectMarker2(0,0,pos,0, "=END", 0, color)
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("", -1)
reaper.UpdateArrange()
