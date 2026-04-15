function love.conf(t)
    -- Identity: the LÖVE save directory name. The portal expects this to
    -- match its slug-with-dashes-converted-to-underscores default. Keep
    -- stable forever — changing it orphans every player's save.
    t.identity = "claude_mythos"
    t.version  = "11.5"
    t.console  = false

    t.window.title     = "Claude: Mythos"
    -- 16:9 logical resolution. The iframe rescales to whatever size the
    -- portal gives it; main.lua already scales internally to match.
    t.window.width     = 1280
    t.window.height    = 720
    t.window.resizable = false      -- iframe controls real size
    t.window.vsync     = 1
    t.window.msaa      = 0          -- msaa>0 can break some WebGL drivers
    t.window.highdpi   = true       -- let love.js pick DPR; looks sharper

    -- Drop modules we don't use so the WASM init is faster.
    t.modules.thread = false
    t.modules.video  = false
end
