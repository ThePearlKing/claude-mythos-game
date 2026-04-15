-- Persistent save file per slot. 5 independent profiles, each stored in its own
-- text file. A small sidecar file tracks which slot is currently active.
--
-- File layout:
--   claude_mythos_save_1.txt .. claude_mythos_save_5.txt   (one per slot)
--   claude_mythos_active.txt                                (active slot number)

local Save = {}

local ACTIVE_FILE = "claude_mythos_active.txt"
local function slotPath(slot)
    return string.format("claude_mythos_save_%d.txt", slot)
end

-- Back-compat: the original single-file save path. If a slot file doesn't exist
-- on first boot we migrate the legacy file into slot 1 so nobody loses progress.
local LEGACY_PATH = "claude_mythos_save.txt"

function Save.getActiveSlot()
    if love.filesystem.getInfo(ACTIVE_FILE) then
        local s = love.filesystem.read(ACTIVE_FILE)
        local n = tonumber(s)
        if n and n >= 1 and n <= 5 then return n end
    end
    return 1
end

function Save.setActiveSlot(slot)
    love.filesystem.write(ACTIVE_FILE, tostring(math.max(1, math.min(5, slot))))
end

local function readPath(path)
    local data = {
        globalRep = 50,
        globalRepMax = 50,
        winStreak = 0,
        bestStreak = 0,
        totalWins = 0,
        totalRuns = 0,
    }
    if love.filesystem.getInfo(path) then
        local content = love.filesystem.read(path)
        if content then
            for line in content:gmatch("[^\n]+") do
                local k, v = line:match("^([%w_]+)=(.*)$")
                if k and v then
                    local n = tonumber(v)
                    if n then data[k] = n else data[k] = v end
                end
            end
        end
    end
    return data
end

-- Load the save for a specific slot. If nil, loads the active slot. Performs
-- a one-time legacy migration into slot 1 on first run with the new system.
function Save.load(slot)
    slot = slot or Save.getActiveSlot()
    local path = slotPath(slot)
    -- Legacy migration into slot 1
    if slot == 1
        and not love.filesystem.getInfo(path)
        and love.filesystem.getInfo(LEGACY_PATH) then
        local content = love.filesystem.read(LEGACY_PATH)
        if content then love.filesystem.write(path, content) end
    end
    return readPath(path)
end

function Save.save(data, slot)
    slot = slot or Save.getActiveSlot()
    local out = {}
    for k, v in pairs(data) do
        table.insert(out, k .. "=" .. tostring(v))
    end
    love.filesystem.write(slotPath(slot), table.concat(out, "\n"))
end

-- Quick summary of a slot (used in the selection UI without switching to it).
function Save.summary(slot)
    return readPath(slotPath(slot))
end

function Save.hasData(slot)
    return love.filesystem.getInfo(slotPath(slot)) ~= nil
end

function Save.deleteSlot(slot)
    if love.filesystem.getInfo(slotPath(slot)) then
        love.filesystem.remove(slotPath(slot))
    end
end

return Save
