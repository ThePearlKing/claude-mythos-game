local Game = require("src.game")

-- Fixed internal game resolution. The window can be any size; the rendered
-- game is letterboxed with black bars so the 16:9 aspect ratio is preserved.
local GAME_W, GAME_H = 1280, 720
local gameCanvas

-- Current letterbox fit (updated every frame and used for mouse mapping)
local fitScale, fitOffX, fitOffY = 1, 0, 0

local function computeFit()
    local ww, wh = love.graphics.getDimensions()
    fitScale = math.min(ww / GAME_W, wh / GAME_H)
    fitOffX = (ww - GAME_W * fitScale) * 0.5
    fitOffY = (wh - GAME_H * fitScale) * 0.5
end

local function windowToGame(x, y)
    if fitScale <= 0 then return x, y end
    return (x - fitOffX) / fitScale, (y - fitOffY) / fitScale
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    math.randomseed(os.time())
    love.mouse.setVisible(true)  -- menus use OS cursor; game state hides it

    gameCanvas = love.graphics.newCanvas(GAME_W, GAME_H)
    gameCanvas:setFilter("linear", "linear")
    computeFit()

    -- Monkey-patch love.mouse.getPosition so every caller (Player aim, UI
    -- hover checks, etc.) sees positions in the fixed 1280x720 game frame.
    local realGetPosition = love.mouse.getPosition
    love.mouse.getPosition = function()
        local mx, my = realGetPosition()
        return windowToGame(mx, my)
    end
    local realGetX = love.mouse.getX
    love.mouse.getX = function()
        local mx = realGetX()
        return (mx - fitOffX) / math.max(0.0001, fitScale)
    end
    local realGetY = love.mouse.getY
    love.mouse.getY = function()
        local my = realGetY()
        return (my - fitOffY) / math.max(0.0001, fitScale)
    end

    Game:load()
end

function love.resize(w, h)
    computeFit()
end

-- Frame-accumulated mouse motion for direction-mode aim
local _aimDX, _aimDY = 0, 0

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end
    Game:update(dt)
    -- Mouse-lock management: relative mode only during gameplay (wave /
    -- voidsea) AND aim mode "direction" (1). Menus all release the mouse.
    local aimMode = (Game.persist and Game.persist.aimMode) or 0
    local gameplay = Game.state == "wave" or Game.state == "voidsea"
    local wantLock = (aimMode == 1) and gameplay
    if love.mouse.getRelativeMode() ~= wantLock then
        love.mouse.setRelativeMode(wantLock)
    end
    -- Direction-mode aim integration. Smoothly tracks a "stick velocity":
    -- raw mouse deltas decay each frame, and the aim angle lerps toward
    -- their direction. Eliminates micro-shake while still reacting fast.
    if wantLock then
        Game._aimVx = (Game._aimVx or 0) * 0.55 + _aimDX
        Game._aimVy = (Game._aimVy or 0) * 0.55 + _aimDY
        _aimDX, _aimDY = 0, 0
        local mag = math.sqrt(Game._aimVx * Game._aimVx + Game._aimVy * Game._aimVy)
        if mag > 1.2 then
            local targetAngle = math.atan2(Game._aimVy, Game._aimVx)
            local cur = Game._dirAim or targetAngle
            local diff = targetAngle - cur
            while diff > math.pi do diff = diff - math.pi * 2 end
            while diff < -math.pi do diff = diff + math.pi * 2 end
            -- Lerp speed scales with motion magnitude — slow flicks settle
            -- gently, fast flicks snap quickly
            local lerp = math.min(1, dt * (10 + math.min(mag, 60) * 0.6))
            Game._dirAim = cur + diff * lerp
        end
    else
        _aimDX, _aimDY = 0, 0
        Game._aimVx, Game._aimVy = 0, 0
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    -- Accumulate raw motion deltas; love.update applies them with smoothing
    local aimMode = (Game.persist and Game.persist.aimMode) or 0
    if aimMode == 1 then
        _aimDX = _aimDX + (dx or 0)
        _aimDY = _aimDY + (dy or 0)
    end
end

