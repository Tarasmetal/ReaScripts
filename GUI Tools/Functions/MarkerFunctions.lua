-- @description Marker Functions
-- @author Taras Umanskiy

local r = reaper

function msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

-- таблица с кодами цветов
col_arr = {
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

function convertColor(color)
    local r_val, g_val, b_val

    if not color or color == '' then
        return 0
    end

    if type(color) == 'string' then
        if col_arr[color:lower()] then
            r_val, g_val, b_val = table.unpack(col_arr[color:lower()])
        elseif color:match("^#?%x%x%x%x%x%x$") then
            local hex = color:gsub("#","")
            r_val = tonumber(hex:sub(1,2), 16)
            g_val = tonumber(hex:sub(3,4), 16)
            b_val = tonumber(hex:sub(5,6), 16)
        end
    elseif type(color) == 'table' then
        r_val, g_val, b_val = table.unpack(color)
    end

    if r_val and g_val and b_val then
        return reaper.ColorToNative(r_val, g_val, b_val)|0x1000000
    else
        return 0
    end
end

function round(num)
  return num ~= 0 and math.floor(num+0.5) or math.ceil(num-0.5)
end

-- function songTimeAll()

-- local TIME_FORMAT = 1       -- number of timestamp format from the above list
-- local POS_POINTER = 1       -- 1 - Edit cursor, any other number - Mouse cursor

-- local err1 = (not TIME_FORMAT or type(TIME_FORMAT) ~= 'number' or TIME_FORMAT < 1 or TIME_FORMAT > 9) and '       Incorrect timestamp format.\n\nMust be a number between 1 and 9.'
-- local err2 = not POS_POINTER or type(POS_POINTER) ~= 'number' and 'Incorrect position pointer format.\n\n\tMust be a number.'
-- local err = err1 or err2

--     if err then r.MB(err,'USER SETTINGS error',0) r.defer(function() end) return end

-- local t = {
-- '%H:%M:%S', -- 1
-- '%d.%m.%y - %H:%M:%S', -- 2
-- '%d.%m.%Y - %I:%M:%S', -- 3
-- '%d.%m.%y - %I:%M:%S', -- 4
-- '%m.%d.%Y - %H:%M:%S', -- 5
-- '%m.%d.%y - %H:%M:%S', -- 6
-- '%m.%d.%Y - %I:%M:%S', -- 7
-- '%m.%d.%y - %I:%M:%S', -- 8
-- '%x - %X'          -- 9
-- }
-- os.setlocale('', 'time')

-- local daytime = tonumber(os.date('%H')) < 12 and ' AM' or ' PM' -- for 3,4,7,8 using 12 hour cycle
-- local daytime = (TIME_FORMAT == 3 or TIME_FORMAT == 4 or TIME_FORMAT == 7 or TIME_FORMAT == 8) and daytime or ''
-- local timestamp = os.date(t[TIME_FORMAT])..daytime
--     return timestamp
-- end

-- function StopRegions()
--     local markerIndex = 0
--     local regionIndex = 0
--     local ret, isrgn, pos, rgnend, name, markrgnindexnumber
--     local num_markers, num_regions = r.CountProjectMarkers(0)
--     local total_count = num_markers + num_regions

--     -- Удаление всех маркеров с именем "!1016"
--     for i = total_count - 1, 0, -1 do
--         ret, isrgn, pos, rgnend, name, markrgnindexnumber = r.EnumProjectMarkers(i)
--         if ret ~= nil and name == "!1016" then
--             r.DeleteProjectMarkerByIndex(0, i)
--         end
--     end

--     for i = 0, total_count - 1 do
--         ret, isrgn, pos, rgnend, name, markrgnindexnumber = r.EnumProjectMarkers(i)
--         if ret ~= nil and isrgn then
--             r.AddProjectMarker(0, false, rgnend, 0, "!1016", 0)
--             -- r.AddProjectMarker(0, false, rgnend, 0, "!1016", markerIndex)
--             markerIndex = markerIndex + 1
--         end
--     end
-- end


function StopRegions()
    local markerIndex = 0
    local regionIndex = 0
    local ret, isrgn, pos, rgnend, name, markrgnindexnumber
    local num_markers, num_regions = r.CountProjectMarkers(0)
    local total_count = num_markers + num_regions

    -- Удаление всех маркеров с именем "!1016"
    for i = total_count - 1, 0, -1 do
        ret, isrgn, pos, rgnend, name, markrgnindexnumber = r.EnumProjectMarkers(i)
        if ret ~= nil and name == "!1016" then
            r.DeleteProjectMarkerByIndex(0, i)
        end
    end

    for i = 0, total_count - 1 do
        ret, isrgn, pos, rgnend, name, markrgnindexnumber = r.EnumProjectMarkers(i)
        if ret ~= nil and isrgn then
            -- Изменяем цвет маркера на чёрный
            r.AddProjectMarker(0, false, rgnend, 0xFF000000, "!1016", 0)
            markerIndex = markerIndex + 1
        end
    end
end

function StopRegionsDelete()
-- Начало отмены блока
reaper.Undo_BeginBlock()

-- Получаем количество маркеров и регионов в проекте
local num_markers_and_regions, num_markers = reaper.CountProjectMarkers(0)

-- Перебираем все маркеры и регионы
for i = num_markers_and_regions - 1, 0, -1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, i)
    if not isrgn and name == "!1016" then
        -- Удаляем маркер с заданным именем
        reaper.DeleteProjectMarkerByIndex(0, i)
    end
