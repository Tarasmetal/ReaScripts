-- @description Script Launcher - File manager for launching REAPER scripts
-- @author Taras Umanskiy
-- @version 2.9
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
--   + v2.0: Добавра возможность менять порядок элементов в избранном (Drag & Drop)
--   + v2.1: Добавлен чекбокс "Recursive Search" для поиска файлов во всех подпапках
--   + v2.2: Оптимизирован поиск: добавлено кеширование результатов и дебаунсинг (задержка)
--   + v2.3: Исправлено добавление кастомных путей с завершающим слэшем
--   + v2.4: Добавлена колонка Path в раздел History
--   + v2.5: Исправлено отображение размера и описания в поиске, добавлена колонка Path в браузер
--   + v2.6: Добавлена возможность изменения размера главного окна, адаптивная верстка
--   + v2.7: Папки, добавленные в избранное, теперь отображаются белым цветом везде
--   + v2.8: Выбор любого диска
--   + v2.9: Добавлена система тегов для скриптов и папок

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.2'

local ctx = ImGui.CreateContext('Script Launcher')
local VERSION = "2.9"
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
    favorite = "⭐",
    run = "▶️",
    edit = "✏️",
    back = "◀",
    up = "🔼",
    home = "🏠",
    drive = "💻",
    search = "🔍",
    history = "🕐",
    refresh = "🔄",
    tag = "🏷️"
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

local function GetAvailableDrives()
    local drives = {}
    for i = 65, 90 do
        local drive = string.char(i) .. ":"
        local test_dir = reaper.EnumerateSubdirectories(drive .. "\\", 0)
        local test_file = reaper.EnumerateFiles(drive .. "\\", 0)
        if test_dir or test_file then
            table.insert(drives, drive)
        end
    end
    return drives
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
    window_flags = ImGui.WindowFlags_MenuBar + ImGui.WindowFlags_NoScrollbar,
    window_w = 900,
    window_h = 600,
    sort_by = "name",
    sort_ascending = true,
    ide_path = "",
    show_settings = false,
    tree_width = 200,
    show_add_custom_path_modal = false,
    custom_path_input = "",
    recursive_search = false,
    search_results = {},
    last_search_text = "",
    last_recursive_search = false,
    last_search_path = "",
    search_timer = 0,
    needs_search_update = false,
    tags = {}, -- { "Tag1", "Tag2" }
    item_tags = {}, -- { ["path/to/item"] = { ["Tag1"] = true } }
    filter_tag = nil,
    show_manage_tags = false,
    new_tag_name = "",
    tag_to_edit = nil,
    edit_tag_name = "",
    show_assign_tags_modal = false,
    assign_tags_path = nil,
    last_filter_tag = nil
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
        file:write("window_w=" .. tostring(state.window_w) .. "\n")
        file:write("window_h=" .. tostring(state.window_h) .. "\n")
        file:write("tree_width=" .. tostring(state.tree_width) .. "\n")
        
        file:write("tags=")
        for i, tag in ipairs(state.tags) do
            if i > 1 then file:write("|") end
            file:write(tag)
        end
        file:write("\n")

        file:write("item_tags=")
        local first_item = true
        for path, tags in pairs(state.item_tags) do
            local tag_list = {}
            for tag, _ in pairs(tags) do table.insert(tag_list, tag) end
            if #tag_list > 0 then
                if not first_item then file:write("|") end
                file:write(path .. ">" .. table.concat(tag_list, ","))
                first_item = false
            end
        end
        file:write("\n")

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
                elseif key == "window_w" then
                    state.window_w = tonumber(value) or 900
                elseif key == "window_h" then
                    state.window_h = tonumber(value) or 600
                elseif key == "tree_width" then
                    state.tree_width = tonumber(value) or 200
                elseif key == "tags" and value ~= "" then
                    state.tags = {}
                    for tag in value:gmatch("[^|]+") do
                        table.insert(state.tags, tag)
                    end
                elseif key == "item_tags" and value ~= "" then
                    state.item_tags = {}
                    for item in value:gmatch("[^|]+") do
                        local path, tags_str = item:match("^(.-)>(.*)$")
                        if path and tags_str then
                            state.item_tags[path] = {}
                            for tag in tags_str:gmatch("[^,]+") do
                                state.item_tags[path][tag] = true
                            end
                        end
                    end
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

