local _, DBR = ...

-- Cooldown chimes (author-approved in MTF, after MageAlert; ported to WTF,
-- then to Dyre's Cooldown Chimes, which merged into DBR): a sound just before
-- a chosen spell is ready again, also in combat. The client hides cooldown
-- details from AddOns in combat and offers no event when a cooldown ends, and
-- the combat log is closed to AddOns. Your own cast (UNIT_SPELLCAST_SUCCEEDED)
-- stays readable in combat, so DBR times each cooldown itself from it: the
-- length it last read for that spell out of combat, else Classic's, and right
-- after an out-of-combat cast it reads the real time left. A spell is matched
-- by its name, so every rank counts (the reason chimes exist beside the
-- Cooldown Manager, which on Forever treats each rank as a different spell).
-- The spells are in ChimeSpells.lua; the sounds come from Dyre's Sounds.

-- Seconds before a cooldown ends that its chime plays, so you can act the
-- moment it is ready (as MageAlert's 14.5 s for Blink's 15).
DBR.CHIME_LEAD_MIN = 0
DBR.CHIME_LEAD_MAX = 3
DBR.CHIME_LEAD_STEP = 0.5
DBR.DEFAULT_CHIME_LEAD = 0.5
-- Interface: Talent ready (author-approved in MTF and WTF: a good sound for a
-- spell becoming available; players change any of them).
DBR.DEFAULT_CHIME_SOUND = "talent"
-- A cooldown read in client, kept only when plausible (the longest Classic
-- cooldowns, Inferno and Lay on Hands, are an hour).
DBR.CHIME_LEARNED_MIN = 1.5
DBR.CHIME_LEARNED_MAX = 3600

-- Seconds after a cast before DBR reads its cooldown, once the client has set it.
local READ_DELAY = 0.1
-- Shorter cooldowns are the global cooldown, not the spell's own.
local GLOBAL_COOLDOWN = 1.5
-- The latest casts, schedules, and chimes, for /dbr debug.
local LOG_SIZE = 12
-- Dyre's Cooldown Chimes never shipped; it merged into DBR (author). Its
-- saved settings are only read, never written.
local MERGED_ADDON = "DyresCooldownChimes"
local MERGED_DB = "DyresCooldownChimesDB"
local MERGED_TITLE = "Dyre's Cooldown Chimes"

local chimes = {list = {}, byName = {}, generation = {}, readyAt = {}, lastCast = nil, log = {}}

-- The chime spells of a class, in settings order; none for a class without a list.
function DBR.ClassChimes(classFile)
    return DBR.CHIME_SPELLS[classFile] or {}
end

-- Dyre's Sounds -----------------------------------------------------------------

-- Dyre's Sounds, when installed with the contract DBR needs, else nil. The
-- TOC lists it as OptionalDeps, so DBR loads (and times chimes) without it.
local SOUNDS_CONTRACT = 1
local SOUNDS_FUNCTIONS = {"List", "Groups", "Label", "Resolve", "Play", "Choices", "SetupMenu"}

function DBR.SoundLibrary()
    local library = rawget(_G, "DyresSounds")
    if type(library) ~= "table" or type(library.RequireContract) ~= "function" then
        return nil, "missing"
    end
    library = library.RequireContract(SOUNDS_CONTRACT)
    if type(library) ~= "table" then
        return nil, "old"
    end
    for _, name in ipairs(SOUNDS_FUNCTIONS) do
        if type(library[name]) ~= "function" then
            return nil, "old"
        end
    end
    return library, "ok"
end

-- Where to get Dyre's Sounds: CurseForge only, for now (author-approved).
local SOUNDS_WHERE = " Get it from CurseForge."
local SOUNDS_MESSAGES = {
    missing = "Install Dyre's Sounds to hear the cooldown chimes and proc sounds. Without it, DBR still times "
        .. "the chimes but plays nothing; the buff reminders work as usual." .. SOUNDS_WHERE,
    old = "Update Dyre's Sounds to hear the cooldown chimes and proc sounds. This version is too old for DBR, "
        .. "so it plays nothing." .. SOUNDS_WHERE,
}

-- Whether any sound on this character wants Dyre's Sounds: the chimes (on,
-- with a class list) or a switched-on proc sound.
local function WantsSounds(classFile)
    if DBR.db.chimes.enabled and #DBR.ClassChimes(classFile) > 0 then
        return true
    end
    local procs = DBR.db.procs
    if procs and procs.enabled and DBR.ClassProcs then
        for _, proc in ipairs(DBR.ClassProcs(classFile)) do
            if procs.spells[proc.key] then
                return true
            end
        end
    end
    return false
