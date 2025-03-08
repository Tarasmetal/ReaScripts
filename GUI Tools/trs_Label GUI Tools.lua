-- @description Label GUI Tools
-- @author Taras Umanskiy
-- @version 1.0
-- @provides
--   [main] .
--   [script] Functions/LabelFunctions.lua
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://vk.com/Tarasmetal
-- @about
--   # Инструменты для работы с метками в Reaper
--   Этот скрипт предоставляет удобный графический интерфейс для управления и редактирования меток (Label) в проекте Reaper.  Он позволяет быстро переименовывать метки, добавлять информацию о регионе и треке, а также выполнять другие полезные операции.
-- @changelog
--  + Code Fixies

r = reaper
console = false

function msg(value)
  if console then
    r.ShowConsoleMsg(tostring(value) .. "\n")
  end
end

myTime = ''
scrVersion = '0.1'
scrName = 'LABEL TOOLS' .. ' ' .. scrVersion .. ' | by Taras Umanskiy'

ListDir = {}
ListDir.scriptDir, ListDir.scriptFileName = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")

scriptDir = ListDir.scriptDir
scriptFileName = ListDir.scriptFileName

windowTitle = scrName

dofile(scriptDir .. "Functions/" .. "LabelFunctions.lua")
-----------------------------------------------------------------------------
local ctx = r.ImGui_CreateContext(windowTitle)
local size =  r.GetAppVersion():match('Win64') and 12 or 14
local font = reaper.ImGui_CreateFont('sans-serif', size)
r.ImGui_Attach(ctx, font)
click_count, text = 0, '/T /E'
color = nil
-----------------------------------------------------------------------------

function round(num)
  return num ~= 0 and math.floor(num+0.1) or math.ceil(num-0.1)
end

-- function round(exact, quantum)
--     local quant,frac = math.modf(exact/quantum)
--     return quantum * (quant + (frac > 0.5 and 1 or 0))
-- end

-- function round(x, n)
--     n = math.pow(10, n or 0)
--     x = x * n
--     if x >= 0 then x = math.floor(x + 0.5) else x = math.ceil(x - 0.5) end
--     return x / n
-- end

-- function round(num)
--   return math.floor(num + .5)
-- end

function btnColor(col, i)
    r.ImGui_PushID(ctx, color)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(color / 7.0, 0.6, 0.6, 1.0))
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(color / 7.0, 0.7, 0.7, 1.0))
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(color / 7.0, 0.8, 0.8, 1.0))
end

function btnCol(name, string, col, i)
              r.ImGui_PushID(ctx, col)
              r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
              r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
              r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           if r.ImGui_Button(ctx, name) then
              click_count, text = 0, string
              click_count = click_count + 1
           end
           r.ImGui_PopStyleColor(ctx, 3)
           r.ImGui_PopID(ctx)
           return
end
------------------------------------------------------------------------------------------------------------------

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

function btnCmdCol(name, idCmd, helpText, col, i)
           r.ImGui_PushID(ctx, col)
       r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           if r.ImGui_Button(ctx, ''..name..'') then
              click_count, text = 1, idCmd
              if idCmd ~= '' then
                r.Main_OnCommand(r.NamedCommandLookup('' .. idCmd ..''), 0)
              end
              click_count = click_count + 1
           end
            r.ImGui_PopStyleColor(ctx, 3)
            r.ImGui_PopID(ctx)

          if r.ImGui_IsItemHovered(ctx) then
          r.ImGui_BeginTooltip(ctx)
           r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
               if helpText ~= '' then
           r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), helpText)
               end
           r.ImGui_PopTextWrapPos(ctx)
           r.ImGui_EndTooltip(ctx)
            end

           return
end


function btnFuncCol(name, funcName, helpText, col, i)
           r.ImGui_PushID(ctx, col)
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        trs_HSV(col / 7.0, 0.6, 0.6, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), trs_HSV(col / 7.0, 0.7, 0.7, 1.0))
           r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  trs_HSV(col / 7.0, 0.8, 0.8, 1.0))
           if r.ImGui_Button(ctx, ''..name..'') then
              click_count, text = 0, funcName
              if funcName ~= '' then
                _G[funcName]() -- Вызываем функцию по имени переменной idCmd
              end
              funcName = ''
              click_count = click_count + 1
           end
            r.ImGui_PopStyleColor(ctx, 3)
            r.ImGui_PopID(ctx)

          if r.ImGui_IsItemHovered(ctx) then
          r.ImGui_BeginTooltip(ctx)
           r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
               if helpText ~= '' then
           r.ImGui_TextColored(ctx, hex2rgb('#C7C7C7'), helpText)
               end
           r.ImGui_PopTextWrapPos(ctx)
           r.ImGui_EndTooltip(ctx)
            end
               return
