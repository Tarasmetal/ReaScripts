-- @description Playback Playlist: project region playlists (ReaImGui)
-- @author Taras Umanskiy
-- @version 1.27
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://vk.com/Tarasmetal
-- @about Requires ReaImGui. Playlists are stored in PlaybackList beside the project file.
-- @changelog
--   v.1.27 + Переход запускается за 1/8 длительности региона, чтобы smooth seek успевал до конца.
--   v.1.26 + Переход подготавливается за одну восьмую ноту до конца региона.
--   v.1.25 + Чекбокс непрерывного воспроизведения перенесён вправо от кнопки >>>.
--   v.1.24 + Красная кнопка Stop «s» снова сразу справа от >> у играющего региона.
--   v.1.23 + Кнопка Stop «s» справа от длительности; под Total duration кнопки плеера <<<, Play, Pause, >>>.
--   v.1.22 + Красная кнопка Stop «s» показывается справа от >> у играющего региона.
--   v.1.21 + Длительность регионов отображается серым цветом справа от названия.
--   v.1.20 + Показаны длительности регионов и общая длительность выбранного плейлиста с учётом повторов.
--   v.1.19 + Подпись «Play consecutively» перенесена во всплывающую подсказку чекбокса.
--   v.1.18 + Смежные регионы играют непрерывно, повтор перехода выполняется на ходу.
--   v.1.17 + Исправлено подтверждение переходов между регионами, включая повторы и переходы назад.
--   v.1.16 + Переход к следующему региону, когда остаётся 1/4 длительности текущего.
--   v.1.15 + Переход к следующему региону, когда остаётся 1/8 длительности текущего.
--   v.1.14 + Убрана стрелка перед названием играющего региона.
--   v.1.13 + Жёлтая кнопка играющего региона показывает >>.
--   v.1.12 + Кнопка играющего региона подсвечивается жёлтым, символ на ней чёрный.
--   v.1.11 + Подсветка сохраняется при переходе между регионами без остановки воспроизведения.
--   v.1.10 + Название играющего региона в плейлисте подсвечивается жёлтым.
--   v.1.9 + Убраны видимые ID регионов из плейлиста и панели Project regions.
--   v.1.8 + Файлы playlist_<Name>.txt; безопасное переименование и миграция числовых файлов.
--   v.1.7 + Исправлено переключение на первый плейлист при переименовании выбранной вкладки.
--   v.1.6 + Поле Name уменьшено на треть; каждый плейлист хранится в отдельном файле, старый формат переносится автоматически.
--   v.1.5 + Кнопка Project regions открывает и закрывает боковое окно регионов слева от плейлиста.


local version = 1.27

local r = reaper
if not r.ImGui_CreateContext then
  r.MB('Install ReaImGui via ReaPack to run Playback Playlist.', 'Playback Playlist', 0)
  return
end

local ctx = r.ImGui_CreateContext('Playback Playlist ' .. version .. '')
local playlists = {}
local selected = 1
local playing = false
local playing_playlist
local paused = false
local single_region = false
local play_consecutively = false
local step = 0
local target_start, target_end, expected_end
local seek_requested_at, seek_from, seek_retried
local project = r.EnumProjects(-1, '')
local _, project_file = r.EnumProjects(-1, '')
local last_position
local storage_error
local show_regions = false
local next_playlist_id = 1
local name_drafts = {}
local editing_name_id
local select_new_tab_id

local function storage_path()
  local _, filename = r.EnumProjects(-1, '')
  if not filename or filename == '' then return nil end
  local directory = filename:match('^(.*)[/\\][^/\\]+$')
  if not directory then return nil end
  local separator = r.GetOS():match('Win') and '\\' or '/'
  return directory .. separator .. 'PlaybackList', separator
end

local function encode(value)
  return (tostring(value):gsub('([^%w%-_%.])', function(c)
    return string.format('%%%02X', c:byte())
  end))
end

