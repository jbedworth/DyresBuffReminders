local _, DBR = ...

-- Proc sounds (author-approved, played the way WTF plays Nightfall): a sound
-- the moment a proc buff appears on you, also in combat. AddOn code cannot
-- read buffs in combat, so DBR asks the game to play it
-- (C_UnitAuras.AddAuraSound, trigger Added, one registration per buff ID).
-- Auras are read only out of combat, to learn a proc's real buff ID (see
-- ProcSpells.lua); never in combat. The game refuses aura sound changes
-- during a boss encounter, so registration then waits until it ends.
--
-- Reactive abilities (ProcSpells.lua's reactive) are not buffs: DBR plays
-- their sound itself when C_Spell.IsSpellUsable turns true, on
-- SPELL_UPDATE_USABLE, also in combat. Rage going up and down makes the
-- answer flicker within one window, so a sound plays at most once per
-- REACTIVE_GAP seconds; a secret answer is skipped, never compared.

DBR.DEFAULT_PROC_SOUND = "magical"
-- At most one sound per this many seconds (the API allows 0 to 5).
local SOUND_THROTTLE = 1
local AURA_FILTER = "HELPFUL"
local REACTIVE_GAP = 3

local procs = {list = {}, handles = {}, deferred = false, available = false, usable = {}, playedAt = {}}

-- The proc sounds of a class, in settings order; none for a class without a list.
function DBR.ClassProcs(classFile)
    return DBR.PROC_SOUNDS[classFile] or {}
end

-- Whether the client can play aura sounds at all.
function DBR.HasProcSounds()
    return procs.available
end

-- A saved sound key in the library's spelling when it can be an aura sound
-- (a file), else the proc's default. Without the library a key is kept.
function DBR.SanitizeProcSound(key, default)
    default = default or DBR.DEFAULT_PROC_SOUND
    if type(key) ~= "string" then
        return default
    end
    local library = DBR.SoundLibrary()
    if not library or type(library.AuraSound) ~= "function" then
        return key
    end
    local resolved = library.Resolve(key)
    return resolved and library.AuraSound(resolved) and resolved or default
end

-- The proc settings, repaired; Core calls this from SanitizeDB. learned holds
-- the real buff ID read in client, per proc.
function DBR.SanitizeProcs(saved)
    saved = type(saved) == "table" and saved or {}
    local spells = type(saved.spells) == "table" and saved.spells or {}
    local sounds = type(saved.sounds) == "table" and saved.sounds or {}
    local learned = type(saved.learned) == "table" and saved.learned or {}
    local clean = {enabled = saved.enabled ~= false, spells = {}, sounds = {}, learned = {}}
    for _, list in pairs(DBR.PROC_SOUNDS) do
        for _, proc in ipairs(list) do
            if type(spells[proc.key]) == "boolean" then
                clean.spells[proc.key] = spells[proc.key]
            else
                clean.spells[proc.key] = proc.on
            end
            if proc.reactive then
                -- Played by DBR, so any sound: the chimes' rules.
                local default = proc.sound or DBR.DEFAULT_PROC_SOUND
                clean.sounds[proc.key] = DBR.SanitizeChimeSound and DBR.SanitizeChimeSound(sounds[proc.key], default)
                    or (type(sounds[proc.key]) == "string" and sounds[proc.key]) or default
            else
                clean.sounds[proc.key] = DBR.SanitizeProcSound(sounds[proc.key], proc.sound)
            end
            local id = learned[proc.key]
            if type(id) == "number" and id > 0 and id == math.floor(id) then
                clean.learned[proc.key] = id
            end
        end
    end
    return clean
end

-- The IDs a proc's sound is registered for: its listed IDs the client names
-- as the buff, and the ID read in client.
local function ProcIDs(proc)
    local ids, seen = {}, {}
    local function Add(id)
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    for _, id in ipairs(proc.spells) do
        local name = C_Spell.GetSpellName(id)
        if name and not DBR.IsSecret(name) and name == proc.buff then
            Add(id)
        end
    end
    local learned = DBR.db.procs.learned[proc.key]
    if learned then
        Add(learned)
    end
    return ids
end

-- The game refuses aura sound changes during a boss encounter.
local function Restricted()
    if type(C_RestrictedActions) ~= "table" or type(C_RestrictedActions.IsAddOnRestrictionActive) ~= "function"
        or type(Enum) ~= "table" or type(Enum.AddOnRestrictionType) ~= "table" then
        return false
    end
    return C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Encounter) == true
