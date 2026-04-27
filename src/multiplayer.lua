-- Multiplayer: portal-backed lobby + peer presence using the
-- [[LOVEWEB_NET]]<verb> magic-print protocol. The portal runtime writes
-- response and event files into __loveweb__/net/, which we poll once per
-- frame. On desktop LÖVE (no portal) those files don't exist so MP
-- gracefully sits in offline mode and the lobby UI says so.

local Cosmetics = require("src.cosmetics")

local MP = {}

-- ============================================================
-- Catalog
-- ============================================================
MP.MODES = {
    {id = "last_stand", name = "LAST STAND",
        desc = "Die once and you spectate. Last crab standing wins."},
    {id = "rally",      name = "RALLY",
        desc = "Downed crabs become ghosts. Stand on one and hold R to revive them."},
    {id = "endless",    name = "RESPAWN",
        desc = "Respawn after 10s. The run still ends if every crab is down at once."},
}

function MP.modeById(id)
    for _, m in ipairs(MP.MODES) do if m.id == id then return m end end
    return MP.MODES[1]
end

MP.RESPAWN_TIME = 10.0
MP.REVIVE_HOLD  = 2.0
MP.PVP_FACTOR   = 0.25
MP.POS_TICK     = 0.45  -- ~2.2 Hz, well below the 12/s rate cap
MP.PEER_TIMEOUT = 18.0
MP.MIN_CAP      = 2
MP.MAX_CAP      = 8

-- ============================================================
-- Live state
-- ============================================================
MP.connected   = false   -- portal infrastructure detected
MP.probed      = false   -- have we finished the on-boot detection grace?
MP.enabled     = false   -- in a room and using MP for the live run
MP.localId     = nil
MP.localHandle = "Crab"
MP.lobby       = nil     -- {roomId, code, name, capacity, mode, pvp, difficulty, finalWave, phase}
MP.list        = nil
MP.peers       = {}
MP.events      = {}      -- short rolling text log shown in lobby
MP.chatLog     = {}      -- in-run chat history (only rendered while typing)
MP.selfBubble  = nil     -- our own ephemeral chat bubble {text, life, max}
MP.session     = nil     -- per-run state once a wave begins
MP._pendingSettings = nil
MP._lastPos     = 0
MP._lastList    = 0
MP._inboxLen    = 0
MP._connectGrace = 0

local NET = "__loveweb__/net"

