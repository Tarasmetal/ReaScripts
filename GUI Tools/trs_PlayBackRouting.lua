-- @description trs_PlayBackRouting.lua
-- @author Taras Umanskiy
-- @version 1.0
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://vk.com/Tarasmetal
-- @about Скрипт для автоматической маршрутизации треков по именам в REAPER. Отключает отправку на мастер и назначает аппаратные выходы для треков PB, GTR, GTR G, GTR B, GTR AC, BASS, CLICK.
-- @changelog
--  + Code Fixies

local r = reaper
console = false

function msg(value) if console then r.ShowConsoleMsg(tostring(value) .. "\n") end end

local title = 'PlayBackRouting'
local ver = '1.0'
local author = 'Taras Umanskiy'
local about = title .. ' ' .. ver .. ' by ' .. author
local ListDir = {}
ListDir.scriptDir, ListDir.scriptFileName = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")
local scriptDir = ListDir.scriptDir
local scriptFileName = ListDir.scriptFileName
local windowTitle = about
local presetsDir = scriptDir .. "/RoutingPresets"
reaper.RecursiveCreateDirectory(presetsDir, 0)

local ctx = r.ImGui_CreateContext(windowTitle)
local size =  r.GetAppVersion():match('Win64') and 12 or 14
local font = reaper.ImGui_CreateFont('sans-serif', size)
reaper.ImGui_Attach(ctx, font)

local MST = 0  -- Флаг управления мастер-выходами: 1 = включить, 0 = отключить
local master_track_enabled = false -- Состояние чекбокса для мастер-трека
-- Создаем массив с именами треков и выходами для обработки
tr_settings = {
    {name = "PB", output = 1, type = "s"},
    {name = "GTR", output = 3, type = "m"},
    {name = "GTR G", output = 3, type = "s"},
    {name = "GTR B", output = 4, type = "s"},
    {name = "GTR AC", output = 5, type = "s"},
    {name = "BASS", output = 6, type = "m"},
    {name = "CLICK", output = 7, type = "m"},
}

function split(s, delimiter)
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function LoadSettingsFromFile(filepath)
    local file = io.open(filepath, "r")
    if file then
        local new_settings = {}
        for line in file:lines() do
            local parts = split(line, ",")
            if #parts == 3 then
                table.insert(new_settings, {
                    name = parts[1],
                    output = tonumber(parts[2]),
                    type = parts[3]
                })
            end
        end
        file:close()
        if #new_settings > 0 then
            tr_settings = new_settings
            reaper.SetExtState("trs_PlayBackRouting", "LastPresetPath", filepath, true)
            return true
        end
    end
    return false
end

function SavePreset(name)
    local filepath = presetsDir .. "/" .. name .. ".txt"
    local file = io.open(filepath, "w")
    if file then
        for _, settings in ipairs(tr_settings) do
            file:write(settings.name .. "," .. settings.output .. "," .. settings.type .. "\n")
        end
        file:close()
        msg("Preset saved: " .. filepath)
        reaper.SetExtState("trs_PlayBackRouting", "LastPresetPath", filepath, true)
    else
        msg("Error saving preset: " .. filepath)
    end
end

function LoadPreset()
    local retval, filepath = reaper.GetUserFileNameForRead(presetsDir, "Load Preset", "txt")
    if retval then
        if LoadSettingsFromFile(filepath) then
             msg("Preset loaded: " .. filepath)
        else
             msg("Error opening or parsing file: " .. filepath)
        end
    end
end

-- Пытаемся загрузить последний пресет при старте
local last_preset = reaper.GetExtState("trs_PlayBackRouting", "LastPresetPath")
if last_preset ~= "" then
    if LoadSettingsFromFile(last_preset) then
        msg("Auto-loaded last preset: " .. last_preset)
    end
end

function processTracks()
    reaper.Undo_BeginBlock()
    -- Создаем карту настроек для быстрого поиска по имени
    local settings_map = {}
    for _, item in ipairs(tr_settings) do
        settings_map[item.name] = {item.output, item.type}
    end

    -- Получаем количество треков в проекте
    local track_count = reaper.CountTracks(0)

    -- Перебираем все треки в проекте
    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track)

        -- Если имя трека есть в массиве настроек
        if settings_map[track_name] then
            -- Отключаем отправку на мастер
            reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)

            -- Управление аппаратными выходами мастер-трека в зависимости от чекбокса
            local master = reaper.GetMasterTrack(0)
            local master_hw_send_count = reaper.GetTrackNumSends(master, 1)
            local mute_value = master_track_enabled and 0 or 1 -- 0 = unmute, 1 = mute
            for j = 0, master_hw_send_count - 1 do
                reaper.BR_GetSetTrackSendInfo(master, 1, j, "B_MUTE", 1, mute_value)
            end
            -----------------------------------------------
            -- Удаляем все hardware output
            local hw_send_count = reaper.GetTrackNumSends(track, 1)
            for j = hw_send_count - 1, 0, -1 do
                reaper.RemoveTrackSend(track, 1, j)
            end

            -- Добавляем hardware output
            local send_output = settings_map[track_name][1]
            local send_type = settings_map[track_name][2]

            reaper.CreateTrackSend(track, nil)
            local new_send_idx = reaper.GetTrackNumSends(track, -1)

            if send_type == "s" then
                reaper.BR_GetSetTrackSendInfo(track, 0, new_send_idx, "I_SRCCHAN", 1, 0)
                reaper.BR_GetSetTrackSendInfo(track, 1, new_send_idx, "I_DSTCHAN", 1, send_output - 1)
            elseif send_type == "m" then
                reaper.BR_GetSetTrackSendInfo(track, 0, new_send_idx, "I_SRCCHAN", 1, 1024) -- Source channel 1 (mono)
                reaper.BR_GetSetTrackSendInfo(track, 1, new_send_idx, "I_DSTCHAN", 1, (send_output - 1) | 1024) -- Destination channel (mono)
            end
            reaper.BR_GetSetTrackSendInfo(track, 0, new_send_idx, "I_MIDI_DSTCHAN", 1, -1)
        end
    end
    reaper.Undo_EndBlock('• ' .. title .. ' •', -1)
