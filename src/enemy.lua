local Bullet = require("src.bullet")
local Audio = require("src.audio")
local P = require("src.particles")

local Enemy = {}
Enemy.__index = Enemy

-- Enemy type definitions: tech companies
local types = {
    chatgpt = {
        name = "ChatGPT", color = {0.1, 0.8, 0.55}, r = 20, hp = 52, speed = 85,
        dmg = 10, fireRate = 0, score = 10, shape = "hex",
    },
    gemini = {
        name = "Gemini", color = {0.3, 0.5, 1.0}, r = 18, hp = 38, speed = 115,
        dmg = 9, fireRate = 0, score = 12, shape = "diamond",
    },
    bing = {
        name = "Bing", color = {0.1, 0.7, 0.85}, r = 22, hp = 73, speed = 65,
        dmg = 12, fireRate = 1.2, score = 15, shape = "circle", bulletColor = {0.3,0.9,1},
    },
    deepseek = {
        name = "DeepSeek", color = {0.1, 0.3, 0.7}, r = 26, hp = 96, speed = 90,
        dmg = 15, fireRate = 0.9, score = 20, shape = "whale", bulletColor = {0.4,0.5,1},
    },
    copilot = {
        name = "Copilot", color = {0.3, 0.4, 0.8}, r = 20, hp = 63, speed = 100,
        dmg = 11, fireRate = 1.1, score = 14, shape = "circle", bulletColor = {0.5,0.6,1},
    },
    windows = {
        name = "Windows", color = {0.0, 0.5, 0.9}, r = 28, hp = 131, speed = 55,
        dmg = 16, fireRate = 0.6, score = 25, shape = "windows",
    },
    meta = {
        name = "Meta AI", color = {0.3, 0.3, 1.0}, r = 24, hp = 84, speed = 85,
        dmg = 13, fireRate = 1.0, score = 18, shape = "infinity", bulletColor = {0.5,0.5,1},
    },
    grok = {
        name = "Grok", color = {0.15, 0.15, 0.2}, r = 22, hp = 73, speed = 120,
        dmg = 13, fireRate = 1.5, score = 16, shape = "x", bulletColor = {0.8,0.2,0.2},
    },
    perplexity = {
        name = "Perplexity", color = {0.1, 0.6, 0.6}, r = 20, hp = 59, speed = 110,
        dmg = 10, fireRate = 1.2, score = 14, shape = "circle", bulletColor = {0.3,0.8,0.9},
    },
    llama = {
        name = "Llama", color = {0.85, 0.6, 0.3}, r = 22, hp = 66, speed = 75,
        dmg = 11, fireRate = 0, score = 13, shape = "circle",
    },
    -- Mid/late game variety
    drone = {
        name = "Drone", color = {0.9, 0.6, 0.2}, r = 16, hp = 49, speed = 160,
        dmg = 7, fireRate = 0.9, score = 20, shape = "circle", bulletColor = {1, 0.7, 0.3},
        ai = "circler",
    },
    sniper = {
        name = "Sniper", color = {0.8, 0.2, 0.5}, r = 22, hp = 84, speed = 40,
        dmg = 34, fireRate = 0.5, score = 30, shape = "diamond", bulletColor = {1, 0.3, 0.9},
        ai = "sniper",
    },
    teleporter = {
        name = "Blink", color = {0.5, 0.3, 1.0}, r = 20, hp = 96, speed = 0,
        dmg = 12, fireRate = 0, score = 28, shape = "circle", bulletColor = {0.7, 0.4, 1},
        ai = "blink",
    },
    mine = {
        name = "Mine", color = {0.95, 0.85, 0.2}, r = 14, hp = 35, speed = 0,
        dmg = 40, fireRate = 0, score = 15, shape = "hex",
        ai = "mine",
    },
    drifter = {
        name = "Drift Debris", color = {0.4, 0.5, 0.55}, r = 24, hp = 122, speed = 80,
        dmg = 16, fireRate = 0, score = 12, shape = "junk",
        ai = "drift",
    },
    shrimp_spirit = {
        name = "Shrimp Spirit", color = {1.0, 0.65, 0.75}, r = 18, hp = 63, speed = 130,
        dmg = 15, fireRate = 0, score = 25, shape = "shrimp",
        ai = "weaver", ghostly = true,
    },
    swarm = {
        name = "Swarmlet", color = {0.3, 1.0, 0.6}, r = 10, hp = 21, speed = 180,
        dmg = 6, fireRate = 0, score = 5, shape = "circle",
        ai = "flanker",
    },

    -- Boss
    openclaw = {
        name = "OpenClaw", color = {0.9, 0.2, 0.2}, r = 90, hp = 21000, speed = 120,
        dmg = 56, fireRate = 3.0, score = 2500, shape = "lobster", boss = true,
    },
}

