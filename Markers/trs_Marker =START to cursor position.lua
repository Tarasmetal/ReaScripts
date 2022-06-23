-- @description trs_Marker START
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
--  # trs_Marker START
-- @changelog
--  + Code Fixies

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
local pos = reaper.GetCursorPosition()
for i=1,100-1 do
	reaper.DeleteProjectMarker(0, 0, 0)
end
color = false
if color == false or color == nil or color == '' then
local color = reaper.ColorToNative(255,0,255)|0x1000000
reaper.AddProjectMarker2(0,0,pos,0, "=START", 0, color)
end
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("trs_Marker START", -1)
