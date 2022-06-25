-- @description trs_Project Render Metadata
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link https://github.com/Tarasmetal/ReaScripts
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies


-- Get Project Render Metadata IDs
-- Edgemeal - https://www.paypal.me/Edgemeal
-- Testing: Win10 x64, REAPER v6.10+dev0511, JS_API v1.002.

VK_HOME = 0x24
VK_DOWN = 0x28

function SendKey(hwnd, vk_key)
  reaper.JS_WindowMessage_Send(hwnd, "WM_KEYDOWN", vk_key, 0,0,0)
  reaper.JS_WindowMessage_Send(hwnd, "WM_KEYUP", vk_key, 0,0,0)
end

function GetMetaData()
  local hwnd = reaper.JS_Window_FindTop("Project Render Metadata", true)
  if not hwnd then reaper.MB("Please open 'Project Render Metadata' window!", 'ERROR', 0) return end
  local lv = reaper.JS_Window_FindChildByID(hwnd, 0x42F) -- элемент управления ListView
  if not lv then return end
  local scheme_hwnd = reaper.JS_Window_FindChildByID(hwnd, 0x3E8) -- комбинированный список
  if not scheme_hwnd then return end
  local scheme_count = reaper.JS_WindowMessage_Send(scheme_hwnd, "CB_GETCOUNT", 0,0,0,0)
  local label_hwnd = reaper.JS_Window_FindChildByID(hwnd, 0x4D8) -- метка информации о типе файла

  local t = {} -- сохранить данные
  SendKey(scheme_hwnd, VK_HOME) -- выберите пункт первая схема combobox
  for i = 0, scheme_count-1 do -- петля через схемы
    --reaper.JS_WindowMessage_Send(scheme_hwnd, "CB_SETCURSEL",i,0,0,0)--< Не изменяет выбор комбо (только текст), вместо этого отправляйте ключи! :(
    local lv_count = reaper.JS_ListView_GetItemCount(lv)
    local scheme_name = reaper.JS_Window_GetTitle(scheme_hwnd,"")
    local filetype_text = reaper.JS_Window_GetTitle(label_hwnd,"") -- получить текст метки
    local header_line = scheme_name .. " - " .. filetype_text ..'\n' -- схема и информация о типе
    t[#t+1] = header_line .. string.rep('-', #header_line-1) -- заголовок+подчеркивание
    for index = 0, lv_count-1 do  -- сквозной ЛВ пользования
      local desc = reaper.JS_ListView_GetItemText(lv, index, 0)
      local id = reaper.JS_ListView_GetItemText(lv, index, 2)
      t[#t+1] = desc .. ' = ' .. id
    end

   t[#t+1] = '' -- пропустить строку
   SendKey(scheme_hwnd, VK_DOWN) -- выберите пункт следующая схема combobox
 end

  -- OPTIONAL: закройте окно 'Project Render Metadata' окно
  reaper.JS_Window_Destroy(hwnd)

  -- отображать данные
  reaper.ClearConsole()
  reaper.ShowConsoleMsg(table.concat(t,"\n"))
end

if not reaper.APIExists('JS_Localize') then
  reaper.MB('js_ReaScriptAPI extension is required for this script.', 'Missing API', 0)
else
  reaper.Main_OnCommand(42397, 0) -- Файл: показать окно метаданных рендеринга проекта
  GetMetaData()
end
reaper.defer(function () end)
