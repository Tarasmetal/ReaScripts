-- @description Sequential Send/Receive Channels with GUI
-- @author Taras Umanskiy
-- @version 3.1
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://vk.me/Tarasmetal
-- @about Скрипт с GUI для переназначения аудиоканалов посылов (Send) или получений (Receive) на выбранных треках последовательно (1/2->1/2, 3/4->1/2 и т.д.)
-- @changelog
--  + Changed Mode selector from Combo to Radio buttons
--  + UI improvements

-- Проверка наличия ReaImGui
if not reaper.APIExists('ImGui_GetBuiltinPath') then
    reaper.MB('Для работы этого скрипта необходимо установить расширение ReaImGui через ReaPack.', 'Ошибка', 0)
    return
end

-- Подключение ReaImGui
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'

-- Переменные состояния
local ctx = ImGui.CreateContext('Sequential Send/Receive Channels')
local script_modes = {"Send (Посылы)", "Receive (Возвраты)"}
local script_mode_idx = 0 -- 0 = Send, 1 = Receive

local send_modes = {"Post-Fader", "Pre-Fader (Post-FX)", "Pre-FX"}
local send_mode_idx = 1 -- По умолчанию Pre-Fader (Post-FX)
local auto_expand = true

-- Маппинг индексов REAPER для режимов посыла
local mode_map = {0, 3, 1} -- Post-Fader=0, Pre-Fader (Post-FX)=3, Pre-FX=1

function ProcessSendMode(track)
    local send_count = reaper.GetTrackNumSends(track, 0) -- 0 = посылы (sends)
    if send_count > 0 then
        if auto_expand then
            local required_channels = send_count * 2
            local current_channels = reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")
            if current_channels < required_channels then
                reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", required_channels)
            end
        end

        for j = 0, send_count - 1 do
            local src_chan = j * 2
            reaper.SetTrackSendInfo_Value(track, 0, j, "I_SRCCHAN", src_chan)
            reaper.SetTrackSendInfo_Value(track, 0, j, "I_DSTCHAN", 0)
            reaper.SetTrackSendInfo_Value(track, 0, j, "I_SENDMODE", mode_map[send_mode_idx + 1] or 3)
        end
    end
end

function ProcessReceiveMode(track, track_idx)
    local receive_count = reaper.GetTrackNumSends(track, -1) -- -1 = получения (receives)
    if receive_count > 0 then
        for j = 0, receive_count - 1 do
            -- Для режима Receive мы переназначаем каналы каждого входа (receive) на этом треке
            -- Согласно логике пользователя: 1-я дорожка 1/2->1/2, 2-я 3/4->1/2 и т.д.
            -- Если track_idx это индекс выделенного трека:
            local src_chan = track_idx * 2
            reaper.SetTrackSendInfo_Value(track, -1, j, "I_SRCCHAN", src_chan)
            reaper.SetTrackSendInfo_Value(track, -1, j, "I_DSTCHAN", 0)
            reaper.SetTrackSendInfo_Value(track, -1, j, "I_SENDMODE", mode_map[send_mode_idx + 1] or 3)
        end
    end
end

function MainProcess()
    local sel_track_count = reaper.CountSelectedTracks(0)
    if sel_track_count == 0 then 
        reaper.MB("Пожалуйста, выделите хотя бы одну дорожку.", "Нет выделенных дорожек", 0)
        return 
    end

    reaper.Undo_BeginBlock()

    for i = 0, sel_track_count - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        
        if script_mode_idx == 0 then
            -- Режим SEND: обрабатываем посылы внутри каждого трека
            ProcessSendMode(track)
        else
            -- Режим RECEIVE: обрабатываем получения трека в зависимости от его порядкового номера в выделении
            ProcessReceiveMode(track, i)
        end
    end

    local undo_name = script_mode_idx == 0 and "Sequential Send Channels" or "Sequential Receive Channels"
    reaper.Undo_EndBlock(undo_name, -1)
    reaper.UpdateArrange()
end

function Loop()
    local visible, open = ImGui.Begin(ctx, 'Sequential Send/Receive', true, ImGui.WindowFlags_AlwaysAutoResize)
    if visible then
        -- Выбор режима работы скрипта (Радио-кнопки)
        ImGui.Text(ctx, "Режим работы:")
        
        if ImGui.RadioButton(ctx, "Send (Посылы)", script_mode_idx == 0) then
            script_mode_idx = 0
        end
        ImGui.SameLine(ctx)
        if ImGui.RadioButton(ctx, "Receive (Возвраты)", script_mode_idx == 1) then
            script_mode_idx = 1
        end

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        ImGui.Text(ctx, "Настройки:")
        
        -- Выбор режима посыла
        if ImGui.BeginCombo(ctx, "Режим аудио", send_modes[send_mode_idx + 1]) then
            for i, mode in ipairs(send_modes) do
                local is_selected = (send_mode_idx == i - 1)
                if ImGui.Selectable(ctx, mode, is_selected) then
                    send_mode_idx = i - 1
                end
            end
            ImGui.EndCombo(ctx)
        end

        -- Чекбокс авто-расширения (только для Send режима это критично, но оставим доступным)
        local changed
        changed, auto_expand = ImGui.Checkbox(ctx, "Авто-расширение каналов трека", auto_expand)
        
        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        -- Кнопка запуска
        local btn_label = script_mode_idx == 0 and "Применить к посылам (Send)" or "Применить к получениям (Receive)"
        if ImGui.Button(ctx, btn_label, -1, 30) then
            MainProcess()
        end

        ImGui.End(ctx)
    end

    if open then
        reaper.defer(Loop)
    end
end

reaper.defer(Loop)
