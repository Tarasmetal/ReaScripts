-- @description Track Color Auto Loader & Gradients
-- @author Taras Umanskiy
-- @version 1.8
-- @provides [main] .
--   [script] trs_Track color auto loader.txt
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about Скрипт для автоматической окраски треков по имени и создания градиентов для папок (поддержка 2 и 3 цветов).
-- @changelog
--   + Added support for 3-color gradients for Folder rules (Start-Mid-End)
--   + UI: Added ability to add/remove 3rd color for folders via context menu or button
--   + Added 'RUN_WITHOUT_GUI' flag to allow running script in headless mode (apply colors and exit)
--   + Fix: Allow loading rules with empty patterns (names)
--   + Added 'Receive' rule type (colors track based on source track name of receives)
--   + Feature: Right-click on color palette to copy selected track color
--   + Improvement: Folder tracks can now use Suffix/Prefix rules for their own color while maintaining gradients for children
--   + Added 'Folder' rule type for folder gradients
--   + Added secondary color support for gradients
--   + Added Save As and Load Preset functionality
--   + Fix: Prevent child tracks from being overwritten by other rules
--   + Code optimizations

local r = reaper
local version = 1.8
local RUN_WITHOUT_GUI = fasle -- Set to true to apply colors and exit without opening GUI

local script_name = "Track Color Auto Loader & Gradients by Taras Umanskiy v." .. version
local script_path = debug.getinfo(1,'S').source:sub(2):match('(.*[/\\])') or ''
local default_config_file = script_path .. 'trs_Track color auto loader.txt'
local current_config_file = default_config_file

-- Проверка наличия ReaImGui
if not r.APIExists('ImGui_GetVersion') then
  r.ShowMessageBox('ReaImGui extension is required', 'Error', 0)
  return
end

local ctx = r.ImGui_CreateContext(script_name)
local font_size = r.GetAppVersion():match('Win64') and 12 or 14
local font = r.ImGui_CreateFont('sans-serif', font_size)
r.ImGui_Attach(ctx, font)

-- Данные
local rules = {}
local is_modified = false
local status_msg = ""
local status_time = 0

-- --- Функции работы с цветом ---

-- Функция для преобразования RGB в Native Color (OS dependent)
local function rgbToNative(rgb_color)
    local r_val = (rgb_color >> 16) & 0xFF
    local g_val = (rgb_color >> 8) & 0xFF
    local b_val = rgb_color & 0xFF
    local native = r.ColorToNative(r_val, g_val, b_val)
    if native == 0 then native = 0x1000000 end
    return native
end

-- Интерполяция цвета для градиента
local function interpolateColor(c1, c2, factor)
    local r1 = (c1 >> 16) & 0xFF
    local g1 = (c1 >> 8) & 0xFF
    local b1 = c1 & 0xFF

    local r2 = (c2 >> 16) & 0xFF
    local g2 = (c2 >> 8) & 0xFF
    local b2 = c2 & 0xFF

    local r_res = math.floor(r1 + (r2 - r1) * factor)
    local g_res = math.floor(g1 + (g2 - g1) * factor)
    local b_res = math.floor(b1 + (b2 - b1) * factor)

    return (r_res << 16) | (g_res << 8) | b_res
end

-- --- Функции работы с файлом ---

local function extractFileName(path)
    return path:match("^.+[\\/](.+)$") or path
end

-- Загрузка правил из файла
local function loadRules(filepath)
    local target_file = filepath or current_config_file

    local file = io.open(target_file, 'r')
    if not file then
        if filepath then
             r.ShowMessageBox("Файл не найден:\n" .. filepath, "Ошибка", 0)
        else
             status_msg = "Файл конфигурации не найден, создан новый список."
             status_time = r.time_precise()
        end
        return
    end

    rules = {}
    for line in file:lines() do
        line = line:gsub('%s+', ' ')
        -- Парсинг строки: type,pattern,color1[-color2][-color3]
        local prefix, pattern, color_str = line:match('([psfr]),([^,]*),([%w%-x]+)')
        if prefix and pattern and color_str then
            local colors = {}
            for c in color_str:gmatch("0x%x+") do
                table.insert(colors, tonumber(c))
            end

            table.insert(rules, {
                prefix = prefix,
                pattern = pattern,
                color = colors[1] or 0xFFFFFF,
                color2 = colors[2], -- Может быть nil, если не указан
                color3 = colors[3]  -- Может быть nil, если не указан
            })
        end
    end
    file:close()

    current_config_file = target_file
    is_modified = false
    status_msg = "Загружено: " .. extractFileName(current_config_file)
    status_time = r.time_precise()
