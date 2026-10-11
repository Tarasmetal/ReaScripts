-- @description TRACK RENAME GUI TOOLS
-- @author Taras Umanskiy
-- @version 4.8
-- @provides [main] .
--  [script] TrackPresets/trs_TrackGUITools_default.lua
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about Скрипт предоставляет мощный графический интерфейс для управления именами треков, панорамированием и цветами в REAPER. Поддерживает систему пресетов, HEX-коды цветов и удобную навигацию.
-- @changelog
--   + ПКМ на кнопке панорамы открывает поле InputInt прямо на месте кнопок; Enter/клик мимо — сохранение и выход, Escape — выход без сохранения.
--   + Убрана кнопка "+ Add" из окна панорамирования (добавление строки теперь через Insert).
--   + В окне панорамирования клавиши Insert и Delete работают на обеих кнопках (-val и val) по аналогии с главным окном.
--   + В подсказку кнопки "P" добавлено описание горячих клавиш Insert/Delete.
--   + Панорамирование убрано из основного окна и теперь редактируется только в отдельном окне Pan.
--   + Добавлено отдельное окно панорамирования с магнитным прилипанием (лево/право от основного).
--   + Добавлена кнопка "Pan" рядом с Clone для показа/скрытия окна панорамирования (ПКМ — переключение стороны).
--   + Добавлены всплывающие подсказки на кнопках Index, LR и Clone.
--   + Улучшена логика кнопки "LR": теперь окончания L и R проверяются с учетом предшествующего пробела, подчеркивания (_) или дефиса (-).
--   + Добавлена возможность добавления строки (Insert на основной кнопке) и суффикса (Insert на кнопке суффикса) при наведении мыши.
--   + Кнопка "Add Row" теперь большая, находится по центру и мигает красно-желтым цветом (для пустых пресетов).
--   + Кнопка "Add Row" теперь отображается в главном интерфейсе, только если пресет пустой.
--   + Добавлены кнопки New, Clear и Delete во всплывающее меню PRESETS для управления файлами пресетов.
--   + Кнопка PRESETS теперь открывает список пресетов в виде всплывающего меню.
--   + Добавлена возможность удаления ячейки или строки пресета клавишей Delete при наведении мыши.
--   + Добавлена возможность клонирования имен треков с разделением на префиксы и суффиксы (ПКМ на кнопке Clone).
--   + Добавлена кнопка "Clone" для добавления имен выделенных треков в список пресетов.
--   + Добавлена кнопка "LR" для автоматического именования дубликатов треков (L/R).
--   + Добавлена кнопка "Index" для нумерации дубликатов треков.
--   + Added multi-track support for renaming, coloring, and panning.
--   + Added support for HEX color codes in presets.
--   + Code optimizations.

local r = reaper
console = false

function msg(value) if console then r.ShowConsoleMsg(tostring(value) .. "\n") end end

title = 'TRACK RENAME GUI TOOLS'
ver = '4.8'
author = 'Taras Umanskiy'
about = title .. ' ' .. ver .. ' | by ' .. author
ListDir = {}
ListDir.scriptDir, ListDir.scriptFileName = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")
windowTitle = title .. " by " .. author .. " " .. ver

scriptDir = ListDir.scriptDir
scriptFileName = ListDir.scriptFileName

presetPath = ListDir.scriptDir .. "TrackPresets"
presetFile = ListDir.scriptDir .. "TrackPresets" .. "/" .. "user.txt"

function GetAllPresetFiles(path)
  local files = {}
  local i = 0
  while true do
    local filename = reaper.EnumerateFiles(path, i)
    if not filename then break end
    if filename:match("%.txt$") then -- Проверяем, что это .txt файл
      table.insert(files, path .. "/" .. filename)
    end
    i = i + 1
  end
  return files
end
saveFile = ListDir.scriptDir .. "TrackPresets" .. "/" .. "default.txt"

local lastPresetExtStateKey = scriptFileName .. "_LastPreset"

dofile(scriptDir  .. "TrackPresets" .. "/" ..  "trs_TrackGUITools_default.lua")
track_set = track_set_def

function ColorToHex(color)
  if type(color) == "number" then
    local r_val, g_val, b_val = r.ColorFromNative(color)
    return string.format("#%02X%02X%02X", r_val, g_val, b_val)
  end
  return "false"
end

function HexToColor(hex)
  if type(hex) == "string" and hex:sub(1, 1) == "#" then
    local r_val = tonumber(hex:sub(2, 3), 16)
    local g_val = tonumber(hex:sub(4, 5), 16)
    local b_val = tonumber(hex:sub(6, 7), 16)
    if r_val and g_val and b_val then
      return r.ColorToNative(r_val, g_val, b_val)
    end
  elseif tonumber(hex) then
    return tonumber(hex)
  end
  return false
end

local currentPresetIndex = 1
local allPresetFiles = {}

-- Глобальный массив панорамирования (независим от track_set)
pan_set = {}

