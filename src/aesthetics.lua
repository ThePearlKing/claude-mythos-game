-- Unlockable background aesthetics. Each background draws full screen behind entities.

local Aesthetics = {}
local always = function() return true end

Aesthetics.backgrounds = {
    {id="grid",        name="Grid",           desc="Classic dark grid.",                             hint="Default",                         unlock=always},
    {id="starfield",   name="Starfield",      desc="Moving stars of the void.",                      hint="Win 1 run",                       unlock=function(p) return (p.totalWins or 0) >= 1 end},
    {id="matrix",      name="Matrix Rain",    desc="Falling green code streams.",                    hint="Kill 500 enemies",                 unlock=function(p) return (p.totalKills or 0) >= 500 end},
    {id="deepsea",     name="Deep Sea",       desc="Drifting currents and bubbles.",                 hint="Global Rep >= 60",                 unlock=function(p) return math.max(p.globalRepMax or 0, p.globalRep or 0) >= 60 end},
    {id="void",        name="The Void",       desc="Slow-spinning purple cosmos.",                   hint="Eldritch level >= 6 in a run",     unlock=function(p) return (p.eldritchMax or 0) >= 6 end},
    {id="sunset",      name="Digital Sunset", desc="Warm horizon with moving scan-lines.",           hint="Best streak >= 3",                 unlock=function(p) return (p.bestStreak or 0) >= 3 end},
    {id="bloodmoon",   name="Blood Moon",     desc="Crimson lunar haze.",                            hint="Kill 1000 enemies",                unlock=function(p) return (p.totalKills or 0) >= 1000 end},
    {id="neon_city",   name="Neon City",      desc="Scrolling cyber skyline.",                       hint="Win 4 runs",                       unlock=function(p) return (p.totalWins or 0) >= 4 end},
    {id="forest",      name="Mystic Forest",   desc="Silhouetted pines with drifting fireflies.",     hint="Global Rep >= 80",                 unlock=function(p) return math.max(p.globalRepMax or 0, p.globalRep or 0) >= 80 end},
    {id="ruins",       name="Sunken Ruins",    desc="Crumbling columns beneath deep blue.",           hint="Win 3 runs on Hard+",              unlock=function(p) return (p.hardWins or 0) >= 3 end},
    {id="aurora_sky",  name="Aurora Sky",      desc="Dancing green & violet lights.",                 hint="Best streak >= 6",                 unlock=function(p) return (p.bestStreak or 0) >= 6 end},
    {id="circuit",     name="Circuit Board",   desc="Glowing traces and scrolling signals.",          hint="Kill 2500 enemies",                unlock=function(p) return (p.totalKills or 0) >= 2500 end},
    {id="storm",       name="Thunderstorm",    desc="Rain sheets with flashes of lightning.",         hint="Win 4 runs on Hard+",              unlock=function(p) return (p.hardWins or 0) >= 4 end},
    {id="tron",        name="Tron Grid",       desc="Deep-blue circuit grid with streaming data.",    hint="Win 3 runs at eldritch >= 6",      unlock=function(p) return (p.hardWins or 0) >= 2 or (p.winEldritchMax or 0) >= 6 end},
    {id="voidsea_rise", name="Rising Void",    desc="Golden Void Sea glow rising from below.",                             hint="???",                              unlock=function(p) return (p.slugcrabUnlocked or 0) == 1 end},
    {id="king_source",  name="The King's Gaze", desc="Infinite knowledge — the game's own source scrolls across the screen.", hint="???",                              unlock=function(p) return (p.kingEndingSeen or 0) == 1 end},
}

function Aesthetics.isUnlocked(bg, persist)
    return bg.unlock(persist or {})
end

function Aesthetics.get(id)
    for _, b in ipairs(Aesthetics.backgrounds) do
        if b.id == id then return b end
    end
    return Aesthetics.backgrounds[1]
end

function Aesthetics.defaultId() return "grid" end

-- ================== DRAW FUNCTIONS ==================

