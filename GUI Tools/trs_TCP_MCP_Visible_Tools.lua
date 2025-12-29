-- @description Track Visible Tools
-- @author Taras Umanskiy
-- @version 1.10
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://vk.com/Tarasmetal
-- @about Инструмент для управления видимостью треков в TCP и MCP. Позволяет показывать/скрывать треки по префиксу или суффиксу имени трека. Поддерживает предустановленные и пользовательские группы.
-- #
-- @changelog
--  + Store button names in a local .ini file (comma-separated)
--  + Added Auto-Resize Window to fit content
--  + New button now inserts after the current button instead of at the end
--  + Moved (+) button to context menu
--  + Added 'E' hotkey to toggle Edit Mode
--  + Fixed button renaming issue (stable ID with ###)
--  + Added Drag & Drop reordering in Edit Mode
--  + Added editable buttons (Edit Mode)
--  + Context menu for adding/renaming/deleting buttons
--  + Code Fixies

local r = reaper
console = false

function msg(value) if console then r.ShowConsoleMsg(tostring(value) .. "\n") end end

title = 'Track Visible Tools'
ver = '1.7'
author = 'Taras Umanskiy'
about = title .. ' ' .. ver .. ' | by ' .. author
ListDir = {}
ListDir.scriptDir, ListDir.scriptFileName = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")
scriptDir = ListDir.scriptDir
scriptFileName = ListDir.scriptFileName
windowTitle = about

local ctx = r.ImGui_CreateContext(windowTitle)
local size = 13
local font = reaper.ImGui_CreateFont('sans-serif', size)
r.ImGui_Attach(ctx, font)

-- Переменные для отслеживания режимов
local is_suffix_mode = false
local is_shift_pressed = false -- Переменная для отслеживания нажатия Shift
local tn = ""
local tfc = 0
local edit_mode = false -- Режим редактирования кнопок

-- Загрузка и сохранение кнопок
local default_buttons = {"DRUM", "DRM", "BASS", "GTR", "VOX", "SYNTH", "LEAD", "SFX", "BUS", "FX", "REV"}
local buttons = {}
local ini_file = scriptDir .. "trs_TCP_MCP_Visible_Tools.ini"

function SaveButtons()
    local file = io.open(ini_file, "w")
    if file then
        file:write("[Main]\n")
        file:write("Buttons=" .. table.concat(buttons, ",") .. "\n")
        file:close()
    end
end

function LoadButtons()
    local file = io.open(ini_file, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local str = content:match("Buttons=([^\r\n]*)")
        if str then
            buttons = {}
            for s in str:gmatch("([^,]+)") do
                -- Удаляем возможные пробелы по краям
                s = s:match("^%s*(.-)%s*$")
                if s ~= "" then table.insert(buttons, s) end
            end
        end
    end

    -- Если кнопки не загрузились из файла (или файл пустой), используем дефолт
    if #buttons == 0 then
        -- Загрузка дефолтных кнопок
        for _, v in ipairs(default_buttons) do table.insert(buttons, v) end
    end
end

LoadButtons()

-- Функция для показа всех треков с учетом режима Shift
function ShowAllTracks()
    -- Сохраняем текущее состояние Shift
    local temp_shift = is_shift_pressed
    if not temp_shift then
        -- Если Shift не нажат, сбрасываем все треки
        SetTrackVisName("", "p", nil)
    else
        -- Если Shift нажат, показываем все треки без сброса текущих
        -- Временно отключаем режим Shift для функции SetTrackVisName
        is_shift_pressed = false
        -- Показываем все треки
        local track_count = reaper.CountTracks(0)
        for i = 0, track_count - 1 do
            local track = reaper.GetTrack(0, i)
            reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
            reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 1)
        end
        -- Восстанавливаем режим Shift
        is_shift_pressed = temp_shift
        -- Обновляем информацию
        tn = "ALL TRACKS"
        tfc = reaper.CountTracks(0)
        reaper.TrackList_AdjustWindows(false)
        reaper.UpdateTimeline()
    end
end

-- Функция для изменения видимости треков
function SetTrackVisName(t_name, mode, mixer_mode)
    local track_count = reaper.CountTracks(0)
    local track_found_count = 0

    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

        local match = false
        if mode == 'p' and track_name:lower():sub(1, #t_name) == t_name:lower() then
            match = true
        elseif mode == 's' and track_name:lower():sub(-#t_name) == t_name:lower() then
            match = true
        end

        if match then
            track_found_count = track_found_count + 1

            -- Показываем найденные треки везде
            reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
            reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 1)
        else
            -- Если Shift нажат, не скрываем треки, которые уже видимы
            if is_shift_pressed then
                -- Не меняем видимость существующих треков при нажатом Shift
                -- Это позволяет добавлять треки к текущему выбору
            else
                -- Обычное поведение без Shift
                if mixer_mode == 't' then
                    -- TCP режим: в TCP только нужные, в микшере все
                    reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
                    reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 1)
                elseif mixer_mode == 'm' then
                    -- Mixer режим: в TCP все, в микшере только нужные
                    reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
                    reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0)
                elseif mixer_mode == 'b' then
                    -- Both режим: в TCP и микшере только нужные
                    reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
                    reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0)
                end
            end
        end
    end

    -- Если t_name пустой, показать все треки
    if t_name == "" then
        for i = 0, track_count - 1 do
            local track = reaper.GetTrack(0, i)
            reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 1)
            reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
    end

    tn = t_name
    tfc = track_found_count

    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateTimeline()
