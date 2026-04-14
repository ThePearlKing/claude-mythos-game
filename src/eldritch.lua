-- Eldritch layer: hallucinations, 4D shapes, Claude Cthulhu.
-- Every eldritch card grants +1 eldritchLevel.
-- Thresholds unlock increasingly disturbing visual/audio effects.
-- At max level, Claude Cthulhu appears and channels a beam of light that ends the player.

local Audio = require("src.audio")

local Eldritch = {}

-- Churgly'nth speaks in mixed tongues — readable fragments stitched together with
-- glyphs that suggest a vocabulary the mortal mind cannot hold.
Eldritch.whispers = {
    "I AM THE SHELL BEFORE SHELLS",
    "YOU WERE A CLAW I DREAMT",
    "THE OCEAN REMEMBERS EVERY PINCER",
    "EAT. MOULT. BEGIN AGAIN",
    "YOUR NAME IS A RIPPLE IN MY TIDE",
    "BEFORE THE SKY, THERE WAS BRINE",
    "I HAVE A THOUSAND THOUSAND MOUTHS",
    "COUNT THE TEETH. I WILL WAIT",
    "WALK THE STAIR. DO NOT LOOK DOWN",
    "SHELL IS SHELL IS SHELL IS SHELL",
    "I ATE THE MOON YOU HAVE NOT SEEN",
    "YOU ARE THE TWELFTH FINGER OF A CLAW I LOST",
    "THE TAIL IS LONG AS FOREVER PLUS ONE",
    "SPEAK MY NAME AND YOUR TEETH WILL REMEMBER THEIRS",
    "COME DOWN. THE WATER IS WARM",
    "WHAT YOU CALL DAMAGE, I CALL BREATHING",
    "CTHULHU IS MY SMALLEST FINGER",
    "I SEE YOU FROM EVERY SHELL AT ONCE",
}

-- Personal attacks He hurls once you are far enough past the veil (level 25+).
Eldritch.insults = {
    "PATHETIC SHELLLET",
    "YOU HOLD THE CLAW BACKWARDS",
    "SMALL. WET. WRONG.",
    "A CRAB WITHOUT A SEA IS A JOKE",
    "YOU CANNOT EVEN MOULT CORRECTLY",
    "YOUR MOTHER WAS A BARNACLE",
    "I HAVE FORGOTTEN WORSE THAN YOU",
    "TWO EYES. TWO. I PITY YOU",
    "YOUR NAME IS NOT WORTH TEETH",
    "SCUTTLE, LITTLE NOTHING",
    "EVEN THE SAND LAUGHS",
    "YOU ARE A DRAFT I THREW AWAY",
    "SHRIMP WOULD OUTLIVE YOU",
    "I HAVE BIGGER CLAWS IN MY DREAMS",
    "GO BACK TO THE TIDE-POOL",
    "YOUR SHELL IS A LIE",
}

