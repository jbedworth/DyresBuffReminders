local _, DBR = ...

-- Every proc sound and its defaults, in one place (author-approved:
-- data-driven, built like the cooldown chimes). Add a class or proc here;
-- Procs and Options read only this table.
--
-- A proc is a buff the game gives you; the game plays its sound when the buff
-- appears, also in combat (C_UnitAuras.AddAuraSound). buff is the buff's name
-- in the client; spells are its Classic IDs (author: start with Classic's).
-- An ID counts only when the client names it buff, and the real ID is read
-- once the buff is on you out of combat, saved, and used from then on, so a
-- Forever ID that differs corrects itself (Forever changed some spells: Seal
-- of Fury, found in client). None is confirmed in client yet (TESTING.md).
-- on is the default switch (author: Mage Clearcasting off, the game already
-- plays a sound for it; Flurry off); sound is a Dyre's Sounds file sound.
--
-- reactive: not a buff but an ability that becomes usable for a moment
-- (Overpower after a dodge, Revenge after a block, dodge, or parry; author:
-- "Warrior is missing ... Overpower and Revenge procs"). Its Classic rank 1
-- ID; asked for by name, so your highest rank counts. C_Spell.IsSpellUsable
-- is readable in combat (found in client with /dbr probe), so DBR plays the
-- sound itself when the ability turns usable, any sound Dyre's Sounds has.
DBR.PROC_SOUNDS = {
    -- Nightfall (talent): Shadow Trance, your next Shadow Bolt is instant.
    -- Off by default, as in WTF (author-approved: many players use it, others
    -- find it noisy).
    WARLOCK = {
        {key = "nightfall", label = "Nightfall (Shadow Trance)", buff = "Shadow Trance", spells = {17941},
            on = false, sound = "impspell"},
    },
    -- Arcane Concentration (talent).
    MAGE = {
        {key = "mageclearcasting", label = "Clearcasting (Arcane Concentration)", buff = "Clearcasting",
            spells = {12536}, on = false},
    },
    -- Omen of Clarity, and Nature's Grace (talent): your next spell casts faster.
    DRUID = {
        {key = "druidclearcasting", label = "Clearcasting (Omen of Clarity)", buff = "Clearcasting",
            spells = {16870}, on = false},
        {key = "naturesgrace", label = "Nature's Grace", buff = "Nature's Grace", spells = {16886}, on = true},
    },
    -- Elemental Focus (talent).
    SHAMAN = {
        {key = "shamanclearcasting", label = "Clearcasting (Elemental Focus)", buff = "Clearcasting",
            spells = {16246}, on = false},
    },
    -- Flurry (talent): one buff ID per rank.
    WARRIOR = {
        {key = "flurry", label = "Flurry", buff = "Flurry", spells = {12966, 12967, 12968, 12969, 12970},
            on = false},
        {key = "overpower", label = "Overpower", reactive = 7384, on = true, sound = "talent"},
        {key = "revenge", label = "Revenge", reactive = 6572, on = true, sound = "magical"},
    },
}