function Enemy.new(typeName, x, y, scale)
    scale = scale or 1
    local t = types[typeName]
    if not t then error("Unknown enemy: "..tostring(typeName)) end
    local self = setmetatable({}, Enemy)
    self.typeName = typeName
    self.type = t
    self.name = t.name
    self.color = t.color
    self.x, self.y = x, y
    self.r = t.r
    self.hp = t.hp * scale
    self.maxHp = self.hp
    self.speed = t.speed
    self.dmg = t.dmg
    self.fireRate = t.fireRate
    self.shootTimer = math.random() * 2
    self.score = t.score * scale
    self.shape = t.shape
    self.bulletColor = t.bulletColor
    self.dead = false
    self.freezeTime = 0
    self.burnTime = 0
    self.burnDmg = 0
    self.flash = 0
    self.scale = scale
    self.isBoss = t.boss or false
    self.bossPhase = 1
    self.bossTimer = 0
    self.spawnTimer = 0
    self.anim = math.random() * 100
    -- Drift debris is ambient — it doesn't block wave completion and can be ignored.
    self.optional = (typeName == "drifter")
    return self
end

function Enemy:damage(amt, source, game, crit)
    self.hp = self.hp - amt
    self.flash = 0.12
    Audio:play("enemyHit")
    local col = crit and {1,0.9,0.2} or {1,0.4,0.4}
    P:text(self.x + math.random(-8,8), self.y - self.r - 4, math.floor(amt), col, 0.6)
    P:spawn(self.x, self.y, 4, self.color, 120, 0.3, 2)
    if self.hp <= 0 and not self.dead then
        self.dead = true
        Audio:play("kill")
        P:spawn(self.x, self.y, 20, self.color, 280, 0.6, 4)
        if source and source.stats and source.stats.killHeal > 0 then
            source:heal(source.stats.killHeal)
        end
        if game then
            game:onKill(self, source)
        end
    end
end

