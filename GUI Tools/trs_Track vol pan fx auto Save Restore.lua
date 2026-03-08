-- @description Track Volume Pan & Automation Save/Restore (ReaImGui)
-- @author Taras Umanskiy
-- @version 1.2
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://vk.com/Tarasmetal
-- @about Скрипт для REAPER, который сохраняет и восстанавливает значения громкости и панорамы всех треков проекта.
-- Имеет GUI (ReaImGui) с кнопками "Save" и "Restore". Сохраняет данные в текстовый файл внутри папки проекта, позволяя восстанавливать настройки микса.
-- @changelog
--  + Добавлена возможность редактирования уровня сброса громкости (my_vol) в интерфейсе.
--  + Переписан интерфейс на ReaImGui
--  + Первоначальная версия скрипта для сохранения и восстановления значений громкости и панорамы.

local SCRIPT_TITLE = "Save/Restore FX by Taras Umanskiy v1.2"

-- Проверка наличия ReaImGui
if not reaper.APIExists("ImGui_CreateContext") then
  reaper.ShowMessageBox("Требуется расширение ReaImGui.\nПожалуйста, установите его через ReaPack.", SCRIPT_TITLE, 0)
  return
end

flag_volume = 1  -- Флаг: сохранять/восстанавливать громкость треков (1 – включено, 0 – выключено)
my_vol = -3  -- Уровень громкости в dB, на который будут установлены все треки при сбросе (значение 0 дБ)
flag_pan = 1  -- Флаг: сохранять/восстанавливать панораму треков (1 – включено, 0 – выключено)
flag_fx = 1  -- Флаг: сохранять/восстанавливать состояние FX треков (1 – включено, 0 – выключено)
flag_global_automation = 0  -- Флаг: сохранять/восстанавливать глобальную автоматизацию треков (1 – включено, 0 – выключено)

----------------------------------------------------------------
-- Путь проекта и путь к файлу
----------------------------------------------------------------

local function get_project_dir()
  local _, proj_path = reaper.EnumProjects(-1, "")
  if not proj_path or proj_path == "" then
    return nil
  end
  -- proj_path: "C:\\path\\to\\project.rpp"
  return proj_path:match("^(.*[\\/])") or nil
end

local function get_state_file_path()
  local proj_dir = get_project_dir()
  if not proj_dir then return nil end
  local sep = proj_dir:match("[/\\]$") and "" or package.config:sub(1,1)
  return proj_dir .. sep .. "TrackMixSnap.txt"
end

local function get_flags_file_path()
  local proj_dir = get_project_dir()
  if not proj_dir then return nil end
  local sep = proj_dir:match("[/\\]$") and "" or package.config:sub(1,1)
  return proj_dir .. sep .. "TrackMixFlags.txt"
end

local function save_flag_states()
  local path = get_flags_file_path()
  if not path then return end

  local file, err = io.open(path, "w")
  if not file then return end

  file:write(string.format("flag_volume=%d\n", flag_volume))
  file:write(string.format("my_vol=%.2f\n", my_vol))
  file:write(string.format("flag_pan=%d\n", flag_pan))
  file:write(string.format("flag_fx=%d\n", flag_fx))
  file:write(string.format("flag_global_automation=%d\n", flag_global_automation))
  file:close()
end

local function load_flag_states()
  local path = get_flags_file_path()
  if not path then return end

  local file, err = io.open(path, "r")
  if not file then return end

  for line in file:lines() do
    local var_name, value_str = line:match("^(.-)=(.-)$")
    if var_name and value_str then
      local value = tonumber(value_str)
      if value ~= nil then
        _G[var_name] = value
      end
    end
  end
  file:close()
end

----------------------------------------------------------------
-- Вспомогательные функции (Volume/Pan)
----------------------------------------------------------------

