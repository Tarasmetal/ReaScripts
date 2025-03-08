-- @description Move selected items files to region folder
-- @author Taras Umanskiy
-- @version 1.2
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about
--   Moves source files of selected items to a directory named after the region located at the edit cursor position OR the item's position.
--   Includes a GUI to preview file moves before execution.
-- @changelog
--   v1.2
--     + Added option to use Item Position for region detection (instead of just Edit Cursor).
--   v1.1
--     + Changed logic: files are now moved to the folder of the region under the Edit Cursor.

local ctx = reaper.ImGui_CreateContext('Move Files to Region Folder by Taras Umanskiy v.1.2')
local FONT_SIZE = 13
local sans_serif = reaper.ImGui_CreateFont('sans-serif', FONT_SIZE)
reaper.ImGui_Attach(ctx, sans_serif)

-- Global state
local scanned_files = {} -- Stores proposed moves
local status_msg = "Ready to scan."
local use_cursor_position = false -- Toggle for region detection mode

-- Helper Functions
function Msg(param) reaper.ShowConsoleMsg(tostring(param).."\n") end

local function RecursiveCreateDirectory(path)
    local separator = package.config:sub(1,1)
    local p = ""
    for folder in path:gmatch("[^"..separator.."]+") do
        p = p .. folder .. separator
        reaper.RecursiveCreateDirectory(p, 0)
    end
end

local function GetRegionAtTime(time)
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if retval and isrgn then
            if time >= pos and time < rgnend then
                return name ~= "" and name or "Unnamed Region"
            end
        end
    end
    return nil
end

local function MoveFile(source, dest)
    -- Ensure destination directory exists
    local dest_dir = dest:match("(.*[/\\])")
    if dest_dir then RecursiveCreateDirectory(dest_dir) end

    -- 1. Try SWS
    if reaper.BR_Win32_MoveFile then
        if reaper.BR_Win32_MoveFile(source, dest) then return true end
    end

    -- 2. Try os.rename (check if os exists)
    if os and os.rename then
        local result, err = os.rename(source, dest)
        if result then return true end
    end

    -- 3. Try shell command (Fallback)
    local cmd = ""
    if package.config:sub(1,1) == "\\" then
        -- Windows: move is a shell internal command, needs cmd.exe /C
        cmd = 'cmd.exe /C move /Y "' .. source .. '" "' .. dest .. '"'
    else
        -- Unix/Mac
        cmd = 'mv -f "' .. source .. '" "' .. dest .. '"'
    end

    -- Try os.execute if available
    if os and os.execute then
        local execute_result = os.execute(cmd)
        if execute_result == 0 or execute_result == true then
            if reaper.file_exists(dest) then return true end
        end
    end

    -- Try reaper.ExecProcess if available
    if reaper.ExecProcess then
        reaper.ExecProcess(cmd, 0)
        if reaper.file_exists(dest) then return true end
    end

    -- Final check
    return reaper.file_exists(dest)
end

-- Logic Functions
local function ScanItems()
    scanned_files = {}
    local count = reaper.CountSelectedMediaItems(0)
    if count == 0 then
        status_msg = "No items selected."
        return
    end

    local project_path = reaper.GetProjectPath()
    if project_path == "" then
        status_msg = "Project must be saved first."
        return
    end
    project_path = project_path .. package.config:sub(1,1)

    local cursor_region_name = nil

    -- If using cursor position, determine region once
    if use_cursor_position then
        local cursor_pos = reaper.GetCursorPosition()
        cursor_region_name = GetRegionAtTime(cursor_pos)

        if not cursor_region_name then
            status_msg = "No region at edit cursor."
            return
        end
    end

    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if take then
            local current_region_name = cursor_region_name

            -- If using item position, determine region for each item
            if not use_cursor_position then
                local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                current_region_name = GetRegionAtTime(item_pos)
            end

            if current_region_name then
                local source = reaper.GetMediaItemTake_Source(take)
                local source_path = reaper.GetMediaSourceFileName(source, "")

                if source_path and source_path ~= "" and reaper.file_exists(source_path) then
                    local safe_region_name = current_region_name:gsub('[<>:"/\\|?*]', '_')
                    local file_name = source_path:match("^.+[\\/](.+)$")
                    local dest_path = project_path .. safe_region_name .. package.config:sub(1,1) .. file_name

                    -- Only add if paths are different
                    if source_path ~= dest_path then
                        table.insert(scanned_files, {
                            item = item,
                            take = take,
                            source_path = source_path,
                            dest_path = dest_path,
                            file_name = file_name,
                            region = current_region_name
                        })
                    end
                end
            end
        end
    end
    status_msg = "Scanned " .. #scanned_files .. " move candidates."
end

