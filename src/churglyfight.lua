-- Churgly'nth boss fight — triggered by Ugnrak Beam during the King
-- obliteration cinematic (or natural Cthulhu kill). Visually identical to
-- the background Churgly'nth form (48-segment serpent curving into the
-- vanishing point) but scaled up, fully opaque, and mobile. Major segments
-- along the spine can be destroyed; the head only becomes vulnerable once
-- they're all down.

local Eldritch = require("src.eldritch")
local P = require("src.particles")
local Audio = require("src.audio")
local Save = require("src.save")
local Bullet = require("src.bullet")

local Churglyfight = {}

-- Layout constants
local SCALE = 2.0                     -- 2x size vs background form
local SEGMENT_COUNT = 48
local MAJOR_EVERY = 6                 -- every Nth segment is destroyable
local SEG_HP = 1800                   -- per major segment
local HEAD_HP = 4500
local VANISH_X, VANISH_Y = 640, 360

-- =============================================================================
-- GEOMETRY (identical formula to drawChurglyForm, scaled)
-- =============================================================================

-- Returns {x, y, size} for each of the SEGMENT_COUNT body segments plus the
-- head, given the current time. Head moves around; vanishing point fixed.
local function computePositions(t, b)
    -- Head drifts using the same wobble formula as the background form —
    -- just with wider range since Churgly is closer/bigger.
    local bigX = math.sin(t * 0.28) * 520 + math.cos(t * 0.15) * 200
    local bigY = math.sin(t * 0.21 + 1.3) * 240 + math.cos(t * 0.1) * 100
    local dart = math.sin(t * 2.4) > 0.85 and math.sin(t * 30) * 30 or 0
    local hx = VANISH_X + bigX + dart
    local hy = VANISH_Y + bigY + math.sin(t * 0.5) * 44
    hx = math.max(80, math.min(1200, hx))
    hy = math.max(100, math.min(640, hy))

    b.headPos = {x = hx, y = hy, r = 28 * SCALE}

    -- Curve segments from head to vanishing point
    local dx = VANISH_X - hx
    local dy = VANISH_Y - hy
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    local px, py = -dy / len, dx / len
    b.segPositions = {}
    for i = 1, SEGMENT_COUNT do
        local tParam = (i - 1) / (SEGMENT_COUNT - 1)
        local falloff = 1 - tParam
        local bx = hx + dx * tParam
        local by = hy + dy * tParam
        local wave = math.sin(t * 1.3 + tParam * 6 + hx * 0.001) * 50 * (1 - tParam) ^ 0.7
        local nx = bx + px * wave
        local ny = by + py * wave
        local size = (20 * falloff + 2) * SCALE
        b.segPositions[i] = {x = nx, y = ny, r = size, t = tParam}
    end
end

-- =============================================================================
-- INIT / DEFEAT
-- =============================================================================

function Churglyfight.start(game)
    -- Wipe everything else
    game.enemies = {}
    game.enemyBullets = {}
    game.pendingSpawns = {}
    game.shockwaves = {}
    do
        local Fx = require("src.fx")
        Fx.clearAll()
        Fx.shatter(0.85, 900)
        Fx.invert(220)
        Fx.mood("#3a0512", 0.5)
        Fx.pulsate("#cc0033", 60, 0.45)
        Fx.vignette(0.65, 1300)
    end
    -- Clear the King obliteration state + all its ripples/fractals
    if game.player and game.player.eldritch then
        local eld = game.player.eldritch
        eld.kingOblit = nil
        eld.kingFractal = 0
        eld.cthulhu = nil
        eld.cthulhuDestroyed = true
    end
    game.player.kingVisions = false
    game.player.disabled = false
    -- HARD RESET invuln — the Ugnrak cinematic set it to 999 to make the
    -- player immortal during the beam; carrying that into the fight
    -- trivialized the whole boss.
    game.player.invuln = 3
    game.screenFlash = 0
    game.screenFlashHold = 0
    game.kingFractalHold = 0
    game.backfireHold = 0

    -- Strip sustain aggressively so the fight demands dodging, not tanking.
    local p = game.player
    p.regen = 0.5                        -- was 1.5, basically chip only
    if p.stats then
        p.stats.lifesteal = 0             -- no leeching in
        p.stats.killHeal  = 0
        p.stats.reviveAvailable = false   -- no free revives either
    end
    p.coffeeCurse = false

    -- Build major-segment HP table keyed by segment index
    local majors = {}
    for i = 1, SEGMENT_COUNT, MAJOR_EVERY do
        majors[i] = {hp = SEG_HP, maxHp = SEG_HP, flash = 0, dead = false, idx = i}
    end

    game.churglyBoss = {
        majors = majors,             -- sparse table keyed by segment idx
        segPositions = {},           -- recomputed every update
        headPos = {x = 640, y = 180, r = 56},
        head = {hp = HEAD_HP, maxHp = HEAD_HP, dead = false, flash = 0},
        phase = "fight",
        attackTimer = 2.5,
        specialTimer = 6,
        life = 0,
        deathTimer = 0,
    }

    P:text(640, 200, "CHURGLY'NTH MANIFESTS", {0.9, 0.2, 1}, 5)
    P:text(640, 240, "DESTROY EVERY SEGMENT", {1, 0.4, 0.6}, 4)
    Audio:play("cthulhu")
    Audio:play("glitch")
    Audio:stopMusic()
    Audio:setTheme("whisperwave_epic")
    Audio:playMusic("normal")
