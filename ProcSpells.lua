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

-- Cast chimes (author, 1.4.0: "a sound when Travel Form, Pact of Cheeta and
-- Sprint fire off ... the road-runner meep meep or something fun"): a sound
-- just after you cast one of these (CAST_CHIME_DELAY), also in combat, every
-- rank by name. The Road Runner's own sound is copyrighted, so the default is Text to Speech
-- saying the spell's speech (else DBR.CAST_SPEECH); each spell has its own
-- switch and sound. Classic IDs; Travel Form and the aspects have no
-- cooldown, Sprint and Dash chime under Chimes too. form: a Druid form
-- (author: "Shifting INTO form only, not out"), which chimes when you enter
-- it, from the form change, never when you leave it. sound: the spell's own
-- default (a Dyre's Sounds key; one an older Dyre's Sounds lacks plays the
-- chimes' default). whenKnown: listed only once you know it (later clients'
-- spells, such as TBC's Intervene).
DBR.DEFAULT_CAST_SOUND = "voice"
-- Seconds before every cast chime (author: "add a .75 second delay ... and
-- debounce it (powershifting)"; 1.5.0: "the half-second delay on cast chimes
-- means we do NOT have to disable the built-in sounds ... Make sure all cast
-- chimes have the same delay"). Forms are also debounced; casts are not.
DBR.CAST_CHIME_DELAY = 0.75
DBR.CAST_SPEECH = "Meep meep"
DBR.CAST_SOUNDS = {
    DRUID = {
        {key = "travelform", label = "Travel Form", spells = {783}, on = true, form = true},
        {key = "bearform", label = "Bear Form (and Dire Bear)", spells = {5487, 9634}, on = true, form = true,
            speech = "Rawr"},
        {key = "catform", label = "Cat Form", spells = {768}, on = true, form = true, speech = "Meow"},
        {key = "aquaticform", label = "Aquatic Form", spells = {1066}, on = true, form = true, speech = "Splash"},
        {key = "moonkinform", label = "Moonkin Form", spells = {24858}, on = true, form = true, speech = "Hoot hoot"},
        {key = "dash", label = "Dash", spells = {1850, 9821, 9823}, on = false},
        -- A Druid's Warrior-like abilities (author, 1.5.0: "druid has some
        -- warrior-like abilities/talents (Feral Charge, Enrage) - make sure
        -- they work too"), with Dyre's Aggression sounds. Casts, not forms:
        -- they chime on the cast, after the same wait. Feral Charge is a
        -- talent, so it is listed once known.
        {key = "feralcharge", label = "Feral Charge", spells = {16979}, on = true, sound = "orccharge",
            speech = "Feral Charge", whenKnown = true},
        {key = "enrage", label = "Enrage", spells = {5229}, on = true, sound = "rageattack", speech = "Enrage"},
        {key = "demoroar", label = "Demoralizing Roar", spells = {99, 1735, 9490, 9747, 9898, 26998}, on = false,
            sound = "orcangry", speech = "Demoralizing Roar"},
        {key = "challengingroar", label = "Challenging Roar", spells = {5209}, on = false, sound = "crowdcharge",
            speech = "Challenging Roar"},
        {key = "bash", label = "Bash", spells = {5211, 6798, 8983}, on = false, sound = "orcfury", speech = "Bash"},
        {key = "frenziedregen", label = "Frenzied Regeneration", spells = {22842, 22895, 22896, 26999}, on = false,
            sound = "raspyshout", speech = "Frenzied Regeneration"},
    },
    HUNTER = {
        {key = "cheetah", label = "Aspect of the Cheetah", spells = {5118}, on = true},
        {key = "pack", label = "Aspect of the Pack", spells = {13159}, on = false},
    },
    ROGUE = {
        {key = "sprint", label = "Sprint", spells = {2983, 8696, 11305}, on = true},
    },
    -- Author, 1.5.0 (from a look at Full Steel, which plays sounds on these
    -- casts): Dyre's Sounds 1.2.0's "Dyre's Aggression" sounds; Charge,
    -- Intercept, and Execute on, the rest off. Text to Speech says the name.
    WARRIOR = {
        {key = "charge", label = "Charge", spells = {100, 6178, 11578}, on = true, sound = "militarycharge",
            speech = "Charge"},
        {key = "intercept", label = "Intercept", spells = {20252, 20616, 20617, 25272, 25275}, on = true,
            sound = "orccharge", speech = "Intercept"},
        {key = "execute", label = "Execute", spells = {5308, 20658, 20660, 20661, 20662, 25234, 25236}, on = true,
            sound = "angryscream", speech = "Execute"},
        {key = "whirlwind", label = "Whirlwind", spells = {1680}, on = false, sound = "rageattack",
            speech = "Whirlwind"},
        {key = "battleshoutcast", label = "Battle Shout", spells = {6673, 5242, 6192, 11549, 11550, 11551, 25289, 2048},
            on = false, sound = "raspyshout", speech = "Battle Shout"},
        {key = "demoshout", label = "Demoralizing Shout", spells = {1160, 6190, 11554, 11555, 11556, 25202, 25203},
            on = false, sound = "orcangry", speech = "Demoralizing Shout"},
        {key = "challengingshout", label = "Challenging Shout", spells = {1161}, on = false, sound = "crowdcharge",
            speech = "Challenging Shout"},
        {key = "intimidatingshout", label = "Intimidating Shout", spells = {5246}, on = false, sound = "orcfury",
            speech = "Intimidating Shout"},
        {key = "taunt", label = "Taunt", spells = {355}, on = false, sound = "piratecharge", speech = "Taunt"},
        {key = "rend", label = "Rend", spells = {772, 6546, 6547, 6548, 11572, 11573, 11574, 25208}, on = false,
            sound = "rageattack", speech = "Rend"},
        {key = "intervene", label = "Intervene", spells = {3411}, on = false, sound = "whistlecharge",
            speech = "Intervene", whenKnown = true},
        {key = "commandingshout", label = "Commanding Shout", spells = {469}, on = false, sound = "raspyshout",
            speech = "Commanding Shout", whenKnown = true},
        {key = "victoryrush", label = "Victory Rush", spells = {34428}, on = false, sound = "childrencharge",
            speech = "Victory Rush", whenKnown = true},
    },
}

-- Combo point chimes (author, 1.6.0: "when combo points are earned in Druid
-- Cat Form or Rogue's, we need to play a chime", as the Hear Kitty AddOn
-- does): a note per point gained, the held high note at the most, and a
-- sound when they are spent. finishers: the casts that spend them, every
-- rank by name, for a client whose count is secret (Forever).
DBR.COMBO_CLASSES = {ROGUE = true, DRUID = true}
-- The note sets (author, 1.7.0: "Try this as the primary theme for
-- combo-point notes, move what we have to a second theme"): Dyre's Sounds
-- 1.4.0's "Dyre's Bassoon", a chromatic climb from Bb to the held F, and
-- 1.3.0's "Dyre's Sax", Bb up to the held high Bb. notes: the points below
-- the most; full and spend: the Full and Spend sounds' defaults. "full" plays
-- Full's sound for every point and keeps the Full and Spend sounds as they are.
DBR.COMBO_SETS = {
    bassoon = {label = "Bassoon", notes = {"bassoon1", "bassoon2", "bassoon3", "bassoon4", "bassoon5", "bassoon6",
        "bassoon7"}, full = "bassoon8", spend = "bassoon1"},
    sax = {label = "Sax", notes = {"sax1", "sax2", "sax3", "sax4", "sax5", "sax6", "sax7"}, full = "sax8",
        spend = "sax1"},
    full = {label = "Same as Full"},
}
DBR.COMBO_SET_ORDER = {"bassoon", "sax", "full"}
DBR.COMBO_DEFAULT_SET = "bassoon"
DBR.COMBO_FULL_SOUND = DBR.COMBO_SETS.bassoon.full
DBR.COMBO_SPEND_SOUND = DBR.COMBO_SETS.bassoon.spend
-- With a Dyre's Sounds older than 1.4.0 a bassoon note plays the sax note of
-- the same number (then the chimes' default).
DBR.COMBO_FALLBACK = {pattern = "^bassoon(%d)$", prefix = "sax"}
-- The note for each change when the count cannot be read: the set's third.
DBR.COMBO_SECRET_INDEX = 3
-- Between queued notes (the cuts run 0.22-0.3 s).
DBR.COMBO_NOTE_GAP = 0.13
-- A drop this close to a target change (either side) is the switch, not a
-- spend, unless your own finisher came as close.
DBR.COMBO_TARGET_WINDOW = 0.3
DBR.COMBO_FINISHERS = {
    ROGUE = {2098, 6760, 6761, 6762, 8623, 8624, 11299, 11300, 31016, 26865, 5171, 6774, 408, 8643, 1943, 8639,
        8640, 11273, 11274, 11275, 26867, 8647, 8649, 8650, 11197, 11198, 26866, 26679, 32645, 32684},
    DRUID = {22568, 22827, 22828, 22829, 31018, 24248, 1079, 9492, 9493, 9752, 9894, 9896, 27008, 22570},
}
