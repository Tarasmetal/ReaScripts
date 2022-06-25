-- @description trs_Play start
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
-- @changelog
--  + Code Fixies

local r = reaper
local d = "• trs_Play start •"

r.Undo_BeginBlock(0) --
r.PreventUIRefresh(-1);
--=====================

r.Main_OnCommand(40527, 0); -- View: Clear all peak indicators
r.Main_OnCommand(r.NamedCommandLookup("_S&M_WNMAIN"), 0);
r.Main_OnCommand(40044, 0);

--=====================
r.PreventUIRefresh(-1);
r.Undo_EndBlock(d, -1) --
