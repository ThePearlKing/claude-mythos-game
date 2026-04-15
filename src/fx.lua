-- Portal runtime UI effects bridge. Emits [[LOVEWEB_FX]] magic-print lines
-- that the games.brassey.io portal intercepts to flash, shake, mood-tint,
-- ripple, etc. the iframe chrome around the game. No-op on desktop LÖVE
-- (print just goes to stdout), so it's safe to call from any code path.
--
-- The portal clamps duration to 2.5s, intensity to 0..1, BPM to 20..200,
-- merges fast strobes, and skips motion effects under prefers-reduced-motion.
-- Verbs are defined in INTEGRATION.md "Runtime UI effects".

local Fx = {}

local function emit(verb, ...)
    local parts = { verb }
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[#parts + 1] = tostring(v)
    end
    print("[[LOVEWEB_FX]]" .. table.concat(parts, " "))
end

function Fx.flash(color, ms, intensity)   emit("flash", color, ms, intensity or 0.6) end
function Fx.shake(intensity, ms)          emit("shake", intensity, ms) end
function Fx.invert(ms)                    emit("invert", ms) end
function Fx.tint(color, alpha, ms)        emit("tint", color, alpha, ms) end
function Fx.pulse(color, ms)              emit("pulse", color, ms) end
function Fx.ripple(color, x, y, ms)       emit("ripple", color, x, y, ms) end
function Fx.glow(color, intensity, ms)    emit("glow", color, intensity, ms) end
function Fx.chroma(intensity, ms)         emit("chroma", intensity, ms) end
function Fx.vignette(intensity, ms)       emit("vignette", intensity, ms) end
function Fx.shatter(intensity, ms)        emit("shatter", intensity, ms) end
function Fx.flicker(intensity, ms)        emit("flicker", intensity, ms) end
function Fx.zoom(amount, ms)              emit("zoom", amount, ms) end
function Fx.scanlines(intensity, ms)      emit("scanlines", intensity, ms) end

-- Persistent verbs: pass nil/"none"/"off" to clear.
function Fx.mood(color, intensity)
    if not color or color == "none" then emit("mood", "none")
    else emit("mood", color, intensity or 0.3) end
end
function Fx.calm(color, intensity)
    if not color or color == "none" then emit("calm", "none")
    else emit("calm", color, intensity or 0.3) end
end
function Fx.pulsate(color, bpm, intensity)
    if not color or color == "off" then emit("pulsate", "off")
    else emit("pulsate", color, bpm or 72, intensity or 0.3) end
end

-- Wipe every persistent effect at once. Use on menu return / new run / quit.
function Fx.clearAll()
    emit("mood", "none")
    emit("calm", "none")
    emit("pulsate", "off")
end

return Fx