end

-- Конец отмены блока
reaper.Undo_EndBlock("Удалить все маркеры с названием '!1016'", -1)

-- Обновляем представление проекта
reaper.UpdateArrange()
end

function hex2rgb(HEX_COLOR)
-- https://gist.github.com/jasonbradley/4357406
    if HEX_COLOR == nil then
        HEX_COLOR = '#FFFFFF'
    end
    local hex = HEX_COLOR:sub(2)
    return '0x' .. hex .. 'FF'
end


function mySort(a,b)
    if  a[1] < b [1] then
        return true
    end
    return false
end

------------------------------------------------------------------------------------------------------------------

function RgbaToArgb(rgba)
  return (rgba >> 8 & 0x00FFFFFF) | (rgba << 24 & 0xFF000000)
end

function ArgbToRgba(argb)
  return (argb << 8) | (argb >> 24 & 0xFF)
end

-- function round(n)
--   return math.floor(n + .5)
-- end

function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

function Link(url)
  if not r.CF_ShellExecute then
    r.ImGui_Text(ctx, url)
    return
  end

  local color = r.ImGui_GetStyleColor(ctx, r.ImGui_Col_CheckMark())
  r.ImGui_TextColored(ctx, color, url)
  if r.ImGui_IsItemClicked(ctx) then
    r.CF_ShellExecute(url)
  elseif r.ImGui_IsItemHovered(ctx) then
    r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_Hand())
  end
end

function trs_HSV(h, s, v, a)
  local r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s, v)
  return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

------------------------------------------------------------------------------------------------------------------

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

function btn(label, color)
  reaper.ImGui_PushStyleColor(reaper.ImGui_Col_Button(), color)
  local clicked, selected = reaper.ImGui_Button(label)
  reaper.ImGui_PopStyleColor(1)
  return clicked, selected
end

-- сама основная функция вставляющая маркер
function insertMarker(name, color)

    reaper.Undo_BeginBlock()

    color = convertColor(color)

    local _, num_markers, _ = reaper.CountProjectMarkers(0)
    local cursor_pos = reaper.GetCursorPosition()

    if reaper.GetPlayState() & 1 == 1 then
        cursor_pos = reaper.SnapToGrid(0, reaper.GetPlayPosition())
    end

    reaper.AddProjectMarker2(0, 0, cursor_pos, 0, name..' '..generateId(name), num_markers+1, color)
    reaper.Undo_EndBlock("Insert marker • " ..name, -1)
end

