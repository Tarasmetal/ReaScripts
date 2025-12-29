-- @description VST Macro Linker (16 Colors)
-- @author Taras Umanskiy
-- @version 3.60
-- @provides [main] .
--   [script] trs_VST_Macro_Linker.jsfx
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about Скрипт для линковки параметров VST в цветные макросы (до 16 шт)
-- @changelog
--   + Optimization: Implemented Interlaced Sync (50% params per frame) to reduce CPU usage.
--   + Optimization: Implemented Project State Caching to reduce API calls.
--   + Optimization: Implemented UI String Caching to reduce garbage collection overhead (significant reduction in string allocations per frame).
--   + Optimization: Preset list caching (disk IO reduction).
--   + Optimization: ExtState caching for last used preset.
--   + Optimization: Throttled backend validation (CPU reduction).
--   + Optimization: ImGui style vars caching.
--   + Optimization: Added Track Caching to reduce CPU usage (GetTrackByGUID).
--   + Optimization: Added Lookup Tables for Linked Parameters to speed up GUI and processing.
--   + Optimization: Targeted parameter updates (only update parameters for the changed macro).
--   + Added: Track Automation Mode switches (Trim/Read, Read, Touch, Latch, Latch Prev, Write).
--   + UI: Moved Automation controls to top section (below Automation toggle).
--   + Fixed: Master Track parameters can now be controlled correctly (Added Master Track check in GetTrackByGUID).
--   + Pads: Linking now defaults "Min" to 0.0 (instead of current value).
--   + Pads: Hidden "Offset" slider in Linked Parameters list (not needed for buttons).
--   + Added hotkey 'H' to toggle Linked Parameters visibility.
--   + Added "Offset" slider to Linked Parameters (Default 0.50).
--   + Allows shifting the modulation range up or down.
--   + Simplification: Removed "Position" parameter.
--   + Linking Logic: Initial parameter value is now automatically set to "Min" value.
--   + This allows modulation to start from the current parameter position.
--   + Global Persistence: "Automation" checkbox state is now remembered globally via ExtState
--   + Added "Automation" checkbox to toggle JSFX backend connection
--   + Script now works purely as a controller if Automation is OFF
--   + Saved Automation state in settings
--   + Pads: Increased count to 16
--   + Pads: Added automation sync with JSFX backend
--   + Pads: Fix tooltip state always showing OFF (scoping issue)
--   + Pads: Fix toggle behavior logic (explicit check)
--   + Pads: MIDI Learn mode now displays Pad in Yellow with Black text
--   + Pads: Toggle MIDI Learn mode on/off with Ctrl+R-Click

local r = reaper
console = false -- DEBUG ENABLED

function msg(value) if console then r.ShowConsoleMsg(tostring(value) .. "\n") end end

title = 'VST Macro Linker'
VERSION = '3.60'
author = 'Taras Umanskiy'
about = title .. ' ' .. VERSION .. ' | by ' .. author
ListDir = {}
ListDir.scriptDir, ListDir.scriptFileName = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")
scriptDir = ListDir.scriptDir
scriptFileName = ListDir.scriptFileName
windowTitle = about

local ctx = r.ImGui_CreateContext(windowTitle)
-- local size =  r.GetAppVersion():match('Win64') and 12 or 14
local size =  12
local font = reaper.ImGui_CreateFont('sans-serif', size)
reaper.ImGui_Attach(ctx, font)

-- --- Application State ---
-- Colors for 16 macros (RGBA)
local macro_colors = {
    -- Set 1 (Original)
    0xFF4444FF, -- Red
    0xFF8844FF, -- Orange
    0xFFCC44FF, -- Yellow
    0x44CC44FF, -- Green
    0x44CCCCFF, -- Cyan
    0x4488FFFF, -- Blue
    0x8844FFFF, -- Purple
    0xFF44CCFF, -- Magenta
    -- Set 2 (New)
    0xAAFF44FF, -- Lime
    0x44FF88FF, -- Spring Green
    0x44FFAAFF, -- Mint
    0x44AAFFFF, -- Sky Blue
    0x2244FFFF, -- Deep Blue
    0x5500FFFF, -- Indigo
    0xFF2288FF, -- Hot Pink
    0xDDAA22FF  -- Goldenrod
}

local MAX_MACROS = 16
local MAX_PADS = 16
local TOTAL_PARAMS = MAX_MACROS + MAX_PADS -- 32
local visible_macros = 8

local macro_names = {}
local macro_values = {}
local show_linked_params = true
local automation_enabled = (r.GetExtState("VST_Macro_Linker", "AutomationEnabled") == "true")

-- UI Cache Strings
local ui_cache = {}

function UpdateUIStrings()
    for i = 1, TOTAL_PARAMS do
        if not ui_cache[i] then ui_cache[i] = {} end

        -- Macros
        if i <= MAX_MACROS then
            ui_cache[i].slider_format = macro_names[i] .. ": %.2f"
            ui_cache[i].btn_link = "Link##" .. i
            ui_cache[i].btn_learn = "M##" .. i
            ui_cache[i].btn_learn_cancel = "L##" .. i
            ui_cache[i].slider_id = "##Slider" .. i -- Use explicit ID to avoid PushID dependency if needed, but PushID is cleaner
        else
            -- Pads
            ui_cache[i].btn_pad = "##Pad" -- Suffix, prefix handled in draw loop
        end
    end
end

-- Initialize names and values
for i = 1, TOTAL_PARAMS do
    if i <= MAX_MACROS then
        macro_names[i] = "Macro " .. i
    else
        macro_names[i] = "Pad " .. (i - MAX_MACROS)
    end
    macro_values[i] = 0.0
end
UpdateUIStrings()

-- Automation Backend State
local backend_jsfx_name = "VST Macro Linker"
local backend_jsfx_filename = "trs_VST_Macro_Linker.jsfx"
local backend_track = nil
local backend_fx_id = -1
local backend_missing = false

local linked_params = {}
-- Structure: { track_guid, fx_id, param_id, track_name, fx_name, param_name, min_val, max_val, inverted, macro_idx }

-- Optimization Globals
local links_by_macro = {} -- Index: [macro_idx] = {param_obj, ...}
local track_cache = {} -- GUID -> MediaTrack*
local last_proj_change_count = 0

-- Cache Globals
local presets_cache = nil
local presets_cache_time = 0
local PRESETS_CACHE_TTL = 2.0 -- seconds
local last_preset_cache = nil
local frame_counter = 0
local VALIDATE_INTERVAL = 30

-- Rebuild index for fast lookups (Call this whenever linked_params changes)
function BuildLinkIndex()
    links_by_macro = {}
    for _, p in ipairs(linked_params) do
        if not links_by_macro[p.macro_idx] then
            links_by_macro[p.macro_idx] = {}
        end
        table.insert(links_by_macro[p.macro_idx], p)
    end
