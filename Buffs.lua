local _, DBR = ...

-- The buffs each class is reminded of (author-approved for v1: Mage, Warlock,
-- Druid, Priest, and Paladin self buffs). Classic spell IDs; a buff counts by
-- name, so every rank does. Thorns stays self only (author).
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
-- cancelForm: a click while shapeshifted leaves the form first.
DBR.BUFFS = {
    MAGE = {
        {key = "arcaneIntellect", label = "Arcane Intellect", on = true,
            spells = {1459, 1460, 1461, 10156, 10157},
            group = {mana = true, spells = {{spell = 23028, reagent = 17020}}}},
        {key = "mageArmor", label = "Armor (Frost, Ice, or Mage Armor)", on = true,
            spells = {168, 7300, 7301, 7302, 7320, 10219, 10220, 6117, 22782, 22783}, prefer = {6117, 7302, 168}},
        {key = "dampenMagic", label = "Dampen or Amplify Magic", on = false,
            spells = {604, 8450, 8451, 10173, 10174, 1008, 8455, 10169, 10170}, prefer = {604, 1008}},
    },
    WARLOCK = {
        -- Demon Skin counts as Demon Armor before you learn it.
        {key = "demonArmor", label = "Demon Armor", on = true,
            spells = {687, 696, 706, 1086, 11733, 11734, 11735}, prefer = {706, 687}},
    },
    DRUID = {
        {key = "markOfTheWild", label = "Mark of the Wild", on = true, cancelForm = true,
            spells = {1126, 5232, 6756, 5234, 8907, 9884, 9885},
            group = {spells = {{spell = 21849, reagent = 17021}, {spell = 21850, reagent = 17026}}}},
        {key = "thorns", label = "Thorns", on = true, cancelForm = true,
            spells = {467, 782, 1075, 8914, 9756, 9910}},
    },
    -- Self buffs only (author-approved): blessings are per member and
    -- situational, and PallyPower covers them.
    PALADIN = {
        {key = "righteousFury", label = "Righteous Fury", on = true, spells = {25780}},
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
