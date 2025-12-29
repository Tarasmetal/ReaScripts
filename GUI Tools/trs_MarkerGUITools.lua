-- @description Marker GUI Tools
-- @author Taras Umanskiy
-- @version 2.3
-- @provides
--   [main] .
--   [script] MarkerPresets/*.txt
--   [script] Functions/MarkerFunctions.lua
--   [script] Functions/PresetFileLoadFunctions.lua
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about
--   # КАК ЭТО РАБОТАЕТ?
--   Основная идея и задача скрипта — максимально сократить время на разметку проекта, оставляя его красивым и понятным для всех, а главное для самого себя.
--   Не отвлекайтесь от творческого процесса, перемещайтесь в любую точку проекта за пару секунд, чтобы записать, прослушать или внести кориктеровки в трекинг.
-- @changelog
--   + Добавлены необходимые файлы функций в зависимость пакета (Functions/*.lua)


local r = reaper
local FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()
local IMGUI_VERSION, REAIMGUI_VERSION = r.ImGui_GetVersion()

local EXT_SECTION = "trs_MarkerGUITools_Settings"

function SaveSetting(key, value)
  reaper.SetExtState(EXT_SECTION, key, tostring(value), true)
end

function LoadSettings()
  local w = {}

  -- Load closable (ID)
  local val = reaper.GetExtState(EXT_SECTION, "closable")
  if val ~= "" then w.closable = (val == "true") else w.closable = false end

  -- Load start_color
  val = reaper.GetExtState(EXT_SECTION, "start_color")
  if val ~= "" then w.start_color = val else w.start_color = nil end

  -- Load end_color
  val = reaper.GetExtState(EXT_SECTION, "end_color")
  if val ~= "" then w.end_color = val else w.end_color = nil end

  w.cheads = {}
  -- Load closable_group (<)
  val = reaper.GetExtState(EXT_SECTION, "closable_group")
  if val ~= "" then w.cheads.closable_group = (val == "true") else w.cheads.closable_group = true end

  -- Load show_additional_buttons (PB)
  val = reaper.GetExtState(EXT_SECTION, "show_additional_buttons")
  if val ~= "" then w.cheads.show_additional_buttons = (val == "true") else w.cheads.show_additional_buttons = false end

  return w
end

widgets = LoadSettings()

console = true

function msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

scrAuthor = 'Taras Umanskiy'
version = '2.3'
scrName = 'MARKER TOOLS'
scrAbout = scrName .. ' ' .. version .. ' by ' .. scrAuthor

ListDir = {}
ListDir.scriptDir, ListDir.scriptFileName = ({r.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")

scriptDir = ListDir.scriptDir
presetDir = ListDir.scriptDir .. 'MarkerPresets'

windowTitle = scrAbout

------------------------------------------------------------------------------------------------------------------
local info = debug.getinfo(1, 'S');
local FontPath = info.source:match[[^@?(.*[\/])[^\/]-$]]
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua') ('0.8.1') -- current version at the time of writing the script

--local ctx = r.ImGui_CreateContext(windowTitle)
ctx = r.ImGui_CreateContext(windowTitle)
local size = r.GetAppVersion():match('Win64') and 12 or 14
-- local font = r.ImGui_CreateFont('Tahoma', 9)
local font = reaper.ImGui_CreateFont('sans-serif', 14)
-- local font = r.ImGui_CreateFont('Consolas', 9)
-- local font =  r.ImGui_CreateFont('Sedoe', 9)
r.ImGui_Attach(ctx, font)
------------------------------------------------------------------------------------------------------------------

dofile(scriptDir .. "Functions/" .. "PresetFileLoadFunctions.lua")
dofile(scriptDir .. "Functions/" .. "MarkerFunctions.lua")

function ParseColorToRGB(color)
    local r, g, b = 1, 1, 1
    if not color or color == '' then return r, g, b end
    if type(color) == 'string' then
        if col_arr and col_arr[color:lower()] then
            local t = col_arr[color:lower()]
            r, g, b = t[1]/255, t[2]/255, t[3]/255
        elseif color:match("^#?%x%x%x%x%x%x$") then
            local hex = color:gsub("#","")
            r = tonumber(hex:sub(1,2), 16) / 255
            g = tonumber(hex:sub(3,4), 16) / 255
            b = tonumber(hex:sub(5,6), 16) / 255
        end
    end
    return r, g, b
end

function RGBToHex(r, g, b)
    local function to255(v) return math.floor(v * 255 + 0.5) end
    return string.format("#%02X%02X%02X", to255(r), to255(g), to255(b))
end

-- чтение значения переменной defaultPresetName из файла
-- defaultPresetName = 'Default.lua'
local f_preset_check = scriptDir .. "/" .."trs_MarkerGUITools.ini"

if os.rename(f_preset_check, f_preset_check) == true then
  -- file exists, do something
local f_preset = io.open(scriptDir .. "/" .."trs_MarkerGUITools.ini", "r")

if f_preset then
    local contents = f_preset:read("*all")
    defaultPresetName = string.match(contents, "(.+)")
    f_preset:close()
end

else
  -- file does not exist, set defaultPresetName variable
  defaultPresetName = "Default.txt"
end

markersToShow = parse_simple_preset_content(preset_read_simple(presetDir, defaultPresetName)) -- Дефолтный пресет


function HelpMarker(helpName, desc)
  r.ImGui_TextDisabled(ctx, '' .. helpName .. '')
  if r.ImGui_IsItemHovered(ctx) then
    r.ImGui_BeginTooltip(ctx)
    r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
    r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), desc)
    r.ImGui_PopTextWrapPos(ctx)
    r.ImGui_EndTooltip(ctx)
  end
end

-- Вызывается в цикле ОСТОРОЖНО

local val_omm = reaper.GetExtState(EXT_SECTION, "only_markers_mode")
only_markers_mode = (val_omm == "true")

function frame(ctx)
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_H(), false) then
        only_markers_mode = not only_markers_mode
        SaveSetting("only_markers_mode", only_markers_mode)
    end

    -- r.ImGui_LabelText(ctx, left, text)
    -- -- r.ImGui_Text(ctx, 'Hold to repeat:')
    if not only_markers_mode then
    r.ImGui_SameLine(ctx) r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'),'<(?)>')
    if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
                r.ImGui_Spacing(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'),'** ABOUT SCRIPT **')
                r.ImGui_Spacing(ctx)
                r.ImGui_Separator(ctx)
                r.ImGui_Spacing(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Script File:') r.ImGui_SameLine(ctx) r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), ListDir.scriptFileName .. '.lua')
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Script Name:') r.ImGui_SameLine(ctx) r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'), scrName .. ' ' .. version)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Author:')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), scrAuthor)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Author URL:')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'), 'http://vk.com/tarasmetal')
                r.ImGui_Text(ctx, '')
                r.ImGui_TextColored(ctx, hex2rgb('#FF0000'), '<3')r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,'&')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, hex2rgb('#88FF00'), 'SPECIAL THX:')
                r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), 'MPL,SuperMaximus,Aleksey Bezborodov.\n')
                r.ImGui_Spacing(ctx)
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
      end
    r.ImGui_SameLine(ctx)
    selectedMarkers, newPresetName = renderFilesList(ctx, presetDir)
    if selectedMarkers then
        markersToShow = selectedMarkers
        if newPresetName then
            defaultPresetName = newPresetName
        end
    end

    r.ImGui_SameLine(ctx)
    local rv_id
    rv_id, widgets.closable = r.ImGui_Checkbox(ctx, 'ID', widgets.closable)
    if rv_id then SaveSetting("closable", widgets.closable) end

    r.ImGui_SameLine(ctx)HelpMarker('(?)',
      'Hidden ID number for Markers\n')
    r.ImGui_SameLine(ctx)

if not widgets.cheads then
      widgets.cheads = {
        closable_group = true,
        show_additional_buttons = false,
      }
      end

    local rv_cg
    rv_cg, widgets.cheads.closable_group = r.ImGui_Checkbox(ctx, '<', widgets.cheads.closable_group)
    if rv_cg then SaveSetting("closable_group", widgets.cheads.closable_group) end
    -- rv,widgets.cheads.closable_group = r.ImGui_Checkbox(ctx, 'Scripts', widgets.cheads.closable_group)

        r.ImGui_SameLine(ctx) HelpMarker('(?)',
            'Show CUSTOM SCRIPTS buttons\n')

    if widgets.cheads.closable_group then
      -- rv,widgets.cheads.closable_group = r.ImGui_CollapsingHeader(ctx, 'Custom Buttons', true)
      -- if rv then
        -- r.ImGui_Spacing(ctx)
        -- r.ImGui_Text(ctx, ('IsItemHovered: %s'):format(r.ImGui_IsItemHovered(ctx)))
        r.ImGui_SameLine(ctx)
        btnFuncCol('S-E', 'setStartEndMarkers','Set START and END Markers of time selection', 9,0)
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnCmdCol('Del T', '42395', 'Markers: Delete all tempo markers', 7,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('Del M', '40613', 'Markers: Delete marker at cursor', 7.5,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('Del M all', '_SWSMARKERLIST9', 'Markers: Delete all Markers', 7,0)
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnCmdCol('Del R', '40615', 'Regions: Delete region at cursor', 7.5,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('Del R all', '_SWSMARKERLIST10', 'Regions: Delete all Regions', 7,0)
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnFuncCol('Inx Add', 'MarkerReNameIndex', 'Set all markers new index', 9,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        btnFuncCol('Inx Rem', 'MarkerDelIndex', 'Delete all markers index (TESTED FUNC - work with bugs !!!)', 7,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnCmdCol('M ID', '_SWSMARKERLIST7','ReNumber Markers ID [0-9X]', 5.8,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('R ID', '_SWSMARKERLIST8','ReNumber Regions ID [0-9X]', 5.5,0)
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnCmdCol('M >> R', '_SWSMARKERLIST13','Convert all Markers to Regions', 5.2,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('R << M', '_SWSMARKERLIST14','Convert all Regions to Markers', 5.0,0)
        r.ImGui_SameLine(ctx) r.ImGui_TextDisabled(ctx, '|')r.ImGui_SameLine(ctx)
        -- btnSCRCol('File Load', 'Taras\\Tools\\trs_TrackReNameTools.lua', 'Script Load', 6.5,0) -- Load lua file script
        btnFuncCol('Set 00', 'setTimecodeZero', 'Set start 0:00:00 at edit cursor', 0,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        btnFuncCol('Bck 00', 'resetProjBackTime', 'Jump cursor to 0:00:00', 8,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        btnFuncCol('Rst 00', 'resetProjStartTime', 'Reset project start time', 9,0) -- Load lua file script
        r.ImGui_SameLine(ctx) r.ImGui_TextDisabled(ctx, '|')r.ImGui_SameLine(ctx)
        -- работающие за комментированное кнопки
        -- btnFuncCol('REC', 'setMarker666', 'Insert REC 666 Marker', 0,0) -- Red -- Load lua file script
        -- r.ImGui_SameLine(ctx)
        -- btnFuncCol('BCK', 'goToMarker666', 'Go to REC 666 Marker', 9,0) -- Green -- Load lua file script
        -- r.ImGui_SameLine(ctx) r.ImGui_TextDisabled(ctx, '|')r.ImGui_SameLine(ctx)
        r.ImGui_SameLine(ctx)
        local rv_pb
        rv_pb, widgets.cheads.show_additional_buttons = r.ImGui_Checkbox(ctx, 'PB', widgets.cheads.show_additional_buttons)
        if rv_pb then SaveSetting("show_additional_buttons", widgets.cheads.show_additional_buttons) end
        r.ImGui_SameLine(ctx) HelpMarker('(?)','Show PlayBack Tools Maker\n')
        if widgets.cheads.show_additional_buttons then
        r.ImGui_SameLine(ctx)
        btnCmdCol('+ T', '40256','Insert tempo/time sig. change marker at edit cursor...', 5.0,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('+ R', '40174','Insert Region from time selection', 5.3,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('+ R.I', '_SWS_REGIONSFROMITEMS','SWS: Create regions from selected items (name by active take)', 4,0)
        r.ImGui_SameLine(ctx)
        btnFuncCol('T+++', 'create_tempo_markers_sel_items','Move cursor to next end-start of item, select item', 5.1,0)
        r.ImGui_SameLine(ctx)
        btnFuncCol('Items R', 'removeWavFromItemNames','Items: Rename rename items.wav', 5.6,0)
        r.ImGui_SameLine(ctx)
        btnFuncCol('Items -', 'snap_sel_itmes_off','', 7,0)
        r.ImGui_SameLine(ctx)
        btnFuncCol('items +', 'snap_sel_itmes_on','', 8,0)
        r.ImGui_SameLine(ctx)
        btnCmdCol('items s', '41183','Selected items snap to grid', 9,0)
        end
        -- r.ImGui_Checkbox(ctx, 'test', 0)
        -- if r.ImGui_IsItemHovered(ctx) then
        --         r.ImGui_BeginTooltip(ctx)
        --         r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
        --         r.ImGui_TextColored(ctx, hex2rgb('#FFFFFF'),'DONT WORK!')
        --         r.ImGui_TextColored(ctx, hex2rgb('#FF0000'),'SCRIPT NOT COMPLITE !!!')
        --         r.ImGui_PopTextWrapPos(ctx)
        --         r.ImGui_EndTooltip(ctx)
        --       end
    r.ImGui_SameLine(ctx)
        -- r.ImGui_Spacing(ctx)
      -- end
    end
        r.ImGui_Spacing(ctx)
        r.ImGui_Separator(ctx)
        r.ImGui_Spacing(ctx)
    end
        r.ImGui_Text(ctx, '<')
        r.ImGui_SameLine(ctx)
          local col = 6
           r.ImGui_PushID(ctx, 'start_btn')

           if widgets.start_color and widgets.start_color ~= "" then
               local c_r, c_g, c_b = ParseColorToRGB(widgets.start_color)
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.6))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.8))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0))
           else
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           end

        if r.ImGui_Button(ctx, 'START') then
            insertMarkerStart('=START', widgets.start_color or 'pink')
        end
            if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Set')
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), 'START')
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'project marker')
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
              end

        if r.ImGui_BeginPopupContextItem(ctx) then
            r.ImGui_Text(ctx, 'Edit START Button Color')
            r.ImGui_Separator(ctx)

            local c_r, c_g, c_b = ParseColorToRGB(widgets.start_color)
            if not widgets.start_color then c_r, c_g, c_b = 1, 0, 1 end -- Default Pink
            local packed_col = r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0)
            local rv_color, new_packed_col = r.ImGui_ColorEdit4(ctx, 'Color', packed_col)
            if rv_color then
                local new_r, new_g, new_b, _ = r.ImGui_ColorConvertU32ToDouble4(new_packed_col)
                widgets.start_color = RGBToHex(new_r, new_g, new_b)
                SaveSetting("start_color", widgets.start_color)
            end

            if r.ImGui_Button(ctx, 'Reset Color') then
                widgets.start_color = nil
                SaveSetting("start_color", "")
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        r.ImGui_PopStyleColor(ctx, 3)
        r.ImGui_PopID(ctx)
        r.ImGui_SameLine(ctx)
        r.ImGui_Text(ctx, '|')


    for i = 1, #markersToShow do -- С какого элемента начинать

        buttonText = markersToShow[i].name
        color = markersToShow[i].color

        if i > 0 then
          r.ImGui_SameLine(ctx)
        end
           r.ImGui_PushID(ctx, i)
           if color and color ~= "" then
               local c_r, c_g, c_b = ParseColorToRGB(color)
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.6))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.8))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0))
           else
               local col = 4
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 0.6))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           end


if not widgets then
       widgets = {
        closable = true,
      }
    end
        if not widgets.closable then

          if r.ImGui_Button(ctx, buttonText .. "###marker_btn") then
              insertMarker(buttonText, markersToShow[i].color)
          end
             if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Insert')
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), buttonText)
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#88FF00'), generateId(buttonText))
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'marker at cursor')
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
              end
             else
          if r.ImGui_Button(ctx, buttonText .. "###marker_btn") then
               insertMarkerNoID(buttonText, color)
          end
          if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Insert')
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), buttonText)
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'marker at cursor')
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
              end
        end

        -- Drag and Drop
        if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_None()) then
            r.ImGui_SetDragDropPayload(ctx, 'MARKER_CELL', tostring(i))
            r.ImGui_Text(ctx, markersToShow[i].name)
            r.ImGui_EndDragDropSource(ctx)
        end
        if r.ImGui_BeginDragDropTarget(ctx) then
            local retval, payload = r.ImGui_AcceptDragDropPayload(ctx, 'MARKER_CELL')
            if retval then
                local from_i = tonumber(payload)
                if from_i ~= i then
                    local moved_item = table.remove(markersToShow, from_i)
                    table.insert(markersToShow, i, moved_item)
                    save_simple_preset(presetDir, defaultPresetName, markersToShow)
                end
            end
            r.ImGui_EndDragDropTarget(ctx)
        end

        r.ImGui_PopStyleColor(ctx, 3)

        if r.ImGui_BeginPopupContextItem(ctx) then
            r.ImGui_Text(ctx, 'Edit Marker: ' .. markersToShow[i].name)
            r.ImGui_Separator(ctx)

            -- Edit Name
            local rv_name, new_name = r.ImGui_InputText(ctx, 'Name', markersToShow[i].name)
            if rv_name then
                markersToShow[i].name = new_name
                save_simple_preset(presetDir, defaultPresetName, markersToShow)
            end

            -- Edit Color
            local c_r, c_g, c_b = ParseColorToRGB(markersToShow[i].color)
            local packed_col = r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0)
            local rv_color, new_packed_col = r.ImGui_ColorEdit4(ctx, 'Color', packed_col)
            if rv_color then
                local new_r, new_g, new_b, _ = r.ImGui_ColorConvertU32ToDouble4(new_packed_col)
                markersToShow[i].color = RGBToHex(new_r, new_g, new_b)
                save_simple_preset(presetDir, defaultPresetName, markersToShow)
            end

            if r.ImGui_Button(ctx, 'Delete Color') then
                markersToShow[i].color = ''
                save_simple_preset(presetDir, defaultPresetName, markersToShow)
            end

            r.ImGui_Separator(ctx)

            -- Delete Button
            if r.ImGui_Button(ctx, 'DELETE MARKER') then
                table.remove(markersToShow, i)
                save_simple_preset(presetDir, defaultPresetName, markersToShow)
                r.ImGui_CloseCurrentPopup(ctx)
                r.ImGui_EndPopup(ctx)
                r.ImGui_PopID(ctx)
                break
            end

            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, 'INSERT MARKER') then
                 table.insert(markersToShow, i + 1, {name='New', color=''})
                 save_simple_preset(presetDir, defaultPresetName, markersToShow)
                 r.ImGui_CloseCurrentPopup(ctx)
                 r.ImGui_EndPopup(ctx)
                 r.ImGui_PopID(ctx)
                 break
            end
            if r.ImGui_IsItemHovered(ctx) then
                 r.ImGui_SetTooltip(ctx, 'Insert New Marker After Current')
            end
            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        r.ImGui_PopID(ctx)
        end


        r.ImGui_SameLine(ctx)
        r.ImGui_Text(ctx, '|')
        r.ImGui_SameLine(ctx)

      local col = 6
           r.ImGui_PushID(ctx, 'end_btn')

           if widgets.end_color and widgets.end_color ~= "" then
               local c_r, c_g, c_b = ParseColorToRGB(widgets.end_color)
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.6))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 0.8))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0))
           else
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
               r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           end

        if r.ImGui_Button(ctx, 'END') then
            insertMarkerEnd("=END", widgets.end_color or 'pink')
         end
          -- if  r.ImGui_IsItemHovered(ctx) then
          --      -- local cursor_pos = r.GetCursorPosition()
          --           r.ImGui_SetTooltip(ctx, 'Set END project maker point') -- Need to Fix
          --           -- r.ImGui_SetTooltip(ctx, 'Set END point pos '.. timeEND ..' for render track') -- Need to Fix
          --   end
            if r.ImGui_IsItemHovered(ctx) then
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'Set')
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#FFFF00'), 'END')
                r.ImGui_SameLine(ctx)
                r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), 'project marker')
                r.ImGui_PopTextWrapPos(ctx)
                r.ImGui_EndTooltip(ctx)
              end

        if r.ImGui_BeginPopupContextItem(ctx) then
            r.ImGui_Text(ctx, 'Edit END Button Color')
            r.ImGui_Separator(ctx)

            local c_r, c_g, c_b = ParseColorToRGB(widgets.end_color)
            if not widgets.end_color then c_r, c_g, c_b = 1, 0, 1 end -- Default Pink
            local packed_col = r.ImGui_ColorConvertDouble4ToU32(c_r, c_g, c_b, 1.0)
            local rv_color, new_packed_col = r.ImGui_ColorEdit4(ctx, 'Color', packed_col)
            if rv_color then
                local new_r, new_g, new_b, _ = r.ImGui_ColorConvertU32ToDouble4(new_packed_col)
                widgets.end_color = RGBToHex(new_r, new_g, new_b)
                SaveSetting("end_color", widgets.end_color)
            end

            if r.ImGui_Button(ctx, 'Reset Color') then
                widgets.end_color = nil
                SaveSetting("end_color", "")
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        r.ImGui_PopStyleColor(ctx, 3)
        r.ImGui_PopID(ctx)
        if not only_markers_mode then
        r.ImGui_SameLine(ctx)
        r.ImGui_SameLine(ctx)
        r.ImGui_Text(ctx, '|')
        r.ImGui_SameLine(ctx)
        btnFuncCol('Add PL', 'StopRegions', 'Add STOP Markers to End of Regions', 9,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        btnFuncCol('Rem PL', 'StopRegionsDelete', 'Delete STOP Markers to End of Regions', 0,0) -- Load lua file script
        r.ImGui_SameLine(ctx)
        r.ImGui_Text(ctx, '>')
        end
        r.ImGui_Spacing(ctx)
end

function loop()
    local visible, open = r.ImGui_Begin(ctx, windowTitle, true, r.ImGui_WindowFlags_AlwaysAutoResize())
    if visible then
        frame(ctx)
        r.ImGui_End(ctx)
    end

    if open and (not r.ImGui_IsKeyDown(ctx, 27)) then
        r.defer(loop)
    -- else
        -- r.ImGui_DestroyContext(ctx)
    end
end

r.defer(loop)