end

-- MIDI Map State
local macro_midi_map = {} -- { [macro_idx] = {status=0xB0, cc=10} }
local learning_macro_idx = nil
local last_event_count = 0 -- Using event counter instead of timestamp
local last_midi_activity_time = 0
local last_touched_param = "None"
local last_linked_macro_idx = 1
local key_state = {}

-- Preset UI State
local new_preset_name_buf = ""
local selected_preset_idx = 0

-- API Compatibility
local GetRecentInputEvent = r.GetRecentInputEvent or r.MIDI_GetRecentInputEvent
local has_midi_api = (GetRecentInputEvent ~= nil)

if not has_midi_api then
    local app_ver = r.GetAppVersion()
    r.ShowConsoleMsg("WARNING: GetRecentInputEvent API not found! MIDI Learn will be disabled.\n")
    r.ShowConsoleMsg("Current REAPER version: " .. app_ver .. "\n")
    r.ShowConsoleMsg("Please update to REAPER 7.03 or newer to use MIDI Learn.\n")
end

-- Initialize event counter to ignore old events
if has_midi_api then
    -- Get the current newest event count
    local retval = GetRecentInputEvent(0)
    if retval then last_event_count = retval end
end

-- --- Preset Management ---
local preset_dir = scriptDir .. "MacroPresets"
local separator = package.config:sub(1,1)
-- Ensure trailing slash for directory construction if needed
if not preset_dir:match("[\\/]$") then preset_dir = preset_dir .. separator end

function EnsurePresetDir()
    r.RecursiveCreateDirectory(preset_dir, 0)
end

function GetLastUsedPreset()
    if not last_preset_cache then
         last_preset_cache = r.GetExtState("VST_Macro_Linker", "LastMidiPreset")
    end
    return last_preset_cache
end

function SetLastUsedPreset(name)
    last_preset_cache = name
    r.SetExtState("VST_Macro_Linker", "LastMidiPreset", name, true)
end

function SavePreset(name)
    EnsurePresetDir()
    if not name or name == "" then return false end
    local filepath = preset_dir .. name .. ".txt"
    local file = io.open(filepath, "w")
    if file then
        -- Serialize macro_midi_map
        -- Format: macro_idx,status,cc
        for idx, map in pairs(macro_midi_map) do
            file:write(string.format("%d,%d,%d\n", idx, map.status, map.cc))
        end
        io.close(file)
        SetLastUsedPreset(name) -- Remember as last used
        presets_cache = nil -- Invalidate cache
        return true
    end
    return false
end

function LoadPreset(name)
    local filepath = preset_dir .. name .. ".txt"
    local file = io.open(filepath, "r")
    if file then
        macro_midi_map = {} -- Clear current map
        for line in file:lines() do
            local idx, status, cc = line:match("(%d+),(%d+),(%d+)")
            if idx then
                macro_midi_map[tonumber(idx)] = { status = tonumber(status), cc = tonumber(cc) }
            end
        end
        io.close(file)
        SetLastUsedPreset(name) -- Remember as last used
        return true
    end
    return false
end

function GetPresetsList()
    local now = r.time_precise()
    if presets_cache and (now - presets_cache_time) < PRESETS_CACHE_TTL then
        return presets_cache
    end

    local files = {}
    local idx = 0
    EnsurePresetDir() -- Ensure dir exists before enumerating
    while true do
        local file = r.EnumerateFiles(preset_dir, idx)
        if not file then break end
        if file:match("%.txt$") then
            table.insert(files, (file:gsub("%.txt$", "")))
        end
        idx = idx + 1
    end
    presets_cache = files
    presets_cache_time = now
    return files
end

-- --- Linked Params Persistence ---

function GetProjectDir()
    local _, proj_fn = r.EnumProjects(-1)
    if proj_fn == "" then return "" end
    return proj_fn:match("(.*[/\\])") or ""
end

function GetProjectAutoSavePath()
    local _, proj_fn = r.EnumProjects(-1)
    if proj_fn == "" then return nil end
    return proj_fn:gsub("%.RPP$", "") .. "_ML.ini"
end

function SaveLinkedParams(filepath)
    if not filepath then return end
    local f = io.open(filepath, "w")
    if not f then return end

    f:write("[Version]\n2.9\n")

    f:write("[Settings]\n")
    f:write("ShowLinkedParams=" .. tostring(show_linked_params) .. "\n")
    f:write("AutomationEnabled=" .. tostring(automation_enabled) .. "\n")

    f:write("[LinkedParams]\n")
    for _, p in ipairs(linked_params) do
        -- Escape pipes in names to prevent parsing errors
        local tn = p.track_name:gsub("|", "")
        local fn = p.fx_name:gsub("|", "")
        local pn = p.param_name:gsub("|", "")

        f:write(string.format("%s|%d|%d|%d|%.4f|%.4f|%s|%s|%s|%s|%.4f\n",
            p.track_guid, p.fx_id, p.param_id, p.macro_idx,
            p.min_val, p.max_val, tostring(p.inverted),
            tn, fn, pn, p.offset or 0.5))
    end

        f:write("[MacroNames]\n")
    for i=1, TOTAL_PARAMS do
        f:write(macro_names[i] .. "\n")
    end
    io.close(f)
end