end

-- Сохранение правил в файл
local function saveRules(filepath)
    local target_file = filepath or current_config_file

    local file = io.open(target_file, 'w')
    if not file then
        r.ShowMessageBox("Не удалось открыть файл для записи:\n" .. target_file, "Ошибка", 0)
        return
    end

    for _, rule in ipairs(rules) do
        local color_str = string.format("0x%06X", rule.color)
        -- Добавляем дополнительные цвета для градиентов папок, если они заданы
        if rule.prefix == 'f' then
            if rule.color2 then
                color_str = color_str .. string.format("-0x%06X", rule.color2)
            end
            if rule.color3 then
                color_str = color_str .. string.format("-0x%06X", rule.color3)
            end
        end
        file:write(string.format("%s,%s,%s\n", rule.prefix, rule.pattern, color_str))
    end
    file:close()

    current_config_file = target_file
    is_modified = false
    status_msg = "Сохранено: " .. extractFileName(current_config_file)
    status_time = r.time_precise()
end

local function saveAs()
    local initial_folder = current_config_file:match('(.*[/\\])') or script_path

    if r.APIExists('JS_Dialog_BrowseForSaveFile') then
        local retval, file = r.JS_Dialog_BrowseForSaveFile("Save Preset As", initial_folder, "preset.txt", "Text files (.txt)\0*.txt\0All files (*.*)\0*.*\0")
        if retval and file ~= "" then
            if not file:match("%.txt$") then file = file .. ".txt" end
            saveRules(file)
        end
    else
        local retval, user_input = r.GetUserInputs("Save Preset As", 1, "File Name:", "")
        if retval and user_input ~= "" then
            if not user_input:match("%.txt$") then user_input = user_input .. ".txt" end
            local new_path
            if user_input:match("[\\/]") then
                new_path = user_input
            else
                new_path = script_path .. user_input
            end
            saveRules(new_path)
        end
    end
end

local function openPreset()
    local initial_folder = current_config_file:match('(.*[/\\])') or script_path
    local retval, file = r.GetUserFileNameForRead(initial_folder, "Open Preset", "txt")
    if retval then
        loadRules(file)
    end
end

local function getSelectedTrackColor()
    local track = r.GetSelectedTrack(0, 0)
    if track then
        local native_color = r.GetTrackColor(track)
        if native_color and native_color ~= 0 then
            local r_val, g_val, b_val = r.ColorFromNative(native_color)
            return (r_val << 16) | (g_val << 8) | b_val
        end
    end
    return nil
end

