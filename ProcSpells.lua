local addonName, DBR = ...

-- Every proc sound and its defaults, in one place (author-approved:
-- data-driven, built like the cooldown chimes). Add a class or proc here;
-- Procs and Options read only this table.
--
-- A proc is a buff the game gives you; the game plays its sound when the buff
-- appears, also in combat (C_UnitAuras.AddAuraSound). buff is the buff's name
-- in the client; spells are its Classic IDs (author: start with Classic's).
-- An ID counts only when the client names it buff, and the real ID is read
-- once the buff is on you out of combat, saved, and used from then on, so a
-- Forever ID that differs would correct itself. A safeguard only: no Classic
-- ID checked in client has changed on Forever so far (Polymorph, Conjure
-- Water and Food ranks 1-3); Seal of Fury is a new Forever spell, not a
-- changed one (John, 2026-11-16). None is confirmed in client yet (TESTING.md).
-- on is the default switch (author: Mage Clearcasting off, the game already
-- plays a sound for it; Flurry off); sound is a Dyre's Sounds file sound.
--
-- reactive: not a buff but an ability that becomes usable for a moment
-- (Overpower after a dodge, Revenge after a block, dodge, or parry; author:
-- "Warrior is missing ... Overpower and Revenge procs"; Hunter Mongoose Bite
-- after a dodge, John, 2026-11-24: "Mongoose Bite is like Overpower/Revenge
-- ... We should add that to DBR"). Its Classic rank 1
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
    -- Mongoose Bite (trained, not a talent): usable after your target dodges.
    HUNTER = {
        {key = "mongoosebite", label = "Mongoose Bite", reactive = 1495, on = true, sound = "talent"},
    },
}

-- Proc cues (1.13.0; John, 2026-11-20: DBR holds "all buffs/procs ...
-- chimes and visuals", Dyre's Shields Up shields only; docs/CUE_MODEL.md,
-- families Proc and Window). With Dyre's Toolkit's proc engine 2
-- (PROC_ENGINE_VERSION, Toolkit 2.12.0) DBR passes this catalog to
-- RegisterProcs: an arc each side of you while the proc is up and its sound,
-- each with its own switch. Without it, PROC_SOUNDS above (Proc Chimes) as
-- before. Same keys as PROC_SOUNDS and DSU 1.4's catalog, so settings carry
-- over and Owners "proc:<key>" match.
--
-- The proc engine's fields (Toolkit Procs.lua): key, label, buff (English),
-- class, talents (a player who knows one gets the cue and rows; every rank),
-- ids (candidate buff IDs; the engine uses one only when the client names it
-- the buff, and learns the real one out of combat), color, sound, soundOn and
-- arcOn (false: that switch starts off), stacks, tooltip; usable (an ability,
-- not a buff, shown while C_Spell.IsSpellUsable says so).
--
-- From DSU 1.4.1's Procs.lua (moved, with its notes): Missile Barrage
-- (talents 400588 and 1326083, TalentsForeverBook; buff 400589, a fact from
-- MageProcs 1.13.0; 44401 a spare), Fingers of Frost (talent 400647; buff
-- 400670, 2 charges: stacks = 2, the right arc shows only at both; 44544 a
-- spare), Nightfall (talents 18094, 18095; Shadow Trance 17941), Decimation
-- (talent 440870, new on Forever; no source gives its buff ID, so it shows
-- after the engine has read the ID once out of combat), the Druid (Omen of
-- Clarity 16864, a trained passive on Forever) and Shaman (Elemental Focus
-- 16164) Clearcastings, Overpower and Revenge (usable, rank 1 IDs), and
-- Mongoose Bite (1.13.4, usable 1495, as Overpower: no talents, so the engine
-- shows it once you know the spell itself). DBR's own
-- Proc Chimes before 1.13.0 (sound only by default, arcOn = false; John's
-- defaults kept: Mage Clearcasting off, the game plays a sound for it; Flurry
-- off; Nature's Grace on): Arcane Concentration (Classic ranks 11213,
-- 12574-12577; TalentsForeverBook names 11213 on Forever), Nature's Grace
-- (16880, TalentsForeverBook), Flurry (Classic ranks 12319, 12971-12974;
-- TalentsForeverBook names 12319). Sound switches start as Proc Chimes' did
-- (Nightfall off). No talent or buff ID here is confirmed in client.
DBR.ARCANE_MISSILES_SPELL = 5143
DBR.ARCANE_MISSILES_ENGLISH = "Arcane Missiles"
DBR.MISSILE_BARRAGE_TOOLTIP = "\n\nA macro that catches it, also during a cast:\n"
-- One art for every proc for now: white lightning the engine tints with each
-- proc's color, made by scripts/make_arcane_arcs.py to the engine's geometry
-- (John's own art, from DSU 1.4). New texture files need a full client restart.
DBR.PROC_ART = {
    right = "Interface\\AddOns\\" .. addonName .. "\\Textures\\ArcaneArc",
    left = "Interface\\AddOns\\" .. addonName .. "\\Textures\\ArcaneArcLeft",
    tint = true,
}
DBR.PROC_CUES = {
    {key = "missilebarrage", label = "Missile Barrage", buff = "Missile Barrage", class = "MAGE",
        talents = {400588, 1326083}, ids = {400589, 44401}, color = {0.62, 0.8, 1}, sound = "alertselect",
        macroTooltip = true},
    {key = "fingersoffrost", label = "Fingers of Frost", buff = "Fingers of Frost", class = "MAGE",
        talents = {400647}, ids = {400670, 44544}, color = {0.7, 0.95, 1}, sound = "frostyicespell1",
        stacks = 2,
        tooltip = "\n\nWith two charges up, both arcs show; when you use one, the right arc goes."},
    {key = "mageclearcasting", label = "Clearcasting (Arcane Concentration)", buff = "Clearcasting",
        class = "MAGE", talents = {11213, 12574, 12575, 12576, 12577}, ids = {12536}, color = {0.75, 0.85, 1},
        sound = "magical", soundOn = false, arcOn = false,
        tooltip = "Your next damage spell costs no mana."},
    {key = "nightfall", label = "Nightfall (Shadow Trance)", buff = "Shadow Trance", class = "WARLOCK",
        talents = {18094, 18095}, ids = {17941}, color = {0.35, 0.95, 0.35}, sound = "impspell", soundOn = false,
        tooltip = "Shadow Trance: your next Shadow Bolt is instant."},
    {key = "decimation", label = "Decimation", buff = "Decimation", class = "WARLOCK",
        talents = {440870}, ids = {}, color = {1, 0.45, 0.1}, sound = "powerup",
        tooltip = "Soul Fire casts faster and costs no Soul Shard for 10 seconds."},
    {key = "druidclearcasting", label = "Clearcasting (Omen of Clarity)", buff = "Clearcasting", class = "DRUID",
        talents = {16864}, ids = {16870}, color = {0.85, 0.95, 1}, sound = "magical", soundOn = false,
        tooltip = "Your next damage or healing spell or offensive ability costs nothing."},
    {key = "naturesgrace", label = "Nature's Grace", buff = "Nature's Grace", class = "DRUID",
        talents = {16880}, ids = {16886}, color = {0.4, 1, 0.5}, sound = "magical", arcOn = false,
        tooltip = "Your next spell casts faster."},
    {key = "shamanclearcasting", label = "Clearcasting (Elemental Focus)", buff = "Clearcasting",
        class = "SHAMAN", talents = {16164}, ids = {16246}, color = {0.3, 0.6, 1}, sound = "magical",
        soundOn = false, tooltip = "Your next damage spell costs no mana."},
    {key = "flurry", label = "Flurry", buff = "Flurry", class = "WARRIOR",
        talents = {12319, 12971, 12972, 12973, 12974}, ids = {12966, 12967, 12968, 12969, 12970},
        color = {1, 0.6, 0.3}, sound = "magical", soundOn = false, arcOn = false,
        tooltip = "Your next three swings are faster."},
    {key = "overpower", label = "Overpower", class = "WARRIOR", usable = 7384, color = {1, 0.35, 0.2},
        sound = "talent",
        tooltip = "After your target dodges; dimmed while you lack the rage."},
    {key = "revenge", label = "Revenge", class = "WARRIOR", usable = 6572, color = {1, 0.8, 0.25},
        sound = "magical",
        tooltip = "After you block, dodge, or parry; dimmed while you lack the rage."},
    {key = "mongoosebite", label = "Mongoose Bite", class = "HUNTER", usable = 1495, color = {0.55, 0.9, 0.3},
        sound = "talent",
        tooltip = "After your target dodges; dimmed while you lack the mana."},
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
-- chimes have the same delay"; 2026-11-17: "Can we reduce the delay by about
-- 75%?": 0.75 s to 0.2 s). Forms are also debounced; casts are not.
DBR.CAST_CHIME_DELAY = 0.2
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
