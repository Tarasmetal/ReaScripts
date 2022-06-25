-- @description trs_set pan or take
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies

-- local r = reaper

-- local items = r.CountSelectedMediaItems()

-- r.Undo_BeginBlock(); r.PreventUIRefresh(1)

-- -- if items > 0 then
-- --   for i = 0, items-1 do
-- --     local item = r.GetSelectedMediaItem(0,i)
-- --     if item then
-- --       local take = r.GetActiveTake(item)
-- --       if not take then return end
-- --       chan_mode = r.GetMediaItemTakeInfo_Value(take, 'I_CHANMODE')
-- --       if chan_mode < 4 then chan_mode = chan_mode+1 else chan_mode = 0 end
-- --       r.SetMediaItemTakeInfo_Value(take, 'I_CHANMODE', chan_mode)
-- --     end
-- --   end
-- -- else
--   tracks = r.CountSelectedTracks()
--   if tracks == 0 then return end
--   for i = 0, tracks-1 do
--     tr = r.GetSelectedTrack(0,i)
--     tr_pan_mode = r.GetMediaTrackInfo_Value(tr, 'I_PANMODE')
--    if tr_pan_mode == 0 then tr_pan_mode = -50 end
--    -- elseif tr_pan_mode == 5 then tr_pan_mode = 6
--    -- elseif tr_pan_mode == 6 then tr_pan_mode = -1 end
--     r.SetMediaTrackInfo_Value(tr, 'D_PAN',0.01*tr_pan_mode)

--   end
-- -- end

-- r.PreventUIRefresh(-1); r.Undo_EndBlock('set next track pan mode or take channel mode', -1)

function nothing() end; function bla() reaper.defer(nothing) end
--retval, pan = reaper.GetUserInputs("Pan", 1, "Set track pan, percents:", "50")
pan = -66
--if pan > 0 then
  pan = tonumber(pan)
  if pan >=-100 and pan <=100 then
    reaper.Undo_BeginBlock()
    for i = 0, reaper.CountSelectedTracks(0)-1 do
      tr = reaper.GetSelectedTrack(0,i)
      reaper.SetMediaTrackInfo_Value(tr, 'D_PAN', 0.01*pan)
    end
    reaper.Undo_EndBlock('Set '..pan..' pan for sel tracks', -1)
 else bla() end
--else bla() end
