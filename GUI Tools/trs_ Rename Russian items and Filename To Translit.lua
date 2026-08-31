-- @description Транслитерация русских имен файлов в латиницу с GUI
-- @author Taras Umanskiy
-- @version 1.4.0
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about
--   Production-ready GUI инструмент для транслитерации аудио файлов в REAPER
--   
--   Основные возможности:
--   - Режимы сканирования: только файлы проекта или все доступные аудио
--   - Транслитерация кириллицы в латиницу
--   - Безопасное разрешение конфликтов с суффиксами
--   - Предпросмотр и dry-run режим
--   - Выборочное переименование
--   - Экспорт в CSV
--   - История операций с возможностью отката
--   - Корректный offline/online режим для надежного переименования
--   
--   Требования:
--   - REAPER
--   - ReaImGui extension
--   - SWS Extensions (для команды _BR_TOGGLE_ITEM_ONLINE)
-- @changelog
--   v.1.4.0 + КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: обновление путей перенесено ПОСЛЕ возврата items в online режим
--           + Изменена последовательность шагов: offline → wait → rename → wait → online → wait → update_paths → done
--           + Добавлен новый шаг 19 для обновления путей в проекте (после online)
--           + Добавлены шаги 16-18 для паузы после возврата в online (90мс стабилизации)
--           + Теперь 7 шагов вместо 6: шаги перенумерованы (16→20 для done)
--           + Это должно решить проблему с неправильными путями к файлам и items
--   v.1.3.0 + Исправлены корректные API функции: CountTakes вместо CountMediaItemTakes, GetTake вместо GetMediaItemTake
--           + Добавлено сохранение и восстановление выделения items при offline/online переключении
--           + Улучшена функция retarget_project_references с добавлением UpdateTimeline и подсчётом обновлённых путей
--           + Добавлено отображение количества обновлённых путей в статусе шага 3
--           + Исправлена работа set_items_offline для корректного сохранения выделения
--   v.1.2.0 + Использование команды SWS _BR_TOGGLE_ITEM_ONLINE для offline/online переключения
--           + Заменена функция set_takes_offline на set_items_offline с корректной работой через items, а не takes
--           + Исправлена проверка состояния items перед переключением
--           + Переименованы affected_takes → affected_items во всех местах
--           + Исправлена ошибка ImGui_BeginChild (boolean → WindowFlags_None)
--   v.1.1.0 + Исправлен механизм offline-переименования файлов
--           + Заменены устаревшие API функции (CountTakes → CountMediaItemTakes, GetTake → GetMediaItemTake)
--           + Добавлена проверка MIDI takes для предотвращения ошибок
--           + Увеличено время ожидания после offline до 300мс (было 120мс)
--           + Добавлена дополнительная пауза 90мс после обновления путей перед возвратом в online
--           + Обновлена структура шагов: 0→offline, 1-10→wait(300ms), 11→rename, 12-14→wait(90ms), 15→online, 16→done
--           + Улучшены статусные сообщения с отображением текущего шага (1/6, 2/6 и т.д.)
--   v.1.0.0 + Первая версия скрипта

if not reaper or not reaper.ImGui_CreateContext then
  reaper.ShowMessageBox("ReaImGui extension is required.", "Error", 0)
  return
end

local SCRIPT_NAME = "Translit Rename Production"
local ctx = reaper.ImGui_CreateContext(SCRIPT_NAME)

local translit_map = {
  ["А"]="A",["а"]="a", ["Б"]="B",["б"]="b", ["В"]="V",["в"]="v",
  ["Г"]="G",["г"]="g", ["Д"]="D",["д"]="d", ["Е"]="E",["е"]="e",
  ["Ё"]="E",["ё"]="e", ["Ж"]="Zh",["ж"]="zh", ["З"]="Z",["з"]="z",
  ["И"]="I",["и"]="i", ["Й"]="Y",["й"]="y", ["К"]="K",["к"]="k",
  ["Л"]="L",["л"]="l", ["М"]="M",["м"]="m", ["Н"]="N",["н"]="n",
  ["О"]="O",["о"]="o", ["П"]="P",["п"]="p", ["Р"]="R",["р"]="r",
  ["С"]="S",["с"]="s", ["Т"]="T",["т"]="t", ["У"]="U",["у"]="u",
  ["Ф"]="F",["ф"]="f", ["Х"]="Kh",["х"]="kh", ["Ц"]="Ts",["ц"]="ts",
  ["Ч"]="Ch",["ч"]="ch", ["Ш"]="Sh",["ш"]="sh", ["Щ"]="Shch",["щ"]="shch",
  ["Ъ"]="",["ъ"]="", ["Ы"]="Y",["ы"]="y", ["Ь"]="",["ь"]="",
  ["Э"]="E",["э"]="e", ["Ю"]="Yu",["ю"]="yu", ["Я"]="Ya",["я"]="ya"
}

local audio_exts = {
  wav=true, wave=true, mp3=true, flac=true, ogg=true, aif=true, aiff=true,
  w64=true, caf=true, opus=true, m4a=true, mp4=true, ape=true
}

local SORT_OLD = 1
local SORT_NEW = 2
local SORT_DIR = 3
local SORT_STATUS = 4

local state = {
  mode = 1,
  dry_run = true,
  filter_text = "",
  filter_conflicts_only = false,
  keep_spaces = true,
  plans = {},
  status = "Ready",
  project_dir = nil,
  history_dir = nil,
  export_dir = nil,
  logs_dir = nil,
  history = {},
  selected_batch_index = 0,
  sort_column = SORT_OLD,
  sort_asc = true,
  show_preview_popup = false,
  preview_text = "",
  pending_action = nil,
  last_error_log = nil,
  -- Временные данные для асинхронного офлайн-онлайн переименования
  rename_data = {
    step = 0,          -- 0=offline, 1..10=wait1, 11=rename, 12..14=wait2, 15=online, 16..18=wait3, 19=update_paths, 20=done
    wait_count = 0,
    selected = {},
    affected_items = {},
    saved_selection = {},
    rename_map = {},
    history_entries = {},
    errors = {},
    renamed = 0
  }
}

