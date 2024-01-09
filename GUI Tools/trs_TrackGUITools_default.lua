-- @description Tracks GUI Tools Default Preset
-- @author Taras Umanskiy
-- @version 1.0
-- @metapackage
-- @provides [main] .
-- @link http://vk.com/tarasmetal
-- @donation https://paypal.me/Tarasmetal
-- @about
--   # Tracks GUI Tools
-- @changelog
--  + Code optimizations

-- таблица со списком кнопок c параметрами которые нужно выводить.
track_set = {
  {
        text = 'INSTRUM',
        color = false,
        text_left = 'Delay',
        text_right = 'Reverb',
        text_center = 'Filter',
        text_add = 'Mod',
        text_end = 'FX',
        pan = false,

    },
    {
        text = '',
        color = false,
        text_left = 'Click',
        text_right = 'MUSIC',
        text_center = 'NEW',
        text_add = 'OLD',
        text_end = 'DRM',
        pan = false,

    },
     {
        text = 'REFERENCE',
        color = false,
        text_left = 'MIX',
        text_right = 'DEMO',
        text_center = 'PlayBack',
        text_add = 'LIVE',
        text_end = 'STUDIO',
        pan = false,
    },
    {
        text = 'MIX',
        color = false,
        text_left = 'SUM',
        text_right = 'FX',
        text_center = 'DBL',
        text_add = 'BUS',
        pan = 0,

    },
    {
        text = 'Drums',
        color = false,
        text_left = 'Comp',
        text_right = 'PR',
        text_center = 'Verb',
        text_add = 'MIDI',
        pan = 5,
    },
    {
        text = 'Kick',
        color = false,
        text_left = 'in',
        text_right = 'out',
        text_center = 'Sub',
        text_add = 'DIR',
        pan = 10,
    },
    {
        text = 'Snare',
        color = false,
        text_left = 'Top',
        text_right = 'Bot',
        text_center = 'Rim',
        text_add = 'trg',
        pan = 15,

    },
     {
        text = 'Clap',
        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = '1',
        text_add = '2',
        pan = 20,

    },
    {
        text = 'Tom',
        color = false,
        text_left = '1',
        text_right = '2',
        text_center = '3',
        text_add = 'trg',
        pan = 25,

    },
    {
        text = 'Tom',
        color = false,
        text_left = 'Alt',
        text_right = 'Rack',
        text_center = 'Floor',
        text_add = 'trg',
        pan = 30,

    },
    {
        text = 'HiHat',
        color = false,
        text_left = 'O',
        text_right = 'C',
        text_center = '1',
        text_add = '2',
        pan = 35,
    },
    {
        text = 'Crash',
        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = '3',
        text_add = '4',
        pan = 40,

    },
    {
        text = 'China',
        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = '5',
        text_add = '6',
        pan = 45,

    },
    {
        text = 'Ride',
        color = false,
        text_left = 'Bell',
        text_right = 'Cow',
        text_center = '7',
        text_add = '8',
        pan = 50,
    },
    {
        text = 'Splash',
        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = '9',
        text_add = '10',
        pan = 55,
    },
    {
        text = 'OH',

        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = 'OverHeads',
        text_add = 'BUS',
        pan = 60,

    },
    {
        text = 'RM',
        color = false,
        text_left = 'Mid',
        text_right = 'Side',
        text_center = 'Mono',
        text_add = 'BUS',
        pan = 65,

    },
    {
        text = 'Room',
        color = false,
        text_left = 'Near',
        text_right = 'Far',
        text_center = 'Crush',
        text_add = 'Room',
        pan = 70,

    },
     {
        text = '',
        color = false,
        text_left = 'on_Axis',
        text_right = 'off_Axis',
        text_center = 'Cap',
        text_add = 'Cone',
        text_end = 'Edge',
        pan = false,
    },
     {
        text = 'BASS',
        color = false,
        text_left = 'DI',
        text_right = 'Sub',
        text_center = 'Lo',
        text_add = 'Hi',
        pan = 75,

    },
     {
        text = 'GTR',
        color = false,
        text_left = 'L',
        text_right = 'R',
        text_center = 'DI',
        text_add = 'BUS',
        pan = 80,

    },
     {
        text = 'GTR',
        color = false,
        text_left = 'Cln',
        text_right = 'Dist',
        text_center = 'Amp',
        text_add = 'Cab',
        pan = 85,

    },
     {
        text = 'GTRS',
        color = false,
        text_left = 'rtm',
        text_right = 'lead',
        text_center = 'solo',
        text_add = 'Add',
        pan = 90,

    },
    {
        text = '',
        color = false,
        text_left = 'Dyn',
        text_right = 'Cond',
        text_center = 'ЗБС',
        text_add = 'Tape',
        text_end = 'Warm',
        pan = false,

    },
     {
        text = 'Synth',
        color = false,
        text_left = 'Lead',
        text_right = 'Chrds',
        text_center = 'Pluck',
        text_add = 'Arp',
        pan = 95,

    },
     {
        text = 'Synths',
        color = false,
        text_left = 'Pad',
        text_right = 'SEQ',
        text_center = 'Atmo',
        text_add = 'Sub',
        pan = 100,

    },
     {
        text = 'Keys',
        color = false,
        text_left = 'Хуейс',
        text_right = 'Piano',
        text_center = 'Melody',
        text_add = 'BUS',
        pan = false,

    },
    {
        text = 'Strings',
        color = false,
        text_left = 'Ensemble',
        text_right = 'Cellos',
        text_center = 'Violas',
        text_add = 'Violins',
        pan = false,

    },
    {
        text = '',
        color = false,
        text_left = 'SingAlong',
        text_right = 'SFX',
        text_center = 'Pitch',
        text_add = 'Dry',
        text_end = 'Wet',
        pan = false,

    },
    {
        text = 'Vox',
        color = false,
        text_left = 'DBL',
        text_right = 'BCK',
        text_center = 'Low',
        text_add = 'Mid',
        text_end = 'High',
        pan = false,

    },
    {
        text = 'Vox',
        color = false,
        text_left = 'Cln',
        text_right = 'Scr',
        text_center = 'Grl',
        text_add = 'Wishper',
        text_end = 'Harmony',
        pan = false,

    },
     {
        text = 'Vox',
        color = false,
        text_left = 'Verse',
        text_right = 'Chorus',
        text_center = 'Main',
        text_add = 'Flow',
        text_end = 'BUS',
        pan = false,

    },
}