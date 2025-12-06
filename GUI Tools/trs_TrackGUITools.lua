-- @description GUI Инструменты для Треков с Пресетами и Навигацией
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about Скрипт предоставляет удобный графический интерфейс для быстрого переименования треков, добавления префиксов/суффиксов, настройки панорамы, а также навигации и загрузки пресетов в REAPER.
-- @changelog + Code optimizations

local r = reaper
console = false

function msg(value) if console then r.ShowConsoleMsg(tostring(value) .. "\n") end end

title = 'RENAME TRACKS TOOLS'
ver = '2.0'
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

function SavePreset(saveFile, track_set)
  local file = io.open(saveFile, "w")
  if file then
    for _, set in ipairs(track_set) do
      local line = set.text or ""
      for i = 1, 5 do
        line = line .. "," .. (set["text_add_" .. i] or "")
      end
      local pan_value = ""
      if type(set.pan) == "number" then
        pan_value = tostring(set.pan)
      elseif set.pan == false then
        pan_value = "false"
      end
      line = line .. "," .. pan_value
      file:write(line .. "\n")
    end
    file:close()
    msg("Preset saved to: " .. saveFile)
  else
    msg("Error: Could not open file for writing: " .. saveFile)
  end
end

function LoadPreset(saveFile)
  local loaded_track_set = {}
  local file = io.open(saveFile, "r")
  if file then
    for line in file:lines() do
      local parts = {}
      for part in line:gmatch("([^,]*),?") do
        table.insert(parts, part)
      end

      local set = {}
      set.text = parts[1] or ""
      for i = 1, 5 do
        set["text_add_" .. i] = parts[i + 1] or ""
      end

      local pan_str = parts[7]
      if pan_str == "false" then
        set.pan = false
      else
        set.pan = tonumber(pan_str) or 'false' -- Default to 0 if not a number
      end
      table.insert(loaded_track_set, set)
    end
    file:close()
    msg("Preset loaded from: " .. saveFile)
    return loaded_track_set
  else
    msg("Error: Could not open file for reading: " .. saveFile)
    return nil
  end
end

local allPresetFiles = GetAllPresetFiles(presetPath)
local currentPresetIndex = 1

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

local color_1 = 0x3B4068FF --F0
local color_2 = 0x2C3A47F0 --F0
local color_3 = 0x202020FF --F0
local color_4 = 0x102010FF --F0
local color_yellow = 0xFFFF00FF -- Желтый цвет для имени пресета