end

-- Registers every switched-on proc's sound, or removes them; waits out an encounter.
function DBR.ApplyProcSounds()
    if not procs.available then
        return
    end
    if Restricted() then
        procs.deferred = true
        return
    end
    procs.deferred = false
    for _, handle in ipairs(procs.handles) do
        C_UnitAuras.RemoveAuraSound(handle)
    end
    procs.handles = {}
    procs.registered = {}
    local settings = DBR.db.procs
    local library = DBR.SoundLibrary()
    if not settings.enabled or not library or type(library.AuraSound) ~= "function" then
        return
    end
    local trigger = Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added or 0
    for _, proc in ipairs(procs.list) do
        local sound = not proc.reactive and settings.spells[proc.key] and (library.AuraSound(settings.sounds[proc.key])
            or library.AuraSound(proc.sound or DBR.DEFAULT_PROC_SOUND))
        if sound then
            procs.registered[proc.key] = {}
            for _, id in ipairs(ProcIDs(proc)) do
                local handle = C_UnitAuras.AddAuraSound(trigger, {
                    spellID = id,
                    unitToken = "player",
                    outputChannel = "master",
                    throttleSeconds = SOUND_THROTTLE,
                    soundFileName = sound.soundFileName,
                    soundFileID = sound.soundFileID,
                })
                if handle then
                    procs.handles[#procs.handles + 1] = handle
                    table.insert(procs.registered[proc.key], id)
                end
            end
        end
    end
end

-- Plays a proc's sound once, so the settings page can preview it.
function DBR.PreviewProc(key)
    local library = DBR.SoundLibrary()
    if library then
        library.Play(DBR.db.procs.sounds[key])
    end
end

-- Out of combat only: reads the real ID of each switched-on proc buff on you.
-- A new one is saved and registered, so the sound follows Forever's own ID.
local function Learn()
    local settings = DBR.db.procs
    if InCombatLockdown() or not procs.available or not settings.enabled then
        return
    end
    local grew = false
    for _, proc in ipairs(procs.list) do
        local aura = not proc.reactive and settings.spells[proc.key]
            and C_UnitAuras.GetAuraDataBySpellName("player", proc.buff, AURA_FILTER)
        -- A secret answer is never tested or indexed.
        if not DBR.IsSecret(aura) and aura then
            local id = aura.spellId
            if type(id) == "number" and not DBR.IsSecret(id) and settings.learned[proc.key] ~= id then
                settings.learned[proc.key] = id
                grew = true
            end
        end
    end
    if grew then
        DBR.ApplyProcSounds()
    end
end

-- Also in combat: a sound when a switched-on reactive ability turns usable.
local function CheckReactive()
    local settings = DBR.db.procs
    if type(C_Spell.IsSpellUsable) ~= "function" then
        return
    end
    for _, proc in ipairs(procs.list) do
        local name = proc.reactive and C_Spell.GetSpellName(proc.reactive)
        if name and not DBR.IsSecret(name) then
            local usable = C_Spell.IsSpellUsable(name)
            if not DBR.IsSecret(usable) then
                usable = usable == true
                local was = procs.usable[proc.key]
                procs.usable[proc.key] = usable
                local now = GetTime()
                if usable and not was and settings.enabled and settings.spells[proc.key]
                        and now - (procs.playedAt[proc.key] or -REACTIVE_GAP) >= REACTIVE_GAP then
                    procs.playedAt[proc.key] = now
                    local library = DBR.SoundLibrary()
                    if library and not library.Play(settings.sounds[proc.key], proc.label) then
                        library.Play(DBR.DEFAULT_PROC_SOUND, proc.label)
                    end
                end
            end
        end
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "SPELL_UPDATE_USABLE" then
        CheckReactive()
        return
    end
    if event == "UNIT_AURA" then
        if unit == "player" then
            Learn()
        end
        return
    end
    if procs.deferred and not Restricted() then
        DBR.ApplyProcSounds()
    end
    if event == "PLAYER_REGEN_ENABLED" then
        Learn()
    end
end)

