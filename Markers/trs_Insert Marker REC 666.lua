-- @description Insert recording marker 666 MOD
-- @version 1.1
-- @changelog
--  + Code optimizations
-- @author Stephan Römer
-- @author Stephan Römer (Taras MOD)
-- @link https://forums.cockos.com/showthread.php?p=1923923
-- @provides [main=main] .
-- @about
--  + Code optimizations

local r = reaper
console = true

function msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

reaper.Undo_BeginBlock()
local pos = reaper.GetCursorPosition()
m_index = 666
for i=1,m_index do
    reaper.DeleteProjectMarker(0, m_index, 0)
end

if color == nil or color == '' then
    color = reaper.ColorToNative(0,0,0)|0x1000000
else
    color = reaper.ColorToNative(table.unpack(color))|0x1000000
end
reaper.AddProjectMarker2(0,0,pos,0, 'REC', m_index, color)
reaper.Undo_EndBlock('Set Marker • ' .. 'REC', -1)
reaper.UpdateArrange()

