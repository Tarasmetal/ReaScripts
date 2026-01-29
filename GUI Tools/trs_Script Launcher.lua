-- @description Script Launcher - File manager for launching REAPER scripts
-- @author Taras Umanskiy
-- @version 2.3
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about Файловый менеджер для запуска скриптов с превью, избранным и историей
-- @changelog
--   + Первый релиз
--   + Полнофункциональный файловый менеджер
--   + v1.1: Папки тоже можно добавлять в избранное
--   + v1.2: Добавлена возможность добавления кастомных путей в избранное
--   + v1.3: Исправлена проверка путей папок (регистронезависимая)
--   + v1.4: Папки в избранном теперь отображаются белым цветом
--   + v1.5: Настройки теперь сохраняются в .ini файл рядом со скриптом
--   + v1.6: Скрипт теперь запоминает и открывает последнюю посещенную папку
--   + v1.7: Добавлено контекстное меню для дерева папок (добавление в избранное)
--   + v1.8: Скрипты теперь запускаются без добавления в Action List (без следов)
--   + v1.9: Добавлена колонка Path в раздел Favorites
--   + v2.0: Добавлена возможность менять порядок элементов в избранном (Drag & Drop)
--   + v2.1: Добавлен чекбокс "Recursive Search" для поиска файлов во всех подпапках
--   + v2.2: Оптимизирован поиск: добавлено кеширование результатов и дебаунсинг (задержка)
--   + v2.3: Исправлено добавление кастомных путей с завершающим слэшем

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.2'

local ctx = ImGui.CreateContext('Script Launcher')
local VERSION = "2.3"
local SCRIPT_NAME = "Script Launcher "

local SCRIPT_EXTENSIONS = {
    lua = true, eel = true, py = true
}

local ICONS = {
    folder = "📁",
    folder_open = "📂",
    lua = "🌙",
    eel = "⚡",
    py = "🐍",
    script = "📜",
    favorite = "Fav",
    run = "▶️",
    edit = "✏️",
    back = "◀",
    up = "🔼",
    home = "🏠",
    search = "🔍",
    history = "🕐",
    refresh = "🔄"
}

local colors = {
    folder = 0xFFD700FF,
    lua = 0x00D4FFFF,
    eel = 0xFF9500FF,
    py = 0x3776ABFF,
    selected = 0x4A90D9FF,
    favorite = 0xFFD700FF,
    header = 0x2D5A8AFF,
    breadcrumb = 0x88AACCFF,
    size = 0x888888FF,
    date = 0x666666FF
}

local function GetResourcePath()
    return reaper.GetResourcePath()
end

local function GetScriptsPath()
    return GetResourcePath() .. "/Scripts"
end

local function GetFileExtension(filename)
    return filename:match("^.+%.(.+)$")
end

local function IsScriptFile(filename)
    local ext = GetFileExtension(filename)
    return ext and SCRIPT_EXTENSIONS[ext:lower()] or false
end

local function GetParentPath(path)
    return path:match("(.+)[\\/]")
end

local function GetFileName(path)
    return path:match("[^\\/]+$")
end

local function FormatFileSize(size)
    if size < 1024 then
        return string.format("%d B", size)
    elseif size < 1024 * 1024 then
        return string.format("%.1f KB", size / 1024)
    else
        return string.format("%.1f MB", size / (1024 * 1024))
    end
end

local function FormatDate(timestamp)
    return os.date("%Y-%m-%d %H:%M", timestamp)
end

local function GetFileInfo(filepath)
    local file = io.open(filepath, "r")
    if not file then return nil end
    local info = {
        size = 0,
        description = "",
        author = "",
        version = ""
    }
    local content = file:read("*a")
    info.size = #content
    info.description = content:match("@description%s+([^\r\n]+)") or ""
    info.author = content:match("@author%s+([^\r\n]+)") or ""
    info.version = content:match("@version%s+([^\r\n]+)") or ""
    file:close()
    return info
end

local function NormalizePath(path)
    return path:gsub("\\", "/")
end

local function IsDirectory(path)
    -- Normalize path for comparison
    path = NormalizePath(path)
    -- Remove trailing slash if present
    if path:sub(-1) == "/" then path = path:sub(1, -2) end
    
    local parent = GetParentPath(path)
    if not parent then 
        -- Check if it is a drive letter (e.g. C:)
        if path:match("^%a:$") then return true end
        return false 
    end
    
    -- Ensure parent path ends with slash if it is just a drive letter
    if parent:match("^%a:$") then parent = parent .. "/" end
    
    local dirname = GetFileName(path)
    if not dirname then return false end

    local i = 0
    repeat
        local folder = reaper.EnumerateSubdirectories(parent, i)
        if folder then
            if folder:lower() == dirname:lower() then
                return true
            end
        end
        i = i + 1
    until not folder
    return false
