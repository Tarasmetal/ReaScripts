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


console = true

function Msg(value)
  if console then
    reaper.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

--подключение либы для гуя
local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Не удалось загрузить библиотеку Lokasenna_GUI. Пожалуйста, установите 'Lokasenna's GUI library v2 для Lua', доступно на ReaPack, затем запустите 'Set Lokasenna_GUI v2 library path.lua' скрипт в вашем Action List.", "Whoops!", 0)
    return
end

loadfile(lib_path .. "Core.lua")()

GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Textbox.lua")()
GUI.req("Classes/Class - Label.lua")()

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

-- таблица со списком кнопок c параметрами которые нужно выводить.
local track_settings = {
  {
        text = 'INSTRUM',
        color = false,
        text_left = 'Delay',
        text_right = 'Reverb',
        text_center = 'Filter',
        text_add = 'Mod',
        text_end = 'FX',
        pan = false,

    },
    {
        text = '',
        color = false,
        text_left = 'Click',
        text_right = 'MUSIC',
        text_center = 'NEW',
        text_add = 'OLD',
        text_end = 'DRM',
        pan = false,

    },
     {
        text = 'REFERENCE',
        color = false,
        text_left = 'MIX',
        text_right = 'DEMO',
        text_center = 'PlayBack',
        text_add = 'LIVE',
        text_end = 'STUDIO',

    },
    {
        text = 'MIX',
        color = false,
        text_left = 'SUM',
        text_right = 'FX',
        text_center = 'DBL',
        text_add = 'BUS',
        pan = 0,

    },
    {
        text = 'Drums',
        color = false,
        text_left = 'Comp',
        text_right = 'PR',
        text_center = 'Verb',
        text_add = 'MIDI',
        col_fill = 'red',
        pan = 5,
    },
    {
        text = 'Kick',
        color = false,
        text_left = 'in',
        text_right = 'out',
        text_center = 'Sub',
        text_add = 'DIR',
        pan = 10,
    },
    {
        text = 'Snare',
        color = false,
        text_left = 'Top',
        text_right = 'Bot',
        text_center = 'Rim',
        text_add = 'trg',
        pan = 15,

    },
     {
        text = 'Clap',
        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = '1',
        text_add = '2',
        pan = 20,

    },
    {
        text = 'Tom',
        color = false,
        text_left = '1',
        text_right = '2',
        text_center = '3',
        text_add = 'trg',
        pan = 25,

    },
    {
        text = 'Tom',
        color = false,
        text_left = 'Alt',
        text_right = 'Rack',
        text_center = 'Floor',
        text_add = 'trg',
        pan = 30,

    },
    {
        text = 'HiHat',
        color = false,
        text_left = 'O',
        text_right = 'C',
        text_center = '1',
        text_add = '2',
        pan = 35,
    },
    {
        text = 'Crash',
        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = '3',
        text_add = '4',
        pan = 40,

    },
    {
        text = 'China',
        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = '5',
        text_add = '6',
        pan = 45,

    },
    {
        text = 'Ride',
        color = false,
        text_left = 'Bell',
        text_right = '',
        text_center = '7',
        text_add = '8',
        pan = 50,
    },
    {
        text = 'Splash',

        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = '9',
        text_add = '10',
        pan = 55,
    },
    {
        text = 'OH',

        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = 'OverHeads',
        text_add = 'BUS',
        pan = 60,

    },
    {
        text = 'RM',
        color = false,
        text_left = 'Mid',
        text_right = 'Side',
        text_center = 'Mono',
        text_add = 'BUS',
        pan = 65,

    },
    {
        text = 'Room',
        color = false,
        text_left = 'Near',
        text_right = 'Far',
        text_center = 'Crush',
        text_add = 'Room',
        pan = 70,

    },
    -- {
    --     text = '',
    --     color = false,
    --     text_left = '',
    --     text_right = '',
    --     text_center = '',
    --     text_add = '',
    --     text_end = '',
    --     pan = false,
    -- },
     {
        text = '',
        color = false,
        text_left = 'on_Axis',
        text_right = 'off_Axis',
        text_center = 'Cap',
        text_add = 'Cone',
        text_end = 'Edge',
        pan = false,
    },
     {
        text = 'BASS',
        color = false,
        text_left = 'DI',
        text_right = 'Sub',
        text_center = 'Lo',
        text_add = 'Hi',
        pan = 75,

    },
     {
        text = 'GTR',
        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = 'DI',
        text_add = 'BUS',
        pan = 80,

    },
     {
        text = 'GTR',
        color = false,
        text_left = 'Cln',
        text_right = 'Dist',
        text_center = 'Amp',
        text_add = 'Cab',
        pan = 85,

    },
     {
        text = 'GTRS',
        color = false,
        text_left = 'rtm',
        text_right = 'lead',
        text_center = 'solo',
        text_add = 'Add',
        pan = 90,

    },
    {
        text = '',
        color = false,
        text_left = 'Dyn',
        text_right = 'Cond',
        text_center = 'ЗБС',
        text_add = 'Tape',
        text_end = 'Warm',
        pan = false,

    },
     {
        text = 'Synth',
        color = false,
        text_left = 'Lead',
        text_right = 'Chrds',
        text_center = 'Pluck',
        text_add = 'Arp',
        pan = 95,

    },
     {
        text = 'Synths',
        color = false,
        text_left = 'Pad',
        text_right = 'SEQ',
        text_center = 'Atmo',
        text_add = 'Sub',
        pan = 100,

    },
     {
        text = 'Keys',
        color = false,
        text_left = 'Хуейс',
        text_right = 'Piano',
        text_center = 'Melody',
        text_add = 'BUS',
        pan = false,

    },
    {
        text = 'Strings',
        color = false,
        text_left = 'Ensemble',
        text_right = 'Cellos',
        text_center = 'Violas',
        text_add = 'Violins',
        pan = false,

    },
    {
        text = '',
        color = false,
        text_left = 'SingAlong',
        text_right = 'SFX',
        text_center = 'Pitch',
        text_add = 'Dry',
        text_end = 'Wet',
        pan = false,

    },
    {
        text = 'Vox',
        color = false,
        text_left = 'DBL',
        text_right = 'BCK',
        text_center = 'Low',
        text_add = 'Mid',
        text_end = 'High',
        pan = false,

    },
    {
        text = 'Vox',
        color = false,
        text_left = 'Cln',
        text_right = 'Scr',
        text_center = 'Grl',
        text_add = 'Wishper',
        text_end = 'Harmony',
        pan = false,

    },
     {
        text = 'Vox',
        color = false,
        text_left = 'Verse',
        text_right = 'Chorus',
        text_center = 'Main',
        text_add = 'Flow',
        text_end = 'BUS',
        pan = false,

    },
    --  {
    --     text = '',
    --     color = false,
    --     text_left = '',
    --     text_right = '',
    --     text_center = '',
    --     text_add = '',
    -- pan = false,

    -- },
}
    -- {
        -- text = '',
        -- color = false,
        -- text_left = '',
        -- text_right = '',
        -- text_center = '',
        -- text_add = '',
        -- pan = false,

    -- },
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

