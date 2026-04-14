local Bullet = require("src.bullet")
local Audio = require("src.audio")
local P = require("src.particles")
local Eldritch = require("src.eldritch")
local Cosmetics = require("src.cosmetics")

local Player = {}
Player.__index = Player

function Player.new(x, y, config, persist)
    config = config or {}
    local self = setmetatable({}, Player)
    self.cosmetics = Cosmetics.equipped(persist)
    self.uprightHead = (persist and persist.uprightHead) == 1
    self.trailTimer = 0
    self.x, self.y = x, y
    self.r = 18
    self.speed = 245
    self.baseSpeed = 245
    self.hp = config.startHp or 115
    self.maxHp = config.startHp or 115
    self.eldritch = Eldritch.newState()
    if config.startEldritch then
        Eldritch.gainLevel(self, config.startEldritch)
    end
    -- Base passive HP regen. Cards like Crawling Shell stack on top.
    self.regen = 1.5
    self.angle = 0
    self.shootTimer = 0
    self.invuln = 0
    self.dashCD = 0
    self.dashMax = 2.5
    self.bombCD = 0
    self.bombMax = 15
    self.legPhase = 0
    self.flashTimer = 0

    -- Gun stats modified by cards
    self.stats = {
        damage = 14,
        fireRate = 4.3,       -- shots per second
        bulletSpeed = 700,
        bulletSize = 5,
        bullets = 1,           -- bullets per shot
        spread = 0.05,         -- radians
        pierce = 0,
        bounce = 0,
        homing = 0,
        crit = 0.05,
        critMult = 2.0,
        lifesteal = 0,
        killHeal = 0,
        explosive = 0,
        explodeRadius = 110,
        freeze = 0,
        burn = 0,
        chain = 0,
        chainRange = 150,
        split = 0,
        rangeBonus = 0,
        thorns = 0,
        dodge = 0,
        pickupRange = 40,
        scoreMult = 1,
        shield = 0,
        shieldMax = 0,
        shieldRegen = 0,
        orbs = 0,
        barrier = false,
        barrierUsed = false,
        reviveAvailable = false,
        magnet = 80,
        weaponType = "normal", -- normal, laser, shotgun, railgun
        railCharge = 0,
        hasDash = true,
        hasBomb = false,
        glassCannon = false,
        berserker = 0,
        cursedDmg = 0,
        repMod = 0,
        extraCards = 0,
    }
    self.orbAngle = 0
    self.score = 0
    self.reputation = 30
    self.cardsTaken = {}
    self.laserActive = false
    self.railChargeTime = 0
    self.rainTimer = 0
    self.bodyAngle = 0 -- rotates toward movement direction
    self.slugTailHistory = {} -- past player positions for procedural slug tail
    return self
end

