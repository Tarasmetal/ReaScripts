-- @description trs_Create folder from sel. tracks
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies

-- USER CONFIG AREA --
local r = reaper
local p_text = 'trs'..'_'
local d_text = 'Create folder from sel. tracks'

if d_text ~= '' then
	string.format('• ' .. p_text .. d_text .. ' •')
else
	string.format('• ' .. p_text .. 'T@RvZ Test Script' .. ' •')
end

console = true -- true/false: display debug messages in the console
-- MSG("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")

-- Display a message in the console for debugging
function MSG(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

local function nothing() end; local function bla() r.defer(nothing) end
-- END OF USER CONFIG AREA --
r.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
r.PreventUIRefresh(-1);
--=====================
function last_tr_in_folder (folder_tr)
  last = nil
  local dep = r.GetTrackDepth(folder_tr)
  local num = r.GetMediaTrackInfo_Value(folder_tr, 'IP_TRACKNUMBER')
  local tracks = r.CountTracks()
  for i = num+1, tracks do
    if r.GetTrackDepth(r.GetTrack(0,i-1)) <= dep then last = r.GetTrack(0,i-2) break end
  end
  if last == nil then last = r.GetTrack(0, tracks-1) end
  return last
end

sel_tracks = r.CountSelectedTracks()
if sel_tracks == 0 then bla() end

first_sel = r.GetSelectedTrack(0,0)
tr_num = r.GetMediaTrackInfo_Value(first_sel, 'IP_TRACKNUMBER')

last_sel = r.GetSelectedTrack(0,sel_tracks-1)
last_sel_dep = r.GetMediaTrackInfo_Value(last_sel, 'I_FOLDERDEPTH')
if last_sel_dep == 1 then last_tr = last_tr_in_folder(last_sel) else last_tr = last_sel end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

r.InsertTrackAtIndex(tr_num-1, 1)
r.TrackList_AdjustWindows(0)
tr = r.GetTrack(0, tr_num-1)

r.SetMediaTrackInfo_Value(tr, 'I_FOLDERDEPTH', 1)
r.SetMediaTrackInfo_Value(last_tr, 'I_FOLDERDEPTH', last_sel_dep-1)
r.SetOnlyTrackSelected(tr)
r.Main_OnCommand(40914,0) -- Track: Set first selected track as last touched track


r.Main_OnCommand(40914,0) -- Track: Set first selected track as last touched track
r.Main_OnCommand(40913,0) -- Track: Vertical scroll selected tracks into view
-- r.Main_OnCommand(40696,0) -- Track: Rename last touched track
r.Main_OnCommand(r.NamedCommandLookup('_trs_trackrenametools'), 0);
-- r.Main_OnCommand(r.NamedCommandLookup('Script: trs_Group Selected Tracks with Rename.lua'), 0);

r.PreventUIRefresh(-1)
r.Undo_EndBlock(d_text, -1)