function SavePreset(saveFile, track_set)
  local file = io.open(saveFile, "w")
  if file then
    for _, set in ipairs(track_set) do
      local line = set.text or ""
      for i = 1, 5 do
        line = line .. "," .. (set["text_add_" .. i] or "")
      end
      -- pan и color
      local color_value = ColorToHex(set.color)
      line = line .. ",false," .. color_value
      file:write(line .. "\n")
    end
    -- Секция панорамирования
    file:write("##PAN##\n")
    for _, val in ipairs(pan_set) do
      file:write(tostring(val) .. "\n")
    end
    file:close()
    msg("Preset saved to: " .. saveFile)
  else
    msg("Error: Could not open file for writing: " .. saveFile)
  end
end

function cloneSelectedTracksToSet(split_prefix_suffix)
  local track_count = reaper.CountSelectedTracks(0)
  if track_count == 0 then
    reaper.ShowMessageBox("Не выбрано ни одного трека!", "Ошибка", 0)
    return
  end

  for i = 0, track_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if name == "" then
      name = "Track " .. math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    end

    local main_text = name
    local suffixes = {"", "", "", "", ""}

    if split_prefix_suffix then
      -- Пытаемся найти разделитель (пробел, дефис или подчеркивание)
      -- Ищем первое слово как префикс, остальное как суффиксы
      local prefix, rest = name:match("^%s*([^%s%-_]+)%s*[ %-_]%s*(.*)$")
      if prefix and rest then
        main_text = prefix
        -- Разбиваем остаток на части по разделителям
        local count = 1
        for part in rest:gmatch("([^%s%-_]+)") do
          if count <= 5 then
            suffixes[count] = part
            count = count + 1
          else
            break
          end
        end
      end
    end

    local color = reaper.GetTrackColor(track)
    local has_color = (color ~= 0)

    local new_set = {
      text = main_text,
      text_add_1 = suffixes[1],
      text_add_2 = suffixes[2],
      text_add_3 = suffixes[3],
      text_add_4 = suffixes[4],
      text_add_5 = suffixes[5],
      pan = false,
      color = has_color and color or false
    }
    table.insert(track_set, new_set)
  end

  if #allPresetFiles > 0 and allPresetFiles[currentPresetIndex] then
    SavePreset(allPresetFiles[currentPresetIndex], track_set)
  end
end

function LoadPreset(saveFile)
  local loaded_track_set = {}
  local loaded_pan_set = {}
  local in_pan_section = false
  local legacy_pan = {}
  local file = io.open(saveFile, "r")
  if file then
    for line in file:lines() do
      if line == "##PAN##" then
        in_pan_section = true
      elseif in_pan_section then
        -- Строки секции панорамирования: по одному значению
        local val = tonumber(line)
        if val then table.insert(loaded_pan_set, val) end
      else
        local parts = {}
        for part in line:gmatch("([^,]*),?") do
          table.insert(parts, part)
        end

        local set = {}
        set.text = parts[1] or ""
        for i = 1, 5 do
          set["text_add_" .. i] = parts[i + 1] or ""
        end

        -- Колонка 7 больше не хранит pan (зарезервировано), мигрируем старые файлы
        local pan_str = parts[7]
        if pan_str and pan_str ~= "false" and pan_str ~= "" then
          local num = tonumber(pan_str)
          if num then table.insert(legacy_pan, num) end
        end

        local color_str = parts[8]
        if color_str and color_str ~= "false" and color_str ~= "" then
          set.color = HexToColor(color_str)
        else
          set.color = false
        end

        table.insert(loaded_track_set, set)
      end
    end
    file:close()
    -- Если секции ##PAN## не было — используем значения из старых файлов
    if #loaded_pan_set == 0 and #legacy_pan > 0 then
      loaded_pan_set = legacy_pan
    end
    pan_set = loaded_pan_set
    msg("Preset loaded from: " .. saveFile)
    return loaded_track_set
  else
    msg("Error: Could not open file for reading: " .. saveFile)
    return nil
  end
end

if not r.file_exists(presetPath) then
  r.RecursiveCreateDirectory(presetPath, 0)
end
if not r.file_exists(presetFile) then
  SavePreset(presetFile, track_set_def_user)
end
if not r.file_exists(saveFile) then
  SavePreset(saveFile, track_set_def)
end

allPresetFiles = GetAllPresetFiles(presetPath)
currentPresetIndex = 1

-- Проверяем lastPresetPath и добавляем его в allPresetFiles, если он не там
local lastPresetPath = reaper.GetExtState("trs_TrackGUITools", lastPresetExtStateKey)
if lastPresetPath ~= "" and reaper.file_exists(lastPresetPath) then
  local found = false
  for _, path in ipairs(allPresetFiles) do
    if path == lastPresetPath then
      found = true
      break
    end
  end
  if not found then
    table.insert(allPresetFiles, lastPresetPath)
  end
end

function LoadPresetByIndex(index)
  if #allPresetFiles == 0 then
    msg("No preset files found.")
    return
  end
  local actualIndex = (index - 1) % #allPresetFiles + 1 -- Циклическая навигация
  if actualIndex < 1 then
    actualIndex = #allPresetFiles
  end
  currentPresetIndex = actualIndex
  local presetToLoad = allPresetFiles[currentPresetIndex]
  local loaded_set = LoadPreset(presetToLoad)
  if loaded_set then
    track_set = loaded_set
    reaper.SetExtState("trs_TrackGUITools", lastPresetExtStateKey, presetToLoad, true)
  end