end

local state = {
    current_path = GetScriptsPath(),
    files = {},
    folders = {},
    selected_file = nil,
    selected_index = 0,
    search_text = "",
    favorites = {},
    show_favorites = false,
    show_history = false,
    history = {},
    run_history = {},
    history_index = 0,
    script_info = {},
    window_flags = ImGui.WindowFlags_MenuBar + ImGui.WindowFlags_AlwaysAutoResize + ImGui.WindowFlags_NoScrollbar,
    sort_by = "name",
    sort_ascending = true,
    ide_path = "",
    show_settings = false,
    tree_width = 200,
    list_height = 400,
    list_width = 600,
    show_add_custom_path_modal = false,
    custom_path_input = "",
    recursive_search = false,
    search_results = {},
    last_search_text = "",
    last_recursive_search = false,
    last_search_path = "",
    search_timer = 0,
    needs_search_update = false
}

local SCRIPT_PATH = select(2, reaper.get_action_context())
local CONFIG_FILE = SCRIPT_PATH:gsub("%.lua$", ".ini")

local function SaveConfig()
    local file = io.open(CONFIG_FILE, "w")
    if file then
        file:write("[Settings]\n")
        file:write("ide_path=" .. state.ide_path .. "\n")
        file:write("last_path=" .. state.current_path .. "\n")
        file:write("recursive_search=" .. (state.recursive_search and "1" or "0") .. "\n")
        file:write("favorites=")
        for i, fav in ipairs(state.favorites) do
            if i > 1 then file:write("|") end
            file:write(fav)
        end
        file:write("\n")
        file:write("run_history=")
        for i, h in ipairs(state.run_history) do
            if i > 1 then file:write("|") end
            file:write(h)
        end
        file:write("\n")
        file:close()
    end
end

local function LoadConfig()
    local file = io.open(CONFIG_FILE, "r")
    if file then
        for line in file:lines() do
            local key, value = line:match("^(.-)=(.*)$")
            if key then
                if key == "ide_path" then
                    state.ide_path = value
                elseif key == "last_path" then
                    if IsDirectory(value) then
                        state.current_path = value
                    end
                elseif key == "recursive_search" then
                    state.recursive_search = (value == "1")
                elseif key == "favorites" and value ~= "" then
                    state.favorites = {}
                    for fav in value:gmatch("[^|]+") do
                        table.insert(state.favorites, fav)
                    end
                elseif key == "run_history" and value ~= "" then
                    state.run_history = {}
                    for h in value:gmatch("[^|]+") do
                        table.insert(state.run_history, h)
                    end
                end
            end
        end
        file:close()
    end
end

local function IsFavorite(filepath)
    for _, fav in ipairs(state.favorites) do
        if fav == filepath then return true end
    end
    return false
end

local function ToggleFavorite(filepath)
    for i, fav in ipairs(state.favorites) do
        if fav == filepath then
            table.remove(state.favorites, i)
            SaveConfig()
            return
        end
    end
    table.insert(state.favorites, filepath)
    SaveConfig()
end

local function AddToHistory(filepath)
    for i, h in ipairs(state.run_history) do
        if h == filepath then
            table.remove(state.run_history, i)
            break
        end
    end
    table.insert(state.run_history, 1, filepath)
    if #state.run_history > 20 then
        table.remove(state.run_history)
    end
    SaveConfig()
end

local function ScanDirectory(path)
    state.files = {}
    state.folders = {}
    local i = 0
    repeat
        local file = reaper.EnumerateFiles(path, i)
        if file and IsScriptFile(file) then
            local filepath = path .. "/" .. file
            local info = GetFileInfo(filepath)
            table.insert(state.files, {
                name = file,
                path = filepath,
                info = info
            })
        end
        i = i + 1
    until not file
    i = 0
    repeat
        local folder = reaper.EnumerateSubdirectories(path, i)
        if folder then
            table.insert(state.folders, {
                name = folder,
                path = path .. "/" .. folder
            })
        end
        i = i + 1
    until not folder
    if state.sort_by == "name" then
        table.sort(state.folders, function(a, b)
            if state.sort_ascending then
                return a.name:lower() < b.name:lower()
            else
                return a.name:lower() > b.name:lower()
            end
        end)
        table.sort(state.files, function(a, b)
            if state.sort_ascending then
                return a.name:lower() < b.name:lower()
            else
                return a.name:lower() > b.name:lower()
            end
        end)
    elseif state.sort_by == "size" then
        table.sort(state.files, function(a, b)
            local size_a = a.info and a.info.size or 0
            local size_b = b.info and b.info.size or 0
            if state.sort_ascending then
                return size_a < size_b
            else
                return size_a > size_b
            end
        end)
    end
