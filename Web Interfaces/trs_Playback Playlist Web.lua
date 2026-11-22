-- @description Playback Playlist Web bridge (run instead of the ReaImGui playlist)
-- @author Taras Umanskiy
-- @version 1.1
-- @changelog
--   v.1.1 + Смежные регионы играют непрерывно, повтор перехода выполняется на ходу.
-- @about Open playback_playlist.html in REAPER Web Remote after running this script.

local r = reaper
local section = 'TRS_PlaybackPlaylistWeb'
local playlists, selected, next_id = {}, 1, 1
local project, project_file = r.EnumProjects(-1, '')
local playing, playing_playlist, step, single, consecutive = false, nil, 0, false, false
local target_start, target_end, expected_end, seek_at, seek_from, retried, last_position
local error_text, last_command, revision = '', r.GetExtState(section, 'command'), 0

local function encode(value)
  return (tostring(value or ''):gsub('([^%w%-_%.])', function(c) return string.format('%%%02X', c:byte()) end))
end

local function decode(value)
  return (value:gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex, 16)) end))
end

local function location()
  local _, filename = r.EnumProjects(-1, '')
  local directory = filename and filename:match('^(.*)[/\\][^/\\]+$')
  if not directory then return nil end
  local sep = r.GetOS():match('Win') and '\\' or '/'
  return directory .. sep .. 'PlaybackList', sep
end

local function filename_for(name)
  local safe = name:gsub('[<>:"/\\|%?%*%c]', '_'):gsub('[%. ]+$', '')
  if safe == '' then return nil end
  return 'playlist_' .. safe .. '.txt'
end

local function taken(filename, except)
  for _, p in ipairs(playlists) do
    if p ~= except and p.filename:lower() == filename:lower() then return true end
  end
  return false
end

local function save()
  local directory, sep = location()
  if not directory then error_text = 'Save the REAPER project first.'; return false end
  r.RecursiveCreateDirectory(directory, 0)
  for _, p in ipairs(playlists) do
    local file, err = io.open(directory .. sep .. p.filename, 'wb')
    if not file then error_text = tostring(err); return false end
    local ok, write_err = file:write('1\n', encode(p.name), '\n', table.concat(p.items, ','), '\n')
    local closed, close_err = file:close()
    if not ok or not closed then error_text = tostring(write_err or close_err); return false end
  end
  error_text = ''
  return true
end

