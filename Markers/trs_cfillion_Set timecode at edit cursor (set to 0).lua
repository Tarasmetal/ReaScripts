-- @description Set timecode at edit cursor
-- @author cfillion (Taras MOD)
-- @version 1.2
-- @changelog Add a "set to 0" action
-- @provides [main] .
-- @link
--   cfillion.ca https://cfillion.ca
--   Request Thread https://forum.cockos.com/showthread.php?t=202578
-- @screenshot https://i.imgur.com/uly6oy5.gif
-- @donation https://www.paypal.com/cgi-bin/webscr?business=T3DEWBQJAV7WL&cmd=_donations&currency_code=CAD

-- USER CONFIG AREA --
local SCRIPT_NAME = ({reaper.get_action_context()})[2]:match("([^/\\_]+)%.lua$")

local r = reaper
local p_text = 'trs'..'_'
local d_text = SCRIPT_NAME
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

-- END OF USER CONFIG AREA --
r.Undo_BeginBlock() -- для того, чтобы можно было отменить действие
r.PreventUIRefresh(-1);
--=====================
local MODE = ({
  ['time'    ] =  0,
  ['seconds' ] =  3,
  ['frames'  ] =  5,
  ['set to 0'] = -1,
})[SCRIPT_NAME:match('%(([^%)]+)%)') or 'time']

assert(MODE, "Internal error: unknown timecode format")
assert(reaper.SNM_GetDoubleConfigVar, "SWS is required to use this script")

local curpos = reaper.GetCursorPosition()
local timecode = 0

if MODE >= 0 then
  timecode = reaper.format_timestr_pos(curpos, '', MODE)
  -- local ok, csv = reaper.GetUserInputs(SCRIPT_NAME, 1, "Timecode,extrawidth=50", timecode)
  local ok, csv = reaper.GetUserInputs(SCRIPT_NAME, 0, "Timecode,extrawidth=50", timecode)

  -- if not ok then
  if ok then
    reaper.defer(function() end)
    return
  end

  timecode = reaper.parse_timestr_len(csv, 0, MODE)
end

reaper.SNM_SetDoubleConfigVar('projtimeoffs', timecode - curpos)
reaper.UpdateTimeline()
--=====================
r.PreventUIRefresh(0);
r.Undo_EndBlock(d, -1) -- для того, чтобы можно было отменить действие