function LoadLinkedParams(filepath)
    local f = io.open(filepath, "r")
    if not f then return end

    local section = nil
    local new_links = {}
    local new_names = {}

    for line in f:lines() do
        -- Trim whitespace
        line = line:match("^%s*(.-)%s*$")
        if line:match("^%[.*%]$") then
            section = line:match("^%[(.*)%]$")
        elseif line ~= "" then
            if section == "Settings" then
                local k, v = line:match("([^=]+)=([^=]+)")
                if k == "ShowLinkedParams" then
                    show_linked_params = (v == "true")
                elseif k == "AutomationEnabled" then
                    automation_enabled = (v == "true")
                end
            elseif section == "LinkedParams" then
                local parts = {}
                for part in line:gmatch("[^|]+") do table.insert(parts, part) end
                if #parts >= 10 then
                    table.insert(new_links, {
                        track_guid = parts[1],
                        fx_id = tonumber(parts[2]),
                        param_id = tonumber(parts[3]),
                        macro_idx = tonumber(parts[4]),
                        min_val = tonumber(parts[5]),
                        max_val = tonumber(parts[6]),
                        inverted = (parts[7] == "true"),
                        track_name = parts[8],
                        fx_name = parts[9],
                        param_name = parts[10],
                        offset = tonumber(parts[11]) or 0.5
                    })
                end
            elseif section == "MacroNames" then
                table.insert(new_names, line)
            end
        end
    end
    io.close(f)

    if #new_links > 0 then linked_params = new_links end
    if #new_names > 0 then
        for i=1, math.min(#new_names, TOTAL_PARAMS) do
            macro_names[i] = new_names[i]
        end
    end
    BuildLinkIndex()
    UpdateLinkedParams()
    UpdateUIStrings() -- Refresh UI strings with new names
end

-- --- Helper Functions ---

function InstallBackendJSFX()
    local src = scriptDir .. backend_jsfx_filename
    local res_path = r.GetResourcePath()
    local sep = r.GetOS():match("Win") and "\\" or "/"
    local dest_dir = res_path .. sep .. "Effects" .. sep .. "Taras Scripts"
    local dest = dest_dir .. sep .. backend_jsfx_filename

    if r.GetOS():match("Win") then
        src = src:gsub("/", "\\")
    end

    -- Check if source exists
    if not r.file_exists(src) then
        r.ShowMessageBox("Source JSFX not found at:\n" .. src, "Error", 0)
        return false
    end

    -- Create directory
    r.RecursiveCreateDirectory(dest_dir, 0)

    -- Copy file
    local infile = io.open(src, "rb")
    if not infile then
        r.ShowMessageBox("Could not open source file for reading.", "Error", 0)
        return false
    end
    local content = infile:read("*a")
    infile:close()

    local outfile = io.open(dest, "wb")
    if not outfile then
        r.ShowMessageBox("Could not open destination file for writing:\n" .. dest, "Error", 0)
        return false
    end
    outfile:write(content)
    outfile:close()

    return true
end

function GetBackendPath()
    -- Construct path to JSFX in script directory
    local path = scriptDir .. backend_jsfx_filename
    if r.GetOS():match("Win") then
        path = path:gsub("/", "\\")
    end
    return path
end

function InitializeBackend()
    if not automation_enabled then
        backend_missing = false
        return false
    end

    -- 1. Find specific track "VST Macro Linker"
    local target_track = nil
    local count = r.CountTracks(0)
    for i = 0, count - 1 do
        local tr = r.GetTrack(0, i)
        local _, name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        if name == "VST Macro Linker" then
            target_track = tr
            break
        end
    end

    -- If track not found, create it at index 0 (start of project)
    if not target_track then
        r.InsertTrackAtIndex(0, true)
        target_track = r.GetTrack(0, 0)
        r.GetSetMediaTrackInfo_String(target_track, "P_NAME", "VST Macro Linker", true)
    end

    -- 2. Search for JSFX on this track
    local fx_count = r.TrackFX_GetCount(target_track)
    for i = 0, fx_count - 1 do
        local retval, buf = r.TrackFX_GetFXName(target_track, i, "")
        if retval and (buf:find(backend_jsfx_name, 1, true) or buf:find(backend_jsfx_filename, 1, true)) then
            backend_track = target_track
            backend_fx_id = i
            backend_missing = false
            return true
        end
    end

    -- 3. Create FX if not found
    local path = GetBackendPath()
    local idx = r.TrackFX_AddByName(target_track, path, false, -1)

    -- If absolute path failed, try direct filename (if user installed it in REAPER Effects)
    if idx < 0 then
         idx = r.TrackFX_AddByName(target_track, backend_jsfx_filename, false, -1)
    end

    -- If still failed, try specifically in Taras Scripts folder
    if idx < 0 then
         idx = r.TrackFX_AddByName(target_track, "Taras Scripts/" .. backend_jsfx_filename, false, -1)
    end

    -- If still failed
    if idx < 0 then
         backend_missing = true
         return false
    end

    if idx >= 0 then
        backend_track = target_track
        backend_fx_id = idx
        backend_missing = false
        -- Initialize JSFX with current Lua values
        for i=1, TOTAL_PARAMS do
             r.TrackFX_SetParamNormalized(target_track, idx, i-1, macro_values[i])
        end
        return true
    end

    return false
end

function ValidateBackend()
    if not automation_enabled then return true end

    if backend_track and r.ValidatePtr2(0, backend_track, "MediaTrack*") then
         -- Verify it's still the right FX (in case user deleted/replaced it)
         local retval, buf = r.TrackFX_GetFXName(backend_track, backend_fx_id, "")
         if retval and (buf:find(backend_jsfx_name, 1, true) or buf:find(backend_jsfx_filename, 1, true)) then
             backend_missing = false
             return true
         end
    end
    backend_missing = true
    return false
end

function PollMIDI()
    if not has_midi_api then return end

    -- Get the newest event count
    -- retval acts as a sequential counter for events
    local current_count, _, _, _, _, _, _, _ = GetRecentInputEvent(0)

    if not current_count then return end

    -- If counts match, no new events.
    -- If current < last, counter wrapped or reset, just update last.
    if current_count <= last_event_count then
        return
    end

    -- How many new events?
    local num_new_events = current_count - last_event_count
    if num_new_events > 64 then num_new_events = 64 end -- Process max 64 events at once to prevent freeze

    -- Collect new events (Index 0 is newest, so we iterate from num_new-1 down to 0 to get oldest->newest order)
    -- Actually, to process in order, we should fetch indices (num_new_events - 1) down to 0

    local events_to_process = {}

    for i = 0, num_new_events - 1 do
        -- Capture raw returns to handle API differences (safely find the string argument)
        local rv1, rv2, rv3, rv4, rv5, rv6 = GetRecentInputEvent(i)

        -- Standard: rv1=retval(int), rv2=selected(bool), rv3=loop(bool), rv4=midimsg(str), rv5=ts(num)
        -- Fallback: rv1=retval(int), rv2=midimsg(str), rv3=ts(num) ... (if bools missing)

        local retval = rv1
        local midimsg = nil
        local ts = 0

        if type(rv4) == 'string' then
            midimsg = rv4; ts = rv5
        elseif type(rv2) == 'string' then
            midimsg = rv2; ts = rv3
        elseif type(rv3) == 'string' then
            midimsg = rv3; ts = rv4
        end

        -- Sanity check: verify this event is actually newer than our last processed count
        -- Also verify midimsg is a valid string
        if retval and retval > last_event_count and midimsg and #midimsg >= 3 then
            table.insert(events_to_process, {msg=midimsg, ts=ts, count=retval})
        end
    end

    -- Update high-water mark
    last_event_count = current_count

    -- Events are currently Newest -> Oldest in the table because we fetched 0, 1, 2...
    -- But Wait: Index 0 is Newest. Index 1 is older.
    -- So if we iterate i from 0 to num-1, we are collecting Newest, then Older, then Older.
    -- To process correctly (Oldest -> Newest), we need to reverse the processing order.

    for i = #events_to_process, 1, -1 do
        local evt = events_to_process[i]
        local midimsg = evt.msg
        local status = midimsg:byte(1)
        local data1 = midimsg:byte(2) or 0 -- Data 1 (CC Number / Note)
        local data2 = midimsg:byte(3) or 0 -- Data 2 (Value / Velocity)

        last_midi_activity_time = r.time_precise()

        -- DEBUG: Print all incoming MIDI events if learning
        if learning_macro_idx then
             msg(string.format("MIDI IN: Status=%02X (%d) D1=%d D2=%d", status, status, data1, data2))
        end

        -- Filter for Control Change (CC) and Note On (0x90-0x9F)
        local is_cc = (status >= 0xB0 and status <= 0xBF)
        local is_note = (status >= 0x90 and status <= 0x9F) and (data2 > 0) -- Ignore Note On vel 0 (Note Off)

        if is_cc or is_note then

            -- LEARN MODE
            if learning_macro_idx then
                macro_midi_map[learning_macro_idx] = { status = status, cc = data1 }
                learning_macro_idx = nil -- Exit learn mode

            -- CONTROL MODE
            else
                for m_idx = 1, TOTAL_PARAMS do
                    local map = macro_midi_map[m_idx]
                    -- Match Channel (Status) and CC Number (or Note Number)
                    if map and map.status == status and map.cc == data1 then
                        local new_val = data2 / 127.0

                        -- For Pads (indices > 16)
                        if m_idx > MAX_MACROS then
                            -- Toggle Logic
                            -- For CC: If value goes high (>64), toggle state
                            -- For Note: Any velocity > 0 triggers toggle (filtered by is_note check above)
                            local trigger = false
                            if is_note then
                                trigger = true
                            elseif is_cc and new_val > 0.5 then
                                trigger = true
                            end

                            if trigger then
                                if (macro_values[m_idx] < 0.5) then
                                     macro_values[m_idx] = 1.0
                                else
                                     macro_values[m_idx] = 0.0
                                end
                                UpdateLinkedParams(m_idx)

                                if automation_enabled and not backend_missing then
                                    r.TrackFX_SetParamNormalized(backend_track, backend_fx_id, m_idx-1, macro_values[m_idx])
                                end
                            end
                        else
                            -- Sliders (Usually controlled by CC)
                            -- If mapped to Note, maybe ignore or treat as switch?
                            -- Assuming CC for Sliders for now, but allowing code to run.

                            -- Only update if value changed significantly
                            if math.abs(macro_values[m_idx] - new_val) > 0.001 then
                                macro_values[m_idx] = new_val
                                UpdateLinkedParams(m_idx)

                                -- Sync to Automation Backend (Only for first 16 macros supported by JSFX)
                                if automation_enabled and not backend_missing and m_idx <= MAX_MACROS then
                                    r.TrackFX_SetParamNormalized(backend_track, backend_fx_id, m_idx-1, macro_values[m_idx])
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function CheckProjectStateChange()
    local proj_change_cnt = r.GetProjectStateChangeCount(0)
    if proj_change_cnt > last_proj_change_count then
        track_cache = {} -- Invalidate cache
        last_proj_change_count = proj_change_cnt
    end
end

function GetTrackByGUID(guid)
    -- Check Cache (Cache invalidation is handled in loop -> CheckProjectStateChange)
    if track_cache[guid] then
        -- Validate pointer (just in case)
        if r.ValidatePtr2(0, track_cache[guid], "MediaTrack*") then
             return track_cache[guid]
        else
             track_cache[guid] = nil
        end
    end

    -- Try SWS Extension
    if r.BR_GetMediaTrackByGUID then
        local tr = r.BR_GetMediaTrackByGUID(0, guid)
        if tr then
            track_cache[guid] = tr
            return tr
        end
    end

    -- Fallback: Manual Search

    -- 1. Check Master Track
    local master = r.GetMasterTrack(0)
    if master and r.GetTrackGUID(master) == guid then
        track_cache[guid] = master
        return master
    end

    -- 2. Check Regular Tracks
    for i = 0, r.CountTracks(0) - 1 do
        local tr = r.GetTrack(0, i)
        if r.GetTrackGUID(tr) == guid then
            track_cache[guid] = tr
            return tr
        end
    end
    return nil
end

function AddLastTouchedParam(target_macro_idx)
    local retval, tracknumber, fxnumber, paramnumber = r.GetLastTouchedFX()
    if not retval then return end

    local track = r.CSurf_TrackFromID(tracknumber, false)
    if not track then return end

    local track_guid = r.GetTrackGUID(track)
    local _, track_name = r.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if track_name == "" then track_name = "Track " .. tostring(math.floor(tracknumber)) end

    local _, fx_name = r.TrackFX_GetFXName(track, fxnumber, "")
    local _, param_name = r.TrackFX_GetParamName(track, fxnumber, paramnumber, "")

    -- Capture Current Value
    local current_val = r.TrackFX_GetParamNormalized(track, fxnumber, paramnumber)

    -- Update last linked macro index for Global Hotkeys
    last_linked_macro_idx = target_macro_idx

    -- Logic for Pads vs Macros
    local is_pad = (target_macro_idx > MAX_MACROS)
    local initial_min = is_pad and 0.0 or current_val

    -- Check for duplicates (update link if exists)
    for i, p in ipairs(linked_params) do
        if p.track_guid == track_guid and p.fx_id == fxnumber and p.param_id == paramnumber then
            p.macro_idx = target_macro_idx
            p.min_val = initial_min -- Update min (0 for pads, current for macros)
            p.offset = 0.5
            BuildLinkIndex()
            return
        end
    end

    table.insert(linked_params, {
        track_guid = track_guid,
        fx_id = fxnumber,
        param_id = paramnumber,
        track_name = track_name,
        fx_name = fx_name,
        param_name = param_name,
        min_val = initial_min, -- Start from current value for Macros, 0 for Pads
        max_val = 1.0,
        inverted = false,
        macro_idx = target_macro_idx,
        offset = 0.5
    })
    BuildLinkIndex()
end

function RemoveLinksForMacro(target_idx)
    local i = 1
    local changed = false
    while i <= #linked_params do
        if linked_params[i].macro_idx == target_idx then
            table.remove(linked_params, i)
            changed = true
        else
            i = i + 1
        end
    end
    if changed then BuildLinkIndex() end
end

function GetNextEmptyMacroIndex()
    for m = 1, MAX_MACROS do
        local used = false
        for _, p in ipairs(linked_params) do
            if p.macro_idx == m then
                used = true
                break
            end
        end
        if not used then return m end
    end
    return 1 -- Fallback if all full
end

function PollGlobalKeys()
    if not r.JS_VKeys_GetState then return end

    -- Get current state of all keys
    local state = r.JS_VKeys_GetState(0)

    -- Key '1' (0x31): Link to last linked macro
    local key1 = state:byte(0x31) ~= 0
    if key1 and not key_state[0x31] then
        AddLastTouchedParam(last_linked_macro_idx)
    end
    key_state[0x31] = key1

    -- Key '2' (0x32): Link to next empty macro
    local key2 = state:byte(0x32) ~= 0
    if key2 and not key_state[0x32] then
        local next_idx = GetNextEmptyMacroIndex()
        AddLastTouchedParam(next_idx)
    end
    key_state[0x32] = key2
end

function UpdateLinkedParams(specific_macro_idx)
    -- If index not built (first run), build it
    if not next(links_by_macro) and #linked_params > 0 then
        BuildLinkIndex()
    end

    local params_to_update = {}

    if specific_macro_idx then
        -- Update specific macro's params
        if links_by_macro[specific_macro_idx] then
            params_to_update = links_by_macro[specific_macro_idx]
        end
    else
        -- Update ALL (fallback or full refresh)
        params_to_update = linked_params
    end

    for _, p in ipairs(params_to_update) do
        local track = GetTrackByGUID(p.track_guid)
        if track then
            local val = macro_values[p.macro_idx]
            if p.inverted then val = 1.0 - val end

            -- Scale
            val = p.min_val + (p.max_val - p.min_val) * val

            -- Apply Offset (0.5 is neutral)
            val = val + ((p.offset or 0.5) - 0.5)

            -- Clamp
            if val < 0.0 then val = 0.0 end
            if val > 1.0 then val = 1.0 end

            r.TrackFX_SetParamNormalized(track, p.fx_id, p.param_id, val)
        end
    end
end

-- --- GUI Functions ---

local function myWindow()
    -- Common Style Vars
    local pad_w, pad_h = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())
    local item_spacing_x, item_spacing_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
    local frame_h_spacing = r.ImGui_GetFrameHeightWithSpacing(ctx)

    -- Info / Header
    -- r.ImGui_TextColored(ctx, 0x992222FF, 'Last Touched: ' .. (last_touched_param or "None"))

    -- Automation Toggle
    local auto_changed, auto_val = r.ImGui_Checkbox(ctx, "Automation", automation_enabled)
    if auto_changed then
        automation_enabled = auto_val
        r.SetExtState("VST_Macro_Linker", "AutomationEnabled", tostring(automation_enabled), true)

        if automation_enabled then
            InitializeBackend()
        else
            backend_missing = false
        end
    end
    if r.ImGui_IsItemHovered(ctx) then
        r.ImGui_SetTooltip(ctx, "Enable/Disable JSFX Automation Backend\nOFF: Script works as controller only (No track created)\nON: Script syncs with 'VST Macro Linker' track for automation")
    end

    r.ImGui_SameLine(ctx)

    if automation_enabled and backend_missing then
        r.ImGui_TextColored(ctx, 0xFF0000FF, "JSFX Missing!")
        if r.ImGui_IsItemHovered(ctx) then
             r.ImGui_SetTooltip(ctx, "The 'VST Macro Linker' JSFX file was not found.\nAutomation will not work.\n\nScript expects: " .. GetBackendPath())
        end
        r.ImGui_SameLine(ctx)

        if r.ImGui_Button(ctx, "Reload") then
             if InstallBackendJSFX() then
                 InitializeBackend()
             end
        end
        if r.ImGui_IsItemHovered(ctx) then
            r.ImGui_SetTooltip(ctx, "Copy JSFX to REAPER/Effects/Taras Scripts and retry")
        end
        r.ImGui_SameLine(ctx)
    end

    -- r.ImGui_SameLine(ctx) -- removed to fix alignment with Automation toggle
    local avail_w = r.ImGui_GetContentRegionAvail(ctx)
    r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx) + avail_w - 20)

    -- MIDI Activity Indicator
    local is_active = (r.time_precise() - last_midi_activity_time) < 0.2
    local col = is_active and 0x00FF00FF or 0x333333FF
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), col)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), col)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), col)
    r.ImGui_Button(ctx, "##MidiIn", 10, 10)
    if r.ImGui_IsItemHovered(ctx) then
        r.ImGui_SetTooltip(ctx, "MIDI Input Activity\nIf this doesn't flash when you move knobs,\ncheck REAPER Preferences > MIDI Devices > Enable input for control messages")
    end
    r.ImGui_PopStyleColor(ctx, 3)

    r.ImGui_Spacing(ctx)

    -- Automation Modes
    local modes = {
        {name="Trim/Read", mode=0},
        {name="Read", mode=1},
        {name="Touch", mode=2},
        {name="Latch", mode=4},
        {name="Latch Prev", mode=5},
        {name="Write", mode=3}
    }

    local current_mode = -1
    local track_valid = (automation_enabled and not backend_missing and backend_track and r.ValidatePtr2(0, backend_track, "MediaTrack*"))

    if track_valid then
        current_mode = r.GetTrackAutomationMode(backend_track)
    end

    for i, m in ipairs(modes) do
        if i > 1 then r.ImGui_SameLine(ctx) end

        local is_active = (current_mode == m.mode)
        if is_active then
            local col = 0x999999FF -- Default Gray
            if m.mode == 1 then col = 0x44CC44FF -- Read Green
            elseif m.mode == 2 then col = 0xCCCC44FF -- Touch Yellow
            elseif m.mode == 3 then col = 0xFF4444FF -- Write Red
            elseif m.mode == 4 then col = 0xCC44CCFF -- Latch Magenta
            elseif m.mode == 5 then col = 0x44CCCCFF -- Latch Prev Cyan
            end

            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), col)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), (col & 0xFFFFFF00) | 0xDD)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), col)
        end

        if r.ImGui_Button(ctx, m.name) then
            if not track_valid then
                -- Auto-enable Automation
                automation_enabled = true
                r.SetExtState("VST_Macro_Linker", "AutomationEnabled", "true", true)
                if InitializeBackend() then
                    track_valid = true
                    backend_missing = false
                end
            end

            if track_valid then
                r.SetTrackAutomationMode(backend_track, m.mode)
            end
        end

        if is_active then
            r.ImGui_PopStyleColor(ctx, 3)
        end
    end
    r.ImGui_Spacing(ctx)

    r.ImGui_Separator(ctx)

    -- Preset Manager (Moved Here)
    -- Refresh preset list
    local presets = GetPresetsList()
    local current_preset = GetLastUsedPreset()

    r.ImGui_AlignTextToFramePadding(ctx)
    r.ImGui_Text(ctx, "MIDI Mapping:")
    r.ImGui_SameLine(ctx)

    -- Preset Combo Box
    r.ImGui_SetNextItemWidth(ctx, 150)
    local preview_val = current_preset or ""
    if preview_val == "" and #presets == 0 then preview_val = "(No presets)" end

    if r.ImGui_BeginCombo(ctx, "##PresetList", preview_val) then
        for i, p_name in ipairs(presets) do
            local is_selected = (current_preset == p_name)
            if r.ImGui_Selectable(ctx, p_name, is_selected) then
                LoadPreset(p_name)
            end
            if is_selected then r.ImGui_SetItemDefaultFocus(ctx) end
        end
        r.ImGui_EndCombo(ctx)
    end

    r.ImGui_SameLine(ctx)

    -- Save Button (Overwrites current)
    local can_save = (current_preset and current_preset ~= "")
    if not can_save then r.ImGui_BeginDisabled(ctx) end

    if r.ImGui_Button(ctx, "Save") then
            if current_preset and current_preset ~= "" then
                SavePreset(current_preset)
            end
    end

    if not can_save then r.ImGui_EndDisabled(ctx) end
    if r.ImGui_IsItemHovered(ctx) then r.ImGui_SetTooltip(ctx, "Overwrite current preset") end

    r.ImGui_SameLine(ctx)

    -- Save As Button (New file)
    if r.ImGui_Button(ctx, "Save As") then
            local retval, retvals_csv = r.GetUserInputs("Save Preset As", 1, "New Preset Name:", current_preset or "")
            if retval then
                local new_name = retvals_csv:match("([^,]+)")
                if new_name and new_name ~= "" then
                    SavePreset(new_name)
                end
            end
    end

    r.ImGui_Spacing(ctx)


    r.ImGui_Separator(ctx)

    -- Macros Section
    -- Auto-calculate height based on content
    local child_height = (frame_h_spacing * visible_macros) + (pad_h * 2)

    if r.ImGui_BeginChild(ctx, "MacrosArea", 0, child_height, 1) then
        for i = 1, visible_macros do
            r.ImGui_PushID(ctx, i)

            -- Check Link State first (Optimized)
            local is_linked = (links_by_macro[i] ~= nil)

            -- Determine Color
            local current_col = macro_colors[i]
            if not is_linked then current_col = 0x888888FF end -- Gray if not linked

            -- Color style for slider
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_SliderGrab(), current_col)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_SliderGrabActive(), 0xFFFFFFFF)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), (current_col & 0xFFFFFF00) | 0x33) -- Dim version for bg
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgHovered(), (current_col & 0xFFFFFF00) | 0x55)

            -- Layout: [L] | [Link] | Slider

            -- Learn Button
            local is_learning = (learning_macro_idx == i)
            local is_mapped = (macro_midi_map[i] ~= nil)

            if is_learning then
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0xFFFF00FF) -- Yellow
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x000000FF) -- Black Text
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0xFFDD00FF)
                if r.ImGui_Button(ctx, ui_cache[i].btn_learn_cancel, 20, 0) then
                    learning_macro_idx = nil -- Cancel learn
                end
                r.ImGui_PopStyleColor(ctx, 3)
            else
                local l_btn_col = 0x444444FF -- Grey
                local l_btn_hov = 0x555555FF
                local l_btn_act = 0x666666FF

                if is_mapped then
                     local map_col = 0x44CC44FF -- Green
                     l_btn_col = (map_col & 0xFFFFFF00) | 0x55
                     l_btn_hov = (map_col & 0xFFFFFF00) | 0xAA
                     l_btn_act = (map_col & 0xFFFFFF00) | 0xFF
                end

                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), l_btn_col)
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), l_btn_hov)
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), l_btn_act)

                if r.ImGui_Button(ctx, ui_cache[i].btn_learn, 20, 0) then
                    if has_midi_api then
                        learning_macro_idx = i
                    else
                        r.ShowMessageBox("MIDI Learn requires REAPER 7.03+.\nCurrent version: " .. r.GetAppVersion(), "Feature Not Available", 0)
                    end
                end

                r.ImGui_PopStyleColor(ctx, 3)

                if r.ImGui_IsItemHovered(ctx) then
                    if is_mapped then
                        local m = macro_midi_map[i]
                        local type_str = ((m.status & 0xF0) == 0x90) and "Note" or "CC"
                        r.ImGui_SetTooltip(ctx, string.format("Mapped to Ch %d %s %d\nClick to Re-Learn", (m.status & 0x0F) + 1, type_str, m.cc))
                    else
                        r.ImGui_SetTooltip(ctx, "MIDI Learn")
                    end
                end
            end

            if is_learning then
                if r.ImGui_IsItemHovered(ctx) then
                     r.ImGui_SetTooltip(ctx, "Waiting for MIDI...\nMove a knob or press a key")
                end
            end

            r.ImGui_SameLine(ctx)

            -- Link Button
            local btn_col = 0x444444FF -- Grey
            local btn_hov = 0x555555FF
            local btn_act = 0x666666FF

            if is_linked then
                 -- Darker (lower alpha) for normal state
                 btn_col = (macro_colors[i] & 0xFFFFFF00) | 0x55
                 btn_hov = (macro_colors[i] & 0xFFFFFF00) | 0xAA
                 btn_act = (macro_colors[i] & 0xFFFFFF00) | 0xFF
            end

            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), btn_col)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), btn_hov)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), btn_act)

            if r.ImGui_Button(ctx, ui_cache[i].btn_link) then
                AddLastTouchedParam(i)
            end

            -- Right Click to Remove Links
            if r.ImGui_IsItemClicked(ctx, 1) then
                RemoveLinksForMacro(i)
            end

            r.ImGui_PopStyleColor(ctx, 3)

            if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_SetTooltip(ctx, "L-Click: Link Last Touched Parameter\nR-Click: Remove All Links from " .. macro_names[i])
            end

            r.ImGui_SameLine(ctx)
            r.ImGui_SetNextItemWidth(ctx, -1)
            local changed, new_val = r.ImGui_SliderDouble(ctx, ui_cache[i].slider_id, macro_values[i], 0.0, 1.0, ui_cache[i].slider_format)

            local is_active = r.ImGui_IsItemActive(ctx)
            local is_edited = r.ImGui_IsItemEdited(ctx)

            if changed then
                macro_values[i] = new_val
                UpdateLinkedParams(i)
            end

            -- Automation Sync
            if automation_enabled and not backend_missing then
                if is_active or changed then
                    -- User -> Backend (Write Automation)
                    r.TrackFX_SetParamNormalized(backend_track, backend_fx_id, i-1, macro_values[i])
                else
                    -- Backend -> User (Read Automation)
                    -- Throttled Sync: Check 50% of params per frame (Interlaced)
                    if (i + frame_counter) % 2 == 0 then
                        local val = r.TrackFX_GetParamNormalized(backend_track, backend_fx_id, i-1)
                        if math.abs(val - macro_values[i]) > 0.0001 then
                             macro_values[i] = val
                             UpdateLinkedParams(i)
                        end
                    end
                end
            end

            r.ImGui_PopStyleColor(ctx, 4)
            r.ImGui_PopID(ctx)
        end
        r.ImGui_EndChild(ctx)
    end

    -- Toggle Button for Macros count
    r.ImGui_Spacing(ctx)

    if visible_macros == 8 then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x339933FF) -- Darker Green
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0x44BB44FF)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), 0x227722FF)
        if r.ImGui_Button(ctx, "+ Add 8 More Macros", -1) then
            visible_macros = 16
        end
        r.ImGui_PopStyleColor(ctx, 3)
    else
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0xCC3333FF) -- Darker Red
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0xEE4444FF)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), 0x992222FF)
        if r.ImGui_Button(ctx, "- Remove 8 Macros", -1) then
            visible_macros = 8
        end
        r.ImGui_PopStyleColor(ctx, 3)
    end

    r.ImGui_Separator(ctx)

    -- Pads Section
    -- r.ImGui_Text(ctx, "Pads:")

    local pad_size = 35
    local pads_per_row = 8 -- Changed to 8 per row

    for i = 1, MAX_PADS do
        local pad_idx = MAX_MACROS + i
        r.ImGui_PushID(ctx, pad_idx)

        -- Check Link State (Optimized)
        local is_linked_pad = (links_by_macro[pad_idx] ~= nil)

        -- Sync from Backend (Read Automation)
        if automation_enabled and not backend_missing then
            -- Throttled Sync: Check 50% of pads per frame (Interlaced)
            if (pad_idx + frame_counter) % 2 == 0 then
                local val = r.TrackFX_GetParamNormalized(backend_track, backend_fx_id, pad_idx-1)
                -- Only update if significantly different (ignoring float jitter)
                if math.abs(val - macro_values[pad_idx]) > 0.001 then
                    macro_values[pad_idx] = (val > 0.5) and 1.0 or 0.0
                    UpdateLinkedParams(pad_idx)
                end
            end
        end

        -- Determine Visuals
        local is_learning = (learning_macro_idx == pad_idx)
        local pushed_colors = 0
        local is_on = (macro_values[pad_idx] > 0.5)

        if is_learning then
            -- Yellow with Black Text for Learn Mode
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0xFFFF00FF)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0xFFDD00FF)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), 0xFFCC00FF)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x000000FF)
            pushed_colors = 4
        else
            -- Normal Mode
            -- Wrap color index to 1-16 range
            local col_idx = i
            while col_idx > 16 do col_idx = col_idx - 16 end
            local base_col = macro_colors[col_idx]

            if not is_linked_pad then base_col = 0x888888FF end -- Gray if not linked

            -- Visual State
            local display_col = base_col

            if not is_on then
                display_col = (base_col & 0xFFFFFF00) | 0x44 -- Dim alpha
            end

            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), display_col)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), (base_col & 0xFFFFFF00) | 0xAA)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), base_col)
            pushed_colors = 3
        end

        -- Draw Pad
        local pad_label = is_learning and "LRN" or ""
        if r.ImGui_Button(ctx, pad_label .. ui_cache[pad_idx].btn_pad, pad_size, pad_size) then
             if r.ImGui_IsKeyDown(ctx, r.ImGui_Mod_Ctrl()) then
                 -- Ctrl + L-Click: Link Param
                 AddLastTouchedParam(pad_idx)
             else
                 -- Normal L-Click: Toggle
                 if macro_values[pad_idx] > 0.5 then
                     macro_values[pad_idx] = 0.0
                 else
                     macro_values[pad_idx] = 1.0
                 end
                 UpdateLinkedParams(pad_idx)

                 -- Sync to Backend (Write Automation)
                 if automation_enabled and not backend_missing then
                    r.TrackFX_SetParamNormalized(backend_track, backend_fx_id, pad_idx-1, macro_values[pad_idx])
                 end
             end
        end

        -- Right Click Actions
        if r.ImGui_IsItemClicked(ctx, 1) then
            if r.ImGui_IsKeyDown(ctx, r.ImGui_Mod_Ctrl()) then
                -- Ctrl + Right Click -> MIDI Learn
                if has_midi_api then
                    if learning_macro_idx == pad_idx then
                        learning_macro_idx = nil -- Toggle Off
                    else
                        learning_macro_idx = pad_idx -- Toggle On
                    end
                else
                    r.ShowMessageBox("MIDI Learn requires REAPER 7.03+", "Error", 0)
                end
            else
                -- Normal Right Click -> Remove Links
                RemoveLinksForMacro(pad_idx)
            end
        end

        -- Tooltip
        if r.ImGui_IsItemHovered(ctx) then
            local status_txt = is_on and "ON" or "OFF"
            local m = macro_midi_map[pad_idx]
            local map_txt = ""
            if m then
                 local type_str = ((m.status & 0xF0) == 0x90) and "Note" or "CC"
                 map_txt = string.format(" [Ch %d %s %d]", (m.status & 0x0F) + 1, type_str, m.cc)
            end
            if learning_macro_idx == pad_idx then map_txt = " [LEARNING...]" end

            r.ImGui_SetTooltip(ctx, string.format("%s\nState: %s%s\nL-Click: Toggle\nCtrl+L-Click: Link Param\nR-Click: Remove Link Param\nCtrl+R-Click: Toggle MIDI Learn", macro_names[pad_idx], status_txt, map_txt))
        end

        r.ImGui_PopStyleColor(ctx, pushed_colors)

        -- Layout: 8 per row
        if i % pads_per_row ~= 0 and i ~= MAX_PADS then
            r.ImGui_SameLine(ctx)
        end

        r.ImGui_PopID(ctx)
    end



    r.ImGui_Separator(ctx)

    -- Linked Params Header & Controls
    r.ImGui_AlignTextToFramePadding(ctx)

    -- Toggle Button (Arrow)
    if r.ImGui_ArrowButton(ctx, "##ToggleLinkedParams", show_linked_params and r.ImGui_Dir_Down() or r.ImGui_Dir_Right()) then
        show_linked_params = not show_linked_params
    end
    r.ImGui_SameLine(ctx)

    -- Buttons (Left aligned next to arrow)
    if r.ImGui_Button(ctx, "L##Linked") then
        local start_dir = GetProjectDir()
        local retval, file = r.GetUserFileNameForRead(start_dir, "Load Linked Params", "ini")
        if retval then LoadLinkedParams(file) end
    end
    if r.ImGui_IsItemHovered(ctx) then r.ImGui_SetTooltip(ctx, "Load Linked Parameters from file") end

    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "S##Linked") then
        local start_dir = GetProjectDir()
        if r.JS_Dialog_BrowseForSaveFile then
            local retval, file = r.JS_Dialog_BrowseForSaveFile("Save Linked Params", start_dir, "LinkedParams.ini", "INI files (.ini)\0*.ini\0All Files (*.*)\0*.*\0")
            if retval and file ~= "" then
                if not file:match("%.ini$") then file = file .. ".ini" end
                SaveLinkedParams(file)
            end
        else
             local retval, file = r.GetUserFileNameForRead(start_dir, "Save Linked Params", "ini")
             if retval then SaveLinkedParams(file) end
        end
    end
    if r.ImGui_IsItemHovered(ctx) then r.ImGui_SetTooltip(ctx, "Save Linked Parameters to a new file") end

    r.ImGui_SameLine(ctx)

    -- Text (Right aligned)
    local part1 = "Linked Parameters : "
    local part2 = tostring(#linked_params)
    local part3 = ""

    local w1 = r.ImGui_CalcTextSize(ctx, part1)
    local w2 = r.ImGui_CalcTextSize(ctx, part2)
    local w3 = r.ImGui_CalcTextSize(ctx, part3)
    local total_w = w1 + w2 + w3

    local avail_w = r.ImGui_GetContentRegionAvail(ctx)
    r.ImGui_SetCursorPosX(ctx, r.ImGui_GetCursorPosX(ctx) + avail_w - total_w)

    r.ImGui_Text(ctx, part1)
    r.ImGui_SameLine(ctx, 0, 0)

    local text_col = 0xFF4444FF -- Red
    if #linked_params > 0 then text_col = 0x44CC44FF end -- Green
    r.ImGui_TextColored(ctx, text_col, part2)

    r.ImGui_SameLine(ctx, 0, 0)
    r.ImGui_Text(ctx, part3)

    -- List of parameters
    if show_linked_params then
        -- Calculate height for 8 items
        -- One item = 2 rows + separator
        -- Height = (2 * fh) + is_y (approx for separator)
        local list_h = ((frame_h_spacing * 2) + item_spacing_y) * 8 + (pad_h * 2)

        if r.ImGui_BeginChild(ctx, "ParamsList", 0, list_h, 1) then
            local remove_idx = nil

            for i, p in ipairs(linked_params) do
                r.ImGui_PushID(ctx, i)

                -- Determine color index (wrap if pad)
                local col_idx = p.macro_idx
                if col_idx > 16 then col_idx = col_idx - 16 end
                local col = macro_colors[col_idx] or 0xFFFFFFFF

                -- Color indicator stripe
                r.ImGui_ColorButton(ctx, "##ColorInd", col, r.ImGui_ColorEditFlags_NoTooltip() | r.ImGui_ColorEditFlags_NoDragDrop(), 10, 10)
                r.ImGui_SameLine(ctx)

                -- Remove button
                if r.ImGui_Button(ctx, "X") then
                    remove_idx = i
                end
                r.ImGui_SameLine(ctx)

                -- Info
                r.ImGui_AlignTextToFramePadding(ctx)

                local label_prefix = "M"
                local disp_idx = p.macro_idx
                if p.macro_idx > 16 then
                    label_prefix = "P"
                    disp_idx = p.macro_idx - 16
                end

                local info_txt = string.format("%s%d [%s] %s : %s", label_prefix, disp_idx, p.track_name, p.fx_name, p.param_name)
                r.ImGui_TextColored(ctx, col, info_txt)

                -- Settings per param
                r.ImGui_Indent(ctx)

                -- Invert
                local inv_changed, inv_val = r.ImGui_Checkbox(ctx, "Invert", p.inverted)
                if inv_changed then
                    p.inverted = inv_val
                    UpdateLinkedParams(p.macro_idx)
                end

                r.ImGui_SameLine(ctx)
                r.ImGui_SetNextItemWidth(ctx, 60)
                local min_changed, min_v = r.ImGui_SliderDouble(ctx, "Min", p.min_val, 0.0, 1.0, "%.2f")
                if min_changed then
                    p.min_val = min_v
                    if p.min_val > p.max_val then p.min_val = p.max_val end
                    UpdateLinkedParams(p.macro_idx)
                end

                r.ImGui_SameLine(ctx)
                r.ImGui_SetNextItemWidth(ctx, 60)
                local max_changed, max_v = r.ImGui_SliderDouble(ctx, "Max", p.max_val, 0.0, 1.0, "%.2f")
                if max_changed then
                    p.max_val = max_v
                    if p.max_val < p.min_val then p.max_val = p.min_val end
                    UpdateLinkedParams(p.macro_idx)
                end

                -- Offset Slider (Only for Macros, not Pads)
                if p.macro_idx <= MAX_MACROS then
                    r.ImGui_SameLine(ctx)
                    r.ImGui_SetNextItemWidth(ctx, 60)
                    local off_changed, off_v = r.ImGui_SliderDouble(ctx, "Offset", p.offset or 0.5, 0.0, 1.0, "%.2f")
                    if off_changed then
                        p.offset = off_v
                        UpdateLinkedParams(p.macro_idx)
                    end
                end

                r.ImGui_Unindent(ctx)
                r.ImGui_Separator(ctx)

                r.ImGui_PopID(ctx)
            end

            if remove_idx then
                table.remove(linked_params, remove_idx)
                BuildLinkIndex()
            end

            r.ImGui_EndChild(ctx)
        end
    end
end

-- Auto-Load at startup (Linked Params)
local auto_file = GetProjectAutoSavePath()
if auto_file and r.file_exists(auto_file) then
    LoadLinkedParams(auto_file)
end

-- Auto-Load last used MIDI Preset
local last_midi_preset = GetLastUsedPreset()
if last_midi_preset and last_midi_preset ~= "" then
    if LoadPreset(last_midi_preset) then
        -- Sync UI selection
        local presets = GetPresetsList()
        for i, p_name in ipairs(presets) do
            if p_name == last_midi_preset then
                selected_preset_idx = i - 1
                break
            end
        end
    end
end

-- Auto-Save on exit
r.atexit(function()
    local f = GetProjectAutoSavePath()
    if f then SaveLinkedParams(f) end
end)

-- Initialize Backend Once at Startup
InitializeBackend()

local function loop()
  frame_counter = frame_counter + 1

  -- Check Project State (once per frame to avoid calls in GetTrackByGUID)
  CheckProjectStateChange()

  -- Validate Backend status (Throttled)
  if frame_counter % VALIDATE_INTERVAL == 0 then
      ValidateBackend()
  end

  -- Reset counter periodically
  if frame_counter > 10000 then frame_counter = 0 end

  -- Poll MIDI every cycle
  PollMIDI()

  -- Poll Global Hotkeys
  PollGlobalKeys()

  reaper.ImGui_PushFont(ctx, font, size)
  reaper.ImGui_SetNextWindowSize(ctx, 500, 500, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, windowTitle, true, reaper.ImGui_WindowFlags_AlwaysAutoResize())
  if visible then
    -- Hotkey H to toggle Linked Params
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_H()) then
        show_linked_params = not show_linked_params
    end

    myWindow()
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopFont(ctx)

  if open then
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then open = false end
  end

  if open then
    reaper.defer(loop)
  end
end
reaper.defer(loop)