local function parse_items(value)
  local items = {}
  for id in (value or ''):gmatch('[^,]+') do
    local number = tonumber(id)
    if number then items[#items + 1] = number end
  end
  return items
end

local function load()
  playlists, selected, next_id, error_text = {}, 1, 1, ''
  local directory, sep = location()
  if not directory then return end
  local index = 0
  while true do
    local filename = r.EnumerateFiles(directory, index)
    if not filename then break end
    if filename:match('^playlist_.+%.txt$') then
      local file = io.open(directory .. sep .. filename, 'rb')
      if file then
        local version, name, ids = file:read('*l', '*l', '*l')
        file:close()
        if version == '1' and name and ids then
          playlists[#playlists + 1] = { id = next_id, filename = filename, name = decode(name), items = parse_items(ids) }
          next_id = next_id + 1
        end
      end
    end
    index = index + 1
  end
  table.sort(playlists, function(a, b) return a.filename:lower() < b.filename:lower() end)
end

local function regions()
  local result = {}
  local _, markers, count = r.CountProjectMarkers(0)
  for i = 0, markers + count - 1 do
    local ok, is_region, start_pos, end_pos, name, id = r.EnumProjectMarkers3(0, i)
    if ok and is_region then result[#result + 1] = { id = id, start_pos = start_pos, end_pos = end_pos, name = name } end
  end
  table.sort(result, function(a, b) return a.start_pos < b.start_pos end)
  return result
end

local function stop(stop_transport)
  playing, playing_playlist, step, single = false, nil, 0, false
  expected_end, seek_at, seek_from, retried, last_position = nil, nil, nil, false, nil
  if stop_transport then r.OnStopButton() end
end

local function seek()
  local transport_playing = r.GetPlayState() & 1 ~= 0
  seek_from = transport_playing and r.GetPlayPosition2() or nil
  seek_at = r.time_precise()
  r.SetEditCurPos2(0, target_start, false, true)
  if not transport_playing then r.OnPlayButton() end
end

local function start(index, region, playlist, play_single)
  step, target_start, target_end = index, region.start_pos, region.end_pos
  last_position, retried, single = nil, false, play_single
  playing_playlist, playing = playlist, true
  seek()
end

local function playable(index, playlist)
  local list = regions()
  while playlist and index <= #playlist.items do
    for _, region in ipairs(list) do
      if region.id == playlist.items[index] and region.end_pos > region.start_pos then return index, region end
    end
    index = index + 1
  end
end

local function publish()
  local lines = { table.concat({ 'S', revision, selected, consecutive and 1 or 0,
    playing and playing_playlist and playing_playlist.id or 0, step, encode(error_text), location() and 1 or 0,
    encode(project_file), math.floor(r.time_precise() * 1000) }, '|') }
  for _, p in ipairs(playlists) do
    lines[#lines + 1] = table.concat({ 'P', p.id, encode(p.name), table.concat(p.items, ',') }, '|')
  end
  r.SetExtState(section, 'state', table.concat(lines, '~'), false)
end

local function handle(raw)
  if raw == '' or raw == last_command then return end
  last_command = raw
  local seq, op, arg = raw:match('^(%d+)|([%a_]+)|(.*)$')
  if not seq then return end
  arg = decode(arg)
  local p = playlists[selected]
  error_text = ''
  if op == 'select' then
    local id = tonumber(arg)
    for i, item in ipairs(playlists) do if item.id == id then selected = i; break end end
  elseif op == 'new' then
    if not location() then error_text = 'Save the REAPER project first.'; return end
    local name, filename
    repeat
      name = 'Playlist ' .. next_id
      filename = filename_for(name)
      next_id = next_id + 1
      local directory, sep = location()
      local existing = io.open(directory .. sep .. filename, 'rb')
      if existing then existing:close() else break end
    until false
    playlists[#playlists + 1] = { id = next_id - 1, name = name, filename = filename, items = {} }
    selected = #playlists
    stop(false)
    save()
  elseif op == 'rename' and p then
    local filename = filename_for(arg)
    if not filename or taken(filename, p) then error_text = 'Invalid or duplicate playlist name.'
    else
      local directory, sep = location()
      if filename ~= p.filename then
        local path = directory .. sep .. filename
        if filename:lower() ~= p.filename:lower() then
          local existing = io.open(path, 'rb')
          if existing then existing:close(); error_text = 'Playlist file already exists.'; return end
        end
        local ok, err = os.rename(directory .. sep .. p.filename, path)
        if not ok then error_text = tostring(err); return end
        p.filename = filename
      end
      p.name = arg
      save()
    end
  elseif op == 'delete' and p then
    local directory, sep = location()
    local ok, err = os.remove(directory .. sep .. p.filename)
    if not ok then error_text = tostring(err); return end
    stop(false)
    table.remove(playlists, selected)
    selected = math.max(1, selected - 1)
  elseif op == 'clear' and p then
    if playing_playlist == p then stop(true) end
    p.items = {}
    save()
  elseif op == 'add' and p then
    local id = tonumber(arg)
    for _, region in ipairs(regions()) do
      if region.id == id then p.items[#p.items + 1] = id; save(); break end
    end
  elseif op == 'all' and p then
    for _, region in ipairs(regions()) do p.items[#p.items + 1] = region.id end
    save()
  elseif op == 'remove' and p then
    local index = tonumber(arg)
    if index and index >= 1 and index <= #p.items then
      table.remove(p.items, index); stop(false); save()
    end
  elseif op == 'move' and p then
    local from, to = arg:match('^(%d+),(%d+)$')
    from, to = tonumber(from), tonumber(to)
    if from and to and from >= 1 and from <= #p.items and to >= 1 and to <= #p.items then
      table.insert(p.items, to, table.remove(p.items, from)); stop(false); save()
    end
  elseif op == 'mode' then
    consecutive = arg == '1'
    if playing then single = not consecutive end
  elseif op == 'stop' then stop(true)
  elseif op == 'play' and p then
    local index, region = playable(1, p)
    if region then start(index, region, p, not consecutive) else stop(true) end
  elseif op == 'entry' and p then
    local index = tonumber(arg)
    if index and p.items[index] then
      for _, region in ipairs(regions()) do
        if region.id == p.items[index] and region.end_pos > region.start_pos then
          start(index, region, p, not consecutive); break
        end
      end
    end
  end
  revision = revision + 1
end

local function tick()
  local current, filename = r.EnumProjects(-1, '')
  if current ~= project or filename ~= project_file then
    stop(false); project, project_file = current, filename; load(); revision = revision + 1
  end
  handle(r.GetExtState(section, 'command'))
  if playing then
    local state, position, now = r.GetPlayState(), r.GetPlayPosition2(), r.time_precise()
    local transition_at = target_end - (target_end - target_start) / 4
    local stop_at = target_end - 0.015
    if state & 1 == 0 or state & 2 ~= 0 then stop(false)
    elseif seek_at then
      local elapsed = now - seek_at
      local rate = math.max(r.Master_GetPlayRate(project), 0.001)
      local waiting = seek_from and seek_from > target_start and position >= seek_from
      if position >= target_start and position <= target_start + elapsed * rate + 0.1 and not waiting then
        seek_at, seek_from, last_position = nil, nil, position
        expected_end = now + (target_end - target_start) / rate + 1
      elseif elapsed > 2 then
        if not single and not retried then retried = true; seek() else stop(true) end
      end
    elseif position >= math.min(transition_at, stop_at) and last_position and position >= last_position and now <= expected_end then
      local index, region
      if not single then index, region = playable(step + 1, playing_playlist) end
      if region and math.abs(region.start_pos - target_end) < 0.000001 then
        if position >= target_end then
          step, target_start, target_end = index, region.start_pos, region.end_pos
          expected_end = now + (target_end - position) / r.Master_GetPlayRate(project) + 1
        end
        last_position = position
      elseif region and position >= transition_at then start(index, region, playing_playlist, false)
      elseif not region and position >= stop_at then stop(true)
      else last_position = position end
    elseif position < target_start - 0.05 or position > target_end + 0.25 or now > expected_end then stop(false)
    else last_position = position end
  end
  publish()
  r.defer(tick)
end

load()
tick()