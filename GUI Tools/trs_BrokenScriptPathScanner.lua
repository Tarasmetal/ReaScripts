-- @description Broken Script Path Scanner
-- @author Taras Umanskiy
-- @version 1.6.1
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about Скрипт для сканирования Action List и поиска битых скриптов с нерабочими путями с возможностью их удаления.
-- @changelog
--   + Changed: "Fix Errors" button color changed to dark green for better readability
--   + Added: Fix Errors button to remove broken scripts from reaper-kb.ini
--   + Added: Automatic backup of reaper-kb.ini before fixing
--   + Initial release
--   + Added right-click functionality to open Action List and copy Command ID
--   + Fixed: Corrected Action List command ID (was 40060, now 40605)
--   + Changed: Right-click now copies filename only (without path)
--   + Added: Auto-insert filename into Action List filter (requires JS_ReaScriptAPI)

-- 🤖 REAPER — Broken Script Path Scanner

local ctx = reaper.ImGui_CreateContext('BrokenScriptPathScanner')
local WINDOW_FLAGS = reaper.ImGui_WindowFlags_MenuBar()
local SCRIPT_NAME = "Broken Script Path Scanner"

-- Настройки шрифтов и цветов
local FONT_SIZE = 14
local COLOR_RED = 0xFF0000FF
local COLOR_GREEN = 0x00FF00FF
local COLOR_GREEN_DARK = 0x2E7D32FF
local COLOR_YELLOW = 0xFFFF00FF

-- Переменные для хранения данных
local broken_scripts = {}
local is_scanning = false
local scan_complete = false
local error_msg = ""
local fix_msg = ""

-- Функция проверки существования файла
local function file_exists(name)
    if reaper.file_exists then
        return reaper.file_exists(name)
    end
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

-- Функция копирования файла
local function copy_file(src, dst)
    local input = io.open(src, "rb")
    if not input then return false end
    local content = input:read("*a")
    input:close()

    local output = io.open(dst, "wb")
    if not output then return false end
    output:write(content)
    output:close()
    return true
end

-- Функция установки фильтра в Action List (требуется JS_ReaScriptAPI)
local function SetActionListFilter(text)
    if not reaper.JS_Window_Find then
        reaper.ShowConsoleMsg("Для авто-вставки фильтра установите расширение JS_ReaScriptAPI (через ReaPack).\n")
        return
    end

    -- Находим окно Action List
    local title = reaper.JS_Localize("Actions", "common")
    local hwnd = reaper.JS_Window_Find(title, true)

    if not hwnd then return end

    -- Пытаемся найти поле ввода фильтра (обычно ID 1324 на Windows)
    local filter_hwnd = reaper.JS_Window_FindChildByID(hwnd, 1324)

    -- Если по ID не нашли, ищем первый дочерний элемент класса Edit
    if not filter_hwnd then
        local arr = reaper.new_array({}, 100)
        reaper.JS_Window_ArrayAllChild(hwnd, arr)
        local childs = arr.table()
        for i=1, #childs do
            local child = reaper.JS_Window_HandleFromAddress(childs[i])
            if reaper.JS_Window_GetClassName(child) == "Edit" then
                filter_hwnd = child
                break
            end
        end
    end

    if filter_hwnd then
        reaper.JS_Window_SetTitle(filter_hwnd, text)
        reaper.JS_Window_SetFocus(filter_hwnd)
        -- Симулируем ввод для обновления списка (Пробел + Backspace)
        reaper.JS_WindowMessage_Post(filter_hwnd, "WM_KEYDOWN", 0x20, 0,0,0)
        reaper.JS_WindowMessage_Post(filter_hwnd, "WM_KEYUP", 0x20, 0,0,0)
        reaper.JS_WindowMessage_Post(filter_hwnd, "WM_KEYDOWN", 0x08, 0,0,0)
        reaper.JS_WindowMessage_Post(filter_hwnd, "WM_KEYUP", 0x08, 0,0,0)
    end
end