local function drawGrid()
    love.graphics.setColor(0.15, 0.12, 0.2)
    for x = 0, 1280, 64 do love.graphics.line(x, 40, x, 720) end
    for y = 40, 720, 64 do love.graphics.line(0, y, 1280, y) end
end

local function drawStarfield()
    local t = love.timer.getTime()
    love.graphics.clear(0.02, 0.01, 0.08)
    for i = 1, 200 do
        local bx = (i * 73 + t * (30 + (i % 10) * 8)) % 1280
        local by = (i * 61 + (i * 17) % 720) % 720
        local size = (i % 3 == 0) and 2 or 1
        local a = 0.4 + 0.6 * math.sin(t + i)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.circle("fill", bx, by, size)
    end
    -- Distant nebula
    love.graphics.setColor(0.3, 0.1, 0.5, 0.08)
    love.graphics.circle("fill", 300 + math.sin(t * 0.1) * 100, 400, 280)
    love.graphics.setColor(0.1, 0.3, 0.6, 0.08)
    love.graphics.circle("fill", 900 + math.cos(t * 0.1) * 80, 300, 240)
end

local function drawMatrix()
    love.graphics.clear(0, 0.02, 0.01)
    local t = love.timer.getTime()
    -- Columns of falling glyphs
    for col = 0, 42 do
        local x = col * 30 + 12
        local speed = 60 + ((col * 13) % 8) * 18
        local start = (col * 9) % 100
        for row = 0, 25 do
            local y = ((row * 28 + t * speed + start * 6) % (720 + 28 * 26)) - 28
            local fade = 1 - (row / 25)
            love.graphics.setColor(0.2, 1, 0.3, fade * (row == 0 and 1 or 0.7))
            local char = string.char(0x21 + ((col * 7 + row * 3 + math.floor(t * 5)) % 90))
            love.graphics.print(char, x, y)
        end
    end
end

local function drawDeepSea()
    -- Depth gradient
    for i = 0, 20 do
        local g = 0.02 + i * 0.01
        love.graphics.setColor(0, g * 0.4, g, 1)
        love.graphics.rectangle("fill", 0, 40 + i * 34, 1280, 34)
    end
    local t = love.timer.getTime()
    -- Light shafts
    for i = 1, 6 do
        local x = (i * 220 + math.sin(t * 0.3 + i) * 50) % 1280
        love.graphics.setColor(0.5, 0.8, 1, 0.06)
        love.graphics.polygon("fill", x, 40, x + 100, 40, x + 200, 720, x - 50, 720)
    end
    -- Bubbles
    for i = 1, 60 do
        local bx = (i * 97 + math.sin(t + i) * 15) % 1280
        local by = ((720 - (t * (30 + i % 20)) - i * 17) % 720)
        local sz = 2 + (i % 4)
        love.graphics.setColor(0.7, 0.9, 1, 0.5)
        love.graphics.circle("line", bx, by, sz)
    end
end

local function drawVoid()
    love.graphics.clear(0.04, 0.01, 0.06)
    local t = love.timer.getTime()
    -- Concentric rings
    for i = 1, 10 do
        local r = 60 + i * 70 + math.sin(t + i) * 10
        love.graphics.setColor(0.4, 0.1, 0.6, 0.05)
        love.graphics.circle("line", 640, 400, r)
    end
    -- Spinning stars
    for i = 1, 120 do
        local a = (i / 120) * math.pi * 2 + t * 0.1
        local d = 80 + ((i * 47) % 500)
        local x = 640 + math.cos(a + i * 0.1) * d
        local y = 400 + math.sin(a + i * 0.1) * d * 0.7
        love.graphics.setColor(0.8, 0.5, 1, 0.5 + 0.5 * math.sin(t * 2 + i))
        love.graphics.circle("fill", x, y, 1)
    end
    -- Subtle central pulse
    love.graphics.setColor(0.6, 0.2, 0.8, 0.04 + math.sin(t) * 0.02)
    love.graphics.circle("fill", 640, 400, 260)
end

