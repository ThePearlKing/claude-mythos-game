local Audio = {}

local rate = 44100

-- ====== SFX helpers (single-tone and chord) ======
local function tone(freq, dur, vol, wave, decay)
    vol = vol or 0.3
    wave = wave or "sine"
    decay = decay == nil and true or decay
    local samples = math.floor(rate * dur)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / rate
        local env = decay and math.max(0, 1 - t / dur) or 1
        local s
        if wave == "sine" then
            s = math.sin(2 * math.pi * freq * t)
        elseif wave == "square" then
            s = math.sin(2 * math.pi * freq * t) > 0 and 1 or -1
        elseif wave == "saw" then
            s = 2 * (t * freq - math.floor(0.5 + t * freq))
        elseif wave == "noise" then
            s = (math.random() * 2 - 1)
        elseif wave == "triangle" then
            local p = (t * freq) % 1
            s = p < 0.5 and (4 * p - 1) or (3 - 4 * p)
        end
        data:setSample(i, s * vol * env)
    end
    return data
end

local function chord(freqs, dur, vol, wave)
    vol = vol or 0.25
    wave = wave or "sine"
    local samples = math.floor(rate * dur)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / rate
        local env = math.max(0, 1 - t / dur)
        local s = 0
        for _, f in ipairs(freqs) do
            s = s + math.sin(2 * math.pi * f * t)
        end
        s = s / #freqs
        data:setSample(i, s * vol * env)
    end
    return data
end

-- ====== Multi-layer music synth ======
local function mixAdd(data, samples, idx, v)
    if idx < 0 or idx >= samples then return end
    local cur = data:getSample(idx)
    local nv = cur + v
    if nv > 1 then nv = 1 elseif nv < -1 then nv = -1 end
    data:setSample(idx, nv)
end

local function addNote(data, samples, freq, startT, dur, vol, wave, attack, release)
    vol = vol or 0.18
    wave = wave or "sine"
    attack = attack or 0.005
    release = release or 0.08
    local s0 = math.floor(startT * rate)
    local sN = math.floor(dur * rate)
    for i = 0, sN - 1 do
        local t = i / rate
        local e
        if t < attack then
            e = t / attack
        elseif t > dur - release then
            e = math.max(0, (dur - t) / release)
        else
            e = 1
        end
        local s
        if wave == "sine" then
            s = math.sin(2 * math.pi * freq * t)
        elseif wave == "square" then
            s = math.sin(2 * math.pi * freq * t) > 0 and 1 or -1
        elseif wave == "saw" then
            local p = (t * freq) % 1
            s = 2 * p - 1
        elseif wave == "triangle" then
            local p = (t * freq) % 1
            s = p < 0.5 and (4 * p - 1) or (3 - 4 * p)
        elseif wave == "pulse" then
            local p = (t * freq) % 1
            s = p < 0.25 and 1 or -1
        end
        -- subtle vibrato
        s = s + 0.12 * math.sin(2 * math.pi * freq * 2.01 * t)
        mixAdd(data, samples, s0 + i, s * vol * e)
    end
end

local function addChordStab(data, samples, freqs, startT, dur, vol, wave)
    for _, f in ipairs(freqs) do
        addNote(data, samples, f, startT, dur, (vol or 0.08), wave or "triangle", 0.01, 0.15)
    end
end