local function HasTag(path, tag)
    if not state.item_tags[path] then return false end
    return state.item_tags[path][tag] == true
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

local function MatchesSearch(name, path)
    if state.search_text ~= "" then
        if not name:lower():find(state.search_text:lower(), 1, true) then
            return false
        end
    end
    if state.filter_tag then
        if not HasTag(path, state.filter_tag) then
            return false
        end
    end
    return true
end

local function GetRecursiveScripts(path, search_text, results)
    local i = 0
    repeat
        local file = reaper.EnumerateFiles(path, i)
        if file then
            local filepath = path .. "/" .. file
            if IsScriptFile(file) and MatchesSearch(file, filepath) then
                table.insert(results, {
                    path = filepath,
                    name = file,
                    is_dir = false,
                    info = GetFileInfo(filepath)
                })
            end
        end
        i = i + 1
    until not file

    i = 0
    repeat
        local folder = reaper.EnumerateSubdirectories(path, i)
        if folder then
            local folder_path = path .. "/" .. folder
            -- If folder itself matches search/tag, we might want to include it?
            -- But GetRecursiveScripts usually returns files. 
            -- The existing logic only added files.
            GetRecursiveScripts(folder_path, search_text, results)
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
            if ImGui.MenuItem(ctx, ICONS.tag .. " Manage Tags...") then
                state.show_manage_tags = true
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

    if ImGui.Button(ctx, ICONS.drive .. "##drives") then
        ImGui.OpenPopup(ctx, "DrivesPopup")
    end
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Drives") end

    if ImGui.BeginPopup(ctx, "DrivesPopup") then
        local drives = GetAvailableDrives()
        for _, drive in ipairs(drives) do
            if ImGui.MenuItem(ctx, drive) then
                NavigateTo(drive .. "/")
            end
        end
        ImGui.EndPopup(ctx)
    end

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

local function DrawFolderTree(list_height)
    if ImGui.BeginChild(ctx, "FolderTree", state.tree_width, list_height, ImGui.ChildFlags_Border + ImGui.ChildFlags_ResizeX) then
        state.tree_width, _ = ImGui.GetWindowSize(ctx)

        local root_path = GetScriptsPath()
        local root_is_fav = IsFavorite(root_path)

        ImGui.PushStyleColor(ctx, ImGui.Col_Text, root_is_fav and 0xFFFFFFFF or colors.folder)
        local root_open = ImGui.TreeNodeEx(ctx, "Scripts", "Scripts", ImGui.TreeNodeFlags_DefaultOpen)
        ImGui.PopStyleColor(ctx)

        if root_open then
            if ImGui.BeginPopupContextItem(ctx) then
                if ImGui.MenuItem(ctx, root_is_fav and "Remove from Favorites" or "Add to Favorites") then
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

                        local is_fav = IsFavorite(folder_path)
                        ImGui.PushStyleColor(ctx, ImGui.Col_Text, is_fav and 0xFFFFFFFF or colors.folder)
                        local is_open = ImGui.TreeNodeEx(ctx, folder_path, folder, flags)
                        ImGui.PopStyleColor(ctx)

                        if ImGui.BeginPopupContextItem(ctx) then
                            if ImGui.MenuItem(ctx, is_fav and "Remove from Favorites" or "Add to Favorites") then
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
        ImGui.EndChild(ctx)
    end
end

