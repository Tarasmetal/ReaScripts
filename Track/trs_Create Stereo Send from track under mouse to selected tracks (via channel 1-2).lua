--[[
Description: Создание стерео из трека под мышкой на выбранные треки (via channel 3-4)
Instructions:
Screenshot:
Version: 1.0
Author: Outboarder
REAPER: 5.40
Licence: GPL v3
--]]

--[[
Changelog:
+ Initial Release v1.0 (2017-07-05)
--]]

local r = reaper
local d = '• Create Stereo under mouse to sel track (via ch 1-2) •'
console = false -- true/false: display debug messages in the console

-- END OF USER CONFIG AREA --
r.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
r.PreventUIRefresh(-1);
--=====================

S_track = reaper.BR_TrackAtMouseCursor()

if S_track then
  Last_send = reaper.GetTrackNumSends( S_track , 0 )
  Ct = reaper.CountSelectedTracks( 0 )
  R_ch = 0
  for i = 0 ,Ct-1 do

    R_track = reaper.GetSelectedTrack( 0, i )
    reaper.SetMediaTrackInfo_Value( R_track, "I_NCHAN", Ct*2 ) -- Можно отключить.
    reaper.CreateTrackSend( S_track, R_track )
    reaper.BR_GetSetTrackSendInfo( S_track, 0, Last_send+i, "I_DSTCHAN", 1, R_ch )
  end
end

reaper.Undo_EndBlock(d, -1) -- End of the undo block. Leave it at the bottom of your main function.
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)





