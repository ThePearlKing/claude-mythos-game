-- Achievements bridge for the love.js portal. Emits one print line per unlock
-- in the [[LOVEWEB_ACH]] protocol; the portal handles dedup, persistence,
-- catalog mirroring, and leaderboard scoring. See achievements.json at the
-- repo root for the canonical catalog.
--
-- Two entry points:
--   A.fire(key)       — emit one specific unlock (event-driven achievements).
--   A.check(persist)  — scan the persist save and emit any milestone unlocks
--                       whose threshold conditions are now met.
-- Session-local dedup keeps log noise down even though the portal is also
-- idempotent.

local A = {}

local fired = {}

function A.fire(key)
    if fired[key] then return end
    fired[key] = true
    print("[[LOVEWEB_ACH]]unlock " .. key)
end

-- Threshold-style achievements derived from persist stats. Safe to call after
-- any save, run-end, or stat update — duplicates are filtered locally.
function A.check(persist)
    if not persist then return end
    local p = persist

    local kills = p.totalKills or 0
    if kills >= 1    then A.fire("first_blood")  end
    if kills >= 100  then A.fire("kills_100")    end
    if kills >= 500  then A.fire("kills_500")    end
    if kills >= 2000 then A.fire("kills_2000")   end
    if kills >= 5000 then A.fire("kills_5000")   end

    local wins = p.totalWins or 0
    if wins >= 1  then A.fire("first_win") end
    if wins >= 5  then A.fire("wins_5")    end
    if wins >= 10 then A.fire("wins_10")   end
    if wins >= 25 then A.fire("wins_25")   end

    local streak = p.bestStreak or 0
    if streak >= 3  then A.fire("streak_3")  end
    if streak >= 5  then A.fire("streak_5")  end
    if streak >= 10 then A.fire("streak_10") end

    local rep = math.max(p.globalRepMax or 0, p.globalRep or 0)
    if rep >= 75  then A.fire("rep_75")  end
    if rep >= 90  then A.fire("rep_90")  end
    if rep >= 100 then A.fire("rep_max") end

    if (p.hardWins       or 0) >= 1 then A.fire("win_hard")       end
    if (p.nightmareWins  or 0) >= 1 then A.fire("win_nightmare")  end
    if (p.apocalypseWins or 0) >= 1 then A.fire("win_apocalypse") end

    local eld = p.eldritchMax or 0
    if eld >= 5  then A.fire("eldritch_5")  end
    if eld >= 10 then A.fire("eldritch_10") end
    if eld >= 15 then A.fire("eldritch_15") end
    if eld >= 20 then A.fire("eldritch_20") end
    if eld >= 25 then A.fire("eldritch_25") end

    local shards = p.realityShards or 0
    if shards >= 1 then A.fire("shard_first") end
    if shards >= 3 then A.fire("shard_3")     end
    if shards >= 6 then A.fire("shard_all")   end

    if (p.bossKills        or 0) >= 1  then A.fire("openclaw_slain")  end
    if (p.churglyDefeated  or 0) == 1  then A.fire("churgly_defeated") end
    if (p.kingEndingSeen   or 0) == 1  then A.fire("king_ending")      end
    if (p.slugcrabUnlocked or 0) == 1  then A.fire("slugcrab_friend")  end
    if (p.deepestWave      or 0) >= 30 then A.fire("deep_dive")        end
end

return A
