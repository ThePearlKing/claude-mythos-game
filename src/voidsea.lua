-- The Void Sea: the secret dive beneath the world.
-- Four phases:
--   A (0-800):     glowing yellow abyss. Swimming down slowly refills your reputation.
--   B (800-1600):  black abyss. 17 Churgly'nths streak past at absurd speeds, thundering.
--   C (1600-2400): one Churgly'nth meets you and carries you gently downward.
--   D (2400+):     a white glow pulls you home. Swim into it to ASCEND and win.
-- Enemies from the surface can't touch you here. Your reputation only goes up.

local Audio = require("src.audio")
local P = require("src.particles")

local Voidsea = {}

-- Deeper thresholds so the full descent takes longer (~45-90 seconds).
local PHASE_B = 1500
local PHASE_C = 3000
local PHASE_D = 4500
local WHITE_GLOW_Y = 560 -- screen y of the white glow in phase D

function Voidsea.enter(game)
    -- Escape hatch from THE KING obliteration: diving into the Void Sea
    -- cancels Churgly'nth's targeting. The hallucinations end too.
    if game.player and game.player.eldritch and game.player.eldritch.kingOblit then
        game.player.eldritch.kingOblit = nil
        game.player.eldritch.kingFractal = 0
        game.player.eldritch.cthuluCracks = nil
        game.player.eldritch.cthulhu = nil
        game.player.kingVisions = false
        game.screenFlash = 0
        P:text(640, 200, "YOU SLIP BENEATH HIS GAZE", {1, 0.95, 0.5}, 4)
    end
    game.state = "voidsea"
    game.void = {
        depth      = 0,
        phase      = "A",
        bubbles    = {},
        churglies  = {},  -- array of 17 for phase B
        carrier    = nil, -- single Churgly'nth for phase C
        phaseTimer = 0,
        repBanked  = 0,
        whiteAlpha = 0,
        carrierStarted = false,
        spawnedB   = false,
        pulseTimer = 0,
    }
    -- Snap player to the middle of the screen — they stay here for the whole descent.
    game.player.x = 640
    game.player.y = 360
    game.player.voidVy = 0
    game.player.swimming = true
    -- Wipe the surface board — they can't follow.
    game.enemies = {}
    game.enemyBullets = {}
    game.pendingSpawns = {}
    game.shockwaves = {}
    Audio:play("whisper")
    Audio:playMusic("voidsea")
end

function Voidsea.ascend(game)
    -- Win the run as if you finished the final wave.
    game.persist.slugcrabUnlocked = 1
    require("src.save").save(game.persist)
    game.player.swimming = false
    game.state = "victory"
    game.endTime = 0
    game:recordRunResult(true)
    Audio:play("victory")
    Audio:stopMusic()
    P:text(640, 240, "YOU ASCEND FROM THE VOID SEA", {1, 1, 1}, 4)
    P:text(640, 280, "SOMETHING HAS BEEN UNLOCKED", {0.9, 0.9, 1}, 4)
end