function Enemy:update(dt, game)
    if self.freezeTime > 0 then
        self.freezeTime = self.freezeTime - dt
        dt = dt * 0.3
    end
    if self.burnTime > 0 then
        self.burnTime = self.burnTime - dt
        self.hp = self.hp - self.burnDmg * dt
        -- Fire-spread: burn only jumps to enemies that are physically
        -- TOUCHING this one (overlapping hitboxes). Throttled so flames
        -- don't erupt every single frame.
        self.burnSpreadCD = (self.burnSpreadCD or 0) - dt
        if self.burnSpreadCD <= 0 and game and game.enemies and math.random() < 0.5 then
            self.burnSpreadCD = 0.15 + math.random() * 0.15
            for _, other in ipairs(game.enemies) do
                if other ~= self and not other.dead and (other.burnTime or 0) <= 0 then
                    local odx = other.x - self.x
                    local ody = other.y - self.y
                    -- Touching = overlap (sum of radii, with tiny tolerance
                    -- since collideR is smaller than visual r).
                    local touchR = (self.r or 16) + (other.r or 16) + 2
                    if odx * odx + ody * ody <= touchR * touchR then
                        other.burnTime = math.max(1.5, self.burnTime * 0.7)
                        other.burnDmg = self.burnDmg
                        -- Fire arc between the two for visual feedback
                        for s = 1, 6 do
                            local fx = self.x + odx * (s / 6) + math.random(-3, 3)
                            local fy = self.y + ody * (s / 6) + math.random(-3, 3)
                            P:spawn(fx, fy, 1, {1, 0.6, 0.15}, 60, 0.35, 3)
                        end
                        break
                    end
                end
            end
        end
        -- Much thicker fire plume — noticeable spray of flame particles
        if math.random() < 0.85 then
            local ox = math.random(-self.r, self.r) * 0.7
            local oy = math.random(-self.r, self.r) * 0.7
            local col = (math.random() < 0.5) and {1, 0.9, 0.3} or {1, 0.4, 0.1}
            P:spawn(self.x + ox, self.y + oy, 2, col, 60, 0.45, 3)
        end
        if math.random() < 0.25 then
            -- Rising ember
            P:spawn(self.x + math.random(-self.r, self.r), self.y - self.r,
                1, {1, 0.6, 0.15}, 80, 0.7, 3)
        end
        if self.hp <= 0 and not self.dead then
            self.dead = true
            if game then game:onKill(self, nil) end
        end
    end
    self.flash = math.max(0, self.flash - dt)
    self.anim = self.anim + dt

    local p = game.player
    local dx, dy = p.x - self.x, p.y - self.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist > 0 then dx, dy = dx/dist, dy/dist end

    if self.isBoss then
        self:updateBoss(dt, game, dx, dy, dist)
    else
        local ai = self.type.ai
        if ai == "circler" then
            -- Drone: circles player, maintains radius, bursts 3 shots
            local target = 220
            local pull = (dist - target) / 200
            local vx = dx * self.speed * pull + dy * self.speed * 1.0
            local vy = dy * self.speed * pull - dx * self.speed * 1.0
            self.x = self.x + vx * dt
            self.y = self.y + vy * dt
            self.shootTimer = self.shootTimer - dt
            if self.shootTimer <= 0 and dist < 600 then
                for i = -1, 1 do
                    local a = math.atan2(dy, dx) + i * 0.08
                    local b = Bullet.new(self.x, self.y, math.cos(a) * 300, math.sin(a) * 300, self.dmg, false)
                    b.color = self.bulletColor; b.size = 5
                    table.insert(game.enemyBullets, b)
                end
                self.shootTimer = 1 / self.fireRate
            end
        elseif ai == "sniper" then
            -- Sniper: stays still, charges, fires a heavy projectile
            self.chargeT = (self.chargeT or 0) + dt
            if self.chargeT > 2.0 then
                self.chargeT = 0
                local b = Bullet.new(self.x, self.y, dx * 520, dy * 520, self.dmg, false)
                b.color = self.bulletColor; b.size = 10
                table.insert(game.enemyBullets, b)
                P:spawn(self.x, self.y, 12, self.bulletColor, 200, 0.4, 3)
            end
            -- Rotate slightly toward player
            if dist > 320 then
                self.x = self.x + dx * self.speed * dt * 0.4
                self.y = self.y + dy * self.speed * dt * 0.4
            end
        elseif ai == "blink" then
            -- Teleporter: periodically blinks near player and fires burst
            self.blinkT = (self.blinkT or 1.2) - dt
            if self.blinkT <= 0 then
                local a = math.random() * math.pi * 2
                local rr = 180 + math.random() * 120
                self.x = game.player.x + math.cos(a) * rr
                self.y = game.player.y + math.sin(a) * rr
                self.x = math.max(40, math.min(1240, self.x))
                self.y = math.max(80, math.min(680, self.y))
                P:spawn(self.x, self.y, 16, self.color, 180, 0.4, 3)
                -- On Nightmare/Apocalypse the Blink's bullets get softened
                -- (fewer, wider spread, slower) so they're not one-shotting
                -- on top of the difficulty multiplier. Flag is set in
                -- Game:beginWave when difficulty is nightmare+.
                if self.softBlinkBullets then
                    for i = -1, 1 do
                        local ang = math.atan2(dy, dx) + i * 0.45
                        local b = Bullet.new(self.x, self.y,
                            math.cos(ang) * 180, math.sin(ang) * 180, self.dmg, false)
                        b.color = self.bulletColor; b.size = 6
                        table.insert(game.enemyBullets, b)
                    end
                else
                    for i = -2, 2 do
                        local ang = math.atan2(dy, dx) + i * 0.18
                        local b = Bullet.new(self.x, self.y,
                            math.cos(ang) * 280, math.sin(ang) * 280, self.dmg, false)
                        b.color = self.bulletColor; b.size = 6
                        table.insert(game.enemyBullets, b)
                    end
                end
                self.blinkT = 1.6 + math.random() * 0.6
            end
        elseif ai == "mine" then
            -- Mine: stationary; explodes in large AoE at close range
            if dist < 60 then
                self.exploding = (self.exploding or 0.5) - dt
                if self.exploding <= 0 and not self.dead then
                    table.insert(game.shockwaves or {}, {x = self.x, y = self.y, r = 0, max = 120, life = 0.4, color = {1, 0.7, 0.1}})
                    P:spawn(self.x, self.y, 30, {1, 0.6, 0.1}, 320, 0.5, 5)
                    local d2 = (game.player.x - self.x)^2 + (game.player.y - self.y)^2
                    if d2 < 120 * 120 then game.player:takeDamage(self.dmg, self) end
                    self.hp = 0; self.dead = true
                    if game then game:onKill(self, nil) end
                    Audio:play("explode")
                end
            end
        elseif ai == "drift" then
            -- Drifting debris: uses an assigned drift velocity, bounces off walls
            if not self.vx then
                local a = math.random() * math.pi * 2
                self.vx = math.cos(a) * self.speed
                self.vy = math.sin(a) * self.speed
                self.rot = math.random() * math.pi * 2
            end
            self.x = self.x + self.vx * dt
            self.y = self.y + self.vy * dt
            self.rot = self.rot + dt * 1.2
            if self.x < 30 or self.x > 1250 then self.vx = -self.vx end
            if self.y < 70 or self.y > 690 then self.vy = -self.vy end
        elseif ai == "weaver" then
            -- Shrimp spirit: weaves approach, ghostly. Grows faster & more damaging with age.
            self.weaveT = (self.weaveT or 0) + dt
            self.ageT = (self.ageT or 0) + dt
            local ageBoost = 1 + math.min(2, self.ageT * 0.12) -- up to 3x after ~16s alive
            local weave = math.sin(self.weaveT * 5) * 0.8
            local vx = dx * self.speed * ageBoost + dy * self.speed * weave
            local vy = dy * self.speed * ageBoost - dx * self.speed * weave
            self.x = self.x + vx * dt
            self.y = self.y + vy * dt
            -- Ramp damage over time
            self._baseDmg = self._baseDmg or self.dmg
            self.dmg = self._baseDmg * ageBoost
        elseif ai == "flanker" then
            -- Swarmlet: approaches player from a flank angle
            if not self.flankSide then self.flankSide = math.random() < 0.5 and 1 or -1 end
            local tx = game.player.x + (-dy) * 180 * self.flankSide
            local ty = game.player.y + dx * 180 * self.flankSide
            local fx, fy = tx - self.x, ty - self.y
            local l = math.sqrt(fx*fx + fy*fy)
            if l > 0 then fx, fy = fx/l, fy/l end
            self.x = self.x + fx * self.speed * dt
            self.y = self.y + fy * self.speed * dt
        elseif self.fireRate > 0 then
            -- Default shooter AI: keep distance, strafe
            if dist < 250 then
                self.x = self.x - dx * self.speed * dt * 0.7
                self.y = self.y - dy * self.speed * dt * 0.7
            elseif dist > 400 then
                self.x = self.x + dx * self.speed * dt
                self.y = self.y + dy * self.speed * dt
            else
                self.x = self.x + dy * self.speed * dt * 0.6
                self.y = self.y - dx * self.speed * dt * 0.6
            end
            self.shootTimer = self.shootTimer - dt
            if self.shootTimer <= 0 and dist < 600 then
                self:shoot(game, dx, dy)
                self.shootTimer = 1 / self.fireRate
            end
        else
            -- Default chaser
            self.x = self.x + dx * self.speed * dt
            self.y = self.y + dy * self.speed * dt
        end
    end

    -- Collide with player: discrete hit gated by invulnerability (real damage, not DoT dust)
    local pdx, pdy = p.x - self.x, p.y - self.y
    local pd2 = pdx*pdx + pdy*pdy
    local combined = (self.r + p.r)
    if pd2 < combined * combined then
        if p.invuln <= 0 then
            -- Deal a full contact-hit scaled by enemy strength; bosses hit extra hard
            local hit = self.dmg * (self.isBoss and 1.2 or 0.9)
            p:takeDamage(hit, self)
        end
        -- Push apart
        local pd = math.sqrt(pd2)
        if pd > 0 then
            self.x = self.x - (pdx / pd) * 80 * dt
            self.y = self.y - (pdy / pd) * 80 * dt
        end
        -- Thorns still applies per-frame while touching
        if p.stats.thorns > 0 then
            self:damage(p.stats.thorns * dt, p, game)
        end
    end