end

local function NavigateTo(path)
    if path then
        table.insert(state.history, state.current_path)
        state.history_index = #state.history
        state.current_path = path
        state.selected_file = nil
        state.selected_index = 0
        ScanDirectory(path)
        SaveConfig()
    end
end

local function GoBack()
    if state.history_index > 0 then
        state.current_path = state.history[state.history_index]
        state.history_index = state.history_index - 1
        state.selected_file = nil
        ScanDirectory(state.current_path)
    end
end

local function GoUp()
    local parent = GetParentPath(state.current_path)
    if parent then NavigateTo(parent) end
end

local function GoHome()
    NavigateTo(GetScriptsPath())
end

local function RunScript(filepath)
    if filepath and reaper.file_exists(filepath) then
        AddToHistory(filepath)
        local command_id = reaper.AddRemoveReaScript(true, 0, filepath, false)
        if command_id ~= 0 then
            reaper.Main_OnCommand(command_id, 0)
            reaper.AddRemoveReaScript(false, 0, filepath, false)
        end
    end
end

local function EditScript(filepath)
    if filepath and reaper.file_exists(filepath) then
        if state.ide_path ~= "" then
            os.execute('start "" "' .. state.ide_path .. '" "' .. filepath .. '"')
        else
            reaper.CF_ShellExecute(filepath)
        end
    end
end

local function MatchesSearch(name)
    if state.search_text == "" then return true end
    return name:lower():find(state.search_text:lower(), 1, true) ~= nil
end

local function GetRecursiveScripts(path, search_text, results)
    local i = 0
    repeat
        local file = reaper.EnumerateFiles(path, i)
        if file then
            if IsScriptFile(file) and file:lower():find(search_text:lower(), 1, true) then
                local filepath = path .. "/" .. file
                table.insert(results, {
                    path = filepath,
                    name = file,
                    is_dir = false
                    -- Metadata (info) will be loaded lazily
                })
            end
        end
        i = i + 1
    until not file

    i = 0
    repeat
        local folder = reaper.EnumerateSubdirectories(path, i)
        if folder then
            GetRecursiveScripts(path .. "/" .. folder, search_text, results)
        end
        i = i + 1
    until not folder
end

local function GetIconForFile(filename)
    local ext = GetFileExtension(filename)
    if ext then
        ext = ext:lower()
        if ext == "lua" then return ICONS.lua
        elseif ext == "eel" then return ICONS.eel
        elseif ext == "py" then return ICONS.py
        end
    end
    return ICONS.script
end

local function GetColorForFile(filename)
    local ext = GetFileExtension(filename)
    if ext then
        ext = ext:lower()
        if ext == "lua" then return colors.lua
        elseif ext == "eel" then return colors.eel
        elseif ext == "py" then return colors.py
        end
    end
    return 0xFFFFFFFF
end

local function DrawBreadcrumbs()
    local parts = {}
    local path = state.current_path
    while path do
        local name = GetFileName(path)
        if name then
            table.insert(parts, 1, {name = name, path = path})
        end
        path = GetParentPath(path)
    end
    for i, part in ipairs(parts) do
        if i > 1 then
            ImGui.SameLine(ctx)
            ImGui.TextDisabled(ctx, ">")
            ImGui.SameLine(ctx)
        end
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, colors.breadcrumb)
        if ImGui.SmallButton(ctx, part.name .. "##bc" .. i) then
            NavigateTo(part.path)
        end
        ImGui.PopStyleColor(ctx)
    end
end