end

-- Says once per session what to install when the sounds are missing, and only
-- to a player with sounds on.
function DBR.ReportMissingSounds(classFile)
    local library, state = DBR.SoundLibrary()
    if library or DBR.soundsReported or not WantsSounds(classFile) then
        return
    end
    DBR.soundsReported = true
    DBR.Report(SOUNDS_MESSAGES[state])
end

-- Saved settings -------------------------------------------------------------------

function DBR.SanitizeChimeLead(value)
    if type(value) ~= "number" or value ~= value then
        return DBR.DEFAULT_CHIME_LEAD
    end
    local stepped = math.floor(value / DBR.CHIME_LEAD_STEP + 0.5) * DBR.CHIME_LEAD_STEP
    return math.max(DBR.CHIME_LEAD_MIN, math.min(DBR.CHIME_LEAD_MAX, stepped))
end

-- A saved sound key in the library's own spelling (it maps MTF's and WTF's
-- old keys), else the default (the spell's own, else DBR.DEFAULT_CHIME_SOUND).
-- Without the library a saved key is kept as it is, so a missing library
-- never resets the player's choices.
function DBR.SanitizeChimeSound(key, default)
    default = default or DBR.DEFAULT_CHIME_SOUND
    if type(key) ~= "string" then
        return default
    end
    local library = DBR.SoundLibrary()
    if not library then
        return key
    end
    return library.Resolve(key) or default
end

-- The chime settings, repaired; Core calls this from SanitizeDB. Every class's
-- spells are kept, so the table does not depend on when the class is known.
function DBR.SanitizeChimes(saved)
    saved = type(saved) == "table" and saved or {}
    local spells = type(saved.spells) == "table" and saved.spells or {}
    local sounds = type(saved.sounds) == "table" and saved.sounds or {}
    local learned = type(saved.learned) == "table" and saved.learned or {}
    local clean = {enabled = saved.enabled ~= false, lead = DBR.SanitizeChimeLead(saved.lead),
        spells = {}, sounds = {}, learned = {}}
    for _, classFile in ipairs(DBR.CHIME_CLASS_ORDER) do
        for _, chime in ipairs(DBR.ClassChimes(classFile)) do
            if type(spells[chime.key]) == "boolean" then
                clean.spells[chime.key] = spells[chime.key]
            else
                clean.spells[chime.key] = chime.on
            end
            clean.sounds[chime.key] = DBR.SanitizeChimeSound(sounds[chime.key], chime.sound)
            local seconds = learned[chime.key]
            if type(seconds) == "number" and seconds >= DBR.CHIME_LEARNED_MIN and seconds <= DBR.CHIME_LEARNED_MAX then
                clean.learned[chime.key] = seconds
            end
        end
    end
    return clean
end

-- Other AddOns' chimes ----------------------------------------------------------

-- Whether another AddOn is loaded; shared with Procs.
function DBR.AddOnLoaded(name)
    if type(C_AddOns) ~= "table" or type(C_AddOns.IsAddOnLoaded) ~= "function" then
        return false
    end
    local loaded = C_AddOns.IsAddOnLoaded(name)
    return loaded == true
end
local AddOnLoaded = DBR.AddOnLoaded

-- While Dyre's Cooldown Chimes is still installed, it plays the chimes and DBR
-- plays none, so nothing chimes twice; DBR says once to remove it.
function DBR.MergedChimesLoaded()
    return AddOnLoaded(MERGED_ADDON)
end

-- Mage Tools Forever (on a Mage) and Warlock Tools Forever (on a Warlock) play
-- their own chimes until they stand aside for DBR. asideFrom: their first
-- version that plays no chimes while DBR is loaded (0.3.2-beta, author),
-- so DBR warns only about older ones. Their saved settings are only read.
DBR.OTHER_CHIMES = {
    {addon = "MageToolsForever", title = "Mage Tools Forever", class = "MAGE", db = "MageToolsForeverDB",
        asideFrom = {0, 3, 2}},
    {addon = "WarlockToolsForever", title = "Warlock Tools Forever", class = "WARLOCK",
        db = "WarlockToolsForeverDB", asideFrom = {0, 3, 2}},
}

-- Whether another AddOn's TOC version (major.minor.patch) is at least the one
-- that stands aside for DBR. A version that cannot be read counts as older.
-- Shared with Procs.
function DBR.StandsAside(other)
    if type(C_AddOns) ~= "table" or type(C_AddOns.GetAddOnMetadata) ~= "function" then
        return false
    end
    local version = C_AddOns.GetAddOnMetadata(other.addon, "Version")
    local major, minor, patch = (type(version) == "string" and version or ""):match("^(%d+)%.(%d+)%.(%d+)")
    if not major then
        return false
    end
    local found = {tonumber(major), tonumber(minor), tonumber(patch)}
    for index = 1, 3 do
        if found[index] ~= other.asideFrom[index] then
            return found[index] > other.asideFrom[index]
        end
    end
    return true
end

-- The titles of the other AddOns playing chimes on this character.
function DBR.OtherChimes(classFile)
    local titles = {}
    for _, other in ipairs(DBR.OTHER_CHIMES) do
        if other.class == classFile and AddOnLoaded(other.addon) and not DBR.StandsAside(other) then
            local saved = rawget(_G, other.db)
            local otherChimes = type(saved) == "table" and saved.chimes
            -- Their chimes are on by default.
            if type(otherChimes) ~= "table" or otherChimes.enabled ~= false then
                titles[#titles + 1] = other.title
            end
        end
    end
    return titles
end

-- On the chimes' first run on this character, copies the chime settings from
-- Dyre's Cooldown Chimes when its saved settings are there (author: only he
-- ran it), else from Mage Tools Forever or Warlock Tools Forever, as DCC did,
-- so a player keeps their choices. Those saved settings load at their own
-- ADDON_LOADED, so this runs at login. The keys are the same; sounds are
-- mapped by the library.
function DBR.ImportChimes(classFile)
    local merged = rawget(_G, MERGED_DB)
    if type(merged) == "table" then
        DBR.db.chimes = DBR.SanitizeChimes(merged)
        DBR.Report("Copied your chime settings from " .. MERGED_TITLE .. ".")
        return true
    end
    for _, other in ipairs(DBR.OTHER_CHIMES) do
        local saved = other.class == classFile and rawget(_G, other.db)
        local otherChimes = type(saved) == "table" and saved.chimes
        if type(otherChimes) == "table" then
            DBR.db.chimes = DBR.SanitizeChimes({enabled = DBR.db.chimes.enabled, lead = otherChimes.lead,
                spells = otherChimes.spells, sounds = otherChimes.sounds, learned = otherChimes.learned})
            DBR.Report("Copied your chime settings from " .. other.title .. ".")
            return true
        end
    end
    return false
end

function DBR.ReportOtherChimes(classFile)
    if not DBR.db.chimes.enabled then
        return
    end
    if DBR.MergedChimesLoaded() then
        DBR.Report(MERGED_TITLE .. " is now part of Dyre's Buff Reminders. Remove its AddOn folder "
            .. "(DyresCooldownChimes); until then it plays your chimes and DBR plays none.")
        return
    end
    for _, title in ipairs(DBR.OtherChimes(classFile)) do
        DBR.Report(title .. " also plays cooldown chimes, so you may hear some twice. Turn off its "
            .. "Cooldown chimes until its next update.")
    end
end

-- Timing ---------------------------------------------------------------------------

local function Log(text)
    table.insert(chimes.log, 1, {time = GetTime(), text = text})
    chimes.log[LOG_SIZE + 1] = nil
end

-- A chime's own sound through Dyre's Sounds; Text to Speech says
-- "<Spell> ready". A sound the client cannot play (no voice installed) falls
-- back to the default. Without the library nothing plays.
local function Play(chime)
    local library = DBR.SoundLibrary()
    if not library then
        return false
    end
    if library.Play(DBR.db.chimes.sounds[chime.key], chime.label .. " ready") then
        return true
    end
    return library.Play(DBR.DEFAULT_CHIME_SOUND, chime.label .. " ready")
end

local function FindChime(key)
    for _, classFile in ipairs(DBR.CHIME_CLASS_ORDER) do
        for _, chime in ipairs(DBR.ClassChimes(classFile)) do
            if chime.key == key then
                return chime
            end
        end
    end
end

-- Plays a chime's sound once, so the settings page can preview it.
function DBR.PreviewChime(key)
    local chime = FindChime(key)
    if chime then
        Play(chime)
    end
end

local function Cancel(chime)
    chimes.generation[chime.key] = (chimes.generation[chime.key] or 0) + 1
    chimes.readyAt[chime.key] = nil
end

-- Chimes `lead` seconds before a cooldown of this many seconds ends; a newer
-- schedule for the same spell replaces this one.
local function Schedule(chime, seconds, source)
    Cancel(chime)
    local generation = chimes.generation[chime.key]
    chimes.readyAt[chime.key] = GetTime() + seconds
    Log(string.format("scheduled %s #%d in %.1fs (%s)", chime.key, generation, seconds, source))
    C_Timer.After(math.max(0, seconds - DBR.db.chimes.lead), function()
        if chimes.generation[chime.key] ~= generation then
            return
        end
        chimes.readyAt[chime.key] = nil
        local settings = DBR.db.chimes
        if settings.enabled and settings.spells[chime.key] and not DBR.MergedChimesLoaded() then
            Log(string.format("played %s #%d", chime.key, generation))
            Play(chime)
        end
    end)
end

-- The cooldown as the client reports it, or nil while it is secret or idle.
local function ReadCooldown(spellID)
    if type(C_Spell.GetSpellCooldown) ~= "function" then
        return nil
    end
    local info = C_Spell.GetSpellCooldown(spellID)
    if type(info) ~= "table" then
        return nil
    end
    local start, duration = info.startTime, info.duration
    if DBR.IsSecret(start) or DBR.IsSecret(duration) or type(start) ~= "number" or type(duration) ~= "number"
        or duration <= GLOBAL_COOLDOWN then
        return nil
    end
    return duration, start + duration - GetTime()
end

-- Right after a cast, the real cooldown: learned for next time, and the
-- chime rescheduled to it.
local function Refine(chime, spellID)
    local duration, left = ReadCooldown(spellID)
    if not duration then
        return
    end
    DBR.db.chimes.learned[chime.key] = math.max(DBR.CHIME_LEARNED_MIN,
        math.min(DBR.CHIME_LEARNED_MAX, math.floor(duration * 10 + 0.5) / 10))
    if left > 0 then
        Schedule(chime, left, "read")
    end
end

local function OnCast(spellID)
    if DBR.IsSecret(spellID) or type(spellID) ~= "number" then
        return
    end
    local name = C_Spell.GetSpellName(spellID)
    if DBR.IsSecret(name) or type(name) ~= "string" then
        return
    end
    local chime = chimes.byName[name]
    if not chime then
        return
    end
    chimes.lastCast = {key = chime.key, spell = spellID, time = GetTime()}
    Log(string.format("cast %s spell=%d", chime.key, spellID))
    if chime.resets then
        for _, other in ipairs(chimes.list) do
            if other.group == chime.resets and other ~= chime then
                Cancel(other)
            end
        end
        Log("reset " .. chime.resets)
    end
    local learned = DBR.db.chimes.learned[chime.key]
    local seconds = learned or chime.cooldown
    if seconds then
        Schedule(chime, seconds, learned and "learned" or "classic")
    end
    C_Timer.After(READ_DELAY, function() Refine(chime, spellID) end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, _, _, _, spellID)
    OnCast(spellID)
end)

