-- @description trs_Track automation mode toggle
-- @author Taras Umanskiy
-- @version 1.7
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about
--   Скрипт с современным графическим интерфейсом на базе ReaImGui для управления режимами автоматизации треков.
--   Поддерживает переключение всех режимов: Trim/Read, Read, Touch, Write, Latch, Latch Preview.
-- @changelog
--   + Дополнительное уменьшение размеров кнопок и отступов
--   + Уменьшен размер кнопок и шрифта
--   + Исправлено удаление автоматизации (теперь работает через Chunk Parsing)
--   + Добавлена кнопка удаления автоматизации
--   + Исправлена ошибка вылета (ImGui_GetWindowContentRegionMax deprecated)
--   + Code optimizations

local r = reaper

-- Проверка наличия ReaImGui
if not r.APIExists('ImGui_GetVersion') then
  r.ShowMessageBox('Please install ReaImGui API via ReaPack!', 'Error', 0)
  return
end
local version = "1.7"
local ctx = r.ImGui_CreateContext('Automation Toggler')
local FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

-- Константы дизайна
local FONT_SIZE = 12
local WINDOW_FLAGS = r.ImGui_WindowFlags_NoCollapse() | r.ImGui_WindowFlags_AlwaysAutoResize()

-- Цветовая схема
local COLOR_BG           = 0x1E1E1EFF
local COLOR_BTN          = 0x333333FF
local COLOR_BTN_HOVER    = 0x444444FF
local COLOR_BTN_ACTIVE   = 0x555555FF
local COLOR_TEXT         = 0xFFFFFFFF
local COLOR_TEXT_DIM     = 0xAAAAAAFF
local COLOR_TEXT_BLACK   = 0x000000FF

local COLOR_BTN_DEL        = 0x8B0000FF -- Dark Red
local COLOR_BTN_DEL_HOVER  = 0xA52A2AFF -- Red
local COLOR_BTN_DEL_ACTIVE = 0xFF0000FF -- Bright Red

-- Цвета режимов (примерно соответствуют стандартам Reaper)
local COLOR_MODE_TRIM       = 0xAAAAAAFF -- Gray for Trim/Read (Default)
local COLOR_MODE_READ       = 0x4CAF50FF -- Green for Read
local COLOR_MODE_TOUCH      = 0xFFB300FF -- Amber for Touch
local COLOR_MODE_WRITE      = 0xF44336FF -- Red for Write
local COLOR_MODE_LATCH      = 0x9C27B0FF -- Purple for Latch
local COLOR_MODE_LATCH_PREV = 0x2196F3FF -- Blue for Latch Preview

-- Шрифты
local font = r.ImGui_CreateFont('sans-serif', FONT_SIZE)
r.ImGui_Attach(ctx, font)

-- Состояние
local current_status_mode = -2 -- -2: None, -1: Mixed, 0-5: Specific Mode

-- Функция для получения состояния выбранных треков
local function GetTracksStatus()
  local count = r.CountSelectedTracks(0)
  if count == 0 then return -2 end -- None selected

  local first_mode = r.GetTrackAutomationMode(r.GetSelectedTrack(0, 0))

  for i = 1, count - 1 do
    local track = r.GetSelectedTrack(0, i)
    local mode = r.GetTrackAutomationMode(track)
    if mode ~= first_mode then return -1 end -- Mixed
  end

  return first_mode
end

-- Функция для получения названия режима
local function GetModeName(mode)
    if mode == 0 then return "Trim/Read"
    elseif mode == 1 then return "Read"
    elseif mode == 2 then return "Touch"
    elseif mode == 3 then return "Write"
    elseif mode == 4 then return "Latch"
    elseif mode == 5 then return "Latch Preview"
    elseif mode == -1 then return "Mixed"
    else return "None"
    end
end

-- Функция для получения цвета режима
local function GetModeColor(mode)
    if mode == 0 then return COLOR_MODE_TRIM
    elseif mode == 1 then return COLOR_MODE_READ
    elseif mode == 2 then return COLOR_MODE_TOUCH
    elseif mode == 3 then return COLOR_MODE_WRITE
    elseif mode == 4 then return COLOR_MODE_LATCH
    elseif mode == 5 then return COLOR_MODE_LATCH_PREV
    else return COLOR_TEXT
    end
end

-- Функция переключения режима
local function SetAutomationMode(mode)
  r.Undo_BeginBlock()
  r.PreventUIRefresh(-1)

  local count = r.CountSelectedTracks(0)
  for i = 0, count - 1 do
    local track = r.GetSelectedTrack(0, i)
    r.SetTrackAutomationMode(track, mode)
  end

  r.PreventUIRefresh(0)
  r.Undo_EndBlock("Set Automation Mode: " .. GetModeName(mode), -1)
  r.UpdateArrange()
end

-- Функция для удаления энвелопов из чанка
local function DeleteEnvelopesFromChunk(chunk)
  local t = {}
  local depth = 0
  local removing = false

  for line in chunk:gmatch("([^\n]*)\n?") do
      if line == "" and not chunk:match("\n$") then
         -- Skip the empty string matched at the very end of file if it doesn't end with newline
         -- But actually gmatch iterates once for the end.
         -- Simple check: if line is empty, we can skip or keep.
         -- Reaper chunks usually end with >.
      end

      -- Helper to trim whitespace for check
      local trimmed = line:match("^%s*(.+)") or ""

      -- Check for start of envelope
      if not removing then
          if trimmed:match("^<VOLENV") or
             trimmed:match("^<PANENV") or
             trimmed:match("^<WIDTHENV") or
             trimmed:match("^<MUTEENV") or
             trimmed:match("^<PARMENV") then
              removing = true
              depth = 0
          end
      end

      if removing then
          local _, open = line:gsub("<", "")
          local _, close = line:gsub(">", "")
          depth = depth + open - close

          if depth <= 0 then
              removing = false
              depth = 0
          end
      else
          if line ~= "" then table.insert(t, line) end
      end
  end
  return table.concat(t, "\n")