local function DrawFileList(list_height)
    ImGui.SameLine(ctx)
    if ImGui.BeginChild(ctx, "FileList", 0, list_height, ImGui.ChildFlags_Border) then

        -- Подготовка списка видимых элементов
        local visible_items = {}
        local mode = "browser"
        if state.show_favorites then mode = "favorites"
        elseif state.show_history then mode = "history" end

        if mode == "favorites" then
            for i, filepath in ipairs(state.favorites) do
                local filename = GetFileName(filepath)
                if filename and MatchesSearch(filename, filepath) then
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
                if filename and MatchesSearch(filename, filepath) then
                    table.insert(visible_items, {
                        path = filepath,
                        name = filename,
                        is_dir = false
                    })
                end
            end
        elseif state.filter_tag then
            -- Глобальный поиск по тегу (независимо от пути)
            local search_changed = state.filter_tag ~= state.last_filter_tag or
                                 state.search_text ~= state.last_search_text
            
            if search_changed or state.needs_search_update then
                state.search_results = {}
                for path, tags in pairs(state.item_tags) do
                    if tags[state.filter_tag] then
                        local filename = GetFileName(path)
                        if not state.search_text or state.search_text == "" or (filename and filename:lower():find(state.search_text:lower(), 1, true)) then
                            table.insert(state.search_results, {
                                path = path,
                                name = filename or path,
                                is_dir = IsDirectory(path),
                                info = not IsDirectory(path) and GetFileInfo(path) or nil
                            })
                        end
                    end
                end
                -- Сортировка результатов
                table.sort(state.search_results, function(a, b)
                    if a.is_dir ~= b.is_dir then return a.is_dir end
                    return a.name:lower() < b.name:lower()
                end)
                state.last_filter_tag = state.filter_tag
                state.last_search_text = state.search_text
                state.needs_search_update = false
            end
            visible_items = state.search_results

            ImGui.TextColored(ctx, colors.selected, ICONS.tag .. " Tag: " .. state.filter_tag)
            ImGui.Separator(ctx)

            if ImGui.BeginTable(ctx, "TagsTable", 6, ImGui.TableFlags_Resizable + ImGui.TableFlags_RowBg + ImGui.TableFlags_ScrollY) then
                ImGui.TableSetupColumn(ctx, "Name", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "Tags", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "Size", ImGui.TableColumnFlags_WidthFixed, 80)
                ImGui.TableSetupColumn(ctx, "Description", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "Path", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "", ImGui.TableColumnFlags_WidthFixed, 30)
                ImGui.TableHeadersRow(ctx)

                for i, item in ipairs(visible_items) do
                    ImGui.TableNextRow(ctx)
                    ImGui.TableNextColumn(ctx)

                    local is_selected = (i == state.selected_index)
                    local is_fav = IsFavorite(item.path)

                    local icon, color
                    if item.is_dir then
                        icon = ICONS.folder
                        color = is_fav and 0xFFFFFFFF or colors.folder
                    else
                        icon = GetIconForFile(item.name)
                        color = GetColorForFile(item.name)
                    end

                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, color)
                    local flags = ImGui.SelectableFlags_AllowDoubleClick + ImGui.SelectableFlags_SpanAllColumns

                    local display_name = icon .. " " .. item.name
                    if is_fav then display_name = display_name .. " " .. ICONS.favorite end

                    if ImGui.Selectable(ctx, display_name .. "##tag_item" .. i, is_selected, flags) then
                        state.selected_index = i
                        state.selected_file = item.path
                        state.script_info = item.info

                        if ImGui.IsMouseDoubleClicked(ctx, 0) then
                            if item.is_dir then
                                NavigateTo(item.path)
                                state.filter_tag = nil
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
                            if ImGui.MenuItem(ctx, ICONS.folder_open .. " Open") then 
                                NavigateTo(item.path)
                                state.filter_tag = nil
                            end
                        else
                            if ImGui.MenuItem(ctx, ICONS.run .. " Run") then RunScript(item.path) end
                            if ImGui.MenuItem(ctx, ICONS.edit .. " Edit") then EditScript(item.path) end
                        end
                        ImGui.Separator(ctx)
                        if ImGui.MenuItem(ctx, is_fav and "Remove from Favorites" or "Add to Favorites") then
                            ToggleFavorite(item.path)
                        end
                        ImGui.Separator(ctx)
                        if ImGui.MenuItem(ctx, ICONS.tag .. " Assign Tags...") then
                            state.assign_tags_path = item.path
                            state.show_assign_tags_modal = true
                        end
                        ImGui.EndPopup(ctx)
                    end

                    ImGui.TableNextColumn(ctx)
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, colors.breadcrumb)
                    if state.item_tags[item.path] then
                        local tags = {}
                        for t, _ in pairs(state.item_tags[item.path]) do table.insert(tags, t) end
                        if #tags > 0 then
                            table.sort(tags)
                            ImGui.Text(ctx, table.concat(tags, ", "))
                        end
                    end
                    ImGui.PopStyleColor(ctx)

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
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, colors.size)
                    ImGui.Text(ctx, item.path)
                    ImGui.PopStyleColor(ctx)

                    ImGui.TableNextColumn(ctx)
                end
                ImGui.EndTable(ctx)
            end
        else -- browser
            -- Обновление кешированного поиска
            local current_time = reaper.time_precise()
            local search_changed = state.search_text ~= state.last_search_text or
                                 state.recursive_search ~= state.last_recursive_search or
                                 state.current_path ~= state.last_search_path or
                                 state.filter_tag ~= state.last_filter_tag

            if search_changed or state.needs_search_update then
                if state.search_timer <= current_time then
                    state.search_results = {}
                    if state.recursive_search and state.search_text ~= "" then
                        GetRecursiveScripts(state.current_path, state.search_text, state.search_results)
                    else
                        for _, folder in ipairs(state.folders) do
                            if MatchesSearch(folder.name, folder.path) then
                                table.insert(state.search_results, {
                                    path = folder.path,
                                    name = folder.name,
                                    is_dir = true
                                })
                            end
                        end
                        for _, file in ipairs(state.files) do
                            if MatchesSearch(file.name, file.path) then
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
                    state.last_filter_tag = state.filter_tag
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
                        ImGui.Separator(ctx)
                        if ImGui.MenuItem(ctx, ICONS.tag .. " Assign Tags...") then
                            state.assign_tags_path = item.path
                            state.show_assign_tags_modal = true
                        end
                        ImGui.EndPopup(ctx)
                    end

                    ImGui.TableNextColumn(ctx)
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, colors.breadcrumb)
                    if state.item_tags[item.path] then
                        local tags = {}
                        for t, _ in pairs(state.item_tags[item.path]) do table.insert(tags, t) end
                        if #tags > 0 then
                            table.sort(tags)
                            ImGui.Text(ctx, table.concat(tags, ", "))
                        end
                    end
                    ImGui.PopStyleColor(ctx)

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

            if ImGui.BeginTable(ctx, "HistoryTable", 2, ImGui.TableFlags_Resizable + ImGui.TableFlags_RowBg + ImGui.TableFlags_ScrollY) then
                ImGui.TableSetupColumn(ctx, "Name", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "Path", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableHeadersRow(ctx)

                for i, item in ipairs(visible_items) do
                    ImGui.TableNextRow(ctx)
                    ImGui.TableNextColumn(ctx)

                    local icon = GetIconForFile(item.name)
                    local color = GetColorForFile(item.name)

                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, color)
                    local is_selected = (i == state.selected_index)

                    local flags = ImGui.SelectableFlags_AllowDoubleClick + ImGui.SelectableFlags_SpanAllColumns

                    if ImGui.Selectable(ctx, icon .. " " .. item.name .. "##hist" .. i, is_selected, flags) then
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
                        ImGui.Separator(ctx)
                        if ImGui.MenuItem(ctx, ICONS.tag .. " Assign Tags...") then
                            state.assign_tags_path = item.path
                            state.show_assign_tags_modal = true
                        end
                        ImGui.EndPopup(ctx)
                    end

                    ImGui.TableNextColumn(ctx)
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, colors.size)
                    ImGui.Text(ctx, item.path)
                    ImGui.PopStyleColor(ctx)
                end
                ImGui.EndTable(ctx)
            end

        else -- browser
            if ImGui.BeginTable(ctx, "FilesTable", 6, ImGui.TableFlags_Resizable + ImGui.TableFlags_RowBg + ImGui.TableFlags_ScrollY) then
                ImGui.TableSetupColumn(ctx, "Name", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "Tags", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "Size", ImGui.TableColumnFlags_WidthFixed, 80)
                ImGui.TableSetupColumn(ctx, "Description", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "Path", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, "", ImGui.TableColumnFlags_WidthFixed, 30)
                ImGui.TableHeadersRow(ctx)

                for i, item in ipairs(visible_items) do
                    ImGui.TableNextRow(ctx)
                    ImGui.TableNextColumn(ctx)

                    local is_selected = (i == state.selected_index)
                    local is_fav = IsFavorite(item.path)

                    local icon, color
                    if item.is_dir then
                        icon = ICONS.folder
                        color = is_fav and 0xFFFFFFFF or colors.folder
                    else
                        icon = GetIconForFile(item.name)
                        color = GetColorForFile(item.name)
                    end

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
                        ImGui.Separator(ctx)
                        if ImGui.MenuItem(ctx, ICONS.tag .. " Assign Tags...") then
                            state.assign_tags_path = item.path
                            state.show_assign_tags_modal = true
                        end
                        ImGui.EndPopup(ctx)
                    end

                    ImGui.TableNextColumn(ctx)
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, colors.breadcrumb)
                    if state.item_tags[item.path] then
                        local tags = {}
                        for t, _ in pairs(state.item_tags[item.path]) do table.insert(tags, t) end
                        if #tags > 0 then
                            table.sort(tags)
                            ImGui.Text(ctx, table.concat(tags, ", "))
                        end
                    end
                    ImGui.PopStyleColor(ctx)

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
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, colors.size)
                    ImGui.Text(ctx, item.path)
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

        -- Show tags
        if state.item_tags[state.selected_file] then
            local tags = {}
            for t, _ in pairs(state.item_tags[state.selected_file]) do table.insert(tags, t) end
            if #tags > 0 then
                table.sort(tags)
                ImGui.Text(ctx, "Tags: " .. table.concat(tags, ", "))
            end
        end

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

