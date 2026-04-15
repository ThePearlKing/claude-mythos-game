-- Unlockable music themes. Each theme = builder function returning a LOVE Source.
-- Sources are lazily built the first time a theme is played.

local Playlist = {}

local always = function() return true end

Playlist.themes = {
    {id="default",   name="Hacker Cyberpunk",  desc="The signature driving acid track.",                hint="Default",                         unlock=always},
    {id="synthwave", name="Neon Dusk",         desc="Warm melodic synthwave.",                          hint="Win 2 runs",                      unlock=function(p) return (p.totalWins or 0) >= 2 end},
    {id="chiptune",  name="8-Bit Clawde",      desc="Retro square-wave arcade.",                        hint="Kill 250 enemies",                 unlock=function(p) return (p.totalKills or 0) >= 250 end},
    {id="doom",      name="Crabhammer",        desc="Heavy distorted darksynth.",                       hint="Best streak >= 3",                 unlock=function(p) return (p.bestStreak or 0) >= 3 end},
    {id="lofi",      name="Ocean Lofi",        desc="Mellow beats and soft chords.",                    hint="Global Rep >= 65",                 unlock=function(p) return math.max(p.globalRepMax or 0, p.globalRep or 0) >= 65 end},
    {id="eldritch_theme", name="Whisperwave",  desc="Dissonant drones. Reality drifts.",                hint="Eldritch level >= 6 in a run",     unlock=function(p) return (p.eldritchMax or 0) >= 6 end},
    {id="vapor",     name="Sunken Vapor",      desc="Slow, dreamy, underwater.",                        hint="Win 5 runs total",                 unlock=function(p) return (p.totalWins or 0) >= 5 end},
    {id="jazz",      name="Midnight Jazz",     desc="Smoky walking bass and brushed drums.",            hint="Win 3 runs on Hard+",              unlock=function(p) return (p.hardWins or 0) >= 3 end},
    {id="drumnbass", name="Crab & Bass",       desc="Fast breakbeats, sub-heavy chaos.",                hint="Kill 4000 enemies",                unlock=function(p) return (p.totalKills or 0) >= 4000 end},
    {id="choir",     name="Chorale Abyssum",   desc="Sacred choir singing into dread.",                 hint="WIN a run at eldritch >= 12",      unlock=function(p) return (p.winEldritchMax or 0) >= 12 end},
    {id="arcade",    name="Arcade Fury",       desc="Frantic 8-bit boss shuffle.",                      hint="Best streak >= 6",                 unlock=function(p) return (p.bestStreak or 0) >= 6 end},
}

function Playlist.isUnlocked(theme, persist)
    return theme.unlock(persist or {})
end

function Playlist.getTheme(id)
    for _, t in ipairs(Playlist.themes) do
        if t.id == id then return t end
    end
    return Playlist.themes[1]
end

function Playlist.defaultId() return "default" end

return Playlist
