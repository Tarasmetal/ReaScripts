-- @description Label GUI Tools
-- @author Taras Umanskiy
-- @version 1.6.1
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://vk.com/Tarasmetal
-- @about
--   # Инструменты для работы с метками в Reaper
--   Этот скрипт предоставляет удобный графический интерфейс для управления и редактирования меток (Label) в проекте Reaper.  Он позволяет быстро переименовывать метки, добавлять информацию о регионе и треке, а также выполнять другие полезные операции.
-- @changelog
--   v.1.6.1 + Все функции встроены в основной Lua-файл; зависимость от Functions/LabelFunctions.lua удалена.
--   v.1.6.0 + Настройки пресетов перенесены в trs_Label GUI Tools.ini.
--   v.1.5.0 + Кнопки Add, GO и поле ввода размещены в одной строке.
--   v.1.4.0 + Добавлена кнопка Check для выделения айтемов с одинаковым источником.
--   v.1.3.0 + Добавлена кнопка Check для выделения айтемов с одинаковым источником.
--   v.1.2.0 + Добавлена кнопка Add для сохранения пользовательских пресетов.
--   v.1.1.0 + Исправлена подстановка региона по позиции курсора и работа кнопок интерфейса.
--  + Code Fixies

r = reaper
console = false

function msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

myTime = ''
scrVersion = '1.6.1'
scrName = 'LABEL TOOLS' .. ' ' .. scrVersion .. ' | by Taras Umanskiy'

ListDir = {}
ListDir.scriptDir, ListDir.scriptFileName = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")

scriptDir = ListDir.scriptDir
scriptFileName = ListDir.scriptFileName

windowTitle = scrName

-- Встроенные функции обработки меток.
do
function AddZerosAndOffset(number, zeros, offset)

    local number = number + offset

    number = tostring(number)

    number = string.format('%0' .. zeros .. 'd', number)
    msg(number)

    return number

end


function ProcessKeyword(input, number, keyword)

    local zeros, offset = input:match(keyword .. "(%d+)_([^,]+)_")

    if zeros or offset then
        msg('zeros = ' .. zeros)
        msg('offset = ' .. offset)
        local number = AddZerosAndOffset(number, zeros, offset)
        input = input:gsub(keyword .. "(%d+)_([^,]+)_", tostring(number))
    else
        input = input:gsub(keyword, tostring(number))
    end

    return input

end

------------------------------------------------------------------------------------------------------------------

function round(num)
  return num ~= 0 and math.floor(num+0.5) or math.ceil(num-0.5)
end

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

function hex2rgb(HEX_COLOR)
-- https://gist.github.com/jasonbradley/4357406
    if HEX_COLOR == nil then
        HEX_COLOR = '#FFFFFF'
    end
    local hex = HEX_COLOR:sub(2)
    return '0x' .. hex .. 'FF'
end

local function getRegionNameAtPosition(position)
    local _, marker_count, region_count = reaper.CountProjectMarkers(0)
    local total_markers = marker_count + region_count
    local matched_name = ""
    local matched_start = -math.huge

    for marker_index = 0, total_markers - 1 do
        local _, is_region, start_position, end_position, region_name =
            reaper.EnumProjectMarkers(marker_index)

        if is_region and position >= start_position and position <= end_position
            and start_position >= matched_start then
            matched_name = region_name or ""
            matched_start = start_position
        end
    end

    return matched_name
end

