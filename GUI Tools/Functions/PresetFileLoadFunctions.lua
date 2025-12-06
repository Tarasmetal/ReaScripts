-- @description Presets Functions
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [nomain] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
--   # Presets Functions
-- @changelog
--  + Code optimizations

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
    content = str_split(content, "\n")
    res = {}
    for rowKey, rowValue in ipairs(content) do
        local row = str_split(rowValue, ',')
        table.insert(res, {
            name = row[1],
            color = row[2],
            -- color = convertColor(color),
        })
    end
    return res
end

function renderFilesList(ctx, path)
    selected = nil
    rv = reaper.ImGui_Button(ctx, ' Presets ')
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
        filesList = {}
        filesList = GetListOfFiles(path)
        reaper.ImGui_OpenPopup(ctx, 'load_popup')
    end

    if reaper.ImGui_BeginPopup(ctx, 'load_popup') then
        if r.ImGui_Button(ctx, ' Open Folder ') then
            r.ImGui_BulletText(ctx, '•')
            reaper.CF_ShellExecute(presetDir)
        end
        -- if r.ImGui_IsItemHovered(ctx) then
        --         r.ImGui_BeginTooltip(ctx)
        --         r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
        --         r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'),'Open presets folder for edit')
        --         r.ImGui_PopTextWrapPos(ctx)
        --         r.ImGui_EndTooltip(ctx)
        -- end
        if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
                r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'),'PRESET PATH -')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, hex2rgb('#88FF00'),'Found')
                r.ImGui_Separator(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#c7c7c7'), presetDir)
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
              end
        reaper.ImGui_Separator(ctx)
        r.ImGui_SameLine(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_TextColored(ctx, 0xFFFF00FF, ' LOAD PRESETS ')
        reaper.ImGui_Separator(ctx)
        for i, v in ipairs(filesList) do
            local no_exp = string.gsub(v, "%.lua$", "")
            if reaper.ImGui_Selectable(ctx, no_exp) then
                selected = i
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end


    if filesList ~= nil and selected ~= nil then

        -- сохранение значения переменной defaultPresetName в файл
        local file = io.open(scriptDir .. "/" .."trs_MarkerGUITools.ini", "w")
        file:write("" .. filesList[selected] .. "")
        file:close()

        return parse_simple_preset_content(preset_read_simple(path, filesList[selected]))
    end
    return nil

end