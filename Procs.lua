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
