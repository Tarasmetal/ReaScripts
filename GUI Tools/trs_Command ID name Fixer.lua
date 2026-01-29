-- @description Исправление ID команд (Command ID name Fixer)
-- @author Taras Umanskiy
-- @version 1.7
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about Конвертирует случайные RS ID в KeyMap и меню файлах в читаемые имена на основе описания скрипта.
-- @changelog
--   + v1.7: Автоматический поиск reaper-kb.ini в папке ресурсов REAPER
--   + v1.6: Внедрен "Безопасный режим" с предпросмотром изменений (Safe Mode with Preview)
--   + Разделение логики анализа и применения изменений
--   + Таблица предпросмотра с чекбоксами для выбора конкретных замен
--   + Добавлена кнопка "Обработать меню" для обновления reaper-menu.ini
--   + Сохранение маппинга ID для использования в обработке меню
--   + Добавлено: Создание резервной копии (*.ini.bck) перед обработкой
--   + Добавлено: Опциональный фильтр поиска для обработки только совпадающих скриптов

local r = reaper
console = true

function msg(value) if console then r.ShowConsoleMsg(tostring(value) .. "\n") end end

title = 'Command ID name Fixer'
VERSION = '1.7'
author = 'Taras Umanskiy'
about = title .. ' ' .. VERSION .. ' | by ' .. author
ListDir = {}
ListDir.scriptDir, ListDir.scriptFileName = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")
scriptDir = ListDir.scriptDir
scriptFileName = ListDir.scriptFileName
windowTitle = about

local ctx = r.ImGui_CreateContext(windowTitle)
local size = r.GetAppVersion():match('Win64') and 12 or 14
local font = reaper.ImGui_CreateFont('sans-serif', size)
reaper.ImGui_Attach(ctx, font)

-- State variables
local selected_file = ""
local status_msg = "Ожидание выбора файла..."
local process_log = ""
local filter_text = ""
local last_id_map = nil -- Stores ID mappings from the last ProcessFile run

-- Auto-detect reaper-kb.ini
local resource_path = r.GetResourcePath()
local sep = package.config:sub(1,1)
local auto_kb_path = resource_path .. sep .. "reaper-kb.ini"
local f_check = io.open(auto_kb_path, "r")
if f_check then
    f_check:close()
    selected_file = auto_kb_path
    status_msg = "Файл автоматически найден: " .. auto_kb_path
end

-- Analysis State
local file_lines = {}
local analysis_results = {} -- { line_index, old_id, new_id, desc, section, enabled }
local is_analyzed = false
local current_filepath = ""

-- Helper: Escape Lua pattern magic characters
function escape_lua_pattern(s)
  return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- Helper: Escape replacement string for gsub (% -> %%)
function escape_replacement(s)
  return (s:gsub("%%", "%%%%"))
end

-- Logic from AHK: Clean up string
local function CleanString(str)
  local s = str
  s = s:lower() -- Lowercase
  s = s:gsub("%s", "_") -- Spaces -> _
  s = s:gsub("[%.%,%(%)%[%]%+':]", "") -- Remove . , ( ) [ ] + ' : (excluding -)
  s = s:gsub('["]', '') -- Remove quotes
  s = s:gsub("_-_", "_") -- _-_ -> -
  s = s:gsub("__+", "_") -- Remove double underscores
  return s
end

-- Logic from AHK: Get suffix by section ID
local function GetSectionSuffix(sectionID)
  local id = tonumber(sectionID)
  if id == 32060 then return "_me" end
  if id == 32062 then return "_mie" end
  return ""
end

