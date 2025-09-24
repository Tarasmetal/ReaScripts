-- @description Track Volume Pan & Automation Save/Restore (ReaImGui)
-- @author Taras Umanskiy
-- @version 1.4
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://vk.com/Tarasmetal
-- @about Скрипт для REAPER, который сохраняет и восстанавливает значения громкости, панорамы и FX треков проекта.
-- Имеет GUI (ReaImGui) с 4 слотами снэпшотов (A/B/C/D), гибкой областью действия (All / Selected tracks, Master),
-- надежной привязкой по GUID треков, отдельной кнопкой сброса (Reset Only) и индикацией состояния.
-- @changelog
--  + Добавлен чекбокс "Reset after Save" (включен по умолчанию; если снять галочку, настройки после сохранения не сбрасываются).
--  + Добавлена привязка к трекам по уникальному GUID вместо порядкового индекса (с обратной совместимостью).
--  + Добавлена поддержка 4 независимых слотов снэпшотов (A, B, C, D) для быстрого A/B сравнения миксов.
--  + Хранение снэпшотов прямо внутри проекта (ProjExtState) с резервной копией в текстовые файлы.
--  + Добавлен выбор области действия (Scope): Все треки / Только выделенные треки.
--  + Добавлены опции включения Master Track и исключения треков-папок (Ignore Folders).
--  + Добавлена отдельная кнопка "Reset" для мгновенного сброса без перезаписи сохраненных снэпшотов.
--  + Добавлен статус-индикатор активного слота (время сохранения и количество треков).
--  + Добавлена кнопка быстрого отката (Undo).
--  + Нативный байпас FX без изменения пользовательского выделения треков и жесткой привязки к SWS.

local SCRIPT_TITLE = "Track Snapshots & Reset by Taras Umanskiy v1.4"
local EXT_SECTION = "TRS_TRACK_MIX_SNAP"

-- Проверка наличия ReaImGui
if not reaper.APIExists("ImGui_CreateContext") then
  reaper.ShowMessageBox("Требуется расширение ReaImGui.\nПожалуйста, установите его через ReaPack.", SCRIPT_TITLE, 0)
  return
end

----------------------------------------------------------------
-- Глобальные настройки и флаги
----------------------------------------------------------------

flag_volume = 1            -- Сохранять/восстанавливать громкость (1/0)
my_vol = 0.0               -- Уровень громкости в dB для сброса
flag_pan = 1               -- Сохранять/восстанавливать панораму (1/0)
flag_fx = 1                -- Сохранять/восстанавливать состояние FX (1/0)
flag_global_automation = 0 -- Глобальный байпас автоматизации (1/0)

scope_selected = 0         -- Область действия: 0 - Все треки, 1 - Только выделенные
flag_include_master = 0    -- Включать мастер-трек в сброс/снапшот (1/0)
flag_ignore_folders = 0    -- Игнорировать треки-папки при сбросе (1/0)
flag_reset_after_save = 1  -- Сбрасывать треки сразу после нажатия Save (1/0, по умолчанию включено)

current_slot = 1           -- Текущий активный слот (1..4)

-- Информация о слотах (хранится в памяти и ProjExtState)
local slots_info = {
  [1] = { name = "Slot A", time = nil, track_count = 0, has_data = false },
  [2] = { name = "Slot B", time = nil, track_count = 0, has_data = false },
  [3] = { name = "Slot C", time = nil, track_count = 0, has_data = false },
  [4] = { name = "Slot D", time = nil, track_count = 0, has_data = false },
}

local status_message = ""
local status_time = 0

local function set_status(msg)
  status_message = msg
  status_time = reaper.time_precise()
end

----------------------------------------------------------------
-- Пути к файлам (Резервное сохранение на диск)
----------------------------------------------------------------

local function get_project_dir()
  local _, proj_path = reaper.EnumProjects(-1, "")
  if not proj_path or proj_path == "" then
    return nil
  end
  return proj_path:match("^(.*[\\/])") or nil
end

local function get_state_file_path(slot_idx)
  local proj_dir = get_project_dir()
  if not proj_dir then return nil end
  local sep = proj_dir:match("[/\\]$") and "" or package.config:sub(1,1)
  if slot_idx == 1 then
    return proj_dir .. sep .. "TrackMixSnap.txt"
  else
    return proj_dir .. sep .. string.format("TrackMixSnap_Slot%d.txt", slot_idx)
  end