-- -- сама основная функция вставляющая маркер
-- function insertMarker(name, color)
--     reaper.Undo_BeginBlock()

--     if color == nil or color == '' then
--         color = reaper.ColorToNative(0,0,0)|0x0000000
--     else
--         color = reaper.ColorToNative(table.unpack(col_arr[color]))|0x1000000
--     end

--     local _, num_markers, _ = reaper.CountProjectMarkers(0)
--     local cursor_pos = reaper.GetCursorPosition()

--     reaper.AddProjectMarker2(0, 0, cursor_pos, 0, name..' '..generateId(name), num_markers+1, color)
--     reaper.Undo_EndBlock("Insert marker • " ..name, -1)
-- end

function clrMarkers(n)

  -- local m_name = tostring(n)
  local m_name = n

  local markerCount = reaper.CountProjectMarkers(0)
  local markersToDelete = {}

  for i = 0, markerCount - 1 do
    local _, isrgn, pos, rgnend, name, id = reaper.EnumProjectMarkers(i)

    if name:find(m_name) then
      table.insert(markersToDelete, i)
    end
  end

  for i = #markersToDelete, 1, -1 do
    reaper.DeleteProjectMarkerByIndex(0, markersToDelete[i])
  end
end

function insertMarkerNoID(name, color)
    reaper.Undo_BeginBlock()

    color = convertColor(color)

    local _, num_markers, _ = reaper.CountProjectMarkers(0)
    local cursor_pos = reaper.GetCursorPosition()

    if reaper.GetPlayState() & 1 == 1 then
        cursor_pos = reaper.SnapToGrid(0, reaper.GetPlayPosition())
    end

    reaper.AddProjectMarker2(0, 0, cursor_pos, 0, name, num_markers, color)
    reaper.Undo_EndBlock("Insert NoID • " ..name, -1)
end

function insertMarkerStart(name,color)
clrMarkers(name)
reaper.Undo_BeginBlock()
local pos = reaper.GetCursorPosition()

color = convertColor(color)

reaper.AddProjectMarker2(0,0,pos,0, name, 0, color)
reaper.Undo_EndBlock('Set Marker • ' .. name, -1)
reaper.UpdateArrange()
end

function insertMarkerEnd(name,color)
clrMarkers(name)
reaper.Undo_BeginBlock()
local pos = reaper.GetCursorPosition()

color = convertColor(color)

reaper.AddProjectMarker2(0,0,pos,0, name, 99, color)
reaper.Undo_EndBlock('Set Marker • ' .. name, -1)
reaper.UpdateArrange()
end

function setStartEndMarkers()

  local nameLeft = '=START'
  local nameRight = '=END'

  local markerCount = reaper.CountProjectMarkers(0)
  local markersToDelete = {}

  for i = 0, markerCount - 1 do
    local _, isrgn, pos, rgnend, name, id = reaper.EnumProjectMarkers(i)

    if name:find(nameLeft) then
      -- msg(name .. " - " .. id)
      table.insert(markersToDelete, i)
    end
    if name:find(nameRight) then
      -- msg(name .. " - " .. id)
      table.insert(markersToDelete, i)
    end
  end
  -- msg(" All Markers: " .. markerCount)

  for i = #markersToDelete, 1, -1 do
    reaper.DeleteProjectMarkerByIndex(0, markersToDelete[i])
    -- msg(markersToDelete[i])
  end
    -------------------------------------------------------
    local function no_undo()reaper.defer(function()end)end;
    -------------------------------------------------------
    local timeSelStart,timeSelEnd = reaper.GetSet_LoopTimeRange(0,0,0,0,0); -- В Аранже
    if timeSelStart==timeSelEnd then no_undo() return end;
    reaper.Undo_BeginBlock();
    reaper.PreventUIRefresh(1);
    local colorStart = convertColor(widgets and widgets.start_color or 'pink')
    local colorEnd = convertColor(widgets and widgets.end_color or 'pink')
    reaper.AddProjectMarker2(0,0,timeSelStart,0, nameLeft, 0, colorStart)
    reaper.AddProjectMarker2(0,0,timeSelEnd,0, nameRight, 99, colorEnd)
    reaper.PreventUIRefresh(-1);
    reaper.Undo_EndBlock('trs_Insert • START & END markers by time selection',-1);
    reaper.UpdateArrange();