local function DrawManageTagsWindow()
    if state.show_manage_tags then
        local visible, open = ImGui.Begin(ctx, "Manage Tags", true, ImGui.WindowFlags_AlwaysAutoResize)
        if visible then
            ImGui.Text(ctx, "Create New Tag:")
            ImGui.SetNextItemWidth(ctx, 200)
            local changed, new_val = ImGui.InputText(ctx, "##new_tag", state.new_tag_name)
            if changed then 
                -- Remove forbidden characters
                state.new_tag_name = new_val:gsub("[:|,]", "") 
            end
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Add") and state.new_tag_name ~= "" then
                -- Check if tag already exists
                local exists = false
                for _, t in ipairs(state.tags) do
                    if t == state.new_tag_name then exists = true break end
                end
                if not exists then
                    table.insert(state.tags, state.new_tag_name)
                    table.sort(state.tags)
                    state.new_tag_name = ""
                    SaveConfig()
                end
            end

            ImGui.Separator(ctx)
            ImGui.Text(ctx, "Existing Tags:")
            
            local tag_to_remove = nil
            for i, tag in ipairs(state.tags) do
                if state.tag_to_edit == tag then
                    ImGui.SetNextItemWidth(ctx, 150)
                    local changed_edit, new_edit = ImGui.InputText(ctx, "##edit_tag" .. i, state.edit_tag_name)
                    if changed_edit then 
                        state.edit_tag_name = new_edit:gsub("[:|,]", "") 
                    end
                    ImGui.SameLine(ctx)
                    if ImGui.Button(ctx, "OK##ok" .. i) then
                        if state.edit_tag_name ~= "" and state.edit_tag_name ~= tag then
                            -- Update all items using this tag
                            for path, tags in pairs(state.item_tags) do
                                if tags[tag] then
                                    tags[tag] = nil
                                    tags[state.edit_tag_name] = true
                                end
                            end
                            state.tags[i] = state.edit_tag_name
                            table.sort(state.tags)
                            SaveConfig()
                        end
                        state.tag_to_edit = nil
                    end
                    ImGui.SameLine(ctx)
                    if ImGui.Button(ctx, "Cancel##cancel" .. i) then
                        state.tag_to_edit = nil
                    end
                else
                    ImGui.Text(ctx, tag)
                    ImGui.SameLine(ctx, 200)
                    if ImGui.Button(ctx, "Edit##edit" .. i) then
                        state.tag_to_edit = tag
                        state.edit_tag_name = tag
                    end
                    ImGui.SameLine(ctx)
                    if ImGui.Button(ctx, "Delete##del" .. i) then
                        tag_to_remove = i
                    end
                end
            end

            if tag_to_remove then
                local deleted_tag = table.remove(state.tags, tag_to_remove)
                -- Remove from all items
                for path, tags in pairs(state.item_tags) do
                    tags[deleted_tag] = nil
                end
                if state.filter_tag == deleted_tag then state.filter_tag = nil end
                SaveConfig()
            end

            ImGui.Separator(ctx)
            if ImGui.Button(ctx, "Close") then
                state.show_manage_tags = false
            end
            ImGui.End(ctx)
        end
        if not open then state.show_manage_tags = false end
    end
