-- @description Broken Script Path Scan and Fix
-- @author Taras Umanskiy
-- @version 1.8.0
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about Мощный инструмент для пользователей REAPER, который помогает поддерживать чистоту в Action List, выявляя и устраняя "битые" ссылки на скрипты.
-- @changelog
--   + Added: Все элементы интерфейса переведены на английский язык.
--   + Changed: Обновлена версия до 1.8.0.
--   + Added: Поддержка файла конфигурации reapack.ini и секции [remotes] (для портативных сборок).

local ctx = reaper.ImGui_CreateContext('BrokenScriptPathScanner')
local WINDOW_FLAGS = reaper.ImGui_WindowFlags_MenuBar()
local VERSION = "1.8.0"
local SCRIPT_NAME = "Broken Script Path Scan and Fix" .. " " .. VERSION

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
local show_repo_window = false
local unique_repos = {}

-- Функция парсинга reaper-reapack.ini для получения URL репозиториев
local function GetReaPackRepoMap()
    local repo_map = {}

    -- 1. Попытка через ReaPack API (самый надежный способ)
    if reaper.ReaPack_GetCount then
        local num_repos = reaper.ReaPack_GetCount()
        for i = 0, num_repos - 1 do
            local success, name, url = reaper.ReaPack_GetRepositoryInfo(i)
            if success and url then
                repo_map[name] = url
                repo_map[name:lower()] = url
            end
        end
    end

    -- 2. Дополнительно парсим reaper-reapack.ini и reapack.ini для получения путей папок и URL
    local resource_path = reaper.GetResourcePath()
    local ini_files = {
        resource_path .. "/reaper-reapack.ini",
        resource_path .. "/reapack.ini",
        -- "c:/REAPERMini/reapack.ini" -- Путь из запроса пользователя
    }

    for _, ini_path in ipairs(ini_files) do
        local file = io.open(ini_path, "r")
        if file then
            local current_section = ""
            for line in file:lines() do
                line = line:gsub("^%s*(.-)%s*$", "%1")
                local lower_line = line:lower()

                if lower_line:match("^%[.-%]") then
                    current_section = lower_line:match("^%[(.-)%]")
                elseif line ~= "" then
                    if current_section == "index" or current_section == "repos" then
                        -- Формат: index-1=URL FolderPath
                        local url, folder = line:match("=([^%s]+)%s+(.+)$")
                        if not url then url = line:match("=([^%s]+)$") end

                        if url then
                            if folder then
                                folder = folder:gsub('^"(.*)"$', "%1")
                                local folder_norm = folder:gsub("\\", "/"):gsub("^Scripts/", "")
                                repo_map[folder_norm:lower()] = url
                                repo_map[folder_norm] = url
                            else
                                repo_map[""] = url
                            end
                        end
                    elseif current_section == "remotes" then
                        -- Формат: remote0=Name|URL|Enabled|Flags
                        local name, url = line:match("=[^|]+|([^|]+)|") -- Ошибка в моем предположении? Нет, remote0=Name|URL|...
                        -- На самом деле в файле: remote0=ReaPack|https://reapack.com/index.xml|1|2
                        name, url = line:match("=([^|]+)|([^|]+)|")

                        if name and url then
                            repo_map[name] = url
                            repo_map[name:lower()] = url
                        end
                    end
                end
            end
            file:close()
        end
    end

    return repo_map
end

