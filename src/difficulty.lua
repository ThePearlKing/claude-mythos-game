-- Global difficulty modifier applied to normal (non-custom) runs.
-- Each level defines enemy/player multipliers and a color for the UI pill.

local Difficulty = {}

Difficulty.levels = {
    {id = "chill",      name = "CHILL",      color = {0.4, 0.9, 0.5},
        enemyHp = 0.70, enemyDmg = 0.55, spawnCount = 0.85, playerHpBonus = 40,  repMult = 0.4, desc = "Relaxed pace. Reputation gains reduced."},
    {id = "easy",       name = "EASY",       color = {0.5, 1.0, 0.4},
        enemyHp = 0.85, enemyDmg = 0.75, spawnCount = 0.95, playerHpBonus = 20,  repMult = 0.65, desc = "Forgiving. Reputation gains reduced."},
    {id = "normal",     name = "NORMAL",     color = {0.9, 0.9, 0.9},
        enemyHp = 0.92, enemyDmg = 0.92, spawnCount = 0.95, playerHpBonus = 10,  repMult = 1.0, desc = "As designed. Tuned for streaks."},
    {id = "hard",       name = "HARD",       color = {1.0, 0.65, 0.2},
        enemyHp = 1.25, enemyDmg = 1.30, spawnCount = 1.15, playerHpBonus = 0,   repMult = 1.35, desc = "Sharp fangs. Reputation +35%."},
    {id = "nightmare",  name = "NIGHTMARE",  color = {1.0, 0.25, 0.25},
        enemyHp = 1.55, enemyDmg = 1.45, spawnCount = 1.30, playerHpBonus = 0,   repMult = 1.7, desc = "You will bleed. Reputation +70%."},
    {id = "apocalypse", name = "APOCALYPSE", color = {0.8, 0.0, 0.9},
        enemyHp = 1.80, enemyDmg = 1.45, spawnCount = 1.40, playerHpBonus = 0,   repMult = 2.1, desc = "The tech hive descends. Reputation x2.1."},
}

function Difficulty.defaultId() return "normal" end

function Difficulty.indexOf(id)
    for i, lvl in ipairs(Difficulty.levels) do
        if lvl.id == id then return i end
    end
    return 3 -- normal
end

function Difficulty.get(id)
    local i = Difficulty.indexOf(id or Difficulty.defaultId())
    return Difficulty.levels[i]
end

function Difficulty.cycle(id, dir)
    local i = Difficulty.indexOf(id)
    i = i + dir
    if i < 1 then i = #Difficulty.levels end
    if i > #Difficulty.levels then i = 1 end
    return Difficulty.levels[i].id
end

return Difficulty
