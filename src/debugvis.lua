-- Debug visualiser: preview sprites/animations against a chosen background.
-- Triggered by holding Shift+Space and tapping V. Keys inside:
--   up/down     — select sprite
--   left/right  — cycle background color
--   r           — reset animation timer
--   i           — toggle UI (leaves a hint in bottom-left)
--   escape      — leave
local Eldritch  = require("src.eldritch")
local Player    = require("src.player")
local Enemy     = require("src.enemy")
local Bullet    = require("src.bullet")
local Cosmetics = require("src.cosmetics")
local P         = require("src.particles")

local DV = {}

-- Chroma-key friendly backgrounds so you can capture sprites against any
-- needed color (e.g. greenscreen for video work).
DV.backgrounds = {
    {name = "Black",       color = {0.00, 0.00, 0.00}},
    {name = "Greenscreen", color = {0.00, 1.00, 0.00}},
    {name = "Bluescreen",  color = {0.00, 0.00, 1.00}},
    {name = "Magenta",     color = {1.00, 0.00, 1.00}},
    {name = "White",       color = {1.00, 1.00, 1.00}},
    {name = "Dark Grey",   color = {0.12, 0.10, 0.15}},
}

-- Small helper to build a mock player for preview rendering.
-- Keeps Player:emitTrail intact so trail cosmetics actually emit particles.
local function mockPlayer(opts)
    local p = setmetatable({}, {__index = Player})
    p.x = opts.x or 640
    p.y = opts.y or 360
    p.r = 18
    p.angle       = opts.angle or 0
    p.bodyAngle   = opts.bodyAngle or 0
    p.legPhase    = opts.legPhase or 0
    p.swimming    = opts.swimming or false
    p.flashTimer  = 0
    p.stats       = {shield = 0, shieldMax = 0, orbs = 0}
    p.cosmetics   = opts.cosmetics or {
        body = "orange", eye = "normal", claw = "normal",
        hat = "none",    trail = "none", gun = "pistol",
    }
    p.uprightHead = false
    p.laserActive = false
    p.laserEnds   = nil
    p.railChargeTime = 0
    p.slugTailHistory = opts.slugTailHistory
    -- Trail fields: initialize so Player:emitTrail runs cleanly
    p.trailTimer = 0
    p._prevX = opts.prevX or (p.x - 2)
    p._prevY = opts.prevY or p.y
    -- Aura (Super Saiyan) requires these
    p.auraTime = 0
    p.maxHp = 100; p.hp = 100
    -- Stub only drawAura for baseline previews; explicit previews call it.
    p.drawAura = function() end
    return p
end

-- Build a "only this slot swapped" preview
local function swapCosm(slot, id)
    local c = {body = "orange", eye = "normal", claw = "normal",
               hat = "none", trail = "none", gun = "pistol"}
    c[slot] = id
    return c
end

-- ============================================================================
-- ITEM LIST (BUILT PROGRAMMATICALLY)
-- ============================================================================

DV.items = {}