-- --- Функция применения цветов ---
local function applyColors()
    if is_modified then
        saveRules()
    end

    r.Undo_BeginBlock()
    local count_tracks = r.CountTracks(0)
    local processed_tracks = {} -- Таблица для отслеживания обработанных треков

    for i = 0, count_tracks - 1 do
        local track = r.GetTrack(0, i)
        if track and not processed_tracks[track] then
            local _, track_name = r.GetTrackName(track, '')
            track_name = track_name:lower()

            -- Поиск правил: отдельно для цвета самого трека (S/P) и для градиента (F)
            local found_sp_rule = nil
            local found_f_rule = nil

            for _, rule in ipairs(rules) do
                local pat = rule.pattern:lower()

                if rule.prefix == 'f' then
                    -- Для папки ищем первое совпадение для градиента
                    if not found_f_rule then
                        local is_folder = r.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH') == 1
                        if is_folder and track_name:find(pat, 1, true) then
                            found_f_rule = rule
                        end
                    end
                elseif rule.prefix == 'p' then
                    -- Ищем первое совпадение Prefix
                    if not found_sp_rule and track_name:find(pat, 1, true) == 1 then
                        found_sp_rule = rule
                    end
                elseif rule.prefix == 's' then
                    -- Ищем первое совпадение Suffix
                    if not found_sp_rule and track_name:sub(-pat:len()) == pat then
                        found_sp_rule = rule
                    end
                elseif rule.prefix == 'r' then
                    -- Ищем первое совпадение по Receive (имя трека-источника)
                    if not found_sp_rule then
                        local num_receives = r.GetTrackNumSends(track, -1)
                        for rc = 0, num_receives - 1 do
                            local src_track = r.GetTrackSendInfo_Value(track, -1, rc, "P_SRCTRACK")
                            if src_track then
                                local retval, src_name = r.GetTrackName(src_track)
                                if retval and src_name:lower():find(pat, 1, true) then
                                    found_sp_rule = rule
                                    break
                                end
                            end
                        end
                    end
                end

                if found_sp_rule and found_f_rule then break end
            end

            -- 1. Применяем цвет к самому треку
            -- Приоритет: Prefix/Suffix > Folder Rule (Start Color)
            local self_rule = found_sp_rule or found_f_rule
            if self_rule then
                r.SetTrackColor(track, rgbToNative(self_rule.color))
            end

            -- 2. Если трек - папка с правилом F, применяем градиент к детям
            if found_f_rule then
                local parent_depth = r.GetTrackDepth(track)
                local child_idx = i + 1
                local children = {}

                -- Собираем всех прямых и вложенных детей до конца папки
                while child_idx < count_tracks do
                    local child_track = r.GetTrack(0, child_idx)
                    local child_depth = r.GetTrackDepth(child_track)
                    if child_depth <= parent_depth then break end
                    table.insert(children, child_track)
                    child_idx = child_idx + 1
                end

                local num_children = #children
                if num_children > 0 then
                    local c1 = found_f_rule.color
                    local c2 = found_f_rule.color2 or found_f_rule.color
                    local c3 = found_f_rule.color3 -- Опциональный 3-й цвет

                    for k, child in ipairs(children) do
                        local factor = 0
                        if num_children > 1 then
                            factor = (k - 1) / (num_children - 1)
                        end

                        local final_color
                        if c3 then
                            -- 3-точечный градиент (Start -> Mid -> End)
                            if factor <= 0.5 then
                                -- Первая половина: интерполяция от c1 к c2
                                final_color = interpolateColor(c1, c2, factor * 2)
                            else
                                -- Вторая половина: интерполяция от c2 к c3
                                final_color = interpolateColor(c2, c3, (factor - 0.5) * 2)
                            end
                        else
                            -- 2-точечный градиент (Start -> End)
                            final_color = interpolateColor(c1, c2, factor)
                        end

                        r.SetTrackColor(child, rgbToNative(final_color))
                        processed_tracks[child] = true
                    end
                end
            end
        end
    end
    r.UpdateArrange()
    r.Undo_EndBlock("Auto Color Tracks", -1)
    status_msg = "Цвета применены к трекам."
    status_time = r.time_precise()
end

-- --- UI Loop ---

