-- @description trs_REC Vox & Master output mute
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies

 -- Set Button ON
 function master_state_on()
		reaper.Main_OnCommand(8, 1) -- Track FX ByPass - OFF
		reaper.Main_OnCommand( reaper.NamedCommandLookup("_SWS_DISMASTERFX"), 0) -- Master FX - OFF
		reaper.Main_OnCommand( reaper.NamedCommandLookup("_SWS_RECREDRULER"), 0) -- REC RULER
		reaper.Main_OnCommand(1013, 1)-- REC PLAY
		reaper.Main_OnCommand( reaper.NamedCommandLookup("_XEN_SET_MAS_SEND0MUTE"), 0) -- Master state - MUTE
		reaper.UpdateArrange()  -- UPDATE
end

-- Set Button OFF
 function master_state_off()
		reaper.Main_OnCommand(40044, 0)-- REC STOP
		reaper.Main_OnCommand(8, 0) -- Track FX ByPass - ON
		reaper.Main_OnCommand( reaper.NamedCommandLookup("_SWS_ENMASTERFX"), 0) -- Master FX - ON
		reaper.Main_OnCommand( reaper.NamedCommandLookup("_XEN_UNSET_MAS_SEND0MUTE"), 0) -- Master state - UNMUTE
		reaper.UpdateArrange()
end

-- Main Function (which loop in background)
function main()
	reaper.defer( main )
end

-- RUN
master_state_on()
reaper.UpdateArrange()
main()
reaper.atexit( master_state_off )
reaper.UpdateArrange()