GUI.x, GUI.y, GUI.w, GUI.h = 20, 0, window_width_array[#window_width_array],990
GUI.anchor, GUI.corner = "mouse", "L"

-- инициализация гуя
GUI.Init()
GUI.Main()


-- Change length of selected items to 4 beats based on current tempo markers.
-- written by newbie Thonex
-- console outputs a bunch of data... just so I could learn.


-- function Msg (param)
--   reaper.ShowConsoleMsg(tostring (param).."\n")
-- end

-- function Main()
--   reaper.ClearConsole()
--   Num_of_Items = reaper.CountSelectedMediaItems(0)
--   Msg("Number of items: ".. Num_of_Items)

--   for i = 0, Num_of_Items - 1 do

--     Item = reaper.GetSelectedMediaItem(0,i)

--     Take = reaper.GetMediaItemTake(Item, 0)
--     _, Take_Name = reaper.GetSetMediaItemTakeInfo_String(Take, "P_NAME", "", 0)


--     Item_Len = reaper.GetMediaItemInfo_Value(Item, "D_LENGTH")
--     Item_Pos = reaper.GetMediaItemInfo_Value(Item, "D_POSITION")
--     Cursor_Pos = reaper.SetEditCurPos( Item_Pos,0, 0 )
--     Tempo_ID =  reaper.FindTempoTimeSigMarker( 0, Item_Pos )
--     retval, pos, measure_pos, beat_pos, bpm, timesig_num, timesig_denom, lineartempoOut = reaper.GetTempoTimeSigMarker(0, Tempo_ID)
--     bpm = tostring(bpm)
--     Len_calc = (60/bpm)*4

--     reaper.SetMediaItemLength(Item,Len_calc, 1 )
--     Item_Track = reaper.GetMediaItemTrack(Item)
--     _, Track_Name = reaper.GetTrackName(Item_Track, "")

--     Msg(Track_Name)
--     Msg("Item: ".. i)
--     Msg("Item name: ".. Take_Name)
--     Msg("Len: ".. Len_calc)
--     Msg("Pos: ".. Item_Pos)
--     Msg("Tempo ID: ".. Tempo_ID)
--     Msg("Tempo: ".. bpm)
--     Msg("Time Sig: ".. timesig_num)
--     Msg("------------------------------")

--   end

-- end

-- Main()