-- Функция получения списка уникальных репозиториев (теперь возвращает URL)
local function GetRepositoriesFromBrokenScripts()
    local repo_map = GetReaPackRepoMap()
    local repos = {}
    local seen = {}

    for _, script in ipairs(broken_scripts) do
        local path = script.path:gsub("\\", "/")
        local repo_url = nil
        local repo_name = nil

        -- 1. Попытка через ReaPack API (самый надежный способ)
        if reaper.ReaPack_GetOwner then
            repo_name = reaper.ReaPack_GetOwner(script.full_path)
            if repo_name and repo_name ~= "" then
                if reaper.ReaPack_GetRepositoryInfo then
                    local success, _, url = reaper.ReaPack_GetRepositoryInfo(repo_name)
                    if success then repo_url = url end
                end
            end
        end

        -- 2. Если API не помогло, извлекаем имя папки вручную
        if not repo_url then
            local folder_match = path:match("^Scripts/([^/]+)")
            if not folder_match then
                folder_match = path:match("([^/]+)/")
            end

            if folder_match then
                repo_name = folder_match
                -- Ищем в карте из INI или API (без учета регистра)
                repo_url = repo_map[repo_name] or repo_map[repo_name:lower()]

                -- Дополнительная проверка через API по имени папки
                if not repo_url and reaper.ReaPack_GetRepositoryInfo then
                    local success, _, url = reaper.ReaPack_GetRepositoryInfo(repo_name)
                    if success then repo_url = url end
                end
            end
        end

        if repo_name then
            if not repo_url then
                repo_url = "Unknown repository: " .. repo_name
            end

            if not seen[tostring(repo_url)] then
                table.insert(repos, {url = tostring(repo_url), name = tostring(repo_name)})
                seen[tostring(repo_url)] = true
            end
        end
    end

    table.sort(repos, function(a, b) return a.name < b.name end)
    return repos
end

