-- @description trs_Set_project_timebase_to_beats
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


local r = reaper
local d = "• trs_Set_Startup_Action •"


function trs_Set_project_timebase_to_beats()

	r.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
	r.PreventUIRefresh(1)
	-- track_beat = r.NamedCommandLookup("_SWS_AWTRACKTBASEBEATALL"); -- Get non-native action command_name
	-- r.Main_OnCommand(track_beat, 0); -- MAIN section action "Sel track with selected Item"
	r.Main_OnCommand(r.NamedCommandLookup"_SWS_AWTBASEBEATALL", 0); -- SWS/AW: Set project timebase to beats (position, length, rate)
	-- r.Main_OnCommand(r.NamedCommandLookup"_SWS_AWITEMTBASEPROJ", 0); -- SWS/AW: Set selected items timebase to project/track default
	-- r.Main_OnCommand(r.NamedCommandLookup"_SWS_AWTRACKTBASEPROJ", 0); -- SWS/AW: Set selected tracks timebase to project default
	-- r.Main_OnCommand(r.NamedCommandLookup"_SWSCONSOLE2",0); -- MAIN section action "Sel track with selected Item"

	r.PreventUIRefresh(-1)
	r.Undo_EndBlock("• Set timebase to beats (pos, len, rate) •", 0)
end

trs_Set_project_timebase_to_beats() --Выполняем функцию
r.UpdateTimeline()
r.UpdateArrange()
