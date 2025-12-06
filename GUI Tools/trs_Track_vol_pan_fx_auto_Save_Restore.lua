-- @description Track Volume Pan & Automation Save/Restore (with GUI)
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://vk.com/Tarasmetal
-- @about Скрипт для REAPER, который сохраняет и восстанавливает значения громкости и панорамы всех треков проекта.
-- Имеет GUI с кнопками "Save" и "Restore". Сохраняет данные в текстовый файл внутри папки проекта, позволяя восстанавливать настройки микса.
-- @changelog + Code optimizations

local SCRIPT_TITLE = "Save/Restore FX by Taras Umanskiy"

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
  set_all_tracks_vol(my_vol)  -- Устанавливает громкость всех треков на -6 dB
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

-- reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_SETMASTVOLTO0"), 0) -- Set master volume to 0 dB
-- reaper.SetMediaTrackInfo_Value(reaper.GetMasterTrack(0), "B_PAN", 0, true) -- Reset master pan to 0
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
-- Настройка графического интерфейса (GUI)
----------------------------------------------------------------

local BUTTON_SAVE    = 1
local BUTTON_RESTORE = 2
local TOGGLE_VOLUME  = 3
local TOGGLE_PAN     = 4
local TOGGLE_FX      = 5
local TOGGLE_GLOBAL_AUTOMATION = 6

local buttons = {
  [BUTTON_SAVE] = {
    label = "Save",
    x = 10,  y = 10,
    w = 100, h = 30,
    type = "button"
  },
  [BUTTON_RESTORE] = {
    label = "Restore",
    x = 120, y = 10,
    w = 100, h = 30,
    type = "button"
  },
  [TOGGLE_VOLUME] = {
    label = "Volume",
    x = 10, y = 50,
    w = 210, h = 30,
    type = "toggle",
    flag_var = "flag_volume"
  },
  [TOGGLE_PAN] = {
    label = "Pan",
    x = 10, y = 90,
    w = 210, h = 30,
    type = "toggle",
    flag_var = "flag_pan"
  },
  [TOGGLE_FX] = {
    label = "FX",
    x = 10, y = 130,
    w = 210, h = 30,
    type = "toggle",
    flag_var = "flag_fx"
  },
  [TOGGLE_GLOBAL_AUTOMATION] = {
    label = "Automation",
    x = 10, y = 170,
    w = 210, h = 30,
    type = "toggle",
    flag_var = "flag_global_automation"
  }
}

local function point_in_rect(mx, my, b)
  return mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
end

local function draw_button(b, mouse_over)
  local current_label = b.label
  if b.type == "toggle" then
    local flag_value = _G[b.flag_var]
    current_label = b.label .. ": " .. (flag_value == 1 and "ON" or "OFF")
  end

  -- фон
  if mouse_over then
    gfx.r, gfx.g, gfx.b, gfx.a = 0.3, 0.6, 1, 1
  elseif b.type == "toggle" and _G[b.flag_var] == 1 then
    gfx.r, gfx.g, gfx.b, gfx.a = 0.1, 0.4, 0.8, 1 -- Цвет для включенного переключателя
  else
    gfx.r, gfx.g, gfx.b, gfx.a = 0.2, 0.2, 0.2, 1
  end
  gfx.rect(b.x, b.y, b.w, b.h, 1)

  -- рамка
  gfx.r, gfx.g, gfx.b, gfx.a = 0.8, 0.8, 0.8, 1
  gfx.rect(b.x, b.y, b.w, b.h, 0)

  -- текст
  gfx.setfont(1, "Arial", 16)
  local tw, th = gfx.measurestr(current_label)
  gfx.x = b.x + (b.w - tw) / 2
  gfx.y = b.y + (b.h - th) / 2
  gfx.r, gfx.g, gfx.b, gfx.a = 1, 1, 1, 1
  gfx.drawstr(current_label)
end

local last_mouse_state = 0
local last_click_time = 0
local click_delay = 0.15 -- сек

local function gui_loop()
  if gfx.getchar() < 0 then
    save_flag_states() -- Сохраняем состояние флагов при закрытии GUI
    return
  end

  gfx.r, gfx.g, gfx.b, gfx.a = 0.1, 0.1, 0.1, 1
  gfx.clear = 0x202020

  local mx, my = gfx.mouse_x, gfx.mouse_y
  local mouse_state = gfx.mouse_cap
  local now = reaper.time_precise()

  for id, b in pairs(buttons) do
    local hover = point_in_rect(mx, my, b)
    draw_button(b, hover)

    -- обработка клика
    local left_button_down = (mouse_state & 1) == 1
    local left_button_was_down = (last_mouse_state & 1) == 1

    if hover and left_button_down and not left_button_was_down then
      -- защита от слишком частых кликов
      if now - last_click_time > click_delay then
        last_click_time = now
        if id == BUTTON_SAVE then
          save_mix()
        elseif id == BUTTON_RESTORE then
          restore_mix()
        elseif b.type == "toggle" then
          _G[b.flag_var] = 1 - _G[b.flag_var] -- Инвертировать значение флага (0 <-> 1)
        end
      end
    end
  end

  last_mouse_state = mouse_state

  gfx.update()
  reaper.defer(gui_loop)
end

----------------------------------------------------------------
-- Инициализация графического интерфейса
----------------------------------------------------------------

local function init_gui()
  gfx.clear = 0x202020
  -- gfx.init(SCRIPT_TITLE, 240, 60, 0, 100, 100)
  gfx.init(SCRIPT_TITLE, 240, 220, 0, 500, 100)
  gui_loop()
end

----------------------------------------------------------------
-- Запись сценария
----------------------------------------------------------------
load_flag_states() -- Загружаем состояние флагов при запуске скрипта
-- Устанавливает громкость всех треков в dB, переданных аргументом
function set_all_tracks_vol(db_value)
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
function reset_all_pan()
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

init_gui()