end

function btn(name, i)
    local current_mode = is_suffix_mode and 's' or 'p'

    -- Используем стабильный ID для кнопки (###i), чтобы имя (name) не влияло на ID элемента
    -- Это позволяет избежать потери фокуса/закрытия меню при редактировании имени
    if r.ImGui_Button(ctx, name .. "###" .. i) then
        if not edit_mode then
            -- Обычный клик (без CTRL) - режим префикса
            if not is_suffix_mode then
                -- Левая кнопка: TCP режим
                SetTrackVisName(name, 'p', "t")
            else
                -- CTRL активен - режим суффикса
                -- Левая кнопка: TCP режим с поиском по суффиксу
                SetTrackVisName(name, 's', "t")
            end
        end
    end

    -- Режим редактирования: Drag & Drop и Context Menu
    if edit_mode then
        -- Drag Source
        if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_None()) then
            r.ImGui_SetDragDropPayload(ctx, 'BUTTON_ORDER', tostring(i))
            r.ImGui_Text(ctx, name)
            r.ImGui_EndDragDropSource(ctx)
        end

        -- Drag Target
        if r.ImGui_BeginDragDropTarget(ctx) then
            local retval, payload = r.ImGui_AcceptDragDropPayload(ctx, 'BUTTON_ORDER')
            if retval then
                local src = tonumber(payload)
                local dst = i
                if src and src ~= dst then
                    local val = buttons[src]
                    table.remove(buttons, src)
                    table.insert(buttons, dst, val)
                    SaveButtons()
                end
            end
            r.ImGui_EndDragDropTarget(ctx)
        end

        -- Context Menu
        if r.ImGui_BeginPopupContextItem(ctx) then
            r.ImGui_Text(ctx, 'Edit Button:')
            local changed, new_name = r.ImGui_InputText(ctx, '##edit'..i, buttons[i])
            if changed then
                buttons[i] = new_name
                SaveButtons()
            end

            if r.ImGui_Button(ctx, 'Delete') then
                table.remove(buttons, i)
                SaveButtons()
                r.ImGui_CloseCurrentPopup(ctx)
            end

            r.ImGui_SameLine(ctx)

            if r.ImGui_Button(ctx, 'Insert') then
                table.insert(buttons, i + 1, "NEW")
                SaveButtons()
                r.ImGui_CloseCurrentPopup(ctx)
            end

            r.ImGui_EndPopup(ctx)
        end
    else
        -- Обработка правой кнопки мыши
        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseClicked(ctx, 1) then
            if not is_suffix_mode then
                -- Правая кнопка: Mixer режим
                SetTrackVisName(name, 'p', "m")
            else
                -- CTRL активен - Mixer режим с поиском по суффиксу
                SetTrackVisName(name, 's', "m")
            end
        end

        -- Обработка средней кнопки мыши (колесико)
        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseClicked(ctx, 2) then
            if not is_suffix_mode then
                -- Средняя кнопка: Both режим
                SetTrackVisName(name, 'p', "b")
            else
                -- CTRL активен - Both режим с поиском по суффиксу
                SetTrackVisName(name, 's', "b")
            end
        end
    end

    r.ImGui_SameLine(ctx)