-- ============================================================
-- Tiny JSON encoder/decoder (sufficient for the portal payloads
-- we send and receive — no nested unicode escapes required).
-- ============================================================
local function escStr(s)
    return (s:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t"))
end

local function enc(v)
    local t = type(v)
    if t == "nil" then return "null"
    elseif t == "boolean" then return v and "true" or "false"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "0" end
        return tostring(v)
    elseif t == "string" then return "\"" .. escStr(v) .. "\""
    elseif t == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        local arr = (n > 0 and #v == n)
        if arr then
            local out = {}
            for i, x in ipairs(v) do out[i] = enc(x) end
            return "[" .. table.concat(out, ",") .. "]"
        else
            local out = {}
            for k, x in pairs(v) do out[#out+1] = "\"" .. escStr(tostring(k)) .. "\":" .. enc(x) end
            return "{" .. table.concat(out, ",") .. "}"
        end
    end
    return "null"
end

local dec
local function skip(s, i)
    while i <= #s do
        local c = s:byte(i)
        if c == 32 or c == 9 or c == 10 or c == 13 then i = i + 1 else break end
    end
    return i
end

local function decStr(s, i)
    i = i + 1
    local out = {}
    while i <= #s do
        local c = s:sub(i, i)
        if c == "\\" then
            local esc = s:sub(i + 1, i + 1)
            if esc == "n" then out[#out + 1] = "\n"
            elseif esc == "t" then out[#out + 1] = "\t"
            elseif esc == "\"" then out[#out + 1] = "\""
            elseif esc == "\\" then out[#out + 1] = "\\"
            elseif esc == "/" then out[#out + 1] = "/"
            elseif esc == "u" then i = i + 4; out[#out + 1] = "?"
            else out[#out + 1] = esc end
            i = i + 2
        elseif c == "\"" then
            return table.concat(out), i + 1
        else
            out[#out + 1] = c; i = i + 1
        end
    end
    return table.concat(out), i
end

local function decNum(s, i)
    local j = i
    while i <= #s and s:sub(i, i):match("[%-%d%.eE+]") do i = i + 1 end
    return tonumber(s:sub(j, i - 1)), i
end

dec = function(s, i)
    i = skip(s, i)
    if i > #s then return nil, i end
    local c = s:sub(i, i)
    if c == "{" then
        local out = {}
        i = i + 1
        i = skip(s, i)
        if s:sub(i, i) == "}" then return out, i + 1 end
        while i <= #s do
            i = skip(s, i)
            local k; k, i = decStr(s, i)
            i = skip(s, i)
            if s:sub(i, i) == ":" then i = i + 1 end
            local v; v, i = dec(s, i)
            out[k] = v
            i = skip(s, i)
            local cc = s:sub(i, i)
            if cc == "," then i = i + 1
            elseif cc == "}" then return out, i + 1
            else return out, i end
        end
        return out, i
    elseif c == "[" then
        local out = {}
        i = i + 1
        i = skip(s, i)
        if s:sub(i, i) == "]" then return out, i + 1 end
        while i <= #s do
            local v; v, i = dec(s, i)
            out[#out + 1] = v
            i = skip(s, i)
            local cc = s:sub(i, i)
            if cc == "," then i = i + 1
            elseif cc == "]" then return out, i + 1
            else return out, i end
        end
        return out, i
    elseif c == "\"" then return decStr(s, i)
    elseif c == "t" then return true, i + 4
    elseif c == "f" then return false, i + 5
    elseif c == "n" then return nil, i + 4
    else return decNum(s, i) end
end

local function parseJson(s)
    if not s or s == "" then return nil end
    local ok, v = pcall(dec, s, 1)
    if ok then return v end
    return nil
end

-- ============================================================
-- Magic-print primitives. We always emit during the boot grace
-- window so the portal can actually receive create/join verbs even
-- before its first response file has materialised. Only AFTER we've
-- conclusively determined we're running on desktop LÖVE (probed=true
-- and still no net dir) do we silence subsequent emits to keep the
-- terminal clean.
-- ============================================================
local function emit(line)
    if MP.probed and not MP.connected then return end
    print("[[LOVEWEB_NET]]" .. line)
end
local function emitSend(verb, payload)
    if MP.probed and not MP.connected then return end
    print("[[LOVEWEB_NET]]send " .. verb .. " " .. enc(payload or {}))
end

local function readJson(path)
    if not (love and love.filesystem and love.filesystem.getInfo) then return nil end
    if not love.filesystem.getInfo(path) then return nil end
    return parseJson(love.filesystem.read(path))
end

local function readText(path)
    if not (love and love.filesystem and love.filesystem.getInfo) then return nil end
    if not love.filesystem.getInfo(path) then return nil end
    return love.filesystem.read(path)
end

-- ============================================================
-- Portal detect & profile publishing
-- ============================================================
function MP.detect()
    if not (love and love.filesystem) then
        MP.probed = true
        MP.connected = false
        return false
    end
    -- Single-shot boot probe: poke the runtime so it materialises the
    -- net dir if it's there, then we'll re-check during MP.poll after a
    -- brief grace period and lock the verdict in MP.probed.
    if not MP.probed then
        print("[[LOVEWEB_NET]]list")
        MP._probeStart = love.timer.getTime()
    end
    MP.connected = love.filesystem.getInfo(NET) ~= nil
        or love.filesystem.getInfo(NET .. "/status.json") ~= nil
    return MP.connected
end

function MP.publishProfile(persist)
    persist = persist or {}
    local equipped = Cosmetics.equipped(persist)
    local handle = persist.mpHandle
    if not handle or handle == "" then
        local pool = {"Clawde", "Redshell", "Tidewalker", "Pinch", "Saltcrab",
            "Mythos", "Carcinus", "Chela", "Reefling", "Brackish"}
        handle = pool[(love.timer.getTime() * 7) % #pool + 1]
        persist.mpHandle = handle
    end
    MP.localHandle = handle
    local body = {
        cosmetics = equipped,
        handle = handle,
        eldritchMax = persist.eldritchMax or 0,
        wins = persist.totalWins or 0,
    }
    pcall(love.filesystem.write, "public_profile.json", enc(body))
end

-- ============================================================
-- Lobby actions (host-agnostic — every member can mutate state)
-- ============================================================
function MP.requestList()
    emit("list")
    MP._lastList = love.timer.getTime()
end

-- Locally-hidden room codes (loaded from persist on demand). The portal
-- has no public "delete room" verb, but for rooms the user created we can
-- still try a soft-delete by joining briefly and mutating state.deleted=1
-- before leaving, which lets every client that respects the flag drop the
-- ghost from its list. Either way, hidden codes are filtered out of this
-- client's lobby browser permanently.
MP.hidden = nil   -- { [code] = true }

local function loadHidden(persist)
    if MP.hidden then return MP.hidden end
    MP.hidden = {}
    local raw = (persist and persist.mpHiddenRooms) or ""
    for code in raw:gmatch("[^|]+") do
        MP.hidden[code:upper()] = true
    end
    return MP.hidden
end

local function saveHidden(persist)
    if not persist then return end
    local list = {}
    for code in pairs(MP.hidden or {}) do list[#list + 1] = code end
    persist.mpHiddenRooms = table.concat(list, "|")
    pcall(require("src.save").save, persist)
end

function MP.isHidden(code, persist)
    if not code then return false end
    loadHidden(persist)
    return MP.hidden[code:upper()] == true
end

-- Attempts a "soft delete" for a frozen lobby. Joins long enough to
-- mutate state.deleted=1 + state.phase="deleted" so other clients can
-- filter it out, then leaves. If the room is fully dead (5s timeout),
-- we still hide it locally so the user gets it out of their list.
function MP.deleteRoom(code, persist)
    if not code then return end
    code = code:upper()
    loadHidden(persist)
    MP.hidden[code] = true
    saveHidden(persist)
    -- Best-effort portal-side cleanup
    if MP.connected then
        emit("join " .. code)
        emit("state " .. enc({deleted = 1, phase = "deleted"}))
        emit("leave")
    end
    -- Drop from the in-memory list immediately
    if MP.list then
        for i = #MP.list, 1, -1 do
            if (MP.list[i].code or ""):upper() == code then
                table.remove(MP.list, i)
            end
        end
    end
end

function MP.create(name, opts)
    name = (name and name ~= "" and name) or "Crab Lobby"
    MP._pendingSettings = opts or {}
    -- Mark ourselves as the host. The host id rides in room.state so every
    -- joiner sees the same value, and the lobby UI uses it to gate the
    -- START button (only the host can launch).
    MP._pendingSettings.hostId = MP.localId or "self"
    MP._connectGrace = love.timer.getTime() + 6
    if opts and opts.private then
        emit("create unlisted " .. name)
    else
        emit("create lobby " .. name)
    end
end

-- Toggle the lobby's locked flag. Locked rooms are still visible to current
-- members but the lobby browser hides them, the JOIN button refuses, and a
-- code-join attempt sees locked=1 in room.state and bails back out.
function MP.setLocked(locked)
    if not MP.enabled then return end
    emit("state " .. enc({locked = locked and 1 or 0}))
    if MP.lobby then MP.lobby.locked = locked and true or false end
end

function MP.toggleLock()
    MP.setLocked(not (MP.lobby and MP.lobby.locked))
end

function MP.join(code)
    if not code or #code < 4 then return end
    MP._joinAt = love.timer.getTime()
    MP._joinError = nil
    MP._connectGrace = love.timer.getTime() + 6
    emit("join " .. code:upper())
end

function MP.leave()
    if MP.lobby then emit("leave") end
    MP.enabled = false
    MP.lobby = nil
    MP.peers = {}
    MP.events = {}
    MP.session = nil
    MP._pendingSettings = nil
    MP._inboxLen = 0
    MP._joinAt = nil
    MP._joinError = nil
end

-- Mark the room dead before leaving — used when a multiplayer run ends or
-- the player abandons. Other clients seeing state.deleted=1 filter it out
-- of their lobby browser. Combined with the leave verb the room ends up
-- with zero members and a deleted flag, which is the strongest cleanup
-- signal available without a portal-side delete verb.
function MP.endRoom()
    if MP.enabled then
        emit("state " .. enc({deleted = 1, phase = "ended"}))
    end
    MP.leave()
end

-- Mirror the desired lobby settings into the room's persistent state so
-- every joining client sees the same mode/pvp/difficulty/wave cap.
function MP.applyLobbySettings(t)
    t = t or {}
    local patch = {
        mode = t.mode or (MP.lobby and MP.lobby.mode) or "last_stand",
        pvp = (t.pvp == nil) and (MP.lobby and MP.lobby.pvp and 1 or 0) or (t.pvp and 1 or 0),
        difficulty = t.difficulty or (MP.lobby and MP.lobby.difficulty) or "normal",
        final_wave = t.finalWave or (MP.lobby and MP.lobby.finalWave) or 20,
        capacity = t.capacity or (MP.lobby and MP.lobby.capacity) or 4,
        host_id = t.hostId or (MP.lobby and MP.lobby.hostId) or MP.localId,
    }
    emit("state " .. enc(patch))
    if MP.lobby then
        MP.lobby.mode = patch.mode
        MP.lobby.pvp = patch.pvp == 1
        MP.lobby.difficulty = patch.difficulty
        MP.lobby.finalWave = patch.final_wave
        MP.lobby.capacity = patch.capacity
        MP.lobby.hostId = patch.host_id and tostring(patch.host_id) or MP.lobby.hostId
    end
end

-- Any member can flip this and broadcast — every client picks it up via
-- room.json and transitions into the wave together. Also locks the room
-- so the lobby browser hides it and new joiners bounce off.
function MP.startRun()
    local now = love.timer.getTime()
    emit("state " .. enc({phase = "wave", started_at = now, locked = 1}))
    if MP.lobby then
        MP.lobby.phase = "wave"
        MP.lobby.startedAt = now
        MP.lobby.locked = true
    end
end

-- ============================================================
-- Polling
-- ============================================================
function MP._handleEvent(evt)
    local v, p, from = evt.verb, evt.payload or {}, evt.userId
    if from ~= nil then from = tostring(from) end
    if not v then return end
    if from == MP.localId then return end
    -- Self may not be set yet; ignore self-echoes once we know our id
    local peer = from and MP.peers[from]
    if not peer and from then
        -- New peer we hadn't rostered yet — minimal stub so events apply
        peer = {
            handle = "Crab " .. tostring(from),
            x = 640, y = 360, dispX = 640, dispY = 360,
            hp = 100, max = 100, alive = true, deathTimer = 0,
            last = love.timer.getTime(),
        }
        MP.peers[from] = peer
    end
    if peer then peer.last = love.timer.getTime() end

    if v == "pos" and peer then
        peer.x = tonumber(p.x) or peer.x
        peer.y = tonumber(p.y) or peer.y
        peer.hp = tonumber(p.hp) or peer.hp
        peer.max = tonumber(p.max) or peer.max
        peer.alive = (p.alive == 1) or (p.alive == true) or (p.alive == nil and peer.alive)
        peer.angle = tonumber(p.a) or peer.angle or 0
        peer.wave = tonumber(p.w) or peer.wave
    elseif v == "dead" and peer then
        peer.alive = false
        peer.deathTimer = MP.RESPAWN_TIME
        table.insert(MP.events, peer.handle .. " is down")
    elseif v == "revive" then
        local tgt = p.target
        if tgt and MP.peers[tgt] then
            MP.peers[tgt].alive = true
            MP.peers[tgt].hp = math.max(MP.peers[tgt].max or 100, 1) * 0.5
            table.insert(MP.events, (peer and peer.handle or "?") .. " revived " .. MP.peers[tgt].handle)
        end
        if tgt == MP.localId and MP.session then
            MP.session.requestRevive = true
        end
    elseif v == "hit" then
        if p.target == MP.localId and MP.session then
            MP.session.incomingHit = (MP.session.incomingHit or 0) + (tonumber(p.dmg) or 0)
            MP.session.lastAttacker = from
        end
    elseif v == "cardpick" and peer then
        table.insert(MP.events, peer.handle .. " took " .. tostring(p.name or p.id or "a card"))
    elseif v == "wave" and peer then
        peer.wave = tonumber(p.w) or peer.wave
    elseif v == "mp_event" then
        -- Stash for game.lua to consume next frame. Each entry has a kind
        -- field the game.lua dispatcher uses to apply local FX + permanent
        -- effects (Ugnrak unlock, Void Sea unlock, King ending, etc.).
        MP.pendingEvents = MP.pendingEvents or {}
        p._from = from
        p._handle = peer and peer.handle or nil
        table.insert(MP.pendingEvents, p)
    elseif v == "chat" and peer then
        local msg = tostring(p.text or "")
        if #msg > 0 then
            if #msg > 120 then msg = msg:sub(1, 120) end
            peer.bubble = {text = msg, life = 4.5, max = 4.5}
            table.insert(MP.chatLog, {who = peer.handle, text = msg, t = love.timer.getTime()})
            while #MP.chatLog > 12 do table.remove(MP.chatLog, 1) end
        end
    end
    while #MP.events > 8 do table.remove(MP.events, 1) end
end

function MP.poll(dt)
    -- Boot-time probe: 5s grace for the portal to write any response file
    -- (last_result.json appears even before the first room is created).
    -- After the grace, lock as offline if nothing showed up. If portal
    -- files DO appear later (slow init), unlock and reconnect — emits
    -- start flowing again.
    local now = love.timer.getTime()
    local netExists = love.filesystem.getInfo(NET)
        or love.filesystem.getInfo(NET .. "/status.json")
        or love.filesystem.getInfo(NET .. "/last_result.json")
        or love.filesystem.getInfo("__loveweb__/identity.json")
    if not MP.probed then
        local started = MP._probeStart or now
        if netExists then
            MP.connected = true
            MP.probed = true
        elseif (now - started) > 5 then
            MP.connected = false
            MP.probed = true
        end
    elseif not MP.connected and netExists then
        MP.connected = true
    end
    if MP.probed and not MP.connected then return end

    -- Local identity: the portal writes signed-in user info to
    -- __loveweb__/identity.json. We use that to recognise ourselves in
    -- the roster. Always normalise to a string so comparisons against
    -- roster userIds (which are strings per the integration doc) match —
    -- otherwise a number/string mismatch makes the local user render
    -- as a fake peer with no fetched profile.
    if not MP.localId then
        local idj = readJson("__loveweb__/identity.json")
        if idj then
            local uid = idj.userId or idj.id or idj.user_id
            if uid ~= nil then MP.localId = tostring(uid) end
            if idj.handle and (not MP.localHandle or MP.localHandle == "Crab") then
                MP.localHandle = idj.handle
            end
        end
    end
    -- Room file
    local room = readJson(NET .. "/room.json")
    if room then
        MP.lobby = MP.lobby or {}
        local prev = MP.lobby.roomId
        MP.lobby.roomId    = room.roomId or room.id or MP.lobby.roomId
        MP.lobby.code      = room.code or MP.lobby.code
        MP.lobby.name      = room.name or MP.lobby.name
        MP.lobby.capacity  = room.capacity or MP.lobby.capacity or 4
        local rs = room.state or {}
        MP.lobby.mode       = rs.mode or MP.lobby.mode or "last_stand"
        MP.lobby.pvp        = (rs.pvp == 1) or (rs.pvp == true) or MP.lobby.pvp or false
        MP.lobby.private    = (rs.private == 1) or (rs.private == true) or MP.lobby.private or false
        if rs.host_id ~= nil then
            MP.lobby.hostId = tostring(rs.host_id)
        end
        MP.lobby.difficulty = rs.difficulty or MP.lobby.difficulty or "normal"
        MP.lobby.finalWave  = tonumber(rs.final_wave) or MP.lobby.finalWave or 20
        -- Magic-print state mutations are last-write-wins with a propagation
        -- delay, so room.json can come back stale right after a local
        -- optimistic update and clobber it (e.g. phase=wave → phase=lobby).
        -- Treat phase/locked/startedAt as forward-only: they latch on and
        -- never get unset by a stale read.
        local rsPhase = rs.phase or MP.lobby.phase or "lobby"
        if MP.lobby.phase == "wave" or MP.lobby.phase == "ended" then
            -- already advanced; only allow forward moves
            if rsPhase == "ended" then MP.lobby.phase = "ended" end
        else
            MP.lobby.phase = rsPhase
        end
        local rsLocked = (rs.locked == 1) or (rs.locked == true)
        MP.lobby.locked = MP.lobby.locked or rsLocked
        MP.lobby.startedAt = MP.lobby.startedAt or rs.started_at
        if not MP.enabled and MP.lobby.roomId then MP.enabled = true end
        if MP._pendingSettings and MP.lobby.roomId and prev ~= MP.lobby.roomId then
            local s = MP._pendingSettings
            MP._pendingSettings = nil
            MP.applyLobbySettings(s)
        end
        -- Bail out of any room that's been flagged dead by another member,
        -- or any room we joined that turns out to already be locked. This
        -- prevents a code-paste from sneaking into a started/ended run.
        if MP.lobby.roomId and (rs.deleted == 1 or rs.deleted == true) then
            MP._joinError = "this lobby was deleted"
            MP.leave()
        elseif MP.lobby.roomId and MP._joinAt and MP.lobby.locked
               and MP.lobby.phase ~= "lobby" then
            -- We pasted a code into a room that's already started.
            MP._joinError = "this lobby has already started"
            MP.leave()
        end
    end

    -- Most-recent verb result (rooms list, create echoes, errors)
    local lr = readJson(NET .. "/last_result.json")
    if lr then
        if lr.rooms then
            MP.list = lr.rooms
            MP._lastList = love.timer.getTime()
        end
        if lr.youUserId and not MP.localId then
            MP.localId = tostring(lr.youUserId)
        end
        -- Create echo: {ok=true, room={id,code,name,capacity,...}} —
        -- populate MP.lobby IMMEDIATELY so the lobby screen can show
        -- the code without waiting for room.json to materialise.
        if lr.ok and lr.room and lr.room.code then
            MP.lobby = MP.lobby or {}
            MP.lobby.code     = MP.lobby.code     or lr.room.code
            MP.lobby.name     = MP.lobby.name     or lr.room.name
            MP.lobby.capacity = MP.lobby.capacity or lr.room.capacity or 8
            MP.lobby.roomId   = MP.lobby.roomId   or lr.room.id or lr.room.roomId
            if MP.lobby.roomId then MP.enabled = true end
        end
        -- Surface a failed join so the UI can bail out of mp_lobby
        if MP._joinAt and not MP.lobby and lr.ok == false then
            MP._joinError = lr.error or lr.message or "lobby unavailable"
        end
    end
    -- Hard timeout: if a join request hasn't materialised a roomId in 3s,
    -- assume the code is dead. The user-facing UI auto-bounces back to
    -- the lobby browser so they can try a different code.
    if MP._joinAt and not (MP.lobby and MP.lobby.roomId) then
        if (love.timer.getTime() - MP._joinAt) > 3 then
            MP._joinError = MP._joinError or "lobby code not found"
            MP._joinAt = nil
        end
    elseif MP.lobby and MP.lobby.roomId then
        MP._joinAt = nil
    end

    -- Roster / presence. All userIds normalised to strings so peer keys
    -- match identity.json's MP.localId regardless of how the portal
    -- happens to type its values today.
    local roster = readJson(NET .. "/roster.json")
    if roster and roster.members then
        local seen = {}
        for _, m in ipairs(roster.members) do
            local id = m.userId ~= nil and tostring(m.userId) or nil
            if id then
                seen[id] = true
                local p = MP.peers[id]
                if not p then
                    p = {
                        handle = m.handle or ("Crab " .. id),
                        x = 640, y = 360, dispX = 640, dispY = 360,
                        hp = 100, max = 100, alive = true, deathTimer = 0,
                        last = love.timer.getTime(),
                    }
                    MP.peers[id] = p
                    if id ~= MP.localId then
                        table.insert(MP.events, "+ " .. p.handle .. " joined")
                    end
                end
                p.handle = m.handle or p.handle
                if id == MP.localId and m.handle then MP.localHandle = m.handle end
                if id ~= MP.localId and not p.cosmetics and not p.cosmeticsRequested then
                    emit("profile " .. id)
                    p.cosmeticsRequested = true
                end
            end
        end
        for id, peer in pairs(MP.peers) do
            if not seen[id] and id ~= MP.localId then
                table.insert(MP.events, "- " .. (peer.handle or "?") .. " left")
                MP.peers[id] = nil
            end
        end
    end

    -- Per-peer profile fetches (cosmetics)
    for id, p in pairs(MP.peers) do
        if p.cosmeticsRequested and not p.cosmetics then
            local pf = readJson(NET .. "/profiles/" .. tostring(id) .. ".json")
            if pf then
                local prof = pf.profile or pf
                if type(prof) == "string" then prof = parseJson(prof) end
                if type(prof) == "table" and prof.cosmetics then
                    p.cosmetics = prof.cosmetics
                    p.handle = prof.handle or p.handle
                end
            end
        end
    end

    -- Inbox events (new lines only)
    local s = readText(NET .. "/inbox.jsonl")
    if s then
        if #s < MP._inboxLen then MP._inboxLen = 0 end -- file rotated
        if #s > MP._inboxLen then
            local newPart = s:sub(MP._inboxLen + 1)
            MP._inboxLen = #s
            for line in newPart:gmatch("[^\r\n]+") do
                local evt = parseJson(line)
                if evt then MP._handleEvent(evt) end
            end
        end
    end

    -- Drop dead peers (no traffic for too long, never appeared in roster)
    local now = love.timer.getTime()
    for id, peer in pairs(MP.peers) do
        if (now - (peer.last or 0)) > MP.PEER_TIMEOUT and not peer._rostered then
            -- keep — roster is authoritative
        end
    end
end

-- ============================================================
-- Sending helpers (rate-limit-friendly)
-- ============================================================
function MP.sendPos(player, wave)
    if not MP.enabled or not player then return end
    local now = love.timer.getTime()
    if (now - MP._lastPos) < MP.POS_TICK then return end
    MP._lastPos = now
    emitSend("pos", {
        x = math.floor(player.x or 0),
        y = math.floor(player.y or 0),
        hp = math.floor(player.hp or 0),
        max = math.floor(player.maxHp or 0),
        alive = ((player.hp or 0) > 0) and 1 or 0,
        a = math.floor((player.angle or 0) * 100) / 100,
        w = wave or 0,
    })
end

function MP.announceCard(card)
    if not MP.enabled or not card then return end
    emitSend("cardpick", {id = card.id, name = card.name})
end

-- Broadcast a "world event" (King ending, Ugnrak fire, Void Sea unlock,
-- Cthulhu beam, etc.) so every peer's local sim mirrors the cinematic
-- + applies whatever permanent effect makes sense ("you also unlocked
-- Void Sea", "Ugnrak Beam visual fires across your screen too", ...).
MP.pendingEvents = MP.pendingEvents or {}
function MP.announceEvent(kind, payload)
    if not MP.enabled or not kind then return end
    payload = payload or {}
    payload.kind = kind
    emitSend("mp_event", payload)
end

function MP.announceDeath()
    if not MP.enabled then return end
    emitSend("dead", {at = love.timer.getTime()})
end

function MP.sendHit(targetId, dmg)
    if not MP.enabled or not targetId then return end
    emitSend("hit", {target = targetId, dmg = math.floor(dmg)})
end

function MP.sendRevive(targetId)
    if not MP.enabled or not targetId then return end
    emitSend("revive", {target = targetId})
    if MP.peers[targetId] then
        MP.peers[targetId].alive = true
        MP.peers[targetId].hp = (MP.peers[targetId].max or 100) * 0.5
    end
end

function MP.sendChat(text)
    if not MP.enabled or not text or text == "" then return end
    if #text > 120 then text = text:sub(1, 120) end
    emitSend("chat", {text = text})
    MP.selfBubble = {text = text, life = 4.5, max = 4.5}
    table.insert(MP.chatLog, {who = MP.localHandle or "you", text = text, t = love.timer.getTime(), self = true})
    while #MP.chatLog > 12 do table.remove(MP.chatLog, 1) end
end

-- ============================================================
-- Per-frame & per-run lifecycle
-- ============================================================
function MP.beginSession()
    MP.session = {
        local_dead       = false,
        respawnTimer     = 0,
        incomingHit      = 0,
        lastAttacker     = nil,
        revivePartner    = nil,
        reviveProgress   = 0,
        requestRevive    = false,
    }
    MP._lastPos = 0
end

function MP.endSession()
    MP.session = nil
end

-- Auto-cleanup tick: rooms self-terminate when nobody else is around.
-- Two cases:
--   * In-lobby (phase=lobby) AND alone for 60s → mark deleted=1 so the
--     room stops appearing in everyone else's browser. We DON'T auto-leave
--     because the player might just be waiting for friends.
--   * In-wave (phase=wave) AND alone for 30s → mark deleted=1. Same idea.
-- Together with the "leave on close" handler in main.lua, this is the
-- closest we can get to "rooms murder themselves with no players" given
-- the portal has no public delete-room verb.
local _autoEndCheckAt = 0
local _aloneSince = nil
function MP._autoEndCheck()
    if not MP.enabled or not MP.lobby then
        _aloneSince = nil
        return
    end
    local now = love.timer.getTime()
    if (now - _autoEndCheckAt) < 5 then return end
    _autoEndCheckAt = now
    local activePeers = 0
    for id, peer in pairs(MP.peers) do
        if id ~= MP.localId and (now - (peer.last or now)) < MP.PEER_TIMEOUT then
            activePeers = activePeers + 1
        end
    end
    if activePeers > 0 then
        _aloneSince = nil
        return
    end
    _aloneSince = _aloneSince or now
    local aloneFor = now - _aloneSince
    local threshold = (MP.lobby.phase == "wave") and 30 or 60
    if aloneFor > threshold then
        emit("state " .. enc({deleted = 1}))
        _aloneSince = nil
    end
end

function MP.update(dt, game)
    if not MP.enabled then return end
    MP._autoEndCheck()
    -- Smooth peers toward their last reported position
    for _, peer in pairs(MP.peers) do
        peer.dispX = peer.dispX or peer.x
        peer.dispY = peer.dispY or peer.y
        peer.dispX = peer.dispX + (peer.x - peer.dispX) * math.min(1, dt * 6)
        peer.dispY = peer.dispY + (peer.y - peer.dispY) * math.min(1, dt * 6)
        if peer.deathTimer and peer.deathTimer > 0 then
            peer.deathTimer = math.max(0, peer.deathTimer - dt)
            if peer.deathTimer == 0 and MP.lobby and MP.lobby.mode == "endless" then
                peer.alive = true
                peer.hp = peer.max or 100
            end
        end
        if peer.bubble then
            peer.bubble.life = peer.bubble.life - dt
            if peer.bubble.life <= 0 then peer.bubble = nil end
        end
    end
    if MP.selfBubble then
        MP.selfBubble.life = MP.selfBubble.life - dt
        if MP.selfBubble.life <= 0 then MP.selfBubble = nil end
    end
end

function MP.draw(game)
    if not MP.enabled then return end
    local UI = require("src.ui")
    local t = love.timer.getTime()
    local pvpOn = MP.lobby and MP.lobby.pvp
    for id, peer in pairs(MP.peers) do
        if id ~= MP.localId then
            local x, y = peer.dispX or peer.x, peer.dispY or peer.y
            local cos = peer.cosmetics
                or {body="orange", eye="normal", claw="normal", hat="none", trail="none", gun="pistol"}
            local col = Cosmetics.bodyColor(cos)
            local alpha = peer.alive and 1.0 or 0.45
            -- Render the exact same preview-crab the menu and customise
            -- screens use, so peer crabs match the local player's visual
            -- style instead of a hand-rolled sprite. drawCrab handles
            -- body / pattern / legs / claws / eyes / hat / trail itself.
            love.graphics.setColor(1, 1, 1, alpha)
            UI.drawCrab(x, y, 1.0, cos, t)
            love.graphics.setColor(1, 1, 1, 1)
            -- Soft halo behind so peers stay readable even on busy backgrounds
            love.graphics.setColor(col[1], col[2], col[3], 0.12 * alpha)
            love.graphics.circle("fill", x, y, 26)
            -- Floating name + hp wisp. Bobs slightly above the head, no box,
            -- soft shadow so it stays readable on any background without
            -- obstructing combat.
            local bob = math.sin(t * 1.6 + (id or 0) * 0.5) * 1.5
            local nameY = y - 36 + bob
            local label = peer.handle or ("Crab " .. tostring(id))
            love.graphics.setColor(0, 0, 0, 0.55 * alpha)
            love.graphics.printf(label, x - 80 + 1, nameY + 1, 160, "center")
            love.graphics.printf(label, x - 80 - 1, nameY + 1, 160, "center")
            love.graphics.setColor(col[1] * 0.4 + 0.6, col[2] * 0.4 + 0.6, col[3] * 0.4 + 0.6,
                0.92 * alpha)
            love.graphics.printf(label, x - 80, nameY, 160, "center")
            -- Slim hp tick under the name
            local maxhp = math.max(1, peer.max or 1)
            local frac = math.max(0, math.min(1, (peer.hp or 0) / maxhp))
            love.graphics.setColor(0, 0, 0, 0.5 * alpha)
            love.graphics.rectangle("fill", x - 22, nameY + 18, 44, 3, 1.5, 1.5)
            local hpr = peer.alive and {0.45, 0.95, 0.55} or {0.7, 0.35, 0.4}
            love.graphics.setColor(hpr[1], hpr[2], hpr[3], 0.85 * alpha)
            love.graphics.rectangle("fill", x - 22, nameY + 18, 44 * frac, 3, 1.5, 1.5)
            -- PvP target ring
            if pvpOn and peer.alive then
                love.graphics.setColor(1, 0.3, 0.3, 0.35 + math.sin(t * 4) * 0.15)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", x, y, 20)
                love.graphics.setLineWidth(1)
            end
            -- Chat bubble above the name (fades over its life)
            if peer.bubble then
                local life = peer.bubble.life / peer.bubble.max
                local fade = math.min(1, life * 1.6)
                local txt = peer.bubble.text
                local font = love.graphics.getFont()
                local tw = math.min(280, font:getWidth(txt) + 22)
                local th = font:getHeight() + 12
                local bx = x - tw / 2
                local by = nameY - th - 6
                love.graphics.setColor(0.05, 0.07, 0.12, 0.78 * fade)
                love.graphics.rectangle("fill", bx, by, tw, th, 8, 8)
                love.graphics.setColor(col[1] * 0.5 + 0.4, col[2] * 0.5 + 0.4, col[3] * 0.5 + 0.4, 0.85 * fade)
                love.graphics.rectangle("line", bx, by, tw, th, 8, 8)
                love.graphics.polygon("fill",
                    x - 6, by + th, x + 6, by + th, x, by + th + 6)
                love.graphics.setColor(1, 1, 1, fade)
                love.graphics.printf(txt, bx + 8, by + 6, tw - 16, "center")
            end
            -- Mode hints below the name
            if not peer.alive then
                if MP.lobby and MP.lobby.mode == "endless" and (peer.deathTimer or 0) > 0 then
                    love.graphics.setColor(1, 0.7, 0.4, 0.95)
                    love.graphics.printf(string.format("respawn %ds", math.ceil(peer.deathTimer)),
                        x - 60, y + 22, 120, "center")
                elseif MP.lobby and MP.lobby.mode == "rally" then
                    love.graphics.setColor(0.7, 0.95, 1, 0.85 + math.sin(t * 4) * 0.15)
                    love.graphics.printf("hold R to revive", x - 80, y + 22, 160, "center")
                else
                    love.graphics.setColor(0.85, 0.5, 1, 0.85)
                    love.graphics.printf("eliminated", x - 60, y + 22, 120, "center")
                end
            end
        end
    end
end

-- Local-player floating chat bubble + chat input + log overlay.
-- Bubble follows the local crab; the typing window only appears while
-- the player is composing — and only THEN is the chat log visible.
function MP.drawLocalChat(game)
    if not MP.enabled then return end
    local player = game.player
    if MP.selfBubble and player then
        local life = MP.selfBubble.life / MP.selfBubble.max
        local fade = math.min(1, life * 1.6)
        local txt = MP.selfBubble.text
        local font = love.graphics.getFont()
        local tw = math.min(280, font:getWidth(txt) + 22)
        local th = font:getHeight() + 12
        local x, y = player.x, player.y
        local bx = x - tw / 2
        local by = y - 60 - th
        love.graphics.setColor(0.05, 0.07, 0.12, 0.78 * fade)
        love.graphics.rectangle("fill", bx, by, tw, th, 8, 8)
        love.graphics.setColor(0.5, 0.95, 0.65, 0.85 * fade)
        love.graphics.rectangle("line", bx, by, tw, th, 8, 8)
        love.graphics.polygon("fill",
            x - 6, by + th, x + 6, by + th, x, by + th + 6)
        love.graphics.setColor(1, 1, 1, fade)
        love.graphics.printf(txt, bx + 8, by + 6, tw - 16, "center")
    end
    -- Chat input + log only while user is composing
    local chat = game.chat
    if chat and chat.open then
        local font = love.graphics.getFont()
        local lh = font:getHeight() + 4
        -- Log: last few messages, fading older
        local log = MP.chatLog
        local count = math.min(8, #log)
        local logH = count * lh + 8
        local logY = 720 - 78 - logH
        if count > 0 then
            love.graphics.setColor(0, 0, 0, 0.55)
            love.graphics.rectangle("fill", 24, logY, 540, logH, 6, 6)
        end
        for i = 1, count do
            local entry = log[#log - count + i]
            if entry then
                local age = (love.timer.getTime() - (entry.t or 0))
                local a = math.max(0.55, 1 - age * 0.04)
                love.graphics.setColor(entry.self and 0.55 or 0.85,
                                       entry.self and 0.95 or 0.85,
                                       entry.self and 0.75 or 1, a)
                love.graphics.printf(
                    string.format("%s: %s", entry.who or "?", entry.text or ""),
                    32, logY + 4 + (i - 1) * lh, 524, "left")
            end
        end
        -- Input bar
        local inputY = 720 - 64
        love.graphics.setColor(0.06, 0.08, 0.14, 0.92)
        love.graphics.rectangle("fill", 24, inputY, 1232, 44, 8, 8)
        love.graphics.setColor(0.4, 0.85, 0.6, 0.85)
        love.graphics.rectangle("line", 24, inputY, 1232, 44, 8, 8)
        love.graphics.setColor(0.6, 0.95, 0.75, 0.85)
        love.graphics.printf("CHAT", 36, inputY + 12, 80, "left")
        love.graphics.setColor(1, 1, 1, 1)
        local prompt = chat.text or ""
        love.graphics.printf(prompt, 96, inputY + 12, 1140, "left")
        if math.floor(love.timer.getTime() * 2) % 2 == 0 then
            local cx = 96 + font:getWidth(prompt)
            love.graphics.rectangle("fill", math.min(cx, 1230), inputY + 12, 2, 18)
        end
        love.graphics.setColor(1, 1, 1, 0.45)
        love.graphics.printf("ENTER send   |   ESC close", 24, inputY - 18, 1232, "right")
    end
end

-- ============================================================
-- Mode helpers
-- ============================================================
function MP.allDown(localAlive)
    local total, alive = 0, 0
    if MP.localId then
        total = total + 1
        if localAlive then alive = alive + 1 end
    end
    for id, p in pairs(MP.peers) do
        if id ~= MP.localId then
            total = total + 1
            if p.alive then alive = alive + 1 end
        end
    end
    if total == 0 then return false end
    return alive == 0
end

function MP.aliveCount(localAlive)
    local n = localAlive and 1 or 0
    for id, p in pairs(MP.peers) do
        if id ~= MP.localId and p.alive then n = n + 1 end
    end
    return n
end

-- Total roster size (including the local crab and downed peers). Used to
-- split score by lobby size. Falls back to 1 when MP isn't engaged so
-- callers can divide unconditionally.
function MP.lobbySize()
    if not MP.enabled then return 1 end
    local n = 0
    local sawSelf = false
    for id, _ in pairs(MP.peers) do
        n = n + 1
        if id == MP.localId then sawSelf = true end
    end
    if not sawSelf then n = n + 1 end
    return math.max(1, n)
end

function MP.nearestDownedPeer(x, y, r)
    local best, bestD = nil, r * r
    for id, p in pairs(MP.peers) do
        if id ~= MP.localId and not p.alive then
            local dx = (p.dispX or p.x) - x
            local dy = (p.dispY or p.y) - y
            local d = dx * dx + dy * dy
            if d < bestD then best, bestD = id, d end
        end
    end
    return best
end

function MP.peerHitTest(x, y, r)
    if not MP.lobby or not MP.lobby.pvp then return nil end
    for id, p in pairs(MP.peers) do
        if id ~= MP.localId and p.alive then
            local dx = (p.dispX or p.x) - x
            local dy = (p.dispY or p.y) - y
            local rad = (r or 4) + 18
            if dx * dx + dy * dy < rad * rad then return id end
        end
    end
end

return MP