function Player:takeDamage(amt, source, unstoppable)
    -- Unstoppable damage (Claude Cthulhu's beam) bypasses invuln/dodge/barrier/shield.
    if not unstoppable then
        if self.invuln > 0 then return end
        if self.stats.dodge > 0 and math.random() < self.stats.dodge then
            P:text(self.x, self.y - 20, "DODGE!", {1,1,0.3}, 0.6)
            return
        end
        if self.stats.barrier and not self.stats.barrierUsed then
            self.stats.barrierUsed = true
            P:text(self.x, self.y - 20, "BLOCKED", {0.5,0.8,1}, 0.6)
            P:spawn(self.x, self.y, 18, {0.5,0.8,1}, 300, 0.5, 3)
            self.invuln = 0.6
            return
        end
        if self.stats.shield > 0 then
            local absorbed = math.min(self.stats.shield, amt)
            self.stats.shield = self.stats.shield - absorbed
            amt = amt - absorbed
        end
    end
    if amt <= 0 then return end
    self.hp = self.hp - amt
    self.invuln = 0.5
    self.flashTimer = 0.2
    Audio:play("hurt")
    P:spawn(self.x, self.y, 12, {1,0.3,0.3}, 220, 0.5, 3)

    -- Adrenaline trigger
    if self.adrenaline then
        self.adrenalineTime = 3.0
        self.adrenalineActive = true
    end
    -- Aegis: small shockwave + extra invuln
    if self.aegis and self.game then
        self.invuln = 1.0
        table.insert(self.game.shockwaves or {}, {x = self.x, y = self.y, r = 0, max = 140, life = 0.4, color = {0.5, 0.8, 1}})
        for _, e in ipairs(self.game.enemies) do
            local d = (e.x - self.x)^2 + (e.y - self.y)^2
            if d < 140 * 140 then e:damage(30, self, self.game) end
        end
    end
    -- Counter burst: ring of bullets in response to hit
    if self.counterBurst and self.counterBurst > 0 and self.game then
        local count = self.counterBurst
        for i = 0, count - 1 do
            local a = (i / count) * math.pi * 2
            local b = Bullet.new(self.x, self.y, math.cos(a)*420, math.sin(a)*420, self.stats.damage * 0.7, true)
            b.size = self.stats.bulletSize
            b.color = {0.6, 0.8, 1}
            b.owner = self
            table.insert(self.game.bullets, b)
        end
    end

    if self.hp <= 0 and self.stats.reviveAvailable then
        self.stats.reviveAvailable = false
        self.hp = self.maxHp * 0.5
        self.invuln = 2
        P:text(self.x, self.y - 30, "REVIVED!", {0.5,1,0.5}, 1.5)
        P:spawn(self.x, self.y, 40, {0.5,1,0.5}, 400, 1, 5)
    end
end

function Player:heal(amt)
    self.hp = math.min(self.maxHp, self.hp + amt)
    P:text(self.x + math.random(-10,10), self.y - 10, "+"..math.floor(amt), {0.4,1,0.4}, 0.8)
end

function Player:update(dt, game)
    self.game = game
    local mx, my = love.mouse.getPosition()
    self.angle = math.atan2(my - self.y, mx - self.x)

    local dx, dy = 0, 0
    if love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("s") then dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("d") then dx = dx + 1 end
    if dx ~= 0 or dy ~= 0 then
        local l = math.sqrt(dx*dx + dy*dy)
        dx, dy = dx/l, dy/l
        self.legPhase = self.legPhase + dt * 10
        -- Rotate body toward movement (smooth)
        local targetAngle = math.atan2(dy, dx)
        local diff = targetAngle - self.bodyAngle
        while diff > math.pi do diff = diff - math.pi * 2 end
        while diff < -math.pi do diff = diff + math.pi * 2 end
        self.bodyAngle = self.bodyAngle + diff * math.min(1, dt * 10)
    end
    local spd = self.speed
    if self.stats.berserker > 0 then
        local lowHpBoost = 1 + (1 - self.hp/self.maxHp) * self.stats.berserker
        spd = spd * lowHpBoost
    end
    if self.duskMode and self.hp / self.maxHp < 0.3 then
        spd = spd * 1.5
    end
    spd = spd * (self.scuttleBoost or 1)
    self.x = self.x + dx * spd * dt
    self.y = self.y + dy * spd * dt

    -- Bounds
    self.x = math.max(self.r, math.min(1280 - self.r, self.x))
    self.y = math.max(self.r + 40, math.min(720 - self.r, self.y))

    -- Shooting
    self.shootTimer = math.max(0, self.shootTimer - dt)
    -- Effective fire rate modifiers (adrenaline + overdrive)
    local effFireRate = self.stats.fireRate
    if self.adrenalineActive then effFireRate = effFireRate * 1.6 end
    if self.overdriveActive then effFireRate = effFireRate * 3.0 end
    if love.mouse.isDown(1) and not self.laserActive and not self.disabled then
        if self.stats.weaponType == "railgun" then
            self.railChargeTime = self.railChargeTime + dt
            if self.railChargeTime >= 1.2 then
                self:fireRail(game)
                self.railChargeTime = 0
            end
        elseif self.shootTimer <= 0 then
            self:shoot(game)
            if self.flurryShots and self.flurryShots > 0 then
                self.flurryShots = self.flurryShots - 1
                self.shootTimer = 0.04
            elseif self.freeShotEvery then
                -- Every Nth shot skips the fire-rate cooldown entirely.
                self._shotCountFree = (self._shotCountFree or 0) + 1
                if self._shotCountFree >= self.freeShotEvery then
                    self._shotCountFree = 0
                    self.shootTimer = 0.04 -- essentially instant next shot
                else
                    self.shootTimer = 1 / effFireRate
                end
            else
                self.shootTimer = 1 / effFireRate
            end
        end
    else
        if self.stats.weaponType == "railgun" and self.railChargeTime > 0.4 then
            self:fireRail(game)
        end
        self.railChargeTime = 0
    end
    if self.stats.weaponType == "laser" and love.mouse.isDown(1) then
        self.laserActive = true
        self:fireLaser(game, dt)
    else
        self.laserActive = false
    end

    -- Cooldowns
    self.dashCD = math.max(0, self.dashCD - dt)
    self.bombCD = math.max(0, self.bombCD - dt)
    self.invuln = math.max(0, self.invuln - dt)
    self.flashTimer = math.max(0, self.flashTimer - dt)

    -- Shield regen
    if self.stats.shieldMax > 0 then
        self.stats.shield = math.min(self.stats.shieldMax, self.stats.shield + self.stats.shieldRegen * dt)
    end

    -- Passive HP regen (from Crawling Shell etc)
    if self.regen > 0 and self.hp < self.maxHp then
        self.hp = math.min(self.maxHp, self.hp + self.regen * dt)
    end

    -- Static aura damage (per-second)
    if self.staticAura and self.staticAura > 0 then
        for _, e in ipairs(game.enemies) do
            local d = (e.x - self.x)^2 + (e.y - self.y)^2
            if d < 140 * 140 then
                e:damage(self.staticAura * dt, self, game)
            end
        end
        if math.random() < dt * 10 then
            P:spawn(self.x + math.random(-140, 140), self.y + math.random(-140, 140), 1, {0.5, 0.9, 1}, 20, 0.3, 2)
        end
    end

    -- Pulse fire (free AoE every 1s)
    if self.pulseFire then
        self.pulseTimer = (self.pulseTimer or 0) + dt
        if self.pulseTimer >= 1.0 then
            self.pulseTimer = 0
            table.insert(game.shockwaves or {}, {x = self.x, y = self.y, r = 0, max = 110, life = 0.35, color = {0.9, 0.9, 0.2}})
            for _, e in ipairs(game.enemies) do
                local d = (e.x - self.x)^2 + (e.y - self.y)^2
                if d < 110 * 110 then e:damage(20, self, game) end
            end
            P:spawn(self.x, self.y, 20, {1, 1, 0.3}, 250, 0.4, 4)
        end
    end

    -- Adrenaline timer
    if self.adrenaline and self.adrenalineTime then
        self.adrenalineTime = self.adrenalineTime - dt
        if self.adrenalineTime <= 0 then
            self.adrenalineTime = nil
            self.adrenalineActive = false
        end
    end

    -- Overdrive: first 2s of wave = triple fire rate
    if self.overdriveWaveStart then
        self.waveRunTime = (self.waveRunTime or 0) + dt
        self.overdriveActive = (self.waveRunTime < 2.0)
    end

    -- Scuttle: boost speed while firing
    if self.scuttle and love.mouse.isDown(1) then
        self.scuttleBoost = 1.35
    else
        self.scuttleBoost = 1.0
    end

    -- Track movement velocity magnitude for momentum/focus checks
    if self._prevMoveX and self._prevMoveY then
        local mdx, mdy = self.x - self._prevMoveX, self.y - self._prevMoveY
        local speed = math.sqrt(mdx * mdx + mdy * mdy) / math.max(dt, 0.001)
        self.velocityMag = speed
    else
        self.velocityMag = 0
    end
    self._prevMoveX, self._prevMoveY = self.x, self.y

    -- Slug tail history: records when the "slug" trail is equipped.
    if self.cosmetics and self.cosmetics.trail == "slug" then
        local hist = self.slugTailHistory
        local last = hist[1]
        if not last or ((self.x - last.x) ^ 2 + (self.y - last.y) ^ 2) > 4 then
            table.insert(hist, 1, {x = self.x, y = self.y})
            while #hist > 33 do table.remove(hist) end
        end
    end

    -- Rain bullets (Unshaped One): a continuous downpour of bullets across the
    -- whole playfield. Denser and more visible than the old 1-per-tick version.
    if self.rainBullets and self.rainBullets > 0 then
        self.rainTimer = (self.rainTimer or 0) - dt
        if self.rainTimer <= 0 then
            self.rainTimer = 0.10 -- fire a burst every 100ms regardless of mouse state
            local perTick = 4 * self.rainBullets
            for _ = 1, perTick do
                local sx = math.random(40, 1240)
                local sy = -10 - math.random(0, 40)
                -- Mostly vertical drop with a slight random angle so it feels natural
                local ang = math.pi / 2 + (math.random() - 0.5) * 0.3
                local speed = 560 + math.random(0, 120)
                local b = Bullet.new(sx, sy,
                    math.cos(ang) * speed, math.sin(ang) * speed,
                    self.stats.damage * 0.45, true)
                b.size = math.max(4, self.stats.bulletSize * 0.8)
                b.owner = self
                b.color = {0.85, 0.35, 1}
                b.trail = true
                b.life = 3.5 -- long enough to cross the screen
                table.insert(game.bullets, b)
            end
        end
    end

    -- Orbiting projectiles - now inherit damage, crit, freeze, burn
    if self.stats.orbs > 0 then
        self.orbAngle = self.orbAngle + dt * 3
        local mult = self.orbDmgMult or 1
        for i = 1, self.stats.orbs do
            local a = self.orbAngle + (i - 1) * (math.pi * 2 / self.stats.orbs)
            local ox = self.x + math.cos(a) * 60
            local oy = self.y + math.sin(a) * 60
            for _, e in ipairs(game.enemies) do
                local d2 = (e.x - ox)^2 + (e.y - oy)^2
                if d2 < (e.r + 8)^2 then
                    if not e.orbHitTime or love.timer.getTime() - e.orbHitTime > 0.3 then
                        local dmg = self.stats.damage * 0.5 * mult
                        local isCrit = math.random() < self.stats.crit
                        if isCrit then dmg = dmg * self.stats.critMult end
                        e:damage(dmg, self, game, isCrit)
                        if self.stats.freeze > 0 then e.freezeTime = math.max(e.freezeTime or 0, self.stats.freeze * 0.5) end
                        if self.stats.burn > 0 then e.burnTime = math.max(e.burnTime or 0, 2); e.burnDmg = self.stats.burn end
                        e.orbHitTime = love.timer.getTime()
                    end
                end
            end
        end
    end

    -- Thorns check handled on collision in enemy
end

function Player:computeShotDamage()
    local s = self.stats
    local dmg = s.damage
    -- Momentum: up to +50% at full speed
    if self.momentum and self.velocityMag then
        local frac = math.min(1, self.velocityMag / self.baseSpeed)
        dmg = dmg * (1 + 0.5 * frac)
    end
    -- Focus: +10% when stationary
    if self.focusWhenStill and (self.velocityMag or 0) < 5 then
        dmg = dmg * 1.10
    end
    -- Dusk: low HP = +100% damage
    if self.duskMode and self.hp / self.maxHp < 0.3 then
        dmg = dmg * 2
    end
    -- Compound interest: +1% per wave kill
    if self.compoundInterest then
        dmg = dmg * (1 + 0.01 * (self._waveCompKills or 0))
    end
    return dmg
end

-- Soft stat caps applied at fire-time so stacking many cards doesn't trivialize combat.
local STAT_CAPS = {bullets = 8, pierce = 8, chain = 5, orbs = 5, bounce = 5}
local function cap(v, k)
    local c = STAT_CAPS[k]
    if not c then return v end
    return math.min(v, c)
end

function Player:shoot(game)
    local s = self.stats

    -- "Every Nth shot is a crit" stat
    if self.everyNthCrit then
        self._shotCount = (self._shotCount or 0) + 1
        if self._shotCount >= self.everyNthCrit then
            self._shotCount = 0
            self._forceCritNextShot = true
        end
    end

    local dmg = self:computeShotDamage()

    local bullets = cap(s.bullets, "bullets")
    if s.weaponType == "shotgun" then
        local count = 5 + bullets - 1
        for i = 1, count do
            local spread = (i - (count+1)/2) * 0.18
            self:fireBullet(game, self.angle + spread, dmg * 0.6)
        end
        Audio:play("shoot2")
    else
        for i = 1, bullets do
            local off = 0
            if bullets > 1 then off = (i - (bullets+1)/2) * 0.12 end
            local spread = (math.random() - 0.5) * s.spread * 2
            if self.wobbleShots then spread = spread + (math.random() - 0.5) * 0.3 end
            self:fireBullet(game, self.angle + off + spread, dmg)
        end
        -- Tri-way: extra bullets perpendicular
        if self.triWay then
            self:fireBullet(game, self.angle + math.pi * 0.5, dmg * 0.55)
            self:fireBullet(game, self.angle - math.pi * 0.5, dmg * 0.55)
        end
        Audio:play("shoot")
    end
    self._forceCritNextShot = nil
end

function Player:fireBullet(game, angle, damage)
    local s = self.stats
    local b = Bullet.new(self.x + math.cos(angle) * self.r, self.y + math.sin(angle) * self.r,
        math.cos(angle) * s.bulletSpeed, math.sin(angle) * s.bulletSpeed,
        damage, true)
    b.size = s.bulletSize
    b.pierce = cap(s.pierce, "pierce")
    b.bounce = cap(s.bounce, "bounce")
    b.bounceDmgStack = self.bounceDmgStack
    b.homing = s.homing
    b.explosive = s.explosive
    b.explodeRadius = s.explodeRadius
    b.freeze = s.freeze
    b.burn = s.burn
    b.chain = cap(s.chain, "chain")
    b.chainRange = s.chainRange
    b.split = s.split
    b.crit = self._forceCritNextShot and 1.0 or s.crit
    b.critMult = s.critMult
    b.lifesteal = s.lifesteal
    b.owner = self
    b.color = {1, 0.6, 0.2}
    table.insert(game.bullets, b)
end

function Player:fireRail(game)
    local s = self.stats
    -- Railgun now inherits bullet count (multishot fans), homing, explosive, freeze, burn, chain, crit
    local count = s.bullets
    for i = 1, count do
        local off = 0
        if count > 1 then off = (i - (count + 1) / 2) * 0.05 end
        local ang = self.angle + off + (math.random() - 0.5) * s.spread
        local b = Bullet.new(self.x + math.cos(ang) * self.r, self.y + math.sin(ang) * self.r,
            math.cos(ang) * s.bulletSpeed * 2, math.sin(ang) * s.bulletSpeed * 2,
            s.damage * 4, true)
        b.size = s.bulletSize * 2.5
        b.pierce = math.max(99, s.pierce + 99)
        b.color = {1, 1, 0.3}
        b.owner = self
        b.trail = true
        b.homing = s.homing * 0.5  -- less responsive homing for heavy rails
        b.explosive = s.explosive
        b.explodeRadius = s.explodeRadius
        b.freeze = s.freeze
        b.burn = s.burn
        b.chain = s.chain
        b.chainRange = s.chainRange
        b.crit = s.crit
        b.critMult = s.critMult
        b.lifesteal = s.lifesteal
        table.insert(game.bullets, b)
    end
    Audio:play("shoot2")
end

function Player:fireLaser(game, dt)
    local s = self.stats
    local widthMult = self.laserWidthMult or 1
    local dmgMult = self.laserDmgMult or 1
    local beams = self.laserBeams or 1
    local hitRadiusMult = widthMult  -- wider beam = larger hit radius
    self.laserEnds = {}

    for beamIdx = 1, beams do
        local angleOffset = 0
        if beams > 1 then
            angleOffset = (beamIdx - (beams + 1) / 2) * 0.12
        end
        local ang = self.angle + angleOffset
        local sx, sy = self.x, self.y
        local dx, dy = math.cos(ang), math.sin(ang)
        local hitEnemy = nil
        local hitDist = 2000
        for _, e in ipairs(game.enemies) do
            local ex, ey = e.x - sx, e.y - sy
            local t = ex * dx + ey * dy
            if t > 0 and t < hitDist then
                local cx, cy = sx + dx * t, sy + dy * t
                local d2 = (e.x - cx) ^ 2 + (e.y - cy) ^ 2
                if d2 < (e.r * hitRadiusMult) ^ 2 then
                    hitDist = t
                    hitEnemy = e
                end
            end
        end
        table.insert(self.laserEnds, {sx + dx * hitDist, sy + dy * hitDist})
        if hitEnemy then
            local base = s.damage * dmgMult * dt * s.fireRate * 2
            local isCrit = self.laserAlwaysCrit or (math.random() < s.crit * dt * 8)
            if isCrit then base = base * s.critMult end
            hitEnemy:damage(base, self, game, isCrit)
            local freezeMult = self.laserFreezeMult or 0.5
            if s.freeze > 0 then hitEnemy.freezeTime = math.max(hitEnemy.freezeTime or 0, s.freeze * freezeMult) end
            local burnMult = self.laserBurnMult or 1
            if s.burn > 0 then hitEnemy.burnTime = math.max(hitEnemy.burnTime or 0, 2); hitEnemy.burnDmg = s.burn * burnMult end
            local lsMult = self.laserLifestealMult or 1
            if s.lifesteal > 0 then self:heal(base * s.lifesteal * lsMult) end

            if s.pierce > 0 or self.laserFullPierce then
                local maxPast = self.laserFullPierce and 999 or math.min(s.pierce, 5)
                local checked = 0
                for _, e in ipairs(game.enemies) do
                    if e ~= hitEnemy and checked < maxPast then
                        local ex, ey = e.x - sx, e.y - sy
                        local t = ex * dx + ey * dy
                        if t > hitDist and t < 2000 then
                            local cx, cy = sx + dx * t, sy + dy * t
                            local d2 = (e.x - cx) ^ 2 + (e.y - cy) ^ 2
                            if d2 < (e.r * hitRadiusMult) ^ 2 then
                                e:damage(base * 0.65, self, game, isCrit)
                                if s.burn > 0 then e.burnTime = math.max(e.burnTime or 0, 2); e.burnDmg = s.burn * burnMult end
                                if s.freeze > 0 then e.freezeTime = math.max(e.freezeTime or 0, s.freeze * freezeMult) end
                                checked = checked + 1
                            end
                        end
                    end
                end
            end
            if math.random() < 0.2 then
                P:spawn(hitEnemy.x, hitEnemy.y, 2, {1, 0.4, 0.2}, 120, 0.3, 2)
            end
        end
    end
    -- Keep legacy single-end field for compatibility with draw
    self.laserEnd = self.laserEnds[1]
end

function Player:dash()
    if self.dashCD > 0 or not self.stats.hasDash then return end
    local dx, dy = 0, 0
    if love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("s") then dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("d") then dx = dx + 1 end
    if dx == 0 and dy == 0 then
        dx = math.cos(self.angle); dy = math.sin(self.angle)
    end
    local l = math.sqrt(dx*dx + dy*dy)
    dx, dy = dx/l, dy/l
    local preX, preY = self.x, self.y
    self.x = self.x + dx * 180
    self.y = self.y + dy * 180
    self.x = math.max(self.r, math.min(1280 - self.r, self.x))
    self.y = math.max(self.r + 40, math.min(720 - self.r, self.y))
    -- Drag the slug tail along with the teleport so it doesn't stretch across
    -- the screen from old position to new.
    if self.slugTailHistory then
        local ddx, ddy = self.x - preX, self.y - preY
        for _, pos in ipairs(self.slugTailHistory) do
            pos.x = pos.x + ddx
            pos.y = pos.y + ddy
        end
    end
    self._prevMoveX, self._prevMoveY = self.x, self.y
    self.invuln = math.max(0.3, self.dashInvuln or 0.3)
    self.dashCD = self.dashMax
    Audio:play("dash")
    P:spawn(self.x, self.y, 14, {1,0.7,0.3}, 150, 0.4, 3)
end

function Player:bomb(game)
    if self.bombCD > 0 or not self.stats.hasBomb then return end
    self.bombCD = self.bombMax
    Audio:play("explode")
    P:spawn(self.x, self.y, 60, {1, 0.8, 0.2}, 500, 0.8, 6)
    for _, e in ipairs(game.enemies) do
        e:damage(80, self, game)
    end
    for i = #game.enemyBullets, 1, -1 do
        table.remove(game.enemyBullets, i)
    end
end

-- Draws the weapon in the player's aim-rotated frame. Called after _drawClaws
-- so the weapon sits on top of the claws. Local coordinates: +x = muzzle direction.
function Player:_drawGun(style)
    style = style or "pistol"
    local baseX = self.r
    if style == "pistol" then
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", baseX, -3, 22, 6)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", baseX, -3, 22, 6)
        -- Front sight
        love.graphics.rectangle("fill", baseX + 19, -5, 2, 2)
    elseif style == "compact" then
        -- Compact pistol: slide with serrations, iron sights, trigger guard,
        -- ejection port, checkered grip, front muzzle.
        love.graphics.setColor(0.22, 0.22, 0.26)
        love.graphics.rectangle("fill", baseX, -3, 17, 6)
        love.graphics.setColor(0.4, 0.4, 0.48)
        love.graphics.rectangle("line", baseX, -3, 17, 6)
        -- Slide on top (darker)
        love.graphics.setColor(0.12, 0.12, 0.15)
        love.graphics.rectangle("fill", baseX + 1, -4, 15, 2)
        -- Slide serrations (diagonal grooves)
        love.graphics.setColor(0.5, 0.5, 0.55)
        for i = 0, 4 do
            love.graphics.line(baseX + 11 + i * 0.8, -4, baseX + 10 + i * 0.8, -2)
        end
        -- Rear iron sight
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", baseX + 2, -5, 2, 1)
        -- Front iron sight with white dot
        love.graphics.rectangle("fill", baseX + 14, -5, 1.5, 1)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", baseX + 14.5, -4.5, 0.6, 0.5)
        -- Trigger guard arc
        love.graphics.setColor(0.25, 0.25, 0.3)
        love.graphics.setLineWidth(1.5)
        love.graphics.arc("line", "open", baseX + 6, 4, 2, 0, math.pi)
        love.graphics.setLineWidth(1)
        -- Ejection port
        love.graphics.setColor(0.05, 0.05, 0.08)
        love.graphics.rectangle("fill", baseX + 8, -2, 3, 1)
        -- Checkered grip
        love.graphics.setColor(0.08, 0.08, 0.1)
        for i = 0, 2 do
            love.graphics.rectangle("fill", baseX + 1, -1 + i * 1.3, 4, 0.5)
        end
        -- Muzzle
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", baseX + 17, 0, 1)
    elseif style == "magnum" then
        -- Revolver: barrel + cylinder drum
        love.graphics.setColor(0.22, 0.2, 0.25)
        love.graphics.rectangle("fill", baseX + 8, -2.5, 18, 5)
        love.graphics.setColor(0.35, 0.3, 0.38)
        love.graphics.circle("fill", baseX + 5, 0, 6)
        love.graphics.setColor(0.15, 0.12, 0.18)
        love.graphics.circle("line", baseX + 5, 0, 6)
        for i = 0, 5 do
            local a = (i / 6) * math.pi * 2
            love.graphics.circle("fill", baseX + 5 + math.cos(a) * 3, math.sin(a) * 3, 1)
        end
    elseif style == "rifle" then
        -- Long barrel with a forestock and small stock nub
        love.graphics.setColor(0.25, 0.2, 0.12)
        love.graphics.rectangle("fill", baseX - 2, -2, 6, 4) -- stock
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", baseX + 4, -2, 32, 4)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", baseX + 4, -2, 32, 4)
        love.graphics.setColor(0.35, 0.35, 0.45)
        love.graphics.rectangle("fill", baseX + 14, -4, 6, 2) -- scope
        love.graphics.rectangle("fill", baseX + 33, -5, 2, 2) -- front sight
    elseif style == "shotgun" then
        -- Pump-action double-barrel
        love.graphics.setColor(0.15, 0.1, 0.06)
        love.graphics.rectangle("fill", baseX - 2, -4, 6, 8)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", baseX + 4, -4, 20, 3)
        love.graphics.rectangle("fill", baseX + 4, 1, 20, 3)
        love.graphics.setColor(0.35, 0.35, 0.42)
        love.graphics.rectangle("fill", baseX + 12, -4, 5, 8)
    elseif style == "smg" then
        -- Detailed compact SMG: folding stock, textured grip, extended mag,
        -- charging handle, suppressor, red-dot sight
        local t = love.timer.getTime()
        -- Folding wire stock at the back
        love.graphics.setColor(0.2, 0.2, 0.24)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(baseX - 6, -2, baseX - 2, -2)
        love.graphics.line(baseX - 6, 2, baseX - 2, 2)
        love.graphics.line(baseX - 6, -2, baseX - 6, 2)
        love.graphics.setLineWidth(1)
        -- Main body (steel)
        love.graphics.setColor(0.18, 0.18, 0.22)
        love.graphics.rectangle("fill", baseX, -3, 22, 6)
        love.graphics.setColor(0.35, 0.35, 0.4)
        love.graphics.rectangle("line", baseX, -3, 22, 6)
        -- Textured grip area
        love.graphics.setColor(0.1, 0.1, 0.12)
        for i = 0, 3 do
            love.graphics.rectangle("fill", baseX + 2 + i * 1.5, -2, 0.8, 4)
        end
        -- Charging handle on top
        love.graphics.setColor(0.45, 0.45, 0.5)
        love.graphics.rectangle("fill", baseX + 12, -5, 5, 2)
        love.graphics.setColor(0.25, 0.25, 0.3)
        love.graphics.rectangle("line", baseX + 12, -5, 5, 2)
        -- Red-dot optic
        love.graphics.setColor(0.15, 0.15, 0.18)
        love.graphics.rectangle("fill", baseX + 5, -7, 5, 3)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", baseX + 5, -7, 5, 3)
        love.graphics.setColor(1, 0.2, 0.2, 0.9 + math.sin(t * 4) * 0.1)
        love.graphics.circle("fill", baseX + 7.5, -5.5, 0.9)
        -- Extended vertical mag with visible rounds
        love.graphics.setColor(0.12, 0.12, 0.15)
        love.graphics.rectangle("fill", baseX + 4, 3, 6, 10)
        love.graphics.setColor(0.35, 0.35, 0.4)
        love.graphics.rectangle("line", baseX + 4, 3, 6, 10)
        love.graphics.setColor(0.85, 0.65, 0.2)
        for i = 0, 3 do love.graphics.line(baseX + 5, 5 + i * 2, baseX + 9, 5 + i * 2) end
        -- Trigger guard (arc under the grip)
        love.graphics.setColor(0.25, 0.25, 0.3)
        love.graphics.setLineWidth(1.5)
        love.graphics.arc("line", "open", baseX + 14, 4, 2.5, 0, math.pi)
        love.graphics.setLineWidth(1)
        -- Suppressor (ribbed)
        love.graphics.setColor(0.1, 0.1, 0.12)
        love.graphics.rectangle("fill", baseX + 22, -2.5, 10, 5)
        love.graphics.setColor(0.3, 0.3, 0.35)
        for i = 0, 3 do love.graphics.line(baseX + 24 + i * 2, -2.5, baseX + 24 + i * 2, 2.5) end
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", baseX + 32, 0, 1.2)
    elseif style == "blaster" then
        -- Sci-fi with glowing tip
        local t = love.timer.getTime()
        love.graphics.setColor(0.15, 0.2, 0.35)
        love.graphics.rectangle("fill", baseX, -3, 20, 6, 1, 1)
        love.graphics.setColor(0.3, 0.5, 0.9)
        love.graphics.rectangle("fill", baseX + 2, -2, 14, 4)
        -- glowing tip
        love.graphics.setColor(0.3, 1, 1, 0.9)
        love.graphics.circle("fill", baseX + 22, 0, 3 + math.sin(t * 5) * 0.5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", baseX + 22, 0, 1.4)
    elseif style == "cannon" then
        -- Heavy anti-material cannon: recoil buffer, top rail, carry handle,
        -- side vents, flared muzzle with inner rifling, targeting laser
        local t = love.timer.getTime()
        -- Recoil buffer at back
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", baseX - 4, -3, 5, 6)
        love.graphics.setColor(0.6, 0.6, 0.65)
        love.graphics.rectangle("line", baseX - 4, -3, 5, 6)
        love.graphics.setColor(0.08, 0.08, 0.1)
        for i = 0, 2 do love.graphics.line(baseX - 3 + i * 1.5, -3, baseX - 3 + i * 1.5, 3) end
        -- Thick main body
        love.graphics.setColor(0.18, 0.18, 0.22)
        love.graphics.rectangle("fill", baseX + 1, -6, 20, 12)
        love.graphics.setColor(0.5, 0.5, 0.55)
        love.graphics.rectangle("line", baseX + 1, -6, 20, 12)
        -- Top rail + carry handle
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", baseX + 3, -8, 16, 2)
        love.graphics.setColor(0.15, 0.15, 0.18)
        for i = 0, 6 do love.graphics.line(baseX + 4 + i * 2, -8, baseX + 4 + i * 2, -6) end
        -- Carry handle arch
        love.graphics.setColor(0.25, 0.25, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", baseX + 11, -8, 4, -math.pi, 0)
        love.graphics.setLineWidth(1)
        -- Side heat vents (gills)
        love.graphics.setColor(0.08, 0.08, 0.1)
        for i = 0, 3 do
            love.graphics.rectangle("fill", baseX + 5 + i * 3, -5, 2, 0.8)
            love.graphics.rectangle("fill", baseX + 5 + i * 3, 4.2, 2, 0.8)
        end
        -- Gold bolt rivets
        love.graphics.setColor(0.85, 0.65, 0.2)
        love.graphics.circle("fill", baseX + 3, -4, 0.9)
        love.graphics.circle("fill", baseX + 3, 4, 0.9)
        love.graphics.circle("fill", baseX + 19, -4, 0.9)
        love.graphics.circle("fill", baseX + 19, 4, 0.9)
        -- Flared muzzle (trapezoid)
        love.graphics.setColor(0.22, 0.22, 0.26)
        love.graphics.polygon("fill", baseX + 21, -7, baseX + 30, -5, baseX + 30, 5, baseX + 21, 7)
        love.graphics.setColor(0.5, 0.5, 0.55)
        love.graphics.polygon("line", baseX + 21, -7, baseX + 30, -5, baseX + 30, 5, baseX + 21, 7)
        -- Deep bore
        love.graphics.setColor(0.02, 0.02, 0.03)
        love.graphics.circle("fill", baseX + 27, 0, 3)
        -- Inner rifling (3 lines showing the spiral)
        love.graphics.setColor(0.15, 0.15, 0.2)
        for i = 0, 2 do
            local a = (i / 3) * math.pi * 2
            love.graphics.line(baseX + 27, 0, baseX + 27 + math.cos(a) * 3, math.sin(a) * 3)
        end
        -- Targeting laser dot emanating forward
        love.graphics.setColor(1, 0.2, 0.2, 0.5 + math.sin(t * 6) * 0.3)
        love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 30, 0, baseX + 46, math.sin(t * 3) * 2)
        love.graphics.setColor(1, 0.3, 0.3, 0.9)
        love.graphics.circle("fill", baseX + 46, math.sin(t * 3) * 2, 1.2)
    elseif style == "crossbow" then
        -- Bow + horizontal bolt
        love.graphics.setColor(0.35, 0.22, 0.1)
        love.graphics.setLineWidth(3)
        love.graphics.line(baseX + 2, -10, baseX + 2, 10)
        love.graphics.arc("line", "open", baseX, 0, 12, -math.pi * 0.4, math.pi * 0.4)
        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.line(baseX - 6, -8, baseX + 2, 0)
        love.graphics.line(baseX - 6, 8, baseX + 2, 0)
        love.graphics.setColor(0.7, 0.6, 0.3)
        love.graphics.rectangle("fill", baseX, -0.8, 24, 1.6)
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.polygon("fill", baseX + 24, -2, baseX + 28, 0, baseX + 24, 2)
        love.graphics.setLineWidth(1)
    elseif style == "musket" then
        -- Long flintlock with wooden stock and brass fittings
        love.graphics.setColor(0.3, 0.18, 0.05)
        love.graphics.rectangle("fill", baseX - 4, -3, 12, 6)
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.rectangle("fill", baseX + 8, -1.5, 26, 3)
        love.graphics.setColor(0.85, 0.65, 0.25)
        love.graphics.rectangle("fill", baseX + 6, -2.5, 3, 5)
        love.graphics.rectangle("fill", baseX + 33, -2, 2, 4)
    elseif style == "void_spear" then
        -- Plain thin dark-gray shaft with a sharp point at the tip.
        love.graphics.setColor(0.32, 0.32, 0.34)
        love.graphics.setLineWidth(2)
        love.graphics.line(baseX - 2, 0, baseX + 60, 0)
        love.graphics.polygon("fill", baseX + 58, -2, baseX + 70, 0, baseX + 58, 2)
        love.graphics.setLineWidth(1)
    elseif style == "reality_bend" then
        -- Purple eldritch counterpart to telekinesis: violet particles, runic
        -- glyphs floating in orbit, plus an occasional reality tear.
        local t = love.timer.getTime()
        -- Faint warp tear (flashing crack)
        local tearA = math.max(0, math.sin(t * 0.9)) * 0.55
        love.graphics.setColor(0.75, 0.3, 1, tearA)
        love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 4, -8, baseX + 7, -4, baseX + 5, 0, baseX + 8, 3, baseX + 6, 8)
        -- 16 small violet sparkles orbiting
        for i = 1, 16 do
            local a = t * 1.4 + i * 0.52
            local rr = 7 + ((i * 3) % 14) + math.sin(t * 2 + i) * 2
            local px = baseX + 8 + math.cos(a) * rr
            local py = math.sin(a) * rr * 0.9
            local alpha = 0.4 + 0.5 * math.sin(t * 4 + i * 0.7)
            love.graphics.setColor(0.75, 0.4, 1, alpha)
            love.graphics.circle("fill", px, py, 1)
        end
        -- A few floating runic glyphs on slow orbit
        local glyphs = {"*", "+", "x", "#"}
        for i = 0, 3 do
            local a = t * 0.8 + i * (math.pi / 2)
            local rr = 16 + math.sin(t + i) * 3
            local gx = baseX + 8 + math.cos(a) * rr
            local gy = math.sin(a) * rr * 0.9
            love.graphics.setColor(0.9, 0.55, 1, 0.85)
            love.graphics.print(glyphs[i + 1], gx - 3, gy - 5)
        end
        -- Brighter drift motes outward
        for i = 0, 5 do
            local drift = ((t * 0.9) + i / 6) % 1
            local dist = 6 + drift * 30
            local ang = i * (math.pi / 3) + t * 0.5
            local px = baseX + 8 + math.cos(ang) * dist
            local py = math.sin(ang) * dist * 0.9
            local alpha = (1 - drift) * 0.85
            love.graphics.setColor(1, 0.7, 1, alpha)
            love.graphics.circle("fill", px, py, 1)
            love.graphics.setColor(0.6, 0.25, 0.9, alpha * 0.55)
            love.graphics.circle("fill", px, py, 2.4)
        end
    elseif style == "telekinesis" then
        -- No held object — just drifting magical particles orbiting the claw.
        local t = love.timer.getTime()
        -- Scattered orbiting sparkles
        for i = 1, 18 do
            local a = t * 1.6 + i * 0.45
            local rr = 8 + ((i * 3) % 14) + math.sin(t * 2 + i) * 2
            local px = baseX + 8 + math.cos(a) * rr
            local py = math.sin(a) * rr * 0.9
            local alpha = 0.4 + 0.5 * math.sin(t * 4 + i * 0.7)
            if alpha > 0 then
                love.graphics.setColor(0.6, 0.85, 1, alpha)
                love.graphics.circle("fill", px, py, 1)
            end
        end
        -- A few brighter motes that drift outward then fade
        for i = 0, 5 do
            local drift = ((t * 0.9) + i / 6) % 1
            local dist = 6 + drift * 30
            local ang = i * (math.pi / 3) + t * 0.5
            local px = baseX + 8 + math.cos(ang) * dist
            local py = math.sin(ang) * dist * 0.9
            local alpha = (1 - drift) * 0.8
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.circle("fill", px, py, 0.9)
            love.graphics.setColor(0.55, 0.8, 1, alpha * 0.5)
            love.graphics.circle("fill", px, py, 2.2)
        end
    elseif style == "dark_magic" then
        -- Dark Magic staff: blackened shaft with grip wraps, a pulsing violet
        -- orb at the tip, floating runic sigils and a spectral glow.
        local t = love.timer.getTime()
        -- Grip wrap
        love.graphics.setColor(0.18, 0.10, 0.20)
        love.graphics.rectangle("fill", baseX - 3, -3, 10, 6)
        for gx = baseX - 2, baseX + 5, 2 do
            love.graphics.setColor(0.55, 0.25, 0.75)
            love.graphics.line(gx, -3, gx, 3)
        end
        -- Shaft (black with subtle violet sheen)
        love.graphics.setColor(0.05, 0.03, 0.08)
        love.graphics.setLineWidth(4)
        love.graphics.line(baseX + 6, 0, baseX + 26, 0)
        love.graphics.setColor(0.25, 0.1, 0.35)
        love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 6, -1.2, baseX + 26, -1.2)
        love.graphics.line(baseX + 6, 1.2, baseX + 26, 1.2)
        -- Prongs around the orb
        love.graphics.setColor(0.08, 0.04, 0.12)
        love.graphics.setLineWidth(3)
        love.graphics.line(baseX + 26, 0, baseX + 30, -8)
        love.graphics.line(baseX + 26, 0, baseX + 30,  8)
        love.graphics.line(baseX + 26, 0, baseX + 34, -5)
        love.graphics.line(baseX + 26, 0, baseX + 34,  5)
        love.graphics.setLineWidth(1)
        -- Pulsing violet orb at the head
        local pulse = 0.75 + math.sin(t * 3) * 0.25
        love.graphics.setColor(0.55, 0.15, 0.85, 0.35)
        love.graphics.circle("fill", baseX + 30, 0, 10 * pulse)
        love.graphics.setColor(0.75, 0.35, 1, 0.85)
        love.graphics.circle("fill", baseX + 30, 0, 6)
        love.graphics.setColor(1, 0.85, 0.3, 0.95)
        love.graphics.circle("fill", baseX + 30, 0, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", baseX + 30, 0, 1.2)
        -- Floating runic sigils orbiting the orb
        for i = 0, 2 do
            local a = t * 2 + i * (math.pi * 2 / 3)
            local rx = baseX + 30 + math.cos(a) * 14
            local ry = 0 + math.sin(a) * 9
            love.graphics.setColor(0.85, 0.45, 1, 0.8)
            love.graphics.print(({"*","+","x"})[i + 1], rx, ry - 4)
        end
        -- Wisp trail coming off the shaft
        for i = 1, 3 do
            local a = t * 4 + i
            love.graphics.setColor(0.55, 0.2, 0.8, 0.5)
            love.graphics.circle("fill",
                baseX + 10 + math.sin(a) * 2,
                math.cos(a) * 4,
                1.2)
        end
    elseif style == "nailgun" then
        -- Pneumatic nailgun: angular yellow body + pressure hose + vertical nail
        -- clip with individual nails + compressor dial.
        local t = love.timer.getTime()
        -- Main body (angular)
        love.graphics.setColor(0.85, 0.75, 0.12)
        love.graphics.polygon("fill", baseX, -4, baseX + 22, -4, baseX + 24, -2, baseX + 24, 3, baseX, 3)
        love.graphics.setColor(0.45, 0.4, 0.05)
        love.graphics.polygon("line", baseX, -4, baseX + 22, -4, baseX + 24, -2, baseX + 24, 3, baseX, 3)
        -- Black grip wrap
        love.graphics.setColor(0.08, 0.08, 0.1)
        love.graphics.rectangle("fill", baseX + 2, -3, 6, 5)
        -- Compressor dial (rotating)
        love.graphics.setColor(0.15, 0.13, 0.08)
        love.graphics.circle("fill", baseX + 11, -1, 3.5)
        love.graphics.setColor(0.85, 0.7, 0.15)
        love.graphics.circle("line", baseX + 11, -1, 3.5)
        local rot = t * 4
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.line(baseX + 11, -1, baseX + 11 + math.cos(rot) * 3, -1 + math.sin(rot) * 3)
        -- Pressure hose (curvy) trailing to the back
        love.graphics.setColor(0.15, 0.15, 0.18)
        love.graphics.setLineWidth(2.5)
        love.graphics.line(baseX - 2, 3, baseX - 5, 6, baseX - 2, 9, baseX - 6, 11)
        love.graphics.setLineWidth(1)
        -- Vertical nail magazine (under body, tall)
        love.graphics.setColor(0.2, 0.18, 0.12)
        love.graphics.rectangle("fill", baseX + 4, 3, 12, 10)
        love.graphics.setColor(0.6, 0.55, 0.1)
        love.graphics.rectangle("line", baseX + 4, 3, 12, 10)
        -- Individual nails (silver, pointed heads)
        love.graphics.setColor(0.88, 0.88, 0.92)
        for i = 0, 5 do
            local nx = baseX + 5.5 + i * 1.7
            love.graphics.line(nx, 5, nx, 12)
            love.graphics.circle("fill", nx, 4.5, 0.7)
        end
        -- Chunky muzzle punch
        love.graphics.setColor(0.35, 0.35, 0.4)
        love.graphics.rectangle("fill", baseX + 24, -3, 5, 5)
        love.graphics.setColor(0.08, 0.08, 0.1)
        love.graphics.rectangle("fill", baseX + 27, -2, 2, 3)
    elseif style == "handcannon" then
        -- Massive revolver-pistol with dragon-head muzzle + filigree
        local t = love.timer.getTime()
        -- Grip wrap (checkered)
        love.graphics.setColor(0.22, 0.14, 0.08)
        love.graphics.rectangle("fill", baseX - 4, -3, 8, 7)
        love.graphics.setColor(0.35, 0.22, 0.12)
        for i = 0, 3 do
            love.graphics.line(baseX - 3 + i * 2, -3, baseX - 3 + i * 2, 4)
        end
        -- Body (dark steel with gold inlay)
        love.graphics.setColor(0.18, 0.15, 0.2)
        love.graphics.rectangle("fill", baseX + 2, -5, 22, 10)
        love.graphics.setColor(0.35, 0.3, 0.4)
        love.graphics.rectangle("line", baseX + 2, -5, 22, 10)
        love.graphics.setColor(0.95, 0.75, 0.15)
        love.graphics.rectangle("fill", baseX + 4, -1, 18, 2)
        -- Cylinder drum (with 6 chambers)
        love.graphics.setColor(0.25, 0.22, 0.28)
        love.graphics.circle("fill", baseX + 8, 0, 6)
        love.graphics.setColor(0.5, 0.45, 0.55)
        love.graphics.circle("line", baseX + 8, 0, 6)
        for i = 0, 5 do
            local a = (i / 6) * math.pi * 2 + t * 0.3
            love.graphics.setColor(0.05, 0.05, 0.08)
            love.graphics.circle("fill", baseX + 8 + math.cos(a) * 3.5, math.sin(a) * 3.5, 1.3)
        end
        -- Dragon-head flared muzzle (teeth + eye)
        love.graphics.setColor(0.3, 0.26, 0.32)
        love.graphics.polygon("fill",
            baseX + 24, -6, baseX + 32, -7,
            baseX + 34, 0,
            baseX + 32, 7, baseX + 24, 6)
        love.graphics.setColor(0.85, 0.8, 0.85)
        -- Teeth (top + bottom row)
        for i = 0, 3 do
            local tx = baseX + 26 + i * 2
            love.graphics.polygon("fill", tx, -5, tx + 1, -3, tx - 1, -3)
            love.graphics.polygon("fill", tx, 5, tx + 1, 3, tx - 1, 3)
        end
        -- Dragon eye (glowing)
        local eyePulse = 0.7 + math.sin(t * 5) * 0.3
        love.graphics.setColor(1, 0.3, 0.1, eyePulse)
        love.graphics.circle("fill", baseX + 28, -4, 1.3)
        love.graphics.setColor(1, 1, 0.8, 1)
        love.graphics.circle("fill", baseX + 28, -4, 0.5)
        -- Black bore
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("fill", baseX + 32, 0, 2.5)
    elseif style == "sniper" then
        -- Long bolt-action rifle with brass bolt, massive scope, muzzle brake,
        -- bipod, and a live reticle.
        local t = love.timer.getTime()
        -- Wooden stock with grip curve
        love.graphics.setColor(0.32, 0.2, 0.1)
        love.graphics.polygon("fill", baseX - 8, -3, baseX + 6, -3, baseX + 6, 3, baseX - 8, 4, baseX - 6, 1)
        love.graphics.setColor(0.45, 0.28, 0.12)
        love.graphics.polygon("line", baseX - 8, -3, baseX + 6, -3, baseX + 6, 3, baseX - 8, 4, baseX - 6, 1)
        -- Receiver body
        love.graphics.setColor(0.12, 0.1, 0.14)
        love.graphics.rectangle("fill", baseX + 6, -3, 12, 5)
        -- Brass bolt handle
        love.graphics.setColor(0.85, 0.65, 0.15)
        love.graphics.rectangle("fill", baseX + 10, -6, 3, 4)
        love.graphics.circle("fill", baseX + 11.5, -7, 1.8)
        -- Long thin barrel
        love.graphics.setColor(0.18, 0.18, 0.22)
        love.graphics.rectangle("fill", baseX + 18, -1.2, 38, 2.4)
        -- Muzzle brake
        love.graphics.setColor(0.35, 0.35, 0.4)
        love.graphics.rectangle("fill", baseX + 54, -2.5, 4, 5)
        love.graphics.setColor(0.1, 0.1, 0.12)
        for i = 0, 2 do
            love.graphics.rectangle("fill", baseX + 55, -2 + i * 1.5, 2, 0.6)
        end
        -- Big scope (body + mounts + lens)
        love.graphics.setColor(0.15, 0.15, 0.18)
        love.graphics.rectangle("fill", baseX + 14, -6, 4, 3) -- rear mount
        love.graphics.rectangle("fill", baseX + 26, -6, 4, 3) -- front mount
        love.graphics.setColor(0.22, 0.22, 0.26)
        love.graphics.rectangle("fill", baseX + 13, -9, 18, 4)
        love.graphics.setColor(0.4, 0.4, 0.48)
        love.graphics.rectangle("line", baseX + 13, -9, 18, 4)
        -- Scope lenses with animated reticle
        love.graphics.setColor(0.05, 0.6, 0.9, 0.9)
        love.graphics.circle("fill", baseX + 14, -7, 2)
        love.graphics.circle("fill", baseX + 30, -7, 2.5)
        love.graphics.setColor(0.4, 0.95, 1, 1)
        love.graphics.circle("fill", baseX + 30, -7, 1.5)
        love.graphics.setColor(1, 0.2, 0.2, 0.9)
        love.graphics.line(baseX + 28, -7, baseX + 32, -7)
        love.graphics.line(baseX + 30, -9, baseX + 30, -5)
        love.graphics.circle("line", baseX + 30, -7, 1)
        -- Bipod legs
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(baseX + 34, 1, baseX + 30, 8)
        love.graphics.line(baseX + 34, 1, baseX + 38, 8)
        love.graphics.setLineWidth(1)
    elseif style == "glauncher" then
        -- Revolver-style grenade launcher with big drum, trigger assembly,
        -- folding stock, and visible 40mm grenade in each chamber.
        local t = love.timer.getTime()
        -- Folding stock
        love.graphics.setColor(0.2, 0.2, 0.22)
        love.graphics.setLineWidth(2)
        love.graphics.line(baseX - 6, -2, baseX - 2, -2)
        love.graphics.line(baseX - 6, 2, baseX - 2, 2)
        love.graphics.line(baseX - 6, -2, baseX - 6, 2)
        love.graphics.setLineWidth(1)
        -- Receiver
        love.graphics.setColor(0.15, 0.18, 0.12)
        love.graphics.rectangle("fill", baseX - 2, -3, 6, 6)
        -- Big rotating drum magazine
        love.graphics.setColor(0.22, 0.2, 0.24)
        love.graphics.circle("fill", baseX + 5, 0, 9)
        love.graphics.setColor(0.4, 0.4, 0.45)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", baseX + 5, 0, 9)
        love.graphics.setLineWidth(1)
        local rot = t * 1.2
        for i = 0, 5 do
            local a = rot + (i / 6) * math.pi * 2
            local cx = baseX + 5 + math.cos(a) * 5.5
            local cy = math.sin(a) * 5.5
            -- Grenade in chamber
            love.graphics.setColor(0.15, 0.35, 0.12)
            love.graphics.circle("fill", cx, cy, 2)
            love.graphics.setColor(0.85, 0.65, 0.2)
            love.graphics.circle("line", cx, cy, 2)
            love.graphics.setColor(0.9, 0.8, 0.2)
            love.graphics.circle("fill", cx, cy, 0.6)
        end
        -- Central pivot
        love.graphics.setColor(0.1, 0.1, 0.12)
        love.graphics.circle("fill", baseX + 5, 0, 1.5)
        -- Fat barrel
        love.graphics.setColor(0.18, 0.22, 0.14)
        love.graphics.rectangle("fill", baseX + 14, -4, 14, 8)
        love.graphics.setColor(0.35, 0.4, 0.22)
        love.graphics.rectangle("line", baseX + 14, -4, 14, 8)
        -- Thick muzzle ring
        love.graphics.setColor(0.12, 0.12, 0.14)
        love.graphics.circle("fill", baseX + 28, 0, 4.5)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", baseX + 28, 0, 3)
        -- Trigger guard
        love.graphics.setColor(0.2, 0.2, 0.22)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", baseX + 2, 4, 3, 0, math.pi)
        love.graphics.setLineWidth(1)
    elseif style == "plasma" then
        -- Heavy plasma cannon: tesla coils wrapping the barrel, superheated
        -- plasma chamber with swirling particles, vents with escaping steam.
        local t = love.timer.getTime()
        -- Shoulder strut
        love.graphics.setColor(0.08, 0.1, 0.18)
        love.graphics.rectangle("fill", baseX - 5, -4, 6, 8)
        -- Main body
        love.graphics.setColor(0.1, 0.14, 0.26)
        love.graphics.rectangle("fill", baseX + 1, -7, 30, 14)
        love.graphics.setColor(0.25, 0.45, 0.85)
        love.graphics.rectangle("line", baseX + 1, -7, 30, 14)
        -- Plasma chamber window
        love.graphics.setColor(0, 0, 0.05)
        love.graphics.rectangle("fill", baseX + 4, -5, 12, 10)
        -- Swirling plasma inside
        for i = 1, 12 do
            local a = t * 3 + i * 0.6
            local r = 4 * math.abs(math.sin(t * 2 + i))
            local cx = baseX + 10 + math.cos(a) * r
            local cy = math.sin(a) * r * 0.6
            love.graphics.setColor(0.3, 0.75, 1, 0.85)
            love.graphics.circle("fill", cx, cy, 0.8)
            love.graphics.setColor(0.95, 1, 1, 0.9)
            love.graphics.circle("fill", cx, cy, 0.35)
        end
        love.graphics.setColor(0.6, 0.85, 1, 0.15)
        love.graphics.rectangle("fill", baseX + 4, -5, 12, 10)
        -- Tesla coil rings wrapping the barrel section
        for i = 0, 3 do
            local rx = baseX + 18 + i * 3
            love.graphics.setColor(0.5, 0.3, 0.1)
            love.graphics.ellipse("line", rx, 0, 1.5, 6)
            love.graphics.setColor(0.85, 0.55, 0.15)
            love.graphics.ellipse("line", rx, 0, 1.5, 5)
        end
        -- Crackling arcs between coils
        for i = 0, 2 do
            if math.sin(t * 25 + i * 5) > 0.5 then
                local x1 = baseX + 19 + i * 3
                local x2 = x1 + 3
                love.graphics.setColor(0.6, 0.9, 1, 0.95)
                love.graphics.setLineWidth(1.5)
                love.graphics.line(x1, -3, x1 + 1.5, -5, x2 - 1, -2, x2, -4)
                love.graphics.setLineWidth(1)
            end
        end
        -- Muzzle: superheated emitter cone
        love.graphics.setColor(0.1, 0.15, 0.25)
        love.graphics.polygon("fill", baseX + 31, -5, baseX + 36, -3, baseX + 36, 3, baseX + 31, 5)
        local glow = 0.7 + math.sin(t * 8) * 0.3
        love.graphics.setColor(0.3, 0.6, 1, 0.5 * glow)
        love.graphics.circle("fill", baseX + 36, 0, 7 * glow)
        love.graphics.setColor(0.6, 0.9, 1, 0.9)
        love.graphics.circle("fill", baseX + 36, 0, 3.5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", baseX + 36, 0, 1.5)
        -- Heat vents (top + bottom) releasing color-cycled wisps
        for i = 0, 2 do
            local vx = baseX + 20 + i * 3
            love.graphics.setColor(1, 0.3 + math.sin(t * 6 + i) * 0.2, 0.1, 0.7)
            love.graphics.rectangle("fill", vx, -8, 2, 1.5)
            love.graphics.rectangle("fill", vx, 6.5, 2, 1.5)
            -- Steam wisp rising
            love.graphics.setColor(0.85, 0.9, 1, 0.35 + math.sin(t * 4 + i) * 0.2)
            love.graphics.circle("fill", vx + 1, -10 - math.sin(t * 3 + i) * 2, 1.5)
        end
    elseif style == "lightning_rod" then
        -- Tall rod with glowing tesla coils stacked along it, forked tip,
        -- continuous high-frequency arcing and a huge pulsing corona.
        local t = love.timer.getTime()
        -- Grip base
        love.graphics.setColor(0.18, 0.14, 0.22)
        love.graphics.rectangle("fill", baseX - 4, -3, 8, 6)
        love.graphics.setColor(0.55, 0.3, 0.8)
        love.graphics.rectangle("line", baseX - 4, -3, 8, 6)
        -- Main shaft
        love.graphics.setColor(0.35, 0.35, 0.45)
        love.graphics.setLineWidth(3)
        love.graphics.line(baseX + 4, 0, baseX + 48, 0)
        love.graphics.setColor(0.65, 0.65, 0.75)
        love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 4, -1.2, baseX + 48, -1.2)
        -- Tesla coil stacks along the shaft
        for i = 0, 3 do
            local cx = baseX + 10 + i * 8
            love.graphics.setColor(0.5, 0.3, 0.1)
            love.graphics.ellipse("fill", cx, 0, 2.5, 4)
            love.graphics.setColor(0.85, 0.55, 0.15)
            love.graphics.ellipse("line", cx, 0, 2.5, 4)
            -- Buzzing glow ring
            local glow = 0.5 + math.abs(math.sin(t * 7 + i * 1.3)) * 0.5
            love.graphics.setColor(0.6, 0.85, 1, 0.5 * glow)
            love.graphics.ellipse("line", cx, 0, 3.5 * glow, 5.5 * glow)
        end
        -- Forked tip (trident-style)
        love.graphics.setColor(0.85, 0.88, 0.95)
        love.graphics.polygon("fill", baseX + 48, -1, baseX + 58, 0, baseX + 48, 1)
        love.graphics.setColor(0.6, 0.62, 0.7)
        love.graphics.line(baseX + 46, 0, baseX + 52, -7)
        love.graphics.line(baseX + 46, 0, baseX + 52,  7)
        love.graphics.line(baseX + 50, -5, baseX + 55, -10)
        love.graphics.line(baseX + 50,  5, baseX + 55,  10)
        -- Continuous arcing — stronger, more frequent
        for i = 1, 10 do
            local phase = math.floor(t * 35 + i * 13) % 4
            if phase < 2 then
                local along = 6 + (i * 5) % 42
                local side = ((i % 2 == 0) and 1 or -1)
                local sx = baseX + along
                local sy = 0
                local ex = sx + math.sin(t * 55 + i) * 8
                local ey = side * (4 + math.random() * 9)
                love.graphics.setColor(0.6, 0.9, 1, 0.95)
                love.graphics.setLineWidth(1.5)
                love.graphics.line(sx, sy,
                    (sx + ex) / 2 + math.sin(t * 80 + i) * 3, (sy + ey) / 2 + math.cos(t * 90 + i) * 2,
                    ex, ey)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setLineWidth(0.7)
                love.graphics.line(sx, sy, ex, ey)
            end
        end
        -- Big pulsing corona at the tip
        local pulse = 0.5 + math.sin(t * 10) * 0.5
        for r = 16, 4, -3 do
            love.graphics.setColor(0.5, 0.85, 1, 0.12 * pulse * (1 - r / 16))
            love.graphics.circle("fill", baseX + 56, 0, r * pulse)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
    elseif style == "chainsword" then
        -- Motorized sword with detailed engine housing, exhaust pipe, guard,
        -- scrolling chain teeth, oil drip + sparks from the blade.
        local t = love.timer.getTime()
        -- Grip (wrapped leather)
        love.graphics.setColor(0.3, 0.18, 0.08)
        love.graphics.rectangle("fill", baseX - 5, -3, 11, 6)
        love.graphics.setColor(0.5, 0.3, 0.15)
        for i = 0, 4 do
            love.graphics.line(baseX - 4 + i * 2, -3, baseX - 4 + i * 2, 3)
        end
        -- Engine housing
        love.graphics.setColor(0.12, 0.12, 0.14)
        love.graphics.rectangle("fill", baseX + 6, -6, 10, 12)
        love.graphics.setColor(0.45, 0.45, 0.5)
        love.graphics.rectangle("line", baseX + 6, -6, 10, 12)
        -- Gauge dial (rotating needle)
        love.graphics.setColor(0.18, 0.18, 0.2)
        love.graphics.circle("fill", baseX + 11, -3, 2.5)
        love.graphics.setColor(0.8, 0.8, 0.85)
        love.graphics.circle("line", baseX + 11, -3, 2.5)
        local ang = math.sin(t * 6) * math.pi * 0.4
        love.graphics.setColor(1, 0.3, 0.2)
        love.graphics.line(baseX + 11, -3, baseX + 11 + math.cos(ang - math.pi/2) * 2, -3 + math.sin(ang - math.pi/2) * 2)
        -- Exhaust pipe (curving up + smoke puff)
        love.graphics.setColor(0.3, 0.3, 0.32)
        love.graphics.rectangle("fill", baseX + 8, -9, 2, 3)
        love.graphics.setColor(0.6, 0.6, 0.65, 0.6 + math.sin(t * 4) * 0.3)
        love.graphics.circle("fill", baseX + 9, -11 - math.sin(t * 3) * 1, 1.8)
        -- Gold crossguard
        love.graphics.setColor(0.85, 0.65, 0.2)
        love.graphics.rectangle("fill", baseX + 16, -6, 2, 12)
        love.graphics.setColor(0.55, 0.4, 0.1)
        love.graphics.rectangle("line", baseX + 16, -6, 2, 12)
        -- Blade body (steel with highlight line)
        love.graphics.setColor(0.6, 0.6, 0.65)
        love.graphics.rectangle("fill", baseX + 18, -4, 34, 8)
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.line(baseX + 18, 0, baseX + 52, 0)
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("line", baseX + 18, -4, 34, 8)
        -- Scrolling chain teeth (alternating staggered pattern)
        local off = (t * 80) % 5
        love.graphics.setColor(0.92, 0.92, 0.95)
        for i = 0, 7 do
            local x = baseX + 19 + i * 5 - off
            love.graphics.polygon("fill", x, -4, x + 2.5, -7, x + 5, -4)
            love.graphics.polygon("fill", x + 2.5, 4, x, 7, x + 5, 7)
        end
        -- Blade tip (sharp point)
        love.graphics.setColor(0.75, 0.75, 0.8)
        love.graphics.polygon("fill", baseX + 52, -4, baseX + 58, 0, baseX + 52, 4)
        -- Sparks flying from the blade (random)
        for i = 1, 3 do
            if math.sin(t * 25 + i * 7) > 0.3 then
                local sx = baseX + 22 + (i * 13) % 28
                local sy = (i % 2 == 0) and -6 or 6
                love.graphics.setColor(1, 0.8, 0.3, 0.9)
                love.graphics.circle("fill", sx, sy + math.sin(t * 8 + i) * 1, 0.9)
            end
        end
    elseif style == "quantum" then
        -- Phase-shifting pistol with strong chromatic offset, probability cloud,
        -- schrodinger-box housing, wave function particles.
        local t = love.timer.getTime()
        local phase1 = math.sin(t * 7) * 4
        local phase2 = math.cos(t * 9) * 4
        -- Probability cloud halo behind the gun
        for r = 14, 6, -2 do
            love.graphics.setColor(0.6, 0.3, 1, 0.08 * (1 - r / 14))
            love.graphics.circle("fill", baseX + 12, 0, r)
        end
        -- Ghost copy 1 (violet, offset up)
        love.graphics.setColor(0.5, 0.2, 1, 0.5)
        love.graphics.rectangle("fill", baseX + 1, -3 + phase1, 24, 6, 1, 1)
        love.graphics.setColor(0.7, 0.4, 1, 0.7)
        love.graphics.rectangle("line", baseX + 1, -3 + phase1, 24, 6, 1, 1)
        -- Ghost copy 2 (cyan, offset down)
        love.graphics.setColor(0.3, 0.8, 1, 0.5)
        love.graphics.rectangle("fill", baseX + 1, -3 + phase2, 24, 6, 1, 1)
        love.graphics.setColor(0.4, 0.95, 1, 0.7)
        love.graphics.rectangle("line", baseX + 1, -3 + phase2, 24, 6, 1, 1)
        -- Core body (the "observed" solid copy)
        love.graphics.setColor(0.15, 0.1, 0.22, 1)
        love.graphics.rectangle("fill", baseX, -3, 26, 6, 1, 1)
        love.graphics.setColor(0.75, 0.55, 1, 1)
        love.graphics.rectangle("line", baseX, -3, 26, 6, 1, 1)
        -- Schrödinger chamber window (center)
        love.graphics.setColor(0.05, 0.05, 0.1)
        love.graphics.rectangle("fill", baseX + 8, -2, 6, 4)
        love.graphics.setColor(0.6, 0.9, 1, 0.9)
        love.graphics.circle("fill", baseX + 11 + math.sin(t * 18) * 1.5, math.cos(t * 14) * 1, 1)
        -- Wave-function lines leaving the muzzle
        for i = 1, 4 do
            local wave = math.sin(t * 10 + i) * 2
            local col = (i % 2 == 0) and {0.4, 0.9, 1, 0.8} or {0.7, 0.4, 1, 0.8}
            love.graphics.setColor(col[1], col[2], col[3], col[4])
            love.graphics.setLineWidth(1.2)
            love.graphics.line(
                baseX + 26, 0,
                baseX + 30 + wave, (i - 2.5) * 1.5,
                baseX + 34, (i - 2.5) * 2 + math.sin(t * 12 + i) * 1.5)
        end
        love.graphics.setLineWidth(1)
        -- Pulsing phase core at muzzle tip
        local pulse = 0.7 + math.sin(t * 15) * 0.3
        for r = 6, 2, -1 do
            love.graphics.setColor(0.6, 0.3, 1, 0.2 * (1 - r / 6))
            love.graphics.circle("fill", baseX + 27, 0, r * pulse * 1.5)
        end
        love.graphics.setColor(0.95, 0.95, 1, 1)
        love.graphics.circle("fill", baseX + 27, 0, 1.8)
        -- Probability-cloud flickers around the barrel
        for i = 1, 10 do
            local a = t * 4 + i * 0.7
            local alive = math.sin(t * 22 + i * 11) * 0.5 + 0.5
            if alive > 0.5 then
                local cr = (i % 2 == 0) and 0.4 or 0.2
                local cg = (i % 3 == 0) and 0.9 or 0.5
                local cb = 1
                love.graphics.setColor(cr, cg, cb, alive * 0.9)
                love.graphics.circle("fill",
                    baseX + 13 + math.cos(a) * 9, math.sin(a) * 5, 0.8)
            end
        end
    -- NEW mid-tier guns: hard-to-get but not very-hard.
    elseif style == "flamethrower" then
        -- Tank-fed flamethrower with pilot light + rolling flame jet
        local t = love.timer.getTime()
        -- Twin fuel tanks on the back
        love.graphics.setColor(0.45, 0.15, 0.1)
        love.graphics.rectangle("fill", baseX - 8, -5, 5, 11)
        love.graphics.setColor(0.6, 0.2, 0.15)
        love.graphics.rectangle("line", baseX - 8, -5, 5, 11)
        love.graphics.setColor(0.9, 0.85, 0.3)
        love.graphics.print("F", baseX - 7, -4)
        -- Hose
        love.graphics.setColor(0.15, 0.15, 0.18)
        love.graphics.setLineWidth(2)
        love.graphics.line(baseX - 3, 0, baseX, 0)
        love.graphics.setLineWidth(1)
        -- Gun body
        love.graphics.setColor(0.22, 0.18, 0.18)
        love.graphics.rectangle("fill", baseX, -3, 18, 6)
        love.graphics.setColor(0.5, 0.3, 0.2)
        love.graphics.rectangle("line", baseX, -3, 18, 6)
        -- Pilot light (small flame at the tip, continuous)
        love.graphics.setColor(0.9, 0.5, 0.1, 0.9)
        love.graphics.circle("fill", baseX + 22, 0, 2 + math.sin(t * 10) * 0.5)
        love.graphics.setColor(1, 0.85, 0.3, 1)
        love.graphics.circle("fill", baseX + 22, 0, 1)
        -- Rolling flame jet out the muzzle
        for i = 1, 18 do
            local f = ((t * 3 + i * 0.17) % 1)
            local x = baseX + 24 + f * 38
            local y = math.sin(t * 6 + i) * (3 + f * 4)
            local r = (1 - f) * 4
            local col = (f < 0.5) and {1, 0.9, 0.3} or {1, 0.45, 0.1}
            love.graphics.setColor(col[1], col[2], col[3], (1 - f) * 0.85)
            love.graphics.circle("fill", x, y, r)
        end
    elseif style == "sawedoff" then
        -- Short double-barrel shotgun with tape-wrapped grip + hammer
        love.graphics.setColor(0.22, 0.14, 0.08)
        love.graphics.rectangle("fill", baseX - 4, -3, 10, 6)
        -- Tape wrap
        love.graphics.setColor(0.6, 0.55, 0.35)
        for i = 0, 3 do
            love.graphics.rectangle("fill", baseX - 3 + i * 2.5, -3, 1, 6)
        end
        -- Double barrels (over/under)
        love.graphics.setColor(0.18, 0.18, 0.22)
        love.graphics.rectangle("fill", baseX + 6, -4, 16, 3)
        love.graphics.rectangle("fill", baseX + 6, 1, 16, 3)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", baseX + 6, -4, 16, 3)
        love.graphics.rectangle("line", baseX + 6, 1, 16, 3)
        -- Black bores
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", baseX + 22, -2.5, 1.2)
        love.graphics.circle("fill", baseX + 22, 2.5, 1.2)
        -- External hammer
        love.graphics.setColor(0.35, 0.28, 0.15)
        love.graphics.polygon("fill", baseX + 4, -4, baseX + 7, -7, baseX + 7, -4)
    elseif style == "gatling" then
        -- Hand-held gatling gun: spinning multi-barrel cluster with brass box
        local t = love.timer.getTime()
        -- Brass ammo box under
        love.graphics.setColor(0.85, 0.65, 0.2)
        love.graphics.rectangle("fill", baseX - 4, 3, 16, 8)
        love.graphics.setColor(0.55, 0.4, 0.1)
        love.graphics.rectangle("line", baseX - 4, 3, 16, 8)
        for i = 0, 4 do
            love.graphics.rectangle("fill", baseX - 3 + i * 3, 4, 1, 2)
        end
        -- Ammo belt feed
        love.graphics.setColor(0.8, 0.7, 0.2)
        love.graphics.line(baseX + 4, 3, baseX + 10, 0)
        -- Body housing
        love.graphics.setColor(0.25, 0.22, 0.28)
        love.graphics.rectangle("fill", baseX, -5, 14, 10)
        love.graphics.setColor(0.5, 0.45, 0.55)
        love.graphics.rectangle("line", baseX, -5, 14, 10)
        -- Spinning barrel cluster (6 barrels in a circle, rotating)
        local rot = t * 20
        love.graphics.setColor(0.15, 0.15, 0.18)
        love.graphics.rectangle("fill", baseX + 14, -5, 22, 10)
        for i = 0, 5 do
            local a = rot + (i / 6) * math.pi * 2
            local cy = math.sin(a) * 3
            love.graphics.setColor(0.35, 0.35, 0.4)
            love.graphics.rectangle("fill", baseX + 14, cy - 0.8, 22, 1.6)
        end
        -- Front ring
        love.graphics.setColor(0.5, 0.5, 0.55)
        love.graphics.circle("line", baseX + 36, 0, 4.5)
        love.graphics.setColor(0.08, 0.08, 0.1)
        love.graphics.circle("fill", baseX + 36, 0, 3.5)
        -- Muzzle flash — only when the player is actually firing. Faster
        -- flicker than before (was t*40 / t*60 → now t*90 / t*140).
        local firing = love.mouse.isDown(1) and not self.disabled and not self.laserActive
        if firing and math.sin(t * 90) > 0.2 then
            love.graphics.setColor(1, 0.8, 0.3, 0.9)
            love.graphics.circle("fill", baseX + 38, 0, 3 + math.sin(t * 140) * 1)
            love.graphics.setColor(1, 1, 0.8, 1)
            love.graphics.circle("fill", baseX + 38, 0, 1.5)
        end
    elseif style == "icegun" then
        -- Frost cannon: crystal-tipped, frosted chamber, drifting snowflakes
        local t = love.timer.getTime()
        -- Body (pale blue steel)
        love.graphics.setColor(0.6, 0.8, 0.95)
        love.graphics.rectangle("fill", baseX, -4, 22, 8)
        love.graphics.setColor(0.25, 0.4, 0.55)
        love.graphics.rectangle("line", baseX, -4, 22, 8)
        -- Frozen coolant chamber (frosted)
        love.graphics.setColor(0.85, 0.95, 1, 0.85)
        love.graphics.rectangle("fill", baseX + 3, -3, 8, 6)
        love.graphics.setColor(0.4, 0.6, 0.85)
        love.graphics.rectangle("line", baseX + 3, -3, 8, 6)
        -- Ice crystal growths on body
        love.graphics.setColor(0.9, 0.98, 1, 0.9)
        love.graphics.polygon("fill", baseX + 14, -5, baseX + 16, -7, baseX + 18, -5)
        love.graphics.polygon("fill", baseX + 13, 4, baseX + 15, 6, baseX + 17, 4)
        -- Crystal muzzle (big, faceted)
        love.graphics.setColor(0.75, 0.9, 1, 0.95)
        love.graphics.polygon("fill",
            baseX + 22, -5, baseX + 30, -4, baseX + 32, 0,
            baseX + 30, 4, baseX + 22, 5)
        love.graphics.setColor(0.4, 0.6, 0.85)
        love.graphics.polygon("line",
            baseX + 22, -5, baseX + 30, -4, baseX + 32, 0,
            baseX + 30, 4, baseX + 22, 5)
        -- Interior glow
        love.graphics.setColor(0.95, 1, 1, 0.85)
        love.graphics.circle("fill", baseX + 28, 0, 1.5 + math.sin(t * 4) * 0.5)
        -- Drifting snowflakes around the muzzle
        for i = 1, 6 do
            local f = ((t * 0.7 + i / 6) % 1)
            local sx = baseX + 30 + f * 18
            local sy = math.sin(t + i) * 5
            local a = (1 - f) * 0.9
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.circle("fill", sx, sy, 1 - f * 0.5)
            -- Tiny snowflake cross
            love.graphics.line(sx - 1.5, sy, sx + 1.5, sy)
            love.graphics.line(sx, sy - 1.5, sx, sy + 1.5)
        end
    elseif style == "scythe" then
        -- Proper reaper's scythe: long wooden snath with grip wraps, metal
        -- attachment collar, and a BIG curved crescent blade (crescent shape
        -- is split into an outer-body polygon + an inner-hook polygon since
        -- LÖVE polygons must be convex). Glowing green cutting edge on the
        -- inside of the crescent, with drip wisps off the blade point.
        local t = love.timer.getTime()
        -- Long wooden snath
        love.graphics.setColor(0.35, 0.22, 0.1)
        love.graphics.setLineWidth(4)
        love.graphics.line(baseX - 4, 0, baseX + 50, 0)
        love.graphics.setColor(0.55, 0.36, 0.16)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(baseX - 4, -1.2, baseX + 50, -1.2)
        love.graphics.setLineWidth(1)
        -- Grip wraps (leather bindings with gold stitching)
        for _, wx in ipairs({baseX + 4, baseX + 22, baseX + 40}) do
            love.graphics.setColor(0.1, 0.06, 0.04)
            love.graphics.rectangle("fill", wx, -2.5, 3, 5)
            love.graphics.setColor(0.85, 0.65, 0.2)
            love.graphics.line(wx + 1, -2.5, wx + 1, 2.5)
        end
        -- Metal collar where the blade attaches
        love.graphics.setColor(0.3, 0.3, 0.36)
        love.graphics.rectangle("fill", baseX + 46, -3.5, 7, 7)
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.rectangle("line", baseX + 46, -3.5, 7, 7)
        love.graphics.setColor(0.1, 0.08, 0.12)
        love.graphics.line(baseX + 49, -3.5, baseX + 49, 3.5)

        -- BLADE: crescent split into two convex halves.
        -- Half 1 — outer body (rising from the collar, arcing to the tip)
        love.graphics.setColor(0.14, 0.1, 0.18)
        love.graphics.polygon("fill",
            baseX + 53, -2,
            baseX + 56, -12,
            baseX + 64, -22,
            baseX + 78, -28,
            baseX + 94, -26,
            baseX + 100, -18,
            baseX + 96, -10,
            baseX + 82, -12,
            baseX + 66, -10,
            baseX + 54, -4)
        -- Half 2 — inner hook (the curl on the underside, convex)
        love.graphics.polygon("fill",
            baseX + 54, -4,
            baseX + 66, -10,
            baseX + 82, -12,
            baseX + 96, -10,
            baseX + 96, -6,
            baseX + 82, -6,
            baseX + 66, -4,
            baseX + 54, 0)
        -- Blade outline (dark violet)
        love.graphics.setColor(0.04, 0.02, 0.08)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(
            baseX + 53, -2,
            baseX + 56, -12,
            baseX + 64, -22,
            baseX + 78, -28,
            baseX + 94, -26,
            baseX + 100, -18,
            baseX + 96, -10,
            baseX + 96, -6)
        love.graphics.line(
            baseX + 96, -6,
            baseX + 82, -6,
            baseX + 66, -4,
            baseX + 54, 0)
        love.graphics.setLineWidth(1)

        -- Steel highlight along the blade spine
        love.graphics.setColor(0.42, 0.38, 0.48)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(
            baseX + 58, -14,
            baseX + 68, -22,
            baseX + 82, -26,
            baseX + 94, -24,
            baseX + 98, -18)
        love.graphics.setLineWidth(1)

        -- Glowing green CUTTING EDGE along the inner curve
        local glow = 0.8 + math.sin(t * 5) * 0.2
        love.graphics.setColor(0.3, 1, 0.5, glow)
        love.graphics.setLineWidth(2.2)
        love.graphics.line(
            baseX + 54, -4,
            baseX + 66, -8,
            baseX + 80, -10,
            baseX + 94, -8,
            baseX + 96, -6)
        love.graphics.setColor(1, 1, 0.9, glow * 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.line(
            baseX + 54, -4,
            baseX + 66, -8,
            baseX + 80, -10,
            baseX + 94, -8)

        -- Small rune etched into the blade body
        love.graphics.setColor(0.3, 1, 0.5, 0.5 + math.sin(t * 3) * 0.3)
        love.graphics.circle("line", baseX + 78, -18, 2.2)
        love.graphics.line(baseX + 76, -18, baseX + 80, -18)
        love.graphics.line(baseX + 78, -20, baseX + 78, -16)

        -- Drip wisps trailing off the blade point
        for i = 0, 4 do
            local f = ((t * 0.8 + i * 0.2) % 1)
            love.graphics.setColor(0.3, 1, 0.4, (1 - f) * 0.7)
            love.graphics.circle("fill", baseX + 98 + f * 3, -18 + f * 18, 2 - f * 1.3)
        end
    else
        -- fallback (same as pistol)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", baseX, -3, 22, 6)
    end
end

function Player:_drawClaws(body, deep, style)
    style = style or "normal"
    if style == "crystal" then
        love.graphics.setColor(0.4, 0.7, 1)
        love.graphics.polygon("fill", self.r+4, -14, self.r+13, -8, self.r+4, 0, self.r-4, -8)
        love.graphics.polygon("fill", self.r+4, 14, self.r+13, 8, self.r+4, 0, self.r-4, 8)
        love.graphics.setColor(0.15, 0.3, 0.6)
        love.graphics.polygon("line", self.r+4, -14, self.r+13, -8, self.r+4, 0, self.r-4, -8)
        love.graphics.polygon("line", self.r+4, 14, self.r+13, 8, self.r+4, 0, self.r-4, 8)
    elseif style == "cursed" then
        love.graphics.setColor(0.55, 0.15, 0.8)
        love.graphics.circle("fill", self.r + 4, -8, 9)
        love.graphics.circle("fill", self.r + 4, 8, 9)
        love.graphics.setColor(0.2, 0.05, 0.3)
        love.graphics.circle("line", self.r + 4, -8, 9)
        love.graphics.circle("line", self.r + 4, 8, 9)
        -- eldritch tendril wisps
        local t = love.timer.getTime()
        love.graphics.setColor(0.8, 0.4, 1, 0.6)
        love.graphics.line(self.r+10, -8, self.r+16, -10 + math.sin(t*3)*3)
        love.graphics.line(self.r+10, 8, self.r+16, 10 + math.cos(t*3)*3)
    elseif style == "molten" then
        local t = love.timer.getTime()
        local pulse = 0.8 + math.sin(t * 5) * 0.2
        love.graphics.setColor(1, 0.4 * pulse, 0.1)
        love.graphics.circle("fill", self.r + 4, -8, 9)
        love.graphics.circle("fill", self.r + 4, 8, 9)
        love.graphics.setColor(1, 0.9, 0.3, 0.6)
        love.graphics.circle("fill", self.r + 4, -8, 5)
        love.graphics.circle("fill", self.r + 4, 8, 5)
    elseif style == "spiked" then
        love.graphics.setColor(body)
        love.graphics.circle("fill", self.r + 4, -8, 9)
        love.graphics.circle("fill", self.r + 4, 8, 9)
        love.graphics.setColor(deep)
        love.graphics.circle("line", self.r + 4, -8, 9)
        love.graphics.circle("line", self.r + 4, 8, 9)
        love.graphics.setColor(0.8, 0.8, 0.85)
        for s = -1, 1, 2 do
            love.graphics.polygon("fill", self.r + 4, -14 * s - 2 * s, self.r + 10, -8 * s + 1 * s, self.r - 2, -8 * s + 1 * s)
            love.graphics.polygon("fill", self.r + 11, s * -6, self.r + 18, s * -8, self.r + 11, s * -10)
        end
    elseif style == "small" then
        love.graphics.setColor(body)
        love.graphics.circle("fill", self.r + 4, -6, 6)
        love.graphics.circle("fill", self.r + 4, 6, 6)
        love.graphics.setColor(deep)
        love.graphics.circle("line", self.r + 4, -6, 6)
        love.graphics.circle("line", self.r + 4, 6, 6)
    elseif style == "wide" then
        love.graphics.setColor(body)
        love.graphics.ellipse("fill", self.r + 5, -9, 11, 8)
        love.graphics.ellipse("fill", self.r + 5, 9, 11, 8)
        love.graphics.setColor(deep)
        love.graphics.ellipse("line", self.r + 5, -9, 11, 8)
        love.graphics.ellipse("line", self.r + 5, 9, 11, 8)
    elseif style == "leaf" then
        love.graphics.setColor(0.25, 0.7, 0.25)
        love.graphics.polygon("fill", self.r, -12, self.r + 12, -8, self.r + 14, -4, self.r - 2, -4)
        love.graphics.polygon("fill", self.r, 12, self.r + 12, 8, self.r + 14, 4, self.r - 2, 4)
        love.graphics.setColor(0.1, 0.35, 0.1)
        love.graphics.polygon("line", self.r, -12, self.r + 12, -8, self.r + 14, -4, self.r - 2, -4)
        love.graphics.polygon("line", self.r, 12, self.r + 12, 8, self.r + 14, 4, self.r - 2, 4)
    elseif style == "skeletal" then
        love.graphics.setColor(0.9, 0.9, 0.85)
        love.graphics.polygon("fill", self.r, -10, self.r + 14, -8, self.r + 14, -4, self.r, -4)
        love.graphics.polygon("fill", self.r, 10, self.r + 14, 8, self.r + 14, 4, self.r, 4)
        love.graphics.setColor(0.25, 0.2, 0.15)
        love.graphics.polygon("line", self.r, -10, self.r + 14, -8, self.r + 14, -4, self.r, -4)
        love.graphics.polygon("line", self.r, 10, self.r + 14, 8, self.r + 14, 4, self.r, 4)
    elseif style == "chain" then
        love.graphics.setColor(body)
        love.graphics.circle("fill", self.r + 4, -8, 9)
        love.graphics.circle("fill", self.r + 4, 8, 9)
        love.graphics.setColor(deep)
        love.graphics.circle("line", self.r + 4, -8, 9)
        love.graphics.circle("line", self.r + 4, 8, 9)
        love.graphics.setColor(0.45, 0.45, 0.5)
        for i = 1, 3 do
            love.graphics.circle("line", self.r + 4 + i * 5, -8, 2)
            love.graphics.circle("line", self.r + 4 + i * 5, 8, 2)
        end
    elseif style == "obsidian" then
        love.graphics.setColor(0.05, 0.05, 0.08)
        love.graphics.polygon("fill", self.r, -12, self.r + 14, 0, self.r, -2)
        love.graphics.polygon("fill", self.r, 12, self.r + 14, 0, self.r, 2)
        love.graphics.setColor(0.25, 0.15, 0.35)
        love.graphics.polygon("line", self.r, -12, self.r + 14, 0, self.r, -2)
        love.graphics.polygon("line", self.r, 12, self.r + 14, 0, self.r, 2)
    elseif style == "saw" then
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.circle("fill", self.r + 6, -8, 9)
        love.graphics.circle("fill", self.r + 6, 8, 9)
        love.graphics.setColor(0.3, 0.3, 0.35)
        for i = 0, 7 do
            local a = (i / 8) * math.pi * 2
            love.graphics.polygon("fill",
                self.r + 6 + math.cos(a) * 9, -8 + math.sin(a) * 9,
                self.r + 6 + math.cos(a) * 13, -8 + math.sin(a) * 13,
                self.r + 6 + math.cos(a + 0.4) * 9, -8 + math.sin(a + 0.4) * 9)
            love.graphics.polygon("fill",
                self.r + 6 + math.cos(a) * 9, 8 + math.sin(a) * 9,
                self.r + 6 + math.cos(a) * 13, 8 + math.sin(a) * 13,
                self.r + 6 + math.cos(a + 0.4) * 9, 8 + math.sin(a + 0.4) * 9)
        end
    elseif style == "prism" then
        local t = love.timer.getTime()
        for sign = -1, 1, 2 do
            local cy = 8 * sign
            local hue = (t * 0.25 + (sign + 1) * 0.25) % 1
            local i = math.floor(hue * 6)
            local f = hue * 6 - i
            local r, g, b = 1, 1, 1
            if i == 0 then r,g,b = 1, f, 0
            elseif i == 1 then r,g,b = 1-f, 1, 0
            elseif i == 2 then r,g,b = 0, 1, f
            elseif i == 3 then r,g,b = 0, 1-f, 1
            elseif i == 4 then r,g,b = f, 0, 1
            else r,g,b = 1, 0, 1-f end
            love.graphics.setColor(r, g, b)
            love.graphics.polygon("fill", self.r, cy - 6, self.r + 14, cy, self.r, cy + 6)
        end
    elseif style == "churgly_jaws" then
        -- Each "arm" is replaced by a full reptilian alligator jaw that
        -- points forward along the aim direction and chomps rhythmically.
        local t = love.timer.getTime()
        local chomp = 0.45 + 0.55 * math.abs(math.sin(t * 3))
        for sy = -1, 1, 2 do
            local cy = 8 * sy
            -- Outer jaw shell (dark purple)
            love.graphics.setColor(0.25, 0.1, 0.35)
            love.graphics.polygon("fill",
                self.r - 4, cy,
                self.r + 4, cy - 9,
                self.r + 22, cy - 6 * chomp,
                self.r + 26, cy,
                self.r + 22, cy + 6 * chomp,
                self.r + 4, cy + 9)
            -- Maw interior (black)
            love.graphics.setColor(0.05, 0.02, 0.08)
            love.graphics.polygon("fill",
                self.r + 2, cy - 4,
                self.r + 20, cy - 5 * chomp,
                self.r + 22, cy,
                self.r + 20, cy + 5 * chomp,
                self.r + 2, cy + 4)
            -- Teeth rows (upper + lower), staggered
            love.graphics.setColor(0.94, 0.92, 0.84)
            for k = 0, 4 do
                local tx = self.r + 4 + k * 3.6
                local ty = cy - 5 * chomp
                love.graphics.polygon("fill",
                    tx, ty,
                    tx - 1, ty + 3,
                    tx + 1, ty + 3)
                local ty2 = cy + 5 * chomp
                love.graphics.polygon("fill",
                    tx, ty2,
                    tx - 1, ty2 - 3,
                    tx + 1, ty2 - 3)
            end
            -- Scaly ridges on the upper jaw
            love.graphics.setColor(0.15, 0.05, 0.25)
            for k = 0, 3 do
                love.graphics.circle("fill", self.r + 6 + k * 4, cy - 7, 1.2)
            end
            -- Slit reptilian eye on the side of the jaw
            love.graphics.setColor(1, 0.85, 0.2)
            love.graphics.circle("fill", self.r + 6, cy - 2, 1.8)
            love.graphics.setColor(0, 0, 0)
            love.graphics.ellipse("fill", self.r + 6, cy - 2, 0.5, 1.3)
            love.graphics.setColor(1, 1, 0.7)
            love.graphics.circle("fill", self.r + 5.5, cy - 2.5, 0.5)
            -- Tongue flicker
            if math.sin(t * 5 + sy) > 0.6 then
                love.graphics.setColor(0.7, 0.1, 0.2)
                love.graphics.setLineWidth(1.2)
                love.graphics.line(self.r + 10, cy, self.r + 18, cy + sy * 1.5)
                love.graphics.setLineWidth(1)
            end
        end
    elseif style == "churgly" then
        -- Churgly's Grasp: Lovecraftian eldritch claws — writhing purple flesh,
        -- multiple blinking eyes, bony spikes, flowing tendrils, golden sigil.
        local t = love.timer.getTime()
        local pulse = 0.75 + math.sin(t * 2.3) * 0.25
        for sign = -1, 1, 2 do
            local cx = self.r + 4
            local cy = 8 * sign

            -- Pulsing dark flesh halo
            love.graphics.setColor(0.35, 0.1, 0.45, 0.5)
            love.graphics.circle("fill", cx, cy, 16 + math.sin(t * 3 + sign) * 2)
            -- Main claw orb — shifting cosmic flesh
            love.graphics.setColor(0.25 * pulse, 0.08, 0.55 * pulse)
            love.graphics.circle("fill", cx, cy, 12)
            love.graphics.setColor(0.4, 0.15, 0.6)
            love.graphics.circle("fill", cx, cy, 9)
            -- Dark pupil-heart
            love.graphics.setColor(0.05, 0, 0.1)
            love.graphics.circle("fill", cx, cy, 6)

            -- Ring of small eyes
            for i = 0, 5 do
                local a = t * 1.5 + sign * i * math.pi / 3
                local ex = cx + math.cos(a) * 7
                local ey = cy + math.sin(a) * 7
                local blink = (math.sin(t * 2.5 + i + sign) > 0.6) and 0.2 or 1
                love.graphics.setColor(1, 0.85, 0.2, blink)
                love.graphics.circle("fill", ex, ey, 1.8)
                love.graphics.setColor(0, 0, 0, blink)
                love.graphics.circle("fill", ex, ey, 0.9)
            end
            -- Central great eye (blinks slowly)
            local bigBlink = math.abs(math.sin(t * 0.7 + sign))
            love.graphics.setColor(1, 0.85, 0.2)
            love.graphics.circle("fill", cx, cy, 4)
            love.graphics.setColor(0.9, 0.4, 0.05)
            love.graphics.circle("fill", cx, cy, 3)
            love.graphics.setColor(0, 0, 0)
            love.graphics.ellipse("fill", cx, cy, 3, 3 * bigBlink)
            love.graphics.setColor(1, 1, 1, 0.85)
            love.graphics.circle("fill", cx - 1, cy - 1, 0.8)

            -- Bony spikes jutting outward
            love.graphics.setColor(0.9, 0.85, 0.7)
            for i = -1, 1 do
                local ang = (math.pi * 0.25) * i
                local sx = cx + math.cos(ang) * 12
                local sy = cy + math.sin(ang) * 12 + sign * 2
                local ex = cx + math.cos(ang) * 19
                local ey = cy + math.sin(ang) * 19 + sign * 2
                love.graphics.polygon("fill", sx, sy - 1.5, sx, sy + 1.5, ex, ey)
            end
            love.graphics.setColor(0.3, 0.2, 0.1)
            for i = -1, 1 do
                local ang = (math.pi * 0.25) * i
                local sx = cx + math.cos(ang) * 12
                local sy = cy + math.sin(ang) * 12 + sign * 2
                local ex = cx + math.cos(ang) * 19
                local ey = cy + math.sin(ang) * 19 + sign * 2
                love.graphics.polygon("line", sx, sy - 1.5, sx, sy + 1.5, ex, ey)
            end

            -- Writhing tendrils trailing outward
            love.graphics.setLineWidth(2.2)
            for i = 0, 4 do
                local a = t * 2.4 + i * 0.8 + sign
                local base = 14
                local x1 = cx + math.cos(a) * base
                local y1 = cy + math.sin(a) * base
                local mx = x1 + math.cos(a + math.sin(t * 4 + i)) * 6
                local my = y1 + math.sin(a + math.cos(t * 4 + i)) * 6
                local ex2 = mx + math.cos(a + math.sin(t * 3 + i) * 2) * 8
                local ey2 = my + math.sin(a + math.cos(t * 3 + i) * 2) * 8
                love.graphics.setColor(0.6, 0.25, 0.9, 0.75)
                love.graphics.line(x1, y1, mx, my, ex2, ey2)
                love.graphics.setColor(1, 0.85, 0.2, 0.5)
                love.graphics.circle("fill", ex2, ey2, 1)
            end
            love.graphics.setLineWidth(1)

            -- Golden outer sigil ring with gaps
            love.graphics.setColor(0.95, 0.78, 0.15, 0.85)
            love.graphics.setLineWidth(1.5)
            for i = 0, 7 do
                local a1 = (i / 8) * math.pi * 2 + t * 0.7 * sign
                local a2 = a1 + 0.4
                love.graphics.arc("line", "open", cx, cy, 14, a1, a2)
            end
            love.graphics.setLineWidth(1)

            -- Dripping energy wisp
            love.graphics.setColor(0.7, 0.3, 1, 0.6)
            for d = 1, 3 do
                local dy2 = 14 + d * 4 + math.sin(t * 4 + d + sign) * 1.5
                love.graphics.circle("fill", cx + math.sin(t * 3 + d) * 2, cy + dy2 * sign, 1.5)
            end
        end
    else
        -- normal
        love.graphics.setColor(body)
        love.graphics.circle("fill", self.r + 4, -8, 9)
        love.graphics.circle("fill", self.r + 4, 8, 9)
        love.graphics.setColor(deep)
        love.graphics.circle("line", self.r + 4, -8, 9)
        love.graphics.circle("line", self.r + 4, 8, 9)
    end
end

function Player:_drawEyes(style, deep)
    style = style or "normal"
    if style == "cute" then
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", -6, -5, 4)
        love.graphics.circle("fill", 6, -5, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", -4, -7, 1.5)
        love.graphics.circle("fill", 8, -7, 1.5)
    elseif style == "cyber" then
        love.graphics.setColor(0, 0.9, 1, 0.7)
        love.graphics.rectangle("fill", -9, -7, 6, 4)
        love.graphics.rectangle("fill", 3, -7, 6, 4)
        love.graphics.setColor(0, 1, 1, 1)
        love.graphics.rectangle("line", -9, -7, 6, 4)
        love.graphics.rectangle("line", 3, -7, 6, 4)
    elseif style == "angry" then
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.polygon("fill", -9, -6, -3, -3, -3, -7)
        love.graphics.polygon("fill", 9, -6, 3, -3, 3, -7)
        love.graphics.setColor(0, 0, 0)
        love.graphics.polygon("line", -9, -6, -3, -3, -3, -7)
        love.graphics.polygon("line", 9, -6, 3, -3, 3, -7)
    elseif style == "third" then
        -- normal two + third
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", -5, -5, 3)
        love.graphics.circle("fill", 5, -5, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", -5, -5, 1.5)
        love.graphics.circle("fill", 5, -5, 1.5)
        -- third eye on forehead
        local t = love.timer.getTime()
        love.graphics.setColor(0.8, 0.3, 1)
        love.graphics.circle("fill", 0, -11, 3.5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", 0, -11 + math.sin(t*2)*0.5, 1.8)
    elseif style == "many" then
        local t = love.timer.getTime()
        for i = -3, 3 do
            love.graphics.setColor(1, 0.9 - math.abs(i)*0.15, 0.2)
            love.graphics.circle("fill", i * 3.5, -6 + math.sin(t*2 + i) * 1, 2)
            love.graphics.setColor(0, 0, 0)
            love.graphics.circle("fill", i * 3.5, -6 + math.sin(t*2 + i) * 1, 1)
        end
    elseif style == "slugcrab" then
        -- Slug eyes: black ovals on light bodies, invert to white on dark bodies for visibility
        local bodyCol = self._drawBodyColor or {1, 1, 1}
        local lum = Cosmetics.luminance(bodyCol)
        if lum < 0.4 then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0, 0, 0)
        end
        love.graphics.ellipse("fill", -5, -5, 2.8, 6)
        love.graphics.ellipse("fill", 5, -5, 2.8, 6)
    elseif style == "happy" then
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", -5, -5, 3, math.pi, math.pi * 2)
        love.graphics.arc("line", "open",  5, -5, 3, math.pi, math.pi * 2)
        love.graphics.setLineWidth(1)
    elseif style == "sleepy" then
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(1.8)
        love.graphics.line(-8, -5, -2, -5)
        love.graphics.line( 2, -5,  8, -5)
        love.graphics.setLineWidth(1)
    elseif style == "heart" then
        love.graphics.setColor(1, 0.3, 0.4)
        for _, px in ipairs({-5, 5}) do
            love.graphics.circle("fill", px - 1.3, -6, 1.6)
            love.graphics.circle("fill", px + 1.3, -6, 1.6)
            love.graphics.polygon("fill", px - 2.8, -5.2, px + 2.8, -5.2, px, -2.5)
        end
    elseif style == "spiral" then
        local t = love.timer.getTime()
        for _, px in ipairs({-5, 5}) do
            love.graphics.setColor(0, 0, 0)
            love.graphics.circle("fill", px, -5, 3)
            love.graphics.setColor(1, 1, 1)
            for i = 0, 12 do
                local a = i * 0.35 + t * 2 * (px / 5)
                local rr = i / 12 * 2.5
                love.graphics.circle("fill", px + math.cos(a) * rr, -5 + math.sin(a) * rr, 0.35)
            end
        end
    elseif style == "frozen" then
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.circle("fill", -5, -5, 3)
        love.graphics.circle("fill",  5, -5, 3)
        love.graphics.setColor(1, 1, 1)
        for _, px in ipairs({-5, 5}) do
            love.graphics.line(px - 3, -5, px + 3, -5)
            love.graphics.line(px, -8, px, -2)
        end
    elseif style == "fire" then
        local t = love.timer.getTime()
        for _, px in ipairs({-5, 5}) do
            love.graphics.setColor(1, 0.5, 0.1, 0.8)
            love.graphics.circle("fill", px, -5 + math.sin(t * 4 + px) * 0.4, 4)
            love.graphics.setColor(1, 0.9, 0.2)
            love.graphics.circle("fill", px, -5, 2)
        end
    elseif style == "skull" then
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", -5, -5, 3.5)
        love.graphics.circle("fill",  5, -5, 3.5)
    elseif style == "crystal" then
        love.graphics.setColor(0.6, 0.9, 1)
        love.graphics.polygon("fill", -7, -5, -5, -8, -3, -5, -5, -2)
        love.graphics.polygon("fill",  3, -5,  5, -8,  7, -5,  5, -2)
        love.graphics.setColor(0.3, 0.5, 0.8)
        love.graphics.polygon("line", -7, -5, -5, -8, -3, -5, -5, -2)
        love.graphics.polygon("line",  3, -5,  5, -8,  7, -5,  5, -2)
    elseif style == "rune" then
        -- Rune-etched eyes: a glowing purple sigil framed by carved runic marks.
        -- Color shifts to a deeper purple on light bodies so it reads as etched.
        local t = love.timer.getTime()
        local bodyCol = self._drawBodyColor or {1, 1, 1}
        local lum = Cosmetics.luminance(bodyCol)
        -- dark purple on light skin, bright purple on dark skin
        local baseR, baseG, baseB
        if lum > 0.55 then
            baseR, baseG, baseB = 0.22, 0.05, 0.40
        else
            baseR, baseG, baseB = 0.75, 0.35, 1.0
        end
        local pulse = 0.75 + 0.25 * math.sin(t * 2)
        for _, px in ipairs({-5, 5}) do
            -- Eye socket (dim glow)
            love.graphics.setColor(baseR * 0.45, baseG * 0.45, baseB * 0.45, 0.85)
            love.graphics.circle("fill", px, -5, 3.2)
            -- Inner glow core
            love.graphics.setColor(baseR, baseG, baseB, 0.9 * pulse)
            love.graphics.circle("fill", px, -5, 1.9)
            -- Runic cross (vertical + horizontal carve)
            love.graphics.setColor(baseR * 1.2, baseG * 0.9, baseB * 1.2, pulse)
            love.graphics.setLineWidth(1)
            love.graphics.line(px, -7.5, px, -2.5)
            love.graphics.line(px - 2, -5, px + 2, -5)
            -- Small tick marks (runic serifs)
            love.graphics.line(px - 2, -7, px - 1, -6)
            love.graphics.line(px + 1, -6, px + 2, -7)
            love.graphics.line(px - 2, -3, px - 1, -4)
            love.graphics.line(px + 1, -4, px + 2, -3)
        end
        -- Angular runic mark across the brow connecting the two eyes
        love.graphics.setColor(baseR, baseG, baseB, 0.55 * pulse)
        love.graphics.setLineWidth(0.8)
        love.graphics.line(-5, -9, -3, -10, 3, -10, 5, -9)
        love.graphics.line(-3, -10, -2, -11)
        love.graphics.line( 3, -10,  2, -11)
    elseif style == "vacant" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", -5, -5, 3)
        love.graphics.circle("fill",  5, -5, 3)
    elseif style == "churgly_eyes" then
        -- Churgly'nth face — mirrors the in-game Churgly head:
        --   * Big black upside-down triangle maw whose apex barely touches the
        --     bottom of the head outline (apex y = +18, head radius). Mouth
        --     height = 2.2/3 of the 36-px head ≈ 26 px so the top edge sits at
        --     y = 18 - 26 = -8.
        --   * Two yellow reptilian slit-pupil eyes pinned in close to the side
        --     of the head, vertically centered inside the mouth (eye y = 5,
        --     halfway between the mouth top -8 and the apex 18).
        love.graphics.setColor(0, 0, 0)
        love.graphics.polygon("fill",
            -11, -7,    -- mouth top-left (slimmer but not too narrow)
             11, -7,    -- mouth top-right
              0, 17)    -- mouth apex (slightly shorter, grazes outline)
        for _, px in ipairs({-11, 11}) do
            -- Yellow iris
            love.graphics.setColor(1, 0.8, 0.15)
            love.graphics.circle("fill", px, 5, 3)
            -- Vertical slit pupil
            love.graphics.setColor(0, 0, 0)
            love.graphics.ellipse("fill", px, 5, 0.6, 2.2)
        end
    elseif style == "void_gaze" then
        -- Void Gaze: two main cosmic voids + extra eldritch eyes studded across the face,
        -- leaking purple energy tears and crowned by a forehead sigil-eye.
        local t = love.timer.getTime()

        -- Forehead third eye (bigger, vertical slit pupil)
        local fglow = 0.5 + 0.3 * math.sin(t * 2)
        love.graphics.setColor(0.5, 0.1, 0.8, 0.7)
        love.graphics.circle("fill", 0, -12, 4 + fglow)
        love.graphics.setColor(1, 0.4, 0.7)
        love.graphics.circle("fill", 0, -12, 3)
        love.graphics.setColor(0.95, 0.85, 0.2)
        love.graphics.circle("fill", 0, -12, 2)
        love.graphics.setColor(0, 0, 0)
        love.graphics.ellipse("fill", 0, -12, 0.7, 2)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.circle("fill", -0.6, -12.6, 0.3)

        -- Little extra eyes dotted around the face (blinking out of sync)
        local tinyEyes = {{-10, -2}, {10, -2}, {-7, 2}, {7, 2}}
        for i, p in ipairs(tinyEyes) do
            local blink = math.abs(math.sin(t * 2 + i * 0.7))
            if blink > 0.15 then
                love.graphics.setColor(1, 0.85, 0.25, blink * 0.9)
                love.graphics.circle("fill", p[1], p[2], 1.2)
                love.graphics.setColor(0, 0, 0, blink)
                love.graphics.circle("fill", p[1], p[2], 0.6)
            end
        end

        -- Main eyes (big cosmic voids)
        for side = -1, 1, 2 do
            local ex = side * 6
            local ey = -5

            -- Outer purple glow halo
            love.graphics.setColor(0.5, 0.1, 0.8, 0.45)
            love.graphics.circle("fill", ex, ey, 6 + math.sin(t * 2 + side) * 0.6)
            -- Iris rings (shifting)
            love.graphics.setColor(0.35, 0.05, 0.55)
            love.graphics.circle("fill", ex, ey, 4.5)
            for r = 4, 2, -0.5 do
                local a = 0.3 + 0.3 * math.sin(t * 3 + r + side)
                love.graphics.setColor(1, 0.4 + (4 - r) * 0.15, 0.7, a)
                love.graphics.circle("line", ex, ey, r)
            end
            -- Golden inner iris
            love.graphics.setColor(1, 0.85, 0.2)
            love.graphics.circle("fill", ex, ey, 2.2)
            -- Void pupil (never fully black — it's a deeper dimension)
            love.graphics.setColor(0, 0, 0)
            love.graphics.circle("fill", ex, ey, 1.5)
            love.graphics.setColor(0.2, 0.0, 0.3, 0.9)
            love.graphics.circle("fill", ex, ey, 0.9)

            -- Tear of purple energy dripping down
            love.graphics.setColor(0.7, 0.3, 1, 0.55)
            local tearY = ey + 6 + math.sin(t * 3 + side) * 2
            love.graphics.circle("fill", ex + side * 0.8, tearY, 1)
            love.graphics.setColor(0.9, 0.5, 1, 0.4)
            love.graphics.circle("fill", ex + side * 0.8, tearY - 1, 0.6)

            -- Swirling spark orbiting the eye
            local sa = t * 3 + side
            local sx = ex + math.cos(sa) * 5
            local sy = ey + math.sin(sa) * 5
            love.graphics.setColor(1, 0.9, 0.3, 0.8)
            love.graphics.circle("fill", sx, sy, 0.8)
        end

        -- Subtle rune arcs above the brows
        love.graphics.setColor(0.7, 0.3, 1, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.arc("line", "open", -6, -8, 3, math.pi * 1.1, math.pi * 1.9)
        love.graphics.arc("line", "open", 6, -8, 3, math.pi * 1.1, math.pi * 1.9)
    else
        -- normal
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", -5, -5, 3)
        love.graphics.circle("fill", 5, -5, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", -5, -5, 1.5)
        love.graphics.circle("fill", 5, -5, 1.5)
    end
end

function Player:_drawHat(style)
    style = style or "none"
    if style == "none" then return end
    if style == "tophat" then
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", -10, -24, 20, 10)
        love.graphics.rectangle("fill", -13, -15, 26, 3)
        love.graphics.setColor(0.9, 0.1, 0.1)
        love.graphics.rectangle("fill", -10, -16, 20, 2)
    elseif style == "crown" then
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.polygon("fill", -11, -12, -11, -20, -7, -15, -3, -22, 0, -15, 3, -22, 7, -15, 11, -20, 11, -12)
        love.graphics.setColor(0.6, 0.4, 0.1)
        love.graphics.polygon("line", -11, -12, -11, -20, -7, -15, -3, -22, 0, -15, 3, -22, 7, -15, 11, -20, 11, -12)
        love.graphics.setColor(0.9, 0.2, 0.3)
        love.graphics.circle("fill", 0, -14, 2)
    elseif style == "hood" then
        love.graphics.setColor(0.1, 0.8, 0.3)
        love.graphics.arc("fill", "pie", 0, -4, 22, math.pi, 2 * math.pi)
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.arc("fill", "pie", 0, -4, 18, math.pi * 1.1, math.pi * 1.9)
    elseif style == "tinfoil" then
        love.graphics.setColor(0.8, 0.8, 0.85)
        love.graphics.polygon("fill", -11, -12, 0, -24, 11, -12)
        love.graphics.setColor(0.4, 0.4, 0.45)
        love.graphics.polygon("line", -11, -12, 0, -24, 11, -12)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.line(-3, -18, 2, -14)
    elseif style == "halo" then
        local t = love.timer.getTime()
        love.graphics.setColor(1, 1, 0.5, 0.8 + math.sin(t*3)*0.2)
        love.graphics.ellipse("line", 0, -22, 14, 4)
        love.graphics.setColor(1, 1, 0.8, 0.4)
        love.graphics.ellipse("line", 0, -22, 12, 3)
    elseif style == "horns" then
        love.graphics.setColor(0.25, 0.1, 0.3)
        love.graphics.polygon("fill", -12, -12, -8, -22, -4, -12)
        love.graphics.polygon("fill", 12, -12, 8, -22, 4, -12)
        love.graphics.setColor(0.6, 0.3, 0.8)
        love.graphics.polygon("line", -12, -12, -8, -22, -4, -12)
        love.graphics.polygon("line", 12, -12, 8, -22, 4, -12)
    elseif style == "beanie" then
        love.graphics.setColor(0.9, 0.25, 0.35)
        love.graphics.arc("fill", "pie", 0, -12, 14, math.pi, 2 * math.pi)
        love.graphics.setColor(0.5, 0.1, 0.15)
        love.graphics.circle("fill", 0, -24, 3)
        love.graphics.rectangle("fill", -15, -12, 30, 2)
    elseif style == "cap" then
        love.graphics.setColor(0.2, 0.5, 0.9)
        love.graphics.arc("fill", "pie", 0, -10, 13, math.pi, 2 * math.pi)
        love.graphics.rectangle("fill", -17, -10, 10, 3)
    elseif style == "antlers" then
        love.graphics.setColor(0.6, 0.4, 0.2)
        love.graphics.setLineWidth(3)
        for s = -1, 1, 2 do
            love.graphics.line(s * 5, -14, s * 10, -24)
            love.graphics.line(s * 10, -24, s * 6, -30)
            love.graphics.line(s * 10, -24, s * 16, -26)
            love.graphics.line(s * 16, -26, s * 14, -32)
        end
        love.graphics.setLineWidth(1)
    elseif style == "wizard" then
        love.graphics.setColor(0.2, 0.1, 0.4)
        love.graphics.polygon("fill", -14, -10, 14, -10, 0, -32)
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.circle("fill", -6, -18, 1.2)
        love.graphics.circle("fill", 5, -22, 1.2)
        love.graphics.circle("fill", 0, -26, 1.2)
    elseif style == "cowboy" then
        love.graphics.setColor(0.4, 0.25, 0.08)
        love.graphics.ellipse("fill", 0, -10, 18, 4)
        love.graphics.arc("fill", "pie", 0, -13, 10, math.pi, 2 * math.pi)
    elseif style == "helmet" then
        love.graphics.setColor(0.35, 0.35, 0.4)
        love.graphics.arc("fill", "pie", 0, -11, 13, math.pi, 2 * math.pi)
        love.graphics.setColor(0.8, 0.8, 0.85)
        love.graphics.rectangle("fill", -12, -14, 24, 2)
    elseif style == "pirate" then
        love.graphics.setColor(0.05, 0.05, 0.08)
        love.graphics.polygon("fill", -16, -11, 16, -11, 14, -20, -14, -20)
        love.graphics.setColor(0.85, 0.85, 0.85)
        local sx, sy = 0, -15
        love.graphics.polygon("fill", sx, sy - 3, sx - 3, sy, sx, sy + 3, sx + 3, sy)
        love.graphics.polygon("fill", sx - 2, sy - 2, sx + 2, sy + 2, sx - 2, sy + 2, sx + 2, sy - 2)
    elseif style == "fin" then
        love.graphics.setColor(0.3, 0.4, 0.55)
        love.graphics.polygon("fill", -6, -12, 10, -12, 0, -28)
        love.graphics.setColor(0.15, 0.2, 0.3)
        love.graphics.polygon("line", -6, -12, 10, -12, 0, -28)
    elseif style == "cap_spike" then
        love.graphics.setColor(0.25, 0.25, 0.3)
        love.graphics.arc("fill", "pie", 0, -11, 13, math.pi, 2 * math.pi)
        love.graphics.setColor(0.7, 0.7, 0.75)
        for i = -2, 2 do
            love.graphics.polygon("fill", i * 4, -14, i * 4 - 2, -20, i * 4 + 2, -20)
        end
    elseif style == "deepcrown" then
        -- Crown of the Deep: jagged golden crown with floating orbs
        local t = love.timer.getTime()
        love.graphics.setColor(0.95, 0.8, 0.2)
        love.graphics.polygon("fill", -13, -12, -13, -22, -9, -16, -5, -24, -1, -16, 1, -16, 5, -24, 9, -16, 13, -22, 13, -12)
        love.graphics.setColor(0.35, 0.2, 0.55)
        love.graphics.polygon("line", -13, -12, -13, -22, -9, -16, -5, -24, -1, -16, 1, -16, 5, -24, 9, -16, 13, -22, 13, -12)
        -- Floating orbs
        for i = -1, 1, 2 do
            local ox = i * 14 + math.cos(t * 2 + i) * 3
            local oy = -26 + math.sin(t * 2 + i) * 2
            love.graphics.setColor(1, 0.85, 0.3, 0.9)
            love.graphics.circle("fill", ox, oy, 2.5)
        end
    elseif style == "slugears" then
        -- Slug ears: long droopy ovals tinted to match the body's primary color
        local t = love.timer.getTime()
        local sway = math.sin(t * 1.8) * 2
        local bodyCol = self._drawBodyColor or {1, 1, 1}
        love.graphics.setColor(bodyCol[1], bodyCol[2], bodyCol[3])
        love.graphics.ellipse("fill", -8, -17 + sway * 0.3, 2.2, 11)
        love.graphics.ellipse("fill",  8, -17 - sway * 0.3, 2.2, 11)
    end
end

function Player:emitTrail()
    local trail = (self.cosmetics or {}).trail or "none"
    if trail == "none" then return end
    self.trailTimer = self.trailTimer - (1/60)
    local moving = self._prevX and ((self.x - self._prevX)^2 + (self.y - self._prevY)^2) > 1 or false
    self._prevX, self._prevY = self.x, self.y
    if self.trailTimer > 0 then return end
    if trail == "sparkle" then
        self.trailTimer = 0.05
        if moving then
            P:spawn(self.x + math.random(-8,8), self.y + math.random(-8,8), 1, {1, 1, 0.6}, 40, 0.5, 2)
        end
    elseif trail == "fire" then
        self.trailTimer = 0.04
        P:spawn(self.x, self.y + 4, 2, {1, 0.5 - math.random()*0.3, 0.1}, 80, 0.4, 3)
    elseif trail == "data" then
        self.trailTimer = 0.08
        if math.random() < 0.5 then
            P:text(self.x + math.random(-10,10), self.y + math.random(-6,6), tostring(math.random(0,1)), {0.2, 1, 0.4}, 0.5)
        else
            P:spawn(self.x, self.y, 1, {0.2, 0.8, 1}, 30, 0.4, 2)
        end
    elseif trail == "void" then
        self.trailTimer = 0.05
        P:spawn(self.x + math.random(-10,10), self.y + math.random(-10,10), 1, {0.4, 0.1, 0.6}, 20, 0.8, 3)
    elseif trail == "wake" then
        -- Wake of Horrors: swirling purple-gold horror wisps that pulse with eldritch energy
        self.trailTimer = 0.03
        local t = love.timer.getTime()
        for i = 1, 2 do
            local a = t * 3 + i * math.pi
            local ox = math.cos(a) * 12
            local oy = math.sin(a) * 12
            local col = (math.random() < 0.5) and {0.5, 0.1, 0.8} or {1, 0.85, 0.2}
            P:spawn(self.x + ox, self.y + oy, 1, col, 40, 0.9, 3)
        end
        if math.random() < 0.2 then
            P:text(self.x + math.random(-12, 12), self.y + math.random(-8, 8), "~", {0.7, 0.3, 1}, 0.4)
        end
    elseif trail == "bubbles" then
        self.trailTimer = 0.09
        P:spawn(self.x + math.random(-6, 6), self.y + math.random(0, 6), 1, {0.6, 0.85, 1}, 30, 0.9, 3)
    elseif trail == "petals" then
        self.trailTimer = 0.08
        local col = (math.random() < 0.5) and {1, 0.7, 0.8} or {1, 0.9, 0.8}
        P:spawn(self.x + math.random(-8, 8), self.y + math.random(-3, 6), 1, col, 40, 1.2, 3)
    elseif trail == "lightning" then
        self.trailTimer = 0.05
        P:spawn(self.x + math.random(-10, 10), self.y + math.random(-6, 6), 2, {0.6, 0.9, 1}, 90, 0.3, 2)
        if math.random() < 0.15 then
            P:text(self.x + math.random(-10, 10), self.y + math.random(-6, 6), "z", {0.7, 1, 1}, 0.35)
        end
    elseif trail == "shadow" then
        self.trailTimer = 0.06
        P:spawn(self.x, self.y + 2, 1, {0.05, 0.05, 0.08}, 20, 0.6, 5)
    elseif trail == "music" then
        self.trailTimer = 0.14
        local notes = {"o", ".", "J", "F"}
        local n = notes[math.random(#notes)]
        P:text(self.x + math.random(-8, 8), self.y - 2, n, {1, 0.85, 0.4}, 0.8)
    elseif trail == "runes" then
        self.trailTimer = 0.12
        local syms = {"*", "+", "x", "#", "%"}
        P:text(self.x + math.random(-10, 10), self.y + math.random(-6, 6),
            syms[math.random(#syms)], {0.7, 0.4, 1}, 0.7)
    elseif trail == "chaos" then
        self.trailTimer = 0.02
        local col = {math.random(), math.random(), math.random()}
        P:spawn(self.x + math.random(-10, 10), self.y + math.random(-10, 10), 1, col, 120, 0.5, 3)
    elseif trail == "super_saiyan" then
        -- Particles are minor; the aura is drawn separately in drawAura().
        self.trailTimer = 0.04
        if math.random() < 0.25 then
            P:spawn(self.x + math.random(-10, 10), self.y - 12, 1, {1, 0.9, 0.3}, 150, 0.7, 3)
        end
        if math.random() < 0.05 then
            P:text(self.x + math.random(-22, 22), self.y + math.random(-18, 18), "z", {0.7, 0.9, 1}, 0.35)
        end
    end
end

-- Build a flat vertex list shaped like an egg (tapered top, rounded bottom).
-- cx, cy = center; w = max width (horizontal); h = height (vertical).
local function eggVerts(cx, cy, w, h)
    local N = 42
    local verts = {}
    for i = 0, N - 1 do
        local theta = (i / N) * math.pi * 2
        local vx = math.cos(theta)
        local vy = math.sin(theta) -- +y = down in love2d
        -- Narrow the TOP: when vy < 0 (above center) shrink the width.
        local widthMul
        if vy < 0 then
            -- Top half: smoothly narrow from 1.0 at equator to 0.55 at tip
            widthMul = 0.55 + 0.45 * (1 + vy) -- vy in [-1,0]
        else
            widthMul = 1.0
        end
        -- Egg sits slightly low so the wide belly is below center
        verts[#verts + 1] = cx + vx * w * widthMul
        verts[#verts + 1] = cy + vy * h + 4
    end
    return verts
end

-- Persistent aura effects drawn behind the body each frame (not particles).
function Player:drawAura()
    local trail = (self.cosmetics or {}).trail
    if trail ~= "super_saiyan" then return end
    local t = love.timer.getTime()
    local basePulse = 0.85 + 0.15 * math.sin(t * 3)
    -- 6 concentric EGG-shaped rings (tapered top, rounded belly) rippling outward
    for i = 0, 5 do
        local ringOffset = math.sin(t * 4 + i * 0.9) * 3
        local w = 22 + i * 5 + ringOffset
        local h = 32 + i * 6 + ringOffset * 1.2
        local mix = i / 5
        local a = (0.42 - i * 0.06) * basePulse
        love.graphics.setColor(1, 0.9 - mix * 0.35, 0.2 - mix * 0.15, a)
        love.graphics.polygon("fill", eggVerts(self.x, self.y, w, h))
    end
    -- Outermost rippling orange shell
    love.graphics.setColor(1, 0.55, 0.1, 0.22 * basePulse)
    local shellW = 56 + math.sin(t * 2.5) * 4
    love.graphics.polygon("fill", eggVerts(self.x, self.y, shellW, shellW * 1.15))
    -- Bright expanding egg-line pulses
    for i = 0, 2 do
        local ring = ((t * 0.9) + i / 3) % 1
        local rw = 22 + ring * 40
        local rh = 28 + ring * 50
        local a = (1 - ring) * 0.6
        love.graphics.setColor(1, 0.95, 0.35, a)
        love.graphics.polygon("line", eggVerts(self.x, self.y, rw, rh))
    end
    -- Occasional lightning arc flickering across the aura
    if math.sin(t * 5) > 0.55 then
        love.graphics.setColor(0.85, 0.95, 1, 0.8)
        love.graphics.setLineWidth(1.5)
        local a = math.random() * math.pi * 2
        local r1 = 26
        local r2 = 42
        local x1 = self.x + math.cos(a) * r1
        local y1 = self.y + math.sin(a) * r1
        local x2 = self.x + math.cos(a) * r2
        local y2 = self.y + math.sin(a) * r2
        local mx = (x1 + x2) / 2 + math.random(-6, 6)
        local my = (y1 + y2) / 2 + math.random(-6, 6)
        love.graphics.line(x1, y1, mx, my, x2, y2)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Player:draw()
    -- Trail emission (cosmetic only — no gameplay effect)
    self:emitTrail()
    -- Persistent aura trails (drawn BEHIND the crab)
    self:drawAura()

    local c = self.cosmetics or {body="orange", eye="normal", claw="normal", hat="none", trail="none"}
    local body = Cosmetics.bodyColor(c)
    local deep = Cosmetics.outlineColor(c, body)
    self._drawBodyColor = body

    -- Slug tail is a TRAIL cosmetic now ("slug"), drawn BEHIND the body,
    -- colored to match the body's primary color so it blends with the skin.
    if c.trail == "slug" then
        local segs = 14
        local t = love.timer.getTime()
        local tr, tg, tb = body[1], body[2], body[3]
        if self.swimming then
            for i = segs, 1, -1 do
                local progress = i / segs
                local r = 16 * (1 - progress) ^ 1.2 + 1.6
                local phase = t * 6 - progress * 3
                local wave = math.sin(phase) * (progress * 14)
                local tx = self.x - progress * 36 + math.cos(phase) * progress * 6
                local ty = self.y + progress * 30 + wave
                love.graphics.setColor(tr, tg, tb)
                love.graphics.circle("fill", tx, ty, r)
            end
        elseif self.slugTailHistory and #self.slugTailHistory > 2 then
            local hist = self.slugTailHistory
            for i = segs, 1, -1 do
                local idx = math.min(#hist, math.floor(i * (#hist / segs)) + 1)
                local pos = hist[idx]
                if pos then
                    local progress = i / segs
                    local r = 16 * (1 - progress) ^ 1.2 + 1.6
                    love.graphics.setColor(tr, tg, tb)
                    love.graphics.circle("fill", pos.x, pos.y, r)
                end
            end
        end
    end

    -- Ugnrak trail — 3 serpents orbit the player. Each serpent is drawn as
    -- a continuous curved body (thick line through sample points) with
    -- spike pairs along its length, not discrete circles.
    if c.trail == "ugnrak" then
        local t = love.timer.getTime()
        local serpents = 3
        for s = 1, serpents do
            local speed = 1.2 + s * 0.3
            local radius = 56 + s * 14
            local segs = 18
            local baseOff = (s * math.pi * 2 / serpents) + t * speed
            -- Gather sample points along the snake's orbit
            local pts = {}
            local spikeCenters = {}
            for i = 1, segs do
                local segAng = baseOff - i * 0.14
                local r = radius + math.sin(t * 2 + i + s) * 4
                local cx = self.x + math.cos(segAng) * r
                local cy = self.y + math.sin(segAng) * r
                pts[#pts + 1] = cx
                pts[#pts + 1] = cy
                if i % 3 == 0 then
                    spikeCenters[#spikeCenters + 1] = {x = cx, y = cy,
                        ang = segAng, iFrac = i / segs}
                end
            end
            -- Spikes (drawn BEHIND body so body overlaps neatly)
            for _, sc in ipairs(spikeCenters) do
                local tanX = -math.sin(sc.ang); local tanY = math.cos(sc.ang)
                local perpX = math.cos(sc.ang); local perpY = math.sin(sc.ang)
                local baseW = (1 - sc.iFrac) * 4 + 2
                local spikeLen = baseW + 7
                for side = -1, 1, 2 do
                    love.graphics.setColor(0.75, 0.08, 0.1)
                    love.graphics.polygon("fill",
                        sc.x + tanX * baseW, sc.y + tanY * baseW,
                        sc.x - tanX * baseW, sc.y - tanY * baseW,
                        sc.x + perpX * side * spikeLen,
                        sc.y + perpY * side * spikeLen)
                    love.graphics.setColor(0.35, 0.02, 0.02)
                    love.graphics.line(
                        sc.x, sc.y,
                        sc.x + perpX * side * spikeLen,
                        sc.y + perpY * side * spikeLen)
                end
            end
            -- Snake body — thick outer, thinner inner, tapered
            love.graphics.setColor(0.35, 0.02, 0.02)
            love.graphics.setLineWidth(10)
            love.graphics.line(pts)
            love.graphics.setColor(0.72, 0.1, 0.12)   -- brighter dark red
            love.graphics.setLineWidth(7)
            love.graphics.line(pts)
            love.graphics.setColor(0.9, 0.2, 0.2)     -- brighter highlight
            love.graphics.setLineWidth(3)
            love.graphics.line(pts)
            love.graphics.setLineWidth(1)
            -- Head segment (first sample) — circular face with 24 #110000 dots
            local hx, hy = pts[1], pts[2]
            love.graphics.setColor(0.8, 0.12, 0.14)
            love.graphics.circle("fill", hx, hy, 8)
            love.graphics.setColor(1, 0.2, 0.2)
            love.graphics.circle("line", hx, hy, 8)
            local faceR = 6.5
            for d = 1, 24 do
                local fa = (d / 24) * math.pi * 2 + t * 0.7
                local fr = faceR * (0.35 + (d % 5) * 0.12)
                love.graphics.setColor(0.067, 0, 0)
                love.graphics.circle("fill",
                    hx + math.cos(fa) * fr,
                    hy + math.sin(fa) * fr, 0.85)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    love.graphics.push()
    love.graphics.translate(self.x, self.y)

    -- Void Sea: claws render BEHIND the body so the crab looks like it's
    -- gliding forward with arms trailing underneath. Also skip the gun here —
    -- no weapons in the Void Sea dive.
    if self.swimming then
        love.graphics.push()
        love.graphics.rotate(self.angle)
        self:_drawClaws(body, deep, c.claw)
        love.graphics.pop()
    end

    -- Shield ring (no rotation)
    if self.stats.shield > 0 then
        local a = 0.2 + 0.3 * (self.stats.shield / math.max(1, self.stats.shieldMax))
        love.graphics.setColor(0.4, 0.7, 1, a)
        love.graphics.circle("line", 0, 0, self.r + 8)
    end

    -- Rotating body layer (legs, body, eyes, hat follow movement)
    love.graphics.push()
    love.graphics.rotate(self.bodyAngle)

    -- Legs — bigger sweep when swimming
    love.graphics.setColor(deep)
    love.graphics.setLineWidth(3)
    local legAmp = self.swimming and 10 or 4
    local legExt = self.swimming and 14 or 10
    for i = -2, 2 do
        if i ~= 0 then
            local ly = math.sin(self.legPhase + i) * legAmp
            local lx = self.swimming and (math.cos(self.legPhase + i) * 6) or 0
            love.graphics.line(i * 4, self.r - 2, i * 8 + lx, self.r + legExt + ly)
            love.graphics.line(-i * 4, -(self.r - 2), -i * 8 - lx, -(self.r + legExt + ly))
        end
    end

    -- Body base
    local flash = self.flashTimer > 0 and 0.6 or 0
    love.graphics.setColor(body[1] + flash, body[2] + flash, body[3] + flash)
    love.graphics.circle("fill", 0, 0, self.r)
    -- Multicolor body patterns — overlaid onto the solid body using clipping via
    -- additional circles (we cheat and just scatter shapes within the body radius).
    local pattern = Cosmetics.bodyPattern(c)
    local sec = Cosmetics.bodySecondary(c)
    if pattern and sec then
        local t = love.timer.getTime()
        if pattern == "camo" then
            -- Irregular blobs of secondary color
            for i = 1, 7 do
                local a = (i / 7) * math.pi * 2 + (i * 1.3)
                local dist = 4 + (i % 3) * 3
                local sx = math.cos(a) * dist
                local sy = math.sin(a) * dist
                love.graphics.setColor(sec[1], sec[2], sec[3])
                love.graphics.circle("fill", sx, sy, 4.5 + (i % 2))
            end
        elseif pattern == "galaxy" then
            -- Swirl + stars
            for i = 1, 12 do
                local a = t * 0.4 + i * 0.6
                local d = (i % 4) * 4
                love.graphics.setColor(sec[1], sec[2], sec[3], 0.85)
                love.graphics.circle("fill", math.cos(a) * d, math.sin(a) * d, 0.8)
            end
            love.graphics.setColor(sec[1], sec[2], sec[3], 0.45)
            love.graphics.circle("line", 0, 0, self.r - 4)
        elseif pattern == "stripes" then
            love.graphics.setColor(sec[1], sec[2], sec[3])
            for sy = -self.r + 3, self.r - 3, 5 do
                love.graphics.rectangle("fill", -self.r + 2, sy, self.r * 2 - 4, 2)
            end
        elseif pattern == "dots" then
            love.graphics.setColor(sec[1], sec[2], sec[3])
            for i = 1, 6 do
                local a = (i / 6) * math.pi * 2
                love.graphics.circle("fill", math.cos(a) * (self.r * 0.55), math.sin(a) * (self.r * 0.55), 2)
            end
        elseif pattern == "marble" then
            love.graphics.setColor(sec[1], sec[2], sec[3], 0.65)
            love.graphics.setLineWidth(1.5)
            for i = 0, 4 do
                local a = i * 1.2 + t * 0.3
                love.graphics.arc("line", "open", math.cos(a) * 4, math.sin(a) * 4, self.r - 2, a, a + math.pi * 0.6)
            end
            love.graphics.setLineWidth(1)
        elseif pattern == "stars" then
            for i = 1, 5 do
                local a = (i / 5) * math.pi * 2 + t * 0.3
                local sx = math.cos(a) * (self.r * 0.6)
                local sy = math.sin(a) * (self.r * 0.6)
                love.graphics.setColor(sec[1], sec[2], sec[3], 0.9)
                love.graphics.circle("fill", sx, sy, 1.6)
            end
        elseif pattern == "checker" then
            love.graphics.setColor(sec[1], sec[2], sec[3])
            for ix = -2, 2 do
                for iy = -2, 2 do
                    if (ix + iy) % 2 == 0 then
                        love.graphics.rectangle("fill", ix * 5 - 2, iy * 5 - 2, 4, 4)
                    end
                end
            end
        elseif pattern == "aurora" then
            for i = 0, 4 do
                local a = i / 4
                local ca = t * 0.8 + i
                love.graphics.setColor(sec[1] * a + body[1] * (1 - a), sec[2] * a + body[2] * (1 - a), sec[3] * a + body[3] * (1 - a), 0.6)
                love.graphics.arc("fill", "pie", 0, 0, self.r - 2, ca, ca + 0.7)
            end
        elseif pattern == "lava" then
            love.graphics.setColor(sec[1], sec[2], sec[3], 0.9)
            for i = 1, 5 do
                local a = (i / 5) * math.pi * 2 + math.sin(t * 2 + i) * 0.4
                local d = 4 + (i % 3) * 3
                love.graphics.circle("fill", math.cos(a) * d, math.sin(a) * d, 2.5)
            end
        elseif pattern == "churgly" then
            -- A full ring of reptilian alligator-like mouths around the shell.
            -- 8 jaws offset 22.5° so none sit directly at the top (eye area).
            local jawPhase = 0.35 + 0.35 * math.abs(math.sin(t * 1.8))
            for i = 0, 7 do
                local a = (i / 8) * math.pi * 2 + math.pi / 8
                local cx = math.cos(a) * (self.r - 4)
                local cy = math.sin(a) * (self.r - 4)
                -- Skip the top jaw area so eyes stay readable
                if math.abs(a - (-math.pi / 2 + math.pi / 8)) > 0.001 then end
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(a)
                -- In this rotated frame, "out of body" is +x and "along body" is +/-y.
                local open = jawPhase + 0.12 * math.sin(t * 2.2 + i)
                -- Dark purple jaw pocket (bigger + wider)
                love.graphics.setColor(sec[1] * 0.45, sec[2] * 0.25, sec[3] * 0.55)
                love.graphics.polygon("fill",
                    -4, -11,
                    11, -5 * open,
                    15,   0,
                    11,  5 * open,
                    -4,  11)
                -- Dark maw interior
                love.graphics.setColor(0.04, 0, 0.08)
                love.graphics.polygon("fill",
                     1, -7,
                    11, -5 * open,
                    11,  5 * open,
                     1,  7)
                -- Teeth rows (top + bottom) — 5 teeth, thicker
                love.graphics.setColor(0.92, 0.90, 0.85)
                for k = 0, 4 do
                    local tx = 2 + k * 2.0
                    love.graphics.polygon("fill",
                        tx, -3 * open,
                        tx - 1.1, -0.3,
                        tx + 1.1, -0.3)
                    love.graphics.polygon("fill",
                        tx,  3 * open,
                        tx - 1.1,  0.3,
                        tx + 1.1,  0.3)
                end
                -- Slit reptilian eye above the jaw
                love.graphics.setColor(sec[1], sec[2], sec[3])
                love.graphics.circle("fill", -1, -13, 1.7)
                love.graphics.setColor(0, 0, 0)
                love.graphics.ellipse("fill", -1, -13, 0.5, 1.3)
                love.graphics.pop()
            end
            -- Central subtle purple rune on the shell
            love.graphics.setColor(sec[1], sec[2], sec[3], 0.35)
            love.graphics.circle("line", 0, 0, 3)
            love.graphics.line(-3, 0, 3, 0)
            love.graphics.line(0, -3, 0, 3)
        end
    end
    love.graphics.setColor(deep)
    love.graphics.circle("line", 0, 0, self.r)

    -- Eyes + hat: if the "upright head" toggle is enabled (persist flag),
    -- draw them AFTER the body-rotation pop so they're always world-upright.
    -- Otherwise they rotate with the body like before.
    local upright = self.uprightHead
    if not upright then
        love.graphics.push()
        self:_drawEyes(c.eye, deep)
        love.graphics.pop()
        self:_drawHat(c.hat)
    end

    love.graphics.pop()

    if upright then
        self:_drawEyes(c.eye, deep)
        self:_drawHat(c.hat)
    end

    -- Claws / gun rotate INDEPENDENTLY toward mouse (already drawn under body
    -- in the swimming/Void Sea branch above).
    if not self.swimming then
        love.graphics.push()
        love.graphics.rotate(self.angle)
        self:_drawClaws(body, deep, c.claw)
        self:_drawGun(c.gun or "pistol")
        love.graphics.pop()
    end

    love.graphics.pop()

    -- Orbs — suppressed in the Void Sea (nothing orbits the crab there)
    if self.stats.orbs > 0 and not self.swimming then
        for i = 1, self.stats.orbs do
            local a = self.orbAngle + (i - 1) * (math.pi * 2 / self.stats.orbs)
            local ox = self.x + math.cos(a) * 60
            local oy = self.y + math.sin(a) * 60
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.circle("fill", ox, oy, 6)
            love.graphics.setColor(1, 1, 0.8)
            love.graphics.circle("fill", ox, oy, 3)
        end
    end

    -- Laser beam(s) — render all beams when Prism Split is active
    if self.laserActive and self.laserEnds then
        local widthMult = self.laserWidthMult or 1
        local outer = 6 * widthMult
        local inner = 2 * widthMult
        local boost = self.laserDmgMult or 1
        local outerColor = {1, 0.3, 0.2, 0.7 * math.min(1, boost)}
        if boost > 1 then outerColor = {1, 0.8, 0.3, 0.85} end
        for _, endPt in ipairs(self.laserEnds) do
            love.graphics.setColor(outerColor)
            love.graphics.setLineWidth(outer)
            love.graphics.line(self.x, self.y, endPt[1], endPt[2])
            love.graphics.setColor(1, 0.9, 0.8, 1)
            love.graphics.setLineWidth(inner)
            love.graphics.line(self.x, self.y, endPt[1], endPt[2])
            -- Core bright line
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(math.max(1, inner * 0.4))
            love.graphics.line(self.x, self.y, endPt[1], endPt[2])
        end
    end

    -- Rail charge
    if self.railChargeTime > 0 then
        local r = 8 + self.railChargeTime * 20
        love.graphics.setColor(1, 1, 0.3, 0.6)
        love.graphics.circle("line", self.x + math.cos(self.angle)*30, self.y + math.sin(self.angle)*30, r)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1,1,1,1)
end

return Player