local function DrawMenuBar()
    if ImGui.BeginMenuBar(ctx) then
        if ImGui.BeginMenu(ctx, "File") then
            if ImGui.MenuItem(ctx, ICONS.refresh .. " Refresh", "F5") then
                ScanDirectory(state.current_path)
            end
            ImGui.Separator(ctx)
            if ImGui.MenuItem(ctx, "Settings...") then
                state.show_settings = true
            end
            ImGui.EndMenu(ctx)
        end
        if ImGui.BeginMenu(ctx, "Favorites") then
            if ImGui.MenuItem(ctx, "Show Favorites", nil, state.show_favorites) then
                state.show_favorites = not state.show_favorites
                state.show_history = false
            end
            if ImGui.MenuItem(ctx, "Add Custom Path...") then
                state.show_add_custom_path_modal = true
            end
            ImGui.EndMenu(ctx)
        end
        if ImGui.BeginMenu(ctx, "View") then
            if ImGui.MenuItem(ctx, ICONS.favorite .. " Favorites (Toggle)", nil, state.show_favorites) then
                state.show_favorites = not state.show_favorites
                state.show_history = false
            end
            if ImGui.MenuItem(ctx, ICONS.history .. " History", nil, state.show_history) then
                state.show_history = not state.show_history
                state.show_favorites = false
            end
            ImGui.Separator(ctx)
            if ImGui.MenuItem(ctx, "Sort by Name", nil, state.sort_by == "name") then
                state.sort_by = "name"
                ScanDirectory(state.current_path)
            end
            if ImGui.MenuItem(ctx, "Sort by Size", nil, state.sort_by == "size") then
                state.sort_by = "size"
                ScanDirectory(state.current_path)
            end
            ImGui.Separator(ctx)
            if ImGui.MenuItem(ctx, "Ascending", nil, state.sort_ascending) then
                state.sort_ascending = true
                ScanDirectory(state.current_path)
            end
            if ImGui.MenuItem(ctx, "Descending", nil, not state.sort_ascending) then
                state.sort_ascending = false
                ScanDirectory(state.current_path)
            end
            ImGui.EndMenu(ctx)
        end
        if ImGui.BeginMenu(ctx, "Help") then
            if ImGui.MenuItem(ctx, "About...") then
                reaper.ShowMessageBox(
                    SCRIPT_NAME .. " v" .. VERSION .. "\n\n" ..
                    "Author: Taras Umanskiy\n" ..
                    "File manager for launching REAPER scripts",
                    "About", 0)
            end
            ImGui.EndMenu(ctx)
        end
        ImGui.EndMenuBar(ctx)
    end
end

local function DrawToolbar()
    if ImGui.Button(ctx, ICONS.back .. "##back") then GoBack() end
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Back") end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, ICONS.up .. "##up") then GoUp() end
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Up") end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, ICONS.home .. "##home") then GoHome() end
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Home (Scripts folder)") end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, ICONS.refresh .. "##refresh") then ScanDirectory(state.current_path) end
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Refresh") end
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "|")
    ImGui.SameLine(ctx)
    local fav_color = state.show_favorites and colors.favorite or 0xFFFFFFFF
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, fav_color)
    if ImGui.Button(ctx, ICONS.favorite .. "##favorites") then
        state.show_favorites = not state.show_favorites
        state.show_history = false
    end
    ImGui.PopStyleColor(ctx)
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Favorites") end
    ImGui.SameLine(ctx)
    local hist_color = state.show_history and colors.favorite or 0xFFFFFFFF
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hist_color)
    if ImGui.Button(ctx, ICONS.history .. "##history") then
        state.show_history = not state.show_history
        state.show_favorites = false
    end
    ImGui.PopStyleColor(ctx)
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Run History") end
end

local function DrawSearchBar()
    ImGui.SetNextItemWidth(ctx, -200)
    local changed, new_text = ImGui.InputTextWithHint(ctx, "##search", ICONS.search .. " Search scripts...", state.search_text)
    if changed then 
        state.search_text = new_text 
        state.needs_search_update = true
        state.search_timer = reaper.time_precise() + 0.3 -- 300ms debounce
    end
    ImGui.SameLine(ctx)
    local changed_rec, new_rec = ImGui.Checkbox(ctx, "Recursive Search", state.recursive_search)
    if changed_rec then 
        state.recursive_search = new_rec 
        state.needs_search_update = true
        state.search_timer = 0 -- Update immediately on checkbox change
        SaveConfig()
    end
end

