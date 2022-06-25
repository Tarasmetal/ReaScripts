--[[
 * Version: 1.0
 * Author: nofish
 * About: a mod from 'mpl_Save_all_track_FX_chains.lua' found here:
 * http://forum.cockos.com/showpost.php?p=1596059&postcount=26
--]]

--[[
 Changelog:
 * v1.0
    + Initial release
--]]


   --[[
    nofish_Save_track_FX-chains_for_sel_tracks.lua
    v1.0

    a mod from 'mpl_Save_all_track_FX_chains.lua' found here:
    http://forum.cockos.com/showpost.php?p=1596059&postcount=26

    this versions saves FX chains for all tracks if no track is selected
    otherwise it saves the FX chains for the selected tracks
    --]]

  script_title = "trs_Save selected tracks FX chains to project path"

  ----------------------------------------------------------------------
  ----------------------------------------------------------------------

  -- раскомментируйте путь, по которому вы хотите сохранить цепочки FX, или введите свою пользовательскую папку,
  -- использовать только '/' и не используйте '\'

  -- saving_path = 'C:/FX Chains/'
  saving_path = reaper.GetProjectPath(0,'')..'/FXChains/' ------------
  -- saving_path = reaper.GetResourcePath()..'/FXChains/'..'<project_name>'

--  saving_path = reaper.GetResourcePath()..'/FXChains/! _SAVED_CHAINS_FROM_PROJECTS/'..'<project_name>' -----
  -- используйте выше, если вы хотите сохранить в подпапке FXChains

  ---- reaper.Main_OnCommand(40296, 0) -- Выделить все треки --------------------------------

  ----------------------------------------------------------------------
  ----------------------------------------------------------------------
     _, project_name = reaper.EnumProjects(0,'')
    repeat
      st1 = string.find(project_name,'\\') if st1 == nil then st1 = 0 end
      st2 = string.find(project_name,'/') if st2 == nil then st2 = 0 end
      st = math.max(st1,st2)
      project_name = string.sub(project_name, st+1)
    until st == 0
    project_name = string.sub(project_name, 0, -5)..'/'

  saving_path = string.gsub(saving_path,'<project_name>',project_name)
  saving_path = string.gsub(saving_path,'\\','/')

  -- проверьте, выбраны ли какие-либо треки
  count_sel_track = reaper.CountSelectedTracks(0)
  if count_sel_track ~= 0 then
    ret = reaper.MB('Do you wanna save your FX chains for sel. tracks to'..'\n'..
           saving_path..' ?', 'Save all tracks FX chains', 1)
  else
    ret = reaper.MB('Do you wanna save all your FX chains to'..'\n'..
             saving_path..' ?', 'Save all tracks FX chains', 1)
  end


  function find_chain(chunk_t, searchfrom)
    for i = searchfrom, #chunk_t do
      st_find = string.find(chunk_t[i], 'BYPASS')
      if st_find == 1 then
        vst_data0 = chunk_t[i]
        j = i
        repeat
          j = j + 1
          if string.find(chunk_t[j],'FLOATPOS') == nil
             and string.find(chunk_t[j],'FXID') == nil then
               vst_data0 = vst_data0..'\n'..chunk_t[j] end
          st_find2 = string.find(chunk_t[j], 'WAK')
        until st_find2 ~= nil
        return vst_data0, j+1, i
      end
    end
  end

  if ret == 1 then

    reaper.Undo_BeginBlock()

    chains_t = {}
    if count_sel_track ~= 0 then -- проверьте, выбран ли какой-либо трек
      counttrack = reaper.CountSelectedTracks(0)
    else -- если ни один трек Не выбран
      counttrack = reaper.CountTracks(0)
    end
    if counttrack ~= nil then
      for i = 1, counttrack do
      if count_sel_track ~= 0 then
        track = reaper.GetSelectedTrack(0,i-1)
      else
        track = reaper.GetTrack(0,i-1)
      end
        if track ~= nil then
          _, chunk = reaper.GetTrackStateChunk(track, '')
          chunk_t = {}
          for line in chunk:gmatch("[^\r\n]+") do  table.insert(chunk_t, line)  end

          -- поиск trackfx chunk

            end_search_id = #chunk_t
            for j = 1, #chunk_t do
              st_find0 = string.find(chunk_t[j], '<FXCHAIN')
              if st_find0 ~= nil then chain_exists = true end
              st_find1 = string.find(chunk_t[j], '<FXCHAIN_REC')
              st_find2 = string.find(chunk_t[j], '<ITEM')
              if st_find1 ~= nil or st_find2 ~= nil then end_search_id = math.min(end_search_id, j) end
            end

          -- получите все данные fxchain

            if chain_exists then
              search_from = 1
              vst_data_com = ""
              while search_from ~= nil and search_from < end_search_id do
                vst_data, search_from, start_id = find_chain(chunk_t, search_from)
                if vst_data  ~= nil and start_id < end_search_id then vst_data_com = vst_data_com..'\n'..vst_data  end
              end
            end

          -- объявите имя файла для fx chain
            -- получить номер трека для текущего трека
            trackNumber = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
            trackNumber = math.ceil(trackNumber) -- снимите десятичные дроби

            _, trackname = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
            if trackname == '' then name = 'Track '..trackNumber else name = 'Track '..trackNumber..' - '..trackname end
            table.insert(chains_t, {vst_data_com, name} )

        end -- если тр не пропустит
      end -- петля тр
    end -- counttrack

    -- запись таблицы fx chains в файлы

      if chains_t ~= nil then
        reaper.RecursiveCreateDirectory(saving_path, 1)
        for i = 1, #chains_t do
          chains_subt = chains_t[i]
          if chains_subt[1] ~= '' and chains_subt[1] ~= nil then
            file = io.open (saving_path..chains_subt[2]..'.RfxChain', 'w')
            file:write(chains_subt[1])
            io.close (file)
          end
        end
      end

    reaper.Undo_EndBlock(script_title, 1)

  end -- если ret = = 1