-- Функция сохранения списка репозиториев в файл
local function SaveRepositoriesToFile(repos)
    if #repos == 0 then return end

    local path = reaper.GetResourcePath() .. "/Scripts/Broken_Repos_List.txt"
    local file = io.open(path, "w")
    if not file then
        reaper.MB("Failed to create file: " .. path, "Error", 0)
        return
    end

    file:write("-- Repository list for ReaPack import --\n")
    file:write("-- Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. " --\n\n")

    for _, repo in ipairs(repos) do
        file:write(string.format("%-20s : %s\n", repo.name, repo.url))
    end

    file:close()
    reaper.MB("Repository list saved to file:\n" .. path, "Success", 0)
end

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
        reaper.ShowConsoleMsg("To auto-insert filter, install JS_ReaScriptAPI extension (via ReaPack).\n")
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
        error_msg = "reaper-kb.ini not found"
        is_scanning = false
        return
    end

    local file = io.open(kb_ini_path, "r")
    if not file then
        error_msg = "Could not open reaper-kb.ini"
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
        error_msg = "Failed to create reaper-kb.ini backup. Operation cancelled."
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
        error_msg = "Failed to open reaper-kb.ini for writing."
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
        error_msg = "Error writing to reaper-kb.ini."
        return
    end

    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()

    -- 5. Завершение
    fix_msg = string.format("Deleted %d records.\nBackup created: %s", deleted_count, backup_path:match("([^/]+)$"))

    -- Перезагрузка списка (должен стать пустым)
    reaper.defer(ScanForBrokenScripts)
end

-- Отрисовка GUI
local function loop()
    local visible, open = reaper.ImGui_Begin(ctx, SCRIPT_NAME, true, WINDOW_FLAGS)

    if visible then

        -- Меню бар
        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Menu') then
                if reaper.ImGui_MenuItem(ctx, 'Scan') then
                    ScanForBrokenScripts()
                end
                reaper.ImGui_Separator(ctx)
                if reaper.ImGui_MenuItem(ctx, 'Close') then
                    open = false
                end
                reaper.ImGui_EndMenu(ctx)
            end
            reaper.ImGui_EndMenuBar(ctx)
        end

        -- Основной контент
        if reaper.ImGui_Button(ctx, "Scan Action List") then
            ScanForBrokenScripts()
        end

        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, is_scanning and "Scanning..." or (scan_complete and "Scan complete." or "Press scan."))

        -- Кнопка "Fix Errors"
        if scan_complete and #broken_scripts > 0 then
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR_GREEN_DARK)
            if reaper.ImGui_Button(ctx, "Fix Errors (" .. #broken_scripts .. ")") then
                local retval = reaper.MB("Are you sure you want to remove these scripts from Action List?\nA backup of reaper-kb.ini will be created.", "Confirmation", 4)
                if retval == 6 then -- 6 = Yes
                    FixBrokenScripts()
                end
            end
            reaper.ImGui_PopStyleColor(ctx)

            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Show Repository") then
                unique_repos = GetRepositoriesFromBrokenScripts()
                show_repo_window = true
            end
        end

        if error_msg ~= "" then
            reaper.ImGui_TextColored(ctx, COLOR_RED, "Error: " .. error_msg)
        end

        if fix_msg ~= "" then
            reaper.ImGui_TextColored(ctx, COLOR_GREEN, fix_msg)
        end

        reaper.ImGui_Separator(ctx)

        if scan_complete then
            reaper.ImGui_Text(ctx, "Broken scripts found: " .. #broken_scripts)

            if #broken_scripts > 0 then
                -- Таблица результатов
                if reaper.ImGui_BeginTable(ctx, 'BrokenScriptsTable', 3, reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_RowBg() | reaper.ImGui_TableFlags_Resizable()) then

                    reaper.ImGui_TableSetupColumn(ctx, 'Command ID')
                    reaper.ImGui_TableSetupColumn(ctx, 'Script Name')
                    reaper.ImGui_TableSetupColumn(ctx, 'File Path')
                    reaper.ImGui_TableHeadersRow(ctx)

                    for i, script in ipairs(broken_scripts) do
                        reaper.ImGui_TableNextRow(ctx)

                        reaper.ImGui_TableSetColumnIndex(ctx, 0)
                        reaper.ImGui_Text(ctx, script.id)

                        if reaper.ImGui_IsItemHovered(ctx) then
                            reaper.ImGui_SetTooltip(ctx, "RMB: Find in Action List (Filter will be set automatically)")
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
                            reaper.ImGui_SetTooltip(ctx, "Full path (expected): " .. script.full_path)
                        end
                    end

                    reaper.ImGui_EndTable(ctx)
                end
            else
                 reaper.ImGui_TextColored(ctx, COLOR_GREEN, "All scripts found in their places!")
            end
        end

        reaper.ImGui_End(ctx)
    end

    -- Окно списка репозиториев
    if show_repo_window then
        reaper.ImGui_SetNextWindowSize(ctx, 500, 300, reaper.ImGui_Cond_FirstUseEver())
        local repo_visible, repo_open = reaper.ImGui_Begin(ctx, 'Repository list for import', true)
        if repo_visible then
            reaper.ImGui_Text(ctx, "Repositories of broken scripts (URLs for ReaPack):")
            reaper.ImGui_Separator(ctx)

            if #unique_repos > 0 then
                if reaper.ImGui_BeginTable(ctx, 'RepoTable', 2, reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_RowBg()) then
                    reaper.ImGui_TableSetupColumn(ctx, 'Folder/Name', reaper.ImGui_TableColumnFlags_WidthFixed(), 120)
                    reaper.ImGui_TableSetupColumn(ctx, 'Repository URL')
                    reaper.ImGui_TableHeadersRow(ctx)

                    for _, repo in ipairs(unique_repos) do
                        if type(repo) == "table" then
                            reaper.ImGui_TableNextRow(ctx)

                            reaper.ImGui_TableSetColumnIndex(ctx, 0)
                            reaper.ImGui_Text(ctx, tostring(repo.name or "Unknown"))

                            reaper.ImGui_TableSetColumnIndex(ctx, 1)
                            local url = tostring(repo.url or "")
                            if url:match("^http") then
                                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLOR_GREEN)
                                reaper.ImGui_Text(ctx, url)
                                reaper.ImGui_PopStyleColor(ctx)

                                if reaper.ImGui_IsItemHovered(ctx) then
                                    reaper.ImGui_SetTooltip(ctx, "LMB: Copy URL")
                                end

                                if reaper.ImGui_IsItemClicked(ctx) then
                                    reaper.ImGui_SetClipboardText(ctx, url)
                                    reaper.MB("URL copied to clipboard:\n" .. url, "Copy", 0)
                                end
                            else
                                reaper.ImGui_Text(ctx, url)
                            end
                        end
                    end
                    reaper.ImGui_EndTable(ctx)
                end
            else
                reaper.ImGui_Text(ctx, "Repositories not defined.")
            end

            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Separator(ctx)

            if reaper.ImGui_Button(ctx, "Save list to file") then
                SaveRepositoriesToFile(unique_repos)
            end

            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Close") then
                show_repo_window = false
            end
            reaper.ImGui_End(ctx)
        end
        if not repo_open then
            show_repo_window = false
        end
    end

    if open then
        reaper.defer(loop)
    end
end

-- Запуск скрипта
reaper.defer(loop)