function Voidsea.update(dt, game)
    local v = game.void
    local p = game.player
    v.phaseTimer = v.phaseTimer + dt

    -- Crab stays locked to screen center, swimming in place.
    p.x = 640
    p.y = 360
    p.swimming = true
    p.legPhase = (p.legPhase or 0) + dt * 18 -- faster leg kicks

    -- Intentions: W = rise (slow retreat), S = descend (deepen)
    local dy = 0
    if love.keyboard.isDown("s") then dy = 1 end
    if love.keyboard.isDown("w") then dy = -1 end

    -- Descent updates "depth" only — no player translation
    local descentRate = 0
    if dy > 0 then descentRate = 70 end
    if dy < 0 then descentRate = -35 end
    v.depth = math.max(0, v.depth + descentRate * dt)

    -- Chaotic pulse noise SFX while descending
    v.pulseTimer = (v.pulseTimer or 0) - dt
    if descentRate > 0 and v.pulseTimer <= 0 then
        v.pulseTimer = 0.18 + math.random() * 0.35
        if math.random() < 0.5 then Audio:play("whisper") end
        if math.random() < 0.25 then Audio:play("glitch") end
        if math.random() < 0.15 then Audio:play("explode") end
    end

    -- Bubbles rising (yellow in phase A, blue-white in later phases).
    if math.random() < dt * 18 then
        table.insert(v.bubbles, {
            x = math.random(0, 1280),
            y = 720 + math.random(0, 60),
            r = 1 + math.random() * 3,
            vy = -20 - math.random() * 40,
        })
    end
    for i = #v.bubbles, 1, -1 do
        local b = v.bubbles[i]
        b.y = b.y + b.vy * dt
        if b.y < -20 then table.remove(v.bubbles, i) end
    end

    -- Phase transitions
    if v.phase == "A" and v.depth >= PHASE_B then
        v.phase = "B"
        v.phaseTimer = 0
        -- Spawn 17 fast Churglies streaking horizontally at various Y bands
        v.churglies = {}
        for i = 1, 17 do
            local side = (i % 2 == 0) and -1 or 1
            local startX = side == 1 and -300 or 1580
            table.insert(v.churglies, {
                x = startX, y = 60 + (i * 34) % 620,
                vx = side * (900 + math.random(0, 700)),
                phase = math.random() * math.pi * 2,
                scale = 1.4 + math.random() * 1.2, -- much bigger
            })
        end
        Audio:play("cthulhu")
        Audio:play("boss")
    elseif v.phase == "B" and v.depth >= PHASE_C then
        v.phase = "C"
        v.phaseTimer = 0
        v.carrier = {x = p.x, y = -100, vy = 0, offsetX = p.x, offsetY = p.y}
        Audio:play("eldritch")
    elseif v.phase == "C" and v.depth >= PHASE_D then
        v.phase = "D"
        v.phaseTimer = 0
        v.carrier = nil
        Audio:play("victory")
    end

    -- Phase A: reputation trickles up while you survive the descent.
    if v.phase == "A" then
        v.repBanked = v.repBanked + dt * 2
        if v.repBanked >= 1 then
            local gain = math.floor(v.repBanked)
            v.repBanked = v.repBanked - gain
            p.reputation = math.min(100, p.reputation + gain)
            if math.random() < 0.3 then
                P:text(p.x + math.random(-8, 8), p.y - 10, "+" .. gain .. " rep", {1, 0.9, 0.3}, 0.8)
            end
        end
    end

    -- Phase B: Churglies streaking past, looping edges, loud rumble SFX.
    if v.phase == "B" then
        for _, c in ipairs(v.churglies) do
            c.x = c.x + c.vx * dt
            c.y = c.y + math.sin(c.phase + love.timer.getTime() * 3) * 60 * dt
            if c.x < -400 then c.x = 1600 end
            if c.x > 1700 then c.x = -300 end
        end
        if math.random() < dt * 6 then Audio:play("boss") end
        if math.random() < dt * 4 then Audio:play("cthulhu") end
    end

    -- Phase C: a single Churgly descends and carries you silently deeper.
    if v.phase == "C" and v.carrier then
        v.carrier.x = v.carrier.x + (640 - v.carrier.x) * dt * 1.2
        v.carrier.y = math.min(340, v.carrier.y + 120 * dt)
        -- Auto-descend while carried
        if v.carrier.y >= 300 then
            v.depth = v.depth + 45 * dt
        end
        if math.random() < dt * 2 then Audio:play("whisper") end
    end

    -- Phase D: bright white glow rises up. Auto-ascend once it fully envelops you.
    if v.phase == "D" then
        v.whiteAlpha = math.min(1, v.whiteAlpha + dt * 0.35)
        if v.whiteAlpha >= 0.97 then
            Voidsea.ascend(game)
        end
    end
end