end

local function defeat(game)
    local b = game.churglyBoss
    if not b or b.phase ~= "fight" then return end
    b.phase = "dying"
    b.deathTimer = 0
    game.enemyBullets = {}
    Eldritch.gainLevel(game.player, 15)
    game.persist.churglyDefeated = 1
    game.persist.churglyDefeats = (game.persist.churglyDefeats or 0) + 1
    require("src.achievements").fire("churgly_defeated")
    do
        local Fx = require("src.fx")
        Fx.mood("none")
        Fx.pulsate("off")
        Fx.flash("#ffaa55", 600, 0.8)
        Fx.shake(0.85, 600)
        Fx.pulse("#ffaa55", 1700)
        Fx.glow("#ffaa55", 0.7, 2000)
        Fx.calm("#ffaa55", 0.4)
    end
    local lvl = game.player.eldritch and game.player.eldritch.level or 0
    game.persist.eldritchMax = math.max(game.persist.eldritchMax or 0, lvl)
    game.persist.winEldritchMax = math.max(game.persist.winEldritchMax or 0, lvl)
    Save.save(game.persist)
    Audio:play("cthulhu")
end

function Churglyfight.isActive(game)
    return game.churglyBoss and game.churglyBoss.phase ~= "done"
end

-- =============================================================================
-- ATTACKS
-- =============================================================================

local function fireBarrageFromHead(game, b)
    local p = game.player
    if not p then return end
    local h = b.headPos
    local ang = math.atan2(p.y - h.y, p.x - h.x)
    local count = 9
    for i = -math.floor(count / 2), math.floor(count / 2) do
        local a = ang + i * 0.18
        local bb = Bullet.new(h.x, h.y, math.cos(a) * 220, math.sin(a) * 220, 12, false)
        bb.color = {0.85, 0.2, 1}; bb.size = 10
        bb.churglySmall = true
        table.insert(game.enemyBullets, bb)
    end
    Audio:play("shoot2")
end

local function fireHomingFromSpine(game, b)
    local p = game.player
    if not p then return end
    -- Fire from each alive major segment's current position
    for idx, m in pairs(b.majors) do
        if not m.dead then
            local pos = b.segPositions[idx]
            if pos then
                local ang = math.atan2(p.y - pos.y, p.x - pos.x)
                local bb = Bullet.new(pos.x, pos.y, math.cos(ang) * 130, math.sin(ang) * 130, 10, false)
                bb.color = {1, 0.4, 0.9}; bb.size = 8
                bb.churglyHoming = 0.6
                bb.churglySmall = true
                table.insert(game.enemyBullets, bb)
            end
        end
    end
    Audio:play("whisper")
end

local function fireSweepFromHead(game, b)
    local p = game.player
    if not p then return end
    local h = b.headPos
    local baseAng = math.atan2(p.y - h.y, p.x - h.x)
    for i = 0, 22 do
        local a = baseAng + (i - 11) * 0.12
        local bb = Bullet.new(h.x, h.y, math.cos(a) * 180, math.sin(a) * 180, 14, false)
        bb.color = {1, 0.2, 0.35}; bb.size = 9
        bb.churglySmall = true
        table.insert(game.enemyBullets, bb)
    end
    Audio:play("boss")
end

-- Big attack — single massive orb from the head that floats slowly toward
-- the player. This one IS shoot-downable: hitting it with a player bullet
-- detonates it and deals huge damage to the nearest segment.
local function fireBigOrb(game, b)
    local p = game.player
    if not p then return end
    local h = b.headPos
    local ang = math.atan2(p.y - h.y, p.x - h.x)
    local bb = Bullet.new(h.x, h.y, math.cos(ang) * 70, math.sin(ang) * 70, 28, false)
    bb.color = {0.9, 0.3, 1}
    bb.size = 30
    bb.churglyBigAttack = true
    bb.life = 10          -- stays on screen much longer so you can shoot it
    table.insert(game.enemyBullets, bb)
    P:spawn(h.x, h.y, 16, {0.9, 0.3, 1}, 220, 0.4, 4)
    Audio:play("boss")
end

local function fireTracers(game, b)
    local p = game.player
    if not p then return end
    local h = b.headPos
    for i = 1, 3 do
        local a = math.atan2(p.y - h.y, p.x - h.x) + (math.random() - 0.5) * 0.1
        local bb = Bullet.new(h.x, h.y, math.cos(a) * 420, math.sin(a) * 420, 18, false)
        bb.color = {1, 0.9, 0.3}; bb.size = 5
        bb.churglySmall = true
        table.insert(game.enemyBullets, bb)
    end