local ctx = r.ImGui_CreateContext(windowTitle)
local size = 13
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
    -- Логика для загрузки пресетов
    local success, fn = reaper.GetUserFileNameForRead(
      presetPath,         -- Начальная директория
      "Загрузить пресет", -- Заголовок диалога
      "txt"               -- Расширение файла
    )
    if success and fn then
      local foundIndex = -1
      for i, path in ipairs(allPresetFiles) do
        if path == fn then
          foundIndex = i
          break
        end
      end
      if foundIndex ~= -1 then
        LoadPresetByIndex(foundIndex)
      else
        -- Если выбранный файл не в allPresetFiles, загружаем его напрямую и добавляем в список
        local loaded_set = LoadPreset(fn)
        if loaded_set then
          track_set = loaded_set
          reaper.SetExtState("trs_TrackGUITools", lastPresetExtStateKey, fn, true)
          table.insert(allPresetFiles, fn) -- Добавляем новый пресет в список
          currentPresetIndex = #allPresetFiles -- Устанавливаем текущий индекс на новый пресет
        end
      end
    end
  end
  r.ImGui_PopStyleColor(ctx, 1)
  r.ImGui_SameLine(ctx)

  -- Кнопка для предыдущего пресета
  local navBtnWidth = 30 -- Ширина кнопок навигации
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_4)
  if r.ImGui_Button(ctx, "<", navBtnWidth, 0) then
    GoToPreviousPreset()
  end
  r.ImGui_PopStyleColor(ctx, 1)
  r.ImGui_SameLine(ctx)

  -- Кнопка для следующего пресета
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_4)
  if r.ImGui_Button(ctx, ">", navBtnWidth, 0) then
    GoToNextPreset()
  end
  r.ImGui_PopStyleColor(ctx, 1)
  r.ImGui_SameLine(ctx)

  -- Отображение имени текущего пресета
  if #allPresetFiles > 0 then
    local currentPresetName = allPresetFiles[currentPresetIndex]:match("[^/\\]+%.txt$")
    if currentPresetName then
      currentPresetName = currentPresetName:gsub("%.txt$", "") -- Удаляем расширение .txt
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), color_yellow)
      r.ImGui_Text(ctx, "  " .. currentPresetName)
      r.ImGui_PopStyleColor(ctx, 1)
    end
  end
  r.ImGui_SameLine(ctx)

  r.ImGui_NewLine(ctx) -- Переход на новую строку после кнопок PRESETS и навигации

  for _, set in ipairs(track_set) do
    -- Основная кнопка: заменяет название трека
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_1) -- Серый цвет
    if r.ImGui_Button(ctx, set.text .. "##main_btn_" .. _, btnWidth, 0) then
      local track = r.GetSelectedTrack(0, 0)
      if track then
        r.GetSetMediaTrackInfo_String(track, "P_NAME", set.text, true)
      end
    end
    r.ImGui_PopStyleColor(ctx, 1)
    r.ImGui_SameLine(ctx)

    -- Кнопки добавления: дописывают к текущему имени
    for i = 1, 5 do
      local addText = set["text_add_" .. i]
      if addText and addText ~= "" then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_2)

        local button_clicked_left = r.ImGui_Button(ctx, addText .. "##add_btn_" .. _ .. "_" .. i, btnWidth, 0)
        local button_clicked_middle = r.ImGui_IsItemClicked(ctx, 2)

        if button_clicked_left or button_clicked_middle then
          local track = r.GetSelectedTrack(0, 0)
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
        r.ImGui_PopStyleColor(ctx, 1)
        r.ImGui_SameLine(ctx)
      end
    end

    -- Кнопки панорамирования
    if type(set.pan) == "number" then
      local panValue = set.pan / 100.0 -- Преобразуем значение pan в диапазон от 0.0 до 1.0
      -- Кнопка для панорамирования влево
       r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_3)
      if r.ImGui_Button(ctx, " -" .. set.pan .. "##pan_L_" .. _, btnWidth / 2.1, 0) then
        local track = r.GetSelectedTrack(0, 0)
        if track then
          r.SetMediaTrackInfo_Value(track, "D_PAN", -panValue)
        end
      end
      r.ImGui_PopStyleColor(ctx, 1)
      r.ImGui_SameLine(ctx)

      -- Кнопка для панорамирования вправо
       r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color_4)
      if r.ImGui_Button(ctx, " " .. set.pan .. "##pan_R_" .. _, btnWidth / 2.1, 0) then
        local track = r.GetSelectedTrack(0, 0)
        if track then
          r.SetMediaTrackInfo_Value(track, "D_PAN", panValue)
        end
      end
      r.ImGui_PopStyleColor(ctx, 1)
      r.ImGui_SameLine(ctx)
    elseif set.pan == false then
      -- Кнопка для центрирования панорамы
      -- if r.ImGui_Button(ctx, "Center", btnWidth, 0) then
      --   local track = r.GetSelectedTrack(0, 0)
      --   if track then
      --     r.SetMediaTrackInfo_Value(track, "D_PAN", 0.0)
      --   end
      -- end
      r.ImGui_SameLine(ctx)
    end
    r.ImGui_NewLine(ctx)
  end

  r.ImGui_PopStyleVar(ctx)

end

local function loop()
  reaper.ImGui_PushFont(ctx, font, size)
  local row_height = 28 -- Приблизительная высота одной строки элементов (кнопка + отступ)
  local presets_button_height = 24 -- Высота кнопки PRESETS
  local top_padding = 4 -- Дополнительный отступ сверху
  local bottom_padding = 2 -- Дополнительный отступ снизу

  local num_tracks = #track_set
  local calculated_height = presets_button_height + top_padding + (num_tracks * row_height) + bottom_padding
  local min_height = 100 -- Минимальная высота окна

  if calculated_height < min_height then
    calculated_height = min_height
  end

  reaper.ImGui_SetNextWindowSize(ctx, 515, calculated_height, reaper.ImGui_Cond_Always())
  local visible, open = reaper.ImGui_Begin(ctx, windowTitle, true)
  if visible then
    myWindow()
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopFont(ctx)


    -- Обработка нажатия клавиши 'w' для перехода к следующему треку
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_W()) then
      reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_SELPREVTRACK"), 0)
    end

    -- Обработка нажатия клавиши 's' для перехода к предыдущему треку
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_S()) then
      reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_SELNEXTTRACK"), 0)
    end

  -- if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftAlt()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightAlt()) then
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftAlt()) then
    open = false
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)