local function addPad(data, samples, freqs, startT, dur, vol)
    -- Slow sine pad with detune and slow amplitude wobble
    vol = vol or 0.05
    local s0 = math.floor(startT * rate)
    local sN = math.floor(dur * rate)
    for i = 0, sN - 1 do
        local t = i / rate
        local e = math.min(1, t / 0.2) * math.max(0, math.min(1, (dur - t) / 0.3))
        local wobble = 1 + 0.15 * math.sin(2 * math.pi * 0.7 * t)
        local s = 0
        for _, f in ipairs(freqs) do
            s = s + math.sin(2 * math.pi * f * t)
            s = s + 0.6 * math.sin(2 * math.pi * f * 1.003 * t)
        end
        s = s / (#freqs * 1.5)
        mixAdd(data, samples, s0 + i, s * vol * e * wobble)
    end
end

local function addKick(data, samples, startT, vol)
    vol = vol or 0.5
    local dur = 0.16
    local s0 = math.floor(startT * rate)
    local sN = math.floor(dur * rate)
    for i = 0, sN - 1 do
        local t = i / rate
        local freq = 40 + 110 * math.exp(-t * 30)
        local env = math.exp(-t * 14)
        local s = math.sin(2 * math.pi * freq * t) * env
        -- click transient
        if i < 80 then s = s + (math.random() * 2 - 1) * 0.4 * (1 - i / 80) end
        mixAdd(data, samples, s0 + i, s * vol)
    end
end

local function addSnare(data, samples, startT, vol)
    vol = vol or 0.32
    local dur = 0.14
    local s0 = math.floor(startT * rate)
    local sN = math.floor(dur * rate)
    for i = 0, sN - 1 do
        local t = i / rate
        local env = math.exp(-t * 22)
        local noise = (math.random() * 2 - 1) * 0.75
        local body = math.sin(2 * math.pi * 200 * t) * 0.3
        mixAdd(data, samples, s0 + i, (noise + body) * vol * env)
    end
end

local function addHat(data, samples, startT, vol, open)
    vol = vol or 0.14
    local dur = open and 0.12 or 0.04
    local s0 = math.floor(startT * rate)
    local sN = math.floor(dur * rate)
    for i = 0, sN - 1 do
        local t = i / rate
        local env = math.exp(-t * (open and 25 or 70))
        local s = (math.random() * 2 - 1) * env
        mixAdd(data, samples, s0 + i, s * vol)
    end
end

local function addBass(data, samples, freq, startT, dur, vol)
    -- Fat saw bass with sub
    vol = vol or 0.25
    local s0 = math.floor(startT * rate)
    local sN = math.floor(dur * rate)
    for i = 0, sN - 1 do
        local t = i / rate
        local e = math.min(1, t / 0.01) * math.max(0, math.min(1, (dur - t) / 0.05))
        local p = (t * freq) % 1
        local saw = 2 * p - 1
        local sub = math.sin(2 * math.pi * freq * 0.5 * t)
        local s = (saw * 0.6 + sub * 0.4)
        mixAdd(data, samples, s0 + i, s * vol * e)
    end
end

local function addArp(data, samples, freq, startT, dur, vol)
    addNote(data, samples, freq, startT, dur * 0.9, vol or 0.14, "pulse", 0.003, 0.04)
end

-- Chromatic notes (Hz)
local N = {
    A1 = 55, C2 = 65.41, D2 = 73.42, Eb2 = 77.78, E2 = 82.41, F2 = 87.31, G2 = 98, Ab2 = 103.83,
    A2 = 110, Bb2 = 116.54, B2 = 123.47, C3 = 130.81, Db3 = 138.59, D3 = 146.83, Eb3 = 155.56,
    E3 = 164.81, F3 = 174.61, Gb3 = 185, G3 = 196, Ab3 = 207.65,
    A3 = 220, Bb3 = 233.08, B3 = 246.94, C4 = 261.63, Db4 = 277.18, D4 = 293.66, Eb4 = 311.13,
    E4 = 329.63, F4 = 349.23, Gb4 = 369.99, G4 = 392, Ab4 = 415.3,
    A4 = 440, Bb4 = 466.16, B4 = 493.88, C5 = 523.25, Db5 = 554.37, D5 = 587.33, Eb5 = 622.25,
    E5 = 659.25, F5 = 698.46, Gb5 = 739.99, G5 = 783.99, Ab5 = 830.61,
    A5 = 880, Bb5 = 932.33, B5 = 987.77, C6 = 1046.5, D6 = 1174.66, E6 = 1318.51,
}

-- Add distortion/clip for grit
local function clipper(v, drive)
    drive = drive or 2.2
    local x = v * drive
    if x > 1 then x = 1 elseif x < -1 then x = -1 end
    -- soft saturate
    return math.tanh(x * 1.4)
end

-- Acid-style resonant filter sweep (simplified: 2-pole resonant low-pass approximation via envelope + pitch)
local function addAcid(data, samples, freq, startT, dur, vol, reso)
    vol = vol or 0.18
    reso = reso or 0.7
    local s0 = math.floor(startT * rate)
    local sN = math.floor(dur * rate)
    for i = 0, sN - 1 do
        local t = i / rate
        local e = math.min(1, t / 0.005) * math.max(0, math.min(1, (dur - t) / 0.04))
        -- Filter cutoff sweep
        local cutoff = 0.3 + 0.7 * math.exp(-t * 8)
        local p = (t * freq) % 1
        local saw = 2 * p - 1
        -- "Resonance" simulated by adding a sine at cutoff freq
        local resoTone = math.sin(2 * math.pi * freq * cutoff * 4 * t) * reso
        local s = (saw * (1 - reso * 0.3) + resoTone * reso) * cutoff
        mixAdd(data, samples, s0 + i, clipper(s * vol * e, 1.8))
    end
end

-- Noise riser / sweep
local function addRiser(data, samples, startT, dur, vol)
    vol = vol or 0.15
    local s0 = math.floor(startT * rate)
    local sN = math.floor(dur * rate)
    for i = 0, sN - 1 do
        local t = i / rate
        local e = (t / dur)
        local pitch = 200 + 2000 * e * e
        local s = math.sin(2 * math.pi * pitch * t) * 0.3
        s = s + (math.random() * 2 - 1) * e * 0.6
        mixAdd(data, samples, s0 + i, s * vol * e)
    end
end

-- Glitchy stab chord (dissonant, quick attack)
local function addStab(data, samples, freqs, startT, dur, vol)
    vol = vol or 0.12
    local s0 = math.floor(startT * rate)
    local sN = math.floor(dur * rate)
    for i = 0, sN - 1 do
        local t = i / rate
        local e = math.min(1, t / 0.002) * math.max(0, math.min(1, (dur - t) / 0.05)) ^ 2
        local s = 0
        for _, f in ipairs(freqs) do
            local p = (t * f) % 1
            s = s + (p < 0.5 and 1 or -1) -- pulse
        end
        s = clipper(s / #freqs, 2.5)
        mixAdd(data, samples, s0 + i, s * vol * e)
    end
end

-- Pumping sidechain envelope: strong duck on each kick
local function applyPumping(data, samples, kickTimes, kickDur, depth)
    kickDur = kickDur or 0.18
    depth = depth or 0.45
    for _, kt in ipairs(kickTimes) do
        local k0 = math.floor(kt * rate)
        local kN = math.floor(kickDur * rate)
        for i = 0, kN - 1 do
            local idx = k0 + i
            if idx >= 0 and idx < samples then
                local prog = i / kN
                -- deepest right at the kick, recovers to 1.0 by kickDur
                local duck = 1 - depth * (1 - prog)
                local cur = data:getSample(idx)
                data:setSample(idx, cur * duck)
            end
        end
    end
end

local function buildNormalMusic()
    -- Intense hacker/cyberpunk. 160 BPM, D phrygian. 8 bars = 12s.
    local beat = 60 / 160          -- 0.375s
    local sixteenth = beat / 4     -- 0.09375s
    local barDur = beat * 4        -- 1.5s
    local bars = 8
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)

    -- D phrygian scale: D Eb F G A Bb C
    local scale = {N.D4, N.Eb4, N.F4, N.G4, N.A4, N.Bb4, N.C5, N.D5}

    -- 8-bar progression (root freqs): i, i, bII, i, iv, i, bVII, V
    local roots = {N.D2, N.D2, N.Eb2, N.D2, N.G2, N.D2, N.C2, N.A2}
    local chordAbove = {
        {N.D3, N.F3, N.A3},
        {N.D3, N.F3, N.A3},
        {N.Eb3, N.G3, N.Bb3},
        {N.D3, N.F3, N.A3},
        {N.G3, N.Bb3, N.D4},
        {N.D3, N.F3, N.A3},
        {N.C3, N.Eb3, N.G3},
        {N.A2, N.Db3, N.E3},
    }

    -- Track kick hits for pumping sidechain
    local kickTimes = {}

    for b = 1, bars do
        local bt = (b - 1) * barDur
        local root = roots[b]
        local chord = chordAbove[b]

        -- === PAD/DRONE ===
        addPad(data, samples, chord, bt, barDur, 0.045)

        -- === GRITTY BASS GROOVE ===
        -- Pattern: R R _ R | _ R _ R8 (where R8 = octave up) with 16th variations
        -- 16 sixteenths per bar. Bass plays on select 16ths.
        local bassHits = {0, 2, 3, 4, 6, 7, 8, 10, 12, 13, 14}
        for _, i in ipairs(bassHits) do
            local t0 = bt + i * sixteenth
            local f = root
            if i == 7 or i == 14 then f = root * 2 end -- octave jumps
            if i == 10 then f = root * 1.5 end          -- fifth
            addAcid(data, samples, f, t0, sixteenth * 0.95, 0.22, 0.5)
        end

        -- === DRUMS ===
        -- Kick on every beat (4-on-floor), extra kicks on select 16ths
        for i = 0, 3 do
            local kt = bt + i * beat
            addKick(data, samples, kt, 0.65)
            table.insert(kickTimes, kt)
        end
        if b % 2 == 0 then
            local kt = bt + 3.5 * beat
            addKick(data, samples, kt, 0.4)
            table.insert(kickTimes, kt)
        end
        -- Snare on 2 and 4 with ghost snares
        addSnare(data, samples, bt + beat, 0.5)
        addSnare(data, samples, bt + 3 * beat, 0.5)
        if b % 4 == 3 then
            addSnare(data, samples, bt + 3.5 * beat, 0.2) -- ghost
        end
        -- Hats: 16th notes with open on 4e
        for i = 0, 15 do
            local open = (i == 14) or (i == 7 and b % 2 == 0)
            local accent = (i % 4 == 0) and 0.18 or 0.1
            addHat(data, samples, bt + i * sixteenth, accent, open)
        end

        -- === ACID LEAD ARP (top line) ===
        -- Fast 16th-note arpeggio through the scale with pitch bends
        local arpPattern = {1, 3, 5, 3, 6, 4, 7, 5, 1, 3, 5, 8, 6, 4, 2, 3}
        for i = 1, 16 do
            local t0 = bt + (i - 1) * sixteenth
            local idx = ((arpPattern[i] - 1) % #scale) + 1
            local f = scale[idx]
            if b > 4 then f = f * 2 end -- Octave up in second half
            addAcid(data, samples, f, t0, sixteenth * 0.85, 0.1, 0.55)
        end

        -- === DISSONANT STAB CHORDS ===
        -- On certain syncopated beats (adds tension)
        if b == 2 or b == 4 or b == 6 or b == 8 then
            addStab(data, samples, chord, bt + 2.5 * beat, beat * 0.5, 0.16)
        end
        if b == 7 then
            -- Rising stab series to build tension into phrase end
            for i = 0, 3 do
                addStab(data, samples, {chord[1] * (1 + i * 0.08), chord[2] * (1 + i * 0.08)},
                    bt + i * sixteenth * 2, sixteenth * 1.5, 0.08)
            end
        end

        -- === RISER INTO PHRASE CHANGE ===
        if b == 4 or b == 8 then
            addRiser(data, samples, bt + 3 * beat, beat, 0.14)
        end
    end

    -- Apply sidechain-style pumping to the whole mix (cyberpunk feel)
    applyPumping(data, samples, kickTimes, 0.12, 0.35)

    local src = love.audio.newSource(data)
    src:setLooping(true)
    src:setVolume(0.7)
    return src
end

local function buildBossMusic()
    -- Brutal industrial darksynth for OpenClaw. 175 BPM, D phrygian. 8 bars.
    local beat = 60 / 175
    local sixteenth = beat / 4
    local barDur = beat * 4
    local bars = 8
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)

    -- Brutal low roots
    local roots = {N.D2, N.D2, N.D2, N.Eb2, N.D2, N.D2, N.C2, N.Bb2 or N.A2 * 1.06}
    local chords = {
        {N.D3, N.F3, N.A3},
        {N.D3, N.F3, N.Ab3},
        {N.D3, N.F3, N.A3},
        {N.Eb3, N.Gb3, N.Bb3 or N.A3 * 1.06},
        {N.D3, N.F3, N.A3},
        {N.D3, N.F3, N.Ab3},
        {N.C3, N.Eb3, N.G3},
        {N.A2, N.Db3, N.E3},
    }

    local kickTimes = {}

    for b = 1, bars do
        local bt = (b - 1) * barDur
        local root = roots[b]
        local chord = chords[b]

        -- Ominous detuned sub drone
        addPad(data, samples, {root * 0.5, root * 0.5 * 1.015, root * 0.5 * 0.985}, bt, barDur, 0.08)

        -- === DRIVING 16TH-NOTE BASS (like Perturbator) ===
        for i = 0, 15 do
            local f = root
            if i % 4 == 3 then f = root * 2 end   -- octave
            if i == 10 then f = root * 1.5 end    -- fifth
            if i == 13 then f = root * 1.19 end   -- b3 accent
            addAcid(data, samples, f, bt + i * sixteenth, sixteenth * 0.95, 0.26, 0.65)
        end

        -- === DRUMS ===
        -- Four-on-the-floor kicks with aggressive ghost kicks
        for i = 0, 3 do
            local kt = bt + i * beat
            addKick(data, samples, kt, 0.75)
            table.insert(kickTimes, kt)
        end
        -- Blast kick roll on bar 4 (build-up)
        if b % 4 == 0 then
            for i = 0, 7 do
                local kt = bt + 3 * beat + i * (beat / 8)
                addKick(data, samples, kt, 0.35)
                table.insert(kickTimes, kt)
            end
        end
        -- Industrial snare on 2 and 4
        addSnare(data, samples, bt + beat, 0.6)
        addSnare(data, samples, bt + 3 * beat, 0.6)
        -- Fast hats
        for i = 0, 15 do
            local open = (i == 14)
            local accent = (i % 2 == 0) and 0.14 or 0.09
            addHat(data, samples, bt + i * sixteenth, accent, open)
        end

        -- === MENACING LEAD ===
        local scale = {N.D4, N.Eb4, N.F4, N.G4, N.A4, N.Bb4, N.C5, N.D5, N.Eb5, N.F5}
        local riff = {1, 4, 6, 4, 8, 6, 4, 6, 2, 5, 7, 5, 9, 7, 5, 7}
        for i = 1, 16 do
            local idx = ((riff[i] - 1) % #scale) + 1
            local f = scale[idx] * (b > 4 and 2 or 1)
            addNote(data, samples, f, bt + (i - 1) * sixteenth, sixteenth * 0.9, 0.11, "saw", 0.003, 0.04)
        end

        -- === GLITCHY STAB ACCENTS ===
        -- Every bar: stab on beat 3 and syncopated stab on 4-and
        addStab(data, samples, chord, bt + 2 * beat, beat * 0.4, 0.14)
        addStab(data, samples, {chord[1], chord[2] * 1.06, chord[3]}, bt + 3.5 * beat, beat * 0.3, 0.12)

        -- === RISERS INTO BARS 5 AND 8 ===
        if b == 4 then
            addRiser(data, samples, bt + 3 * beat, beat, 0.22)
        end
        if b == 8 then
            addRiser(data, samples, bt + 2.5 * beat, beat * 1.5, 0.2)
        end

        -- Dissonant screaming high note on beat 1 of phrase starts
        if b == 1 or b == 5 then
            addNote(data, samples, N.F5 * 2, bt, beat * 2, 0.05, "square", 0.005, 0.5)
        end
    end

    applyPumping(data, samples, kickTimes, 0.10, 0.45)

    local src = love.audio.newSource(data)
    src:setLooping(true)
    src:setVolume(0.75)
    return src
end

local function buildEldritchMusic()
    -- Drones, dissonance, detuned pads, whispers
    local total = 16.0
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)

    -- Very low sub drone (unstable)
    for t0 = 0, total - 0.5, 0.5 do
        local f = 55 + math.random() * 6 - 3
        addNote(data, samples, f, t0, 0.55, 0.22, "sine", 0.1, 0.1)
    end

    -- Detuned pad clusters
    local clusters = {
        {N.A2, N.A2 * 1.06, N.A2 * 1.12, N.A2 * 1.18},
        {N.F3, N.F3 * 1.04, N.F3 * 1.07},
        {N.C3 * 0.5, N.C3 * 0.53, N.C3 * 0.55},
        {N.D3, N.D3 * 1.06, N.D3 * 1.14},
    }
    for i = 0, 7 do
        local c = clusters[(i % #clusters) + 1]
        addPad(data, samples, c, i * 2, 2.2, 0.07)
    end

    -- High shimmering whispers (random high notes)
    for i = 1, 50 do
        local t0 = math.random() * (total - 1)
        local f = 1200 + math.random() * 2400
        addNote(data, samples, f, t0, 0.3 + math.random() * 0.5, 0.03, "sine", 0.05, 0.1)
    end

    -- Scraping saw bursts
    for i = 1, 14 do
        local t0 = math.random() * (total - 0.6)
        local f = 80 + math.random() * 200
        addNote(data, samples, f, t0, 0.4, 0.08, "saw", 0.01, 0.1)
    end

    -- Occasional "heartbeat" kick
    for t0 = 0, total - 1, 1.2 do
        addKick(data, samples, t0, 0.35)
        addKick(data, samples, t0 + 0.18, 0.25)
    end

    local src = love.audio.newSource(data)
    src:setLooping(true)
    src:setVolume(0.55)
    return src
end

Audio.masterVol = 1.0
Audio.musicVol = 1.0
Audio.sfxVol = 1.0

function Audio:setMasterVolume(v) self.masterVol = v; self:applyVolumes() end
function Audio:setMusicVolume(v)  self.musicVol  = v; self:applyVolumes() end
function Audio:setSfxVolume(v)    self.sfxVol    = v end

function Audio:applyVolumes()
    if self.music       then self.music:setVolume(0.7  * self.masterVol * self.musicVol) end
    if self.bossMusic   then self.bossMusic:setVolume(0.75 * self.masterVol * self.musicVol) end
    if self.eldritchMusic then self.eldritchMusic:setVolume(0.55 * self.masterVol * self.musicVol) end
end

-- === Extra themes (lazy-built) ===
local function buildSynthwave()
    local beat = 60 / 110
    local sixteenth = beat / 4
    local barDur = beat * 4
    local bars = 8
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)

    local roots = {N.F2, N.F2, N.Eb2, N.C2, N.F2, N.Eb2, N.G2, N.C2}
    local chords = {
        {N.F3, N.A3, N.C4},
        {N.F3, N.A3, N.C4},
        {N.Eb3, N.G3, N.Bb3},
        {N.C3, N.E3, N.G3},
        {N.F3, N.A3, N.C4},
        {N.Eb3, N.G3, N.Bb3},
        {N.G3, N.B3, N.D4},
        {N.C3, N.E3, N.G3},
    }

    local kickTimes = {}
    for b = 1, bars do
        local bt = (b - 1) * barDur
        local root = roots[b]
        local chord = chords[b]
        addPad(data, samples, chord, bt, barDur, 0.09)
        -- Bass on 8ths
        for i = 0, 7 do
            local f = root
            if i == 6 then f = root * 2 end
            addBass(data, samples, f, bt + i * (beat / 2), (beat / 2) * 0.9, 0.2)
        end
        -- Drums
        for i = 0, 3 do
            addKick(data, samples, bt + i * beat, 0.55); table.insert(kickTimes, bt + i * beat)
        end
        addSnare(data, samples, bt + beat, 0.4)
        addSnare(data, samples, bt + 3 * beat, 0.4)
        for i = 0, 7 do addHat(data, samples, bt + i * (beat/2), 0.1, i == 7) end
        -- Melodic lead
        local scale = {chord[1], chord[2], chord[3], chord[1] * 2, chord[2] * 2}
        local r = {1, 2, 3, 2, 4, 3, 5, 4}
        for i = 1, 8 do
            addNote(data, samples, scale[r[i]], bt + (i-1) * (beat/2), beat * 0.48, 0.12, "triangle", 0.01, 0.2)
        end
    end
    applyPumping(data, samples, kickTimes, 0.14, 0.3)
    local src = love.audio.newSource(data); src:setLooping(true); src:setVolume(0.65); return src
end

local function buildChiptune()
    local beat = 60 / 150
    local sixteenth = beat / 4
    local barDur = beat * 4
    local bars = 8
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    local scale = {N.C4, N.D4, N.E4, N.G4, N.A4, N.C5, N.D5, N.E5}
    local bassline = {N.C3, N.C3, N.G2, N.G2, N.A2, N.A2, N.F2, N.F2}
    for b = 1, bars do
        local bt = (b - 1) * barDur
        -- 16th-note square bass
        for i = 0, 15 do
            addNote(data, samples, bassline[b], bt + i * sixteenth, sixteenth * 0.9, 0.18, "square", 0.002, 0.01)
        end
        -- Melody arp
        local riff = {1, 3, 5, 3, 2, 5, 4, 7, 6, 4, 3, 5, 8, 6, 5, 3}
        for i = 1, 16 do
            addNote(data, samples, scale[((riff[i] - 1) % #scale) + 1], bt + (i - 1) * sixteenth, sixteenth * 0.85, 0.14, "pulse", 0.002, 0.02)
        end
        -- Noise drums
        for i = 0, 3 do addSnare(data, samples, bt + i * beat + beat * 0.5, 0.15) end
        for i = 0, 3 do addKick(data, samples, bt + i * beat, 0.35) end
    end
    local src = love.audio.newSource(data); src:setLooping(true); src:setVolume(0.55); return src
end

local function buildDoom()
    local beat = 60 / 180
    local sixteenth = beat / 4
    local barDur = beat * 4
    local bars = 8
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    local roots = {N.E2, N.E2, N.E2, N.G2, N.E2, N.E2, N.D2, N.A2 * 0.5}
    local kickTimes = {}
    for b = 1, bars do
        local bt = (b - 1) * barDur
        local root = roots[b]
        -- Galloping triplets bass
        for i = 0, 11 do
            local f = root
            if i % 3 == 2 then f = root * 1.5 end
            addAcid(data, samples, f, bt + i * (barDur / 12), (barDur / 12) * 0.9, 0.3, 0.75)
        end
        -- Blast beats
        for i = 0, 7 do
            addKick(data, samples, bt + i * (beat / 2), 0.7); table.insert(kickTimes, bt + i * (beat / 2))
        end
        addSnare(data, samples, bt + beat * 0.5, 0.55)
        addSnare(data, samples, bt + beat * 1.5, 0.55)
        addSnare(data, samples, bt + beat * 2.5, 0.55)
        addSnare(data, samples, bt + beat * 3.5, 0.55)
        -- Dissonant lead / power chord stab
        addStab(data, samples, {root * 2, root * 2 * 1.498, root * 4}, bt, barDur * 0.5, 0.18)
        addNote(data, samples, root * 4, bt + 2.5 * beat, beat * 1.5, 0.14, "saw", 0.005, 0.2)
    end
    applyPumping(data, samples, kickTimes, 0.08, 0.5)
    local src = love.audio.newSource(data); src:setLooping(true); src:setVolume(0.72); return src
end

local function buildLofi()
    local beat = 60 / 80
    local barDur = beat * 4
    local bars = 8
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    local chords = {
        {N.F3, N.A3, N.C4, N.E4},
        {N.Dm and N.D3 or N.D3, N.F3, N.A3, N.C4},
        {N.Bb2, N.D3, N.F3, N.A3},
        {N.C3, N.E3, N.G3, N.Bb3},
        {N.F3, N.A3, N.C4, N.E4},
        {N.D3, N.F3, N.A3, N.C4},
        {N.G2, N.Bb2, N.D3, N.F3},
        {N.C3, N.E3, N.G3, N.Bb3},
    }
    local kickTimes = {}
    for b = 1, bars do
        local bt = (b - 1) * barDur
        addPad(data, samples, chords[b], bt, barDur, 0.11)
        -- Walking bass
        addBass(data, samples, chords[b][1] * 0.5, bt,              beat * 0.95, 0.14)
        addBass(data, samples, chords[b][2] * 0.5, bt + beat,       beat * 0.95, 0.12)
        addBass(data, samples, chords[b][3] * 0.5, bt + 2 * beat,   beat * 0.95, 0.12)
        addBass(data, samples, chords[b][2] * 0.5, bt + 3 * beat,   beat * 0.95, 0.12)
        -- Soft kick/snare
        addKick(data, samples, bt, 0.28);            table.insert(kickTimes, bt)
        addKick(data, samples, bt + 2 * beat, 0.28); table.insert(kickTimes, bt + 2 * beat)
        addSnare(data, samples, bt + beat, 0.22)
        addSnare(data, samples, bt + 3 * beat, 0.22)
        for i = 0, 7 do addHat(data, samples, bt + i * (beat / 2), 0.06, false) end
        -- Dreamy lead (sparse)
        if b % 2 == 1 then
            addNote(data, samples, chords[b][4] * 2, bt + beat * 2, beat * 2, 0.08, "sine", 0.08, 0.3)
        end
    end
    -- Vinyl crackle
    for i = 0, math.floor(total * 30) do
        local idx = math.random(0, samples - 1)
        local cur = data:getSample(idx)
        data:setSample(idx, math.max(-1, math.min(1, cur + (math.random() - 0.5) * 0.04)))
    end
    applyPumping(data, samples, kickTimes, 0.18, 0.18)
    local src = love.audio.newSource(data); src:setLooping(true); src:setVolume(0.6); return src
end

local function buildWhisperwaveCool()
    -- Playable cool version of Whisperwave: ambient ethereal track with slow beat,
    -- detuned pads, echoey lead melody in natural minor, sub bass, ghost whispers.
    local beat = 60 / 85
    local barDur = beat * 4
    local bars = 8
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    -- A minor chord progression: Am - Fmaj7 - Dm - Em
    local chords = {
        {N.A2, N.C3, N.E3, N.A3},
        {N.A2, N.C3, N.E3, N.A3},
        {N.F2, N.A2, N.C3, N.E3},
        {N.F2, N.A2, N.C3, N.E3},
        {N.D2, N.F2, N.A2, N.D3},
        {N.D2, N.F2, N.A2, N.D3},
        {N.E2, N.G2, N.B2, N.E3},
        {N.E2, N.G2, N.B2, N.E3},
    }
    local melody = {N.E4, N.G4, N.A4, N.E4, N.F4, N.A4, N.C5, N.B4}
    local kickTimes = {}
    for b = 1, bars do
        local bt = (b - 1) * barDur
        -- Slow ethereal pad with detune
        addPad(data, samples, chords[b], bt, barDur, 0.14)
        addPad(data, samples, {chords[b][1] * 0.5}, bt, barDur, 0.12)
        -- Deep sub bass on 1 and 3
        addBass(data, samples, chords[b][1] * 0.5, bt, beat * 1.8, 0.16)
        addBass(data, samples, chords[b][1] * 0.5, bt + 2 * beat, beat * 1.8, 0.16)
        -- Gentle beat
        addKick(data, samples, bt, 0.35); table.insert(kickTimes, bt)
        addKick(data, samples, bt + 2 * beat, 0.35); table.insert(kickTimes, bt + 2 * beat)
        addSnare(data, samples, bt + beat, 0.18)
        addSnare(data, samples, bt + 3 * beat, 0.18)
        for i = 0, 7 do addHat(data, samples, bt + i * (beat / 2), 0.05, i == 7) end
        -- Echoey lead melody (main + 2 delayed echoes)
        local note = melody[b]
        addNote(data, samples, note * 2, bt + beat * 0.5, beat * 1.8, 0.10, "sine", 0.05, 0.3)
        addNote(data, samples, note * 2, bt + beat * 0.5 + 0.25, beat * 1.6, 0.06, "sine", 0.05, 0.25)
        addNote(data, samples, note * 2, bt + beat * 0.5 + 0.50, beat * 1.4, 0.035, "sine", 0.05, 0.2)
        -- Shimmery octave-up harmony every other bar
        if b % 2 == 0 then
            addNote(data, samples, note * 4, bt + beat * 2, beat * 2, 0.04, "triangle", 0.15, 0.5)
        end
        -- Ghostly high whisper bursts
        for i = 1, 3 do
            local wt = bt + math.random() * barDur
            local wf = 1400 + math.random() * 1600
            addNote(data, samples, wf, wt, 0.3 + math.random() * 0.4, 0.025, "sine", 0.08, 0.15)
        end
    end
    -- Gentle sidechain pump
    applyPumping(data, samples, kickTimes, 0.15, 0.2)
    local src = love.audio.newSource(data); src:setLooping(true); src:setVolume(0.6); return src
end

-- Epic chilling take on Whisperwave: 26 bars with a slower burn into a
-- bigger climax than before. Structure:
--   1-5   : ambient intro (pads + sub drone, no drums)
--   6-10  : slow tribal kick arrives, main lead eases in
--   11-15 : choir counter-melody layers in, bass taiko doubles
--   16-20 : tension — kicks heavier, snares on 2/4, ride picks up
--   21-22 : pre-climax riser — swelling sub, rising whispers
--   23-25 : EPIC FINALE — double-time kicks, triple-octave lead stack,
--           thunder 27Hz hits, choir wall, every instrument at full
--   26    : resolution — pads ring out into the loop point
-- Unlisted in the playlist UI — accessible from the sound debug menu only.
local function buildWhisperwaveEpic()
    local beat = 60 / 66
    local barDur = beat * 4
    local bars = 26
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    -- Progression (26 bars)
    local progression = {
        {N.A2, N.C3, N.E3, N.A3},   -- 1  intro Am
        {N.A2, N.C3, N.E3, N.A3},   -- 2
        {N.F2, N.A2, N.C3, N.E3},   -- 3
        {N.F2, N.A2, N.C3, N.E3},   -- 4
        {N.A2, N.C3, N.E3, N.A3},   -- 5
        {N.A2, N.C3, N.E3, N.A3},   -- 6  kick enters
        {N.F2, N.A2, N.C3, N.E3},   -- 7
        {N.D2, N.F2, N.A2, N.D3},   -- 8
        {N.D2, N.F2, N.A2, N.D3},   -- 9
        {N.E2, N.G2, N.B2, N.E3},   -- 10
        {N.A2, N.C3, N.E3, N.A3},   -- 11 choir enters
        {N.F2, N.A2, N.C3, N.E3},   -- 12
        {N.D2, N.F2, N.A2, N.D3},   -- 13
        {N.E2, N.G2, N.B2, N.E3},   -- 14
        {N.A2, N.C3, N.E3, N.A3},   -- 15
        {N.F2, N.A2, N.C3, N.E3},   -- 16 tension
        {N.D2, N.F2, N.A2, N.D3},   -- 17
        {N.D2, N.F2, N.A2, N.D3},   -- 18
        {N.E2, N.G2, N.B2, N.E3},   -- 19
        {N.E2, N.G2, N.B2, N.E3},   -- 20
        {N.F2, N.A2, N.C3, N.E3},   -- 21 riser
        {N.E2, N.G2, N.B2, N.E3},   -- 22
        {N.A2, N.C3, N.E3, N.A3},   -- 23 FINALE
        {N.F2, N.A2, N.C3, N.E3},   -- 24
        {N.D2, N.F2, N.A2, N.D3},   -- 25
        {N.A2, N.C3, N.E3, N.A3},   -- 26 resolution
    }
    -- Main lead motif — enters at bar 6, peaks bars 23-25 with octave climb
    local lead = {
        nil, nil, nil, nil, nil,            -- 1-5 silent intro
        N.E4, N.G4, N.A4, N.C5, N.A4,       -- 6-10 first phrase
        N.F4, N.E4, N.G4, N.A4, N.C5,       -- 11-15
        N.B4, N.A4, N.F4, N.G4, N.E4,       -- 16-20 descending tension
        N.A4, N.C5,                         -- 21-22 riser climb
        N.E5, N.G5, N.A5,                   -- 23-25 OCTAVE UP climax
        N.E5,                               -- 26 resolution
    }
    -- Choir counter-melody — enters bar 11
    local counter = {
        nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,       -- 1-10 silent
        N.A5, N.A5, N.C6, N.F5, N.A5,                            -- 11-15
        N.G5, N.E5, N.D5, N.E5, N.G5,                            -- 16-20
        N.A5, N.C6,                                              -- 21-22
        N.E6, N.G6, N.A6,                                        -- 23-25 finale
        N.A5,                                                    -- 26
    }
    local kickTimes = {}
    for b = 1, bars do
        local bt = (b - 1) * barDur
        local ch = progression[b]
        local isIntro  = b <= 5
        local isBuild  = b >= 16 and b <= 20
        local isRiser  = b == 21 or b == 22
        local isFinale = b >= 23 and b <= 25
        local isCoda   = b == 26
        -- Pad stack: low drone + mid chord + high shimmer.
        -- Intensity grows with section.
        local padMid  = isFinale and 0.26 or ((isBuild or isRiser) and 0.19 or 0.15)
        local padLow  = isFinale and 0.20 or ((isBuild or isRiser) and 0.14 or 0.12)
        local padHigh = isFinale and 0.14 or ((isBuild or isRiser) and 0.08 or 0.06)
        addPad(data, samples, ch, bt, barDur, padMid)
        addPad(data, samples, {ch[1] * 0.5, ch[2] * 0.5}, bt, barDur, padLow)
        addPad(data, samples, {ch[3] * 2, ch[4] * 2}, bt, barDur, padHigh)
        -- Taiko bass
        if not isIntro then
            local bassAmp = isFinale and 0.34 or ((isBuild or isRiser) and 0.26 or 0.2)
            addBass(data, samples, ch[1] * 0.5, bt, beat * 1.8, bassAmp)
            addBass(data, samples, ch[1] * 0.5, bt + 2 * beat, beat * 1.8, bassAmp)
            if isBuild or isRiser or isFinale then
                addBass(data, samples, ch[1] * 0.5, bt + 3 * beat, beat * 0.9, bassAmp * 0.7)
            end
        end
        -- Tribal kick pattern
        if not isIntro then
            local kickAmp = isFinale and 0.65 or ((isBuild or isRiser) and 0.45 or 0.3)
            addKick(data, samples, bt, kickAmp); table.insert(kickTimes, bt)
            addKick(data, samples, bt + 2 * beat, kickAmp * 0.9)
            table.insert(kickTimes, bt + 2 * beat)
            -- Riser: extra kick on beat 4 to push momentum
            if isRiser then
                addKick(data, samples, bt + 3 * beat, kickAmp * 0.85)
                table.insert(kickTimes, bt + 3 * beat)
            end
            -- Finale: DOUBLE-TIME kicks — 8 hits per bar for the climax
            if isFinale then
                for i = 1, 7 do
                    addKick(data, samples, bt + i * (beat / 2), kickAmp * (0.7 + (i % 2) * 0.15))
                    table.insert(kickTimes, bt + i * (beat / 2))
                end
            end
        end
        -- Hats: sparse from bar 6, denser through the build + finale
        if b >= 6 and not isCoda then
            local hatSlots = isFinale and 16 or ((isBuild or isRiser) and 8 or 4)
            for i = 0, hatSlots - 1 do
                addHat(data, samples, bt + i * (barDur / hatSlots),
                    isFinale and 0.08 or 0.04, (i % math.max(1, hatSlots / 2)) == (hatSlots / 2 - 1))
            end
        end
        -- Snare/clap accents on 2 and 4 during build + riser + finale
        if isBuild or isRiser or isFinale then
            local sAmp = isFinale and 0.3 or 0.2
            addSnare(data, samples, bt + beat, sAmp)
            addSnare(data, samples, bt + 3 * beat, sAmp)
            -- Finale: extra snare rolls on 2.5 + 4.5
            if isFinale then
                addSnare(data, samples, bt + beat * 1.5, 0.2)
                addSnare(data, samples, bt + beat * 3.5, 0.2)
            end
        end
        -- Main lead
        local note = lead[b]
        if note then
            local leadAmp = isFinale and 0.18 or ((isBuild or isRiser) and 0.12 or 0.09)
            addNote(data, samples, note, bt + beat * 0.5, beat * 2.5, leadAmp, "triangle", 0.1, 0.5)
            addNote(data, samples, note, bt + beat * 0.5 + 0.35, beat * 2.0, leadAmp * 0.6, "sine", 0.1, 0.4)
            addNote(data, samples, note, bt + beat * 0.5 + 0.70, beat * 1.6, leadAmp * 0.35, "sine", 0.1, 0.3)
            -- Finale: TRIPLE-octave stack for grandeur
            if isFinale then
                addNote(data, samples, note * 2, bt + beat * 0.5, beat * 3, 0.09, "triangle", 0.1, 0.5)
                addNote(data, samples, note * 4, bt + beat * 0.5, beat * 3, 0.04, "sine", 0.1, 0.5)
                addNote(data, samples, note * 0.5, bt + beat * 0.5, beat * 3, 0.06, "sine", 0.1, 0.5)
            end
        end
        -- Choir counter-melody
        local cnote = counter[b]
        if cnote then
            local cAmp = isFinale and 0.16 or ((isBuild or isRiser) and 0.1 or 0.07)
            addNote(data, samples, cnote, bt, beat * 4, cAmp, "sine", 0.2, 0.6)
            addNote(data, samples, cnote * 2, bt, beat * 4, cAmp * 0.4, "sine", 0.25, 0.5)
            if isFinale then
                addNote(data, samples, cnote * 0.5, bt, beat * 4, cAmp * 0.5, "sine", 0.25, 0.5)
            end
        end
        -- Ghost whispers — quiet intro, much more during finale
        local whisperCount = isFinale and 10 or (isRiser and 7 or (isBuild and 5 or (b >= 6 and 3 or 2)))
        for i = 1, whisperCount do
            local wt = bt + math.random() * barDur
            local wf = 1600 + math.random() * 2400
            addNote(data, samples, wf, wt, 0.4 + math.random() * 0.5, 0.025, "sine", 0.08, 0.18)
        end
        -- Riser: rising sub-pulse that sweeps from low to high across bars
        if isRiser then
            local localT = (b - 21) / 2  -- 0..1 across the two riser bars
            local riseStart = 27.5 * (1 + localT * 2)
            addNote(data, samples, riseStart, bt, barDur, 0.14, "saw", 0.05, 0.2)
        end
        -- Thunder-low hits EVERY kick in the finale
        if isFinale then
            addBass(data, samples, 27.5, bt, beat * 1.0, 0.35)
            addBass(data, samples, 27.5, bt + 2 * beat, beat * 1.0, 0.35)
            -- Overdriven saw stab on beat 1 for epic flavor
            addNote(data, samples, ch[1], bt, beat * 0.4, 0.18, "saw", 0.02, 0.15)
        end
        -- Resolution bar 20 — only pad + lead tail + silent drums for breathing
        if isCoda then
            addNote(data, samples, ch[1], bt, beat * 4, 0.18, "triangle", 0.2, 0.8)
            addNote(data, samples, ch[3], bt, beat * 4, 0.12, "sine", 0.2, 0.8)
        end
    end
    -- Sidechain pump so the kicks punch through the pad wall
    applyPumping(data, samples, kickTimes, 0.2, 0.22)
    local src = love.audio.newSource(data); src:setLooping(true); src:setVolume(0.65); return src
end

local function buildVapor()
    local beat = 60 / 70
    local barDur = beat * 4
    local bars = 6
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    local chords = {
        {N.F3, N.A3, N.C4},
        {N.C3, N.E3, N.G3},
        {N.D3, N.F3, N.A3},
        {N.A2, N.C3, N.E3},
        {N.F3, N.A3, N.C4},
        {N.G2, N.B2, N.D3},
    }
    for b = 1, bars do
        local bt = (b - 1) * barDur
        addPad(data, samples, chords[b], bt, barDur, 0.14)
        addPad(data, samples, {chords[b][1] * 0.5}, bt, barDur, 0.12)
        -- Very slow hat
        for i = 0, 3 do addHat(data, samples, bt + i * beat, 0.05, true) end
        addKick(data, samples, bt, 0.18)
        addKick(data, samples, bt + 2 * beat, 0.18)
        -- Shimmer
        if b % 2 == 0 then
            addNote(data, samples, chords[b][3] * 2, bt + beat, beat * 3, 0.05, "sine", 0.3, 0.6)
        end
    end
    local src = love.audio.newSource(data); src:setLooping(true); src:setVolume(0.55); return src
end

-- VoidSea music: a chaotic-yet-beautiful pulsing drone for the descent.
local function buildVoidseaMusic()
    local total = 24.0
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)

    -- Sub drone that pulses like a slow heartbeat
    for t0 = 0, total - 0.01, 1.2 do
        addNote(data, samples, 41, t0, 1.1, 0.28, "sine", 0.2, 0.5)
        addNote(data, samples, 55, t0, 1.1, 0.18, "sine", 0.3, 0.6)
    end

    -- Evolving pad clusters in a consonant/dissonant interplay
    local clusters = {
        {110, 146.83, 164.81, 220},             -- A minor-ish
        {110, 138.59, 164.81, 220 * 1.06},      -- dissonant shift
        {103.83, 130.81, 174.61, 207.65},       -- another cluster
        {110, 146.83, 185.0, 220},              -- returning to center
        {98,   130.81, 164.81, 196},            -- G minor
        {110, 146.83, 164.81, 220},             -- home
    }
    for i = 0, 11 do
        local c = clusters[(i % #clusters) + 1]
        addPad(data, samples, c, i * 2, 2.2, 0.09)
    end

    -- Shimmering high bell notes (beauty)
    local pent = {440, 523.25, 587.33, 659.25, 783.99, 880}
    for i = 1, 22 do
        local t0 = math.random() * (total - 2)
        local f = pent[math.random(#pent)] * (math.random() < 0.5 and 1 or 2)
        addNote(data, samples, f, t0, 1.0 + math.random() * 1.5, 0.06, "sine", 0.1, 0.8)
    end

    -- Glitchy dissonant chirps (chaos)
    for i = 1, 34 do
        local t0 = math.random() * (total - 0.5)
        local f = 600 + math.random() * 2600
        addNote(data, samples, f, t0, 0.18 + math.random() * 0.4, 0.045, "square", 0.02, 0.15)
    end
    -- Pulsing chaotic noise bursts — grain of fear
    for t0 = 0, total - 0.01, 0.4 + math.random() * 0.6 do
        local dur = 0.08 + math.random() * 0.2
        local s0 = math.floor(t0 * rate)
        local sN = math.floor(dur * rate)
        for i = 0, sN - 1 do
            local idx = s0 + i
            if idx < samples then
                local env = math.min(1, (i / rate) / 0.01) * math.max(0, 1 - (i / rate) / dur) ^ 1.2
                local s = (math.random() * 2 - 1) * 0.14 * env
                mixAdd(data, samples, idx, s)
            end
        end
    end

    -- Heartbeat kicks
    for t0 = 0, total - 0.01, 2.4 do
        addKick(data, samples, t0, 0.3)
        addKick(data, samples, t0 + 0.22, 0.2)
    end

    -- Gentle saw pulses on the 2nd half of each bar
    for t0 = 0, total - 0.01, 2.4 do
        addNote(data, samples, 82.41, t0 + 1.2, 1.0, 0.1, "saw", 0.1, 0.4)
    end

    local src = love.audio.newSource(data)
    src:setLooping(true)
    src:setVolume(0.55)
    return src
end

-- ====== Extra themes ======
local function buildJazz()
    local beat = 60 / 100
    local barDur = beat * 4
    local bars = 8
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    local kickTimes = {}
    -- ii-V-I in Ab: Bbm7 Eb7 AbM7 ...
    local walking = {N.Ab2, N.Bb2, N.C3, N.Eb3, N.Ab2, N.Bb2, N.C3, N.Db3}
    local chords = {
        {N.Ab3, N.C4, N.Eb4, N.G4},
        {N.Bb3, N.Db4, N.F4, N.Ab4},
        {N.Eb3, N.G3, N.Bb3, N.Db4},
        {N.Ab3, N.C4, N.Eb4, N.G4},
        {N.Ab3, N.C4, N.Eb4, N.G4},
        {N.Bb3, N.Db4, N.F4, N.Ab4},
        {N.Eb3, N.G3, N.Bb3, N.Db4},
        {N.Ab3, N.C4, N.Eb4, N.G4},
    }
    for b = 1, bars do
        local bt = (b - 1) * barDur
        addPad(data, samples, chords[b], bt, barDur, 0.07)
        for i = 1, 4 do
            addBass(data, samples, walking[((b - 1) * 4 + i - 1) % #walking + 1] * 0.5, bt + (i - 1) * beat, beat * 0.95, 0.18)
        end
        addKick(data, samples, bt, 0.3); table.insert(kickTimes, bt)
        addKick(data, samples, bt + 2 * beat, 0.3); table.insert(kickTimes, bt + 2 * beat)
        addSnare(data, samples, bt + beat, 0.18)
        addSnare(data, samples, bt + 3 * beat, 0.18)
        for i = 0, 7 do addHat(data, samples, bt + i * (beat / 2), 0.05, i == 5) end
        -- Sparse lead pentatonic
        local lead = {chords[b][1] * 2, chords[b][3] * 2, chords[b][2] * 2, chords[b][4] * 2}
        for i = 1, 4 do
            addNote(data, samples, lead[i], bt + (i - 1) * beat + 0.2, beat * 0.7, 0.08, "triangle", 0.02, 0.2)
        end
    end
    applyPumping(data, samples, kickTimes, 0.18, 0.15)
    local src = love.audio.newSource(data); src:setLooping(true); src:setVolume(0.55); return src
end

local function buildDrumNBass()
    local beat = 60 / 174
    local sixteenth = beat / 4
    local barDur = beat * 4
    local bars = 8
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    local kickTimes = {}
    -- A-minor pentatonic melody riff over 8 bars. Each bar gets a 16-step pattern
    -- of indices into the scale; 0 means rest.
    local scale = {N.A4, N.C5, N.D5, N.E5, N.G5, N.A5, N.C6}
    local melodyPatterns = {
        -- bar 1: statement
        {1, 0, 3, 0, 5, 0, 4, 3, 1, 0, 3, 5, 4, 0, 3, 0},
        -- bar 2: answer (lifts)
        {1, 0, 3, 0, 5, 0, 6, 5, 4, 0, 5, 6, 5, 4, 3, 0},
        -- bar 3: drop lower, syncopated
        {1, 2, 3, 0, 4, 3, 0, 5, 4, 0, 3, 0, 2, 3, 0, 0},
        -- bar 4: fill up into bar 5
        {0, 3, 5, 4, 3, 5, 6, 5, 7, 6, 5, 4, 3, 5, 6, 7},
        -- bar 5: restate with octave jump at the end
        {1, 0, 3, 0, 5, 0, 4, 3, 1, 0, 3, 5, 4, 0, 6, 7},
        -- bar 6: sparse, tense
        {0, 0, 5, 0, 0, 4, 0, 3, 0, 5, 0, 0, 4, 3, 0, 0},
        -- bar 7: climbing
        {1, 3, 4, 5, 3, 4, 5, 6, 4, 5, 6, 7, 5, 6, 7, 6},
        -- bar 8: resolving call-back
        {7, 5, 4, 3, 5, 4, 3, 1, 3, 4, 5, 3, 1, 0, 1, 0},
    }
    for b = 1, bars do
        local bt = (b - 1) * barDur
        -- Amen-ish break
        addKick(data, samples, bt, 0.7); table.insert(kickTimes, bt)
        addKick(data, samples, bt + 2.5 * beat, 0.65); table.insert(kickTimes, bt + 2.5 * beat)
        addKick(data, samples, bt + 3.75 * beat, 0.4)
        addSnare(data, samples, bt + beat, 0.55)
        addSnare(data, samples, bt + 3 * beat, 0.55)
        addSnare(data, samples, bt + 2.25 * beat, 0.3)
        for i = 0, 15 do
            addHat(data, samples, bt + i * sixteenth, 0.08, i % 8 == 7)
        end
        -- Sub bass rolling 8ths
        local root = (b % 2 == 0) and N.A1 or N.C2 * 0.5
        for i = 0, 7 do
            addAcid(data, samples, root, bt + i * (beat / 2), (beat / 2) * 0.95, 0.22, 0.7)
        end
        -- Zooming reese pad
        addPad(data, samples, {root * 2, root * 2 * 1.006, root * 2 * 1.5}, bt, barDur, 0.08)
        -- MELODY — sharp pulse lead cutting over the break
        local pat = melodyPatterns[b]
        for i = 1, 16 do
            local idx = pat[i]
            if idx > 0 then
                local f = scale[idx]
                addNote(data, samples, f, bt + (i - 1) * sixteenth, sixteenth * 0.88, 0.13, "pulse", 0.003, 0.04)
                -- Thin saw harmony an octave down for body
                addNote(data, samples, f * 0.5, bt + (i - 1) * sixteenth, sixteenth * 0.85, 0.06, "saw", 0.003, 0.04)
            end
        end
        -- Occasional echo of the melody note on the off-beat (delayed by an 8th)
        for i = 1, 16, 4 do
            local idx = pat[i]
            if idx > 0 then
                addNote(data, samples, scale[idx] * 2, bt + (i - 1) * sixteenth + sixteenth * 2,
                    sixteenth * 1.2, 0.05, "triangle", 0.05, 0.25)
            end
        end
    end
    applyPumping(data, samples, kickTimes, 0.1, 0.4)
    local src = love.audio.newSource(data); src:setLooping(true); src:setVolume(0.7); return src
end

local function buildChoir()
    local total = 18.0
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    -- Sacred choir chord pads, shifting through minor plagal motion
    local progression = {
        {N.A3, N.C4, N.E4},
        {N.F3, N.A3, N.C4},
        {N.D3, N.F3, N.A3},
        {N.E3, N.G3, N.B3},
        {N.A3, N.C4, N.E4},
        {N.D3, N.F3, N.A3},
    }
    for i, chord in ipairs(progression) do
        local t0 = (i - 1) * (total / #progression)
        local dur = total / #progression + 0.1
        addPad(data, samples, chord, t0, dur, 0.12)
        addPad(data, samples, {chord[1] * 0.5, chord[2] * 0.5}, t0, dur, 0.10)
        -- Singing top note
        addNote(data, samples, chord[1] * 2, t0 + 0.3, dur - 0.2, 0.08, "sine", 0.3, 0.6)
        addNote(data, samples, chord[3] * 2, t0 + 0.6, dur - 0.4, 0.06, "sine", 0.4, 0.6)
    end
    -- Distant dread kick heartbeat
    for t0 = 0, total - 0.1, 2 do
        addKick(data, samples, t0, 0.22)
    end
    local src = love.audio.newSource(data); src:setLooping(true); src:setVolume(0.6); return src
end

local function buildArcade()
    local beat = 60 / 170
    local sixteenth = beat / 4
    local barDur = beat * 4
    local bars = 8
    local total = barDur * bars
    local samples = math.floor(rate * total)
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    local scale = {N.C4, N.D4, N.E4, N.G4, N.A4, N.C5, N.D5, N.E5, N.G5}
    -- Frantic 8-bit melodic arp
    local pat = {1, 3, 5, 3, 6, 4, 7, 5, 8, 6, 4, 3, 5, 7, 9, 7}
    for b = 1, bars do
        local bt = (b - 1) * barDur
        -- Fast square bass root hopping
        for i = 0, 15 do
            local f = (i % 4 < 2) and N.C3 or N.E3
            if i > 7 and b % 2 == 0 then f = N.F3 end
            addNote(data, samples, f, bt + i * sixteenth, sixteenth * 0.9, 0.16, "square", 0.002, 0.02)
        end
        -- Pulse arp
        for i = 1, 16 do
            local f = scale[((pat[i] - 1) % #scale) + 1]
            addNote(data, samples, f, bt + (i - 1) * sixteenth, sixteenth * 0.85, 0.12, "pulse", 0.002, 0.015)
        end
        -- Snappy noise drums
        for i = 0, 3 do
            addKick(data, samples, bt + i * beat, 0.35)
            addSnare(data, samples, bt + i * beat + beat * 0.5, 0.13)
        end
    end
    local src = love.audio.newSource(data); src:setLooping(true); src:setVolume(0.6); return src
end

function Audio:load()
    self.sfx = {
        shoot = tone(880, 0.08, 0.2, "square"),
        shoot2 = tone(660, 0.12, 0.22, "saw"),
        hit = tone(220, 0.1, 0.3, "noise"),
        enemyHit = tone(140, 0.08, 0.25, "square"),
        kill = tone(440, 0.15, 0.3, "triangle"),
        hurt = tone(180, 0.2, 0.35, "saw"),
        card = chord({523, 659, 784}, 0.4, 0.3, "sine"),
        wave = chord({392, 523, 659, 784}, 0.6, 0.3, "triangle"),
        victory = chord({523, 659, 784, 1047}, 1.2, 0.35, "sine"),
        defeat = chord({220, 196, 174, 146}, 1.0, 0.35, "saw"),
        boss = chord({110, 138, 164}, 0.8, 0.4, "saw"),
        dash = tone(1200, 0.12, 0.2, "sine"),
        explode = tone(80, 0.3, 0.4, "noise"),
        select = tone(1047, 0.06, 0.2, "sine"),
        whisper = tone(2400, 0.35, 0.08, "sine"),
        eldritch = chord({55, 58, 61, 67}, 0.9, 0.3, "saw"),
        cthulhu = chord({27.5, 32, 37, 41}, 2.0, 0.5, "saw"),
        glitch = tone(440, 0.05, 0.3, "noise"),
    }
    self.bossMusic = buildBossMusic()
    self.eldritchMusic = buildEldritchMusic()
    self.voidseaMusic = buildVoidseaMusic()

    -- Theme registry (main-run music). Lazily built on first selection.
    self.themeBuilders = {
        default        = buildNormalMusic,
        synthwave      = buildSynthwave,
        chiptune       = buildChiptune,
        doom           = buildDoom,
        lofi           = buildLofi,
        vapor          = buildVapor,
        eldritch_theme = buildWhisperwaveCool,
        whisperwave_epic = buildWhisperwaveEpic,
        jazz           = buildJazz,
        drumnbass      = buildDrumNBass,
        choir          = buildChoir,
        arcade         = buildArcade,
    }
    self.themes = {}
    self.currentThemeId = "default"
    self.music = self:getThemeSource("default")
end

function Audio:getThemeSource(id)
    if not self.themes[id] then
        local builder = self.themeBuilders[id]
        if not builder then builder = self.themeBuilders.default end
        self.themes[id] = builder()
    end
    return self.themes[id]
end

function Audio:setTheme(id)
    if id == self.currentThemeId then return end
    self.currentThemeId = id
    local wasPlaying = self.music and self.music:isPlaying()
    if self.music then self.music:stop() end
    self.music = self:getThemeSource(id)
    self:applyVolumes()
    if wasPlaying then self.music:play() end
end

function Audio:play(name)
    local d = self.sfx[name]
    if not d then return end
    local src = love.audio.newSource(d)
    src:setVolume(0.8 * self.masterVol * self.sfxVol)
    src:play()
end

function Audio:playMusic(which)
    which = which or "normal"
    -- "darkened": play the current theme with pitch shifted down — slower +
    -- lower. If the theme is already the eldritch one, drop pitch further so
    -- the notes feel roughly twice as long.
    if which == "darkened" then
        if self.bossMusic then self.bossMusic:stop() end
        if self.eldritchMusic then self.eldritchMusic:stop() end
        if self.voidseaMusic then self.voidseaMusic:stop() end
        if self.music then
            -- Whisperwave stays at full speed — it's already the eldritch
            -- track. Other themes get pitched down for that warped eerie
            -- take on your own playlist.
            local pitch = (self.currentThemeId == "eldritch_theme") and 1.0 or 0.72
            self.music:setPitch(pitch)
            if not self.music:isPlaying() then self.music:play() end
        end
        return
    end
    -- Any non-darkened transition resets the main theme's pitch.
    if self.music then self.music:setPitch(1.0) end
    local tracks = {normal = self.music, boss = self.bossMusic, eldritch = self.eldritchMusic, voidsea = self.voidseaMusic}
    local target = tracks[which]
    if target and target:isPlaying() then return end
    for _, t in pairs(tracks) do if t then t:stop() end end
    if target then target:play() end
end

function Audio:stopMusic()
    if self.music then self.music:stop() end
    if self.bossMusic then self.bossMusic:stop() end
    if self.eldritchMusic then self.eldritchMusic:stop() end
    if self.voidseaMusic then self.voidseaMusic:stop() end
end

return Audio