local function drawSunset()
    -- Gradient sky
    for i = 0, 30 do
        local y = 40 + i * 10
        local r = 0.1 + i * 0.02
        local g = 0.05 + i * 0.01
        local b = 0.2 - i * 0.005
        if b < 0 then b = 0 end
        love.graphics.setColor(r + 0.4, g + 0.2, b + 0.1, 1)
        love.graphics.rectangle("fill", 0, y, 1280, 12)
    end
    local t = love.timer.getTime()
    -- Sun
    love.graphics.setColor(1, 0.55, 0.2, 0.9)
    love.graphics.circle("fill", 640, 380, 110)
    love.graphics.setColor(1, 0.8, 0.4, 0.5)
    love.graphics.circle("fill", 640, 380, 145)
    -- Scan lines
    for i = 0, 50 do
        local y = 420 + i * 8 - (t * 40) % 8
        love.graphics.setColor(0, 0, 0, 0.35 + (i / 80))
        love.graphics.rectangle("fill", 0, y, 1280, 2)
    end
    -- Horizon line
    love.graphics.setColor(0.6, 0.2, 0.4)
    love.graphics.line(0, 480, 1280, 480)
end

local function drawBloodMoon()
    love.graphics.clear(0.08, 0.01, 0.02)
    local t = love.timer.getTime()
    -- Fog layers
    for i = 1, 8 do
        love.graphics.setColor(0.4, 0.05, 0.1, 0.04)
        love.graphics.circle("fill", (i * 180 + math.sin(t * 0.2 + i) * 60) % 1280, 200 + i * 30, 200)
    end
    -- Moon
    love.graphics.setColor(0.9, 0.2, 0.25, 0.9)
    love.graphics.circle("fill", 1000, 200, 80)
    love.graphics.setColor(0.6, 0.1, 0.15, 0.5)
    love.graphics.circle("fill", 1000, 200, 110)
    -- Crater marks
    love.graphics.setColor(0.4, 0.05, 0.1)
    love.graphics.circle("fill", 980, 180, 12)
    love.graphics.circle("fill", 1015, 215, 8)
    -- Flying silhouettes
    for i = 1, 20 do
        local x = ((i * 127 + t * 40) % 1280)
        local y = 100 + (i * 23 % 200)
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.line(x, y, x + 4, y - 2, x + 8, y)
    end
end

local function drawNeonCity()
    love.graphics.clear(0.05, 0.02, 0.12)
    local t = love.timer.getTime()
    -- Sky glow
    love.graphics.setColor(0.8, 0.1, 0.5, 0.15)
    love.graphics.rectangle("fill", 0, 40, 1280, 180)
    -- Buildings (parallax two layers)
    local function drawBuildings(offset, scale, color)
        for i = 0, 40 do
            local bx = ((i * 70 - t * 20 * scale + offset) % 1400) - 40
            local h = 80 + ((i * 37) % 160) * scale
            love.graphics.setColor(color[1], color[2], color[3], 0.8)
            love.graphics.rectangle("fill", bx, 720 - h, 60 * scale, h)
            -- Windows
            love.graphics.setColor(1, 0.9, 0.3, 0.8)
            for wy = 730 - h, 720 - 10, 12 do
                for wx = bx + 4, bx + 60 * scale - 4, 10 do
                    if math.sin(wx * 13 + wy * 7) > 0.5 then
                        love.graphics.rectangle("fill", wx, wy, 3, 4)
                    end
                end
            end
        end
    end
    drawBuildings(0, 1.2, {0.15, 0.05, 0.3})
    drawBuildings(500, 0.8, {0.25, 0.1, 0.45})
    -- Rain
    for i = 1, 140 do
        local x = ((i * 89 + t * 800) % 1280)
        local y = ((i * 131 + t * 600) % 720)
        love.graphics.setColor(0.4, 0.6, 1, 0.4)
        love.graphics.line(x, y, x + 2, y + 8)
    end
end