local function decode(value)
  return (value:gsub('%%(%x%x)', function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

local function regions()
  local result = {}
  local _, markers, count = r.CountProjectMarkers(0)
  for i = 0, markers + count - 1 do
    local ok, is_region, start_pos, end_pos, name, id = r.EnumProjectMarkers3(0, i)
    if ok and is_region then
      result[#result + 1] = { id = id, start_pos = start_pos, end_pos = end_pos, name = name }
    end
  end
  table.sort(result, function(a, b) return a.start_pos < b.start_pos end)
  return result
end

local function find_region(id, list)
  for _, region in ipairs(list) do
    if region.id == id then return region end
  end
end

local function region_duration(region)
  return math.max(0, region.end_pos - region.start_pos)
end

local function format_duration(seconds)
  local milliseconds = math.floor(seconds * 1000 + 0.5)
  local hours = milliseconds // 3600000
  local minutes = milliseconds // 60000 % 60
  local time = string.format('%02d:%02d.%03d', minutes, milliseconds // 1000 % 60, milliseconds % 1000)
  if hours > 0 then return string.format('%02d:', hours) .. time end
  return time
end

local function safe_name(name)
  local value = name:gsub('[<>:"/\\|%?%*%c]', '_'):gsub('[%. ]+$', '')
  if value == '' then return nil end
  return value
end

local function playlist_file(directory, separator, filename)
  return directory .. separator .. filename
end

local function filename_for(name)
  local safe = safe_name(name)
  return safe and ('playlist_' .. safe .. '.txt') or nil
end

local function filename_taken(filename, except)
  for _, item in ipairs(playlists) do
    if item ~= except and item.filename:lower() == filename:lower() then return true end
  end
  return false
end

local function save()
  local directory, separator = storage_path()
  if not directory then
    storage_error = 'Save the REAPER project before editing playlists.'
    return false
  end
  r.RecursiveCreateDirectory(directory, 0)
  for _, playlist in ipairs(playlists) do
    local path = playlist_file(directory, separator, playlist.filename)
    local file, err = io.open(path, 'wb')
    if not file then storage_error = err; return false end
    local ok, write_err = file:write('1\n', encode(playlist.name), '\n', table.concat(playlist.items, ','), '\n')
    local closed, close_err = file:close()
    if not ok or not closed then
      storage_error = write_err or close_err
      return false
    end
  end
  storage_error = nil
  return true
end

local function parse_items(ids)
  local items = {}
  for id in ids:gmatch('[^,]+') do
    local number = tonumber(id)
    if number then items[#items + 1] = number end
  end
  return items
end

local function load_legacy(data)
  local lines = {}
  for line in (data .. '\n'):gmatch('(.-)\n') do lines[#lines + 1] = line end
  if lines[1] ~= '1' then return end
  local count = tonumber(lines[2]) or 0
  for i = 1, count do
    local name, ids = (lines[i + 2] or ''):match('^(.-)\t(.*)$')
    if name then
      local title = decode(name)
      local filename = filename_for(title)
      if not filename or filename_taken(filename) then
        storage_error = 'Duplicate or invalid playlist name: ' .. title
        return false
      end
      playlists[#playlists + 1] = { id = next_playlist_id, filename = filename, name = title, items = parse_items(ids) }
      next_playlist_id = next_playlist_id + 1
    end
  end
  return true
end

local function load()
  playlists = {}
  next_playlist_id = 1
  storage_error = nil
  local directory, separator = storage_path()
  if not directory then return end
  local legacy_path = directory .. separator .. 'playlists.txt'
  local legacy = io.open(legacy_path, 'rb')
  if legacy then
    local index = 0
    while true do
      local filename = r.EnumerateFiles(directory, index)
      if not filename then break end
      if filename:match('^playlist_.+%.txt$') then legacy:close(); legacy = nil; break end
      index = index + 1
    end
  end
  if legacy then
    local data = legacy:read('*a')
    legacy:close()
    if not load_legacy(data) then
      storage_error = 'Invalid playlists.txt; migration skipped.'
      return
    end
    if save() then
      local archived, err = os.rename(legacy_path, directory .. separator .. 'playlists.txt.migrated')
      if not archived then storage_error = 'Cannot archive playlists.txt: ' .. tostring(err) end
    end
    return
  end
  local index = 0
  while true do
    local filename = r.EnumerateFiles(directory, index)
    if not filename then break end
    if filename:match('^playlist_.+%.txt$') then
      local file = io.open(directory .. separator .. filename, 'rb')
      if file then
        local version, name, ids = file:read('*l', '*l', '*l')
        file:close()
        if version == '1' and name and ids then
          playlists[#playlists + 1] = { id = next_playlist_id, filename = filename, name = decode(name), items = parse_items(ids) }
          next_playlist_id = next_playlist_id + 1
        end
      end
    end
    index = index + 1
  end
  table.sort(playlists, function(a, b) return a.filename:lower() < b.filename:lower() end)
  for _, playlist in ipairs(playlists) do
    if playlist.filename:match('^playlist_%d+%.txt$') then
      local filename = filename_for(playlist.name)
      if filename and not filename_taken(filename, playlist) then
        local old = playlist_file(directory, separator, playlist.filename)
        local new = playlist_file(directory, separator, filename)
        local existing = io.open(new, 'rb')
        if existing then existing:close() else
          local renamed = os.rename(old, new)
          if renamed then playlist.filename = filename end
        end
      end
    end
  end
end

local function stop_playlist(stop_transport)
  playing = false
  playing_playlist = nil
  paused = false
  single_region = false
  step = 0
  expected_end = nil
  seek_requested_at = nil
  seek_from = nil
  seek_retried = false
  last_position = nil
  if stop_transport then r.OnStopButton() end
end

local function seek_to_region_start()
  local transport_playing = r.GetPlayState() & 1 ~= 0
  seek_from = transport_playing and r.GetPlayPosition2() or nil
  seek_requested_at = r.time_precise()
  r.SetEditCurPos2(0, target_start, false, true)
  if not transport_playing then r.OnPlayButton() end
end

local function start_region(index, region, playlist, play_single)
  step = index
  target_start, target_end = region.start_pos, region.end_pos
  last_position = nil
  seek_retried = false
  single_region = play_single
  playing_playlist = playlist
  playing = true
  paused = false
  seek_to_region_start()
end

local function find_playable_step(index, playlist)
  local list = regions()
  while playlist and index <= #playlist.items do
    local region = find_region(playlist.items[index], list)
    if region and region.end_pos > region.start_pos then
      return index, region
    end
    index = index + 1
  end
end

local function find_playable_step_back(index, playlist)
  local list = regions()
  while playlist and index >= 1 do
    local region = find_region(playlist.items[index], list)
    if region and region.end_pos > region.start_pos then
      return index, region
    end
    index = index - 1
  end
end

local function pause_playlist()
  if not playing or paused then return end
  paused = true
  r.OnPauseButton()
end

local function resume_playlist()
  if not playing or not paused then return end
  paused = false
  local position = r.GetPlayPosition2()
  local rate = r.Master_GetPlayRate(project)
  expected_end = r.time_precise() + math.max(0, target_end - position) / rate + 1
  last_position = position
  r.OnPlayButton()
end

local function play_step(index, playlist)
  local next_index, region = find_playable_step(index, playlist)
  if region then
    start_region(next_index, region, playlist, false)
    return
  end
  stop_playlist(true)
end

local function play_region(index, region, playlist)
  if not region or region.end_pos <= region.start_pos then return end
  start_region(index, region, playlist, not play_consecutively)
end

local function play_or_resume(playlist)
  if playing and paused then
    resume_playlist()
    return
  end
  if playing then return end
  play_step(1, playlist)
  if playing then single_region = not play_consecutively end
end

local function skip_previous(playlist)
  local current = playing and playing_playlist == playlist and step or 1
  local index, region = find_playable_step_back(current - 1, playlist)
  if region then
    start_region(index, region, playlist, not play_consecutively)
  end
end

local function skip_next(playlist)
  local current = playing and playing_playlist == playlist and step or 0
  local index, region = find_playable_step(current + 1, playlist)
  if region then
    start_region(index, region, playlist, not play_consecutively)
  elseif playing then
    stop_playlist(true)
  end
end

local function input_name(label, playlist)
  r.ImGui_SetNextItemWidth(ctx, r.ImGui_GetContentRegionAvail(ctx) * 2 / 3)
  local draft = name_drafts[playlist.id] or playlist.name
  local changed, value = r.ImGui_InputText(ctx, label, draft)
  if changed then name_drafts[playlist.id] = value end
  if not r.ImGui_IsItemDeactivatedAfterEdit(ctx) then return end
  value = name_drafts[playlist.id] or playlist.name
  name_drafts[playlist.id] = nil
  local filename = filename_for(value)
  if not filename or filename_taken(filename, playlist) then
    storage_error = 'Invalid or duplicate playlist name.'
    return
  end
  if filename ~= playlist.filename then
    local directory, separator = storage_path()
    local new_path = playlist_file(directory, separator, filename)
    if filename:lower() ~= playlist.filename:lower() then
      local existing = io.open(new_path, 'rb')
      if existing then
        existing:close()
        storage_error = 'Playlist file already exists: ' .. filename
        return
      end
    end
    local renamed, err = os.rename(playlist_file(directory, separator, playlist.filename), new_path)
    if not renamed then storage_error = tostring(err); return end
    playlist.filename = filename
  end
  playlist.name = value
  save()
end

local function move_item(items, from, to)
  if from == to then return end
  local item = table.remove(items, from)
  table.insert(items, to, item)
  stop_playlist(false)
  save()
end

local duration_gap = 8

local function fit_label(text, width)
  if r.ImGui_CalcTextSize(ctx, text) <= width then return text end
  if width < r.ImGui_CalcTextSize(ctx, '...') then return '' end
  while #text > 0 and r.ImGui_CalcTextSize(ctx, text .. '...') > width do
    local start = utf8.offset(text, -1)
    text = start and text:sub(1, start - 1) or ''
  end
  return text .. '...'
end

local function draw(list)
  if not storage_path() then
    r.ImGui_Text(ctx, 'Save the REAPER project to enable playlists.')
    return
  end
  if storage_error then r.ImGui_Text(ctx, storage_error) end
  if r.ImGui_BeginTabBar(ctx, 'Playlists') then
    for index, playlist in ipairs(playlists) do
      local flags = playlist.id == select_new_tab_id and r.ImGui_TabItemFlags_SetSelected() or 0
      local visible = r.ImGui_BeginTabItem(ctx, playlist.name .. '###playlist_' .. playlist.id, nil, flags)
      if r.ImGui_IsItemClicked(ctx, 1) then editing_name_id = playlist.id end
      if visible then selected = index; r.ImGui_EndTabItem(ctx) end
    end
    r.ImGui_EndTabBar(ctx)
    select_new_tab_id = nil
  end
  if r.ImGui_Button(ctx, 'New playlist') then
    local name, filename
    repeat
      name = 'Playlist ' .. next_playlist_id
      filename = filename_for(name)
      next_playlist_id = next_playlist_id + 1
      local directory, separator = storage_path()
      local file = io.open(playlist_file(directory, separator, filename), 'rb')
      if file then file:close() else break end
    until false
    playlists[#playlists + 1] = { id = next_playlist_id - 1, filename = filename, name = name, items = {} }
    selected = #playlists
    editing_name_id = playlists[selected].id
    select_new_tab_id = editing_name_id
    stop_playlist(false)
    save()
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, 'Project regions') then
    show_regions = not show_regions
  end
  local playlist = playlists[selected]
  if not playlist then return end
  if editing_name_id == playlist.id then input_name('Name', playlist) end
  if r.ImGui_Button(ctx, 'Delete playlist') then
    stop_playlist(false)
    local directory, separator = storage_path()
    local path = playlist_file(directory, separator, playlist.filename)
    local removed, err = os.remove(path)
    if not removed then
      storage_error = 'Cannot delete playlist file: ' .. tostring(err)
      return
    end
    table.remove(playlists, selected)
    name_drafts[playlist.id] = nil
    if editing_name_id == playlist.id then editing_name_id = nil end
    selected = math.max(1, selected - 1)
    storage_error = nil
    return
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, 'Clear') then
    if playing_playlist == playlist then stop_playlist(true) end
    playlist.items = {}
    save()
  end
  r.ImGui_Separator(ctx)
  local regions_by_id = {}
  for _, region in ipairs(list) do
    regions_by_id[region.id] = region
  end
  local total_duration = 0
  for _, id in ipairs(playlist.items) do
    local region = regions_by_id[id]
    if region then total_duration = total_duration + region_duration(region) end
  end
  r.ImGui_Text(ctx, 'Total duration: ' .. format_duration(total_duration))
  if r.ImGui_Button(ctx, '<<<') then skip_previous(playlist) end
  if r.ImGui_IsItemHovered(ctx) then r.ImGui_SetTooltip(ctx, 'Previous region') end
  r.ImGui_SameLine(ctx)
  local can_play = not playing or paused
  r.ImGui_BeginDisabled(ctx, not can_play)
  if r.ImGui_Button(ctx, 'Play') then play_or_resume(playlist) end
  r.ImGui_EndDisabled(ctx)
  r.ImGui_SameLine(ctx)
  r.ImGui_BeginDisabled(ctx, not playing or paused)
  if r.ImGui_Button(ctx, 'Pause') then pause_playlist() end
  r.ImGui_EndDisabled(ctx)
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '>>>') then skip_next(playlist) end
  if r.ImGui_IsItemHovered(ctx) then r.ImGui_SetTooltip(ctx, 'Next region') end
  r.ImGui_SameLine(ctx)
  local changed
  changed, play_consecutively = r.ImGui_Checkbox(ctx, '##play_consecutively', play_consecutively)
  if r.ImGui_IsItemHovered(ctx) then r.ImGui_SetTooltip(ctx, 'Play consecutively') end
  if changed and playing then single_region = not play_consecutively end
  r.ImGui_Text(ctx, 'Playlist entries (duplicates allowed)')
  local move_from, move_to
  local duration_color = r.ImGui_GetStyleColor(ctx, r.ImGui_Col_TextDisabled())
  local draw_list = r.ImGui_GetWindowDrawList(ctx)
  for i, id in ipairs(playlist.items) do
    r.ImGui_PushID(ctx, i)
    local region = regions_by_id[id]
    local label = region and (region.name ~= '' and region.name or ('Region ' .. id)) or ('Missing region ' .. id)
    local is_playing = playing and playing_playlist == playlist and i == step
    if is_playing then
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0xFFFF00FF)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0xFFFF00FF)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), 0xFFFF00FF)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x000000FF)
    end
    local button_label = is_playing and '>>###play_region' or '>###play_region'
    local clicked = r.ImGui_SmallButton(ctx, button_label)
    if is_playing then r.ImGui_PopStyleColor(ctx, 4) end
    if clicked then
      play_region(i, region, playlist)
      is_playing = playing and playing_playlist == playlist and i == step
    end
    if is_playing then
      r.ImGui_SameLine(ctx)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0xFF0000FF)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0xFF4444FF)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), 0xCC0000FF)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0xFFFFFFFF)
      if r.ImGui_SmallButton(ctx, 'S###stop_region') then
        stop_playlist(true)
        is_playing = false
      end
      r.ImGui_PopStyleColor(ctx, 4)
      if r.ImGui_IsItemHovered(ctx) then r.ImGui_SetTooltip(ctx, 'Stop') end
    end
    r.ImGui_SameLine(ctx)
    local width = math.max(40, r.ImGui_GetContentRegionAvail(ctx) - r.ImGui_CalcTextSize(ctx, 'x') - 24)
    local duration = region and format_duration(region_duration(region)) or '--:--.---'
    local time_label = '[' .. duration .. ']'
    local time_width, time_height = r.ImGui_CalcTextSize(ctx, time_label)
    local text = fit_label(i .. '. ' .. label, width - duration_gap - time_width - 8)
    local row_x = r.ImGui_GetCursorScreenPos(ctx)
    if is_playing then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0xFFFF00FF) end
    r.ImGui_Selectable(ctx, text .. '###entry', false, 0, width, 0)
    if is_playing then r.ImGui_PopStyleColor(ctx) end
    -- Draw the duration inside the row without replacing the drag-and-drop item.
    local _, top = r.ImGui_GetItemRectMin(ctx)
    local _, bottom = r.ImGui_GetItemRectMax(ctx)
    local text_width = r.ImGui_CalcTextSize(ctx, text, nil, nil, true)
    local time_x = row_x + text_width + (text ~= '' and duration_gap or 0)
    local time_y = math.floor((top + bottom - time_height) / 2)
    r.ImGui_DrawList_AddText(draw_list, time_x, time_y, duration_color, time_label)
    if r.ImGui_BeginDragDropSource(ctx) then
      r.ImGui_SetDragDropPayload(ctx, 'PLAYLIST_ENTRY', tostring(i))
      r.ImGui_Text(ctx, label)
      r.ImGui_EndDragDropSource(ctx)
    end
    if r.ImGui_BeginDragDropTarget(ctx) then
      local accepted, source = r.ImGui_AcceptDragDropPayload(ctx, 'PLAYLIST_ENTRY')
      if accepted then
        local from = tonumber(source)
        if from and from >= 1 and from <= #playlist.items and from ~= i then
          move_from, move_to = from, i
        end
      end
      r.ImGui_EndDragDropTarget(ctx)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_SmallButton(ctx, 'x') then
      table.remove(playlist.items, i)
      stop_playlist(false); save()
    end
    if r.ImGui_IsItemHovered(ctx) then r.ImGui_SetTooltip(ctx, 'Remove from playlist') end
    r.ImGui_PopID(ctx)
  end
  if move_from then move_item(playlist.items, move_from, move_to) end