-- STEP 1: Analyze File
local function AnalyzeFile(filepath)
  local f = io.open(filepath, "r")
  if not f then
    status_msg = "Ошибка: Не удалось открыть файл."
    return
  end

  local content = f:read("*all")
  f:close()

  -- Reset state
  file_lines = {}
  analysis_results = {}
  current_filepath = filepath
  
  -- Split into lines
  for line in content:gmatch("([^\r\n]*)\r?\n?") do
    if line ~= "" then table.insert(file_lines, line) end
  end

  -- Pass 1: Identify SCR lines candidates
  for i, line in ipairs(file_lines) do
    if line:match("^SCR%s+") then
      local section, old_id, desc_part = line:match("^SCR%s+%d+%s+(%d+)%s+(RS[%w_]+)%s+\"(.-)\"")

      if section and old_id and desc_part then
        -- Filter check
        local matches_filter = true
        if filter_text ~= "" then
          if not desc_part:lower():find(filter_text:lower(), 1, true) then
            matches_filter = false
          end
        end

        if matches_filter then
          -- Clean the name
          local clean_name = desc_part
          clean_name = clean_name:gsub("^Script: ", ""):gsub("^Custom: ", "")
          clean_name = clean_name:gsub("%.[lL][uU][aA]$", ""):gsub("%.[eE][eE][lL]$", ""):gsub("%.[pP][yY]$", "")
  
          local base_id = CleanString(clean_name)
          local suffix = GetSectionSuffix(section)
          local new_id = "" .. base_id .. suffix
  
          if old_id ~= new_id then
             table.insert(analysis_results, {
                 line_index = i,
                 old_id = old_id,
                 new_id = new_id,
                 desc = desc_part,
                 section = section,
                 enabled = true
             })
          end
        end
      end
    end
  end
  
  is_analyzed = true
  status_msg = "Анализ завершен. Найдено кандидатов: " .. #analysis_results
end

-- STEP 2: Apply Changes
local function ApplyChanges()
  if not is_analyzed or not current_filepath then return end
  
  local count_scr = 0
  local count_key = 0
  local id_map = {} -- Map old -> new
  
  -- Create map from enabled items and update lines
  for _, item in ipairs(analysis_results) do
      if item.enabled then
          id_map[item.old_id] = item.new_id
          
          local line = file_lines[item.line_index]
          -- Replace ID in the line
          local new_line = line:gsub(escape_lua_pattern(item.old_id), escape_replacement(item.new_id), 1)
          file_lines[item.line_index] = new_line
          
          count_scr = count_scr + 1
      end
  end
  
  -- Update global map for menu processing
  last_id_map = id_map

  -- Pass 2: Process KEY lines in memory
  for i, line in ipairs(file_lines) do
    if line:match("^KEY%s+") then
       local prefix, old_id_ref, rest = line:match("^(KEY%s+%d+%s+%d+%s+_)(RS[%w_]+)(.*)$")
       if prefix and old_id_ref and id_map[old_id_ref] then
         local new_id = id_map[old_id_ref]
         file_lines[i] = prefix .. new_id .. rest
         count_key = count_key + 1
       end
    end
  end

  -- Write result
  -- Backup
  local backup_path = current_filepath .. ".bck"
  local f_in = io.open(current_filepath, "r")
  if f_in then
      local c = f_in:read("*all")
      f_in:close()
      local f_bck = io.open(backup_path, "w")
      if f_bck then f_bck:write(c); f_bck:close() end
  end

  local out_f = io.open(current_filepath, "w")
  if out_f then
    out_f:write(table.concat(file_lines, "\n"))
    out_f:close()
    status_msg = "Готово!\nSCR переименовано: " .. count_scr .. "\nKEY обновлено: " .. count_key .. "\nБекап: " .. backup_path
    
    -- Reset analysis
    is_analyzed = false
    analysis_results = {}
    file_lines = {}
  else
    status_msg = "Ошибка при записи файла."
  end
end

local function ProcessMenuFile()
  if not last_id_map or next(last_id_map) == nil then
    status_msg = "Ошибка: Нет данных маппинга. Сначала примените изменения к файлу KeyMap."
    return
  end

  local dir = selected_file:match("(.*[/\\])")
  if not dir then dir = "" end
  local menu_path = dir .. "reaper-menu.ini"

  local f = io.open(menu_path, "r")
  if not f then
     local retval, filename = r.GetUserFileNameForRead("", "Выберите reaper-menu.ini", "reaper-menu.ini")
     if retval then
        menu_path = filename
        f = io.open(menu_path, "r")
     end
     
     if not f then
        status_msg = "Ошибка: reaper-menu.ini не найден."
        return
     end
  end

  local content = f:read("*all")
  f:close()

  local backup_path = menu_path .. ".bck"
  local backup_f = io.open(backup_path, "w")
  if backup_f then
    backup_f:write(content)
    backup_f:close()
  end

  local lines = {}
  for line in content:gmatch("([^\r\n]*)\r?\n?") do
    if line ~= "" then table.insert(lines, line) end
  end

  local count_menu = 0
  
  for i, line in ipairs(lines) do
    local newline = line:gsub("(_RS[%w_]+)", function(captured_id)
        local core_id = captured_id:sub(2) -- remove leading _
        if last_id_map[core_id] then
           return "_" .. last_id_map[core_id]
        end
        return captured_id
    end)

    if newline ~= line then
       lines[i] = newline
       count_menu = count_menu + 1
    end
  end

  local out_f = io.open(menu_path, "w")
  if out_f then
    out_f:write(table.concat(lines, "\n"))
    out_f:close()
    status_msg = status_msg .. "\nМеню обновлено: " .. count_menu .. " замен."
  else
    status_msg = status_msg .. "\nОшибка записи меню."
  end
