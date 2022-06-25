--[[
* ReaScript Name: kawa_MAIN_TakeNameFromTrackNameWithNumbering.
* Version: 2017/02/03
* Author: kawa_
* link: https://bitbucket.org/kawaCat/reascript-m2bpack/
--]]

local r = reaper
local bpm = r.GetProjectTimeSignature2(0)
r.DeleteExtState('me2beats_copy-paste', 'bpm', 0)
r.SetExtState('me2beats_copy-paste', 'bpm', bpm, 0)

-- local bpm = r.GetExtState('me2beats_copy-paste', 'bpm')
-- if bpm and bpm ~= '' then
--   r.Undo_BeginBlock() r.SetCurrentBPM(0, bpm, 1) r.Undo_EndBlock('Paste BPM', -1)
-- end

local d="trs_Take Name From Track Name numbering & BPM"
local i=0;
local l=200;
local function t(e)
	local a=true;
	local t=reaper.CountSelectedMediaItems(i);if(t>e)
	then reaper.ShowMessageBox("над "..tostring(e).." клип номер .\nОстановить процесс","стоп.",0)
		a=false;
	end
	return a end if(t(l)==false)
	then
		return end

		local function c(e)
			local t=reaper.CountSelectedMediaItems(e);
			local d=reaper.GetProjectLength(e);
			local o={}
			local a={}
			local n=0;while(n<t)
			do
				local t=reaper.GetSelectedMediaItem(e,n);
				local l=reaper.GetMediaItemTrack(t);
				local e=reaper.GetMediaTrackInfo_Value(l,"IP_TRACKNUMBER");if(a[e]==nil)
				then a[e]={}
					local t=reaper.CountTrackMediaItems(l);
					local r=0;while(r<t)
					do
						local t=reaper.GetTrackMediaItem(l,r)
						local n=reaper.GetMediaItemInfo_Value(t,"D_POSITION")
						local o=reaper.GetMediaItemInfo_Value(t,"D_LENGTH")
						local t=
						{
							mediaItem=t,
							startTime=n,
							length=o,
							endTime=n+o,
							mediaItemIdx=reaper.GetMediaItemInfo_Value(t,"IP_ITEMNUMBER"),
							trackId=e,
							mediaTrack=l
						}
						;table.insert(a[e],t);r=r+1;
					end table.sort(a[e],
						function(a,e)
							return(a.startTime>e.startTime);
						end);
				end

				local i=reaper.GetMediaItemInfo_Value(t,"D_POSITION")
				local r=reaper.GetMediaItemInfo_Value(t,"D_LENGTH")
				local t=
				{
					mediaItem=t,
					startTime=i,
					length=r,
					endTime=i+r,
					mediaItemIdx=reaper.GetMediaItemInfo_Value(t,"IP_ITEMNUMBER"),
					trackId=e,
					mediaTrack=l,
					nextItemStartTime=nil,
					nextMediaItem=nil
				}
				;

				local r=d;
				local l=nil
				for a,e in ipairs(a[e])
				do if(e.mediaItemIdx==t.mediaItemIdx)
					then t.nextItemStartTime=r;t.nextMediaItem=l;end r=e.startTime;l=e;end if(o[e]==nil)
					then o[e]={}
					end table.insert(o[e],t);n=n+1;end return a,o end local function a(e)
					local e=reaper.GetTake(e,reaper.GetMediaItemInfo_Value(e,"I_CURTAKE"))
					return e;end local function l()
					local t,e=c(i)
					for t,e in pairs(e)
					do for t,e in ipairs(e)
						do
							local a=a(e.mediaItem)
							local e=e.mediaTrack
							local l,
							e=reaper.GetSetMediaTrackInfo_String(e,"P_NAME","",false)
							if(a~=nil)
								then
									-- local t="."..tostring(t);
									-- local t="."..tostring(t).." ("..bpm..' bpm)';
									local t="."..tostring(t).." ("..bpm..')';
									local e,
									e=reaper.GetSetMediaItemTakeInfo_String(a,"P_NAME",e..t,true)
								end end end end reaper.Undo_BeginBlock();l()
								reaper.Undo_EndBlock(d,-1);reaper.UpdateArrange();