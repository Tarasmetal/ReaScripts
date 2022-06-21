-- @description Marker Functions
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [nomain] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
--   # Marker Functions
-- @changelog
--  + Code optimizations

local r = reaper
-- таблица с кодами цветов
ColorMap = {
    blue = {0,0,255},
    red = {255,0,0},
    green = {0,255,0},
    cyan = {0,255,255},
    magenta = {255,0,255},
    yellow = {255,255,0},
    orange = {255,125,0},
    purple = {125,0,225},
    lightblue = {13,165,175},
    lightgreen = {125,255,155},
    pink = {225,0,255},
    brown = {125,95,25},
    gray = {125,125,125},
    white =  {255,255,255},
    black =  {0,0,0},
}

function songTimeAll()

local TIME_FORMAT = 1       -- number of timestamp format from the above list
local POS_POINTER = 1       -- 1 - Edit cursor, any other number - Mouse cursor

local err1 = (not TIME_FORMAT or type(TIME_FORMAT) ~= 'number' or TIME_FORMAT < 1 or TIME_FORMAT > 9) and '       Incorrect timestamp format.\n\nMust be a number between 1 and 9.'
local err2 = not POS_POINTER or type(POS_POINTER) ~= 'number' and 'Incorrect position pointer format.\n\n\tMust be a number.'
local err = err1 or err2

    if err then r.MB(err,'USER SETTINGS error',0) r.defer(function() end) return end

local t = {
'%H:%M:%S', -- 1
'%d.%m.%y - %H:%M:%S', -- 2
'%d.%m.%Y - %I:%M:%S', -- 3
'%d.%m.%y - %I:%M:%S', -- 4
'%m.%d.%Y - %H:%M:%S', -- 5
'%m.%d.%y - %H:%M:%S', -- 6
'%m.%d.%Y - %I:%M:%S', -- 7
'%m.%d.%y - %I:%M:%S', -- 8
'%x - %X'          -- 9
}
os.setlocale('', 'time')

local daytime = tonumber(os.date('%H')) < 12 and ' AM' or ' PM' -- for 3,4,7,8 using 12 hour cycle
local daytime = (TIME_FORMAT == 3 or TIME_FORMAT == 4 or TIME_FORMAT == 7 or TIME_FORMAT == 8) and daytime or ''
local timestamp = os.date(t[TIME_FORMAT])..daytime
    return timestamp
end

function hex2rgb(HEX_COLOR)
-- https://gist.github.com/jasonbradley/4357406
    if HEX_COLOR == nil then
        HEX_COLOR = '#FFFFFF'
    end
    local hex = HEX_COLOR:sub(2)
    return '0x' .. hex .. 'FF'
end

function convertColor(color)
    if color then
        if type(color) == "table" or type(color) == "string" then
            return reaper.ColorToNative(table.unpack(ColorMap[color]))|0x1000000
        else
            return color
    end
    end
end

function mySort(a,b)
    if  a[1] < b [1] then
        return true
    end
    return false
end

--твоя функция которую я на скорую руку начал рефакторить и разбил на несколько, см еще фунции ниже
-- предполагаемая задача этой функции - вернуть колво маркеров с таким же названием
function getLastId(name)
    local last_id0 = -1
    for idx =1, ({reaper.CountProjectMarkers( 0 )})[2] do
        local _, _, _, _, m_name = reaper.EnumProjectMarkers( idx-1 )
        local last_id = m_name:lower():match(name:lower()..'(%s%d+)')
        if last_id and tonumber(last_id) then
            last_id0 = math.max(last_id0, tonumber( last_id))
        end
    end
    return last_id0
end

-- предполагаемая задача этой - вернуть новый номер
function generateId(name)
    local last_id = getLastId(name)
    if not last_id or last_id == -1 then
        return 1
    end
    last_id = last_id + 1
    return last_id
end

-- сама основная функция вставляющая маркер
function insertMarker(name, color, ColorMap)
    reaper.Undo_BeginBlock()

    if color == nil or color == '' then
        color = reaper.ColorToNative(0,0,0)|0x0000000
    else
        color = reaper.ColorToNative(table.unpack(ColorMap[color]))|0x1000000
    end

    local _, num_markers, _ = reaper.CountProjectMarkers(0)
    local cursor_pos = reaper.GetCursorPosition()

    reaper.AddProjectMarker2(0, 0, cursor_pos, 0, name..' '..generateId(name), num_markers+1, color)
    reaper.Undo_EndBlock("Insert marker • " ..name, -1)
end