end

------------------------------------------------------------------------------------------------------------------
function btnFuncCol(name, funcName, helpText, col, i)
           r.ImGui_PushID(ctx, col)
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           if r.ImGui_Button(ctx, ''..name..'') then
              click_count, text = 0, funcName
              if funcName ~= '' then
                _G[funcName]() -- Вызываем функцию по имени переменной idCmd
              end
              click_count = click_count + 1
           end
            r.ImGui_PopStyleColor(ctx, 3)
            r.ImGui_PopID(ctx)

          if r.ImGui_IsItemHovered(ctx) then
          r.ImGui_BeginTooltip(ctx)
           r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
               if helpText ~= '' then
           r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), helpText)
               end
           r.ImGui_PopTextWrapPos(ctx)
           r.ImGui_EndTooltip(ctx)
            end
           		return
end

function btnCmdCol(name, idCmd, helpText, col, i)
           r.ImGui_PushID(ctx, col)
		   r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           if r.ImGui_Button(ctx, ''..name..'') then
              click_count, text = 0, idCmd
              if idCmd ~= '' then
                r.Main_OnCommand(r.NamedCommandLookup('' .. idCmd ..''), 0)
              end
              click_count = click_count + 1
           end
            r.ImGui_PopStyleColor(ctx, 3)
            r.ImGui_PopID(ctx)

          if r.ImGui_IsItemHovered(ctx) then
          r.ImGui_BeginTooltip(ctx)
			     r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
               if helpText ~= '' then
			     r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), helpText)
               end
			     r.ImGui_PopTextWrapPos(ctx)
			     r.ImGui_EndTooltip(ctx)
            end

           return
end

function btnSCRCol(name, idCmd, helpText, col, i)
		   r.ImGui_PushID(ctx, col)
		   r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           if r.ImGui_Button(ctx, ''..name..'') then
              click_count, text = 0, idCmd
              if idCmd ~= '' then
                -- r.Main_OnCommand(r.NamedCommandLookup('' .. idCmd ..''), 0)
                local r_path = reaper.GetResourcePath()
                dofile(string.format("%s\\Scripts\\Taras Scripts\\" .. idCmd .. "", r_path))
              end
              click_count = click_count + 1
           end
            r.ImGui_PopStyleColor(ctx, 3)
            r.ImGui_PopID(ctx)

          if r.ImGui_IsItemHovered(ctx) then
          r.ImGui_BeginTooltip(ctx)
           r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
               if helpText ~= '' then
           r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'), helpText)
           r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), idCmd)
               end
           r.ImGui_PopTextWrapPos(ctx)
           r.ImGui_EndTooltip(ctx)
            end

           return
end

function setMarker666()
    reaper.Undo_BeginBlock()
    local pos = reaper.GetCursorPosition()
    m_index = 666
    -- Delete existing markers with ID 666
    local i = 0
    while reaper.DeleteProjectMarker(0, m_index, 0) do
        -- Loop until all markers with ID 666 are deleted
        i = i + 1
        if i > 100 then break end -- Safety break
    end

    local color = convertColor('red') -- Use 'red' by default for REC
    reaper.AddProjectMarker2(0,0,pos,0, 'REC', m_index, color)
    reaper.Undo_EndBlock('Set Marker • ' .. 'REC', -1)
    reaper.UpdateArrange()
end

function goToMarker666()
local marker_num = reaper.CountProjectMarkers(0)

for i=0, marker_num-1 do
    local _, _, pos, _, name, _ = reaper.EnumProjectMarkers(i)
    -- if name == "=START" or "=END" then
    if name == "REC" then
        reaper.SetEditCurPos(pos, true, false)
    end
end

if reaper.GetPlayState() == 1 then -- Если воспроизведение включено
    reaper.OnPlayButton() -- Нажмите PLAY, чтобы переместить курсор воспроизведения на курсор редактирования
