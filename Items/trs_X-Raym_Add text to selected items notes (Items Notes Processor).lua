--[[
 * ReaScript Name: Add text to selected items notes (Items Notes Processor)
 * About: Equivalent to SWS label processor, but for items notes. Select items. Run. See below for customization and wildcards references.
 * Screenshot: http://i.giphy.com/l41lPYdijt9494V5S.gif
 * Author: X-Raym
 * Author URI: http://extremraym.com
 * Repository: GitHub > X-Raym > EEL Scripts for Cockos REAPER
 * Repository URI: https://github.com/X-Raym/REAPER-EEL-Scripts
 * Licence: GPL v3
 * Forum Thread: Scripts (LUA): Text Items Formatting Actions (various)
 * Forum Thread URI: http://forum.cockos.com/showthread.php?t=156757
 * REAPER: 5.0
 * Extensions: SWS/S&M 2.8.1
 * Version: 2.0
--]]

--[[
 * Changelog:
 * v2.0 (2020-06-10)
	+ one single line input $notes wildcard based
	+ \n for break lines
 * v1.3 (2020-06-09)
	+ /r for regions
 * v1.2 (2016-04-12)
	+ Added "Below" and Above keywords. "After" and "Before" now work without breaklines.
	+ Argument for /E and /I (leading zeros and offset) like this /Eoffset_digits eg /E2_2 will output 03 for first selected items
 * v1.1 (2015-10-07)
	+ Replace
	+ User config area
	+ Shortcut (B for Before, A for After, R for Replace)
	# bug fixes
 * v1.0 (2015-05-06)
	+ Initial Release
--]]

--[[ ------ TEXT WILDCARDS REFERENCES ---------------------
/E -- перечислить в выделении
/I -- обратное перечисление в выделении
/T -- Название трека
/t -- Номер дорожки
--]] -----------------------------------------------------


-- ------ USER CONFIG AREA -----------------------------
--default_text = "/E3_0_" -- "Text"
-- default_text = "Snare Top0/E_120_127" -- "Text"
default_text = "/T /E" -- "Text"
popup = true
console = false
-- ------ USER CONFIG AREA -----------------------------

function Msg(value)
	if console then
		reaper.ShowConsoleMsg(tostring(value) .. "\n")
	end
end


function AddZerosAndOffset(number, zeros, offset)

	local number = number + offset

	number = tostring(number)

	number = string.format('%0' .. zeros .. 'd', number)
	Msg(number)

	return number

end


function ProcessKeyword(input, number, keyword)

	local zeros, offset = input:match(keyword .. "(%d+)_([^,]+)_")

	if zeros or offset then
		Msg('zeros = ' .. zeros)
		Msg('offset = ' .. offset)
		local number = AddZerosAndOffset(number, zeros, offset)
		input = input:gsub(keyword .. "(%d+)_([^,]+)_", tostring(number))
	else
		input = input:gsub(keyword, tostring(number))
	end

	return input

end


function main(text)

	reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the

	-- INITIALIZE loop through selected items
	for i = 0, selected_items_count-1  do
		-- GET ITEMS
		item = reaper.GetSelectedMediaItem(0, i) -- Get selected item i

		track = reaper.GetMediaItemTrack(item)
		track_id = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
		track_name_retval, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

		-- Some possible keywords from SWS label processor
		-- /D -- Duration
		-- /E[digits, first] -- enumerate in selection
		-- /e[digits, first] -- enumerate in selection on track
		-- /I[digits, first] -- inverse enumerate in selection
		-- /i[digits, first] -- inverse enumerate in selection on track
		-- /T[offset, length] -- Track name
		-- /t[digits] -- Track number

		input = text
		Msg('input = ' .. input)

		if string.find(input, "/E") then
			number = i + 1

			input  = ProcessKeyword(input, number, "/E")
		end

		if string.find(input, "/I") then
			number = selected_items_count - i

			input  = ProcessKeyword(input, number, "/I")
		end

		input = input:gsub("/T", track_name)
		input = input:gsub("/t", tostring(track_id))
		item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		markeridx, regionidx = reaper.GetLastMarkerAndCurRegion( 0, item_pos )
		retval, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers( regionidx )
		input = input:gsub("/r", name )

		notes = reaper.ULT_GetMediaItemNote(item)
		input = input:gsub("$notes", notes )
		input = input:gsub("\\n", "\r\n" )

		reaper.ULT_SetMediaItemNote(item, input)

	end -- end of items loop

	reaper.Undo_EndBlock("Add text to selected items notes (Items Notes Processor)", -1) -- End of the undo block. Leave it at the bottom of your main function

end -- end of function


reaper.PreventUIRefresh(1)

selected_items_count = reaper.CountSelectedMediaItems(0)

if selected_items_count > 0 then

	if popup then
		retval, default_text = reaper.GetUserInputs("Item Notes Processor", 1, "Text (/Ex_x /I /T /t /r \\n):,extrawidth=150", default_text)
	end

	if retval or not popup then

		if console then reaper.ClearConsole() end

		main(default_text) -- Execute your main function

	end

end

reaper.UpdateArrange() -- Update the arrangement (often needed)

reaper.PreventUIRefresh(-1)