end

local function get_flags_file_path()
  local proj_dir = get_project_dir()
  if not proj_dir then return nil end
  local sep = proj_dir:match("[/\\]$") and "" or package.config:sub(1,1)
  return proj_dir .. sep .. "TrackMixFlags.txt"
end

----------------------------------------------------------------
-- Сохранение и загрузка настроек UI
----------------------------------------------------------------

local function save_flag_states()
  -- Сохраняем в ExtState REAPER (работает всегда)
  local flags_str = string.format(
    "%d|%.2f|%d|%d|%d|%d|%d|%d|%d|%d",
    flag_volume, my_vol, flag_pan, flag_fx, flag_global_automation,
    scope_selected, flag_include_master, flag_ignore_folders, flag_reset_after_save, current_slot
  )
  reaper.SetExtState(EXT_SECTION, "config_flags", flags_str, true)

  -- Дублируем в файл проекта, если он сохранен
  local path = get_flags_file_path()
  if not path then return end
  local file = io.open(path, "w")
  if not file then return end

  file:write(string.format("flag_volume=%d\n", flag_volume))
  file:write(string.format("my_vol=%.2f\n", my_vol))
  file:write(string.format("flag_pan=%d\n", flag_pan))
  file:write(string.format("flag_fx=%d\n", flag_fx))
  file:write(string.format("flag_global_automation=%d\n", flag_global_automation))
  file:write(string.format("scope_selected=%d\n", scope_selected))
  file:write(string.format("flag_include_master=%d\n", flag_include_master))
  file:write(string.format("flag_ignore_folders=%d\n", flag_ignore_folders))
  file:write(string.format("flag_reset_after_save=%d\n", flag_reset_after_save))
  file:write(string.format("current_slot=%d\n", current_slot))
  file:close()
end

local function load_flag_states()
  -- Сначала пробуем загрузить из ExtState
  if reaper.HasExtState(EXT_SECTION, "config_flags") then
    local str = reaper.GetExtState(EXT_SECTION, "config_flags")
    local f_vol, m_vol, f_pan, f_fx, f_auto, sc_sel, inc_m, ign_f, res_sav, c_slot =
      str:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
    if f_vol then
      flag_volume = tonumber(f_vol) or flag_volume
      my_vol = tonumber(m_vol) or my_vol
      flag_pan = tonumber(f_pan) or flag_pan
      flag_fx = tonumber(f_fx) or flag_fx
      flag_global_automation = tonumber(f_auto) or flag_global_automation
      scope_selected = tonumber(sc_sel) or scope_selected
      flag_include_master = tonumber(inc_m) or flag_include_master
      flag_ignore_folders = tonumber(ign_f) or flag_ignore_folders
      flag_reset_after_save = tonumber(res_sav) or flag_reset_after_save
      current_slot = tonumber(c_slot) or current_slot
    end
  end

  -- Затем проверяем файл проекта (имеет приоритет для конкретного проекта)
  local path = get_flags_file_path()
  if not path then return end
  local file = io.open(path, "r")
  if not file then return end

  for line in file:lines() do
    local var_name, value_str = line:match("^(.-)=(.-)$")
    if var_name and value_str then
      local value = tonumber(value_str)
      if value ~= nil then
        if var_name == "flag_reset_on_save" then
          flag_reset_after_save = value
        else
          _G[var_name] = value
        end
      end
    end
  end
  file:close()
end

----------------------------------------------------------------
-- Работа со слотами (ProjExtState + Файлы)
----------------------------------------------------------------

local function load_slots_metadata()
  for slot_idx = 1, 4 do
    local has_state, meta_str = reaper.GetProjExtState(0, EXT_SECTION, "slot_meta_" .. slot_idx)
    if has_state == 1 and meta_str and meta_str ~= "" then
      local time_s, count_s = meta_str:match("^(.-)|(%d+)$")
      slots_info[slot_idx].time = time_s or "Saved"
      slots_info[slot_idx].track_count = tonumber(count_s) or 0
      slots_info[slot_idx].has_data = true
    else
      -- Проверка наличия файла на диске
      local path = get_state_file_path(slot_idx)
      if path then
        local f = io.open(path, "r")
        if f then
          slots_info[slot_idx].time = "Saved (Disk)"
          slots_info[slot_idx].has_data = true
          f:close()
        end
      end
    end
  end
