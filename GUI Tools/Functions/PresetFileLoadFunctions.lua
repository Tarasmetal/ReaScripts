-- @description Presets Functions
-- @author Taras Umanskiy

local r = reaper
function GetListOfFiles(d)
    local tb = {}
    local i = 0
    repeat
        local retval = reaper.EnumerateFiles(d, i)
        table.insert(tb, retval)
        i = i + 1
    until not retval
    return tb
end

function str_split (inputstr, sep)
    if not inputstr then return {} end
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local function read_file(path)
    local open = io.open
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then
        return nil
    end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

function preset_read(preset_path, presetId)
    if not (preset_path and presetId)
    then
        return
    end
    return table.load(preset_path .. '/' .. presetId)
end

function preset_read_simple(preset_path, presetId)
    local fileContent = read_file(preset_path .. '/' .. presetId)
    return fileContent
end

function parse_simple_preset_content(content)
    if not content then return {} end
    content = str_split(content, "\n")
    local res = {}
    for rowKey, rowValue in ipairs(content) do
        -- Skip comments and empty lines
        if rowValue and rowValue ~= "" and string.sub(rowValue, 1, 2) ~= "--" then
            rowValue = rowValue:gsub("\r", "")
            local row = str_split(rowValue, ',')
            if row[1] then
                table.insert(res, {
                    name = row[1],
                    color = row[2] or "",
                })
            end
        end
    end
    return res
end

function save_simple_preset(preset_path, presetId, data)
    local file = io.open(preset_path .. '/' .. presetId, "w")
    if not file then return end

    for _, v in ipairs(data) do
        if v.name then
            local clean_name = v.name:gsub("[\r\n]", "")
            local clean_color = (v.color or ""):gsub("[\r\n]", "")
            file:write(clean_name .. "," .. clean_color .. "\n")
        end
    end
    file:close()
end

local presetState = { newName = "", showInput = false }

function renderFilesList(ctx, path, currentMarkers, currentPresetName)
    local selected = nil
    local newMarkers = nil
    local newName = nil

    local rv = reaper.ImGui_Button(ctx, ' Presets ')
     if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
     --            r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'),'PRESET PATH -')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, hex2rgb('#88FF00'),'Found')
     --            r.ImGui_Separator(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#c7c7c7'), 'Load Presets for Marker Tools')
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
              end
    if rv then
        filesList = GetListOfFiles(path)
        presetState.showInput = false -- Reset state on open
        reaper.ImGui_OpenPopup(ctx, 'load_popup')
    end

    if reaper.ImGui_BeginPopup(ctx, 'load_popup') then
        if r.ImGui_Button(ctx, ' Open Folder ') then
            r.ImGui_BulletText(ctx, '•')
            reaper.CF_ShellExecute(path)
        end
        if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
                r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'),'PRESET PATH -')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, hex2rgb('#88FF00'),'Found')
                r.ImGui_Separator(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#c7c7c7'), path)
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
              end
        reaper.ImGui_Separator(ctx)

        -- New Preset Logic
        if not presetState.showInput then
            if reaper.ImGui_Button(ctx, "New") then
                presetState.showInput = true
                presetState.newName = ""
            end
            
            -- Clear / Delete on the same line as New
            if currentPresetName then
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "Clear") then
                    local defaultData = {{ name = " ", color = "" }}
                    save_simple_preset(path, currentPresetName, defaultData)
                    newMarkers = defaultData
                    newName = currentPresetName
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, "Delete") then
                    os.remove(path .. "/" .. currentPresetName)
                    local defaultFile = "Default.txt"
                    if currentPresetName ~= defaultFile then
                        local content = preset_read_simple(path, defaultFile)
                        if content then
                            newMarkers = parse_simple_preset_content(content)
                            newName = defaultFile
                        else
                            newMarkers = {}
                            newName = defaultFile
                        end
                    else
                        newMarkers = {}
                        newName = defaultFile
                    end
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
            end
        else
            reaper.ImGui_PushItemWidth(ctx, 120)
            local rv_in, inputName = reaper.ImGui_InputText(ctx, "##new_preset_name", presetState.newName)
            if rv_in then presetState.newName = inputName end
            reaper.ImGui_PopItemWidth(ctx)
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Create") then
                if presetState.newName ~= "" then
                    local fileName = presetState.newName
                    if not fileName:match("%.txt$") then fileName = fileName .. ".txt" end
                    local f = io.open(path .. "/" .. fileName, "w")
                    if f then
                        f:write(" \n") -- Default content is a space
                        f:close()
                        newMarkers = {{ name = " ", color = "" }}
                        newName = fileName
                        presetState.newName = ""
                        presetState.showInput = false
                        reaper.ImGui_CloseCurrentPopup(ctx)
                    end
                end
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel") then
                presetState.showInput = false
            end
        end

        reaper.ImGui_Separator(ctx)
        reaper.ImGui_TextColored(ctx, 0xFFFF00FF, ' LOAD PRESETS ')
        reaper.ImGui_Separator(ctx)
        for i, v in ipairs(filesList) do
            local no_exp = string.gsub(v, "%.txt$", "")
            if reaper.ImGui_Selectable(ctx, no_exp) then
                selected = i
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end


    if newMarkers and newName then
        -- сохранение значения переменной defaultPresetName в файл
        local file = io.open(scriptDir .. "/" .. settingsFileName, "w")
        if file then
            file:write(newName)
            file:close()
        end
        return newMarkers, newName
    end

    if filesList ~= nil and selected ~= nil then

        -- сохранение значения переменной defaultPresetName в файл
        local file = io.open(scriptDir .. "/" .. settingsFileName, "w")
        file:write("" .. filesList[selected] .. "")
        file:close()

        return parse_simple_preset_content(preset_read_simple(path, filesList[selected])), filesList[selected]
    end
    return nil

end