local function loop()
    local window_flags = r.ImGui_WindowFlags_MenuBar()
    r.ImGui_SetNextWindowSize(ctx, 750, 400, r.ImGui_Cond_FirstUseEver()) -- Увеличил ширину для 3 цветов

    local visible, open = r.ImGui_Begin(ctx, script_name, true, window_flags)

    if visible then
        -- Меню бар
        if r.ImGui_BeginMenuBar(ctx) then
            if r.ImGui_BeginMenu(ctx, "File") then
                if r.ImGui_MenuItem(ctx, "Open Preset...", "Ctrl+O") then
                    openPreset()
                end
                if r.ImGui_MenuItem(ctx, "Save", "Ctrl+S") then
                    saveRules()
                end
                if r.ImGui_MenuItem(ctx, "Save As...", "Ctrl+Shift+S") then
                    saveAs()
                end
                r.ImGui_Separator(ctx)
                if r.ImGui_MenuItem(ctx, "Reload Current") then
                    loadRules()
                end
                r.ImGui_EndMenu(ctx)
            end
            r.ImGui_EndMenuBar(ctx)
        end

        -- Горячие клавиши
        if r.ImGui_IsWindowFocused(ctx) then
            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_O()) and r.ImGui_IsKeyDown(ctx, r.ImGui_Mod_Ctrl()) then
                openPreset()
            end
            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_S()) and r.ImGui_IsKeyDown(ctx, r.ImGui_Mod_Ctrl()) then
                if r.ImGui_IsKeyDown(ctx, r.ImGui_Mod_Shift()) then
                    saveAs()
                else
                    saveRules()
                end
            end
        end

        -- Верхняя панель
        if r.ImGui_Button(ctx, "Add Rule") then
            table.insert(rules, { prefix = 'p', pattern = "new", color = 0xFFFFFF, color2 = 0x000000 })
            is_modified = true
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, "Save Config") then
            saveRules()
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, "Run / Apply Colors") then
            applyColors()
        end

        r.ImGui_Separator(ctx)

        -- Таблица правил
        local table_flags = r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_RowBg() | r.ImGui_TableFlags_Resizable()
        if r.ImGui_BeginTable(ctx, "RulesTable", 4, table_flags) then
            r.ImGui_TableSetupColumn(ctx, "Type", r.ImGui_TableColumnFlags_WidthFixed(), 80)
            r.ImGui_TableSetupColumn(ctx, "Pattern", r.ImGui_TableColumnFlags_WidthStretch())
            -- Увеличил ширину колонки Color для 3-х цветов
            r.ImGui_TableSetupColumn(ctx, "Color (RMB Copy)", r.ImGui_TableColumnFlags_WidthFixed(), 150)
            r.ImGui_TableSetupColumn(ctx, "Action", r.ImGui_TableColumnFlags_WidthFixed(), 70)
            r.ImGui_TableHeadersRow(ctx)

            local to_remove = nil
            local move_from = nil
            local move_to = nil

            for i, rule in ipairs(rules) do
                r.ImGui_TableNextRow(ctx)
                r.ImGui_PushID(ctx, i)

                -- Column 1: Type (Prefix/Suffix/Folder)
                r.ImGui_TableSetColumnIndex(ctx, 0)
                r.ImGui_SetNextItemWidth(ctx, -1)

                local current_item = 0
                if rule.prefix == 's' then current_item = 1
                elseif rule.prefix == 'f' then current_item = 2
                elseif rule.prefix == 'r' then current_item = 3 end

                local changed, new_item = r.ImGui_Combo(ctx, "##type", current_item, "Prefix\0Suffix\0Folder\0Receive\0")
                if changed then
                    if new_item == 0 then rule.prefix = 'p'
                    elseif new_item == 1 then rule.prefix = 's'
                    elseif new_item == 2 then rule.prefix = 'f'
                    elseif new_item == 3 then rule.prefix = 'r' end

                    -- Если переключили на Folder, убедимся что color2 существует (для градиента)
                    if rule.prefix == 'f' and not rule.color2 then
                        rule.color2 = rule.color
                    end
                    is_modified = true
                end

                -- Column 2: Pattern
                r.ImGui_TableSetColumnIndex(ctx, 1)
                r.ImGui_SetNextItemWidth(ctx, -1)
                local changed_pat, new_pat = r.ImGui_InputText(ctx, "##pattern", rule.pattern)
                if changed_pat then
                    rule.pattern = new_pat
                    is_modified = true
                end

                -- Column 3: Color
                r.ImGui_TableSetColumnIndex(ctx, 2)
                local flags = r.ImGui_ColorEditFlags_NoInputs() | r.ImGui_ColorEditFlags_NoLabel() | r.ImGui_ColorEditFlags_NoOptions()

                -- Color 1
                local col_packed = (rule.color << 8) | 0xFF
                local changed_col, new_col_packed = r.ImGui_ColorEdit4(ctx, "##color1", col_packed, flags)
                if changed_col then
                    rule.color = (new_col_packed >> 8) & 0xFFFFFF
                    is_modified = true
                end
                if r.ImGui_IsItemClicked(ctx, 1) then -- Right click
                    local track_color = getSelectedTrackColor()
                    if track_color then
                        rule.color = track_color
                        is_modified = true
                    end
                end
                if r.ImGui_IsItemHovered(ctx) then
                    r.ImGui_SetTooltip(ctx, "Start Color\nRMB: Copy Selected Track Color")
                end

                -- Color 2 and 3 (only for Folder)
                if rule.prefix == 'f' then
                    r.ImGui_SameLine(ctx)
                    local col2_packed = ((rule.color2 or 0xFFFFFF) << 8) | 0xFF
                    local changed_col2, new_col2_packed = r.ImGui_ColorEdit4(ctx, "##color2", col2_packed, flags)
                    if changed_col2 then
                        rule.color2 = (new_col2_packed >> 8) & 0xFFFFFF
                        is_modified = true
                    end
                    if r.ImGui_IsItemClicked(ctx, 1) then -- Right click
                        local track_color = getSelectedTrackColor()
                        if track_color then
                            rule.color2 = track_color
                            is_modified = true
                        end
                    end
                    if r.ImGui_IsItemHovered(ctx) then
                        if rule.color3 then
                            r.ImGui_SetTooltip(ctx, "Middle Color\nRMB: Copy Selected Track Color")
                        else
                            r.ImGui_SetTooltip(ctx, "End Color\nRMB: Copy Selected Track Color")
                        end
                    end

                    r.ImGui_SameLine(ctx)
                    -- Управление 3-м цветом
                    if rule.color3 then
                        -- Если 3-й цвет активен, показываем ColorPicker
                        local col3_packed = (rule.color3 << 8) | 0xFF
                        local changed_col3, new_col3_packed = r.ImGui_ColorEdit4(ctx, "##color3", col3_packed, flags)
                        if changed_col3 then
                            rule.color3 = (new_col3_packed >> 8) & 0xFFFFFF
                            is_modified = true
                        end

                        -- Контекстное меню для удаления или копирования
                        if r.ImGui_IsItemClicked(ctx, 1) then
                             r.ImGui_OpenPopup(ctx, "context_color3")
                        end
                        if r.ImGui_IsItemHovered(ctx) then
                             r.ImGui_SetTooltip(ctx, "End Color\nRMB: Menu (Copy/Remove)")
                        end

                        if r.ImGui_BeginPopup(ctx, "context_color3") then
                            if r.ImGui_MenuItem(ctx, "Copy Selected Track Color") then
                                 local tc = getSelectedTrackColor()
                                 if tc then rule.color3 = tc; is_modified = true end
                            end
                            if r.ImGui_MenuItem(ctx, "Remove 3rd Color") then
                                rule.color3 = nil
                                is_modified = true
                            end
                            r.ImGui_EndPopup(ctx)
                        end
                    else
                        -- Если 3-го цвета нет, показываем кнопку добавления
                        if r.ImGui_Button(ctx, "+##add_c3") then
                            rule.color3 = rule.color2 or rule.color
                            is_modified = true
                        end
                        if r.ImGui_IsItemHovered(ctx) then
                             r.ImGui_SetTooltip(ctx, "Add 3rd Color point (Mid -> End)")
                        end
                    end
                end

                -- Column 4: Actions
                r.ImGui_TableSetColumnIndex(ctx, 3)

                r.ImGui_Button(ctx, "::")
                if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_SourceNoDisableHover()) then
                    r.ImGui_SetDragDropPayload(ctx, "DND_ROW", tostring(i))
                    r.ImGui_Text(ctx, "Move Rule " .. i)
                    r.ImGui_EndDragDropSource(ctx)
                end

                if r.ImGui_BeginDragDropTarget(ctx) then
                    local retval, payload = r.ImGui_AcceptDragDropPayload(ctx, "DND_ROW")
                    if retval then
                        move_from = tonumber(payload)
                        move_to = i
                    end
                    r.ImGui_EndDragDropTarget(ctx)
                end

                r.ImGui_SameLine(ctx)

                if r.ImGui_Button(ctx, "X") then
                    to_remove = i
                end

                r.ImGui_PopID(ctx)
            end
            r.ImGui_EndTable(ctx)

            if move_from and move_to and move_from ~= move_to then
                local item = table.remove(rules, move_from)
                table.insert(rules, move_to, item)
                is_modified = true
            elseif to_remove then
                table.remove(rules, to_remove)
                is_modified = true
            end
        end

        -- Статус
        if r.time_precise() - status_time < 3.0 then
             r.ImGui_TextColored(ctx, 0x00FF00FF, status_msg)
        elseif is_modified then
             r.ImGui_TextColored(ctx, 0xFFFF00FF, "Есть несохраненные изменения!")
        end

        r.ImGui_End(ctx)
    end

    if open then
        r.defer(loop)
    end
end

-- Инициализация
loadRules()

if RUN_WITHOUT_GUI then
    applyColors()
    return
end

r.defer(loop)