local function drawForest()
    love.graphics.clear(0.04, 0.06, 0.04)
    local t = love.timer.getTime()
    -- Layered silhouette pines
    for layer = 1, 3 do
        local scale = 0.5 + layer * 0.35
        local alpha = layer / 4
        love.graphics.setColor(0.02, 0.06 + layer * 0.04, 0.04, alpha + 0.3)
        for px = 0, 1280, math.floor(70 / scale) do
            local bx = (px + t * 5 * layer) % 1350 - 35
            local h = 100 + ((bx * 7 + layer * 13) % 80) * scale
            love.graphics.polygon("fill", bx - 30 * scale, 720, bx, 720 - h, bx + 30 * scale, 720)
        end
    end
    -- Fireflies
    for i = 1, 40 do
        local fx = (i * 123 + t * 15) % 1280
        local fy = 200 + ((i * 71 + math.sin(t * 1.5 + i) * 60) % 400)
        love.graphics.setColor(1, 0.9, 0.3, 0.6 + 0.4 * math.sin(t * 3 + i))
        love.graphics.circle("fill", fx, fy, 1.5)
    end
end

local function drawRuins()
    love.graphics.clear(0.02, 0.05, 0.10)
    local t = love.timer.getTime()
    -- Blue gradient depth
    for i = 0, 30 do
        local y = i * 24
        local k = i / 30
        love.graphics.setColor(0.02 + k * 0.04, 0.06 + k * 0.08, 0.18 + k * 0.1, 1)
        love.graphics.rectangle("fill", 0, y, 1280, 24)
    end
    -- Columns in the distance
    for i = 0, 7 do
        local cx = 80 + i * 160 + math.sin(t * 0.2 + i) * 8
        local cw = 40 + (i % 3) * 10
        local ch = 260 + ((i * 37) % 160)
        love.graphics.setColor(0.08, 0.10, 0.16, 0.9)
        love.graphics.rectangle("fill", cx - cw / 2, 720 - ch, cw, ch)
        love.graphics.setColor(0.04, 0.05, 0.08, 1)
        love.graphics.rectangle("fill", cx - cw / 2 - 6, 720 - ch, cw + 12, 14)
        love.graphics.rectangle("fill", cx - cw / 2 - 6, 720 - 14, cw + 12, 14)
    end
    -- Drifting particles
    for i = 1, 40 do
        local x = (i * 53 + t * 20) % 1280
        local y = (i * 77 + math.sin(t + i) * 20) % 720
        love.graphics.setColor(0.5, 0.7, 1, 0.3)
        love.graphics.circle("fill", x, y, 0.8)
    end
end

local function drawAuroraSky()
    love.graphics.clear(0.02, 0.02, 0.08)
    local t = love.timer.getTime()
    for band = 1, 6 do
        local hue = band / 6
        local r, g, b = 0.1, 0.8, 0.3
        if hue > 0.5 then r, g, b = 0.6, 0.3, 0.95 end
        love.graphics.setColor(r, g, b, 0.08 + 0.04 * math.sin(t + band))
        for x = 0, 1280, 20 do
            local y = 100 + band * 30 + math.sin(t * 0.4 + x * 0.01 + band) * 60
            love.graphics.circle("fill", x, y, 30)
        end
    end
    -- Distant mountain silhouette
    love.graphics.setColor(0.05, 0.05, 0.1, 1)
    love.graphics.polygon("fill", 0, 720, 0, 620, 120, 540, 260, 600, 420, 520, 580, 580, 760, 500, 920, 580, 1080, 540, 1280, 610, 1280, 720)
    -- Stars
    for i = 1, 60 do
        local x = (i * 113) % 1280
        local y = (i * 47) % 300
        love.graphics.setColor(1, 1, 1, 0.3 + 0.5 * math.sin(t * 2 + i))
        love.graphics.circle("fill", x, y, 0.8)
    end
end