-- Устанавливает громкость всех треков в dB, переданных аргументом
local function set_all_tracks_vol(db_value)
  if type(db_value) ~= "number" then return end

  local proj = 0
  local track_count = reaper.CountTracks(proj)

  -- Перевод dB в линейное значение фейдера
  local vol_linear = 10 ^ (db_value / 20)

  reaper.Undo_BeginBlock()

  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(proj, i)
    if track then
      reaper.SetMediaTrackInfo_Value(track, "D_VOL", vol_linear)
    end
  end

  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()

  reaper.Undo_EndBlock("Set all track volumes to " .. db_value .. " dB", -1)
end

-- Сбрасывает панораму всех треков на центр (0.0)
local function reset_all_pan()
  local proj = 0
  local track_count = reaper.CountTracks(proj)

  reaper.Undo_BeginBlock()

  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(proj, i)
    if track then
      reaper.SetMediaTrackInfo_Value(track, "D_PAN", 0.0)
    end
  end

  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()

  reaper.Undo_EndBlock("Reset pan on all tracks", -1)
end

----------------------------------------------------------------
-- Функции сохранения/восстановления (с состояниями FX)
----------------------------------------------------------------

local function save_mix()
  local path = get_state_file_path()
  if not path then
    reaper.ShowMessageBox(
      "Не удалось получить путь к папке проекта.\nСохранение невозможно.",
      SCRIPT_TITLE, 0
    )
    return
  end

  local file, err = io.open(path, "w")
  if not file then
    reaper.ShowMessageBox(
      "Не удалось открыть файл для записи:\n" .. tostring(err),
      SCRIPT_TITLE, 0
    )
    return
  end

  local track_count = reaper.CountTracks(0)

  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    local track_index = i + 1

    if flag_volume == 1 then
      local vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
      file:write(string.format("V|%d|%0.17f\n", track_index, vol))
    end

    if flag_pan == 1 then
      local pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
      file:write(string.format("P|%d|%0.17f\n", track_index, pan))
    end

    if flag_fx == 1 then
      local fx_count = reaper.TrackFX_GetCount(track)
      for fx = 0, fx_count - 1 do
        local enabled = reaper.TrackFX_GetEnabled(track, fx) and 1 or 0
        local offline = reaper.TrackFX_GetOffline(track, fx) and 1 or 0
        file:write(string.format(
          "F|%d|%d|%d|%d\n",
          track_index,
          fx + 1,
          enabled,
          offline
        ))
      end
    end
  end

  file:close()

  if flag_volume == 1 then
    set_all_tracks_vol(my_vol)  -- Устанавливает громкость всех треков на указанное значение
  end
  if flag_pan == 1 then
    reset_all_pan()  -- Сбрасывает панораму на всех треках (пан в центр)
  end
  if flag_fx == 1 then
    reaper.Main_OnCommand(40296, 0) -- Track: Select all tracks
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_NF_BYPASS_FX_EXCEPT_VSTI_FOR_SEL_TRACKS"), 0) -- Bypass FX (except VSTi) for sel. tracks
    reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_DISMASTERFX"), 0) -- Disable master FX
  end

  if flag_global_automation == 1 then
    reaper.Main_OnCommand(40885, 0)
  end
end