end

reaper.UpdateArrange()

function NoUndoPoint() end
reaper.defer(NoUndoPoint)
end

function resetProjStartTime()
local sws_exist = reaper.APIExists("SNM_SetDoubleConfigVar")
if sws_exist then
  reaper.SNM_SetDoubleConfigVar("projtimeoffs", 0)
  reaper.UpdateTimeline()
else
  reaper.ShowConsoleMsg("This script requires the SWS extension for REAPER. Please install it and try again.")
end
end

function resetProjBackTime()
-- function Main()

  reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.

  if reaper.GetPlayState() == 0 or reaper.GetPlayState == 2 then

    offset = reaper.GetProjectTimeOffset( 0, false )

    reaper.SetEditCurPos( -offset, 1, 0 )
  end

  reaper.Undo_EndBlock("Move edit cursor to time 0 or to project start", 0) -- End of the undo block. Leave it at the bottom of your main function.

-- end

-- Main() -- Execute your main function
reaper.UpdateArrange() -- Update the arrangement (often needed)
end

function setTimecodeZero()
-- USER CONFIG AREA --
local SCRIPT_NAME = ({reaper.get_action_context()})[2]:match("([^/\\_]+)%.lua$")

-- local r = reaper
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
end
------------------------------------------------------------------------------------------------------------------

-- function MarkerReNameIndex()
--   local marker_count = r.CountProjectMarkers(0)
--   local marker_names = {}

--   for i = 0, marker_count - 1 do
--     local _, isrgn, pos, rgnend, name, markrgnindexnumber = r.EnumProjectMarkers(i)

--     -- if not isrgn then
--     if not isrgn and name ~= "=START" and name ~= "=END" then
--       local base_name = name:gsub("%d", ""):gsub("%s+$", "") -- удаляем цифры и пробелы в конце
--       marker_names[base_name] = (marker_names[base_name] or 0) + 1
--       local new_name = base_name .. " " .. marker_names[base_name] -- добавлен пробел между именем и индексом

--       if new_name ~= name then
--         r.SetProjectMarkerByIndex(0, i, isrgn, pos, rgnend, markrgnindexnumber, new_name, 0)
--       end
--     end
--   end
--   r.UpdateArrange()
-- end

function MarkerReNameIndex()
  reaper.Undo_BeginBlock()

  local marker_count = r.CountProjectMarkers(0)
  local marker_names = {}
  local marker_indices = {}

  -- Первый проход: считаем количество каждого base_name
  for i = 0, marker_count - 1 do
    local _, isrgn, _, _, name = r.EnumProjectMarkers(i)
    if not isrgn and name ~= "=START" and name ~= "=END" and name ~= "!1016" then
      local base_name = name:gsub("%d", ""):gsub("%s+$", "")
      marker_names[base_name] = (marker_names[base_name] or 0) + 1
    end
  end

  -- Второй проход: переименовываем только дубликаты
  for i = 0, marker_count - 1 do
    local _, isrgn, pos, rgnend, name, markrgnindexnumber = r.EnumProjectMarkers(i)
    if not isrgn and name ~= "=START" and name ~= "=END" and name ~= "!1016" then
      local base_name = name:gsub("%d", ""):gsub("%s+$", "")
      if marker_names[base_name] > 1 then
        marker_indices[base_name] = (marker_indices[base_name] or 0) + 1
        local new_name = base_name .. " " .. marker_indices[base_name]
        if new_name ~= name then
          r.SetProjectMarkerByIndex(0, i, isrgn, pos, rgnend, markrgnindexnumber, new_name, 0)
        end
      else
        if base_name ~= name then
          r.SetProjectMarkerByIndex(0, i, isrgn, pos, rgnend, markrgnindexnumber, base_name, 0)
        end
      end
    end
  end
  r.UpdateArrange()
   -- Финализация Undo
  reaper.Undo_EndBlock("Добавить индексы к маркерам", -1)
  reaper.UpdateArrange()
end