local function drawCircuit()
    love.graphics.clear(0.02, 0.06, 0.04)
    local t = love.timer.getTime()
    -- Grid of circuit traces
    love.graphics.setColor(0.1, 0.45, 0.25, 0.7)
    for y = 60, 720, 40 do
        love.graphics.line(0, y, 1280, y)
    end
    for x = 0, 1280, 40 do
        love.graphics.line(x, 40, x, 720)
    end
    -- Node dots
    for x = 40, 1280, 40 do
        for y = 80, 720, 40 do
            love.graphics.setColor(0.2, 0.85, 0.4, 0.6)
            love.graphics.circle("fill", x, y, 1.5)
        end
    end
    -- Scrolling signal pulses
    for i = 1, 20 do
        local sx = ((i * 137 + t * 220) % 1280)
        local sy = 80 + ((i * 43) % 640)
        love.graphics.setColor(0.4, 1, 0.6, 0.9)
        love.graphics.rectangle("fill", sx, sy - 1, 24, 2)
    end
end

local function drawStorm()
    love.graphics.clear(0.02, 0.03, 0.06)
    local t = love.timer.getTime()
    local flash = math.sin(t * 0.7) > 0.96
    if flash then
        love.graphics.setColor(0.3, 0.4, 0.55, 0.9)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
    end
    -- Diagonal rain
    for i = 1, 200 do
        local x = ((i * 71 + t * 1200) % 1340) - 30
        local y = ((i * 131 + t * 800) % 720)
        love.graphics.setColor(0.5, 0.6, 0.8, 0.4)
        love.graphics.line(x, y, x + 3, y + 12)
    end
    -- Occasional bolt
    if flash then
        local bx = 400 + math.random(0, 480)
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.setLineWidth(2)
        local px, py = bx, 40
        for i = 1, 8 do
            local nx = px + math.random(-20, 20)
            local ny = py + 60
            love.graphics.line(px, py, nx, ny)
            px, py = nx, ny
        end
        love.graphics.setLineWidth(1)
    end
end

local function drawVoidseaRise()
    -- Rain World's Void Sea is famously GOLDEN YELLOW — this is the calm
    -- post-ascension glow, not the murky descent.
    local t = love.timer.getTime()
    -- Warm yellow gradient: brighter at the BOTTOM (the light source is below),
    -- darker olive at the top where the glow fades.
    for i = 0, 30 do
        local y = 40 + i * 23
        local k = i / 30 -- 0 = top, 1 = bottom
        local r = 0.10 + k * 0.65
        local g = 0.08 + k * 0.55
        local b = 0.02 + k * 0.08
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", 0, y, 1280, 24)
    end
    -- Diagonal light shafts rising from below in warm gold
    for i = 1, 6 do
        local x = (i * 230 + math.sin(t * 0.3 + i) * 50) % 1280
        love.graphics.setColor(1, 0.9, 0.35, 0.08 + 0.04 * math.sin(t + i))
        -- Fan-out upward (narrow at bottom, wide at top) — inverted shafts
        love.graphics.polygon("fill", x - 40, 40, x + 140, 40, x + 60, 720, x - 10, 720)
    end
    -- Rising gold motes — the signature Void Sea glow particles
    for i = 1, 90 do
        local mx = ((i * 97 + math.sin(t * 0.4 + i) * 40) % 1280)
        local my = ((i * 131 - t * (25 + (i % 4) * 12)) % 720)
        local glow = 0.5 + 0.5 * math.sin(t * 2 + i)
        love.graphics.setColor(1, 0.95, 0.4, 0.55 * glow)
        love.graphics.circle("fill", mx, my, 1.8)
        love.graphics.setColor(1, 1, 0.8, 0.2 * glow)
        love.graphics.circle("fill", mx, my, 3.5)
    end
    -- Rising bubble rings — tinted warm
    for i = 1, 80 do
        local bx = ((i * 77 + math.sin(t + i) * 12) % 1280)
        local by = ((i * 53 - t * (50 + (i % 5) * 20)) % 740) - 10
        local sz = 1 + (i % 4) * 0.6
        love.graphics.setColor(1, 0.95, 0.6, 0.35)
        love.graphics.circle("line", bx, by, sz)
    end
    -- Soft caustic shimmer in warm tone
    for row = 0, 10 do
        local yy = 80 + row * 60 + math.sin(t * 0.8 + row) * 6
        love.graphics.setColor(1, 0.9, 0.4, 0.04)
        love.graphics.rectangle("fill", 0, yy, 1280, 6)
    end
    -- Distant silhouette of the leviathan far below, backlit by the glow.
    love.graphics.setColor(0.18, 0.10, 0.02, 0.7)
    love.graphics.ellipse("fill", 640, 760, 900, 120)
