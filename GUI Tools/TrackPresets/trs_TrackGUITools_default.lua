-- @description Tracks GUI Tools Default Preset
-- @author Taras Umanskiy

-- Получаем путь к самому скрипту
local _, script_path = reaper.get_action_context()
script_path = script_path:match("^(.*[\\/])")
--------------------------------
-- 1. taras color.txt
--------------------------------
local file1_path = script_path .. "TrackPresets/default color.txt"
local file1_exists = io.open(file1_path, "r")

if file1_exists then
  file1_exists:close()
else
  local file1, err1 = io.open(file1_path, "w")
  if not file1 then
    reaper.ShowMessageBox("Не удалось открыть default color.txt:\n" .. tostring(err1), "Ошибка", 0)
    return
  end

  file1:write([[
INSTRUM,Delay,Reverb,Filter,Mod,FX,false,false
MIX,Click,MUSIC,NEW,OLD,DRM,false,false
REFERENCE,MIX,DEMO,PlayBack,LIVE,STUDIO,false,false
DRM,SUM,FX,DBL,BUS,,false,#EC0744
Drums,Comp,PR,Verb,MIDI,,false,#C40002
Kick,in,out,Sub,DIR,,false,#AD5BFF
Snare,Top,Bot,Rim,trg,,false,#885BFF
Clap,L,R,1,2,,false,#A05EFA
Tom,1,2,3,trg,,false,#6D3EFD
Tom,Alt,Rack,Floor,trg,,false,#594EF8
HiHat,O,C,1,2,,false,#047ED0
Crash,L,R,3,4,,false,#009FD5
China,L,R,5,6,,false,#009FD5
Ride,Bell,Cow,7,8,,false,#009FD5
Splash,L,R,9,10,,false,#009FD5
OH,L,R,OverHeads,AMB,,false,#0CDEC3
RM,Mid,Side,Mono,BUS,,false,#0CDEC3
Room,Near,Far,Crush,Room,,false,#0CDEC3
,on_Axis,off_Axis,Cap,Cone,Edge,false,false
BASS,DI,Sub,Lo,Hi,,false,#A13D00
GTR,L,R,DI,BUS,,false,#6AD500
GTR,Cln,Dist,Amp,Cab,,false,#9FD500
GTRS,RTM,lead,solo,Add,,false,#D5D500
,Dyn,Cond,ЗБС,Tape,Warm,false,false
Synth,Lead,Chrds,Pluck,Arp,,false,#00D7C5
Synths,Pad,SEQ,Atmo,Sub,,false,#6BD550
Keys,Хуейс,Piano,Melody,BUS,,false,#D0D75A
Strings,Ensemble,Cellos,Violas,Violins,Хуелинс,false,#B25AD7
,SingAlong,SFX,Pitch,Dry,Wet,false,false
VOX,DBl,Bck,Low,Mid,High,false,#FF8000
VOС,Cln,Scr,Grl,Wishper,Harmony,false,#C86300
Voсal,Verse,Chorus,Main,Flow,BUS,false,#A25000
##PAN##
0
5
10
15
20
25
30
35
40
45
50
55
60
65
70
75
80
85
90
95
100
]])
  file1:close()
end

--------------------------------
-- 2. user color.txt
--------------------------------
local file2_path = script_path .. "TrackPresets/user color.txt"
local file2_exists = io.open(file2_path, "r")

if file2_exists then
  file2_exists:close()
else
  local file2, err2 = io.open(file2_path, "w")
  if not file2 then
    reaper.ShowMessageBox("Не удалось открыть user color.txt:\n" .. tostring(err2), "Ошибка", 0)
    return
  end

  file2:write([[
INSTRUM,Delay,Reverb,Filter,Mod,FX,false,#C40000
REFERENCE,MIX,DEMO,PlayBack,LIVE,STUDIO,false,false
,SUM,FX,DBL,BUS,,0,false
BASS,DI,Sub,Lo,Hi,,25,#0080FF
GTR,L,R,DI,BUS,,50,#6AD500
Synth,Lead,Chrds,Pluck,Arp,,75,#CCD700
Keys,Хуейс,Piano,Melody,BUS,,90,#BEAA00
Strings,Ensemble,Cellos,Violas,Violins,,100,#00C2D7
Vox,,Bck,Low,Mid,High,false,#FF8000
##PAN##
0
5
10
15
20
25
30
35
40
45
50
55
60
65
70
75
80
85
90
95
100
]])
  file2:close()