end

local function myWindow()
  if r.ImGui_Button(ctx, 'Выбрать файл (reaper-kb.ini)') then
    local retval, filename = r.GetUserFileNameForRead("", "Выберите файл", "")
    if retval then
      selected_file = filename
      status_msg = "Файл выбран: " .. filename
      last_id_map = nil 
      is_analyzed = false
      analysis_results = {}
    end
  end

  if selected_file ~= "" then
    r.ImGui_SameLine(ctx)
    r.ImGui_Text(ctx, selected_file:match("([^/\\]+)$"))

    r.ImGui_Separator(ctx)

    local changed, new_text = r.ImGui_InputText(ctx, 'Фильтр (по названию)', filter_text)
    if changed then 
        filter_text = new_text 
        -- Reset analysis on filter change
        if is_analyzed then
            is_analyzed = false
            analysis_results = {}
            status_msg = "Фильтр изменен. Нажмите 'Анализировать'."
        end
    end
    
    if r.ImGui_Button(ctx, 'Анализировать') then
      AnalyzeFile(selected_file)
    end
    
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, 'Обработать меню') then
      ProcessMenuFile()
    end
  end
  
  -- Preview Table
  if is_analyzed and #analysis_results > 0 then
      r.ImGui_Separator(ctx)
      r.ImGui_Text(ctx, "Предпросмотр (" .. #analysis_results .. " изменений):")
      
      -- Helper buttons
      if r.ImGui_Button(ctx, "Выбрать все") then
          for _, item in ipairs(analysis_results) do item.enabled = true end
      end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "Снять все") then
          for _, item in ipairs(analysis_results) do item.enabled = false end
      end
      
      local table_flags = r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_RowBg() | r.ImGui_TableFlags_ScrollY() | r.ImGui_TableFlags_Resizable()
      if r.ImGui_BeginTable(ctx, 'preview_table', 4, table_flags, 0, 300) then
          r.ImGui_TableSetupColumn(ctx, "Chk", r.ImGui_TableColumnFlags_WidthFixed(), 30)
          r.ImGui_TableSetupColumn(ctx, "Описание", r.ImGui_TableColumnFlags_WidthStretch())
          r.ImGui_TableSetupColumn(ctx, "Старый ID", r.ImGui_TableColumnFlags_WidthFixed(), 150)
          r.ImGui_TableSetupColumn(ctx, "Новый ID", r.ImGui_TableColumnFlags_WidthFixed(), 150)
          r.ImGui_TableHeadersRow(ctx)
          
          for i, item in ipairs(analysis_results) do
              r.ImGui_TableNextRow(ctx)
              
              r.ImGui_TableSetColumnIndex(ctx, 0)
              local chk_changed, chk_val = r.ImGui_Checkbox(ctx, "##chk"..i, item.enabled)
              if chk_changed then item.enabled = chk_val end
              
              r.ImGui_TableSetColumnIndex(ctx, 1)
              r.ImGui_Text(ctx, item.desc)
              
              r.ImGui_TableSetColumnIndex(ctx, 2)
              r.ImGui_Text(ctx, item.old_id)
              
              r.ImGui_TableSetColumnIndex(ctx, 3)
              r.ImGui_Text(ctx, item.new_id)
          end
          r.ImGui_EndTable(ctx)
      end
      
      if r.ImGui_Button(ctx, "ПРИМЕНИТЬ ИЗМЕНЕНИЯ") then
          ApplyChanges()
      end
  elseif is_analyzed and #analysis_results == 0 then
      r.ImGui_Separator(ctx)
      r.ImGui_Text(ctx, "Изменений не найдено (проверьте фильтр).")
  end

  r.ImGui_Separator(ctx)
  r.ImGui_TextWrapped(ctx, status_msg)
end

local function loop()
  r.ImGui_PushFont(ctx, font, size)
  r.ImGui_SetNextWindowSize(ctx, 800, 600, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, windowTitle, true)
  if visible then
    myWindow()
    r.ImGui_End(ctx)
  end
  r.ImGui_PopFont(ctx)

  if open then
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then open = false end
    r.defer(loop)
  end
end

r.defer(loop)