end

function GoToPreviousPreset()
  LoadPresetByIndex(currentPresetIndex - 1)
end

function GoToNextPreset()
  LoadPresetByIndex(currentPresetIndex + 1)
end

-- Инициализация при запуске скрипта
if lastPresetPath ~= "" and reaper.file_exists(lastPresetPath) then
  local foundIndex = -1
  for i, path in ipairs(allPresetFiles) do
    if path == lastPresetPath then
      foundIndex = i
      break
    end
  end
  if foundIndex ~= -1 then
    LoadPresetByIndex(foundIndex)
  else
    -- Если lastPresetPath не найден в allPresetFiles (например, был добавлен вручную), загружаем его
    local loaded_set = LoadPreset(lastPresetPath)
    if loaded_set then
      track_set = loaded_set
      reaper.SetExtState("trs_TrackGUITools", lastPresetExtStateKey, lastPresetPath, true)
      -- currentPresetIndex уже установлен на 1 по умолчанию, если lastPresetPath не был в allPresetFiles
      -- и мы его только что добавили, то он будет последним элементом
      currentPresetIndex = #allPresetFiles
    else
      -- Если lastPresetPath недействителен, загружаем первый пресет или дефолтный
      if #allPresetFiles > 0 then
        LoadPresetByIndex(1)
      else
        r.RecursiveCreateDirectory(presetPath, 0)
        SavePreset(presetFile, track_set_def)
        SavePreset(saveFile, track_set_def)
        track_set = track_set_def
      end
    end
  end
else
  -- Если в ExtState нет сохраненного пути или он недействителен, используем первый пресет или дефолтный
  if #allPresetFiles > 0 then
    LoadPresetByIndex(1)
  else
    r.RecursiveCreateDirectory(presetPath, 0)
    SavePreset(presetFile, track_set_def)
    SavePreset(saveFile, track_set_def)
    track_set = track_set_def
  end
end

local color_1 = 0x171717F0 --F0 0x3B4068FF
local color_2 = 0x2C3A47F0 --F0 0x2C3A47F0
local color_3 = 0x202020FF --F0 0x202020FF
local color_4 = 0x102010FF --F0 0x102010FF
local color_yellow = 0xFFFF00FF -- Желтый цвет для имени пресета

local new_preset_name = "" -- Переменная для хранения имени нового пресета

function renameSelectedTracks()
  local selectedTracksCount = reaper.CountSelectedTracks(0)
  if selectedTracksCount == 0 then
    reaper.ShowMessageBox("Не выбрано ни одного трека!", "Ошибка", 0)
    return
  end
  local trackNames = {}
  local renameCounters = {}

  local function removeExtraSpaces(name)
    return name:match("^%s*(.-)%s*$"):gsub("%s+", " ")
  end

  for i = 0, selectedTracksCount - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    trackName = removeExtraSpaces(trackName)
    trackNames[trackName] = (trackNames[trackName] or 0) + 1
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", trackName, true)
  end

  for i = 0, selectedTracksCount - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if trackNames[trackName] > 1 then
      renameCounters[trackName] = (renameCounters[trackName] or 1)
      local newTrackName = string.format("%s %d", trackName, renameCounters[trackName])
      reaper.GetSetMediaTrackInfo_String(track, "P_NAME", newTrackName, true)
      renameCounters[trackName] = renameCounters[trackName] + 1
    end
  end
end

function hasSuffix(name)
  return name:match("[%s%-_][LR]$") ~= nil
end

function processDuplicateTracksLR()
  local track_count = reaper.CountSelectedTracks(0)
  if track_count == 0 then
    reaper.ShowMessageBox("Не выбрано ни одного трека!", "Ошибка", 0)
    return
  end

  local tracks = {}
  local name_counts = {}

  for i = 0, track_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local clean_name = name:match("^(.-)[%s%-_][LR]$")
    if not clean_name then
      clean_name = name
    end
    clean_name = clean_name:lower()

    if not name_counts[clean_name] then
      name_counts[clean_name] = {count = 0, indices = {}}
    end

    if not hasSuffix(name) then
      name_counts[clean_name].count = name_counts[clean_name].count + 1
      table.insert(name_counts[clean_name].indices, i)
    end

    tracks[i] = {
      track = track,
      original_name = name,
      clean_name = clean_name,
      has_suffix = hasSuffix(name)
    }
  end

  for clean_name, data in pairs(name_counts) do
    if data.count > 1 then
      local indices = data.indices
      local total_duplicates = #indices

      local pairs_to_process = math.floor(total_duplicates / 2)
      for pair = 1, pairs_to_process do
        local idx1 = indices[(pair-1)*2 + 1]
        local idx2 = indices[(pair-1)*2 + 2]

        local track1 = tracks[idx1].track
        local track2 = tracks[idx2].track

        if not tracks[idx1].has_suffix then
          reaper.GetSetMediaTrackInfo_String(track1, "P_NAME", tracks[idx1].original_name .. " L", true)
        end
        if not tracks[idx2].has_suffix then
          reaper.GetSetMediaTrackInfo_String(track2, "P_NAME", tracks[idx2].original_name .. " R", true)
        end
      end
    end
  end