end

----------------------------------------------------------------
-- Получение целевых треков
----------------------------------------------------------------

local function get_target_tracks()
  local list = {}
  local proj = 0

  if flag_include_master == 1 then
    local master = reaper.GetMasterTrack(proj)
    if master then
      table.insert(list, master)
    end
  end

  local is_selected_mode = (scope_selected == 1)
  local count = is_selected_mode and reaper.CountSelectedTracks(proj) or reaper.CountTracks(proj)

  for i = 0, count - 1 do
    local tr = is_selected_mode and reaper.GetSelectedTrack(proj, i) or reaper.GetTrack(proj, i)
    if tr then
      local is_folder = (reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1)
      if not (flag_ignore_folders == 1 and is_folder) then
        table.insert(list, tr)
      end
    end
  end

  return list
end

-- Построение карты GUID -> Track для быстрого O(1) поиска
local function build_guid_map()
  local map = {}
  local proj = 0
  local master = reaper.GetMasterTrack(proj)
  if master then
    map[reaper.GetTrackGUID(master)] = master
  end
  local total = reaper.CountTracks(proj)
  for i = 0, total - 1 do
    local tr = reaper.GetTrack(proj, i)
    if tr then
      map[reaper.GetTrackGUID(tr)] = tr
    end
  end
  return map
end

----------------------------------------------------------------
-- Логика сброса (Reset)
----------------------------------------------------------------

