-- Cosmetics: per-slot items with unlock predicates. Persisted via Save.
-- Items can have:
--   id           : short unique key
--   name         : display name (shown to user)
--   secretName   : optional name revealed only when unlocked
--   color        : {r,g,b} OR special "rainbow" string for body hue cycling
--   pattern      : optional multicolor pattern key (body only): "galaxy","camo",
--                  "stripes","dots","marble","stars","checker","lava","aurora"
--   secondary    : optional second color used by patterns
--   hint         : text shown when locked
--   unlock(p)    : predicate given persist table
--
-- Slot categories: body, eye, claw, hat, trail.

local C = {}

local function always() return true end

-- ========================================================================
-- UNLOCK PREDICATE HELPERS
-- ========================================================================
local function kills(n)       return function(p) return (p.totalKills      or 0) >= n end end
local function wins(n)        return function(p) return (p.totalWins       or 0) >= n end end
local function streak(n)      return function(p) return (p.bestStreak      or 0) >= n end end
-- Rep unlocks check the lifetime MAX rep so cosmetics never re-lock if your
-- current reputation drifts below the threshold later.
local function rep(n)         return function(p) return math.max(p.globalRepMax or 0, p.globalRep or 0) >= n end end
local function eldMax(n)      return function(p) return (p.eldritchMax     or 0) >= n end end
local function winEld(n)      return function(p) return (p.winEldritchMax  or 0) >= n end end
local function slug()         return function(p) return (p.slugcrabUnlocked or 0) == 1 end end
local function hardWins(n)    return function(p) return (p.hardWins        or 0) >= n end end
local function nightmareWins(n) return function(p) return (p.nightmareWins or 0) >= n end end
local function apocalypseWins(n) return function(p) return (p.apocalypseWins or 0) >= n end end
local function bossKills(n)   return function(p) return (p.bossKills       or 0) >= n end end
local function totalRuns(n)   return function(p) return (p.totalRuns       or 0) >= n end end