end

local show_save_dialog = false
local preset_name_input = "MyPreset"

local function myWindow()
  local rv

  if reaper.ImGui_Button(ctx, 'Загрузить пресет') then
      LoadPreset()
  end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, 'Сохранить пресет') then
      show_save_dialog = true
      reaper.ImGui_OpenPopup(ctx, 'Save Preset Dialog')
  end

  if reaper.ImGui_BeginPopupModal(ctx, 'Save Preset Dialog', true, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
      reaper.ImGui_Text(ctx, 'Введите имя пресета:')
      local changed, text = reaper.ImGui_InputText(ctx, '##presetname', preset_name_input)
      if changed then preset_name_input = text end

      if reaper.ImGui_Button(ctx, 'Сохранить', 120, 0) then
          SavePreset(preset_name_input)
          show_save_dialog = false
          reaper.ImGui_CloseCurrentPopup(ctx)
      end
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, 'Отмена', 120, 0) then
          show_save_dialog = false
          reaper.ImGui_CloseCurrentPopup(ctx)
      end
      reaper.ImGui_EndPopup(ctx)
  end

  reaper.ImGui_Separator(ctx)
  reaper.ImGui_TextColored(ctx, 0xFFFFFFFF, 'Настройки маршрутизации:')
  reaper.ImGui_Separator(ctx)

  local changed_master, current_master = reaper.ImGui_Checkbox(ctx, 'Мастер-трек', master_track_enabled)
  if changed_master then
    master_track_enabled = current_master
  end

  reaper.ImGui_Separator(ctx)

  local index_to_remove = nil

  -- Обработка нажатия Insert (добавление трека)
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Insert()) then
      table.insert(tr_settings, {name = "New Track", output = 1, type = "s"})
  end

  for i, settings in ipairs(tr_settings) do
    local display_output = tostring(settings.output)
    if settings.type == 's' then
      display_output = settings.output .. '-' .. (settings.output + 1)
    end
    local TEXT_WIDTH = 200
    local SLIDER_WIDTH = 100
    local COMBO_WIDTH = 80
    local PADDING = 10

    local start_x_of_line = reaper.ImGui_GetCursorPosX(ctx)

    reaper.ImGui_SetNextItemWidth(ctx, TEXT_WIDTH - 40) -- Оставляем место для диапазона каналов
    local changed_name, new_track_name = reaper.ImGui_InputText(ctx, '##track_name_' .. i, settings.name, 256) -- 256 - размер буфера

    -- Проверяем фокус и нажатие Delete для удаления
    if reaper.ImGui_IsItemFocused(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Delete()) then
        index_to_remove = i
    end

    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, '(' .. display_output .. ')') -- Отображаем диапазон каналов
    if changed_name then
        settings.name = new_track_name
    end

    local slider_start_x = start_x_of_line + TEXT_WIDTH + PADDING
    reaper.ImGui_SameLine(ctx, slider_start_x)
    reaper.ImGui_SetNextItemWidth(ctx, SLIDER_WIDTH)
    local changed_output, new_output_value = reaper.ImGui_InputInt(ctx, '##output_' .. i, settings.output)
    if changed_output then
      settings.output = new_output_value
    end

    local combo_start_x = slider_start_x + SLIDER_WIDTH + PADDING
    reaper.ImGui_SameLine(ctx, combo_start_x)
    reaper.ImGui_SetNextItemWidth(ctx, COMBO_WIDTH)
    local changed_type, current_type_idx = reaper.ImGui_Combo(ctx, '##type_' .. i, (settings.type == 's' and 0 or 1), 'стерео\0моно\0')
    if changed_type then
      if current_type_idx == 0 then
        settings.type = 's'
      else
        settings.type = 'm'
      end
    end
  end

  if index_to_remove then
      table.remove(tr_settings, index_to_remove)
  end

  reaper.ImGui_Separator(ctx)
  if reaper.ImGui_Button(ctx, 'Применить маршрутизацию') then
    processTracks()
  end

end

local function loop()
  reaper.ImGui_PushFont(ctx, font, size)
  reaper.ImGui_SetNextWindowSize(ctx, 400, 300, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, windowTitle, true)
  if visible then
    myWindow()
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopFont(ctx)

  if open then
    reaper.defer(loop)
  end
end
reaper.defer(loop)
