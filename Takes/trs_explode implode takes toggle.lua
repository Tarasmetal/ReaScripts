-- @description trs_explode implode takes toggle
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
local d_text = 'Explode implode takes toggle'
local d = d_text

if d_text ~= '' then
  d_text = string.format('• ' .. p_text .. d_text .. ' •')
else
  d_text = string.format('• ' .. p_text .. 'T@RvZ Test Script' .. ' •')
end

console = false -- true/false: display debug messages in the console
-- msg("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")

-- Display a message in the console for debugging
function msg(value)
  if console then
    r.ShowConsoleMsg('♦ '.. tostring(value) .. " ♦" .. "\n")
  end
end
msg(''..d_text..'')

 -- Set ToolBar Button ON
function SetButtonON()
  r.Undo_BeginBlock() -- отменить действие

  reaper.Main_OnCommand(40642, 0) -- Take: Explode takes of items in place

  is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  state = r.GetToggleCommandStateEx( sec, cmd )
  r.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
  r.RefreshToolbar2( sec, cmd )

  r.Undo_EndBlock(d .. " • ON", 1)
end

-- Set ToolBar Button OFF
function SetButtonOFF()
  r.Undo_BeginBlock() -- отменить действие

   -- r.Main_OnCommand(r.NamedCommandLookup('_RS722e8613a4f575481cc318bdd802f986ce742d68'), 1)
   --__________________________________
   _, _, _ = reaper.BR_GetMouseCursorContext()
track = reaper.BR_GetMouseCursorContext_Track()

if track ~= nil then
  num_items = reaper.GetTrackNumMediaItems(track)

  if num_items > 0 then
    reaper.Undo_BeginBlock()
    reaper.Main_OnCommand(40289, 0)

    first_item = reaper.GetTrackMediaItem(track, 0)
    first_item_sel =  reaper.IsMediaItemSelected(first_item)

    for i = 0, num_items - 1 do
      item = reaper.GetTrackMediaItem(track, i)
      reaper.SetMediaItemSelected(item, not first_item_sel)
    end

    reaper.Undo_EndBlock("Toggle selecting all items on track under mouse cursor", 0)
  end
end
   reaper.Main_OnCommand(40543, 1) -- Take: Implode items on same track into takes

  is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  state = r.GetToggleCommandStateEx( sec, cmd )
  r.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
  r.RefreshToolbar2( sec, cmd )

  r.Undo_EndBlock(d .. " • OFF", 0)
end

-- Main Function (which loop in background)
function main()
  r.defer( main )
end

-- RUN
SetButtonON()
main()
r.atexit( SetButtonOFF )