function DBR.InitializeProcs(classFile)
    procs.list = DBR.ClassProcs(classFile)
    for _, proc in ipairs(procs.list) do
        if proc.reactive then
            events:RegisterEvent("SPELL_UPDATE_USABLE")
        end
    end
    if type(C_UnitAuras) ~= "table" or type(C_UnitAuras.AddAuraSound) ~= "function"
        or type(C_UnitAuras.RemoveAuraSound) ~= "function" then
        return
    end
    procs.available = true
    events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    if #procs.list > 0 then
        events:RegisterUnitEvent("UNIT_AURA", "player")
    end
    DBR.ApplyProcSounds()
    Learn()
end

-- On the proc sounds' first run on a Warlock, copies the Nightfall switch and
-- sound from Warlock Tools Forever (author: WTF's Nightfall stands aside for
-- DBR); read only, never written.
function DBR.ImportProcs(classFile)
    local saved = classFile == "WARLOCK" and rawget(_G, "WarlockToolsForeverDB")
    local alerts = type(saved) == "table" and saved.alerts
    if type(alerts) ~= "table" or type(alerts.nightfall) ~= "boolean" then
        return false
    end
    DBR.db.procs.spells.nightfall = alerts.nightfall
    if type(alerts.nightfallSound) == "string" then
        DBR.db.procs.sounds.nightfall = DBR.SanitizeProcSound(alerts.nightfallSound, "impspell")
    end
    DBR.Report("Copied your Nightfall sound setting from Warlock Tools Forever.")
    return true
end

-- Other AddOns that play a proc's sound themselves, until they stand aside for
-- DBR (author: as DBR treats older MTF and WTF chimes, it warns once and keeps
-- playing). asideFrom: their first version that plays none while DBR 0.3.0
-- or later is loaded. saved/switch: their saved switch, read only.
DBR.OTHER_PROCS = {
    {addon = "WarlockToolsForever", title = "Warlock Tools Forever", class = "WARLOCK", proc = "nightfall",
        db = "WarlockToolsForeverDB", group = "alerts", switch = "nightfall", asideFrom = {0, 3, 3}},
}

