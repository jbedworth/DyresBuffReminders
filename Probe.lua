local _, DBR = ...

-- The reactive-ability probe (debug only, author-approved for a test): while
-- `/dbr probe on`, chat says when each of your class's reactive abilities
-- becomes usable or not (C_Spell.IsSpellUsable on SPELL_UPDATE_USABLE), and
-- each spell glow the client sends (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW and
-- _HIDE). It answers whether these are readable in combat, for a later
-- tracker bar. No frames, no settings; event-driven; a secret value is never
-- compared or printed, only reported as "secret". Saved per character, off by
-- default.

-- Classic rank 1 IDs; a spell is asked for by name, so your highest rank counts.
DBR.PROBE_SPELLS = {
    WARRIOR = {7384, 6572, 5308}, -- Overpower, Revenge, Execute
    ROGUE = {14251}, -- Riposte
    HUNTER = {1495, 19306}, -- Mongoose Bite, Counterattack
}
-- At most this many chat lines per window, so a burst of events cannot flood chat.
local LINE_LIMIT = 20
local LINE_WINDOW = 10

-- A debuff on your target to test (lead, 2026-11-15; John tests it on
-- Forever): Winter's Chill. The probe asks the game for an aura sound on
-- "target" (unitToken is a plain string in the 70338 docs, but no Blizzard
-- code uses another unit), for the debuff going on and for each new stack,
-- and, out of combat only, prints the target's Winter's Chill: its real spell
-- ID and stack count. Never registered outside the probe.
DBR.PROBE_TARGET_DEBUFFS = {MAGE = DBR.WINTERS_CHILL.debuff}
local TRIGGER_ADDED, TRIGGER_STACKS = 0, 1
local TARGET_THROTTLE = 1

local probe = {spells = {}, last = {}, lines = 0, windowStart = 0, paused = false, handles = {}}

local function Combat()
    return InCombatLockdown() and "yes" or "no"
end

-- One chat line, within the cap.
local function Say(text)
    local now = GetTime()
    if now - probe.windowStart >= LINE_WINDOW then
        probe.windowStart, probe.lines, probe.paused = now, 0, false
    end
    if probe.lines >= LINE_LIMIT then
        if not probe.paused then
            probe.paused = true
            DBR.Report("probe: too many lines; quiet for a few seconds.")
        end
        return
    end
    probe.lines = probe.lines + 1
    DBR.Report("probe " .. text)
end

-- A value as text, without ever reading a secret one.
local function Text(value)
    if DBR.IsSecret(value) then
        return "secret"
    end
    return tostring(value)
end