end

-- Создаем функцию, которая будет переименовывать выделенный айтем, вставив имя региона и имя трека
-- function RX()
--   -- Получаем выделенный айтем
--   local item = reaper.GetSelectedMediaItem(0, 0)
--   -- Проверяем, что айтем существует
--   if item then
--     -- Получаем позицию и длину айтема в секундах
--     local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
--     local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
--     -- Получаем количество регионов в проекте
--     local region_count = reaper.CountProjectMarkers(0)
--     -- Перебираем все регионы в цикле
--     for i = 0, region_count - 1 do
--       -- Получаем информацию о регионе по индексу
--       local _, is_region, region_pos, region_end, region_name = reaper.EnumProjectMarkers(i)
--       -- Проверяем, что это регион, а не маркер
--       if is_region then
--         -- Проверяем, попадает ли позиция айтема в диапазон региона
--         if item_pos >= region_pos and item_pos + item_len <= region_end then
--           -- Получаем трек, на котором находится айтем
--           local track = reaper.GetMediaItemTrack(item)
--           -- Получаем имя трека
--           local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
--           -- Формируем новое имя айтема, состоящее из имени региона и имени трека
--            new_item_name = tostring(region_name) .. " - " ..  tostring(track_name)
--           -- Устанавливаем новое имя айтему
--           reaper.GetSetMediaItemInfo_String(item, "P_NAME", new_item_name, true)
--           -- Прерываем цикл
--           break
--         end
--       end
--     end
--   end
--   -- reaper.UpdateArrange()
-- end

local function RR()
  -- Получить количество выделенных айтемов
  local num_items = reaper.CountSelectedMediaItems(0)

  -- Перебрать все выделенные айтемы
  for i = 0, num_items - 1 do
    -- Получить выделенный айтем
    local item = reaper.GetSelectedMediaItem(0, i)

    -- Проверить, что айтем существует
    if item then
      -- Получить позицию курсора воспроизведения
      local cursor_pos = reaper.GetCursorPosition()
      -- Получить имя региона, в котором находится курсор
      local RegionName = ""
      -- Получить количество регионов в проекте
      local num_regions = reaper.CountProjectMarkers(0)
      -- Перебрать все регионы
      for j = 0, num_regions - 1 do
        -- Получить информацию о регионе
        local _, is_region, start_pos, end_pos, name = reaper.EnumProjectMarkers(j)
        -- Проверить, что это регион и курсор внутри него
        if is_region and cursor_pos >= start_pos and cursor_pos <= end_pos then
          -- Сохранить имя региона
          RegionName = tostring(name)
          -- Прервать цикл
          break
        end
      end

      -- Получить активный трек
      local track = reaper.GetMediaItemTrack(item)
      -- Получить имя активного трека
      local track_name = ""
      if track then
        _, track_name = reaper.GetTrackName(track, "")
      end

      -- Объединить имя региона и имя трека
      local new_name = RegionName .. " " .. track_name

      local take = reaper.GetActiveTake(item)
      if take then
         reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
      end
    end
  end
end

local function RS()
  -- Получить количество выделенных айтемов
  local num_items = reaper.CountSelectedMediaItems(0)

  -- Перебрать все выделенные айтемы
  for i = 0, num_items - 1 do
    -- Получить выделенный айтем
    local item = reaper.GetSelectedMediaItem(0, i)

    -- Проверить, что айтем существует
    if item then
      -- Получить позицию курсора воспроизведения
      local cursor_pos = reaper.GetCursorPosition()
      -- Получить имя региона, в котором находится курсор
      local RegionName = ""
      -- Получить количество регионов в проекте
      local num_regions = reaper.CountProjectMarkers(0)
      -- Перебрать все регионы
      for j = 0, num_regions - 1 do
        -- Получить информацию о регионе
        local _, is_region, start_pos, end_pos, name = reaper.EnumProjectMarkers(j)
        -- Проверить, что это регион и курсор внутри него
        if is_region and cursor_pos >= start_pos and cursor_pos <= end_pos then
          -- Сохранить имя региона
          RegionName = tostring(name)
          -- Прервать цикл
          break
        end
      end

      -- Получить активный трек
      local track = reaper.GetMediaItemTrack(item)
      -- Получить имя активного трека
      local track_name = ""
      if track then
        _, track_name = reaper.GetTrackName(track, "")
      end

      -- Объединить имя региона и имя трека
      local new_name = RegionName .. " " .. track_name .. " " .. round(showBPM()) ..' bpm'

      local take = reaper.GetActiveTake(item)
      if take then
         reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
      end
    end
  end