function insertMarkerNoID(name, color, ColorMap)
    reaper.Undo_BeginBlock()

    if color == nil or color == '' then
        color = reaper.ColorToNative(0,0,0)|0x0000000
    else
        color = reaper.ColorToNative(table.unpack(ColorMap[color]))|0x1000000
    end

    local _, num_markers, _ = reaper.CountProjectMarkers(0)
    local cursor_pos = reaper.GetCursorPosition()

    reaper.AddProjectMarker2(0, 0, cursor_pos, 0, name, num_markers, color)
    reaper.Undo_EndBlock("Insert NoID • " ..name, -1)
end

function insertMarkerStartEnd(name,color)
reaper.Undo_BeginBlock()
local pos = reaper.GetCursorPosition()
for i=1,100 do
    reaper.DeleteProjectMarker(0, 0, 0)
end

if color == nil or color == '' then
    color = reaper.ColorToNative(0,0,0)|0x0000000
else
    color = reaper.ColorToNative(table.unpack(color))|0x1000000
end

reaper.AddProjectMarker2(0,0,pos,0, name, 0, color)
reaper.Undo_EndBlock('Set Marker • ' .. name, -1)
reaper.UpdateArrange()
end

function insertMarkerStart(name,color)
reaper.Undo_BeginBlock()
-- local ma, num, mc = reaper.CountProjectMarkers(0)
local pos = reaper.GetCursorPosition()
max = 100
for i=1,max do
    reaper.DeleteProjectMarker(0, 0, 0)
end

if color == nil or color == '' then
    color = reaper.ColorToNative(0,0,0)|0x0000000
else
    color = reaper.ColorToNative(table.unpack(color))|0x1000000
end

reaper.AddProjectMarker2(0,0,pos,0, name, 0, color)
reaper.Undo_EndBlock('Set Marker • ' .. name, -1)
reaper.UpdateArrange()
end

function insertMarkerEnd(name,color)
reaper.Undo_BeginBlock()
local pos = reaper.GetCursorPosition()
max = 99
for i=1,max do
    reaper.DeleteProjectMarker(0, max, 0)
end

if color == nil or color == '' then
    color = reaper.ColorToNative(0,0,0)|0x0000000
else
    color = reaper.ColorToNative(table.unpack(color))|0x1000000
end

reaper.AddProjectMarker2(0,0,pos,0, name, max, color)
reaper.Undo_EndBlock('Set Marker • ' .. name, -1)
reaper.UpdateArrange()
end

-- function insertMarkerEnd(name,color)

-- local marker_num = reaper.CountProjectMarkers(0)

-- for i=0, marker_num do
--      local _, _, pos, _, name, id = reaper.EnumProjectMarkers(i)
--     if name == "=END" then
--         -- reaper.SetEditCurPos(pos, true, false)
--         reaper.DeleteProjectMarker(0, true, 0)
--         -- r.DeleteProjectMarker(0, id, 0)
--     end
--         r.AddProjectMarker2(0,0,pos,0, name, 0, r.ColorToNative(table.unpack(color))|0x1000000)
-- end

-- if reaper.GetPlayState() == 1 then -- if playback is on
--     reaper.OnPlayButton() -- press play to move the play cursor to the edit cursor
-- end

 -- if color == nil or color == '' then
 --            color = reaper.ColorToNative(0,0,0)|0x0000000
 --        else
 --            color = reaper.ColorToNative(table.unpack(color))|0x1000000
 --        end

-- r.AddProjectMarker2(0,0,pos,0, name, 0, color)
-- reaper.Undo_EndBlock('Set Marker • ' .. name, -1)
-- reaper.UpdateArrange()

-- function NoUndoPoint() end
-- reaper.defer(NoUndoPoint)
-- end

-- function insertMarkerEnd(name, color, ColorMap)
--     local cursor_pos = reaper.GetCursorPosition()
--     local marker_count = reaper.CountProjectMarkers(0)
--     for m = 0, marker_count-1 do
--         _, _, _, _, name, marker_id = reaper.EnumProjectMarkers(m)

--         if name == "=END" then
--             marker_exists = 1
--             break
--         end
--     end
--     reaper.Undo_BeginBlock2(0)
--     if marker_exists then
--         reaper.SetProjectMarker(marker_id, false, cursor_pos, 0, "=END")
--     else
--         if color == nil or '' then
--         color = reaper.ColorToNative(255,0,255)|0x0000000
--     else
--         color = reaper.ColorToNative(table.unpack(ColorMap[color]))|0x1000000
--     end
--         reaper.AddProjectMarker(0, false, cursor_pos, 0, "=END", -1, color)
--     end
--     reaper.Undo_EndBlock2(0, "trs_Set END marker", -1)
--     reaper.UpdateArrange()
-- end