-- The titles of the other AddOns still playing a proc sound that DBR plays too.
function DBR.OtherProcs(classFile)
    local titles = {}
    local settings = DBR.db.procs
    for _, other in ipairs(DBR.OTHER_PROCS) do
        local saved = rawget(_G, other.db)
        local group = type(saved) == "table" and saved[other.group]
        if other.class == classFile and settings.enabled and settings.spells[other.proc]
            and DBR.AddOnLoaded(other.addon) and not DBR.StandsAside(other)
            and type(group) == "table" and group[other.switch] == true then
            titles[#titles + 1] = other.title
        end
    end
    return titles
end

-- Says once at login when an older AddOn also plays a proc sound.
function DBR.ReportOtherProcs(classFile)
    for _, title in ipairs(DBR.OtherProcs(classFile)) do
        DBR.Report(title .. " also plays the Nightfall sound, so you may hear it twice. Turn off its Nightfall "
            .. "sound, or update it: get it from CurseForge.")
    end
end

-- /dbr debug: each proc, its IDs, which the client names as the buff, the ID
-- read in client, and whether it is confirmed (read in client) or unverified.
function DBR.ReportProcsDebug(classFile)
    local settings = DBR.db and DBR.db.procs
    local others = settings and table.concat(DBR.OtherProcs(classFile), ", ") or ""
    DBR.Report(string.format("debug procs enabled=%s available=%s deferred=%s otherProcs=%s",
        tostring(settings and settings.enabled), tostring(procs.available), tostring(procs.deferred),
        others ~= "" and others or "none"))
    for _, proc in ipairs(DBR.ClassProcs(classFile)) do
        if proc.reactive then
            DBR.Report(string.format("debug procs %s on=%s sound=%s reactive=%s=%s usable=%s", proc.key,
                tostring(settings and settings.spells[proc.key]), tostring(settings and settings.sounds[proc.key]),
                proc.reactive, DBR.Describe(C_Spell.GetSpellName(proc.reactive)), tostring(procs.usable[proc.key])))
        else
            local named = {}
            for _, id in ipairs(proc.spells or {}) do
                local name = C_Spell.GetSpellName(id)
                named[#named + 1] = id .. "=" .. DBR.Describe(name)
            end
            local learned = settings and settings.learned[proc.key]
            local registered = procs.registered and procs.registered[proc.key]
            DBR.Report(string.format("debug procs %s on=%s sound=%s ids=%s learned=%s registered=%s status=%s",
                proc.key, tostring(settings and settings.spells[proc.key]),
                tostring(settings and settings.sounds[proc.key]),
                table.concat(named, ","), tostring(learned),
                registered and #registered > 0 and table.concat(registered, ",") or "none",
                learned and "confirmed" or "unverified"))
        end
    end
end

-- Cast chimes ------------------------------------------------------------------

-- The cast chimes' settings, repaired; Core calls this from SanitizeDB. Every
-- class's spells keep a setting. DBR plays them, so any sound.
function DBR.SanitizeCasts(saved)
    saved = type(saved) == "table" and saved or {}
    local spells = type(saved.spells) == "table" and saved.spells or {}
    local sounds = type(saved.sounds) == "table" and saved.sounds or {}
    local clean = {enabled = saved.enabled ~= false, spells = {}, sounds = {}}
    for _, list in pairs(DBR.CAST_SOUNDS) do
        for _, cast in ipairs(list) do
            if type(spells[cast.key]) == "boolean" then
                clean.spells[cast.key] = spells[cast.key]
            else
                clean.spells[cast.key] = cast.on
            end
            local default = cast.sound or DBR.DEFAULT_CAST_SOUND
            clean.sounds[cast.key] = DBR.SanitizeChimeSound and DBR.SanitizeChimeSound(sounds[cast.key], default)
                or (type(sounds[cast.key]) == "string" and sounds[cast.key]) or default
        end
    end
    return clean
end

function DBR.ClassCasts(classFile)
    return classFile and DBR.CAST_SOUNDS[classFile] or {}
end

local casts = {names = {}, byKey = {}}

-- Its own sound; one the client cannot play (no voice installed) falls back
-- to the chimes' default. Without Dyre's Sounds nothing plays.
local function PlayCast(cast)
    local library = DBR.SoundLibrary()
    if not library then
        return false
    end
    local speech = cast.speech or DBR.CAST_SPEECH
    if library.Play(DBR.db.casts.sounds[cast.key], speech) then
        return true
    end
    return library.Play(DBR.DEFAULT_CHIME_SOUND, speech)
end

function DBR.PreviewCast(key)
    local cast = casts.byKey[key]
    if cast then
        PlayCast(cast)
    end
end

local function CastFor(spellID)
    if DBR.IsSecret(spellID) or type(spellID) ~= "number" then
        return nil
    end
    local name = C_Spell.GetSpellName(spellID)
    return name and not DBR.IsSecret(name) and casts.names[name] or nil
end

local function Chime(cast)
    if cast and DBR.db.casts.enabled and DBR.db.casts.spells[cast.key] then
        casts.last = cast.label
        PlayCast(cast)
    end
end

-- The active form's spell ID, or nil (none, or unreadable). The pinned
-- StanceBar.lua reads the spell as GetShapeshiftFormInfo's fourth value.
local function ActiveForm()
    if type(GetNumShapeshiftForms) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then
        return nil
    end
    local count = GetNumShapeshiftForms()
    if DBR.IsSecret(count) or type(count) ~= "number" then
        return nil
    end
    for index = 1, count do
        local _, active, _, spellID = GetShapeshiftFormInfo(index)
        if not DBR.IsSecret(active) and active == true then
            return not DBR.IsSecret(spellID) and spellID or nil
        end
    end
end

local castEvents = CreateFrame("Frame")
castEvents:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UPDATE_SHAPESHIFT_FORM" then
        -- Into a form only, once things settle: each change (also leaving a
        -- form) cancels a pending chime; a new form waits CAST_CHIME_DELAY and
        -- chimes only if you are still in it, so a powershift (Cat, caster,
        -- Cat) chimes once and in-and-out none. The same form again (the
        -- event also fires on loading) changes nothing.
        local form = ActiveForm()
        if form == casts.form then
            return
        end
        casts.form = form
        casts.formToken = (casts.formToken or 0) + 1
        local cast = form and CastFor(form)
        if cast and cast.form then
            local token = casts.formToken
            C_Timer.After(DBR.CAST_CHIME_DELAY, function()
                if casts.formToken == token and ActiveForm() == form then
                    Chime(cast)
                end
            end)
        end
        return
    end
    local cast = CastFor(spellID)
    -- A form chimes from the form change, so leaving it (a cast too) does not.
    -- Every cast chimes, each after the same wait as a form.
    if cast and not cast.form then
        C_Timer.After(DBR.CAST_CHIME_DELAY, function() Chime(cast) end)
    end
end)

-- Your class's cast chimes, by every rank's name; the player's casts only,
-- readable also in combat (UNIT_SPELLCAST_SUCCEEDED).
function DBR.InitializeCasts(classFile)
    for _, cast in ipairs(DBR.ClassCasts(classFile)) do
        casts.byKey[cast.key] = cast
        for _, id in ipairs(cast.spells) do
            local name = C_Spell.GetSpellName(id)
            if name then
                casts.names[name] = cast
            end
        end
    end
    if next(casts.names) then
        castEvents:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    end
    for _, cast in pairs(casts.byKey) do
        if cast.form then
            -- No chime for the form you log in in.
            casts.form = ActiveForm()
            castEvents:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
            break
        end
    end
end

function DBR.ReportCastsDebug(classFile)
    local parts = {}
    for _, cast in ipairs(DBR.ClassCasts(classFile)) do
        parts[#parts + 1] = string.format("%s=%s:%s", cast.key, DBR.db.casts.spells[cast.key] and "on" or "off",
            tostring(DBR.db.casts.sounds[cast.key]))
    end
    DBR.Report(string.format("debug casts enabled=%s %s last=%s", tostring(DBR.db.casts.enabled),
        #parts > 0 and table.concat(parts, " ") or "none", tostring(casts.last)))
end

-- Combo point chimes ----------------------------------------------------------------

-- The settings, repaired; Core calls this from SanitizeDB.
function DBR.SanitizeCombo(saved)
    saved = type(saved) == "table" and saved or {}
    local function Sound(key, default)
        return DBR.SanitizeChimeSound and DBR.SanitizeChimeSound(key, default)
            or (type(key) == "string" and key) or default
    end
    local set = DBR.COMBO_SETS[saved.noteSet or ""] and saved.noteSet
    local fullSound, spendSound = saved.fullSound, saved.spendSound
    if not set then
        -- 1.6.0 had a sax scale switch (scale). Off becomes "Same as Full";
        -- on becomes the new default, bassoon, unless the player chose a
        -- Full or Spend sound of their own, which stays with the sax.
        local sax = DBR.COMBO_SETS.sax
        local own = (fullSound ~= nil and fullSound ~= sax.full) or (spendSound ~= nil and spendSound ~= sax.spend)
        set = saved.scale == false and "full" or (own and "sax" or DBR.COMBO_DEFAULT_SET)
        if not own then
            fullSound, spendSound = nil, nil
        end
    end
    local defaults = DBR.COMBO_SETS[set].full and DBR.COMBO_SETS[set] or DBR.COMBO_SETS[DBR.COMBO_DEFAULT_SET]
    return {enabled = saved.enabled ~= false, full = saved.full ~= false, spend = saved.spend ~= false,
        onlyFull = saved.onlyFull == true, noteSet = set,
        fullSound = Sound(fullSound, defaults.full), spendSound = Sound(spendSound, defaults.spend)}
end

-- Whether a Full (which "full") or Spend sound is some set's default, not
-- one the player chose.
local function SetDefault(which, key)
    for _, set in pairs(DBR.COMBO_SETS) do
        if set[which] and set[which] == key then
            return true
        end
    end
    return false
end

-- A new note set: Full and Spend follow a set with notes, unless the player
-- chose their own; "Same as Full" keeps them as they are.
function DBR.SetComboNoteSet(set)
    local saved = DBR.db.combo
    local new = DBR.COMBO_SETS[set]
    if not new then
        return
    end
    if new.full and SetDefault("full", saved.fullSound) then
        saved.fullSound = new.full
    end
    if new.spend and SetDefault("spend", saved.spendSound) then
        saved.spendSound = new.spend
    end
    saved.noteSet = set
end

function DBR.HasComboChimes()
    return DBR.COMBO_CLASSES[DBR.classFile or ""] == true
end

-- Last count, the notes waiting to play, and the finishers' names.
local combo = {queue = {}, finishers = {}, history = {}}
local COMBO_POWER = "COMBO_POINTS"
local CAT_FORM_ID = 1
-- The last actions (counts read, notes queued and played) for /dbr debug.
local COMBO_HISTORY = 8

local function Log(text)
    local history = combo.history
    history[#history + 1] = string.format("%.2f %s", GetTime(), text)
    if #history > COMBO_HISTORY then
        table.remove(history, 1)
    end
end

-- One sound; one an older Dyre's Sounds lacks plays the chimes' default.
local function PlayCombo(key, speech)
    local library = DBR.SoundLibrary()
    if not library then
        Log("play " .. tostring(key) .. " no-library")
        return
    end
    if library.Play(key, speech) then
        Log("play " .. tostring(key))
        return
    end
    -- An older Dyre's Sounds: the sax note of the same number, then the default.
    local number = type(key) == "string" and key:match(DBR.COMBO_FALLBACK.pattern)
    local sax = number and DBR.COMBO_FALLBACK.prefix .. number
    if sax and library.Play(sax, speech) then
        Log("play " .. key .. " as " .. sax)
        return
    end
    Log("play " .. tostring(key) .. " fallback=" .. tostring(library.Play(DBR.DEFAULT_CHIME_SOUND, speech)))
end

-- Notes play in order, one gap apart, by C_Timer (no OnUpdate).
local function PlayNext()
    local note = table.remove(combo.queue, 1)
    if not note then
        combo.playing = false
        return
    end
    combo.playing = true
    -- The next one is set first, so a failing Play cannot stop the queue.
    C_Timer.After(DBR.COMBO_NOTE_GAP, PlayNext)
    PlayCombo(note.key, note.speech)
end

-- hold: queue only; the caller starts the queue once all its notes are in,
-- so a failing first note cannot lose the rest.
local function Enqueue(key, speech, hold)
    combo.queue[#combo.queue + 1] = {key = key, speech = speech}
    Log("queue " .. tostring(key) .. (#combo.queue > 1 and " behind " .. (#combo.queue - 1) or ""))
    if not hold and not combo.playing then
        PlayNext()
    end
end

function DBR.PreviewCombo(which)
    local saved = DBR.db.combo
    PlayCombo(which == "spend" and saved.spendSound or saved.fullSound, which == "spend" and "Spent" or "Full")
end

-- A Druid counts only in Cat Form: GetShapeshiftFormID 1 (Classic's
-- CAT_FORM, Era's Constants.lua) or the active form being Cat Form by its
-- spell's name; either is enough (player report: "Not working on the druid").
local function CatByID()
    if type(GetShapeshiftFormID) ~= "function" then
        return false
    end
    local id = GetShapeshiftFormID()
    return not DBR.IsSecret(id) and id == (rawget(_G, "CAT_FORM") or CAT_FORM_ID)
end

local function CatBySpell()
    local cat = C_Spell.GetSpellName(768)
    if not cat or type(GetNumShapeshiftForms) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then
        return false
    end
    local count = GetNumShapeshiftForms()
    for index = 1, (not DBR.IsSecret(count) and type(count) == "number" and count or 0) do
        local _, active, _, spellID = GetShapeshiftFormInfo(index)
        if active == true and not DBR.IsSecret(spellID) and spellID and C_Spell.GetSpellName(spellID) == cat then
            return true
        end
    end
    return false
end

local function InCatForm()
    return CatByID() or CatBySpell()
end

local function Counts()
    return DBR.classFile ~= "DRUID" or InCatForm()
end

-- The count and the most: the higher of UnitPower and Classic's
-- GetComboPoints on the target (a Druid's may read on only one of them); a
-- readable one wins over a secret one. Both secret or missing: "secret" or nil.
local function ReadCount()
    local power = type(Enum) == "table" and Enum.PowerType and Enum.PowerType.ComboPoints
    local count, most
    if power and type(UnitPower) == "function" then
        count = UnitPower("player", power)
        most = type(UnitPowerMax) == "function" and UnitPowerMax("player", power) or nil
    end
    if type(GetComboPoints) == "function" then
        local onTarget = GetComboPoints("player", "target")
        if not DBR.IsSecret(onTarget) and type(onTarget) == "number"
            and (DBR.IsSecret(count) or type(count) ~= "number" or onTarget > count) then
            count = onTarget
        end
    end
    if DBR.IsSecret(count) then
        return "secret"
    end
    if DBR.IsSecret(most) or type(most) ~= "number" or most < 1 then
        most = rawget(_G, "MAX_COMBO_POINTS") or 5
    end
    return type(count) == "number" and count or nil, most
end

-- The note for reaching count of most: the most plays Full's sound; below
-- it, a rising note (or Full's sound, without "Rising notes").
local function NoteFor(count, most)
    local saved = DBR.db.combo
    if count >= most then
        return saved.full and saved.fullSound or nil, "Full"
    end
    if saved.onlyFull then
        return nil
    end
    local notes = DBR.COMBO_SETS[saved.noteSet].notes
    if not notes then
        return saved.fullSound, tostring(count)
    end
    return notes[math.min(count, #notes)], tostring(count)
end

-- otherPower: the event named another power (a Druid's Energy); then only a
-- readable count is read, so a secret one plays no note per Energy tick.
-- Fewer points: a spend, unless a target change is as close (Era loses
-- the points on a switch; Forever shows the new mob's). Your own finisher
-- that close makes it a spend after all. With neither yet, wait the window.
local function Dropped()
    local saved = DBR.db.combo
    local window = DBR.COMBO_TARGET_WINDOW
    local now = GetTime()
    combo.pending = nil
    if combo.finisherAt and now - combo.finisherAt <= window then
        Enqueue(saved.spendSound, "Spent")
        return
    end
    if combo.targetAt and now - combo.targetAt <= window then
        Log("drop after a target change: silent")
        return
    end
    local token = (combo.dropToken or 0) + 1
    combo.dropToken, combo.pending = token, now
    C_Timer.After(window, function()
        if combo.dropToken ~= token or not combo.pending then
            return
        end
        local at = combo.pending
        combo.pending = nil
        if not (combo.targetAt and combo.targetAt >= at) then
            Enqueue(DBR.db.combo.spendSound, "Spent")
        else
            Log("drop before a target change: silent")
        end
    end)
end

local function Changed(otherPower)
    local saved = DBR.db.combo
    if not saved.enabled or not DBR.db.enabled or not Counts() then
        combo.last = nil
        return
    end
    local count, most = ReadCount()
    if count == "secret" and otherPower then
        return
    end
    if count == "secret" then
        -- Forever: the count is secret; one mid note per change, and the
        -- spend sound from your own finisher (UNIT_SPELLCAST_SUCCEEDED).
        combo.secret, combo.last = true, nil
        if not saved.onlyFull then
            local notes = DBR.COMBO_SETS[saved.noteSet].notes
            Enqueue(notes and notes[DBR.COMBO_SECRET_INDEX] or saved.fullSound, "Point")
        end
        return
    end
    combo.secret = false
    if not count then
        return
    end
    -- No count taken yet (a Druid just shifted into Cat Form, or its form
    -- read late): from none, so the first point plays.
    local last = combo.last or 0
    combo.last = count
    if count == last then
        return
    end
    Log(string.format("%s %d>%d of %d", tostring(combo.event or "?"), last, count, most))
    if count > last then
        for point = last + 1, count do
            local key, speech = NoteFor(point, most)
            if key then
                Enqueue(key, speech, true)
            end
        end
        if not combo.playing then
            PlayNext()
        end
        return
    end
    -- Fewer: spent, but one point lost out of combat is decay, silent.
    if last - count == 1 and not InCombatLockdown() then
        Log("decay: silent")
        return
    end
    if saved.spend then
        Dropped()
    end
end

-- Quietly take the count as it is now (a new target, a new form, login).
local function Baseline(event)
    local count = ReadCount()
    local taken = Counts() and type(count) == "number" and count or nil
    if taken ~= combo.last then
        Log(string.format("%s takes %s>%s", tostring(event or "login"), tostring(combo.last), tostring(taken)))
    end
    combo.last = taken
end

local comboEvents = CreateFrame("Frame")
comboEvents:SetScript("OnEvent", function(_, event, unit, powerType, spellID)
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        -- Era's ComboFrame re-reads on every player power event, whatever its
        -- power; a Druid's points may come with another one (player report:
        -- the Rogue chimes on Era, the Druid in Cat Form does not).
        local combos = not DBR.IsSecret(powerType) and powerType == COMBO_POWER
        combo.event = event .. " " .. DBR.Describe(powerType)
        Changed(not combos)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local saved = DBR.db.combo
        local name = not DBR.IsSecret(spellID) and C_Spell.GetSpellName(spellID) or nil
        if not (name and combo.finishers[name]) then
            return
        end
        combo.finisherAt = GetTime()
        if saved.enabled and saved.spend and Counts() and (combo.secret or combo.pending) then
            -- A secret count's spend, or a drop waiting on a target change.
            combo.pending = nil
            Enqueue(saved.spendSound, "Spent")
        end
    else
        if event == "PLAYER_TARGET_CHANGED" or event == "COMBO_TARGET_CHANGED" then
            combo.targetAt = GetTime()
        end
        Baseline(event)
    end
end)

-- Rogues and Druids: the player's combo points, on the events only.
function DBR.InitializeCombo(classFile)
    if not DBR.COMBO_CLASSES[classFile or ""] then
        return
    end
    for _, id in ipairs(DBR.COMBO_FINISHERS[classFile] or {}) do
        local name = C_Spell.GetSpellName(id)
        if name then
            combo.finishers[name] = true
        end
    end
    comboEvents:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    -- Era's own combo frame follows UNIT_POWER_FREQUENT; a repeat changes nothing.
    comboEvents:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    comboEvents:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    -- Forever keeps the points on the mob, Era on the caster (author): a new
    -- target is no spend, and with the points on the caster it changes nothing.
    for _, event in ipairs({"PLAYER_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD"}) do
        comboEvents:RegisterEvent(event)
    end
    -- Era's ComboFrame also follows COMBO_TARGET_CHANGED; registered only
    -- where the client knows it (an unknown event is an error).
    local events = rawget(_G, "C_EventUtils")
    if type(events) == "table" and type(events.IsEventValid) == "function"
        and events.IsEventValid("COMBO_TARGET_CHANGED") == true then
        comboEvents:RegisterEvent("COMBO_TARGET_CHANGED")
    end
    Baseline()
end

function DBR.ReportComboDebug()
    if not DBR.HasComboChimes() then
        return
    end
    local count, most = ReadCount()
    local power = type(Enum) == "table" and Enum.PowerType and Enum.PowerType.ComboPoints
    local unitPower = power and type(UnitPower) == "function" and UnitPower("player", power) or nil
    local onTarget = type(GetComboPoints) == "function" and GetComboPoints("player", "target") or nil
    local formID = type(GetShapeshiftFormID) == "function" and GetShapeshiftFormID() or nil
    DBR.Report(string.format("debug combo enabled=%s count=%s most=%s counts=%s last=%s secret=%s unitPower=%s "
        .. "getComboPoints=%s formID=%s catByID=%s catBySpell=%s lastPowerEvent=%s", tostring(DBR.db.combo.enabled),
        tostring(count), tostring(most), tostring(Counts()), tostring(combo.last), tostring(combo.secret),
        DBR.Describe(unitPower), DBR.Describe(onTarget), DBR.Describe(formID), tostring(CatByID()),
        tostring(CatBySpell()), tostring(combo.event or "none")))
    local saved = DBR.db.combo
    DBR.Report(string.format("debug combo settings full=%s spend=%s onlyFull=%s noteSet=%s fullSound=%s spendSound=%s "
        .. "playing=%s queued=%d", tostring(saved.full), tostring(saved.spend), tostring(saved.onlyFull),
        tostring(saved.noteSet), tostring(saved.fullSound), tostring(saved.spendSound), tostring(combo.playing == true),
        #combo.queue))
    DBR.Report("debug combo history " .. (#combo.history > 0 and table.concat(combo.history, " | ") or "none"))
end
