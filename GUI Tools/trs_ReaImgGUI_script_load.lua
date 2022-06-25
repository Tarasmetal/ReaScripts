-- @description ReaImgGUI_script_load
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
--   # Init Lua Script
-- @changelog
--  + Code optimizations


local r = reaper

-- path = reaper.GetResourcePath() .. '\\Scripts\\Taras\\Tools\\'
path_scr = reaper.GetResourcePath() .. '\\Scripts\\Taras\\ReaImgGUI\\'
path_taras = reaper.GetResourcePath() .. '\\Scripts\\Taras\\'
-- path_taras = reaper.GetResourcePath() .. '\\Scripts\\Taras\\'

my_bpm = reaper.GetProjectTimeSignature()

function myPath(str)
    -- path = reaper.GetResourcePath() .. '\\Scripts\\Taras\\Tools\\'
    -- local path = reaper.GetResourcePath() .. '\\'.. str .. '\\'
    local path = reaper.GetResourcePath() .. str
    return path
end

pathList = {
    path = '\\Scripts\\Taras\\',
    path = '\\Scripts\\Taras\\ReaImgGUI\\',
    path = '\\Scripts\\Taras\\Tools\\',
    -- path = ' .. myPath(Scripts\\Taras\\) .. ',
    -- path = {Scripts\\Taras\\Tools},
    -- path = {myPath(Scripts\\Taras)},
}

function GetListOfFiles(d)
  local tb = {}
  local i = 0
  repeat
  local retval = reaper.EnumerateFiles(d,i)
  table.insert(tb, retval)
  i = i + 1
  until not retval
  return tb
end

-- function GetListPath(v)
--   local pl = {}
--   local i = 0
--   repeat
--   for i,v in pairs(pathList) do
--   local retval = v,i
--   end
--   table.insert(pl, retval)
--   i = i + 1
--   until not retval
--   return pl
-- end

-- pathWithFilename=io.popen("cd"):read'*all'

-- function dirtree(dir)
--   assert(dir and dir ~= "", "directory parameter is missing or empty")
--   if string.sub(dir, -1) == "/" then
--     dir=string.sub(dir, 1, -2)
--   end

--   local diriters = {lfs.dir(dir)}
--   local dirs = {dir}

