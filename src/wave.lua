local Enemy = require("src.enemy")

local Wave = {}

local function pick(list)
    return list[math.random(#list)]
end

-- Composition: enemy pool per wave and total enemy budget
local function composition(w, finalWave)
    -- finalWave = 0 means infinite; spawn OpenClaw every 20 waves starting at 20.
    if finalWave and finalWave > 0 and w == finalWave then
        return {boss = true}
    end
    if (not finalWave or finalWave == 0) and w >= 20 and w % 20 == 0 then
        return {boss = true}
    end
    local tiers = {
        -- Wave 1-3 easy
        {"chatgpt", "llama"},
        {"chatgpt", "llama", "gemini"},
        {"chatgpt", "gemini", "bing"},
        -- 4-6: introduce drones & drifters
        {"chatgpt", "gemini", "bing", "copilot", "drone"},
        {"gemini", "bing", "copilot", "perplexity", "drone", "drifter"},
        {"bing", "copilot", "perplexity", "meta", "drone", "swarm"},
        -- 7-9: snipers + mines
        {"gemini", "copilot", "perplexity", "meta", "grok", "drone", "sniper"},
        {"bing", "copilot", "meta", "grok", "deepseek", "mine", "drifter"},
        {"copilot", "meta", "grok", "deepseek", "windows", "drone", "sniper", "mine"},
        -- 10 mini-boss wave
        {"deepseek", "windows", "grok", "meta", "teleporter"},
        -- 11-19 ramp with more creative enemies
        {"deepseek", "windows", "grok", "meta", "copilot", "teleporter", "sniper"},
        {"windows", "grok", "deepseek", "bing", "meta", "mine", "swarm", "drone"},
        {"windows", "deepseek", "grok", "meta", "copilot", "gemini", "teleporter", "sniper"},
        {"windows", "deepseek", "grok", "meta", "perplexity", "mine", "drifter", "drone"},
        {"deepseek", "windows", "grok", "meta", "bing", "sniper", "teleporter"},
        {"windows", "deepseek", "grok", "meta", "swarm", "mine", "drifter", "sniper"},
        {"deepseek", "windows", "grok", "teleporter", "sniper", "drone"},
        {"deepseek", "windows", "grok", "copilot", "meta", "sniper", "mine", "teleporter", "swarm"},
        {"deepseek", "windows", "grok", "teleporter", "sniper", "mine", "drifter"},
    }
    return {pool = tiers[math.min(w, #tiers)]}
end

function Wave.build(w, finalWave, hpMult, countMult, dmgMult, speedMult)
    finalWave = finalWave or 20
    hpMult = hpMult or 1
    countMult = countMult or 1
    dmgMult = dmgMult or 1
    speedMult = speedMult or 1
    local comp = composition(w, finalWave)
    local enemies = {}
    if comp.boss then
        -- Infinite mode: each boss appearance (every 20 waves) piles on more
        -- HP, damage, and minions than the last. Normal mode stays flat.
        local infinite = (finalWave == 0)
        local bossNum  = infinite and math.max(1, math.floor(w / 20)) or 1
        local bossHpScale    = infinite and (1 + (bossNum - 1) * 0.85) or 1
        local bossDmgScale   = infinite and (1 + (bossNum - 1) * 0.40) or 1
        local minionCount    = infinite and (10 + (bossNum - 1) * 3) or 10
        local minionHpScale  = infinite and (1 + (bossNum - 1) * 0.30) or 1
        local minionDmgScale = infinite and (1 + (bossNum - 1) * 0.25) or 1
        local minionSpdScale = infinite and (1 + (bossNum - 1) * 0.05) or 1

        local boss = Enemy.new("openclaw", 640, 200, 1)
        boss.hp    = boss.hp * hpMult * bossHpScale
        boss.maxHp = boss.maxHp * hpMult * bossHpScale
        boss.dmg   = boss.dmg * dmgMult * bossDmgScale
        table.insert(enemies, boss)
        -- Much more intense add wave: stronger minions, continuous pressure
        for i = 1, minionCount do
            local t = pick({"grok", "meta", "deepseek", "windows"})
            local x = 100 + math.random() * 1080
            local y = 100 + math.random() * 300
            local e = Enemy.new(t, x, y, 1.5)
            e.hp    = e.hp * hpMult * minionHpScale
            e.maxHp = e.maxHp * hpMult * minionHpScale
            e.dmg   = e.dmg * dmgMult * 1.3 * minionDmgScale
            e.speed = e.speed * speedMult * 1.15 * minionSpdScale
            e.spawnDelay = i * 1.0
            table.insert(enemies, e)
        end
        return enemies, true
    end

    -- Balanced scaling: enough pressure to be threatening, not so much you can't streak.
    local count = math.floor((5 + w * 1.5) * countMult)
    if w >= 5 then count = count + 1 end
    if w >= 10 then count = count + 3 end
    if w >= 15 then count = count + 3 end
    -- HP/damage scale grows steadily, moderate late-game ramp
    local scale = 1 + (w - 1) * 0.14 + math.max(0, w - 10) * 0.06
    for i = 1, count do
        local t = pick(comp.pool)
        local side = math.random(1, 4)
        local x, y
        if side == 1 then x = math.random(0, 1280); y = 60
        elseif side == 2 then x = math.random(0, 1280); y = 720
        elseif side == 3 then x = 20; y = math.random(80, 700)
        else x = 1260; y = math.random(80, 700) end
        local e = Enemy.new(t, x, y, scale)
        e.hp = e.hp * hpMult; e.maxHp = e.maxHp * hpMult
        e.dmg = e.dmg * dmgMult; e.speed = e.speed * speedMult
        -- Gentler late-game damage/speed ramp
        if w >= 10 then e.dmg = e.dmg * (1 + (w - 10) * 0.05) end
        if w >= 15 then e.speed = e.speed * 1.08; e.fireRate = e.fireRate * 1.10 end
        -- Enemies spawn in faster, tighter waves
        e.spawnDelay = (i - 1) * 0.15
        table.insert(enemies, e)
    end
    return enemies, false
end

return Wave
