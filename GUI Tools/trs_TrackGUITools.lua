-- @description Tracks GUI Tools
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
--   # Tracks GUI Tools
-- @changelog
--  + Code optimizations

local r = reaper

console = true

function msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

--подключение либы для гуя
local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
-- dofile(reaper.GetResourcePath() .. '\\Scripts\\ReaTeam Scripts\\Development\\Lokasenna_GUI v2\\Developer Tools\\Open Lokasenna_GUI v2 Developer Tools folder.lua')
	dofile(reaper.GetResourcePath() .. '\\Scripts\\ReaTeam Scripts\\Development\\Lokasenna_GUI v2\\Library\\Set Lokasenna_GUI v2 library path.lua')
    -- reaper.MB("Не удалось загрузить библиотеку Lokasenna_GUI. Пожалуйста, установите 'Lokasenna's GUI library v2 для Lua', доступно на ReaPack, затем запустите 'Set Lokasenna_GUI v2 library path.lua' скрипт в вашем Action List.", "Whoops!", 0)
    reaper.MB("Пожалуйста, запустите еще раз скрипт в вашем Action List.", "Whoops!", 0)
    return
end

loadfile(lib_path .. "Core.lua")()

GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Textbox.lua")()
GUI.req("Classes/Class - Label.lua")()