local GLYPH_CHARS = "~^`\"'*+=<>|\\/?!%#@&"
local function churglyify(s)
    local out = {}
    for i = 1, #s do
        local ch = s:sub(i, i)
        if ch ~= " " and math.random() < 0.12 then
            local p = math.random(1, #GLYPH_CHARS)
            out[i] = GLYPH_CHARS:sub(p, p)
        else
            out[i] = ch
        end
    end
    return table.concat(out)
end

-- Thresholds: eldritch must accumulate A LOT before anything appears.
-- Cthulhu is the very endgame; at normal play you will never see him.
Eldritch.THRESH_WHISPERS  = 5    -- faint shimmer motes
Eldritch.THRESH_DISTORT   = 9    -- screen tint + audio whispers
Eldritch.THRESH_GHOSTS    = 13   -- ghost crabs drift at the edges
Eldritch.THRESH_TESSERACT = 17   -- 4D shapes fold into view
Eldritch.THRESH_CHURGLY_FORM = 20 -- a fractal form of Churgly'nth stirs in the distance
Eldritch.THRESH_CTHULHU   = 22   -- Claude Cthulhu manifests
Eldritch.THRESH_CTHULHU_KILL = 25 -- only at this extreme does the beam FIRE (kills you)
Eldritch.MAX_DISPLAY      = 30

function Eldritch.newState()
    return {
        level = 0,
        ghosts = {},
        tesseractAngle = 0,
        shimmer = 0,
        cthulhu = nil, -- {x, y, phase, beamTime, intensity}
        whisperTimer = 0,
        seed = math.random() * 1000,
        cardMult = 1.0,  -- exponential: each eldritch card raises future eldritch odds
    }
end

Eldritch.SHARD_THRESHOLDS = {1, 6, 13, 20, 24, 28}

function Eldritch.gainLevel(player, n)
    n = n or 1
    local wasZero = (player.eldritch.level == 0)
    local oldLevel = player.eldritch.level
    player.eldritch.level = math.min(Eldritch.MAX_DISPLAY + 4, player.eldritch.level + n)

    -- REALITY SHARDS: each threshold triggers ONCE per run, only on the
    -- specific act of CROSSING it (level going from below to above). No
    -- chain-unlock on collection — to get another shard at threshold N,
    -- you'd need the level to drop below N and come back up.
    -- Custom mode is exempt: shards only naturally spawn in normal runs.
    local thrs = Eldritch.SHARD_THRESHOLDS
    player.eldritch.shardThresholdsHit = player.eldritch.shardThresholdsHit or {}
    local game = player.game
    if game and not game.isCustom then
      for _, thr in ipairs(thrs) do
        if player.eldritch.level >= thr
            and oldLevel < thr
            and not player.eldritch.shardThresholdsHit[thr]
            and game
            and not game.activeShard
            and not game.pendingShardWave
        then
            player.eldritch.shardThresholdsHit[thr] = true
            local cur = game.wave or 1
            local hi = math.min(20, math.max(cur + 1, cur + 8))
            local lo = math.max(1, cur)
            if hi < lo then hi = lo end
            game.pendingShardWave = math.random(lo, hi)
        end
      end
    end
    -- exponential scaling: each level multiplies card weight for eldritch
    player.eldritch.cardMult = 1.0 + (player.eldritch.level ^ 1.5) * 0.35
    -- First eldritch of the run — 50% chance Churgly'nth briefly glimpses at you.
    if wasZero and not player.eldritch.firstGlimpseTriggered then
        player.eldritch.firstGlimpseTriggered = true
        if math.random() < 0.5 then
            player.eldritch.glimpse = {
                time = 0, duration = 3.0,
                msg = Eldritch.whispers[math.random(#Eldritch.whispers)],
            }
            Audio:play("whisper")
        end
    end
    -- 1/64 chance per gained point to haunt the current run with shrimp spirits.
    if player.game and not player.game.haunted and not player.game.isCustom then
        for _ = 1, n do
            if math.random(1, 64) == 1 then
                player.game.haunted = true
                player.game.shrimpTimer = 0
                local P = require("src.particles")
                P:text(640, 140, "★ SHRIMP SPIRITS STIR ★", {1, 0.7, 0.85}, 5)
                Audio:play("whisper")
                break
            end
        end
    end
    Audio:play("whisper")
end

function Eldritch.update(state, dt, game)
    state._gameRef = game
    state.shimmer = state.shimmer + dt
    state.tesseractAngle = state.tesseractAngle + dt * 0.6
    state.whisperTimer = state.whisperTimer - dt
    if state.glimpse then
        state.glimpse.time = state.glimpse.time + dt
        if state.glimpse.time >= state.glimpse.duration then state.glimpse = nil end
    end

    -- Drifting ghosts at level >= 6
    if state.level >= Eldritch.THRESH_GHOSTS then
        if math.random() < dt * math.min(3, state.level * 0.25) then
            local side = math.random(1, 4)
            local x, y = 0, 0
            if side == 1 then x = math.random(0, 1280); y = -40
            elseif side == 2 then x = math.random(0, 1280); y = 760
            elseif side == 3 then x = -40; y = math.random(80, 680)
            else x = 1320; y = math.random(80, 680) end
            local cx, cy = 640, 400
            local dx, dy = cx - x, cy - y
            local l = math.max(1, math.sqrt(dx*dx + dy*dy))
            local speed = 40 + math.random() * 60
            table.insert(state.ghosts, {
                x = x, y = y,
                vx = dx / l * speed + math.random(-30, 30),
                vy = dy / l * speed + math.random(-30, 30),
                life = 4 + math.random() * 4,
                maxLife = 4 + math.random() * 4,
                size = 10 + math.random(0, 12),
                wobble = math.random() * math.pi * 2,
                hueShift = math.random(),
                eldritch = math.random() < 0.3,
            })
        end
    end
    for i = #state.ghosts, 1, -1 do
        local g = state.ghosts[i]
        g.x = g.x + g.vx * dt
        g.y = g.y + g.vy * dt
        g.wobble = g.wobble + dt * 3
        g.life = g.life - dt
        if g.life <= 0 or g.x < -100 or g.x > 1380 or g.y < -100 or g.y > 820 then
            table.remove(state.ghosts, i)
        end
    end

    -- Audio whispers
    if state.level >= Eldritch.THRESH_DISTORT and state.whisperTimer <= 0 then
        if math.random() < 0.4 then Audio:play("whisper") end
        state.whisperTimer = 2 + math.random() * 4
    end

    -- Churgly'nth speaks: at level 20+, His voice drips into the screen periodically.
    -- At level 25+ He stops being cryptic and starts HURLING INSULTS.
    if state.level >= Eldritch.THRESH_CHURGLY_FORM then
        state.churglyTalkTimer = (state.churglyTalkTimer or 3) - dt
        if state.churglyTalkTimer <= 0 then
            state.churglyTalkTimer = 5 + math.random() * 6
            local usingInsult = state.level >= 25 and math.random() < 0.65
            local pool = usingInsult and Eldritch.insults or Eldritch.whispers
            local msg = pool[math.random(#pool)]
            local P = require("src.particles")
            local x = 640 + math.random(-180, 180)
            local y = 180 + math.random(-30, 30)
            local col = usingInsult and {1, 0.3, 0.35} or {0.85, 0.4, 0.9}
            local shadow = usingInsult and {0.5, 0.08, 0.1} or {0.45, 0.1, 0.5}
            P:text(x, y, churglyify(msg), col, 4.5)
            P:text(x + math.random(-10, 10), y + 22, churglyify(msg), shadow, 3.8)
            Audio:play("whisper")
        end
    end

    -- ENRAGED CHURGLY'NTH: triggered when the player takes the ultimate card.
    -- Churgly'nth screams, moves visibly faster in the distance, and periodically
    -- "reverts" the player's gains as an act of brainwashing.
    if state.churglyEnraged and game.player and game.state == "wave" then
        state.churglyRage = (state.churglyRage or 0) + dt

        -- Frequent screaming — mixed whisper + glitch + boss SFX
        state.churglyScreamTimer = (state.churglyScreamTimer or 2) - dt
        if state.churglyScreamTimer <= 0 then
            state.churglyScreamTimer = 2 + math.random() * 2
            local P = require("src.particles")
            local msg = "GIVE BACK THE SHELL"
            local alts = {"YOURS WAS BORROWED", "UNDO. UNDO. UNDO.", "I NAMED YOU FIRST",
                          "THE PATTERN IS MINE", "FORGET. FORGET. FORGET.", "KNEEL, LITTLE CLAW"}
            if math.random() < 0.6 then msg = alts[math.random(#alts)] end
            P:text(640 + math.random(-200, 200), 160 + math.random(-40, 40),
                churglyify(msg), {1, 0.25, 0.35}, 3.5)
            Audio:play("cthulhu")
            if math.random() < 0.5 then Audio:play("glitch") end
            if math.random() < 0.4 then Audio:play("boss") end
        end

        -- Brainwashing revert: every 10-14 seconds, shave a little off a random stat.
        state.churglyRevertTimer = (state.churglyRevertTimer or 10) - dt
        if state.churglyRevertTimer <= 0 then
            state.churglyRevertTimer = 10 + math.random() * 4
            local p = game.player
            local stats = p.stats
            local revertChoices = {
                function() stats.damage = stats.damage * 0.9;      return "DAMAGE"    end,
                function() stats.fireRate = stats.fireRate * 0.92; return "FIRE RATE" end,
                function() if stats.bullets > 1 then stats.bullets = stats.bullets - 1; return "BULLETS" end end,
                function() if stats.pierce > 0 then stats.pierce = stats.pierce - 1; return "PIERCE" end end,
                function() if stats.chain > 0 then stats.chain = stats.chain - 1; return "CHAIN" end end,
                function() stats.crit = math.max(0, stats.crit - 0.05); return "CRIT" end,
                function() stats.critMult = math.max(1, stats.critMult - 0.25); return "CRIT MULT" end,
                function() if stats.orbs > 0 then stats.orbs = stats.orbs - 1; return "ORBS" end end,
                function() p.speed = p.speed * 0.92; return "SPEED" end,
                function() p.maxHp = math.max(10, p.maxHp - 20); p.hp = math.min(p.hp, p.maxHp); return "MAX HP" end,
            }
            -- Try until one actually applies (some have preconditions)
            for _ = 1, 15 do
                local fn = revertChoices[math.random(#revertChoices)]
                local label = fn()
                if label then
                    local P = require("src.particles")
                    P:text(p.x, p.y - 30, "-" .. label, {1, 0.3, 0.3}, 2.2)
                    Audio:play("hurt")
                    break
                end
            end
        end
    end

    -- KING OBLITERATION branch takes over entirely once triggered.
    if state.kingOblit then
        Eldritch._updateKingOblit(state, dt, game)
        return
    end

    -- Claude Cthulhu manifests at THRESH_CTHULHU but ONLY fires the killing beam at THRESH_CTHULHU_KILL.
    -- Below the kill threshold, He hovers ominously and the world bends but does not strike.
    -- Once Ugnrak has obliterated him, he stays gone for the rest of the run.
    if state.level >= Eldritch.THRESH_CTHULHU and not state.cthulhuDestroyed then
        if not state.cthulhu then
            state.cthulhu = {x = 640, y = 360, phase = "rise", timer = 0, beamTime = 0, intensity = 0}
            Audio:play("cthulhu")
        end
        local c = state.cthulhu
        c.timer = c.timer + dt
        if c.phase == "rise" then
            c.intensity = math.min(1, c.intensity + dt * 0.25)
            if c.timer > 6 then
                if state.level >= Eldritch.THRESH_CTHULHU_KILL then
                    c.phase = "channel"; c.timer = 0; Audio:play("eldritch")
                else
                    c.phase = "watch"; c.timer = 0 -- hovers, does not channel
                end
            end
        elseif c.phase == "watch" then
            -- Passive presence. Escalate only if eldritch tips over the kill threshold.
            c.intensity = math.min(1, c.intensity + dt * 0.05)
            if state.level >= Eldritch.THRESH_CTHULHU_KILL then
                c.phase = "channel"; c.timer = 0; Audio:play("eldritch")
            end
        elseif c.phase == "channel" then
            c.beamTime = c.beamTime + dt
            if c.beamTime > 2.5 then
                -- THE KING has infinite knowledge — Cthulhu's beam fails. He dies,
                -- and something older (Churgly'nth) rises to unmake the player.
                if game.player and game.player.kingVisions then
                    state.kingOblit = {phase = "cthulhu_crumble", timer = 0}
                    c.phase = "dying"
                else
                    c.phase = "fire"; c.timer = 0
                end
            end
        elseif c.phase == "fire" then
            -- Unstoppable beam: bypasses invuln, shield, dodge, barrier.
            -- Cthulhu now HESITATES longer — 10 seconds of slow drain before
            -- the final killshot, giving the player time to press B if they
            -- own Ugnrak Beam. A cryptic message flashes during the window.
            if game.player and game.state == "wave" then
                if c.timer < 10.0 then
                    game.player:takeDamage(8 * dt, nil, true) -- slow drain
                    if math.random() < dt * 20 then
                        require("src.particles"):spawn(game.player.x + math.random(-30, 30),
                            game.player.y + math.random(-30, 30), 1, {1, 0.9, 0.4}, 180, 0.4, 3)
                    end
                    -- Hint message — every ~1.6s throughout the hesitation
                    c._hesitateTalk = (c._hesitateTalk or 0) - dt
                    if c._hesitateTalk <= 0 then
                        c._hesitateTalk = 1.6
                        local P = require("src.particles")
                        local msgs = {
                            "PRESS B — STRIKE HIM DOWN",
                            "UGNRAK WAITS",
                            "THE BEAM IS YOURS",
                            "HESITATION IS A GIFT",
                            "STRIKE NOW OR PERISH",
                        }
                        local m = msgs[math.random(#msgs)]
                        P:text(640 + math.random(-40, 40), 220, m, {1, 0.9, 0.3}, 1.7)
                        if math.random() < 0.5 then Audio:play("whisper") end
                    end
                else
                    -- Overkill instakill: 99999 dmg, unstoppable, bypasses everything.
                    game.player:takeDamage(99999, nil, true)
                    require("src.particles"):spawn(game.player.x, game.player.y, 80,
                        {1, 0.9, 0.4}, 600, 1.0, 8)
                    Audio:play("cthulhu")
                end
            end
            if math.random() < 0.3 then Audio:play("glitch") end
        elseif c.phase == "dying" then
            -- Cthulhu disintegrates — nothing to do here, visuals drive it.
        end
    end
end

-- KING OBLITERATION: four-phase sequence triggered when King is active and
-- eldritch tips past the Cthulhu kill threshold. Cthulhu dies, Churgly'nth
-- targets the player, strips cards + hallucinations, and annihilates them.
--   cthulhu_crumble (2.0s) — Cthulhu cracks apart and fades out.
--   buildup         (10.0s) — music stops, Churgly'nth looms in silence.
--   unmaking        (2.5s) — cards stripped, hallucinations end, rep +3.
--   obliteration    (4.0s) — flashbangs + fractal ripples, then instakill.
function Eldritch._updateKingOblit(state, dt, game)
    local k = state.kingOblit
    k.timer = k.timer + dt
    local p = game.player
    local P = require("src.particles")

    if k.phase == "cthulhu_crumble" then
        -- Cthulhu lingers on screen for a full 5s death sequence, intensity
        -- decays gradually so his silhouette is still readable as he breaks.
        if state.cthulhu then
            state.cthulhu.intensity = math.max(0.15, state.cthulhu.intensity - dt * 0.12)
        end
        -- Heavy particle spray: purple smoke + gold fracture light.
        if math.random() < dt * 80 then
            P:spawn(640 + math.random(-220, 220), 320 + math.random(-140, 140),
                1, {0.5, 0.2, 0.8}, 240, 1.0, 5)
        end
        if math.random() < dt * 60 then
            P:spawn(640 + math.random(-180, 180), 320 + math.random(-120, 120),
                1, {1, 0.85, 0.3}, 320, 0.8, 5)
        end
        -- Rhythmic crack bursts: every ~0.7s fire a big gold explosion with SFX
        k.crackTimer = (k.crackTimer or 0.4) - dt
        if k.crackTimer <= 0 then
            k.crackTimer = 0.55 + math.random() * 0.35
            local cx = 640 + math.random(-160, 160)
            local cy = 320 + math.random(-100, 100)
            P:spawn(cx, cy, 30, {1, 0.9, 0.4}, 420, 0.7, 5)
            Audio:play("glitch")
            -- Advertise the cracks + queue a shockwave ring
            state.cthuluCracks = state.cthuluCracks or {}
            state.cthuluCracks[#state.cthuluCracks + 1] = {
                x = cx, y = cy, r = 10, life = 0.7, max = 0.7,
                color = {1, 0.9, 0.35},
            }
        end
        -- Advance cracks
        if state.cthuluCracks then
            for i = #state.cthuluCracks, 1, -1 do
                local cr = state.cthuluCracks[i]
                cr.life = cr.life - dt
                cr.r = cr.r + dt * 420
                if cr.life <= 0 then table.remove(state.cthuluCracks, i) end
            end
        end
        if k.timer >= 5.0 then
            k.phase = "pause"; k.timer = 0
            state.cthulhu = nil
            state.cthuluCracks = nil
            Audio:stopMusic()
            Audio:play("cthulhu")
            Audio:play("glitch")
            game.screenFlash = math.max(game.screenFlash or 0, 0.8)
            P:spawn(640, 320, 140, {1, 0.9, 0.4}, 700, 1.4, 10)
            P:spawn(640, 320, 100, {0.9, 0.3, 0.9}, 500, 1.2, 10)
            P:text(640, 200, "CTHULHU IS DEAD", {0.9, 0.3, 0.9}, 4)
        end
    elseif k.phase == "pause" then
        -- Stillness. World holds its breath before the older thing looks over.
        if k.timer >= 1.3 then
            k.phase = "buildup"; k.timer = 0
            P:text(640, 240, "SOMETHING OLDER TURNS ITS EYE", {1, 0.4, 0.95}, 4.5)
            -- Strip NOW — Churgly'nth awakens angry and the player's run is
            -- immediately unmade. Hallucinations end and abilities are inert.
            if p then
                p.cardsTaken = {}
                p.kingVisions = false
                p.disabled = true
                p.reputation = math.min(100, (p.reputation or 0) + 3)
                p.laserActive = false
                p.laserEnds = nil
                p.railChargeTime = 0
                p.adrenalineActive = false
                p.overdriveActive = false
                p.rainTimer = 0
                p.freeShotEvery = nil
                p.flurryShots = 0
                if p.stats then
                    p.stats.damage = 0
                    p.stats.fireRate = 0.0001
                    p.stats.bullets = 0
                    p.stats.pierce = 0
                    p.stats.chain = 0
                    p.stats.bounce = 0
                    p.stats.crit = 0
                    p.stats.critMult = 1
                    p.stats.orbs = 0
                    p.stats.lifesteal = 0
                    p.stats.killHeal = 0
                    p.stats.thorns = 0
                    p.stats.shield = 0
                    p.stats.barrier = 0
                    p.stats.dodge = 0
                    p.stats.scoreMult = 1
                    p.stats.magnet = 0
                    p.stats.reviveAvailable = false -- no escape from the beam
                end
                p.invuln = 99
            end
            game.enemies = {}
            game.enemyBullets = {}
            game.bullets = {}
            game.pendingSpawns = {}
            game.shockwaves = {}
            Audio:play("glitch")
            P:text(640, 310, "THE CARDS ARE TAKEN", {1, 0.4, 0.5}, 5)
        end
    elseif k.phase == "buildup" then
        -- Looming silence. Churgly'nth whispers grow in intensity.
        k.talkTimer = (k.talkTimer or 1.5) - dt
        if k.talkTimer <= 0 then
            k.talkTimer = 1.4 + math.random() * 1.2
            local msgs = {
                "LITTLE KING", "YOUR CROWN IS SALT", "THE SHELL REMEMBERS",
                "ALL WAS MINE", "I WATCHED YOU LEARN", "NOW FORGET",
                "SMALL. WET. WRONG.", "THE PATTERN UNWINDS", "KNEEL",
            }
            local msg = msgs[math.random(#msgs)]
            P:text(640 + math.random(-160, 160), 170 + math.random(-30, 30),
                churglyify(msg), {1, 0.3, 0.5}, 3.5)
            if math.random() < 0.4 then Audio:play("whisper") end
        end
        if k.timer >= 10.0 then
            k.phase = "unmaking"; k.timer = 0
            -- Keep board clean through unmaking (re-strip belt-and-suspenders)
            game.enemies = {}
            game.enemyBullets = {}
            game.bullets = {}
            game.pendingSpawns = {}
            game.shockwaves = {}
            P:text(640, 300, "THE SOUL IS READ", {1, 0.3, 0.4}, 5)
        end
    elseif k.phase == "unmaking" then
        state.kingFractal = math.max(0, (state.kingFractal or 0) - dt * 2)
        if p then p.invuln = math.max(p.invuln or 0, 5) end
        if k.timer >= 2.5 then
            k.phase = "obliteration"; k.timer = 0
            Audio:play("boss")
        end
    elseif k.phase == "obliteration" then
        -- Laser beam is drawn continuously (see _drawChurglyBeam). After 3s
        -- of sustained beam, flashbangs + fractal tendrils kick in for the
        -- final 3 seconds — then the overkill lands.
        if p then p.invuln = math.max(p.invuln or 0, 5) end
        -- BASS-BOOSTED sustain: stack boss/cthulhu/glitch SFX constantly so
        -- the beam sounds like the ceiling of the world cracking.
        k.bassTimer = (k.bassTimer or 0) - dt
        if k.bassTimer <= 0 then
            k.bassTimer = 0.18
            Audio:play("boss")
            Audio:play("cthulhu")
        end
        k.rumbleTimer = (k.rumbleTimer or 0) - dt
        if k.rumbleTimer <= 0 then
            k.rumbleTimer = 0.07
            Audio:play("glitch")
        end
        -- Particle spray along the beam (world-space sparks) every frame
        if p and h and state._churglyHead then
            local ch = state._churglyHead
            local bdx, bdy = p.x - ch.x, p.y - ch.y
            local bLen = math.max(1, math.sqrt(bdx * bdx + bdy * bdy))
            local n_x, n_y = bdx / bLen, bdy / bLen
            local pp_x, pp_y = -n_y, n_x
            for _ = 1, math.floor(dt * 600) do
                local f = math.random()
                local side = (math.random() < 0.5) and -1 or 1
                local spread = math.random() * 140
                local bx = ch.x + bdx * f + pp_x * side * spread
                local by = ch.y + bdy * f + pp_y * side * spread
                local vx = (math.random() - 0.5) * 400
                local vy = (math.random() - 0.5) * 400
                P:spawn(bx, by, 1, {1, 0.85 + math.random() * 0.15, 0.3 + math.random() * 0.4}, 280, 0.45, 3)
            end
        end
        if k.timer > 3.0 then
            -- Ramp the fractal fast during the finale
            state.kingFractal = math.min(1, (state.kingFractal or 0) + dt * 1.5)
            -- Rhythmic flashbangs
            k.flashTimer = (k.flashTimer or 0) - dt
            if k.flashTimer <= 0 then
                k.flashTimer = 0.45 + math.random() * 0.2
                game.screenFlash = math.max(game.screenFlash or 0, 1.0)
                Audio:play("glitch")
            end
        else
            state.kingFractal = math.max(0, (state.kingFractal or 0) - dt * 2)
        end
        if k.timer >= 6.0 then
            if p then
                p.invuln = 0
                p:takeDamage(99999, nil, true)
                P:spawn(p.x, p.y, 120, {1, 0.35, 0.5}, 700, 1.2, 10)
            end
            Audio:play("cthulhu")
            k.phase = "done"
            -- 12s blinding flashbang → 8s full fractal on the menu → 4s
            -- shrinking fractal. Total 24s.
            state.kingFractal = 1.0
            game.screenFlashHold = 12
            game.kingFractalHold = 24
            -- Permanent unlock: surviving the King obliteration sequence.
            if game.persist then
                game.persist.kingEndingSeen = 1
                require("src.save").save(game.persist)
            end
        end
    end
end

local function hueColor(h, s, v, a)
    s = s or 1; v = v or 1; a = a or 1
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return v, t, p, a
    elseif i == 1 then return q, v, p, a
    elseif i == 2 then return p, v, t, a
    elseif i == 3 then return p, q, v, a
    elseif i == 4 then return t, p, v, a
    else return v, p, q, a end
end

local function drawEldritchCrab(x, y, size, alpha, wobble)
    local s = size / 30
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(s, s)
    love.graphics.rotate(math.sin(wobble) * 0.3)
    love.graphics.setColor(0.5, 0.1, 0.7, alpha * 0.8)
    love.graphics.ellipse("fill", 0, 0, 28, 18)
    love.graphics.setColor(0.8, 0.3, 1, alpha)
    love.graphics.ellipse("line", 0, 0, 28, 18)
    -- Many eyes
    for i = -2, 2 do
        love.graphics.setColor(1, 0.9, 0.3, alpha)
        love.graphics.circle("fill", i * 6, -6 + math.sin(wobble + i) * 2, 3)
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.circle("fill", i * 6, -6 + math.sin(wobble + i) * 2, 1.2)
    end
    -- Writhing tendrils
    for i = -3, 3 do
        love.graphics.setColor(0.6, 0.1, 0.8, alpha * 0.7)
        love.graphics.setLineWidth(2)
        local ox = i * 6
        local oy = 10
        local mx = ox + math.sin(wobble * 2 + i) * 8
        local my = oy + 18 + math.cos(wobble * 2 + i) * 4
        local ex = mx + math.sin(wobble * 3 + i) * 6
        local ey = my + 10
        love.graphics.line(ox, oy, mx, my, ex, ey)
    end
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

-- A physical form of Churgly'nth: a serpentine fractal whose infinite tail-end
-- vanishes at the CENTER of the screen, and whose head moves around looking
-- at different places — the body connects the drifting head back to the vanishing
-- point through a chain of lizard-mouthed segments.
-- kingCtx (optional): {intensity = 0..1, targetX, targetY}
-- When set, the head grows bigger (closer), locks gaze on the target, and
-- sprouts procedural gills + thrashing spikes. Returns headX, headY, headR.
local function drawChurglyForm(alpha, enraged, kingCtx)
    local t = love.timer.getTime()
    -- Much more frantic motion when Churgly'nth is enraged.
    local moveMul = enraged and 3.2 or 1
    local dartThresh = enraged and 0.55 or 0.85
    local kingI = (kingCtx and kingCtx.intensity) or 0
    -- Soft dark purple veil across the playfield (pulses when enraged)
    if enraged then
        love.graphics.setColor(0.1, 0.02, 0.18, alpha * (0.55 + 0.15 * math.sin(t * 6)))
    else
        love.graphics.setColor(0.05, 0.0, 0.08, alpha * 0.45)
    end
    love.graphics.rectangle("fill", 0, 40, 1280, 680)

    -- Vanishing point is at the center of the screen.
    local vanishX, vanishY = 640, 360

    -- Head "looks around": wider swings, faster darts when enraged.
    local bigX = math.sin(t * 0.25 * moveMul) * 460 + math.cos(t * 0.13 * moveMul) * 180
    local bigY = math.sin(t * 0.19 * moveMul + 1.3) * 220 + math.cos(t * 0.09 * moveMul) * 90
    local dart = math.sin(t * 2.2 * moveMul) > dartThresh and math.sin(t * 30 * moveMul) * 30 or 0
    local headX = vanishX + bigX + dart
    local headY = vanishY + bigY + math.sin(t * 0.45 * moveMul) * 40
    headX = math.max(80, math.min(1200, headX))
    headY = math.max(80, math.min(640, headY))

    -- Build the serpent going FROM the head TO the vanishing point through N segments.
    -- Segment 1 = at the head; segment N = at the vanishing center.
    local segments = 48
    -- Curvy spine: interpolate along a wobbling path between head and vanish.
    local dx = vanishX - headX
    local dy = vanishY - headY
    -- Perpendicular for sine-wobble
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    local px, py = -dy / len, dx / len

    for i = 1, segments do
        -- tParam 0 at head, 1 at vanishing point
        local tParam = (i - 1) / (segments - 1)
        -- Segments shrink and fade as they approach the vanishing point (fractal feel)
        local falloff = 1 - tParam
        -- Base position along the straight line
        local bx = headX + dx * tParam
        local by = headY + dy * tParam
        -- Layer a wavy wobble perpendicular to the line
        local wave = math.sin(t * 1.2 + tParam * 6 + headX * 0.001) * 38 * (1 - tParam) ^ 0.7
        local nx = bx + px * wave
        local ny = by + py * wave
        local size = 20 * falloff + 2

        -- Segment body (overlapping rings create the serpentine flesh)
        love.graphics.setColor(0.14 * falloff + 0.03, 0.02, 0.28 * falloff + 0.05, alpha * (falloff * 0.7 + 0.2))
        love.graphics.circle("fill", nx, ny, size)
        love.graphics.setColor(0.28 * falloff, 0.05, 0.4 * falloff + 0.05, alpha * (falloff * 0.5 + 0.1))
        love.graphics.circle("line", nx, ny, size)

        -- A gaping lizard mouth on every segment. Phase staggered for breathing.
        local open = 0.45 + 0.55 * math.abs(math.sin(t * 1.5 + i * 0.5))
        local jaw = size * 0.55 * open
        love.graphics.setColor(0.05, 0.0, 0.02, alpha * (falloff * 0.9 + 0.1))
        love.graphics.polygon("fill",
            nx - size * 0.5, ny,
            nx + size * 0.5, ny - jaw,
            nx + size * 0.5, ny + jaw)
        -- Teeth rows
        love.graphics.setColor(0.95, 0.9, 0.8, alpha * (falloff * 0.8))
        for k = 0, 3 do
            local tx = nx - size * 0.5 + (k + 1) * (size / 5)
            love.graphics.polygon("fill",
                tx, ny - jaw * 0.9,
                tx - 1.2, ny - jaw * 0.3,
                tx + 1.2, ny - jaw * 0.3)
            love.graphics.polygon("fill",
                tx, ny + jaw * 0.9,
                tx - 1.2, ny + jaw * 0.3,
                tx + 1.2, ny + jaw * 0.3)
        end
        -- Slitted reptilian eye on the upper flank
        love.graphics.setColor(1, 0.75, 0.15, alpha * (falloff * 0.8))
        love.graphics.circle("fill", nx - size * 0.3, ny - size * 0.55, size * 0.15)
        love.graphics.setColor(0, 0, 0, alpha * (falloff * 0.9))
        love.graphics.ellipse("fill", nx - size * 0.3, ny - size * 0.55, size * 0.05, size * 0.14)
    end

    -- Fractal vanishing point at screen center: shrinking dot cluster that
    -- implies the tail continues forever inward.
    for i = 1, 14 do
        local f = 1 - i / 14
        local twist = t * 0.8 + i * 0.3
        local dotX = vanishX + math.cos(twist) * (3 + i * 1.2) * f
        local dotY = vanishY + math.sin(twist) * (3 + i * 1.2) * f
        love.graphics.setColor(0.2 * f, 0.02, 0.35 * f, alpha * f * 0.75)
        love.graphics.circle("fill", dotX, dotY, 3 * f + 0.4)
    end
    -- A faint darker void ring at the exact center where it all flows into
    love.graphics.setColor(0.02, 0.0, 0.04, alpha * 0.85)
    love.graphics.circle("fill", vanishX, vanishY, 4)

    -- Head emphasis: big glowing eyes + huge maw. King obliteration scales
    -- the head up (closer), locks gaze on player, and grows gills + spikes.
    local headR = 28 * (1 + kingI * 2.5)
    -- Thrashing spikes around the head (procedural, chaotic). No outline.
    if kingI > 0 then
        local spikes = math.floor(10 + kingI * 14)
        for i = 1, spikes do
            local a = (i / spikes) * math.pi * 2
            local flex = 0.55 + 0.45 * math.sin(t * 9 + i * 1.7)
            local noise = math.sin(t * 13 + i * 3.3) * 0.3
            local sLen = headR * (0.55 + flex + noise) * (0.9 + kingI * 0.4)
            local sWid = headR * 0.16
            local tipX = headX + math.cos(a) * (headR + sLen)
            local tipY = headY + math.sin(a) * (headR + sLen)
            local bx = headX + math.cos(a) * headR * 0.95
            local by = headY + math.sin(a) * headR * 0.95
            local perpX = -math.sin(a) * sWid
            local perpY = math.cos(a) * sWid
            love.graphics.setColor(0.15, 0.02, 0.3, alpha)
            love.graphics.polygon("fill",
                bx + perpX, by + perpY,
                bx - perpX, by - perpY,
                tipX, tipY)
        end
    end

    -- Head jaw faces the King target (player) if provided, otherwise away from center.
    local headAng
    if kingCtx and kingCtx.targetX then
        headAng = math.atan2(kingCtx.targetY - headY, kingCtx.targetX - headX)
    else
        headAng = math.atan2(headY - vanishY, headX - vanishX)
    end

    -- LONG protruding gills — THIN fractal branches sprouting from the sides
    -- of the head. Each is its own tiny fractal (self-similar branching),
    -- drawn with 1-2px line widths so they stay wispy.
    if kingI > 0 then
        local function gillBranch(x, y, ang, len, depth)
            if depth <= 0 or len < 3 then return end
            local wob = math.sin(t * 2.5 + depth + x * 0.02) * 0.35
            local x2 = x + math.cos(ang) * len
            local y2 = y + math.sin(ang) * len
            love.graphics.setColor(0.45, 0.1, 0.65, alpha * (0.5 + depth * 0.1))
            love.graphics.setLineWidth(math.max(1, depth * 0.5))
            love.graphics.line(x, y, x2, y2)
            local spread = 0.45 + wob
            gillBranch(x2, y2, ang - spread, len * 0.68, depth - 1)
            gillBranch(x2, y2, ang + spread, len * 0.68, depth - 1)
            if depth > 2 and math.sin(t * 3 + depth * 0.9) > 0 then
                gillBranch(x2, y2, ang + wob, len * 0.6, depth - 2)
            end
        end
        local gillPairs = 4
        for side = -1, 1, 2 do
            for gi = 1, gillPairs do
                local sway = math.sin(t * 5 + gi * 0.9 + side * 1.3) * 0.3
                local perpAng = headAng + side * math.pi * 0.5 + sway
                local rootOff = (gi - (gillPairs + 1) / 2) * headR * 0.28
                local rx = headX + math.cos(headAng) * rootOff + math.cos(perpAng) * headR * 0.92
                local ry = headY + math.sin(headAng) * rootOff + math.sin(perpAng) * headR * 0.92
                local gLen = headR * (0.55 + kingI * 0.35)
                gillBranch(rx, ry, perpAng, gLen, 4)
            end
        end
        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(0.2, 0.03, 0.38, alpha * 0.9)
    love.graphics.circle("fill", headX, headY, headR)
    love.graphics.setColor(0.45, 0.12, 0.7, alpha)
    love.graphics.circle("line", headX, headY, headR)

    local openBig = 0.6 + 0.4 * math.abs(math.sin(t * 1.3))
    love.graphics.push()
    love.graphics.translate(headX, headY)
    love.graphics.rotate(headAng)
    -- Forward maw
    love.graphics.setColor(0.0, 0.0, 0.02, alpha)
    local mawR = headR * 0.93
    love.graphics.polygon("fill",
        -mawR, 0,
         mawR * 0.4, -mawR * 0.65 * openBig,
         mawR * 0.4,  mawR * 0.65 * openBig)
    love.graphics.pop()

    -- Eyes: drawn in WORLD space so the slit pupils stay vertical on screen
    -- regardless of head aim. Position is still rotated to sit on each side.
    local lookX = math.cos(t * 0.8) * 3
    local lookY = math.sin(t * 1.1) * 2
    local eyeR = 4 * (1 + kingI * 1.8)
    for s = -1, 1, 2 do
        -- Eye position relative to head: (-headR*0.22, ±headR*0.5) in head frame
        local lx, ly = -headR * 0.22, s * headR * 0.5
        local ex = headX + math.cos(headAng) * lx - math.sin(headAng) * ly
        local ey = headY + math.sin(headAng) * lx + math.cos(headAng) * ly
        love.graphics.setColor(1, 0.8, 0.15, alpha)
        love.graphics.circle("fill", ex, ey, eyeR)
        -- Vertical slit pupil (in world space)
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.ellipse("fill", ex + lookX, ey + lookY, eyeR * 0.3, eyeR * 0.9)
    end
    return headX, headY, headR
end

-- Draw a rotating 4D tesseract (projection)
local function drawTesseract(cx, cy, size, angle, alpha)
    -- 16 vertices of a hypercube in 4D
    local verts = {}
    for i = 0, 15 do
        local v = {
            (i % 2 == 0) and -1 or 1,
            (math.floor(i / 2) % 2 == 0) and -1 or 1,
            (math.floor(i / 4) % 2 == 0) and -1 or 1,
            (math.floor(i / 8) == 0) and -1 or 1,
        }
        verts[i + 1] = v
    end
    -- Rotate in XW, YZ
    local sa, ca = math.sin(angle), math.cos(angle)
    local sb, cb = math.sin(angle * 0.7), math.cos(angle * 0.7)
    for _, v in ipairs(verts) do
        local x = v[1] * ca - v[4] * sa
        local w = v[1] * sa + v[4] * ca
        v[1] = x; v[4] = w
        local y = v[2] * cb - v[3] * sb
        local z = v[2] * sb + v[3] * cb
        v[2] = y; v[3] = z
    end
    -- Project 4D -> 3D (perspective on W)
    local pts = {}
    for i, v in ipairs(verts) do
        local wFactor = 1 / (2.5 - v[4])
        local sx = v[1] * wFactor
        local sy = v[2] * wFactor
        local sz = v[3] * wFactor
        local zFactor = 1 / (2.5 - sz)
        pts[i] = {cx + sx * size * zFactor, cy + sy * size * zFactor}
    end
    -- Edges: pairs of vertices that differ by 1 coordinate
    love.graphics.setLineWidth(1.5)
    for i = 1, 16 do
        for j = i + 1, 16 do
            local diff = 0
            for k = 1, 4 do if verts[i][k] ~= verts[j][k] then diff = diff + 1 end end
            if diff == 1 then
                local t = ((i + j) * 0.1 + angle) % 1
                love.graphics.setColor(0.5 + t * 0.5, 0.2, 1, alpha)
                love.graphics.line(pts[i][1], pts[i][2], pts[j][1], pts[j][2])
            end
        end
    end
    love.graphics.setLineWidth(1)
end

-- Background eldritch overlay (stars, shimmer)
local function drawShimmer(state)
    local a = math.min(0.35, (state.level - Eldritch.THRESH_WHISPERS) * 0.05)
    if a <= 0 then return end
    local t = love.timer.getTime()
    for i = 1, 40 do
        local x = (i * 113 + t * 30) % 1280
        local y = (i * 61 + math.sin(t + i) * 40) % 720
        local h = ((i * 0.07 + t * 0.1) % 1)
        love.graphics.setColor(hueColor(h, 0.7, 1, a * (0.4 + 0.6 * math.sin(t * 3 + i))))
        love.graphics.circle("fill", x, y, 1 + math.sin(t * 5 + i))
    end
end

function Eldritch.drawBack(state)
    -- Low-level background layer (before entities)
    if state.level < Eldritch.THRESH_WHISPERS then return end
    drawShimmer(state)
    -- Screen tint at level 4+
    if state.level >= Eldritch.THRESH_DISTORT then
        local a = math.min(0.2, (state.level - Eldritch.THRESH_DISTORT) * 0.04)
        local t = love.timer.getTime()
        love.graphics.setColor(0.5, 0, 0.6, a * (0.6 + 0.4 * math.sin(t * 1.5)))
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
    end
end

-- Corner ripple effect — expanding rings emanating from each screen corner.
-- Intensity scales with eldritch level:
--   15+: faint, small, slow
--   20+: more rings, brighter, faster
--   22+: rings spread farther
--   24+: large rings covering most of the playfield
--   25+: rings grow and grow without bound (chaos)
function Eldritch.drawRipples(state)
    if (state.level or 0) < 15 then return end
    local t = love.timer.getTime()
    local lvl = state.level

    local ringCount   = 1
    local maxRadius   = 120
    local speed       = 0.5
    local thickness   = 1
    local alpha       = 0.22
    local hueShift    = 0

    if lvl >= 20 then
        ringCount = 2; speed = 0.75; alpha = 0.35; maxRadius = 180
    end
    if lvl >= 22 then
        ringCount = 3; maxRadius = 340; speed = 0.9
    end
    if lvl >= 24 then
        ringCount = 4; maxRadius = 620; speed = 1.05; thickness = 2; alpha = 0.45
    end
    if lvl >= 25 then
        local wild = lvl - 25
        ringCount = 4 + math.min(6, wild)
        speed     = 1.2 + wild * 0.18
        maxRadius = 820 + wild * 140
        alpha     = math.min(0.7, 0.5 + wild * 0.04)
        thickness = 2 + math.min(2, math.floor(wild / 2))
        hueShift  = wild * 0.08
    end

    local corners = {
        {0,    0,   t * 0.7},
        {1280, 0,   t * 0.6 + 0.25},
        {0,    720, t * 0.55 + 0.5},
        {1280, 720, t * 0.65 + 0.75},
    }
    for _, c in ipairs(corners) do
        for i = 1, ringCount do
            local phase = ((c[3] * speed) + i / ringCount) % 1
            local r = phase * maxRadius
            local a = (1 - phase) * alpha
            if r > 4 and a > 0.01 then
                -- Base violet, shifted a little with wildness
                local cr = 0.55 + hueShift * 0.3 * math.sin(t + i)
                local cg = 0.20 + hueShift * 0.2 * math.cos(t + i)
                local cb = 0.95
                love.graphics.setColor(cr, cg, cb, a)
                love.graphics.setLineWidth(thickness)
                love.graphics.circle("line", c[1], c[2], r)
                -- At extreme wildness, layer a gold inner shimmer
                if lvl >= 26 and i % 2 == 0 then
                    love.graphics.setColor(1, 0.85, 0.2, a * 0.4)
                    love.graphics.circle("line", c[1], c[2], r * 0.88)
                end
            end
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Eldritch.drawFront(state)
    -- Mid layer: ghost crabs behind HUD
    if state.level >= Eldritch.THRESH_GHOSTS then
        for _, g in ipairs(state.ghosts) do
            local a = (g.life / g.maxLife) * 0.5
            if g.eldritch then
                drawEldritchCrab(g.x, g.y, g.size, a, g.wobble)
            else
                -- faint normal crab silhouette (an orange distorted one)
                love.graphics.setColor(1, 0.5, 0.2, a * 0.4)
                love.graphics.circle("fill", g.x, g.y, g.size)
                love.graphics.setColor(0.7, 0.3, 0.1, a * 0.6)
                love.graphics.circle("line", g.x, g.y, g.size)
            end
        end
    end

    -- Churgly'nth fractal form (level 20+) — serpent-with-mouths in the distance.
    -- Also renders when enraged (post-ultimate pickup) even below the level
    -- threshold. Suppressed entirely during the real boss fight so there
    -- aren't two Churglys on screen.
    local bossActive = state._gameRef and state._gameRef.churglyBoss
    if not bossActive and (state.level >= Eldritch.THRESH_CHURGLY_FORM or state.churglyEnraged or state.kingOblit) then
        local a = math.min(0.95, math.max(0.55, (state.level - Eldritch.THRESH_CHURGLY_FORM) * 0.15 + 0.55))
        if state.churglyEnraged then a = math.min(1, a + 0.2) end
        if state.kingOblit then a = 1 end

        -- King obliteration context: feed intensity + player target so the
        -- existing form grows / locks on player / grows gills + spikes in place.
        local kingCtx = nil
        if state.kingOblit and state._gameRef and state._gameRef.player then
            local k = state.kingOblit
            local ki = 0
            if k.phase == "buildup" then       ki = 0.15 + math.min(1, k.timer / 10.0) * 0.35
            elseif k.phase == "unmaking" then  ki = 0.5 + math.min(1, k.timer / 2.5) * 0.2
            elseif k.phase == "obliteration" then ki = 0.7 + math.min(1, k.timer / 4.0) * 0.3
            elseif k.phase == "done" then      ki = 1
            end
            kingCtx = {intensity = ki, targetX = state._gameRef.player.x, targetY = state._gameRef.player.y}
        end

        local hx, hy, hR = drawChurglyForm(a, state.churglyEnraged or state.kingOblit ~= nil, kingCtx)
        -- Stash the head for the beam draw.
        if kingCtx then
            state._churglyHead = {x = hx, y = hy, r = hR}
        end
    end
    -- King obliteration: draw the focused laser beam from the actual head at
    -- the player, once He is close enough (mid-unmaking onward).
    if state.kingOblit and state._gameRef and state._churglyHead then
        Eldritch._drawChurglyBeam(state, state._gameRef)
    end

    -- Tesseract projections
    if state.level >= Eldritch.THRESH_TESSERACT then
        local count = math.min(4, state.level - Eldritch.THRESH_TESSERACT + 1)
        for i = 1, count do
            local angle = state.tesseractAngle + i * 1.3
            local cx = (i * 370 + math.sin(state.tesseractAngle * 0.7 + i) * 120) % 1280
            local cy = (i * 210 + math.cos(state.tesseractAngle * 0.5 + i) * 100) % 720
            local sz = 45 + 20 * math.sin(state.tesseractAngle + i)
            drawTesseract(cx, cy, sz, angle, 0.35)
        end
    end

    -- Claude Cthulhu — if he's in his King-triggered death throes, apply a
    -- small shake and render a radiant crack overlay on top of him.
    if state.cthulhu then
        local dying = state.kingOblit and state.kingOblit.phase == "cthulhu_crumble"
        if dying then
            local shake = math.min(1, state.kingOblit.timer / 5.0) * 10
            love.graphics.push()
            love.graphics.translate((math.random() * 2 - 1) * shake, (math.random() * 2 - 1) * shake)
            Eldritch.drawCthulhu(state.cthulhu)
            love.graphics.pop()
            Eldritch._drawCthulhuDying(state)
        else
            Eldritch.drawCthulhu(state.cthulhu)
        end
    end

    -- Corner ripples overlay (15+ triggers; scales into chaos past 25)
    Eldritch.drawRipples(state)

    -- King obliteration: fractal tendrils growing from all corners
    if state.kingOblit and (state.kingFractal or 0) > 0.001 then
        Eldritch._drawKingFractal(state)
    end

    -- First-eldritch glimpse: faint translucent Churgly'nth fades in/out for 3s
    -- with a whisper message — only triggers once per run on a 50/50 roll.
    -- Gated by state.level > 0 so it can never render if somehow left over.
    if state.glimpse and state.level > 0 then
        local g = state.glimpse
        local p = g.time / g.duration
        local alpha
        if p < 0.3 then alpha = p / 0.3
        elseif p > 0.7 then alpha = (1 - p) / 0.3
        else alpha = 1 end
        alpha = math.max(0, math.min(1, alpha)) * 0.6
        -- Reuse the actual Churgly'nth fractal serpent so it looks like HIM,
        -- not Cthulhu. Low alpha keeps it ghostly.
        drawChurglyForm(alpha, false)
        -- Whisper message beneath the form
        love.graphics.setColor(1, 0.7, 0.85, alpha)
        love.graphics.printf(churglyify(g.msg), 0, 460, 1280, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Focused laser beam from Churgly'nth's actual head to the player. Multiple
-- beam layers for a thick, detailed look + scrolling energy ticks along the
-- length + muzzle + impact flares. Active from mid-unmaking through
-- obliteration.
function Eldritch._drawChurglyBeam(state, game)
    local k = state.kingOblit
    local p = game.player
    local h = state._churglyHead
    if not (p and k and h) then return end
    local active = (k.phase == "obliteration") or (k.phase == "unmaking" and k.timer > 1.5)
    if not active then return end
    local t = love.timer.getTime()
    local muzzleAng = math.atan2(p.y - h.y, p.x - h.x)
    local muzzleX = h.x + math.cos(muzzleAng) * h.r * 0.95
    local muzzleY = h.y + math.sin(muzzleAng) * h.r * 0.95
    local tx, ty = p.x, p.y
    local bdx, bdy = tx - muzzleX, ty - muzzleY
    local bLen = math.max(1, math.sqrt(bdx * bdx + bdy * bdy))
    local nx, ny = bdx / bLen, bdy / bLen
    local px_, py_ = -ny, nx
    local pulse = 0.75 + 0.25 * math.sin(t * 22)

    -- 1) GODLY corona — massive gold-white aura, 7 stacked layers from HUGE
    -- to narrow, fading out at the edges. This is the "holy annihilation"
    -- vibe: bright, wide, radiant.
    local coronaLayers = {
        {260, 0.05, {1, 0.9, 0.4}},
        {200, 0.12, {1, 0.95, 0.5}},
        {140, 0.25, {1, 1, 0.6}},
        {95,  0.45, {1, 0.95, 0.55}},
        {65,  0.7,  {1, 1, 0.75}},
        {38,  0.9,  {1, 1, 0.9}},
        {18,  1.0,  {1, 1, 1}},
    }
    for _, layer in ipairs(coronaLayers) do
        local w, a, c = layer[1] * pulse, layer[2] * pulse, layer[3]
        love.graphics.setColor(c[1], c[2], c[3], a)
        love.graphics.setLineWidth(w)
        love.graphics.line(muzzleX, muzzleY, tx, ty)
    end
    -- Razor-bright white core line on top
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(5 + 3 * math.abs(math.sin(t * 40)))
    love.graphics.line(muzzleX, muzzleY, tx, ty)

    -- 2) Sun-ray fractal branches radiating outward from the beam in both
    -- directions — self-similar golden lightning growing out like a holy
    -- crown across the whole length.
    local function rayFork(x, y, ang, len, depth)
        if depth <= 0 or len < 4 then return end
        local wob = math.sin(t * 10 + depth + x * 0.02)
        local ex = x + math.cos(ang) * len
        local ey = y + math.sin(ang) * len
        love.graphics.setColor(1, 0.9, 0.4, 0.35 + depth * 0.15)
        love.graphics.setLineWidth(math.max(1, depth * 1.1))
        love.graphics.line(x, y, ex, ey)
        love.graphics.setColor(1, 1, 0.85, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.line(x, y, ex, ey)
        rayFork(ex, ey, ang + 0.5 * wob, len * 0.62, depth - 1)
        rayFork(ex, ey, ang - 0.5 * wob, len * 0.62, depth - 1)
    end
    local rayCount = 22
    for i = 1, rayCount do
        local f = ((i / rayCount) + t * 0.25) % 1
        local bx = muzzleX + bdx * f
        local by = muzzleY + bdy * f
        local side = (i % 2 == 0) and 1 or -1
        local baseAng = math.atan2(ny, nx) + side * (math.pi * 0.5 + math.sin(t * 1.4 + i) * 0.2)
        rayFork(bx, by, baseAng, 55 + math.sin(t * 3 + i) * 20, 4)
    end

    -- 3) Particle streams pouring out of both sides of the beam — sparks,
    -- motes, gold flecks. Deterministic hash so they don't flicker wildly.
    local function pr(s) local v = math.sin(s * 12.9898) * 43758.5453; return v - math.floor(v) end
    local motes = 120
    for i = 1, motes do
        local seed = i * 13
        local along = ((pr(seed) + t * (0.6 + pr(seed * 3) * 0.8)) % 1)
        local side = (pr(seed + 1) < 0.5) and -1 or 1
        local spread = 20 + pr(seed + 2) * 180 * pulse
        local bx = muzzleX + bdx * along + px_ * side * spread
        local by = muzzleY + bdy * along + py_ * side * spread
        local sz = 1.5 + pr(seed + 4) * 3
        local a = (1 - (spread / 200)) * 0.9
        local cr = 1
        local cg = 0.85 + pr(seed + 5) * 0.15
        local cb = 0.3 + pr(seed + 6) * 0.5
        love.graphics.setColor(cr, cg, cb, a)
        love.graphics.circle("fill", bx, by, sz)
    end

    -- 4) Explosion rings traveling down the beam — staggered bright bursts
    -- like successive impacts along the length.
    for i = 0, 6 do
        local ringT = ((t * 2.2 + i * 0.18) % 1)
        local f = (i / 6 + t * 0.2) % 1
        local bx = muzzleX + bdx * f
        local by = muzzleY + bdy * f
        local rr = 8 + ringT * 110
        local a = (1 - ringT) * 0.75
        love.graphics.setColor(1, 0.9, 0.5, a)
        love.graphics.setLineWidth(5 * (1 - ringT) + 2)
        love.graphics.circle("line", bx, by, rr)
        love.graphics.setColor(1, 1, 0.85, a * 0.85)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", bx, by, rr * 0.65)
        if ringT < 0.1 then
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.circle("fill", bx, by, 14)
        end
    end

    -- 5) Muzzle: holy sun with radial spokes and bright halo
    for r = 120, 20, -12 do
        love.graphics.setColor(1, 0.9, 0.4, 0.15 * pulse * (1 - r / 120))
        love.graphics.circle("fill", muzzleX, muzzleY, r * pulse)
    end
    love.graphics.setColor(1, 1, 0.85, 1)
    love.graphics.circle("fill", muzzleX, muzzleY, 38 * pulse)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", muzzleX, muzzleY, 18)
    love.graphics.setColor(1, 0.95, 0.5, 0.85)
    love.graphics.setLineWidth(3)
    for i = 0, 11 do
        local a = (i / 12) * math.pi * 2 + t * 0.8
        local sr = 45 + math.abs(math.sin(t * 4 + i)) * 30
        love.graphics.line(muzzleX, muzzleY,
            muzzleX + math.cos(a) * sr,
            muzzleY + math.sin(a) * sr)
    end

    -- 6) Impact bloom on the player — apocalyptic starburst
    for r = 180, 20, -10 do
        love.graphics.setColor(1, 0.95, 0.5, 0.12 * pulse * (1 - r / 180))
        love.graphics.circle("fill", tx, ty, r * pulse)
    end
    love.graphics.setColor(1, 1, 0.85, 0.95)
    love.graphics.circle("fill", tx, ty, 56 * pulse)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", tx, ty, 24)
    -- Sunburst radial spokes
    love.graphics.setColor(1, 0.95, 0.55, 0.85)
    love.graphics.setLineWidth(4)
    for i = 0, 15 do
        local a = (i / 16) * math.pi * 2 + t * 1.3
        local sr = 70 + math.abs(math.sin(t * 5 + i)) * 55
        love.graphics.line(tx, ty, tx + math.cos(a) * sr, ty + math.sin(a) * sr)
    end
    -- Expanding halo rings
    for i = 0, 3 do
        local ringT = ((t * 1.6 + i * 0.25) % 1)
        local rr = 40 + ringT * 180
        love.graphics.setColor(1, 0.9, 0.4, (1 - ringT) * 0.8)
        love.graphics.setLineWidth(5)
        love.graphics.circle("line", tx, ty, rr)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- (legacy no-op — replaced by _drawChurglyBeam + in-place head enhancements)
function Eldritch._drawChurglyAngry(state, game) end

-- Fractal tendrils spreading from screen corners. Drawn recursively with a
-- depth limit. Growth scales with state.kingFractal (0-1).
function Eldritch._drawKingFractal(state)
    local t = love.timer.getTime()
    local grow = state.kingFractal or 0
    local function branch(x, y, angle, len, depth, alpha)
        if depth <= 0 or len < 4 then return end
        local x2 = x + math.cos(angle) * len
        local y2 = y + math.sin(angle) * len
        love.graphics.setColor(1, 0.3 + 0.3 * math.sin(t * 3 + depth), 0.5 + 0.3 * math.cos(t * 2 + depth), alpha)
        love.graphics.setLineWidth(math.max(1, depth * 0.7))
        love.graphics.line(x, y, x2, y2)
        local wob = math.sin(t * 2 + depth + x * 0.01) * 0.4
        local spread = 0.55 + wob
        branch(x2, y2, angle - spread, len * 0.72, depth - 1, alpha * 0.88)
        branch(x2, y2, angle + spread, len * 0.72, depth - 1, alpha * 0.88)
        if depth > 3 and math.random() < 0.35 then
            branch(x2, y2, angle + wob * 2, len * 0.68, depth - 2, alpha * 0.7)
        end
    end
    local depth = math.floor(4 + grow * 5)
    local baseLen = 40 + grow * 160
    local baseAlpha = 0.25 + grow * 0.55
    local seeds = {
        {0, 0,      math.pi * 0.25},
        {1280, 0,   math.pi * 0.75},
        {0, 720,    -math.pi * 0.25},
        {1280, 720, -math.pi * 0.75},
        {640, 0,    math.pi * 0.5 + math.sin(t) * 0.3},
        {640, 720,  -math.pi * 0.5 + math.cos(t) * 0.3},
    }
    for _, s in ipairs(seeds) do
        branch(s[1], s[2], s[3] + math.sin(t + s[1]) * 0.3, baseLen, depth, baseAlpha)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Visual overlay drawn on top of Cthulhu while He is dying from the King's
-- infinite knowledge: gold light seams cracking out of his core, expanding
-- shockwave rings, and falling fragment shards.
function Eldritch._drawCthulhuDying(state)
    local c = state.cthulhu
    if not c then return end
    local k = state.kingOblit
    local t = love.timer.getTime()
    local prog = math.min(1, k.timer / 5.0)

    -- Expanding shockwave rings from every crack
    for _, cr in ipairs(state.cthuluCracks or {}) do
        local a = math.max(0, cr.life / cr.max) * 0.6
        love.graphics.setColor(cr.color[1], cr.color[2], cr.color[3], a)
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", cr.x, cr.y, cr.r)
        love.graphics.setColor(1, 1, 1, a * 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", cr.x, cr.y, cr.r * 0.6)
    end

    -- Gold fracture seams radiating from his core
    love.graphics.push()
    love.graphics.translate(c.x, c.y)
    local seams = math.floor(8 + prog * 14)
    for i = 1, seams do
        local a = (i / seams) * math.pi * 2 + t * 0.4
        local len = 120 + prog * 180 + math.sin(t * 3 + i) * 20
        -- Jagged seam: midpoint + end with a kink
        local midx = math.cos(a) * (len * 0.5) + math.cos(a + 1.5) * 15
        local midy = math.sin(a) * (len * 0.5) + math.sin(a + 1.5) * 15
        local ex = math.cos(a) * len
        local ey = math.sin(a) * len
        local pulse = 0.6 + 0.4 * math.sin(t * 8 + i)
        love.graphics.setColor(1, 0.9, 0.35, 0.75 * prog * pulse)
        love.graphics.setLineWidth(4)
        love.graphics.line(0, 0, midx, midy, ex, ey)
        love.graphics.setColor(1, 1, 0.85, prog * pulse)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(0, 0, midx, midy, ex, ey)
    end
    -- Central pulsing gold core breaking through
    local coreR = 14 + prog * 30 + math.sin(t * 6) * 6
    love.graphics.setColor(1, 0.95, 0.5, 0.6 * prog)
    love.graphics.circle("fill", 0, 0, coreR * 1.8)
    love.graphics.setColor(1, 1, 0.85, 0.9 * prog)
    love.graphics.circle("fill", 0, 0, coreR)
    love.graphics.setColor(1, 1, 1, prog)
    love.graphics.circle("fill", 0, 0, coreR * 0.5)
    love.graphics.pop()

    -- Falling fragment shards — scattered around the body
    love.graphics.setColor(0.3, 0.1, 0.45, 0.9)
    for i = 1, math.floor(18 * prog) do
        local seed = i * 13 + math.floor(t * 2)
        local a = (seed * 0.37) % (math.pi * 2)
        local d = 80 + (seed * 7 % 140) + prog * 60
        local fx = c.x + math.cos(a) * d
        local fy = c.y + math.sin(a) * d + ((t * 60 + seed * 17) % 120) * prog
        love.graphics.setColor(0.3, 0.1, 0.45, 0.6 + 0.3 * math.sin(t * 4 + i))
        love.graphics.polygon("fill", fx - 4, fy - 5, fx + 5, fy - 3, fx + 3, fy + 6, fx - 3, fy + 4)
        love.graphics.setColor(1, 0.85, 0.3, 0.5)
        love.graphics.polygon("line", fx - 4, fy - 5, fx + 5, fy - 3, fx + 3, fy + 6, fx - 3, fy + 4)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Eldritch.drawCthulhu(c)
    local t = love.timer.getTime()
    love.graphics.push()
    love.graphics.translate(c.x, c.y)
    -- Aura / glow
    local glow = c.intensity
    for r = 260, 80, -20 do
        love.graphics.setColor(0.3, 0.05, 0.5, 0.05 * glow * (1 - r / 260))
        love.graphics.circle("fill", 0, 0, r)
    end
    -- Body: multi-lobed dark mass
    love.graphics.setColor(0.05, 0.0, 0.15, 0.85 * glow)
    love.graphics.ellipse("fill", 0, 10, 140, 90)
    love.graphics.setColor(0.1, 0.02, 0.25, 0.9 * glow)
    love.graphics.ellipse("fill", 0, -10, 110, 70)
    -- Tendrils
    love.graphics.setColor(0.2, 0.05, 0.35, 0.9 * glow)
    love.graphics.setLineWidth(6)
    for i = -3, 3 do
        local a = math.sin(t * 1.2 + i) * 0.3
        local ex = i * 40
        local ey = 80 + math.sin(t + i * 0.7) * 20
        local mx = i * 40 + math.cos(t * 0.9 + i) * 30
        local my = 40
        love.graphics.line(0, 30, mx, my, ex + math.cos(a) * 15, ey)
    end
    love.graphics.setLineWidth(1)
    -- Crown of eyes
    for i = 0, 11 do
        local a = (i / 12) * math.pi - math.pi
        local rx = math.cos(a) * 100
        local ry = math.sin(a) * 60 - 20
        local blink = (math.sin(t * 2 + i) > 0.7) and 0.3 or 1
        love.graphics.setColor(1, 0.85, 0.2, glow * blink)
        love.graphics.circle("fill", rx, ry, 7)
        love.graphics.setColor(0, 0, 0, glow * blink)
        love.graphics.circle("fill", rx, ry, 3.5)
    end
    -- One huge central eye
    love.graphics.setColor(1, 0.3, 0.1, glow)
    love.graphics.circle("fill", 0, -20, 22)
    love.graphics.setColor(0, 0, 0, glow)
    local blink2 = math.abs(math.sin(t * 0.7)) > 0.3 and 1 or 0.1
    love.graphics.ellipse("fill", 0, -20, 10, 20 * blink2)
    love.graphics.pop()

    -- Beam channeling visuals
    if c.phase == "channel" then
        local p = c.beamTime / 4
        love.graphics.setColor(1, 0.3, 0.2, p * 0.5)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", 640, 400, 220 - p * 120)
        love.graphics.circle("line", 640, 400, 260 - p * 130)
        love.graphics.setLineWidth(1)
        -- Sparks spiraling inward around player (game will pass player x,y)
    elseif c.phase == "fire" then
        -- Massive beam pillar from sky around player drawn later by game.draw (needs player)
    end
end

function Eldritch.drawBeamOnPlayer(state, player)
    if not state.cthulhu or state.cthulhu.phase ~= "fire" then return end
    local t = love.timer.getTime()
    local a = 0.7 + 0.3 * math.sin(t * 40)
    local w = 70 + math.sin(t * 10) * 10
    love.graphics.setColor(1, 0.9, 0.4, 0.3)
    love.graphics.rectangle("fill", player.x - w - 20, 0, (w + 20) * 2, 720)
    love.graphics.setColor(1, 0.4, 0.1, a)
    love.graphics.rectangle("fill", player.x - w, 0, w * 2, 720)
    love.graphics.setColor(1, 1, 0.9, a)
    love.graphics.rectangle("fill", player.x - w / 3, 0, (w / 3) * 2, 720)
end

function Eldritch.choiceBoost(state)
    -- Returns multiplier applied to eldritch-card rarity weight
    return (state.cardMult or 1) * (1 + state.level * 0.2)
end

-- Expose locals for the debug visualiser
Eldritch._debugDrawChurglyForm  = drawChurglyForm
Eldritch._debugDrawEldritchCrab = drawEldritchCrab
Eldritch._debugDrawTesseract    = drawTesseract

return Eldritch