end

local function DrawAssignTagsModal()
    if state.show_assign_tags_modal then
        ImGui.OpenPopup(ctx, "Assign Tags")
        state.show_assign_tags_modal = false
    end

    local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
    ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing, 0.5, 0.5)

    if ImGui.BeginPopupModal(ctx, "Assign Tags", true, ImGui.WindowFlags_AlwaysAutoResize) then
        if state.assign_tags_path then
            ImGui.Text(ctx, "Assign tags to: " .. GetFileName(state.assign_tags_path))
            ImGui.Separator(ctx)

            if #state.tags == 0 then
                ImGui.TextDisabled(ctx, "No tags created yet. Use 'File > Manage Tags...' first.")
            else
                if not state.item_tags[state.assign_tags_path] then
                    state.item_tags[state.assign_tags_path] = {}
                end

                for _, tag in ipairs(state.tags) do
                    local is_assigned = state.item_tags[state.assign_tags_path][tag] or false
                    local changed, checked = ImGui.Checkbox(ctx, tag, is_assigned)
                    if changed then
                        state.item_tags[state.assign_tags_path][tag] = checked or nil
                        SaveConfig()
                    end
                end
            end
        end

        ImGui.Separator(ctx)
        if ImGui.Button(ctx, "Done", 120) then
            ImGui.CloseCurrentPopup(ctx)
        end
        ImGui.EndPopup(ctx)
    end