-- ========================================================================
-- COSMETICS
-- ========================================================================
C.items = {
    -- ============================ BODY ============================
    body = {
        -- Defaults + Claude brand palette
        {id="orange",       name="Classic Orange",    color={1.00, 0.55, 0.15}, hint="Default",           unlock=always},
        {id="claude_ember", name="Claude Ember",      color={0.85, 0.46, 0.34}, hint="Claude palette",    unlock=always},
        {id="claude_cream", name="Claude Cream",      color={0.96, 0.90, 0.80}, hint="Claude palette",    unlock=always},
        {id="claude_mocha", name="Claude Mocha",      color={0.70, 0.55, 0.40}, hint="Claude palette",    unlock=always},
        {id="claude_slate", name="Claude Slate",      color={0.28, 0.26, 0.32}, hint="Claude palette",    unlock=always},

        -- Easier earned solid colors
        {id="red",          name="Crimson Shell",     color={1.00, 0.25, 0.25}, hint="Win 1 run",                   unlock=wins(1)},
        {id="yellow",       name="Canary Shell",      color={1.00, 0.92, 0.25}, hint="Win 2 runs",                  unlock=wins(2)},
        {id="blue",         name="Azure Pincer",      color={0.30, 0.55, 1.00}, hint="Kill 150 enemies",            unlock=kills(150)},
        {id="cyan",         name="Tidal Cyan",        color={0.25, 0.90, 0.95}, hint="Kill 250 enemies",            unlock=kills(250)},
        {id="gold",         name="Goldshell",         color={1.00, 0.85, 0.25}, hint="Reach 3-win streak",          unlock=streak(3)},
        {id="green",        name="Mossback",          color={0.30, 0.90, 0.40}, hint="Global Rep >= 70",            unlock=rep(70)},
        {id="pink",         name="Coral",             color={1.00, 0.55, 0.75}, hint="Win 5 runs total",            unlock=wins(5)},
        {id="magenta",      name="Fuchsia Pincer",    color={1.00, 0.20, 0.70}, hint="Win 7 runs total",            unlock=wins(7)},
        {id="veteran",      name="Veteran Carapace",  color={0.30, 0.70, 0.55}, hint="Win 10 runs total",           unlock=wins(10)},
        {id="silver",       name="Silver Carapace",   color={0.78, 0.80, 0.85}, hint="Kill 600 enemies",            unlock=kills(600)},
        {id="bronze",       name="Bronze Carapace",   color={0.70, 0.45, 0.22}, hint="Best streak >= 4",            unlock=streak(4)},
        {id="forest",       name="Forest Green",      color={0.08, 0.45, 0.15}, hint="Win 4 runs",                  unlock=wins(4)},
        -- Black & White: crisp monochrome — pure white body, black outline + legs
        {id="white",        name="Black&White",       color={1.00, 1.00, 1.00}, secondary={0.08, 0.08, 0.10},
            hint="Win 2 runs",                                                                                   unlock=wins(2)},
        -- Flashbang: pure #FFFFFF body, #FFFFFF outline/legs (invisible against light backgrounds)
        {id="flashbang",    name="Flashbang",         color={1.00, 1.00, 1.00}, secondary={1.00, 1.00, 1.00},
            hint="Win 3 runs on Apocalypse",                                                                     unlock=apocalypseWins(3)},
        -- Cotton Candy: blue body, pink outline + pink legs (secondary used without a pattern).
        {id="cotton_candy", name="Cotton Candy",      color={0.50, 0.75, 1.00}, secondary={1, 0.55, 0.85},
            hint="Win 4 runs",                                                                                   unlock=wins(4)},

        -- Harder solid colors
        {id="dark_red",     name="Blackheart",        color={0.45, 0.05, 0.05}, hint="Win 3 runs on Hard+",         unlock=hardWins(3)},
        {id="dark_blue",    name="Deepwater",         color={0.05, 0.15, 0.40}, hint="Kill 3000 enemies",           unlock=kills(3000)},
        {id="dark_green",   name="Rotvine",           color={0.05, 0.25, 0.10}, hint="Win a run on Nightmare+",     unlock=nightmareWins(1)},
        {id="dark_purple",  name="Nightbloom",        color={0.22, 0.05, 0.35}, hint="Eldritch level >= 10 in a run", unlock=eldMax(10)},
        {id="dark_orange",  name="Rust Carapace",     color={0.42, 0.18, 0.05}, hint="Win 3 runs on Hard+",         unlock=hardWins(3)},
        {id="dark_slate",   name="Obsidian",          color={0.08, 0.08, 0.12}, hint="Win 2 runs on Nightmare+",    unlock=nightmareWins(2)},

        -- Earned (legacy)
        {id="purple",       name="Umbral Chitin",     color={0.70, 0.30, 1.00}, hint="Eldritch level >= 6 in a run", unlock=eldMax(6)},
        {id="shadow",       name="Shadow Form",       color={0.30, 0.30, 0.40}, hint="Eldritch level >= 4 in a run", unlock=eldMax(4)},
        {id="rainbow",      name="Prismatic",         color="rainbow",          hint="Best streak >= 5",            unlock=streak(5)},
        {id="abyssal",      name="Abyssal Chitin",    color={0.18, 0.05, 0.28}, hint="WIN a run at eldritch >= 8",  unlock=winEld(8)},

        -- Multicolor patterns (primary color used for derived parts — tail/ears/eyes).
        -- Tuned to be genuinely hard: most sit behind Hard+/Nightmare/Apocalypse wins.
        {id="camo",         name="Camo",              color={0.30, 0.45, 0.20}, secondary={0.15, 0.25, 0.08}, pattern="camo",
            hint="Kill 1500 enemies",                unlock=kills(1500)},
        {id="stripes",      name="Striped Reef",      color={0.95, 0.80, 0.25}, secondary={0.25, 0.20, 0.10}, pattern="stripes",
            hint="Win 3 runs on Hard+",              unlock=hardWins(3)},
        {id="spots",        name="Dotted Deep",       color={0.30, 0.55, 1.00}, secondary={1, 1, 1}, pattern="dots",
            hint="Kill 3000 enemies",                unlock=kills(3000)},
        {id="aurora",       name="Aurora",            color={0.10, 0.55, 0.55}, secondary={1.00, 0.30, 0.80}, pattern="aurora",
            hint="Win at eldritch >= 10",            unlock=winEld(10)},
        {id="lava",         name="Lava Flow",         color={0.9, 0.25, 0.05},  secondary={1, 0.85, 0.20}, pattern="lava",
            hint="Kill 5000 enemies",                unlock=kills(5000)},
        {id="marble",       name="Marbled Shell",     color={0.92, 0.92, 0.95}, secondary={0.25, 0.25, 0.35}, pattern="marble",
            hint="Win 2 runs on Nightmare+",         unlock=nightmareWins(2)},
        {id="galaxy",       name="Galaxy",            color={0.25, 0.08, 0.45}, secondary={1, 1, 1}, pattern="galaxy",
            hint="WIN a run at eldritch >= 18",      unlock=winEld(18)},
        {id="checker",      name="Checker",           color={0.95, 0.95, 0.95}, secondary={0.08, 0.08, 0.10}, pattern="checker",
            hint="Best streak >= 10",                unlock=streak(10)},
        {id="prism",        name="Prism Scales",      color={0.50, 0.80, 1.00}, secondary={1.00, 0.90, 0.60}, pattern="stripes",
            hint="Best streak >= 12",                unlock=streak(12)},
        {id="voidmarble",   name="Void Marble",       color={0.12, 0.02, 0.22}, secondary={0.80, 0.30, 1.00}, pattern="marble",
            hint="WIN a run at eldritch >= 20",      unlock=winEld(20)},
        {id="bloodmoon",    name="Bloodmoon",         color={0.55, 0.05, 0.10}, secondary={1.00, 0.30, 0.20}, pattern="stars",
            hint="Win 2 runs on Apocalypse",         unlock=apocalypseWins(2)},

        -- Churgly'nth body — endgame eldritch unlock. Slightly darker purple
        -- (no black) so it pairs cleanly with the Churgly'nth Eyes face.
        {id="churglynth",   name="Churgly'nth",        color={0.22, 0.08, 0.32}, secondary={0.55, 0.15, 0.90}, pattern="churgly",
            hint="WIN a run at eldritch >= 24",      unlock=winEld(24)},

        -- Secret
        {id="slugcrab",     name="???", secretName="Slugcrab", color={1, 1, 1},  hint="???",               unlock=slug()},
    },

    -- ============================ EYES ============================
    eye = {
        {id="normal",     name="Normal Eyes",     hint="Default",                     unlock=always},
        {id="cute",       name="Cute Eyes",       hint="Win 2 runs",                  unlock=wins(2)},
        {id="happy",      name="Happy Eyes",      hint="Win 1 run",                   unlock=wins(1)},
        {id="cyber",      name="Cyber Lenses",    hint="Kill 100 enemies",            unlock=kills(100)},
        {id="angry",      name="Furious Glare",   hint="Kill 500 enemies",            unlock=kills(500)},
        {id="sleepy",     name="Sleepy Eyes",     hint="Global Rep >= 55",            unlock=rep(55)},
        {id="heart",      name="Heart Eyes",      hint="Win 6 runs",                  unlock=wins(6)},
        {id="spiral",     name="Spiral Eyes",     hint="Take 5 eldritch cards",       unlock=function(p) return (p.eldritchMax or 0) >= 5 end},
        {id="third",      name="Third Eye",       hint="Eldritch level >= 5 in a run", unlock=eldMax(5)},
        {id="many",       name="Many Eyes",       hint="Eldritch level >= 13 in a run", unlock=eldMax(13)},
        -- Harder
        {id="frozen",     name="Frozen Gaze",     hint="Win 2 runs on Hard+",         unlock=hardWins(2)},
        {id="fire",       name="Fire Eyes",       hint="Win 2 runs on Nightmare+",    unlock=nightmareWins(2)},
        {id="skull",      name="Hollow Sockets",  hint="Kill 4000 enemies",           unlock=kills(4000)},
        {id="crystal",    name="Crystal Eyes",    hint="Kill 2000 enemies",           unlock=kills(2000)},
        {id="rune",       name="Rune-etched",     hint="Win 3 runs at eldritch >= 6", unlock=winEld(6)},
        {id="vacant",     name="Vacant Stare",    hint="Reach wave 30 (infinite)",    unlock=function(p) return (p.deepestWave or 0) >= 30 end},
        {id="void_gaze",  name="Void Gaze",       hint="WIN a run at eldritch >= 10", unlock=winEld(10)},
        {id="churgly_eyes", name="Churgly'nth Eyes", hint="WIN a run at eldritch >= 18", unlock=winEld(18)},
        -- Secret
        {id="slugcrab",   name="???", secretName="Slugcrab Eyes", hint="???",          unlock=slug()},
    },

    -- ============================ CLAWS ============================
    claw = {
        {id="normal",     name="Normal Claws",    hint="Default",                     unlock=always},
        {id="small",      name="Tiny Pincers",    hint="Win 1 run",                   unlock=wins(1)},
        {id="wide",       name="Wide Pincers",    hint="Kill 200 enemies",            unlock=kills(200)},
        {id="spiked",     name="Spiked Claws",    hint="Kill 400 enemies",            unlock=kills(400)},
        {id="crystal",    name="Crystal Claws",   hint="Win 3 runs",                  unlock=wins(3)},
        {id="leaf",       name="Leaf Claws",      hint="Global Rep >= 65",            unlock=rep(65)},
        {id="skeletal",   name="Skeletal Claws",  hint="Kill 1200 enemies",           unlock=kills(1200)},
        {id="cursed",     name="Cursed Claws",    hint="Eldritch level >= 5 in a run", unlock=eldMax(5)},
        -- Harder
        {id="chain",      name="Chained Claws",   hint="Win 3 runs on Hard+",         unlock=hardWins(3)},
        {id="obsidian",   name="Obsidian Claws",  hint="Win 2 runs on Nightmare+",    unlock=nightmareWins(2)},
        {id="saw",        name="Bone-Saw Claws",  hint="Kill 5000 enemies",           unlock=kills(5000)},
        {id="prism",      name="Prism Claws",     hint="Best streak >= 7",            unlock=streak(7)},
        {id="molten",     name="Molten Claws",    hint="Kill 1000 enemies",           unlock=kills(1000)},
        {id="churgly",    name="Churgly's Grasp", hint="WIN a run at eldritch >= 12", unlock=winEld(12)},
        {id="churgly_jaws", name="Churgly's Maws", hint="WIN a run at eldritch >= 20", unlock=winEld(20)},
    },

    -- ============================ HATS ============================
    hat = {
        {id="none",       name="No Hat",          hint="Default",                     unlock=always},
        {id="tophat",     name="Top Hat",         hint="Win 1 run",                   unlock=wins(1)},
        {id="beanie",     name="Beanie",          hint="Win 2 runs",                  unlock=wins(2)},
        {id="cap",        name="Backwards Cap",   hint="Kill 250 enemies",            unlock=kills(250)},
        {id="crown",      name="Crown",           hint="Best streak >= 3",            unlock=streak(3)},
        {id="hood",       name="Hacker Hood",     hint="Global Rep >= 80",            unlock=rep(80)},
        {id="tinfoil",    name="Tinfoil Hat",     hint="Kill 300 enemies",            unlock=kills(300)},
        {id="halo",       name="Halo",            hint="Best streak >= 5",            unlock=streak(5)},
        {id="horns",      name="Dark Horns",      hint="Eldritch level >= 7 in a run", unlock=eldMax(7)},
        {id="antlers",    name="Antlers",         hint="Win 6 runs",                  unlock=wins(6)},
        -- Harder
        {id="wizard",     name="Wizard Hat",      hint="Eldritch level >= 8 in a run", unlock=eldMax(8)},
        {id="cowboy",     name="Cowboy Hat",      hint="Win 3 runs on Hard+",         unlock=hardWins(3)},
        {id="helmet",     name="Battle Helmet",   hint="Win 2 runs on Nightmare+",    unlock=nightmareWins(2)},
        {id="pirate",     name="Pirate Hat",      hint="Best streak >= 6",            unlock=streak(6)},
        {id="fin",        name="Shark Fin",       hint="Kill 3500 enemies",           unlock=kills(3500)},
        {id="cap_spike",  name="Spiked Helm",     hint="Kill 8000 enemies",           unlock=kills(8000)},
        {id="deepcrown",  name="Crown of the Deep", hint="WIN a run at eldritch >= 15", unlock=winEld(15)},
        -- Secret
        {id="slugears",   name="???", secretName="Slugcrab Ears", hint="???",          unlock=slug()},
    },

    -- ============================ GUNS ============================
    -- 10 starter weapon skins (all default-unlocked) + 1 secret from the Void Sea.
    -- Each entry's draw function runs inside the claw/weapon rotation frame, so
    -- coordinates are local to the barrel hand (x=self.r marks the muzzle base).
    gun = {
        {id="pistol",     name="Pistol",         hint="Default", unlock=always},
        {id="compact",    name="Compact",        hint="Default", unlock=always},
        {id="magnum",     name="Magnum",         hint="Default", unlock=always},
        {id="rifle",      name="Rifle",          hint="Default", unlock=always},
        {id="shotgun",    name="Shotgun",        hint="Default", unlock=always},
        {id="smg",        name="Sub-machine",    hint="Default", unlock=always},
        {id="blaster",    name="Blaster",        hint="Default", unlock=always},
        {id="cannon",     name="Cannon",         hint="Default", unlock=always},
        {id="crossbow",   name="Crossbow",       hint="Default", unlock=always},
        {id="musket",     name="Musket",         hint="Default", unlock=always},
        -- Slightly hard-to-get
        {id="nailgun",    name="Nailgun",        hint="Kill 1500 enemies",            unlock=kills(1500)},
        {id="handcannon", name="Hand Cannon",    hint="Best streak >= 6",             unlock=streak(6)},
        {id="sniper",     name="Bolt Sniper",    hint="Win 3 runs on Hard+",          unlock=hardWins(3)},
        {id="glauncher",  name="Grenade Launcher", hint="Kill 4000 enemies",          unlock=kills(4000)},
        -- Eldritch: unlocks by reaching eldritch level 16 in a run
        {id="dark_magic", name="Dark Magic",    hint="Eldritch level >= 16 in a run", unlock=function(p) return (p.eldritchMax or 0) >= 16 end},
        -- Kill a shrimp spirit (haunted runs) to unlock the psychic telekinesis weapon
        {id="telekinesis", name="Telekinesis",  hint="Kill a shrimp spirit",          unlock=function(p) return (p.shrimpKills or 0) >= 1 end},
        -- Eldritch counterpart — purple, warped, reality-bending
        {id="reality_bend", name="Reality Bend", hint="Own Telekinesis AND eldritch >= 8 in a run",
            unlock=function(p) return (p.shrimpKills or 0) >= 1 and (p.eldritchMax or 0) >= 8 end},
        -- More hard-to-get (mid-tier)
        {id="flamethrower", name="Flamethrower", hint="Win 2 runs on Hard+",          unlock=hardWins(2)},
        {id="sawedoff",   name="Sawed-Off",      hint="Best streak >= 5",             unlock=streak(5)},
        {id="gatling",    name="Gatling",        hint="Kill 2500 enemies",            unlock=kills(2500)},
        {id="icegun",     name="Frost Cannon",   hint="Win 8 runs",                   unlock=wins(8)},
        {id="scythe",     name="Reaper's Scythe", hint="Eldritch level >= 14 in a run", unlock=eldMax(14)},
        -- Very challenging
        {id="plasma",     name="Plasma Cannon",  hint="Win a run on Apocalypse",      unlock=apocalypseWins(1)},
        {id="lightning_rod", name="Lightning Rod", hint="Best streak >= 15",          unlock=streak(15)},
        {id="chainsword", name="Chainsword",     hint="Kill 8000 enemies",            unlock=kills(8000)},
        {id="quantum",    name="Quantum Pistol", hint="WIN a run at eldritch >= 22",  unlock=winEld(22)},
        -- Void Sea secret — the spear from the ascension (replaces the auto-spear behavior)
        {id="void_spear", name="???", secretName="Void Spear", hint="???", unlock=slug()},
    },

    -- ============================ TRAILS ============================
    trail = {
        {id="none",       name="No Trail",        hint="Default",                     unlock=always},
        {id="sparkle",    name="Sparkles",        hint="Global Rep >= 60",            unlock=rep(60)},
        {id="fire",       name="Fire Trail",      hint="Kill 400 enemies",            unlock=kills(400)},
        {id="data",       name="Data Stream",     hint="Win 5 runs",                  unlock=wins(5)},
        {id="bubbles",    name="Bubbles",         hint="Win 2 runs",                  unlock=wins(2)},
        {id="petals",     name="Flower Petals",   hint="Global Rep >= 75",            unlock=rep(75)},
        {id="void",       name="Void Mist",       hint="Eldritch level >= 6 in a run", unlock=eldMax(6)},
        {id="slug",       name="Slugcrab Tail",   hint="Unlock the Slugcrab secret",  unlock=slug()},
        {id="shiny",      name="Shiny",           hint="Win 8 runs total",            unlock=wins(8)},
        -- Harder
        {id="lightning",  name="Lightning",       hint="Win 4 runs on Hard+",         unlock=hardWins(4)},
        {id="shadow",     name="Shadow",          hint="Win 2 runs on Nightmare+",    unlock=nightmareWins(2)},
        {id="music",      name="Music Notes",     hint="Kill 3000 enemies",           unlock=kills(3000)},
        {id="runes",      name="Floating Runes",  hint="Win at eldritch >= 6",        unlock=winEld(6)},
        {id="chaos",      name="Chaos",           hint="Win a run on Apocalypse",     unlock=apocalypseWins(1)},
        {id="super_saiyan", name="Super Saiyan",  hint="Global Rep >= 85",            unlock=rep(85)},
        {id="wake",       name="Wake of Horrors", hint="WIN a run at eldritch >= 18", unlock=winEld(18)},
        {id="ugnrak",     name="Ugnrak",          hint="???", secretName="Ugnrak",
            unlock=function(p) return (p.churglyDefeated or 0) == 1 end},
    },
}

