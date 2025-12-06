-- @description Track Visible Tools
-- @author Taras Umanskiy
-- @version 1.1
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://vk.com/Tarasmetal
-- @about Инструмент для управления видимостью треков в TCP и MCP. Позволяет показывать/скрывать треки по префиксу или суффиксу имени трека. Поддерживает предустановленные группы для различных типов инструментов.
-- #
-- @changelog
--  + Code Fixies

local r = reaper
console = false

function msg(value) if console then r.ShowConsoleMsg(tostring(value) .. "\n") end end

title = 'Track Visible Tools'
ver = '1.1'
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

function btn(name)
    local current_mode = is_suffix_mode and 's' or 'p'

    if r.ImGui_Button(ctx, name) then
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

    -- r.ImGui_Separator(ctx)
    -- r.ImGui_Spacing(ctx)

    r.ImGui_Spacing(ctx)
    r.ImGui_Separator(ctx)
    r.ImGui_Spacing(ctx)

    -- Информация о режимах работы
    r.ImGui_TextColored(ctx, 0xFFFFFFBB, 'Left Click: TCP mode | Right Click: Mixer mode | Middle Click: Both mode')
    r.ImGui_Spacing(ctx)

    btn("DRUM")
    btn("DRM")
    btn("BASS")
    btn("GTR")
    btn("VOX")
    btn("SYNTH")
    btn("LEAD")
    btn("SFX")
    btn("BUS")
    btn("FX")
    btn("REV")
end

local function loop()
  reaper.ImGui_PushFont(ctx, font, size)
  reaper.ImGui_SetNextWindowSize(ctx, 400, 120, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, windowTitle, true)

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