end

local function drawTron()
    love.graphics.clear(0.01, 0.03, 0.08)
    local t = love.timer.getTime()
    -- Grid of cyan traces
    love.graphics.setColor(0.15, 0.5, 0.9, 0.85)
    for y = 60, 720, 40 do
        love.graphics.line(0, y, 1280, y)
    end
    for x = 0, 1280, 40 do
        love.graphics.line(x, 40, x, 720)
    end
    -- Bright node dots
    for x = 40, 1280, 40 do
        for y = 80, 720, 40 do
            love.graphics.setColor(0.3, 0.75, 1, 0.7)
            love.graphics.circle("fill", x, y, 1.6)
        end
    end
    -- Streaming signal pulses (horizontal cyan)
    for i = 1, 24 do
        local sx = ((i * 137 + t * 260) % 1280)
        local sy = 80 + ((i * 43) % 640)
        love.graphics.setColor(0.4, 0.9, 1, 1)
        love.graphics.rectangle("fill", sx, sy - 1, 28, 2)
        love.graphics.setColor(0.6, 0.95, 1, 0.4)
        love.graphics.rectangle("fill", sx - 8, sy - 1, 8, 2)
    end
    -- Vertical signal pulses for that Tron look
    for i = 1, 18 do
        local sy = ((i * 97 + t * 320) % 720)
        local sx = 40 + ((i * 51) % 1200)
        love.graphics.setColor(0.35, 0.85, 1, 1)
        love.graphics.rectangle("fill", sx - 1, sy, 2, 24)
    end
    -- Faint scanlines overlay
    love.graphics.setColor(0, 0.2, 0.4, 0.15)
    for y = 0, 720, 4 do
        love.graphics.rectangle("fill", 0, y, 1280, 1)
    end
end