-- Only the player's own class's spells, each found by the name of its
-- Classic ID, so a cast of any rank finds it.
function DBR.InitializeChimes(classFile)
    chimes.list = DBR.ClassChimes(classFile)
    chimes.byName = {}
    for _, chime in ipairs(chimes.list) do
        local name = C_Spell.GetSpellName(chime.spell)
        if type(name) == "string" and not DBR.IsSecret(name) then
            chimes.byName[name] = chime
        end
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
end

local SOUNDS_STATES = {ok = "installed", missing = "missing", old = "too old"}

-- /dbr debug: the library, the other AddOns playing chimes, each of your
-- class's chime spells as the client knows it, whether its cooldown is
-- readable now, the length DBR uses, the sound, and the latest events.
function DBR.ReportChimesDebug(classFile)
    local function Report(text)
        DBR.Report("debug chimes " .. text)
    end
    local settings = DBR.db and DBR.db.chimes
    local _, state = DBR.SoundLibrary()
    local others = table.concat(DBR.OtherChimes(classFile), ", ")
    Report(string.format("enabled=%s lead=%s sounds=%s dccLoaded=%s otherChimes=%s",
        tostring(settings and settings.enabled), tostring(settings and settings.lead), SOUNDS_STATES[state],
        tostring(DBR.MergedChimesLoaded()), others ~= "" and others or "none"))
    local secrecy = type(C_Secrets) == "table" and type(C_Secrets.GetSpellCooldownSecrecy) == "function"
    local readable = type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function"
    local now = GetTime()
    for _, chime in ipairs(DBR.ClassChimes(classFile)) do
        local known = type(C_SpellBook) == "table" and type(C_SpellBook.IsSpellKnown) == "function"
            and C_SpellBook.IsSpellKnown(chime.spell)
        -- The client returns no value for an unknown spell; tostring needs one.
        local name = readable and C_Spell.GetSpellName(chime.spell)
        local duration = readable and ReadCooldown(chime.spell)
        Report(string.format("%s name=%s known=%s on=%s sound=%s classic=%s learned=%s readNow=%s secrecy=%s "
            .. "readyIn=%s", chime.key, DBR.Describe(name), DBR.Describe(known),
            tostring(settings and settings.spells[chime.key]), tostring(settings and settings.sounds[chime.key]),
            tostring(chime.cooldown), tostring(settings and settings.learned[chime.key]), tostring(duration),
            secrecy and DBR.Describe(C_Secrets.GetSpellCooldownSecrecy(chime.spell)) or "n/a",
            chimes.readyAt[chime.key] and string.format("%.1fs", chimes.readyAt[chime.key] - now) or "-"))
    end
    local last = chimes.lastCast
    Report("lastCast=" .. (last and string.format("%s %.1fs ago", last.key, now - last.time) or "none"))
    for _, entry in ipairs(chimes.log) do
        Report(string.format("log %.1fs ago %s", now - entry.time, entry.text))
    end
end
