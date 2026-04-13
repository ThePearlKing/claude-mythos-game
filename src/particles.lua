local P = {}
P.list = {}

function P:clear()
    self.list = {}
end

function P:spawn(x, y, count, color, speed, life, size)
    speed = speed or 200
    life = life or 0.5
    size = size or 3
    for _ = 1, count do
        local a = math.random() * math.pi * 2
        local s = speed * (0.4 + math.random() * 0.8)
        table.insert(self.list, {
            x = x, y = y,
            vx = math.cos(a) * s,
            vy = math.sin(a) * s,
            life = life,
            maxLife = life,
            color = color,
            size = size,
        })
    end
end

function P:text(x, y, text, color, life)
    table.insert(self.list, {
        x = x, y = y, vx = 0, vy = -40,
        life = life or 0.8, maxLife = life or 0.8,
        color = color or {1,1,1}, text = text, size = 1,
    })
end

function P:update(dt)
    for i = #self.list, 1, -1 do
        local p = self.list[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vx = p.vx * 0.92
        p.vy = p.vy * 0.92
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.list, i)
        end
    end
end

function P:draw()
    for _, p in ipairs(self.list) do
        local a = p.life / p.maxLife
        local c = p.color
        love.graphics.setColor(c[1], c[2], c[3], a)
        if p.text then
            love.graphics.print(p.text, p.x, p.y)
        else
            love.graphics.circle("fill", p.x, p.y, p.size * a)
        end
    end
    love.graphics.setColor(1,1,1,1)
end

return P