end
function frame()
  local rv
    click_count = 0
      function showBPM()
          local bpm = reaper.Master_GetTempo()
          -- r.ImGui_Text(ctx, 'BPM: ')
          -- r.ImGui_SameLine(ctx)
          -- r.ImGui_TextColored(ctx, 0x88FF00FF, bpm)
          return tostring(bpm)
      end
      myBPM = tostring(showBPM())

      r.ImGui_Text(ctx,  'Selected Items:' .. '\n')
           r.ImGui_SameLine(ctx)
           selected_items_count =  r.CountSelectedMediaItems(0)
           if selected_items_count > 0 then
                 r.ImGui_TextColored(ctx, 0x88FF00FF, selected_items_count)
               else if selected_items_count == 1 then
                 r.ImGui_TextColored(ctx, 0xFF0036FF, selected_items_count)
               else
                 r.ImGui_TextColored(ctx, 0xFF0036FF, selected_items_count)
              end
           end

      btnCmdCol('Rename takes and source files','_XENAKIOS_RENMTAKEANDSOURCE','Xenakios/SWS: Rename takes and source files... (no undo)', 4,0)
      -- btnFuncCol('rename playback item', 'RR', 'XXX', 0) -- Load lua file script
      -- if r.ImGui_Button(ctx, 'RENAME TAKE - REGION + TRACKNAME') then
      --        RR()
      --    end
      --    if r.ImGui_Button(ctx, 'RENAME TAKE - REGION + TRACKNAME + BPM') then
      --           RS()
      --       end
      -- r.ImGui_Text(ctx,  '')
      r.ImGui_TextColored(ctx, 0xFFFF00FF, 'Rename LABEL Buttons:')

      btnCol('EMPTY##Empty','', 7,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  '')
      btnCol('RENAME##RegionTrack','/r /T', 5,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Region Track')
      btnCol('RENAME##RegionTrackBPM','/r /T '..round(showBPM()) ..'', 6,2)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Region Track BPM')
      btnCol('RENAME##NameOnly','/T', 5,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name only')
      btnCol('RENAME##NameIndex','/T_/E', 6,2)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name Index')
      btnCol('RENAME##NameTuned','/T /E Tunned', 4,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name Tuned')
      -- btnCol('RENAME','/T Fixed', 3,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name Fixed')
      btnCol('RENAME##NameClick','/T Click', 3,1)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name Click')

      btnCol('RENAME##NameIndex_BPM','/T_'..round(showBPM()) ..'', 7,5)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name_')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, 0xFFFF00FF,myBPM)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx, '')
      btnCol('RENAME##NameIndexBPM','/T_/E '.. round(showBPM()) ..' bpm', 7,5)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx,  'Name Index')r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, 0xFFFF00FF, myBPM)r.ImGui_SameLine(ctx)r.ImGui_Text(ctx, 'BPM')
      r.ImGui_Text(ctx,  '  ')
      btnCol('GO!', text, 9,3)
      r.ImGui_SameLine(ctx)
  if click_count % 2 == 1 then
      main(text) -- Execute your main function
      notes_to_names() -- Execute your main function
      delete() -- Execute your main function
  end
      rv, text = r.ImGui_InputText(ctx, ' ',text)r.ImGui_Text(ctx,  ' ')
  end
      r.ImGui_SameLine(ctx)
      r.ImGui_TextColored(ctx, 0xFF0036FF, text)

function loop()
  r.ImGui_PushFont(ctx, font, size)
  r.ImGui_PopFont(ctx)
  r.ImGui_SetNextWindowSize(ctx, 180, 150,  r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, windowTitle, true)
  if visible then
    frame(ctx)
    r.ImGui_End(ctx)
  end

-- Просто продолжаем цикл пока окно открыто
if open then
    r.defer(loop)
-- Не нужно явно уничтожать контекст - ReaImGui сделает это автоматически
end
end

 r.defer(loop)