function main(text)

    reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the

    -- INITIALIZE loop through selected items
    local selected_items_count = reaper.CountSelectedMediaItems(0)
    local items_by_track = {}

    for i = 0, selected_items_count-1  do
        -- GET ITEMS
        local item = reaper.GetSelectedMediaItem(0, i) -- Get selected item i

        local track = reaper.GetMediaItemTrack(item)
        local track_id = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
        local track_name_retval, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

        if not items_by_track[track] then
            items_by_track[track] = {}
        end
        table.insert(items_by_track[track], {item = item, track_id = track_id, track_name = track_name})
    end

    for track, items_on_track in pairs(items_by_track) do
        for i, item_data in ipairs(items_on_track) do
            local item = item_data.item
            local track_id = item_data.track_id
            local track_name = item_data.track_name

        -- Some possible keywords from SWS label processor
        -- /D -- Duration
        -- /E[digits, first] -- enumerate in selection
        -- /e[digits, first] -- enumerate in selection on track
        -- /I[digits, first] -- inverse enumerate in selection
        -- /i[digits, first] -- inverse enumerate in selection on track
        -- /T[offset, length] -- Track name
        -- /t[digits] -- Track number

        local input = text
        msg('input = ' .. input)

        if string.find(input, "/E") then
            local number = i

            input  = ProcessKeyword(input, number, "/E")
        end

        if string.find(input, "/I") then
            local number = #items_on_track - i + 1

            input  = ProcessKeyword(input, number, "/I")
        end

        if string.find(input, "/e") then
            local number = i

            input  = ProcessKeyword(input, number, "/e")
        end

        if string.find(input, "/i") then
            local number = #items_on_track - i + 1

            input  = ProcessKeyword(input, number, "/i")
        end

        -- if string.find(input, "/M") then
        --         -- получить позицию элемента
        --         item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        --         -- получить индекс маркера, рядом с которым находится элемент
        --         markeridx, regionidx = reaper.GetNearestMarkerAndCurRegion( 0, item_pos )
        --         -- получить имя маркера по индексу
        --         retval, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers( markeridx )
        --         input  = ProcessKeyword(input, number, "/M")
        -- end

        input = input:gsub("/T", track_name)
        input = input:gsub("/t", tostring(track_id))
        local cursor_pos = reaper.GetCursorPosition()
        local region_name = getRegionNameAtPosition(cursor_pos)
        input = input:gsub("/r", function()
            return region_name
        end)
        -- input = input:gsub("/M", name ) -- добавлено
        local notes = reaper.ULT_GetMediaItemNote(item)
        input = input:gsub("$notes", notes )
        input = input:gsub("\\n", "\r\n" )

        reaper.ULT_SetMediaItemNote(item, input)

        end -- end of items loop on track
    end -- end of tracks loop

    reaper.Undo_EndBlock("Add text to selected items notes (Items Names Processor)", -1) -- End of the undo block. Leave it at the bottom of your main function

end

------------------------------------------------------------------------------------------------------------
function notes_to_names() -- local (i, j, item, take, track)

    reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.
    -- LOOP THROUGH SELECTED ITEMS
    selected_items_count = reaper.CountSelectedMediaItems(0)
    -- INITIALIZE loop through selected items
    for i = 0, selected_items_count-1  do
        -- GET ITEMS
        item = reaper.GetSelectedMediaItem(0, i) -- Get selected item i
        take = reaper.GetActiveTake(item)
        if take ~= nil then
            -- GET NOTES
            note = reaper.ULT_GetMediaItemNote(item)
            note = note:gsub("\n", " ")
            --reaper.ShowConsolemsg(note)
            -- MODIFY TAKE
            retval, stringNeedBig = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", note, 1)
        end
    end -- ENDLOOP through selected items
    reaper.Undo_EndBlock("Convert selected item to take name", 0) -- End of the undo block. Leave it at the bottom of your main function.
end

-- notes_to_names() -- Execute your main function

------------------------------------------------------------------------------------------------------------
function delete() -- local (i, j, item, take, track)
    reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.
    -- LOOP THROUGH SELECTED ITEMS
    selected_items_count = reaper.CountSelectedMediaItems(0)
    -- INITIALIZE loop through selected items
    for i = 0, selected_items_count-1  do
        -- GET ITEMS
        item = reaper.GetSelectedMediaItem(0, i) -- Get selected item i
        -- MODIFY NOTES
        note = ""
        -- SET NOTES
        reaper.ULT_SetMediaItemNote(item, note)
    end -- ENDLOOP through selected items
    reaper.Undo_EndBlock("Delete selected items names", 0) -- End of the undo block. Leave it at the bottom of your main function.
end

-- delete() -- Execute your main function
------------------------------------------------------------------------------------------------------------
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
reaper.UpdateArrange() -- Update the arrangement (often needed)
reaper.PreventUIRefresh(-1)
end
-----------------------------------------------------------------------------
local ctx = r.ImGui_CreateContext(windowTitle)
local size =  r.GetAppVersion():match('Win64') and 12 or 12
local font = reaper.ImGui_CreateFont('sans-serif', size)
r.ImGui_Attach(ctx, font)
click_count, text = 0, '/T /E'
color = nil
local executeAction = false
local presets = {}
local settingsFile = scriptDir .. 'trs_Label GUI Tools.ini'

local function encodeIniValue(value)
  return value:gsub('\\', '\\\\'):gsub('\r', '\\r'):gsub('\n', '\\n')
end