local function restore_mix()
  local path = get_state_file_path()
  if not path then
    reaper.ShowMessageBox(
      "Не удалось получить путь к папке проекта.\nВосстановление невозможно.",
      SCRIPT_TITLE, 0
    )
    return
  end

  local file = io.open(path, "r")
  if not file then
    reaper.ShowMessageBox(
      "Файл с сохранённым миксом не найден:\n" .. path,
      SCRIPT_TITLE, 0
    )
    return
  end

  reaper.Undo_BeginBlock()

  local proj = 0

  for line in file:lines() do
    local kind = line:match("^(%u)|")
    if kind == "V" and flag_volume == 1 then
      local idx_str, vol_str = line:match("^V|([^|]+)|([^|]+)$")
      if idx_str and vol_str then
        local idx = tonumber(idx_str)
        local vol = tonumber(vol_str)
        if idx and vol then
          local tr = reaper.GetTrack(proj, idx - 1)
          if tr then
            reaper.SetMediaTrackInfo_Value(tr, "D_VOL", vol)
          end
        end
      end
    elseif kind == "P" and flag_pan == 1 then
      local idx_str, pan_str = line:match("^P|([^|]+)|([^|]+)$")
      if idx_str and pan_str then
        local idx = tonumber(idx_str)
        local pan = tonumber(pan_str)
        if idx and pan then
          local tr = reaper.GetTrack(proj, idx - 1)
          if tr then
            reaper.SetMediaTrackInfo_Value(tr, "D_PAN", pan)
          end
        end
      end
    elseif kind == "F" and flag_fx == 1 then
      local idx_str, fx_str, en_str, off_str = line:match("^F|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
      if idx_str and fx_str and en_str and off_str then
        local track_idx = tonumber(idx_str)
        local fx_idx    = tonumber(fx_str)
        local enabled   = tonumber(en_str)
        local offline   = tonumber(off_str)
        if track_idx and fx_idx and enabled and offline then
          local tr = reaper.GetTrack(proj, track_idx - 1)
          if tr then
            local fx = fx_idx - 1
            local fx_count = reaper.TrackFX_GetCount(tr)
            if fx >= 0 and fx < fx_count then
              reaper.TrackFX_SetEnabled(tr, fx, enabled == 1)
              reaper.TrackFX_SetOffline(tr, fx, offline == 1)
            end
          end
        end
      end
    end
  end

  file:close()

  if flag_fx == 1 then
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_ENMASTERFX"), 0) -- Enable master FX
  end
  if flag_global_automation == 1 then
    reaper.Main_OnCommand(40876, 0)
  end
  -- обновляем интерфейс
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()

  reaper.Undo_EndBlock("Restore track vol/pan & FX states from file", -1)
end

----------------------------------------------------------------
-- ReaImGui Интерфейс
----------------------------------------------------------------

local ctx = reaper.ImGui_CreateContext(SCRIPT_TITLE)

local function gui_loop()
  -- Флаги окна: AlwaysAutoResize позволяет окну подстраиваться под контент
  local visible, open = reaper.ImGui_Begin(ctx, SCRIPT_TITLE, true, reaper.ImGui_WindowFlags_AlwaysAutoResize())

  if visible then
    -- Кнопки Save и Restore
    -- Используем GetContentRegionAvail для расчета ширины, если хотим растянуть,
    -- но здесь зададим фиксированный размер как в оригинале (100x30)

    if reaper.ImGui_Button(ctx, "Save", 100, 30) then
      save_mix()
    end

    reaper.ImGui_SameLine(ctx)

    if reaper.ImGui_Button(ctx, "Restore", 100, 30) then
      restore_mix()
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    -- Чекбоксы (Переключатели)
    -- ReaImGui возвращает (changed, new_value)
    -- Lua 1/0 -> Bool -> Lua 1/0

    local changed, new_val

    changed, new_val = reaper.ImGui_Checkbox(ctx, "Volume", flag_volume == 1)
    if changed then flag_volume = new_val and 1 or 0 end

    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 80)
    -- changed, new_val = reaper.ImGui_InputDouble(ctx, "##my_vol", my_vol, 0.5, 1.0, "%.1f dB")
    changed, new_val = reaper.ImGui_InputDouble(ctx, "##my_vol", my_vol, 0.5, 1.0, "%.1f")
    if changed then my_vol = new_val end

    changed, new_val = reaper.ImGui_Checkbox(ctx, "Pan", flag_pan == 1)
    if changed then flag_pan = new_val and 1 or 0 end

    changed, new_val = reaper.ImGui_Checkbox(ctx, "FX", flag_fx == 1)
    if changed then flag_fx = new_val and 1 or 0 end

    changed, new_val = reaper.ImGui_Checkbox(ctx, "Automation", flag_global_automation == 1)
    if changed then flag_global_automation = new_val and 1 or 0 end

    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(gui_loop)
  else
    -- При закрытии окна сохраняем настройки флагов
    save_flag_states()
  end
end

----------------------------------------------------------------
-- Инициализация
----------------------------------------------------------------

load_flag_states() -- Загружаем состояние флагов при запуске скрипта
reaper.defer(gui_loop)
