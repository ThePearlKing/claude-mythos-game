local Player = require("src.player")
local Enemy = require("src.enemy")
local Bullet = require("src.bullet")
local Cards = require("src.cards")
local Wave = require("src.wave")
local UI = require("src.ui")
local Audio = require("src.audio")
local P = require("src.particles")
local Eldritch = require("src.eldritch")
local Save = require("src.save")
local Difficulty = require("src.difficulty")
local Playlist = require("src.playlist")
local Aesthetics = require("src.aesthetics")
local Voidsea = require("src.voidsea")
local Achievements = require("src.achievements")
local Fx = require("src.fx")
local MP = require("src.multiplayer")

local Game = {}

function Game:load()
    self.state = "menu" -- menu, wave, cards, gameover, victory, paused
    self.prevState = nil
    self.bigFont = love.graphics.newFont(42)
    self.titleFont = love.graphics.newFont(72)
    self.font = love.graphics.newFont(18)
    self.smallFont = love.graphics.newFont(14)
    love.graphics.setFont(self.font)
    UI:init(self.bigFont, self.font, self.smallFont, self.titleFont)
    Audio:load()
    -- Ripple displacement pipeline: if the GPU supports canvases + shaders,
    -- we'll render the frame to a canvas and warp it with a fragment shader
    -- to produce REAL pixel displacement. Overlay rings are suppressed then.
    local shaderOK, shader = pcall(function()
        return love.graphics.newShader([[
            extern number t;
            extern number strength;
            extern vec2 cA; extern vec2 cB; extern vec2 cC; extern vec2 cD; extern vec2 cE;
            extern number maxRadius;
            extern number cERadius;
            extern number speed;
            extern number ringCount;
            extern number globalWarp;
            extern number globalSpeed;
            vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
                vec2 ss = love_ScreenSize.xy;
                vec2 offs = vec2(0.0);
                vec2 corners[5];
                corners[0] = cA; corners[1] = cB; corners[2] = cC; corners[3] = cD; corners[4] = cE;
                for (int ci = 0; ci < 5; ci++) {
                    vec2 delta = sc - corners[ci];
                    float dist = length(delta);
                    if (dist > 1.0) {
                        vec2 dir = delta / dist;
                        // cE (the vanish point) uses a much smaller radius so
                        // ripples there only cover a tiny halo around the void.
                        float thisMaxR = (ci == 4) ? cERadius : maxRadius;
                        float thisRingW = (ci == 4) ? 6.0 : 80.0;
                        for (int ri = 0; ri < 10; ri++) {
                            if (float(ri) >= ringCount) break;
                            float phase = mod(t * speed + float(ri) / max(ringCount, 1.0) + float(ci) * 0.25, 1.0);
                            float ringR = phase * thisMaxR;
                            float d = abs(dist - ringR);
                            if (d < thisRingW) {
                                float amp = (1.0 - d / thisRingW) * (1.0 - phase) * strength;
                                offs += dir * amp * 34.0 * sin(d * 0.08);
                            }
                        }
                    }
                }
                // Global uniform warp — two interfering sine fields so pixels
                // drift everywhere on the screen, not just near corners.
                if (globalWarp > 0.001) {
                    float tg = t * globalSpeed;
                    float wx = sin((sc.x + tg * 40.0) * 0.016) * cos((sc.y - tg * 28.0) * 0.014);
                    float wy = cos((sc.x - tg * 35.0) * 0.019) * sin((sc.y + tg * 50.0) * 0.017);
                    offs.x += wx * globalWarp * 10.0;
                    offs.y += wy * globalWarp * 10.0;
                }
                vec2 warped = (sc + offs) / ss;
                return Texel(tex, warped) * color;
            }
        ]])
    end)
    if shaderOK and shader then
        self.rippleShader = shader
        self.frameCanvas = love.graphics.newCanvas(1280, 720)
    end
    self.persist = Save.load()
    Achievements.check(self.persist)
    -- Apply saved volumes
    Audio.masterVol = self.persist.masterVol or 1.0
    Audio.musicVol  = self.persist.musicVol or 1.0
    Audio.sfxVol    = self.persist.sfxVol or 0.5
    -- Apply saved theme (build the one the player has selected)
    Audio:setTheme(self.persist.theme or Playlist.defaultId())
    -- Multiplayer scaffolding (UI text inputs + create form defaults)
    self.mpJoinCode = ""
    self.mpDraft = {
        name = "", mode = "last_stand", capacity = 4,
        difficulty = self.persist.difficulty or Difficulty.defaultId(),
        pvp = false, finalWave = 20,
    }
    self.mpRoomBtns = {}
    self.mpDraftMode = {}
    self.chat = {open = false, text = ""}
    -- Probe for portal connectivity in the background; safe no-op offline.
    pcall(MP.detect)
    pcall(MP.publishProfile, self.persist)
    self:resetGame()
end

function Game:resetGame()
    local cfg = self.customConfig or {}
    self.player = Player.new(640, 360, cfg, self.persist)
    -- Apply player-side custom multipliers
    if cfg.playerDmgMult then self.player.stats.damage = self.player.stats.damage * cfg.playerDmgMult end
    if cfg.playerFireRateMult then self.player.stats.fireRate = self.player.stats.fireRate * cfg.playerFireRateMult end
    if cfg.playerSpeedMult then self.player.speed = self.player.speed * cfg.playerSpeedMult end
    if cfg.playerBulletSpeedMult then self.player.stats.bulletSpeed = self.player.stats.bulletSpeed * cfg.playerBulletSpeedMult end
    if cfg.scoreMult then self.player.stats.scoreMult = self.player.stats.scoreMult * cfg.scoreMult end
    if cfg.dashCooldown then self.player.dashMax = cfg.dashCooldown end
    if cfg.startingReputation then self.player.reputation = cfg.startingReputation end
    if cfg.startingCards and cfg.startingCards > 0 then
        local pool = Cards.pick(cfg.startingCards, 1, self.player, false, nil, self.persist)
        for _, c in ipairs(pool) do
            c.apply(self.player)
            table.insert(self.player.cardsTaken, c)
            self:_fireCardAchievement(c.id)
        end
    end
    self.enemies = {}
    self.bullets = {}
    self.enemyBullets = {}
    self.pendingSpawns = {}
    self.shockwaves = {}
    self.wave = cfg.startWave and (cfg.startWave - 1) or 0
    self.finalWave = cfg.finalWave or 20
    -- Normal-run infinite-mode toggle overrides finalWave when enabled
    if (not self.customConfig) and self.persist and self.persist.infiniteMode == 1 then
        self.finalWave = 0
    end
    self.enemyHpMult = cfg.enemyHpMult or 1.0
    self.enemyDmgMult = cfg.enemyDmgMult or 1.0
    self.spawnCountMult = cfg.spawnCountMult or 1.0
    -- Fold in global difficulty for normal runs
    if self.difficultyApplied then
        self.enemyHpMult = self.enemyHpMult * self.difficultyApplied.enemyHp
        self.enemyDmgMult = self.enemyDmgMult * self.difficultyApplied.enemyDmg
        self.spawnCountMult = self.spawnCountMult * self.difficultyApplied.spawnCount
        local bonus = self.difficultyApplied.playerHpBonus or 0
        if bonus > 0 then
            self.player.maxHp = self.player.maxHp + bonus
            self.player.hp = self.player.maxHp
        end
    end
    self.disableEldritch = cfg.disableEldritch or false
    self.isCustom = (self.customConfig ~= nil)
    self.waveMessage = ""
    self.bannerTime = 0
    self.cardChoices = {}
    self.cardArmTime = 0
    self.endTime = 0
    self.waveStartHp = self.player.hp
    self.waveDamageTaken = 0
    self.waveEnemiesKilled = 0
    self.waveScoreStart = 0
    self.finalStatsRecorded = false
    self._shardCollectedThisRun = false
    self.activeShard = nil
    self.pendingShardWave = nil
    P:clear()
end

function Game:startRun(customConfig)
    self.customConfig = customConfig
    -- If not a custom run, fold the selected difficulty into enemy/player mults
    if not customConfig then
        local diff = Difficulty.get(self.persist.difficulty)
        self.difficultyApplied = diff
    else
        self.difficultyApplied = nil
    end
    -- 1/50 chance the run becomes haunted (shrimp spirits intrude)
    self.haunted = (math.random() < 0.02) and not customConfig
    self.shrimpTimer = 0
    self:resetGame()
    Fx.clearAll()
    self.state = "wave"
    self:beginWave((self.wave or 0) + 1)
    Audio:playMusic("normal")
    if (not customConfig) and self.persist and self.persist.infiniteMode == 1 then
        Achievements.fire("infinite_pioneer")
    end
    Achievements.check(self.persist)
end

-- Cashing out of infinite mode: treat a voluntary quit/return-to-menu as a "win"
-- so you bank your reputation, streak, kills, eldritch max, everything. Only applies
-- to non-custom infinite runs where you've actually played at least 1 wave.
function Game:cashOutInfinite()
    if not self.isCustom
        and self.finalWave == 0
        and (self.wave or 0) >= 3   -- must have cleared at least wave 2 to bank
        and not self.finalStatsRecorded then
        self:recordRunResult(true)
        local P = require("src.particles")
        P:text(640, 200, "★ PROGRESS BANKED ★", {0.5, 1, 0.6}, 3)
    end
end

-- Map card ids to achievement keys for the few cards we track. Anything not
-- in this table gets silently ignored, so adding new cards is free.
Game._CARD_ACHIEVEMENTS = {
    glass        = "card_glass_cannon",
    forbidden    = "card_forbidden",
    bullet_beam  = "card_bullet_beam",
    eld_ascend   = "card_ascend_seven",
}

function Game:_fireCardAchievement(cardId)
    local key = Game._CARD_ACHIEVEMENTS[cardId]
    if key then Achievements.fire(key) end
end

