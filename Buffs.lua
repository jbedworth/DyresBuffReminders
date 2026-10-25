local _, DBR = ...

-- The buffs each class is reminded of (author-approved for v1: Mage, Warlock,
-- Druid, Priest, and Paladin self buffs). Classic spell IDs; a buff counts by
-- name, so every rank does. Left out as situational, cast on chosen members
-- (author): Dampen and Amplify Magic, and Paladin Blessings.
--
-- key: saved per character, unique across classes. spells: the ranks you can
-- cast yourself, lowest first. A click casts spells[1]'s name, which the
-- client casts at your highest rank, unless prefer is given: then a click
-- recasts the one you used last, else the first of prefer you know (for buffs
-- with several spells, such as a Mage's armors). group: the buff also goes on
-- your party or raid (a setting, on by default); mana means only members who
-- use mana count. group.spells are the group-wide versions, best last, each
-- with its reagent; they count as the buff, and a click casts the best one
-- you know and carry the reagent for when two or more members lack it.
-- cancelForm: a click while shapeshifted leaves the form first. others: the
-- spell can go on another player, though DBR watches one unit only; with
-- group, it puts the reminder in the Group buffs bar (author: a buff that can
-- go on another player is a group buff). tank: that unit is your group's
-- tank (the Tank role), else you. forget: spells that count as the buff but
-- are never remembered for the click (a Hunter's Cheetah and Pack, which
-- daze you when you are hit). bang: the click casts with "!" ("/use !Name"),
-- which never takes the buff down when it is already up (a Hunter's
-- aspects toggle). combatAspect: the combat aspect button watches for
-- the forget spells (travel aspects) when combat starts. lead: the buff's
-- own "remind before it runs out" setting, {min, max, step, default} in
-- seconds, instead of the shared one (author: Battle Shout, "I usually don't
-- let BS get below 1 min"). combatWindow: a short or situational buff
-- (author's rule), shown only when needed: missing or within its lead, out
-- of combat and in it (DBR's own timing in combat); every other buff is
-- always shown. duration is its length when no out-of-combat read gave one.
-- castOnYou: its cast always lands on you too (Battle Shout), so any cast of
-- it in combat restarts its time.
-- pet: "hunter" or "warlock" (author, 1.5.0: "a 'no pet up' warning"): not
-- an aura; shown, also in combat, while you have no living pet (the game's
-- own [nopet] and [@pet,dead], so no reads), hidden while mounted, and, for a
-- Warlock, after a Demonic Sacrifice (sacrifice: its buffs). revive: the
-- Hunter's Revive Pet, for a dead pet.
-- tankOnly: shown only solo, or as your group's designated tank (the Tank
-- role, or a raid's main tank), or with the player's "Always show" switch.
-- knownBy: the spells that make it apply, instead of spells.
DBR.BUFFS = {
    MAGE = {
        {key = "arcaneIntellect", label = "Arcane Intellect", on = true,
            spells = {1459, 1460, 1461, 10156, 10157},
            group = {mana = true, spells = {{spell = 23028, reagent = 17020}}}},
        {key = "mageArmor", label = "Armor (Frost, Ice, or Mage Armor)", on = true,
            spells = {168, 7300, 7301, 7302, 7320, 10219, 10220, 6117, 22782, 22783, 27124, 27125, 30482},
            prefer = {6117, 7302, 168}},
        -- Off at first (author, 1.3.0: "add to DBR, off by default"). One
        -- reminder, as MTF's: the two cannot be on you together, so either
        -- counts; a click recasts the one you cast last, else Dampen.
        {key = "dampen", label = "Dampen or Amplify Magic", on = false,
            spells = {604, 8450, 8451, 10173, 10174, 1008, 8455, 10169, 10170}, prefer = {604, 1008}},
    },
    -- Any aspect counts as up (author); a click recasts the last combat aspect
    -- you cast (Hawk, Monkey, Wild, Beast), else Hawk, else Monkey.
    HUNTER = {
        {key = "aspect", label = "Aspect", on = true,
            spells = {13165, 14318, 14319, 14320, 14321, 14322, 25296, 13163, 20043, 20190, 13161, 5118, 13159},
            prefer = {13165, 13163}, forget = {5118, 13159}, bang = true, combatAspect = true},
        -- Call Pet; a click calls it, or revives it when it is dead (a
        -- right-click always revives).
        {key = "hunterPet", label = "Pet", on = true, pet = "hunter", spells = {883}, revive = 982},

    },
    -- Battle Shout reaches your party, so it sits in Group buffs (author: a
    -- buff that can go on another player); DBR watches it on you. It needs
    -- rage, which runs out soon after a fight.
    WARRIOR = {
        {key = "battleShout", label = "Battle Shout", on = true, others = true,
            spells = {6673, 5242, 6192, 11549, 11550, 11551, 25289},
            lead = {min = 5, max = 120, step = 5, default = 60}, combatWindow = true, duration = 120,
            castOnYou = true},
    },
    WARLOCK = {
        -- Demon Skin counts as Demon Armor before you learn it.
        {key = "demonArmor", label = "Demon Armor", on = true,
            spells = {687, 696, 706, 1086, 11733, 11734, 11735}, prefer = {706, 687}},
        -- Summon Imp, Voidwalker, Succubus, Felhunter, Felguard (TBC); a click
        -- summons the last one you summoned, else the Imp. Demonic Sacrifice:
        -- Burning Wish (Imp), Fel Stamina (Voidwalker), Touch of Shadow
        -- (Succubus; 35701, TBC's Felguard), Fel Energy (Felhunter).
        {key = "warlockPet", label = "Pet (your demon)", on = true, pet = "warlock",
            spells = {688, 697, 712, 691, 30146}, prefer = {688, 697, 712, 691, 30146},
            sacrifice = {18789, 18790, 18791, 18792, 35701}},

    },
    DRUID = {
        {key = "markOfTheWild", label = "Mark of the Wild", on = true, cancelForm = true,
            spells = {1126, 5232, 6756, 5234, 8907, 9884, 9885},
            group = {spells = {{spell = 21849, reagent = 17021}, {spell = 21850, reagent = 17026}}}},
        -- On the tank (author, a Druid player): solo or with no tank, on you.
        {key = "thorns", label = "Thorns", on = true, cancelForm = true, others = true, tank = true,
            spells = {467, 782, 1075, 8914, 9756, 9910}},
    },
    -- Self buffs only (author-approved): blessings are per member and
    -- situational, and PallyPower covers them.
    PALADIN = {
        -- Only when you may tank (author, 1.5.0: "only come up if I'm a
        -- designated Tank in Group/Raid, or, if solo"), or with the player's
        -- "Always show" switch.
        {key = "righteousFury", label = "Righteous Fury", on = true, spells = {25780}, tankOnly = true},
    },
    PRIEST = {
        {key = "fortitude", label = "Power Word: Fortitude", on = true,
            spells = {1243, 1244, 1245, 2791, 10937, 10938},
            group = {spells = {{spell = 21562, reagent = 17028}, {spell = 21564, reagent = 17029}}}},
        {key = "innerFire", label = "Inner Fire", on = true,
            spells = {588, 7128, 602, 1006, 10951, 10952}},
        {key = "divineSpirit", label = "Divine Spirit", on = false,
            spells = {14752, 14818, 14819, 27841},
            group = {mana = true, spells = {{spell = 27681, reagent = 17029}}}},
        {key = "shadowProtection", label = "Shadow Protection", on = false,
            spells = {976, 10957, 10958},
            group = {spells = {{spell = 27683, reagent = 17029}}}},
    },
}

-- Warnings, on-screen messages rather than icons (author, 1.5.0: "use the
-- same mechanism (Message Box on-screen, like DCM) for the taunting-warnings
-- ... instead of using icons"), for a group or raid where you are not the
-- designated tank. kind: "fury" (Righteous Fury up; spells) or "petTaunt"
-- (your pet's taunt on autocast; petTaunts, every rank, by name). knownBy:
-- the spells that make it apply (a pet's spells are not yours). Each has its
-- own switch under Reminders, on at first.
DBR.WARNINGS = {
    PALADIN = {
        {key = "furyOff", label = "Warn: Righteous Fury on when not tanking", kind = "fury", spells = {25780},
            knownBy = {25780}},
    },
    HUNTER = {
        {key = "hunterPetTaunt", label = "Warn: pet taunt on in a group", kind = "petTaunt",
            petTaunts = {2649, 14916, 14917, 14918, 14919, 14920, 14921, 27047}, knownBy = {883}},
    },
    -- The Voidwalker's Torment and Suffering; the Felguard's Anguish (TBC).
    WARLOCK = {
        {key = "warlockPetTaunt", label = "Warn: pet taunt on in a group", kind = "petTaunt",
            petTaunts = {3716, 7809, 7810, 7811, 11774, 11775, 27270, 17735, 17750, 17751, 17752, 27271, 33701, 33698, 33699, 33700}, knownBy = {697, 30146}},
    },
}
