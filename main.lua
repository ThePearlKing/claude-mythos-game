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

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end
    Game:update(dt)
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
    local useWarp = Game.rippleShader and Game.frameCanvas
        and ((Game.state == "wave" and lvl >= 15) or inVoidsea)

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
            local wild = lvl - 25
            strength  = 3.0 + wild * 0.3
            maxRadius = 900 + wild * 150
            speed     = 0.7 + wild * 0.12
            ringCount = math.min(10, 5 + wild)
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

function love.wheelmoved(x, y)
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