-- Основная функция сканирования
local function ScanForBrokenScripts()
    is_scanning = true
    scan_complete = false
    broken_scripts = {}
    error_msg = ""
    fix_msg = ""

    local resource_path = reaper.GetResourcePath()
    local kb_ini_path = resource_path .. "/reaper-kb.ini"

    if not file_exists(kb_ini_path) then
        error_msg = "Не найден файл reaper-kb.ini"
        is_scanning = false
        return
    end

    local file = io.open(kb_ini_path, "r")
    if not file then
        error_msg = "Не удалось открыть reaper-kb.ini"
        is_scanning = false
        return
    end

    -- Паттерн для парсинга строки SCR
    -- Формат: SCR <flags> <flags> "command_id" "description" "filename"
    -- Пример: SCR 4 0 RS7d3c_... "Custom: script name" "Scripts/MyScript.lua"
    -- Упрощенный парсинг с учетом кавычек

    for line in file:lines() do
        -- Ищем строки, начинающиеся с SCR (скрипты)
        if line:match("^SCR") then
            local parts = {}
            for part in line:gmatch('%b""') do
                table.insert(parts, part:sub(2, -2)) -- Удаляем кавычки
            end

            local cmd_id, name, path

            -- Вариант 1: 3 и более строки в кавычках (ID в кавычках, например Custom Action)
            if #parts >= 3 then
                cmd_id = parts[#parts-2]
                name = parts[#parts-1]
                path = parts[#parts]
            -- Вариант 2: 2 строки в кавычках (ID без кавычек, стандартный ReaScript)
            elseif #parts == 2 then
                name = parts[1]
                path = parts[2]
                -- Извлекаем ID из части строки до первой кавычки
                local pre_quote = line:sub(1, (line:find('"') or 1) - 1)
                local tokens = {}
                for token in pre_quote:gmatch("%S+") do
                    table.insert(tokens, token)
                end
                cmd_id = tokens[#tokens] -- Обычно последний токен перед строками
            end

            if cmd_id and name and path then
                -- Нормализуем разделители для корректной проверки
                path = path:gsub("\\", "/")
                local resource_path_norm = resource_path:gsub("\\", "/")

                local full_path = path
                local exists = false

                -- Проверка пути
                if path:match("^[a-zA-Z]:") or path:match("^/") then
                    -- Абсолютный путь
                    exists = file_exists(path)
                else
                    -- Относительный путь
                    local try_paths = {
                        resource_path_norm .. "/" .. path,
                        resource_path_norm .. "/Scripts/" .. path
                    }

                    for _, p in ipairs(try_paths) do
                        if file_exists(p) then
                            full_path = p
                            exists = true
                            break
                        end
                    end

                    if not exists then
                        full_path = resource_path_norm .. "/" .. path -- Дефолтный путь для отчета
                    end
                end

                if not exists then
                    table.insert(broken_scripts, {
                        id = "_" .. cmd_id, -- Добавляем underscore для вызова экшена из API
                        raw_id = cmd_id, -- Сохраняем "сырой" ID для последующего удаления
                        name = name,
                        path = path,
                        full_path = full_path
                    })
                end
            end
        end
    end

    file:close()
    is_scanning = false
    scan_complete = true
end

-- Функция исправления ошибок (удаление битых ссылок)
local function FixBrokenScripts()
    if #broken_scripts == 0 then return end

    local resource_path = reaper.GetResourcePath()
    local kb_ini_path = resource_path .. "/reaper-kb.ini"

    -- 1. Создание резервной копии
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_path = kb_ini_path .. ".backup_" .. timestamp
    
    if not copy_file(kb_ini_path, backup_path) then
        error_msg = "Не удалось создать резервную копию reaper-kb.ini. Операция отменена."
        return
    end

    -- 2. Подготовка списка ID для удаления
    local ids_to_delete = {}
    for _, script in ipairs(broken_scripts) do
        ids_to_delete[script.raw_id] = true
    end

    -- 3. Чтение и фильтрация
    local lines = {}
    local file = io.open(kb_ini_path, "r")
    if not file then
        error_msg = "Не удалось открыть reaper-kb.ini для записи."
        return
    end

    local deleted_count = 0

    for line in file:lines() do
        local keep = true
        if line:match("^SCR") then
            -- Парсинг для извлечения ID (аналогично ScanForBrokenScripts)
            local parts = {}
            for part in line:gmatch('%b""') do
                table.insert(parts, part:sub(2, -2))
            end

            local cmd_id
            if #parts >= 3 then
                cmd_id = parts[#parts-2]
            elseif #parts == 2 then
                local pre_quote = line:sub(1, (line:find('"') or 1) - 1)
                local tokens = {}
                for token in pre_quote:gmatch("%S+") do
                    table.insert(tokens, token)
                end
                cmd_id = tokens[#tokens]
            end

            if cmd_id and ids_to_delete[cmd_id] then
                keep = false
                deleted_count = deleted_count + 1
            end
        end

        if keep then
            table.insert(lines, line)
        end
    end
    file:close()

    -- 4. Запись отфильтрованного содержимого
    file = io.open(kb_ini_path, "w")
    if not file then
        error_msg = "Ошибка при записи в reaper-kb.ini."
        return
    end

    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()

    -- 5. Завершение
    fix_msg = string.format("Удалено %d записей.\nБэкап создан: %s", deleted_count, backup_path:match("([^/]+)$"))
    
    -- Перезагрузка списка (должен стать пустым)
    reaper.defer(ScanForBrokenScripts)
end

-- Отрисовка GUI
local function loop()
    local visible, open = reaper.ImGui_Begin(ctx, SCRIPT_NAME, true, WINDOW_FLAGS)

    if visible then

        -- Меню бар
        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Меню') then
                if reaper.ImGui_MenuItem(ctx, 'Сканировать') then
                    ScanForBrokenScripts()
                end
                reaper.ImGui_Separator(ctx)
                if reaper.ImGui_MenuItem(ctx, 'Закрыть') then
                    open = false
                end
                reaper.ImGui_EndMenu(ctx)
            end
            reaper.ImGui_EndMenuBar(ctx)
        end

        -- Основной контент
        if reaper.ImGui_Button(ctx, "Сканировать Action List") then
            ScanForBrokenScripts()
        end

        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, is_scanning and "Сканирование..." or (scan_complete and "Сканирование завершено." or "Нажмите сканировать."))

        -- Кнопка "Fix Errors"
        if scan_complete and #broken_scripts > 0 then
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR_GREEN_DARK)
            if reaper.ImGui_Button(ctx, "Исправить ошибки (" .. #broken_scripts .. ")") then
                local retval = reaper.MB("Вы уверены, что хотите удалить эти скрипты из Action List?\nБудет создана резервная копия reaper-kb.ini.", "Подтверждение", 4)
                if retval == 6 then -- 6 = Yes
                    FixBrokenScripts()
                end
            end
            reaper.ImGui_PopStyleColor(ctx)
        end

        if error_msg ~= "" then
            reaper.ImGui_TextColored(ctx, COLOR_RED, "Ошибка: " .. error_msg)
        end

        if fix_msg ~= "" then
            reaper.ImGui_TextColored(ctx, COLOR_GREEN, fix_msg)
        end

        reaper.ImGui_Separator(ctx)

        if scan_complete then
            reaper.ImGui_Text(ctx, "Найдено нерабочих скриптов: " .. #broken_scripts)

            if #broken_scripts > 0 then
                -- Таблица результатов
                if reaper.ImGui_BeginTable(ctx, 'BrokenScriptsTable', 3, reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_RowBg() | reaper.ImGui_TableFlags_Resizable()) then

                    reaper.ImGui_TableSetupColumn(ctx, 'Command ID')
                    reaper.ImGui_TableSetupColumn(ctx, 'Имя скрипта')
                    reaper.ImGui_TableSetupColumn(ctx, 'Путь к файлу')
                    reaper.ImGui_TableHeadersRow(ctx)

                    for i, script in ipairs(broken_scripts) do
                        reaper.ImGui_TableNextRow(ctx)

                        reaper.ImGui_TableSetColumnIndex(ctx, 0)
                        reaper.ImGui_Text(ctx, script.id)

                        if reaper.ImGui_IsItemHovered(ctx) then
                            reaper.ImGui_SetTooltip(ctx, "ПКМ: Найти в Action List (Фильтр будет установлен автоматически)")
                        end

                        if reaper.ImGui_IsItemClicked(ctx, 1) then
                            local filename = script.path:match("([^/]+)$") or script.path
                            reaper.ImGui_SetClipboardText(ctx, filename)
                            reaper.Main_OnCommand(40605, 0) -- View: Show action list

                            -- Пытаемся вставить текст в фильтр
                            reaper.defer(function() SetActionListFilter(filename) end)
                        end

                        if reaper.ImGui_IsItemClicked(ctx) then
                            reaper.ShowConsoleMsg("ID: " .. script.id .. "\n")
                        end

                        reaper.ImGui_TableSetColumnIndex(ctx, 1)
                        reaper.ImGui_Text(ctx, script.name)

                        reaper.ImGui_TableSetColumnIndex(ctx, 2)
                        reaper.ImGui_TextColored(ctx, COLOR_RED, script.path)
                        if reaper.ImGui_IsItemHovered(ctx) then
                            reaper.ImGui_SetTooltip(ctx, "Полный путь (ожидаемый): " .. script.full_path)
                        end
                    end

                    reaper.ImGui_EndTable(ctx)
                end
            else
                 reaper.ImGui_TextColored(ctx, COLOR_GREEN, "Все скрипты найдены на своих местах!")
            end
        end

        reaper.ImGui_End(ctx)
    end

    if open then
        reaper.defer(loop)
    end
end

-- Запуск скрипта
reaper.defer(loop)