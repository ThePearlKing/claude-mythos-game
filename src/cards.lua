-- Giant card pool for Claude: Mythos.
-- Rarity: common, uncommon, rare, legendary, cursed
-- apply(player) modifies player.stats or player directly.

local Cards = {}

local function addMax(p, n)
    p.maxHp = p.maxHp + n
    p.hp = p.hp + n
end

Cards.pool = {
    -- COMMON GUN STATS
    {id="rapid", name="Rapid Fire", rarity="common", color={1,0.8,0.4},
        desc="+40% fire rate, -15% damage",
        apply=function(p) p.stats.fireRate = p.stats.fireRate * 1.4; p.stats.damage = p.stats.damage * 0.85 end},
    {id="heavy", name="Heavy Rounds", rarity="common", color={1,0.5,0.3},
        desc="+50% damage, -25% fire rate",
        apply=function(p) p.stats.damage = p.stats.damage * 1.5; p.stats.fireRate = p.stats.fireRate * 0.75 end},
    {id="double", name="Double Shot", rarity="common", color={1,0.7,0.2},
        desc="+1 bullet per shot",
        apply=function(p) p.stats.bullets = p.stats.bullets + 1 end},
    {id="bigger", name="Bigger Bullets", rarity="common", color={0.9,0.6,0.3},
        desc="+60% bullet size & damage, -20% speed",
        apply=function(p) p.stats.bulletSize = p.stats.bulletSize * 1.6; p.stats.damage = p.stats.damage * 1.6; p.stats.bulletSpeed = p.stats.bulletSpeed * 0.8 end},
    {id="faster", name="Faster Bullets", rarity="common", color={0.9,0.9,0.6},
        desc="+40% bullet speed",
        apply=function(p) p.stats.bulletSpeed = p.stats.bulletSpeed * 1.4 end},
    {id="stabilizer", name="Stabilizer", rarity="common", color={0.7,0.9,1},
        desc="Perfect accuracy (no spread)",
        apply=function(p) p.stats.spread = 0 end},
    {id="scatter", name="Scatter", rarity="common", color={1,0.6,0.6},
        desc="+1 bullet, 3x spread",
        apply=function(p) p.stats.bullets = p.stats.bullets + 1; p.stats.spread = p.stats.spread * 3 + 0.1 end},
    {id="sharp", name="Sharpened Shells", rarity="common", color={0.9,0.9,0.9},
        desc="+20% damage",
        apply=function(p) p.stats.damage = p.stats.damage * 1.2 end},

    -- UNCOMMON EFFECTS
    {id="pierce", name="Piercing", rarity="uncommon", color={0.8,0.9,1},
        desc="Bullets pierce +2 enemies",
        apply=function(p) p.stats.pierce = p.stats.pierce + 2 end},
    {id="bounce", name="Ricochet", rarity="uncommon", color={0.9,0.7,1},
        desc="Bullets bounce off walls +2 times",
        apply=function(p) p.stats.bounce = p.stats.bounce + 2 end},
    {id="homing", name="Homing Rounds", rarity="uncommon", color={0.6,1,0.6},
        desc="Bullets track enemies",
        apply=function(p) p.stats.homing = p.stats.homing + 3 end},
    {id="crit", name="Hollow Points", rarity="uncommon", color={1,0.9,0.3},
        desc="+15% crit chance",
        apply=function(p) p.stats.crit = p.stats.crit + 0.15 end},
    {id="critmult", name="Critical Strike", rarity="uncommon", color={1,0.8,0.1},
        desc="+1.0x crit multiplier",
        apply=function(p) p.stats.critMult = p.stats.critMult + 1.0 end},
    {id="freeze", name="Cryo Rounds", rarity="uncommon", color={0.5,0.9,1},
        desc="Bullets freeze enemies 1s",
        apply=function(p) p.stats.freeze = math.max(p.stats.freeze, 1) end},
    {id="burn", name="Incendiary", rarity="uncommon", color={1,0.5,0.2},
        desc="Burns enemies. +14 burn DoT/sec.",
        apply=function(p) p.stats.burn = p.stats.burn + 14 end},
    {id="lifesteal", name="Vampiric Rounds", rarity="uncommon", color={1,0.3,0.4}, healthCard=true,
        desc="Heal 8% of damage dealt",
        apply=function(p) p.stats.lifesteal = p.stats.lifesteal + 0.08 end},
    {id="killheal", name="Bloodlust", rarity="uncommon", color={0.9,0.2,0.3}, healthCard=true,
        desc="Heal 4 HP on kill",
        apply=function(p) p.stats.killHeal = p.stats.killHeal + 4 end},
    {id="nimble", name="Nimble Crab", rarity="uncommon", color={0.6,1,0.9},
        desc="+25% move speed",
        apply=function(p) p.speed = p.speed * 1.25 end},
    {id="armor", name="Chitin Plating", rarity="uncommon", color={0.7,0.5,0.3},
        desc="+30 max HP, -10% speed",
        apply=function(p) addMax(p, 30); p.speed = p.speed * 0.9 end},
    {id="dodge", name="Sidestep", rarity="uncommon", color={0.8,0.8,1},
        desc="+15% dodge chance",
        apply=function(p) p.stats.dodge = p.stats.dodge + 0.15 end},
    {id="thorns", name="Thorns", rarity="uncommon", color={0.5,0.8,0.4},
        desc="Damage enemies that touch you",
        apply=function(p) p.stats.thorns = p.stats.thorns + 20 end},
    {id="pickupr", name="Magnet", rarity="uncommon", color={0.8,0.4,0.8},
        desc="+150% pickup range",
        apply=function(p) p.stats.magnet = p.stats.magnet * 2.5 end},
    {id="heal", name="First Aid", rarity="uncommon", color={0.4,1,0.5}, healthCard=true,
        desc="Full heal + 10 max HP",
        apply=function(p) addMax(p, 10); p.hp = p.maxHp end},

    -- RARE
    {id="explosive", name="Explosive Shells", rarity="rare", color={1,0.4,0.1},
        desc="Bullets explode on impact",
        apply=function(p) p.stats.explosive = p.stats.explosive + 1 end},
    {id="chain", name="Chain Lightning", rarity="rare", color={0.6,0.8,1},
        desc="Bullets chain to 2 extra enemies",
        apply=function(p) p.stats.chain = p.stats.chain + 2 end},
    {id="split", name="Splitter Rounds", rarity="rare", color={1,0.6,0.8},
        desc="Bullets split into 3 on hit",
        apply=function(p) p.stats.split = 1 end},
    {id="orb", name="Orbital Guard", rarity="rare", color={1,0.9,0.4},
        desc="+1 orbiting projectile",
        apply=function(p) p.stats.orbs = p.stats.orbs + 1 end},
    {id="shield", name="Energy Shield", rarity="rare", color={0.4,0.7,1}, healthCard=true,
        desc="+40 regenerating shield",
        apply=function(p) p.stats.shieldMax = p.stats.shieldMax + 40; p.stats.shieldRegen = p.stats.shieldRegen + 4; p.stats.shield = p.stats.shieldMax end},
    {id="dash", name="Crab Dash", rarity="rare", color={0.9,0.7,0.3},
        desc="Enable SPACE to dash (already on, lowers CD)",
        apply=function(p) p.stats.hasDash = true; p.dashMax = math.max(1.0, p.dashMax * 0.7) end},
    {id="bomb", name="Ink Bomb", rarity="rare", color={0.5,0.2,0.7},
        desc="Press Q to nuke screen (15s CD)",
        apply=function(p) p.stats.hasBomb = true end},
    {id="shotgun", name="Clawshot", rarity="rare", color={0.9,0.4,0.2},
        desc="SHOTGUN: 5 spread pellets",
        apply=function(p) p.stats.weaponType = "shotgun"; p.stats.fireRate = p.stats.fireRate * 0.7 end},
    {id="laser", name="Beam Weapon", rarity="rare", color={1,0.3,0.3},
        desc="LASER: continuous beam",
        apply=function(p) p.stats.weaponType = "laser" end},
    {id="railgun", name="Railgun", rarity="rare", color={1,1,0.4},
        desc="RAILGUN: charged shots (huge dmg)",
        apply=function(p) p.stats.weaponType = "railgun"; p.stats.damage = p.stats.damage * 1.2 end},
    {id="triple", name="Triple Threat", rarity="rare", color={1,0.5,0.1},
        desc="+2 bullets per shot",
        apply=function(p) p.stats.bullets = p.stats.bullets + 2 end},
    {id="rage", name="Berserker", rarity="rare", color={1,0.2,0.2},
        desc="Up to +80% speed at low HP",
        apply=function(p) p.stats.berserker = p.stats.berserker + 0.8 end},
    {id="barrier", name="Barrier", rarity="rare", color={0.7,0.8,1}, oncePerRun=true,
        desc="Block 1 hit per wave",
        apply=function(p) p.stats.barrier = true end},
    {id="rep", name="Clout", rarity="rare", color={1,0.9,0.5},
        desc="+10 reputation & score x1.25",
        apply=function(p) p.reputation = p.reputation + 10; p.stats.scoreMult = p.stats.scoreMult * 1.25 end},

    -- LEGENDARY
    {id="glass", name="Glass Cannon", rarity="legendary", color={1,0.4,0.4},
        desc="2x damage, half max HP",
        apply=function(p) p.stats.damage = p.stats.damage * 2; p.maxHp = math.max(10, p.maxHp * 0.5); p.hp = math.min(p.hp, p.maxHp); p.stats.glassCannon = true end},
    {id="overclock", name="Overclock", rarity="legendary", color={0.8,0.3,1},
        desc="+50% fire rate, +25% move speed",
        apply=function(p) p.stats.fireRate = p.stats.fireRate * 1.5; p.speed = p.speed * 1.25 end},
    {id="revive", name="Second Wind", rarity="legendary", color={0.4,1,0.6}, oncePerRun=true,
        desc="Revive once at 50% HP",
        apply=function(p) p.stats.reviveAvailable = true end},
    {id="lucky", name="Lucky Seven", rarity="legendary", color={1,0.85,0.2},
        desc="+7% crit, +7% dodge, +7 max HP",
        apply=function(p) p.stats.crit = p.stats.crit + 0.07; p.stats.dodge = p.stats.dodge + 0.07; addMax(p, 7) end},
    {id="clawdefury", name="Clawde's Fury", rarity="legendary", color={1,0.55,0.15},
        desc="+100% crit multiplier, +25% fire rate",
        apply=function(p) p.stats.critMult = p.stats.critMult + 1.0; p.stats.fireRate = p.stats.fireRate * 1.25 end},
    {id="forbidden", name="Forbidden Knowledge", rarity="legendary", color={0.6,0.2,0.8}, eldritch=true,
        desc="+1 eldritch, see +1 card next wave, -10 max HP",
        apply=function(p) p.stats.extraCards = p.stats.extraCards + 1; p.maxHp = math.max(10, p.maxHp - 10); p.hp = math.min(p.hp, p.maxHp); require("src.eldritch").gainLevel(p, 1) end},
    {id="antimatter", name="Antimatter Core", rarity="legendary", color={0.5,0.2,1},
        desc="All bullets explode, bigger radius",
        apply=function(p) p.stats.explosive = math.max(1, p.stats.explosive); p.stats.explodeRadius = p.stats.explodeRadius + 40 end},
    {id="drone", name="Companion Orb", rarity="legendary", color={1,1,0.7},
        desc="+2 orbiting projectiles",
        apply=function(p) p.stats.orbs = p.stats.orbs + 2 end},
    {id="singularity", name="Singularity Rounds", rarity="legendary", color={0.4,0.1,0.8},
        desc="Pierce 5, chain 2, homing",
        apply=function(p) p.stats.pierce = p.stats.pierce + 5; p.stats.chain = p.stats.chain + 2; p.stats.homing = p.stats.homing + 2 end},

    -- CURSED (big buffs, big drawbacks)
    {id="cursed_blood", name="Blood Pact", rarity="cursed", color={0.5,0,0.1},
        desc="+100% damage, -25 max HP",
        apply=function(p) p.stats.damage = p.stats.damage * 2; p.maxHp = math.max(10, p.maxHp - 25); p.hp = math.min(p.hp, p.maxHp) end},
    {id="cursed_coffee", name="Corrupted Coffee", rarity="cursed", color={0.6,0.3,0.1},
        desc="+80% fire rate; lose 1 HP/sec",
        apply=function(p) p.stats.fireRate = p.stats.fireRate * 1.8; p.coffeeCurse = true end},
    {id="cursed_gamble", name="Gambler's Round", rarity="cursed", color={0.8,0.2,0.6},
        desc="25% shots miss; +120% damage",
        apply=function(p) p.stats.damage = p.stats.damage * 2.2; p.stats.spread = p.stats.spread + 0.6 end},
    {id="cursed_data", name="Corrupted Data", rarity="cursed", color={0.3,0.1,0.5}, oncePerRun=true,
        desc="Random stat change each wave (mostly good)",
        apply=function(p) p.corruptedData = true end},
    {id="cursed_sacrifice", name="Sacrificial Shell", rarity="cursed", color={0.6,0.1,0.3},
        desc="-40 max HP now; +100% damage, +25% speed",
        apply=function(p) p.maxHp = math.max(10, p.maxHp - 40); p.hp = math.min(p.hp, p.maxHp); p.stats.damage = p.stats.damage * 2; p.speed = p.speed * 1.25 end},
    {id="cursed_jam", name="Jammed Gun", rarity="cursed", color={0.5,0.4,0.2},
        desc="20% fire-miss chance, +200% damage",
        apply=function(p) p.stats.damage = p.stats.damage * 3; p.jamChance = 0.2 end},

    -- UTILITY
    {id="mag", name="Score Multiplier", rarity="uncommon", color={1,0.9,0.4},
        desc="+35% score & reputation",
        apply=function(p) p.stats.scoreMult = p.stats.scoreMult * 1.35; p.reputation = p.reputation + 5 end},
    {id="repair", name="Repair Kit", rarity="common", color={0.5,1,0.5}, healthCard=true,
        desc="Heal 50 HP",
        apply=function(p) p:heal(50) end},
    {id="vitality", name="Vitality", rarity="common", color={0.5,0.9,0.4}, healthCard=true,
        desc="+20 max HP",
        apply=function(p) addMax(p, 20) end},
    {id="quick", name="Quick Hands", rarity="common", color={0.9,0.8,0.6},
        desc="+25% fire rate",
        apply=function(p) p.stats.fireRate = p.stats.fireRate * 1.25 end},
    {id="range", name="Extended Range", rarity="common", color={0.7,0.9,0.9},
        desc="+25% bullet lifetime",
        apply=function(p) p.stats.rangeBonus = p.stats.rangeBonus + 0.25 end},

    -- ====== ELDRITCH KICKSTARTER (rare-rarity gateway; the ONLY way to start eldritch) ======
    -- Gated to wave >= 5 so early runs don't get derailed into the eldritch path.
    {id="eld_glimpse", name="Glimpse Beyond", rarity="rare", color={0.55,0.25,0.75}, eldritch=true, kickstarter=true, minWave=5,
        desc="+2 eldritch. +8% dmg. The veil thins.",
        apply=function(p) p.stats.damage = p.stats.damage * 1.08; require("src.eldritch").gainLevel(p, 2) end},

    -- ELDRITCH CARDS (gated by requiresEldritch; nerfed so they're sidegrades not I-win buttons)
    {id="eld_whispers", name="Whispers of the Deep", rarity="eldritch", color={0.5,0.1,0.6}, eldritch=true, requiresEldritch=1,
        desc="+1 eldritch. +20% damage. -15 max HP.",
        apply=function(p) p.stats.damage = p.stats.damage * 1.20; p.maxHp = math.max(10, p.maxHp - 15); p.hp = math.min(p.hp, p.maxHp); require("src.eldritch").gainLevel(p, 1) end},
    {id="eld_sight", name="Eldritch Sight", rarity="eldritch", color={0.4,0.05,0.8}, eldritch=true, requiresEldritch=1,
        desc="+1 eldritch. +12% crit chance, +0.5 crit mult.",
        apply=function(p) p.stats.crit = p.stats.crit + 0.12; p.stats.critMult = p.stats.critMult + 0.5; require("src.eldritch").gainLevel(p, 1) end},
    {id="eld_thirdclaw", name="The Third Claw", rarity="eldritch", color={0.6,0.1,0.7}, eldritch=true, requiresEldritch=2,
        desc="+2 eldritch. +1 bullet. -25 max HP.",
        apply=function(p) p.stats.bullets = p.stats.bullets + 1; p.maxHp = math.max(10, p.maxHp - 25); p.hp = math.min(p.hp, p.maxHp); require("src.eldritch").gainLevel(p, 2) end},
    {id="eld_veil", name="Beyond the Veil", rarity="eldritch", color={0.3,0.1,0.5}, eldritch=true, requiresEldritch=2,
        desc="+2 eldritch. +15% dodge. Enemies +15% speed.",
        apply=function(p) p.stats.dodge = p.stats.dodge + 0.15; p.veilEnemyBoost = (p.veilEnemyBoost or 1) * 1.15; require("src.eldritch").gainLevel(p, 2) end},
    {id="eld_crawling", name="The Crawling Shell", rarity="eldritch", color={0.5,0.2,0.4}, eldritch=true, requiresEldritch=2,
        desc="+2 eldritch. Regen 2 HP/sec. -25% fire rate.",
        apply=function(p) p.regen = (p.regen or 0) + 2; p.stats.fireRate = p.stats.fireRate * 0.75; require("src.eldritch").gainLevel(p, 2) end},
    {id="eld_rain", name="The Unshaped One", rarity="eldritch", color={0.5,0.05,0.7}, eldritch=true, requiresEldritch=3,
        desc="+3 eldritch. Bullets rain from sky while firing.",
        apply=function(p) p.rainBullets = (p.rainBullets or 0) + 1; require("src.eldritch").gainLevel(p, 3) end},
    {id="eld_nghaa", name="Ngh'aaa'th", rarity="eldritch", color={0.25,0.0,0.4}, eldritch=true, requiresEldritch=3,
        desc="+3 eldritch. x2 damage. -40% fire rate.",
        apply=function(p) p.stats.damage = p.stats.damage * 2.0; p.stats.fireRate = p.stats.fireRate * 0.60; require("src.eldritch").gainLevel(p, 3) end},
    {id="eld_grimoire", name="Claude's Grimoire", rarity="eldritch", color={0.35,0.0,0.55}, eldritch=true, requiresEldritch=3,
        desc="+3 eldritch. +2 card choices next wave.",
        apply=function(p) p.stats.extraCards = p.stats.extraCards + 2; require("src.eldritch").gainLevel(p, 3) end},
    {id="eld_ascend", name="Ascend the Seventh Stair", rarity="eldritch", color={0.45,0.1,0.7}, eldritch=true, requiresEldritch=4,
        desc="+4 eldritch. +1 orb, +1 bullet, -40 max HP.",
        apply=function(p) p.stats.orbs = p.stats.orbs + 1; p.stats.bullets = p.stats.bullets + 1; p.maxHp = math.max(10, p.maxHp - 40); p.hp = math.min(p.hp, p.maxHp); require("src.eldritch").gainLevel(p, 4) end},
    {id="eld_maw", name="Maw of the Deep", rarity="eldritch", color={0.15,0.0,0.35}, eldritch=true, requiresEldritch=4,
        desc="+4 eldritch. Bullets explode; +2 pierce.",
        apply=function(p) p.stats.explosive = math.max(p.stats.explosive, 1); p.stats.pierce = p.stats.pierce + 2; require("src.eldritch").gainLevel(p, 4) end},
    {id="eld_tome", name="The Final Tome", rarity="eldritch", color={0.05,0.0,0.2}, eldritch=true, requiresEldritch=6,
        desc="+5 eldritch. x1.5 dmg, x1.5 fire rate, +20% speed.",
        apply=function(p)
            p.stats.damage = p.stats.damage * 1.5; p.stats.fireRate = p.stats.fireRate * 1.5
            p.stats.bulletSpeed = p.stats.bulletSpeed * 1.25; p.speed = p.speed * 1.20
            require("src.eldritch").gainLevel(p, 5)
        end},

    -- ====== ULTIMATE ELDRITCH: Churgly'nth, Crafter of Shells ======
    -- Lore: Before oceans, before seas, before the first claw clicked, there was
    --   CHURGLY'NTH - a being of brine and shadow who dreamt the concept of "shell".
    --   All crabs are fractals of Its self. Cthulhu is but a disciple. To accept this
    --   card is to inherit the pattern that wove the first pincer.
    {id="eld_churglynth", name="Churgly'nth, Crafter of Shells", rarity="eldritch", color={0.98,0.78,0.15}, eldritch=true, requiresEldritch=10,
        desc="The Crafter wakes. x4 dmg, x2 fire, +3 bullets, +5 pierce, +3 chain, +3 orbs, +200 HP, revive, explosive, +50% crit, +2 crit mult. You ascend.",
        apply=function(p)
            p.stats.damage = p.stats.damage * 4
            p.stats.fireRate = p.stats.fireRate * 2
            p.stats.bullets = p.stats.bullets + 3
            p.stats.pierce = p.stats.pierce + 5
            p.stats.chain = p.stats.chain + 3
            p.stats.explosive = math.max(1, p.stats.explosive)
            p.stats.explodeRadius = p.stats.explodeRadius + 50
            p.stats.crit = p.stats.crit + 0.5
            p.stats.critMult = p.stats.critMult + 2
            p.maxHp = p.maxHp + 200
            p.hp = p.maxHp
            p.stats.orbs = p.stats.orbs + 3
            p.stats.reviveAvailable = true
            p.stats.hasDash = true
            p.dashInvuln = 1.0
            p.dashMax = 0.6
            p.speed = p.speed * 1.4
            p.churglyBlessed = true
            require("src.eldritch").gainLevel(p, 15)
            -- Churgly'nth does NOT take kindly to a mortal wearing the first shell.
            -- Flip the rage state on the eldritch layer and wire up the revert timer.
            p.eldritch.churglyEnraged = true
            p.eldritch.churglyRevertTimer = 8
            p.eldritch.churglyScreamTimer = 1.5
            -- Lore burst
            local P = require("src.particles")
            P:text(640, 200, "CHURGLY'NTH STIRS", {1, 0.85, 0.2}, 5)
            P:text(640, 230, "Before the first claw, there was Churgly'nth.", {1, 0.9, 0.5}, 6)
            P:text(640, 255, "You inherit the first pattern. The shell is yours.", {1, 0.8, 0.3}, 7)
            P:text(640, 290, "...and He wants it back.", {1, 0.3, 0.3}, 7)
            P:spawn(640, 300, 60, {1, 0.85, 0.2}, 500, 1.2, 6)
        end},

    -- ====== MORE ELDRITCH CARDS (all gated behind current eldritch level) ======
    {id="eld_starving", name="Starving Jaws", rarity="eldritch", color={0.4,0.05,0.35}, eldritch=true, requiresEldritch=1,
        desc="+1 eldritch. +15% lifesteal. HP drains 0.5/sec.",
        apply=function(p) p.stats.lifesteal = p.stats.lifesteal + 0.15; p.coffeeCurse = true; require("src.eldritch").gainLevel(p, 1) end},
    {id="eld_mirror", name="Mirror of Nhass", rarity="eldritch", color={0.3,0.3,0.7}, eldritch=true, requiresEldritch=2, oncePerRun=true,
        desc="+2 eldritch. Shots split on first kill of each wave.",
        apply=function(p) p.stats.split = 1; require("src.eldritch").gainLevel(p, 2) end},
    {id="eld_signal", name="The Wet Signal", rarity="eldritch", color={0.2,0.4,0.6}, eldritch=true, requiresEldritch=1,
        desc="+1 eldritch. Homing +4. Chain +1. Range ++.",
        apply=function(p) p.stats.homing = p.stats.homing + 4; p.stats.chain = p.stats.chain + 1; p.stats.rangeBonus = p.stats.rangeBonus + 0.5; require("src.eldritch").gainLevel(p, 1) end},
    {id="eld_molt", name="Unholy Molt", rarity="eldritch", color={0.5,0.1,0.3}, eldritch=true, requiresEldritch=2,
        desc="+2 eldritch. +60 max HP; drop to 1 HP now.",
        apply=function(p) p.maxHp = p.maxHp + 60; p.hp = 1; require("src.eldritch").gainLevel(p, 2) end},
    {id="eld_pact", name="Pact of Y'glaax", rarity="eldritch", color={0.6,0.15,0.55}, eldritch=true, requiresEldritch=2, oncePerRun=true,
        desc="+2 eldritch. Revive with full HP once.",
        apply=function(p) p.stats.reviveAvailable = true; require("src.eldritch").gainLevel(p, 2) end},
    {id="eld_horror", name="Writhing Horror", rarity="eldritch", color={0.25,0.05,0.35}, eldritch=true, requiresEldritch=3,
        desc="+3 eldritch. +2 orbs. Orbs deal more damage.",
        apply=function(p) p.stats.orbs = p.stats.orbs + 2; p.orbDmgMult = (p.orbDmgMult or 1) * 2; require("src.eldritch").gainLevel(p, 3) end},
    {id="eld_dreaming", name="Dreaming Tide", rarity="eldritch", color={0.15,0.1,0.5}, eldritch=true, requiresEldritch=2, oncePerRun=true,
        desc="+2 eldritch. Enemies freeze for 2s on first hit.",
        apply=function(p) p.stats.freeze = math.max(p.stats.freeze, 2); require("src.eldritch").gainLevel(p, 2) end},
    {id="eld_saltbrine", name="Saltbrine Curse", rarity="eldritch", color={0.2,0.5,0.45}, eldritch=true, requiresEldritch=1,
        desc="+1 eldritch. +22 burn DoT/sec. Crit +10%.",
        apply=function(p) p.stats.burn = p.stats.burn + 22; p.stats.crit = p.stats.crit + 0.1; require("src.eldritch").gainLevel(p, 1) end},
    {id="eld_thousand", name="A Thousand Pincers", rarity="eldritch", color={0.65,0.1,0.4}, eldritch=true, requiresEldritch=3,
        desc="+3 eldritch. +3 bullets. 3x spread.",
        apply=function(p) p.stats.bullets = p.stats.bullets + 3; p.stats.spread = p.stats.spread * 3 + 0.15; require("src.eldritch").gainLevel(p, 3) end},
    {id="eld_unname", name="The Unnameable", rarity="eldritch", color={0.05,0.0,0.1}, eldritch=true, requiresEldritch=4,
        desc="+4 eldritch. Bullets phase through enemies.",
        apply=function(p) p.stats.pierce = p.stats.pierce + 99; require("src.eldritch").gainLevel(p, 4) end},
    {id="eld_nowhere", name="Home from Nowhere", rarity="eldritch", color={0.4,0.2,0.6}, eldritch=true, requiresEldritch=2,
        desc="+2 eldritch. Dash teleports further, no CD.",
        apply=function(p) p.stats.hasDash = true; p.dashMax = 0.4; p.dashDist = (p.dashDist or 180) + 80; require("src.eldritch").gainLevel(p, 2) end},
    {id="eld_hunger", name="Hunger of the Deep", rarity="eldritch", color={0.35,0.0,0.2}, eldritch=true, requiresEldritch=3,
        desc="+3 eldritch. Kills give +1 max HP permanently.",
        apply=function(p) p.killGrowth = (p.killGrowth or 0) + 1; require("src.eldritch").gainLevel(p, 3) end},
    {id="eld_crabmind", name="The Crab Mind", rarity="eldritch", color={0.7,0.2,0.3}, eldritch=true, requiresEldritch=2, oncePerRun=true,
        desc="+2 eldritch. Every 4th shot is a crit.",
        apply=function(p) p.everyNthCrit = 4; require("src.eldritch").gainLevel(p, 2) end},
    {id="eld_vow", name="Sunken Vow", rarity="eldritch", color={0.1,0.3,0.35}, eldritch=true, requiresEldritch=1,
        desc="+1 eldritch. Barrier blocks 3 hits/wave.",
        apply=function(p) p.stats.barrier = true; p.barrierCharges = (p.barrierCharges or 0) + 3; require("src.eldritch").gainLevel(p, 1) end},
    {id="eld_dim", name="Dimension Drift", rarity="eldritch", color={0.5,0.3,0.85}, eldritch=true, requiresEldritch=2,
        desc="+2 eldritch. 25% dodge. Eldritch cards always offered.",
        apply=function(p) p.stats.dodge = p.stats.dodge + 0.25; p.alwaysEldritch = true; require("src.eldritch").gainLevel(p, 2) end},
    -- Common-ish eldritch card: unlocks a glitchy on-screen eldritch counter.
    {id="eld_tally", name="Forbidden Tally", rarity="eldritch", color={0.65,0.25,0.85}, eldritch=true, requiresEldritch=1, commonEldritch=true, oncePerRun=true,
        desc="+1 eldritch. A glitched counter haunts the corner of your eye.",
        apply=function(p) p.eldritchCounterUnlocked = true; require("src.eldritch").gainLevel(p, 1) end},
    -- Secret: Void Sea. Unlocks the ability to dive beneath the battlefield.
    {id="eld_voidsea", name="Void Sea", rarity="eldritch", color={0.25,0.18,0.45}, eldritch=true, requiresEldritch=5, oncePerRun=true,
        desc="+3 eldritch. The floor is not a floor. Press S at the bottom edge...",
        apply=function(p)
            p.voidSeaUnlocked = true
            if p.game and p.game.persist then
                p.game.persist.voidSeaEverUnlocked = 1
                require("src.save").save(p.game.persist)
            end
            require("src.eldritch").gainLevel(p, 3)
        end},
    -- THE KING: crowns you with 16 random cards and infinite knowledge.
    {id="eld_king", name="The King", rarity="eldritch", color={1,0.85,0.15}, eldritch=true, requiresEldritch=15,
        desc="+10 eldritch. 16 random cards applied. Infinite knowledge. NO RETURN.",
        apply=function(p)
            require("src.eldritch").gainLevel(p, 10)
            p.alwaysEldritch = true
            p.kingVisions = true
            p.stats.extraCards = (p.stats.extraCards or 0) + 4
            -- Apply 16 random cards from the pool (no repeats, excludes The King itself
            -- to avoid recursion).
            local Cards = require("src.cards")
            local taken = {eld_king = true}
            local applied = 0
            local attempts = 0
            while applied < 16 and attempts < 400 do
                attempts = attempts + 1
                local c = Cards.pool[math.random(#Cards.pool)]
                if c and not taken[c.id] and c.rarity ~= "eldritch" then
                    taken[c.id] = true
                    c.apply(p)
                    applied = applied + 1
                end
            end
            local P = require("src.particles")
            P:text(640, 180, "THE KING RISES", {1, 0.9, 0.3}, 5)
            P:text(640, 215, "INFINITE KNOWLEDGE", {1, 0.85, 0.4}, 5)
            P:text(640, 250, "16 CARDS INSCRIBED", {0.9, 0.75, 0.2}, 5)
            P:spawn(640, 320, 100, {1, 0.9, 0.3}, 600, 1.5, 8)
        end},

    -- ====== CREATIVE NORMAL CARDS ======
    {id="boomerang", name="Boomerang Round", rarity="rare", color={0.9,0.5,0.9}, oncePerRun=true,
        desc="Bullets return on miss, hit again.",
        apply=function(p) p.boomerang = true end},
    {id="ricochet", name="Ricochet Master", rarity="rare", color={0.7,0.9,1},
        desc="+3 wall bounces. Each bounce adds +20% damage.",
        apply=function(p) p.stats.bounce = p.stats.bounce + 3; p.bounceDmgStack = true end},
    {id="momentum", name="Momentum", rarity="uncommon", color={1,0.9,0.5}, oncePerRun=true,
        desc="Up to +50% damage while moving at full speed.",
        apply=function(p) p.momentum = true end},
    {id="sniper", name="Patient Predator", rarity="rare", color={0.9,0.7,0.9}, oncePerRun=true,
        desc="Holding fire 1s: next shot 3x damage.",
        apply=function(p) p.patientShot = true end},
    {id="static", name="Static Field", rarity="rare", color={0.5,0.9,1},
        desc="Nearby enemies take 10 dmg/sec aura.",
        apply=function(p) p.staticAura = (p.staticAura or 0) + 10 end},
    {id="void_well", name="Void Well", rarity="rare", color={0.3,0.1,0.5}, oncePerRun=true,
        desc="Bullets pull enemies toward impact.",
        apply=function(p) p.voidWell = true end},
    {id="shell_spike", name="Shell Spikes", rarity="uncommon", color={0.7,0.5,0.3},
        desc="+40 thorns. -10% speed.",
        apply=function(p) p.stats.thorns = p.stats.thorns + 40; p.speed = p.speed * 0.9 end},
    {id="mercy_kill", name="Mercy Shot", rarity="uncommon", color={1,0.4,0.6},
        desc="Killing blow restores 8% max HP.",
        apply=function(p) p.stats.killHeal = p.stats.killHeal + math.max(5, p.maxHp * 0.08) end},
    {id="second_hand", name="Second Hand", rarity="uncommon", color={1,0.85,0.4}, oncePerRun=true,
        desc="Every 3rd shot is free (no fire-rate cost).",
        apply=function(p) p.freeShotEvery = 3 end},
    {id="scuttle", name="Scuttle", rarity="uncommon", color={0.8,1,0.8}, oncePerRun=true,
        desc="+35% move speed while firing.",
        apply=function(p) p.scuttle = true end},
    {id="counter", name="Counter Claw", rarity="rare", color={0.6,0.8,1},
        desc="Being hit fires 8 bullets in a ring.",
        apply=function(p) p.counterBurst = (p.counterBurst or 0) + 8 end},
    {id="adrenaline", name="Adrenaline", rarity="common", color={1,0.6,0.4}, oncePerRun=true,
        desc="+60% fire rate for 3s after taking damage.",
        apply=function(p) p.adrenaline = true end},
    {id="focus", name="Laser Focus", rarity="common", color={0.9,0.9,0.6}, oncePerRun=true,
        desc="Zero spread. +10% damage while stationary.",
        apply=function(p) p.stats.spread = 0; p.focusWhenStill = true end},
    {id="scramble", name="Scrambled Aim", rarity="cursed", color={0.7,0.1,0.5},
        desc="Bullets wobble violently. +70% damage.",
        apply=function(p) p.wobbleShots = true; p.stats.damage = p.stats.damage * 1.7 end},
    {id="overdrive", name="Overdrive", rarity="rare", color={1,0.5,0.1}, oncePerRun=true,
        desc="First 2s of each wave: triple fire rate.",
        apply=function(p) p.overdriveWaveStart = true end},
    {id="phase", name="Phase Shift", rarity="rare", color={0.5,0.5,1}, oncePerRun=true,
        desc="Dash makes you invulnerable for 0.8s.",
        apply=function(p) p.stats.hasDash = true; p.dashInvuln = 0.8 end},
    {id="magnetic", name="Magnetic Shells", rarity="uncommon", color={0.9,0.4,0.9},
        desc="Bullets curve toward nearest enemy.",
        apply=function(p) p.stats.homing = p.stats.homing + 2 end},
    {id="armor_pierce", name="Armor-Piercing", rarity="uncommon", color={0.8,0.8,0.9},
        desc="+1 pierce. +15% damage.",
        apply=function(p) p.stats.pierce = p.stats.pierce + 1; p.stats.damage = p.stats.damage * 1.15 end},
    {id="compound", name="Compound Interest", rarity="rare", color={1,0.85,0.4}, oncePerRun=true,
        desc="Each kill this wave: +1% damage (resets per wave).",
        apply=function(p) p.compoundInterest = true end},
    {id="flurry", name="Flurry of Claws", rarity="rare", color={1,0.6,0.2}, oncePerRun=true,
        desc="After a kill: next 3 shots are instant.",
        apply=function(p) p.flurryOnKill = true end},
    {id="weight", name="Dead Weight", rarity="cursed", color={0.6,0.3,0.3},
        desc="Move speed halved. +150% damage.",
        apply=function(p) p.speed = p.speed * 0.5; p.stats.damage = p.stats.damage * 2.5 end},
    {id="siphon", name="Kill Siphon", rarity="legendary", color={0.6,0.2,0.8},
        desc="On kill: 10% chance for a free card next wave.",
        apply=function(p) p.cardFromKill = (p.cardFromKill or 0) + 0.10 end},
    {id="aegis", name="Aegis Protocol", rarity="legendary", color={0.5,0.8,1}, oncePerRun=true,
        desc="Taking damage: 1s invuln + shockwave (30 dmg AoE).",
        apply=function(p) p.aegis = true end},
    {id="bullet_storm", name="Bullet Storm", rarity="legendary", color={1,0.6,0.2},
        desc="+3 bullets, +50% fire rate, 2x spread.",
        apply=function(p) p.stats.bullets = p.stats.bullets + 3; p.stats.fireRate = p.stats.fireRate * 1.5; p.stats.spread = p.stats.spread * 2 + 0.05 end},
    {id="clone", name="Shell Clone", rarity="legendary", color={0.8,0.5,0.9},
        desc="Spawns a tiny follower that fires too.",
        apply=function(p) p.clones = (p.clones or 0) + 1 end},
    {id="gold_rush", name="Gold Rush", rarity="rare", color={1,0.85,0.1},
        desc="Score 2x. Reputation gains doubled.",
        apply=function(p) p.stats.scoreMult = p.stats.scoreMult * 2; p.repBonusMult = (p.repBonusMult or 1) * 2 end},
    {id="kraken", name="Kraken Rounds", rarity="rare", color={0.2,0.4,0.6}, oncePerRun=true,
        desc="Bullets leave slowing ink clouds.",
        apply=function(p) p.inkTrail = true end},
    {id="pulse", name="Pulse Fire", rarity="uncommon", color={0.9,0.9,0.2},
        desc="Every 1s: free AoE pulse (20 dmg).",
        apply=function(p) p.pulseFire = true end},
    {id="rebirth", name="Rebirth Shell", rarity="legendary", color={0.9,1,0.9},
        desc="Start each wave with +10 max HP.",
        apply=function(p) p.rebirthPerWave = (p.rebirthPerWave or 0) + 10 end},
    {id="dusk", name="Dusk Reaver", rarity="rare", color={0.4,0.2,0.5}, oncePerRun=true,
        desc="Under 30% HP: +100% damage, +50% speed.",
        apply=function(p) p.duskMode = true end},
    {id="nimble_mind", name="Nimble Mind", rarity="uncommon", color={0.8,0.8,1},
        desc="Dodge +10%. Dash CD -50%.",
        apply=function(p) p.stats.dodge = p.stats.dodge + 0.10; p.dashMax = math.max(0.3, p.dashMax * 0.5) end},
    {id="swarm", name="Swarm of Hands", rarity="legendary", color={1,0.3,0.5}, oncePerRun=true,
        desc="All shots fire in 3 directions (front + 2 sides).",
        apply=function(p) p.triWay = true end},

    -- ====== LASER-SPECIFIC CARDS (only offered once you own the Beam Weapon) ======
    {id="laser_overchg", name="Overcharged Beam", rarity="rare", color={1,0.4,0.3}, requiresWeapon="laser",
        desc="LASER: +100% beam damage. Glows brighter.",
        apply=function(p) p.laserDmgMult = (p.laserDmgMult or 1) * 2.0 end},
    {id="laser_refract", name="Refracted Lens", rarity="rare", color={0.4,0.9,1}, requiresWeapon="laser",
        desc="LASER: pierces through every enemy in line.",
        apply=function(p) p.stats.pierce = p.stats.pierce + 20; p.laserFullPierce = true end},
    {id="laser_solar", name="Solar Focus", rarity="rare", color={1,0.8,0.2}, requiresWeapon="laser",
        desc="LASER: burns at 3x strength for 4s.",
        apply=function(p) p.stats.burn = p.stats.burn + 30; p.laserBurnMult = 3 end},
    {id="laser_cryo", name="Cryo Beam", rarity="rare", color={0.4,0.9,1}, requiresWeapon="laser", oncePerRun=true,
        desc="LASER: freezes enemies for 1s on contact.",
        apply=function(p) p.stats.freeze = math.max(p.stats.freeze, 1); p.laserFreezeMult = 2 end},
    {id="laser_width", name="Wide Beam", rarity="uncommon", color={1,0.5,0.5}, requiresWeapon="laser",
        desc="LASER: beam hits a wider area.",
        apply=function(p) p.laserWidthMult = (p.laserWidthMult or 1) * 1.8 end},
    {id="laser_crit", name="Death Ray", rarity="legendary", color={1,0.2,0.2}, requiresWeapon="laser",
        desc="LASER: guaranteed crits, +2.0 crit mult.",
        apply=function(p) p.laserAlwaysCrit = true; p.stats.critMult = p.stats.critMult + 2.0 end},
    {id="laser_drain", name="Draining Ray", rarity="rare", color={0.8,0.2,0.6}, requiresWeapon="laser",
        desc="LASER: +20% lifesteal on beam hit.",
        apply=function(p) p.stats.lifesteal = p.stats.lifesteal + 0.20; p.laserLifestealMult = 2 end},
    {id="laser_prism", name="Prism Split", rarity="legendary", color={0.7,0.8,1}, requiresWeapon="laser",
        desc="LASER: fires 3 beams in a fan.",
        apply=function(p) p.laserBeams = (p.laserBeams or 1) + 2 end},
}

local rarityWeight = {
    common = 40,
    uncommon = 24,
    rare = 10,
    legendary = 3,
    cursed = 6,
    eldritch = 12,
}

local rarityColor = {
    common = {0.8, 0.8, 0.8},
    uncommon = {0.3, 0.9, 0.3},
    rare = {0.4, 0.6, 1},
    legendary = {1, 0.6, 0.1},
    cursed = {0.8, 0.1, 0.6},
    eldritch = {0.55, 0.1, 0.85},
}

function Cards.rarityColor(r)
    return rarityColor[r] or {1,1,1}
end

-- TEMP DEBUG: force Void Sea into the first card offer. Remove before ship.
local DEBUG_FORCE_VOIDSEA_WAVE_1 = false

function Cards.pick(n, wave, player, disableEldritch, finalWave)
    if DEBUG_FORCE_VOIDSEA_WAVE_1 and wave == 1 then
        local voidCard
        for _, c in ipairs(Cards.pool) do
            if c.id == "eld_voidsea" then voidCard = c; break end
        end
        if voidCard then
            local result = {voidCard}
            -- pad with other random picks (skipping void)
            local takenIds = {eld_voidsea = true}
            for _, c in ipairs(Cards.pool) do
                if #result >= n then break end
                if not takenIds[c.id] and c.rarity == "common" then
                    table.insert(result, c)
                    takenIds[c.id] = true
                end
            end
            return result
        end
    end
    -- Early-wave throttle for powerful rarities: 0.25x at wave 1, full by wave 10, boost past 10
    local earlyFactor = math.max(0.25, math.min(1, wave / 10))
    local lateBoost   = 1 + math.max(0, wave - 10) * 0.08
    -- Eldritch weight grows LINEARLY (not exponentially). Generous baseline once the first card is taken
    -- so subsequent eldritch cards actually show up instead of vanishing.
    local eldritchMult = 1.5
    if player and player.eldritch then
        local lvl = player.eldritch.level or 0
        eldritchMult = 1.5 + lvl * 0.5
    end
    if disableEldritch then eldritchMult = 0 end
    local result = {}
    local taken = {}
    local eldritchPickedCount = 0
    local attempts = 0
    while #result < n and attempts < 800 do
        attempts = attempts + 1
        local total = 0
        local entries = {}
        local playerLvl = (player and player.eldritch and player.eldritch.level) or 0
        for _, c in ipairs(Cards.pool) do
            local gated = c.requiresEldritch and playerLvl < c.requiresEldritch
            -- HARD RULE: no eldritch-RARITY cards at level 0 (kickstarter is rare, not eldritch)
            local lockedByLevel = (playerLvl == 0 and c.rarity == "eldritch")
            -- HARD RULE: max 1 eldritch-rarity card per offer set — always leave room for normal cards
            local eldritchCap = (c.rarity == "eldritch") and (eldritchPickedCount >= 1)
            -- minWave gate (Glimpse Beyond hidden until wave >= 5, etc.)
            local belowMinWave = c.minWave and wave < c.minWave
            -- Weapon-specific cards (e.g. Overcharged Beam) only appear if you own that weapon
            local wrongWeapon = c.requiresWeapon and (not player or (player.stats and player.stats.weaponType) ~= c.requiresWeapon)
            -- oncePerRun cards disappear after being picked up this run.
            local alreadyHave = false
            if c.oncePerRun and player and player.cardsTaken then
                for _, prev in ipairs(player.cardsTaken) do
                    if prev.id == c.id then alreadyHave = true; break end
                end
            end
            if not taken[c.id]
                and not (disableEldritch and c.eldritch)
                and not gated
                and not lockedByLevel
                and not eldritchCap
                and not belowMinWave
                and not wrongWeapon
                and not alreadyHave
            then
                local w = rarityWeight[c.rarity] or 10
                if c.rarity == "rare"      then w = w * earlyFactor * lateBoost end
                if c.rarity == "legendary" then w = w * (earlyFactor ^ 2) * lateBoost end
                if c.rarity == "cursed"    then w = w * earlyFactor end
                if c.rarity == "eldritch"  then w = w * eldritchMult end
                -- commonEldritch flag: roughly 2.5x more likely than its eldritch peers.
                if c.commonEldritch and not disableEldritch then w = w * 2.5 end
                -- healthCard flag: moderately bumped so sustain options show
                -- up reliably (winning runs usually need ~2 health cards).
                if c.healthCard then w = w * 2.2 end
                -- Non-eldritch-rarity cards still tagged eldritch (e.g. Forbidden Knowledge, Glimpse Beyond)
                -- get an eldritch bump scaling with current level
                if c.eldritch and c.rarity ~= "eldritch" and not disableEldritch then
                    w = w * (1 + playerLvl * 0.25 + 0.7)
                end
                -- Strong kickstarter bump so Glimpse Beyond reliably appears at wave 5+,
                -- peaking around wave 15 and rapidly tapering off past 15 so the player
                -- can't pivot into a fresh eldritch path late in a 20-wave run.
                -- In long runs (infinite mode OR custom finalWave > 20), the weight
                -- ramps back UP past wave 20 since you have plenty of run left.
                if c.kickstarter and playerLvl == 0 then
                    local longRun = (not finalWave) or finalWave == 0 or finalWave > 20
                    local base = 4.0 + math.max(0, math.min(wave, 15) - 5) * 0.6
                    local lateDecay
                    if wave <= 15 then
                        lateDecay = 1.0
                    elseif longRun and wave >= 20 then
                        -- gently climb back toward 1.0 past wave 20
                        lateDecay = math.min(1.0, 0.3 + (wave - 20) * 0.08)
                    else
                        lateDecay = 0.4 ^ ((wave - 15) / 3)
                    end
                    w = w * base * lateDecay
                end
                total = total + w
                entries[#entries + 1] = {c, total}
            end
        end
        if total <= 0 then break end
        local pick = math.random() * total
        for _, e in ipairs(entries) do
            if pick <= e[2] then
                local chosen = e[1]
                taken[chosen.id] = true
                if chosen.rarity == "eldritch" then
                    eldritchPickedCount = eldritchPickedCount + 1
                end
                table.insert(result, chosen)
                break
            end
        end
    end
    return result
end

return Cards