end

-- Функция удаления автоматизации
local function DeleteAutomation()
  local count = r.CountSelectedTracks(0)
  if count == 0 then return end

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  for i = 0, count - 1 do
      local track = r.GetSelectedTrack(0, i)
      local ret, chunk = r.GetTrackStateChunk(track, "", false)
      if ret then
          local new_chunk = DeleteEnvelopesFromChunk(chunk)
          r.SetTrackStateChunk(track, new_chunk, false)
      end
  end

  r.PreventUIRefresh(-1)
  r.Undo_EndBlock("Delete Automation for selected tracks", -1)
  r.UpdateArrange()
end

-- Отрисовка кнопки режима
local function DrawModeButton(label, mode, color, width, height)
    local is_active = (current_status_mode == mode)

    if is_active then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), color)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), color) -- Stay same on hover if active
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), color)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), COLOR_TEXT_BLACK)
    else
         -- Optional: Subtle hint of color on borders or inactive state? keeping simple for now
    end

    if r.ImGui_Button(ctx, label, width, height) then
        SetAutomationMode(mode)
    end

    if is_active then
        r.ImGui_PopStyleColor(ctx, 4)
    end
end

-- Основная функция отрисовки
local function Frame()
  local visible, open = r.ImGui_Begin(ctx, 'Automation ' .. version .. ' by Taras Umanskiy', true, WINDOW_FLAGS)

  if visible then
    -- Стилизация
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        COLOR_BTN)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), COLOR_BTN_HOVER)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  COLOR_BTN_ACTIVE)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(),          COLOR_TEXT)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FrameRounding(), 5)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), 6, 6)

    -- Получаем текущее состояние
    current_status_mode = GetTracksStatus()
    local selected_count = r.CountSelectedTracks(0)

    -- Заголовок / Инфо
    r.ImGui_TextColored(ctx, COLOR_TEXT_DIM, "Selected Tracks: " .. tostring(selected_count))
    r.ImGui_SameLine(ctx)

    -- Индикатор статуса справа
    local status_text = GetModeName(current_status_mode)
    local status_color = GetModeColor(current_status_mode)
    if current_status_mode == -1 then status_color = COLOR_TEXT_DIM end -- Mixed color

    local window_width = r.ImGui_GetWindowWidth(ctx)
    local pad_x = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())
    local text_width = r.ImGui_CalcTextSize(ctx, status_text)
    r.ImGui_SetCursorPosX(ctx, window_width - text_width - pad_x)
    r.ImGui_TextColored(ctx, status_color, status_text)

    r.ImGui_Separator(ctx)
    r.ImGui_Dummy(ctx, 0, 5)

    -- Сетка кнопок (2 колонки)
    local btn_width = 100
    local btn_height = 22

    DrawModeButton("TRIM / READ", 0, COLOR_MODE_TRIM, btn_width, btn_height)
    r.ImGui_SameLine(ctx)
    DrawModeButton("READ", 1, COLOR_MODE_READ, btn_width, btn_height)

    DrawModeButton("TOUCH", 2, COLOR_MODE_TOUCH, btn_width, btn_height)
    r.ImGui_SameLine(ctx)
    DrawModeButton("LATCH", 4, COLOR_MODE_LATCH, btn_width, btn_height)

    DrawModeButton("LATCH PREVIEW", 5, COLOR_MODE_LATCH_PREV, btn_width, btn_height)
    r.ImGui_SameLine(ctx)
    DrawModeButton("WRITE", 3, COLOR_MODE_WRITE, btn_width, btn_height)

    -- Кнопка Toggle (Умное переключение)
    r.ImGui_Dummy(ctx, 0, 3)
    r.ImGui_Separator(ctx)
    r.ImGui_Dummy(ctx, 0, 3)

    -- Кнопка на всю ширину
    local toggle_label = "TOGGLE: TOUCH <-> TRIM"
    if r.ImGui_Button(ctx, toggle_label, -1, 26) then
       if current_status_mode == 2 then SetAutomationMode(0) -- If Touch -> Trim
       else SetAutomationMode(2) -- Anything else -> Touch
       end
    end

    -- Кнопка DELETE
    r.ImGui_Dummy(ctx, 0, 3)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        COLOR_BTN_DEL)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), COLOR_BTN_DEL_HOVER)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  COLOR_BTN_DEL_ACTIVE)

    if r.ImGui_Button(ctx, "DELETE ALL AUTOMATION", -1, 22) then
        local retval = r.ShowMessageBox("Are you sure you want to delete ALL envelopes on selected tracks?", "Confirm Delete", 4)
        if retval == 6 then -- 6 = Yes
             DeleteAutomation()
        end
    end

    r.ImGui_PopStyleColor(ctx, 3)

    -- Очистка стилей
    r.ImGui_PopStyleVar(ctx, 2)
    r.ImGui_PopStyleColor(ctx, 4)

    r.ImGui_End(ctx)
  end

  if open then
    r.defer(Frame)
  end
end

-- Запуск скрипта
r.defer(Frame)
