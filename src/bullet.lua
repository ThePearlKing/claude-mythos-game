local P = require("src.particles")
local Audio = require("src.audio")

local Bullet = {}
Bullet.__index = Bullet

function Bullet.new(x, y, vx, vy, damage, friendly)
    local self = setmetatable({}, Bullet)
    self.x, self.y = x, y
    self.vx, self.vy = vx, vy
    self.damage = damage
    self.friendly = friendly
    self.size = 5
    self.life = 2.5
    self.pierce = 0
    self.bounce = 0
    self.homing = 0
    self.explosive = 0
    self.explodeRadius = 60
    self.freeze = 0
    self.burn = 0
    self.chain = 0
    self.chainRange = 150
    self.split = 0
    self.crit = 0
    self.critMult = 2.0
    self.lifesteal = 0
    self.hit = {}
    self.color = friendly and {1, 0.6, 0.2} or {0.6, 0.8, 1}
    self.dead = false
    return self
end

function Bullet:update(dt, game)
    self.life = self.life - dt
    if self.life <= 0 then self.dead = true; return end

    -- Homing
    if self.homing > 0 and self.friendly then
        local nearest, nd = nil, 99999
        for _, e in ipairs(game.enemies) do
            local d = (e.x - self.x)^2 + (e.y - self.y)^2
            if d < nd then nd = d; nearest = e end
        end
        if nearest then
            local ta = math.atan2(nearest.y - self.y, nearest.x - self.x)
            local ca = math.atan2(self.vy, self.vx)
            local diff = ta - ca
            while diff > math.pi do diff = diff - math.pi * 2 end
            while diff < -math.pi do diff = diff + math.pi * 2 end
            ca = ca + diff * self.homing * dt
            local sp = math.sqrt(self.vx^2 + self.vy^2)
            self.vx = math.cos(ca) * sp
            self.vy = math.sin(ca) * sp
        end
    end

    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Walls (bounce or die)
    local bounced = false
    if self.x < 0 or self.x > 1280 then
        if self.bounce > 0 then
            self.vx = -self.vx
            self.bounce = self.bounce - 1
            if self.bounceDmgStack then self.damage = self.damage * 1.2 end
            bounced = true
        else self.dead = true end
    end
    if self.y < 40 or self.y > 720 then
        if self.bounce > 0 then
            self.vy = -self.vy
            self.bounce = self.bounce - 1
            if self.bounceDmgStack then self.damage = self.damage * 1.2 end
            bounced = true
        else self.dead = true end
    end

    if self.trail then
        P:spawn(self.x, self.y, 1, self.color, 40, 0.2, 2)
    end
end