local function DrawFolderTree()
    if ImGui.BeginChild(ctx, "FolderTree", state.tree_width, state.list_height, ImGui.ChildFlags_Border + ImGui.ChildFlags_ResizeX) then
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, colors.folder)
        if ImGui.TreeNodeEx(ctx, "Scripts", "Scripts", ImGui.TreeNodeFlags_DefaultOpen) then
            if ImGui.BeginPopupContextItem(ctx) then
                local root_path = GetScriptsPath()
                if ImGui.MenuItem(ctx, IsFavorite(root_path) and "Remove from Favorites" or "Add to Favorites") then
                    ToggleFavorite(root_path)
                end
                ImGui.EndPopup(ctx)
            end

            local function DrawTreeNode(path, depth)
                if depth > 5 then return end
                local i = 0
                repeat
                    local folder = reaper.EnumerateSubdirectories(path, i)
                    if folder then
                        local folder_path = path .. "/" .. folder
                        local flags = ImGui.TreeNodeFlags_OpenOnArrow
                        if folder_path == state.current_path then
                            flags = flags + ImGui.TreeNodeFlags_Selected
                        end
                        local is_open = ImGui.TreeNodeEx(ctx, folder_path, folder, flags)
                        
                        if ImGui.BeginPopupContextItem(ctx) then
                            if ImGui.MenuItem(ctx, IsFavorite(folder_path) and "Remove from Favorites" or "Add to Favorites") then
                                ToggleFavorite(folder_path)
                            end
                            ImGui.EndPopup(ctx)
                        end

                        if ImGui.IsItemClicked(ctx) and not ImGui.IsItemToggledOpen(ctx) then
                            NavigateTo(folder_path)
                        end
                        if is_open then
                            DrawTreeNode(folder_path, depth + 1)
                            ImGui.TreePop(ctx)
                        end
                    end
                    i = i + 1
                until not folder
            end
            DrawTreeNode(GetScriptsPath(), 0)
            ImGui.TreePop(ctx)
        end
        ImGui.PopStyleColor(ctx)
        ImGui.EndChild(ctx)
    end
end

