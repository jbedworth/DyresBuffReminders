local addonName, DBR = ...

-- Dyre's Buff Reminders: the buff reminders from Mage Tools Forever and
-- Warlock Tools Forever on their own, for any class with buffs in Buffs.lua,
-- and the cooldown chimes from Dyre's Cooldown Chimes, which merged into it
-- (author).
-- This file owns saved settings, the login banner, install and API checks,
-- slash conflict reporting, joining Dyre's Toolkit, the lock, and startup.
-- All layout (placing, dragging, snapping, sizing, saving places) is the
-- toolkit's: DBR's frames are its widgets (author's rule, 2026-10-20).
local DEFAULT_TITLE = "Dyre's Buff Reminders"
local READY_MESSAGE = "  Ready. Type /dbr to open the settings."
local SLASH_KEY = "DYRESBUFFREMINDERS"
local PRIMARY_SLASH = "/dbr"
local BACKUP_SLASH = "/buffreminders"
local MAX_SLASH_ALIASES = 10
DBR.available = false

function DBR.Report(message)
    DEFAULT_CHAT_FRAME:AddMessage("DBR: " .. tostring(message))
end

-- Dyre's Toolkit 2.0 or later (contract 2, widgets) is required: the TOC
-- lists it as Dependencies. Without it DBR stays off and says what to install.
local TOOLKIT_CONTRACT = 2
local TOOLKIT_FUNCTIONS = {"RegisterAddOn", "IsLocked", "SetLocked", "RegisterSettingsCategory", "OpenSettings",
    "CreateWidget", "AddWidgetSettings", "ResetWidgets"}
-- Where to get it: CurseForge only, for now (author).
local TOOLKIT_MISSING = "Dyre's Buff Reminders needs Dyre's Toolkit 2.0 or later: install or update it from "
    .. "CurseForge. DBR stays off until then."

function DBR.Toolkit()
    local toolkit = rawget(_G, "DyresToolkit")
    if type(toolkit) ~= "table" or type(toolkit.RequireContract) ~= "function" then
        return nil
    end
    toolkit = toolkit.RequireContract(TOOLKIT_CONTRACT)
    if type(toolkit) ~= "table" then
        return nil
    end
    for _, name in ipairs(TOOLKIT_FUNCTIONS) do
        if type(toolkit[name]) ~= "function" then
            return nil
        end
    end
    return toolkit
end

-- Combat data can be a secret value on the target client: code may store and
-- pass it on, but never compare, concatenate, or print it.
function DBR.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

-- Text for diagnostics that never touches a secret value's contents.
function DBR.Describe(value)
    if DBR.IsSecret(value) then
        return "secret"
    end
    return tostring(value)
end

-- Reads TOC fields so the banner follows the packaged version; never gates operations.
local function Metadata(field)
    if type(C_AddOns) ~= "table" or type(C_AddOns.GetAddOnMetadata) ~= "function" then
        return nil
    end
    local value = C_AddOns.GetAddOnMetadata(addonName, field)
    if type(value) == "string" and value:find("%S") then
        return value
    end
end

local function ReportLoaded(available)
    local banner = Metadata("Title") or DEFAULT_TITLE
    local version, author = Metadata("Version"), Metadata("Author")
    if version then
        banner = banner .. " " .. version
    end
    if author then
        banner = banner .. " by " .. author
    end
    DBR.Report(banner)
    if available then
        DBR.Report(READY_MESSAGE)
    end
end

-- Functions other runtime files must define. A mixed install of old and new
-- files otherwise fails silently, because the client hides Lua errors by default.
local REQUIRED_NAMESPACE = {
    "ParseCommand", "HandleCommand",
    "ClassReminders", "SanitizeReminders", "SanitizeLead", "InitializeReminders",
    "RefreshReminders", "ReportRemindersDebug", "SanitizeSeal", "InitializeSeal",
    "RefreshSeal", "ReportSealDebug", "HasSealTimer", "SealWidget", "ReminderBars", "CombatAspectWidget", "RefreshCombatAspect",
    "SanitizeConsumables", "SanitizeAmmoWarn", "InitializeConsumables", "RefreshConsumables", "ConsumablesWidget",
    "ReportConsumablesDebug",
    "ClassChimes", "SoundLibrary", "ReportMissingSounds", "SanitizeChimes", "ImportChimes", "ReportOtherChimes",
    "InitializeChimes", "PreviewChime", "ReportChimesDebug",
    "ClassProcs", "HasProcSounds", "SanitizeProcs", "SanitizeProcSound", "ApplyProcSounds", "PreviewProc",
    "InitializeProcs", "ImportProcs", "ReportProcsDebug", "OtherProcs", "ReportOtherProcs", "AddOnLoaded",
    "StandsAside", "SetProbe", "ProbeOn", "ProbeOff", "InitializeProbe", "ReportProbeDebug",
    "InitializeOptions", "OpenSettings",
}
-- Client APIs the reminders cannot work without. Range checks and reagent
-- counts are optional: without them, DBR assumes in range and no reagent.
local REQUIRED_APIS = {
    {"C_SpellBook", "IsSpellKnown"}, {"C_Spell", "GetSpellName"}, {"C_Spell", "GetSpellTexture"},
    {"C_UnitAuras", "GetAuraDataBySpellName"}, {nil, "RegisterStateDriver"}, {nil, "InCombatLockdown"},
    {nil, "UnitClass"}, {nil, "UnitExists"}, {nil, "UnitIsUnit"}, {nil, "IsInGroup"}, {nil, "IsInRaid"},
    {"C_Timer", "After"}, {nil, "GetTime"},
}

local function CheckInstalledFiles()
    if type(DBR.BUFFS) ~= "table" or type(DBR.SEALS) ~= "table" or type(DBR.CHIME_SPELLS) ~= "table"
        or type(DBR.PROC_SOUNDS) ~= "table" then
        return false, "AddOn files are from different versions (missing Buffs.lua, Seals.lua, "
            .. "ChimeSpells.lua, or ProcSpells.lua). Reinstall every Dyre's Buff Reminders file, then restart "
            .. "the client."
    end
    for _, name in ipairs(REQUIRED_NAMESPACE) do
        if type(DBR[name]) ~= "function" then
            return false, "AddOn files are from different versions (missing " .. name
                .. "). Reinstall every Dyre's Buff Reminders file, then restart the client."
        end
    end
    for _, api in ipairs(REQUIRED_APIS) do
        local owner = api[1] and _G[api[1]] or _G
        if type(owner) ~= "table" or type(owner[api[2]]) ~= "function" then
            local name = api[1] and (api[1] .. "." .. api[2]) or api[2]
            return false, "This client lacks " .. name .. ", which the buff reminders need. DBR stays off."
        end
    end
    return true
end

local function SanitizePosition(position)
    if type(position) ~= "table" or type(position.point) ~= "string"
        or type(position.relativePoint) ~= "string"
        or type(position.x) ~= "number" or type(position.y) ~= "number" then
        return nil
    end
    return {point = position.point, relativePoint = position.relativePoint,
        x = position.x, y = position.y}
end

-- Per-character settings in DyresBuffRemindersDB, repaired on load so a
-- damaged or older table can never break the AddOn.
function DBR.SanitizeDB(db)
    db = type(db) == "table" and db or {}
    db.enabled = db.enabled ~= false
    -- The toolkit's lock, mirrored at login and on each change; frames start locked.
    db.locked = true
    -- Before 1.1.0: DBR's own grid switch (the toolkit draws the one grid now).
    db.grid = nil
    -- The reactive-ability probe (Probe.lua): debug only, off by default.
    db.probe = db.probe == true
    if DBR.SanitizeReminders and type(DBR.BUFFS) == "table" then
        DBR.SanitizeReminders(db, SanitizePosition)
    end
    if DBR.SanitizeSeal then
        db.seal = DBR.SanitizeSeal(db.seal, SanitizePosition)
    end
    if DBR.SanitizeConsumables then
        db.consumables = DBR.SanitizeConsumables(db.consumables, SanitizePosition)
    end
    if DBR.SanitizeChimes and type(DBR.CHIME_SPELLS) == "table" then
        db.chimes = DBR.SanitizeChimes(db.chimes)
    end
    if DBR.SanitizeProcs and type(DBR.PROC_SOUNDS) == "table" then
        db.procs = DBR.SanitizeProcs(db.procs)
    end
    return db
end

-- Another AddOn can register the same slash command; the last one loaded wins.
-- Returns the other command key, or nil when /dbr is ours alone.
local function FindSlashConflict()
    for key in pairs(SlashCmdList) do
        if key ~= SLASH_KEY then
            for index = 1, MAX_SLASH_ALIASES do
                local alias = _G["SLASH_" .. key .. index]
                if type(alias) == "string" and alias:lower() == PRIMARY_SLASH then
                    return key
                end
            end
        end
    end
end

-- The toolkit's lock changed: DBR's samples show or hide, quietly (the
-- toolkit draws the outlines and says one line for all).
function DBR.ApplyLocked(locked)
    DBR.db.locked = locked == true
    DBR.RefreshReminders()
    DBR.RefreshSeal()
    DBR.RefreshConsumables()
end

-- /dbr unlock and /dbr lock: one layout mode for every Dyre's AddOn.
function DBR.SetLocked(locked)
    DBR.toolkit.SetLocked(locked)
end

function DBR.Unlock()
    DBR.SetLocked(false)
end

function DBR.Lock()
    DBR.SetLocked(true)
end

-- /dbr reset: every DBR widget back to its default place (the toolkit waits
-- out combat for those holding secure buttons).
function DBR.ResetPositions()
    DBR.toolkit.ResetWidgets(addonName)
    if InCombatLockdown() then
        DBR.Report("DBR's frames move back to their default places after combat.")
    else
        DBR.Report("DBR's frames moved back to their default places.")
    end
end

function DBR.ReportDebug()
    local _, class
    if type(UnitClass) == "function" then
        _, class = UnitClass("player")
    end
    DBR.Report(string.format("debug class=%s available=%s enabled=%s locked=%s combat=%s",
        DBR.Describe(class), tostring(DBR.available), tostring(DBR.db and DBR.db.enabled),
        tostring(DBR.db and DBR.db.locked), tostring(InCombatLockdown())))
    if not DBR.available then
        return
    end
    DBR.ReportRemindersDebug()
    DBR.ReportSealDebug()
    DBR.ReportConsumablesDebug()
    DBR.ReportChimesDebug(not DBR.IsSecret(class) and class or nil)
    DBR.ReportProcsDebug(not DBR.IsSecret(class) and class or nil)
    DBR.ReportProbeDebug()
end

SLASH_DYRESBUFFREMINDERS1 = PRIMARY_SLASH
SLASH_DYRESBUFFREMINDERS2 = BACKUP_SLASH
SlashCmdList[SLASH_KEY] = function(message) DBR.HandleCommand(message) end

local function LoadDB()
    -- No chime settings yet: the chimes' first run on this character.
    local saved = DyresBuffRemindersDB
    DBR.chimesFirstRun = type(saved) ~= "table" or type(saved.chimes) ~= "table"
    DBR.procsFirstRun = type(saved) ~= "table" or type(saved.procs) ~= "table"
    DyresBuffRemindersDB = DBR.SanitizeDB(DyresBuffRemindersDB)
    DBR.db = DyresBuffRemindersDB
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, loadedName)
    if event == "ADDON_LOADED" then
        if loadedName == addonName then
            self:UnregisterEvent("ADDON_LOADED")
            LoadDB()
        end
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    local available, message = CheckInstalledFiles()
    if available and not DBR.db then
        LoadDB()
    end
    if available then
        DBR.toolkit = DBR.Toolkit()
        available = DBR.toolkit ~= nil
        message = TOOLKIT_MISSING
    end
    DBR.available = available
    ReportLoaded(available)
    local conflict = FindSlashConflict()
    if conflict then
        DBR.Report("Another AddOn (" .. conflict .. ") also uses " .. PRIMARY_SLASH
            .. ". Use " .. BACKUP_SLASH .. " instead.")
    end
    if not available then
        DBR.Report(message)
        return
    end
    -- The class picks the buff list (data, not a gate): a class without one
    -- loads, says so, and shows nothing. Called here rather than from each
    -- file's own PLAYER_LOGIN handler, so startup never depends on event
    -- handler order.
    -- Before any widget exists: the toolkit's lock state is DBR's.
    DBR.db.locked = DBR.toolkit.IsLocked() ~= false
    local _, class = UnitClass("player")
    class = not DBR.IsSecret(class) and class or nil
    DBR.classFile = class
    DBR.InitializeReminders(class)
    DBR.InitializeSeal(class)
    DBR.InitializeConsumables()
    if #DBR.ClassReminders() == 0 then
        DBR.Report("There are no buff reminders for your class yet.")
    end
    if DBR.chimesFirstRun then
        DBR.ImportChimes(class)
    end
    DBR.ReportMissingSounds(class)
    DBR.ReportOtherChimes(class)
    DBR.InitializeChimes(class)
    if DBR.procsFirstRun then
        DBR.ImportProcs(class)
    end
    DBR.InitializeProcs(class)
    DBR.ReportOtherProcs(class)
    DBR.InitializeProbe()
    DBR.InitializeOptions()
    DBR.toolkit.RegisterAddOn({addon = addonName, title = DEFAULT_TITLE, setLocked = DBR.ApplyLocked,
        openSettings = DBR.OpenSettings})
end)