end

local function draw_regions(list)
  local playlist = playlists[selected]
  if not playlist then r.ImGui_Text(ctx, 'Select or create a playlist to add regions.') end

  r.ImGui_BeginDisabled(ctx, not playlist or #list == 0)
  if r.ImGui_SmallButton(ctx, 'Add all regions') and playlist and #list > 0 then
    for _, region in ipairs(list) do
      playlist.items[#playlist.items + 1] = region.id
    end
    save()
  end
  r.ImGui_EndDisabled(ctx)
  r.ImGui_Separator(ctx)
  for _, region in ipairs(list) do
    r.ImGui_PushID(ctx, region.id)
    r.ImGui_BeginDisabled(ctx, not playlist)
    if r.ImGui_SmallButton(ctx, '+') and playlist then
      playlist.items[#playlist.items + 1] = region.id
      save()
    end
    r.ImGui_EndDisabled(ctx)
    r.ImGui_SameLine(ctx)
    local time_label = '[' .. format_duration(region_duration(region)) .. ']'
    local label = region.name ~= '' and region.name or 'Untitled'
    local width = r.ImGui_GetContentRegionAvail(ctx) - duration_gap - r.ImGui_CalcTextSize(ctx, time_label)
    local text = fit_label(label, width)
    if text ~= '' then
      r.ImGui_Text(ctx, text)
      r.ImGui_SameLine(ctx, 0, duration_gap)
    end
    r.ImGui_TextDisabled(ctx, time_label)
    r.ImGui_PopID(ctx)
  end
end

local function draw_regions_window(list, main_x, main_y, main_height)
  local width, gap = 270, 8
  r.ImGui_SetNextWindowPos(ctx, main_x - width - gap, main_y)
  r.ImGui_SetNextWindowSize(ctx, width, main_height)
  local flags = r.ImGui_WindowFlags_NoDocking() | r.ImGui_WindowFlags_NoMove()
    | r.ImGui_WindowFlags_NoResize() | r.ImGui_WindowFlags_NoCollapse()
    | r.ImGui_WindowFlags_NoSavedSettings()
  local visible, open = r.ImGui_Begin(ctx, 'Project regions', true, flags)
  if visible then
    draw_regions(list)
    r.ImGui_End(ctx)
  end
  show_regions = open
end

local function loop()
  local current_project, current_file = r.EnumProjects(-1, '')
  if current_project ~= project or current_file ~= project_file then
    stop_playlist(false)
    name_drafts = {}
    editing_name_id = nil
    select_new_tab_id = nil
    project = current_project
    project_file = current_file
    selected = 1
    load()
  end
  if playing then
    local state = r.GetPlayState()
    local position = r.GetPlayPosition2()
    local now = r.time_precise()
    local transition_at = target_end - (target_end - target_start) / 16
    local stop_at = target_end - 0.015
    if state & 2 ~= 0 then
      paused = true
    elseif state & 1 == 0 then
      stop_playlist(false)
    elseif paused then
      paused = false
      local rate = r.Master_GetPlayRate(project)
      expected_end = now + math.max(0, target_end - position) / rate + 1
      last_position = position
    elseif seek_requested_at then
      -- The transport can still report the previous position while a seek is pending.
      local elapsed = now - seek_requested_at
      local rate = r.Master_GetPlayRate(project)
      local waiting_for_rewind = seek_from and seek_from > target_start and position >= seek_from
      if position >= target_start and position <= target_start + elapsed * rate + 0.1
          and not waiting_for_rewind then
        seek_requested_at = nil
        seek_from = nil
        last_position = position
        expected_end = now + (target_end - target_start) / rate + 1
      elseif elapsed > 2 then
        if not single_region and not seek_retried then
          -- Retry the seek while the transport keeps playing.
          seek_retried = true
          seek_to_region_start()
        else
          stop_playlist(true)
        end
      end
    elseif position >= math.min(transition_at, stop_at)
        and last_position and position >= last_position
        and now <= expected_end then
      local next_index, region
      if not single_region then
        next_index, region = find_playable_step(step + 1, playing_playlist)
      end
      if region and math.abs(region.start_pos - target_end) < 0.000001 then
        if position >= target_end then
          step, target_start, target_end = next_index, region.start_pos, region.end_pos
          expected_end = now + (target_end - position) / r.Master_GetPlayRate(project) + 1
        end
        last_position = position
      elseif region and position >= transition_at then
        start_region(next_index, region, playing_playlist, false)
      elseif not region and position >= stop_at then
        stop_playlist(true)
      else
        last_position = position
      end
    elseif position < target_start - 0.05 or position > target_end + 0.25
        or now > expected_end then
      stop_playlist(false)
    else
      last_position = position
    end
  end
  r.ImGui_SetNextWindowSize(ctx, 270, 480, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, 'Playback Playlist ' .. version .. '', true)
  if visible then
    local list = regions()
    draw(list)
    local main_x, main_y = r.ImGui_GetWindowPos(ctx)
    local _, main_height = r.ImGui_GetWindowSize(ctx)
    r.ImGui_End(ctx)
    if open and show_regions then draw_regions_window(list, main_x, main_y, main_height) end
  end
  if open then r.defer(loop) else stop_playlist(false) end
end

load()
r.defer(loop)