function love.draw()
    -- Render the entire game to the fixed-size canvas.
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear(0, 0, 0, 1)

    -- REAL pixel-displacement ripples:
    --   * Kick in at eldritch level >= 15 during a wave (scaling stronger every
    --     few levels — 15 / 20 / 22 / 24 / 25+).
    --   * Also always active inside the Void Sea dive (regardless of level).
    local lvl = Game.player and Game.player.eldritch and Game.player.eldritch.level or 0
    local inVoidsea = Game.state == "voidsea"
    local kingVis = Game.player and Game.player.kingVisions
    local backfiring = Game.backfireHold and Game.backfireHold > 0
    local useWarp = Game.rippleShader and Game.frameCanvas
        and ((Game.state == "wave" and lvl >= 15) or inVoidsea or backfiring)

    if useWarp then
        love.graphics.setCanvas(Game.frameCanvas)
        love.graphics.clear()
        Game:draw()
        -- Return to gameCanvas for the shader pass
        love.graphics.setCanvas(gameCanvas)

        local strength = 1.0
        local maxRadius = 180
        local speed = 0.6
        local ringCount = 2
        local globalWarp = 0
        local globalSpeed = 0.5
        if inVoidsea then
            strength, maxRadius, speed, ringCount = 0.4, 260, 0.25, 2
            globalWarp = 0.55
            globalSpeed = 0.3
        elseif lvl >= 25 then
            -- Toned down — past 25 used to be chaos, now stays manageable
            local wild = lvl - 25
            strength  = 0.9 + wild * 0.08
            maxRadius = 420 + wild * 60
            speed     = 0.45 + wild * 0.04
            ringCount = math.min(5, 3 + math.floor(wild / 2))
        elseif lvl >= 24 then
            strength, maxRadius, speed, ringCount = 2.2, 720, 0.6, 4
        elseif lvl >= 20 then
            strength, maxRadius, speed, ringCount = 1.3, 280, 0.4, 2
        elseif lvl >= 15 then
            strength, maxRadius, speed, ringCount = 0.35, 130, 0.28, 1
        end

        if kingVis and not inVoidsea then
            strength   = strength * 0.25
            maxRadius  = maxRadius * 0.5
            speed      = speed * 0.7
            ringCount  = math.max(1, math.floor(ringCount * 0.5))
            globalWarp = globalWarp * 0.3
        end

        local eld = Game.player and Game.player.eldritch
        if eld and eld.kingOblit then
            strength   = strength * 0.1
            maxRadius  = maxRadius * 0.3
            globalWarp = globalWarp * 0.1
        end
        -- Boss fight — calm ripples so the fight reads cleanly
        if Game.churglyBoss then
            strength   = strength * 0.15
            maxRadius  = maxRadius * 0.35
            globalWarp = globalWarp * 0.1
        end

        -- Ugnrak backfire: noticeable chaos ripples on top of everything,
        -- but not eye-searing.
        if backfiring then
            strength   = 1.6
            maxRadius  = 560
            speed      = 0.55
            ringCount  = 4
            globalWarp = 0.35
            globalSpeed = 0.45
        end

        local sh = Game.rippleShader
        sh:send("t", love.timer.getTime())
        sh:send("strength", strength)
        sh:send("maxRadius", maxRadius)
        sh:send("speed", speed)
        sh:send("ringCount", ringCount)
        sh:send("cA", {0, 0})
        sh:send("cB", {GAME_W, 0})
        sh:send("cC", {0, GAME_H})
        sh:send("cD", {GAME_W, GAME_H})
        -- Fifth ripple source at the vanishing point — Churgly's "black hole"
        -- center where his three serpent forms converge.
        sh:send("cE", {GAME_W * 0.5, GAME_H * 0.5})
        -- Void only ripples within ~8px (twice the void ring radius of ~4)
        sh:send("cERadius", 8)
        sh:send("globalWarp", globalWarp)
        sh:send("globalSpeed", globalSpeed)
        love.graphics.setShader(sh)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Game.frameCanvas, 0, 0)
        love.graphics.setShader()
    else
        Game:draw()
    end

    -- Blit the game canvas to the window, letterboxed with black bars.
    love.graphics.setCanvas()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(gameCanvas, fitOffX, fitOffY, 0, fitScale, fitScale)
end

function love.keypressed(key)
    if key == "escape" then
        if Game.state == "wave" or Game.state == "voidsea" then
            Game._resumeTo = Game.state
            Game.state = "paused"
            return
        elseif Game.state == "menu" or Game.state == "gameover" or Game.state == "victory" then
            love.event.quit()
            return
        end
    end
    Game:keypressed(key)
end

function love.mousepressed(x, y, button)
    local gx, gy = windowToGame(x, y)
    Game:mousepressed(gx, gy, button)
end

function love.mousereleased(x, y, button)
    local gx, gy = windowToGame(x, y)
    Game:mousereleased(gx, gy, button)
end

function love.quit()
    -- Best-effort clean leave so we don't linger as a stale member in any
    -- multiplayer room when the player closes the game. The portal's
    -- 60s heartbeat eviction would catch us eventually but firing the
    -- leave verb makes our seat free up immediately.
    local ok, MP = pcall(require, "src.multiplayer")
    if ok and MP then pcall(MP.leave) end
end

function love.textinput(text)
    -- Forward to MP lobby/create text fields when those screens are open
    if Game.state == "mp_menu" then
        local UI = require("src.ui")
        UI:mpMenuText(Game, text)
    elseif Game.state == "mp_create" then
        local UI = require("src.ui")
        UI:mpCreateText(Game, text)
    elseif Game.state == "wave" and Game.chat and Game.chat.open then
        -- Skip the very first character that opened the chat (T or /)
        if Game.chat._justOpened then
            Game.chat._justOpened = false
            return
        end
        local s = Game.chat.text or ""
        -- Skip space — handled by game.lua's wave keypressed so love.js
        -- builds that don't fire textinput for space still get spaces
        -- without doubling on desktop.
        for c in text:gmatch(".") do
            if #s < 120 and c ~= "\n" and c ~= " " then s = s .. c end
        end
        Game.chat.text = s
    end
end

function love.wheelmoved(x, y)
    -- love.js forwards raw WheelEvent.deltaY (often 100+ pixels per tick)
    -- instead of the ±1 ticks native LÖVE sends. Clamp so the web build
    -- scrolls at the same pace as the desktop build.
    if y > 1 then y = 1 elseif y < -1 then y = -1 end
    if x > 1 then x = 1 elseif x < -1 then x = -1 end
    if Game.state == "custom" then
        Game.customScroll = (Game.customScroll or 0) - y
    elseif Game.state == "customise" then
        Game.customiseScrollTarget = (Game.customiseScrollTarget or Game.customiseScroll or 0) - y * 40
    elseif Game.state == "playlist" then
        Game.playlistScrollTarget = (Game.playlistScrollTarget or Game.playlistScroll or 0) - y * 40
    elseif Game.state == "aesthetics" then
        Game.aestheticsScrollTarget = (Game.aestheticsScrollTarget or Game.aestheticsScroll or 0) - y * 40
    end
end