local function ExecuteMoves()
    if #scanned_files == 0 then return end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    -- Save current selection
    local saved_selection = {}
    local count = reaper.CountSelectedMediaItems(0)
    for i = 0, count - 1 do
        saved_selection[reaper.GetSelectedMediaItem(0, i)] = true
    end

    -- Select only scanned items for offline toggling
    reaper.Main_OnCommand(40289, 0) -- Unselect all items
    for _, entry in ipairs(scanned_files) do
        reaper.SetMediaItemSelected(entry.item, true)
    end

    -- Set items offline to release file locks
    reaper.Main_OnCommand(40100, 0)

    local success_count = 0
    local fail_count = 0

    -- Move files and update sources
    for _, entry in ipairs(scanned_files) do
        local success = false
        if MoveFile(entry.source_path, entry.dest_path) then
            success = true
        else
            -- If move failed, maybe file already exists or permission denied
            reaper.ShowConsoleMsg("Failed to move: " .. entry.source_path .. " -> " .. entry.dest_path .. "\n")
        end

        if success then
            success_count = success_count + 1
            local new_source = reaper.PCM_Source_CreateFromFile(entry.dest_path)
            if new_source then
                reaper.SetMediaItemTake_Source(entry.take, new_source)
            end
        else
            fail_count = fail_count + 1
        end
    end

    -- Set items online
    reaper.Main_OnCommand(40101, 0)

    -- Restore selection
    reaper.Main_OnCommand(40289, 0)
    for item, _ in pairs(saved_selection) do
        if reaper.ValidatePtr(item, "MediaItem*") then
            reaper.SetMediaItemSelected(item, true)
        end
    end

    reaper.Undo_EndBlock("Move item files to region folders", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()

    status_msg = string.format("Moved: %d, Failed: %d", success_count, fail_count)
    scanned_files = {} -- Clear list after execution
end

-- GUI Main Loop
local function loop()
    reaper.ImGui_PushFont(ctx, sans_serif, FONT_SIZE)
    local window_flags = reaper.ImGui_WindowFlags_None()
    reaper.ImGui_SetNextWindowSize(ctx, 700, 400, reaper.ImGui_Cond_FirstUseEver())

    local visible, open = reaper.ImGui_Begin(ctx, 'Move Files to Region Folder by Taras Umanskiy v.1.2', true, window_flags)

    if visible then
        -- Controls Area
        if reaper.ImGui_Button(ctx, 'Scan Selected Items') then
            ScanItems()
        end

        reaper.ImGui_SameLine(ctx)

        -- Checkbox for mode selection
        local retval, v = reaper.ImGui_Checkbox(ctx, 'Use Edit Cursor Position', use_cursor_position)
        if retval then use_cursor_position = v end

        -- Tooltip for the checkbox
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetTooltip(ctx, "If checked: Uses the region at the edit cursor for all items.\nIf unchecked: Uses the region at each item's start position.")
        end

        reaper.ImGui_Text(ctx, status_msg)

        reaper.ImGui_Separator(ctx)

        -- File List Table
        local region_avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
        local table_flags = reaper.ImGui_TableFlags_Borders() |
                            reaper.ImGui_TableFlags_RowBg() |
                            reaper.ImGui_TableFlags_Resizable() |
                            reaper.ImGui_TableFlags_ScrollY()

        if reaper.ImGui_BeginTable(ctx, 'files_table', 3, table_flags, region_avail_w, -40) then
            reaper.ImGui_TableSetupColumn(ctx, 'File Name', reaper.ImGui_TableColumnFlags_WidthStretch())
            reaper.ImGui_TableSetupColumn(ctx, 'Region / Folder', reaper.ImGui_TableColumnFlags_WidthFixed(), 150)
            reaper.ImGui_TableSetupColumn(ctx, 'Destination Path', reaper.ImGui_TableColumnFlags_WidthStretch())
            reaper.ImGui_TableHeadersRow(ctx)

            if #scanned_files == 0 then
                reaper.ImGui_TableNextRow(ctx)
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_TextColored(ctx, 0x808080FF, "No files to move.")
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_TableNextColumn(ctx)
            else
                for _, entry in ipairs(scanned_files) do
                    reaper.ImGui_TableNextRow(ctx)

                    reaper.ImGui_TableNextColumn(ctx)
                    reaper.ImGui_Text(ctx, entry.file_name)

                    reaper.ImGui_TableNextColumn(ctx)
                    reaper.ImGui_Text(ctx, entry.region)

                    reaper.ImGui_TableNextColumn(ctx)
                    reaper.ImGui_Text(ctx, entry.dest_path)
                end
            end
            reaper.ImGui_EndTable(ctx)
        end

        -- Bottom Action Area
        reaper.ImGui_Separator(ctx)

        if #scanned_files > 0 then
            if reaper.ImGui_Button(ctx, 'MOVE FILES', 120, 30) then
                ExecuteMoves()
            end
        else
            reaper.ImGui_BeginDisabled(ctx)
            reaper.ImGui_Button(ctx, 'MOVE FILES', 120, 30)
            reaper.ImGui_EndDisabled(ctx)
        end

        reaper.ImGui_End(ctx)
    end

    reaper.ImGui_PopFont(ctx)

    if open then
        reaper.defer(loop)
    end
end

reaper.defer(loop)