local function apply_reset(tracks)
  if not tracks or #tracks == 0 then
    tracks = get_target_tracks()
  end
  if #tracks == 0 then
    set_status("Нет подходящих треков для сброса")
    return
  end

  reaper.Undo_BeginBlock()

  -- 1. Сброс громкости
  if flag_volume == 1 then
    local vol_linear = 10 ^ (my_vol / 20)
    for _, tr in ipairs(tracks) do
      reaper.SetMediaTrackInfo_Value(tr, "D_VOL", vol_linear)
    end
  end

  -- 2. Сброс панорамы в центр (0.0)
  if flag_pan == 1 then
    for _, tr in ipairs(tracks) do
      reaper.SetMediaTrackInfo_Value(tr, "D_PAN", 0.0)
    end
  end

  -- 3. Нативный байпас FX (отключаем все FX, кроме инструментов VSTi)
  if flag_fx == 1 then
    for _, tr in ipairs(tracks) do
      local fx_count = reaper.TrackFX_GetCount(tr)
      local vsti_idx = reaper.TrackFX_GetInstrument(tr)
      for fx = 0, fx_count - 1 do
        if fx ~= vsti_idx then
          reaper.TrackFX_SetEnabled(tr, fx, false)
        end
      end
    end

    -- Если есть SWS/NF экшены для мастера, отключаем мастер FX при необходимости
    if flag_include_master == 1 then
      local master = reaper.GetMasterTrack(0)
      local m_fx_count = reaper.TrackFX_GetCount(master)
      for fx = 0, m_fx_count - 1 do
        reaper.TrackFX_SetEnabled(master, fx, false)
      end
    end
  end

  -- 4. Глобальная автоматизация
  if flag_global_automation == 1 then
    reaper.Main_OnCommand(40885, 0) -- Global automation override: bypass all automation
  end

  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()

  reaper.Undo_EndBlock("Reset track vol/pan/fx", -1)
  set_status(string.format("Сброшено треков: %d", #tracks))
end

----------------------------------------------------------------
-- Сохранение состояния микса (Save)
----------------------------------------------------------------

local function save_mix()
  local tracks = get_target_tracks()
  if #tracks == 0 then
    reaper.ShowMessageBox("Не найдено треков для сохранения.\nПроверьте настройки области (Scope).", SCRIPT_TITLE, 0)
    return
  end

  local lines = {}
  local time_now = os.date("%H:%M:%S")

  for i, track in ipairs(tracks) do
    local guid = reaper.GetTrackGUID(track)
    local track_num = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))

    if flag_volume == 1 then
      local vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
      table.insert(lines, string.format("V|%s|%d|%0.17f", guid, track_num, vol))
    end

    if flag_pan == 1 then
      local pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
      table.insert(lines, string.format("P|%s|%d|%0.17f", guid, track_num, pan))
    end

    if flag_fx == 1 then
      local fx_count = reaper.TrackFX_GetCount(track)
      for fx = 0, fx_count - 1 do
        local enabled = reaper.TrackFX_GetEnabled(track, fx) and 1 or 0
        local offline = reaper.TrackFX_GetOffline(track, fx) and 1 or 0
        table.insert(lines, string.format("F|%s|%d|%d|%d|%d", guid, track_num, fx + 1, enabled, offline))
      end
    end
  end

  local serialized_data = table.concat(lines, "\n")

  -- 1. Сохранение в ProjExtState проекта
  reaper.SetProjExtState(0, EXT_SECTION, "slot_data_" .. current_slot, serialized_data)
  reaper.SetProjExtState(0, EXT_SECTION, "slot_meta_" .. current_slot, string.format("%s|%d", time_now, #tracks))

  -- 2. Резервное сохранение в текстовый файл (если проект сохранен на диске)
  local path = get_state_file_path(current_slot)
  if path then
    local file = io.open(path, "w")
    if file then
      file:write(serialized_data .. "\n")
      file:close()
    end
  end

  -- Обновляем метаданные в памяти
  slots_info[current_slot].time = time_now
  slots_info[current_slot].track_count = #tracks
  slots_info[current_slot].has_data = true

  set_status(string.format("Слот %s сохранен (%d треков в %s)", slots_info[current_slot].name, #tracks, time_now))

  -- Если включен сброс после сохранения
  if flag_reset_after_save == 1 then
    apply_reset(tracks)
  end
end

----------------------------------------------------------------
-- Восстановление состояния микса (Restore)
----------------------------------------------------------------

local function restore_mix()
  local data_str = nil

  -- 1. Проверяем ProjExtState
  local has_state, ext_data = reaper.GetProjExtState(0, EXT_SECTION, "slot_data_" .. current_slot)
  if has_state == 1 and ext_data and ext_data ~= "" then
    data_str = ext_data
  else
    -- 2. Читаем из файла на диске
    local path = get_state_file_path(current_slot)
    if path then
      local file = io.open(path, "r")
      if file then
        data_str = file:read("*a")
        file:close()
      end
    end
  end

  if not data_str or data_str == "" then
    reaper.ShowMessageBox(
      string.format("В %s нет сохраненных данных микса.\nСначала нажмите 'Save'.", slots_info[current_slot].name),
      SCRIPT_TITLE, 0
    )
    return
  end

  reaper.Undo_BeginBlock()

  local guid_map = build_guid_map()
  local proj = 0
  local restored_tracks_set = {}

  for line in data_str:gmatch("[^\r\n]+") do
    local kind = line:sub(1, 1)

    if kind == "V" and flag_volume == 1 then
      -- Поддержка формата с GUID: V|{GUID}|track_num|vol
      -- Обратная совместимость со старым форматом: V|track_num|vol
      local guid, num_str, vol_str = line:match("^V|(%b{})|([^|]+)|([^|]+)$")
      if not guid then
        num_str, vol_str = line:match("^V|([^|]+)|([^|]+)$")
      end

      local vol = tonumber(vol_str)
      if vol then
        local tr = guid and guid_map[guid]
        if not tr and num_str then
          local idx = tonumber(num_str)
          if idx then
            tr = (idx == 0 and reaper.GetMasterTrack(proj)) or reaper.GetTrack(proj, idx - 1)
          end
        end
        if tr then
          reaper.SetMediaTrackInfo_Value(tr, "D_VOL", vol)
          restored_tracks_set[tr] = true
        end
      end

    elseif kind == "P" and flag_pan == 1 then
      local guid, num_str, pan_str = line:match("^P|(%b{})|([^|]+)|([^|]+)$")
      if not guid then
        num_str, pan_str = line:match("^P|([^|]+)|([^|]+)$")
      end

      local pan = tonumber(pan_str)
      if pan then
        local tr = guid and guid_map[guid]
        if not tr and num_str then
          local idx = tonumber(num_str)
          if idx then
            tr = (idx == 0 and reaper.GetMasterTrack(proj)) or reaper.GetTrack(proj, idx - 1)
          end
        end
        if tr then
          reaper.SetMediaTrackInfo_Value(tr, "D_PAN", pan)
          restored_tracks_set[tr] = true
        end
      end

    elseif kind == "F" and flag_fx == 1 then
      local guid, num_str, fx_str, en_str, off_str = line:match("^F|(%b{})|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
      if not guid then
        num_str, fx_str, en_str, off_str = line:match("^F|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
      end

      local fx_idx  = tonumber(fx_str)
      local enabled = tonumber(en_str)
      local offline = tonumber(off_str)

      if fx_idx and enabled and offline then
        local tr = guid and guid_map[guid]
        if not tr and num_str then
          local idx = tonumber(num_str)
          if idx then
            tr = (idx == 0 and reaper.GetMasterTrack(proj)) or reaper.GetTrack(proj, idx - 1)
          end
        end
        if tr then
          local fx = fx_idx - 1
          local fx_count = reaper.TrackFX_GetCount(tr)
          if fx >= 0 and fx < fx_count then
            reaper.TrackFX_SetEnabled(tr, fx, enabled == 1)
            reaper.TrackFX_SetOffline(tr, fx, offline == 1)
          end
          restored_tracks_set[tr] = true
        end
      end
    end
  end

  -- Включаем мастер FX обратно, если было выключено
  if flag_include_master == 1 or flag_fx == 1 then
    local master = reaper.GetMasterTrack(0)
    local m_fx_count = reaper.TrackFX_GetCount(master)
    for fx = 0, m_fx_count - 1 do
      reaper.TrackFX_SetEnabled(master, fx, true)
    end
  end

  -- Отключаем глобальный оверрайд автоматизации
  if flag_global_automation == 1 then
    reaper.Main_OnCommand(40876, 0) -- Global automation override: no override
  end

  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()

  local count_restored = 0
  for _ in pairs(restored_tracks_set) do count_restored = count_restored + 1 end

  reaper.Undo_EndBlock(string.format("Restore mix from %s", slots_info[current_slot].name), -1)
  set_status(string.format("Восстановлено из %s: %d треков", slots_info[current_slot].name, count_restored))
end

----------------------------------------------------------------
-- Быстрый Undo
----------------------------------------------------------------

local function perform_undo()
  reaper.Main_OnCommand(40029, 0) -- Edit: Undo
  set_status("Выполнен откат (Undo)")
end

----------------------------------------------------------------
-- ReaImGui Интерфейс
----------------------------------------------------------------

local ctx = reaper.ImGui_CreateContext(SCRIPT_TITLE)

local function gui_loop()
  local window_flags = reaper.ImGui_WindowFlags_AlwaysAutoResize()
  local visible, open = reaper.ImGui_Begin(ctx, SCRIPT_TITLE, true, window_flags)

  if visible then
    ----------------------------------------------------------------
    -- Блок слотов снэпшотов (A / B / C / D)
    ----------------------------------------------------------------
    reaper.ImGui_Text(ctx, "Слоты миксов (A/B сравнение):")

    for slot_idx = 1, 4 do
      if slot_idx > 1 then
        reaper.ImGui_SameLine(ctx)
      end

      local is_active = (current_slot == slot_idx)
      local info = slots_info[slot_idx]
      local btn_label = string.format("%s%s", info.name, info.has_data and " *" or "")

      if is_active then
        -- Подсветка активного слота акцентным цветом
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x2A82DAFF)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x3D94ECFF)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x1E6CB8FF)
      end

      if reaper.ImGui_Button(ctx, btn_label, 68, 26) then
        current_slot = slot_idx
        set_status("Выбран " .. info.name)
      end

      if is_active then
        reaper.ImGui_PopStyleColor(ctx, 3)
      end
    end

    -- Индикатор текущего слота
    local cur_info = slots_info[current_slot]
    if cur_info.has_data then
      reaper.ImGui_TextColored(ctx, 0x4CAF50FF, string.format("%s: сохранен (%s, %d треков)", cur_info.name, cur_info.time or "-", cur_info.track_count))
    else
      reaper.ImGui_TextColored(ctx, 0x9E9E9EFF, string.format("%s: пуст (нет сохраненных данных)", cur_info.name))
    end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    ----------------------------------------------------------------
    -- Основные действия: Save, Restore, Reset, Undo
    ----------------------------------------------------------------
    -- Кнопка Save
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x1B5E20FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x2E7D32FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x144718FF)
    if reaper.ImGui_Button(ctx, "Save", 72, 32) then
      save_mix()
    end
    reaper.ImGui_PopStyleColor(ctx, 3)

    reaper.ImGui_SameLine(ctx)

    -- Кнопка Restore (с легким затемнением, если слот пуст)
    if not cur_info.has_data then
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x424242FF)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x9E9E9EFF)
    else
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x0D47A1FF)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFFFFFFFF)
    end
    if reaper.ImGui_Button(ctx, "Restore", 72, 32) then
      restore_mix()
    end
    reaper.ImGui_PopStyleColor(ctx, 2)

    reaper.ImGui_SameLine(ctx)

    -- Кнопка Reset (сброс уровней без сохранения)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xB71C1CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xC62828FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x8E0000FF)
    if reaper.ImGui_Button(ctx, "Reset", 65, 32) then
      apply_reset()
    end
    reaper.ImGui_PopStyleColor(ctx, 3)

    reaper.ImGui_SameLine(ctx)

    -- Кнопка Undo
    if reaper.ImGui_Button(ctx, "Undo", 55, 32) then
      perform_undo()
    end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    ----------------------------------------------------------------
    -- Область действия (Scope)
    ----------------------------------------------------------------
    reaper.ImGui_Text(ctx, "Область действия (Scope):")

    local sc_changed, sc_val
    if reaper.ImGui_RadioButton(ctx, "Все треки", scope_selected == 0) then
      scope_selected = 0
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_RadioButton(ctx, "Только выделенные", scope_selected == 1) then
      scope_selected = 1
    end

    local chg, val
    chg, val = reaper.ImGui_Checkbox(ctx, "Мастер-трек (Master)", flag_include_master == 1)
    if chg then flag_include_master = val and 1 or 0 end

    reaper.ImGui_SameLine(ctx)
    chg, val = reaper.ImGui_Checkbox(ctx, "Игнорировать папки", flag_ignore_folders == 1)
    if chg then flag_ignore_folders = val and 1 or 0 end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    ----------------------------------------------------------------
    -- Параметры сохранения / сброса
    ----------------------------------------------------------------
    reaper.ImGui_Text(ctx, "Параметры:")

    chg, val = reaper.ImGui_Checkbox(ctx, "Volume", flag_volume == 1)
    if chg then flag_volume = val and 1 or 0 end

    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 80)
    chg, val = reaper.ImGui_InputDouble(ctx, "dB##my_vol", my_vol, 0.5, 1.0, "%.1f")
    if chg then my_vol = val end

    reaper.ImGui_SameLine(ctx)
    chg, val = reaper.ImGui_Checkbox(ctx, "Pan", flag_pan == 1)
    if chg then flag_pan = val and 1 or 0 end

    chg, val = reaper.ImGui_Checkbox(ctx, "FX (Bypass)", flag_fx == 1)
    if chg then flag_fx = val and 1 or 0 end

    reaper.ImGui_SameLine(ctx)
    chg, val = reaper.ImGui_Checkbox(ctx, "Automation", flag_global_automation == 1)
    if chg then flag_global_automation = val and 1 or 0 end

    chg, val = reaper.ImGui_Checkbox(ctx, "Reset after Save", flag_reset_after_save == 1)
    if chg then flag_reset_after_save = val and 1 or 0 end

    ----------------------------------------------------------------
    -- Строка статуса
    ----------------------------------------------------------------
    if status_message ~= "" and (reaper.time_precise() - status_time < 5.0) then
      reaper.ImGui_Spacing(ctx)
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_TextColored(ctx, 0xE0E0E0FF, status_message)
    end

    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(gui_loop)
  else
    save_flag_states()
  end
end

----------------------------------------------------------------
-- Инициализация при запуске
----------------------------------------------------------------

load_flag_states()     -- Загрузка сохраненных флагов настроек
load_slots_metadata()  -- Чтение метаданных слотов из ProjExtState / файлов
reaper.defer(gui_loop)