end


-- Получаем путь к самому скрипту
local _, script_path = reaper.get_action_context()
script_path = script_path:match("^(.*[\\/])")
--------------------------------
-- 1. taras color.txt
--------------------------------
local file1_path = script_path .. "TrackPresets/default.txt"
local file1_exists = io.open(file1_path, "r")

if file1_exists then
  file1_exists:close()
else
  local file1, err1 = io.open(file1_path, "w")
  if not file1 then
    reaper.ShowMessageBox("Не удалось открыть default.txt:\n" .. tostring(err1), "Ошибка", 0)
    return
  end

  file1:write([[
INSTRUM,Delay,Reverb,Filter,Mod,FX,false,false
MIX,Click,MUSIC,NEW,OLD,DRM,false,false
REFERENCE,MIX,DEMO,PlayBack,LIVE,STUDIO,false,false
,SUM,FX,DBL,BUS,,false,false
Drums,Comp,PR,Verb,MIDI,,false,false
Kick,in,out,Sub,DIR,,false,false
Snare,Top,Bot,Rim,trg,,false,false
Clap,L,R,1,2,,false,false
Tom,1,2,3,trg,,false,false
Tom,Alt,Rack,Floor,trg,,false,false
HiHat,O,C,1,2,,false,false
Crash,L,R,3,4,,false,false
China,L,R,5,6,,false,false
Ride,Bell,Cow,7,8,,false,false
Splash,L,R,9,10,,false,false
OH,L,R,OverHeads,BUS,,false,false
RM,Mid,Side,Mono,BUS,,false,false
Room,Near,Far,Crush,Room,,false,false
,on_Axis,off_Axis,Cap,Cone,Edge,false,false
BASS,DI,Sub,Lo,Hi,,false,false
GTR,L,R,DI,BUS,,false,false
GTR,Cln,Dist,Amp,Cab,,false,false
GTRS,rtm,lead,solo,Add,,false,false
,Dyn,Cond,ЗБС,Tape,Warm,false,false
Synth,Lead,Chrds,Pluck,Arp,,false,false
Synths,Pad,SEQ,Atmo,Sub,,false,false
Keys,Хуейс,Piano,Melody,BUS,,false,false
Strings,Ensemble,Cellos,Violas,Violins,Хуелинс,false,false
,SingAlong,SFX,Pitch,Dry,Wet,false,false
VOX,DBl,Bck,Low,Mid,High,false,false
VOС,Cln,Scr,Grl,Wishper,Harmony,false,false
Voсal,Verse,Chorus,Main,Flow,BUS,false,false
##PAN##
0
5
10
15
20
25
30
35
40
45
50
55
60
65
70
75
80
85
90
95
100
]])
  file1:close()
end


-- Получаем путь к самому скрипту
local _, script_path = reaper.get_action_context()
script_path = script_path:match("^(.*[\\/])")
--------------------------------
-- 1. taras color.txt
--------------------------------
local file1_path = script_path .. "TrackPresets/user.txt"
local file1_exists = io.open(file1_path, "r")

if file1_exists then
  file1_exists:close()
else
  local file1, err1 = io.open(file1_path, "w")
  if not file1 then
    reaper.ShowMessageBox("Не удалось открыть user.txt:\n" .. tostring(err1), "Ошибка", 0)
    return
  end

  file1:write([[
DRUMS,Delay,Reverb,Filter,Mod,FX,false,false
BASS,DI,Sub,Lo,Hi,,false,false
GTR,L,R,DI,BUS,,false,false
Synth,Lead,Chrds,Pluck,Arp,,false,false
Keys,Хуейс,Piano,Melody,BUS,,false,false
Strings,Ensemble,Cellos,Violas,Violins,Хуелинс,false,false
VOX,DBl,Bck,Low,Mid,High,false,false
]])
  file1:close()
end
