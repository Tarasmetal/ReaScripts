-- @description Marker GUI Tools
-- @author Taras Umanskiy
-- @version 3.4.0
-- @provides
--   [main] .
--   [script] MarkerPresets/*.txt
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about
--   # КАК ЭТО РАБОТАЕТ?
--   Основная идея и задача скрипта — максимально сократить время на разметку проекта, оставляя его красивым и понятным для всех, а главное для самого себя.
--   Не отвлекайтесь от творческого процесса, перемещайтесь в любую точку проекта за пару секунд, чтобы записать, прослушать или внести кориктеровки в трекинг.
-- @changelog
--   v.3.4.0 + Функции пресетов, маркеров и регионов объединены в один Lua-файл; папка Functions больше не требуется
--   + Кнопки пресетов автоматически создают регионы по выделению времени или маркеры при отсутствии выделения
--   + Настройка ID применяется к именам маркеров и регионов; нумерация регионов ведётся отдельно
--   + Inx Add и Inx Rem обрабатывают маркеры и регионы с отдельной нумерацией для каждого типа
--   + Обработка индексов сохраняет цифры внутри имён, служебные имена и границы регионов
--   + Удалены чекбоксы R и <; дополнительные инструменты всегда доступны в обычном режиме интерфейса
--   + Обновлены подсказки кнопок и настройки ID
--   v.3.3
--   + Добавлена возможность удаления пресета маркера клавишей Delete при наведении мыши
--   + Добавлена возможность вставки нового пресета маркера клавишей Insert при наведении мыши (вставляет справа)
--   + Исправлена нумерация ID первого маркера (теперь начинается с 1 вместо 0 при выключенном ID)
--   + Автоматическое создание Default.txt с набором маркеров при первом запуске
--   + Исправлена критическая ошибка при загрузке несуществующих пресетов (nil error)
--   + Новый пресет и очистка пресета теперь создают пустой маркер " " по умолчанию
--   + Кнопки New, Clear и Delete теперь расположены на одной строке
--   + Обновлена логика создания пресета: ввод имени после нажатия "New"
--   + Новый пресет теперь по умолчанию содержит маркер "Intro"
--   + Изменена логика чекбокса ID (Вкл = с ID, Выкл = без ID)
--   + Имя файла настроек теперь зависит от имени файла скрипта
--   + Добавлены необходимые файлы функций в зависимость пакета (Functions/*.lua)


local r = reaper
local FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()
local IMGUI_VERSION, REAIMGUI_VERSION = r.ImGui_GetVersion()

local EXT_SECTION = "trs_MarkerGUITools_Settings"

function SaveSetting(key, value)
  reaper.SetExtState(EXT_SECTION, key, tostring(value), true)
end

function LoadSettings()
  local w = {}

  -- Load closable (ID)
  local val = reaper.GetExtState(EXT_SECTION, "closable")
  if val ~= "" then w.closable = (val == "true") else w.closable = false end

  -- Load start_color
  val = reaper.GetExtState(EXT_SECTION, "start_color")
  if val ~= "" then w.start_color = val else w.start_color = nil end

  -- Load end_color
  val = reaper.GetExtState(EXT_SECTION, "end_color")
  if val ~= "" then w.end_color = val else w.end_color = nil end

  w.cheads = {}
  -- Load show_additional_buttons (PB)
  val = reaper.GetExtState(EXT_SECTION, "show_additional_buttons")
  if val ~= "" then w.cheads.show_additional_buttons = (val == "true") else w.cheads.show_additional_buttons = false end

  return w
end

widgets = LoadSettings()

console = true

function msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

scrAuthor = 'Taras Umanskiy'
version = '3.4.0'
scrName = 'MARKER TOOLS'
scrAbout = scrName .. ' ' .. version .. ' by ' .. scrAuthor

ListDir = {}
ListDir.scriptDir, ListDir.scriptFileName = ({r.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")

scriptDir = ListDir.scriptDir
settingsFileName = ListDir.scriptFileName .. ".ini"
presetDir = ListDir.scriptDir .. 'MarkerPresets'

windowTitle = scrAbout

------------------------------------------------------------------------------------------------------------------
local info = debug.getinfo(1, 'S');
local FontPath = info.source:match[[^@?(.*[\/])[^\/]-$]]
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua') ('0.8.1') -- current version at the time of writing the script

--local ctx = r.ImGui_CreateContext(windowTitle)
ctx = r.ImGui_CreateContext(windowTitle)
local size = r.GetAppVersion():match('Win64') and 12 or 14
-- local font = r.ImGui_CreateFont('Tahoma', 9)
local font = reaper.ImGui_CreateFont('sans-serif', 14)
-- local font = r.ImGui_CreateFont('Consolas', 9)
-- local font =  r.ImGui_CreateFont('Sedoe', 9)
r.ImGui_Attach(ctx, font)
------------------------------------------------------------------------------------------------------------------

-- Preset functions (embedded)
do
local r = reaper
function GetListOfFiles(d)
    local tb = {}
    local i = 0
    repeat
        local retval = reaper.EnumerateFiles(d, i)
        table.insert(tb, retval)
        i = i + 1
    until not retval
    return tb
end

function str_split (inputstr, sep)
    if not inputstr then return {} end
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local function read_file(path)
    local open = io.open
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then
        return nil
    end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

function preset_read(preset_path, presetId)
    if not (preset_path and presetId)
    then
        return
    end
    return table.load(preset_path .. '/' .. presetId)
end

function preset_read_simple(preset_path, presetId)
    local fileContent = read_file(preset_path .. '/' .. presetId)
    return fileContent
end

function parse_simple_preset_content(content)
    if not content then return {} end
    content = str_split(content, "\n")
    local res = {}
    for rowKey, rowValue in ipairs(content) do
        -- Skip comments and empty lines
        if rowValue and rowValue ~= "" and string.sub(rowValue, 1, 2) ~= "--" then
            rowValue = rowValue:gsub("\r", "")
            local row = str_split(rowValue, ',')
            if row[1] then
                table.insert(res, {
                    name = row[1],
                    color = row[2] or "",
                })
            end
        end
    end
    return res
end

function save_simple_preset(preset_path, presetId, data)
    local file = io.open(preset_path .. '/' .. presetId, "w")
    if not file then return end

    for _, v in ipairs(data) do
        if v.name then
            local clean_name = v.name:gsub("[\r\n]", "")
            local clean_color = (v.color or ""):gsub("[\r\n]", "")
            file:write(clean_name .. "," .. clean_color .. "\n")
        end
    end
    file:close()
end

local presetState = { newName = "", showInput = false }

function renderFilesList(ctx, path, currentMarkers, currentPresetName)
    local selected = nil
    local newMarkers = nil
    local newName = nil

    local rv = reaper.ImGui_Button(ctx, ' Presets ')
     if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
     --            r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'),'PRESET PATH -')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, hex2rgb('#88FF00'),'Found')
     --            r.ImGui_Separator(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#c7c7c7'), 'Load Presets for Marker Tools')
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
              end
    if rv then
        filesList = GetListOfFiles(path)
        presetState.showInput = false -- Reset state on open
        reaper.ImGui_OpenPopup(ctx, 'load_popup')
    end

    if reaper.ImGui_BeginPopup(ctx, 'load_popup') then
        if r.ImGui_Button(ctx, ' Open Folder ') then
            r.ImGui_BulletText(ctx, '•')
            reaper.CF_ShellExecute(path)
        end
        if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
                r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'),'PRESET PATH -')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, hex2rgb('#88FF00'),'Found')
                r.ImGui_Separator(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#c7c7c7'), path)
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
              end
        reaper.ImGui_Separator(ctx)

        -- New Preset Logic
        if not presetState.showInput then
            if reaper.ImGui_Button(ctx, "New") then
                presetState.showInput = true
                presetState.newName = ""
            end
            
            -- Clear / Delete on the same line as New
            if currentPresetName then
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "Clear") then
                    local defaultData = {{ name = " ", color = "" }}
                    save_simple_preset(path, currentPresetName, defaultData)
                    newMarkers = defaultData
                    newName = currentPresetName
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "Delete") then
                    os.remove(path .. "/" .. currentPresetName)
                    local defaultFile = "Default.txt"
                    if currentPresetName ~= defaultFile then
                        local content = preset_read_simple(path, defaultFile)
                        if content then
                            newMarkers = parse_simple_preset_content(content)
                            newName = defaultFile
                        else
                            newMarkers = {}
                            newName = defaultFile
                        end
                    else
                        newMarkers = {}
                        newName = defaultFile
                    end
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
            end
        else
            reaper.ImGui_PushItemWidth(ctx, 120)
            local rv_in, inputName = reaper.ImGui_InputText(ctx, "##new_preset_name", presetState.newName)
            if rv_in then presetState.newName = inputName end
            reaper.ImGui_PopItemWidth(ctx)
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Create") then
                if presetState.newName ~= "" then
                    local fileName = presetState.newName
                    if not fileName:match("%.txt$") then fileName = fileName .. ".txt" end
                    local f = io.open(path .. "/" .. fileName, "w")
                    if f then
                        f:write(" \n") -- Default content is a space
                        f:close()
                        newMarkers = {{ name = " ", color = "" }}
                        newName = fileName
                        presetState.newName = ""
                        presetState.showInput = false
                        reaper.ImGui_CloseCurrentPopup(ctx)
                    end
                end
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel") then
                presetState.showInput = false
            end
        end

        reaper.ImGui_Separator(ctx)
        reaper.ImGui_TextColored(ctx, 0xFFFF00FF, ' LOAD PRESETS ')
        reaper.ImGui_Separator(ctx)
        for i, v in ipairs(filesList) do
            local no_exp = string.gsub(v, "%.txt$", "")
            if reaper.ImGui_Selectable(ctx, no_exp) then
                selected = i
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end


    if newMarkers and newName then
        -- сохранение значения переменной defaultPresetName в файл
        local file = io.open(scriptDir .. "/" .. settingsFileName, "w")
        if file then
            file:write(newName)
            file:close()
        end
        return newMarkers, newName
    end

    if filesList ~= nil and selected ~= nil then

        -- сохранение значения переменной defaultPresetName в файл
        local file = io.open(scriptDir .. "/" .. settingsFileName, "w")
        file:write("" .. filesList[selected] .. "")
        file:close()

        return parse_simple_preset_content(preset_read_simple(path, filesList[selected])), filesList[selected]
    end
    return nil

end
end

-- Marker and region functions (embedded)
do
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

    reaper.AddProjectMarker2(0, 0, cursor_pos, 0, name, num_markers + 1, color)
    reaper.Undo_EndBlock("Insert NoID • " ..name, -1)
end

function insertRegion(name, color, with_id)
    local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if end_pos <= start_pos then
        if with_id then
            insertMarker(name, color)
        else
            insertMarkerNoID(name, color)
        end
        return
    end

    local region_name = name
    if with_id then
        local last_id = 0
        local total = reaper.CountProjectMarkers(0)
        local prefix = name .. ' '
        for idx = 0, total - 1 do
            local _, is_region, _, _, existing_name = reaper.EnumProjectMarkers(idx)
            if is_region and existing_name:sub(1, #prefix):lower() == prefix:lower() then
                local suffix = existing_name:sub(#prefix + 1):match('^%d+$')
                if suffix then last_id = math.max(last_id, tonumber(suffix)) end
            end
        end
        region_name = name .. ' ' .. (last_id + 1)
    end

    reaper.Undo_BeginBlock()
    reaper.AddProjectMarker2(0, true, start_pos, end_pos, region_name, -1, convertColor(color))
    reaper.Undo_EndBlock("Insert region • " .. region_name, -1)
    reaper.UpdateArrange()
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

local function nameWithoutIndex(name)
  return (name:gsub("[%s_]+%d+$", ""):gsub("%s+$", ""))
end

local function canIndexName(name)
  return name ~= "=START" and name ~= "=END" and name ~= "!1016"
end

function MarkerReNameIndex()
  reaper.Undo_BeginBlock()

  local marker_count = r.CountProjectMarkers(0)
  local marker_names = {[false] = {}, [true] = {}}
  local marker_indices = {[false] = {}, [true] = {}}

  -- Первый проход: считаем количество каждого base_name
  for i = 0, marker_count - 1 do
    local _, isrgn, _, _, name = r.EnumProjectMarkers(i)
    if canIndexName(name) then
      local base_name = nameWithoutIndex(name)
      local names = marker_names[isrgn]
      names[base_name] = (names[base_name] or 0) + 1
    end
  end

  -- Второй проход: переименовываем только дубликаты
  for i = 0, marker_count - 1 do
    local _, isrgn, pos, rgnend, name, markrgnindexnumber = r.EnumProjectMarkers(i)
    if canIndexName(name) then
      local base_name = nameWithoutIndex(name)
      local indices = marker_indices[isrgn]
      if marker_names[isrgn][base_name] > 1 then
        indices[base_name] = (indices[base_name] or 0) + 1
        local new_name = base_name .. " " .. indices[base_name]
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
   -- Финализация Undo
  reaper.Undo_EndBlock("Добавить индексы к маркерам и регионам", -1)
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
    if canIndexName(name) then
      table.insert(markers, {pos = pos, rgnend = rgnend, isrgn = isrgn, name = name, index = markrgnindexnumber})
    end
  end

  -- Удаляем числовые суффиксы и обновляем маркеры и регионы
  for _, m in ipairs(markers) do
    local new_name = nameWithoutIndex(m.name)
    if new_name ~= m.name then
      reaper.SetProjectMarker(m.index, m.isrgn, m.pos, m.rgnend, new_name)
    end
  end

  -- Финализация Undo
  reaper.Undo_EndBlock("Удалить индексы у маркеров и регионов", -1)
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
end


function ParseColorToRGB(color)
    local r, g, b = 1, 1, 1
    if not color or color == '' then return r, g, b end
    if type(color) == 'string' then
        if col_arr and col_arr[color:lower()] then
            local t = col_arr[color:lower()]
            r, g, b = t[1]/255, t[2]/255, t[3]/255
        elseif color:match("^#?%x%x%x%x%x%x$") then
            local hex = color:gsub("#","")
            r = tonumber(hex:sub(1,2), 16) / 255
            g = tonumber(hex:sub(3,4), 16) / 255
            b = tonumber(hex:sub(5,6), 16) / 255
        end
    end
    return r, g, b
end

function RGBToHex(r, g, b)
    local function to255(v) return math.floor(v * 255 + 0.5) end
    return string.format("#%02X%02X%02X", to255(r), to255(g), to255(b))
end

-- чтение значения переменной defaultPresetName из файла
-- defaultPresetName = 'Default.lua'
local f_preset_check = scriptDir .. "/" .. settingsFileName

if os.rename(f_preset_check, f_preset_check) == true then
  -- file exists, do something
local f_preset = io.open(scriptDir .. "/" .. settingsFileName, "r")

if f_preset then
    local contents = f_preset:read("*all")
    defaultPresetName = string.match(contents, "(.+)")
    f_preset:close()
end

else
  -- file does not exist, set defaultPresetName variable
  defaultPresetName = "Default.txt"
end

-- Проверка существования Default.txt и его создание с базовым набором маркеров
local default_path = presetDir .. "/Default.txt"
local f_check = io.open(default_path, "r")
if not f_check then
    -- Создаем директорию если её нет (на всякий случай)
    r.RecursiveCreateDirectory(presetDir, 0)
    local f_def = io.open(default_path, "w")
    if f_def then
        local default_markers = {
            "Intro", "Main", "Verse", "Chorus", "Fill", "Pre", "Bridge",
            "BDown", "Drop", "Beat", "Silent", "Riff", "Solo", "Tap",
            "Outro", "Phase", "Idea", "Old", "Fx", "!1016"
        }
        for _, m_name in ipairs(default_markers) do
            f_def:write(m_name .. ",\n")
        end
        f_def:close()
    end
else
    f_check:close()
end

markersToShow = parse_simple_preset_content(preset_read_simple(presetDir, defaultPresetName)) -- Дефолтный пресет


function HelpMarker(helpName, desc)
  r.ImGui_TextDisabled(ctx, '' .. helpName .. '')
  if r.ImGui_IsItemHovered(ctx) then
    r.ImGui_BeginTooltip(ctx)
    r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
    r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), desc)
    r.ImGui_PopTextWrapPos(ctx)
    r.ImGui_EndTooltip(ctx)
  end
end

-- Вызывается в цикле ОСТОРОЖНО

local val_omm = reaper.GetExtState(EXT_SECTION, "only_markers_mode")
only_markers_mode = (val_omm == "true")

function frame(ctx)
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_H(), false) then
        only_markers_mode = not only_markers_mode
        SaveSetting("only_markers_mode", only_markers_mode)
    end

    -- r.ImGui_LabelText(ctx, left, text)
    -- -- r.ImGui_Text(ctx, 'Hold to repeat:')
    if not only_markers_mode then
    r.ImGui_SameLine(ctx) r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'),'<(?)>')
    if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
                r.ImGui_Spacing(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'),'** ABOUT SCRIPT **')
                r.ImGui_Spacing(ctx)
                r.ImGui_Separator(ctx)
                r.ImGui_Spacing(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Script File:') r.ImGui_SameLine(ctx) r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), ListDir.scriptFileName .. '.lua')
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Script Name:') r.ImGui_SameLine(ctx) r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'), scrName .. ' ' .. version)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Author:')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), scrAuthor)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Author URL:')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'), 'http://vk.com/tarasmetal')
                r.ImGui_Text(ctx, '')
                r.ImGui_TextColored(ctx, hex2rgb('#FF0000'), '<3')r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,'&')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, hex2rgb('#88FF00'), 'SPECIAL THX:')
                r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), 'MPL,SuperMaximus,Aleksey Bezborodov.\n')
                r.ImGui_Spacing(ctx)
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
      end
    r.ImGui_SameLine(ctx)
    selectedMarkers, newPresetName = renderFilesList(ctx, presetDir, markersToShow, defaultPresetName)
    if selectedMarkers then
        markersToShow = selectedMarkers
        if newPresetName then
            defaultPresetName = newPresetName
        end
    end

    r.ImGui_SameLine(ctx)
    local rv_id
    rv_id, widgets.closable = r.ImGui_Checkbox(ctx, 'ID', widgets.closable)
    if rv_id then SaveSetting("closable", widgets.closable) end

    r.ImGui_SameLine(ctx)HelpMarker('(?)',
      'Add a numeric suffix to marker and region names\n')
    r.ImGui_SameLine(ctx)

if not widgets.cheads then
      widgets.cheads = {
        show_additional_buttons = false,
      }
      end

        btnFuncCol('S-E', 'setStartEndMarkers','Set START and END Markers of time selection', 9,0)
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnCmdCol('Del T', '42395', 'Markers: Delete all tempo markers', 7,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('Del M', '40613', 'Markers: Delete marker at cursor', 7.5,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('Del M all', '_SWSMARKERLIST9', 'Markers: Delete all Markers', 7,0)
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnCmdCol('Del R', '40615', 'Regions: Delete region at cursor', 7.5,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('Del R all', '_SWSMARKERLIST10', 'Regions: Delete all Regions', 7,0)
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnFuncCol('Inx Add', 'MarkerReNameIndex', 'Set name indices for duplicate markers and regions (numbered separately)', 9,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        btnFuncCol('Inx Rem', 'MarkerDelIndex', 'Remove name indices from all markers and regions', 7,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnCmdCol('M ID', '_SWSMARKERLIST7','ReNumber Markers ID [0-9X]', 5.8,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('R ID', '_SWSMARKERLIST8','ReNumber Regions ID [0-9X]', 5.5,0)
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnCmdCol('M >> R', '_SWSMARKERLIST13','Convert all Markers to Regions', 5.2,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('R << M', '_SWSMARKERLIST14','Convert all Regions to Markers', 5.0,0)
        r.ImGui_SameLine(ctx) r.ImGui_TextDisabled(ctx, '|')r.ImGui_SameLine(ctx)
        -- btnSCRCol('File Load', 'Taras\\Tools\\trs_TrackReNameTools.lua', 'Script Load', 6.5,0) -- Load lua file script
        btnFuncCol('Set 00', 'setTimecodeZero', 'Set start 0:00:00 at edit cursor', 0,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        btnFuncCol('Bck 00', 'resetProjBackTime', 'Jump cursor to 0:00:00', 8,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        btnFuncCol('Rst 00', 'resetProjStartTime', 'Reset project start time', 9,0) -- Load lua file script
        r.ImGui_SameLine(ctx) r.ImGui_TextDisabled(ctx, '|')r.ImGui_SameLine(ctx)
        -- работающие за комментированное кнопки
        -- btnFuncCol('REC', 'setMarker666', 'Insert REC 666 Marker', 0,0) -- Red -- Load lua file script
        -- r.ImGui_SameLine(ctx)
        -- btnFuncCol('BCK', 'goToMarker666', 'Go to REC 666 Marker', 9,0) -- Green -- Load lua file script
        -- r.ImGui_SameLine(ctx) r.ImGui_TextDisabled(ctx, '|')r.ImGui_SameLine(ctx)
        r.ImGui_SameLine(ctx)
        local rv_pb
        rv_pb, widgets.cheads.show_additional_buttons = r.ImGui_Checkbox(ctx, 'PB', widgets.cheads.show_additional_buttons)
        if rv_pb then SaveSetting("show_additional_buttons", widgets.cheads.show_additional_buttons) end
        r.ImGui_SameLine(ctx) HelpMarker('(?)','Show PlayBack Tools Maker\n')
        if widgets.cheads.show_additional_buttons then
        r.ImGui_SameLine(ctx)
        btnCmdCol('+ T', '40256','Insert tempo/time sig. change marker at edit cursor...', 5.0,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('+ R', '40174','Insert Region from time selection', 5.3,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('+ R.I', '_SWS_REGIONSFROMITEMS','SWS: Create regions from selected items (name by active take)', 4,0)
        r.ImGui_SameLine(ctx)
        btnFuncCol('T+++', 'create_tempo_markers_sel_items','Move cursor to next end-start of item, select item', 5.1,0)
        r.ImGui_SameLine(ctx)
        btnFuncCol('Items R', 'removeWavFromItemNames','Items: Rename rename items.wav', 5.6,0)
        r.ImGui_SameLine(ctx)
        btnFuncCol('Items -', 'snap_sel_itmes_off','', 7,0)
        r.ImGui_SameLine(ctx)
        btnFuncCol('items +', 'snap_sel_itmes_on','', 8,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('items s', '41183','Selected items snap to grid', 9,0)
        end
        -- r.ImGui_Checkbox(ctx, 'test', 0)
        -- if r.ImGui_IsItemHovered(ctx) then
        --         r.ImGui_BeginTooltip(ctx)
        --         r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
        --         r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'),'DONT WORK!')
        --         r.ImGui_TextColored(ctx, hex2rgb('#FF0000'),'SCRIPT NOT COMPLITE !!!')
        --         r.ImGui_PopTextWrapPos(ctx)
        --         r.ImGui_EndTooltip(ctx)
        --       end
    r.ImGui_SameLine(ctx)
        r.ImGui_Spacing(ctx)
        r.ImGui_Separator(ctx)
        r.ImGui_Spacing(ctx)
    end
        r.ImGui_Text(ctx, '<')
        r.ImGui_SameLine(ctx)
          local col = 6
           r.ImGui_PushID(ctx, 'start_btn')

           if widgets.start_color and widgets.start_color ~= "" then
               local c_r, c_g, c_b = ParseColorToRGB(widgets.start_color)
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.6))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.8))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0))
           else
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           end

        if r.ImGui_Button(ctx, 'START') then
            insertMarkerStart('=START', widgets.start_color or 'pink')
        end
            if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Set')
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), 'START')
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'project marker')
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
              end

        if r.ImGui_BeginPopupContextItem(ctx) then
            r.ImGui_Text(ctx, 'Edit START Button Color')
            r.ImGui_Separator(ctx)

            local c_r, c_g, c_b = ParseColorToRGB(widgets.start_color)
            if not widgets.start_color then c_r, c_g, c_b = 1, 0, 1 end -- Default Pink
            local packed_col = r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0)
            local rv_color, new_packed_col = r.ImGui_ColorEdit4(ctx, 'Color', packed_col)
            if rv_color then
                local new_r, new_g, new_b, _ = r.ImGui_ColorConvertU32ToDouble4(new_packed_col)
                widgets.start_color = RGBToHex(new_r, new_g, new_b)
                SaveSetting("start_color", widgets.start_color)
            end

            if r.ImGui_Button(ctx, 'Reset Color') then
                widgets.start_color = nil
                SaveSetting("start_color", "")
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        r.ImGui_PopStyleColor(ctx, 3)
        r.ImGui_PopID(ctx)
        r.ImGui_SameLine(ctx)
        r.ImGui_Text(ctx, '|')


    for i = 1, #markersToShow do -- С какого элемента начинать

        buttonText = markersToShow[i].name
        color = markersToShow[i].color

        if i > 0 then
          r.ImGui_SameLine(ctx)
        end
           r.ImGui_PushID(ctx, i)
           if color and color ~= "" then
               local c_r, c_g, c_b = ParseColorToRGB(color)
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.6))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.8))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0))
           else
               local col = 4
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 0.6))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           end


        if r.ImGui_Button(ctx, buttonText .. "###marker_btn") then
            insertRegion(buttonText, color, widgets.closable)
        end

        if r.ImGui_IsItemHovered(ctx) then
            -- Tooltip
            r.ImGui_BeginTooltip(ctx)
            r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
            r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Insert')
            r.ImGui_SameLine(ctx)
            r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), buttonText)
            if widgets.closable then
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#88FF00'), '(with index)')
            end
            r.ImGui_SameLine(ctx)
            r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'region from time selection, or marker when no time is selected')
            r.ImGui_PopTextWrapPos(ctx)
            r.ImGui_EndTooltip(ctx)

            -- Keyboard shortcuts (Insert / Delete)
             if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Insert()) then
                 table.insert(markersToShow, i + 1, {name='New', color=''})
                 save_simple_preset(presetDir, defaultPresetName, markersToShow)
                 r.ImGui_PopStyleColor(ctx, 3)
                 r.ImGui_PopID(ctx)
                 break
             elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Delete()) then
                 table.remove(markersToShow, i)
                 save_simple_preset(presetDir, defaultPresetName, markersToShow)
                 r.ImGui_PopStyleColor(ctx, 3)
                 r.ImGui_PopID(ctx)
                 break
             end
        end

        -- Drag and Drop
        if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_None()) then
            r.ImGui_SetDragDropPayload(ctx, 'MARKER_CELL', tostring(i))
            r.ImGui_Text(ctx, markersToShow[i].name)
            r.ImGui_EndDragDropSource(ctx)
        end
        if r.ImGui_BeginDragDropTarget(ctx) then
            local retval, payload = r.ImGui_AcceptDragDropPayload(ctx, 'MARKER_CELL')
            if retval then
                local from_i = tonumber(payload)
                if from_i ~= i then
                    local moved_item = table.remove(markersToShow, from_i)
                    table.insert(markersToShow, i, moved_item)
                    save_simple_preset(presetDir, defaultPresetName, markersToShow)
                end
            end
            r.ImGui_EndDragDropTarget(ctx)
        end

        r.ImGui_PopStyleColor(ctx, 3)

        if r.ImGui_BeginPopupContextItem(ctx) then
            r.ImGui_Text(ctx, 'Edit Marker: ' .. markersToShow[i].name)
            r.ImGui_Separator(ctx)

            -- Edit Name
            local rv_name, new_name = r.ImGui_InputText(ctx, 'Name', markersToShow[i].name)
            if rv_name then
                markersToShow[i].name = new_name
                save_simple_preset(presetDir, defaultPresetName, markersToShow)
            end

            -- Edit Color
            local c_r, c_g, c_b = ParseColorToRGB(markersToShow[i].color)
            local packed_col = r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0)
            local rv_color, new_packed_col = r.ImGui_ColorEdit4(ctx, 'Color', packed_col)
            if rv_color then
                local new_r, new_g, new_b, _ = r.ImGui_ColorConvertU32ToDouble4(new_packed_col)
                markersToShow[i].color = RGBToHex(new_r, new_g, new_b)
                save_simple_preset(presetDir, defaultPresetName, markersToShow)
            end

            if r.ImGui_Button(ctx, 'Delete Color') then
                markersToShow[i].color = ''
                save_simple_preset(presetDir, defaultPresetName, markersToShow)
            end

            r.ImGui_Separator(ctx)

            -- Delete Button
            if r.ImGui_Button(ctx, 'DELETE MARKER') then
                table.remove(markersToShow, i)
                save_simple_preset(presetDir, defaultPresetName, markersToShow)
                r.ImGui_CloseCurrentPopup(ctx)
                r.ImGui_EndPopup(ctx)
                r.ImGui_PopID(ctx)
                break
            end

            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, 'INSERT MARKER') then
                 table.insert(markersToShow, i + 1, {name='New', color=''})
                 save_simple_preset(presetDir, defaultPresetName, markersToShow)
                 r.ImGui_CloseCurrentPopup(ctx)
                 r.ImGui_EndPopup(ctx)
                 r.ImGui_PopID(ctx)
                 break
            end
            if r.ImGui_IsItemHovered(ctx) then
                 r.ImGui_SetTooltip(ctx, 'Insert New Marker After Current')
            end
            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        r.ImGui_PopID(ctx)
        end


        r.ImGui_SameLine(ctx)
        r.ImGui_Text(ctx, '|')
        r.ImGui_SameLine(ctx)

      local col = 6
           r.ImGui_PushID(ctx, 'end_btn')

           if widgets.end_color and widgets.end_color ~= "" then
               local c_r, c_g, c_b = ParseColorToRGB(widgets.end_color)
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.6))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.8))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0))
           else
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           end

        if r.ImGui_Button(ctx, 'END') then
            insertMarkerEnd("=END", widgets.end_color or 'pink')
         end
          -- if  r.ImGui_IsItemHovered(ctx) then
          --      -- local cursor_pos = r.GetCursorPosition()
          --           r.ImGui_SetTooltip(ctx, 'Set END project maker point') -- Need to Fix
          --           -- r.ImGui_SetTooltip(ctx, 'Set END point pos '.. timeEND ..' for render track') -- Need to Fix
          --   end
            if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Set')
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), 'END')
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'project marker')
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
              end

        if r.ImGui_BeginPopupContextItem(ctx) then
            r.ImGui_Text(ctx, 'Edit END Button Color')
            r.ImGui_Separator(ctx)

            local c_r, c_g, c_b = ParseColorToRGB(widgets.end_color)
            if not widgets.end_color then c_r, c_g, c_b = 1, 0, 1 end -- Default Pink
            local packed_col = r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0)
            local rv_color, new_packed_col = r.ImGui_ColorEdit4(ctx, 'Color', packed_col)
            if rv_color then
                local new_r, new_g, new_b, _ = r.ImGui_ColorConvertU32ToDouble4(new_packed_col)
                widgets.end_color = RGBToHex(new_r, new_g, new_b)
                SaveSetting("end_color", widgets.end_color)
            end

            if r.ImGui_Button(ctx, 'Reset Color') then
                widgets.end_color = nil
                SaveSetting("end_color", "")
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        r.ImGui_PopStyleColor(ctx, 3)
        r.ImGui_PopID(ctx)
        if not only_markers_mode then
        r.ImGui_SameLine(ctx)
        r.ImGui_SameLine(ctx)
        r.ImGui_Text(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnFuncCol('Add PL', 'StopRegions', 'Add STOP Markers to End of Regions', 9,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        btnFuncCol('Rem PL', 'StopRegionsDelete', 'Delete STOP Markers to End of Regions', 0,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        r.ImGui_Text(ctx, '>')
        end
        r.ImGui_Spacing(ctx)
end

function loop()
    local visible, open = r.ImGui_Begin(ctx, windowTitle, true, r.ImGui_WindowFlags_AlwaysAutoResize())
    if visible then
        frame(ctx)
        r.ImGui_End(ctx)
    end

    if open and (not r.ImGui_IsKeyDown(ctx, 27)) then
        r.defer(loop)
    -- else
        -- r.ImGui_DestroyContext(ctx)
    end
end

r.defer(loop)
