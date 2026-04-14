-- Sound debug menu: audition every SFX and music theme in the game.
-- Triggered by holding Shift+Space and tapping S. Keys inside:
--   up/down    — select item (auto-repeat after 0.7s hold)
--   enter      — play the selected item (SFX fires once; music swaps/plays)
--   backspace  — stop all music
--   i          — toggle UI
--   escape     — leave
local Audio = require("src.audio")

local DS = {}

-- Build the item list once on first access
local function buildItems()
    local items = {}
    -- SFX
    local sfxOrder = {
        "shoot", "shoot2", "hit", "enemyHit", "kill", "hurt",
        "card", "wave", "victory", "defeat", "boss", "dash",
        "explode", "select", "whisper", "eldritch", "cthulhu", "glitch",
    }
    for _, name in ipairs(sfxOrder) do
        items[#items + 1] = {kind = "sfx", id = name, name = "SFX: " .. name}
    end
    -- Music themes (main run music rotation)
    local themeOrder = {
        "default", "synthwave", "chiptune", "doom", "lofi", "vapor",
        "eldritch_theme", "jazz", "drumnbass", "choir", "arcade",
        "whisperwave_epic", -- unlisted epic chill track, debug-only
    }
    for _, id in ipairs(themeOrder) do
        items[#items + 1] = {kind = "theme", id = id, name = "Theme: " .. id}
    end
    -- Special music tracks
    local special = {
        {id = "normal",   name = "Music: Normal (current theme)"},
        {id = "boss",     name = "Music: Boss"},
        {id = "eldritch", name = "Music: Eldritch"},
        {id = "voidsea",  name = "Music: Void Sea"},
    }
    for _, t in ipairs(special) do
        items[#items + 1] = {kind = "music", id = t.id, name = t.name}
    end
    return items
end

DS.items = buildItems()

local function play(game, idx)
    local item = DS.items[idx]
    if not item then return end
    game._dsLastPlayed = item.name
    game._dsLastPlayedT = love.timer.getTime()
    if item.kind == "sfx" then
        Audio:play(item.id)
    elseif item.kind == "theme" then
        -- Swap theme AND start it playing so you actually hear it
        Audio:setTheme(item.id)
        Audio:playMusic("normal")
    elseif item.kind == "music" then
        Audio:playMusic(item.id)
    end
end

function DS.keypressed(game, key)
    if key == "escape" then
        Audio:stopMusic()
        game.state = game._dsPrevState or "menu"
    elseif key == "up" then
        game.debugSoundIndex = math.max(1, (game.debugSoundIndex or 1) - 1)
    elseif key == "down" then
        game.debugSoundIndex = math.min(#DS.items, (game.debugSoundIndex or 1) + 1)
    elseif key == "return" or key == "kpenter" then
        play(game, game.debugSoundIndex or 1)
    elseif key == "backspace" then
        Audio:stopMusic()
        game._dsLastPlayed = "(music stopped)"
        game._dsLastPlayedT = love.timer.getTime()
    elseif key == "i" then
        game.debugSoundHideUI = not game.debugSoundHideUI
    end
end

-- Hold up/down for 0.7s to auto-scroll through the list fast.
function DS.update(game, dt)
    local upHeld   = love.keyboard.isDown("up")
    local downHeld = love.keyboard.isDown("down")
    if upHeld and not downHeld then
        game._dsHoldDir = -1
    elseif downHeld and not upHeld then
        game._dsHoldDir = 1
    else
        game._dsHoldDir = 0
        game._dsHoldT   = 0
        game._dsRepeatT = 0
        return
    end
    game._dsHoldT = (game._dsHoldT or 0) + dt
    if game._dsHoldT > 0.7 then
        game._dsRepeatT = (game._dsRepeatT or 0) - dt
        if game._dsRepeatT <= 0 then
            game._dsRepeatT = 0.04
            local n = #DS.items
            game.debugSoundIndex = ((game.debugSoundIndex or 1) - 1 + game._dsHoldDir) % n + 1
        end
    end
end

function DS.draw(game)
    local idx = game.debugSoundIndex or 1
    if idx > #DS.items then idx = 1 end
    love.graphics.clear(0.06, 0.05, 0.09)

    local item = DS.items[idx]

    if game.debugSoundHideUI then
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 6, 696, 76, 18)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setFont(game.font)
        love.graphics.print("I: UI", 12, 698)
        return
    end

    -- Header
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setFont(game.titleFont or game.bigFont or game.font)
    love.graphics.printf("SOUND DEBUG", 0, 30, 1280, "center")
    love.graphics.setFont(game.bigFont or game.font)
    love.graphics.setColor(1, 0.9, 0.4, 0.95)
    love.graphics.printf(item.name, 0, 110, 1280, "center")
    love.graphics.setFont(game.font)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(string.format("(%d / %d)", idx, #DS.items), 0, 160, 1280, "center")

    -- "Now playing" indicator
    if game._dsLastPlayed then
        local age = love.timer.getTime() - (game._dsLastPlayedT or 0)
        local a = math.max(0, 1 - age / 2.5)
        love.graphics.setColor(0.5, 1, 0.6, 0.9 * a)
        love.graphics.printf("▶ " .. game._dsLastPlayed, 0, 188, 1280, "center")
    end

    -- Centered list window
    local listX, listY = 440, 240
    local listW, listH = 400, 400
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", listX, listY, listW, listH)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("line", listX, listY, listW, listH)
    local span = 18
    local start = math.max(1, math.min(idx - math.floor(span / 2), #DS.items - span + 1))
    if start < 1 then start = 1 end
    local stop = math.min(#DS.items, start + span - 1)
    for i = start, stop do
        if i == idx then
            love.graphics.setColor(1, 0.85, 0.4, 1)
            love.graphics.rectangle("fill", listX + 6, listY + 10 + (i - start) * 20 - 2, listW - 12, 18)
            love.graphics.setColor(0, 0, 0, 1)
        else
            love.graphics.setColor(1, 1, 1, 0.7)
        end
        love.graphics.print(string.format("  %3d. %s", i, DS.items[i].name),
            listX + 12, listY + 10 + (i - start) * 20)
    end

    -- Controls hint
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 684, 1280, 36)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(
        "UP/DOWN: select    ENTER: play    BACKSPACE: stop music    I: hide UI    ESC: exit",
        0, 695, 1280, "center")
end

return DS