local function DrawFileList()
    ImGui.SameLine(ctx)
    if ImGui.BeginChild(ctx, "FileList", state.list_width, state.list_height, ImGui.ChildFlags_Border) then
        
        -- Подготовка списка видимых элементов
        local visible_items = {}
        local mode = "browser"
        if state.show_favorites then mode = "favorites"
        elseif state.show_history then mode = "history" end

        if mode == "favorites" then
            for i, filepath in ipairs(state.favorites) do
                local filename = GetFileName(filepath)
                if filename and MatchesSearch(filename) then
                    table.insert(visible_items, {
                        path = filepath,
                        name = filename,
                        is_dir = IsDirectory(filepath),
                        orig_index = i
                    })
                end
            end
        elseif mode == "history" then
            for _, filepath in ipairs(state.run_history) do
                local filename = GetFileName(filepath)
                if filename and MatchesSearch(filename) then
                    table.insert(visible_items, {
                        path = filepath,
                        name = filename,
                        is_dir = false
                    })
                end
            end
        else -- browser
            -- Обновление кешированного поиска
            local current_time = reaper.time_precise()
            local search_changed = state.search_text ~= state.last_search_text or 
                                 state.recursive_search ~= state.last_recursive_search or
                                 state.current_path ~= state.last_search_path

            if search_changed or state.needs_search_update then
                if state.search_timer <= current_time then
                    state.search_results = {}
                    if state.recursive_search and state.search_text ~= "" then
                        GetRecursiveScripts(state.current_path, state.search_text, state.search_results)
                    else
                        for _, folder in ipairs(state.folders) do
                            if MatchesSearch(folder.name) then
                                table.insert(state.search_results, {
                                    path = folder.path,
                                    name = folder.name,
                                    is_dir = true
                                })
                            end
                        end
                        for _, file in ipairs(state.files) do
                            if MatchesSearch(file.name) then
                                table.insert(state.search_results, {
                                    path = file.path,
                                    name = file.name,
                                    is_dir = false,
                                    info = file.info
                                })
                            end
                        end
                    end
                    state.last_search_text = state.search_text
                    state.last_recursive_search = state.recursive_search
                    state.last_search_path = state.current_path
                    state.needs_search_update = false
                end
            end
            visible_items = state.search_results
        end

        -- Коррекция индекса выделения
        if state.selected_index > #visible_items then state.selected_index = #visible_items end
        if state.selected_index < 0 then state.selected_index = 0 end

        -- Обработка клавиатуры
        if ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows) then
            local nav_key = false
            if ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow) then
                state.selected_index = state.selected_index - 1
                if state.selected_index < 1 then state.selected_index = 1 end
                nav_key = true
            elseif ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow) then
                state.selected_index = state.selected_index + 1
                if state.selected_index > #visible_items then state.selected_index = #visible_items end
                nav_key = true
            elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
                local item = visible_items[state.selected_index]
                if item then
                    if item.is_dir then
                        NavigateTo(item.path)
                        if mode == "favorites" then state.show_favorites = false end
                    else
                        RunScript(item.path)
                    end
                end
            end

            if nav_key then
                local item = visible_items[state.selected_index]
                if item then
                    state.selected_file = item.path
                    if not item.is_dir then
                        state.script_info = item.info or GetFileInfo(item.path)
                    else
                        state.script_info = nil
                    end
                end
            end
        end

        -- Отрисовка
        if mode == "favorites" then
            ImGui.TextColored(ctx, colors.favorite, ICONS.favorite .. " Favorites")
            ImGui.Separator(ctx)

            if ImGui.BeginTable(ctx, "FavoritesTable", 2, ImGui.TableFlags_Resizable + ImGui.TableFlags_RowBg + ImGui.TableFlags_ScrollY) then
                ImGui.TableSetupColumn(ctx, "Name", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "Path", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableHeadersRow(ctx)

                for i, item in ipairs(visible_items) do
                    ImGui.TableNextRow(ctx)
                    ImGui.TableNextColumn(ctx)

                    local icon, color
                    if item.is_dir then
                        icon = ICONS.folder
                        color = 0xFFFFFFFF -- White for favorite folders
                    else
                        icon = GetIconForFile(item.name)
                        color = GetColorForFile(item.name)
                    end
                    
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, color)
                    local is_selected = (i == state.selected_index)
                    
                    local flags = ImGui.SelectableFlags_AllowDoubleClick + ImGui.SelectableFlags_SpanAllColumns
                    
                    if ImGui.Selectable(ctx, icon .. " " .. item.name .. "##fav" .. i, is_selected, flags) then
                        state.selected_index = i
                        state.selected_file = item.path
                        if not item.is_dir then
                             state.script_info = GetFileInfo(item.path)
                        else
                             state.script_info = nil
                        end
                        
                        if ImGui.IsMouseDoubleClicked(ctx, 0) then
                            if item.is_dir then
                                NavigateTo(item.path)
                                state.show_favorites = false
                            else
                                RunScript(item.path)
                            end
                        end
                    end

                    -- Drag and Drop for reordering
                    if ImGui.BeginDragDropSource(ctx) then
                        ImGui.SetDragDropPayload(ctx, "FAV_ITEM", tostring(i))
                        ImGui.Text(ctx, "Move: " .. item.name)
                        ImGui.EndDragDropSource(ctx)
                    end

                    if ImGui.BeginDragDropTarget(ctx) then
                        local payload_retval, payload = ImGui.AcceptDragDropPayload(ctx, "FAV_ITEM")
                        if payload_retval then
                            local from_idx = tonumber(payload)
                            local to_idx = i
                            if from_idx ~= to_idx then
                                local moving_item = table.remove(state.favorites, visible_items[from_idx].orig_index)
                                table.insert(state.favorites, visible_items[to_idx].orig_index, moving_item)
                                SaveConfig()
                            end
                        end
                        ImGui.EndDragDropTarget(ctx)
                    end

                    ImGui.PopStyleColor(ctx)
                    
                    if is_selected and (ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow) or ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow)) then
                        ImGui.SetScrollHereY(ctx)
                    end

                    if ImGui.BeginPopupContextItem(ctx) then
                        if item.is_dir then
                            if ImGui.MenuItem(ctx, ICONS.folder_open .. " Open") then
                                NavigateTo(item.path)
                                state.show_favorites = false
                            end
                        else
                            if ImGui.MenuItem(ctx, ICONS.run .. " Run") then RunScript(item.path) end
                            if ImGui.MenuItem(ctx, ICONS.edit .. " Edit") then EditScript(item.path) end
                        end
                        ImGui.Separator(ctx)
                        if ImGui.MenuItem(ctx, "Remove from Favorites") then ToggleFavorite(item.path) end
                        ImGui.EndPopup(ctx)
                    end

                    ImGui.TableNextColumn(ctx)
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, colors.size)
                    ImGui.Text(ctx, item.path)
                    ImGui.PopStyleColor(ctx)
                end
                ImGui.EndTable(ctx)
            end
            
        elseif mode == "history" then
            ImGui.TextColored(ctx, colors.favorite, ICONS.history .. " Run History")
            ImGui.Separator(ctx)
            for i, item in ipairs(visible_items) do
                local icon = GetIconForFile(item.name)
                local color = GetColorForFile(item.name)
                
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, color)
                local is_selected = (i == state.selected_index)
                if ImGui.Selectable(ctx, icon .. " " .. item.name .. "##hist" .. i, is_selected, ImGui.SelectableFlags_AllowDoubleClick) then
                    state.selected_index = i
                    state.selected_file = item.path
                    state.script_info = GetFileInfo(item.path)
                    
                    if ImGui.IsMouseDoubleClicked(ctx, 0) then
                        RunScript(item.path)
                    end
                end
                ImGui.PopStyleColor(ctx)

                if is_selected and (ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow) or ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow)) then
                    ImGui.SetScrollHereY(ctx)
                end

                if ImGui.BeginPopupContextItem(ctx) then
                    if ImGui.MenuItem(ctx, ICONS.run .. " Run") then RunScript(item.path) end
                    if ImGui.MenuItem(ctx, ICONS.edit .. " Edit") then EditScript(item.path) end
                    ImGui.Separator(ctx)
                    local is_fav = IsFavorite(item.path)
                    if ImGui.MenuItem(ctx, is_fav and "Remove from Favorites" or "Add to Favorites") then
                        ToggleFavorite(item.path)
                    end
                    ImGui.EndPopup(ctx)
                end
            end
            
        else -- browser
            if ImGui.BeginTable(ctx, "FilesTable", 4, ImGui.TableFlags_Resizable + ImGui.TableFlags_RowBg + ImGui.TableFlags_ScrollY) then
                ImGui.TableSetupColumn(ctx, "Name", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "Size", ImGui.TableColumnFlags_WidthFixed, 80)
                ImGui.TableSetupColumn(ctx, "Description", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "", ImGui.TableColumnFlags_WidthFixed, 30)
                ImGui.TableHeadersRow(ctx)
                
                for i, item in ipairs(visible_items) do
                    ImGui.TableNextRow(ctx)
                    ImGui.TableNextColumn(ctx)
                    
                    local icon, color
                    if item.is_dir then
                        icon = ICONS.folder
                        color = colors.folder
                    else
                        icon = GetIconForFile(item.name)
                        color = GetColorForFile(item.name)
                    end
                    
                    local is_selected = (i == state.selected_index)
                    local is_fav = IsFavorite(item.path)
                    
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, color)
                    local flags = ImGui.SelectableFlags_AllowDoubleClick + ImGui.SelectableFlags_SpanAllColumns
                    
                    local display_name = icon .. " " .. item.name
                    if is_fav then display_name = display_name .. " " .. ICONS.favorite end
                    
                    if ImGui.Selectable(ctx, display_name .. "##item" .. i, is_selected, flags) then
                        state.selected_index = i
                        state.selected_file = item.path
                        state.script_info = item.info -- info nil if folder
                        
                        if ImGui.IsMouseDoubleClicked(ctx, 0) then
                            if item.is_dir then
                                NavigateTo(item.path)
                            else
                                RunScript(item.path)
                            end
                        end
                    end
                    ImGui.PopStyleColor(ctx)
                    
                    if is_selected and (ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow) or ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow)) then
                        ImGui.SetScrollHereY(ctx)
                    end

                    if ImGui.BeginPopupContextItem(ctx) then
                        if item.is_dir then
                            if ImGui.MenuItem(ctx, ICONS.folder_open .. " Open") then NavigateTo(item.path) end
                        else
                            if ImGui.MenuItem(ctx, ICONS.run .. " Run") then RunScript(item.path) end
                            if ImGui.MenuItem(ctx, ICONS.edit .. " Edit") then EditScript(item.path) end
                        end
                        ImGui.Separator(ctx)
                        if ImGui.MenuItem(ctx, is_fav and "Remove from Favorites" or "Add to Favorites") then
                            ToggleFavorite(item.path)
                        end
                        ImGui.EndPopup(ctx)
                    end
                    
                    ImGui.TableNextColumn(ctx)
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, colors.size)
                    if item.info then
                        ImGui.Text(ctx, FormatFileSize(item.info.size))
                    end
                    ImGui.PopStyleColor(ctx)
                    
                    ImGui.TableNextColumn(ctx)
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, colors.date)
                    if item.info and item.info.description ~= "" then
                        ImGui.Text(ctx, item.info.description)
                    end
                    ImGui.PopStyleColor(ctx)
                    
                    ImGui.TableNextColumn(ctx)
                    -- Empty column
                end
                ImGui.EndTable(ctx)
            end
        end
        ImGui.EndChild(ctx)
    end
