local Cards = require("src.cards")
local Difficulty = require("src.difficulty")

local UI = {}

local function setFonts(big, reg, small)
    UI.bigFont = big
    UI.font = reg
    UI.smallFont = small
end

function UI:init(bigFont, regFont, smallFont, titleFont)
    self.bigFont = bigFont
    self.font = regFont
    self.smallFont = smallFont
    self.titleFont = titleFont
end

local function darkBox(x, y, w, h, alpha)
    alpha = alpha or 0.7
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
end

local GLITCH_CHARS = "!@#$%&*+=?/\\|<>[]{}~^"
local function glitchText(s, intensity)
    intensity = intensity or 0.3
    local out = {}
    for i = 1, #s do
        local ch = s:sub(i, i)
        if ch ~= " " and math.random() < intensity then
            local pick = math.random(1, #GLITCH_CHARS)
            out[i] = GLITCH_CHARS:sub(pick, pick)
        else
            out[i] = ch
        end
    end
    return table.concat(out)
end

local function glitchPrint(text, x, y, w, align, intensity)
    -- Multi-layer chromatic offset
    love.graphics.setColor(1, 0, 0.4, 0.6)
    love.graphics.printf(glitchText(text, intensity), x - 3, y, w, align)
    love.graphics.setColor(0, 0.8, 1, 0.6)
    love.graphics.printf(glitchText(text, intensity), x + 3, y, w, align)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(glitchText(text, intensity * 0.5), x, y, w, align)
end

function UI:drawHUD(game)
    love.graphics.setFont(self.font)
    local p = game.player
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, 1280, 40)

    -- HP bar
    local hpw = 250
    love.graphics.setColor(0.2, 0.05, 0.05)
    love.graphics.rectangle("fill", 10, 10, hpw, 20)
    love.graphics.setColor(1, 0.25, 0.25)
    love.graphics.rectangle("fill", 10, 10, hpw * math.max(0, p.hp) / p.maxHp, 20)
    if p.stats.shield > 0 then
        love.graphics.setColor(0.4, 0.7, 1, 0.8)
        local sw = hpw * p.stats.shield / math.max(1, p.stats.shieldMax)
        love.graphics.rectangle("fill", 10, 10, sw, 8)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("%d / %d HP", math.max(0, math.floor(p.hp)), p.maxHp), 10, 13, hpw, "center")

    -- Wave
    love.graphics.setColor(1, 0.9, 0.5)
    local fw = game.finalWave or 20
    local waveStr
    if fw == 0 then
        waveStr = string.format("WAVE %d / INF", game.wave)
    else
        waveStr = string.format("WAVE %d / %d", game.wave, fw)
    end
    love.graphics.printf(waveStr, 280, 13, 200, "left")

    -- Score / Reputation
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Score: %d", math.floor(p.score)), 470, 13, 180, "left")

    local repColor = {0.5, 1, 0.5}
    if p.reputation < 50 then repColor = {1, 0.9, 0.3} end
    if p.reputation < 25 then repColor = {1, 0.4, 0.3} end
    love.graphics.setColor(repColor[1], repColor[2], repColor[3])
    love.graphics.printf(string.format("Reputation: %d", math.floor(p.reputation)), 650, 13, 200, "left")

    -- Cooldowns
    local cx = 870
    if p.stats.hasDash then
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", cx, 8, 90, 24)
        local frac = 1 - (p.dashCD / p.dashMax)
        love.graphics.setColor(0.9, 0.7, 0.3)
        love.graphics.rectangle("fill", cx, 8, 90 * frac, 24)
        love.graphics.setColor(1,1,1)
        love.graphics.printf(p.dashCD > 0 and string.format("SPACE %.1f", p.dashCD) or "SPACE ✓", cx, 13, 90, "center")
        cx = cx + 100
    end
    if p.stats.hasBomb then
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", cx, 8, 100, 24)
        local frac = 1 - (p.bombCD / p.bombMax)
        love.graphics.setColor(0.6, 0.3, 0.9)
        love.graphics.rectangle("fill", cx, 8, 100 * frac, 24)
        love.graphics.setColor(1,1,1)
        love.graphics.printf(p.bombCD > 0 and string.format("Q %.1f", p.bombCD) or "Q BOMB", cx, 13, 100, "center")
        cx = cx + 110
    end

    -- Wave timer / remaining
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Enemies: %d", #game.enemies), 1100, 13, 170, "left")
    love.graphics.setColor(1, 1, 1, 1)

    -- Ugnrak Beam prompt: as long as the player has the card AND enough
    -- shards, flash a "PRESS B" hint at center-top. Disappears the moment
    -- they fire (the card flag clears in fireUgnrakBeam).
    if p.ugnrakBeam then
        local rsCount
        if game.isCustom then rsCount = game.tempShards or 0
        else rsCount = (game.persist and game.persist.realityShards) or 0 end
        if rsCount >= 6 then
            local tt = love.timer.getTime()
            local pulse = 0.55 + math.abs(math.sin(tt * 3)) * 0.45
            love.graphics.setColor(1, 0.2, 0.2, pulse)
            love.graphics.setFont(self.bigFont or self.font)
            love.graphics.printf("PRESS B — UGNRAK BEAM READY", 0, 48, 1280, "center")
            love.graphics.setFont(self.font)
        end
    end

    -- Shard presence is signalled only via the pre-wave banner text
    -- ("N threats incoming • 1 Reality Shard") and the in-world shimmer —
    -- no persistent HUD pulse.

    -- Forbidden Tally: glitched eldritch counter in the HUD when the card is active.
    if p.eldritchCounterUnlocked then
        local lvl = (p.eldritch and p.eldritch.level) or 0
        local label = "ELDRITCH " .. lvl
        local tt = love.timer.getTime()
        local hx = 1060
        local hy = 42
        -- Chromatic-split glitch
        love.graphics.setColor(1, 0.1, 0.45, 0.75)
        love.graphics.print(glitchText(label, 0.25), hx - 2 + math.sin(tt * 20) * 1, hy)
        love.graphics.setColor(0.2, 0.9, 1, 0.75)
        love.graphics.print(glitchText(label, 0.25), hx + 2 + math.cos(tt * 18) * 1, hy)
        love.graphics.setColor(0.75, 0.4, 1, 1)
        love.graphics.print(glitchText(label, 0.15), hx, hy)
    end
end

function UI:drawCardChoice(game)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)
    love.graphics.setFont(self.bigFont)
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.printf("CHOOSE A CARD", 0, 40, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("Click a card or press 1/2/3/4/5", 0, 110, 1280, "center")

    local n = #game.cardChoices
    local cardW, cardH = 220, 320
    local gap = 30
    local totalW = n * cardW + (n - 1) * gap
    local startX = (1280 - totalW) / 2
    local startY = 180

    for i, card in ipairs(game.cardChoices) do
        local x = startX + (i - 1) * (cardW + gap)
        local y = startY
        local mx, my = love.mouse.getPosition()
        local hover = mx >= x and mx <= x + cardW and my >= y and my <= y + cardH
        if hover then y = y - 10 end

        local rc = Cards.rarityColor(card.rarity)
        love.graphics.setColor(rc[1] * 0.3, rc[2] * 0.3, rc[3] * 0.3, 0.95)
        love.graphics.rectangle("fill", x, y, cardW, cardH, 14, 14)
        love.graphics.setColor(rc[1], rc[2], rc[3], 1)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, cardW, cardH, 14, 14)
        love.graphics.setLineWidth(1)

        -- Rarity badge
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(rc[1], rc[2], rc[3], 1)
        love.graphics.rectangle("fill", x + 10, y + 10, cardW - 20, 22, 6, 6)
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(card.rarity:upper(), x + 10, y + 15, cardW - 20, "center")

        -- Icon area (big colored shape)
        local c = card.color or {1,1,1}
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.rectangle("fill", x + 20, y + 45, cardW - 40, 95, 8, 8)
        love.graphics.setFont(self.bigFont)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.printf(card.name:sub(1,1), x + 20, y + 65, cardW - 40, "center")

        -- Name
        love.graphics.setFont(self.font)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(card.name, x + 10, y + 155, cardW - 20, "center")

        -- Description
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.printf(card.desc, x + 14, y + 190, cardW - 28, "center")

        -- Number
        love.graphics.setFont(self.font)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf(tostring(i), x + 10, y + cardH - 30, cardW - 20, "center")

        card._bounds = {x, startY, cardW, cardH}
    end

    -- Skip option
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf("(skip: press F  -  +3 HP)", 0, 620, 1280, "center")

    -- Arm delay indicator
    if (game.cardArmTime or 0) > 0 then
        local pct = 1 - (game.cardArmTime / 0.7)
        love.graphics.setColor(0.8, 0.2, 0.3, 0.5)
        love.graphics.rectangle("fill", 440, 660, 400, 10, 4, 4)
        love.graphics.setColor(1, 0.6, 0.2, 0.9)
        love.graphics.rectangle("fill", 440, 660, 400 * pct, 10, 4, 4)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf("Arming...", 0, 675, 1280, "center")
    end
end

