-- @description trs_HorizontalZoom_In_8
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies

  function trs_HorizontalZoom_In_8()

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(0);

    reaper.Main_OnCommand( 40514, 0); -- View: Move edit cursor to mouse cursor
    reaper.Main_OnCommand( 41110, 0); -- Track: Select track under mouse
    reaper.Main_OnCommand( 40723, 0); -- View: Expand selected track height, minimize others
    local a=1011 local a=1012 local n=40112 local n=40111 reaper.Main_OnCommand(a,0); -- kawa_MAIN_HorizontalZoom_In_5
    reaper.Main_OnCommand(a,0);
    reaper.Main_OnCommand(a,0);
    reaper.Main_OnCommand(a,0);
    reaper.Main_OnCommand(a,0);
    reaper.Main_OnCommand(a,0);
    reaper.Main_OnCommand(a,0);
    reaper.Main_OnCommand(a,0);
    reaper.Main_OnCommand(a,0);
    -- local a=1011 local a=1012 local a=40112 local a=40111 reaper.Main_OnCommand(a,0); -- kawa_MAIN_VerticalZoom_In_5
    -- reaper.Main_OnCommand(a,0);
    -- reaper.Main_OnCommand(a,0);
    -- reaper.Main_OnCommand(a,0);
    -- reaper.Main_OnCommand(a,0);
    -- reaper.Main_OnCommand(a,0);
    -- reaper.Main_OnCommand(a,0);
    -- reaper.Main_OnCommand(a,0);
    -- reaper.Main_OnCommand(a,0);
--///////////////////////
--///////////////////////
reaper.PreventUIRefresh(-1);
reaper.Undo_EndBlock("trs_HorizontalZoom_In_8",-1)

end

trs_HorizontalZoom_In_8()
-- reaper.Main_OnCommand( 40723, 0); -- Go to Cursor
-- reaper.UpdateArrange()

