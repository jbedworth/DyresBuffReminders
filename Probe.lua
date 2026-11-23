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

local probe = {spells = {}, last = {}, lines = 0, windowStart = 0, paused = false}

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

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, spellID)
    if event == "SPELL_UPDATE_USABLE" then
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
end

local function Stop()
    for _, event in ipairs(PROBE_EVENTS) do
        events:UnregisterEvent(event)
    end
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