local function os_is_windows()
  local osname = reaper.GetOS() or ""
  return osname:match("Win") ~= nil
end

local PATH_SEP = os_is_windows() and "\\" or "/"

local function path_join(dir, name)
  if not dir or dir == "" then return name end
  local last = dir:sub(-1)
  if last == "/" or last == "\\" then
    return dir .. name
  end
  return dir .. PATH_SEP .. name
end

local function split_path(path)
  local dir, name = path:match("^(.*[\\/])(.-)$")
  if not dir then
    return "", path
  end
  if dir:sub(-1) == "/" or dir:sub(-1) == "\\" then
    dir = dir:sub(1, -2)
  end
  return dir, name
end

local function split_name_ext(filename)
  local base, ext = filename:match("^(.*)%.([^%.]+)$")
  if not base then
    return filename, ""
  end
  return base, ext
end

local function file_exists(path)
  if not path or path == "" then return false end
  -- reaper.FileSize is available since REAPER v7.02 and is UTF-8 safe on Windows
  if reaper.FileSize then
    local size = reaper.FileSize(path)
    return size and size >= 0
  end
  
  -- Fallback for older REAPER versions: use EnumerateFiles which is UTF-8 safe
  local dir, name = split_path(path)
  local i = 0
  while true do
    local f = reaper.EnumerateFiles(dir, i)
    if not f then break end
    if f == name then return true end
    i = i + 1
    if i > 20000 then break end -- Safety limit
  end
  return false
end

local function dir_exists(path)
  if not path or path == "" then return false end
  if reaper.EnumerateFiles(path, 0) ~= nil then return true end
  if reaper.EnumerateSubdirectories(path, 0) ~= nil then return true end
  return false
end

local function ensure_dir(path)
  if not path or path == "" then return false end
  if dir_exists(path) then return true end
  
  -- reaper.RecursiveCreateDirectory is UTF-8 safe and creates all parent dirs
  if reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(path, 0)
    return dir_exists(path)
  end

  -- Fallback for very old versions
  if os_is_windows() then
    os.execute('mkdir "' .. path .. '" >nul 2>nul')
  else
    os.execute('mkdir -p "' .. path .. '" >/dev/null 2>/dev/null')
  end
  return dir_exists(path)
end

local function rename_file(old_path, new_path)
  if not old_path or not new_path then return false, "Invalid paths" end
  
  -- Try JS_ReaScriptAPI if available (best for UTF-8 on Windows)
  if reaper.JS_File_Rename then
    local ok = reaper.JS_File_Rename(old_path, new_path)
    if ok then return true else return false, "JS_File_Rename failed" end
  end
  
  -- Standard Lua rename (safe on macOS/Linux, problematic on Windows with UTF-8)
  local ok, err = os.rename(old_path, new_path)
  if ok then return true end
  
  -- Fallback for Windows UTF-8: use cmd.exe move with proper quoting
  if os_is_windows() then
    -- Double quotes are needed for the entire command and for individual paths
    local cmd = string.format('chcp 65001 >nul & move /Y "%s" "%s"', old_path, new_path)
    local result = os.execute(cmd)
    -- On some systems result is 0, on others it's true
    if result == 0 or result == true then
      return true
    end
    return false, "Windows move command failed (check if file is in use)"
  end
  
  return false, err
end

local function msg_box(text, title)
  reaper.ShowMessageBox(tostring(text), tostring(title or "Info"), 0)
end

local function has_cyrillic(s)
  if not s then return false end
  -- 1. Check for UTF-8 Cyrillic bytes (D0 80 - D1 BF)
  if s:match("[\208\209][\128-\191]") then return true end
  -- 2. Check for literal Cyrillic characters as fallback
  if s:match("[А-Яа-яЁё]") then return true end
  return false
end