end

local function DrawInfoPanel()
    if state.selected_file and state.script_info then
        ImGui.Separator(ctx)
        local filename = GetFileName(state.selected_file)
        ImGui.Text(ctx, GetIconForFile(filename) .. " " .. filename)
        if state.script_info.description ~= "" then
            ImGui.TextWrapped(ctx, "Description: " .. state.script_info.description)
        end
        if state.script_info.author ~= "" then
            ImGui.Text(ctx, "Author: " .. state.script_info.author)
        end
        if state.script_info.version ~= "" then
            ImGui.Text(ctx, "Version: " .. state.script_info.version)
        end
        ImGui.Text(ctx, "Size: " .. FormatFileSize(state.script_info.size))
        ImGui.Spacing(ctx)
        if ImGui.Button(ctx, ICONS.run .. " Run Script") then
            RunScript(state.selected_file)
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, ICONS.edit .. " Edit") then
            EditScript(state.selected_file)
        end
        ImGui.SameLine(ctx)
        local is_fav = IsFavorite(state.selected_file)
        if ImGui.Button(ctx, is_fav and "Remove ⭐" or "Add ⭐") then
            ToggleFavorite(state.selected_file)
        end
    end
end

local function DrawSettingsWindow()
    if state.show_settings then
        local visible, open = ImGui.Begin(ctx, "Settings", true, ImGui.WindowFlags_AlwaysAutoResize)
        if visible then
            ImGui.Text(ctx, "External Editor Path:")
            ImGui.SetNextItemWidth(ctx, 400)
            local changed, new_path = ImGui.InputText(ctx, "##ide_path", state.ide_path)
            if changed then state.ide_path = new_path end
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Browse...") then
                local retval, filename = reaper.GetUserFileNameForRead("", "Select Editor", "exe")
                if retval then
                    state.ide_path = filename
                end
            end
            ImGui.Spacing(ctx)
            ImGui.TextDisabled(ctx, "Leave empty to use system default")
            ImGui.Spacing(ctx)
            if ImGui.Button(ctx, "Save") then
                SaveConfig()
                state.show_settings = false
            end
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Cancel") then
                state.show_settings = false
            end
            ImGui.End(ctx)
        end
        if not open then state.show_settings = false end
    end