ListDir = {}
ListDir.scriptDir, ListDir.scriptFileName = ({r.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")

scriptDir = ListDir.scriptDir
presetPath = ListDir.scriptDir .. "TrackPresets"
presetFile = ListDir.scriptDir .. "TrackPresets" .. "/" .. "user.txt"
saveFile = ListDir.scriptDir .. "TrackPresets" .. "/" .. "default.txt"

dofile(scriptDir  .. "TrackPresets" .. "/" ..  "trs_TrackGUITools_default.lua")

-- Если какая-либо из запрошенных библиотек не была найдена, прервите сценарий.
if missing_lib then return 0 end

-- таблица с кодами цветов
colors_arr = {
    black = {0, 0, 0, 255},
    white = {255, 255, 255, 255},
    red = {255, 0, 0, 255},
    lime = {0, 255, 0, 255},
    blue =  {0, 0, 255, 255},
    yellow = {255, 255, 0, 255},
    cyan = {0, 255, 255, 255},
    magenta = {255, 0, 255, 255},
    silver = {192, 192, 192, 255},
    gray = {128, 128, 128, 255},
    maroon = {128, 0, 0, 255},
    olive = {128, 128, 0, 255},
    green = {0, 128, 0, 255},
    purple = {128, 0, 128, 255},
    teal = {0, 128, 128, 255},
    navy = {0, 0, 128, 255},
}


-- заголовок окна
-- GUI.name = "• RENAME TRACKS TOOLS •"
-- еще параметры для гуя включая ширину и высоту окна (при добавлении кнопок нужно увеличить высоту окна соответственно)
-- GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 130, 170

function convertColor(color)
    if color then
        if type(color) == "table" or type(color) == "string" then
            return reaper.ColorToNative(table.unpack(colors_arr[color]))|0x1000000
        else
            return color
    end
    end
end

-- сама основная функция вставляющая трек
function insertTrackName(name, color)
    local track = reaper.GetSelectedTrack(0, 0)
    if track then
      reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', name, true)
        if color then
            color = convertColor(color)
            reaper.SetTrackColor(track, color)
        end
    end
end

-- цикл в котором выводим кнопки по очереди основываясь на таблице MarkerOptions
function newTrackName(name, color)
    return function()
        return insertTrackName(name, color)
    end
end


function colorPicker(btn)
    local ret, color = reaper.GR_SelectColor()

    if ret == 1 then
        local track = reaper.GetSelectedTrack(0, 0)
        color = color|0x1000000
        if track then
            reaper.SetTrackColor(track, color)
            GUI.elms.color_picker_1.col_fill = color
            GUI.elms.color_picker_1.caption = "*"
            GUI.redraw_z[GUI.elms.color_picker_1] = true
        end
    end
end

function newColorPicker(btn)
    return function()
        return colorPicker(btn)
    end
end

function addWord(word)
    local track = reaper.GetSelectedTrack(0, 0)
    if track then
        local currentTrackNameState, currentTrackName = reaper.GetTrackName(track)
        --local newName = currentTrackName .. ' ' .. word
        local newName
        if string.find(currentTrackName, "Track") then
            newName = word
        else
            newName = currentTrackName .. ' ' .. word
        end

        reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', newName, true)
    end
end

function newAddWord(word)
    return function()
        return addWord(word)
    end
end

function addPan(pan)

    local track = reaper.GetSelectedTrack(0, 0)
    if track then

        if pan then
            for i = 0, reaper.CountSelectedTracks(0)-1 do
              tr = reaper.GetSelectedTrack(0,i)
              reaper.SetMediaTrackInfo_Value(tr, 'D_PAN', 0.01*pan)
           end
        end
    end
end

function newAddPan(pan)
    return function()
        return addPan(pan)
    end
end

function PrevTrack(pan)

    local track = reaper.GetSelectedTrack(0, 0)
    if track then

        if pan then
            for i = 0, reaper.CountSelectedTracks(0)-1 do
              tr = reaper.GetSelectedTrack(0,i)
              reaper.Main_OnCommand(40286, 0)
           end
        end
    end
end

function newPrevTrack(pan)
    return function()
        return PrevTrack(pan)
    end
end

function NextTrack(pan)

    local track = reaper.GetSelectedTrack(0, 0)
    if track then

        if pan then
            for i = 0, reaper.CountSelectedTracks(0)-1 do
              tr = reaper.GetSelectedTrack(0,i)
              reaper.Main_OnCommand(40285, 0)
           end
        end
    end
end

function newNextTrack(pan)
    return function()
        return NextTrack(pan)
    end
end

-- GUI.New("Name2", "Text", {
--     z = 11,
--     x = 280,
--     y = 10,
--     caption = "Script by Taras Umanskiy",
--     font = 2,
--     color = "txt",
--     bg = "wnd_bg",
--     shadow = false
-- })


-- таблица со списком кнопок c параметрами которые нужно выводить.
function read_file(path)
    local open = io.open
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then
        return nil
    end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
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

function parse_simple_preset_content(content)
    content = str_split(content, "\n")
    res = {}
    for rowKey, rowValue in ipairs(content) do
        local row = str_split(rowValue, ',')
        table.insert(res, {
            text = row[1],
            color = row[2] == 'true',
            text_left = row[3],
            text_center = row[4],
            text_right = row[5],
            text_add = row[6],
            text_end = row[7],
            pan = row[8] == 'true',
        })
    end
    return res
end


function SavePresets(saveFile,track_settings)
    local file = io.open(saveFile, "w") -- Открываем файл для записи
    for _, setting in ipairs(track_settings) do
        local text = setting.text ~= '' and setting.text or '_'
        local color = setting.color and 'true' or 'false'
        local text_left = setting.text_left
        local text_right = setting.text_right
        local text_center = setting.text_center
        local text_add = setting.text_add
        local text_end = setting.text_end
        local pan = setting.pan and tostring(setting.pan) or 'false'

        local line = string.format("%s,%s,%s,%s,%s,%s,%s,%s\n",
            text, color, text_left, text_right, text_center, text_add, text_end, pan
        )
        file:write(line) -- Записываем строку в файл
    end

    file:close() -- Закрываем файл
end

function LoadPresets(filename)
    local track_settings = {} -- Создаем пустой массив для хранения данных
    local file = io.open(filename, "r") -- Открываем файл для чтения
    if file then
        for line in file:lines() do
            local values = {}
            for value in line:gmatch("[^,]+") do
                 table.insert(values, value ~= 'nil' and value or false)
            end

            local setting = {
                text = values[1] ~= '_' and values[1] or '',
                color = values[2] == true,
                text_left = values[3]  or false,
                text_right = values[4]  or false,
                text_center = values[5]  or false,
                text_add = values[6] or false,
                text_end = values[7] or false,
                pan = values[8] ~= 'nil' and tonumber(values[8]) or false
                -- pan = values[8] ~= 'false' and tonumber(values[8]) or false
            }

            table.insert(track_settings, setting) -- Добавляем полученные данные в массив
        end

        file:close() -- Закрываем файл
    end

    return track_settings
end


local fileExists = reaper.file_exists(presetFile)

if fileExists then
  track_settings = LoadPresets(presetFile)
else
  r.RecursiveCreateDirectory(presetPath, 0)
  track_settings = track_set
  SavePresets(presetFile,track_set)
  SavePresets(saveFile,track_set)
end


window_width_array = {}

for i=1, #track_settings do

    local x_margin = 5

    local color = false

    local total_width = 0

  if track_settings[i].color then
    color = track_settings[i].color
  end

  local name = track_settings[i].text

    local width = 70
    if track_settings[i].width then
        width = track_settings[i].width
    end

    local height = 24
    if track_settings[i].height then
        height = track_settings[i].height
    end

    local margin = 5
    if track_settings[i].margin then
        margin = track_settings[i].margin
    end

    local margin_bottom = 30
    if track_settings[i].margin then
        margin_bottom = track_settings[i].margin
    end

  GUI.New("insert_marker_" .. i, "Button", {
        z = 11,
        x = margin,
        y = i * margin_bottom, -- смещаем каждую сл. кнопку на 30 пикс ниже предыдущей
        w = width,
        h = height,
        caption = name,
        font = 3,
        col_txt = "txt",
        col_txt = 'white',
        col_fill = "elm_frame",
        func = newTrackName(name, color) --здесь мы передаем обработчик нажатия на кнопку, конструктор создает объект функции которая позже будет вызывана при нажатии
    })

    total_width = margin + width + margin

    -- GUI.New("color_picker_"..i, "Button", {
    --     z = 11,
    --     x = total_width,
    --     y = i * margin_bottom,
    --     w = height,
    --     h = height,
    --     caption = "",
    --     font = 3,
    --     col_fill = color,
    --     func =  newColorPicker("color_picker_"..i)
    -- })
    -- total_width = total_width + height + margin

if track_settings[i].text then
           --добавляем кнопку
           local text = track_settings[i].text

           input_width = height * 1.5

                   GUI.New("newRevTrack_"..i, "Button", {
                   z = 11,
                   x = total_width,
                   y = i * margin_bottom,
                   w = height,
                   h = height,
                   caption = '<<',
                   col_txt = 'red',
                   font = 3,
                   func = newPrevTrack(text)
               })

           total_width = total_width + height + margin
end

if track_settings[i].text then
           --добавляем кнопку
           local text = track_settings[i].text

           input_width = height * 1.5

               GUI.New("next_"..i, "Button", {
                   z = 11,
                   x = total_width,
                   y = i * margin_bottom,
                   w = height,
                   h = height,
                   caption = '>>',
                   col_txt = 'lime',
                   font = 3,
                   -- func = reaper.Main_OnCommand(40285, 0);
                   func = newNextTrack(text)
               })

           total_width = total_width + height + margin
       end
---additional buttons
    if track_settings[i].text_left then

        local content = track_settings[i].text_left
        local input_width = width

        if type(content) == 'boolean' and content == true then
            content = 'L'
            input_width = height * 1.5

            GUI.New("textbox_left_"..i, "Button", {
                z = 11,
                x = total_width,
                y = i * margin_bottom,
                w = input_width,
                h = height,
                caption = content,
                font = 3,
                func = newAddWord(content)
            })
        elseif type(content) == 'string' then
            GUI.New("textbox_left_"..i, "Button", {
                z = 11,
                x = total_width,
                y = i * margin_bottom,
                w = input_width,
                h = height,
                caption = content,
                font = 3,
                func = newAddWord(content)
            })

            -- GUI.New("textbox_left_"..i, "Textbox", {
            --     z = 11,
            --     x = total_width,
            --     y = i * margin_bottom,
            --     w = input_width,
            --     h = height,
            --     font = 3,
            -- })
            -- GUI.Val("textbox_left_"..i, content)
        end

        total_width = total_width + input_width + margin
    end


    if track_settings[i].text_right then
        local content = track_settings[i].text_right
        local input_width = width

        if type(content) == 'boolean' and content == true then
            content = 'R'
            input_width = height * 1.5

            GUI.New("textbox_right_"..i, "Button", {
                z = 11,
                x = total_width,
                y = i * margin_bottom,
                w = input_width,
                h = height,
                caption = content,
                font = 3,
                func = newAddWord(content)
            })
        elseif type(content) == 'string' then
            GUI.New("textbox_right_"..i, "Button", {
                z = 11,
                x = total_width,
                y = i * margin_bottom,
                w = input_width,
                h = height,
                caption = content,
                font = 3,
                func = newAddWord(content)
            })
            -- GUI.New("textbox_right_"..i, "Textbox", {
            --     z = 11,
            --     x = total_width,
            --     y = i * margin_bottom,
            --     w = input_width,
            --     h = height,
            --     font = 3,
            -- })
            -- GUI.Val("textbox_right_"..i, content)
        end
        total_width = total_width + input_width + margin
    end

    if track_settings[i].text_center then
        local content = track_settings[i].text_center
        local input_width = width
        if type(content) == 'boolean' and content == true then
            content = 'C'
            input_width = height * 1.5

            GUI.New("textbox_center_"..i, "Button", {
                z = 11,
                x = total_width,
                y = i * margin_bottom,
                w = input_width,
                h = height,
                caption = content,
                font = 3,
                func = newAddWord(content)
            })
        elseif type(content) == 'string' then
            GUI.New("textbox_center_"..i, "Button", {
                z = 11,
                x = total_width,
                y = i * margin_bottom,
                w = input_width,
                h = height,
                caption = content,
                font = 3,
                func = newAddWord(content)
            })
            -- GUI.New("textbox_center_"..i, "Textbox", {
            --     z = 11,
            --     x = total_width,
            --     y = i * margin_bottom,
            --     w = input_width,
            --     h = height,
            --     font = 3,
            -- })
            -- GUI.Val("textbox_center_"..i, content)
        end
        total_width = total_width + input_width + margin

    end

    if track_settings[i].text_add then
        local content = track_settings[i].text_add
        local input_width = width
        if type(content) == 'boolean' then
            content = ' A'
            input_width = height * 1.5
        end

        GUI.New("textbox_add_"..i, "Button", {
                z = 11,
                x = total_width,
                y = i * margin_bottom,
                w = input_width,
                h = height,
                caption = content,
                font = 3,
                func = newAddWord(content)
        })

        total_width = total_width + input_width + margin
    end

    if track_settings[i].text_end then
        local content = track_settings[i].text_end
        local input_width = width
        if type(content) == 'boolean' then
            content = ' A'
            input_width = height * 1.5
        end

        GUI.New("textbox_end_"..i, "Button", {
                z = 11,
                x = total_width,
                y = i * margin_bottom,
                w = input_width,
                h = height,
                caption = content,
                -- col_txt = content,
                font = 3,
                func = newAddWord(content)
        })

        total_width = total_width + input_width + margin
    end

     if track_settings[i].pan then
        --добавляем кнопку
        local pan = track_settings[i].pan

        input_width = height * 1.5

            GUI.New("pan_mines_"..i, "Button", {
                z = 11,
                x = total_width,
                y = i * margin_bottom,
                w = input_width,
                h = height,
                caption = '' .. -pan,
                col_txt = 'yellow',
                font = 3,
                func = newAddPan(-pan)
            })

        total_width = total_width + input_width + margin
    end

if track_settings[i].pan then

           local text = track_settings[i].text

           input_width = height * 1

               GUI.New("newNextTrack_end_"..i, "Button", {
                   z = 11,
                   x = total_width,
                   y = i * margin_bottom,
                   w = input_width,
                   h = height,
                   caption = '>>',
                   col_txt = 'lime',
                   font = 3,
                   func = newNextTrack(text)
               })

           total_width = total_width + input_width + margin
       end

    if track_settings[i].pan then

        local pan = track_settings[i].pan

        input_width = height * 1.5

            GUI.New("pan_plus_"..i, "Button", {
                z = 11,
                x = total_width,
                y = i * margin_bottom,
                w = input_width,
                h = height,
                caption = '' .. pan,
                col_txt = 'yellow',
                font = 3,
                func = newAddPan(pan)
            })

        total_width = total_width + input_width + margin
    end


    window_width_array[#window_width_array+1] = total_width

end
table.sort(window_width_array)

GUI.name = "• RENAME TRACKS TOOLS beta • v1.0 • by Taras Umanskiy"
-- GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, window_width_array[#window_width_array], 437

local max_y = 0
for _, elm in pairs(GUI.elms) do
    if elm.y + elm.h > max_y then
        max_y = elm.y + elm.h
    end
end
GUI.x, GUI.y, GUI.w, GUI.h = 20, 0, window_width_array[#window_width_array], max_y + 20 -- Добавляем отступ в 20 пикселей
GUI.anchor, GUI.corner = "mouse", "L"

-- инициализация гуя
GUI.Init()
GUI.Main()