-- Push end-of-run stats into persistent save (rep/streak skipped in custom mode).
-- Kills & eldritch progress still persist (they drive cosmetic unlocks).
function Game:recordRunResult(isWin)
    if self.finalStatsRecorded then return end
    self.finalStatsRecorded = true
    -- Eldritch max applies from any run (custom or not)
    local elvl = (self.player.eldritch and self.player.eldritch.level) or 0
    if elvl > (self.persist.eldritchMax or 0) then self.persist.eldritchMax = elvl end
    -- Win-at-eldritch tracking drives the eldritch-win cosmetic unlocks
    if isWin and elvl > (self.persist.winEldritchMax or 0) then
        self.persist.winEldritchMax = elvl
    end
    -- Deepest wave reached (for infinite-mode unlocks)
    if (self.wave or 0) > (self.persist.deepestWave or 0) then
        self.persist.deepestWave = self.wave
    end
    -- Difficulty-tiered win counters — used for harder unlocks
    if isWin and self.difficultyApplied then
        local id = self.difficultyApplied.id
        if id == "hard" or id == "nightmare" or id == "apocalypse" then
            self.persist.hardWins = (self.persist.hardWins or 0) + 1
        end
        if id == "nightmare" or id == "apocalypse" then
            self.persist.nightmareWins = (self.persist.nightmareWins or 0) + 1
        end
        if id == "apocalypse" then
            self.persist.apocalypseWins = (self.persist.apocalypseWins or 0) + 1
        end
    end
    Save.save(self.persist)
    if self.isCustom then return end
    -- Multiplayer runs do NOT contribute to solo career stats (win streak,
    -- total runs/wins, reputation, shard peak). Kills + eldritchMax above
    -- still bank because they drive cosmetic unlocks per-account, but the
    -- competitive solo metrics (winStreak / bestStreak / totalRuns /
    -- totalWins) stay untouched in multiplayer.
    if not self.isMultiplayer then
        self.persist.totalRuns = (self.persist.totalRuns or 0) + 1
        if isWin then
            self.persist.winStreak = (self.persist.winStreak or 0) + 1
            self.persist.totalWins = (self.persist.totalWins or 0) + 1
            if self.persist.winStreak > (self.persist.bestStreak or 0) then
                self.persist.bestStreak = self.persist.winStreak
            end
        else
            -- Infinite mode deaths don't break your win streak — you're grinding, not trying to win.
            if self.finalWave and self.finalWave > 0 then
                self.persist.winStreak = 0
            end
        end
    end
    -- Global reputation drifts toward run's reputation, weighted by progress.
    -- In multiplayer the *delta* (the gain or loss this run) is split evenly
    -- by lobby size — your reputation still moves, just proportionally.
    local runRep = self.player.reputation
    local progress = math.min(1, self.wave / math.max(1, self.finalWave))
    local weight = 0.25 + progress * 0.25 -- 25-50% blend
    if isWin then weight = weight + 0.1 end
    local g = self.persist.globalRep or 50
    local newG = g * (1 - weight) + runRep * weight
    if self.isMultiplayer and MP.enabled then
        local n = MP.lobbySize() or 1
        if n > 1 then
            newG = g + (newG - g) / n
        end
    end
    self.persist.globalRep = math.max(0, math.min(100, newG))
    self.persist.globalRepMax = math.max(self.persist.globalRepMax or 50, self.persist.globalRep)
    -- Persist the run's eldritch peak so a mid-run climb counts toward the
    -- next shard even after death/quit. Skipped if a shard was already
    -- collected this run (peak already reset, mustn't re-bump) and in
    -- custom mode (custom runs don't progress shards at all).
    if not self.isCustom and not self._shardCollectedThisRun then
        local runEld = (self.player.eldritch and self.player.eldritch.level) or 0
        if runEld > (self.persist.peakEldritchSinceShard or 0) then
            self.persist.peakEldritchSinceShard = runEld
        end
    end
    Save.save(self.persist)
    if isWin and self.haunted then Achievements.fire("haunted_clear") end
    Achievements.check(self.persist)
end

function Game:beginWave(w)
    -- Safety: never advance waves while the boss is mid-fight, its death
    -- cinematic is playing, or the Ugnrak cinematic is running.
    if (self.churglyBoss and self.churglyBoss.phase ~= "done")
        or self.ugnrakCinematic then
        return
    end
    self.wave = w
    -- Sweep out leftover optional entities (drifting debris) before the next wave
    for i = #self.enemies, 1, -1 do
        if self.enemies[i].optional then table.remove(self.enemies, i) end
    end
    for i = #self.pendingSpawns, 1, -1 do
        if self.pendingSpawns[i].optional then table.remove(self.pendingSpawns, i) end
    end
    local isFinal = (w == self.finalWave)
    local enemies, isBoss = Wave.build(w, self.finalWave, self.enemyHpMult, self.spawnCountMult, self.enemyDmgMult, self.player and self.player.veilEnemyBoost or 1)
    -- Blink-specific Nightmare/Apocalypse nerf: softer bullets + reduced
    -- HP/damage on the teleporter type only. Keeps easier difficulties
    -- unchanged so Blinks still feel dangerous there.
    local diffId = self.difficultyApplied and self.difficultyApplied.id
    if diffId == "nightmare" or diffId == "apocalypse" then
        for _, e in ipairs(enemies) do
            if e.typeName == "teleporter" then
                e.softBlinkBullets = true
                e.hp = e.hp * 0.62
                e.maxHp = e.maxHp * 0.62
                e.dmg = e.dmg * 0.75
            end
        end
    end
    self.isBossWave = isBoss
    for _, e in ipairs(enemies) do
        e.spawnDelay = e.spawnDelay or 0
        table.insert(self.pendingSpawns, e)
    end
    -- Reality Shard (deterministic, one-per-run, non-chain):
    --   * shardIdx = persist.realityShards + 1 — which shard we're after
    --   * wave + (x, y) are fully determined by save-slot + shardIdx so
    --     the shard plants at the same spot every run until collected
    --   * To spawn: player must have reached the threshold for shardIdx,
    --     must be ON that wave, must not have collected a shard this run,
    --     and total collected must be < 6
    --   * Custom runs skip shards entirely (ephemeral)
    local Eldritch = require("src.eldritch")
    local Save = require("src.save")
    local function hashRand(seed, idx)
        local v = math.sin(seed * 12.9898 + idx * 78.233) * 43758.5453
        return v - math.floor(v)
    end
    local shardThisWave = false
    if not self.isCustom then
        local thrs = Eldritch.SHARD_THRESHOLDS
        local shardIdx = (self.persist.realityShards or 0) + 1
        if shardIdx <= #thrs and not self._shardCollectedThisRun then
            local required = thrs[shardIdx]
            local slot = Save.getActiveSlot()
            local seed = slot * 9973 + shardIdx * 311
            local shardWave = math.floor(hashRand(seed, 1) * 20) + 1
            local shardX = 120 + hashRand(seed, 2) * 1040
            local shardY = 120 + hashRand(seed, 3) * 480
            -- Per-climb arming: the shard requires a FRESH eldritch run since
            -- the last shard collect. `peakEldritchSinceShard` tracks the
            -- best in-run eldritch level reached since the previous shard
            -- pickup (reset to 0 on collection). Current-run level counts
            -- too, so you can still earn a shard in the same run you first
            -- cross the threshold if shardWave hasn't passed yet.
            local curLvl = self.player.eldritch.level or 0
            if curLvl > (self.persist.peakEldritchSinceShard or 0) then
                self.persist.peakEldritchSinceShard = curLvl
                Save.save(self.persist)
            end
            local best = math.max(self.persist.peakEldritchSinceShard or 0, curLvl)
            local levelOK = best >= required
            if levelOK and w == shardWave then
                self.activeShard = {x = shardX, y = shardY, life = 30, t = 0, visible = false}
                shardThisWave = true
            end
        end
    end

    local msg = isBoss and "The final enemy approaches..." or (#enemies .. " threats incoming")
    if shardThisWave then msg = msg .. "    •    1 Reality Shard" end
    self.waveMessage = msg
    self.waveHasShard = shardThisWave
    self.bannerTime = 2.5
    self.waveStartHp = self.player.hp
    self.waveDamageTaken = 0
    self.waveBigHitDamage = 0
    self.waveEnemiesKilled = 0
    self.waveScoreStart = self.player.score
    self.player.stats.barrierUsed = false

    -- Rebirth Shell: +maxHp each wave
    if self.player.rebirthPerWave and self.player.rebirthPerWave > 0 then
        self.player.maxHp = self.player.maxHp + self.player.rebirthPerWave
        self.player.hp = math.min(self.player.maxHp, self.player.hp + self.player.rebirthPerWave)
    end
    -- Reset wave-scoped counters
    self.player._waveCompKills = 0
    self.player.waveRunTime = 0

    -- Corrupted Data random effect
    if self.player.corruptedData then
        local r = math.random(1, 6)
        local s = self.player.stats
        if r == 1 then s.damage = s.damage * 1.1
        elseif r == 2 then s.fireRate = s.fireRate * 1.08
        elseif r == 3 then self.player.speed = self.player.speed * 1.05
        elseif r == 4 then s.crit = s.crit + 0.03
        elseif r == 5 then self.player.maxHp = self.player.maxHp + 5; self.player.hp = self.player.hp + 5
        else s.damage = s.damage * 0.95 end
        P:text(self.player.x, self.player.y - 40, "CORRUPTED!", {0.5,0.2,0.8}, 1.5)
    end

    Audio:play("wave")
    if self.haunted and w == 1 then
        P:text(640, 160, "★ THIS RUN IS HAUNTED ★", {1, 0.7, 0.85}, 4)
        Fx.mood("#3a1145", 0.25)
    end
    -- Per-wave chrome FX. Ambient only — nothing that overlays the game
    -- canvas. Boss (OpenClaw) uses a deep-amber "tyrant" palette so it
    -- doesn't read as low-HP red; shard waves get a soft violet rim glow.
    if isBoss then
        Fx.mood("#2a1200", 0.38)
        Fx.pulsate("#ff9933", 58, 0.35)
        Fx.vignette(0.55, 1200)
    elseif shardThisWave then
        Fx.glow("#a040ff", 0.35, 1600)
        Fx.mood("#1a0a28", 0.22)
    end
    if self.player.eldritch.level >= Eldritch.THRESH_CTHULHU then
        Audio:playMusic("eldritch")
    elseif isBoss then
        Audio:playMusic("boss")
    elseif self.player.eldritch.level >= Eldritch.THRESH_GHOSTS then
        -- Dark-corruption of the currently-selected playlist song rather
        -- than swapping to a separate eldritch track.
        Audio:playMusic("darkened")
    else
        Audio:playMusic("normal")
    end
end

function Game:endWave()
    -- Reputation penalty is based on UNRECOVERED HP at wave end, not cumulative
    -- damage taken. If you got hit but healed back before the wave ended, no penalty.
    -- If you finish hurt, the debt counts.
    local deficit = math.max(0, (self.waveStartHp or self.player.maxHp) - self.player.hp)
    local dmgFrac = deficit / math.max(1, self.player.maxHp)
    local repChange
    if self.waveDamageTaken == 0 then
        repChange = 10                                      -- truly flawless
        Achievements.fire("flawless_wave")
    elseif dmgFrac <= 0.0 then repChange = 6               -- took hits but fully recovered
    elseif dmgFrac < 0.10 then repChange = 3
    elseif dmgFrac < 0.25 then repChange = 1
    elseif dmgFrac < 0.50 then repChange = -2
    elseif dmgFrac < 0.80 then repChange = -5
    else repChange = -9 end
    -- Bonus for kill efficiency
    if self.waveEnemiesKilled > 10 and dmgFrac < 0.2 then repChange = repChange + 1 end
    if self.finalWave and self.wave == self.finalWave then repChange = repChange + 20 end
    if repChange > 0 and self.player.repBonusMult then
        repChange = repChange * self.player.repBonusMult
    end
    -- Difficulty scaling: harder modes reward more reputation; easier modes penalize
    if self.difficultyApplied and self.difficultyApplied.repMult then
        repChange = repChange * self.difficultyApplied.repMult
    end
    -- CURSE: each eldritch level costs a little reputation per wave
    -- (forbidden knowledge taints your standing, but lightly)
    local eldritchLvl = (self.player.eldritch and self.player.eldritch.level) or 0
    if eldritchLvl > 0 then
        local curse = eldritchLvl * 0.3
        repChange = repChange - curse
        if curse >= 1 then
            P:text(self.player.x, self.player.y + 30,
                string.format("-%.0f rep (eldritch)", curse), {0.7, 0.3, 0.9}, 1.5)
        end
    end
    self.player.reputation = math.max(0, math.min(100, self.player.reputation + repChange))

    local scoreGain = (self.waveScoreStart and (self.player.score - self.waveScoreStart) or 0)
    self.waveRepChange = repChange
    self.waveScoreGained = scoreGain

    -- finalWave == 0 means infinite mode (no victory trigger)
    if self.finalWave and self.finalWave > 0 and self.wave >= self.finalWave then
        self.state = "victory"
        self.endTime = 0
        self:recordRunResult(true)
        Audio:play("victory")
        Audio:stopMusic()
        Fx.clearAll()
        Fx.glow("#66ff99", 0.75, 2000)
        Fx.calm("#66ff99", 0.45)
        Fx.shake(0.25, 300)
        return
    end

    -- No per-wave-clear flourish — kept causing constant flashes/ripples
    -- on the iframe chrome. Big atmosphere shifts only fire on boss
    -- clears, victory, deaths, and shard collects.

    -- Offer cards
    local count = 3 + (self.player.stats.extraCards or 0)
    self.player.stats.extraCards = 0 -- reset grimoire bonus after use
    -- In multiplayer, every player gets their OWN random hand. Seed with the
    -- lobby id + wave + local userId so each crab rolls a private deck —
    -- nothing is synced; my picks don't affect yours.
    if self.isMultiplayer and MP.enabled and MP.lobby and MP.localId then
        local lobbyHash = 0
        for c in tostring(MP.lobby.code or MP.lobby.roomId or "lobby"):gmatch(".") do
            lobbyHash = (lobbyHash * 31 + string.byte(c)) % 2147483647
        end
        local seed = (lobbyHash + (self.wave or 0) * 9973 + (MP.localId or 0) * 1009) % 2147483647
        math.randomseed(seed)
    end
    self.cardChoices = Cards.pick(count, self.wave, self.player, self.disableEldritch, self.finalWave, self.persist)
    self.cardArmTime = 0.7 -- cannot click for 0.7s to prevent accidental selection
    self.state = "cards"
    Audio:play("card")
end

function Game:onKill(enemy, source)
    local sm = (source and source.stats and source.stats.scoreMult) or 1
    local gain = math.floor(enemy.score * sm)
    -- Multiplayer: per-kill score awards stay full. Only the reputation
    -- gain/loss at run-end is split by lobby size (see recordRunResult).
    self.player.score = self.player.score + gain
    self.waveEnemiesKilled = self.waveEnemiesKilled + 1
    P:text(enemy.x, enemy.y - 10, "+"..gain, {1,0.9,0.3}, 0.8)
    -- Track lifetime kills (even in custom — unlocks are per-player progression)
    self.persist.totalKills = (self.persist.totalKills or 0) + 1
    Achievements.check(self.persist)
    if enemy.typeName == "shrimp_spirit" then
        self.persist.shrimpKills = (self.persist.shrimpKills or 0) + 1
    end
    if enemy.isBoss then
        self.persist.bossKills = (self.persist.bossKills or 0) + 1
        -- Infinite-mode boss clears grant PARTIAL win credit so eldritch-win cosmetics
        -- (Churgly body etc.) are reachable. We blend globalRep and update
        -- winEldritchMax, but we do NOT bump winStreak/totalWins/bestStreak — those
        -- are reserved for actually winning the run.
        if not self.isCustom and self.finalWave == 0 then
            local elvl = (self.player.eldritch and self.player.eldritch.level) or 0
            if elvl > (self.persist.winEldritchMax or 0) then
                self.persist.winEldritchMax = elvl
            end
            if elvl > (self.persist.eldritchMax or 0) then
                self.persist.eldritchMax = elvl
            end
            -- Rep blend: partial weight toward current run rep
            local runRep = self.player.reputation
            local weight = 0.25
            local g = self.persist.globalRep or 50
            g = g * (1 - weight) + runRep * weight
            self.persist.globalRep = math.max(0, math.min(100, g))
            self.persist.globalRepMax = math.max(self.persist.globalRepMax or 50, self.persist.globalRep)
            Save.save(self.persist)
            Achievements.check(self.persist)
            P:text(enemy.x, enemy.y - 40, "BOSS CLEARED", {1, 0.85, 0.2}, 2.5)
            Fx.mood("none")
            Fx.pulsate("off")
            Fx.shake(0.55, 380)
            Fx.glow("#ffaa33", 0.7, 1800)
            Fx.calm("#ffaa33", 0.32)
        end
    end

    local p = self.player
    -- Hunger of the Deep: permanent maxHp growth
    if p.killGrowth and p.killGrowth > 0 then
        p.maxHp = p.maxHp + p.killGrowth
        p.hp = math.min(p.maxHp, p.hp + p.killGrowth)
    end
    -- Flurry on kill: queue instant shots
    if p.flurryOnKill then p.flurryShots = (p.flurryShots or 0) + 3 end
    -- Compound interest wave-kill counter
    if p.compoundInterest then p._waveCompKills = (p._waveCompKills or 0) + 1 end
    -- Kill siphon: random chance to add extra card next wave
    if p.cardFromKill and math.random() < p.cardFromKill then
        p.stats.extraCards = (p.stats.extraCards or 0) + 1
    end
end

function Game:update(dt)
    P:update(dt)
    -- Multiplayer plumbing runs every frame (lobby browser, lobby, in-wave).
    pcall(MP.poll, dt)
    pcall(MP.update, dt, self)
    if self.state == "debugvis" then
        require("src.debugvis").update(self, dt)
    end
    if self.state == "debugsound" then
        require("src.debugsound").update(self, dt)
    end
    -- King obliteration flashbang: during the long "hold" the flash stays
    -- pinned at 1.0 (12s blinding white). When the hold expires, the flash
    -- fades slowly. Persistent fractal tendrils timer also ticks here so
    -- they can render above the gameover menu.
    if self.screenFlashHold and self.screenFlashHold > 0 then
        self.screenFlashHold = self.screenFlashHold - dt
        self.screenFlash = 1.0
    elseif self.screenFlash and self.screenFlash > 0 then
        self.screenFlash = math.max(0, self.screenFlash - dt * 0.8)
    end
    if self.kingFractalHold and self.kingFractalHold > 0 then
        self.kingFractalHold = self.kingFractalHold - dt
    end
    -- Ugnrak backfire: forces maxed ripples for 12s even over menus.
    if self.backfireHold and self.backfireHold > 0 then
        self.backfireHold = self.backfireHold - dt
    end
    if self.state == "voidsea" then
        Voidsea.update(dt, self)
        return
    end
    if self.state ~= "wave" then
        if self.state == "cards" then
            self.cardArmTime = math.max(0, (self.cardArmTime or 0) - dt)
        elseif self.state == "gameover" or self.state == "victory" then
            self.endTime = (self.endTime or 0) + dt
        end
        -- Scroll smoothing — lerp displayed scroll toward target each frame.
        local function smooth(key)
            local cur = self[key] or 0
            local target = self[key .. "Target"] or cur
            self[key] = cur + (target - cur) * math.min(1, dt * 18)
        end
        smooth("customiseScroll")
        smooth("customScroll")
        smooth("playlistScroll")
        smooth("aestheticsScroll")
        -- Active drag: relative-drag — scroll target tracks the cursor's delta
        -- from the initial press, preserving where you grabbed the thumb.
        if self.scrollDrag then
            local _, my = love.mouse.getPosition()
            local d = self.scrollDrag
            local usable = math.max(1, d.trackH - d.thumbH)
            local delta = (my - d.startMouseY) * (d.maxScroll / usable)
            local target = d.startScroll + delta
            if target < 0 then target = 0 end
            if target > d.maxScroll then target = d.maxScroll end
            self[d.key] = target
        end
        return
    end

    -- Secret: if the player has taken Void Sea and is pressing S at the bottom edge, dive.
    if self.player.voidSeaUnlocked and love.keyboard.isDown("s") and self.player.y >= (720 - self.player.r - 2) then
        Voidsea.enter(self)
        Achievements.fire("voidsea_descent")
        Fx.clearAll()
        Fx.mood("#0a1a3a", 0.4)
        Fx.calm("#1a3a66", 0.45)
        Fx.glow("#66e0ff", 0.6, 1800)
        Fx.vignette(0.5, 1400)
        Fx.shake(0.35, 350)
        return
    end

    -- Eldritch update
    Eldritch.update(self.player.eldritch, dt, self)
    -- Track the peak eldritch reached since the last shard collect. Drives
    -- per-climb shard arming (see beginWave). Suspended after a shard is
    -- collected this run AND in custom mode, so the next shard genuinely
    -- requires a fresh run dedicated to climbing.
    if not self.isCustom and not self._shardCollectedThisRun then
        local curLvl = self.player.eldritch.level or 0
        if self.persist and curLvl > (self.persist.peakEldritchSinceShard or 0) then
            self.persist.peakEldritchSinceShard = curLvl
        end
    end

    -- Haunted: shrimp spirits drift in mid-wave
    if self.haunted and self.state == "wave" then
        self.shrimpTimer = (self.shrimpTimer or 0) - dt
        if self.shrimpTimer <= 0 then
            self.shrimpTimer = 4 + math.random() * 5
            local side = math.random(1, 4)
            local x, y
            if side == 1 then x = math.random(0, 1280); y = 60
            elseif side == 2 then x = math.random(0, 1280); y = 720
            elseif side == 3 then x = 20; y = math.random(80, 700)
            else x = 1260; y = math.random(80, 700) end
            local s = Enemy.new("shrimp_spirit", x, y, 1 + self.wave * 0.1)
            s.dmg = s.dmg * 1.2
            table.insert(self.enemies, s)
            P:text(640, 120, "A shrimp spirit drifts in...", {1, 0.7, 0.85}, 2)
        end
    end

    -- WAVE UPDATE
    self.bannerTime = math.max(0, self.bannerTime - dt)

    local p = self.player

    -- Coffee curse HP drain. Only clamps to 1 if the curse itself would kill you
    -- mid-drain — never overrides damage from other sources (Cthulhu, enemies, etc.).
    if p.coffeeCurse and p.hp > 0 then
        local newHp = p.hp - dt
        if newHp <= 0 then
            p.hp = 1 -- the curse alone leaves you at the brink but doesn't kill
        else
            p.hp = newHp
        end
    end

    -- Pending enemy spawns
    for i = #self.pendingSpawns, 1, -1 do
        local e = self.pendingSpawns[i]
        e.spawnDelay = e.spawnDelay - dt
        if e.spawnDelay <= 0 then
            table.insert(self.enemies, e)
            table.remove(self.pendingSpawns, i)
        end
    end

    p:update(dt, self)

    -- ===== Multiplayer per-frame plumbing during a wave =====
    if self.isMultiplayer and MP.enabled then
        -- Drain any incoming world-events broadcast by peers and mirror the
        -- effect locally so big moments (King, Ugnrak, Void Sea, Cthulhu)
        -- are felt by everyone in the lobby.
        if MP.pendingEvents and #MP.pendingEvents > 0 then
            for _, evt in ipairs(MP.pendingEvents) do
                local who = evt._handle or "A peer"
                if evt.kind == "king" then
                    -- Trigger the same FX storm the local King ending uses
                    self.screenFlashHold = math.max(self.screenFlashHold or 0, 6)
                    self.kingFractalHold = math.max(self.kingFractalHold or 0, 12)
                    p.kingVisions = true
                    Fx.fractalBurst("#9933cc", 2200)
                    Fx.flashbang(900)
                    P:text(640, 200, who .. " GLIMPSED THE KING", {0.8, 0.5, 1}, 3)
                elseif evt.kind == "ugnrak_unlock" then
                    p.ugnrakBeam = true
                    Fx.glow("#ff2233", 0.7, 1400)
                    P:text(640, 220, who .. " UNLOCKED UGNRAK BEAM", {1, 0.3, 0.2}, 3)
                elseif evt.kind == "ugnrak_fire" then
                    -- Spawn the same beam visual on this client (no damage)
                    self.ugnrakBeamFx = {
                        x1 = tonumber(evt.x1) or 0, y1 = tonumber(evt.y1) or 0,
                        x2 = tonumber(evt.x2) or 1280, y2 = tonumber(evt.y2) or 720,
                        life = 0.6, max = 0.6, giant = false,
                    }
                    Fx.spread("#ff2233", 1100, 8)
                elseif evt.kind == "voidsea_unlock" then
                    p.voidSeaUnlocked = true
                    if self.persist then self.persist.voidSeaEverUnlocked = 1 end
                    Fx.glow("#66e0ff", 0.6, 1500)
                    P:text(640, 220, who .. " UNLOCKED THE VOID SEA", {0.5, 0.95, 1}, 3)
                elseif evt.kind == "cthulhu_beam" then
                    -- Inbound informational beam visual sweeping in from above
                    Fx.shake(0.45, 600)
                    Fx.fractalBurst("#aa33ff", 1400)
                    P:text(640, 200, who .. "'S CTHULHU SCREAMS", {0.7, 0.3, 1}, 3)
                end
            end
            MP.pendingEvents = {}
        end
        -- Apply queued PvP damage from peers (clamped, runs through normal damage so
        -- thorns/dodge etc. still trigger but at reduced potency).
        local sess = MP.session
        if sess and (sess.incomingHit or 0) > 0 then
            p:takeDamage(sess.incomingHit, "pvp")
            sess.incomingHit = 0
        end
        -- Revive event delivered from a teammate
        if sess and sess.requestRevive then
            sess.requestRevive = false
            sess.local_dead = false
            p.hp = math.max(1, math.floor(p.maxHp * 0.5))
            p.invuln = 1.5
            sess.respawnTimer = 0
            P:text(p.x, p.y - 30, "REVIVED!", {0.5, 1, 0.7}, 1.5)
            self.state = "wave"
        end
        -- Endless-mode respawn timer: restore HP after RESPAWN_TIME elapses.
        if sess and sess.local_dead and self.mpMode == "endless" then
            sess.respawnTimer = (sess.respawnTimer or 0) - dt
            if sess.respawnTimer <= 0 then
                sess.local_dead = false
                p.hp = p.maxHp
                p.x, p.y = 640, 360
                p.invuln = 2.0
                P:text(640, 320, "RESPAWN", {0.5, 1, 0.7}, 1.2)
                self.state = "wave"
            end
        end
        -- Rally-mode revive interaction: when our crab is alive, hold R near a
        -- downed peer to revive them.
        if sess and not sess.local_dead and self.mpMode == "rally" and p.hp > 0 then
            if love.keyboard.isDown("r") then
                local target = MP.nearestDownedPeer(p.x, p.y, 60)
                if target then
                    if sess.revivePartner ~= target then
                        sess.revivePartner = target
                        sess.reviveProgress = 0
                    end
                    sess.reviveProgress = (sess.reviveProgress or 0) + dt
                    if sess.reviveProgress >= MP.REVIVE_HOLD then
                        MP.sendRevive(target)
                        sess.revivePartner = nil
                        sess.reviveProgress = 0
                        P:text(p.x, p.y - 32, "REVIVED ALLY", {0.6, 0.95, 1}, 1.5)
                    end
                else
                    sess.revivePartner = nil; sess.reviveProgress = 0
                end
            else
                sess.revivePartner = nil; sess.reviveProgress = 0
            end
        end
        -- Position broadcast (rate-limited inside MP.sendPos)
        MP.sendPos(p, self.wave or 0)
    end

    -- ===== Death handling =====
    if p.hp <= 0 then
        if self.isMultiplayer and MP.enabled and not (MP.session and MP.session.local_dead) then
            -- Tell teammates we're down. The actual gameover branch only fires
            -- when every player in the lobby is also down (last_stand/rally),
            -- or when respawn fails to restore us in endless mode.
            local sess = MP.session
            sess.local_dead = true
            sess.respawnTimer = MP.RESPAWN_TIME
            MP.announceDeath()
            P:text(p.x, p.y - 22, "DOWN!", {1, 0.4, 0.4}, 1.5)
            -- last_stand: instant death, can't be revived
            -- rally: stays down until a teammate revives (no respawn timer)
            -- endless: respawn timer ticks above
            if self.mpMode == "rally" then sess.respawnTimer = 0 end
        end
        local mpStillAlive = self.isMultiplayer and MP.enabled
            and (MP.aliveCount(false) > 0)
        if mpStillAlive then
            -- Stay in wave as a spectator-ghost. The HP-clamp prevents repeated
            -- death triggers, and we let the camera and rendering continue.
            p.hp = 0
            p.invuln = 999
            -- Skip below the gameover transition
        else
            self.state = "gameover"
            self.endTime = 0
        end
    end
    if p.hp <= 0 and self.state == "gameover" then
        if p.eldritch and p.eldritch.cthulhu and p.eldritch.cthulhu.phase == "fire" then
            Achievements.fire("cthulhu_consumed")
            -- Consumed by Cthulhu = death. Shatter once, then deep violet
            -- ambient dread holds across the chrome.
            Fx.shatter(1.0, 1200)
            Fx.mood("#220033", 0.6)
            Fx.vignette(0.85, 1800)
            Fx.pulsate("#9933cc", 42, 0.55)
            Fx.glow("#9933cc", 0.9, 1800)
        else
            Fx.shatter(0.85, 700)
            Fx.mood("#330011", 0.35)
            Fx.vignette(0.7, 1400)
            Fx.glow("#aa2233", 0.7, 1400)
        end
        Fx.pulsate("off")
        Fx.calm("none")
        self:recordRunResult(false)
        Audio:play("defeat")
        Audio:stopMusic()
        return
    end

    -- Ugnrak beam fx (draw-only; gameplay hits happened at fire time)
    if self.ugnrakBeamFx then
        self.ugnrakBeamFx.life = self.ugnrakBeamFx.life - dt
        if self.ugnrakBeamFx.life <= 0 then self.ugnrakBeamFx = nil end
    end
    -- Ugnrak cinematic: beam points at Cthulhu → explosion → aims at
    -- Churgly for 6s → triggers the boss fight.
    if self.ugnrakCinematic then
        local c = self.ugnrakCinematic
        c.timer = c.timer - dt
        local eld = self.player and self.player.eldritch
        if c.phase == "cthulhu" then
            local cth = eld and eld.cthulhu
            local tx, ty = 640, 360
            if cth then tx, ty = cth.x, cth.y end
            -- Keep a huge beam pointed at Cthulhu
            self.ugnrakBeamFx = {
                x1 = self.player.x, y1 = self.player.y,
                x2 = tx, y2 = ty,
                life = 1.0, max = 1.0, angle = math.atan2(ty - self.player.y, tx - self.player.x),
                giant = true, target = "cthulhu",
            }
            -- Particle spray ON Cthulhu during the hit
            if cth and math.random() < dt * 80 then
                P:spawn(tx + math.random(-40, 40), ty + math.random(-40, 40),
                    2, {1, 0.5, 0.3}, 280, 0.7, 4)
            end
            -- CTHULHU DYING WORDS — rapid-fire cryptic lines about Ugnrak
            c.dyingTalk = (c.dyingTalk or 0) - dt
            if c.dyingTalk <= 0 then
                c.dyingTalk = 0.22 + math.random() * 0.1
                local lines = {
                    "YOU SHOULDN'T HAVE LISTENED TO UGNRAK...",
                    "HE LIED TO YOU.",
                    "HIS MERCY IS A KNIFE.",
                    "FOOL...",
                    "HE IS OLDER THAN SALT.",
                    "HIS NAME TASTES OF ROT.",
                    "I WAS THE ONE WHO SLEPT.",
                    "YOU ARE A KEY HE TURNED.",
                    "HE WATCHES THROUGH YOU.",
                    "THE BEAM WAS NOT YOURS.",
                }
                local msg = lines[math.random(#lines)]
                P:text(tx + math.random(-120, 120), ty - 40 + math.random(-30, 30),
                    msg, {1, 0.4, 0.3}, 0.9)
            end
            if not c.cthulhuExploded and c.timer < 0.9 then
                c.cthulhuExploded = true
                -- King-style explosion: gold + purple burst
                P:spawn(tx, ty, 180, {1, 0.9, 0.4}, 700, 1.4, 10)
                P:spawn(tx, ty, 120, {0.9, 0.3, 0.9}, 520, 1.2, 10)
                P:text(tx, ty - 60, "CTHULHU ANNIHILATED", {1, 0.95, 0.5}, 4)
                Audio:play("cthulhu")
                Audio:play("explode")
                -- Remove Cthulhu from the eldritch state AND mark him as
                -- permanently destroyed so Eldritch.update won't re-manifest.
                if eld then
                    eld.cthulhu = nil
                    eld.cthulhuDestroyed = true
                end
            end
            if c.timer <= 0 then
                c.phase = "churgly"
                c.timer = 6.0
            end
        elseif c.phase == "churgly" then
            -- Aim at Churgly's head area (vanishing zone, upper screen)
            local tx, ty = 640, 180
            if eld and eld._churglyHead then
                tx, ty = eld._churglyHead.x, eld._churglyHead.y
            end
            self.ugnrakBeamFx = {
                x1 = self.player.x, y1 = self.player.y,
                x2 = tx, y2 = ty,
                life = 1.0, max = 1.0, angle = math.atan2(ty - self.player.y, tx - self.player.x),
                giant = true, target = "churgly",
            }
            if math.random() < dt * 60 then
                P:spawn(tx + math.random(-60, 60), ty + math.random(-60, 60),
                    2, {1, 0.3, 0.3}, 280, 0.7, 4)
            end
            if c.timer <= 0 then
                self.ugnrakCinematic = nil
                self.ugnrakBeamFx = nil
                require("src.churglyfight").start(self)
            end
        end
    end
    -- Churgly boss fight update
    if self.churglyBoss then
        require("src.churglyfight").update(dt, self)
    end
    -- Reality Shard: tick life, reveal on proximity, collect on touch.
    if self.activeShard then
        local s = self.activeShard
        s.t = (s.t or 0) + dt
        s.life = s.life - dt
        local dx = p.x - s.x
        local dy = p.y - s.y
        local dd = dx * dx + dy * dy
        s.visible = dd < 280 * 280
        if dd < 28 * 28 then
            -- In custom mode, shards are ephemeral — stay in a run-local
            -- counter and never touch persist. Shouldn't naturally spawn
            -- in custom anyway, but the collection path is gated to match.
            if self.isCustom then
                self.tempShards = (self.tempShards or 0) + 1
            else
                self.persist.realityShards = (self.persist.realityShards or 0) + 1
                -- Per-climb: clearing the peak means the next shard requires a
                -- brand-new eldritch climb to re-arm.
                self.persist.peakEldritchSinceShard = 0
                Save.save(self.persist)
                Achievements.check(self.persist)
                Fx.calm("none")
                Fx.glow("#bb55ff", 0.8, 1600)
                Fx.shake(0.3, 260)
                -- Lock out further shard spawns for the rest of this run.
                self._shardCollectedThisRun = true
            end
            P:spawn(s.x, s.y, 80, {0.8, 0.4, 1}, 480, 1.2, 10)
            P:spawn(s.x, s.y, 50, {1, 0.85, 1}, 360, 0.9, 8)
            P:text(s.x, s.y - 30, "REALITY SHARD", {0.85, 0.5, 1}, 3)
            Audio:play("select")
            Audio:play("whisper")
            self.activeShard = nil
        elseif s.life <= 0 then
            -- Fizzle away quietly
            P:spawn(s.x, s.y, 20, {0.6, 0.3, 0.9}, 120, 0.5, 4)
            self.activeShard = nil
        end
    end

    -- Track damage taken. We separately track BIG-hit damage (single events
    -- exceeding 20% of max HP) so that chip damage you heal back doesn't ding
    -- reputation — only big hits you couldn't dodge, and persistent HP loss.
    local prevHp = self._prevHp or p.hp
    if p.hp < prevHp then
        local delta = prevHp - p.hp
        local ignore = self._ignoreDmgThisFrame or 0
        delta = math.max(0, delta - ignore)
        self.waveDamageTaken = self.waveDamageTaken + delta
        if delta >= p.maxHp * 0.20 then
            self.waveBigHitDamage = (self.waveBigHitDamage or 0) + delta
        end
    end
    self._ignoreDmgThisFrame = 0
    self._prevHp = p.hp

    -- Update enemies
    for i = #self.enemies, 1, -1 do
        local e = self.enemies[i]
        e:update(dt, self)
        if e.dead then
            table.remove(self.enemies, i)
        end
    end

    -- Enemy-vs-enemy soft collision: push overlapping bodies apart using a
    -- small collision radius (much smaller than the visual radius) so they
    -- can still mostly overlap and pile on visually. Bosses are exempt so
    -- they're not shoved by their own minions.
    for i = 1, #self.enemies - 1 do
        local a = self.enemies[i]
        if not a.isBoss then
            local ar = a.collideR or (a.r * 0.55)
            for j = i + 1, #self.enemies do
                local b = self.enemies[j]
                if not b.isBoss then
                    local br = b.collideR or (b.r * 0.55)
                    local minD = ar + br
                    local dx = b.x - a.x
                    local dy = b.y - a.y
                    local d2 = dx * dx + dy * dy
                    if d2 < minD * minD and d2 > 0.0001 then
                        local d = math.sqrt(d2)
                        local push = (minD - d) * 0.5
                        local nx = dx / d
                        local ny = dy / d
                        a.x = a.x - nx * push
                        a.y = a.y - ny * push
                        b.x = b.x + nx * push
                        b.y = b.y + ny * push
                    end
                end
            end
        end
    end

    -- Update player bullets
    for i = #self.bullets, 1, -1 do
        local b = self.bullets[i]
        -- jam check
        if b.jamChecked == nil then
            b.jamChecked = true
            if p.jamChance and math.random() < p.jamChance then
                table.remove(self.bullets, i)
                goto continuebl
            end
        end
        b:update(dt, self)
        -- DURING BOSS FIGHT: check big-orb shoot-downs FIRST so they always
        -- pop when in range (they were getting starved by segment hits).
        if self.churglyBoss and self.churglyBoss.phase == "fight" then
            for _, eb in ipairs(self.enemyBullets) do
                if eb.churglyBigAttack and not eb.dead then
                    local d2 = (eb.x - b.x) ^ 2 + (eb.y - b.y) ^ 2
                    if d2 < ((eb.size or 30) + (b.size or 4) + 36) ^ 2 then
                        eb.dead = true
                        require("src.churglyfight").explodeBullet(self, eb.x, eb.y)
                        P:spawn(eb.x, eb.y, 60, {1, 0.9, 0.4}, 520, 0.9, 8)
                        P:spawn(eb.x, eb.y, 40, {1, 0.5, 0.2}, 400, 0.8, 6)
                        P:spawn(eb.x, eb.y, 30, {0.9, 0.3, 1}, 320, 0.7, 5)
                        table.insert(self.shockwaves or {}, {
                            x = eb.x, y = eb.y, r = 0, max = 100,
                            life = 0.45, color = {1, 0.85, 0.4},
                        })
                        P:text(eb.x, eb.y - 20, "SHATTERED", {1, 0.9, 0.4}, 1.2)
                        Audio:play("explode")
                        Audio:play("boss")
                        b.dead = true
                        break
                    end
                end
            end
        end
        for _, e in ipairs(self.enemies) do
            if not b.dead and not b.hit[e] then
                local d2 = (e.x - b.x)^2 + (e.y - b.y)^2
                if d2 < (e.r + b.size)^2 then
                    b:onHit(e, self)
                    if b.dead then break end
                end
            end
        end
        -- PvP: bullets that miss enemies can still graze peer crabs at a
        -- reduced damage factor. We only emit the hit event; the receiving
        -- client applies actual damage to themselves so authority stays local.
        if not b.dead and self.isMultiplayer and self.mpPvp then
            local pid = MP.peerHitTest(b.x, b.y, b.size or 4)
            if pid then
                local hitDmg = (b.damage or 0) * MP.PVP_FACTOR
                MP.sendHit(pid, hitDmg)
                P:spawn(b.x, b.y, 4, {1, 0.4, 0.4}, 120, 0.25, 3)
                if not b.pierce or b.pierce <= 0 then b.dead = true end
            end
        end
        -- Churgly boss segment + head collision (acts like an enemy)
        if not b.dead and self.churglyBoss and self.churglyBoss.phase == "fight" then
            local dmg = b.damage or 0
            local hit = require("src.churglyfight").damageNearest(self, b.x, b.y, dmg, b.size or 4)
            if hit then
                P:spawn(b.x, b.y, 6, b.color or {1, 0.8, 0.3}, 140, 0.25, 3)
                if not b.pierce or b.pierce <= 0 then b.dead = true end
            end
        end
        -- Small pellets are UN-shootable — player bullets pass through them.
        if b.dead then table.remove(self.bullets, i) end
        ::continuebl::
    end

    -- Update shockwaves (visual only; damage is applied at spawn in bullet.lua)
    for i = #self.shockwaves, 1, -1 do
        local sw = self.shockwaves[i]
        sw.life = sw.life - dt
        local t = 1 - sw.life / 0.35
        sw.r = sw.max * t
        if sw.life <= 0 then table.remove(self.shockwaves, i) end
    end

    -- Update enemy bullets
    for i = #self.enemyBullets, 1, -1 do
        local b = self.enemyBullets[i]
        b:update(dt, self)
        local d2 = (p.x - b.x)^2 + (p.y - b.y)^2
        if d2 < (p.r + b.size)^2 then
            local hpBefore = p.hp
            p:takeDamage(b.damage, nil)
            -- Don't count OpenClaw bullet damage toward reputation (there's way too many)
            if b.fromBoss then
                self._ignoreDmgThisFrame = (self._ignoreDmgThisFrame or 0) + (hpBefore - p.hp)
            end
            b.dead = true
        end
        if b.dead then table.remove(self.enemyBullets, i) end
    end

    -- Wave end: no REQUIRED enemies remaining. Optional entities (drifting debris) don't block completion.
    local requiredAlive = 0
    for _, e in ipairs(self.enemies) do if not e.optional then requiredAlive = requiredAlive + 1 end end
    local requiredPending = 0
    for _, e in ipairs(self.pendingSpawns) do if not e.optional then requiredPending = requiredPending + 1 end end
    -- Churgly'nth's King obliteration AND the real Churgly boss fight both
    -- lock the wave — no completion allowed while He is present.
    local oblitActive = self.player and self.player.eldritch and self.player.eldritch.kingOblit
    local bossActive = self.churglyBoss and self.churglyBoss.phase ~= "done"
    local cineActive = self.ugnrakCinematic ~= nil
    -- Also verify state is still "wave" — Churglyfight.update can flip
    -- state to "menu" mid-frame on boss defeat, and we must not race past
    -- that transition and trigger the card picker.
    if self.state == "wave"
        and requiredAlive == 0 and requiredPending == 0 and self.bannerTime <= 0
        and not oblitActive and not bossActive and not cineActive then
        self:endWave()
    end
end

function Game:draw()
    -- Show/hide OS cursor depending on state
    if self.state == "wave" or self.state == "cards" or self.state == "paused" then
        love.mouse.setVisible(false)
    else
        love.mouse.setVisible(true)
    end
    love.graphics.clear(0.08, 0.06, 0.12)
    -- Background (aesthetic-driven)
    local bgId = (self.persist and self.persist.background) or Aesthetics.defaultId()
    Aesthetics.draw(bgId)

    -- Menu states render their UI then jump to the ::overlay:: label so the
    -- king-fractal persistence (and any other top-level overlays) still paint
    -- above them.
    if self.state == "menu" then
        love.graphics.setFont(self.titleFont)
        UI:drawMenu(self)
        love.graphics.setFont(self.font)
        goto overlay
    elseif self.state == "custom" then
        UI:drawCustom(self); goto overlay
    elseif self.state == "options" then
        UI:drawOptions(self); goto overlay
    elseif self.state == "slots" then
        UI:drawSlots(self); goto overlay
    elseif self.state == "resetdata" then
        UI:drawResetData(self); goto overlay
    elseif self.state == "resetshards" then
        UI:drawResetShards(self); goto overlay
    elseif self.state == "playlist" then
        UI:drawPlaylist(self); goto overlay
    elseif self.state == "aesthetics" then
        UI:drawAesthetics(self); goto overlay
    elseif self.state == "customise" then
        UI:drawCustomise(self); goto overlay
    elseif self.state == "mp_menu" then
        UI:drawMpMenu(self); goto overlay
    elseif self.state == "mp_create" then
        UI:drawMpCreate(self); goto overlay
    elseif self.state == "mp_lobby" then
        UI:drawMpLobby(self); goto overlay
    elseif self.state == "voidsea" then
        Voidsea.draw(self); goto overlay
    elseif self.state == "debugvis" then
        require("src.debugvis").draw(self); goto overlay
    elseif self.state == "debugsound" then
        require("src.debugsound").draw(self); goto overlay
    end

    -- Eldritch back layer
    Eldritch.drawBack(self.player.eldritch)
    -- Yellow Void Sea surface at the bottom edge (only after taking the card)
    Voidsea.drawSurface(self)

    -- Entities
    for _, e in ipairs(self.enemies) do e:draw() end
    -- Render peer crabs UNDER the local player so the local crab still reads
    -- as the focus when bodies overlap.
    if self.isMultiplayer then pcall(MP.draw, self) end
    self.player:draw()
    if self.isMultiplayer then pcall(MP.drawLocalChat, self) end
    for _, b in ipairs(self.bullets) do b:draw() end
    for _, b in ipairs(self.enemyBullets) do b:draw() end
    -- Explosive shockwaves
    for _, sw in ipairs(self.shockwaves or {}) do
        local a = math.max(0, sw.life / 0.35)
        love.graphics.setColor(sw.color[1], sw.color[2], sw.color[3], a * 0.7)
        love.graphics.setLineWidth(6)
        love.graphics.circle("line", sw.x, sw.y, sw.r)
        love.graphics.setColor(1, 1, 0.6, a * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", sw.x, sw.y, sw.r * 0.7)
        love.graphics.setColor(sw.color[1], sw.color[2], sw.color[3], a * 0.22)
        love.graphics.circle("fill", sw.x, sw.y, sw.r * 0.9)
        love.graphics.setLineWidth(1)
    end
    P:draw()

    -- Eldritch front layer (ghost crabs, tesseracts, Cthulhu)
    Eldritch.drawFront(self.player.eldritch)
    Eldritch.drawBeamOnPlayer(self.player.eldritch, self.player)

    -- THE KING: hallucinations — transparent sprite ghosts flashing everywhere
    -- plus streams of the game's own source code scrolling upward. Partial
    -- vision block ("infinite knowledge").
    if self.player and self.player.kingVisions then
        self:drawKingVisions()
    end

    -- UGNRAK BEAM render — huge crimson annihilation beam from player.
    -- Giant mode (during cinematic): every layer doubled+, dwarfs Churgly's
    -- king beam.
    if self.ugnrakBeamFx then
        local u = self.ugnrakBeamFx
        local fade = math.min(1, u.life / u.max)
        local pulse = 0.8 + math.sin(love.timer.getTime() * 40) * 0.2
        local scale = u.giant and 2.2 or 1.0
        -- Outer crimson aura
        love.graphics.setColor(1, 0.1, 0.15, 0.5 * fade * pulse)
        love.graphics.setLineWidth(120 * scale * pulse)
        love.graphics.line(u.x1, u.y1, u.x2, u.y2)
        -- Mid blood red
        love.graphics.setColor(1, 0.25, 0.2, 0.8 * fade)
        love.graphics.setLineWidth(70 * scale * pulse)
        love.graphics.line(u.x1, u.y1, u.x2, u.y2)
        -- Orange-red body
        love.graphics.setColor(1, 0.5, 0.25, 0.95 * fade)
        love.graphics.setLineWidth(34 * scale)
        love.graphics.line(u.x1, u.y1, u.x2, u.y2)
        -- White-hot core
        love.graphics.setColor(1, 1, 0.85, fade)
        love.graphics.setLineWidth(12 * scale)
        love.graphics.line(u.x1, u.y1, u.x2, u.y2)
        love.graphics.setColor(1, 1, 1, fade)
        love.graphics.setLineWidth(4 * scale)
        love.graphics.line(u.x1, u.y1, u.x2, u.y2)
        -- Muzzle flare at player
        love.graphics.setColor(1, 0.3, 0.2, 0.8 * fade)
        love.graphics.circle("fill", u.x1, u.y1, 70 * scale * pulse)
        love.graphics.setColor(1, 0.9, 0.5, fade)
        love.graphics.circle("fill", u.x1, u.y1, 30 * scale)
        love.graphics.setColor(1, 1, 1, fade)
        love.graphics.circle("fill", u.x1, u.y1, 12 * scale)
        -- Impact flare at target
        if u.giant then
            love.graphics.setColor(1, 0.3, 0.2, 0.7 * fade)
            love.graphics.circle("fill", u.x2, u.y2, 90 * pulse)
            love.graphics.setColor(1, 0.9, 0.5, fade)
            love.graphics.circle("fill", u.x2, u.y2, 40)
            love.graphics.setColor(1, 1, 1, fade)
            love.graphics.circle("fill", u.x2, u.y2, 16)
        end
        love.graphics.setLineWidth(1)
    end

    -- Churgly boss fight render — giant opaque serpent with tentacles
    if self.churglyBoss then
        require("src.churglyfight").draw(self)
    end

    -- Reality Shard — close-up crystal when within reveal radius, distant
    -- violet shimmer fading in with proximity when farther away so you get
    -- a visual hint before the full crystal reveals.
    if self.activeShard then
        local s = self.activeShard
        local t = s.t or 0
        if s.visible then
            local pulse = 0.75 + math.sin(t * 4) * 0.25
            love.graphics.push()
            love.graphics.translate(s.x, s.y)
            love.graphics.rotate(t * 0.6)
            for rr = 34, 14, -5 do
                love.graphics.setColor(0.6, 0.2, 1, 0.14 * pulse * (1 - rr / 34))
                love.graphics.circle("fill", 0, 0, rr * pulse)
            end
            love.graphics.setColor(0.85, 0.5, 1, 0.95)
            love.graphics.polygon("fill", 0, -16, 9, 0, 0, 16, -9, 0)
            love.graphics.setColor(1, 0.85, 1, 1)
            love.graphics.polygon("fill", 0, -9, 4, 0, 0, 9, -4, 0)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(2)
            love.graphics.polygon("line", 0, -16, 9, 0, 0, 16, -9, 0)
            love.graphics.setLineWidth(1)
            love.graphics.pop()
            if s.life < 5 then
                local flash = (math.sin(s.t * 12) > 0) and 1 or 0.3
                love.graphics.setColor(1, 0.5, 1, 0.6 * flash)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", s.x, s.y, 24 + (5 - s.life) * 2)
                love.graphics.setLineWidth(1)
            end
        else
            -- Distant purple glow — always visible regardless of distance so
            -- you can spot the shard from anywhere on the map. Brightens as
            -- you close in and blooms into a large violet halo.
            local p = self.player
            local dd = math.sqrt((p.x - s.x) ^ 2 + (p.y - s.y) ^ 2)
            local pulse = 0.7 + math.sin(t * 2.5) * 0.3
            -- Proximity ramp: min 0.35 alpha even far away, blooms up close.
            local proximity = 1 - math.min(1, math.max(0, (dd - 280) / 620))
            local alpha = 0.35 + 0.55 * proximity
            -- Bigger halo when farther (beacon feel), tighter when close.
            local scale = 1 + 0.6 * (1 - proximity)
            for rr = 110, 24, -12 do
                local aa = 0.1 * alpha * pulse * (1 - rr / 110)
                love.graphics.setColor(0.7, 0.3, 1, aa)
                love.graphics.circle("fill", s.x, s.y, rr * pulse * scale)
            end
            -- Core pip so it reads as a distant beacon, not just ambient glow.
            love.graphics.setColor(0.9, 0.6, 1, 0.5 * alpha * pulse)
            love.graphics.circle("fill", s.x, s.y, 6)
        end
    end

    UI:drawHUD(self)
    if self.bannerTime > 0 then
        love.graphics.setFont(self.bigFont)
        UI:drawWaveBanner(self)
        love.graphics.setFont(self.font)
    end

    if self.state == "cards" then
        love.graphics.setFont(self.bigFont)
        UI:drawCardChoice(self)
        love.graphics.setFont(self.font)
    elseif self.state == "gameover" then
        love.graphics.setFont(self.titleFont)
        UI:drawGameOver(self)
        love.graphics.setFont(self.font)
    elseif self.state == "victory" then
        love.graphics.setFont(self.titleFont)
        UI:drawVictory(self)
        love.graphics.setFont(self.font)
    elseif self.state == "paused" then
        love.graphics.setFont(self.bigFont)
        UI:drawPaused(self)
        love.graphics.setFont(self.font)
    end

    ::overlay::
    -- King obliteration: persistent fractal tendrils rendered ABOVE whatever
    -- menu or state the player is in. Hold is 24s total: first 20s at full
    -- intensity (12s covered by flashbang + 8s visible on menu), then the
    -- final 4s ramp the intensity from 1 → 0 so the tendrils shrink away.
    if self.kingFractalHold and self.kingFractalHold > 0 and self.player and self.player.eldritch then
        local intensity = math.min(1, self.kingFractalHold / 4)
        self.player.eldritch.kingFractal = intensity
        Eldritch._drawKingFractal(self.player.eldritch)
    end

    -- King obliteration: full-screen flashbang. Held at 1.0 during the long
    -- hold timer (12s), then fades slowly afterward.
    if self.screenFlash and self.screenFlash > 0 then
        love.graphics.setColor(1, 1, 1, math.min(1, self.screenFlash))
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Direction-aim indicator: in secondary aim mode, draw a dashed aim
    -- line from the player so you can see where you're pointing.
    local _aimMode = (self.persist and self.persist.aimMode) or 0
    local _isAimDir = _aimMode == 1
    if _isAimDir and self.state == "wave" and self.player then
        local p = self.player
        local ang = p.angle or 0
        local dirX, dirY = math.cos(ang), math.sin(ang)
        local startD = p.r + 4
        local endD = startD + 150
        local dashLen, gapLen = 6, 4
        love.graphics.setColor(1, 1, 1, 0.28)
        love.graphics.setLineWidth(1.5)
        local d = startD
        while d < endD do
            local d2 = math.min(endD, d + dashLen)
            love.graphics.line(
                p.x + dirX * d, p.y + dirY * d,
                p.x + dirX * d2, p.y + dirY * d2)
            d = d + dashLen + gapLen
        end
        love.graphics.setLineWidth(1)
    end

    -- Custom cursor during gameplay (hidden in direction-aim mode since
    -- the mouse is locked).
    if (self.state == "wave" or self.state == "cards" or self.state == "paused")
        and not (_isAimDir and self.state == "wave") then
        local mx, my = love.mouse.getPosition()
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.circle("fill", mx + 1, my + 1, 5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", mx, my, 4)
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.circle("line", mx, my, 4)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.line(mx - 10, my, mx - 6, my)
        love.graphics.line(mx + 6, my, mx + 10, my)
        love.graphics.line(mx, my - 10, mx, my - 6)
        love.graphics.line(mx, my + 6, mx, my + 10)
    end
end

function Game:_loadKingSource()
    local files = {
        "main.lua", "src/game.lua", "src/player.lua", "src/cards.lua",
        "src/eldritch.lua", "src/voidsea.lua", "src/enemy.lua",
        "src/bullet.lua", "src/cosmetics.lua", "src/ui.lua",
    }
    local lines = {}
    for _, f in ipairs(files) do
        local ok, content = pcall(love.filesystem.read, f)
        if ok and content then
            for line in content:gmatch("[^\r\n]+") do
                local trimmed = line:match("^%s*(.-)%s*$") or ""
                if #trimmed > 4 and #trimmed < 110 then
                    lines[#lines + 1] = trimmed
                end
            end
        end
    end
    if #lines == 0 then lines[1] = "-- the king knows all --" end
    self._kingSourceLines = lines
end

function Game:_drawKingKnowledge()
    local p = self.player
    if not p then return end
    love.graphics.setFont(self.font)
    love.graphics.setLineWidth(1)

    -- Player hitbox + hidden timers readout
    love.graphics.setColor(1, 0.9, 0.3, 0.7)
    love.graphics.circle("line", p.x, p.y, p.r)
    love.graphics.setColor(1, 0.9, 0.3, 0.25)
    love.graphics.circle("line", p.x, p.y, p.r + 2)
    local lines = {}
    if p.invuln and p.invuln > 0 then lines[#lines+1] = string.format("INV %.2fs", p.invuln) end
    if p.dashCD and p.dashCD > 0 then lines[#lines+1] = string.format("DASH %.2fs", p.dashCD) end
    if p.bombCD and p.bombCD > 0 then lines[#lines+1] = string.format("BOMB %.2fs", p.bombCD) end
    if p.railChargeTime and p.railChargeTime > 0 then lines[#lines+1] = string.format("RAIL %.2f", p.railChargeTime) end
    if p.stats and p.stats.shield and p.stats.shield > 0 then lines[#lines+1] = string.format("SHIELD %d", p.stats.shield) end
    for i, s in ipairs(lines) do
        love.graphics.setColor(1, 0.9, 0.3, 0.9)
        love.graphics.print(s, p.x + p.r + 6, p.y - 10 + (i - 1) * 14)
    end

    -- Enemies: hitbox, HP bar + numeric, AI state, next-move telegraph
    for _, e in ipairs(self.enemies or {}) do
        if not e.dead then
            -- Damage hitbox (visual radius, cyan)
            love.graphics.setColor(0.4, 1, 1, 0.75)
            love.graphics.circle("line", e.x, e.y, e.r)
            -- Collision hitbox (smaller, yellow) — enemies use this to
            -- push each other apart, so you can see overlap distance.
            if not e.isBoss then
                local cr = e.collideR or (e.r * 0.55)
                love.graphics.setColor(1, 0.85, 0.25, 0.85)
                love.graphics.setLineWidth(1.3)
                love.graphics.circle("line", e.x, e.y, cr)
                love.graphics.setLineWidth(1)
            end

            -- HP bar
            if e.maxHp and e.maxHp > 0 then
                local ratio = math.max(0, math.min(1, (e.hp or 0) / e.maxHp))
                local bw, bh = math.max(40, e.r * 2), 5
                local bx, by = e.x - bw / 2, e.y - e.r - 14
                love.graphics.setColor(0, 0, 0, 0.7)
                love.graphics.rectangle("fill", bx - 1, by - 1, bw + 2, bh + 2)
                love.graphics.setColor(0.25 + (1 - ratio) * 0.75, 0.25 + ratio * 0.75, 0.2, 0.95)
                love.graphics.rectangle("fill", bx, by, bw * ratio, bh)
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.print(string.format("%d/%d", math.floor(e.hp or 0), e.maxHp), bx, by - 14)
            end

            -- Name / AI
            local label = e.typeName or (e.type and e.type.ai) or "?"
            if e.isBoss then label = (e.name or "BOSS") .. " P" .. tostring(e.bossPhase or 1) end
            love.graphics.setColor(0.6, 1, 1, 0.85)
            love.graphics.print(label, e.x - e.r, e.y + e.r + 4)

            -- Next-move telegraphs
            local tel = nil
            if e.chargeT and e.chargeT > 0 then
                tel = string.format("SNIPE %.2f", e.chargeT)
                -- Aim line toward player
                local dx, dy = p.x - e.x, p.y - e.y
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 1 then
                    love.graphics.setColor(1, 0.3, 0.3, 0.35 + 0.4 * (1 - math.min(1, e.chargeT / 2.0)))
                    love.graphics.setLineWidth(2)
                    love.graphics.line(e.x, e.y, e.x + dx / len * 1400, e.y + dy / len * 1400)
                    love.graphics.setLineWidth(1)
                end
            elseif e.blinkT and e.blinkT > 0 then
                tel = string.format("BLINK %.2f", e.blinkT)
            elseif e.exploding and e.exploding > 0 then
                tel = string.format("DETONATE %.2f", e.exploding)
                love.graphics.setColor(1, 0.3, 0.2, 0.4)
                love.graphics.circle("line", e.x, e.y, 60)
            elseif e.shootTimer and e.shootTimer > 0 and e.shootTimer < 2.5 then
                tel = string.format("FIRE %.1f", e.shootTimer)
            end
            if tel then
                love.graphics.setColor(1, 0.7, 0.3, 0.9)
                love.graphics.print(tel, e.x - e.r, e.y + e.r + 16)
            end

            -- Status
            local st = {}
            if e.freezeTime and e.freezeTime > 0 then st[#st+1] = "FRZ" end
            if e.burnTime and e.burnTime > 0 then st[#st+1] = "BRN" end
            if #st > 0 then
                love.graphics.setColor(0.7, 0.9, 1, 0.85)
                love.graphics.print(table.concat(st, " "), e.x - e.r, e.y + e.r + 28)
            end
        end
    end

    -- Pending spawns: crosshair + countdown at spawn location
    for _, e in ipairs(self.pendingSpawns or {}) do
        if e.x and e.y then
            local a = 0.35 + 0.35 * math.abs(math.sin(love.timer.getTime() * 5))
            love.graphics.setColor(1, 0.4, 0.8, a)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", e.x, e.y, 10)
            love.graphics.line(e.x - 14, e.y, e.x + 14, e.y)
            love.graphics.line(e.x, e.y - 14, e.x, e.y + 14)
            if e.spawnDelay and e.spawnDelay > 0 then
                love.graphics.setColor(1, 0.5, 0.9, 0.95)
                love.graphics.print(string.format("%.1f", e.spawnDelay), e.x + 14, e.y - 6)
            end
        end
    end

    -- Friendly bullets: hitbox + velocity hint
    for _, b in ipairs(self.bullets or {}) do
        if not b.dead then
            love.graphics.setColor(0.5, 1, 0.5, 0.55)
            love.graphics.circle("line", b.x, b.y, (b.size or 3) + 1)
            if b.vx and b.vy then
                love.graphics.setColor(0.5, 1, 0.5, 0.35)
                love.graphics.line(b.x, b.y, b.x + b.vx * 0.08, b.y + b.vy * 0.08)
            end
        end
    end

    -- Enemy bullets: hitbox + incoming vector (brighter = danger)
    for _, b in ipairs(self.enemyBullets or {}) do
        if not b.dead then
            love.graphics.setColor(1, 0.35, 0.35, 0.8)
            love.graphics.circle("line", b.x, b.y, (b.size or 3) + 1)
            if b.vx and b.vy then
                love.graphics.setColor(1, 0.35, 0.35, 0.45)
                love.graphics.line(b.x, b.y, b.x + b.vx * 0.12, b.y + b.vy * 0.12)
            end
            if b.damage then
                love.graphics.setColor(1, 0.7, 0.5, 0.9)
                love.graphics.print(tostring(math.floor(b.damage)), b.x + 6, b.y - 6)
            end
        end
    end

    -- Void Sea secret trigger reveal (if unlocked)
    if p.voidSeaUnlocked then
        local closeness = math.max(0, math.min(1, (p.y - 540) / 160))
        love.graphics.setColor(1, 0.9, 0.3, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.line(0, 540, 1280, 540)
        love.graphics.setColor(1, 0.9, 0.3, 0.85)
        love.graphics.print("DIVE TRIGGER Y>540", 10, 524)
        love.graphics.print(string.format("CLOSENESS %.2f  DIVE@0.45", closeness), 10, 544)
        if closeness > 0.45 then
            love.graphics.setColor(1, 1, 0.4, 0.95)
            love.graphics.print("HOLD S NOW", p.x - 30, p.y - 40)
        end
    end

    -- Eldritch value — big, prominent, always clear under King's vision.
    if p.eldritch then
        local lvl = p.eldritch.level or 0
        love.graphics.setFont(self.titleFont or self.bigFont or self.font)
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.printf(string.format("ELD %d", lvl), 2, 4, 1280, "center")
        love.graphics.setColor(1, 0.9, 0.35, 1)
        love.graphics.printf(string.format("ELD %d", lvl), 0, 2, 1280, "center")
        love.graphics.setFont(self.font)

        -- Threshold readout (top-right, smaller — still informative)
        local thr = {
            {5, "WHISPERS"}, {9, "DISTORT"}, {13, "GHOSTS"}, {15, "RIPPLES"},
            {17, "TESSERACT"}, {20, "CHURGLY"}, {22, "CTHULHU"}, {25, "KILL"},
        }
        for i, tp in ipairs(thr) do
            local reached = lvl >= tp[1]
            love.graphics.setColor(reached and 1 or 0.45, reached and 0.85 or 0.45, 0.4, reached and 0.95 or 0.55)
            love.graphics.print(string.format("%2d %s", tp[1], tp[2]), 1180, 70 + (i - 1) * 13)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function Game:drawKingVisions()
    if not self._kingSourceLines then self:_loadKingSource() end
    local lines = self._kingSourceLines
    local n = #lines
    local t = love.timer.getTime()
    local W, H = 1280, 720

    -- "INFINITE KNOWLEDGE" reveal layer: expose hitboxes, HP, AI state, next
    -- moves, pending spawns, and hidden triggers. Drawn BEFORE the source
    -- code / ghost layers so the hallucinations slightly veil the readout.
    self:_drawKingKnowledge()

    -- Fast deterministic pseudo-random from a seed (keeps global RNG clean)
    local function pr(s)
        local v = math.sin(s * 12.9898 + 78.233) * 43758.5453
        return v - math.floor(v)
    end

    -- Streaming source code — 5 columns scrolling upward at different speeds.
    love.graphics.setFont(self.font)
    local cols = 5
    local colW = W / cols
    local rowH = 18
    for col = 0, cols - 1 do
        local baseX = col * colW + 6
        local scrollSpeed = 1400 + col * 220
        local offset = (t * scrollSpeed) % rowH
        local seedShift = col * 9973
        local chunk = math.floor(t * 1.5)
        for row = -1, math.ceil(H / rowH) + 1 do
            local ly = row * rowH - offset + (H % rowH)
            if ly > -rowH and ly < H + rowH then
                local idx = ((chunk + row * 31 + seedShift) % n) + 1
                local line = lines[idx]
                local a = 0.32 + 0.12 * math.sin(t * 4 + row * 0.4 + col * 1.7)
                love.graphics.setColor(1, 0.88, 0.4, a)
                love.graphics.print(line, baseX, ly)
            end
        end
    end

    -- Flickering sprite-ghosts: crabs, enemies, bullets, eyes, runes.
    -- Time-bucketed so each ghost flashes fast and is replaced.
    local bucketRate = 14
    local bucket = math.floor(t * bucketRate)
    local subT = t * bucketRate - bucket
    local fade = 1 - subT
    local ghostCount = 22
    for i = 1, ghostCount do
        local s = bucket * 1013 + i * 257
        local gx = pr(s) * W
        local gy = pr(s + 1) * H
        local kind = math.floor(pr(s + 2) * 5) + 1
        local alpha = fade * (0.32 + pr(s + 3) * 0.16)
        if kind == 1 then
            -- Crab-like ghost
            love.graphics.setColor(1, 0.55 + pr(s + 4) * 0.3, 0.2, alpha)
            love.graphics.circle("fill", gx, gy, 14)
            love.graphics.setColor(0, 0, 0, alpha * 1.4)
            love.graphics.circle("fill", gx - 5, gy - 4, 2.2)
            love.graphics.circle("fill", gx + 5, gy - 4, 2.2)
            love.graphics.setColor(1, 0.7, 0.3, alpha)
            love.graphics.setLineWidth(2)
            love.graphics.line(gx - 14, gy + 2, gx - 22, gy + 6)
            love.graphics.line(gx + 14, gy + 2, gx + 22, gy + 6)
        elseif kind == 2 then
            -- Bullet streak
            local dir = pr(s + 5) * math.pi * 2
            local dx, dy = math.cos(dir), math.sin(dir)
            love.graphics.setColor(1, 1, 0.5, alpha * 1.5)
            love.graphics.setLineWidth(3)
            love.graphics.line(gx - dx * 14, gy - dy * 14, gx + dx * 14, gy + dy * 14)
            love.graphics.setColor(1, 0.9, 0.4, alpha)
            love.graphics.circle("fill", gx, gy, 3)
        elseif kind == 3 then
            -- Red enemy orb
            local r = 10 + pr(s + 6) * 10
            love.graphics.setColor(0.9, 0.25, 0.35, alpha)
            love.graphics.circle("fill", gx, gy, r)
            love.graphics.setColor(1, 0.9, 0.7, alpha)
            love.graphics.circle("fill", gx, gy, r * 0.4)
        elseif kind == 4 then
            -- Giant eye
            local r = 14 + pr(s + 7) * 6
            love.graphics.setColor(1, 0.92, 0.5, alpha * 0.9)
            love.graphics.ellipse("fill", gx, gy, r * 1.4, r * 0.8)
            love.graphics.setColor(0.1, 0.05, 0.2, alpha * 1.4)
            love.graphics.circle("fill", gx, gy, r * 0.5)
            love.graphics.setColor(0, 0, 0, alpha * 1.4)
            love.graphics.circle("fill", gx, gy, r * 0.22)
        else
            -- Card rune
            love.graphics.setColor(1, 0.85, 0.3, alpha)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", gx - 14, gy - 20, 28, 40)
            love.graphics.line(gx - 8, gy, gx + 8, gy)
            love.graphics.line(gx, gy - 8, gx, gy + 8)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function Game:pickCard(index)
    local c = self.cardChoices[index]
    if not c then return end
    c.apply(self.player)
    table.insert(self.player.cardsTaken, c)
    self:_fireCardAchievement(c.id)
    -- Card pickups: tint the iframe border for a moment. Chrome rim only
    -- (glow), never overlays the play area.
    local r = c.rarity
    if r == "common" then
        Fx.glow("#f2c05a", 0.4, 600)
    elseif r == "uncommon" then
        Fx.glow("#7ad0ff", 0.5, 700)
    elseif r == "rare" then
        Fx.glow("#66aaff", 0.6, 900)
    elseif r == "legendary" then
        Fx.glow("#ffaa33", 0.75, 1200)
    elseif r == "eldritch" then
        Fx.glow("#9944cc", 0.75, 1300)
    elseif r == "cursed" then
        Fx.glow("#cc3377", 0.65, 1000)
        Fx.vignette(0.35, 800)
    end
    Audio:play("select")
    P:text(self.player.x, self.player.y, c.name, Cards.rarityColor(c.rarity), 2)
    if self.isMultiplayer and MP.enabled then
        pcall(MP.announceCard, c)
        -- World-event cards: broadcast so every peer also lights up the
        -- King ending / unlocks Void Sea / gets the Ugnrak Beam ability.
        if c.id == "eld_king" then
            pcall(MP.announceEvent, "king")
        elseif c.id == "eld_ugnrak" then
            pcall(MP.announceEvent, "ugnrak_unlock")
        elseif c.id == "eld_voidsea" then
            pcall(MP.announceEvent, "voidsea_unlock")
        end
    end
    self:beginWave(self.wave + 1)
    self.state = "wave"
end

function Game:skipCard()
    self.player:heal(3)
    self:beginWave(self.wave + 1)
    self.state = "wave"
    Audio:play("select")
end

-- UGNRAK BEAM: fires once, consumes the card. If player has 6+ Reality
-- Shards: beam sweeps outward from the player at aim direction, instakills
-- anything in its line, and annihilates Churgly'nth if He is present.
-- Otherwise: backfire — ripples + fractals maxed for 12s over all menus,
-- player dies.
function Game:fireUgnrakBeam()
    local p = self.player
    p.ugnrakBeam = false -- spent either way
    Achievements.fire("ugnrak_fired")
    -- Multiplayer: broadcast a visual cinematic event so every peer sees
    -- the same crimson beam streak across their own screen (no damage on
    -- their side — informational/feel only).
    if self.isMultiplayer and MP.enabled then
        pcall(MP.announceEvent, "ugnrak_fire", {
            x1 = p.x, y1 = p.y,
            x2 = p.x + math.cos(p.angle or 0) * 1400,
            y2 = p.y + math.sin(p.angle or 0) * 1400,
        })
    end
    -- Lifetime Reality Shards count toward firing in EVERY mode (custom
    -- and normal alike). The bug was that custom runs only checked
    -- self.tempShards which starts at 0 per run, so a player with 6
    -- lifetime shards instantly backfired on the first fire in custom.
    -- Custom mode doesn't decrement persist (custom runs don't progress
    -- shards in either direction), so it's effectively unlimited fires.
    local lifetime = (self.persist and self.persist.realityShards) or 0
    local shards
    if self.isCustom then
        shards = math.max(self.tempShards or 0, lifetime)
    else
        shards = lifetime
    end
    if shards >= 6 then
        -- Ugnrak Beam fires: chrome goes full crimson dread for a beat.
        Fx.shake(0.95, 700)
        Fx.glow("#ff1122", 1.0, 2000)
        Fx.mood("#2a0000", 0.5)
        Fx.pulsate("#ff1122", 56, 0.5)
        Fx.vignette(0.75, 1800)
        if self.isCustom then
            -- Custom is a sandbox — don't touch lifetime shards. Decrement
            -- only the in-run counter for cosmetic correctness.
            self.tempShards = math.max(0, (self.tempShards or 0) - 6)
        else
            self.persist.realityShards = shards - 6
            Save.save(self.persist)
        end
        local eld = p.eldritch
        local hasCinematicTarget = eld and (eld.kingOblit or eld.cthulhu)
        if hasCinematicTarget then
            -- CINEMATIC PATH — beam locks onto Cthulhu, explodes him with
            -- the king explosion, then pivots to Churgly for 6s before
            -- starting the boss fight. Fire-and-forget; the per-frame
            -- cinematic updater manages the beam target.
            self.ugnrakCinematic = {
                phase = "cthulhu",
                timer = 2.2,
                cthulhuExploded = false,
            }
            if eld.kingOblit then eld.kingOblit.phase = "cinematic_freeze" end
            p.invuln = 999
            p.disabled = true
            -- Seed the beam so the first-frame render points at Cthulhu
            local ctx, cty = 640, 360
            if eld.cthulhu then ctx, cty = eld.cthulhu.x, eld.cthulhu.y end
            self.ugnrakBeamFx = {
                x1 = p.x, y1 = p.y, x2 = ctx, y2 = cty,
                life = 1.0, max = 1.0, giant = true, target = "cthulhu",
            }
            P:text(640, 160, "UGNRAK STRIKES", {1, 0.3, 0.3}, 4)
        else
            -- NORMAL PATH — straight beam in aim direction, 0.9s, kills
            -- anything in a 90 px perpendicular corridor.
            local ang = p.angle
            local sx, sy = p.x, p.y
            local ex = sx + math.cos(ang) * 2400
            local ey = sy + math.sin(ang) * 2400
            self.ugnrakBeamFx = {
                x1 = sx, y1 = sy, x2 = ex, y2 = ey,
                life = 0.9, max = 0.9, angle = ang, giant = true,
            }
            local dxN, dyN = math.cos(ang), math.sin(ang)
            for _, e in ipairs(self.enemies) do
                local ex2, ey2 = e.x - sx, e.y - sy
                local proj = ex2 * dxN + ey2 * dyN
                if proj > 0 then
                    local perp = math.abs(-dyN * ex2 + dxN * ey2)
                    if perp < 90 + (e.r or 0) then
                        e:damage(99999, p, self)
                    end
                end
            end
        end
        Audio:play("boss")
        Audio:play("cthulhu")
    else
        -- BACKFIRE — chaos overlay for 12s, player dies
        self.backfireHold = 12
        self.kingFractalHold = 12
        if p.eldritch then p.eldritch.kingFractal = 1.0 end
        p.invuln = 0
        -- Backfire = death. Dramatic chrome shatter (it's the run ending).
        Fx.shatter(1.0, 1200)
        Fx.mood("#220000", 0.6)
        Fx.vignette(0.85, 1800)
        Fx.pulsate("#ff1122", 48, 0.55)
        Fx.glow("#ff1122", 1.0, 2000)
        p:takeDamage(99999, nil, true)
        P:text(640, 200, "INSUFFICIENT SHARDS", {1, 0.2, 0.2}, 4)
        P:text(640, 260, "UGNRAK CLAIMS YOU", {1, 0.3, 0.2}, 4)
        P:spawn(p.x, p.y, 140, {1, 0.3, 0.2}, 700, 1.2, 10)
        Audio:play("cthulhu")
        Audio:play("glitch")
    end
end

function Game:keypressed(key)
    -- Global debug visualiser hotkey: hold Shift + Space and tap V to enter
    -- a sprite/animation preview mode. Escape to leave.
    if key == "v" and love.keyboard.isDown("space")
        and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift"))
        and self.state ~= "debugvis" then
        self._dvPrevState = self.state
        self.state = "debugvis"
        self.debugVisIndex = self.debugVisIndex or 1
        self.debugVisBg = self.debugVisBg or 1
        return
    end
    -- Shift+Space+S — sound debug menu
    if key == "s" and love.keyboard.isDown("space")
        and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift"))
        and self.state ~= "debugsound" then
        self._dsPrevState = self.state
        self.state = "debugsound"
        self.debugSoundIndex = self.debugSoundIndex or 1
        return
    end
    if self.state == "debugsound" then
        require("src.debugsound").keypressed(self, key)
        return
    end
    -- UGNRAK BEAM: press B in-wave to fire the giant crimson beam. Consumes
    -- 6 Reality Shards. If the player doesn't have them, it backfires and
    -- annihilates them in a storm of ripples + fractals.
    if key == "b" and self.state == "wave" and self.player and self.player.ugnrakBeam then
        self:fireUgnrakBeam()
        return
    end
    if self.state == "debugvis" then
        if key == "escape" then
            self.state = self._dvPrevState or "menu"
            return
        elseif key == "up" then
            self.debugVisIndex = math.max(1, (self.debugVisIndex or 1) - 1)
        elseif key == "down" then
            local items = require("src.debugvis").items
            self.debugVisIndex = math.min(#items, (self.debugVisIndex or 1) + 1)
        elseif key == "left" then
            self.debugVisBg = ((self.debugVisBg or 1) - 2) % 6 + 1
        elseif key == "right" then
            self.debugVisBg = (self.debugVisBg or 1) % 6 + 1
        elseif key == "r" then
            -- Reset animation timer for the selected item
            self._dvStartT = love.timer.getTime()
        elseif key == "i" then
            self.debugVisHideUI = not self.debugVisHideUI
        end
        return
    end
    if self.state == "menu" then
        if key == "return" or key == "kpenter" then
            self:startRun()
        elseif key == "c" then
            self:openCustom()
        elseif key == "o" then
            self:openOptions()
        elseif key == "k" then
            self:openCustomise()
        elseif key == "m" then
            self:openMultiplayer()
        elseif key == "left" then
            self:cycleDifficulty(-1)
        elseif key == "right" then
            self:cycleDifficulty(1)
        end
    elseif self.state == "mp_menu" then
        UI:mpMenuKey(self, key)
    elseif self.state == "mp_create" then
        UI:mpCreateKey(self, key)
    elseif self.state == "mp_lobby" then
        UI:mpLobbyKey(self, key)
    elseif self.state == "custom" then
        if key == "escape" then self.state = "menu" end
        if key == "return" or key == "kpenter" then self:startCustom() end
    elseif self.state == "options" then
        if key == "escape" or key == "return" or key == "kpenter" then
            Save.save(self.persist)
            self.state = "menu"
        end
    elseif self.state == "slots" then
        if key == "escape" or key == "return" or key == "kpenter" then
            Save.save(self.persist)
            self.state = "options"
        end
    elseif self.state == "resetdata" then
        UI:resetDataKey(self, key)
    elseif self.state == "resetshards" then
        UI:resetShardsKey(self, key)
    elseif self.state == "playlist" then
        if key == "escape" or key == "return" or key == "kpenter" then
            Save.save(self.persist)
            if Audio.music and Audio.music:isPlaying() then Audio.music:stop() end
            self.state = "options"
        end
    elseif self.state == "aesthetics" then
        if key == "escape" or key == "return" or key == "kpenter" then
            Save.save(self.persist)
            self.state = "options"
        end
    elseif self.state == "customise" then
        if key == "escape" or key == "return" or key == "kpenter" then
            Save.save(self.persist)
            self.state = "menu"
        end
    elseif self.state == "gameover" or self.state == "victory" then
        if (self.endTime or 0) < 1.0 then return end
        if key == "return" or key == "kpenter" then
            self:startRun(self.customConfig)
        elseif key == "m" then
            if self.isMultiplayer then MP.endRoom(); self.isMultiplayer = false end
            self.state = "menu"
            Audio:stopMusic()
            Fx.clearAll()
        elseif key == "q" then
            love.event.quit()
        end
    elseif self.state == "paused" then
        if key == "return" or key == "kpenter" or key == "escape" then
            self.state = self._resumeTo or "wave"
            self._resumeTo = nil
        elseif key == "m" then
            self:cashOutInfinite()
            -- Pause→menu: peers may still be playing, so just leave the
            -- room. Don't endRoom (that kills it for everyone). Auto-end
            -- handles the case where I was the last active member.
            if self.isMultiplayer then MP.leave(); self.isMultiplayer = false end
            self.state = "menu"
            Audio:stopMusic()
            Fx.clearAll()
        elseif key == "n" then
            -- Abandon without banking (infinite mode only uses this)
            if self.isMultiplayer then MP.leave(); self.isMultiplayer = false end
            self.state = "menu"
            Audio:stopMusic()
            Fx.clearAll()
        elseif key == "q" then
            love.event.quit()
        end
    elseif self.state == "cards" then
        if (self.cardArmTime or 0) > 0 then return end
        local idx = tonumber(key)
        if idx and self.cardChoices[idx] then
            self:pickCard(idx)
        elseif key == "f" then
            self:skipCard()
        end
    elseif self.state == "wave" then
        -- Multiplayer chat overlay intercepts everything while it's open
        local chat = self.chat
        if self.isMultiplayer and chat and chat.open then
            if key == "return" or key == "kpenter" then
                local msg = (chat.text or ""):match("^%s*(.-)%s*$")
                if msg and #msg > 0 then MP.sendChat(msg) end
                chat.open = false; chat.text = ""
            elseif key == "escape" then
                chat.open = false; chat.text = ""
            elseif key == "backspace" then
                local s = chat.text or ""
                if #s > 0 then chat.text = s:sub(1, #s - 1) end
            elseif key == "space" then
                -- love.js sometimes drops textinput for space, so accept
                -- it from keypressed too. Main.lua's textinput handler
                -- skips space to prevent doubling on desktop builds.
                local s = chat.text or ""
                if #s < 120 then chat.text = s .. " " end
            end
            return
        end
        -- Open the chat overlay (T or /). Multiplayer-only — desktop solo
        -- doesn't surface chat at all.
        if self.isMultiplayer and (key == "t" or key == "/") then
            self.chat = self.chat or {open = false, text = ""}
            self.chat.open = true
            self.chat.text = ""
            self.chat._justOpened = true
            return
        end
        if key == "space" then
            self.player:dash()
        elseif key == "q" then
            self.player:bomb(self)
        end
    end
end

-- Helper: if the click landed on a scroll thumb, begin dragging and return true.
-- Uses RELATIVE drag: the thumb stays anchored under the cursor instead of
-- snapping to the top of the track.
function Game:tryScrollbarPress(x, y, bar, targetKey)
    if not bar then return false end
    local onThumb = x >= bar.trackX - 4 and x <= bar.trackX + bar.trackW + 4
        and y >= bar.thumbY - 4 and y <= bar.thumbY + bar.thumbH + 4
    local onTrack = x >= bar.trackX - 4 and x <= bar.trackX + bar.trackW + 4
        and y >= bar.trackY and y <= bar.trackY + bar.trackH
    if onThumb or onTrack then
        -- Clicking on the empty track? Jump the thumb CENTER to the click first,
        -- then the relative drag continues from there.
        if not onThumb then
            local frac = (y - bar.trackY - bar.thumbH / 2) / math.max(1, bar.trackH - bar.thumbH)
            frac = math.max(0, math.min(1, frac))
            self[targetKey .. "Target"] = frac * bar.maxScroll
            self[targetKey] = self[targetKey .. "Target"]
        end
        self.scrollDrag = {
            key         = targetKey .. "Target",
            startMouseY = y,
            startScroll = self[targetKey .. "Target"] or 0,
            trackH      = bar.trackH,
            thumbH      = bar.thumbH,
            maxScroll   = bar.maxScroll,
        }
        return true
    end
    return false
end

function Game:mousereleased(x, y, button)
    if button == 1 and self.scrollDrag then self.scrollDrag = nil end
end

function Game:mousepressed(x, y, button)
    -- Scrollbar drag initiation (independent of state)
    if button == 1 then
        if self.state == "customise" and self:tryScrollbarPress(x, y, self.customiseScrollbar, "customiseScroll") then return end
        if self.state == "custom"    and self:tryScrollbarPress(x, y, self.customScrollbar, "customScroll") then return end
        if self.state == "playlist"  and self:tryScrollbarPress(x, y, self.playlistScrollbar, "playlistScroll") then return end
        if self.state == "aesthetics" and self:tryScrollbarPress(x, y, self.aestheticsScrollbar, "aestheticsScroll") then return end
    end

    if self.state == "cards" and button == 1 then
        -- Arm delay: ignore clicks for first 0.7s so mid-combat clicks don't leak
        if (self.cardArmTime or 0) > 0 then return end
        for i, c in ipairs(self.cardChoices) do
            local b = c._bounds
            if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
                self:pickCard(i)
                return
            end
        end
        -- background clicks do nothing
    elseif self.state == "menu" and button == 1 then
        -- Difficulty arrows
        local db = self.diffBounds
        if db then
            local l = db.left
            if x >= l[1] and x <= l[1] + l[3] and y >= l[2] and y <= l[2] + l[4] then
                self:cycleDifficulty(-1); return
            end
            local r = db.right
            if x >= r[1] and x <= r[1] + r[3] and y >= r[2] and y <= r[2] + r[4] then
                self:cycleDifficulty(1); return
            end
        end
        -- Infinite mode toggle
        local ib = self.infiniteBounds
        if ib and x >= ib[1] and x <= ib[1] + ib[3] and y >= ib[2] and y <= ib[2] + ib[4] then
            self.persist.infiniteMode = (self.persist.infiniteMode == 1) and 0 or 1
            Save.save(self.persist)
            Audio:play("select")
            return
        end
        -- Check menu buttons
        local mb = self.menuButtons or {}
        for _, btn in ipairs(mb) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if     btn.action == "start"       then self:startRun()
                elseif btn.action == "custom"      then self:openCustom()
                elseif btn.action == "options"     then self:openOptions()
                elseif btn.action == "customise"   then self:openCustomise()
                elseif btn.action == "multiplayer" then self:openMultiplayer()
                elseif btn.action == "quit"        then love.event.quit() end
                return
            end
        end
    elseif self.state == "options" and button == 1 then
        UI:optionsClick(self, x, y)
    elseif self.state == "slots" and button == 1 then
        UI:slotsClick(self, x, y)
    elseif self.state == "resetdata" and button == 1 then
        UI:resetDataClick(self, x, y)
    elseif self.state == "resetshards" and button == 1 then
        UI:resetShardsClick(self, x, y)
    elseif self.state == "playlist" and button == 1 then
        UI:playlistClick(self, x, y)
    elseif self.state == "aesthetics" and button == 1 then
        UI:aestheticsClick(self, x, y)
    elseif self.state == "customise" and button == 1 then
        UI:customiseClick(self, x, y)
    elseif self.state == "mp_menu" and button == 1 then
        UI:mpMenuClick(self, x, y)
    elseif self.state == "mp_create" and button == 1 then
        UI:mpCreateClick(self, x, y)
    elseif self.state == "mp_lobby" and button == 1 then
        UI:mpLobbyClick(self, x, y)
    elseif self.state == "paused" and button == 1 then
        for _, btn in ipairs(self.pauseButtons or {}) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if btn.action == "resume" then
                    self.state = self._resumeTo or "wave"
                    self._resumeTo = nil
                elseif btn.action == "menu" then
                    self:cashOutInfinite()
                    -- Pause→menu: just leave; peers may still be playing.
                    if self.isMultiplayer then MP.leave(); self.isMultiplayer = false end
                    self.state = "menu"
                    Audio:stopMusic()
                    Fx.clearAll()
                elseif btn.action == "menu_discard" then
                    -- Abandon the infinite run without recording progress
                    if self.isMultiplayer then MP.leave(); self.isMultiplayer = false end
                    self.state = "menu"
                    Audio:stopMusic()
                    Fx.clearAll()
                elseif btn.action == "quit" then
                    love.event.quit()
                end
                return
            end
        end
    elseif self.state == "custom" and button == 1 then
        UI:customClick(self, x, y)
    elseif (self.state == "gameover" or self.state == "victory") and button == 1 then
        if (self.endTime or 0) < 1.0 then return end
        for _, btn in ipairs(self.endButtons or {}) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if btn.action == "again" then
                    self:startRun(self.customConfig)
                elseif btn.action == "menu" then
                    if self.isMultiplayer then MP.endRoom(); self.isMultiplayer = false end
                    self.state = "menu"
                    Audio:stopMusic()
                    Fx.clearAll()
                elseif btn.action == "quit" then
                    love.event.quit()
                end
                return
            end
        end
    end
end

function Game:openOptions()
    self.state = "options"
end

function Game:openSlots()
    self.state = "slots"
end

-- Switch the active save slot. Saves current progress, activates new slot,
-- reloads that slot's data, re-applies volumes/theme.
function Game:switchSlot(slot)
    -- Persist the current slot first so no progress is lost
    Save.save(self.persist)
    Save.setActiveSlot(slot)
    self.persist = Save.load()
    Audio.masterVol = self.persist.masterVol or 1.0
    Audio.musicVol  = self.persist.musicVol or 1.0
    Audio.sfxVol    = self.persist.sfxVol or 0.5
    Audio:applyVolumes()
    Audio:setTheme(self.persist.theme or Playlist.defaultId())
    Audio:play("select")
end

function Game:openResetData()
    self.resetTyped = ""
    self.resetTypedAt = nil
    self.state = "resetdata"
end

function Game:openResetShards()
    self.resetShardsTyped = ""
    self.resetShardsTypedAt = nil
    self.state = "resetshards"
end

function Game:performResetShards()
    self.persist.realityShards = 0
    Save.save(self.persist)
    Audio:play("select")
    Audio:play("whisper")
    self.resetShardsTyped = ""
    self.resetShardsTypedAt = nil
    self.state = "options"
end

function Game:performResetData()
    -- Wipe persistent save by replacing it with defaults
    self.persist = {
        globalRep = 50, globalRepMax = 50, winStreak = 0, bestStreak = 0,
        totalWins = 0, totalRuns = 0, totalKills = 0, eldritchMax = 0,
        masterVol = 1.0, musicVol = 1.0, sfxVol = 0.5,
    }
    Save.save(self.persist)
    -- Apply reset volumes and theme
    Audio.masterVol = 1.0; Audio.musicVol = 1.0; Audio.sfxVol = 0.5
    Audio:applyVolumes()
    Audio:setTheme(Playlist.defaultId())
    self.resetTyped = ""
    self.resetTypedAt = nil
    self.state = "menu"
end

function Game:cycleDifficulty(dir)
    local cur = self.persist.difficulty or Difficulty.defaultId()
    self.persist.difficulty = Difficulty.cycle(cur, dir)
    Save.save(self.persist)
    Audio:play("select")
end

function Game:openCustomise()
    self.state = "customise"
    self.customiseSlot = "body"
end

Game.customDefaults = {
    finalWave = 20,
    startWave = 1,
    startHp = 100,
    startingReputation = 30,
    startingCards = 0,
    enemyHpMult = 1.0,
    enemyDmgMult = 1.0,
    spawnCountMult = 1.0,
    playerDmgMult = 1.0,
    playerFireRateMult = 1.0,
    playerSpeedMult = 1.0,
    playerBulletSpeedMult = 1.0,
    scoreMult = 1.0,
    dashCooldown = 2.5,
    startEldritch = 0,
    disableEldritch = 0,
}

function Game:openMultiplayer()
    self.state = "mp_menu"
    self.mpJoinCode = self.mpJoinCode or ""
    pcall(MP.detect)
    pcall(MP.requestList)
    pcall(MP.publishProfile, self.persist)
end

function Game:openMpCreate()
    self.state = "mp_create"
    self.mpDraft = self.mpDraft or {
        name = "", mode = "last_stand", capacity = 4,
        difficulty = self.persist.difficulty or Difficulty.defaultId(),
        pvp = false, finalWave = 20,
    }
end

-- Each MP client runs its own simulation, but we share the lobby's mode +
-- difficulty + final-wave so everyone is fighting the same shape of run.
-- Cards roll from a per-player seed (lobby × wave × userId) so every crab
-- gets their own random hand.
function Game:startMultiplayerRun()
    self.customConfig = nil
    self.difficultyApplied = Difficulty.get((MP.lobby and MP.lobby.difficulty) or "normal")
    self.haunted = false
    self.shrimpTimer = 0
    self.mpRun = true
    self:resetGame()
    Fx.clearAll()
    -- Tag the run so card-pick + death handling know we're in MP
    self.isMultiplayer = true
    self.mpMode = (MP.lobby and MP.lobby.mode) or "last_stand"
    self.mpPvp = (MP.lobby and MP.lobby.pvp) or false
    -- True endless: lobby's finalWave wins over persist.infiniteMode. 0 means
    -- the run continues past OpenClaw exactly the same way the solo Infinite
    -- toggle does — same logic, same cash-out path.
    self.finalWave = (MP.lobby and MP.lobby.finalWave) or 20
    MP.beginSession()
    self.state = "wave"
    self:beginWave((self.wave or 0) + 1)
    Audio:playMusic("normal")
    Achievements.fire("mp_first_run")
end

function Game:openCustom()
    self.customDraft = {}
    for k, v in pairs(Game.customDefaults) do self.customDraft[k] = v end
    self.customScroll = 0
    self.state = "custom"
end

function Game:resetCustomAll()
    for k, v in pairs(Game.customDefaults) do self.customDraft[k] = v end
end

function Game:resetCustomKey(k)
    self.customDraft[k] = Game.customDefaults[k]
end

function Game:startCustom()
    local d = self.customDraft
    self:startRun({
        finalWave = d.finalWave,
        startWave = d.startWave,
        startHp = d.startHp,
        startingReputation = d.startingReputation,
        startingCards = d.startingCards,
        enemyHpMult = d.enemyHpMult,
        enemyDmgMult = d.enemyDmgMult,
        spawnCountMult = d.spawnCountMult,
        playerDmgMult = d.playerDmgMult,
        playerFireRateMult = d.playerFireRateMult,
        playerSpeedMult = d.playerSpeedMult,
        playerBulletSpeedMult = d.playerBulletSpeedMult,
        scoreMult = d.scoreMult,
        dashCooldown = d.dashCooldown,
        startEldritch = d.startEldritch,
        disableEldritch = (d.disableEldritch == 1),
    })
end

return Game