local function decodeIniValue(value)
  local decoded = {}
  local index = 1
  while index <= #value do
    local char = value:sub(index, index)
    if char == '\\' and index < #value then
      local escaped = value:sub(index + 1, index + 1)
      if escaped == 'n' then
        decoded[#decoded + 1] = '\n'
      elseif escaped == 'r' then
        decoded[#decoded + 1] = '\r'
      else
        decoded[#decoded + 1] = escaped
      end
      index = index + 2
    else
      decoded[#decoded + 1] = char
      index = index + 1
    end
  end
  return table.concat(decoded)
end

local savePresets

local function loadPresets()
  local file = io.open(settingsFile, 'r')
  if file then
    for line in file:lines() do
      local value = line:match('^Preset%d+=(.*)$')
      if value then
        presets[#presets + 1] = decodeIniValue(value)
      end
    end
    file:close()
    return
  end

  -- Import presets saved by previous versions, then persist them in the INI file.
  local legacyPresets = r.GetExtState('trs_Label_GUI_Tools', 'presets')
  for preset in legacyPresets:gmatch('[^\r\n]+') do
    presets[#presets + 1] = preset
  end
  if #presets > 0 then
    savePresets()
    r.DeleteExtState('trs_Label_GUI_Tools', 'presets', true)
  end
end

savePresets = function()
  local file = io.open(settingsFile, 'w')
  if not file then
    r.ShowMessageBox('Не удалось сохранить настройки в файл:\n' .. settingsFile,
      'Label GUI Tools', 0)
    return
  end

  file:write('[Presets]\n')
  for index, preset in ipairs(presets) do
    file:write('Preset' .. index .. '=' .. encodeIniValue(preset) .. '\n')
  end
  file:close()
end

local function hasPreset(value)
  for _, preset in ipairs(presets) do
    if preset == value then
      return true
    end
  end
  return false
end

loadPresets()

local function normalizeSourcePath(path)
  return path:gsub('\\', '/'):lower()
end

local function checkSameSource()
  local selectedItem = r.GetSelectedMediaItem(0, 0)
  if not selectedItem then
    return
  end

  local selectedTake = r.GetActiveTake(selectedItem)
  if not selectedTake then
    return
  end

  local selectedSource = r.GetMediaItemTake_Source(selectedTake)
  if not selectedSource then
    return
  end

  local selectedPath = r.GetMediaSourceFileName(selectedSource, '')
  if selectedPath == '' then
    return
  end
  selectedPath = normalizeSourcePath(selectedPath)

  r.SelectAllMediaItems(0, false)

  local itemCount = r.CountMediaItems(0)
  for itemIndex = 0, itemCount - 1 do
    local item = r.GetMediaItem(0, itemIndex)
    local take = r.GetActiveTake(item)
    if take then
      local source = r.GetMediaItemTake_Source(take)
      if source then
        local sourcePath = r.GetMediaSourceFileName(source, '')
        if sourcePath ~= '' and normalizeSourcePath(sourcePath) == selectedPath then
          r.SetMediaItemSelected(item, true)
        end
      end
    end
  end

  r.UpdateArrange()
end
-----------------------------------------------------------------------------

function round(num)
  return num ~= 0 and math.floor(num+0.1) or math.ceil(num-0.1)
end

-- function round(exact, quantum)
--     local quant,frac = math.modf(exact/quantum)
--     return quantum * (quant + (frac > 0.5 and 1 or 0))
-- end

-- function round(x, n)
--     n = math.pow(10, n or 0)
--     x = x * n
--     if x >= 0 then x = math.floor(x + 0.5) else x = math.ceil(x - 0.5) end
--     return x / n
-- end

-- function round(num)
--   return math.floor(num + .5)
-- end

function btnColor(col, i)
    r.ImGui_PushID(ctx, color)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(color / 7.0, 0.6, 0.6, 1.0))
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(color / 7.0, 0.7, 0.7, 1.0))
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(color / 7.0, 0.8, 0.8, 1.0))
end

function btnCol(name, string, col, i)
              r.ImGui_PushID(ctx, col)
              r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
              r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
              r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           if r.ImGui_Button(ctx, name) then
              text = string
              executeAction = true
           end
           r.ImGui_PopStyleColor(ctx, 3)
           r.ImGui_PopID(ctx)
           return
end
------------------------------------------------------------------------------------------------------------------

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

function btnCmdCol(name, idCmd, helpText, col, i)
           r.ImGui_PushID(ctx, col)
       r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           if r.ImGui_Button(ctx, ''..name..'') then
              if idCmd ~= '' then
                local commandId = r.NamedCommandLookup(idCmd)
                if commandId ~= 0 then
                  r.Main_OnCommand(commandId, 0)
                else
                  r.ShowMessageBox("Команда не найдена:\n" .. idCmd, "Label GUI Tools", 0)
                end
              end
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
              funcName = ''
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

-- Создаем функцию, которая будет переименовывать выделенный айтем, вставив имя региона и имя трека
-- function RX()
--   -- Получаем выделенный айтем
--   local item = reaper.GetSelectedMediaItem(0, 0)
--   -- Проверяем, что айтем существует
--   if item then
--     -- Получаем позицию и длину айтема в секундах
--     local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
--     local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
--     -- Получаем количество регионов в проекте
--     local region_count = reaper.CountProjectMarkers(0)
--     -- Перебираем все регионы в цикле
--     for i = 0, region_count - 1 do
--       -- Получаем информацию о регионе по индексу
--       local _, is_region, region_pos, region_end, region_name = reaper.EnumProjectMarkers(i)
--       -- Проверяем, что это регион, а не маркер
--       if is_region then
--         -- Проверяем, попадает ли позиция айтема в диапазон региона
--         if item_pos >= region_pos and item_pos + item_len <= region_end then
--           -- Получаем трек, на котором находится айтем
--           local track = reaper.GetMediaItemTrack(item)
--           -- Получаем имя трека
--           local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
--           -- Формируем новое имя айтема, состоящее из имени региона и имени трека
--            new_item_name = tostring(region_name) .. " - " ..  tostring(track_name)
--           -- Устанавливаем новое имя айтему
--           reaper.GetSetMediaItemInfo_String(item, "P_NAME", new_item_name, true)
--           -- Прерываем цикл
--           break
--         end
--       end
--     end
--   end
--   -- reaper.UpdateArrange()
-- end

local function RR()
  -- Получить количество выделенных айтемов
  local num_items = reaper.CountSelectedMediaItems(0)

  -- Перебрать все выделенные айтемы
  for i = 0, num_items - 1 do
    -- Получить выделенный айтем
    local item = reaper.GetSelectedMediaItem(0, i)

    -- Проверить, что айтем существует
    if item then
      -- Получить позицию айтема
      local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      -- Получить имя региона, в котором находится курсор
      local RegionName = ""
      -- Получить количество регионов в проекте
      local num_regions = reaper.CountProjectMarkers(0)
      -- Перебрать все регионы
      for j = 0, num_regions - 1 do
        -- Получить информацию о регионе
        local _, is_region, start_pos, end_pos, name = reaper.EnumProjectMarkers(j)
        -- Проверить, что это регион и айтем внутри него
        if is_region and item_pos >= start_pos and item_pos <= end_pos then
          -- Сохранить имя региона
          RegionName = tostring(name)
          -- Прервать цикл
          break
        end
      end

      -- Получить активный трек
      local track = reaper.GetMediaItemTrack(item)
      -- Получить имя активного трека
      local track_name = ""
      if track then
        _, track_name = reaper.GetTrackName(track, "")
      end

      -- Объединить имя региона и имя трека
      local new_name = RegionName .. " " .. track_name

      local take = reaper.GetActiveTake(item)
      if take then
         reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
      end
    end
  end
end

local function RS()
  -- Получить количество выделенных айтемов
  local num_items = reaper.CountSelectedMediaItems(0)

  -- Перебрать все выделенные айтемы
  for i = 0, num_items - 1 do
    -- Получить выделенный айтем
    local item = reaper.GetSelectedMediaItem(0, i)

    -- Проверить, что айтем существует
    if item then
      -- Получить позицию айтема
      local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      -- Получить имя региона, в котором находится курсор
      local RegionName = ""
      -- Получить количество регионов в проекте
      local num_regions = reaper.CountProjectMarkers(0)
      -- Перебрать все регионы
      for j = 0, num_regions - 1 do
        -- Получить информацию о регионе
        local _, is_region, start_pos, end_pos, name = reaper.EnumProjectMarkers(j)
        -- Проверить, что это регион и айтем внутри него
        if is_region and item_pos >= start_pos and item_pos <= end_pos then
          -- Сохранить имя региона
          RegionName = tostring(name)
          -- Прервать цикл
          break
        end
      end

      -- Получить активный трек
      local track = reaper.GetMediaItemTrack(item)
      -- Получить имя активного трека
      local track_name = ""
      if track then
        _, track_name = reaper.GetTrackName(track, "")
      end

      -- Объединить имя региона и имя трека
      local new_name = RegionName .. " " .. track_name .. " " .. round(showBPM()) ..' bpm'

      local take = reaper.GetActiveTake(item)
      if take then
         reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
      end
    end
  end
end
local function showBPM()
  return reaper.Master_GetTempo()
end

function frame()
  local rv
      myBPM = tostring(showBPM())

      r.ImGui_Text(ctx,  'Selected Items:' .. '\n')
           r.ImGui_SameLine(ctx)
           selected_items_count =  r.CountSelectedMediaItems(0)
           if selected_items_count > 0 then
                 r.ImGui_TextColored(ctx, 0x88FF00FF, tostring(selected_items_count))
               else
                 r.ImGui_TextColored(ctx, 0xFF0036FF, "0")
           end

      if r.ImGui_Button(ctx, 'Check##SameSource') then
        checkSameSource()
      end
      r.ImGui_SameLine(ctx)
      btnCmdCol('Rename takes and source files','_XENAKIOS_RENMTAKEANDSOURCE','Xenakios/SWS: Rename takes and source files... (no undo)', 4,0)
      -- btnFuncCol('rename playback item', 'RR', 'XXX', 0) -- Load lua file script
      -- if r.ImGui_Button(ctx, 'RENAME TAKE - REGION + TRACKNAME') then
      --        RR()
      --    end
      --    if r.ImGui_Button(ctx, 'RENAME TAKE - REGION + TRACKNAME + BPM') then
      --           RS()
      --       end
      -- r.ImGui_Text(ctx,  '')
      r.ImGui_TextColored(ctx, 0xFFFF00FF, 'Rename LABEL Buttons:')

      btnCol('EMPTY##Empty','', 7,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  '')
      btnCol('RENAME##RegionTrack','/r /T', 5,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Region Track')
      btnCol('RENAME##RegionTrackBPM','/r /T '..round(showBPM()) ..'', 6,2)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Region Track BPM')
      btnCol('RENAME##NameOnly','/T', 5,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name only')
      btnCol('RENAME##NameIndex','/T_/E', 6,2)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name Index')
      btnCol('RENAME##NameTuned','/T /E Tunned', 4,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name Tuned')
      -- btnCol('RENAME','/T Fixed', 3,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name Fixed')
      btnCol('RENAME##NameClick','/T Click', 3,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name Click')

      btnCol('RENAME##NameIndex_BPM','/T_'..round(showBPM()) ..'', 7,5)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name_')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, 0xFFFF00FF,myBPM)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx, '')
      btnCol('RENAME##NameIndexBPM','/T_/E '.. round(showBPM()) ..' bpm', 7,5)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name Index')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, 0xFFFF00FF, myBPM)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx, 'BPM')
      r.ImGui_Text(ctx,  '  ')
      if r.ImGui_Button(ctx, 'Add') then
        local preset = text:match('^%s*(.-)%s*$')
        if preset ~= '' and not hasPreset(preset) then
          presets[#presets + 1] = preset
          savePresets()
        end
      end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, 'GO!') then
        executeAction = true
      end
      r.ImGui_SameLine(ctx)
      local inputWidth = r.ImGui_GetContentRegionAvail(ctx)
      r.ImGui_SetNextItemWidth(ctx, inputWidth)
      rv, text = r.ImGui_InputText(ctx, '##preset_input', text)
      for index, preset in ipairs(presets) do
        r.ImGui_PushID(ctx, 'saved_preset_' .. index)
        if r.ImGui_Button(ctx, preset) then
          text = preset
          executeAction = true
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, 'X') then
          table.remove(presets, index)
          savePresets()
          r.ImGui_PopID(ctx)
          break
        end
        r.ImGui_PopID(ctx)
      end
  if executeAction then
      main(text)
      notes_to_names()
      delete()
      executeAction = false
  end
  end

function loop()
  r.ImGui_SetNextWindowSize(ctx, 180, 150,  r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, windowTitle, true)
  if visible then
    r.ImGui_PushFont(ctx, font, size)
    frame()
    r.ImGui_PopFont(ctx)
  end
  r.ImGui_End(ctx)

-- Просто продолжаем цикл пока окно открыто
if open then
    r.defer(loop)
-- Не нужно явно уничтожать контекст - ReaImGui сделает это автоматически
end
end

 r.defer(loop)