-- ========================================================================
-- API
-- ========================================================================

function C.isUnlocked(item, persist)
    return item.unlock(persist or {})
end

function C.getItem(slot, id)
    for _, item in ipairs(C.items[slot] or {}) do
        if item.id == id then return item end
    end
    return (C.items[slot] or {})[1]
end

function C.equipped(persist)
    persist = persist or {}
    local raw = persist.cosmetics or ""
    local eq = {}
    for k, v in string.gmatch(raw, "([%w_]+):([%w_]+)") do
        eq[k] = v
    end
    eq.body  = eq.body  or "orange"
    eq.eye   = eq.eye   or "normal"
    eq.claw  = eq.claw  or "normal"
    eq.hat   = eq.hat   or "none"
    eq.trail = eq.trail or "none"
    eq.gun   = eq.gun   or "pistol"
    return eq
end

function C.setEquipped(persist, slot, id)
    local eq = C.equipped(persist)
    eq[slot] = id
    local parts = {}
    for k, v in pairs(eq) do table.insert(parts, k .. ":" .. v) end
    persist.cosmetics = table.concat(parts, "|")
end

-- Returns the PRIMARY color of the currently-equipped body as an {r,g,b} table.
-- Handles the special "rainbow" hue-cycle. This is the color used to derive
-- tail, ears, and tinted slug eyes.
function C.bodyColor(equipped)
    local item = C.getItem("body", equipped.body)
    if item and item.color == "rainbow" then
        local t = love.timer.getTime()
        local h = (t * 0.2) % 1
        local s = 0.8
        local v = 1
        local i = math.floor(h * 6)
        local f = h * 6 - i
        local p = v * (1 - s)
        local q = v * (1 - f * s)
        local tt = v * (1 - (1 - f) * s)
        i = i % 6
        if i == 0 then return {v, tt, p}
        elseif i == 1 then return {q, v, p}
        elseif i == 2 then return {p, v, tt}
        elseif i == 3 then return {p, q, v}
        elseif i == 4 then return {tt, p, v}
        else return {v, p, q} end
    end
    return (item and item.color) or {1, 0.55, 0.15}
end

function C.bodySecondary(equipped)
    local item = C.getItem("body", equipped.body)
    return (item and item.secondary) or nil
end

function C.bodyPattern(equipped)
    local item = C.getItem("body", equipped.body)
    return (item and item.pattern) or nil
end

function C.deepColor(base)
    return {base[1] * 0.6, base[2] * 0.5, base[3] * 0.4}
end

-- Outline/leg color given the equipped cosmetics. When a body has a secondary
-- color but no pattern (e.g. Cotton Candy), the secondary is used directly.
-- Otherwise we darken the primary like before.
function C.outlineColor(equipped, base)
    local item = C.getItem("body", equipped.body)
    if item and item.secondary and not item.pattern then
        return {item.secondary[1], item.secondary[2], item.secondary[3]}
    end
    return C.deepColor(base)
end

-- Luminance 0..1 — used to decide whether slug eyes should invert to white.
function C.luminance(col)
    if not col then return 1 end
    return 0.2126 * col[1] + 0.7152 * col[2] + 0.0722 * col[3]
end

return C