end

local function DrawTagsBar()
    if #state.tags == 0 then return end
    
    ImGui.Text(ctx, "Tags: ")
    ImGui.SameLine(ctx)
    
    -- "All" button to clear filter
    local all_active = (state.filter_tag == nil)
    if all_active then ImGui.PushStyleColor(ctx, ImGui.Col_Button, colors.selected) end
    if ImGui.Button(ctx, "All##tag_all") then
        state.filter_tag = nil
        state.needs_search_update = true
    end
    if all_active then ImGui.PopStyleColor(ctx) end
    
    for _, tag in ipairs(state.tags) do
        ImGui.SameLine(ctx)
        local is_active = (state.filter_tag == tag)
        if is_active then ImGui.PushStyleColor(ctx, ImGui.Col_Button, colors.selected) end
        if ImGui.Button(ctx, tag .. "##tag_btn_" .. tag) then
            if state.filter_tag == tag then
                state.filter_tag = nil
            else
                state.filter_tag = tag
            end
            state.needs_search_update = true
        end
        if is_active then ImGui.PopStyleColor(ctx) end
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
    ImGui.SetNextWindowSize(ctx, state.window_w, state.window_h, ImGui.Cond_FirstUseEver)
    local visible, open = ImGui.Begin(ctx, SCRIPT_NAME .. " v" .. VERSION, true, state.window_flags)
    if visible then
        state.window_w, state.window_h = ImGui.GetWindowSize(ctx)

        if ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) and not ImGui.IsAnyItemActive(ctx) then
            open = false
        end
        DrawMenuBar()
        DrawToolbar()
        ImGui.Spacing(ctx)
        DrawTagsBar()
        ImGui.Spacing(ctx)
        DrawBreadcrumbs()
        ImGui.Spacing(ctx)
        DrawSearchBar()
        ImGui.Spacing(ctx)

        -- Calculate remaining height for tree and list
        local _, cur_y = ImGui.GetCursorPos(ctx)
        local win_h = ImGui.GetWindowHeight(ctx)
        local info_panel_h = (state.selected_file and state.script_info) and 150 or 0
        local list_h = win_h - cur_y - info_panel_h - 20
        if list_h < 100 then list_h = 100 end

        DrawFolderTree(list_h)
        DrawFileList(list_h)
        DrawInfoPanel()
        ImGui.End(ctx)
    end
    DrawSettingsWindow()
    DrawManageTagsWindow()
    if open then
        DrawAddCustomPathModal()
        DrawAssignTagsModal()
        reaper.defer(MainLoop)
    else
        SaveConfig()
    end
end

LoadConfig()
ScanDirectory(state.current_path)
reaper.defer(MainLoop)