function Bullet:onHit(target, game)
    local dmg = self.damage
    local isCrit = math.random() < self.crit
    if isCrit then dmg = dmg * self.critMult end

    target:damage(dmg, self.owner, game, isCrit)

    if self.freeze > 0 then target.freezeTime = math.max(target.freezeTime or 0, self.freeze) end
    if self.burn > 0 then target.burnTime = math.max(target.burnTime or 0, 4.5); target.burnDmg = self.burn end

    if self.lifesteal > 0 and self.owner then
        self.owner:heal(dmg * self.lifesteal)
    end

    if self.explosive > 0 then
        local r = self.explodeRadius
        -- Visible expanding ring shockwave
        table.insert(game.shockwaves or {}, {x = self.x, y = self.y, r = 0, max = r, life = 0.35, color = {1, 0.6, 0.1}})
        P:spawn(self.x, self.y, 40, {1, 0.6, 0.1}, 380, 0.55, 6)
        P:spawn(self.x, self.y, 20, {1, 0.9, 0.3}, 200, 0.3, 4)
        Audio:play("explode")
        for _, e in ipairs(game.enemies) do
            if e ~= target then
                local d = (e.x - self.x)^2 + (e.y - self.y)^2
                if d < r * r then
                    -- Full AoE damage, slight falloff at the edge
                    local falloff = 1 - (math.sqrt(d) / r) * 0.3
                    e:damage(dmg * falloff, self.owner, game)
                end
            end
        end
    end

    if self.chain > 0 then
        local chained = 0
        local src = target
        local hitSet = {[target] = true}
        while chained < self.chain do
            local nearest, nd = nil, self.chainRange * self.chainRange
            for _, e in ipairs(game.enemies) do
                if not hitSet[e] then
                    local d = (e.x - src.x)^2 + (e.y - src.y)^2
                    if d < nd then nd = d; nearest = e end
                end
            end
            if not nearest then break end
            -- Draw chain lightning effect via particles
            local steps = 8
            for i = 1, steps do
                local t = i / steps
                local px = src.x + (nearest.x - src.x) * t + math.random(-6, 6)
                local py = src.y + (nearest.y - src.y) * t + math.random(-6, 6)
                P:spawn(px, py, 1, {0.6, 0.8, 1}, 30, 0.2, 2)
            end
            nearest:damage(dmg * 0.7, self.owner, game)
            hitSet[nearest] = true
            src = nearest
            chained = chained + 1
        end
    end

    if self.split > 0 and self.friendly then
        for i = 1, 3 do
            local a = math.random() * math.pi * 2
            local sp = math.sqrt(self.vx^2 + self.vy^2) * 0.7
            local b = Bullet.new(self.x, self.y, math.cos(a)*sp, math.sin(a)*sp, self.damage * 0.4, true)
            b.size = self.size * 0.6
            b.owner = self.owner
            b.color = self.color
            table.insert(game.bullets, b)
        end
        self.split = 0
    end

    if self.pierce > 0 then
        self.pierce = self.pierce - 1
        self.hit[target] = true
    else
        self.dead = true
    end
end

function Bullet:draw()
    if self.churglyBigAttack then
        -- Cracked orb — dark shell with 4 bright fracture lines leaking
        -- yellow-white light from the core. Pulses to signal "shoot me".
        local t = love.timer.getTime()
        local pulse = 0.75 + 0.25 * math.sin(t * 6)
        -- Outer purple halo (telegraph)
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.4 * pulse)
        love.graphics.circle("fill", self.x, self.y, self.size * 1.6)
        -- Shell
        love.graphics.setColor(0.22, 0.02, 0.35)
        love.graphics.circle("fill", self.x, self.y, self.size)
        love.graphics.setColor(self.color[1], self.color[2], self.color[3])
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", self.x, self.y, self.size)
        -- Bright fracture cracks radiating from center (leaking light)
        love.graphics.setColor(1, 1, 0.6, 0.9 * pulse)
        love.graphics.setLineWidth(2.5)
        for i = 0, 3 do
            local a = (i / 4) * math.pi * 2 + t * 0.4
            local r1 = self.size * 0.15
            local r2 = self.size * 1.05
            love.graphics.line(
                self.x + math.cos(a) * r1, self.y + math.sin(a) * r1,
                self.x + math.cos(a) * r2, self.y + math.sin(a) * r2)
        end
        -- Secondary thinner cracks
        love.graphics.setColor(1, 0.95, 0.4, 0.6 * pulse)
        love.graphics.setLineWidth(1)
        for i = 0, 3 do
            local a = (i / 4) * math.pi * 2 + math.pi / 4 + t * 0.4
            love.graphics.line(
                self.x + math.cos(a) * self.size * 0.2,
                self.y + math.sin(a) * self.size * 0.2,
                self.x + math.cos(a) * self.size * 0.85,
                self.y + math.sin(a) * self.size * 0.85)
        end
        -- Hot white core
        love.graphics.setColor(1, 1, 0.9, pulse)
        love.graphics.circle("fill", self.x, self.y, self.size * 0.25 * pulse)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    love.graphics.setColor(self.color[1], self.color[2], self.color[3])
    love.graphics.circle("fill", self.x, self.y, self.size)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("fill", self.x, self.y, self.size * 0.5)
    love.graphics.setColor(1,1,1,1)
end

return Bullet