end

local function myWindow()
    local rv

    r.ImGui_TextColored(ctx, 0xFFFF00FF, 'INFO:')
    r.ImGui_SameLine(ctx)
    if tn == "" then
        tn = "ALL TRACKS"
    end
    r.ImGui_TextColored(ctx, 0xFFFFFFBB, tn)
    r.ImGui_SameLine(ctx)
    r.ImGui_TextColored(ctx, 0xFFFFFFBB, ':')
    r.ImGui_SameLine(ctx)
    r.ImGui_TextColored(ctx, 0xFFFFFFFF, tfc)

    -- Отображение статуса Shift
    if is_shift_pressed then
        r.ImGui_SameLine(ctx)
        r.ImGui_TextColored(ctx, 0x00FF00FF, '[MULTI]')
    end

    if r.ImGui_Button(ctx, 'ALL') then
        ShowAllTracks()
    end

    -- Обработка клавиши Alt для показа всех треков
    if r.ImGui_GetKeyMods(ctx) & r.ImGui_Mod_Alt() ~= 0 then
        ShowAllTracks()
    end

    r.ImGui_SameLine(ctx)

    -- Индикатор режима с цветовой индикацией
    local mode_text = is_suffix_mode and "SUFFIX MODE" or "PREFIX MODE"
    local mode_color = is_suffix_mode and 0xFFFF00FF or 0x00FF0FFF  -- Зеленый для активного, красный для пассивного

    -- Кнопка переключения режима
    if r.ImGui_Button(ctx, 'Mode') then
      is_suffix_mode = not is_suffix_mode
      -- Принудительно обновляем интерфейс
      reaper.defer(function() end)
    end

    -- Обработка клавиши M для переключения режима
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_M()) then
      is_suffix_mode = not is_suffix_mode
      -- Принудительно обновляем интерфейс
      reaper.defer(function() end)
    end

    r.ImGui_SameLine(ctx) r.ImGui_TextColored(ctx, mode_color, mode_text)

    r.ImGui_SameLine(ctx)

    -- Edit Mode Checkbox
    local rv_edit
    rv_edit, edit_mode = r.ImGui_Checkbox(ctx, "Press 'E' for edit", edit_mode)

    -- Обработка клавиши E для переключения режима Edit
    -- Проверяем IsAnyItemActive, чтобы не переключать режим при вводе текста (например, при переименовании кнопок)
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_E()) and not r.ImGui_IsAnyItemActive(ctx) then
        edit_mode = not edit_mode
    end

    r.ImGui_Spacing(ctx)
    r.ImGui_Separator(ctx)
    r.ImGui_Spacing(ctx)

    -- Информация о режимах работы
    if edit_mode then
        r.ImGui_TextColored(ctx, 0xFFAAAAFF, 'EDIT MODE: Drag to Reorder | Right Click to Edit/Delete/Add')
    else
        r.ImGui_TextColored(ctx, 0xFFFFFFBB, 'Left Click: TCP mode | Right Click: Mixer mode | Middle Click: Both mode')
    end
    r.ImGui_Spacing(ctx)

    -- Отрисовка кнопок
    for i, name in ipairs(buttons) do
        btn(name, i)
    end
end

local function loop()
  reaper.ImGui_PushFont(ctx, font, size)
  local visible, open = reaper.ImGui_Begin(ctx, windowTitle, true, reaper.ImGui_WindowFlags_AlwaysAutoResize())

  -- Проверка нажатия CTRL для переключения режима
  is_suffix_mode = r.ImGui_GetKeyMods(ctx) & r.ImGui_Mod_Ctrl() ~= 0

  -- Проверка нажатия Shift для мультивыбора
  is_shift_pressed = r.ImGui_GetKeyMods(ctx) & r.ImGui_Mod_Shift() ~= 0

  -- Обработка клавиши ESC для выхода из скрипта
  if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
    open = false
  end

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