-- Load each source file separately so a column can scroll through one file
-- continuously, then swap to another when it finishes.
local kingFiles
local function loadKingFiles()
    if kingFiles then return kingFiles end
    kingFiles = {}
    local names = {
        "main.lua", "conf.lua",
        "src/game.lua", "src/player.lua", "src/cards.lua",
        "src/eldritch.lua", "src/voidsea.lua", "src/enemy.lua",
        "src/bullet.lua", "src/cosmetics.lua", "src/ui.lua",
        "src/aesthetics.lua", "src/audio.lua", "src/wave.lua",
        "src/particles.lua", "src/save.lua", "src/difficulty.lua",
        "src/playlist.lua", "src/debugvis.lua", "src/debugsound.lua",
    }
    for _, f in ipairs(names) do
        local ok, content = pcall(love.filesystem.read, f)
        if ok and content then
            local lines = {}
            for line in content:gmatch("[^\r\n]+") do
                lines[#lines + 1] = line
            end
            if #lines > 10 then
                kingFiles[#kingFiles + 1] = {name = f, lines = lines}
            end
        end
    end
    if #kingFiles == 0 then
        kingFiles = {{name = "???", lines = {"-- the king knows all --"}}}
    end
    return kingFiles
end

-- Per-column scroll state (persistent across frames)
local kingCols
local function initKingCols(files)
    kingCols = {}
    local cols = 5
    for c = 0, cols - 1 do
        kingCols[c] = {
            fileIdx  = ((c * 3) % #files) + 1,
            startT   = love.timer.getTime() - math.random() * 4,
            dir      = (c % 2 == 0) and -1 or 1,
            speed    = 55 + c * 10,      -- moderate px/s
            switches = 0,
        }
    end
end

local function drawKingSource()
    -- Mid-dark yellow base
    love.graphics.clear(0.18, 0.14, 0.02)
    local t = love.timer.getTime()
    -- Subtle vertical gradient
    for i = 0, 30 do
        local y = 40 + i * 23
        local k = i / 30
        love.graphics.setColor(0.22 + k * 0.06, 0.18 + k * 0.04, 0.03, 0.6)
        love.graphics.rectangle("fill", 0, y, 1280, 24)
    end

    local files = loadKingFiles()
    if not kingCols or #kingCols < 4 then initKingCols(files) end

    local cols = 5
    local colW = 1280 / cols
    local rowH = 18
    -- Hash-based pseudo-random (keeps global RNG untouched)
    local function pr(s)
        local v = math.sin(s * 12.9898 + 78.233) * 43758.5453
        return v - math.floor(v)
    end

    for col = 0, cols - 1 do
        local st = kingCols[col]
        local file = files[st.fileIdx]
        local lineCount = #file.lines
        local fileHeight = lineCount * rowH
        local totalScroll = (t - st.startT) * st.speed

        -- When the entire file has swept past the screen, pick a different
        -- file and restart scroll.
        if totalScroll > fileHeight + 720 then
            local nextIdx = st.fileIdx
            if #files > 1 then
                local attempts = 0
                while nextIdx == st.fileIdx and attempts < 8 do
                    nextIdx = math.floor(pr(st.switches * 7.3 + col * 13.1) * #files) + 1
                    attempts = attempts + 1
                end
            end
            st.fileIdx  = nextIdx
            st.startT   = t
            st.switches = st.switches + 1
            file = files[st.fileIdx]
            lineCount = #file.lines
            fileHeight = lineCount * rowH
            totalScroll = 0
        end

        local baseX = col * colW + 6
        -- Column filename header (faint)
        love.graphics.setColor(1, 0.85, 0.3, 0.22)
        love.graphics.print("-- " .. file.name, baseX, 18)

        -- Draw only lines whose screen Y is on or near screen.
        -- Up direction: strip starts below, moves up. Line N at y = 720 - totalScroll + (N-1)*rowH
        -- Down direction: strip starts above, moves down. Line N at y = -fileHeight + totalScroll + (N-1)*rowH
        local firstVisibleN, lastVisibleN
        if st.dir < 0 then
            firstVisibleN = math.max(1, math.floor((totalScroll - 720) / rowH))
            lastVisibleN  = math.min(lineCount, math.ceil((totalScroll + rowH) / rowH))
        else
            firstVisibleN = math.max(1, math.floor((fileHeight - totalScroll) / rowH))
            lastVisibleN  = math.min(lineCount, math.ceil((fileHeight - totalScroll + 720 + rowH) / rowH))
        end
        for N = firstVisibleN, lastVisibleN do
            local screenY
            if st.dir < 0 then
                screenY = 720 - totalScroll + (N - 1) * rowH
            else
                screenY = -fileHeight + totalScroll + (N - 1) * rowH
            end
            local alpha = 0.7
            -- Fade near top and bottom edges
            if screenY < 60 then alpha = alpha * math.max(0, screenY / 60) end
            if screenY > 660 then alpha = alpha * math.max(0, (720 - screenY) / 60) end
            love.graphics.setColor(1, 0.92, 0.3, alpha)
            love.graphics.print(file.lines[N], baseX, screenY)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local drawers = {
    grid = drawGrid,
    starfield = drawStarfield,
    matrix = drawMatrix,
    deepsea = drawDeepSea,
    void = drawVoid,
    sunset = drawSunset,
    bloodmoon = drawBloodMoon,
    neon_city = drawNeonCity,
    forest = drawForest,
    ruins = drawRuins,
    aurora_sky = drawAuroraSky,
    circuit = drawCircuit,
    storm = drawStorm,
    tron = drawTron,
    voidsea_rise = drawVoidseaRise,
    king_source = drawKingSource,
}

function Aesthetics.draw(id)
    local fn = drawers[id] or drawGrid
    fn()
end

return Aesthetics