function UI:drawMenu(game)
    love.graphics.clear(0.05, 0.02, 0.1)
    love.graphics.setFont(self.titleFont)
    -- Stars
    for i = 1, 80 do
        local x = (i * 73) % 1280
        local y = (i * 137) % 720
        local a = 0.4 + math.sin(love.timer.getTime() * 2 + i) * 0.3
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.circle("fill", x, y, 1)
    end
    -- Once Void Sea has ever been unlocked, a glowing yellow sea hints at the bottom of the menu.
    if game.persist and (game.persist.voidSeaEverUnlocked or 0) == 1 then
        local t = love.timer.getTime()
        for i = 0, 18 do
            local y = 720 - i * 5
            local k = i / 18
            love.graphics.setColor(0.95, 0.78 + 0.12 * math.sin(t + i * 0.3), 0.15, 0.04 + k * 0.14)
            love.graphics.rectangle("fill", 0, y, 1280, 6)
        end
        -- Wave shimmer
        love.graphics.setColor(1, 0.9, 0.25, 0.12)
        for wx = 0, 1280, 22 do
            local wy = 700 + math.sin(t * 2 + wx * 0.03) * 4
            love.graphics.line(wx, wy, wx + 20, wy + math.sin(t * 2 + wx * 0.03 + 1) * 4)
        end
    end

    -- Title
    love.graphics.setColor(1, 0.55, 0.15)
    love.graphics.printf("CLAUDE: MYTHOS", 0, 120, 1280, "center")
    love.graphics.setFont(self.bigFont)
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.printf("Rise of Clawde", 0, 210, 1280, "center")

    -- Draw big crab (Orange Clawde)
    local t = love.timer.getTime()
    love.graphics.push()
    love.graphics.translate(640, 400)
    local scale = 2.6
    love.graphics.scale(scale, scale)

    local orange = {1, 0.55, 0.15}
    local deep = {0.75, 0.32, 0.08}
    local darkShell = {0.5, 0.2, 0.05}

    -- LEGS (4 per side) - drawn first so body overlaps
    love.graphics.setLineWidth(4)
    local legSway = math.sin(t * 4) * 2
    for side = -1, 1, 2 do
        for i = 1, 4 do
            local bx = side * (18 + i * 4)
            local by = 6 + (i - 2) * 4
            local legAng = (i - 2.5) * 0.2
            local ex = bx + side * (14 + math.sin(t * 3 + i) * 2)
            local ey = by + 16 + legSway
            local mx = (bx + ex) / 2 + side * 6
            local my = (by + ey) / 2
            love.graphics.setColor(deep)
            love.graphics.line(bx, by, mx, my)
            love.graphics.line(mx, my, ex, ey)
            -- Tiny foot
            love.graphics.setColor(darkShell)
            love.graphics.circle("fill", ex, ey, 1.5)
        end
    end

    -- CLAWS (with pincers, jointed) - drawn behind body sides
    local clawOpen = (math.sin(t * 2) + 1) * 0.5 -- 0..1
    for side = -1, 1, 2 do
        local baseX = side * 26
        local baseY = -6
        -- forearm
        local midX = side * 44
        local midY = -18
        love.graphics.setColor(deep)
        love.graphics.setLineWidth(6)
        love.graphics.line(baseX, baseY, midX, midY)
        -- upper arm ellipse
        love.graphics.setColor(orange)
        love.graphics.push()
        love.graphics.translate((baseX + midX)/2, (baseY + midY)/2)
        love.graphics.rotate(math.atan2(midY - baseY, midX - baseX))
        love.graphics.ellipse("fill", 0, 0, 11, 5)
        love.graphics.setColor(deep)
        love.graphics.ellipse("line", 0, 0, 11, 5)
        love.graphics.pop()

        -- Claw head (pincer) at end of forearm
        love.graphics.push()
        love.graphics.translate(midX, midY)
        love.graphics.rotate(side * -0.2)
        -- Palm
        love.graphics.setColor(orange)
        love.graphics.ellipse("fill", side * 10, 0, 14, 9)
        love.graphics.setColor(deep)
        love.graphics.ellipse("line", side * 10, 0, 14, 9)
        -- Upper pincer
        local po = clawOpen * 0.4
        love.graphics.push()
        love.graphics.translate(side * 20, -4)
        love.graphics.rotate(side * -po)
        love.graphics.setColor(orange)
        love.graphics.polygon("fill", 0, 0, side * 14, -3, side * 14, 1, 0, 4)
        love.graphics.setColor(deep)
        love.graphics.polygon("line", 0, 0, side * 14, -3, side * 14, 1, 0, 4)
        love.graphics.pop()
        -- Lower pincer
        love.graphics.push()
        love.graphics.translate(side * 20, 4)
        love.graphics.rotate(side * po)
        love.graphics.setColor(orange)
        love.graphics.polygon("fill", 0, 0, side * 14, 3, side * 14, -1, 0, -4)
        love.graphics.setColor(deep)
        love.graphics.polygon("line", 0, 0, side * 14, 3, side * 14, -1, 0, -4)
        love.graphics.pop()
        love.graphics.pop()
    end

    love.graphics.setLineWidth(1)

    -- BODY (shell): ellipse with segments
    love.graphics.setColor(orange)
    love.graphics.ellipse("fill", 0, 0, 32, 22)
    love.graphics.setColor(1, 0.7, 0.35)
    love.graphics.ellipse("fill", 0, -6, 26, 12)
    love.graphics.setColor(deep)
    love.graphics.ellipse("line", 0, 0, 32, 22)
    -- Shell segments
    love.graphics.setColor(0.85, 0.4, 0.1, 0.8)
    for i = -1, 1 do
        love.graphics.arc("line", "open", i * 8, 0, 22, math.pi * 1.1, math.pi * 1.9)
    end
    -- Shell spots
    love.graphics.setColor(deep)
    love.graphics.circle("fill", -12, 2, 1.5)
    love.graphics.circle("fill", 12, 2, 1.5)
    love.graphics.circle("fill", 0, 8, 1.5)

    -- EYE STALKS (two stalks with eyeballs on top)
    love.graphics.setColor(deep)
    love.graphics.setLineWidth(2.5)
    local blink = math.sin(t * 2.5) * 1
    love.graphics.line(-7, -12, -8, -22 + blink)
    love.graphics.line(7, -12, 8, -22 + blink)
    love.graphics.setLineWidth(1)
    -- Eyeballs
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", -8, -22 + blink, 4)
    love.graphics.circle("fill", 8, -22 + blink, 4)
    love.graphics.setColor(deep)
    love.graphics.circle("line", -8, -22 + blink, 4)
    love.graphics.circle("line", 8, -22 + blink, 4)
    -- Pupils (track mouse slightly)
    local mx, my = love.mouse.getPosition()
    local look = math.max(-1.5, math.min(1.5, (mx - 640) / 300))
    local lookY = math.max(-1.5, math.min(1.5, (my - 400) / 300))
    love.graphics.setColor(0, 0, 0)
    love.graphics.circle("fill", -8 + look, -22 + blink + lookY, 2)
    love.graphics.circle("fill", 8 + look, -22 + blink + lookY, 2)
    -- Tiny highlights
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", -9 + look, -23 + blink + lookY, 0.8)
    love.graphics.circle("fill", 7 + look, -23 + blink + lookY, 0.8)

    -- Little mouth
    love.graphics.setColor(deep)
    love.graphics.setLineWidth(1.5)
    love.graphics.arc("line", "open", 0, -2, 4, math.pi * 0.15, math.pi * 0.85)
    love.graphics.setLineWidth(1)

    love.graphics.pop()

    love.graphics.setFont(self.font)

    -- Menu buttons (6 across — kept on a single row, slightly narrower so
    -- the row still fits inside 1280px without crowding the difficulty meter).
    local buttons = {
        {label = "BEGIN [ENTER]",  action = "start",       color = {1, 0.6, 0.2}},
        {label = "MULTI [M]",      action = "multiplayer", color = {0.4, 0.85, 0.6}},
        {label = "CLAUDE [K]",     action = "customise",   color = {1, 0.45, 0.85}},
        {label = "CUSTOM [C]",     action = "custom",      color = {0.6, 0.3, 0.9}},
        {label = "OPTIONS [O]",    action = "options",     color = {0.3, 0.7, 0.9}},
        {label = "QUIT [ESC]",     action = "quit",        color = {0.9, 0.2, 0.2}},
    }
    local bw, bh, gap = 170, 46, 18
    local totalW = #buttons * bw + (#buttons - 1) * gap
    local sx = (1280 - totalW) / 2
    for i, b in ipairs(buttons) do
        b.x = sx + (i - 1) * (bw + gap); b.y = 540; b.w = bw; b.h = bh
    end
    local mx, my = love.mouse.getPosition()
    for _, b in ipairs(buttons) do
        local hover = mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
        local c = b.color
        love.graphics.setColor(c[1] * (hover and 1 or 0.55), c[2] * (hover and 1 or 0.55), c[3] * (hover and 1 or 0.55))
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 8, 8)
        love.graphics.printf(b.label, b.x, b.y + 13, b.w, "center")
    end
    game.menuButtons = buttons

    -- DIFFICULTY METER (directly under the row of buttons)
    local diffId = game.persist.difficulty or Difficulty.defaultId()
    local diff = Difficulty.get(diffId)
    local mx, my = love.mouse.getPosition()
    local dmY = 598
    local dmH = 46

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("DIFFICULTY", 0, dmY + 4, 1280, "center")

    -- left arrow
    local leftX = 440
    local leftH = mx >= leftX and mx <= leftX + 40 and my >= dmY and my <= dmY + dmH
    love.graphics.setColor(leftH and 1 or 0.4, leftH and 0.6 or 0.3, 0.7)
    love.graphics.rectangle("fill", leftX, dmY + 20, 40, 36, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("<", leftX, dmY + 26, 40, "center")

    -- pill showing current level
    local pillX, pillW = 490, 300
    love.graphics.setColor(diff.color[1] * 0.35, diff.color[2] * 0.35, diff.color[3] * 0.35, 0.9)
    love.graphics.rectangle("fill", pillX, dmY + 20, pillW, 36, 10, 10)
    love.graphics.setColor(diff.color)
    love.graphics.rectangle("line", pillX, dmY + 20, pillW, 36, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(diff.name, pillX, dmY + 26, pillW, "center")

    -- right arrow
    local rightX = pillX + pillW + 10
    local rightH = mx >= rightX and mx <= rightX + 40 and my >= dmY and my <= dmY + dmH
    love.graphics.setColor(rightH and 1 or 0.4, rightH and 0.6 or 0.3, 0.7)
    love.graphics.rectangle("fill", rightX, dmY + 20, 40, 36, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(">", rightX, dmY + 26, 40, "center")

    -- description line
    love.graphics.setColor(diff.color[1], diff.color[2], diff.color[3], 0.9)
    love.graphics.printf(string.format("%s   (Enemy HP %.0f%%  DMG %.0f%%  Count %.0f%%)",
        diff.desc, diff.enemyHp * 100, diff.enemyDmg * 100, diff.spawnCount * 100),
        0, dmY + 62, 1280, "center")

    game.diffBounds = {
        left = {leftX, dmY + 20, 40, 36},
        right = {rightX, dmY + 20, 40, 36},
    }

    -- INFINITE MODE TOGGLE (persistent). Placed in the top-right corner so it
    -- doesn't overlap the row of main-menu buttons or the difficulty meter.
    local infOn = game.persist.infiniteMode == 1
    local btnW, btnH = 220, 36
    local btnX = 1280 - btnW - 20
    local btnY = 20
    local infH = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(infOn and 0.7 or 0.25, infOn and 0.3 or 0.25, infOn and 0.9 or 0.35, infH and 1 or 0.85)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 6, 6)
    love.graphics.printf("INFINITE MODE: " .. (infOn and "ON" or "OFF"), btnX, btnY + 10, btnW, "center")
    game.infiniteBounds = {btnX, btnY, btnW, btnH}

    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("WASD move   |   Mouse aim & fire   |   SPACE dash   |   Q bomb (if unlocked)", 0, 690, 1280, "center")

    -- Persistent stats
    local p = game.persist or {}
    local rep = p.globalRep or 50
    local col = {0.5, 1, 0.5}
    if rep < 50 then col = {1, 0.85, 0.3} end
    if rep < 30 then col = {1, 0.4, 0.3} end
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.printf(string.format("Global Reputation: %d / 100", math.floor(rep)), 20, 20, 400, "left")
    love.graphics.setColor(0.9, 0.9, 1)
    love.graphics.printf(string.format("Win Streak: %d  (best: %d)", p.winStreak or 0, p.bestStreak or 0), 20, 48, 400, "left")
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf(string.format("Wins: %d    Runs: %d", p.totalWins or 0, p.totalRuns or 0), 20, 72, 400, "left")
    -- Reality Shards counter. Only ONE shard can spawn per run — the next
    -- uncollected one, pinned to a fixed wave (1-20, deterministic from slot
    -- + shardIdx) and gated by an in-run eldritch threshold. "1 active" means
    -- your lifetime eldritchMax is already at/above the threshold; you still
    -- have to reach it again in-run by the shard's wave for it to actually
    -- spawn.
    do
        local Eldritch = require("src.eldritch")
        local Save = require("src.save")
        local thrs = Eldritch.SHARD_THRESHOLDS
        local total = #thrs
        local got = p.realityShards or 0
        -- Per-climb arming: the shard is active only if the player's eldritch
        -- peak since the LAST shard collect has reached the next threshold.
        -- Reaching it in a prior run is fine; the counter resets on pickup.
        local peak = p.peakEldritchSinceShard or 0
        love.graphics.setColor(0.85, 0.4, 1)
        local label
        if got >= total then
            label = string.format("Reality Shards: %d / %d  (all found)", got, total)
        else
            local shardIdx = got + 1
            local nextReq = thrs[shardIdx]
            local slot = Save.getActiveSlot()
            local seed = slot * 9973 + shardIdx * 311
            local v = math.sin(seed * 12.9898 + 78.233) * 43758.5453
            local shardWave = math.floor((v - math.floor(v)) * 20) + 1
            if peak >= nextReq then
                label = string.format(
                    "Reality Shards: %d / %d  (1 active — next unlocked on %d)",
                    got, total, shardWave)
            else
                label = string.format(
                    "Reality Shards: %d / %d  (0 active — requires eldritch %d)",
                    got, total, nextReq)
            end
        end
        love.graphics.printf(label, 20, 96, 900, "left")
    end
end

-- ====== CUSTOM MODE SETUP ======
local customRows = {
    {key = "finalWave",              label = "Final Wave",            min = 0,   max = 99,  step = 1, infZero = true},
    {key = "startWave",              label = "Starting Wave",         min = 1,   max = 50,  step = 1},
    {key = "startHp",                label = "Starting HP",           min = 20,  max = 999, step = 10},
    {key = "startingReputation",     label = "Starting Reputation",   min = 0,   max = 100, step = 5},
    {key = "startingCards",          label = "Starting Cards",        min = 0,   max = 20,  step = 1},
    {key = "enemyHpMult",            label = "Enemy HP x",            min = 0.1, max = 10,  step = 0.25},
    {key = "enemyDmgMult",           label = "Enemy Damage x",        min = 0.1, max = 10,  step = 0.25},
    {key = "spawnCountMult",         label = "Enemy Count x",         min = 0.25,max = 8,   step = 0.25},
    {key = "playerDmgMult",          label = "Player Damage x",       min = 0.25,max = 10,  step = 0.25},
    {key = "playerFireRateMult",     label = "Player Fire Rate x",    min = 0.25,max = 10,  step = 0.25},
    {key = "playerSpeedMult",        label = "Player Speed x",        min = 0.25,max = 4,   step = 0.25},
    {key = "playerBulletSpeedMult",  label = "Bullet Speed x",        min = 0.25,max = 5,   step = 0.25},
    {key = "scoreMult",              label = "Score Gain x",          min = 0.25,max = 10,  step = 0.25},
    {key = "dashCooldown",           label = "Dash Cooldown (s)",     min = 0.2, max = 10,  step = 0.2},
    {key = "startEldritch",          label = "Starting Eldritch",     min = 0,   max = 12,  step = 1},
    {key = "disableEldritch",        label = "Disable Eldritch (0/1)",min = 0,   max = 1,   step = 1},
}

function UI:drawCustom(game)
    love.graphics.clear(0.05, 0.02, 0.1)
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.7, 0.4, 1)
    love.graphics.printf("CUSTOM RUN", 0, 20, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("Click arrows to tune. ENTER start, ESC back. Scroll wheel to scroll.", 0, 95, 1280, "center")
    love.graphics.setColor(1, 0.6, 0.3, 0.9)
    love.graphics.printf("Custom runs do NOT affect global reputation or win streak.", 0, 118, 1280, "center")

    local d = game.customDraft
    local y0 = 150
    local rowH = 40
    local listTop = y0
    local listBottom = 560
    local visibleRows = math.floor((listBottom - listTop) / rowH)
    local total = #customRows
    local maxScroll = math.max(0, total - visibleRows)
    game.customScroll = math.max(0, math.min(maxScroll, game.customScroll or 0))

    love.graphics.setScissor(0, listTop, 1280, listBottom - listTop)
    local mx, my = love.mouse.getPosition()
    game.customClicks = {}

    for i, row in ipairs(customRows) do
        local displayIdx = i - 1 - game.customScroll
        if displayIdx >= 0 and displayIdx < visibleRows then
            local y = listTop + displayIdx * rowH
            love.graphics.setColor(0.15, 0.1, 0.25, 0.9)
            love.graphics.rectangle("fill", 230, y, 830, rowH - 4, 8, 8)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(row.label, 250, y + 10, 340, "left")

            local bh = rowH - 12
            local btnY = y + 6

            -- Minus
            local bx1 = 620
            local minusH = mx >= bx1 and mx <= bx1 + 36 and my >= btnY and my <= btnY + bh
            love.graphics.setColor(minusH and 1 or 0.4, minusH and 0.3 or 0.2, 0.2)
            love.graphics.rectangle("fill", bx1, btnY, 36, bh, 6, 6)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("-", bx1, btnY + 6, 36, "center")

            local val = d[row.key]
            local str
            if row.infZero and val == 0 then
                str = "INF"
            elseif row.step < 1 then
                str = string.format("%.2f", val)
            else
                str = tostring(val)
            end
            love.graphics.setColor(1, 1, 0.8)
            love.graphics.printf(str, bx1 + 42, y + 10, 120, "center")

            -- Plus
            local bx2 = bx1 + 168
            local plusH = mx >= bx2 and mx <= bx2 + 36 and my >= btnY and my <= btnY + bh
            love.graphics.setColor(0.2, plusH and 1 or 0.4, 0.2)
            love.graphics.rectangle("fill", bx2, btnY, 36, bh, 6, 6)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("+", bx2, btnY + 6, 36, "center")

            -- Reset (R)
            local bx3 = bx2 + 50
            local resetH = mx >= bx3 and mx <= bx3 + 36 and my >= btnY and my <= btnY + bh
            local isDefault = (val == (game.customDefaults[row.key]))
            love.graphics.setColor(resetH and 0.9 or 0.4, resetH and 0.7 or 0.3, 0.15)
            love.graphics.rectangle("fill", bx3, btnY, 36, bh, 6, 6)
            love.graphics.setColor(1, 1, 1, isDefault and 0.4 or 1)
            love.graphics.printf("R", bx3, btnY + 6, 36, "center")

            game.customClicks[#game.customClicks + 1] = {x = bx1, y = btnY, w = 36, h = bh, row = row, dir = -1}
            game.customClicks[#game.customClicks + 1] = {x = bx2, y = btnY, w = 36, h = bh, row = row, dir = 1}
            game.customClicks[#game.customClicks + 1] = {x = bx3, y = btnY, w = 36, h = bh, row = row, reset = true}
        end
    end
    love.graphics.setScissor()

    -- Scroll indicator
    if maxScroll > 0 then
        local sbY = listTop
        local sbH = listBottom - listTop
        love.graphics.setColor(0.3, 0.2, 0.45, 0.4)
        love.graphics.rectangle("fill", 1070, sbY, 8, sbH, 4, 4)
        local thumb = sbH * (visibleRows / total)
        local thumbY = sbY + (sbH - thumb) * (game.customScroll / maxScroll)
        love.graphics.setColor(0.7, 0.4, 1, 0.9)
        love.graphics.rectangle("fill", 1070, thumbY, 8, thumb, 4, 4)
    end

    -- RESET ALL button
    local resetAllH = mx >= 280 and mx <= 500 and my >= 585 and my <= 635
    love.graphics.setColor(resetAllH and 1 or 0.5, resetAllH and 0.7 or 0.35, 0.15)
    love.graphics.rectangle("fill", 280, 585, 220, 50, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 280, 585, 220, 50, 10, 10)
    love.graphics.printf("RESET ALL", 280, 600, 220, "center")
    game.customResetAllBounds = {280, 585, 220, 50}

    -- Start
    local startH = mx >= 540 and mx <= 780 and my >= 585 and my <= 635
    love.graphics.setColor(startH and 1 or 0.5, startH and 0.8 or 0.4, 0.2)
    love.graphics.rectangle("fill", 540, 585, 240, 50, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 540, 585, 240, 50, 10, 10)
    love.graphics.printf("START RUN", 540, 600, 240, "center")
    game.customStartBounds = {540, 585, 240, 50}

    -- Back
    local backH = mx >= 820 and mx <= 1000 and my >= 585 and my <= 635
    love.graphics.setColor(backH and 0.9 or 0.4, 0.4, 0.6)
    love.graphics.rectangle("fill", 820, 585, 180, 50, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 820, 585, 180, 50, 10, 10)
    love.graphics.printf("BACK", 820, 600, 180, "center")
    game.customBackBounds = {820, 585, 180, 50}
end

-- ====== OPTIONS SCREEN ======
local Audio = require("src.audio")

local optionsRows = {
    {key = "masterVol", label = "Master Volume"},
    {key = "musicVol",  label = "Music Volume"},
    {key = "sfxVol",    label = "SFX Volume"},
}

function UI:drawOptions(game)
    love.graphics.clear(0.05, 0.06, 0.14)
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.4, 0.8, 1)
    love.graphics.printf("OPTIONS", 0, 30, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 0.65)
    love.graphics.printf("Click + / - to adjust. ENTER or ESC to save and go back.", 0, 110, 1280, "center")

    local mx, my = love.mouse.getPosition()
    game.optionsClicks = {}

    -- ============================================================
    -- LEFT COLUMN: Volume sliders (compact stack)
    -- The section header used the 42px bigFont and sat just 22px above
    -- the first slider row, which made it bleed into row 1. Use the
    -- regular font for the header and pad the rows down to give clean
    -- vertical separation.
    -- ============================================================
    local volX, volY, volW, volH = 60, 200, 580, 60
    love.graphics.setColor(0.08, 0.12, 0.22, 0.85)
    love.graphics.rectangle("fill", volX - 12, volY - 50, volW + 24, volH * 3 + 64, 12, 12)
    love.graphics.setColor(0.4, 0.8, 1, 0.95)
    love.graphics.setFont(self.font)
    love.graphics.printf("AUDIO", volX, volY - 42, volW, "left")
    love.graphics.setColor(0.4, 0.8, 1, 0.35)
    love.graphics.rectangle("fill", volX, volY - 18, 60, 2)
    for i, row in ipairs(optionsRows) do
        local y = volY + (i - 1) * volH
        love.graphics.setColor(0.12, 0.18, 0.3, 0.9)
        love.graphics.rectangle("fill", volX, y, volW, volH - 8, 8, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(row.label, volX + 14, y + 17, 180, "left")

        local val = game.persist[row.key] or 1.0
        if val < 0 then val = 0 end
        if val > 1 then val = 1 end

        -- minus
        local bx1 = volX + 210
        local minusH = mx >= bx1 and mx <= bx1 + 32 and my >= y + 14 and my <= y + 40
        love.graphics.setColor(minusH and 1 or 0.4, 0.2, 0.3)
        love.graphics.rectangle("fill", bx1, y + 14, 32, 26, 6, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("-", bx1, y + 17, 32, "center")
        -- bar
        love.graphics.setColor(0.15, 0.2, 0.3)
        love.graphics.rectangle("fill", bx1 + 40, y + 18, 220, 18, 4, 4)
        love.graphics.setColor(0.4, 0.8, 1)
        love.graphics.rectangle("fill", bx1 + 40, y + 18, 220 * val, 18, 4, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.format("%d%%", math.floor(val * 100 + 0.5)), bx1 + 40, y + 19, 220, "center")
        -- plus
        local bx2 = bx1 + 270
        local plusH = mx >= bx2 and mx <= bx2 + 32 and my >= y + 14 and my <= y + 40
        love.graphics.setColor(0.2, plusH and 1 or 0.4, 0.3)
        love.graphics.rectangle("fill", bx2, y + 14, 32, 26, 6, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("+", bx2, y + 17, 32, "center")
        game.optionsClicks[#game.optionsClicks + 1] = {x = bx1, y = y + 14, w = 32, h = 26, key = row.key, dir = -1}
        game.optionsClicks[#game.optionsClicks + 1] = {x = bx2, y = y + 14, w = 32, h = 26, key = row.key, dir = 1}
    end

    -- ============================================================
    -- RIGHT COLUMN: Aim Mode toggle (tall, prominent). Header uses the
    -- regular font for the same reason — bigFont was bleeding into the
    -- toggle button below it.
    -- ============================================================
    local aimMode = (game.persist.aimMode or 0) == 1
    local amX, amY, amW, amH = 700, 200, 520, 196
    local amHover = mx >= amX and mx <= amX + amW and my >= amY and my <= amY + amH
    love.graphics.setColor(0.08, 0.12, 0.22, 0.85)
    love.graphics.rectangle("fill", amX - 12, amY - 50, amW + 24, amH + 64, 12, 12)
    love.graphics.setColor(0.4, 0.8, 1, 0.95)
    love.graphics.setFont(self.font)
    love.graphics.printf("CONTROLS", amX, amY - 42, amW, "left")
    love.graphics.setColor(0.4, 0.8, 1, 0.35)
    love.graphics.rectangle("fill", amX, amY - 18, 80, 2)
    love.graphics.setColor(aimMode and 0.4 or 0.2, aimMode and 0.7 or 0.4, aimMode and 0.95 or 0.6,
        amHover and 1 or 0.92)
    love.graphics.rectangle("fill", amX, amY, amW, 70, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", amX, amY, amW, 70, 10, 10)
    love.graphics.setFont(self.bigFont or self.font)
    love.graphics.printf("AIM MODE", amX, amY + 8, amW, "center")
    love.graphics.setFont(self.font)
    love.graphics.printf(aimMode and "DIRECTION (mouse locked)" or "POSITION (mouse pointer)",
        amX, amY + 44, amW, "center")
    game.optionsAimBounds = {amX, amY, amW, 70}
    -- Description below the button
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf(
        aimMode and "Mouse is captured. Aim follows the last direction you moved."
                 or "Aim follows mouse pointer position (default).",
        amX + 12, amY + 90, amW - 24, "left")

    -- ============================================================
    -- BOTTOM ROW: sub-screen buttons in a tidy line of 4 + back
    -- ============================================================
    local function btn(x, y, w, h, label, hoverCol)
        local hover = mx >= x and mx <= x + w and my >= y and my <= y + h
        local r, g, b = hoverCol[1], hoverCol[2], hoverCol[3]
        love.graphics.setColor(hover and r * 1.4 or r, hover and g * 1.4 or g, hover and b * 1.4 or b)
        love.graphics.rectangle("fill", x, y, w, h, 10, 10)
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.rectangle("line", x, y, w, h, 10, 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(label, x, y + (h - 16) / 2, w, "center")
        return {x, y, w, h}
    end

    local bw, bh = 230, 56
    local rowY = 470
    local gap = 16
    local startX = (1280 - (bw * 4 + gap * 3)) / 2
    game.optionsPlaylistBounds   = btn(startX,                           rowY, bw, bh, "PLAYLIST",     {0.32, 0.22, 0.6})
    game.optionsAestheticsBounds = btn(startX + (bw + gap),              rowY, bw, bh, "AESTHETICS",   {0.25, 0.5, 0.7})
    game.optionsSlotsBounds      = btn(startX + (bw + gap) * 2,          rowY, bw, bh, "SAVE SLOTS",   {0.25, 0.55, 0.32})
    game.optionsResetDataBounds  = btn(startX + (bw + gap) * 3,          rowY, bw, bh, "RESET DATA",   {0.55, 0.18, 0.18})

    -- Second-row actions: shard reset (purple, only appears if you've got any)
    local row2Y = rowY + bh + 28
    if (game.persist.realityShards or 0) > 0 then
        game.optionsResetShardsBounds = btn(
            startX + (bw + gap) * 3, row2Y, bw, bh,
            "RESET SHARDS", {0.45, 0.18, 0.7})
    else
        game.optionsResetShardsBounds = nil
    end

    -- Active save slot label
    local Save = require("src.save")
    love.graphics.setColor(0.8, 0.9, 0.85, 0.7)
    love.graphics.printf("Slot " .. Save.getActiveSlot() .. " active",
        startX + (bw + gap) * 2, rowY + bh + 6, bw, "center")

    -- BACK button — bottom right corner
    game.optionsBackBounds = btn(1080, 640, 170, 50, "BACK", {0.4, 0.5, 0.7})
end

function UI:optionsClick(game, x, y)
    for _, c in ipairs(game.optionsClicks or {}) do
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            local cur = game.persist[c.key] or 1.0
            cur = math.max(0, math.min(1, cur + c.dir * 0.1))
            -- round to nearest 0.05
            cur = math.floor(cur * 20 + 0.5) / 20
            game.persist[c.key] = cur
            if c.key == "masterVol" then Audio:setMasterVolume(cur)
            elseif c.key == "musicVol" then Audio:setMusicVolume(cur)
            elseif c.key == "sfxVol" then Audio:setSfxVolume(cur) end
            return
        end
    end
    local b = game.optionsAimBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game.persist.aimMode = ((game.persist.aimMode or 0) == 1) and 0 or 1
        require("src.save").save(game.persist)
        Audio:play("select")
        return
    end
    b = game.optionsPlaylistBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game.state = "playlist"
        return
    end
    b = game.optionsAestheticsBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game.state = "aesthetics"
        return
    end
    b = game.optionsSlotsBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game:openSlots()
        return
    end
    b = game.optionsResetDataBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game:openResetData()
        return
    end
    b = game.optionsResetShardsBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game:openResetShards()
        return
    end
    b = game.optionsBackBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        local Save = require("src.save")
        Save.save(game.persist)
        game.state = "menu"
    end
end

-- ====== SAVE SLOTS SUB-SCREEN ======
function UI:drawSlots(game)
    love.graphics.clear(0.05, 0.08, 0.12)
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.4, 0.9, 0.7)
    love.graphics.printf("SAVE SLOTS", 0, 50, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf("Each slot is a separate profile. Click a slot to switch to it.", 0, 130, 1280, "center")
    love.graphics.setColor(1, 0.7, 0.5, 0.85)
    love.graphics.printf("Your current progress auto-saves before switching.", 0, 155, 1280, "center")

    local Save = require("src.save")
    local active = Save.getActiveSlot()
    local mx, my = love.mouse.getPosition()
    game.slotsClicks = {}

    local y0 = 200
    local rowH = 76
    for i = 1, 5 do
        local y = y0 + (i - 1) * (rowH + 8)
        local exists = Save.hasData(i)
        local isActive = (i == active)
        local hover = mx >= 240 and mx <= 1040 and my >= y and my <= y + rowH

        if isActive then
            love.graphics.setColor(0.25, 0.7, 0.5, 0.95)
        elseif hover then
            love.graphics.setColor(0.15, 0.4, 0.35, 0.95)
        else
            love.graphics.setColor(0.08, 0.18, 0.18, 0.95)
        end
        love.graphics.rectangle("fill", 240, y, 800, rowH, 10, 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", 240, y, 800, rowH, 10, 10)

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.format("SLOT %d%s", i, isActive and "  (ACTIVE)" or ""),
            260, y + 10, 500, "left")

        if exists then
            local s = Save.summary(i)
            love.graphics.setColor(0.85, 0.9, 0.95, 0.9)
            love.graphics.printf(string.format(
                "Wins %d  |  Runs %d  |  Kills %d  |  Streak %d  |  Rep %d  |  Eldritch %d",
                s.totalWins or 0, s.totalRuns or 0, s.totalKills or 0,
                s.bestStreak or 0, math.floor(s.globalRep or 50), s.eldritchMax or 0),
                260, y + 38, 760, "left")
        else
            love.graphics.setColor(0.6, 0.7, 0.7, 0.75)
            love.graphics.printf("<empty slot>", 260, y + 38, 500, "left")
        end

        game.slotsClicks[#game.slotsClicks + 1] = {x = 240, y = y, w = 800, h = rowH, slot = i}
    end

    -- Back
    local backH = mx >= 540 and mx <= 740 and my >= 660 and my <= 700
    love.graphics.setColor(backH and 1 or 0.5, 0.5, 0.8)
    love.graphics.rectangle("fill", 540, 660, 200, 40, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 540, 660, 200, 40, 8, 8)
    love.graphics.printf("BACK", 540, 670, 200, "center")
    game.slotsBackBounds = {540, 660, 200, 40}
end

function UI:slotsClick(game, x, y)
    for _, c in ipairs(game.slotsClicks or {}) do
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            game:switchSlot(c.slot)
            return
        end
    end
    local b = game.slotsBackBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        local Save = require("src.save")
        Save.save(game.persist)
        game.state = "options"
    end
end

-- ====== RESET DATA CONFIRMATION ======
function UI:drawResetData(game)
    love.graphics.clear(0.1, 0.03, 0.05)
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.printf("RESET GAME DATA", 0, 60, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("This wipes ALL progress: stats, cosmetics, unlocks, streak, settings.", 0, 160, 1280, "center")
    love.graphics.printf("To confirm: TYPE 'RESET' below, then hold while the timer runs out.", 0, 190, 1280, "center")

    -- Type box
    local boxX, boxY, boxW, boxH = 440, 260, 400, 56
    love.graphics.setColor(0.1, 0, 0, 0.9)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 8, 8)
    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 8, 8)
    love.graphics.setFont(self.bigFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(game.resetTyped or "", boxX, boxY + 8, boxW, "center")
    love.graphics.setFont(self.font)

    local correct = (game.resetTyped or "") == "RESET"
    if correct then
        local remain = math.max(0, 5 - ((love.timer.getTime() - (game.resetTypedAt or 0))))
        if remain > 0 then
            love.graphics.setColor(1, 0.5, 0.2)
            love.graphics.printf(string.format("CONFIRMING IN %.1f SECONDS...  Click CONFIRM to finalize or CANCEL to abort.", remain), 0, 340, 1280, "center")
            -- progress bar
            local w = 800
            local px = (1280 - w) / 2
            local pct = 1 - remain / 5
            love.graphics.setColor(0.3, 0.1, 0.1)
            love.graphics.rectangle("fill", px, 370, w, 16, 6, 6)
            love.graphics.setColor(1, 0.3, 0.2)
            love.graphics.rectangle("fill", px, 370, w * pct, 16, 6, 6)
        else
            love.graphics.setColor(1, 0.2, 0.2)
            love.graphics.printf("READY. Click CONFIRM RESET.", 0, 340, 1280, "center")
        end
    else
        love.graphics.setColor(1, 0.8, 0.5)
        love.graphics.printf("Type RESET (uppercase) to arm the confirmation.", 0, 340, 1280, "center")
    end

    local mx, my = love.mouse.getPosition()
    -- Confirm button (armed only when typed+timer done)
    local armed = correct and (love.timer.getTime() - (game.resetTypedAt or 0)) >= 5
    local confirmH = mx >= 440 and mx <= 640 and my >= 440 and my <= 490
    if armed then
        love.graphics.setColor(confirmH and 1 or 0.7, 0.2, 0.2)
    else
        love.graphics.setColor(0.3, 0.1, 0.1, 0.6)
    end
    love.graphics.rectangle("fill", 440, 440, 200, 50, 10, 10)
    love.graphics.setColor(1, 1, 1, armed and 1 or 0.4)
    love.graphics.rectangle("line", 440, 440, 200, 50, 10, 10)
    love.graphics.printf("CONFIRM RESET", 440, 455, 200, "center")
    game.resetConfirmBounds = armed and {440, 440, 200, 50} or nil

    -- Cancel
    local cancelH = mx >= 660 and mx <= 860 and my >= 440 and my <= 490
    love.graphics.setColor(cancelH and 1 or 0.5, 0.5, 0.7)
    love.graphics.rectangle("fill", 660, 440, 200, 50, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 660, 440, 200, 50, 10, 10)
    love.graphics.printf("CANCEL", 660, 455, 200, "center")
    game.resetCancelBounds = {660, 440, 200, 50}
end

function UI:resetDataClick(game, x, y)
    local b = game.resetConfirmBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game:performResetData()
        return
    end
    b = game.resetCancelBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game.state = "options"
        game.resetTyped = ""
        game.resetTypedAt = nil
    end
end

function UI:resetDataKey(game, key)
    if key == "backspace" then
        local s = game.resetTyped or ""
        game.resetTyped = s:sub(1, #s - 1)
        game.resetTypedAt = nil
        return
    end
    if key == "escape" then
        game.state = "options"
        game.resetTyped = ""
        game.resetTypedAt = nil
        return
    end
    if #key == 1 then
        local s = (game.resetTyped or "") .. key:upper()
        if #s > 12 then s = s:sub(1, 12) end
        game.resetTyped = s
        if s == "RESET" then
            game.resetTypedAt = love.timer.getTime()
        else
            game.resetTypedAt = nil
        end
    end
end

-- ====== RESET SHARDS CONFIRMATION ======
function UI:drawResetShards(game)
    love.graphics.clear(0.06, 0.03, 0.1)
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.85, 0.45, 1)
    love.graphics.printf("RESET REALITY SHARDS", 0, 60, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("This wipes ALL Reality Shards. Other progress is untouched.", 0, 160, 1280, "center")
    love.graphics.printf("To confirm: TYPE 'RESET' below, then hold while the timer runs out.", 0, 190, 1280, "center")

    local boxX, boxY, boxW, boxH = 440, 260, 400, 56
    love.graphics.setColor(0.08, 0.02, 0.12, 0.9)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 8, 8)
    love.graphics.setColor(0.85, 0.45, 1)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 8, 8)
    love.graphics.setFont(self.bigFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(game.resetShardsTyped or "", boxX, boxY + 8, boxW, "center")
    love.graphics.setFont(self.font)

    local correct = (game.resetShardsTyped or "") == "RESET"
    if correct then
        local remain = math.max(0, 5 - ((love.timer.getTime() - (game.resetShardsTypedAt or 0))))
        if remain > 0 then
            love.graphics.setColor(1, 0.6, 1)
            love.graphics.printf(string.format("CONFIRMING IN %.1f SECONDS...  Click CONFIRM to finalize or CANCEL to abort.", remain), 0, 340, 1280, "center")
            local w = 800
            local px = (1280 - w) / 2
            local pct = 1 - remain / 5
            love.graphics.setColor(0.2, 0.1, 0.3)
            love.graphics.rectangle("fill", px, 370, w, 16, 6, 6)
            love.graphics.setColor(0.85, 0.45, 1)
            love.graphics.rectangle("fill", px, 370, w * pct, 16, 6, 6)
        else
            love.graphics.setColor(1, 0.6, 1)
            love.graphics.printf("READY. Click CONFIRM RESET.", 0, 340, 1280, "center")
        end
    else
        love.graphics.setColor(1, 0.8, 0.9)
        love.graphics.printf("Type RESET (uppercase) to arm the confirmation.", 0, 340, 1280, "center")
    end

    local mx, my = love.mouse.getPosition()
    local armed = correct and (love.timer.getTime() - (game.resetShardsTypedAt or 0)) >= 5
    local confirmH = mx >= 440 and mx <= 640 and my >= 440 and my <= 490
    if armed then
        love.graphics.setColor(confirmH and 1 or 0.65, 0.25, confirmH and 1 or 0.8)
    else
        love.graphics.setColor(0.2, 0.08, 0.25, 0.6)
    end
    love.graphics.rectangle("fill", 440, 440, 200, 50, 10, 10)
    love.graphics.setColor(1, 1, 1, armed and 1 or 0.4)
    love.graphics.rectangle("line", 440, 440, 200, 50, 10, 10)
    love.graphics.printf("CONFIRM RESET", 440, 455, 200, "center")
    game.resetShardsConfirmBounds = armed and {440, 440, 200, 50} or nil

    local cancelH = mx >= 660 and mx <= 860 and my >= 440 and my <= 490
    love.graphics.setColor(cancelH and 1 or 0.5, 0.5, 0.7)
    love.graphics.rectangle("fill", 660, 440, 200, 50, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 660, 440, 200, 50, 10, 10)
    love.graphics.printf("CANCEL", 660, 455, 200, "center")
    game.resetShardsCancelBounds = {660, 440, 200, 50}
end

function UI:resetShardsClick(game, x, y)
    local b = game.resetShardsConfirmBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game:performResetShards()
        return
    end
    b = game.resetShardsCancelBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game.state = "options"
        game.resetShardsTyped = ""
        game.resetShardsTypedAt = nil
    end
end

function UI:resetShardsKey(game, key)
    if key == "backspace" then
        local s = game.resetShardsTyped or ""
        game.resetShardsTyped = s:sub(1, #s - 1)
        game.resetShardsTypedAt = nil
        return
    end
    if key == "escape" then
        game.state = "options"
        game.resetShardsTyped = ""
        game.resetShardsTypedAt = nil
        return
    end
    if #key == 1 then
        local s = (game.resetShardsTyped or "") .. key:upper()
        if #s > 12 then s = s:sub(1, 12) end
        game.resetShardsTyped = s
        if s == "RESET" then
            game.resetShardsTypedAt = love.timer.getTime()
        else
            game.resetShardsTypedAt = nil
        end
    end
end

-- ====== PLAYLIST SUB-SCREEN ======
local Playlist = require("src.playlist")

function UI:drawPlaylist(game)
    love.graphics.clear(0.06, 0.03, 0.12)
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.9, 0.5, 1)
    love.graphics.printf("PLAYLIST", 0, 30, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf("Click a theme to preview & set. ESC to save & return.", 0, 100, 1280, "center")

    local mx, my = love.mouse.getPosition()
    game.playlistClicks = {}
    local y0 = 150
    local listBottom = 630
    local rowStep = 72
    local listH = listBottom - y0

    local total = #Playlist.themes
    local contentH = total * rowStep
    local maxScroll = math.max(0, contentH - listH + 10)
    game.playlistScrollTarget = math.max(0, math.min(maxScroll, game.playlistScrollTarget or 0))
    game.playlistScroll = math.max(0, math.min(maxScroll, game.playlistScroll or 0))
    local scroll = game.playlistScroll

    love.graphics.setScissor(240, y0, 800, listH)
    for i, theme in ipairs(Playlist.themes) do
        local y = y0 + (i - 1) * rowStep - scroll
        if y + 64 >= y0 and y <= listBottom then
            local rowH = 64
            local unlocked = Playlist.isUnlocked(theme, game.persist)
            local selected = (game.persist.theme or Playlist.defaultId()) == theme.id
            local hover = unlocked and mx >= 240 and mx <= 1040 and my >= y and my <= y + rowH and my >= y0 and my <= listBottom
            if selected then
                love.graphics.setColor(0.6, 0.3, 0.95, 0.95)
            elseif unlocked and hover then
                love.graphics.setColor(0.3, 0.2, 0.5, 0.95)
            elseif unlocked then
                love.graphics.setColor(0.15, 0.1, 0.25, 0.95)
            else
                love.graphics.setColor(0.1, 0.08, 0.15, 0.9)
            end
            love.graphics.rectangle("fill", 240, y, 800, rowH, 10, 10)
            love.graphics.setColor(1, 1, 1, unlocked and 1 or 0.5)
            love.graphics.rectangle("line", 240, y, 800, rowH, 10, 10)
            love.graphics.setColor(1, 1, 1, unlocked and 1 or 0.4)
            love.graphics.printf(theme.name, 260, y + 8, 500, "left")
            love.graphics.setColor(0.8, 0.8, 0.9, unlocked and 0.85 or 0.35)
            love.graphics.printf(theme.desc, 260, y + 32, 500, "left")
            if not unlocked then
                love.graphics.setColor(1, 0.6, 0.3, 0.85)
                love.graphics.printf("LOCKED: " .. theme.hint, 770, y + 20, 260, "left")
            elseif selected then
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.printf("SELECTED", 770, y + 20, 260, "right")
            end
            local visTop = math.max(y, y0)
            local visBot = math.min(y + rowH, listBottom)
            if visBot > visTop + 4 then
                game.playlistClicks[#game.playlistClicks + 1] = {
                    x = 240, y = visTop, w = 800, h = visBot - visTop,
                    theme = theme.id, unlocked = unlocked,
                }
            end
        end
    end
    love.graphics.setScissor()

    -- Scrollbar (draggable)
    if maxScroll > 0 then
        local sbX = 1050
        local sbW = 10
        love.graphics.setColor(0.2, 0.1, 0.3, 0.6)
        love.graphics.rectangle("fill", sbX, y0, sbW, listH, 5, 5)
        local thumbH = math.max(24, listH * (listH / contentH))
        local thumbY = y0 + (listH - thumbH) * (scroll / maxScroll)
        love.graphics.setColor(0.75, 0.4, 1, 1)
        love.graphics.rectangle("fill", sbX, thumbY, sbW, thumbH, 5, 5)
        game.playlistScrollbar = {trackX = sbX, trackY = y0, trackW = sbW, trackH = listH, thumbY = thumbY, thumbH = thumbH, maxScroll = maxScroll}
    else
        game.playlistScrollbar = nil
    end

    local backH = mx >= 540 and mx <= 740 and my >= 660 and my <= 700
    love.graphics.setColor(backH and 1 or 0.5, 0.5, 0.8)
    love.graphics.rectangle("fill", 540, 660, 200, 40, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("BACK", 540, 670, 200, "center")
    game.playlistBackBounds = {540, 660, 200, 40}
end

function UI:playlistClick(game, x, y)
    for _, c in ipairs(game.playlistClicks or {}) do
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h and c.unlocked then
            game.persist.theme = c.theme
            local Audio = require("src.audio")
            Audio:setTheme(c.theme)
            -- Force the preview to play so the user can hear the theme immediately
            if Audio.music and not Audio.music:isPlaying() then
                Audio.music:play()
            end
            local Save = require("src.save")
            Save.save(game.persist)
            return
        end
    end
    local b = game.playlistBackBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        -- Stop the preview so it doesn't trickle into menu/other screens
        local Audio = require("src.audio")
        if Audio.music and Audio.music:isPlaying() then Audio.music:stop() end
        local Save = require("src.save")
        Save.save(game.persist)
        game.state = "options"
    end
end

-- ====== AESTHETICS SUB-SCREEN ======
local Aesthetics = require("src.aesthetics")

function UI:drawAesthetics(game)
    local bgId = (game.persist and game.persist.background) or Aesthetics.defaultId()
    Aesthetics.draw(bgId)
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.4, 0.8, 1)
    love.graphics.printf("AESTHETICS", 0, 20, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf("Click a background to preview & set. ESC to save & return.", 0, 90, 1280, "center")

    local mx, my = love.mouse.getPosition()
    game.aestheticsClicks = {}
    local y0 = 150
    local rowStep = 62
    local listBottom = 630
    local listH = listBottom - y0

    local total = #Aesthetics.backgrounds
    local contentH = total * rowStep
    local maxScroll = math.max(0, contentH - listH + 10)
    game.aestheticsScrollTarget = math.max(0, math.min(maxScroll, game.aestheticsScrollTarget or 0))
    game.aestheticsScroll = math.max(0, math.min(maxScroll, game.aestheticsScroll or 0))
    local scroll = game.aestheticsScroll

    love.graphics.setScissor(240, y0, 800, listH)
    for i, bg in ipairs(Aesthetics.backgrounds) do
        local y = y0 + (i - 1) * rowStep - scroll
        if y + 56 >= y0 and y <= listBottom then
            local rowH = 56
            local unlocked = Aesthetics.isUnlocked(bg, game.persist)
            local selected = bgId == bg.id
            local hover = unlocked and mx >= 240 and mx <= 1040 and my >= y and my <= y + rowH and my >= y0 and my <= listBottom
            if selected then
                love.graphics.setColor(0.25, 0.5, 0.9, 0.95)
            elseif unlocked and hover then
                love.graphics.setColor(0.15, 0.3, 0.5, 0.95)
            elseif unlocked then
                love.graphics.setColor(0.08, 0.15, 0.25, 0.95)
            else
                love.graphics.setColor(0.08, 0.1, 0.15, 0.9)
            end
            love.graphics.rectangle("fill", 240, y, 800, rowH, 10, 10)
            love.graphics.setColor(1, 1, 1, unlocked and 1 or 0.4)
            love.graphics.rectangle("line", 240, y, 800, rowH, 10, 10)
            love.graphics.setColor(1, 1, 1, unlocked and 1 or 0.4)
            love.graphics.printf(bg.name, 260, y + 6, 500, "left")
            love.graphics.setColor(0.8, 0.85, 1, unlocked and 0.85 or 0.35)
            love.graphics.printf(bg.desc, 260, y + 28, 500, "left")
            if not unlocked then
                love.graphics.setColor(1, 0.6, 0.3, 0.85)
                love.graphics.printf("LOCKED: " .. bg.hint, 770, y + 18, 260, "left")
            elseif selected then
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.printf("SELECTED", 770, y + 18, 260, "right")
            end
            local visTop = math.max(y, y0)
            local visBot = math.min(y + rowH, listBottom)
            if visBot > visTop + 4 then
                game.aestheticsClicks[#game.aestheticsClicks + 1] = {
                    x = 240, y = visTop, w = 800, h = visBot - visTop,
                    id = bg.id, unlocked = unlocked,
                }
            end
        end
    end
    love.graphics.setScissor()

    if maxScroll > 0 then
        local sbX = 1050
        local sbW = 10
        love.graphics.setColor(0.1, 0.2, 0.3, 0.6)
        love.graphics.rectangle("fill", sbX, y0, sbW, listH, 5, 5)
        local thumbH = math.max(24, listH * (listH / contentH))
        local thumbY = y0 + (listH - thumbH) * (scroll / maxScroll)
        love.graphics.setColor(0.4, 0.75, 1, 1)
        love.graphics.rectangle("fill", sbX, thumbY, sbW, thumbH, 5, 5)
        game.aestheticsScrollbar = {trackX = sbX, trackY = y0, trackW = sbW, trackH = listH, thumbY = thumbY, thumbH = thumbH, maxScroll = maxScroll}
    else
        game.aestheticsScrollbar = nil
    end

    local backH = mx >= 540 and mx <= 740 and my >= 660 and my <= 700
    love.graphics.setColor(backH and 1 or 0.5, 0.5, 0.8)
    love.graphics.rectangle("fill", 540, 660, 200, 40, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("BACK", 540, 670, 200, "center")
    game.aestheticsBackBounds = {540, 660, 200, 40}
end

function UI:aestheticsClick(game, x, y)
    for _, c in ipairs(game.aestheticsClicks or {}) do
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h and c.unlocked then
            game.persist.background = c.id
            local Save = require("src.save")
            Save.save(game.persist)
            return
        end
    end
    local b = game.aestheticsBackBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        local Save = require("src.save")
        Save.save(game.persist)
        game.state = "options"
    end
end

-- ====== CLAUDE CUSTOMISATION ======
local Cosmetics = require("src.cosmetics")
local slotOrder = {"body", "eye", "claw", "hat", "trail", "gun"}
local slotLabels = {body = "Body", eye = "Eyes", claw = "Claws", hat = "Hat", trail = "Trail", gun = "Gun"}

-- Draws the currently-equipped weapon at (x,y) pointing right, with optional scale.
-- Matches the gun rendering used inside drawPreviewCrab so both stay in sync.
local function drawGunAt(x, y, scale, gun, t)
    gun = gun or "pistol"
    scale = scale or 1
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(scale, scale)
    love.graphics.setLineWidth(1)  -- reset so upstream thickness doesn't leak in
    local baseX = 0
    if gun == "pistol" then
        love.graphics.setColor(0.22, 0.22, 0.26); love.graphics.rectangle("fill", baseX, -3, 22, 6)
        love.graphics.setColor(0.4, 0.4, 0.48); love.graphics.rectangle("line", baseX, -3, 22, 6)
        love.graphics.setColor(0.12, 0.12, 0.15); love.graphics.rectangle("fill", baseX + 1, -4, 20, 2)
        love.graphics.setColor(0.5, 0.5, 0.55)
        for i = 0, 5 do love.graphics.line(baseX + 14 + i * 0.9, -4, baseX + 13 + i * 0.9, -2) end
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", baseX + 2, -5, 2, 1)
        love.graphics.rectangle("fill", baseX + 18, -5, 2, 1)
        love.graphics.setColor(1, 1, 1); love.graphics.rectangle("fill", baseX + 18.5, -4.5, 0.8, 0.5)
        love.graphics.setColor(0.25, 0.25, 0.3); love.graphics.setLineWidth(1.5)
        love.graphics.arc("line", "open", baseX + 7, 4, 2.5, 0, math.pi); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.05, 0.05, 0.08); love.graphics.rectangle("fill", baseX + 10, -2, 4, 1)
        love.graphics.setColor(0.08, 0.08, 0.1)
        for i = 0, 2 do love.graphics.rectangle("fill", baseX + 1, -1 + i * 1.3, 5, 0.5) end
        love.graphics.setColor(0, 0, 0); love.graphics.circle("fill", baseX + 22, 0, 1.2)
    elseif gun == "compact" then
        love.graphics.setColor(0.22, 0.22, 0.26); love.graphics.rectangle("fill", baseX, -2.5, 14, 5)
        love.graphics.setColor(0.4, 0.4, 0.48); love.graphics.rectangle("line", baseX, -2.5, 14, 5)
        love.graphics.setColor(0.12, 0.12, 0.15); love.graphics.rectangle("fill", baseX + 1, -3.3, 12, 1.6)
        love.graphics.setColor(0.5, 0.5, 0.55)
        for i = 0, 3 do love.graphics.line(baseX + 9 + i * 0.8, -3.3, baseX + 8 + i * 0.8, -1.7) end
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", baseX + 1.5, -4.1, 1.6, 0.9)
        love.graphics.rectangle("fill", baseX + 11, -4.1, 1.2, 0.9)
        love.graphics.setColor(1, 1, 1); love.graphics.rectangle("fill", baseX + 11.4, -3.7, 0.5, 0.4)
        love.graphics.setColor(0.25, 0.25, 0.3); love.graphics.setLineWidth(1.3)
        love.graphics.arc("line", "open", baseX + 5, 3, 1.8, 0, math.pi); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.05, 0.05, 0.08); love.graphics.rectangle("fill", baseX + 6, -1.8, 2.5, 0.9)
        love.graphics.setColor(0.08, 0.08, 0.1)
        for i = 0, 1 do love.graphics.rectangle("fill", baseX + 1, -0.8 + i * 1.2, 3.5, 0.45) end
        love.graphics.setColor(0, 0, 0); love.graphics.circle("fill", baseX + 14, 0, 1)
    elseif gun == "magnum" then
        love.graphics.setColor(0.22, 0.2, 0.25); love.graphics.rectangle("fill", baseX + 8, -2.5, 18, 5)
        love.graphics.setColor(0.35, 0.3, 0.38); love.graphics.circle("fill", baseX + 5, 0, 6)
        love.graphics.setColor(0.15, 0.12, 0.18); love.graphics.circle("line", baseX + 5, 0, 6)
        for i = 0, 5 do
            local a = (i / 6) * math.pi * 2
            love.graphics.circle("fill", baseX + 5 + math.cos(a) * 3, math.sin(a) * 3, 1)
        end
    elseif gun == "rifle" then
        love.graphics.setColor(0.25, 0.2, 0.12); love.graphics.rectangle("fill", baseX - 2, -2, 6, 4)
        love.graphics.setColor(0.2, 0.2, 0.25); love.graphics.rectangle("fill", baseX + 4, -2, 32, 4)
        love.graphics.setColor(0.4, 0.4, 0.5); love.graphics.rectangle("line", baseX + 4, -2, 32, 4)
        love.graphics.setColor(0.35, 0.35, 0.45); love.graphics.rectangle("fill", baseX + 14, -4, 6, 2)
        love.graphics.rectangle("fill", baseX + 33, -5, 2, 2)
    elseif gun == "shotgun" then
        love.graphics.setColor(0.15, 0.1, 0.06); love.graphics.rectangle("fill", baseX - 2, -4, 6, 8)
        love.graphics.setColor(0.2, 0.2, 0.25); love.graphics.rectangle("fill", baseX + 4, -4, 20, 3); love.graphics.rectangle("fill", baseX + 4, 1, 20, 3)
        love.graphics.setColor(0.35, 0.35, 0.42); love.graphics.rectangle("fill", baseX + 12, -4, 5, 8)
    elseif gun == "smg" then
        love.graphics.setColor(0.2, 0.2, 0.24); love.graphics.setLineWidth(1.5)
        love.graphics.line(baseX - 6, -2, baseX - 2, -2); love.graphics.line(baseX - 6, 2, baseX - 2, 2)
        love.graphics.line(baseX - 6, -2, baseX - 6, 2); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.18, 0.18, 0.22); love.graphics.rectangle("fill", baseX, -3, 22, 6)
        love.graphics.setColor(0.35, 0.35, 0.4); love.graphics.rectangle("line", baseX, -3, 22, 6)
        love.graphics.setColor(0.1, 0.1, 0.12)
        for i = 0, 3 do love.graphics.rectangle("fill", baseX + 2 + i * 1.5, -2, 0.8, 4) end
        love.graphics.setColor(0.45, 0.45, 0.5); love.graphics.rectangle("fill", baseX + 12, -5, 5, 2)
        love.graphics.setColor(0.25, 0.25, 0.3); love.graphics.rectangle("line", baseX + 12, -5, 5, 2)
        love.graphics.setColor(0.15, 0.15, 0.18); love.graphics.rectangle("fill", baseX + 5, -7, 5, 3)
        love.graphics.setColor(0.4, 0.4, 0.5); love.graphics.rectangle("line", baseX + 5, -7, 5, 3)
        love.graphics.setColor(1, 0.2, 0.2, 0.9 + math.sin(t * 4) * 0.1)
        love.graphics.circle("fill", baseX + 7.5, -5.5, 0.9)
        love.graphics.setColor(0.12, 0.12, 0.15); love.graphics.rectangle("fill", baseX + 4, 3, 6, 10)
        love.graphics.setColor(0.35, 0.35, 0.4); love.graphics.rectangle("line", baseX + 4, 3, 6, 10)
        love.graphics.setColor(0.85, 0.65, 0.2)
        for i = 0, 3 do love.graphics.line(baseX + 5, 5 + i * 2, baseX + 9, 5 + i * 2) end
        love.graphics.setColor(0.25, 0.25, 0.3); love.graphics.setLineWidth(1.5)
        love.graphics.arc("line", "open", baseX + 14, 4, 2.5, 0, math.pi); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.1, 0.1, 0.12); love.graphics.rectangle("fill", baseX + 22, -2.5, 10, 5)
        love.graphics.setColor(0.3, 0.3, 0.35)
        for i = 0, 3 do love.graphics.line(baseX + 24 + i * 2, -2.5, baseX + 24 + i * 2, 2.5) end
        love.graphics.setColor(0, 0, 0); love.graphics.circle("fill", baseX + 32, 0, 1.2)
    elseif gun == "blaster" then
        love.graphics.setColor(0.15, 0.2, 0.35); love.graphics.rectangle("fill", baseX, -3, 20, 6, 1, 1)
        love.graphics.setColor(0.3, 0.5, 0.9); love.graphics.rectangle("fill", baseX + 2, -2, 14, 4)
        love.graphics.setColor(0.3, 1, 1, 0.9); love.graphics.circle("fill", baseX + 22, 0, 3 + math.sin(t * 5) * 0.5)
        love.graphics.setColor(1, 1, 1); love.graphics.circle("fill", baseX + 22, 0, 1.4)
    elseif gun == "cannon" then
        love.graphics.setColor(0.3, 0.3, 0.35); love.graphics.rectangle("fill", baseX - 4, -3, 5, 6)
        love.graphics.setColor(0.6, 0.6, 0.65); love.graphics.rectangle("line", baseX - 4, -3, 5, 6)
        love.graphics.setColor(0.08, 0.08, 0.1)
        for i = 0, 2 do love.graphics.line(baseX - 3 + i * 1.5, -3, baseX - 3 + i * 1.5, 3) end
        love.graphics.setColor(0.18, 0.18, 0.22); love.graphics.rectangle("fill", baseX + 1, -6, 20, 12)
        love.graphics.setColor(0.5, 0.5, 0.55); love.graphics.rectangle("line", baseX + 1, -6, 20, 12)
        love.graphics.setColor(0.3, 0.3, 0.35); love.graphics.rectangle("fill", baseX + 3, -8, 16, 2)
        love.graphics.setColor(0.15, 0.15, 0.18)
        for i = 0, 6 do love.graphics.line(baseX + 4 + i * 2, -8, baseX + 4 + i * 2, -6) end
        love.graphics.setColor(0.25, 0.25, 0.3); love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", baseX + 11, -8, 4, -math.pi, 0); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.08, 0.08, 0.1)
        for i = 0, 3 do
            love.graphics.rectangle("fill", baseX + 5 + i * 3, -5, 2, 0.8)
            love.graphics.rectangle("fill", baseX + 5 + i * 3, 4.2, 2, 0.8)
        end
        love.graphics.setColor(0.85, 0.65, 0.2)
        love.graphics.circle("fill", baseX + 3, -4, 0.9); love.graphics.circle("fill", baseX + 3, 4, 0.9)
        love.graphics.circle("fill", baseX + 19, -4, 0.9); love.graphics.circle("fill", baseX + 19, 4, 0.9)
        love.graphics.setColor(0.22, 0.22, 0.26)
        love.graphics.polygon("fill", baseX + 21, -7, baseX + 30, -5, baseX + 30, 5, baseX + 21, 7)
        love.graphics.setColor(0.5, 0.5, 0.55)
        love.graphics.polygon("line", baseX + 21, -7, baseX + 30, -5, baseX + 30, 5, baseX + 21, 7)
        love.graphics.setColor(0.02, 0.02, 0.03); love.graphics.circle("fill", baseX + 27, 0, 3)
        love.graphics.setColor(0.15, 0.15, 0.2)
        for i = 0, 2 do
            local a = (i / 3) * math.pi * 2
            love.graphics.line(baseX + 27, 0, baseX + 27 + math.cos(a) * 3, math.sin(a) * 3)
        end
        love.graphics.setColor(1, 0.2, 0.2, 0.5 + math.sin(t * 6) * 0.3); love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 30, 0, baseX + 46, math.sin(t * 3) * 2)
        love.graphics.setColor(1, 0.3, 0.3, 0.9)
        love.graphics.circle("fill", baseX + 46, math.sin(t * 3) * 2, 1.2)
    elseif gun == "crossbow" then
        love.graphics.setColor(0.35, 0.22, 0.1); love.graphics.setLineWidth(3)
        love.graphics.line(baseX + 2, -10, baseX + 2, 10)
        love.graphics.arc("line", "open", baseX, 0, 12, -math.pi * 0.4, math.pi * 0.4)
        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(0.85, 0.85, 0.9); love.graphics.line(baseX - 6, -8, baseX + 2, 0); love.graphics.line(baseX - 6, 8, baseX + 2, 0)
        love.graphics.setColor(0.7, 0.6, 0.3); love.graphics.rectangle("fill", baseX, -0.8, 24, 1.6)
        love.graphics.setColor(0.85, 0.85, 0.9); love.graphics.polygon("fill", baseX + 24, -2, baseX + 28, 0, baseX + 24, 2)
        love.graphics.setLineWidth(1)
    elseif gun == "musket" then
        love.graphics.setColor(0.3, 0.18, 0.05); love.graphics.rectangle("fill", baseX - 4, -3, 12, 6)
        love.graphics.setColor(0.4, 0.4, 0.4); love.graphics.rectangle("fill", baseX + 8, -1.5, 26, 3)
        love.graphics.setColor(0.85, 0.65, 0.25); love.graphics.rectangle("fill", baseX + 6, -2.5, 3, 5); love.graphics.rectangle("fill", baseX + 33, -2, 2, 4)
    elseif gun == "void_spear" then
        love.graphics.setColor(0.32, 0.32, 0.34)
        love.graphics.setLineWidth(2)
        love.graphics.line(baseX - 2, 0, baseX + 60, 0)
        love.graphics.polygon("fill", baseX + 58, -2, baseX + 70, 0, baseX + 58, 2)
        love.graphics.setLineWidth(1)
    elseif gun == "telekinesis" then
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
    elseif gun == "reality_bend" then
        local tearA = math.max(0, math.sin(t * 0.9)) * 0.55
        love.graphics.setColor(0.75, 0.3, 1, tearA)
        love.graphics.line(baseX + 4, -8, baseX + 7, -4, baseX + 5, 0, baseX + 8, 3, baseX + 6, 8)
        for i = 1, 16 do
            local a = t * 1.4 + i * 0.52
            local rr = 7 + ((i * 3) % 14) + math.sin(t * 2 + i) * 2
            local px = baseX + 8 + math.cos(a) * rr
            local py = math.sin(a) * rr * 0.9
            local alpha = 0.4 + 0.5 * math.sin(t * 4 + i * 0.7)
            love.graphics.setColor(0.75, 0.4, 1, alpha)
            love.graphics.circle("fill", px, py, 1)
        end
        local glyphs = {"*", "+", "x", "#"}
        for i = 0, 3 do
            local a = t * 0.8 + i * (math.pi / 2)
            local rr = 16 + math.sin(t + i) * 3
            local gx = baseX + 8 + math.cos(a) * rr
            local gy = math.sin(a) * rr * 0.9
            love.graphics.setColor(0.9, 0.55, 1, 0.85)
            love.graphics.print(glyphs[i + 1], gx - 3, gy - 5)
        end
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
    elseif gun == "dark_magic" then
        love.graphics.setColor(0.18, 0.10, 0.20)
        love.graphics.rectangle("fill", baseX - 3, -3, 10, 6)
        for gx = baseX - 2, baseX + 5, 2 do
            love.graphics.setColor(0.55, 0.25, 0.75)
            love.graphics.line(gx, -3, gx, 3)
        end
        love.graphics.setColor(0.05, 0.03, 0.08)
        love.graphics.setLineWidth(4)
        love.graphics.line(baseX + 6, 0, baseX + 26, 0)
        love.graphics.setColor(0.25, 0.1, 0.35)
        love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 6, -1.2, baseX + 26, -1.2)
        love.graphics.line(baseX + 6, 1.2, baseX + 26, 1.2)
        love.graphics.setColor(0.08, 0.04, 0.12)
        love.graphics.setLineWidth(3)
        love.graphics.line(baseX + 26, 0, baseX + 30, -8)
        love.graphics.line(baseX + 26, 0, baseX + 30,  8)
        love.graphics.line(baseX + 26, 0, baseX + 34, -5)
        love.graphics.line(baseX + 26, 0, baseX + 34,  5)
        love.graphics.setLineWidth(1)
        local pulse = 0.75 + math.sin(t * 3) * 0.25
        love.graphics.setColor(0.55, 0.15, 0.85, 0.35)
        love.graphics.circle("fill", baseX + 30, 0, 10 * pulse)
        love.graphics.setColor(0.75, 0.35, 1, 0.85)
        love.graphics.circle("fill", baseX + 30, 0, 6)
        love.graphics.setColor(1, 0.85, 0.3, 0.95)
        love.graphics.circle("fill", baseX + 30, 0, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", baseX + 30, 0, 1.2)
        for i = 0, 2 do
            local a = t * 2 + i * (math.pi * 2 / 3)
            love.graphics.setColor(0.85, 0.45, 1, 0.8)
            love.graphics.print(({"*","+","x"})[i + 1], baseX + 30 + math.cos(a) * 14, math.sin(a) * 9 - 4)
        end
        for i = 1, 3 do
            local a = t * 4 + i
            love.graphics.setColor(0.55, 0.2, 0.8, 0.5)
            love.graphics.circle("fill", baseX + 10 + math.sin(a) * 2, math.cos(a) * 4, 1.2)
        end
    elseif gun == "nailgun" then
        love.graphics.setColor(0.85, 0.75, 0.12)
        love.graphics.polygon("fill", baseX, -4, baseX + 22, -4, baseX + 24, -2, baseX + 24, 3, baseX, 3)
        love.graphics.setColor(0.45, 0.4, 0.05)
        love.graphics.polygon("line", baseX, -4, baseX + 22, -4, baseX + 24, -2, baseX + 24, 3, baseX, 3)
        love.graphics.setColor(0.08, 0.08, 0.1)
        love.graphics.rectangle("fill", baseX + 2, -3, 6, 5)
        love.graphics.setColor(0.15, 0.13, 0.08)
        love.graphics.circle("fill", baseX + 11, -1, 3.5)
        love.graphics.setColor(0.85, 0.7, 0.15)
        love.graphics.circle("line", baseX + 11, -1, 3.5)
        local rot = t * 4
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.line(baseX + 11, -1, baseX + 11 + math.cos(rot) * 3, -1 + math.sin(rot) * 3)
        love.graphics.setColor(0.15, 0.15, 0.18); love.graphics.setLineWidth(2.5)
        love.graphics.line(baseX - 2, 3, baseX - 5, 6, baseX - 2, 9, baseX - 6, 11)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.2, 0.18, 0.12); love.graphics.rectangle("fill", baseX + 4, 3, 12, 10)
        love.graphics.setColor(0.6, 0.55, 0.1); love.graphics.rectangle("line", baseX + 4, 3, 12, 10)
        love.graphics.setColor(0.88, 0.88, 0.92)
        for i = 0, 5 do
            local nx = baseX + 5.5 + i * 1.7
            love.graphics.line(nx, 5, nx, 12); love.graphics.circle("fill", nx, 4.5, 0.7)
        end
        love.graphics.setColor(0.35, 0.35, 0.4); love.graphics.rectangle("fill", baseX + 24, -3, 5, 5)
        love.graphics.setColor(0.08, 0.08, 0.1); love.graphics.rectangle("fill", baseX + 27, -2, 2, 3)
    elseif gun == "handcannon" then
        love.graphics.setColor(0.22, 0.14, 0.08); love.graphics.rectangle("fill", baseX - 4, -3, 8, 7)
        love.graphics.setColor(0.35, 0.22, 0.12)
        for i = 0, 3 do love.graphics.line(baseX - 3 + i * 2, -3, baseX - 3 + i * 2, 4) end
        love.graphics.setColor(0.18, 0.15, 0.2); love.graphics.rectangle("fill", baseX + 2, -5, 22, 10)
        love.graphics.setColor(0.35, 0.3, 0.4); love.graphics.rectangle("line", baseX + 2, -5, 22, 10)
        love.graphics.setColor(0.95, 0.75, 0.15); love.graphics.rectangle("fill", baseX + 4, -1, 18, 2)
        love.graphics.setColor(0.25, 0.22, 0.28); love.graphics.circle("fill", baseX + 8, 0, 6)
        love.graphics.setColor(0.5, 0.45, 0.55); love.graphics.circle("line", baseX + 8, 0, 6)
        for i = 0, 5 do
            local a = (i / 6) * math.pi * 2 + t * 0.3
            love.graphics.setColor(0.05, 0.05, 0.08)
            love.graphics.circle("fill", baseX + 8 + math.cos(a) * 3.5, math.sin(a) * 3.5, 1.3)
        end
        love.graphics.setColor(0.3, 0.26, 0.32)
        love.graphics.polygon("fill", baseX + 24, -6, baseX + 32, -7, baseX + 34, 0, baseX + 32, 7, baseX + 24, 6)
        love.graphics.setColor(0.85, 0.8, 0.85)
        for i = 0, 3 do
            local tx = baseX + 26 + i * 2
            love.graphics.polygon("fill", tx, -5, tx + 1, -3, tx - 1, -3)
            love.graphics.polygon("fill", tx, 5, tx + 1, 3, tx - 1, 3)
        end
        local ep = 0.7 + math.sin(t * 5) * 0.3
        love.graphics.setColor(1, 0.3, 0.1, ep); love.graphics.circle("fill", baseX + 28, -4, 1.3)
        love.graphics.setColor(1, 1, 0.8); love.graphics.circle("fill", baseX + 28, -4, 0.5)
        love.graphics.setColor(0, 0, 0); love.graphics.circle("fill", baseX + 32, 0, 2.5)
    elseif gun == "sniper" then
        love.graphics.setColor(0.32, 0.2, 0.1)
        love.graphics.polygon("fill", baseX - 8, -3, baseX + 6, -3, baseX + 6, 3, baseX - 8, 4, baseX - 6, 1)
        love.graphics.setColor(0.45, 0.28, 0.12)
        love.graphics.polygon("line", baseX - 8, -3, baseX + 6, -3, baseX + 6, 3, baseX - 8, 4, baseX - 6, 1)
        love.graphics.setColor(0.12, 0.1, 0.14); love.graphics.rectangle("fill", baseX + 6, -3, 12, 5)
        love.graphics.setColor(0.85, 0.65, 0.15); love.graphics.rectangle("fill", baseX + 10, -6, 3, 4)
        love.graphics.circle("fill", baseX + 11.5, -7, 1.8)
        love.graphics.setColor(0.18, 0.18, 0.22); love.graphics.rectangle("fill", baseX + 18, -1.2, 38, 2.4)
        love.graphics.setColor(0.35, 0.35, 0.4); love.graphics.rectangle("fill", baseX + 54, -2.5, 4, 5)
        love.graphics.setColor(0.1, 0.1, 0.12)
        for i = 0, 2 do love.graphics.rectangle("fill", baseX + 55, -2 + i * 1.5, 2, 0.6) end
        love.graphics.setColor(0.15, 0.15, 0.18)
        love.graphics.rectangle("fill", baseX + 14, -6, 4, 3); love.graphics.rectangle("fill", baseX + 26, -6, 4, 3)
        love.graphics.setColor(0.22, 0.22, 0.26); love.graphics.rectangle("fill", baseX + 13, -9, 18, 4)
        love.graphics.setColor(0.4, 0.4, 0.48); love.graphics.rectangle("line", baseX + 13, -9, 18, 4)
        love.graphics.setColor(0.05, 0.6, 0.9, 0.9)
        love.graphics.circle("fill", baseX + 14, -7, 2); love.graphics.circle("fill", baseX + 30, -7, 2.5)
        love.graphics.setColor(0.4, 0.95, 1); love.graphics.circle("fill", baseX + 30, -7, 1.5)
        love.graphics.setColor(1, 0.2, 0.2, 0.9)
        love.graphics.line(baseX + 28, -7, baseX + 32, -7); love.graphics.line(baseX + 30, -9, baseX + 30, -5)
        love.graphics.circle("line", baseX + 30, -7, 1)
        love.graphics.setColor(0.2, 0.2, 0.25); love.graphics.setLineWidth(1.5)
        love.graphics.line(baseX + 34, 1, baseX + 30, 8); love.graphics.line(baseX + 34, 1, baseX + 38, 8)
        love.graphics.setLineWidth(1)
    elseif gun == "glauncher" then
        love.graphics.setColor(0.2, 0.2, 0.22); love.graphics.setLineWidth(2)
        love.graphics.line(baseX - 6, -2, baseX - 2, -2); love.graphics.line(baseX - 6, 2, baseX - 2, 2)
        love.graphics.line(baseX - 6, -2, baseX - 6, 2); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.15, 0.18, 0.12); love.graphics.rectangle("fill", baseX - 2, -3, 6, 6)
        love.graphics.setColor(0.22, 0.2, 0.24); love.graphics.circle("fill", baseX + 5, 0, 9)
        love.graphics.setColor(0.4, 0.4, 0.45); love.graphics.setLineWidth(2)
        love.graphics.circle("line", baseX + 5, 0, 9); love.graphics.setLineWidth(1)
        local rot = t * 1.2
        for i = 0, 5 do
            local a = rot + (i / 6) * math.pi * 2
            local cx = baseX + 5 + math.cos(a) * 5.5
            local cy = math.sin(a) * 5.5
            love.graphics.setColor(0.15, 0.35, 0.12); love.graphics.circle("fill", cx, cy, 2)
            love.graphics.setColor(0.85, 0.65, 0.2); love.graphics.circle("line", cx, cy, 2)
            love.graphics.setColor(0.9, 0.8, 0.2); love.graphics.circle("fill", cx, cy, 0.6)
        end
        love.graphics.setColor(0.1, 0.1, 0.12); love.graphics.circle("fill", baseX + 5, 0, 1.5)
        love.graphics.setColor(0.18, 0.22, 0.14); love.graphics.rectangle("fill", baseX + 14, -4, 14, 8)
        love.graphics.setColor(0.35, 0.4, 0.22); love.graphics.rectangle("line", baseX + 14, -4, 14, 8)
        love.graphics.setColor(0.12, 0.12, 0.14); love.graphics.circle("fill", baseX + 28, 0, 4.5)
        love.graphics.setColor(0, 0, 0); love.graphics.circle("fill", baseX + 28, 0, 3)
    elseif gun == "plasma" then
        love.graphics.setColor(0.08, 0.1, 0.18); love.graphics.rectangle("fill", baseX - 5, -4, 6, 8)
        love.graphics.setColor(0.1, 0.14, 0.26); love.graphics.rectangle("fill", baseX + 1, -7, 30, 14)
        love.graphics.setColor(0.25, 0.45, 0.85); love.graphics.rectangle("line", baseX + 1, -7, 30, 14)
        love.graphics.setColor(0, 0, 0.05); love.graphics.rectangle("fill", baseX + 4, -5, 12, 10)
        for i = 1, 12 do
            local a = t * 3 + i * 0.6
            local r = 4 * math.abs(math.sin(t * 2 + i))
            local cx = baseX + 10 + math.cos(a) * r; local cy = math.sin(a) * r * 0.6
            love.graphics.setColor(0.3, 0.75, 1, 0.85); love.graphics.circle("fill", cx, cy, 0.8)
            love.graphics.setColor(0.95, 1, 1, 0.9); love.graphics.circle("fill", cx, cy, 0.35)
        end
        love.graphics.setColor(0.6, 0.85, 1, 0.15); love.graphics.rectangle("fill", baseX + 4, -5, 12, 10)
        for i = 0, 3 do
            local rx = baseX + 18 + i * 3
            love.graphics.setColor(0.5, 0.3, 0.1); love.graphics.ellipse("line", rx, 0, 1.5, 6)
            love.graphics.setColor(0.85, 0.55, 0.15); love.graphics.ellipse("line", rx, 0, 1.5, 5)
        end
        love.graphics.setColor(0.1, 0.15, 0.25)
        love.graphics.polygon("fill", baseX + 31, -5, baseX + 36, -3, baseX + 36, 3, baseX + 31, 5)
        local glow = 0.7 + math.sin(t * 8) * 0.3
        love.graphics.setColor(0.3, 0.6, 1, 0.5 * glow); love.graphics.circle("fill", baseX + 36, 0, 7 * glow)
        love.graphics.setColor(0.6, 0.9, 1, 0.9); love.graphics.circle("fill", baseX + 36, 0, 3.5)
        love.graphics.setColor(1, 1, 1); love.graphics.circle("fill", baseX + 36, 0, 1.5)
    elseif gun == "lightning_rod" then
        love.graphics.setColor(0.18, 0.14, 0.22); love.graphics.rectangle("fill", baseX - 4, -3, 8, 6)
        love.graphics.setColor(0.55, 0.3, 0.8); love.graphics.rectangle("line", baseX - 4, -3, 8, 6)
        love.graphics.setColor(0.35, 0.35, 0.45); love.graphics.setLineWidth(3)
        love.graphics.line(baseX + 4, 0, baseX + 48, 0)
        love.graphics.setColor(0.65, 0.65, 0.75); love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 4, -1.2, baseX + 48, -1.2)
        for i = 0, 3 do
            local cx = baseX + 10 + i * 8
            love.graphics.setColor(0.5, 0.3, 0.1); love.graphics.ellipse("fill", cx, 0, 2.5, 4)
            love.graphics.setColor(0.85, 0.55, 0.15); love.graphics.ellipse("line", cx, 0, 2.5, 4)
            local g = 0.5 + math.abs(math.sin(t * 7 + i * 1.3)) * 0.5
            love.graphics.setColor(0.6, 0.85, 1, 0.5 * g); love.graphics.ellipse("line", cx, 0, 3.5 * g, 5.5 * g)
        end
        love.graphics.setColor(0.85, 0.88, 0.95)
        love.graphics.polygon("fill", baseX + 48, -1, baseX + 58, 0, baseX + 48, 1)
        love.graphics.setColor(0.6, 0.62, 0.7)
        love.graphics.line(baseX + 46, 0, baseX + 52, -7); love.graphics.line(baseX + 46, 0, baseX + 52, 7)
        love.graphics.line(baseX + 50, -5, baseX + 55, -10); love.graphics.line(baseX + 50, 5, baseX + 55, 10)
        local pulse = 0.5 + math.sin(t * 10) * 0.5
        for r = 16, 4, -3 do
            love.graphics.setColor(0.5, 0.85, 1, 0.12 * pulse * (1 - r / 16))
            love.graphics.circle("fill", baseX + 56, 0, r * pulse)
        end
        love.graphics.setColor(1, 1, 1); love.graphics.setLineWidth(1)
    elseif gun == "chainsword" then
        love.graphics.setColor(0.3, 0.18, 0.08); love.graphics.rectangle("fill", baseX - 5, -3, 11, 6)
        love.graphics.setColor(0.5, 0.3, 0.15)
        for i = 0, 4 do love.graphics.line(baseX - 4 + i * 2, -3, baseX - 4 + i * 2, 3) end
        love.graphics.setColor(0.12, 0.12, 0.14); love.graphics.rectangle("fill", baseX + 6, -6, 10, 12)
        love.graphics.setColor(0.45, 0.45, 0.5); love.graphics.rectangle("line", baseX + 6, -6, 10, 12)
        love.graphics.setColor(0.18, 0.18, 0.2); love.graphics.circle("fill", baseX + 11, -3, 2.5)
        love.graphics.setColor(0.8, 0.8, 0.85); love.graphics.circle("line", baseX + 11, -3, 2.5)
        local ang = math.sin(t * 6) * math.pi * 0.4
        love.graphics.setColor(1, 0.3, 0.2)
        love.graphics.line(baseX + 11, -3, baseX + 11 + math.cos(ang - math.pi/2) * 2, -3 + math.sin(ang - math.pi/2) * 2)
        love.graphics.setColor(0.3, 0.3, 0.32); love.graphics.rectangle("fill", baseX + 8, -9, 2, 3)
        love.graphics.setColor(0.6, 0.6, 0.65, 0.7)
        love.graphics.circle("fill", baseX + 9, -11 - math.sin(t * 3) * 1, 1.8)
        love.graphics.setColor(0.85, 0.65, 0.2); love.graphics.rectangle("fill", baseX + 16, -6, 2, 12)
        love.graphics.setColor(0.6, 0.6, 0.65); love.graphics.rectangle("fill", baseX + 18, -4, 34, 8)
        love.graphics.setColor(0.85, 0.85, 0.9); love.graphics.line(baseX + 18, 0, baseX + 52, 0)
        love.graphics.setColor(0.3, 0.3, 0.35); love.graphics.rectangle("line", baseX + 18, -4, 34, 8)
        local off = (t * 80) % 5
        love.graphics.setColor(0.92, 0.92, 0.95)
        for i = 0, 7 do
            local x = baseX + 19 + i * 5 - off
            love.graphics.polygon("fill", x, -4, x + 2.5, -7, x + 5, -4)
            love.graphics.polygon("fill", x + 2.5, 4, x, 7, x + 5, 7)
        end
        love.graphics.setColor(0.75, 0.75, 0.8)
        love.graphics.polygon("fill", baseX + 52, -4, baseX + 58, 0, baseX + 52, 4)
    elseif gun == "quantum" then
        local phase1 = math.sin(t * 7) * 4
        local phase2 = math.cos(t * 9) * 4
        for r = 14, 6, -2 do
            love.graphics.setColor(0.6, 0.3, 1, 0.08 * (1 - r / 14))
            love.graphics.circle("fill", baseX + 12, 0, r)
        end
        love.graphics.setColor(0.5, 0.2, 1, 0.5); love.graphics.rectangle("fill", baseX + 1, -3 + phase1, 24, 6, 1, 1)
        love.graphics.setColor(0.7, 0.4, 1, 0.7); love.graphics.rectangle("line", baseX + 1, -3 + phase1, 24, 6, 1, 1)
        love.graphics.setColor(0.3, 0.8, 1, 0.5); love.graphics.rectangle("fill", baseX + 1, -3 + phase2, 24, 6, 1, 1)
        love.graphics.setColor(0.4, 0.95, 1, 0.7); love.graphics.rectangle("line", baseX + 1, -3 + phase2, 24, 6, 1, 1)
        love.graphics.setColor(0.15, 0.1, 0.22); love.graphics.rectangle("fill", baseX, -3, 26, 6, 1, 1)
        love.graphics.setColor(0.75, 0.55, 1); love.graphics.rectangle("line", baseX, -3, 26, 6, 1, 1)
        love.graphics.setColor(0.05, 0.05, 0.1); love.graphics.rectangle("fill", baseX + 8, -2, 6, 4)
        love.graphics.setColor(0.6, 0.9, 1, 0.9)
        love.graphics.circle("fill", baseX + 11 + math.sin(t * 18) * 1.5, math.cos(t * 14) * 1, 1)
        local pulse = 0.7 + math.sin(t * 15) * 0.3
        love.graphics.setColor(0.95, 0.95, 1); love.graphics.circle("fill", baseX + 27, 0, 1.8)
        love.graphics.setColor(0.6, 0.3, 1, 0.4); love.graphics.circle("fill", baseX + 27, 0, 5 * pulse)
    elseif gun == "flamethrower" then
        love.graphics.setColor(0.45, 0.15, 0.1); love.graphics.rectangle("fill", baseX - 8, -5, 5, 11)
        love.graphics.setColor(0.6, 0.2, 0.15); love.graphics.rectangle("line", baseX - 8, -5, 5, 11)
        love.graphics.setColor(0.15, 0.15, 0.18); love.graphics.setLineWidth(2)
        love.graphics.line(baseX - 3, 0, baseX, 0); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.22, 0.18, 0.18); love.graphics.rectangle("fill", baseX, -3, 18, 6)
        love.graphics.setColor(0.5, 0.3, 0.2); love.graphics.rectangle("line", baseX, -3, 18, 6)
        love.graphics.setColor(0.9, 0.5, 0.1, 0.9)
        love.graphics.circle("fill", baseX + 22, 0, 2 + math.sin(t * 10) * 0.5)
        love.graphics.setColor(1, 0.85, 0.3); love.graphics.circle("fill", baseX + 22, 0, 1)
        for i = 1, 18 do
            local f = ((t * 3 + i * 0.17) % 1)
            local x = baseX + 24 + f * 38
            local y = math.sin(t * 6 + i) * (3 + f * 4)
            local r = (1 - f) * 4
            local col = (f < 0.5) and {1, 0.9, 0.3} or {1, 0.45, 0.1}
            love.graphics.setColor(col[1], col[2], col[3], (1 - f) * 0.85)
            love.graphics.circle("fill", x, y, r)
        end
    elseif gun == "sawedoff" then
        love.graphics.setColor(0.22, 0.14, 0.08); love.graphics.rectangle("fill", baseX - 4, -3, 10, 6)
        love.graphics.setColor(0.6, 0.55, 0.35)
        for i = 0, 3 do love.graphics.rectangle("fill", baseX - 3 + i * 2.5, -3, 1, 6) end
        love.graphics.setColor(0.18, 0.18, 0.22)
        love.graphics.rectangle("fill", baseX + 6, -4, 16, 3); love.graphics.rectangle("fill", baseX + 6, 1, 16, 3)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", baseX + 6, -4, 16, 3); love.graphics.rectangle("line", baseX + 6, 1, 16, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", baseX + 22, -2.5, 1.2); love.graphics.circle("fill", baseX + 22, 2.5, 1.2)
        love.graphics.setColor(0.35, 0.28, 0.15)
        love.graphics.polygon("fill", baseX + 4, -4, baseX + 7, -7, baseX + 7, -4)
    elseif gun == "gatling" then
        love.graphics.setColor(0.85, 0.65, 0.2); love.graphics.rectangle("fill", baseX - 4, 3, 16, 8)
        love.graphics.setColor(0.55, 0.4, 0.1); love.graphics.rectangle("line", baseX - 4, 3, 16, 8)
        for i = 0, 4 do love.graphics.rectangle("fill", baseX - 3 + i * 3, 4, 1, 2) end
        love.graphics.setColor(0.8, 0.7, 0.2); love.graphics.line(baseX + 4, 3, baseX + 10, 0)
        love.graphics.setColor(0.25, 0.22, 0.28); love.graphics.rectangle("fill", baseX, -5, 14, 10)
        love.graphics.setColor(0.5, 0.45, 0.55); love.graphics.rectangle("line", baseX, -5, 14, 10)
        local rot = t * 20
        love.graphics.setColor(0.15, 0.15, 0.18); love.graphics.rectangle("fill", baseX + 14, -5, 22, 10)
        for i = 0, 5 do
            local a = rot + (i / 6) * math.pi * 2
            local cy = math.sin(a) * 3
            love.graphics.setColor(0.35, 0.35, 0.4); love.graphics.rectangle("fill", baseX + 14, cy - 0.8, 22, 1.6)
        end
        love.graphics.setColor(0.5, 0.5, 0.55); love.graphics.circle("line", baseX + 36, 0, 4.5)
        love.graphics.setColor(0.08, 0.08, 0.1); love.graphics.circle("fill", baseX + 36, 0, 3.5)
        if math.sin(t * 90) > 0.2 then
            love.graphics.setColor(1, 0.8, 0.3, 0.9); love.graphics.circle("fill", baseX + 38, 0, 3 + math.sin(t * 140) * 1)
            love.graphics.setColor(1, 1, 0.8); love.graphics.circle("fill", baseX + 38, 0, 1.5)
        end
    elseif gun == "icegun" then
        love.graphics.setColor(0.6, 0.8, 0.95); love.graphics.rectangle("fill", baseX, -4, 22, 8)
        love.graphics.setColor(0.25, 0.4, 0.55); love.graphics.rectangle("line", baseX, -4, 22, 8)
        love.graphics.setColor(0.85, 0.95, 1, 0.85); love.graphics.rectangle("fill", baseX + 3, -3, 8, 6)
        love.graphics.setColor(0.4, 0.6, 0.85); love.graphics.rectangle("line", baseX + 3, -3, 8, 6)
        love.graphics.setColor(0.9, 0.98, 1, 0.9)
        love.graphics.polygon("fill", baseX + 14, -5, baseX + 16, -7, baseX + 18, -5)
        love.graphics.polygon("fill", baseX + 13, 4, baseX + 15, 6, baseX + 17, 4)
        love.graphics.setColor(0.75, 0.9, 1, 0.95)
        love.graphics.polygon("fill", baseX + 22, -5, baseX + 30, -4, baseX + 32, 0, baseX + 30, 4, baseX + 22, 5)
        love.graphics.setColor(0.4, 0.6, 0.85)
        love.graphics.polygon("line", baseX + 22, -5, baseX + 30, -4, baseX + 32, 0, baseX + 30, 4, baseX + 22, 5)
        love.graphics.setColor(0.95, 1, 1, 0.85)
        love.graphics.circle("fill", baseX + 28, 0, 1.5 + math.sin(t * 4) * 0.5)
        for i = 1, 6 do
            local f = ((t * 0.7 + i / 6) % 1)
            local sx = baseX + 30 + f * 18
            local sy = math.sin(t + i) * 5
            local a = (1 - f) * 0.9
            love.graphics.setColor(1, 1, 1, a); love.graphics.circle("fill", sx, sy, 1 - f * 0.5)
            love.graphics.line(sx - 1.5, sy, sx + 1.5, sy); love.graphics.line(sx, sy - 1.5, sx, sy + 1.5)
        end
    elseif gun == "scythe" then
        -- Proper reaper scythe: long snath, grip wraps, metal collar, big
        -- curved crescent blade (outer body + inner hook), steel spine
        -- highlight, glowing green inner edge, rune, drip wisps.
        love.graphics.setColor(0.35, 0.22, 0.1); love.graphics.setLineWidth(4)
        love.graphics.line(baseX - 4, 0, baseX + 50, 0)
        love.graphics.setColor(0.55, 0.36, 0.16); love.graphics.setLineWidth(1.5)
        love.graphics.line(baseX - 4, -1.2, baseX + 50, -1.2)
        love.graphics.setLineWidth(1)
        for _, wx in ipairs({baseX + 4, baseX + 22, baseX + 40}) do
            love.graphics.setColor(0.1, 0.06, 0.04)
            love.graphics.rectangle("fill", wx, -2.5, 3, 5)
            love.graphics.setColor(0.85, 0.65, 0.2)
            love.graphics.line(wx + 1, -2.5, wx + 1, 2.5)
        end
        love.graphics.setColor(0.3, 0.3, 0.36); love.graphics.rectangle("fill", baseX + 46, -3.5, 7, 7)
        love.graphics.setColor(0.6, 0.6, 0.7); love.graphics.rectangle("line", baseX + 46, -3.5, 7, 7)
        love.graphics.setColor(0.1, 0.08, 0.12); love.graphics.line(baseX + 49, -3.5, baseX + 49, 3.5)
        -- Blade outer body
        love.graphics.setColor(0.14, 0.1, 0.18)
        love.graphics.polygon("fill",
            baseX + 53, -2, baseX + 56, -12, baseX + 64, -22,
            baseX + 78, -28, baseX + 94, -26, baseX + 100, -18,
            baseX + 96, -10, baseX + 82, -12, baseX + 66, -10, baseX + 54, -4)
        -- Inner hook
        love.graphics.polygon("fill",
            baseX + 54, -4, baseX + 66, -10, baseX + 82, -12, baseX + 96, -10,
            baseX + 96, -6, baseX + 82, -6, baseX + 66, -4, baseX + 54, 0)
        love.graphics.setColor(0.04, 0.02, 0.08); love.graphics.setLineWidth(1.5)
        love.graphics.line(
            baseX + 53, -2, baseX + 56, -12, baseX + 64, -22,
            baseX + 78, -28, baseX + 94, -26, baseX + 100, -18,
            baseX + 96, -10, baseX + 96, -6)
        love.graphics.line(baseX + 96, -6, baseX + 82, -6, baseX + 66, -4, baseX + 54, 0)
        love.graphics.setColor(0.42, 0.38, 0.48); love.graphics.setLineWidth(1.5)
        love.graphics.line(baseX + 58, -14, baseX + 68, -22, baseX + 82, -26, baseX + 94, -24, baseX + 98, -18)
        -- Glowing green cutting edge
        local glow = 0.8 + math.sin(t * 5) * 0.2
        love.graphics.setColor(0.3, 1, 0.5, glow); love.graphics.setLineWidth(2.2)
        love.graphics.line(baseX + 54, -4, baseX + 66, -8, baseX + 80, -10, baseX + 94, -8, baseX + 96, -6)
        love.graphics.setColor(1, 1, 0.9, glow * 0.8); love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 54, -4, baseX + 66, -8, baseX + 80, -10, baseX + 94, -8)
        -- Rune
        love.graphics.setColor(0.3, 1, 0.5, 0.5 + math.sin(t * 3) * 0.3)
        love.graphics.circle("line", baseX + 78, -18, 2.2)
        love.graphics.line(baseX + 76, -18, baseX + 80, -18)
        love.graphics.line(baseX + 78, -20, baseX + 78, -16)
        -- Drip wisps
        for i = 0, 4 do
            local f = ((t * 0.8 + i * 0.2) % 1)
            love.graphics.setColor(0.3, 1, 0.4, (1 - f) * 0.7)
            love.graphics.circle("fill", baseX + 98 + f * 3, -18 + f * 18, 2 - f * 1.3)
        end
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(0.2, 0.2, 0.25); love.graphics.rectangle("fill", baseX, -3, 22, 6)
    end
    love.graphics.setLineWidth(1)  -- reset so hat/claw previews keep their own outline widths
    love.graphics.pop()
end

local function drawTrailPreview(x, y, scale, trail, t)
    if not trail or trail == "none" then return end
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(scale, scale)
    if trail == "sparkle" then
        for i = 1, 10 do
            local a = (t * 2 + i * 0.6) % (math.pi * 2)
            local r = 30 + 18 * math.sin(t * 3 + i)
            local sx = math.cos(a) * r
            local sy = math.sin(a) * r * 0.6 + 12
            local alpha = 0.4 + 0.5 * math.sin(t * 4 + i)
            love.graphics.setColor(1, 1, 0.7, alpha)
            love.graphics.circle("fill", sx, sy, 1.5)
            love.graphics.setColor(1, 1, 1, alpha * 0.6)
            love.graphics.circle("fill", sx - 0.5, sy - 0.5, 0.6)
        end
    elseif trail == "fire" then
        for i = 1, 14 do
            local offX = math.sin(t * 2 + i * 0.8) * 6 - 2 * (i - 7)
            local offY = 18 + i * 2 + math.sin(t * 4 + i) * 2
            local a = 1 - i / 14
            local r = 4 * a + 0.5
            love.graphics.setColor(1, 0.3 + 0.4 * a, 0.1, a * 0.8)
            love.graphics.circle("fill", offX, offY, r)
            if i % 2 == 0 then
                love.graphics.setColor(1, 0.9, 0.4, a * 0.7)
                love.graphics.circle("fill", offX, offY - 1, r * 0.5)
            end
        end
    elseif trail == "data" then
        for i = 0, 7 do
            local col = i - 4
            local dy = ((t * 40 + i * 16) % 60) + 6
            love.graphics.setColor(0.3, 1, 0.5, 1 - dy / 70)
            love.graphics.print(((i + math.floor(t * 2)) % 2 == 0) and "0" or "1", col * 6, dy)
        end
        for i = 1, 6 do
            local a = t * 3 + i
            love.graphics.setColor(0.2, 0.8, 1, 0.5)
            love.graphics.circle("fill", math.cos(a) * 25, math.sin(a) * 15 + 14, 1.2)
        end
    elseif trail == "void" then
        for i = 1, 14 do
            local a = t * 1.5 + i * 0.45
            local r = 20 + 10 * math.sin(t * 2 + i)
            local sx = math.cos(a) * r
            local sy = math.sin(a) * r * 0.6 + 12
            local alpha = 0.3 + 0.25 * math.sin(t * 2 + i * 0.7)
            love.graphics.setColor(0.4, 0.1, 0.6, alpha)
            love.graphics.circle("fill", sx, sy, 2.5)
        end
    elseif trail == "ugnrak" then
        local serpents = 3
        for s = 1, serpents do
            local speed = 1.2 + s * 0.3
            local radius = 28 + s * 8
            local segs = 18
            local baseOff = t * speed + (s * math.pi * 2 / serpents)
            local pts = {}
            local spikeCenters = {}
            for i = 1, segs do
                local segAng = baseOff - i * 0.14
                local r = radius + math.sin(t * 2 + i + s) * 3
                local cx = math.cos(segAng) * r
                local cy = math.sin(segAng) * r
                pts[#pts + 1] = cx; pts[#pts + 1] = cy
                if i % 3 == 0 then
                    spikeCenters[#spikeCenters + 1] = {x = cx, y = cy, ang = segAng, iFrac = i / segs}
                end
            end
            for _, sc in ipairs(spikeCenters) do
                local tanX = -math.sin(sc.ang); local tanY = math.cos(sc.ang)
                local perpX = math.cos(sc.ang); local perpY = math.sin(sc.ang)
                local baseW = (1 - sc.iFrac) * 3 + 1.5
                local spikeLen = baseW + 5
                for side = -1, 1, 2 do
                    love.graphics.setColor(0.75, 0.08, 0.1)
                    love.graphics.polygon("fill",
                        sc.x + tanX * baseW, sc.y + tanY * baseW,
                        sc.x - tanX * baseW, sc.y - tanY * baseW,
                        sc.x + perpX * side * spikeLen,
                        sc.y + perpY * side * spikeLen)
                end
            end
            love.graphics.setColor(0.35, 0.02, 0.02)
            love.graphics.setLineWidth(7); love.graphics.line(pts)
            love.graphics.setColor(0.72, 0.1, 0.12)
            love.graphics.setLineWidth(5); love.graphics.line(pts)
            love.graphics.setColor(0.9, 0.2, 0.2)
            love.graphics.setLineWidth(2); love.graphics.line(pts)
            love.graphics.setLineWidth(1)
            local hx, hy = pts[1], pts[2]
            love.graphics.setColor(0.8, 0.12, 0.14)
            love.graphics.circle("fill", hx, hy, 6)
            love.graphics.setColor(1, 0.2, 0.2)
            love.graphics.circle("line", hx, hy, 6)
            for d = 1, 24 do
                local fa = (d / 24) * math.pi * 2 + t * 0.7
                local fr = 4.5 * (0.35 + (d % 5) * 0.12)
                love.graphics.setColor(0.067, 0, 0)
                love.graphics.circle("fill", hx + math.cos(fa) * fr, hy + math.sin(fa) * fr, 0.7)
            end
        end
    elseif trail == "wake" then
        for i = 1, 12 do
            local a = t * 3.2 + i * 0.6
            local r = 16 + 10 * math.sin(t * 2 + i * 0.5)
            local sx = math.cos(a) * r
            local sy = math.sin(a) * r * 0.55 + 10
            local useGold = (i + math.floor(t * 2)) % 2 == 0
            if useGold then
                love.graphics.setColor(1, 0.85, 0.2, 0.75)
            else
                love.graphics.setColor(0.55, 0.15, 0.85, 0.75)
            end
            love.graphics.circle("fill", sx, sy, 2)
        end
        love.graphics.setColor(0.8, 0.4, 1, 0.3)
        love.graphics.circle("line", 0, 12, 20 + math.sin(t * 2) * 4)
    elseif trail == "bubbles" then
        for i = 1, 8 do
            local bx = math.sin(t * 1 + i) * 12
            local by = ((t * 30 + i * 9) % 40) + 6
            love.graphics.setColor(0.6, 0.85, 1, 0.5)
            love.graphics.circle("line", bx, by, 2 + (i % 3))
        end
    elseif trail == "petals" then
        for i = 1, 10 do
            local a = (t * 1.2 + i * 0.6) % (math.pi * 2)
            local r = 20 + math.sin(t + i) * 8
            local col = (i % 2 == 0) and {1, 0.7, 0.8} or {1, 0.9, 0.8}
            love.graphics.setColor(col[1], col[2], col[3], 0.8)
            love.graphics.ellipse("fill", math.cos(a) * r, math.sin(a) * r * 0.6 + 12, 2.5, 1.2)
        end
    elseif trail == "lightning" then
        -- Jagged electric arcs radiating from the player in all directions.
        -- Flickers by re-seeding ~12x/sec; arc count and angle vary per frame.
        local seed = math.floor(t * 12)
        local arcs = 6
        for i = 1, arcs do
            local rngA = math.sin(seed * 71.3 + i * 13.7) * 1000
            local rngB = math.sin(seed * 37.1 + i * 7.9) * 1000
            local jitterAng = (rngA - math.floor(rngA)) - 0.5
            local jitterLen = (rngB - math.floor(rngB))
            local ang = (i / arcs) * math.pi * 2 + jitterAng * 0.4
            local len = 16 + jitterLen * 14
            local segs = 5
            local pts = {0, 6}
            local stepLen = len / segs
            for s = 1, segs do
                local progress = s / segs
                local rngS = math.sin(seed * 91.7 + i * 11.3 + s * 17.1) * 1000
                local jr = ((rngS - math.floor(rngS)) - 0.5) * 6 * (1 - progress * 0.5)
                local cx = math.cos(ang) * stepLen * s
                local cy = math.sin(ang) * stepLen * s
                local jx = -math.sin(ang) * jr
                local jy = math.cos(ang) * jr
                pts[#pts + 1] = cx + jx
                pts[#pts + 1] = cy + jy + 6
            end
            love.graphics.setColor(0.45, 0.75, 1, 0.85)
            love.graphics.setLineWidth(2.2)
            love.graphics.line(pts)
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.setLineWidth(1)
            love.graphics.line(pts)
        end
        love.graphics.setLineWidth(1)
    elseif trail == "shiny" then
        -- Bright white twinkling sparkles + occasional cross-shaped sheen.
        for i = 1, 12 do
            local a = (t * 1.4 + i * 0.55) % (math.pi * 2)
            local r = 22 + 8 * math.sin(t * 2.3 + i)
            local sx = math.cos(a) * r
            local sy = math.sin(a) * r * 0.55 + 12
            local twink = 0.4 + 0.5 * math.sin(t * 5 + i * 1.7)
            love.graphics.setColor(1, 1, 1, twink)
            love.graphics.circle("fill", sx, sy, 1.4)
            -- Tiny 4-point sheen on the brighter ones
            if twink > 0.7 then
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 1, 1, twink * 0.8)
                love.graphics.line(sx - 3, sy, sx + 3, sy)
                love.graphics.line(sx, sy - 3, sx, sy + 3)
            end
        end
    elseif trail == "shadow" then
        for i = 1, 8 do
            love.graphics.setColor(0.05, 0.05, 0.08, 1 - i / 8)
            love.graphics.circle("fill", -i * 2, 12 + i * 1.2, 4)
        end
    elseif trail == "music" then
        local notes = {"o", ".", "J", "F"}
        for i = 0, 5 do
            local y0 = (t * 20 + i * 8) % 40 + 4
            love.graphics.setColor(1, 0.85, 0.4, 1 - y0 / 50)
            love.graphics.print(notes[(i % #notes) + 1], math.sin(t + i) * 14, y0)
        end
    elseif trail == "runes" then
        local syms = {"*", "+", "x", "#", "%"}
        for i = 1, 8 do
            local a = t * 0.6 + i
            local x2 = math.cos(a) * 16
            local y2 = math.sin(a) * 10 + 12
            love.graphics.setColor(0.7, 0.4, 1, 0.75)
            love.graphics.print(syms[(i % #syms) + 1], x2, y2)
        end
    elseif trail == "chaos" then
        for i = 1, 18 do
            local col = {math.random(), math.random(), math.random()}
            love.graphics.setColor(col[1], col[2], col[3], 0.8)
            love.graphics.circle("fill", math.random(-20, 20), math.random(-4, 24), 1.4)
        end
    elseif trail == "super_saiyan" then
        -- Egg-shaped yellow+orange pulsing aura
        local function egg(cx, cy, w, h)
            local N = 42
            local v = {}
            for i = 0, N - 1 do
                local th = (i / N) * math.pi * 2
                local vx, vy = math.cos(th), math.sin(th)
                local wm = (vy < 0) and (0.55 + 0.45 * (1 + vy)) or 1.0
                v[#v + 1] = cx + vx * w * wm
                v[#v + 1] = cy + vy * h + 3
            end
            return v
        end
        local basePulse = 0.85 + 0.15 * math.sin(t * 3)
        for i = 0, 5 do
            local off = math.sin(t * 4 + i * 0.9) * 2
            local w = 16 + i * 4 + off
            local h = 24 + i * 5 + off * 1.2
            local mix = i / 5
            local a = (0.42 - i * 0.06) * basePulse
            love.graphics.setColor(1, 0.9 - mix * 0.35, 0.2 - mix * 0.15, a)
            love.graphics.polygon("fill", egg(0, 8, w, h))
        end
        love.graphics.setColor(1, 0.55, 0.1, 0.22 * basePulse)
        love.graphics.polygon("fill", egg(0, 8, 42 + math.sin(t * 2.5) * 3, 50))
        for i = 0, 2 do
            local ring = ((t * 0.9) + i / 3) % 1
            local rw = 14 + ring * 28
            local rh = 20 + ring * 36
            local a = (1 - ring) * 0.6
            love.graphics.setColor(1, 0.95, 0.35, a)
            love.graphics.polygon("line", egg(0, 8, rw, rh))
        end
        if math.sin(t * 5) > 0.55 then
            love.graphics.setColor(0.85, 0.95, 1, 0.8)
            local ang = math.random() * math.pi * 2
            local x1 = math.cos(ang) * 18
            local y1 = math.sin(ang) * 18 + 8
            local x2 = math.cos(ang) * 28
            local y2 = math.sin(ang) * 28 + 8
            love.graphics.line(x1, y1, (x1 + x2) / 2, (y1 + y2) / 2 + 3, x2, y2)
        end
    end
    love.graphics.pop()
end

local function drawPreviewCrab(x, y, scale, cosmetics, t)
    -- Render the trail BEHIND the crab.
    drawTrailPreview(x, y, scale, cosmetics.trail, t)
    -- Slug tail preview: only when the "slug" TRAIL is equipped (body-independent).
    -- Matches the in-game tail — body-colored fill, no outlines.
    if cosmetics.trail == "slug" then
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.scale(scale, scale)
        local body = Cosmetics.bodyColor(cosmetics)
        local segs = 14
        for i = segs, 1, -1 do
            local progress = i / segs
            local r = 12 * (1 - progress) ^ 1.1 + 1.8
            local wave = math.sin(t * 2 + progress * 3) * (progress * 2.5)
            local tx = -progress * 26 + wave * 0.3
            local ty = 2 + progress * 12 + wave
            love.graphics.setColor(body[1], body[2], body[3])
            love.graphics.circle("fill", tx, ty, r)
        end
        love.graphics.pop()
    end
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(scale, scale)
    local body = Cosmetics.bodyColor(cosmetics)
    local deep = Cosmetics.outlineColor(cosmetics, body)

    -- Legs
    love.graphics.setColor(deep)
    love.graphics.setLineWidth(3)
    for i = -2, 2 do
        if i ~= 0 then
            local ly = math.sin(t * 3 + i) * 4
            love.graphics.line(i * 4, 16, i * 8, 28 + ly)
            love.graphics.line(-i * 4, -16, -i * 8, -(28 + ly))
        end
    end
    -- Body base
    love.graphics.setColor(body)
    love.graphics.circle("fill", 0, 0, 18)
    -- Multicolor pattern overlays — same logic as in-game
    local pattern = Cosmetics.bodyPattern(cosmetics)
    local sec = Cosmetics.bodySecondary(cosmetics)
    if pattern and sec then
        if pattern == "camo" then
            for i = 1, 7 do
                local a = (i / 7) * math.pi * 2 + (i * 1.3)
                local dist = 4 + (i % 3) * 3
                love.graphics.setColor(sec[1], sec[2], sec[3])
                love.graphics.circle("fill", math.cos(a) * dist, math.sin(a) * dist, 4.5 + (i % 2))
            end
        elseif pattern == "galaxy" then
            for i = 1, 12 do
                local a = t * 0.4 + i * 0.6
                local d = (i % 4) * 4
                love.graphics.setColor(sec[1], sec[2], sec[3], 0.85)
                love.graphics.circle("fill", math.cos(a) * d, math.sin(a) * d, 0.8)
            end
            love.graphics.setColor(sec[1], sec[2], sec[3], 0.45)
            love.graphics.circle("line", 0, 0, 14)
        elseif pattern == "stripes" then
            love.graphics.setColor(sec[1], sec[2], sec[3])
            for sy = -15, 15, 5 do
                love.graphics.rectangle("fill", -16, sy, 32, 2)
            end
        elseif pattern == "dots" then
            love.graphics.setColor(sec[1], sec[2], sec[3])
            for i = 1, 6 do
                local a = (i / 6) * math.pi * 2
                love.graphics.circle("fill", math.cos(a) * 10, math.sin(a) * 10, 2)
            end
        elseif pattern == "marble" then
            love.graphics.setColor(sec[1], sec[2], sec[3], 0.65)
            love.graphics.setLineWidth(1.5)
            for i = 0, 4 do
                local a = i * 1.2 + t * 0.3
                love.graphics.arc("line", "open", math.cos(a) * 4, math.sin(a) * 4, 16, a, a + math.pi * 0.6)
            end
            love.graphics.setLineWidth(1)
        elseif pattern == "stars" then
            for i = 1, 5 do
                local a = (i / 5) * math.pi * 2 + t * 0.3
                love.graphics.setColor(sec[1], sec[2], sec[3], 0.9)
                love.graphics.circle("fill", math.cos(a) * 11, math.sin(a) * 11, 1.6)
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
                love.graphics.arc("fill", "pie", 0, 0, 16, ca, ca + 0.7)
            end
        elseif pattern == "lava" then
            love.graphics.setColor(sec[1], sec[2], sec[3], 0.9)
            for i = 1, 5 do
                local a = (i / 5) * math.pi * 2 + math.sin(t * 2 + i) * 0.4
                local d = 4 + (i % 3) * 3
                love.graphics.circle("fill", math.cos(a) * d, math.sin(a) * d, 2.5)
            end
        elseif pattern == "churgly" then
            local jawPhase = 0.35 + 0.35 * math.abs(math.sin(t * 1.8))
            for i = 0, 7 do
                local a = (i / 8) * math.pi * 2 + math.pi / 8
                local cx = math.cos(a) * 14
                local cy = math.sin(a) * 14
                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.rotate(a)
                local open = jawPhase + 0.12 * math.sin(t * 2.2 + i)
                love.graphics.setColor(sec[1] * 0.45, sec[2] * 0.25, sec[3] * 0.55)
                love.graphics.polygon("fill",
                    -4, -11,
                    11, -5 * open,
                    15,   0,
                    11,  5 * open,
                    -4,  11)
                love.graphics.setColor(0.04, 0, 0.08)
                love.graphics.polygon("fill",
                     1, -7,
                    11, -5 * open,
                    11,  5 * open,
                     1,  7)
                love.graphics.setColor(0.92, 0.90, 0.85)
                for k = 0, 4 do
                    local tx = 2 + k * 2.0
                    love.graphics.polygon("fill", tx, -3 * open, tx - 1.1, -0.3, tx + 1.1, -0.3)
                    love.graphics.polygon("fill", tx,  3 * open, tx - 1.1,  0.3, tx + 1.1,  0.3)
                end
                love.graphics.setColor(sec[1], sec[2], sec[3])
                love.graphics.circle("fill", -1, -13, 1.7)
                love.graphics.setColor(0, 0, 0)
                love.graphics.ellipse("fill", -1, -13, 0.5, 1.3)
                love.graphics.pop()
            end
            love.graphics.setColor(sec[1], sec[2], sec[3], 0.35)
            love.graphics.circle("line", 0, 0, 3)
            love.graphics.line(-3, 0, 3, 0)
            love.graphics.line(0, -3, 0, 3)
        end
    end
    love.graphics.setColor(deep)
    love.graphics.circle("line", 0, 0, 18)
    -- Claws (facing right)
    love.graphics.push()
    love.graphics.rotate(0)
    local style = cosmetics.claw or "normal"
    if style == "crystal" then
        love.graphics.setColor(0.4, 0.7, 1)
        love.graphics.polygon("fill", 22, -14, 31, -8, 22, 0, 14, -8)
        love.graphics.polygon("fill", 22, 14, 31, 8, 22, 0, 14, 8)
        love.graphics.setColor(0.15, 0.3, 0.6)
        love.graphics.polygon("line", 22, -14, 31, -8, 22, 0, 14, -8)
        love.graphics.polygon("line", 22, 14, 31, 8, 22, 0, 14, 8)
    elseif style == "cursed" then
        love.graphics.setColor(0.55, 0.15, 0.8)
        love.graphics.circle("fill", 22, -8, 9)
        love.graphics.circle("fill", 22, 8, 9)
        love.graphics.setColor(0.2, 0.05, 0.3)
        love.graphics.circle("line", 22, -8, 9)
        love.graphics.circle("line", 22, 8, 9)
        love.graphics.setColor(0.8, 0.4, 1, 0.6)
        love.graphics.line(28, -8, 34, -10 + math.sin(t * 3) * 3)
        love.graphics.line(28, 8, 34, 10 + math.cos(t * 3) * 3)
    elseif style == "molten" then
        local pulse = 0.8 + math.sin(t * 5) * 0.2
        love.graphics.setColor(1, 0.4 * pulse, 0.1)
        love.graphics.circle("fill", 22, -8, 9)
        love.graphics.circle("fill", 22, 8, 9)
        love.graphics.setColor(1, 0.9, 0.3, 0.6)
        love.graphics.circle("fill", 22, -8, 5)
        love.graphics.circle("fill", 22, 8, 5)
    elseif style == "spiked" then
        love.graphics.setColor(body)
        love.graphics.circle("fill", 22, -8, 9)
        love.graphics.circle("fill", 22, 8, 9)
        love.graphics.setColor(deep)
        love.graphics.circle("line", 22, -8, 9)
        love.graphics.circle("line", 22, 8, 9)
        love.graphics.setColor(0.8, 0.8, 0.85)
        love.graphics.polygon("fill", 22, -15, 28, -9, 20, -9)
        love.graphics.polygon("fill", 22, 15, 28, 9, 20, 9)
        love.graphics.polygon("fill", 30, -7, 36, -9, 30, -11)
        love.graphics.polygon("fill", 30, 7, 36, 9, 30, 11)
    elseif style == "small" then
        love.graphics.setColor(body)
        love.graphics.circle("fill", 22, -6, 6)
        love.graphics.circle("fill", 22, 6, 6)
        love.graphics.setColor(deep)
        love.graphics.circle("line", 22, -6, 6)
        love.graphics.circle("line", 22, 6, 6)
    elseif style == "wide" then
        love.graphics.setColor(body)
        love.graphics.ellipse("fill", 23, -9, 11, 8)
        love.graphics.ellipse("fill", 23, 9, 11, 8)
        love.graphics.setColor(deep)
        love.graphics.ellipse("line", 23, -9, 11, 8)
        love.graphics.ellipse("line", 23, 9, 11, 8)
    elseif style == "leaf" then
        love.graphics.setColor(0.25, 0.7, 0.25)
        love.graphics.polygon("fill", 18, -12, 30, -8, 32, -4, 16, -4)
        love.graphics.polygon("fill", 18, 12, 30, 8, 32, 4, 16, 4)
        love.graphics.setColor(0.1, 0.35, 0.1)
        love.graphics.polygon("line", 18, -12, 30, -8, 32, -4, 16, -4)
        love.graphics.polygon("line", 18, 12, 30, 8, 32, 4, 16, 4)
    elseif style == "skeletal" then
        love.graphics.setColor(0.9, 0.9, 0.85)
        love.graphics.polygon("fill", 18, -10, 32, -8, 32, -4, 18, -4)
        love.graphics.polygon("fill", 18, 10, 32, 8, 32, 4, 18, 4)
        love.graphics.setColor(0.25, 0.2, 0.15)
        love.graphics.polygon("line", 18, -10, 32, -8, 32, -4, 18, -4)
        love.graphics.polygon("line", 18, 10, 32, 8, 32, 4, 18, 4)
    elseif style == "chain" then
        love.graphics.setColor(body)
        love.graphics.circle("fill", 22, -8, 9)
        love.graphics.circle("fill", 22, 8, 9)
        love.graphics.setColor(deep)
        love.graphics.circle("line", 22, -8, 9)
        love.graphics.circle("line", 22, 8, 9)
        love.graphics.setColor(0.45, 0.45, 0.5)
        for i = 1, 3 do
            love.graphics.circle("line", 22 + i * 5, -8, 2)
            love.graphics.circle("line", 22 + i * 5, 8, 2)
        end
    elseif style == "obsidian" then
        love.graphics.setColor(0.05, 0.05, 0.08)
        love.graphics.polygon("fill", 18, -12, 32, 0, 18, -2)
        love.graphics.polygon("fill", 18, 12, 32, 0, 18, 2)
        love.graphics.setColor(0.25, 0.15, 0.35)
        love.graphics.polygon("line", 18, -12, 32, 0, 18, -2)
        love.graphics.polygon("line", 18, 12, 32, 0, 18, 2)
    elseif style == "saw" then
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.circle("fill", 24, -8, 9)
        love.graphics.circle("fill", 24, 8, 9)
        love.graphics.setColor(0.3, 0.3, 0.35)
        for i = 0, 7 do
            local a = (i / 8) * math.pi * 2
            love.graphics.polygon("fill",
                24 + math.cos(a) * 9, -8 + math.sin(a) * 9,
                24 + math.cos(a) * 13, -8 + math.sin(a) * 13,
                24 + math.cos(a + 0.4) * 9, -8 + math.sin(a + 0.4) * 9)
            love.graphics.polygon("fill",
                24 + math.cos(a) * 9, 8 + math.sin(a) * 9,
                24 + math.cos(a) * 13, 8 + math.sin(a) * 13,
                24 + math.cos(a + 0.4) * 9, 8 + math.sin(a + 0.4) * 9)
        end
    elseif style == "prism" then
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
            love.graphics.polygon("fill", 18, cy - 6, 32, cy, 18, cy + 6)
        end
    elseif style == "churgly_jaws" then
        local chomp = 0.45 + 0.55 * math.abs(math.sin(t * 3))
        for sy = -1, 1, 2 do
            local cy = 8 * sy
            love.graphics.setColor(0.25, 0.1, 0.35)
            love.graphics.polygon("fill",
                14, cy,
                22, cy - 9,
                36, cy - 6 * chomp,
                40, cy,
                36, cy + 6 * chomp,
                22, cy + 9)
            love.graphics.setColor(0.05, 0.02, 0.08)
            love.graphics.polygon("fill",
                20, cy - 4,
                34, cy - 5 * chomp,
                36, cy,
                34, cy + 5 * chomp,
                20, cy + 4)
            love.graphics.setColor(0.94, 0.92, 0.84)
            for k = 0, 4 do
                local tx = 22 + k * 3.6
                local ty = cy - 5 * chomp
                love.graphics.polygon("fill", tx, ty, tx - 1, ty + 3, tx + 1, ty + 3)
                local ty2 = cy + 5 * chomp
                love.graphics.polygon("fill", tx, ty2, tx - 1, ty2 - 3, tx + 1, ty2 - 3)
            end
            love.graphics.setColor(0.15, 0.05, 0.25)
            for k = 0, 3 do
                love.graphics.circle("fill", 24 + k * 4, cy - 7, 1.2)
            end
            love.graphics.setColor(1, 0.85, 0.2)
            love.graphics.circle("fill", 24, cy - 2, 1.8)
            love.graphics.setColor(0, 0, 0)
            love.graphics.ellipse("fill", 24, cy - 2, 0.5, 1.3)
            if math.sin(t * 5 + sy) > 0.6 then
                love.graphics.setColor(0.7, 0.1, 0.2)
                love.graphics.line(28, cy, 36, cy + sy * 1.5)
            end
        end
    elseif style == "churgly" then
        -- Lovecraftian pulsing eldritch claws for the preview
        local pulse = 0.75 + math.sin(t * 2.3) * 0.25
        for sign = -1, 1, 2 do
            local cx, cy = 22, 8 * sign
            love.graphics.setColor(0.35, 0.1, 0.45, 0.5)
            love.graphics.circle("fill", cx, cy, 14)
            love.graphics.setColor(0.25 * pulse, 0.08, 0.55 * pulse)
            love.graphics.circle("fill", cx, cy, 10)
            love.graphics.setColor(0.4, 0.15, 0.6)
            love.graphics.circle("fill", cx, cy, 7)
            love.graphics.setColor(0.05, 0, 0.1)
            love.graphics.circle("fill", cx, cy, 4.5)
            -- Ring of eyes
            for i = 0, 5 do
                local a = t * 1.5 + sign * i * math.pi / 3
                local ex = cx + math.cos(a) * 5.5
                local ey = cy + math.sin(a) * 5.5
                local blink = (math.sin(t * 2.5 + i + sign) > 0.6) and 0.2 or 1
                love.graphics.setColor(1, 0.85, 0.2, blink)
                love.graphics.circle("fill", ex, ey, 1.2)
                love.graphics.setColor(0, 0, 0, blink)
                love.graphics.circle("fill", ex, ey, 0.6)
            end
            -- Big central eye
            local bigBlink = math.abs(math.sin(t * 0.7 + sign))
            love.graphics.setColor(1, 0.85, 0.2)
            love.graphics.circle("fill", cx, cy, 3)
            love.graphics.setColor(0.9, 0.4, 0.05)
            love.graphics.circle("fill", cx, cy, 2.2)
            love.graphics.setColor(0, 0, 0)
            love.graphics.ellipse("fill", cx, cy, 2.2, 2.2 * bigBlink)
            -- Bony spikes
            love.graphics.setColor(0.9, 0.85, 0.7)
            for i = -1, 1 do
                local ang = (math.pi * 0.25) * i
                local sx = cx + math.cos(ang) * 10
                local sy = cy + math.sin(ang) * 10 + sign * 2
                local ex = cx + math.cos(ang) * 16
                local ey = cy + math.sin(ang) * 16 + sign * 2
                love.graphics.polygon("fill", sx, sy - 1, sx, sy + 1, ex, ey)
            end
            -- Writhing tendrils
            love.graphics.setLineWidth(1.8)
            for i = 0, 3 do
                local a = t * 2.4 + i * 0.8 + sign
                local x1 = cx + math.cos(a) * 12
                local y1 = cy + math.sin(a) * 12
                local mx = x1 + math.cos(a + math.sin(t * 4 + i)) * 5
                local my = y1 + math.sin(a + math.cos(t * 4 + i)) * 5
                love.graphics.setColor(0.6, 0.25, 0.9, 0.75)
                love.graphics.line(x1, y1, mx, my)
                love.graphics.setColor(1, 0.85, 0.2, 0.5)
                love.graphics.circle("fill", mx, my, 0.8)
            end
            -- Golden sigil arcs
            love.graphics.setColor(0.95, 0.78, 0.15, 0.8)
            love.graphics.setLineWidth(1.2)
            for i = 0, 7 do
                local a1 = (i / 8) * math.pi * 2 + t * 0.7 * sign
                local a2 = a1 + 0.4
                love.graphics.arc("line", "open", cx, cy, 12, a1, a2)
            end
            love.graphics.setLineWidth(1)
        end
    else
        love.graphics.setColor(body)
        love.graphics.circle("fill", 22, -8, 9)
        love.graphics.circle("fill", 22, 8, 9)
        love.graphics.setColor(deep)
        love.graphics.circle("line", 22, -8, 9)
        love.graphics.circle("line", 22, 8, 9)
    end
    -- Gun skin (same local frame as claws, x=18 marks the muzzle base)
    local gun = cosmetics.gun or "pistol"
    local baseX = 18
    love.graphics.setLineWidth(1)  -- reset before gun draw
    if gun == "pistol" then
        love.graphics.setColor(0.22, 0.22, 0.26); love.graphics.rectangle("fill", baseX, -3, 22, 6)
        love.graphics.setColor(0.4, 0.4, 0.48); love.graphics.rectangle("line", baseX, -3, 22, 6)
        love.graphics.setColor(0.12, 0.12, 0.15); love.graphics.rectangle("fill", baseX + 1, -4, 20, 2)
        love.graphics.setColor(0.5, 0.5, 0.55)
        for i = 0, 5 do love.graphics.line(baseX + 14 + i * 0.9, -4, baseX + 13 + i * 0.9, -2) end
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", baseX + 2, -5, 2, 1)
        love.graphics.rectangle("fill", baseX + 18, -5, 2, 1)
        love.graphics.setColor(1, 1, 1); love.graphics.rectangle("fill", baseX + 18.5, -4.5, 0.8, 0.5)
        love.graphics.setColor(0.25, 0.25, 0.3); love.graphics.setLineWidth(1.5)
        love.graphics.arc("line", "open", baseX + 7, 4, 2.5, 0, math.pi); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.05, 0.05, 0.08); love.graphics.rectangle("fill", baseX + 10, -2, 4, 1)
        love.graphics.setColor(0.08, 0.08, 0.1)
        for i = 0, 2 do love.graphics.rectangle("fill", baseX + 1, -1 + i * 1.3, 5, 0.5) end
        love.graphics.setColor(0, 0, 0); love.graphics.circle("fill", baseX + 22, 0, 1.2)
    elseif gun == "compact" then
        love.graphics.setColor(0.22, 0.22, 0.26); love.graphics.rectangle("fill", baseX, -2.5, 14, 5)
        love.graphics.setColor(0.4, 0.4, 0.48); love.graphics.rectangle("line", baseX, -2.5, 14, 5)
        love.graphics.setColor(0.12, 0.12, 0.15); love.graphics.rectangle("fill", baseX + 1, -3.3, 12, 1.6)
        love.graphics.setColor(0.5, 0.5, 0.55)
        for i = 0, 3 do love.graphics.line(baseX + 9 + i * 0.8, -3.3, baseX + 8 + i * 0.8, -1.7) end
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", baseX + 1.5, -4.1, 1.6, 0.9)
        love.graphics.rectangle("fill", baseX + 11, -4.1, 1.2, 0.9)
        love.graphics.setColor(1, 1, 1); love.graphics.rectangle("fill", baseX + 11.4, -3.7, 0.5, 0.4)
        love.graphics.setColor(0.25, 0.25, 0.3); love.graphics.setLineWidth(1.3)
        love.graphics.arc("line", "open", baseX + 5, 3, 1.8, 0, math.pi); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.05, 0.05, 0.08); love.graphics.rectangle("fill", baseX + 6, -1.8, 2.5, 0.9)
        love.graphics.setColor(0.08, 0.08, 0.1)
        for i = 0, 1 do love.graphics.rectangle("fill", baseX + 1, -0.8 + i * 1.2, 3.5, 0.45) end
        love.graphics.setColor(0, 0, 0); love.graphics.circle("fill", baseX + 14, 0, 1)
    elseif gun == "magnum" then
        love.graphics.setColor(0.22, 0.2, 0.25); love.graphics.rectangle("fill", baseX + 8, -2.5, 18, 5)
        love.graphics.setColor(0.35, 0.3, 0.38); love.graphics.circle("fill", baseX + 5, 0, 6)
        love.graphics.setColor(0.15, 0.12, 0.18); love.graphics.circle("line", baseX + 5, 0, 6)
        for i = 0, 5 do
            local a = (i / 6) * math.pi * 2
            love.graphics.circle("fill", baseX + 5 + math.cos(a) * 3, math.sin(a) * 3, 1)
        end
    elseif gun == "rifle" then
        love.graphics.setColor(0.25, 0.2, 0.12); love.graphics.rectangle("fill", baseX - 2, -2, 6, 4)
        love.graphics.setColor(0.2, 0.2, 0.25); love.graphics.rectangle("fill", baseX + 4, -2, 32, 4)
        love.graphics.setColor(0.4, 0.4, 0.5); love.graphics.rectangle("line", baseX + 4, -2, 32, 4)
        love.graphics.setColor(0.35, 0.35, 0.45); love.graphics.rectangle("fill", baseX + 14, -4, 6, 2)
        love.graphics.rectangle("fill", baseX + 33, -5, 2, 2)
    elseif gun == "shotgun" then
        love.graphics.setColor(0.15, 0.1, 0.06); love.graphics.rectangle("fill", baseX - 2, -4, 6, 8)
        love.graphics.setColor(0.2, 0.2, 0.25); love.graphics.rectangle("fill", baseX + 4, -4, 20, 3); love.graphics.rectangle("fill", baseX + 4, 1, 20, 3)
        love.graphics.setColor(0.35, 0.35, 0.42); love.graphics.rectangle("fill", baseX + 12, -4, 5, 8)
    elseif gun == "smg" then
        love.graphics.setColor(0.2, 0.2, 0.24); love.graphics.setLineWidth(1.5)
        love.graphics.line(baseX - 6, -2, baseX - 2, -2); love.graphics.line(baseX - 6, 2, baseX - 2, 2)
        love.graphics.line(baseX - 6, -2, baseX - 6, 2); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.18, 0.18, 0.22); love.graphics.rectangle("fill", baseX, -3, 22, 6)
        love.graphics.setColor(0.35, 0.35, 0.4); love.graphics.rectangle("line", baseX, -3, 22, 6)
        love.graphics.setColor(0.1, 0.1, 0.12)
        for i = 0, 3 do love.graphics.rectangle("fill", baseX + 2 + i * 1.5, -2, 0.8, 4) end
        love.graphics.setColor(0.45, 0.45, 0.5); love.graphics.rectangle("fill", baseX + 12, -5, 5, 2)
        love.graphics.setColor(0.25, 0.25, 0.3); love.graphics.rectangle("line", baseX + 12, -5, 5, 2)
        love.graphics.setColor(0.15, 0.15, 0.18); love.graphics.rectangle("fill", baseX + 5, -7, 5, 3)
        love.graphics.setColor(0.4, 0.4, 0.5); love.graphics.rectangle("line", baseX + 5, -7, 5, 3)
        love.graphics.setColor(1, 0.2, 0.2, 0.9 + math.sin(t * 4) * 0.1)
        love.graphics.circle("fill", baseX + 7.5, -5.5, 0.9)
        love.graphics.setColor(0.12, 0.12, 0.15); love.graphics.rectangle("fill", baseX + 4, 3, 6, 10)
        love.graphics.setColor(0.35, 0.35, 0.4); love.graphics.rectangle("line", baseX + 4, 3, 6, 10)
        love.graphics.setColor(0.85, 0.65, 0.2)
        for i = 0, 3 do love.graphics.line(baseX + 5, 5 + i * 2, baseX + 9, 5 + i * 2) end
        love.graphics.setColor(0.25, 0.25, 0.3); love.graphics.setLineWidth(1.5)
        love.graphics.arc("line", "open", baseX + 14, 4, 2.5, 0, math.pi); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.1, 0.1, 0.12); love.graphics.rectangle("fill", baseX + 22, -2.5, 10, 5)
        love.graphics.setColor(0.3, 0.3, 0.35)
        for i = 0, 3 do love.graphics.line(baseX + 24 + i * 2, -2.5, baseX + 24 + i * 2, 2.5) end
        love.graphics.setColor(0, 0, 0); love.graphics.circle("fill", baseX + 32, 0, 1.2)
    elseif gun == "blaster" then
        love.graphics.setColor(0.15, 0.2, 0.35); love.graphics.rectangle("fill", baseX, -3, 20, 6, 1, 1)
        love.graphics.setColor(0.3, 0.5, 0.9); love.graphics.rectangle("fill", baseX + 2, -2, 14, 4)
        love.graphics.setColor(0.3, 1, 1, 0.9); love.graphics.circle("fill", baseX + 22, 0, 3 + math.sin(t * 5) * 0.5)
        love.graphics.setColor(1, 1, 1); love.graphics.circle("fill", baseX + 22, 0, 1.4)
    elseif gun == "cannon" then
        love.graphics.setColor(0.3, 0.3, 0.35); love.graphics.rectangle("fill", baseX - 4, -3, 5, 6)
        love.graphics.setColor(0.6, 0.6, 0.65); love.graphics.rectangle("line", baseX - 4, -3, 5, 6)
        love.graphics.setColor(0.08, 0.08, 0.1)
        for i = 0, 2 do love.graphics.line(baseX - 3 + i * 1.5, -3, baseX - 3 + i * 1.5, 3) end
        love.graphics.setColor(0.18, 0.18, 0.22); love.graphics.rectangle("fill", baseX + 1, -6, 20, 12)
        love.graphics.setColor(0.5, 0.5, 0.55); love.graphics.rectangle("line", baseX + 1, -6, 20, 12)
        love.graphics.setColor(0.3, 0.3, 0.35); love.graphics.rectangle("fill", baseX + 3, -8, 16, 2)
        love.graphics.setColor(0.15, 0.15, 0.18)
        for i = 0, 6 do love.graphics.line(baseX + 4 + i * 2, -8, baseX + 4 + i * 2, -6) end
        love.graphics.setColor(0.25, 0.25, 0.3); love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", baseX + 11, -8, 4, -math.pi, 0); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.08, 0.08, 0.1)
        for i = 0, 3 do
            love.graphics.rectangle("fill", baseX + 5 + i * 3, -5, 2, 0.8)
            love.graphics.rectangle("fill", baseX + 5 + i * 3, 4.2, 2, 0.8)
        end
        love.graphics.setColor(0.85, 0.65, 0.2)
        love.graphics.circle("fill", baseX + 3, -4, 0.9); love.graphics.circle("fill", baseX + 3, 4, 0.9)
        love.graphics.circle("fill", baseX + 19, -4, 0.9); love.graphics.circle("fill", baseX + 19, 4, 0.9)
        love.graphics.setColor(0.22, 0.22, 0.26)
        love.graphics.polygon("fill", baseX + 21, -7, baseX + 30, -5, baseX + 30, 5, baseX + 21, 7)
        love.graphics.setColor(0.5, 0.5, 0.55)
        love.graphics.polygon("line", baseX + 21, -7, baseX + 30, -5, baseX + 30, 5, baseX + 21, 7)
        love.graphics.setColor(0.02, 0.02, 0.03); love.graphics.circle("fill", baseX + 27, 0, 3)
        love.graphics.setColor(0.15, 0.15, 0.2)
        for i = 0, 2 do
            local a = (i / 3) * math.pi * 2
            love.graphics.line(baseX + 27, 0, baseX + 27 + math.cos(a) * 3, math.sin(a) * 3)
        end
        love.graphics.setColor(1, 0.2, 0.2, 0.5 + math.sin(t * 6) * 0.3); love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 30, 0, baseX + 46, math.sin(t * 3) * 2)
        love.graphics.setColor(1, 0.3, 0.3, 0.9)
        love.graphics.circle("fill", baseX + 46, math.sin(t * 3) * 2, 1.2)
    elseif gun == "crossbow" then
        love.graphics.setColor(0.35, 0.22, 0.1); love.graphics.setLineWidth(3)
        love.graphics.line(baseX + 2, -10, baseX + 2, 10)
        love.graphics.arc("line", "open", baseX, 0, 12, -math.pi * 0.4, math.pi * 0.4)
        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(0.85, 0.85, 0.9); love.graphics.line(baseX - 6, -8, baseX + 2, 0); love.graphics.line(baseX - 6, 8, baseX + 2, 0)
        love.graphics.setColor(0.7, 0.6, 0.3); love.graphics.rectangle("fill", baseX, -0.8, 24, 1.6)
        love.graphics.setColor(0.85, 0.85, 0.9); love.graphics.polygon("fill", baseX + 24, -2, baseX + 28, 0, baseX + 24, 2)
        love.graphics.setLineWidth(1)
    elseif gun == "musket" then
        love.graphics.setColor(0.3, 0.18, 0.05); love.graphics.rectangle("fill", baseX - 4, -3, 12, 6)
        love.graphics.setColor(0.4, 0.4, 0.4); love.graphics.rectangle("fill", baseX + 8, -1.5, 26, 3)
        love.graphics.setColor(0.85, 0.65, 0.25); love.graphics.rectangle("fill", baseX + 6, -2.5, 3, 5); love.graphics.rectangle("fill", baseX + 33, -2, 2, 4)
    elseif gun == "void_spear" then
        love.graphics.setColor(0.32, 0.32, 0.34)
        love.graphics.setLineWidth(2)
        love.graphics.line(baseX - 2, 0, baseX + 60, 0)
        love.graphics.polygon("fill", baseX + 58, -2, baseX + 70, 0, baseX + 58, 2)
        love.graphics.setLineWidth(1)
    elseif gun == "telekinesis" then
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
    elseif gun == "reality_bend" then
        local tearA = math.max(0, math.sin(t * 0.9)) * 0.55
        love.graphics.setColor(0.75, 0.3, 1, tearA)
        love.graphics.line(baseX + 4, -8, baseX + 7, -4, baseX + 5, 0, baseX + 8, 3, baseX + 6, 8)
        for i = 1, 16 do
            local a = t * 1.4 + i * 0.52
            local rr = 7 + ((i * 3) % 14) + math.sin(t * 2 + i) * 2
            local px = baseX + 8 + math.cos(a) * rr
            local py = math.sin(a) * rr * 0.9
            local alpha = 0.4 + 0.5 * math.sin(t * 4 + i * 0.7)
            love.graphics.setColor(0.75, 0.4, 1, alpha)
            love.graphics.circle("fill", px, py, 1)
        end
        local glyphs = {"*", "+", "x", "#"}
        for i = 0, 3 do
            local a = t * 0.8 + i * (math.pi / 2)
            local rr = 16 + math.sin(t + i) * 3
            local gx = baseX + 8 + math.cos(a) * rr
            local gy = math.sin(a) * rr * 0.9
            love.graphics.setColor(0.9, 0.55, 1, 0.85)
            love.graphics.print(glyphs[i + 1], gx - 3, gy - 5)
        end
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
    elseif gun == "dark_magic" then
        love.graphics.setColor(0.18, 0.10, 0.20)
        love.graphics.rectangle("fill", baseX - 3, -3, 10, 6)
        for gx = baseX - 2, baseX + 5, 2 do
            love.graphics.setColor(0.55, 0.25, 0.75)
            love.graphics.line(gx, -3, gx, 3)
        end
        love.graphics.setColor(0.05, 0.03, 0.08)
        love.graphics.setLineWidth(4)
        love.graphics.line(baseX + 6, 0, baseX + 26, 0)
        love.graphics.setColor(0.25, 0.1, 0.35)
        love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 6, -1.2, baseX + 26, -1.2)
        love.graphics.line(baseX + 6, 1.2, baseX + 26, 1.2)
        love.graphics.setColor(0.08, 0.04, 0.12)
        love.graphics.setLineWidth(3)
        love.graphics.line(baseX + 26, 0, baseX + 30, -8)
        love.graphics.line(baseX + 26, 0, baseX + 30,  8)
        love.graphics.line(baseX + 26, 0, baseX + 34, -5)
        love.graphics.line(baseX + 26, 0, baseX + 34,  5)
        love.graphics.setLineWidth(1)
        local pulse = 0.75 + math.sin(t * 3) * 0.25
        love.graphics.setColor(0.55, 0.15, 0.85, 0.35)
        love.graphics.circle("fill", baseX + 30, 0, 10 * pulse)
        love.graphics.setColor(0.75, 0.35, 1, 0.85)
        love.graphics.circle("fill", baseX + 30, 0, 6)
        love.graphics.setColor(1, 0.85, 0.3, 0.95)
        love.graphics.circle("fill", baseX + 30, 0, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", baseX + 30, 0, 1.2)
        for i = 0, 2 do
            local a = t * 2 + i * (math.pi * 2 / 3)
            love.graphics.setColor(0.85, 0.45, 1, 0.8)
            love.graphics.print(({"*","+","x"})[i + 1], baseX + 30 + math.cos(a) * 14, math.sin(a) * 9 - 4)
        end
        for i = 1, 3 do
            local a = t * 4 + i
            love.graphics.setColor(0.55, 0.2, 0.8, 0.5)
            love.graphics.circle("fill", baseX + 10 + math.sin(a) * 2, math.cos(a) * 4, 1.2)
        end
    elseif gun == "nailgun" then
        love.graphics.setColor(0.85, 0.75, 0.12)
        love.graphics.polygon("fill", baseX, -4, baseX + 22, -4, baseX + 24, -2, baseX + 24, 3, baseX, 3)
        love.graphics.setColor(0.45, 0.4, 0.05)
        love.graphics.polygon("line", baseX, -4, baseX + 22, -4, baseX + 24, -2, baseX + 24, 3, baseX, 3)
        love.graphics.setColor(0.08, 0.08, 0.1); love.graphics.rectangle("fill", baseX + 2, -3, 6, 5)
        love.graphics.setColor(0.15, 0.13, 0.08); love.graphics.circle("fill", baseX + 11, -1, 3.5)
        love.graphics.setColor(0.85, 0.7, 0.15); love.graphics.circle("line", baseX + 11, -1, 3.5)
        local rot = t * 4
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.line(baseX + 11, -1, baseX + 11 + math.cos(rot) * 3, -1 + math.sin(rot) * 3)
        love.graphics.setColor(0.15, 0.15, 0.18); love.graphics.setLineWidth(2.5)
        love.graphics.line(baseX - 2, 3, baseX - 5, 6, baseX - 2, 9, baseX - 6, 11)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.2, 0.18, 0.12); love.graphics.rectangle("fill", baseX + 4, 3, 12, 10)
        love.graphics.setColor(0.6, 0.55, 0.1); love.graphics.rectangle("line", baseX + 4, 3, 12, 10)
        love.graphics.setColor(0.88, 0.88, 0.92)
        for i = 0, 5 do
            local nx = baseX + 5.5 + i * 1.7
            love.graphics.line(nx, 5, nx, 12); love.graphics.circle("fill", nx, 4.5, 0.7)
        end
        love.graphics.setColor(0.35, 0.35, 0.4); love.graphics.rectangle("fill", baseX + 24, -3, 5, 5)
        love.graphics.setColor(0.08, 0.08, 0.1); love.graphics.rectangle("fill", baseX + 27, -2, 2, 3)
    elseif gun == "handcannon" then
        love.graphics.setColor(0.22, 0.14, 0.08); love.graphics.rectangle("fill", baseX - 4, -3, 8, 7)
        love.graphics.setColor(0.35, 0.22, 0.12)
        for i = 0, 3 do love.graphics.line(baseX - 3 + i * 2, -3, baseX - 3 + i * 2, 4) end
        love.graphics.setColor(0.18, 0.15, 0.2); love.graphics.rectangle("fill", baseX + 2, -5, 22, 10)
        love.graphics.setColor(0.35, 0.3, 0.4); love.graphics.rectangle("line", baseX + 2, -5, 22, 10)
        love.graphics.setColor(0.95, 0.75, 0.15); love.graphics.rectangle("fill", baseX + 4, -1, 18, 2)
        love.graphics.setColor(0.25, 0.22, 0.28); love.graphics.circle("fill", baseX + 8, 0, 6)
        love.graphics.setColor(0.5, 0.45, 0.55); love.graphics.circle("line", baseX + 8, 0, 6)
        for i = 0, 5 do
            local a = (i / 6) * math.pi * 2 + t * 0.3
            love.graphics.setColor(0.05, 0.05, 0.08)
            love.graphics.circle("fill", baseX + 8 + math.cos(a) * 3.5, math.sin(a) * 3.5, 1.3)
        end
        love.graphics.setColor(0.3, 0.26, 0.32)
        love.graphics.polygon("fill", baseX + 24, -6, baseX + 32, -7, baseX + 34, 0, baseX + 32, 7, baseX + 24, 6)
        love.graphics.setColor(0.85, 0.8, 0.85)
        for i = 0, 3 do
            local tx = baseX + 26 + i * 2
            love.graphics.polygon("fill", tx, -5, tx + 1, -3, tx - 1, -3)
            love.graphics.polygon("fill", tx, 5, tx + 1, 3, tx - 1, 3)
        end
        local ep = 0.7 + math.sin(t * 5) * 0.3
        love.graphics.setColor(1, 0.3, 0.1, ep); love.graphics.circle("fill", baseX + 28, -4, 1.3)
        love.graphics.setColor(1, 1, 0.8); love.graphics.circle("fill", baseX + 28, -4, 0.5)
        love.graphics.setColor(0, 0, 0); love.graphics.circle("fill", baseX + 32, 0, 2.5)
    elseif gun == "sniper" then
        love.graphics.setColor(0.32, 0.2, 0.1)
        love.graphics.polygon("fill", baseX - 8, -3, baseX + 6, -3, baseX + 6, 3, baseX - 8, 4, baseX - 6, 1)
        love.graphics.setColor(0.45, 0.28, 0.12)
        love.graphics.polygon("line", baseX - 8, -3, baseX + 6, -3, baseX + 6, 3, baseX - 8, 4, baseX - 6, 1)
        love.graphics.setColor(0.12, 0.1, 0.14); love.graphics.rectangle("fill", baseX + 6, -3, 12, 5)
        love.graphics.setColor(0.85, 0.65, 0.15); love.graphics.rectangle("fill", baseX + 10, -6, 3, 4)
        love.graphics.circle("fill", baseX + 11.5, -7, 1.8)
        love.graphics.setColor(0.18, 0.18, 0.22); love.graphics.rectangle("fill", baseX + 18, -1.2, 38, 2.4)
        love.graphics.setColor(0.35, 0.35, 0.4); love.graphics.rectangle("fill", baseX + 54, -2.5, 4, 5)
        love.graphics.setColor(0.1, 0.1, 0.12)
        for i = 0, 2 do love.graphics.rectangle("fill", baseX + 55, -2 + i * 1.5, 2, 0.6) end
        love.graphics.setColor(0.15, 0.15, 0.18)
        love.graphics.rectangle("fill", baseX + 14, -6, 4, 3); love.graphics.rectangle("fill", baseX + 26, -6, 4, 3)
        love.graphics.setColor(0.22, 0.22, 0.26); love.graphics.rectangle("fill", baseX + 13, -9, 18, 4)
        love.graphics.setColor(0.4, 0.4, 0.48); love.graphics.rectangle("line", baseX + 13, -9, 18, 4)
        love.graphics.setColor(0.05, 0.6, 0.9, 0.9)
        love.graphics.circle("fill", baseX + 14, -7, 2); love.graphics.circle("fill", baseX + 30, -7, 2.5)
        love.graphics.setColor(0.4, 0.95, 1); love.graphics.circle("fill", baseX + 30, -7, 1.5)
        love.graphics.setColor(1, 0.2, 0.2, 0.9)
        love.graphics.line(baseX + 28, -7, baseX + 32, -7); love.graphics.line(baseX + 30, -9, baseX + 30, -5)
        love.graphics.circle("line", baseX + 30, -7, 1)
        love.graphics.setColor(0.2, 0.2, 0.25); love.graphics.setLineWidth(1.5)
        love.graphics.line(baseX + 34, 1, baseX + 30, 8); love.graphics.line(baseX + 34, 1, baseX + 38, 8)
        love.graphics.setLineWidth(1)
    elseif gun == "glauncher" then
        love.graphics.setColor(0.2, 0.2, 0.22); love.graphics.setLineWidth(2)
        love.graphics.line(baseX - 6, -2, baseX - 2, -2); love.graphics.line(baseX - 6, 2, baseX - 2, 2)
        love.graphics.line(baseX - 6, -2, baseX - 6, 2); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.15, 0.18, 0.12); love.graphics.rectangle("fill", baseX - 2, -3, 6, 6)
        love.graphics.setColor(0.22, 0.2, 0.24); love.graphics.circle("fill", baseX + 5, 0, 9)
        love.graphics.setColor(0.4, 0.4, 0.45); love.graphics.setLineWidth(2)
        love.graphics.circle("line", baseX + 5, 0, 9); love.graphics.setLineWidth(1)
        local rot = t * 1.2
        for i = 0, 5 do
            local a = rot + (i / 6) * math.pi * 2
            local cx = baseX + 5 + math.cos(a) * 5.5
            local cy = math.sin(a) * 5.5
            love.graphics.setColor(0.15, 0.35, 0.12); love.graphics.circle("fill", cx, cy, 2)
            love.graphics.setColor(0.85, 0.65, 0.2); love.graphics.circle("line", cx, cy, 2)
            love.graphics.setColor(0.9, 0.8, 0.2); love.graphics.circle("fill", cx, cy, 0.6)
        end
        love.graphics.setColor(0.1, 0.1, 0.12); love.graphics.circle("fill", baseX + 5, 0, 1.5)
        love.graphics.setColor(0.18, 0.22, 0.14); love.graphics.rectangle("fill", baseX + 14, -4, 14, 8)
        love.graphics.setColor(0.35, 0.4, 0.22); love.graphics.rectangle("line", baseX + 14, -4, 14, 8)
        love.graphics.setColor(0.12, 0.12, 0.14); love.graphics.circle("fill", baseX + 28, 0, 4.5)
        love.graphics.setColor(0, 0, 0); love.graphics.circle("fill", baseX + 28, 0, 3)
    elseif gun == "plasma" then
        love.graphics.setColor(0.08, 0.1, 0.18); love.graphics.rectangle("fill", baseX - 5, -4, 6, 8)
        love.graphics.setColor(0.1, 0.14, 0.26); love.graphics.rectangle("fill", baseX + 1, -7, 30, 14)
        love.graphics.setColor(0.25, 0.45, 0.85); love.graphics.rectangle("line", baseX + 1, -7, 30, 14)
        love.graphics.setColor(0, 0, 0.05); love.graphics.rectangle("fill", baseX + 4, -5, 12, 10)
        for i = 1, 12 do
            local a = t * 3 + i * 0.6
            local r = 4 * math.abs(math.sin(t * 2 + i))
            local cx = baseX + 10 + math.cos(a) * r; local cy = math.sin(a) * r * 0.6
            love.graphics.setColor(0.3, 0.75, 1, 0.85); love.graphics.circle("fill", cx, cy, 0.8)
            love.graphics.setColor(0.95, 1, 1, 0.9); love.graphics.circle("fill", cx, cy, 0.35)
        end
        love.graphics.setColor(0.6, 0.85, 1, 0.15); love.graphics.rectangle("fill", baseX + 4, -5, 12, 10)
        for i = 0, 3 do
            local rx = baseX + 18 + i * 3
            love.graphics.setColor(0.5, 0.3, 0.1); love.graphics.ellipse("line", rx, 0, 1.5, 6)
            love.graphics.setColor(0.85, 0.55, 0.15); love.graphics.ellipse("line", rx, 0, 1.5, 5)
        end
        love.graphics.setColor(0.1, 0.15, 0.25)
        love.graphics.polygon("fill", baseX + 31, -5, baseX + 36, -3, baseX + 36, 3, baseX + 31, 5)
        local glow = 0.7 + math.sin(t * 8) * 0.3
        love.graphics.setColor(0.3, 0.6, 1, 0.5 * glow); love.graphics.circle("fill", baseX + 36, 0, 7 * glow)
        love.graphics.setColor(0.6, 0.9, 1, 0.9); love.graphics.circle("fill", baseX + 36, 0, 3.5)
        love.graphics.setColor(1, 1, 1); love.graphics.circle("fill", baseX + 36, 0, 1.5)
    elseif gun == "lightning_rod" then
        love.graphics.setColor(0.18, 0.14, 0.22); love.graphics.rectangle("fill", baseX - 4, -3, 8, 6)
        love.graphics.setColor(0.55, 0.3, 0.8); love.graphics.rectangle("line", baseX - 4, -3, 8, 6)
        love.graphics.setColor(0.35, 0.35, 0.45); love.graphics.setLineWidth(3)
        love.graphics.line(baseX + 4, 0, baseX + 48, 0)
        love.graphics.setColor(0.65, 0.65, 0.75); love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 4, -1.2, baseX + 48, -1.2)
        for i = 0, 3 do
            local cx = baseX + 10 + i * 8
            love.graphics.setColor(0.5, 0.3, 0.1); love.graphics.ellipse("fill", cx, 0, 2.5, 4)
            love.graphics.setColor(0.85, 0.55, 0.15); love.graphics.ellipse("line", cx, 0, 2.5, 4)
            local g = 0.5 + math.abs(math.sin(t * 7 + i * 1.3)) * 0.5
            love.graphics.setColor(0.6, 0.85, 1, 0.5 * g); love.graphics.ellipse("line", cx, 0, 3.5 * g, 5.5 * g)
        end
        love.graphics.setColor(0.85, 0.88, 0.95)
        love.graphics.polygon("fill", baseX + 48, -1, baseX + 58, 0, baseX + 48, 1)
        love.graphics.setColor(0.6, 0.62, 0.7)
        love.graphics.line(baseX + 46, 0, baseX + 52, -7); love.graphics.line(baseX + 46, 0, baseX + 52, 7)
        love.graphics.line(baseX + 50, -5, baseX + 55, -10); love.graphics.line(baseX + 50, 5, baseX + 55, 10)
        local pulse = 0.5 + math.sin(t * 10) * 0.5
        for r = 16, 4, -3 do
            love.graphics.setColor(0.5, 0.85, 1, 0.12 * pulse * (1 - r / 16))
            love.graphics.circle("fill", baseX + 56, 0, r * pulse)
        end
        love.graphics.setColor(1, 1, 1); love.graphics.setLineWidth(1)
    elseif gun == "chainsword" then
        love.graphics.setColor(0.3, 0.18, 0.08); love.graphics.rectangle("fill", baseX - 5, -3, 11, 6)
        love.graphics.setColor(0.5, 0.3, 0.15)
        for i = 0, 4 do love.graphics.line(baseX - 4 + i * 2, -3, baseX - 4 + i * 2, 3) end
        love.graphics.setColor(0.12, 0.12, 0.14); love.graphics.rectangle("fill", baseX + 6, -6, 10, 12)
        love.graphics.setColor(0.45, 0.45, 0.5); love.graphics.rectangle("line", baseX + 6, -6, 10, 12)
        love.graphics.setColor(0.18, 0.18, 0.2); love.graphics.circle("fill", baseX + 11, -3, 2.5)
        love.graphics.setColor(0.8, 0.8, 0.85); love.graphics.circle("line", baseX + 11, -3, 2.5)
        local ang = math.sin(t * 6) * math.pi * 0.4
        love.graphics.setColor(1, 0.3, 0.2)
        love.graphics.line(baseX + 11, -3, baseX + 11 + math.cos(ang - math.pi/2) * 2, -3 + math.sin(ang - math.pi/2) * 2)
        love.graphics.setColor(0.3, 0.3, 0.32); love.graphics.rectangle("fill", baseX + 8, -9, 2, 3)
        love.graphics.setColor(0.6, 0.6, 0.65, 0.7)
        love.graphics.circle("fill", baseX + 9, -11 - math.sin(t * 3) * 1, 1.8)
        love.graphics.setColor(0.85, 0.65, 0.2); love.graphics.rectangle("fill", baseX + 16, -6, 2, 12)
        love.graphics.setColor(0.6, 0.6, 0.65); love.graphics.rectangle("fill", baseX + 18, -4, 34, 8)
        love.graphics.setColor(0.85, 0.85, 0.9); love.graphics.line(baseX + 18, 0, baseX + 52, 0)
        love.graphics.setColor(0.3, 0.3, 0.35); love.graphics.rectangle("line", baseX + 18, -4, 34, 8)
        local off = (t * 80) % 5
        love.graphics.setColor(0.92, 0.92, 0.95)
        for i = 0, 7 do
            local x = baseX + 19 + i * 5 - off
            love.graphics.polygon("fill", x, -4, x + 2.5, -7, x + 5, -4)
            love.graphics.polygon("fill", x + 2.5, 4, x, 7, x + 5, 7)
        end
        love.graphics.setColor(0.75, 0.75, 0.8)
        love.graphics.polygon("fill", baseX + 52, -4, baseX + 58, 0, baseX + 52, 4)
    elseif gun == "quantum" then
        local phase1 = math.sin(t * 7) * 4
        local phase2 = math.cos(t * 9) * 4
        for r = 14, 6, -2 do
            love.graphics.setColor(0.6, 0.3, 1, 0.08 * (1 - r / 14))
            love.graphics.circle("fill", baseX + 12, 0, r)
        end
        love.graphics.setColor(0.5, 0.2, 1, 0.5); love.graphics.rectangle("fill", baseX + 1, -3 + phase1, 24, 6, 1, 1)
        love.graphics.setColor(0.7, 0.4, 1, 0.7); love.graphics.rectangle("line", baseX + 1, -3 + phase1, 24, 6, 1, 1)
        love.graphics.setColor(0.3, 0.8, 1, 0.5); love.graphics.rectangle("fill", baseX + 1, -3 + phase2, 24, 6, 1, 1)
        love.graphics.setColor(0.4, 0.95, 1, 0.7); love.graphics.rectangle("line", baseX + 1, -3 + phase2, 24, 6, 1, 1)
        love.graphics.setColor(0.15, 0.1, 0.22); love.graphics.rectangle("fill", baseX, -3, 26, 6, 1, 1)
        love.graphics.setColor(0.75, 0.55, 1); love.graphics.rectangle("line", baseX, -3, 26, 6, 1, 1)
        love.graphics.setColor(0.05, 0.05, 0.1); love.graphics.rectangle("fill", baseX + 8, -2, 6, 4)
        love.graphics.setColor(0.6, 0.9, 1, 0.9)
        love.graphics.circle("fill", baseX + 11 + math.sin(t * 18) * 1.5, math.cos(t * 14) * 1, 1)
        local pulse = 0.7 + math.sin(t * 15) * 0.3
        love.graphics.setColor(0.95, 0.95, 1); love.graphics.circle("fill", baseX + 27, 0, 1.8)
        love.graphics.setColor(0.6, 0.3, 1, 0.4); love.graphics.circle("fill", baseX + 27, 0, 5 * pulse)
    elseif gun == "flamethrower" then
        love.graphics.setColor(0.45, 0.15, 0.1); love.graphics.rectangle("fill", baseX - 8, -5, 5, 11)
        love.graphics.setColor(0.6, 0.2, 0.15); love.graphics.rectangle("line", baseX - 8, -5, 5, 11)
        love.graphics.setColor(0.15, 0.15, 0.18); love.graphics.setLineWidth(2)
        love.graphics.line(baseX - 3, 0, baseX, 0); love.graphics.setLineWidth(1)
        love.graphics.setColor(0.22, 0.18, 0.18); love.graphics.rectangle("fill", baseX, -3, 18, 6)
        love.graphics.setColor(0.5, 0.3, 0.2); love.graphics.rectangle("line", baseX, -3, 18, 6)
        love.graphics.setColor(0.9, 0.5, 0.1, 0.9)
        love.graphics.circle("fill", baseX + 22, 0, 2 + math.sin(t * 10) * 0.5)
        love.graphics.setColor(1, 0.85, 0.3); love.graphics.circle("fill", baseX + 22, 0, 1)
        for i = 1, 18 do
            local f = ((t * 3 + i * 0.17) % 1)
            local x = baseX + 24 + f * 38
            local y = math.sin(t * 6 + i) * (3 + f * 4)
            local r = (1 - f) * 4
            local col = (f < 0.5) and {1, 0.9, 0.3} or {1, 0.45, 0.1}
            love.graphics.setColor(col[1], col[2], col[3], (1 - f) * 0.85)
            love.graphics.circle("fill", x, y, r)
        end
    elseif gun == "sawedoff" then
        love.graphics.setColor(0.22, 0.14, 0.08); love.graphics.rectangle("fill", baseX - 4, -3, 10, 6)
        love.graphics.setColor(0.6, 0.55, 0.35)
        for i = 0, 3 do love.graphics.rectangle("fill", baseX - 3 + i * 2.5, -3, 1, 6) end
        love.graphics.setColor(0.18, 0.18, 0.22)
        love.graphics.rectangle("fill", baseX + 6, -4, 16, 3); love.graphics.rectangle("fill", baseX + 6, 1, 16, 3)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", baseX + 6, -4, 16, 3); love.graphics.rectangle("line", baseX + 6, 1, 16, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", baseX + 22, -2.5, 1.2); love.graphics.circle("fill", baseX + 22, 2.5, 1.2)
        love.graphics.setColor(0.35, 0.28, 0.15)
        love.graphics.polygon("fill", baseX + 4, -4, baseX + 7, -7, baseX + 7, -4)
    elseif gun == "gatling" then
        love.graphics.setColor(0.85, 0.65, 0.2); love.graphics.rectangle("fill", baseX - 4, 3, 16, 8)
        love.graphics.setColor(0.55, 0.4, 0.1); love.graphics.rectangle("line", baseX - 4, 3, 16, 8)
        for i = 0, 4 do love.graphics.rectangle("fill", baseX - 3 + i * 3, 4, 1, 2) end
        love.graphics.setColor(0.8, 0.7, 0.2); love.graphics.line(baseX + 4, 3, baseX + 10, 0)
        love.graphics.setColor(0.25, 0.22, 0.28); love.graphics.rectangle("fill", baseX, -5, 14, 10)
        love.graphics.setColor(0.5, 0.45, 0.55); love.graphics.rectangle("line", baseX, -5, 14, 10)
        local rot = t * 20
        love.graphics.setColor(0.15, 0.15, 0.18); love.graphics.rectangle("fill", baseX + 14, -5, 22, 10)
        for i = 0, 5 do
            local a = rot + (i / 6) * math.pi * 2
            local cy = math.sin(a) * 3
            love.graphics.setColor(0.35, 0.35, 0.4); love.graphics.rectangle("fill", baseX + 14, cy - 0.8, 22, 1.6)
        end
        love.graphics.setColor(0.5, 0.5, 0.55); love.graphics.circle("line", baseX + 36, 0, 4.5)
        love.graphics.setColor(0.08, 0.08, 0.1); love.graphics.circle("fill", baseX + 36, 0, 3.5)
        if math.sin(t * 90) > 0.2 then
            love.graphics.setColor(1, 0.8, 0.3, 0.9); love.graphics.circle("fill", baseX + 38, 0, 3 + math.sin(t * 140) * 1)
            love.graphics.setColor(1, 1, 0.8); love.graphics.circle("fill", baseX + 38, 0, 1.5)
        end
    elseif gun == "icegun" then
        love.graphics.setColor(0.6, 0.8, 0.95); love.graphics.rectangle("fill", baseX, -4, 22, 8)
        love.graphics.setColor(0.25, 0.4, 0.55); love.graphics.rectangle("line", baseX, -4, 22, 8)
        love.graphics.setColor(0.85, 0.95, 1, 0.85); love.graphics.rectangle("fill", baseX + 3, -3, 8, 6)
        love.graphics.setColor(0.4, 0.6, 0.85); love.graphics.rectangle("line", baseX + 3, -3, 8, 6)
        love.graphics.setColor(0.9, 0.98, 1, 0.9)
        love.graphics.polygon("fill", baseX + 14, -5, baseX + 16, -7, baseX + 18, -5)
        love.graphics.polygon("fill", baseX + 13, 4, baseX + 15, 6, baseX + 17, 4)
        love.graphics.setColor(0.75, 0.9, 1, 0.95)
        love.graphics.polygon("fill", baseX + 22, -5, baseX + 30, -4, baseX + 32, 0, baseX + 30, 4, baseX + 22, 5)
        love.graphics.setColor(0.4, 0.6, 0.85)
        love.graphics.polygon("line", baseX + 22, -5, baseX + 30, -4, baseX + 32, 0, baseX + 30, 4, baseX + 22, 5)
        love.graphics.setColor(0.95, 1, 1, 0.85)
        love.graphics.circle("fill", baseX + 28, 0, 1.5 + math.sin(t * 4) * 0.5)
        for i = 1, 6 do
            local f = ((t * 0.7 + i / 6) % 1)
            local sx = baseX + 30 + f * 18
            local sy = math.sin(t + i) * 5
            local a = (1 - f) * 0.9
            love.graphics.setColor(1, 1, 1, a); love.graphics.circle("fill", sx, sy, 1 - f * 0.5)
            love.graphics.line(sx - 1.5, sy, sx + 1.5, sy); love.graphics.line(sx, sy - 1.5, sx, sy + 1.5)
        end
    elseif gun == "scythe" then
        -- Proper reaper scythe: long snath, grip wraps, metal collar, big
        -- curved crescent blade (outer body + inner hook), steel spine
        -- highlight, glowing green inner edge, rune, drip wisps.
        love.graphics.setColor(0.35, 0.22, 0.1); love.graphics.setLineWidth(4)
        love.graphics.line(baseX - 4, 0, baseX + 50, 0)
        love.graphics.setColor(0.55, 0.36, 0.16); love.graphics.setLineWidth(1.5)
        love.graphics.line(baseX - 4, -1.2, baseX + 50, -1.2)
        love.graphics.setLineWidth(1)
        for _, wx in ipairs({baseX + 4, baseX + 22, baseX + 40}) do
            love.graphics.setColor(0.1, 0.06, 0.04)
            love.graphics.rectangle("fill", wx, -2.5, 3, 5)
            love.graphics.setColor(0.85, 0.65, 0.2)
            love.graphics.line(wx + 1, -2.5, wx + 1, 2.5)
        end
        love.graphics.setColor(0.3, 0.3, 0.36); love.graphics.rectangle("fill", baseX + 46, -3.5, 7, 7)
        love.graphics.setColor(0.6, 0.6, 0.7); love.graphics.rectangle("line", baseX + 46, -3.5, 7, 7)
        love.graphics.setColor(0.1, 0.08, 0.12); love.graphics.line(baseX + 49, -3.5, baseX + 49, 3.5)
        -- Blade outer body
        love.graphics.setColor(0.14, 0.1, 0.18)
        love.graphics.polygon("fill",
            baseX + 53, -2, baseX + 56, -12, baseX + 64, -22,
            baseX + 78, -28, baseX + 94, -26, baseX + 100, -18,
            baseX + 96, -10, baseX + 82, -12, baseX + 66, -10, baseX + 54, -4)
        -- Inner hook
        love.graphics.polygon("fill",
            baseX + 54, -4, baseX + 66, -10, baseX + 82, -12, baseX + 96, -10,
            baseX + 96, -6, baseX + 82, -6, baseX + 66, -4, baseX + 54, 0)
        love.graphics.setColor(0.04, 0.02, 0.08); love.graphics.setLineWidth(1.5)
        love.graphics.line(
            baseX + 53, -2, baseX + 56, -12, baseX + 64, -22,
            baseX + 78, -28, baseX + 94, -26, baseX + 100, -18,
            baseX + 96, -10, baseX + 96, -6)
        love.graphics.line(baseX + 96, -6, baseX + 82, -6, baseX + 66, -4, baseX + 54, 0)
        love.graphics.setColor(0.42, 0.38, 0.48); love.graphics.setLineWidth(1.5)
        love.graphics.line(baseX + 58, -14, baseX + 68, -22, baseX + 82, -26, baseX + 94, -24, baseX + 98, -18)
        -- Glowing green cutting edge
        local glow = 0.8 + math.sin(t * 5) * 0.2
        love.graphics.setColor(0.3, 1, 0.5, glow); love.graphics.setLineWidth(2.2)
        love.graphics.line(baseX + 54, -4, baseX + 66, -8, baseX + 80, -10, baseX + 94, -8, baseX + 96, -6)
        love.graphics.setColor(1, 1, 0.9, glow * 0.8); love.graphics.setLineWidth(1)
        love.graphics.line(baseX + 54, -4, baseX + 66, -8, baseX + 80, -10, baseX + 94, -8)
        -- Rune
        love.graphics.setColor(0.3, 1, 0.5, 0.5 + math.sin(t * 3) * 0.3)
        love.graphics.circle("line", baseX + 78, -18, 2.2)
        love.graphics.line(baseX + 76, -18, baseX + 80, -18)
        love.graphics.line(baseX + 78, -20, baseX + 78, -16)
        -- Drip wisps
        for i = 0, 4 do
            local f = ((t * 0.8 + i * 0.2) % 1)
            love.graphics.setColor(0.3, 1, 0.4, (1 - f) * 0.7)
            love.graphics.circle("fill", baseX + 98 + f * 3, -18 + f * 18, 2 - f * 1.3)
        end
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(0.2, 0.2, 0.25); love.graphics.rectangle("fill", baseX, -3, 22, 6)
    end
    love.graphics.setLineWidth(1)  -- reset so hat/eye outlines keep their widths
    love.graphics.pop()

    -- Eyes
    local eye = cosmetics.eye or "normal"
    if eye == "cute" then
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", -6, -5, 4)
        love.graphics.circle("fill", 6, -5, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", -4, -7, 1.5)
        love.graphics.circle("fill", 8, -7, 1.5)
    elseif eye == "cyber" then
        love.graphics.setColor(0, 0.9, 1, 0.7)
        love.graphics.rectangle("fill", -9, -7, 6, 4)
        love.graphics.rectangle("fill", 3, -7, 6, 4)
        love.graphics.setColor(0, 1, 1)
        love.graphics.rectangle("line", -9, -7, 6, 4)
        love.graphics.rectangle("line", 3, -7, 6, 4)
    elseif eye == "angry" then
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.polygon("fill", -9, -6, -3, -3, -3, -7)
        love.graphics.polygon("fill", 9, -6, 3, -3, 3, -7)
    elseif eye == "third" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", -5, -5, 3)
        love.graphics.circle("fill", 5, -5, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", -5, -5, 1.5)
        love.graphics.circle("fill", 5, -5, 1.5)
        love.graphics.setColor(0.8, 0.3, 1)
        love.graphics.circle("fill", 0, -11, 3.5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", 0, -11, 1.8)
    elseif eye == "many" then
        for i = -3, 3 do
            love.graphics.setColor(1, 0.9 - math.abs(i) * 0.15, 0.2)
            love.graphics.circle("fill", i * 3.5, -6 + math.sin(t * 2 + i), 2)
            love.graphics.setColor(0, 0, 0)
            love.graphics.circle("fill", i * 3.5, -6 + math.sin(t * 2 + i), 1)
        end
    elseif eye == "happy" then
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", -5, -5, 3, math.pi, math.pi * 2)
        love.graphics.arc("line", "open",  5, -5, 3, math.pi, math.pi * 2)
        love.graphics.setLineWidth(1)
    elseif eye == "sleepy" then
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(1.8)
        love.graphics.line(-8, -5, -2, -5)
        love.graphics.line( 2, -5,  8, -5)
        love.graphics.setLineWidth(1)
    elseif eye == "heart" then
        love.graphics.setColor(1, 0.3, 0.4)
        for _, px in ipairs({-5, 5}) do
            love.graphics.circle("fill", px - 1.3, -6, 1.6)
            love.graphics.circle("fill", px + 1.3, -6, 1.6)
            love.graphics.polygon("fill", px - 2.8, -5.2, px + 2.8, -5.2, px, -2.5)
        end
    elseif eye == "spiral" then
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
    elseif eye == "frozen" then
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.circle("fill", -5, -5, 3)
        love.graphics.circle("fill",  5, -5, 3)
        love.graphics.setColor(1, 1, 1)
        for _, px in ipairs({-5, 5}) do
            love.graphics.line(px - 3, -5, px + 3, -5)
            love.graphics.line(px, -8, px, -2)
        end
    elseif eye == "fire" then
        for _, px in ipairs({-5, 5}) do
            love.graphics.setColor(1, 0.5, 0.1, 0.8)
            love.graphics.circle("fill", px, -5 + math.sin(t * 4 + px) * 0.4, 4)
            love.graphics.setColor(1, 0.9, 0.2)
            love.graphics.circle("fill", px, -5, 2)
        end
    elseif eye == "skull" then
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", -5, -5, 3.5)
        love.graphics.circle("fill",  5, -5, 3.5)
    elseif eye == "crystal" then
        love.graphics.setColor(0.6, 0.9, 1)
        love.graphics.polygon("fill", -7, -5, -5, -8, -3, -5, -5, -2)
        love.graphics.polygon("fill",  3, -5,  5, -8,  7, -5,  5, -2)
        love.graphics.setColor(0.3, 0.5, 0.8)
        love.graphics.polygon("line", -7, -5, -5, -8, -3, -5, -5, -2)
        love.graphics.polygon("line",  3, -5,  5, -8,  7, -5,  5, -2)
    elseif eye == "rune" then
        -- Match in-game: glowing purple sigil, darker on light bodies.
        local lum = Cosmetics.luminance(Cosmetics.bodyColor(cosmetics))
        local baseR, baseG, baseB
        if lum > 0.55 then
            baseR, baseG, baseB = 0.22, 0.05, 0.40
        else
            baseR, baseG, baseB = 0.75, 0.35, 1.0
        end
        local pulse = 0.75 + 0.25 * math.sin(t * 2)
        for _, px in ipairs({-5, 5}) do
            love.graphics.setColor(baseR * 0.45, baseG * 0.45, baseB * 0.45, 0.85)
            love.graphics.circle("fill", px, -5, 3.2)
            love.graphics.setColor(baseR, baseG, baseB, 0.9 * pulse)
            love.graphics.circle("fill", px, -5, 1.9)
            love.graphics.setColor(baseR * 1.2, baseG * 0.9, baseB * 1.2, pulse)
            love.graphics.line(px, -7.5, px, -2.5)
            love.graphics.line(px - 2, -5, px + 2, -5)
            love.graphics.line(px - 2, -7, px - 1, -6)
            love.graphics.line(px + 1, -6, px + 2, -7)
            love.graphics.line(px - 2, -3, px - 1, -4)
            love.graphics.line(px + 1, -4, px + 2, -3)
        end
        love.graphics.setColor(baseR, baseG, baseB, 0.55 * pulse)
        love.graphics.line(-5, -9, -3, -10, 3, -10, 5, -9)
        love.graphics.line(-3, -10, -2, -11)
        love.graphics.line( 3, -10,  2, -11)
    elseif eye == "vacant" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", -5, -5, 3)
        love.graphics.circle("fill",  5, -5, 3)
    elseif eye == "churgly_eyes" then
        -- Churgly'nth face: black upside-down triangle (apex grazes head
        -- outline at y=18, height = 2.2/3 of the 36-px head). Eyes vertically
        -- centered inside the mouth (y=5), pulled in toward the sides (x=±11).
        love.graphics.setColor(0, 0, 0)
        love.graphics.polygon("fill", -11, -7, 11, -7, 0, 17)
        for _, px in ipairs({-11, 11}) do
            love.graphics.setColor(1, 0.8, 0.15)
            love.graphics.circle("fill", px, 5, 3)
            love.graphics.setColor(0, 0, 0)
            love.graphics.ellipse("fill", px, 5, 0.6, 2.2)
        end
    elseif eye == "slugcrab" then
        -- Match in-game: invert to white on dark bodies so the eyes stay visible.
        local lum = Cosmetics.luminance(Cosmetics.bodyColor(cosmetics))
        if lum < 0.4 then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0, 0, 0)
        end
        love.graphics.ellipse("fill", -5, -5, 2.8, 6)
        love.graphics.ellipse("fill",  5, -5, 2.8, 6)
    elseif eye == "void_gaze" then
        -- Forehead eye
        local fglow = 0.5 + 0.3 * math.sin(t * 2)
        love.graphics.setColor(0.5, 0.1, 0.8, 0.7)
        love.graphics.circle("fill", 0, -12, 4 + fglow)
        love.graphics.setColor(1, 0.4, 0.7)
        love.graphics.circle("fill", 0, -12, 3)
        love.graphics.setColor(0.95, 0.85, 0.2)
        love.graphics.circle("fill", 0, -12, 2)
        love.graphics.setColor(0, 0, 0)
        love.graphics.ellipse("fill", 0, -12, 0.7, 2)
        -- Dotted tiny eyes
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
        -- Main void eyes
        for side = -1, 1, 2 do
            local ex, ey = side * 6, -5
            love.graphics.setColor(0.5, 0.1, 0.8, 0.45)
            love.graphics.circle("fill", ex, ey, 6 + math.sin(t * 2 + side) * 0.6)
            love.graphics.setColor(0.35, 0.05, 0.55)
            love.graphics.circle("fill", ex, ey, 4.5)
            for r = 4, 2, -0.5 do
                local a = 0.3 + 0.3 * math.sin(t * 3 + r + side)
                love.graphics.setColor(1, 0.4 + (4 - r) * 0.15, 0.7, a)
                love.graphics.circle("line", ex, ey, r)
            end
            love.graphics.setColor(1, 0.85, 0.2)
            love.graphics.circle("fill", ex, ey, 2.2)
            love.graphics.setColor(0, 0, 0)
            love.graphics.circle("fill", ex, ey, 1.5)
            love.graphics.setColor(0.2, 0.0, 0.3, 0.9)
            love.graphics.circle("fill", ex, ey, 0.9)
            -- Tear
            love.graphics.setColor(0.7, 0.3, 1, 0.55)
            local tearY = ey + 6 + math.sin(t * 3 + side) * 2
            love.graphics.circle("fill", ex + side * 0.8, tearY, 1)
            -- Spark
            local sa = t * 3 + side
            love.graphics.setColor(1, 0.9, 0.3, 0.8)
            love.graphics.circle("fill", ex + math.cos(sa) * 5, ey + math.sin(sa) * 5, 0.8)
        end
        love.graphics.setColor(0.7, 0.3, 1, 0.5)
        love.graphics.arc("line", "open", -6, -8, 3, math.pi * 1.1, math.pi * 1.9)
        love.graphics.arc("line", "open", 6, -8, 3, math.pi * 1.1, math.pi * 1.9)
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", -5, -5, 3)
        love.graphics.circle("fill", 5, -5, 3)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", -5, -5, 1.5)
        love.graphics.circle("fill", 5, -5, 1.5)
    end

    -- Hat
    local hat = cosmetics.hat or "none"
    if hat == "tophat" then
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", -10, -24, 20, 10)
        love.graphics.rectangle("fill", -13, -15, 26, 3)
        love.graphics.setColor(0.9, 0.1, 0.1)
        love.graphics.rectangle("fill", -10, -16, 20, 2)
    elseif hat == "crown" then
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.polygon("fill", -11, -12, -11, -20, -7, -15, -3, -22, 0, -15, 3, -22, 7, -15, 11, -20, 11, -12)
    elseif hat == "hood" then
        love.graphics.setColor(0.1, 0.8, 0.3)
        love.graphics.arc("fill", "pie", 0, -4, 22, math.pi, 2 * math.pi)
    elseif hat == "tinfoil" then
        love.graphics.setColor(0.8, 0.8, 0.85)
        love.graphics.polygon("fill", -11, -12, 0, -24, 11, -12)
    elseif hat == "halo" then
        love.graphics.setColor(1, 1, 0.5, 0.8 + math.sin(t * 3) * 0.2)
        love.graphics.ellipse("line", 0, -22, 14, 4)
    elseif hat == "horns" then
        love.graphics.setColor(0.25, 0.1, 0.3)
        love.graphics.polygon("fill", -12, -12, -8, -22, -4, -12)
        love.graphics.polygon("fill", 12, -12, 8, -22, 4, -12)
    elseif hat == "beanie" then
        love.graphics.setColor(0.9, 0.25, 0.35)
        love.graphics.arc("fill", "pie", 0, -12, 14, math.pi, 2 * math.pi)
        love.graphics.setColor(0.5, 0.1, 0.15)
        love.graphics.circle("fill", 0, -24, 3)
        love.graphics.rectangle("fill", -15, -12, 30, 2)
    elseif hat == "cap" then
        love.graphics.setColor(0.2, 0.5, 0.9)
        love.graphics.arc("fill", "pie", 0, -10, 13, math.pi, 2 * math.pi)
        love.graphics.rectangle("fill", -17, -10, 10, 3)
    elseif hat == "antlers" then
        love.graphics.setColor(0.6, 0.4, 0.2)
        love.graphics.setLineWidth(3)
        for s = -1, 1, 2 do
            love.graphics.line(s * 5, -14, s * 10, -24)
            love.graphics.line(s * 10, -24, s * 6, -30)
            love.graphics.line(s * 10, -24, s * 16, -26)
            love.graphics.line(s * 16, -26, s * 14, -32)
        end
        love.graphics.setLineWidth(1)
    elseif hat == "wizard" then
        love.graphics.setColor(0.2, 0.1, 0.4)
        love.graphics.polygon("fill", -14, -10, 14, -10, 0, -32)
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.circle("fill", -6, -18, 1.2)
        love.graphics.circle("fill", 5, -22, 1.2)
        love.graphics.circle("fill", 0, -26, 1.2)
    elseif hat == "cowboy" then
        love.graphics.setColor(0.4, 0.25, 0.08)
        love.graphics.ellipse("fill", 0, -10, 18, 4)
        love.graphics.arc("fill", "pie", 0, -13, 10, math.pi, 2 * math.pi)
    elseif hat == "helmet" then
        love.graphics.setColor(0.35, 0.35, 0.4)
        love.graphics.arc("fill", "pie", 0, -11, 13, math.pi, 2 * math.pi)
        love.graphics.setColor(0.8, 0.8, 0.85)
        love.graphics.rectangle("fill", -12, -14, 24, 2)
    elseif hat == "pirate" then
        love.graphics.setColor(0.05, 0.05, 0.08)
        love.graphics.polygon("fill", -16, -11, 16, -11, 14, -20, -14, -20)
        love.graphics.setColor(0.85, 0.85, 0.85)
        love.graphics.polygon("fill", 0, -18, -3, -15, 0, -12, 3, -15)
        love.graphics.polygon("fill", -2, -17, 2, -13, -2, -13, 2, -17)
    elseif hat == "fin" then
        love.graphics.setColor(0.3, 0.4, 0.55)
        love.graphics.polygon("fill", -6, -12, 10, -12, 0, -28)
        love.graphics.setColor(0.15, 0.2, 0.3)
        love.graphics.polygon("line", -6, -12, 10, -12, 0, -28)
    elseif hat == "cap_spike" then
        love.graphics.setColor(0.25, 0.25, 0.3)
        love.graphics.arc("fill", "pie", 0, -11, 13, math.pi, 2 * math.pi)
        love.graphics.setColor(0.7, 0.7, 0.75)
        for i = -2, 2 do
            love.graphics.polygon("fill", i * 4, -14, i * 4 - 2, -20, i * 4 + 2, -20)
        end
    elseif hat == "slugears" then
        local sway = math.sin(t * 1.8) * 2
        local b = Cosmetics.bodyColor(cosmetics)
        love.graphics.setColor(b[1], b[2], b[3])
        love.graphics.ellipse("fill", -8, -17 + sway * 0.3, 2.2, 11)
        love.graphics.ellipse("fill",  8, -17 - sway * 0.3, 2.2, 11)
    elseif hat == "deepcrown" then
        love.graphics.setColor(0.95, 0.8, 0.2)
        love.graphics.polygon("fill", -13, -12, -13, -22, -9, -16, -5, -24, -1, -16, 1, -16, 5, -24, 9, -16, 13, -22, 13, -12)
        love.graphics.setColor(0.35, 0.2, 0.55)
        love.graphics.polygon("line", -13, -12, -13, -22, -9, -16, -5, -24, -1, -16, 1, -16, 5, -24, 9, -16, 13, -22, 13, -12)
        for i = -1, 1, 2 do
            local ox = i * 14 + math.cos(t * 2 + i) * 3
            local oy = -26 + math.sin(t * 2 + i) * 2
            love.graphics.setColor(1, 0.85, 0.3, 0.9)
            love.graphics.circle("fill", ox, oy, 2.5)
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

function UI:drawCustomise(game)
    love.graphics.clear(0.08, 0.05, 0.12)
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 0.5, 0.85)
    love.graphics.printf("CLAUDE CUSTOMISATION", 0, 20, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("Click an unlocked item to equip. ESC to save & return.", 0, 95, 1280, "center")

    local t = love.timer.getTime()
    local cosmetics = Cosmetics.equipped(game.persist)

    -- Preview crab (big)
    love.graphics.setColor(0.15, 0.1, 0.2, 0.7)
    love.graphics.rectangle("fill", 60, 140, 280, 440, 12, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 60, 140, 280, 440, 12, 12)
    love.graphics.printf("PREVIEW", 60, 154, 280, "center")
    drawPreviewCrab(200, 330, 3.8, cosmetics, t)

    -- Dedicated gun strip (clear view of the weapon, unblocked by tabs/buttons).
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.8, 0.8, 0.85, 0.75)
    love.graphics.printf("WEAPON", 60, 458, 280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(0.08, 0.05, 0.15, 0.9)
    love.graphics.rectangle("fill", 80, 478, 240, 38, 6, 6)
    love.graphics.setColor(0.6, 0.4, 0.7, 0.7)
    love.graphics.rectangle("line", 80, 478, 240, 38, 6, 6)
    -- Draw the equipped gun at 1.6x, pointing right from left-inner
    drawGunAt(120, 497, 1.6, cosmetics.gun, t)
    -- Name of the currently equipped weapon
    local gunItem = Cosmetics.getItem("gun", cosmetics.gun)
    local gunLabel = (gunItem and (gunItem.secretName or gunItem.name)) or "—"
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(gunLabel, 80, 522, 240, "center")
    love.graphics.setFont(self.font)

    -- Stats summary
    local p = game.persist
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(string.format("Kills: %d", p.totalKills or 0), 80, 548, 240, "left")
    love.graphics.printf(string.format("Wins: %d", p.totalWins or 0), 80, 566, 240, "left")
    love.graphics.printf(string.format("Best Streak: %d", p.bestStreak or 0), 80, 584, 240, "left")

    -- Slot tabs
    game.customiseClicks = {}
    local tabX = 380
    for i, slot in ipairs(slotOrder) do
        local x = tabX + (i - 1) * 140
        local y = 140
        local selected = game.customiseSlot == slot
        love.graphics.setColor(selected and 0.55 or 0.2, selected and 0.3 or 0.15, selected and 0.75 or 0.25, 0.95)
        love.graphics.rectangle("fill", x, y, 125, 40, 8, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", x, y, 125, 40, 8, 8)
        love.graphics.printf(slotLabels[slot], x, y + 11, 125, "center")
        game.customiseClicks[#game.customiseClicks + 1] = {x = x, y = y, w = 125, h = 40, type = "tab", slot = slot}
    end

    -- Items grid — SCROLLABLE (pixel-based smooth scroll)
    local slot = game.customiseSlot or "body"
    local items = Cosmetics.items[slot] or {}
    local gridX, gridY = 380, 195
    local cellW, cellH, gap = 110, 110, 8
    local rowH = cellH + gap + 30
    local cols = 6
    local gridBottom = 640
    local gridH = gridBottom - gridY
    local mx, my = love.mouse.getPosition()

    local totalRows = math.ceil(#items / cols)
    local contentH = totalRows * rowH
    local maxScroll = math.max(0, contentH - gridH + 30)
    -- Target is what the scroll is heading toward; displayed scroll lerps toward it.
    game.customiseScrollTarget = math.max(0, math.min(maxScroll, game.customiseScrollTarget or 0))
    game.customiseScroll = math.max(0, math.min(maxScroll, game.customiseScroll or 0))
    local scroll = game.customiseScroll

    love.graphics.setScissor(gridX - 4, gridY - 4, (cellW + gap) * cols + 8, gridH + 8)
    for i, item in ipairs(items) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = gridX + col * (cellW + gap)
        local y = gridY + row * rowH - scroll
        if y + cellH + 30 >= gridY and y <= gridBottom then
            local unlocked = Cosmetics.isUnlocked(item, game.persist)
            local equipped = cosmetics[slot] == item.id
            local hover = mx >= x and mx <= x + cellW and my >= y and my <= y + cellH and my < gridBottom and my >= gridY
            if equipped then
                love.graphics.setColor(1, 0.5, 0.85, 0.9)
            elseif unlocked and hover then
                love.graphics.setColor(0.5, 0.25, 0.55, 0.9)
            elseif unlocked then
                love.graphics.setColor(0.2, 0.15, 0.3, 0.9)
            else
                love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
            end
            love.graphics.rectangle("fill", x, y, cellW, cellH, 8, 8)
            love.graphics.setColor(1, 1, 1, unlocked and 1 or 0.3)
            love.graphics.rectangle("line", x, y, cellW, cellH, 8, 8)

            local tmp = {}
            for k, v in pairs(cosmetics) do tmp[k] = v end
            tmp[slot] = item.id
            if unlocked then
                drawPreviewCrab(x + cellW / 2, y + cellH / 2 + 4, 1.7, tmp, t)
            else
                love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
                love.graphics.rectangle("fill", x + cellW / 2 - 12, y + cellH / 2 - 4, 24, 18, 3, 3)
                love.graphics.arc("line", "open", x + cellW / 2, y + cellH / 2 - 4, 10, math.pi, 2 * math.pi)
            end

            love.graphics.setColor(1, 1, 1, unlocked and 1 or 0.5)
            love.graphics.setFont(self.smallFont)
            local displayName = (unlocked and item.secretName) or item.name
            love.graphics.printf(displayName, x, y + cellH + 4, cellW, "center")
            -- Always show the unlock hint (except for the "Default" noise) so the
            -- player can tell how they earned each item. Red for locked, soft grey for unlocked.
            if item.hint and item.hint ~= "Default" then
                if unlocked then
                    love.graphics.setColor(0.75, 0.75, 0.85, 0.65)
                else
                    love.graphics.setColor(1, 0.6, 0.6, 0.85)
                end
                love.graphics.printf(item.hint, x - 6, y + cellH + 18, cellW + 12, "center")
            end
            love.graphics.setFont(self.font)

            -- Register the click rect CLIPPED to the visible grid area so partially
            -- visible cells are still clickable within their visible portion.
            local visTop = math.max(y, gridY)
            local visBot = math.min(y + cellH, gridBottom)
            if visBot > visTop + 4 then
                game.customiseClicks[#game.customiseClicks + 1] = {
                    x = x, y = visTop, w = cellW, h = visBot - visTop,
                    type = "item", slot = slot, id = item.id, unlocked = unlocked,
                }
            end
        end
    end
    love.graphics.setScissor()

    -- Scroll track + draggable thumb
    if maxScroll > 0 then
        local sbX = gridX + (cellW + gap) * cols + 4
        local sbW = 10
        love.graphics.setColor(0.25, 0.15, 0.35, 0.6)
        love.graphics.rectangle("fill", sbX, gridY, sbW, gridH, 5, 5)
        local thumbH = math.max(24, gridH * (gridH / contentH))
        local thumbY = gridY + (gridH - thumbH) * (scroll / maxScroll)
        local overThumb = mx >= sbX - 4 and mx <= sbX + sbW + 4 and my >= thumbY - 4 and my <= thumbY + thumbH + 4
        love.graphics.setColor(1, 0.5 + (overThumb and 0.2 or 0), 0.85, 1)
        love.graphics.rectangle("fill", sbX, thumbY, sbW, thumbH, 5, 5)
        game.customiseScrollbar = {
            trackX = sbX, trackY = gridY, trackW = sbW, trackH = gridH,
            thumbY = thumbY, thumbH = thumbH, maxScroll = maxScroll,
        }
    else
        game.customiseScrollbar = nil
    end

    -- Upright Head toggle — lives inside the preview column under the stats,
    -- well away from the tab row, item grid, back/reset buttons, and scroll track.
    local uprightOn = (game.persist.uprightHead or 0) == 1
    local utX, utY, utW, utH = 80, 608, 240, 38
    local utHover = mx >= utX and mx <= utX + utW and my >= utY and my <= utY + utH
    love.graphics.setColor(uprightOn and 0.4 or 0.2, uprightOn and 0.7 or 0.2, uprightOn and 0.35 or 0.25, utHover and 1 or 0.9)
    love.graphics.rectangle("fill", utX, utY, utW, utH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", utX, utY, utW, utH, 8, 8)
    love.graphics.setFont(self.smallFont)
    love.graphics.printf("UPRIGHT HEAD: " .. (uprightOn and "ON" or "OFF"), utX, utY + 12, utW, "center")
    love.graphics.setFont(self.font)
    game.customiseUprightBounds = {utX, utY, utW, utH}

    -- Reset to default
    local resetH = mx >= 320 and mx <= 520 and my >= 660 and my <= 700
    love.graphics.setColor(resetH and 1 or 0.5, resetH and 0.7 or 0.35, 0.2)
    love.graphics.rectangle("fill", 320, 660, 200, 40, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 320, 660, 200, 40, 8, 8)
    love.graphics.printf("RESET TO DEFAULT", 320, 670, 200, "center")
    game.customiseResetBounds = {320, 660, 200, 40}

    -- Back
    local backH = mx >= 560 and mx <= 760 and my >= 660 and my <= 700
    love.graphics.setColor(backH and 1 or 0.5, 0.4, 0.7)
    love.graphics.rectangle("fill", 560, 660, 200, 40, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 560, 660, 200, 40, 8, 8)
    love.graphics.printf("BACK", 560, 670, 200, "center")
    game.customiseBackBounds = {560, 660, 200, 40}
end

function UI:customiseClick(game, x, y)
    for _, c in ipairs(game.customiseClicks or {}) do
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            if c.type == "tab" then
                game.customiseSlot = c.slot
            elseif c.type == "item" and c.unlocked then
                Cosmetics.setEquipped(game.persist, c.slot, c.id)
                local Save = require("src.save")
                Save.save(game.persist)
                require("src.audio"):play("select")
            end
            return
        end
    end
    local b = game.customiseUprightBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game.persist.uprightHead = ((game.persist.uprightHead or 0) == 1) and 0 or 1
        local Save = require("src.save")
        Save.save(game.persist)
        require("src.audio"):play("select")
        return
    end
    b = game.customiseResetBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        local defaults = {body="orange", eye="normal", claw="normal", hat="none", trail="none"}
        for slot, id in pairs(defaults) do
            Cosmetics.setEquipped(game.persist, slot, id)
        end
        local Save = require("src.save")
        Save.save(game.persist)
        return
    end
    b = game.customiseBackBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        local Save = require("src.save")
        Save.save(game.persist)
        game.state = "menu"
    end
end

function UI:customClick(game, x, y)
    for _, c in ipairs(game.customClicks or {}) do
        if x >= c.x and x <= c.x + c.w and y >= c.y and y <= c.y + c.h then
            local row = c.row
            if c.reset then
                game:resetCustomKey(row.key)
                return
            end
            local v = game.customDraft[row.key] + c.dir * row.step
            if v < row.min then v = row.min end
            if v > row.max then v = row.max end
            if row.step < 1 then v = math.floor(v * 100 + 0.5) / 100 end
            game.customDraft[row.key] = v
            return
        end
    end
    local b = game.customStartBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game:startCustom()
        return
    end
    b = game.customResetAllBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game:resetCustomAll()
        return
    end
    b = game.customBackBounds
    if b and x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
        game.state = "menu"
        return
    end
end

function UI:drawWaveBanner(game)
    local t = game.bannerTime
    if t <= 0 then return end
    local a = math.min(1, t * 2)
    if t < 0.5 then a = t * 2 end
    love.graphics.setColor(0, 0, 0, 0.4 * a)
    love.graphics.rectangle("fill", 0, 280, 1280, 160)
    love.graphics.setFont(self.bigFont)
    love.graphics.setColor(1, 0.6, 0.2, a)

    local isBossWave = game.isBossWave
    local isTrueFinal = game.finalWave and game.finalWave > 0 and game.wave == game.finalWave
    local title
    if isTrueFinal then
        title = string.format("WAVE %d - FINAL BOSS", game.wave)
    elseif isBossWave then
        title = string.format("WAVE %d - BOSS WAVE", game.wave)
    else
        title = "WAVE " .. game.wave
    end
    love.graphics.printf(title, 0, 300, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, a)
    if isBossWave then
        love.graphics.printf("OPENCLAW - THE TYRANT LOBSTER", 0, 370, 1280, "center")
    else
        love.graphics.printf(game.waveMessage or "", 0, 370, 1280, "center")
    end
end

function UI:drawGameOver(game)
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)
    love.graphics.setFont(self.titleFont)
    local eldritch = game.player.eldritch.level
    local cthulhuKill = game.player.eldritch.cthulhu and game.player.eldritch.cthulhu.phase == "fire"
    if cthulhuKill then
        glitchPrint("CONSUMED", 0, 80, 1280, "center", 0.4)
    elseif eldritch >= 4 then
        glitchPrint("YOU FELL", 0, 80, 1280, "center", 0.2)
    else
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf("YOU FELL", 0, 80, 1280, "center")
    end
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("The Orange Clawde Crab has been defeated...", 0, 180, 1280, "center")
    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.printf(string.format("Final Score: %d", math.floor(game.player.score)), 0, 240, 1280, "center")
    love.graphics.printf(string.format("Reputation: %d", math.floor(game.player.reputation)), 0, 280, 1280, "center")
    love.graphics.printf(string.format("Reached Wave %d", game.wave), 0, 320, 1280, "center")

    love.graphics.setColor(0.9, 0.9, 1)
    love.graphics.printf("Cards collected:", 0, 380, 1280, "center")
    local text = ""
    for i, c in ipairs(game.player.cardsTaken) do
        text = text .. c.name
        if i < #game.player.cardsTaken then text = text .. ", " end
    end
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf(text, 80, 410, 1120, "center")

    if not game.isCustom then
        local p = game.persist or {}
        love.graphics.setColor(1, 0.9, 0.4, 0.8)
        love.graphics.printf(string.format("Global Reputation: %d   |   Win Streak: %d   |   Wins: %d (of %d runs)",
            math.floor(p.globalRep or 0), p.winStreak or 0, p.totalWins or 0, p.totalRuns or 0),
            0, 500, 1280, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
        love.graphics.printf("(Custom Mode — run does not affect your global stats)", 0, 500, 1280, "center")
    end
    self:_drawEndButtons(game, (game.endTime or 0) < 1.0)
end

function UI:drawVictory(game)
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)
    love.graphics.setFont(self.titleFont)
    local eld = game.player.eldritch.level
    if eld >= 6 then
        glitchPrint("V!CT[RY?", 0, 60, 1280, "center", 0.5)
    elseif eld >= 3 then
        glitchPrint("VICTORY!", 0, 60, 1280, "center", 0.18)
    else
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.printf("VICTORY!", 0, 60, 1280, "center")
    end
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("OpenClaw has fallen. The Orange Clawde Crab stands triumphant.", 0, 160, 1280, "center")

    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.printf(string.format("Final Score: %d", math.floor(game.player.score)), 0, 230, 1280, "center")
    love.graphics.printf(string.format("Reputation: %d", math.floor(game.player.reputation)), 0, 270, 1280, "center")

    love.graphics.setColor(0.9, 0.9, 1)
    love.graphics.printf("Cards mastered:", 0, 340, 1280, "center")
    local text = ""
    for i, c in ipairs(game.player.cardsTaken) do
        text = text .. c.name
        if i < #game.player.cardsTaken then text = text .. ", " end
    end
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf(text, 80, 370, 1120, "center")

    if not game.isCustom then
        local p = game.persist or {}
        love.graphics.setColor(0.5, 1, 0.6, 0.9)
        love.graphics.printf(string.format("Global Reputation: %d   |   Win Streak: %d   |   Wins: %d (of %d runs)",
            math.floor(p.globalRep or 0), p.winStreak or 0, p.totalWins or 0, p.totalRuns or 0),
            0, 500, 1280, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
        love.graphics.printf("(Custom Mode — run does not affect your global stats)", 0, 500, 1280, "center")
    end
    self:_drawEndButtons(game, (game.endTime or 0) < 1.0)
end

function UI:_drawEndButtons(game, armed)
    local buttons = {
        {label = "TRY AGAIN [ENTER]", action = "again",  color = {0.3, 0.8, 0.4}},
        {label = "MAIN MENU [M]",     action = "menu",   color = {0.6, 0.3, 0.9}},
        {label = "QUIT [Q]",          action = "quit",   color = {0.9, 0.2, 0.2}},
    }
    local mx, my = love.mouse.getPosition()
    local w, h = 260, 54
    local gap = 16
    local totalW = #buttons * w + (#buttons - 1) * gap
    local startX = (1280 - totalW) / 2
    local y = 580
    for i, b in ipairs(buttons) do
        local x = startX + (i - 1) * (w + gap)
        local hover = mx >= x and mx <= x + w and my >= y and my <= y + h
        local c = b.color
        local tint = armed and 0.3 or (hover and 1 or 0.5)
        love.graphics.setColor(c[1] * tint, c[2] * tint, c[3] * tint, armed and 0.6 or 1)
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
        love.graphics.setColor(1, 1, 1, armed and 0.6 or 1)
        love.graphics.rectangle("line", x, y, w, h, 8, 8)
        love.graphics.printf(b.label, x, y + 17, w, "center")
        b.x, b.y, b.w, b.h = x, y, w, h
    end
    game.endButtons = buttons
    if armed then
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf("...", 0, 660, 1280, "center")
    end
end

function UI:drawPaused(game)
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)
    love.graphics.setFont(self.bigFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PAUSED", 0, 220, 1280, "center")
    love.graphics.setFont(self.font)

    -- In infinite mode past wave 3 the player can choose to BANK or DISCARD.
    local isInfinite = (game.finalWave == 0) and (not game.isCustom) and (game.wave or 0) >= 3
    local buttons
    if isInfinite then
        buttons = {
            {label = "RESUME [ENTER]",       action = "resume",       color = {0.3, 0.8, 0.4}},
            {label = "BANK & MENU [M]",      action = "menu",         color = {0.4, 0.75, 0.35}},
            {label = "ABANDON & MENU [N]",   action = "menu_discard", color = {0.6, 0.3, 0.9}},
            {label = "QUIT [Q]",             action = "quit",         color = {0.9, 0.2, 0.2}},
        }
    else
        buttons = {
            {label = "RESUME [ENTER]", action = "resume", color = {0.3, 0.8, 0.4}},
            {label = "MAIN MENU [M]",  action = "menu",   color = {0.6, 0.3, 0.9}},
            {label = "QUIT [Q]",       action = "quit",   color = {0.9, 0.2, 0.2}},
        }
    end
    local mx, my = love.mouse.getPosition()
    local w, h = 260, 54
    local startY = 340
    for i, b in ipairs(buttons) do
        local x = (1280 - w) / 2
        local y = startY + (i - 1) * (h + 16)
        local hover = mx >= x and mx <= x + w and my >= y and my <= y + h
        local c = b.color
        love.graphics.setColor(c[1] * (hover and 1 or 0.5), c[2] * (hover and 1 or 0.5), c[3] * (hover and 1 or 0.5))
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", x, y, w, h, 8, 8)
        love.graphics.printf(b.label, x, y + 17, w, "center")
        b.x, b.y, b.w, b.h = x, y, w, h
    end
    game.pauseButtons = buttons
end

-- =====================================================================
-- MULTIPLAYER SCREENS
-- =====================================================================
local MP = require("src.multiplayer")
local Cosmetics = require("src.cosmetics")

local function mpButton(x, y, w, h, label, color, mx, my)
    local hover = mx >= x and mx <= x + w and my >= y and my <= y + h
    local r, g, b = color[1], color[2], color[3]
    love.graphics.setColor(hover and r * 1.35 or r * 0.85,
                           hover and g * 1.35 or g * 0.85,
                           hover and b * 1.35 or b * 0.85)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(label, x, y + (h - 16) / 2, w, "center")
    return {x = x, y = y, w = w, h = h}
end

-- Draw a small peer-style crab preview at (cx, cy). Used for the lobby
-- roster (where we want the same look the in-game peer crabs have).
local function drawMiniCrab(cx, cy, scale, cosmetics, t, alive)
    cosmetics = cosmetics or {body = "orange", eye = "normal", claw = "normal", hat = "none", trail = "none"}
    local col = Cosmetics.bodyColor(cosmetics)
    local outline = Cosmetics.outlineColor(cosmetics, col)
    local alpha = (alive == false) and 0.5 or 1.0
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.setColor(col[1], col[2], col[3], 0.18 * alpha)
    love.graphics.circle("fill", 0, 0, 28)
    love.graphics.setColor(outline[1], outline[2], outline[3], alpha)
    love.graphics.setLineWidth(2.5)
    for side = -1, 1, 2 do
        for i = 1, 3 do
            local sway = math.sin(t * 4 + i + side) * 1.5
            love.graphics.line(side * (10 + i * 2), (i - 2) * 4,
                               side * (16 + i * 2), (i - 2) * 4 + 8 + sway)
        end
    end
    love.graphics.setColor(col[1], col[2], col[3], alpha)
    love.graphics.circle("fill", 0, 0, 16)
    love.graphics.setColor(col[1] * 1.2, col[2] * 1.2, col[3] * 1.2, alpha * 0.7)
    love.graphics.ellipse("fill", 0, -4, 12, 6)
    love.graphics.setColor(outline[1], outline[2], outline[3], alpha)
    love.graphics.circle("line", 0, 0, 16)
    -- Pincer hint
    love.graphics.setColor(col[1], col[2], col[3], alpha)
    love.graphics.ellipse("fill", -22, -6, 6, 4)
    love.graphics.ellipse("fill",  22, -6, 6, 4)
    love.graphics.setColor(outline[1], outline[2], outline[3], alpha)
    love.graphics.ellipse("line", -22, -6, 6, 4)
    love.graphics.ellipse("line",  22, -6, 6, 4)
    -- Eyes
    love.graphics.setColor(outline[1], outline[2], outline[3], alpha)
    love.graphics.line(-5, -12, -6, -18)
    love.graphics.line( 5, -12,  6, -18)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("fill", -6, -18, 2.6)
    love.graphics.circle("fill",  6, -18, 2.6)
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.circle("fill", -6, -18, 1.2)
    love.graphics.circle("fill",  6, -18, 1.2)
    if cosmetics.hat and cosmetics.hat ~= "none" then
        love.graphics.setColor(0.95, 0.85, 0.4, alpha)
        love.graphics.ellipse("fill", 0, -22, 9, 3)
        love.graphics.rectangle("fill", -5, -28, 10, 6, 1, 1)
    end
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

-- ----- Lobby browser -------------------------------------------------
function UI:drawMpMenu(game)
    love.graphics.clear(0.04, 0.05, 0.12)
    local mx, my = love.mouse.getPosition()
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.5, 0.95, 0.7)
    love.graphics.printf("MULTIPLAYER", 0, 30, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(0.8, 0.85, 0.95, 0.85)
    love.graphics.printf("Pick a public lobby, paste a code, or host your own.",
        0, 110, 1280, "center")

    -- Three layouts:
    --   1. probing   — small "checking..." line, no controls yet
    --   2. local     — full-screen offline notice replaces the controls
    --   3. connected — normal join box + lobby list + actions
    if not MP.probed then
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.printf("Probing portal connection…", 0, 320, 1280, "center")
        game.mpJoinBox, game.mpJoinBtn = nil, nil
        game.mpRoomBtns = {}
        game.mpCreateBtn = nil
        game.mpRefreshBtn = mpButton(80, 624, 200, 50, "REFRESH", {0.3, 0.55, 0.85}, mx, my)
        game.mpBackBtn    = mpButton(1000, 624, 200, 50, "BACK",   {0.5, 0.4, 0.7}, mx, my)
        return
    end

    if not MP.connected then
        -- Centered offline placard, plenty of vertical room, no other UI.
        local boxX, boxY, boxW, boxH = 160, 200, 960, 320
        love.graphics.setColor(0.18, 0.04, 0.04, 0.92)
        love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 14, 14)
        love.graphics.setColor(1, 0.55, 0.35, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 14, 14)
        love.graphics.setLineWidth(1)
        love.graphics.setFont(self.bigFont or self.font)
        love.graphics.setColor(1, 0.85, 0.5)
        love.graphics.printf("YOU'RE RUNNING LOCALLY", boxX, boxY + 50, boxW, "center")
        love.graphics.printf("NOT ON THE PORTAL", boxX, boxY + 96, boxW, "center")
        love.graphics.setFont(self.font)
        love.graphics.setColor(1, 0.9, 0.78, 0.95)
        love.graphics.printf("Multiplayer needs the games.brassey.io wrapper.",
            boxX + 40, boxY + 168, boxW - 80, "center")
        love.graphics.printf("Open Claude: Mythos there to host or join a lobby.",
            boxX + 40, boxY + 196, boxW - 80, "center")
        love.graphics.setColor(1, 1, 1, 0.45)
        love.graphics.printf("(everything else still works locally — singleplayer, custom mode, cosmetics…)",
            boxX + 40, boxY + 248, boxW - 80, "center")
        -- Wipe interactive bounds so stale clicks can't fire on hidden controls
        game.mpJoinBox, game.mpJoinBtn = nil, nil
        game.mpRoomBtns = {}
        game.mpCreateBtn = nil
        -- Only refresh + back live at the bottom
        game.mpRefreshBtn = mpButton(80, 624, 200, 50, "REFRESH", {0.3, 0.55, 0.85}, mx, my)
        game.mpBackBtn    = mpButton(1000, 624, 200, 50, "BACK",   {0.5, 0.4, 0.7}, mx, my)
        return
    end

    -- Connected layout
    local codeBoxX, codeBoxY, codeBoxW, codeBoxH = 360, 178, 360, 50
    love.graphics.setColor(0.12, 0.16, 0.26, 0.9)
    love.graphics.rectangle("fill", codeBoxX, codeBoxY, codeBoxW, codeBoxH, 8, 8)
    love.graphics.setColor(0.5, 0.8, 1, 0.8)
    love.graphics.rectangle("line", codeBoxX, codeBoxY, codeBoxW, codeBoxH, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf("CODE", codeBoxX, codeBoxY + 4, codeBoxW, "left")
    love.graphics.setColor(1, 1, 1, 1)
    local codeStr = (game.mpJoinCode or ""):upper()
    if #codeStr == 0 then
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.printf("type 6-char code…", codeBoxX, codeBoxY + 22, codeBoxW, "center")
    else
        love.graphics.printf(codeStr, codeBoxX, codeBoxY + 22, codeBoxW, "center")
        if math.floor(love.timer.getTime() * 2) % 2 == 0 then
            local tw = self.font:getWidth(codeStr)
            love.graphics.rectangle("fill", codeBoxX + codeBoxW / 2 + tw / 2 + 2, codeBoxY + 22, 2, 16)
        end
    end
    game.mpJoinBox = {x = codeBoxX, y = codeBoxY, w = codeBoxW, h = codeBoxH}
    game.mpJoinBtn = mpButton(codeBoxX + codeBoxW + 12, codeBoxY, 180, codeBoxH,
        "JOIN", {0.3, 0.7, 0.95}, mx, my)

    local listX, listY, listW = 80, 270, 1120
    local rowH = 56
    local rooms = MP.list or {}
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("PUBLIC LOBBIES", listX, listY - 28, listW, "left")
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.printf(
        rooms[1] and (#rooms .. " open") or "(none — host one below)",
        listX, listY - 28, listW, "right")
    game.mpRoomBtns = {}
    if #rooms == 0 then
        love.graphics.setColor(0.6, 0.6, 0.7, 0.8)
        love.graphics.rectangle("line", listX, listY, listW, rowH * 3, 6, 6)
        love.graphics.setColor(0.6, 0.6, 0.7, 0.6)
        love.graphics.printf("No public lobbies right now.", listX, listY + rowH, listW, "center")
    else
        for i, r in ipairs(rooms) do
            if i > 5 then break end
            local y = listY + (i - 1) * (rowH + 8)
            local hover = mx >= listX and mx <= listX + listW and my >= y and my <= y + rowH
            love.graphics.setColor(hover and 0.18 or 0.10, 0.16, 0.28, 0.9)
            love.graphics.rectangle("fill", listX, y, listW, rowH, 6, 6)
            love.graphics.setColor(0.4, 0.7, 0.95, 0.6)
            love.graphics.rectangle("line", listX, y, listW, rowH, 6, 6)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(r.name or "Lobby", listX + 16, y + 8, 540, "left")
            local players = (r.members or r.memberCount or 0)
            local cap = r.capacity or 4
            love.graphics.setColor(0.7, 0.95, 0.7)
            love.graphics.printf(string.format("%d / %d", players, cap),
                listX + 580, y + 8, 100, "left")
            love.graphics.setColor(0.85, 0.8, 1)
            local rs = r.state or {}
            love.graphics.printf((rs.mode or "last_stand"):upper(),
                listX + 700, y + 8, 200, "left")
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.printf("CODE " .. (r.code or "??????"),
                listX + 900, y + 8, 200, "right")
            love.graphics.setColor(1, 1, 1, 0.4)
            love.graphics.printf("click to join", listX + 16, y + 30, listW - 40, "right")
            game.mpRoomBtns[#game.mpRoomBtns + 1] = {x = listX, y = y, w = listW, h = rowH, code = r.code}
        end
    end

    local rowY = 624
    game.mpRefreshBtn = mpButton(80, rowY, 200, 50, "REFRESH",   {0.3, 0.55, 0.85}, mx, my)
    game.mpCreateBtn  = mpButton(540, rowY, 200, 50, "HOST LOBBY", {0.4, 0.85, 0.55}, mx, my)
    game.mpBackBtn    = mpButton(1000, rowY, 200, 50, "BACK",     {0.5, 0.4, 0.7}, mx, my)
end

function UI:mpMenuClick(game, x, y)
    local function within(b) return b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h end
    -- Refresh + Back always work; everything else is a no-op when offline
    if within(game.mpRefreshBtn) then MP.requestList(); return end
    if within(game.mpBackBtn) then game.state = "menu"; return end
    if MP.probed and not MP.connected then return end
    if within(game.mpJoinBtn) then
        if game.mpJoinCode and #game.mpJoinCode >= 4 then
            MP.publishProfile(game.persist)
            MP.join(game.mpJoinCode)
            game.state = "mp_lobby"
        end
        return
    end
    if within(game.mpJoinBox) then return end -- focus stays here
    for _, btn in ipairs(game.mpRoomBtns or {}) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            if btn.code then
                MP.publishProfile(game.persist)
                MP.join(btn.code)
                game.state = "mp_lobby"
            end
            return
        end
    end
    if within(game.mpCreateBtn) then game:openMpCreate(); return end
end

function UI:mpMenuKey(game, key)
    if key == "escape" then game.state = "menu"; return end
    if key == "return" or key == "kpenter" then
        if game.mpJoinCode and #game.mpJoinCode >= 4 then
            MP.publishProfile(game.persist)
            MP.join(game.mpJoinCode)
            game.state = "mp_lobby"
        end
        return
    end
    if key == "backspace" then
        local s = game.mpJoinCode or ""
        if #s > 0 then game.mpJoinCode = s:sub(1, #s - 1) end
        return
    end
    if key == "f5" then MP.requestList(); return end
    if key == "h" or key == "n" then game:openMpCreate(); return end
end

function UI:mpMenuText(game, text)
    if not text then return end
    local s = game.mpJoinCode or ""
    for c in text:gmatch(".") do
        if c:match("[%w]") and #s < 6 then s = s .. c:upper() end
    end
    game.mpJoinCode = s
end

-- ----- Create lobby form --------------------------------------------
function UI:drawMpCreate(game)
    love.graphics.clear(0.04, 0.07, 0.13)
    local mx, my = love.mouse.getPosition()
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.45, 0.95, 0.65)
    love.graphics.printf("HOST A LOBBY", 0, 24, 1280, "center")
    love.graphics.setFont(self.font)
    love.graphics.setColor(0.85, 0.9, 1, 0.85)
    love.graphics.printf("Pick a name, mode, capacity, and difficulty. Anyone can join with the code.",
        0, 96, 1280, "center")
    if MP.probed and not MP.connected then
        love.graphics.setColor(1, 0.85, 0.5)
        love.graphics.printf("(Local mode — no portal detected. Hosting won't actually open a room.)",
            0, 120, 1280, "center")
    end

    local d = game.mpDraft

    -- Name input
    local nameX, nameY, nameW, nameH = 280, 150, 720, 50
    love.graphics.setColor(0.10, 0.16, 0.28, 0.9)
    love.graphics.rectangle("fill", nameX, nameY, nameW, nameH, 8, 8)
    love.graphics.setColor(0.5, 0.85, 1, 0.7)
    love.graphics.rectangle("line", nameX, nameY, nameW, nameH, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.printf("LOBBY NAME", nameX + 12, nameY + 4, nameW, "left")
    love.graphics.setColor(1, 1, 1)
    local n = d.name or ""
    if #n == 0 then
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.printf("Anglerfish Den", nameX, nameY + 22, nameW, "center")
    else
        love.graphics.printf(n, nameX, nameY + 22, nameW, "center")
        if math.floor(love.timer.getTime() * 2) % 2 == 0 then
            local tw = self.font:getWidth(n)
            love.graphics.rectangle("fill", nameX + nameW / 2 + tw / 2 + 4, nameY + 22, 2, 16)
        end
    end
    game.mpDraftBoxes = {{x = nameX, y = nameY, w = nameW, h = nameH, key = "name"}}

    -- Mode picker: 3 cards in a row
    local modeY = 230
    local modeCardW, modeCardH = 360, 130
    local gap = 24
    local startX = (1280 - modeCardW * 3 - gap * 2) / 2
    game.mpDraftMode = game.mpDraftMode or {}
    for i, mode in ipairs(MP.MODES) do
        local x = startX + (i - 1) * (modeCardW + gap)
        local hover = mx >= x and mx <= x + modeCardW and my >= modeY and my <= modeY + modeCardH
        local selected = (d.mode == mode.id)
        local r, g, b
        if mode.id == "last_stand" then r, g, b = 0.85, 0.4, 0.4
        elseif mode.id == "rally"    then r, g, b = 0.45, 0.8, 0.95
        else                              r, g, b = 0.5, 0.9, 0.55 end
        love.graphics.setColor(r * (selected and 0.55 or (hover and 0.35 or 0.18)),
                               g * (selected and 0.55 or (hover and 0.35 or 0.18)),
                               b * (selected and 0.55 or (hover and 0.35 or 0.18)),
                               0.9)
        love.graphics.rectangle("fill", x, modeY, modeCardW, modeCardH, 10, 10)
        love.graphics.setColor(r, g, b, selected and 1 or 0.7)
        love.graphics.setLineWidth(selected and 3 or 1.5)
        love.graphics.rectangle("line", x, modeY, modeCardW, modeCardH, 10, 10)
        love.graphics.setLineWidth(1)
        love.graphics.setFont(self.bigFont or self.font)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(mode.name, x, modeY + 14, modeCardW, "center")
        love.graphics.setFont(self.font)
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.printf(mode.desc, x + 12, modeY + 60, modeCardW - 24, "center")
        game.mpDraftMode[i] = {x = x, y = modeY, w = modeCardW, h = modeCardH, id = mode.id}
    end

    -- Capacity stepper
    local capY = 390
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf("LOBBY SIZE", 280, capY + 10, 200, "left")
    local capH = 50
    local minusH = mx >= 480 and mx <= 520 and my >= capY and my <= capY + capH
    love.graphics.setColor(minusH and 1 or 0.4, 0.3, 0.3)
    love.graphics.rectangle("fill", 480, capY, 40, capH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("-", 480, capY + 14, 40, "center")
    love.graphics.setColor(0.15, 0.2, 0.3, 0.9)
    love.graphics.rectangle("fill", 526, capY, 100, capH, 6, 6)
    love.graphics.setColor(1, 1, 0.85)
    love.graphics.printf(tostring(d.capacity), 526, capY + 14, 100, "center")
    local plusH = mx >= 632 and mx <= 672 and my >= capY and my <= capY + capH
    love.graphics.setColor(0.3, plusH and 1 or 0.4, 0.3)
    love.graphics.rectangle("fill", 632, capY, 40, capH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("+", 632, capY + 14, 40, "center")
    game.mpDraftCapMinus = {x = 480, y = capY, w = 40, h = capH}
    game.mpDraftCapPlus  = {x = 632, y = capY, w = 40, h = capH}

    -- Difficulty selector
    local diffY = 460
    local diff = Difficulty.get(d.difficulty)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf("DIFFICULTY", 280, diffY + 10, 200, "left")
    love.graphics.setColor(0.4, 0.3, 0.7)
    love.graphics.rectangle("fill", 480, diffY, 40, capH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("<", 480, diffY + 14, 40, "center")
    love.graphics.setColor(diff.color[1] * 0.4, diff.color[2] * 0.4, diff.color[3] * 0.4, 0.9)
    love.graphics.rectangle("fill", 526, diffY, 280, capH, 6, 6)
    love.graphics.setColor(diff.color)
    love.graphics.rectangle("line", 526, diffY, 280, capH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(diff.name, 526, diffY + 14, 280, "center")
    love.graphics.setColor(0.4, 0.3, 0.7)
    love.graphics.rectangle("fill", 812, diffY, 40, capH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(">", 812, diffY + 14, 40, "center")
    game.mpDraftDiffPrev = {x = 480, y = diffY, w = 40, h = capH}
    game.mpDraftDiffNext = {x = 812, y = diffY, w = 40, h = capH}

    -- PvP toggle
    local pvpY = 530
    local pvpHover = mx >= 280 and mx <= 880 and my >= pvpY and my <= pvpY + capH
    love.graphics.setColor(d.pvp and 0.95 or 0.18, d.pvp and 0.35 or 0.22, d.pvp and 0.4 or 0.32,
        pvpHover and 1 or 0.85)
    love.graphics.rectangle("fill", 280, pvpY, 600, capH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 280, pvpY, 600, capH, 6, 6)
    love.graphics.printf("PVP: " .. (d.pvp and "ON  (crabs hit each other at "
        .. math.floor(MP.PVP_FACTOR * 100) .. "%)" or "OFF"),
        280, pvpY + 14, 600, "center")
    game.mpDraftPvp = {x = 280, y = pvpY, w = 600, h = capH}

    -- Final wave stepper
    local fwY = 600
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf("FINAL WAVE", 280, fwY + 10, 200, "left")
    love.graphics.setColor(0.4, 0.3, 0.7)
    love.graphics.rectangle("fill", 480, fwY, 40, capH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("-", 480, fwY + 14, 40, "center")
    love.graphics.setColor(0.15, 0.2, 0.3, 0.9)
    love.graphics.rectangle("fill", 526, fwY, 200, capH, 6, 6)
    love.graphics.setColor(1, 1, 0.85)
    local fwLabel = (d.finalWave == 0) and "INFINITE" or tostring(d.finalWave)
    love.graphics.printf(fwLabel, 526, fwY + 14, 200, "center")
    love.graphics.setColor(0.4, 0.3, 0.7)
    love.graphics.rectangle("fill", 732, fwY, 40, capH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("+", 732, fwY + 14, 40, "center")
    game.mpDraftWavePrev = {x = 480, y = fwY, w = 40, h = capH}
    game.mpDraftWaveNext = {x = 732, y = fwY, w = 40, h = capH}

    -- Bottom buttons
    local rowY = 660
    game.mpDraftCreate = mpButton(540, rowY, 200, 50, "CREATE",
        {0.4, 0.85, 0.55}, mx, my)
    game.mpDraftBack   = mpButton(1000, rowY, 200, 50, "BACK",
        {0.5, 0.4, 0.7}, mx, my)
end

function UI:mpCreateClick(game, x, y)
    local function within(b) return b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h end
    local d = game.mpDraft
    for _, m in ipairs(game.mpDraftMode or {}) do
        if within(m) then d.mode = m.id; return end
    end
    if within(game.mpDraftCapMinus) then d.capacity = math.max(MP.MIN_CAP, d.capacity - 1); return end
    if within(game.mpDraftCapPlus)  then d.capacity = math.min(MP.MAX_CAP, d.capacity + 1); return end
    if within(game.mpDraftDiffPrev) then d.difficulty = Difficulty.cycle(d.difficulty, -1); return end
    if within(game.mpDraftDiffNext) then d.difficulty = Difficulty.cycle(d.difficulty,  1); return end
    if within(game.mpDraftPvp)      then d.pvp = not d.pvp; return end
    if within(game.mpDraftWavePrev) then
        if d.finalWave == 0 then d.finalWave = 30
        elseif d.finalWave > 5 then d.finalWave = d.finalWave - 5
        else d.finalWave = math.max(5, d.finalWave - 1) end
        return
    end
    if within(game.mpDraftWaveNext) then
        if d.finalWave == 0 then d.finalWave = 0
        elseif d.finalWave >= 50 then d.finalWave = 0  -- INFINITE
        else d.finalWave = d.finalWave + 5 end
        return
    end
    if within(game.mpDraftCreate) then
        local nm = (d.name and #d.name > 0) and d.name or "Anglerfish Den"
        MP.publishProfile(game.persist)
        MP.create(nm, {
            mode = d.mode, pvp = d.pvp, difficulty = d.difficulty,
            finalWave = d.finalWave, capacity = d.capacity,
        })
        game.state = "mp_lobby"
        return
    end
    if within(game.mpDraftBack) then game.state = "mp_menu"; return end
end

function UI:mpCreateKey(game, key)
    if key == "escape" then game.state = "mp_menu"; return end
    if key == "return" or key == "kpenter" then
        local d = game.mpDraft
        local nm = (d.name and #d.name > 0) and d.name or "Anglerfish Den"
        MP.publishProfile(game.persist)
        MP.create(nm, {
            mode = d.mode, pvp = d.pvp, difficulty = d.difficulty,
            finalWave = d.finalWave, capacity = d.capacity,
        })
        game.state = "mp_lobby"
        return
    end
    if key == "backspace" then
        local s = game.mpDraft.name or ""
        if #s > 0 then game.mpDraft.name = s:sub(1, #s - 1) end
        return
    end
end

function UI:mpCreateText(game, text)
    if not text then return end
    local s = game.mpDraft.name or ""
    -- Accept everything except newlines / carriage returns. The previous
    -- [%w%s%p] filter was meant to reject control chars but in some
    -- LuaJIT builds it dropped the space character outright.
    for c in text:gmatch(".") do
        if #s < 28 and c ~= "\n" and c ~= "\r" then s = s .. c end
    end
    game.mpDraft.name = s
end

-- ----- Live lobby (waiting room) ------------------------------------
function UI:drawMpLobby(game)
    love.graphics.clear(0.03, 0.05, 0.10)
    local mx, my = love.mouse.getPosition()
    local t = love.timer.getTime()

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.55, 0.95, 0.7)
    local lobbyName = (MP.lobby and MP.lobby.name) or "Connecting..."
    love.graphics.printf(lobbyName, 0, 24, 1280, "center")
    love.graphics.setFont(self.font)

    -- Code & connection state
    if MP.lobby and MP.lobby.code then
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf("CODE", 0, 96, 1280, "center")
        love.graphics.setFont(self.bigFont or self.font)
        love.graphics.setColor(0.95, 0.95, 1)
        love.graphics.printf(MP.lobby.code, 0, 116, 1280, "center")
        love.graphics.setFont(self.font)
    elseif MP.probed and not MP.connected then
        love.graphics.setColor(1, 0.85, 0.5)
        love.graphics.printf("YOU'RE RUNNING LOCALLY — NOT ON THE PORTAL", 0, 110, 1280, "center")
        love.graphics.setColor(1, 0.85, 0.7, 0.9)
        love.graphics.printf("Open Claude: Mythos on games.brassey.io to actually host or join.",
            0, 134, 1280, "center")
    else
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.printf("Waiting for the portal to materialise the room...",
            0, 116, 1280, "center")
    end

    -- Settings strip
    if MP.lobby then
        local m = MP.modeById(MP.lobby.mode or "last_stand")
        local diff = Difficulty.get(MP.lobby.difficulty or "normal")
        love.graphics.setColor(0.85, 0.95, 1, 0.92)
        love.graphics.printf(string.format(
            "%s   |   %s   |   PVP %s   |   FINAL WAVE %s   |   %d / %d",
            m.name,
            diff.name,
            MP.lobby.pvp and "ON" or "OFF",
            MP.lobby.finalWave == 0 and "INFINITE" or tostring(MP.lobby.finalWave or 20),
            (function() local n = 0; for _ in pairs(MP.peers) do n = n + 1 end; return n end)(),
            MP.lobby.capacity or 4
        ), 0, 178, 1280, "center")
    end

    -- Roster grid: each peer's mini crab + handle
    local rosterY = 230
    local cellW, cellH = 220, 240
    local gap = 16
    local count = 0
    for _ in pairs(MP.peers) do count = count + 1 end
    if count == 0 then count = 1 end
    local cols = math.min(5, count)
    if cols < 1 then cols = 1 end
    local rowW = cellW * cols + gap * (cols - 1)
    local startX = (1280 - rowW) / 2
    local i = 0
    -- show local first
    local order = {}
    if MP.localId then order[#order + 1] = MP.localId end
    for id in pairs(MP.peers) do if id ~= MP.localId then order[#order + 1] = id end end
    if #order == 0 then order[1] = "self" end

    for _, id in ipairs(order) do
        local col = i % cols
        local row = math.floor(i / cols)
        local x = startX + col * (cellW + gap)
        local y = rosterY + row * (cellH + gap)
        love.graphics.setColor(0.10, 0.14, 0.22, 0.85)
        love.graphics.rectangle("fill", x, y, cellW, cellH, 10, 10)
        love.graphics.setColor(0.4, 0.7, 0.95, 0.55)
        love.graphics.rectangle("line", x, y, cellW, cellH, 10, 10)
        local cosmetics, handle, alive
        if id == MP.localId or id == "self" then
            cosmetics = Cosmetics.equipped(game.persist)
            handle = MP.localHandle
            alive = true
        else
            local p = MP.peers[id]
            cosmetics = p and p.cosmetics
            handle = (p and p.handle) or "?"
            alive = p and p.alive
        end
        -- Use the canonical preview-crab renderer so lobby roster shows the
        -- exact customised skin (body pattern, eyes, claws, hat, trail, gun)
        -- the player will actually run with — not the simplified mini-crab.
        if alive == false then love.graphics.setColor(1, 1, 1, 0.5) end
        drawPreviewCrab(x + cellW / 2, y + cellH / 2 - 10, 1.7, cosmetics, t)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(handle or "Crab", x, y + cellH - 50, cellW, "center")
        if id == MP.localId or id == "self" then
            love.graphics.setColor(0.6, 0.95, 0.7, 0.8)
            love.graphics.printf("(you)", x, y + cellH - 28, cellW, "center")
        end
        i = i + 1
        if i >= cols * 2 then break end
    end

    -- Recent events log
    love.graphics.setColor(1, 1, 1, 0.55)
    local logY = 540
    for k = math.max(1, #MP.events - 3), #MP.events do
        love.graphics.setColor(1, 1, 1, 0.4 + (k / #MP.events) * 0.5)
        love.graphics.printf(MP.events[k] or "", 0, logY, 1280, "center")
        logY = logY + 18
    end

    -- Auto-transition to wave when room phase flips
    if MP.lobby and MP.lobby.phase == "wave" and MP.lobby.startedAt
        and not (game._mpStarted == MP.lobby.startedAt) then
        game._mpStarted = MP.lobby.startedAt
        game:startMultiplayerRun()
    end

    -- Bottom buttons
    local rowY2 = 644
    game.mpLobbyStart  = mpButton(540, rowY2, 200, 50, "START RUN", {0.4, 0.95, 0.55}, mx, my)
    game.mpLobbyLeave  = mpButton(1000, rowY2, 200, 50, "LEAVE",     {0.85, 0.35, 0.4}, mx, my)
end

function UI:mpLobbyClick(game, x, y)
    local function within(b) return b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h end
    if within(game.mpLobbyStart) then
        if MP.lobby and MP.lobby.roomId then
            MP.startRun()
            -- Local transition happens via the phase-watcher in the next draw frame
        end
        return
    end
    if within(game.mpLobbyLeave) then
        MP.leave()
        game.state = "mp_menu"
        return
    end
end

function UI:mpLobbyKey(game, key)
    if key == "escape" then
        MP.leave()
        game.state = "mp_menu"
        return
    end
    if key == "return" or key == "kpenter" then
        if MP.lobby and MP.lobby.roomId then MP.startRun() end
    end
end

return UI