local function transliterate_utf8(str)
  local out = {}
  local i = 1
  while i <= #str do
    local b = str:byte(i)
    local len = 1
    if b >= 0xF0 then len = 4
    elseif b >= 0xE0 then len = 3
    elseif b >= 0xC0 then len = 2
    else len = 1 end
    local ch = str:sub(i, i + len - 1)
    out[#out + 1] = translit_map[ch] or ch
    i = i + len
  end
  return table.concat(out)
end

local function sanitize_filename(name, keep_spaces)
   if not keep_spaces then
      -- If spaces are not kept, replace " - " or " _ " or similar with just "-"
      -- before replacing remaining spaces with "_"
      name = name:gsub("%.%s+", ".") -- Remove spaces after dots
      name = name:gsub("%s*-%s*", "-")
      name = name:gsub("%s*_%s*", "_")
      name = name:gsub("%s+", "_")
      -- Remove brackets in this mode
      name = name:gsub("[%[%]%(%)]", "")
    end
    
    -- If keeping spaces, allow alphanumeric, dots, spaces, underscores, hyphens and brackets
    -- Otherwise, be more restrictive
    if keep_spaces then
      name = name:gsub("[^%w%._%-\208\209\128-\191 %[%]%(%)]", "_")
    else
      name = name:gsub("[^%w%._%-\208\209\128-\191]", "_")
    end
 
   -- Fix double separators
   name = name:gsub("_+", "_")
   name = name:gsub(" +", " ")
   
   -- Handle hyphen case
   if keep_spaces then
     -- Keep " - " clean
     name = name:gsub("_+%-", "-")
     name = name:gsub("%-_+", "-")
   else
     -- Without spaces, ensure we don't have "_-_"
     name = name:gsub("_+%-", "-")
     name = name:gsub("%-_+", "-")
   end
 
   name = name:gsub("^_+", "")
   name = name:gsub("_+$", "")
   name = name:gsub("^ +", "")
   name = name:gsub(" +$", "")
   name = name:gsub("^%-+", "")
   name = name:gsub("%-+$", "")
   
   if name == "" then
     name = "file"
   end
   return name
 end

local function is_audio_file(path)
  local _, filename = split_path(path)
  local _, ext = split_name_ext(filename)
  ext = (ext or ""):lower()
  return audio_exts[ext] == true
end

local function get_project_dir()
  local _, project_path = reaper.EnumProjects(-1, "")
  if project_path == "" then
    -- Try to get from project config if not saved yet
    project_path = reaper.GetProjectPath("")
  end
  
  local dir = ({split_path(project_path)})[1]
  if dir and dir ~= "" and dir_exists(dir) then
    return dir
  end
  
  -- Fallback to the path where the project file should be if we have a name but dir_exists fails
  if project_path ~= "" then
    local path_only = project_path:match("^(.*)[\\/]")
    if path_only and dir_exists(path_only) then return path_only end
  end

  return reaper.GetResourcePath()
end

local function timestamp()
  return os.date("%Y%m%d_%H%M%S")
end

local function escape_field(s)
  s = tostring(s or "")
  s = s:gsub("\\", "\\\\")
  s = s:gsub("\n", "\\n")
  s = s:gsub("|", "\\p")
  return s
end

local function unescape_field(s)
  s = tostring(s or "")
  s = s:gsub("\\p", "|")
  s = s:gsub("\\n", "\n")
  s = s:gsub("\\\\", "\\")
  return s
end

local function write_lines(path, lines)
  local f = io.open(path, "wb")
  if not f then return false end
  for _, line in ipairs(lines) do
    f:write(line, "\n")
  end
  f:close()
  return true
end

local function read_all(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

local function log_error(lines)
  ensure_dir(state.logs_dir)
  local path = path_join(state.logs_dir, "error_" .. timestamp() .. ".log")
  if write_lines(path, lines) then
    state.last_error_log = path
  end
end

local function csv_escape(s)
  s = tostring(s or "")
  s = s:gsub('"', '""')
  return '"' .. s .. '"'
end

local function get_take_source_path(take)
  if not take then return nil end
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return nil end
  
  -- If it's a section/reverse source, get the parent source
  local parent_src = reaper.GetMediaSourceParent(src)
  while parent_src do
    src = parent_src
    parent_src = reaper.GetMediaSourceParent(src)
  end
  
  local path = reaper.GetMediaSourceFileName(src, "")
  if path and path ~= "" then
    return path
  end
  return nil
end

local function collect_project_paths()
  local paths_set = {}
  
  -- 1. Timeline items (including all takes)
  local item_count = reaper.CountMediaItems(0)
  for i = 0, item_count - 1 do
    local item = reaper.GetMediaItem(0, i)
    local take_count = reaper.GetMediaItemNumTakes(item)
    for t = 0, take_count - 1 do
      local take = reaper.GetMediaItemTake(item, t)
      local path = get_take_source_path(take)
      if path and is_audio_file(path) then
        paths_set[path] = true
      end
    end
  end

  -- 2. Scan all Media Explorer / Project Bay files via EnumProjects if possible
  -- Actually, the best way to get ALL media in project is to parse the RPP or use GetMediaSourceFileName
  -- But since we are in Lua, let's use a simpler trick: scan the project's default media path
  local proj_dir = get_project_dir()
  if proj_dir and proj_dir ~= "" then
    -- We'll add this to seeds for Mode 2, but for Mode 1 we stay with Timeline + Project Root
    local i = 0
    while true do
      local name = reaper.EnumerateFiles(proj_dir, i)
      if not name then break end
      local full = path_join(proj_dir, name)
      if is_audio_file(full) then
        paths_set[full] = true
      end
      i = i + 1
    end
  end

  local out = {}
  for path in pairs(paths_set) do
    if file_exists(path) then
      out[#out + 1] = path
    end
  end
  table.sort(out)
  return out
end

local function collect_all_audio_recursive(dir, files_set)
  if not dir or dir == "" or not dir_exists(dir) then 
    return 
  end
  
  -- Files in current dir
  local i = 0
  while true do
    local name = reaper.EnumerateFiles(dir, i)
    if not name then break end
    local full = path_join(dir, name)
    if is_audio_file(full) then
      files_set[full] = true
    end
    i = i + 1
  end
  
  -- Subdirectories
  local j = 0
  while true do
    local sub = reaper.EnumerateSubdirectories(dir, j)
    if not sub then break end
    collect_all_audio_recursive(path_join(dir, sub), files_set)
    j = j + 1
  end
end

local function collect_all_accessible_audio_files(seed_paths)
  local files_set = {}
  local scanned_dirs = {}

  -- Also scan project directory if it exists
  local proj_dir = get_project_dir()
  if proj_dir and proj_dir ~= "" and dir_exists(proj_dir) then
    collect_all_audio_recursive(proj_dir, files_set)
    scanned_dirs[proj_dir] = true
  end

  for _, path in ipairs(seed_paths) do
    local dir = ({split_path(path)})[1]
    if dir ~= "" and dir_exists(dir) and not scanned_dirs[dir] then
      collect_all_audio_recursive(dir, files_set)
      scanned_dirs[dir] = true
    end
  end

  local out = {}
  for path in pairs(files_set) do
    out[#out + 1] = path
  end
  table.sort(out)
  return out
end

local function reserve_unique_new_path(dir, base, ext, reserved_paths)
  local function make_name(candidate_base, n)
    if n and n > 0 then
      candidate_base = candidate_base .. "_" .. tostring(n)
    end
    if ext ~= "" then
      return candidate_base .. "." .. ext
    end
    return candidate_base
  end

  local n = 0
  while true do
    local name = make_name(base, n)
    local full = path_join(dir, name)
    local exists_on_disk = file_exists(full)
    local reserved = reserved_paths[full] == true
    if not exists_on_disk and not reserved then
      reserved_paths[full] = true
      return full, name, n
    end
    n = n + 1
  end
end

local function build_plan(paths)
  local plans = {}
  local reserved_new_paths = {}

  for _, old_path in ipairs(paths) do
    local dir, filename = split_path(old_path)
    local base, ext = split_name_ext(filename)

    local p = {
      selected = true,
      visible = true,
      old_path = old_path,
      new_path = old_path,
      dir = dir,
      old_name = filename,
      new_name = filename,
      action = "skip",
      reason = "no_cyrillic",
      suffix_index = 0,
      had_conflict = false
    }

    if has_cyrillic(base) then
      local translit = sanitize_filename(transliterate_utf8(base), state.keep_spaces)
      if translit ~= base then
        local new_path, new_name, suffix_index = reserve_unique_new_path(dir, translit, ext, reserved_new_paths)
        p.new_path = new_path
        p.new_name = new_name
        p.suffix_index = suffix_index
        p.had_conflict = suffix_index > 0
        p.action = "rename"
        p.reason = "ok"
      else
        p.reason = "same_name"
      end
    end

    plans[#plans + 1] = p
  end

  return plans
end

local function plan_status_text(p)
  if p.action ~= "rename" then
    return "skip: " .. tostring(p.reason)
  end
  if p.had_conflict then
    return "rename + suffix"
  end
  return "rename"
end

local function apply_filter()
  local f = (state.filter_text or ""):lower()
  for _, p in ipairs(state.plans) do
    local ok_text = true
    local ok_conflict = true

    if f ~= "" then
      local s = (p.old_name .. " " .. p.new_name .. " " .. p.old_path):lower()
      ok_text = s:find(f, 1, true) ~= nil
    end

    if state.filter_conflicts_only then
      ok_conflict = p.had_conflict == true
    end

    p.visible = ok_text and ok_conflict
  end
end

local function sort_plans()
  table.sort(state.plans, function(a, b)
    local va, vb
    if state.sort_column == SORT_OLD then
      va, vb = a.old_name:lower(), b.old_name:lower()
    elseif state.sort_column == SORT_NEW then
      va, vb = a.new_name:lower(), b.new_name:lower()
    elseif state.sort_column == SORT_DIR then
      va, vb = a.dir:lower(), b.dir:lower()
    else
      va, vb = plan_status_text(a):lower(), plan_status_text(b):lower()
    end

    if va == vb then
      va, vb = a.old_path:lower(), b.old_path:lower()
    end

    if state.sort_asc then return va < vb end
    return va > vb
  end)
end

local function scan_files()
  local project_paths = collect_project_paths()
  
  if #project_paths == 0 and state.mode == 1 then
    state.plans = {}
    state.status = "No accessible audio files found"
    return
  end

  local target_paths
  if state.mode == 1 then
    target_paths = project_paths
  else
    target_paths = collect_all_accessible_audio_files(project_paths)
  end

  state.plans = build_plan(target_paths)
  
  local candidates = 0
  for _, p in ipairs(state.plans) do
    if p.action == "rename" then candidates = candidates + 1 end
  end
  
  apply_filter()
  sort_plans()
  state.status = "Scanned: " .. tostring(#state.plans) .. " files (" .. candidates .. " candidates)"
end

local function count_stats()
  local total, visible, candidates, selected, conflicts = 0, 0, 0, 0, 0
  for _, p in ipairs(state.plans) do
    total = total + 1
    if p.visible then visible = visible + 1 end
    if p.action == "rename" then
      candidates = candidates + 1
      if p.selected then selected = selected + 1 end
      if p.had_conflict then conflicts = conflicts + 1 end
    end
  end
  return total, visible, candidates, selected, conflicts
end

local function select_all(flag)
  for _, p in ipairs(state.plans) do
    if p.action == "rename" then p.selected = flag end
  end
end

local function select_visible(flag)
  for _, p in ipairs(state.plans) do
    if p.action == "rename" and p.visible then p.selected = flag end
  end
end

local function open_folder(path)
  local dir = ({split_path(path)})[1]
  if dir == "" then return end
  if os_is_windows() then
    os.execute('start "" "' .. dir .. '"')
  else
    os.execute('open "' .. dir .. '" >/dev/null 2>/dev/null || xdg-open "' .. dir .. '" >/dev/null 2>/dev/null')
  end
end

local function retarget_project_references(map_old_to_new)
  local item_count = reaper.CountMediaItems(0)
  local updated_count = 0

  for i = 0, item_count - 1 do
    local item = reaper.GetMediaItem(0, i)
    local take_count = reaper.CountTakes(item)
    for t = 0, take_count - 1 do
      local take = reaper.GetTake(item, t)
      if take and reaper.TakeIsMIDI(take) == false then
        local current_path = get_take_source_path(take)
        local new_path = current_path and map_old_to_new[current_path] or nil
        if new_path and file_exists(new_path) then
          local new_src = reaper.PCM_Source_CreateFromFile(new_path)
          if new_src then
            reaper.SetMediaItemTake_Source(take, new_src)
            updated_count = updated_count + 1
          end
        end
      end
    end
  end
  
  reaper.UpdateArrange()
  reaper.UpdateTimeline()
  
  return updated_count
end

local function save_batch_history(entries, meta)
  ensure_dir(state.history_dir)
  local path = path_join(state.history_dir, "batch_" .. timestamp() .. ".txt")

  local lines = {
    "BATCH|" .. escape_field(meta.time or ""),
    "MODE|" .. escape_field(meta.mode or ""),
    "COUNT|" .. tostring(#entries)
  }

  for _, e in ipairs(entries) do
    lines[#lines + 1] = "MAP|" .. escape_field(e.old_path) .. "|" .. escape_field(e.new_path)
  end

  return write_lines(path, lines), path
end

local function parse_batch_file(path)
  local content = read_all(path)
  if not content then return nil end

  local batch = {
    path = path,
    title = ({split_path(path)})[2],
    entries = {},
    renamed = 0,
    meta = {}
  }

  for line in content:gmatch("[^\r\n]+") do
    local tag, a, b = line:match("^([^|]+)|([^|]*)|?(.*)$")
    if tag == "BATCH" then
      batch.meta.time = unescape_field(a)
    elseif tag == "MODE" then
      batch.meta.mode = unescape_field(a)
    elseif tag == "MAP" then
      local oldp = unescape_field(a)
      local newp = unescape_field(b)
      batch.entries[#batch.entries + 1] = {
        old_path = oldp,
        new_path = newp,
        selected = false
      }
      batch.renamed = batch.renamed + 1
    end
  end

  return batch
end

local function load_history()
  state.history = {}
  ensure_dir(state.history_dir)

  local i = 0
  while true do
    local name = reaper.EnumerateFiles(state.history_dir, i)
    if not name then break end
    if name:lower():match("%.txt$") then
      local full = path_join(state.history_dir, name)
      local batch = parse_batch_file(full)
      if batch and batch.renamed > 0 then
        state.history[#state.history + 1] = batch
      end
    end
    i = i + 1
  end

  table.sort(state.history, function(a, b) return a.title > b.title end)

  if #state.history == 0 then
    state.selected_batch_index = 0
  else
    if state.selected_batch_index < 1 then state.selected_batch_index = 1 end
    if state.selected_batch_index > #state.history then state.selected_batch_index = #state.history end
  end
end

local function export_csv()
  ensure_dir(state.export_dir)
  local path = path_join(state.export_dir, "translit_plan_" .. timestamp() .. ".csv")
  local lines = {
    table.concat({
      csv_escape("selected"),
      csv_escape("old_name"),
      csv_escape("new_name"),
      csv_escape("folder"),
      csv_escape("old_path"),
      csv_escape("new_path"),
      csv_escape("status"),
      csv_escape("conflict")
    }, ",")
  }

  for _, p in ipairs(state.plans) do
    lines[#lines + 1] = table.concat({
      csv_escape(p.selected and "1" or "0"),
      csv_escape(p.old_name),
      csv_escape(p.new_name),
      csv_escape(p.dir),
      csv_escape(p.old_path),
      csv_escape(p.new_path),
      csv_escape(plan_status_text(p)),
      csv_escape(p.had_conflict and "1" or "0")
    }, ",")
  end

  if write_lines(path, lines) then
    state.status = "CSV exported: " .. path
  else
    state.status = "CSV export failed"
  end
end

local function build_preview_text()
  local lines = {}
  local count = 0
  lines[#lines + 1] = state.dry_run and "Dry-run preview" or "Rename preview"
  lines[#lines + 1] = ""

  for _, p in ipairs(state.plans) do
    if p.action == "rename" and p.selected then
      count = count + 1
      lines[#lines + 1] = tostring(count) .. ") " .. p.old_name .. " -> " .. p.new_name
      if count >= 30 then
        lines[#lines + 1] = "..."
        break
      end
    end
  end

  if count == 0 then
    lines[#lines + 1] = "No selected items."
  end

  return table.concat(lines, "\n")
end

local function do_rename_selected()
  local selected = {}
  for _, p in ipairs(state.plans) do
    if p.action == "rename" and p.selected then
      selected[#selected + 1] = p
    end
  end

  if #selected == 0 then
    state.status = "Nothing selected for rename"
    return
  end

  if state.dry_run then
    state.status = "Dry-run complete. Planned: " .. tostring(#selected)
    return
  end

  local rename_map = {}
  local history_entries = {}
  local errors = {}
  local renamed = 0

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for _, p in ipairs(selected) do
    if file_exists(p.old_path) then
      if not file_exists(p.new_path) then
        local ok, err = rename_file(p.old_path, p.new_path)
        if ok then
          renamed = renamed + 1
          rename_map[p.old_path] = p.new_path
          history_entries[#history_entries + 1] = {
            old_path = p.old_path,
            new_path = p.new_path
          }
        else
          errors[#errors + 1] = "RENAME_FAIL|" .. p.old_path .. "|" .. tostring(err)
        end
      else
        errors[#errors + 1] = "TARGET_EXISTS|" .. p.new_path
      end
    else
      errors[#errors + 1] = "SOURCE_MISSING|" .. p.old_path
    end
  end

  if next(rename_map) ~= nil then
    retarget_project_references(rename_map)
    reaper.UpdateArrange()
  end

  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Production translit rename selected files", -1)

  if #history_entries > 0 then
    local ok, hist_path = save_batch_history(history_entries, {
      time = os.date("%Y-%m-%d %H:%M:%S"),
      mode = tostring(state.mode)
    })
    if ok then
      load_history()
    end
  end

  if #errors > 0 then
    log_error(errors)
  end

  state.status = "Renamed: " .. tostring(renamed) .. ", errors: " .. tostring(#errors)
  scan_files()
end

local function get_selected_batch()
  if state.selected_batch_index < 1 then return nil end
  return state.history[state.selected_batch_index]
end

local function history_select_all(flag)
  local batch = get_selected_batch()
  if not batch then return end
  for _, e in ipairs(batch.entries) do
    e.selected = flag
  end
end

local function undo_selected_entries()
  local batch = get_selected_batch()
  if not batch then
    state.status = "No batch selected"
    return
  end

  local reverse_map = {}
  local errors = {}
  local undone = 0

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for i = #batch.entries, 1, -1 do
    local e = batch.entries[i]
    if e.selected then
      if file_exists(e.new_path) and not file_exists(e.old_path) then
        local ok, err = rename_file(e.new_path, e.old_path)
        if ok then
          undone = undone + 1
          reverse_map[e.new_path] = e.old_path
        else
          errors[#errors + 1] = "UNDO_FAIL|" .. e.new_path .. "|" .. tostring(err)
        end
      else
        if not file_exists(e.new_path) then
          errors[#errors + 1] = "UNDO_SOURCE_MISSING|" .. e.new_path
        else
          errors[#errors + 1] = "UNDO_TARGET_EXISTS|" .. e.old_path
        end
      end
    end
  end

  if next(reverse_map) ~= nil then
    retarget_project_references(reverse_map)
    reaper.UpdateArrange()
  end

  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Production translit undo selected entries", -1)

  if #errors > 0 then
    log_error(errors)
  end

  state.status = "Undo complete: " .. tostring(undone) .. ", errors: " .. tostring(#errors)
  load_history()
  scan_files()
end

local function clear_history()
  ensure_dir(state.history_dir)
  local to_delete = {}
  local i = 0
  while true do
    local name = reaper.EnumerateFiles(state.history_dir, i)
    if not name then break end
    if name:lower():match("%.txt$") then
      to_delete[#to_delete + 1] = path_join(state.history_dir, name)
    end
    i = i + 1
  end

  for _, path in ipairs(to_delete) do
    os.remove(path)
  end

  load_history()
  state.status = "History cleared"
end

-- Собирает все items в проекте, чьи takes имеют source-путь совпадающий с old_path из selected_plans.
-- Сохраняет текущее выделение, выделяет нужные items и переключает их в offline/online через команду SWS.
-- Возвращает таблицу affected items и сохраненное выделение для восстановления.
local function set_items_offline(selected_plans, offline_flag)
  local old_paths = {}
  for _, p in ipairs(selected_plans) do
    if p.action == "rename" then
      old_paths[p.old_path] = true
    end
  end
  
  -- Сохраняем текущее выделение
  local saved_selection = {}
  local sel_count = reaper.CountSelectedMediaItems(0)
  for i = 0, sel_count - 1 do
    saved_selection[#saved_selection + 1] = reaper.GetSelectedMediaItem(0, i)
  end
  
  -- Снимаем выделение со всех items
  reaper.SelectAllMediaItems(0, false)
  
  local affected_items = {}
  local item_count = reaper.CountMediaItems(0)
  
  for i = 0, item_count - 1 do
    local item = reaper.GetMediaItem(0, i)
    local take_count = reaper.CountTakes(item)
    local item_has_target = false
    
    for t = 0, take_count - 1 do
      local take = reaper.GetTake(item, t)
      local path = get_take_source_path(take)
      if path and old_paths[path] then
        item_has_target = true
        break
      end
    end
    
    if item_has_target then
      reaper.SetMediaItemSelected(item, true)
      affected_items[#affected_items + 1] = item
    end
  end
  
  -- Переключаем выбранные items через команду SWS
  if #affected_items > 0 then
    local cmd_id = reaper.NamedCommandLookup("_BR_TOGGLE_ITEM_ONLINE")
    if cmd_id > 0 then
      reaper.Main_OnCommand(cmd_id, 0)
    end
  end
  
  reaper.UpdateArrange()
  return affected_items, saved_selection
end

-- Асинхронный конечный автомат для offline -> wait -> rename -> wait -> online -> update paths.
-- Вызывается через reaper.defer на каждом шаге.
-- Шаги:
--   0: offline (set items offline via SWS)
--   1..10: wait (пауза ~10 * 30мс = ~300мс)
--   11: rename (физическое переименование файлов)
--   12..14: wait after rename (пауза ~3 * 30мс = ~90мс)
--   15: online (set items online via SWS)
--   16..18: wait after online (пауза ~3 * 30мс = ~90мс)
--   19: update paths (обновление путей в проекте)
--   20: done (финализация)
local function rename_defer_step()
  local rd = state.rename_data
  if not rd or rd.step < 0 then
    return
  end

  -- Шаг 0: Offline
  if rd.step == 0 then
    state.status = "Шаг 1/7: Переключение items в офлайн..."
    local affected, saved_sel = set_items_offline(rd.selected, true)
    rd.affected_items = affected
    rd.saved_selection = saved_sel
    rd.wait_count = 0
    rd.step = 1
    reaper.defer(rename_defer_step)
    return
  end

  -- Шаги 1-10: Ожидание освобождения файлов (~10 * 30мс = 300мс)
  if rd.step >= 1 and rd.step <= 10 then
    rd.wait_count = rd.wait_count + 1
    state.status = "Шаг 2/7: Ожидание освобождения файлов (" .. tostring(rd.wait_count*30) .. " мс)..."
    if rd.wait_count >= 10 then
      rd.step = 11
      rd.wait_count = 0
    else
      rd.step = rd.step + 1
    end
    reaper.defer(rename_defer_step)
    return
  end

  -- Шаг 11: Rename
  if rd.step == 11 then
    state.status = "Шаг 3/7: Переименование файлов..."
    
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    for _, p in ipairs(rd.selected) do
      if p.action == "rename" then
        if file_exists(p.old_path) then
          if not file_exists(p.new_path) then
            local ok, err = rename_file(p.old_path, p.new_path)
            if ok then
              rd.renamed = rd.renamed + 1
              rd.rename_map[p.old_path] = p.new_path
              rd.history_entries[#rd.history_entries + 1] = {
                old_path = p.old_path,
                new_path = p.new_path
              }
            else
              rd.errors[#rd.errors + 1] = "RENAME_FAIL|" .. p.old_path .. "|" .. tostring(err)
            end
          else
            rd.errors[#rd.errors + 1] = "TARGET_EXISTS|" .. p.new_path
          end
        else
          rd.errors[#rd.errors + 1] = "SOURCE_MISSING|" .. p.old_path
        end
      end
    end

    rd.step = 12
    reaper.defer(rename_defer_step)
    return
  end

  -- Шаги 12-14: Ожидание после переименования (~3 * 30мс = 90мс)
  if rd.step >= 12 and rd.step <= 14 then
    rd.wait_count = rd.wait_count + 1
    state.status = "Шаг 4/7: Ожидание после переименования (" .. tostring(rd.wait_count*30) .. " мс)..."
    if rd.wait_count >= 3 then
      rd.step = 15
      rd.wait_count = 0
    else
      rd.step = rd.step + 1
    end
    reaper.defer(rename_defer_step)
    return
  end

  -- Шаг 15: Online
  if rd.step == 15 then
    state.status = "Шаг 5/7: Возврат items в онлайн..."
    
    -- Снимаем выделение со всех items
    reaper.SelectAllMediaItems(0, false)
    
    -- Выделяем только affected items
    for _, item in ipairs(rd.affected_items) do
      reaper.SetMediaItemSelected(item, true)
    end
    
    -- Переключаем обратно в online через команду SWS
    if #rd.affected_items > 0 then
      local cmd_id = reaper.NamedCommandLookup("_BR_TOGGLE_ITEM_ONLINE")
      if cmd_id > 0 then
        reaper.Main_OnCommand(cmd_id, 0)
      end
    end
    
    -- Восстанавливаем исходное выделение
    reaper.SelectAllMediaItems(0, false)
    if rd.saved_selection then
      for _, item in ipairs(rd.saved_selection) do
        if reaper.ValidatePtr(item, "MediaItem*") then
          reaper.SetMediaItemSelected(item, true)
        end
      end
    end

    reaper.UpdateArrange()
    
    rd.step = 16
    reaper.defer(rename_defer_step)
    return
  end

  -- Шаги 16-18: Ожидание после возврата в online (~3 * 30мс = 90мс)
  if rd.step >= 16 and rd.step <= 18 then
    rd.wait_count = rd.wait_count + 1
    state.status = "Шаг 6/7: Ожидание стабилизации (" .. tostring(rd.wait_count*30) .. " мс)..."
    if rd.wait_count >= 3 then
      rd.step = 19
    else
      rd.step = rd.step + 1
    end
    reaper.defer(rename_defer_step)
    return
  end

  -- Шаг 19: Update paths
  if rd.step == 19 then
    state.status = "Шаг 7/7: Обновление путей в проекте..."
    
    if next(rd.rename_map) ~= nil then
      local updated = retarget_project_references(rd.rename_map)
      state.status = "Шаг 7/7: Обновлено путей: " .. tostring(updated)
    end
    
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Translit: offline rename online selected files", -1)

    rd.step = 20
    reaper.defer(rename_defer_step)
    return
  end

  -- Шаг 20: Done
  if rd.step == 20 then
    state.status = "Шаг 7/7: Финализация..."
    
    if #rd.history_entries > 0 then
      local ok, hist_path = save_batch_history(rd.history_entries, {
        time = os.date("%Y-%m-%d %H:%M:%S"),
        mode = tostring(state.mode)
      })
      if ok then
        load_history()
      end
    end

    if #rd.errors > 0 then
      log_error(rd.errors)
    end

    state.status = "Готово: переименовано " .. tostring(rd.renamed) .. ", ошибок: " .. tostring(#rd.errors)
    
    -- Сброс rename_data
    rd.step = 0
    rd.wait_count = 0
    rd.selected = {}
    rd.affected_items = {}
    rd.saved_selection = {}
    rd.rename_map = {}
    rd.history_entries = {}
    rd.errors = {}
    rd.renamed = 0

    scan_files()
    return
  end
end

local function draw_preview_popup()
  if state.show_preview_popup then
    reaper.ImGui_OpenPopup(ctx, "Preview")
    state.show_preview_popup = false
  end

  if reaper.ImGui_BeginPopupModal(ctx, "Preview", true) then
    reaper.ImGui_TextWrapped(ctx, state.preview_text)
    if reaper.ImGui_Button(ctx, state.dry_run and "Run dry-run" or "Confirm rename") then
      if state.pending_action == "rename" then
        if state.dry_run then
          do_rename_selected()
        else
          -- Асинхронный процесс offline -> wait -> rename -> online
          local selected = {}
          for _, p in ipairs(state.plans) do
            if p.action == "rename" and p.selected then
              selected[#selected + 1] = p
            end
          end
          if #selected == 0 then
            state.status = "Nothing selected for rename"
          else
            state.rename_data.selected = selected
            state.rename_data.step = 0
            state.rename_data.wait_count = 0
            state.rename_data.affected_items = {}
            state.rename_data.saved_selection = {}
            state.rename_data.rename_map = {}
            state.rename_data.history_entries = {}
            state.rename_data.errors = {}
            state.rename_data.renamed = 0
            reaper.defer(rename_defer_step)
          end
        end
      end
      state.pending_action = nil
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Cancel") then
      state.pending_action = nil
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_EndPopup(ctx)
  end
end

local function draw_top_controls()
  reaper.ImGui_Text(ctx, "Project path: " .. (state.project_dir or "Not saved"))
  if reaper.ImGui_Button(ctx, "Open project folder") then
    open_folder(state.project_dir .. PATH_SEP)
  end
  reaper.ImGui_Separator(ctx)

  reaper.ImGui_Text(ctx, "Scan mode")
  local rv
  rv, state.mode = reaper.ImGui_RadioButtonEx(ctx, "Only files used in current project", state.mode, 1)
  rv, state.mode = reaper.ImGui_RadioButtonEx(ctx, "All accessible audio files in discovered folders", state.mode, 2)

  if reaper.ImGui_Button(ctx, "Scan") then scan_files() end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Select all") then select_all(true) end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Select none") then select_all(false) end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Select visible") then select_visible(true) end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Unselect visible") then select_visible(false) end

  reaper.ImGui_SameLine(ctx)
  rv, state.dry_run = reaper.ImGui_Checkbox(ctx, "Dry-run", state.dry_run)

  if reaper.ImGui_Button(ctx, "Preview / Run selected") then
    state.preview_text = build_preview_text()
    state.pending_action = "rename"
    state.show_preview_popup = true
  end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Export CSV") then export_csv() end

  rv, state.filter_text = reaper.ImGui_InputText(ctx, "Filter", state.filter_text)
  if rv then
    apply_filter()
    sort_plans()
  end

  rv, state.filter_conflicts_only = reaper.ImGui_Checkbox(ctx, "Only conflicts", state.filter_conflicts_only)
  if rv then
    apply_filter()
    sort_plans()
  end

  rv, state.keep_spaces = reaper.ImGui_Checkbox(ctx, "Keep spaces in filenames", state.keep_spaces)
  if rv then
    scan_files()
  end
end

local function draw_stats()
  local total, visible, candidates, selected, conflicts = count_stats()
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Text(ctx, "Total: " .. tostring(total))
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_Text(ctx, "Visible: " .. tostring(visible))
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_Text(ctx, "Candidates: " .. tostring(candidates))
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_Text(ctx, "Selected: " .. tostring(selected))
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_Text(ctx, "Conflicts: " .. tostring(conflicts))
  reaper.ImGui_Text(ctx, "Status: " .. tostring(state.status))
  if state.last_error_log then
    reaper.ImGui_Text(ctx, "Last error log: " .. state.last_error_log)
  end
  reaper.ImGui_Separator(ctx)
end

local function draw_sort_buttons()
  if reaper.ImGui_Button(ctx, "Sort old") then
    if state.sort_column == SORT_OLD then state.sort_asc = not state.sort_asc else state.sort_column, state.sort_asc = SORT_OLD, true end
    sort_plans()
  end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Sort new") then
    if state.sort_column == SORT_NEW then state.sort_asc = not state.sort_asc else state.sort_column, state.sort_asc = SORT_NEW, true end
    sort_plans()
  end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Sort folder") then
    if state.sort_column == SORT_DIR then state.sort_asc = not state.sort_asc else state.sort_column, state.sort_asc = SORT_DIR, true end
    sort_plans()
  end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Sort status") then
    if state.sort_column == SORT_STATUS then state.sort_asc = not state.sort_asc else state.sort_column, state.sort_asc = SORT_STATUS, true end
    sort_plans()
  end
end

local function draw_table()
  draw_sort_buttons()

  local flags = reaper.ImGui_TableFlags_RowBg()
    | reaper.ImGui_TableFlags_Borders()
    | reaper.ImGui_TableFlags_Resizable()
    | reaper.ImGui_TableFlags_ScrollY()

  if reaper.ImGui_BeginTable(ctx, "files_table", 6, flags, -1, 320) then
    reaper.ImGui_TableSetupColumn(ctx, "Sel")
    reaper.ImGui_TableSetupColumn(ctx, "Old name")
    reaper.ImGui_TableSetupColumn(ctx, "New name")
    reaper.ImGui_TableSetupColumn(ctx, "Folder")
    reaper.ImGui_TableSetupColumn(ctx, "Status")
    reaper.ImGui_TableSetupColumn(ctx, "Action")
    reaper.ImGui_TableHeadersRow(ctx)

    for i, p in ipairs(state.plans) do
      if p.visible then
        reaper.ImGui_TableNextRow(ctx)

        local is_grey = p.action ~= "rename"
        if is_grey then
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x888888FF)
        end

        reaper.ImGui_TableSetColumnIndex(ctx, 0)
        if p.action == "rename" then
          local rv
          rv, p.selected = reaper.ImGui_Checkbox(ctx, "##sel" .. i, p.selected)
        else
          reaper.ImGui_Text(ctx, "-")
        end

        reaper.ImGui_TableSetColumnIndex(ctx, 1)
        reaper.ImGui_Text(ctx, p.old_name)

        reaper.ImGui_TableSetColumnIndex(ctx, 2)
        if p.had_conflict then
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x55AAFFFF)
          reaper.ImGui_Text(ctx, p.new_name)
          reaper.ImGui_PopStyleColor(ctx)
        else
          reaper.ImGui_Text(ctx, p.new_name)
        end

        reaper.ImGui_TableSetColumnIndex(ctx, 3)
        reaper.ImGui_Text(ctx, p.dir)

        reaper.ImGui_TableSetColumnIndex(ctx, 4)
        local status_text = plan_status_text(p)
        reaper.ImGui_Text(ctx, status_text)

        reaper.ImGui_TableSetColumnIndex(ctx, 5)
        if reaper.ImGui_Button(ctx, "Open##" .. i) then
          open_folder(p.old_path)
        end

        if is_grey then
          reaper.ImGui_PopStyleColor(ctx)
        end
      end
    end

    reaper.ImGui_EndTable(ctx)
  end
end

local function draw_history()
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Text(ctx, "Rename history")

  if reaper.ImGui_Button(ctx, "Reload history") then load_history() end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Clear history") then
    local answer = reaper.ShowMessageBox("Clear history?", "Confirm", 1)
    if answer == 1 then clear_history() end
  end

  if #state.history == 0 then
    reaper.ImGui_Text(ctx, "No history yet")
    return
  end

  for i, batch in ipairs(state.history) do
    local label = batch.title .. " (" .. tostring(batch.renamed) .. ")"
    local rv
    rv, state.selected_batch_index = reaper.ImGui_RadioButtonEx(ctx, label, state.selected_batch_index, i)
  end

  local batch = get_selected_batch()
  if not batch then return end

  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Text(ctx, "Selected batch: " .. batch.path)

  if reaper.ImGui_Button(ctx, "Select all entries") then history_select_all(true) end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Select no entries") then history_select_all(false) end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Undo selected entries") then
    local answer = reaper.ShowMessageBox("Undo selected entries?", "Confirm", 1)
    if answer == 1 then undo_selected_entries() end
  end

  if reaper.ImGui_BeginChild(ctx, "history_entries", -1, 180, reaper.ImGui_WindowFlags_None()) then
    for i, e in ipairs(batch.entries) do
      reaper.ImGui_PushID(ctx, 100000 + i)
      local rv
      rv, e.selected = reaper.ImGui_Checkbox(ctx, "##hist" .. i, e.selected)
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_Text(ctx, ({split_path(e.old_path)})[2] .. " <- " .. ({split_path(e.new_path)})[2])
      reaper.ImGui_PopID(ctx)
    end
    reaper.ImGui_EndChild(ctx)
  end
end

local function draw_gui()
  local visible, open = reaper.ImGui_Begin(ctx, SCRIPT_NAME, true)
  if visible then
    draw_top_controls()
    draw_stats()
    draw_table()
    draw_history()
    draw_preview_popup()
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(draw_gui)
  else
    -- ReaImGui context is automatically destroyed in modern versions 
    -- or manually via reaper.ImGui_DestroyContext if available
    if reaper.ImGui_DestroyContext then
      reaper.ImGui_DestroyContext(ctx)
    end
  end
end

local function init()
  state.project_dir = get_project_dir()
  state.history_dir = path_join(state.project_dir, "translit_history")
  state.export_dir = path_join(state.project_dir, "translit_export")
  state.logs_dir = path_join(state.project_dir, "translit_logs")

  ensure_dir(state.history_dir)
  ensure_dir(state.export_dir)
  ensure_dir(state.logs_dir)

  load_history()
  scan_files()
end

init()
draw_gui()