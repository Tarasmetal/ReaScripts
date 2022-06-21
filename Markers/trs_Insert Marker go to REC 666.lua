-- @description Go to start marker 666 MOD
-- @version 1.1
-- @changelog
--  + Code optimizations
-- @author Stephan Römer
-- @author Stephan Römer (Taras MOD)
-- @link https://forums.cockos.com/showthread.php?p=1923923
-- @provides [main=main] .
-- @about
--  + Code optimizations

local marker_num = reaper.CountProjectMarkers(0)

for i=0, marker_num-1 do
    local _, _, pos, _, name, _ = reaper.EnumProjectMarkers(i)
    -- if name == "=START" or "=END" then
    if name == "REC" then
        reaper.SetEditCurPos(pos, true, false)
    end
end

if reaper.GetPlayState() == 1 then -- Если воспроизведение включено
    reaper.OnPlayButton() -- Нажмите PLAY, чтобы переместить курсор воспроизведения на курсор редактирования
end

reaper.UpdateArrange()

function NoUndoPoint() end
reaper.defer(NoUndoPoint)