end

-- Pan window state
local showPanWindow = (reaper.GetExtState("trs_TrackGUITools", "showPanWindow") == "1")
local panWindowSide = reaper.GetExtState("trs_TrackGUITools", "panWindowSide")
if panWindowSide ~= "left" and panWindowSide ~= "right" then panWindowSide = "right" end

local ctx = r.ImGui_CreateContext(windowTitle)
local size = 12
local font = reaper.ImGui_CreateFont('Arial-Regular', size)
-- local font = reaper.ImGui_CreateFont('NotoSans', size)
-- local font = reaper.ImGui_CreateFont('NotoSans-Regular', size)
-- local font = reaper.ImGui_CreateFont('sans-serif', size)
reaper.ImGui_Attach(ctx, font)

local function myWindow()
  local rv
  -- Кнопки с равной шириной
  local btnWidth = 80
  local spacing = 4
  r.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), spacing, spacing)

  -- Кнопка PRESETS
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_4)
  if r.ImGui_Button(ctx, "PRESETS", btnWidth, 0) then
    r.ImGui_OpenPopup(ctx, "Presets List")
  end
  r.ImGui_PopStyleColor(ctx, 1)

  -- Popup со списком пресетов
  if r.ImGui_BeginPopup(ctx, "Presets List") then
    -- Кнопки управления в начале списка
    if r.ImGui_Button(ctx, "New", btnWidth, 0) then
      r.ImGui_OpenPopup(ctx, "New Preset")
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Clear", btnWidth, 0) then
      track_set = {}
      SavePreset(allPresetFiles[currentPresetIndex], track_set)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Delete", btnWidth, 0) then
      if #allPresetFiles > 1 then
        os.remove(allPresetFiles[currentPresetIndex])
        table.remove(allPresetFiles, currentPresetIndex)
        currentPresetIndex = math.max(1, currentPresetIndex - 1)
        LoadPresetByIndex(currentPresetIndex)
      else
        reaper.ShowMessageBox("Нельзя удалить единственный пресет!", "Ошибка", 0)
      end
    end

    r.ImGui_Separator(ctx)

    for i, path in ipairs(allPresetFiles) do
      local fileName = path:match("[^/\\]+%.txt$")
      if fileName then
        fileName = fileName:gsub("%.txt$", "")
        if r.ImGui_Selectable(ctx, fileName, currentPresetIndex == i) then
          LoadPresetByIndex(i)
        end
      end
    end

    -- Popup для создания НОВОГО пустого пресета
    if r.ImGui_BeginPopupModal(ctx, "New Preset", true, r.ImGui_WindowFlags_AlwaysAutoResize()) then
      local changed, text = r.ImGui_InputText(ctx, "New Preset Name", new_preset_name)
      if changed then new_preset_name = text end

      if r.ImGui_Button(ctx, "Create", 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter()) then
        if new_preset_name ~= "" then
          local newFilename = new_preset_name
          if not newFilename:match("%.txt$") then
            newFilename = newFilename .. ".txt"
          end
          local fullPath = presetPath .. "/" .. newFilename

          track_set = {} -- Пустой пресет
          SavePreset(fullPath, track_set)

          table.insert(allPresetFiles, fullPath)
          currentPresetIndex = #allPresetFiles
          reaper.SetExtState("trs_TrackGUITools", lastPresetExtStateKey, fullPath, true)

          r.ImGui_CloseCurrentPopup(ctx)
          new_preset_name = ""
        end
      end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "Cancel", 120, 0) then
        r.ImGui_CloseCurrentPopup(ctx)
      end
      r.ImGui_EndPopup(ctx)
    end

    r.ImGui_EndPopup(ctx)
  end

  -- Кнопка SAVE AS
  r.ImGui_SameLine(ctx)
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_4)
  if r.ImGui_Button(ctx, "SAVE AS", btnWidth, 0) then
    r.ImGui_OpenPopup(ctx, "Save Preset As")
  end
  r.ImGui_PopStyleColor(ctx, 1)

  -- Popup для сохранения пресета
  if r.ImGui_BeginPopupModal(ctx, "Save Preset As", true, r.ImGui_WindowFlags_AlwaysAutoResize()) then
    local changed, text = r.ImGui_InputText(ctx, "Preset Name", new_preset_name)
    if changed then new_preset_name = text end

    if r.ImGui_Button(ctx, "Save", 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter()) then
      if new_preset_name ~= "" then
        local newFilename = new_preset_name
        if not newFilename:match("%.txt$") then
          newFilename = newFilename .. ".txt"
        end
        local fullPath = presetPath .. "/" .. newFilename

        SavePreset(fullPath, track_set)

        -- Обновляем список и текущий индекс
        local found = false
        for i, path in ipairs(allPresetFiles) do
            if path == fullPath then
                found = true
                currentPresetIndex = i
                break
            end
        end
        if not found then
            table.insert(allPresetFiles, fullPath)
            currentPresetIndex = #allPresetFiles
        end
        reaper.SetExtState("trs_TrackGUITools", lastPresetExtStateKey, fullPath, true)

        r.ImGui_CloseCurrentPopup(ctx)
        new_preset_name = "" -- Сброс имени
      else
         msg("Please enter a preset name.")
      end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Cancel", 120, 0) then
       r.ImGui_CloseCurrentPopup(ctx)
    end
    r.ImGui_EndPopup(ctx)
  end

  -- Кнопка для предыдущего пресета
  local navBtnWidth = 30 -- Ширина кнопок навигации
  r.ImGui_SameLine(ctx)
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_4)
  if r.ImGui_Button(ctx, "<", navBtnWidth, 0) then
    GoToPreviousPreset()
  end
  r.ImGui_PopStyleColor(ctx, 1)

  -- Кнопка для следующего пресета
  r.ImGui_SameLine(ctx)
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_4)
  if r.ImGui_Button(ctx, ">", navBtnWidth, 0) then
    GoToNextPreset()
  end
  r.ImGui_PopStyleColor(ctx, 1)

  -- Отображение имени текущего пресета
  if #allPresetFiles > 0 then
    local currentPresetName = allPresetFiles[currentPresetIndex]:match("[^/\\]+%.txt$")
    if currentPresetName then
      currentPresetName = currentPresetName:gsub("%.txt$", "") -- Удаляем расширение .txt
      r.ImGui_SameLine(ctx)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), color_yellow)
      r.ImGui_Text(ctx, "  " .. currentPresetName)
      r.ImGui_PopStyleColor(ctx, 1)

      r.ImGui_SameLine(ctx)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_4)
      if r.ImGui_Button(ctx, " Index", 50, 0) then
        renameSelectedTracks()
      end
      if r.ImGui_IsItemHovered(ctx) then
        r.ImGui_SetTooltip(ctx, "Пронумеровать дубликаты выделенных треков\n(добавляет индекс к одинаковым именам)")
      end
      r.ImGui_PopStyleColor(ctx, 1)

      r.ImGui_SameLine(ctx)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_4)
      if r.ImGui_Button(ctx, "LR", 50, 0) then
        processDuplicateTracksLR()
      end
      if r.ImGui_IsItemHovered(ctx) then
        r.ImGui_SetTooltip(ctx, "Переименовать дубликаты выделенных треков\n(добавляет суффиксы L и R к парным трекам)")
      end
      r.ImGui_PopStyleColor(ctx, 1)

      r.ImGui_SameLine(ctx)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_4)
      if r.ImGui_Button(ctx, "Clone", 50, 0) then
        cloneSelectedTracksToSet(false)
      end
      if r.ImGui_IsItemHovered(ctx) then
        r.ImGui_SetTooltip(ctx, "ЛКМ — клонировать имена выделенных треков в пресет\nПКМ — клонировать с разделением на префикс и суффиксы")
      end
      if r.ImGui_IsItemClicked(ctx, r.ImGui_MouseButton_Right()) then
        cloneSelectedTracksToSet(true)
      end
      r.ImGui_PopStyleColor(ctx, 1)

      r.ImGui_SameLine(ctx)
      local panBtnColor = showPanWindow and 0x4A7C59FF or color_4
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), panBtnColor)
      if r.ImGui_Button(ctx, "P", 25, 0) then
        showPanWindow = not showPanWindow
        reaper.SetExtState("trs_TrackGUITools", "showPanWindow", showPanWindow and "1" or "0", true)
      end
      if r.ImGui_IsItemHovered(ctx) then
        r.ImGui_SetTooltip(ctx, "Показать/скрыть окно панорамирования\nПКМ — переключить сторону прилипания (лево/право)\nInsert — добавить строку после наведённой\nDelete — удалить наведённую строку")
      end
      if r.ImGui_IsItemClicked(ctx, r.ImGui_MouseButton_Right()) then
        panWindowSide = (panWindowSide == "right") and "left" or "right"
        reaper.SetExtState("trs_TrackGUITools", "panWindowSide", panWindowSide, true)
      end
      r.ImGui_PopStyleColor(ctx, 1)

      -- Add Row button only if preset is empty or cleared
      if #track_set == 0 then
        local window_w = r.ImGui_GetWindowSize(ctx)
        local btn_w, btn_h = 70, 45

        -- Center horizontally
        r.ImGui_SetCursorPosX(ctx, (window_w - btn_w) / 2)
        -- Add some vertical space
        r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + 20)

        -- Flashing color: Red (1,0,0) to Yellow (1,1,0)
        local time = r.time_precise()
        local phase = (math.sin(time * 8) + 1) / 2 -- Pulsing frequency 8
        local flash_color = r.ImGui_ColorConvertDouble4ToU32(1.0, phase, 0.0, 0.3)

        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), flash_color)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), flash_color)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), flash_color)

        if r.ImGui_Button(ctx, "START", btn_w, btn_h) then
          table.insert(track_set, {text = "New", pan = false})
          SavePreset(allPresetFiles[currentPresetIndex], track_set)
        end
        r.ImGui_PopStyleColor(ctx, 3)
      end
    end
  end

  local item_to_delete = nil
  for _, set in ipairs(track_set) do
    -- Основная кнопка: заменяет название трека
    local btn_color = color_1
    if type(set.color) == "number" then
      local r_val, g_val, b_val = r.ColorFromNative(set.color)
      local darken_factor = 0.6 -- Коэффициент затемнения для отображения на кнопке
      btn_color = r.ImGui_ColorConvertDouble4ToU32((r_val * darken_factor) / 255, (g_val * darken_factor) / 255, (b_val * darken_factor) / 255, 1.0)
    end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), btn_color)
    if r.ImGui_Button(ctx, set.text .. "###main_btn_" .. _, btnWidth, 0) then
      local track_count = r.CountSelectedTracks(0)
      for i = 0, track_count - 1 do
        local track = r.GetSelectedTrack(0, i)
        if track then
          r.GetSetMediaTrackInfo_String(track, "P_NAME", set.text, true)
          if type(set.color) == "number" then
            r.SetTrackColor(track, set.color)
          end
        end
      end
    end
    r.ImGui_PopStyleColor(ctx, 1)

    -- Удаление ячейки при наведении и нажатии Delete
    if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Delete()) then
      item_to_delete = _
    end

    -- Добавление новой строки при наведении и нажатии Insert
    if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Insert()) then
      table.insert(track_set, _ + 1, {text = "New", pan = false})
      SavePreset(allPresetFiles[currentPresetIndex], track_set)
    end

    -- Drag and Drop
    if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_None()) then
      r.ImGui_SetDragDropPayload(ctx, "TRACK_ROW", tostring(_))
      r.ImGui_Text(ctx, "Move " .. set.text)
      r.ImGui_EndDragDropSource(ctx)
    end

    if r.ImGui_BeginDragDropTarget(ctx) then
      local payload_retval, payload_data = r.ImGui_AcceptDragDropPayload(ctx, "TRACK_ROW")
      if payload_retval then
        local src_index = tonumber(payload_data)
        local dst_index = _
        if src_index ~= dst_index then
          local item = track_set[src_index]
          table.remove(track_set, src_index)
          table.insert(track_set, dst_index, item)
          SavePreset(allPresetFiles[currentPresetIndex], track_set)
        end
      end
      r.ImGui_EndDragDropTarget(ctx)
    end

    if r.ImGui_BeginPopupContextItem(ctx) then
      r.ImGui_Text(ctx, "Edit Button")
      local changed, new_text = r.ImGui_InputText(ctx, "##edit_name", set.text)
      if changed then set.text = new_text end
      if r.ImGui_IsItemDeactivatedAfterEdit(ctx) then
        SavePreset(allPresetFiles[currentPresetIndex], track_set)
      end

      r.ImGui_Separator(ctx)
      r.ImGui_Text(ctx, "Color Settings")
      local is_color_enabled = (type(set.color) == "number")
      local rv_col, new_enabled_col = r.ImGui_Checkbox(ctx, "Enable Color", is_color_enabled)
      if rv_col then
        if new_enabled_col then
          set.color = 0 -- Default Black
        else
          set.color = false
        end
        SavePreset(allPresetFiles[currentPresetIndex], track_set)
      end

      if type(set.color) == "number" then
        r.ImGui_SameLine(ctx)
        local r_val, g_val, b_val = r.ColorFromNative(set.color)
        local col_rgba = r.ImGui_ColorConvertDouble4ToU32(r_val / 255, g_val / 255, b_val / 255, 1.0)
        local flags = r.ImGui_ColorEditFlags_NoInputs()
        local changed, new_col = r.ImGui_ColorEdit4(ctx, "##color_" .. _, col_rgba, flags)
        if changed then
          local r_new, g_new, b_new = r.ImGui_ColorConvertU32ToDouble4(new_col)
          set.color = r.ColorToNative(math.floor(r_new * 255), math.floor(g_new * 255), math.floor(b_new * 255))
          SavePreset(allPresetFiles[currentPresetIndex], track_set)
        end
        if r.ImGui_IsItemClicked(ctx, 1) then
          local track = r.GetSelectedTrack(0, 0)
          if track then
            local track_color = r.GetTrackColor(track)
            set.color = track_color
            SavePreset(allPresetFiles[currentPresetIndex], track_set)
          end
        end
      end

      r.ImGui_Separator(ctx)

          if r.ImGui_Button(ctx, "Add Suffix") then
            for k = 1, 5 do
              if not set["text_add_" .. k] or set["text_add_" .. k] == "" then
                set["text_add_" .. k] = "New"
                SavePreset(allPresetFiles[currentPresetIndex], track_set)
                break
              end
            end
            r.ImGui_CloseCurrentPopup(ctx)
          end

      if r.ImGui_Button(ctx, "Add Row") then
        table.insert(track_set, _ + 1, {text = "New", pan = false})
        SavePreset(allPresetFiles[currentPresetIndex], track_set)
        r.ImGui_CloseCurrentPopup(ctx)
      end

      if r.ImGui_Button(ctx, "Delete Row") then
        table.remove(track_set, _)
        SavePreset(allPresetFiles[currentPresetIndex], track_set)
        r.ImGui_CloseCurrentPopup(ctx)
      end

      if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter()) then
        r.ImGui_CloseCurrentPopup(ctx)
      end
      r.ImGui_EndPopup(ctx)
    end

    -- Кнопки добавления: дописывают к текущему имени
    for i = 1, 5 do
      local addText = set["text_add_" .. i]
      if addText and addText ~= "" then
        r.ImGui_SameLine(ctx)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_2)

        local button_clicked_left = r.ImGui_Button(ctx, addText .. "###add_btn_" .. _ .. "_" .. i, btnWidth, 0)
        local button_clicked_middle = r.ImGui_IsItemClicked(ctx, 2)

        if button_clicked_left or button_clicked_middle then
          local track_count = r.CountSelectedTracks(0)
          for j = 0, track_count - 1 do
            local track = r.GetSelectedTrack(0, j)
            if track then
              local _, currentName = r.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
              local newName
              if button_clicked_middle then
                newName = addText
              else
                newName = currentName .. " " .. addText
              end
              r.GetSetMediaTrackInfo_String(track, "P_NAME", newName, true)
            end
          end
        end
        r.ImGui_PopStyleColor(ctx, 1)

        -- Удаление суффикса при наведении и нажатии Delete
        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Delete()) then
          set["text_add_" .. i] = ""
          SavePreset(allPresetFiles[currentPresetIndex], track_set)
        end

        -- Добавление нового суффикса при наведении и нажатии Insert
        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Insert()) then
          for k = 1, 5 do
            if not set["text_add_" .. k] or set["text_add_" .. k] == "" then
              set["text_add_" .. k] = "New"
              SavePreset(allPresetFiles[currentPresetIndex], track_set)
              break
            end
          end
        end

        -- Drag and Drop Source
        if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_None()) then
          r.ImGui_SetDragDropPayload(ctx, "SUFFIX_BTN", _ .. "," .. i)
          r.ImGui_Text(ctx, "Move " .. addText)
          r.ImGui_EndDragDropSource(ctx)
        end

        -- Drag and Drop Target
        if r.ImGui_BeginDragDropTarget(ctx) then
          local payload_retval, payload_data = r.ImGui_AcceptDragDropPayload(ctx, "SUFFIX_BTN")
          if payload_retval then
            local src_row_str, src_col_str = payload_data:match("^(%d+),(%d+)$")
            local src_row, src_col = tonumber(src_row_str), tonumber(src_col_str)
            local dst_row, dst_col = _, i

            if src_row ~= dst_row or src_col ~= dst_col then
              local temp = track_set[src_row]["text_add_" .. src_col]
              track_set[src_row]["text_add_" .. src_col] = track_set[dst_row]["text_add_" .. dst_col]
              track_set[dst_row]["text_add_" .. dst_col] = temp
              SavePreset(allPresetFiles[currentPresetIndex], track_set)
            end
          end
          r.ImGui_EndDragDropTarget(ctx)
        end

        if r.ImGui_BeginPopupContextItem(ctx) then
          r.ImGui_Text(ctx, "Edit Suffix")
          local changed, new_text = r.ImGui_InputText(ctx, "##edit_suffix", set["text_add_" .. i])
          if changed then set["text_add_" .. i] = new_text end
          if r.ImGui_IsItemDeactivatedAfterEdit(ctx) then
            SavePreset(allPresetFiles[currentPresetIndex], track_set)
          end

          if r.ImGui_Button(ctx, "Delete Suffix") then
            set["text_add_" .. i] = ""
            SavePreset(allPresetFiles[currentPresetIndex], track_set)
            r.ImGui_CloseCurrentPopup(ctx)
          end
          if r.ImGui_Button(ctx, "Add Suffix") then
        for k = 1, 5 do
          if not set["text_add_" .. k] or set["text_add_" .. k] == "" then
            set["text_add_" .. k] = "New"
            SavePreset(allPresetFiles[currentPresetIndex], track_set)
            break
          end
        end
        r.ImGui_CloseCurrentPopup(ctx)
      end

      if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter()) then
        r.ImGui_CloseCurrentPopup(ctx)
      end
          r.ImGui_EndPopup(ctx)
        end
      end
    end

  end

  if item_to_delete then
    table.remove(track_set, item_to_delete)
    SavePreset(allPresetFiles[currentPresetIndex], track_set)
  end

  r.ImGui_PopStyleVar(ctx)

