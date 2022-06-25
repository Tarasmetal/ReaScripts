-- @description trs_Set_grid_Size
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


local HWND = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(HWND)
local get_grid = reaper.MIDI_GetGrid(take)
local menu_01, menu_02, menu_03, menu_04, menu_05, menu_06, menu_07, menu_08, menu_09, menu_10, straight_on, triplet_on, dotted_on, swing_on

if reaper.GetToggleCommandStateEx(32060, 41003) == 1 then
  if get_grid == 1/32 then menu_01 = true else menu_01 = false end
  if get_grid == 1/16 then menu_02 = true else menu_02 = false end
  if get_grid == 1/8 then menu_03 = true else menu_03 = false end
  if get_grid == 1/4 then menu_04 = true else menu_04 = false end
  if get_grid == 1/2 then menu_05 = true else menu_05 = false end
  if get_grid == 1 then menu_06 = true else menu_06 = false end
  if get_grid == 2 then menu_07 = true else menu_07 = false end
  if get_grid == 4 then menu_08 = true else menu_08 = false end
  if get_grid == 8 then menu_09 = true else menu_09 = false end
  if get_grid == 16 then menu_10 = true else menu_10 = false end
  straight_on = true
end

if reaper.GetToggleCommandStateEx(32060, 41004) == 1 then
  if get_grid == 1/48 then menu_01 = true else menu_01 = false end
  if get_grid == 1/24 then menu_02 = true else menu_02 = false end
  if get_grid == 1/12 then menu_03 = true else menu_03 = false end
  if get_grid == 1/6 then menu_04 = true else menu_04 = false end
  if get_grid == 1/3 then menu_05 = true else menu_05 = false end
  if get_grid == 1/1.5 then menu_06 = true else menu_06 = false end
  if get_grid == 1/0.75 then menu_07 = true else menu_07 = false end
  if get_grid == 1/0.375 then menu_08 = true else menu_08 = false end
  if get_grid == 1/0.1875 then menu_09 = true else menu_09 = false end
  if get_grid == 1/0.09375 then menu_10 = true else menu_10 = false end
  triplet_on = true
end

if reaper.GetToggleCommandStateEx(32060, 41005) == 1 then
  if get_grid == 1.5/32 then menu_01 = true else menu_01 = false end
  if get_grid == 1.5/16 then menu_02 = true else menu_02 = false end
  if get_grid == 1.5/8 then menu_03 = true else menu_03 = false end
  if get_grid == 1.5/4 then menu_04 = true else menu_04 = false end
  if get_grid == 1.5/2 then menu_05 = true else menu_05 = false end
  if get_grid == 1.5 then menu_06 = true else menu_06 = false end
  if get_grid == 3 then menu_07 = true else menu_07 = false end
  if get_grid == 6 then menu_08 = true else menu_08 = false end
  if get_grid == 12 then menu_09 = true else menu_09 = false end
  if get_grid == 24 then menu_10 = true else menu_10 = false end
  dotted_on = true
end

if reaper.GetToggleCommandStateEx(32060, 41006) == 1 then
  swing_on = true
end

local menu = "#GRID||"
menu = menu
.. (menu_01 and "!" or "") .. "1/128" .. "|"
.. (menu_02 and "!" or "") .. "1/64" .. "|"
.. (menu_03 and "!" or "") .. "1/32" .. "|"
.. (menu_04 and "!" or "") .. "1/16" .. "|"
.. (menu_05 and "!" or "") .. "1/8" .. "|"
.. (menu_06 and "!" or "") .. "1/4" .. "|"
.. (menu_07 and "!" or "") .. "1/2" .. "|"
.. (menu_08 and "!" or "") .. "1" .. "|"
.. (menu_09 and "!" or "") .. "2" .. "|"
.. (menu_10 and "!" or "") .. "4" .. "||"
.. (straight_on and "!" or "") .. "straight" .. "|"
.. (triplet_on and "!" or "") .. "triplet" .. "|"
.. (dotted_on and "!" or "") .. "dotted" .. "|"
.. (swing_on and "!" or "") .. "swing" .. "|"

local title = "Hidden gfx window for showing the grid showmenu"
gfx.init(title, 0, 0, 0, 0, 0)
local dyn_win = reaper.JS_Window_Find(title, true)
local out = 0
if dyn_win then
  out = 7000
  reaper.JS_Window_Move(dyn_win, -out, -out)
end
local x, y = reaper.GetMousePosition()
gfx.x, gfx.y = x - 7 + out, y - 30 + out
local selection = gfx.showmenu(menu)
selection = math.floor(selection)
gfx.quit()

if selection > 0 then
  selection = selection - 1
  if selection == 1 then reaper.MIDIEditor_OnCommand(HWND, 41008) end -- 1/128
  if selection == 2 then reaper.MIDIEditor_OnCommand(HWND, 41009) end -- 1/64
  if selection == 3 then reaper.MIDIEditor_OnCommand(HWND, 41010) end -- 1/32
  if selection == 4 then reaper.MIDIEditor_OnCommand(HWND, 41011) end -- 1/16
  if selection == 5 then reaper.MIDIEditor_OnCommand(HWND, 41012) end -- 1/8
  if selection == 6 then reaper.MIDIEditor_OnCommand(HWND, 41013) end -- 1/4
  if selection == 7 then reaper.MIDIEditor_OnCommand(HWND, 41014) end -- 1/2
  if selection == 8 then reaper.MIDIEditor_OnCommand(HWND, 41015) end -- 1
  if selection == 9 then reaper.MIDIEditor_OnCommand(HWND, 41016) end -- 2
  if selection == 10 then reaper.MIDIEditor_OnCommand(HWND, 41017) end -- 4
  if selection == 11 then reaper.MIDIEditor_OnCommand(HWND, 41003) end -- straight
  if selection == 12 then reaper.MIDIEditor_OnCommand(HWND, 41004) end -- triplet
  if selection == 13 then reaper.MIDIEditor_OnCommand(HWND, 41005) end -- dotted
  if selection == 14 then reaper.MIDIEditor_OnCommand(HWND, 41006) end -- swing
end
reaper.SN_FocusMIDIEditor() -- Focus MIDIEditor
reaper.defer(function() end)