local function add(name, drawFn)
    DV.items[#DV.items + 1] = {name = name, draw = drawFn}
end

-- Fetch the player's currently-equipped cosmetics (works from any state)
local function currentCosm()
    local g = DV._currentGame
    if g and g.player and g.player.cosmetics then
        return g.player.cosmetics
    end
    if g and g.persist then
        return Cosmetics.equipped(g.persist)
    end
    return {body = "orange", eye = "normal", claw = "normal",
            hat = "none", trail = "none", gun = "pistol"}
end

-- ---- Current crab poses (reflect the user's equipped outfit).
-- For trails to render we let Player:emitTrail run and call P:draw after.
add("Current Crab (Idle)", function(t)
    -- Truly stationary — no wobble, no trail emission.
    local p = mockPlayer{legPhase = t * 3, cosmetics = currentCosm()}
    p:draw()
end)
add("Current Crab (Moving)", function(t)
    local wobble = math.cos(t * 3) * 80
    local cosm = currentCosm()
    local p = mockPlayer{legPhase = t * 10, cosmetics = cosm,
        x = 640 + wobble, prevX = 640 + math.cos((t - 0.016) * 3) * 80}
    -- Simulate slug tail exactly like in-game: push current position onto the
    -- front of a persistent history whenever we've moved more than 2px, cap
    -- the history at 33 entries. Tail segments sample this history so they
    -- trail along the actual path the crab has taken — not a tweened curve.
    if cosm.trail == "slug" then
        DV._slugHist = DV._slugHist or {}
        DV._slugLastT = DV._slugLastT or t
        -- If we jumped back in time (e.g. R reset), clear the history
        if t < (DV._slugLastT or 0) then DV._slugHist = {} end
        DV._slugLastT = t
        local hist = DV._slugHist
        local last = hist[1]
        if not last or ((p.x - last.x) ^ 2 + (p.y - last.y) ^ 2) > 4 then
            table.insert(hist, 1, {x = p.x, y = p.y})
            while #hist > 33 do table.remove(hist) end
        end
        p.slugTailHistory = hist
    else
        -- Not equipped — drop any stale history so the next toggle starts fresh
        DV._slugHist = nil
    end
    p:draw()
    P:draw()
end)
add("Current Crab (Swimming)", function(t)
    -- Stationary — the swimming animation is the faster leg phase + tail sway,
    -- no positional drift.
    local p = mockPlayer{legPhase = t * 18, swimming = true, cosmetics = currentCosm()}
    p.slugTailHistory = {}
    for i = 1, 30 do p.slugTailHistory[i] = {x = p.x - i * 2, y = p.y} end
    p:draw()
end)
add("Current Crab (Shield on)", function(t)
    local p = mockPlayer{legPhase = t * 3, cosmetics = currentCosm()}
    p.stats.shield = 50; p.stats.shieldMax = 50
    p:draw()
    P:draw()
end)
add("Current Crab (Firing laser)", function(t)
    local p = mockPlayer{legPhase = t * 4, cosmetics = currentCosm()}
    p.laserActive = true
    p.laserEnds = {{p.x + 400, p.y + math.sin(t * 3) * 30}}
    p:draw()
    P:draw()
end)
add("Current Crab (Aim sweep)", function(t)
    local p = mockPlayer{legPhase = t * 3, cosmetics = currentCosm()}
    p.angle = math.sin(t * 0.8) * math.pi
    p:draw()
    P:draw()
end)

-- ---- Every enemy
local enemyOrder = {
    "chatgpt", "gemini", "bing", "deepseek", "copilot", "windows",
    "meta", "grok", "perplexity", "llama",
    "drone", "sniper", "teleporter", "mine", "drifter",
    "shrimp_spirit", "swarm", "openclaw",
}
for _, key in ipairs(enemyOrder) do
    local cfg = Enemy.types[key]
    if cfg then
        local display = cfg.name
        add("Enemy: " .. display, function(t)
            local e = Enemy.new(key, 640, 360, 1)
            e.anim = t
            e.shootTimer = math.abs(math.sin(t)) * 1.5
            if key == "teleporter" then e.blinkT = (t % 2) end
            if key == "sniper"     then e.chargeT = (t % 2) end
            if key == "mine"       then e.exploding = 0.3 + math.sin(t * 3) * 0.2 end
            e:draw()
        end)
    end
end

-- ---- Bullets (friendly + enemy + special)
add("Bullet: friendly normal", function(t)
    for i = 0, 6 do
        local f = ((t - i * 0.12) % 1.2) / 1.2
        if f > 0 and f < 1 then
            local x = 300 + f * 680
            love.graphics.setColor(1, 0.9, 0.4, 1 - f * 0.4)
            love.graphics.circle("fill", x, 360, 4)
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.circle("fill", x, 360, 2)
        end
    end
end)
add("Bullet: enemy red", function(t)
    for i = 0, 4 do
        local f = ((t - i * 0.2) % 1.4) / 1.4
        if f > 0 and f < 1 then
            local x = 980 - f * 680
            love.graphics.setColor(1, 0.3, 0.3, 1 - f * 0.3)
            love.graphics.circle("fill", x, 360, 6)
            love.graphics.setColor(1, 0.9, 0.7, 0.8)
            love.graphics.circle("fill", x, 360, 2.5)
        end
    end
end)
add("Bullet: homing trail", function(t)
    local x = 640 + math.cos(t * 2) * 200
    local y = 360 + math.sin(t * 2) * 80
    love.graphics.setColor(0.4, 1, 0.6, 0.8)
    love.graphics.circle("fill", x, y, 5)
    for i = 1, 8 do
        local px = 640 + math.cos(t * 2 - i * 0.08) * 200
        local py = 360 + math.sin(t * 2 - i * 0.08) * 80
        love.graphics.setColor(0.4, 1, 0.6, (8 - i) / 12)
        love.graphics.circle("fill", px, py, 4 - i * 0.3)
    end
end)
add("Bullet: explosive", function(t)
    local phase = (t % 1.2)
    if phase < 0.9 then
        love.graphics.setColor(1, 0.6, 0.2, 1)
        love.graphics.circle("fill", 640, 360, 7)
        love.graphics.setColor(1, 0.9, 0.4, 0.6)
        love.graphics.circle("fill", 640, 360, 12)
    else
        -- Blast
        local bp = (phase - 0.9) / 0.3
        love.graphics.setColor(1, 0.5, 0.2, 1 - bp)
        love.graphics.circle("line", 640, 360, 40 + bp * 80)
        love.graphics.setColor(1, 0.9, 0.5, (1 - bp) * 0.5)
        love.graphics.circle("fill", 640, 360, 40 + bp * 80)
    end
end)

-- ---- Eldritch effects
add("Cthulhu (rising)", function(t)
    Eldritch.drawCthulhu({x = 640, y = 360, phase = "rise", timer = t,
        beamTime = 0, intensity = math.min(1, t * 0.3)})
end)
add("Cthulhu (watching)", function(t)
    Eldritch.drawCthulhu({x = 640, y = 360, phase = "watch", timer = t,
        beamTime = 0, intensity = 1})
end)
add("Cthulhu (channeling)", function(t)
    Eldritch.drawCthulhu({x = 640, y = 360, phase = "channel", timer = t,
        beamTime = t % 2.5, intensity = 1})
end)
add("Cthulhu (firing beam)", function(t)
    local fakePlayer = {x = 640, y = 660}
    local c = {x = 640, y = 200, phase = "fire", timer = t,
               beamTime = 0, intensity = 1}
    Eldritch.drawCthulhu(c)
    -- Fake beam on player
    Eldritch.drawBeamOnPlayer({cthulhu = c}, fakePlayer)
    love.graphics.setColor(1, 0.3, 0.3, 0.5)
    love.graphics.circle("line", fakePlayer.x, fakePlayer.y, 20)
end)
add("Cthulhu (dying - King)", function(t)
    local state = {
        cthulhu = {x = 640, y = 360, phase = "dying", timer = t,
                   beamTime = 0, intensity = math.max(0.2, 1 - t * 0.15)},
        kingOblit = {phase = "cthulhu_crumble", timer = math.min(4.9, t)},
        cthuluCracks = {
            {x = 600, y = 340, r = (t * 420) % 200, life = 0.5, max = 0.7,
             color = {1, 0.9, 0.35}},
            {x = 700, y = 380, r = ((t + 0.3) * 420) % 200, life = 0.4, max = 0.7,
             color = {1, 0.9, 0.35}},
        },
    }
    Eldritch.drawCthulhu(state.cthulhu)
    Eldritch._drawCthulhuDying(state)
end)

add("Churgly'nth (normal)", function(t)
    Eldritch._debugDrawChurglyForm(0.9, false, nil)
end)
add("Churgly'nth (enraged)", function(t)
    Eldritch._debugDrawChurglyForm(1.0, true, nil)
end)
add("Churgly'nth (King awakened)", function(t)
    local kingCtx = {intensity = math.min(1, t * 0.3), targetX = 400, targetY = 600}
    Eldritch._debugDrawChurglyForm(1.0, true, kingCtx)
end)
add("Churgly Beam (godly laser)", function(t)
    local fakeGame = {player = {x = 400, y = 600}}
    local state = {
        kingOblit = {phase = "obliteration", timer = math.max(4, t)},
        _churglyHead = {x = 880, y = 200, r = 80 + math.sin(t) * 10},
    }
    love.graphics.setColor(0.55, 0.15, 0.85, 0.8)
    love.graphics.circle("fill", state._churglyHead.x, state._churglyHead.y, state._churglyHead.r)
    Eldritch._drawChurglyBeam(state, fakeGame)
    love.graphics.setColor(1, 0.4, 0.3, 0.8)
    love.graphics.circle("line", fakeGame.player.x, fakeGame.player.y, 20)
end)

add("King Fractal (full bloom)", function(t)
    Eldritch._drawKingFractal({kingFractal = 1.0})
end)
add("King Fractal (growing)", function(t)
    Eldritch._drawKingFractal({kingFractal = math.abs(math.sin(t * 0.5))})
end)

add("Tesseract", function(t)
    -- Bigger size + non-zero starting angle so the 4D-to-2D projection
    -- spreads vertices enough to be clearly visible.
    Eldritch._debugDrawTesseract(640, 360, 260, t * 0.6 + 0.9, 1.0)
end)
add("Eldritch Ghost Crab", function(t)
    Eldritch._debugDrawEldritchCrab(640, 360, 80, 0.95, t * 2)
end)
add("Eldritch Ripples (corner)", function(t)
    Eldritch.drawRipples({level = 20, ripples = nil})
end)
add("Eldritch whisper glimpse", function(t)
    -- Churgly glimpse overlay at fading alpha
    local a = math.abs(math.sin(t * 0.7))
    Eldritch._debugDrawChurglyForm(a * 0.6, false, nil)
    love.graphics.setColor(1, 0.7, 0.85, a * 0.6)
    love.graphics.printf("YOU WERE A CLAW I DREAMT", 0, 460, 1280, "center")
end)

-- ---- Particle-driven effects
add("Death burst", function(t)
    local period = math.floor(t / 1.2)
    if period ~= DV._deathLast then
        DV._deathLast = period
        P:spawn(640, 360, 120, {1, 0.35, 0.5}, 700, 1.2, 10)
        P:spawn(640, 360, 80, {0.9, 0.3, 0.9}, 500, 1.0, 8)
        P:spawn(640, 360, 40, {1, 0.9, 0.4}, 400, 0.8, 6)
    end
    P:draw()
end)
add("Kill burst (orange)", function(t)
    local period = math.floor(t / 0.7)
    if period ~= DV._killLast then
        DV._killLast = period
        P:spawn(640, 360, 30, {1, 0.7, 0.2}, 400, 0.6, 5)
    end
    P:draw()
end)
add("Hit flash particles", function(t)
    local period = math.floor(t / 0.4)
    if period ~= DV._hitLast then
        DV._hitLast = period
        P:spawn(640, 360, 12, {1, 0.3, 0.3}, 220, 0.5, 3)
    end
    P:draw()
end)
add("Text burst", function(t)
    local period = math.floor(t / 1.5)
    if period ~= DV._textLast then
        DV._textLast = period
        P:text(640, 340, "CRITICAL!", {1, 0.9, 0.3}, 1.2)
        P:text(640, 380, "+25", {0.4, 1, 0.4}, 1.2)
    end
    P:draw()
end)
add("Shockwave", function(t)
    local p = (t * 0.7) % 1
    local r = 10 + p * 280
    local a = 1 - p
    love.graphics.setColor(1, 0.8, 0.3, a * 0.8)
    love.graphics.setLineWidth(6)
    love.graphics.circle("line", 640, 360, r)
    love.graphics.setColor(1, 1, 0.7, a * 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 640, 360, r * 0.7)
    love.graphics.setLineWidth(1)
end)
add("Explosive shockwave (full)", function(t)
    local period = math.floor(t / 1.5)
    if period ~= DV._shockLast then
        DV._shockLast = period
        DV._shockStart = t
    end
    local age = t - (DV._shockStart or t)
    if age < 0.35 then
        local a = math.max(0, age / 0.35)
        local r = age * 420
        love.graphics.setColor(1, 0.5, 0.2, (1 - a) * 0.7)
        love.graphics.setLineWidth(6)
        love.graphics.circle("line", 640, 360, r)
        love.graphics.setColor(1, 1, 0.6, (1 - a) * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 640, 360, r * 0.7)
        love.graphics.setColor(1, 0.5, 0.2, (1 - a) * 0.22)
        love.graphics.circle("fill", 640, 360, r * 0.9)
    end
    love.graphics.setLineWidth(1)
end)

-- ---- Super Saiyan aura (uses Player:drawAura)
add("Super Saiyan aura", function(t)
    local p = mockPlayer{legPhase = t * 3, cosmetics = swapCosm("trail", "super_saiyan")}
    Player.drawAura(p)
    p:draw()
end)

-- ---- Rail charge / laser flash / orb FX
add("Rail charge", function(t)
    local r = 8 + (t % 1.2) * 20
    local a = 1 - (t % 1.2) / 1.2
    love.graphics.setColor(1, 1, 0.3, 0.6 * a)
    love.graphics.circle("line", 640, 360, r)
    love.graphics.setColor(1, 1, 0.4, 0.4 * a)
    love.graphics.circle("fill", 640, 360, r * 0.4)
end)
add("Laser beam (red line)", function(t)
    local widthMult = 1 + math.sin(t * 3) * 0.3
    local outer = 6 * widthMult
    local inner = 2 * widthMult
    love.graphics.setColor(1, 0.3, 0.2, 0.7)
    love.graphics.setLineWidth(outer)
    love.graphics.line(320, 360, 960, 360 + math.sin(t) * 30)
    love.graphics.setColor(1, 0.9, 0.8, 1)
    love.graphics.setLineWidth(inner)
    love.graphics.line(320, 360, 960, 360 + math.sin(t) * 30)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(math.max(1, inner * 0.4))
    love.graphics.line(320, 360, 960, 360 + math.sin(t) * 30)
    love.graphics.setLineWidth(1)
end)
add("Orbiting orb (single)", function(t)
    local a = t * 3
    local x = 640 + math.cos(a) * 60
    local y = 360 + math.sin(a) * 60
    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.circle("fill", x, y, 6)
    love.graphics.setColor(1, 1, 0.8)
    love.graphics.circle("fill", x, y, 3)
end)

-- ---- Screen effects
add("Flashbang overlay", function(t)
    local a = math.abs(math.sin(t * 0.8))
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)
end)
add("Void Sea yellow surface", function(t)
    -- Simulate the surface stripe that appears at the bottom
    local p = {x = 640, y = 660, voidSeaUnlocked = true}
    local fakeGame = {player = p}
    local Voidsea = require("src.voidsea")
    Voidsea.drawSurface(fakeGame)
end)

-- ============================================================================
-- DRAW
-- ============================================================================

-- Hold up/down for 0.7s to start auto-scrolling through the sprite list fast.
function DV.update(game, dt)
    local upHeld   = love.keyboard.isDown("up")
    local downHeld = love.keyboard.isDown("down")
    if upHeld and not downHeld then
        game._dvHoldDir = -1
    elseif downHeld and not upHeld then
        game._dvHoldDir = 1
    else
        game._dvHoldDir = 0
        game._dvHoldT   = 0
        game._dvRepeatT = 0
        return
    end
    game._dvHoldT = (game._dvHoldT or 0) + dt
    if game._dvHoldT > 0.7 then
        game._dvRepeatT = (game._dvRepeatT or 0) - dt
        if game._dvRepeatT <= 0 then
            game._dvRepeatT = 0.04 -- ~25 items/s once auto-repeat kicks in
            local n = #DV.items
            game.debugVisIndex = ((game.debugVisIndex or 1) - 1 + game._dvHoldDir) % n + 1
        end
    end
end

function DV.draw(game)
    DV._currentGame = game
    local idx = game.debugVisIndex or 1
    if idx > #DV.items then idx = 1 end
    local bgIdx = game.debugVisBg or 1
    local bg = DV.backgrounds[bgIdx] or DV.backgrounds[1]
    love.graphics.clear(bg.color[1], bg.color[2], bg.color[3])

    game._dvStartT = game._dvStartT or love.timer.getTime()
    local localT = love.timer.getTime() - game._dvStartT

    local item = DV.items[idx]
    local ok, err = pcall(item.draw, localT)
    if not ok then
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.printf("ERROR: " .. tostring(err), 20, 360, 1240, "center")
    end

    if game.debugVisHideUI then
        -- UI hidden: only the keybind hint in the bottom-left
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 6, 696, 76, 18)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setFont(game.font)
        love.graphics.print("I: UI", 12, 698)
        return
    end

    -- Full UI: title, position, help, sprite sidebar
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, 1280, 78)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setFont(game.bigFont or game.font)
    love.graphics.printf(item.name, 0, 14, 1280, "center")
    love.graphics.setFont(game.font)
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.printf(string.format("(%d / %d)  BG: %s", idx, #DV.items, bg.name),
        0, 52, 1280, "center")

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 684, 1280, 36)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(
        "UP/DOWN: sprite    LEFT/RIGHT: background    R: reset    I: hide UI    ESC: exit",
        0, 695, 1280, "center")

    -- Scrolling sprite sidebar (11 visible, current highlighted)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 8, 96, 300, 560)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("SPRITES", 20, 106)
    local span = 13
    local start = math.max(1, math.min(idx - math.floor(span / 2), #DV.items - span + 1))
    if start < 1 then start = 1 end
    local stop = math.min(#DV.items, start + span - 1)
    for i = start, stop do
        if i == idx then
            love.graphics.setColor(1, 0.85, 0.4, 1)
        else
            love.graphics.setColor(1, 1, 1, 0.6)
        end
        local n = DV.items[i].name
        if #n > 34 then n = n:sub(1, 32) .. ".." end
        love.graphics.print(string.format("%3d. %s", i, n), 20, 128 + (i - start) * 20)
    end
end

return DV