end

-- =============================================================================
-- UPDATE
-- =============================================================================

function Churglyfight.update(dt, game)
    local b = game.churglyBoss
    if not b then return end
    b.life = b.life + dt
    -- Recompute positions every frame (head moves, spine curves)
    computePositions(b.life, b)

    if b.phase == "fight" then
        -- Tick major segment flash timers; check deaths
        for idx, m in pairs(b.majors) do
            if not m.dead then
                m.flash = math.max(0, m.flash - dt * 4)
                if m.hp <= 0 then
                    m.dead = true
                    local pos = b.segPositions[idx]
                    if pos then
                        P:spawn(pos.x, pos.y, 80, {0.8, 0.2, 1}, 520, 1.3, 8)
                        P:spawn(pos.x, pos.y, 40, {1, 0.3, 0.6}, 420, 1.0, 6)
                    end
                    Audio:play("explode")
                    Audio:play("cthulhu")
                end
            end
        end

        -- Count dead majors for escalation
        local totalMajors, deadMajors = 0, 0
        for _, m in pairs(b.majors) do
            totalMajors = totalMajors + 1
            if m.dead then deadMajors = deadMajors + 1 end
        end

        -- Head flash + aim
        b.head.flash = math.max(0, b.head.flash - dt * 4)

        -- Attacks — escalate as segments fall
        b.attackTimer = b.attackTimer - dt
        if b.attackTimer <= 0 then
            local pattern = math.random(1, 3)
            b.attackTimer = 2.8 - deadMajors * 0.22
            if pattern == 1 then fireBarrageFromHead(game, b)
            elseif pattern == 2 then fireHomingFromSpine(game, b)
            else fireSweepFromHead(game, b) end
        end
        b.specialTimer = b.specialTimer - dt
        if b.specialTimer <= 0 then
            b.specialTimer = 6.5 - deadMajors * 0.3
            fireTracers(game, b)
        end
        -- Big attack timer — one floating orb every ~7s, shootable for
        -- massive damage to the nearest segment.
        b.bigTimer = (b.bigTimer or 5) - dt
        if b.bigTimer <= 0 then
            b.bigTimer = 7.5 - deadMajors * 0.4
            fireBigOrb(game, b)
        end

        -- CHURGLY'NTH SPEAKS — cryptic, mysterious lines about Ugnrak,
        -- never revealing too much about who or what Ugnrak actually is.
        b.talkTimer = (b.talkTimer or 2.5) - dt
        if b.talkTimer <= 0 then
            b.talkTimer = 2.2 + math.random() * 1.4
            local lines = {
                "YOU PARROTED UGNRAK'S NAME...",
                "THE BEAM WAS NOT YOURS.",
                "HE WATCHES THROUGH YOU.",
                "UGNRAK'S BORROWED TONGUE.",
                "YOU ARE A KEY HE TURNED.",
                "HE WILL COME FOR YOU TOO.",
                "SMALL VOICE. BIGGER HUNGER.",
                "HIS SHADOW DRANK ME...",
                "YOU DO NOT KNOW HIM.",
                "HE LET YOU LIVE FOR A REASON.",
                "THE SHELL WAS A GIFT. FROM HIM.",
                "UGNRAK DOES NOT FORGET A DEBT.",
                "WHEN HE CALLS, YOU WILL RUN.",
                "HE IS THE QUESTION I FEARED.",
            }
            local msg = lines[math.random(#lines)]
            P:text(640 + math.random(-220, 220), 180 + math.random(-40, 40),
                msg, {1, 0.3, 0.5}, 3.2)
            if math.random() < 0.4 then Audio:play("whisper") end
        end

        -- Homing bullet tracking
        local p = game.player
        for _, bb in ipairs(game.enemyBullets) do
            if bb.churglyHoming and not bb.dead then
                local ddx = p.x - bb.x
                local ddy = p.y - bb.y
                local len = math.max(1, math.sqrt(ddx * ddx + ddy * ddy))
                bb.vx = bb.vx + (ddx / len) * bb.churglyHoming * dt * 60
                bb.vy = bb.vy + (ddy / len) * bb.churglyHoming * dt * 60
            end
        end

        -- All majors dead: head is exposed but only vulnerable to Ugnrak
        -- orbs — player bullets don't hurt him. Player must shoot down one
        -- of Churgly's big orbs near him to finish the fight.
    elseif b.phase == "dying" then
        b.deathTimer = b.deathTimer + dt
        local d = b.deathTimer
        -- Detailed unravel cinematic (total ~22 s):
        --   0-3   FRACTURE — diagonal cracks crawl across screen, boss body
        --         starts shedding chunks, background distorts
        --   3-9   DISSOLUTION — large screen shards peel off, rotate, fly
        --         in random directions with chromatic aberration trails
        --   9-13  VOID CREEP — radial black wipe shrinks the world, particles
        --         spiral inward, everything converges on center
        --   13-16 STASIS — pitch black, faint ember motes
        --   16-21 "There is nothing left." — 5 full seconds of the epitaph
        --   21    return to menu

        -- Music fade over first 4s
        if d < 4 and Audio.music then
            local vol = math.max(0, 1 - d / 4)
            Audio.music:setVolume(vol * 0.65)
        elseif d >= 4 and Audio.music and Audio.music:isPlaying() then
            Audio:stopMusic()
        end

        -- Initialize unravel state on first tick
        if not b.unravelInit then
            b.unravelInit = true
            b.cracks = {}
            b.shards = {}
            b.embers = {}
            -- Seed cracks radiating from random points
            for i = 1, 14 do
                local ox = math.random(0, 1280)
                local oy = math.random(0, 720)
                for j = 1, 2 + math.random(3) do
                    local ang = math.random() * math.pi * 2
                    table.insert(b.cracks, {
                        x = ox, y = oy, ang = ang,
                        grow = 100 + math.random() * 400,  -- px/s
                        len = 0, maxLen = 300 + math.random() * 700,
                        branches = {},
                    })
                end
            end
        end

        -- PHASE 1: cracks grow outward
        if d < 6 then
            for _, c in ipairs(b.cracks) do
                if c.len < c.maxLen then
                    c.len = c.len + c.grow * dt
                    if c.len > c.maxLen then c.len = c.maxLen end
                    -- Spawn branches randomly along its length
                    if math.random() < dt * 3 and #c.branches < 6 then
                        table.insert(c.branches, {
                            at = math.random() * c.len,
                            ang = c.ang + (math.random() - 0.5) * 1.2,
                            len = 0, maxLen = 80 + math.random() * 200,
                            grow = 180 + math.random() * 300,
                        })
                    end
                end
                for _, br in ipairs(c.branches) do
                    if br.len < br.maxLen then
                        br.len = br.len + br.grow * dt
                        if br.len > br.maxLen then br.len = br.maxLen end
                    end
                end
            end
        end

        -- PHASE 2: shards peel off screen. Spawn new shards rapidly during 3-9s.
        if d >= 3 and d < 9 and math.random() < dt * 14 then
            local sx = math.random(0, 1280)
            local sy = math.random(0, 720)
            local sw = 40 + math.random(120)
            local sh = 40 + math.random(120)
            local ang = math.atan2(sy - 360, sx - 640) + (math.random() - 0.5) * 0.8
            table.insert(b.shards, {
                x = sx, y = sy, w = sw, h = sh,
                vx = math.cos(ang) * (80 + math.random(160)),
                vy = math.sin(ang) * (80 + math.random(160)),
                rot = 0, vrot = (math.random() - 0.5) * 3,
                life = 4.0, max = 4.0,
                hue = {math.random() * 0.7, math.random() * 0.4, math.random() * 0.7 + 0.3},
            })
        end
        -- Advance shards
        for i = #b.shards, 1, -1 do
            local s = b.shards[i]
            s.x = s.x + s.vx * dt
            s.y = s.y + s.vy * dt
            s.rot = s.rot + s.vrot * dt
            s.life = s.life - dt
            s.vx = s.vx * (1 + dt * 0.3)  -- slight acceleration
            s.vy = s.vy * (1 + dt * 0.3)
            if s.life <= 0 then table.remove(b.shards, i) end
        end

        -- PHASE 2-3: continuous colored particle rain
        if d < 13 then
            local rate = (d < 9) and 220 or 80
            for _ = 1, math.floor(dt * rate) do
                local x, y = math.random(0, 1280), math.random(0, 720)
                P:spawn(x, y, 1 + math.random(2),
                    {math.random() * 0.8 + 0.2, math.random() * 0.4, math.random() * 0.8 + 0.2},
                    120 + math.random(240), 0.6 + math.random() * 0.8, 3)
            end
        end

        -- PHASE 3: void creep radius shrinks from 1200 to 0
        if d >= 9 then
            local t = math.min(1, (d - 9) / 4)
            b.voidRadius = 1200 * (1 - t)
        else
            b.voidRadius = nil
        end

        -- Ember motes orbiting toward center during STASIS
        if d >= 13 and d < 16 and math.random() < dt * 22 then
            local a = math.random() * math.pi * 2
            local r = 40 + math.random() * 200
            table.insert(b.embers, {
                x = 640 + math.cos(a) * r,
                y = 360 + math.sin(a) * r,
                life = 1.5 + math.random(),
            })
        end
        for i = #b.embers, 1, -1 do
            local e = b.embers[i]
            local dx = 640 - e.x
            local dy = 360 - e.y
            local len = math.max(1, math.sqrt(dx * dx + dy * dy))
            e.x = e.x + (dx / len) * 30 * dt
            e.y = e.y + (dy / len) * 30 * dt
            e.life = e.life - dt
            if e.life <= 0 then table.remove(b.embers, i) end
        end

        -- Clear residual entities
        if d > 1 then
            game.enemies = {}
            game.enemyBullets = {}
            game.bullets = {}
            game.pendingSpawns = {}
        end

        -- Compute fade states for draw
        b.bodyAlpha = math.max(0, 1 - d / 2.5)                    -- body shreds away 0-2.5s
        b.blackAlpha = math.max(0, math.min(1, (d - 9) / 4))      -- black 0→1 over 9-13s
        b.endTextAlpha = 0
        if d >= 16 and d < 21 then
            b.endTextAlpha = math.min(1, (d - 16) / 0.6)
            if d >= 20.4 then
                b.endTextAlpha = math.max(0, (21 - d) / 0.6)
            end
        end

        if d >= 21 then
            b.phase = "done"
            if Audio.music then Audio.music:setVolume(0.65) end
            game.state = "menu"
            game.churglyBoss = nil
        end
    end
end

-- =============================================================================
-- DAMAGE
-- =============================================================================

-- Player bullet hit test — returns true if any major segment / head was hit.
function Churglyfight.damageNearest(game, x, y, dmg, radius)
    local b = game.churglyBoss
    if not b or b.phase ~= "fight" then return false end
    radius = radius or 4
    -- Test against major segments using the fresh segPositions
    for idx, m in pairs(b.majors) do
        if not m.dead then
            local pos = b.segPositions[idx]
            if pos then
                local dx, dy = pos.x - x, pos.y - y
                if dx * dx + dy * dy < (radius + pos.r) ^ 2 then
                    m.hp = m.hp - dmg
                    m.flash = 0.35
                    return true
                end
            end
        end
    end
    -- Head is NEVER damaged by direct player bullets. You have to pop one
    -- of Churgly's big orbs NEAR HIM to kill it (see explodeBullet below).
    return false
end

-- Exploding a churgly bullet (shoot it down) → large, visible detonation
-- on the nearest segment. Once every segment is dead the exposed head
-- becomes the target — a single orb-pop next to him ends the fight in a
-- massive bang.
function Churglyfight.explodeBullet(game, x, y)
    local b = game.churglyBoss
    if not b or b.phase ~= "fight" then return end
    -- Check head-kill path first (all majors dead)
    local allDead = true
    for _, m in pairs(b.majors) do if not m.dead then allDead = false; break end end
    if allDead and not b.head.dead then
        b.head.hp = 0
        b.head.dead = true
        b.head.flash = 1
        local hx, hy = b.headPos.x, b.headPos.y
        P:spawn(hx, hy, 240, {1, 0.3, 0.9}, 860, 1.8, 12)
        P:spawn(hx, hy, 160, {1, 0.9, 0.4}, 700, 1.5, 10)
        P:spawn(hx, hy, 120, {1, 0.5, 0.2}, 620, 1.3, 9)
        P:spawn(hx, hy, 80,  {1, 1, 0.9},   460, 1.0, 8)
        table.insert(game.shockwaves or {}, {
            x = hx, y = hy, r = 0, max = 260,
            life = 0.7, color = {1, 0.5, 0.3},
        })
        table.insert(game.shockwaves or {}, {
            x = hx, y = hy, r = 0, max = 180,
            life = 0.55, color = {1, 0.95, 0.5},
        })
        game.screenFlash = math.max(game.screenFlash or 0, 0.9)
        Audio:play("explode")
        Audio:play("boss")
        Audio:play("cthulhu")
        Audio:play("glitch")
        defeat(game)
        return
    end
    -- Segment damage path
    local nearest, ndist, nearIdx
    for idx, m in pairs(b.majors) do
        if not m.dead then
            local pos = b.segPositions[idx]
            if pos then
                local dx, dy = pos.x - x, pos.y - y
                local d = dx * dx + dy * dy
                if not ndist or d < ndist then ndist = d; nearest = m; nearIdx = idx end
            end
        end
    end
    if nearest then
        nearest.hp = nearest.hp - 666  -- Ugnrak's number
        nearest.flash = 1.0
        local pos = b.segPositions[nearIdx]
        if pos then
            -- BIG visible blast on the segment — multi-layer particle bursts
            -- and an expanding shockwave ring so the hit reads from anywhere.
            P:spawn(pos.x, pos.y, 120, {1, 0.9, 0.4}, 720, 1.4, 10)
            P:spawn(pos.x, pos.y, 80,  {1, 0.5, 0.2}, 560, 1.1, 8)
            P:spawn(pos.x, pos.y, 60,  {0.9, 0.3, 1}, 420, 1.0, 7)
            P:spawn(pos.x, pos.y, 40,  {1, 1, 0.8},   300, 0.8, 6)
            -- Expanding shockwave ring
            table.insert(game.shockwaves or {}, {
                x = pos.x, y = pos.y, r = 0, max = 160,
                life = 0.55, color = {1, 0.7, 0.3},
            })
            table.insert(game.shockwaves or {}, {
                x = pos.x, y = pos.y, r = 0, max = 100,
                life = 0.35, color = {1, 0.95, 0.6},
            })
            P:text(pos.x, pos.y - 40, "-666", {1, 0.9, 0.4}, 1.6)
            -- Loud, stacked SFX
            Audio:play("explode")
            Audio:play("boss")
            Audio:play("cthulhu")
        end
    end
end

-- =============================================================================
-- DRAW — mirrors drawChurglyForm, scaled by SCALE. Opaque. HP bars on majors.
-- =============================================================================

local function drawBodySegment(pos, tParam, t, idx, major)
    local size = pos.r
    local falloff = 1 - tParam
    -- 4 writhing tentacles out of every segment (base axes + wobble)
    local tentBase = size * 1.8 + 4
    for i = 1, 4 do
        local ang = (i / 4) * math.pi * 2 + t * 0.7 + idx * 0.3
        local segs = 6
        local ppx, ppy = pos.x, pos.y
        local a = ang
        for step = 1, segs do
            local a2 = a + math.sin(t * 3 + step * 0.5 + i + idx) * 0.45
            local nx = ppx + math.cos(a2) * (tentBase / segs)
            local ny = ppy + math.sin(a2) * (tentBase / segs)
            local wd = ((1 - step / segs) * 4 + 1) * (0.6 + falloff * 0.8)
            love.graphics.setColor(0.12, 0.02, 0.22)
            love.graphics.setLineWidth(wd + 1)
            love.graphics.line(ppx, ppy, nx, ny)
            love.graphics.setColor(0.5, 0.1, 0.75)
            love.graphics.setLineWidth(wd)
            love.graphics.line(ppx, ppy, nx, ny)
            ppx, ppy = nx, ny
        end
        love.graphics.setColor(1, 0.5, 1, 0.85 * falloff + 0.15)
        love.graphics.circle("fill", ppx, ppy, 2 * falloff + 1)
    end
    love.graphics.setLineWidth(1)
    -- Overlapping rings of purple flesh
    local flashBoost = (major and major.flash or 0) * 0.7
    love.graphics.setColor(0.18 * falloff + 0.08 + flashBoost,
                           0.02 + flashBoost * 0.5,
                           0.28 * falloff + 0.1 + flashBoost)
    love.graphics.circle("fill", pos.x, pos.y, size)
    love.graphics.setColor(0.55 * falloff + 0.1, 0.08, 0.55 * falloff + 0.1)
    love.graphics.setLineWidth(major and 2.5 or 1.5)
    love.graphics.circle("line", pos.x, pos.y, size)
    love.graphics.setLineWidth(1)
    -- Lizard mouth
    local open = 0.45 + 0.55 * math.abs(math.sin(t * 1.5 + idx * 0.5))
    local jaw = size * 0.55 * open
    love.graphics.setColor(0.04, 0, 0.08)
    love.graphics.polygon("fill",
        pos.x - size * 0.5, pos.y,
        pos.x + size * 0.5, pos.y - jaw,
        pos.x + size * 0.5, pos.y + jaw)
    -- Teeth
    love.graphics.setColor(0.95, 0.9, 0.8)
    for k = 0, 3 do
        local tx = pos.x - size * 0.5 + (k + 1) * (size / 5)
        love.graphics.polygon("fill",
            tx, pos.y - jaw * 0.9,
            tx - 1.6, pos.y - jaw * 0.3,
            tx + 1.6, pos.y - jaw * 0.3)
        love.graphics.polygon("fill",
            tx, pos.y + jaw * 0.9,
            tx - 1.6, pos.y + jaw * 0.3,
            tx + 1.6, pos.y + jaw * 0.3)
    end
    -- Slit eye
    love.graphics.setColor(1, 0.75, 0.15)
    love.graphics.circle("fill", pos.x - size * 0.3, pos.y - size * 0.55, size * 0.15)
    love.graphics.setColor(0, 0, 0)
    love.graphics.ellipse("fill", pos.x - size * 0.3, pos.y - size * 0.55, size * 0.05, size * 0.14)

    -- HP bar for majors
    if major and not major.dead then
        local ratio = math.max(0, major.hp / major.maxHp)
        local bw = size * 1.8
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", pos.x - bw / 2 - 1, pos.y - size - 12, bw + 2, 6)
        love.graphics.setColor(0.9, 0.2, 0.3)
        love.graphics.rectangle("fill", pos.x - bw / 2, pos.y - size - 11, bw * ratio, 4)
    end
end

local function drawHead(b, t)
    local h = b.headPos
    local headR = h.r
    local p = b.game and b.game.player
    -- Tentacles/spikes around the head (chaotic)
    local spikes = 16
    for i = 1, spikes do
        local a = (i / spikes) * math.pi * 2 + t * 0.4
        local flex = 0.55 + 0.45 * math.sin(t * 9 + i * 1.7)
        local noise = math.sin(t * 13 + i * 3.3) * 0.3
        local sLen = headR * (0.85 + flex + noise)
        local tipX = h.x + math.cos(a) * (headR + sLen)
        local tipY = h.y + math.sin(a) * (headR + sLen)
        local bx = h.x + math.cos(a) * headR * 0.95
        local by = h.y + math.sin(a) * headR * 0.95
        local perpX = -math.sin(a) * headR * 0.16
        local perpY =  math.cos(a) * headR * 0.16
        love.graphics.setColor(0.15, 0.02, 0.3)
        love.graphics.polygon("fill",
            bx + perpX, by + perpY,
            bx - perpX, by - perpY,
            tipX, tipY)
    end
    -- Body
    love.graphics.setColor(0.2 + b.head.flash * 0.6, 0.03, 0.38 + b.head.flash * 0.4)
    love.graphics.circle("fill", h.x, h.y, headR)
    love.graphics.setColor(0.45, 0.12, 0.7)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", h.x, h.y, headR)
    love.graphics.setLineWidth(1)
    -- Upside-down triangle maw (wide top edge, apex at bottom) in world
    -- space — no rotation with aim. Matches the Churgly'nth face cosmetic.
    local maw = 0.4 + 0.6 * math.abs(math.sin(t * 1.3))
    love.graphics.setColor(0, 0, 0)
    love.graphics.polygon("fill",
        h.x - headR * 0.72, h.y - headR * 0.25,  -- top-left
        h.x + headR * 0.72, h.y - headR * 0.25,  -- top-right
        h.x,                h.y + headR * 0.95 * maw)  -- apex
    -- Twin side eyes flanking the top of the mouth (vertical slits)
    for side = -1, 1, 2 do
        local ex = h.x + side * headR * 0.58
        local ey = h.y - headR * 0.05
        love.graphics.setColor(1, 0.8, 0.15)
        love.graphics.circle("fill", ex, ey, headR * 0.2)
        love.graphics.setColor(0, 0, 0)
        love.graphics.ellipse("fill", ex, ey, headR * 0.06, headR * 0.18)
    end
    -- Head HP bar (only when vulnerable — all majors dead)
    local allDead = true
    for _, m in pairs(b.majors) do if not m.dead then allDead = false; break end end
    if allDead and not b.head.dead then
        local ratio = math.max(0, b.head.hp / b.head.maxHp)
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", h.x - 85, h.y - headR - 22, 172, 9)
        love.graphics.setColor(1, 0.25, 0.35)
        love.graphics.rectangle("fill", h.x - 84, h.y - headR - 21, 170 * ratio, 7)
    end
end

function Churglyfight.draw(game)
    local b = game.churglyBoss
    if not b then return end
    b.game = game -- for head draw access
    local t = b.life
    local bodyAlpha = b.bodyAlpha or 1.0

    -- Dark veil
    love.graphics.setColor(0.06, 0.0, 0.12, 0.6)
    love.graphics.rectangle("fill", 0, 40, 1280, 680)

    -- Connector body between segments — thick purple flesh, grayed at dead majors
    love.graphics.setLineWidth(14 * SCALE)
    for i = 1, SEGMENT_COUNT - 1 do
        local a = b.segPositions[i]
        local z = b.segPositions[i + 1]
        local aMajor = b.majors[i]
        local zMajor = b.majors[i + 1]
        local dead = (aMajor and aMajor.dead) or (zMajor and zMajor.dead)
        if dead then
            love.graphics.setColor(0.3, 0.3, 0.33)
        else
            love.graphics.setColor(0.2, 0.04, 0.32)
        end
        love.graphics.line(a.x, a.y, z.x, z.y)
    end
    love.graphics.setLineWidth(1)

    -- Draw segments from TAIL (idx 48) back to HEAD (idx 1) so the head
    -- sits on top visually. Dead major segments render as dim gray husks.
    for i = SEGMENT_COUNT, 1, -1 do
        local pos = b.segPositions[i]
        if pos then
            local major = b.majors[i]
            local dead = major and major.dead
            if dead then
                -- Gray husk: simple dim circle, no tentacles/teeth/eye
                love.graphics.setColor(0.28, 0.28, 0.3)
                love.graphics.circle("fill", pos.x, pos.y, pos.r)
                love.graphics.setColor(0.45, 0.45, 0.48)
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", pos.x, pos.y, pos.r)
                love.graphics.setLineWidth(1)
            else
                drawBodySegment(pos, pos.t, t, i, major)
            end
        end
    end

    -- Fractal vanishing-point dot cluster at screen center
    for i = 1, 14 do
        local f = 1 - i / 14
        local twist = t * 0.8 + i * 0.3
        local dotX = VANISH_X + math.cos(twist) * (6 + i * 2) * f
        local dotY = VANISH_Y + math.sin(twist) * (6 + i * 2) * f
        love.graphics.setColor(0.3 * f, 0.04, 0.3 * f)
        love.graphics.circle("fill", dotX, dotY, 5 * f + 0.8)
    end
    love.graphics.setColor(0.02, 0.0, 0.04)
    love.graphics.circle("fill", VANISH_X, VANISH_Y, 6)

    -- Head (on top)
    if not b.head.dead then drawHead(b, t) end

    -- DYING CINEMATIC overlays — cracks growing, screen shards peeling off,
    -- radial void creep, ember motes spiralling inward, then pitch black.
    if b.phase == "dying" then
        local d = b.deathTimer

        -- Growing crack lines
        if b.cracks then
            love.graphics.setLineWidth(2)
            for _, c in ipairs(b.cracks) do
                local ex = c.x + math.cos(c.ang) * c.len
                local ey = c.y + math.sin(c.ang) * c.len
                love.graphics.setColor(1, 1, 1, 0.7)
                love.graphics.line(c.x, c.y, ex, ey)
                love.graphics.setColor(0.4, 0.1, 0.55, 0.85)
                love.graphics.setLineWidth(5)
                love.graphics.line(c.x, c.y, ex, ey)
                love.graphics.setLineWidth(2)
                love.graphics.setColor(1, 0.9, 0.5, 0.9)
                love.graphics.line(c.x, c.y, ex, ey)
                -- Branches
                for _, br in ipairs(c.branches) do
                    local bx = c.x + math.cos(c.ang) * br.at
                    local by = c.y + math.sin(c.ang) * br.at
                    local bex = bx + math.cos(br.ang) * br.len
                    local bey = by + math.sin(br.ang) * br.len
                    love.graphics.setColor(1, 1, 1, 0.55)
                    love.graphics.setLineWidth(1.5)
                    love.graphics.line(bx, by, bex, bey)
                end
            end
            love.graphics.setLineWidth(1)
        end

        -- Screen shards peeling off + rotating
        if b.shards then
            for _, s in ipairs(b.shards) do
                local a = math.max(0, math.min(1, s.life / s.max))
                love.graphics.push()
                love.graphics.translate(s.x, s.y)
                love.graphics.rotate(s.rot)
                -- Chromatic split: red + blue offset behind main
                love.graphics.setColor(1, 0.2, 0.2, 0.35 * a)
                love.graphics.rectangle("fill", -s.w / 2 + 3, -s.h / 2, s.w, s.h)
                love.graphics.setColor(0.3, 0.6, 1, 0.35 * a)
                love.graphics.rectangle("fill", -s.w / 2 - 3, -s.h / 2, s.w, s.h)
                love.graphics.setColor(s.hue[1], s.hue[2], s.hue[3], 0.85 * a)
                love.graphics.rectangle("fill", -s.w / 2, -s.h / 2, s.w, s.h)
                love.graphics.setColor(1, 1, 1, 0.8 * a)
                love.graphics.setLineWidth(1.5)
                love.graphics.rectangle("line", -s.w / 2, -s.h / 2, s.w, s.h)
                love.graphics.pop()
            end
            love.graphics.setLineWidth(1)
        end

        -- VOID CREEP: radial black wipe shrinking inward
        if b.voidRadius and b.voidRadius > 0 then
            -- Layered ring so the edge looks violent, not just a hole
            love.graphics.setColor(0.12, 0.02, 0.18, 0.6)
            love.graphics.circle("fill", 640, 360, b.voidRadius + 120)
            love.graphics.setColor(0, 0, 0, 0.92)
            -- Inverse black: cover everything OUTSIDE the radius
            local ox, oy = 0, 0
            love.graphics.rectangle("fill", 0, 0, 1280, math.max(0, 360 - b.voidRadius))
            love.graphics.rectangle("fill", 0, math.min(720, 360 + b.voidRadius), 1280,
                math.max(0, 720 - (360 + b.voidRadius)))
            love.graphics.rectangle("fill", 0, 0, math.max(0, 640 - b.voidRadius), 720)
            love.graphics.rectangle("fill", math.min(1280, 640 + b.voidRadius), 0,
                math.max(0, 1280 - (640 + b.voidRadius)), 720)
            -- Rim glow
            love.graphics.setColor(0.8, 0.3, 1, 0.5)
            love.graphics.setLineWidth(6)
            love.graphics.circle("line", 640, 360, b.voidRadius)
            love.graphics.setColor(1, 0.6, 1, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", 640, 360, b.voidRadius)
            love.graphics.setLineWidth(1)
        end

        -- Ember motes during stasis
        if b.embers then
            for _, e in ipairs(b.embers) do
                local a = math.min(1, e.life)
                love.graphics.setColor(1, 0.5 + a * 0.3, 0.2, 0.8 * a)
                love.graphics.circle("fill", e.x, e.y, 1.6)
                love.graphics.setColor(1, 1, 0.8, 0.4 * a)
                love.graphics.circle("fill", e.x, e.y, 3.2)
            end
        end

        -- Final pitch-black overlay
        local ba = b.blackAlpha or 0
        if ba > 0 then
            love.graphics.setColor(0, 0, 0, ba)
            love.graphics.rectangle("fill", 0, 0, 1280, 720)
        end

        -- Epitaph text
        if (b.endTextAlpha or 0) > 0 then
            love.graphics.setFont(game.titleFont or game.bigFont or game.font)
            love.graphics.setColor(1, 1, 1, b.endTextAlpha)
            love.graphics.printf("There is nothing left.", 0, 340, 1280, "center")
            love.graphics.setFont(game.font)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Churglyfight