-- Render the Void Sea.
function Voidsea.draw(game)
    local v = game.void
    local t = love.timer.getTime()
    -- Background by phase
    if v.phase == "A" then
        -- Glowing yellow abyss that gets MURKIER and DIRTIER with depth.
        -- depthRatio 0 = clean yellow, 1 = nearly black (about to enter phase B)
        local depthRatio = math.min(1, v.depth / PHASE_B)
        local clean = 1 - depthRatio
        for i = 0, 30 do
            local y = i * 24
            local k = i / 30
            -- Base yellow gradient, multiplied by clean factor so it fades
            local r = (0.05 + k * 0.60) * clean + 0.02
            local g = (0.04 + k * 0.45) * clean + 0.01
            local b = 0.02 + depthRatio * 0.04
            -- Dirty sediment streaks at deeper half
            if depthRatio > 0.3 then
                local dirt = (depthRatio - 0.3) * 0.25
                r = r * (1 - dirt) + 0.08 * dirt
                g = g * (1 - dirt) + 0.05 * dirt
            end
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", 0, y, 1280, 24)
        end
        -- Glow rays also dim with depth
        for i = 1, 6 do
            local x = (i * 220 + math.sin(t * 0.3 + i) * 50) % 1280
            love.graphics.setColor(1, 0.85, 0.2, 0.10 * clean)
            love.graphics.polygon("fill", x, 0, x + 120, 0, x + 260, 720, x - 40, 720)
        end
        -- Dirty particulates drift in the deeper half
        if depthRatio > 0.25 then
            local pc = math.floor(40 * (depthRatio - 0.25))
            for i = 1, pc do
                local px = ((i * 73 + t * 30) % 1280)
                local py = ((i * 151 + t * 60) % 720)
                love.graphics.setColor(0.15, 0.08, 0.03, 0.45 * depthRatio)
                love.graphics.circle("fill", px, py, 1)
            end
        end
        -- Bubbles — tint shifts from yellow to grimy as depth grows
        for _, b in ipairs(v.bubbles) do
            love.graphics.setColor(1 * clean + 0.2 * depthRatio, 0.95 * clean + 0.15 * depthRatio, 0.3 * clean, 0.55)
            love.graphics.circle("line", b.x, b.y, b.r)
        end
    elseif v.phase == "B" then
        -- Black abyss with occasional deep-violet pulse
        love.graphics.clear(0.01, 0.0, 0.02)
        local pulse = 0.03 + 0.04 * math.abs(math.sin(t * 2))
        love.graphics.setColor(0.2, 0.02, 0.3, pulse)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
        -- Draw the 17 Churglies streaking past: grey bodies with yellow accents, much bigger.
        for _, c in ipairs(v.churglies) do
            local s = c.scale
            local stretch = math.min(220, math.abs(c.vx) * 0.11)
            -- Outer grey blur
            love.graphics.setColor(0.3, 0.3, 0.3, 0.55)
            love.graphics.ellipse("fill", c.x, c.y, 32 * s + stretch, 14 * s)
            love.graphics.setColor(0.5, 0.5, 0.5, 0.85)
            love.graphics.ellipse("fill", c.x, c.y, 22 * s + stretch * 0.6, 9 * s)
            love.graphics.setColor(0.7, 0.7, 0.72, 0.95)
            love.graphics.ellipse("fill", c.x, c.y, 14 * s + stretch * 0.3, 5 * s)
            -- Head
            local headX = c.x + (c.vx > 0 and 1 or -1) * (stretch * 0.3 + 22 * s)
            love.graphics.setColor(0.45, 0.45, 0.5, 1)
            love.graphics.circle("fill", headX, c.y, 12 * s)
            -- Glowing yellow eye with wide halo
            love.graphics.setColor(1, 0.85, 0.15, 0.4)
            love.graphics.circle("fill", headX, c.y - 3 * s, 8 * s)
            love.graphics.setColor(1, 0.9, 0.2, 1)
            love.graphics.circle("fill", headX, c.y - 3 * s, 4 * s)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.circle("fill", headX, c.y - 3 * s, 2 * s)
            -- Yellow tooth-lined mouths down the body
            for m = -2, 2 do
                local mx = c.x + m * 12 * s
                love.graphics.setColor(0, 0, 0, 0.9)
                love.graphics.circle("fill", mx, c.y, 4 * s)
                -- Tiny yellow teeth
                love.graphics.setColor(1, 0.9, 0.2, 0.95)
                for tk = -1, 1 do
                    love.graphics.polygon("fill",
                        mx + tk * 1.2 * s, c.y - 3 * s,
                        mx + tk * 1.2 * s - 0.7 * s, c.y - 1 * s,
                        mx + tk * 1.2 * s + 0.7 * s, c.y - 1 * s)
                    love.graphics.polygon("fill",
                        mx + tk * 1.2 * s, c.y + 3 * s,
                        mx + tk * 1.2 * s - 0.7 * s, c.y + 1 * s,
                        mx + tk * 1.2 * s + 0.7 * s, c.y + 1 * s)
                end
            end
            -- Yellow running stripe along the spine
            love.graphics.setColor(1, 0.85, 0.15, 0.55)
            love.graphics.rectangle("fill", c.x - (14 * s + stretch * 0.3), c.y - s * 0.8, (14 * s + stretch * 0.3) * 2, s * 1.6)
        end
        -- Bubbles (cold white tint)
        for _, b in ipairs(v.bubbles) do
            love.graphics.setColor(0.6, 0.7, 1, 0.35)
            love.graphics.circle("line", b.x, b.y, b.r)
        end
    elseif v.phase == "C" then
        -- Very dark background — the Carrier dominates the whole frame.
        love.graphics.clear(0.02, 0.02, 0.03)

        -- HIGH-SPEED DESCENT STREAKS going UPWARD — many fast vertical dashes,
        -- simulating being yanked down at impossible speed.
        for i = 1, 140 do
            local sx = (i * 97 + math.sin(i * 0.37) * 400) % 1280
            local speed = 1800 + ((i * 73) % 1200)
            local len = 30 + (i % 6) * 25
            local sy = ((i * 137 - t * speed) % (720 + len))
            local hue = (i % 5 == 0) and {1, 0.85, 0.2, 0.9} or {0.6, 0.6, 0.65, 0.7}
            love.graphics.setColor(hue)
            love.graphics.rectangle("fill", sx, sy, 1.5, len)
        end
        -- Extra near-ground rushing particles
        for i = 1, 50 do
            local sx = (i * 191 + t * 300) % 1280
            local sy = ((i * 83 - t * 2400) % 720)
            love.graphics.setColor(1, 1, 1, 0.45)
            love.graphics.circle("fill", sx, sy, 1.2)
        end

        -- THE CARRIER: a grey leviathan that barely fits the screen, studded
        -- with glowing yellow eyes and gaping mouths — Churgly'nth beyond comprehension.
        if v.carrier then
            local c = v.carrier
            local cx, cy = c.x, c.y + 60

            -- Outer vast aura
            love.graphics.setColor(0.3, 0.3, 0.32, 0.35)
            love.graphics.ellipse("fill", cx, cy, 720, 360)
            -- Second bulk layer
            love.graphics.setColor(0.38, 0.38, 0.40, 0.75)
            love.graphics.ellipse("fill", cx, cy, 600, 290)
            -- Main body — massive grey mass
            love.graphics.setColor(0.48, 0.48, 0.52)
            love.graphics.ellipse("fill", cx, cy, 500, 240)
            love.graphics.setColor(0.28, 0.28, 0.32)
            love.graphics.ellipse("line", cx, cy, 500, 240)

            -- Irregular bulges (suggests a form too large to resolve)
            for i = 1, 12 do
                local a = (i / 12) * math.pi * 2 + math.sin(t + i) * 0.2
                local d = 320 + math.sin(t * 1.2 + i) * 30
                local bx = cx + math.cos(a) * d * 0.85
                local by = cy + math.sin(a) * d * 0.45
                love.graphics.setColor(0.42, 0.42, 0.46, 0.9)
                love.graphics.circle("fill", bx, by, 55 + (i % 4) * 12)
            end

            -- Many glowing yellow eyes scattered across the mass
            for i = 1, 22 do
                local a = (i / 22) * math.pi * 2 + t * 0.3
                local d = 180 + ((i * 37) % 190)
                local ex = cx + math.cos(a) * d * 0.9
                local ey = cy + math.sin(a) * d * 0.5
                local blink = (math.sin(t * 2 + i * 0.7) > 0.7) and 0.1 or 1
                -- Yellow glow halo
                love.graphics.setColor(1, 0.9, 0.2, 0.35 * blink)
                love.graphics.circle("fill", ex, ey, 24)
                love.graphics.setColor(1, 0.85, 0.15, blink)
                love.graphics.circle("fill", ex, ey, 10)
                -- Slit pupil
                love.graphics.setColor(0, 0, 0, blink)
                love.graphics.ellipse("fill", ex, ey, 2, 8)
                -- Highlight
                love.graphics.setColor(1, 1, 0.8, blink * 0.8)
                love.graphics.circle("fill", ex - 3, ey - 3, 1.6)
            end

            -- Gaping mouths around the rim — dark wells with yellow teeth
            for i = 1, 8 do
                local a = (i / 8) * math.pi * 2
                local mx = cx + math.cos(a) * 360 * 0.9
                local my = cy + math.sin(a) * 360 * 0.5
                local open = 0.5 + 0.5 * math.abs(math.sin(t * 1.6 + i))
                love.graphics.setColor(0, 0, 0, 0.95)
                love.graphics.ellipse("fill", mx, my, 40, 16 * open)
                -- Teeth top/bottom
                love.graphics.setColor(1, 0.9, 0.2, 0.9)
                for k = -3, 3 do
                    love.graphics.polygon("fill",
                        mx + k * 6, my - 14 * open,
                        mx + k * 6 - 2, my - 6 * open,
                        mx + k * 6 + 2, my - 6 * open)
                    love.graphics.polygon("fill",
                        mx + k * 6, my + 14 * open,
                        mx + k * 6 - 2, my + 6 * open,
                        mx + k * 6 + 2, my + 6 * open)
                end
            end

            -- Huge central maw that holds the player
            love.graphics.setColor(0.02, 0.02, 0.02, 0.95)
            love.graphics.circle("fill", cx, cy - 60, 70)
            love.graphics.setColor(1, 0.85, 0.2, 0.6)
            love.graphics.circle("line", cx, cy - 60, 70)
            -- Inner glow ring
            love.graphics.setColor(1, 0.9, 0.2, 0.25 + 0.15 * math.sin(t * 4))
            love.graphics.circle("line", cx, cy - 60, 55)

            -- Countless tendrils streaming upward off-screen, suggesting size
            love.graphics.setColor(0.35, 0.35, 0.38, 0.85)
            love.graphics.setLineWidth(4)
            for i = -8, 8 do
                local off = math.sin(t * 2 + i * 0.5) * 14
                love.graphics.line(cx + i * 60, cy + 240, cx + i * 60 + off, cy + 720)
            end
            -- Lower, smaller tendrils wrapping around the player
            love.graphics.setColor(0.5, 0.5, 0.55, 0.8)
            love.graphics.setLineWidth(2.5)
            for i = -6, 6 do
                local ph = t * 4 + i * 0.9
                local tx = cx + i * 18 + math.cos(ph) * 8
                local ty = cy - 100 + math.sin(ph) * 14
                love.graphics.line(tx, cy - 60, tx, ty)
            end
            love.graphics.setLineWidth(1)
        end
    elseif v.phase == "D" then
        love.graphics.clear(0.04, 0.0, 0.08)
        -- White glow rising from the floor
        local a = v.whiteAlpha
        love.graphics.setColor(1, 1, 1, 0.12 * a)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
        for r = 400, 80, -30 do
            love.graphics.setColor(1, 1, 1, (0.04 + 0.03 * math.sin(t * 2)) * a)
            love.graphics.circle("fill", 640, 720, r)
        end
        -- Bright pillar at bottom
        love.graphics.setColor(1, 1, 1, 0.9 * a)
        love.graphics.rectangle("fill", 400, 620, 480, 100)
        -- Hint text
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.printf("swim to the light to ascend", 0, 560, 1280, "center")
    end

    -- Draw bubbles everywhere (common)
    if v.phase ~= "A" and v.phase ~= "B" then
        for _, b in ipairs(v.bubbles) do
            love.graphics.setColor(0.6, 0.7, 1, 0.45)
            love.graphics.circle("line", b.x, b.y, b.r)
        end
    end

    -- The player — rendered by normal Player:draw through the game
    game.player:draw()
