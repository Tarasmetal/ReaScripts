-- @description Multi-channel MIDI Tracks Generator & Router to Selected Track
-- @author Taras Umanskiy
-- @version 1.1.0
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about Создает заданное количество MIDI треков (каналы 1-16 или All) с автоматической маршрутизацией (MIDI-only send) на текущий выделенный трек.
-- @changelog
--   v.1.1.0 + Добавлен чекбокс "MIDI ALL" (по умолчанию выключен). При включении на всех созданных дорожках назначается MIDI All -> All
--   v.1.0.0 + Начальный релиз: GUI генератор MIDI треков с назначением каналов 1-16 и MIDI-only посылом на целевой трек

local reaper = reaper

-- Проверка доступности ReaImGui
if not reaper.APIExists('ImGui_GetBuiltinPath') then
    reaper.MB('Для работы скрипта требуется расширение ReaImGui.\nУстановите его через ReaPack.', 'Ошибка ReaImGui', 0)
    return
end

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'

-- Параметры скрипта / GUI
local ctx = ImGui.CreateContext('Kontakt MIDI Router Multi')
local FONT_TITLE = nil

local config = {
    track_count = 16,
    start_channel = 1,
    midi_all = false, -- Чекбокс MIDI ALL (по умолчанию выключен)
    prefix_name = "MIDI Ch ",
    placement = 1, -- 0: Перед целевым треком, 1: После целевого трека, 2: В конец проекта
    disable_master_send = true,
    set_midi_input = true,
    arm_tracks = false,
    color_tracks = true
}

local placement_options = {
    "Перед выбранным треком",
    "После выбранного трека",
    "В конец проекта"
}