function MarkerDelIndex()
 -- Инициализация Undo
  reaper.Undo_BeginBlock()

  local marker_count = reaper.CountProjectMarkers(0)
  local markers = {}

  -- Собираем все маркеры и регионы
  for i = 0, marker_count - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
    if not isrgn then -- Работаем только с маркерами (не регионами)
      table.insert(markers, {pos = pos, name = name, index = markrgnindexnumber})
    end
  end

  -- Удаляем числовые суффиксы и обновляем маркеры
  for _, m in ipairs(markers) do
    local new_name = m.name:gsub("%s*_[%d]+$", ""):gsub("%s*[%d]+$", "")
    if new_name ~= m.name then
      reaper.SetProjectMarker(m.index, false, m.pos, 0, new_name)
    end
  end

  -- Финализация Undo
  reaper.Undo_EndBlock("Удалить индексы у маркеров", -1)
  reaper.UpdateArrange()
end


function move_cur_start_item()

-- Скрипт для перемещения курсора к началу следующего айтема
local cur_pos = reaper.GetCursorPosition()
local num_items = reaper.CountMediaItems(0)

if num_items > 0 then
    for i = 0, num_items - 1 do
        local item = reaper.GetMediaItem(0, i)
        local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        if item_pos > cur_pos then
            reaper.SetEditCurPos(item_pos, true, false)
            break
        end
    end
else
    reaper.ShowConsoleMsg("Нет айтемов в проекте.\n")
end
end




function snap_sel_itmes_on()
------------ Options
CheckItemsCnt = true

GapItems = 0
GapGroups = 16
------------ Functions

------------ General
function print(...)
    local t = {}
    for i, v in ipairs( { ... } ) do
      t[i] = tostring( v )
    end
    reaper.ShowConsoleMsg( table.concat( t, "\n" ) .. "\n" )
end

function PrintDeltaTime(start)
    print(reaper.time_precise()  - start)
end


----------- Script

--- Preparate create tracks and count items, put in a table

local max_cnt = 0
-- Count track items see if there is a difference, use the track with more items
local last_cnt
local track_cnt = reaper.CountSelectedTracks(0)
local sel_tracks = {} -- save each selected track, and the item cnt
local prompt -- to ask user only once
for i_track = 0, track_cnt-1 do
    local track = reaper.GetSelectedTrack(0, i_track)
    local cnt = reaper.CountTrackMediaItems(track)
    if CheckItemsCnt and last_cnt and last_cnt ~= cnt and not prompt then -- check different track items sizes
        local answer = reaper.ShowMessageBox('Some tracks have different nº of items!!\nDo you want to continue?' , 'Organize Items In Sequence', 4)
        if answer == 7 then
            return
        end
        prompt = true
    end
    max_cnt = math.max(cnt,max_cnt)
    sel_tracks[#sel_tracks+1] = {
        track = track,
        cnt = cnt
    }
    last_cnt = cnt
end

--- Undo and set ptoject
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-----Get new_pos
local items_table_pos = {}
local last_fim
for i_items = 0, max_cnt-1 do
    local is_gap_groups = true
    for sel_track_idx, track_table in ipairs(sel_tracks) do
        if track_table.cnt-1 >= i_items then-- check if this track have this item cnt

            local item = reaper.GetTrackMediaItem(track_table.track, i_items)
            local start = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
            local len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
            -- reposition item
            local new_pos = start
            if last_fim then
                local gap = is_gap_groups and GapGroups or GapItems
                new_pos = last_fim + gap
                items_table_pos[#items_table_pos+1] = {
                    new_pos = new_pos+1,
                    item = item
                }
            end
            -- Insert in the item table list
            last_fim = new_pos + len
            is_gap_groups = false
        end
    end
end

-- Change Item Positions

for item, item_table in ipairs(items_table_pos) do
    reaper.SetMediaItemInfo_Value( item_table.item, 'D_POSITION', item_table.new_pos )
end


--- End Undo, project set
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, 'Script: Organize Items in Sequence Across Tracks', -1)
end