end

local function DrawAddCustomPathModal()
    if state.show_add_custom_path_modal then
        ImGui.OpenPopup(ctx, "Add Custom Path to Favorites")
        state.show_add_custom_path_modal = false
    end

    local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
    ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing, 0.5, 0.5)

    if ImGui.BeginPopupModal(ctx, "Add Custom Path to Favorites", true, ImGui.WindowFlags_AlwaysAutoResize) then
        ImGui.Text(ctx, "Enter full path to a file or folder:")
        ImGui.SetNextItemWidth(ctx, 400)
        local changed, new_text = ImGui.InputText(ctx, "##custompath", state.custom_path_input)
        if changed then state.custom_path_input = new_text end
        
        ImGui.Spacing(ctx)
        
        if ImGui.Button(ctx, "Add") then
            local path = state.custom_path_input
            -- Remove quotes if user copied as "path"
            path = path:gsub('^"', ''):gsub('"$', '')
            -- Normalize slashes and remove trailing ones
            path = NormalizePath(path)
            if path:sub(-1) == "/" and not path:match("^%a:/$") then 
                path = path:sub(1, -2) 
            end
            
            local is_valid = false
            if reaper.file_exists(path) then
                is_valid = true
            elseif IsDirectory(path) then
                is_valid = true
            end
            
            if is_valid then
                ToggleFavorite(path)
                state.custom_path_input = ""
                ImGui.CloseCurrentPopup(ctx)
            else
                reaper.ShowMessageBox("Path does not exist or is invalid.", "Error", 0)
            end
        end
        
        ImGui.SameLine(ctx)
        
        if ImGui.Button(ctx, "Cancel") then
            ImGui.CloseCurrentPopup(ctx)
        end
        
        ImGui.EndPopup(ctx)
    end
end

local function MainLoop()
    ImGui.SetNextWindowSize(ctx, 900, 600, ImGui.Cond_FirstUseEver)
    local visible, open = ImGui.Begin(ctx, SCRIPT_NAME .. " v" .. VERSION, true, state.window_flags)
    if visible then
        if ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) and not ImGui.IsAnyItemActive(ctx) then
            open = false
        end
        DrawMenuBar()
        DrawToolbar()
        ImGui.Spacing(ctx)
        DrawBreadcrumbs()
        ImGui.Spacing(ctx)
        DrawSearchBar()
        ImGui.Spacing(ctx)
        DrawFolderTree()
        DrawFileList()
        DrawInfoPanel()
        ImGui.End(ctx)
    end
    DrawSettingsWindow()
    if open then
        DrawAddCustomPathModal()
        reaper.defer(MainLoop)
    else
        SaveConfig()
    end
end

LoadConfig()
ScanDirectory(state.current_path)
reaper.defer(MainLoop)