end

-- Переменные для хранения позиции и размера основного окна
local mainWinX, mainWinY, mainWinW, mainWinH = 0, 0, 0, 0

local pan_edit_idx = nil
local pan_edit_focused = false

local function panWindow()
  if not showPanWindow then return end

  -- Магнитное прилипание: позиционируем окно рядом с основным
  local snapMargin = 4
  local posX, posY
  if panWindowSide == "right" then
    posX = mainWinX + mainWinW + snapMargin
  else
    -- Ширина pan-окна ~92px, вычтем при позиционировании слева
    posX = mainWinX - 92 - snapMargin
  end
  posY = mainWinY
  r.ImGui_SetNextWindowPos(ctx, posX, posY, r.ImGui_Cond_Always())
  r.ImGui_SetNextWindowSizeConstraints(ctx, 0, 0, 999999, 999999)

  local panTitle = "Pan##panwin"
  local pvis, popen = r.ImGui_Begin(ctx, panTitle, true,
    r.ImGui_WindowFlags_AlwaysAutoResize() | r.ImGui_WindowFlags_NoTitleBar())
  if pvis then
    local pan_to_delete = nil
    for idx, val in ipairs(pan_set) do
      if pan_edit_idx == idx then
        -- Режим редактирования: InputInt на месте кнопок
        r.ImGui_SetNextItemWidth(ctx, 76)
        if not pan_edit_focused then
          r.ImGui_SetKeyboardFocusHere(ctx)
          pan_edit_focused = true
        end
        local changed, new_val = r.ImGui_InputInt(ctx, "##pan_edit_" .. idx, val, 0, 0)
        if changed then
          pan_set[idx] = new_val
        end
        -- Выход из режима редактирования: Enter, клик мимо или Escape
        if r.ImGui_IsItemDeactivatedAfterEdit(ctx) then
          SavePreset(allPresetFiles[currentPresetIndex], track_set)
        end
        if r.ImGui_IsItemDeactivated(ctx) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
          pan_edit_idx = nil
          pan_edit_focused = false
        end
      else
        local panValue = val / 100.0
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_3)
        if r.ImGui_Button(ctx, " -" .. val .. "##panW_L_" .. idx, 34, 0) then
          local tc = r.CountSelectedTracks(0)
          for i = 0, tc - 1 do
            local track = r.GetSelectedTrack(0, i)
            if track then r.SetMediaTrackInfo_Value(track, "D_PAN", -panValue) end
          end
        end
        r.ImGui_PopStyleColor(ctx, 1)

        -- Удаление по Delete при наведении (левая кнопка)
        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Delete()) then
          pan_to_delete = idx
        end
        -- Вставка по Insert при наведении (левая кнопка)
        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Insert()) then
          table.insert(pan_set, idx + 1, 0)
          SavePreset(allPresetFiles[currentPresetIndex], track_set)
        end
        -- ПКМ на левой кнопке — переход в режим редактирования
        if r.ImGui_IsItemClicked(ctx, r.ImGui_MouseButton_Right()) then
          pan_edit_idx = idx
          pan_edit_focused = false
        end

        r.ImGui_SameLine(ctx)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_4)
        if r.ImGui_Button(ctx, " " .. val .. "##panW_R_" .. idx, 34, 0) then
          local tc = r.CountSelectedTracks(0)
          for i = 0, tc - 1 do
            local track = r.GetSelectedTrack(0, i)
            if track then r.SetMediaTrackInfo_Value(track, "D_PAN", panValue) end
          end
        end
        r.ImGui_PopStyleColor(ctx, 1)

        -- Удаление по Delete при наведении (правая кнопка)
        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Delete()) then
          pan_to_delete = idx
        end
        -- Вставка по Insert при наведении (правая кнопка)
        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Insert()) then
          table.insert(pan_set, idx + 1, 0)
          SavePreset(allPresetFiles[currentPresetIndex], track_set)
        end
        -- ПКМ на правой кнопке — переход в режим редактирования
        if r.ImGui_IsItemClicked(ctx, r.ImGui_MouseButton_Right()) then
          pan_edit_idx = idx
          pan_edit_focused = false
        end
      end
    end

    if pan_to_delete then
      table.remove(pan_set, pan_to_delete)
      SavePreset(allPresetFiles[currentPresetIndex], track_set)
    end

    if #pan_set == 0 then
      if r.ImGui_Button(ctx, "+ Add##pan_add_first", 76, 0) then
        table.insert(pan_set, 0)
        SavePreset(allPresetFiles[currentPresetIndex], track_set)
      end
    end

    r.ImGui_End(ctx)
  end
  if not popen then
    showPanWindow = false
    reaper.SetExtState("trs_TrackGUITools", "showPanWindow", "0", true)
  end
end

local function loop()
  reaper.ImGui_PushFont(ctx, font, size)

  reaper.ImGui_SetNextWindowSizeConstraints(ctx, 100, 100, 999999, 999999)
  local visible, open = reaper.ImGui_Begin(ctx, windowTitle, true, reaper.ImGui_WindowFlags_AlwaysAutoResize())
  if visible then
    -- Запоминаем позицию и размер основного окна для магнита
    mainWinX, mainWinY = r.ImGui_GetWindowPos(ctx)
    mainWinW, mainWinH = r.ImGui_GetWindowSize(ctx)
    myWindow()
    reaper.ImGui_End(ctx)
  end

  -- Рисуем pan-окно поверх основного
  panWindow()

  reaper.ImGui_PopFont(ctx)

    -- Обработка нажатия клавиши 'w' для перехода к следующему треку
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_W()) then
      reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_SELPREVTRACK"), 0)
    end

    -- Обработка нажатия клавиши 's' для перехода к предыдущему треку
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_S()) then
      reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_SELNEXTTRACK"), 0)
    end

  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
    open = false
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)