--   return function()
--     repeat
--       local entry = diriters[#diriters]()
--       if entry then
--         if entry ~= "." and entry ~= ".." then
--           local filename = table.concat(dirs, "/").."/"..entry
--           local attr = lfs.attributes(filename)
--           if attr.mode == "directory" then
--             table.insert(dirs, entry)
--             table.insert(diriters, lfs.dir(filename))
--           end
--           return filename, attr
--         end
--       else
--         table.remove(dirs)
--         table.remove(diriters)
--       end
--     until #diriters==0
--   end
-- end

-- local function CreateDoFile()
--     local orgDoFile = dofile;

--     return function(filename)
--         if(filename) then --can be called with nil.
--             local pathToFile = extractFilePath(filename);
--             if(isRelativePath(pathToFile)) then
--                 pathToFile = currentDir() .. "/" .. pathToFile;
--             end

--             --Store the path in a global, overwriting the previous value.
--             path = pathToFile;
--         end
--         return orgDoFile(filename); --proper tail call.
--     end
-- end

-- dofile = CreateDoFile();

-- function io.splitpath()
--    filename = filename or ""

--    local path,file,ext
--    local file_name

--    path,file_name = filename:match("^%s*(.-)([^\\/].*)$")
--    if file_name then
--       file,ext = file_name:match("([^%.]*)%.?(.*)$")
--    end
--    return path,file,ext
-- end


function rand(vel,rnd)
  math.randomseed(os.time()*100000000000)
    if rnd > 0 then
     rand_num = vel - math.random(0, rnd)
      else
     rand_num = tonumber(vel)
        end
    return rand_num
    -- ('Dynamic velocity: ' ..  rand(120,0) .. '  => ' .. rand(120,5) .. '')
end

-- function GuiInit()
    ctx = reaper.ImGui_CreateContext('Template')
    -- ctx = reaper.ImGui_CreateContext('Item Sequencer') -- Add VERSION TODO
    font = reaper.ImGui_CreateFont('Consolas', 15) -- Create the fonts you need
    -- font = reaper.ImGui_CreateFont('Noto Sans SemCond', 18)
    r.ImGui_AttachFont(ctx, font)-- Attach the fonts you need
-- end

function loop()

    reaper.ImGui_SetNextWindowPos(ctx, 0, 0, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_SetNextWindowSize(ctx, 400, 300, reaper.ImGui_Cond_Once())
    reaper.ImGui_PushFont(ctx, font) -- Says you want to start using a specific font
    local visible, open = reaper.ImGui_Begin(ctx, '<< Script Check Load GUI beta >>', true, flags)
     function ShowUserGuide()
  -- ImGuiIO& io = r.ImGui_GetIO() TODO
  r.ImGui_BulletText(ctx, 'Double-click on title bar to collapse window.')
  r.ImGui_BulletText(ctx,
  'Click and drag on lower corner to resize window\n' ..
  '(double-click to auto fit window to its contents).')
  r.ImGui_BulletText(ctx, 'CTRL+Click on a slider or drag box to input value as text.')
  r.ImGui_BulletText(ctx, 'TAB/SHIFT+TAB to cycle through keyboard editable fields.')
  -- if (io.FontAllowUserScaling)
  --     r.ImGui_BulletText(ctx, 'CTRL+Mouse Wheel to zoom window contents.')
  r.ImGui_BulletText(ctx, 'While inputing text:\n')
  r.ImGui_Indent(ctx)
  r.ImGui_BulletText(ctx, 'CTRL+Left/Right to word jump.')
  r.ImGui_BulletText(ctx, 'CTRL+A or double-click to select all.')
  r.ImGui_BulletText(ctx, 'CTRL+X/C/V to use clipboard cut/copy/paste.')
  r.ImGui_BulletText(ctx, 'CTRL+Z,CTRL+Y to undo/redo.')
  r.ImGui_BulletText(ctx, 'ESCAPE to revert.')
  r.ImGui_BulletText(ctx, 'You can apply arithmetic operators +,*,/ on numerical values.\nUse +- to subtract.')
  r.ImGui_Unindent(ctx)
  r.ImGui_BulletText(ctx, 'With keyboard navigation enabled:')
  r.ImGui_Indent(ctx)
  r.ImGui_BulletText(ctx, 'Arrow keys to navigate.')
  r.ImGui_BulletText(ctx, 'Space to activate a widget.')
  r.ImGui_BulletText(ctx, 'Return to input text into a widget.');
  r.ImGui_BulletText(ctx, 'Escape to deactivate a widget, close popup, exit child window.')
  r.ImGui_BulletText(ctx, 'Alt to jump to the menu layer of a window.')
  r.ImGui_BulletText(ctx, 'CTRL+Tab to select a window.')
  end
     r.ImGui_TextColored(ctx, 0xFF8CFFFF, 'Test Script by Taras')
     reaper.ImGui_Text(ctx, '')
     reaper.ImGui_Text(ctx, 'BPM = 1: ')
     r.ImGui_SameLine(ctx)
     r.ImGui_TextColored(ctx, 0x88FF00FF, my_bpm)
     reaper.ImGui_Text(ctx, 'BPM x 2: ')
     r.ImGui_SameLine(ctx)
      r.ImGui_TextColored(ctx, 0xFF0036FF, my_bpm*2)
     reaper.ImGui_Text(ctx, 'BPM / 2: ')
     r.ImGui_SameLine(ctx)
     r.ImGui_TextColored(ctx, 0x33AFFFFF, my_bpm/2)
     reaper.ImGui_Text(ctx, '')
      -- r.ImGui_SameLine(ctx)
      r.ImGui_TextColored(ctx, 0xFFFFFFFF, 'Test Velocity Range 127 - 10')
      r.ImGui_TextColored(ctx, 0xFFFF00FF, 'Vel:')
      r.ImGui_SameLine(ctx)
      r.ImGui_TextColored(ctx, 0xFF0036FF, rand(127,0))
      r.ImGui_TextColored(ctx, 0xFFFF00FF, 'Hum:')
      r.ImGui_SameLine(ctx)r.ImGui_TextColored(ctx, 0x88FF00FF, rand(127,10))
     r.ImGui_Text(ctx, '')
      r.ImGui_SameLine(ctx)
     r.ImGui_Text(ctx, '')
     r.ImGui_TextColored(ctx, 0xFFFF00FF, 'PATH Status: ')
     if path == nil or path == '' then
        r.ImGui_SameLine(ctx)
        r.ImGui_TextColored(ctx, 0xFFFF00FF, 'Path not found !!!')
       else
        r.ImGui_SameLine(ctx)
        r.ImGui_TextColored(ctx, 0x88FF00FF, 'Path found !!!')
     end
     reaper.ImGui_Text(ctx, '')
     -- reaper.ImGui_Text(ctx, 'PATH: ' .. path)
    if  visible then
        for i,v in pairs(pathList) do
            -- r.ImGui_TextColored(ctx, 0xFF8CFFFF, ''..v..'')
            rv = reaper.ImGui_Button(ctx, ''.. myPath(v) ..'')
        if rv then
            tbl2 = {}
            tbl2 = GetListOfFiles(myPath(v))
            reaper.ImGui_OpenPopup(ctx, 'load_popup')
        end
        if reaper.ImGui_BeginPopup(ctx, 'load_popup') then
         r.ImGui_TextColored(ctx, 0xFFFF00FF, 'Load Script: ')
             reaper.ImGui_Separator(ctx)
            for i, v in ipairs(tbl2) do
                if reaper.ImGui_Selectable(ctx, v) then selected = i end
            end
            reaper.ImGui_EndPopup(ctx)
         end
            if tbl2 ~= nil and selected ~= nil then
                dofile(path .. tbl2[selected])
                selected = nil
            end

    --   local path = path_scr
    --     rv = reaper.ImGui_Button(ctx, path)
    --     if rv then
    --         tbl3 = {}
    --         tbl3 = GetListOfFiles(path)
    --         reaper.ImGui_OpenPopup(ctx, 'tbl3_popup')
    --     end

    --     if reaper.ImGui_BeginPopup(ctx, 'tbl3_popup') then
    --      r.ImGui_TextColored(ctx, 0xFFFF00FF, 'Load Script: ')
    --          reaper.ImGui_Separator(ctx)
    --         for i, v in ipairs(tbl3) do
    --             if reaper.ImGui_Selectable(ctx, v) then selected = i end
    --         end
    --         reaper.ImGui_EndPopup(ctx)
    --     end

    --     if tbl3 ~= nil and selected ~= nil then
    --         dofile(path .. tbl3[selected])
    --         selected = nil
    --     end
    end
        reaper.ImGui_End(ctx)
  end

    reaper.ImGui_PopFont(ctx) -- Pop Font

    if open and (not reaper.ImGui_IsKeyDown(ctx, 27)) then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

-- GuiInit()
reaper.defer(loop)