function snap_sel_itmes_off()
script_title = "Snap selected items to each other"
reaper.Undo_BeginBlock()

first_item = reaper.GetSelectedMediaItem(0, 0)
if  first_item ~= nil then first_item_track = reaper.GetMediaItem_Track(first_item) end

item_t = {}
item_subt = {}
item_count = reaper.CountSelectedMediaItems(0)
if item_count ~= nil then
  -- unselect items on other tracks then first sel item track
  for i = 1, item_count do
    item = reaper.GetSelectedMediaItem(0, i-1)
    item_track = reaper.GetMediaItem_Track(item)
    if item ~= nil and item_track == first_item_track then
      reaper.SetMediaItemInfo_Value(item, "B_UISEL", 1)
     else
       reaper.SetMediaItemInfo_Value(item, "B_UISEL", 0)
    end
  end
  -- main action
  for i = 2, item_count do
    item = reaper.GetSelectedMediaItem(0, i-1)
    if item ~= nil then
      prev_item = reaper.GetSelectedMediaItem(0, i-2)
      prev_item_pos = reaper.GetMediaItemInfo_Value(prev_item, "D_POSITION")
      prev_item_len = reaper.GetMediaItemInfo_Value(prev_item, "D_LENGTH")
      newpos = prev_item_pos + prev_item_len
      reaper.SetMediaItemInfo_Value(item, "D_POSITION", newpos)
    end
   end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock(script_title, 0)
end

------------------------------------------------------
function create_tempo_markers_sel_items()
-- Получаем имя элемента
function get_item_name(item)
  local take = reaper.GetActiveTake(item)
  if take ~= nil then
    return reaper.GetTakeName(take)
  else
    return nil
  end
end

-- Извлекаем последние три цифры из строки
function extract_last_three_digits(name)
  return tonumber(name:match("%d%d%d$"))
end

-- Устанавливаем темп-маркер
function set_tempo_marker(position, bpm)
  reaper.SetTempoTimeSigMarker(0, -1, position, -1, -1, bpm, 0, 0, false)
end

-- Обрабатываем каждый выделенный элемент
function process_selected_items()
  local num_items = reaper.CountSelectedMediaItems(0)
  if num_items == 0 then
    reaper.ShowMessageBox("Нет выделенных элементов", "Ошибка", 0)
    return
  end

  for i = 0, num_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    reaper.Main_OnCommand(r.NamedCommandLookup('' .. 41183 ..''), 0) -- Snap to grid
    local name = get_item_name(item)
    if name ~= nil then
      local bpm = extract_last_three_digits(name)
      if bpm ~= nil then
        local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        set_tempo_marker(position, bpm)
         reaper.UpdateTimeline()
         reaper.UpdateArrange()
        -- reaper.ShowMessageBox("Темп-маркер установлен на " .. bpm .. " BPM для элемента " .. name, "Успех", 0)
      else
        -- reaper.ShowMessageBox("Не удалось извлечь BPM из имени элемента: " .. name, "Ошибка", 0)
      end
    else
      reaper.ShowMessageBox("Не удалось получить имя элемента", "Ошибка", 0)
    end
  end
end

-- Основная функция скрипта
function main()
  reaper.Undo_BeginBlock()
  process_selected_items()
  reaper.Undo_EndBlock("Set tempo marker from item names", -1)
end

-- Запускаем основную функцию
main()
end

------------------------------------

function removeWavFromItemNames()
    local selectedItems = reaper.CountSelectedMediaItems(0)
    if selectedItems == 0 then
        reaper.ShowMessageBox("Нет выделенных элементов.", "Ошибка", 0)
        return
    end

    reaper.Undo_BeginBlock()

    for i = 0, selectedItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if take then
            local _, itemName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if itemName:sub(-4) == ".wav" or ".mid" then
                local newName = itemName:sub(1, -5) -- Удаление последних 4 символов (".wav")
                reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", newName, true)
            end
        end
    end

    reaper.Undo_EndBlock("Удаление .wav из имен элементов", -1)
end