-- Генерация цвета HSV -> RGB
local function HSVtoRGB(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local m = i % 6
    if m == 0 then r, g, b = v, t, p
    elseif m == 1 then r, g, b = q, v, p
    elseif m == 2 then r, g, b = p, v, t
    elseif m == 3 then r, g, b = p, q, v
    elseif m == 4 then r, g, b = t, p, v
    elseif m == 5 then r, g, b = v, p, q
    end
    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

-- Основная функция создания и маршрутизации
local function CreateAndRouteTracks()
    local target_track = reaper.GetSelectedTrack(0, 0)
    if not target_track then
        reaper.MB("Пожалуйста, сначала выберите целевой трек (например, Kontakt/Vsti инструмент)!", "Целевой трек не выбран", 0)
        return false
    end

    local _, target_name = reaper.GetTrackName(target_track)
    local target_track_idx = reaper.CSurf_TrackToID(target_track, false) -- 1-based index

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    -- Определение позиции вставки
    local insert_idx
    if config.placement == 0 then
        insert_idx = target_track_idx - 1 -- Перед целевым треком
    elseif config.placement == 1 then
        insert_idx = target_track_idx -- После целевого трека
    else
        insert_idx = reaper.CountTracks(0) -- В конец
    end

    local created_tracks = {}

    for i = 1, config.track_count do
        local midi_chan
        if config.midi_all then
            midi_chan = 0 -- All Channels
        else
            midi_chan = config.start_channel + (i - 1)
            if midi_chan > 16 then
                midi_chan = ((midi_chan - 1) % 16) + 1
            end
        end

        local current_insert_pos = insert_idx + (i - 1)
        reaper.InsertTrackAtIndex(current_insert_pos, true)
        local new_track = reaper.GetTrack(0, current_insert_pos)
        table.insert(created_tracks, new_track)

        -- Имя трека
        local track_name
        if config.midi_all then
            track_name = string.format("%s%02d (All)", config.prefix_name, i)
        else
            track_name = string.format("%s%02d", config.prefix_name, midi_chan)
        end
        reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", track_name, true)

        -- Отключение Master/Parent Send (для чистых MIDI дорожек)
        if config.disable_master_send then
            reaper.SetMediaTrackInfo_Value(new_track, "B_MAINSEND", 0)
        end

        -- Вход MIDI: Все входы -> соответствующий канал или All
        if config.set_midi_input then
            -- 4096 = 0x1000 (MIDI input). Канал: 0 = All channels, 1-16 = Ch 1-16
            local input_code = 4096 | (63 << 5) | midi_chan
            reaper.SetMediaTrackInfo_Value(new_track, "I_RECINPUT", input_code)
        end

        -- Запись ARM
        if config.arm_tracks then
            reaper.SetMediaTrackInfo_Value(new_track, "I_RECARM", 1)
        end

        -- Окраска треков
        if config.color_tracks then
            local hue
            if config.midi_all then
                hue = ((i - 1) / math.max(config.track_count, 1))
            else
                hue = ((midi_chan - 1) / 16)
            end
            local r, g, b = HSVtoRGB(hue, 0.65, 0.85)
            local native_color = reaper.ColorToNative(r, g, b) | 0x1000000
            reaper.SetTrackColor(new_track, native_color)
        end

        -- Создание Send на целевой трек
        local send_idx = reaper.CreateTrackSend(new_track, target_track)
        if send_idx >= 0 then
            -- Audio None: I_SRCCHAN = -1
            reaper.SetTrackSendInfo_Value(new_track, 0, send_idx, "I_SRCCHAN", -1)

            -- MIDI: Source Channel -> Destination Channel
            -- В REAPER I_MIDIFLAG: (src_chan & 31) | ((dst_chan & 31) << 5)
            -- 0 = All -> All
            local midi_flag = (midi_chan & 31) | ((midi_chan & 31) << 5)
            reaper.SetTrackSendInfo_Value(new_track, 0, send_idx, "I_MIDIFLAG", midi_flag)

            -- Установка через SWS API при наличии
            if reaper.BR_GetSetTrackSendInfo then
                reaper.BR_GetSetTrackSendInfo(new_track, 0, send_idx, "I_MIDI_SRCCHAN", 1, midi_chan)
                reaper.BR_GetSetTrackSendInfo(new_track, 0, send_idx, "I_MIDI_DSTCHAN", 1, midi_chan)
                reaper.BR_GetSetTrackSendInfo(new_track, 0, send_idx, "I_MIDI_SRCBUS", 1, 0)
                reaper.BR_GetSetTrackSendInfo(new_track, 0, send_idx, "I_MIDI_DSTBUS", 1, 0)
            end
        end
    end

    -- Выделяем созданные треки
    reaper.SetOnlyTrackSelected(target_track)
    for _, tr in ipairs(created_tracks) do
        reaper.SetTrackSelected(tr, true)
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Create MIDI tracks with sends to " .. target_name, -1)
    return true
end

-- Главный цикл отрисовки GUI
local function GuiLoop()
    ImGui.SetNextWindowSize(ctx, 420, 420, ImGui.Cond_FirstUseEver)
    local visible, open = ImGui.Begin(ctx, 'Kontakt MIDI In Router Multi v1.0.0', true, ImGui.WindowFlags_NoCollapse)
    
    if visible then
        -- Информация о целевом треке
        local sel_track = reaper.GetSelectedTrack(0, 0)
        if sel_track then
            local _, track_name = reaper.GetTrackName(sel_track)
            local track_num = math.floor(reaper.GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER"))
            ImGui.TextColored(ctx, 0x44FF88FF, string.format("Целевой трек: [#%d] %s", track_num, track_name))
        else
            ImGui.TextColored(ctx, 0xFF5555FF, "Внимание: выделите целевой трек в проекте!")
        end
        
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        -- Настройки количества дорожек и каналов
        local changed_cnt, val_cnt = ImGui.SliderInt(ctx, "Количество треков", config.track_count, 1, 16)
        if changed_cnt then config.track_count = val_cnt end

        local chk_all, val_all = ImGui.Checkbox(ctx, "MIDI ALL (на всех дорожках All -> All)", config.midi_all)
        if chk_all then config.midi_all = val_all end

        if config.midi_all then
            ImGui.BeginDisabled(ctx)
        end
        local changed_ch, val_ch = ImGui.SliderInt(ctx, "Стартовый MIDI канал", config.start_channel, 1, 16)
        if changed_ch then config.start_channel = val_ch end
        if config.midi_all then
            ImGui.EndDisabled(ctx)
        end

        local changed_name, val_name = ImGui.InputText(ctx, "Префикс имени трека", config.prefix_name)
        if changed_name then config.prefix_name = val_name end

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        -- Расположение треков
        ImGui.Text(ctx, "Расположение новых треков:")
        if ImGui.BeginCombo(ctx, "##placement", placement_options[config.placement + 1]) then
            for i, opt in ipairs(placement_options) do
                local is_selected = (config.placement == (i - 1))
                if ImGui.Selectable(ctx, opt, is_selected) then
                    config.placement = i - 1
                end
            end
            ImGui.EndCombo(ctx)
        end

        ImGui.Spacing(ctx)

        -- Дополнительные параметры
        local chk_ms, val_ms = ImGui.Checkbox(ctx, "Отключить Master/Parent Send на новых треках", config.disable_master_send)
        if chk_ms then config.disable_master_send = val_ms end

        local chk_in, val_in = ImGui.Checkbox(ctx, "Установить MIDI Input на соответствующий канал", config.set_midi_input)
        if chk_in then config.set_midi_input = val_in end

        local chk_col, val_col = ImGui.Checkbox(ctx, "Раскрасить треки по цветам MIDI каналов", config.color_tracks)
        if chk_col then config.color_tracks = val_col end

        local chk_arm, val_arm = ImGui.Checkbox(ctx, "Включить запись (Record ARM) на новых треках", config.arm_tracks)
        if chk_arm then config.arm_tracks = val_arm end

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        -- Кнопка создания
        local can_create = (sel_track ~= nil)
        if not can_create then
            ImGui.BeginDisabled(ctx)
        end

        if ImGui.Button(ctx, " Создать MIDI треки и настроить посылы ", -1, 40) then
            CreateAndRouteTracks()
        end

        if not can_create then
            ImGui.EndDisabled(ctx)
        end

        ImGui.End(ctx)
    end

    if open then
        reaper.defer(GuiLoop)
    end
end

-- Старт
reaper.defer(GuiLoop)
