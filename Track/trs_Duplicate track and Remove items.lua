-- @description trs_Duplicate track and Remove items
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
local d = 'trs_'
console = false -- true/false: display debug messages in the console
-- MSG("OFF ♦ "..(sec).." • "..(cmd).." • "..(mode).." • "..(resolution).." • "..(val).." ♦ ")

-- Display a message in the console for debugging
function MSG(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end
-- END OF USER CONFIG AREA --

r.Main_OnCommand(40527, 0); -- View: Clear all peak indicators

local function main()
  r.PreventUIRefresh(1)
  r.Undo_BeginBlock()

  r.Main_OnCommand(40062, 0) -- Track: Duplicate tracks
  r.Main_OnCommand(40421, 0) -- Item: Select all items in track
  r.Main_OnCommand(40006, 0) -- Item: Remove items

  r.Undo_EndBlock('trs_Duplicate tracks and Remove items', 0)
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.UpdateTimeline()
end

main()