-- The spells you know, by name.
local function KnownSpells(classFile)
    local spells = {}
    for _, id in ipairs(DBR.PROBE_SPELLS[classFile] or {}) do
        local name = C_Spell.GetSpellName(id)
        if name and not DBR.IsSecret(name) and C_SpellBook.IsSpellKnown(id) == true then
            spells[#spells + 1] = name
        end
    end
    return spells
end

-- Each spell's usable state; a line only when it changes. The state is kept as
-- text ("secret" for a secret value), so nothing secret is ever compared.
local function CheckUsable()
    if type(C_Spell.IsSpellUsable) ~= "function" then
        return
    end
    for _, name in ipairs(probe.spells) do
        local usable, noMana = C_Spell.IsSpellUsable(name)
        local secret = DBR.IsSecret(usable) or DBR.IsSecret(noMana)
        local state = Text(usable) .. "/" .. Text(noMana)
        if probe.last[name] ~= state then
            probe.last[name] = state
            Say(string.format("%s usable=%s noMana=%s secret=%s combat=%s", name, Text(usable), Text(noMana),
                secret and "yes" or "no", Combat()))
        end
    end
end

local function Glow(kind, spellID)
    local name
    if not DBR.IsSecret(spellID) and type(spellID) == "number" then
        name = C_Spell.GetSpellName(spellID)
    end
    Say(string.format("glow %s spellID=%s name=%s combat=%s", kind, Text(spellID), Text(name), Combat()))
end

-- Out of combat: the target's debuff, a line only when it changes.
local function ReadTarget()
    local id = DBR.PROBE_TARGET_DEBUFFS[DBR.classFile or ""]
    if not id or InCombatLockdown() or type(C_UnitAuras.GetAuraDataBySpellName) ~= "function" then
        return
    end
    local name = C_Spell.GetSpellName(id)
    if not name or DBR.IsSecret(name) then
        return
    end
    local text
    if type(UnitExists) == "function" and UnitExists("target") ~= true then
        text = "no target"
    else
        local aura = C_UnitAuras.GetAuraDataBySpellName("target", name, "HARMFUL")
        if DBR.IsSecret(aura) then
            text = "secret"
        elseif type(aura) == "table" then
            text = string.format("spellID=%s stacks=%s source=%s", Text(aura.spellId), Text(aura.applications),
                Text(aura.sourceUnit))
        else
            text = "none"
        end
    end
    if probe.lastTarget ~= text then
        probe.lastTarget = text
        Say(string.format("target %s %s", name, text))
    end
end

-- The game's aura sounds on "target", for the debuff going on and each new stack.
local function AddTargetSounds()
    local id = DBR.PROBE_TARGET_DEBUFFS[DBR.classFile or ""]
    if not id then
        return
    end
    if type(C_UnitAuras.AddAuraSound) ~= "function" then
        Say("target sound: this client has no C_UnitAuras.AddAuraSound.")
        return
    end
    local library = DBR.SoundLibrary()
    local sound = library and type(library.AuraSound) == "function" and library.AuraSound(DBR.DEFAULT_PROC_SOUND)
    if not sound then
        Say("target sound: install Dyre's Sounds to hear it.")
        return
    end
    local triggers = Enum and Enum.UnitAuraSoundTrigger or {}
    local result = {}
    for _, entry in ipairs({{"added", triggers.Added or TRIGGER_ADDED},
        {"stacks", triggers.ApplicationsIncreased or TRIGGER_STACKS}}) do
        local handle = C_UnitAuras.AddAuraSound(entry[2], {spellID = id, unitToken = "target",
            outputChannel = "master", throttleSeconds = TARGET_THROTTLE, soundFileName = sound.soundFileName,
            soundFileID = sound.soundFileID})
        if handle then
            probe.handles[#probe.handles + 1] = handle
        end
        result[#result + 1] = entry[1] .. "=" .. (handle and "yes" or "refused")
    end
    Say(string.format("target sound %d on target: %s. You hear it when it goes on your target or stacks.", id,
        table.concat(result, " ")))
end

local function RemoveTargetSounds()
    for _, handle in ipairs(probe.handles) do
        C_UnitAuras.RemoveAuraSound(handle)
    end
    probe.handles, probe.lastTarget = {}, nil
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, spellID)
    if event == "UNIT_AURA" or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        ReadTarget()
    elseif event == "SPELL_UPDATE_USABLE" then
        CheckUsable()
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        Glow("show", spellID)
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        Glow("hide", spellID)
    elseif event == "SPELLS_CHANGED" then
        probe.spells = KnownSpells(DBR.classFile)
    end
end)

local PROBE_EVENTS = {"SPELL_UPDATE_USABLE", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
    "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "SPELLS_CHANGED"}

local function Start()
    probe.spells, probe.last = KnownSpells(DBR.classFile), {}
    for _, event in ipairs(PROBE_EVENTS) do
        events:RegisterEvent(event)
    end
    local list = #probe.spells > 0 and table.concat(probe.spells, ", ") or "none known"
    DBR.Report("probe on: " .. list .. ". Lines show when one becomes usable or not, and each spell glow. "
        .. "Type /dbr probe off to stop.")
    CheckUsable()
    if DBR.PROBE_TARGET_DEBUFFS[DBR.classFile or ""] then
        events:RegisterUnitEvent("UNIT_AURA", "target")
        events:RegisterEvent("PLAYER_TARGET_CHANGED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        AddTargetSounds()
        ReadTarget()
    end
end

local function Stop()
    for _, event in ipairs(PROBE_EVENTS) do
        events:UnregisterEvent(event)
    end
    events:UnregisterEvent("UNIT_AURA")
    events:UnregisterEvent("PLAYER_TARGET_CHANGED")
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    RemoveTargetSounds()
end

-- /dbr probe on and /dbr probe off.
function DBR.SetProbe(on)
    DBR.db.probe = on
    if on then
        Start()
    else
        Stop()
        DBR.Report("probe off.")
    end
end

function DBR.ProbeOn()
    DBR.SetProbe(true)
end

function DBR.ProbeOff()
    DBR.SetProbe(false)
end

function DBR.InitializeProbe()
    if DBR.db.probe then
        Start()
    end
end

function DBR.ReportProbeDebug()
    DBR.Report(string.format("debug probe on=%s spells=%s", tostring(DBR.db and DBR.db.probe),
        #probe.spells > 0 and table.concat(probe.spells, ",") or "none"))
end