end

-- Render the "yellow Void Sea" strip at the bottom of the playfield during
-- normal gameplay, once the Void Sea card has been taken. Ripples intensify
-- and a "HOLD S" prompt fades in as the player approaches the bottom edge.
function Voidsea.drawSurface(game)
    local p = game.player
    if not (p and p.voidSeaUnlocked) then return end
    local t = love.timer.getTime()
    -- Closeness: 0 when player is high up, 1 when hugging the bottom edge
    local closeness = math.max(0, math.min(1, (p.y - 540) / 160))

    -- Gradient from transparent at y=650 to bright yellow at y=720
    for i = 0, 14 do
        local yy = 650 + i * 5
        local k = i / 14                     -- 0 top, 1 bottom
        local a = (0.18 + k * 0.55) * (0.75 + closeness * 0.25)
        love.graphics.setColor(1, 0.85 - k * 0.1, 0.15, a)
        love.graphics.rectangle("fill", 0, yy, 1280, 6)
    end

    -- Shimmering surface wave at the top of the band
    love.graphics.setColor(1, 0.95, 0.4, 0.7 + closeness * 0.2)
    love.graphics.setLineWidth(2)
    local surfY = 652
    local prevY = surfY + math.sin(t * 3) * 2
    for x = 0, 1280, 12 do
        local y2 = surfY + math.sin(t * 3 + x * 0.03) * 3 + math.sin(t * 5 + x * 0.07) * 1.5
        love.graphics.line(x, prevY, x + 12, y2)
        prevY = y2
    end
    love.graphics.setLineWidth(1)

    -- Drifting gold motes rising out of the sea (more as player approaches)
    local moteCount = 20 + math.floor(closeness * 40)
    for i = 1, moteCount do
        local mx = ((i * 73 + t * 20) % 1280)
        local my = 720 - ((i * 37 + t * (30 + i % 5 * 8)) % 70)
        local glow = 0.4 + 0.5 * math.sin(t * 2 + i)
        love.graphics.setColor(1, 0.95, 0.35, 0.35 * glow * (0.6 + closeness * 0.4))
        love.graphics.circle("fill", mx, my, 1.5)
    end

    -- Ripples expanding from below the player when they get close
    if closeness > 0.2 then
        local ringCount = 2 + math.floor(closeness * 4)
        local rippleSpeed = 0.8 + closeness * 1.4
        for i = 0, ringCount - 1 do
            local phase = ((t * rippleSpeed) + i / ringCount) % 1
            local r = 10 + phase * (60 + closeness * 120)
            local a = (1 - phase) * 0.55 * closeness
            love.graphics.setColor(1, 0.85, 0.2, a)
            love.graphics.setLineWidth(2)
            love.graphics.ellipse("line", p.x, 700, r, r * 0.35)
        end
        love.graphics.setLineWidth(1)
    end

    -- "HOLD S" prompt pulses above the sea when near
    if closeness > 0.45 then
        local pulse = 0.65 + 0.35 * math.sin(t * 5)
        love.graphics.setColor(1, 0.95, 0.4, (closeness - 0.45) * 1.8 * pulse)
        love.graphics.printf("HOLD  S  TO  DIVE", 0, 600, 1280, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Voidsea