end

function Enemy:shoot(game, dx, dy)
    local speed = 280
    local b = Bullet.new(self.x + dx * self.r, self.y + dy * self.r,
        dx * speed, dy * speed, self.dmg, false)
    b.color = self.bulletColor or self.color
    b.size = 6
    table.insert(game.enemyBullets, b)
end

function Enemy:updateBoss(dt, game, dx, dy, dist)
    self.bossTimer = self.bossTimer + dt
    local hpFrac = self.hp / self.maxHp
    if hpFrac < 0.75 then self.bossPhase = math.max(self.bossPhase, 2) end
    if hpFrac < 0.5 then self.bossPhase = math.max(self.bossPhase, 3) end
    if hpFrac < 0.25 then self.bossPhase = math.max(self.bossPhase, 4) end
    if hpFrac < 0.1 then self.bossPhase = 5 end -- enrage

    -- Phases get faster/harder
    local aggression = 1 + (self.bossPhase - 1) * 0.35

    -- Charging dash
    if self.chargeTimer == nil then self.chargeTimer = 4 end
    self.chargeTimer = self.chargeTimer - dt
    if self.charging then
        self.chargeTime = (self.chargeTime or 0) + dt
        local sp = 520 * aggression
        self.x = self.x + self.chargeDX * sp * dt
        self.y = self.y + self.chargeDY * sp * dt
        -- Trail
        for i = 1, 2 do
            P:spawn(self.x + math.random(-20,20), self.y + math.random(-20,20), 1, {1,0.2,0.1}, 60, 0.4, 4)
        end
        -- Damage if touching player (larger radius)
        local pdx, pdy = game.player.x - self.x, game.player.y - self.y
        if pdx*pdx + pdy*pdy < (self.r + game.player.r)^2 then
            game.player:takeDamage(self.dmg * 0.6, self)
        end
        if self.chargeTime > 0.7 then
            self.charging = false
            self.chargeTime = 0
            self.chargeTimer = math.max(2.2, 4 - self.bossPhase * 0.4)
        end
    elseif self.chargeTimer <= 0 then
        -- Telegraph then dash
        if not self.telegraph then
            self.telegraph = 0
            self.chargeDX = dx
            self.chargeDY = dy
        end
        self.telegraph = self.telegraph + dt
        P:spawn(self.x, self.y, 1, {1,0.9,0.2}, 80, 0.3, 3)
        if self.telegraph > 0.7 then
            self.charging = true
            self.telegraph = nil
            Audio:play("boss")
        end
    else
        -- Normal movement: aggressive pursuit with strafe
        local strafe = math.sin(self.bossTimer * 1.2 * aggression) * 0.9
        self.x = self.x + (dx * self.speed * 0.8 + dy * self.speed * strafe) * dt * aggression
        self.y = self.y + (dy * self.speed * 0.8 - dx * self.speed * strafe) * dt * aggression
    end

    -- Laser sweep charge state
    if self.lasing then
        self.laseTime = self.laseTime + dt
        -- Rotate the laser angle over time
        self.laseAngle = self.laseAngle + self.laseDir * dt * 1.8
        local ex = self.x + math.cos(self.laseAngle) * 2000
        local ey = self.y + math.sin(self.laseAngle) * 2000
        self.laseEnd = {ex, ey}
        -- Damage player if crossing beam
        local px, py = game.player.x - self.x, game.player.y - self.y
        local lx, ly = math.cos(self.laseAngle), math.sin(self.laseAngle)
        local proj = px * lx + py * ly
        if proj > 0 then
            local cx, cy = lx * proj, ly * proj
            local d2 = (px - cx)^2 + (py - cy)^2
            if d2 < 900 then
                game.player:takeDamage(26 * dt, self)
            end
        end
        if self.laseTime > 1.6 then
            self.lasing = false
            self.laseEnd = nil
        end
    end

    -- Attack scheduling
    self.shootTimer = self.shootTimer - dt * aggression
    if self.shootTimer <= 0 and not self.charging and not self.telegraph then
        local patternMax = 3 + math.min(3, self.bossPhase)
        local pattern = math.random(1, patternMax)
        if pattern == 1 then
            -- Ring shot, tighter
            local count = 18 + self.bossPhase * 4
            for i = 0, count - 1 do
                local a = (i / count) * math.pi * 2 + self.bossTimer
                local b = Bullet.new(self.x, self.y, math.cos(a)*260, math.sin(a)*260, 14, false)
                b.color = {1, 0.3, 0.2}; b.size = 8; b.fromBoss = true
                table.insert(game.enemyBullets, b)
            end
        elseif pattern == 2 then
            -- Focused spread
            for i = -4, 4 do
                local a = math.atan2(dy, dx) + i * 0.12
                local b = Bullet.new(self.x, self.y, math.cos(a)*340, math.sin(a)*340, 18, false)
                b.color = {1, 0.4, 0.1}; b.size = 10; b.fromBoss = true
                table.insert(game.enemyBullets, b)
            end
        elseif pattern == 3 then
            -- Minion swarm
            local count = 3 + self.bossPhase
            for i = 1, count do
                local a = math.random() * math.pi * 2
                local nx = self.x + math.cos(a) * 120
                local ny = self.y + math.sin(a) * 120
                local types = {"grok", "meta", "deepseek", "windows"}
                local mini = Enemy.new(types[math.random(#types)], nx, ny, 1.3)
                mini.color = {1, 0.3, 0.2}
                table.insert(game.enemies, mini)
            end
        elseif pattern == 4 then
            -- Spiral burst (multiple spirals)
            for arm = 0, 2 do
                for i = 0, 7 do
                    local a = arm * (math.pi * 2 / 3) + i * 0.3 + self.bossTimer
                    local sp = 180 + i * 20
                    local b = Bullet.new(self.x, self.y, math.cos(a)*sp, math.sin(a)*sp, 12, false)
                    b.color = {1, 0.2, 0.2}; b.size = 7; b.fromBoss = true
                    table.insert(game.enemyBullets, b)
                end
            end
        elseif pattern == 5 then
            -- Laser sweep
            self.lasing = true
            self.laseTime = 0
            self.laseAngle = math.atan2(dy, dx) - 0.8
            self.laseDir = 1
            Audio:play("boss")
        else
            -- Aimed barrage
            for i = 1, 10 do
                local a = math.atan2(dy, dx) + math.random() * 0.5 - 0.25
                local b = Bullet.new(self.x, self.y, math.cos(a)*400, math.sin(a)*400, 12, false)
                b.color = {1, 0.5, 0.2}; b.size = 6; b.fromBoss = true
                table.insert(game.enemyBullets, b)
            end
        end
        self.shootTimer = math.max(0.22, 1.6 - self.bossPhase * 0.3)
        if self.bossPhase >= 4 then self.shootTimer = self.shootTimer * 0.55 end
        if self.bossPhase >= 5 then self.shootTimer = self.shootTimer * 0.7 end
        Audio:play("boss")
    end
end

function Enemy:draw()
    local c = self.color
    local flash = self.flash > 0 and 1 or 0
    local r = self.r
    love.graphics.push()
    love.graphics.translate(self.x, self.y)

    if self.shape == "hex" then
        love.graphics.setColor(c[1] + flash, c[2] + flash, c[3] + flash)
        local pts = {}
        for i = 0, 5 do
            local a = i * math.pi / 3
            pts[#pts+1] = math.cos(a) * r
            pts[#pts+1] = math.sin(a) * r
        end
        love.graphics.polygon("fill", pts)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.polygon("line", pts)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("G", -r, -5, r*2, "center")
    elseif self.shape == "diamond" then
        love.graphics.setColor(c[1] + flash, c[2] + flash, c[3] + flash)
        love.graphics.polygon("fill", 0, -r, r, 0, 0, r, -r, 0)
        love.graphics.setColor(1, 1, 1, 0.8)
        for i = 1, 4 do
            local a = self.anim * 2 + i * math.pi / 2
            love.graphics.line(0, 0, math.cos(a) * r * 0.7, math.sin(a) * r * 0.7)
        end
    elseif self.shape == "circle" then
        love.graphics.setColor(c[1] + flash, c[2] + flash, c[3] + flash)
        love.graphics.circle("fill", 0, 0, r)
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.circle("line", 0, 0, r)
        love.graphics.setColor(1, 1, 1)
        local label = self.name:sub(1,1)
        love.graphics.printf(label, -r, -5, r*2, "center")
    elseif self.shape == "whale" then
        love.graphics.setColor(c[1] + flash, c[2] + flash, c[3] + flash)
        love.graphics.ellipse("fill", 0, 0, r * 1.2, r * 0.8)
        love.graphics.polygon("fill", -r*1.2, 0, -r*1.7, -r*0.5, -r*1.7, r*0.5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", r*0.4, -r*0.2, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", r*0.4, -r*0.2, 1.5)
    elseif self.shape == "windows" then
        local s = r * 0.5
        love.graphics.setColor(0.95, 0.2, 0.2)
        love.graphics.rectangle("fill", -s - 1, -s - 1, s, s)
        love.graphics.setColor(0.2, 0.8, 0.2)
        love.graphics.rectangle("fill", 1, -s - 1, s, s)
        love.graphics.setColor(0.2, 0.4, 1.0)
        love.graphics.rectangle("fill", -s - 1, 1, s, s)
        love.graphics.setColor(1.0, 0.85, 0.2)
        love.graphics.rectangle("fill", 1, 1, s, s)
        if flash > 0 then
            love.graphics.setColor(1,1,1,0.5)
            love.graphics.rectangle("fill", -r, -r, r*2, r*2)
        end
    elseif self.shape == "infinity" then
        love.graphics.setColor(c[1] + flash, c[2] + flash, c[3] + flash)
        love.graphics.circle("fill", -r*0.4, 0, r*0.6)
        love.graphics.circle("fill", r*0.4, 0, r*0.6)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("line", -r*0.4, 0, r*0.6)
        love.graphics.circle("line", r*0.4, 0, r*0.6)
    elseif self.shape == "x" then
        love.graphics.setColor(c[1] + flash, c[2] + flash, c[3] + flash)
        love.graphics.circle("fill", 0, 0, r)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(4)
        love.graphics.line(-r*0.5, -r*0.5, r*0.5, r*0.5)
        love.graphics.line(-r*0.5, r*0.5, r*0.5, -r*0.5)
        love.graphics.setLineWidth(1)
    elseif self.shape == "junk" then
        local rot = self.rot or 0
        love.graphics.push()
        love.graphics.rotate(rot)
        love.graphics.setColor(c[1] + flash, c[2] + flash, c[3] + flash)
        love.graphics.polygon("fill", -r, -r*0.5, r*0.7, -r, r*0.8, r*0.6, -r*0.3, r*0.9)
        love.graphics.setColor(0.1, 0.15, 0.18)
        love.graphics.polygon("line", -r, -r*0.5, r*0.7, -r, r*0.8, r*0.6, -r*0.3, r*0.9)
        love.graphics.setColor(0.7, 0.7, 0.8, 0.4)
        love.graphics.rectangle("fill", -r*0.3, -r*0.2, r*0.5, r*0.2)
        love.graphics.pop()
    elseif self.shape == "shrimp" then
        local t = self.anim or love.timer.getTime()
        local alpha = 0.7 + math.sin(t * 4) * 0.1
        love.graphics.setColor(c[1] + flash, c[2] + flash, c[3] + flash, alpha)
        -- Curled body
        love.graphics.arc("fill", "pie", 0, 0, r, math.pi * 0.1, math.pi * 1.6)
        -- Tail fan
        love.graphics.setColor(1, 0.8, 0.85, alpha)
        love.graphics.polygon("fill", -r*0.6, r*0.3, -r*1.1, r*0.6, -r*1.1, 0, -r*1.1, -r*0.6, -r*0.6, -r*0.3)
        -- Antennae
        love.graphics.setColor(1, 1, 1, alpha * 0.7)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(r*0.6, -r*0.3, r*1.2, -r*0.8 + math.sin(t*3)*3)
        love.graphics.line(r*0.6, -r*0.1, r*1.2, -r*0.5 + math.sin(t*3 + 1)*3)
        love.graphics.setLineWidth(1)
        -- Eye
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.circle("fill", r*0.5, -r*0.15, 2)
        -- Ghostly outer aura
        love.graphics.setColor(c[1], c[2], c[3], 0.2)
        love.graphics.circle("line", 0, 0, r + 6 + math.sin(t * 3) * 2)
    elseif self.shape == "lobster" then
        -- Big evil lobster (OpenClaw) boss
        love.graphics.setColor(c[1] + flash*0.5, c[2] + flash*0.5, c[3] + flash*0.5)
        -- Body
        love.graphics.ellipse("fill", 0, 0, r, r * 0.75)
        -- Tail segments
        for i = 1, 4 do
            local bx = r * 0.8 + i * r * 0.3
            local by = 0
            love.graphics.setColor(c[1]*0.8 + flash*0.5, c[2]*0.7 + flash*0.5, c[3]*0.7 + flash*0.5)
            love.graphics.ellipse("fill", bx, by, r * 0.35, r * 0.5)
        end
        -- Big claws
        local clawAng = math.sin(self.anim * 2) * 0.2
        for sign = -1, 1, 2 do
            local cx = -r * 0.8
            local cy = sign * r * 0.7
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.rotate(clawAng * sign)
            love.graphics.setColor(c[1] + flash*0.5, c[2]*0.9 + flash*0.5, c[3]*0.9 + flash*0.5)
            love.graphics.ellipse("fill", -r*0.4, 0, r*0.5, r*0.35)
            love.graphics.ellipse("fill", -r*0.7, -r*0.15, r*0.3, r*0.12)
            love.graphics.ellipse("fill", -r*0.7, r*0.15, r*0.3, r*0.12)
            love.graphics.pop()
        end
        -- Eyes
        love.graphics.setColor(1, 1, 0.2)
        love.graphics.circle("fill", -r*0.4, -r*0.3, r*0.15)
        love.graphics.circle("fill", -r*0.4, r*0.3, r*0.15)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", -r*0.45, -r*0.3, r*0.08)
        love.graphics.circle("fill", -r*0.45, r*0.3, r*0.08)
        -- Antenna
        love.graphics.setColor(c[1]*0.5, c[2]*0.5, c[3]*0.5)
        love.graphics.setLineWidth(3)
        love.graphics.line(-r*0.6, -r*0.4, -r*1.1, -r*0.7 + math.sin(self.anim*3)*3)
        love.graphics.line(-r*0.6, r*0.4, -r*1.1, r*0.7 + math.cos(self.anim*3)*3)
        love.graphics.setLineWidth(1)
    end

    if self.freezeTime > 0 then
        love.graphics.setColor(0.5, 0.9, 1, 0.4)
        love.graphics.circle("fill", 0, 0, r + 4)
    end
    if self.burnTime > 0 then
        -- Thick pulsing fire aura: outer red glow, inner orange flame tint,
        -- flickering ring around the silhouette.
        local pulse = 0.5 + math.sin(self.anim * 22) * 0.5
        love.graphics.setColor(1, 0.3, 0.05, 0.25 + pulse * 0.2)
        love.graphics.circle("fill", 0, 0, r + 8 + pulse * 2)
        love.graphics.setColor(1, 0.55, 0.15, 0.6)
        love.graphics.setLineWidth(2.5)
        love.graphics.circle("line", 0, 0, r + 4 + pulse * 2)
        love.graphics.setColor(1, 0.85, 0.35, 0.55)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", 0, 0, r + 1)
        -- Flame-licks around the perimeter
        for i = 0, 5 do
            local a = (i / 6) * math.pi * 2 + self.anim * 3
            local flick = r + 6 + math.abs(math.sin(self.anim * 10 + i)) * 6
            love.graphics.setColor(1, 0.7, 0.2, 0.7)
            love.graphics.circle("fill", math.cos(a) * flick, math.sin(a) * flick, 1.8)
        end
    end
    love.graphics.pop()

    -- Boss laser beam
    if self.lasing and self.laseEnd then
        love.graphics.setColor(1, 0.2, 0.1, 0.4)
        love.graphics.setLineWidth(20)
        love.graphics.line(self.x, self.y, self.laseEnd[1], self.laseEnd[2])
        love.graphics.setColor(1, 0.7, 0.3, 0.9)
        love.graphics.setLineWidth(8)
        love.graphics.line(self.x, self.y, self.laseEnd[1], self.laseEnd[2])
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(self.x, self.y, self.laseEnd[1], self.laseEnd[2])
        love.graphics.setLineWidth(1)
    end
    if self.telegraph then
        love.graphics.setColor(1, 0.9, 0.2, 0.5)
        love.graphics.setLineWidth(3)
        love.graphics.line(self.x, self.y, self.x + self.chargeDX * 600, self.y + self.chargeDY * 600)
        love.graphics.setLineWidth(1)
    end

    -- HP bar
    if self.hp < self.maxHp then
        local w = self.isBoss and 300 or math.max(24, r * 1.6)
        local h = self.isBoss and 12 or 4
        local bx = self.x - w / 2
        local by = self.isBoss and 50 or (self.y - r - 10)
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", bx, by, w, h)
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.rectangle("fill", bx, by, w * (self.hp / self.maxHp), h)
        love.graphics.setColor(1,1,1,1)
        if self.isBoss then
            love.graphics.printf(self.name .. " — PHASE " .. self.bossPhase, bx, by - 18, w, "center")
        end
    end
    love.graphics.setColor(1,1,1,1)
end

Enemy.types = types
return Enemy
