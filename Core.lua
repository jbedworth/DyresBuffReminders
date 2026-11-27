local addonName, DBR = ...

-- Dyre's Buff Reminders: the buff reminders from Mage Tools Forever and
-- Warlock Tools Forever on their own, for any class with buffs in Buffs.lua,
-- and the cooldown chimes from Dyre's Cooldown Chimes, which merged into it
-- (author).
-- This file owns saved settings, the login banner, install and API checks,
-- slash conflict reporting, joining Dyre's Toolkit and its profile, the lock, and
-- startup.
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

-- Dyre's Toolkit 2.14.0's "Welcome messages at login" (John, 2026-11-23: "toggle off our
-- welcome messages unless there is an error/problem"; "A: one Toolkit switch"). Without
-- ShowWelcome (an older toolkit, or none) the banner shows as before.
local function WelcomeOff()
    local toolkit = rawget(_G, "DyresToolkit")
    return type(toolkit) == "table" and type(toolkit.ShowWelcome) == "function" and toolkit.ShowWelcome() == false
end

-- The banner and "Ready" line. With the switch off they are skipped, but not
-- when DBR cannot start: the problem line that follows needs the version.
local function ReportLoaded(available)
    if available and WelcomeOff() then
        return
    end
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
    "ClassReminders", "SanitizeReminders", "SanitizeLead", "InitializeReminders", "ImportReminders", "AddCtrlMove", "CheckWarnings", "WarningsAtCombat",
    "SetUpWarnings", "ClassWarnings", "ReportWarningsDebug",
    "RefreshReminders", "ReportRemindersDebug", "SanitizeSeal", "InitializeSeal",
    "RefreshSeal", "ReportSealDebug", "HasSealTimer", "SealWidget", "BuffWidgets", "AspectReminderWidget",
    "LinkAspectBarButton", "HasBuffSlots",
    "SanitizeConsumables", "SanitizeAmmoWarn", "InitializeConsumables", "RefreshConsumables", "ConsumablesWidget",
    "ReportConsumablesDebug", "SanitizeAspectBar", "InitializeAspectBar", "RefreshAspectBar", "AspectBarWidget",
    "ReportAspectBarDebug",
    "ClassChimes", "SoundLibrary", "ReportMissingSounds", "SanitizeChimes", "ImportChimes", "ReportOtherChimes",
    "InitializeChimes", "PreviewChime", "ReportChimesDebug",
    "ClassProcs", "HasProcSounds", "SanitizeProcs", "SanitizeProcSound", "ApplyProcSounds", "PreviewProc",
    "InitializeProcs", "ImportProcs", "SanitizeProcCues", "ImportProcCues", "ApplyProcs", "InitializeProcCues",
    "SanitizeCasts", "ClassCasts", "InitializeCasts", "PreviewCast", "SanitizeCombo", "HasComboChimes",
    "InitializeCombo", "PreviewCombo", "ReportComboDebug",
    "ReportCastsDebug", "ReportProcsDebug", "OtherProcs", "ReportOtherProcs", "AddOnLoaded",
    "StandsAside", "SetProbe", "ProbeOn", "ProbeOff", "InitializeProbe", "ReportProbeDebug",
    "InitializeOptions", "OpenSettings",
}
-- Client APIs the reminders cannot work without. Range checks and reagent
-- counts are optional: without them, DBR assumes in range and no reagent.
local REQUIRED_APIS = {
    {"C_SpellBook", "IsSpellKnown"}, {"C_Spell", "GetSpellName"}, {"C_Spell", "GetSpellTexture"},
    {"C_UnitAuras", "GetAuraDataBySpellName"}, {nil, "RegisterStateDriver"}, {nil, "InCombatLockdown"},
    {nil, "UnitClass"}, {nil, "UnitExists"}, {nil, "UnitIsUnit"}, {nil, "IsInGroup"}, {nil, "IsInRaid"},
    {"C_Timer", "After"}, {nil, "GetTime"}, {nil, "GetWeaponEnchantInfo"},
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
    if DBR.SanitizeAspectBar then
        db.aspectBar = DBR.SanitizeAspectBar(db.aspectBar, SanitizePosition)
    end
    if DBR.SanitizeChimes and type(DBR.CHIME_SPELLS) == "table" then
        db.chimes = DBR.SanitizeChimes(db.chimes)
    end
    if DBR.SanitizeProcs and type(DBR.PROC_SOUNDS) == "table" then
        db.procs = DBR.SanitizeProcs(db.procs)
    end
    if DBR.SanitizeProcCues and type(DBR.PROC_CUES) == "table" then
        DBR.SanitizeProcCues(db)
    end
    if DBR.SanitizeCasts and type(DBR.CAST_SOUNDS) == "table" then
        db.casts = DBR.SanitizeCasts(db.casts)
    end
    if DBR.SanitizeCombo then
        db.combo = DBR.SanitizeCombo(db.combo)
    end
    -- db.wintersChill (DBR 1.9.0 to 1.13.2) stays as saved, for Dyre's Debuff Tracker to import.
    return db
end

-- The Dyre's Toolkit profile (Toolkit 2.10.0, docs/PROFILES.md there; John,
-- 2026-11-17: "one place to go to persist your profile"). DBR's live settings
-- stay in DyresBuffRemindersDB; the toolkit keeps the copies, the UI, and the
-- export line. These top-level keys stay with this character and are never
-- copied, exported, or imported: locked (the toolkit's account-wide lock,
-- mirrored), probe (a debug switch), last (the spell each button casts,
-- remembered from your casts), bars (1.1.0's places, kept only until they
-- seed the icons), procIDs (the proc cues' buff IDs read in client, 1.13.0),
-- wintersChill (the removed chime's settings, kept as saved for Dyre's Debuff
-- Tracker to import; 1.13.3).
local PROFILE_CHARACTER_KEYS = {"locked", "probe", "last", "bars", "procIDs", "wintersChill"}
-- Read in client on this character, nested in settings tables (characterKeys
-- are top-level only): the cooldown lengths (chimes.learned) and the real
-- buff IDs (procs.learned). A copy, import, or the Defaults keeps this
-- character's own.
local PROFILE_LEARNED = {"chimes", "procs"}
local profile = {}

local function CopyTable(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, item in pairs(value) do
        copy[key] = CopyTable(item)
    end
    return copy
end

-- New settings for this character's profile part, repaired as at load.
function DBR.SanitizeProfile(settings)
    settings = type(settings) == "table" and settings or {}
    local live = DBR.db
    for _, group in ipairs(PROFILE_LEARNED) do
        local learned = type(live) == "table" and type(live[group]) == "table" and live[group].learned
        if type(learned) == "table" then
            if type(settings[group]) ~= "table" then
                settings[group] = {}
            end
            settings[group].learned = CopyTable(learned)
        end
    end
    -- At registration the toolkit runs this only to write a part copied or
    -- imported while DBR was not loaded here: then it wins over the first
    -- run's imports from older AddOns.
    if profile.joining then
        profile.wrote = true
    end
    settings = DBR.SanitizeDB(settings)
    -- A newer version's keys are dropped (the toolkit's rule for a part).
    local known = DBR.SanitizeDB({})
    for _, key in ipairs(PROFILE_CHARACTER_KEYS) do
        known[key] = true
    end
    for key in pairs(settings) do
        if known[key] == nil then
            settings[key] = nil
        end
    end
    return settings
end

-- A copy or import was written into DyresBuffRemindersDB in place: every
-- part reads its settings again, live (out of combat; the toolkit refuses
-- a copy in combat).
function DBR.ApplyProfile()
    DBR.db.locked = DBR.toolkit.IsLocked() ~= false
    if type(DBR.toolkit.ReapplyWidgets) == "function" then
        DBR.toolkit.ReapplyWidgets(addonName)
    end
    DBR.RefreshReminders()
    DBR.RefreshSeal()
    DBR.RefreshConsumables()
    DBR.RefreshAspectBar()
    -- The copy wins over a later first-run import from Dyre's Shields Up.
    DBR.db.procCuesImported = true
    DBR.ApplyProcs()
end

-- With a toolkit older than 2.10.0 nothing changes.
local function JoinProfile(toolkit)
    if type(toolkit.RegisterProfilePart) ~= "function" then
        return
    end
    profile.joining = true
    toolkit.RegisterProfilePart({
        addon = addonName,
        title = DEFAULT_TITLE,
        current = function() return DyresBuffRemindersDB end,
        sanitize = DBR.SanitizeProfile,
        characterKeys = PROFILE_CHARACTER_KEYS,
        refresh = DBR.ApplyProfile,
    })
    profile.joining = nil
    if profile.wrote then
        DBR.remindersFirstRun, DBR.chimesFirstRun, DBR.procsFirstRun = false, false, false
        DBR.db.procCuesImported = true
    end
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
-- Ctrl-drag while locked (Dyre's Toolkit's free move, family-wide) can start
-- only on a part that takes the mouse; a widget that is click-through while
-- locked (the Consumables bar, the seal timer) takes the mouse while Ctrl is
-- held, out of combat (player report: the Consumables bar did not move; WTF's
-- fix). Event driven (MODIFIER_STATE_CHANGED), never changed during a drag so
-- its drop arrives, and off as combat starts (PLAYER_REGEN_DISABLED comes
-- before the lockdown). Unlocked, the toolkit owns the mouse.
local ctrlMove = {frames = {}, on = false, events = CreateFrame("Frame")}

local function ApplyCtrlMove(entering)
    if ctrlMove.dragging or InCombatLockdown() then
        return
    end
    local on = not entering and DBR.db ~= nil and DBR.db.locked == true
        and type(IsControlKeyDown) == "function" and IsControlKeyDown() == true
    if on == ctrlMove.on then
        return
    end
    ctrlMove.on = on
    if DBR.db.locked then
        for _, frame in ipairs(ctrlMove.frames) do
            frame:EnableMouse(on)
        end
    end
end

ctrlMove.events:SetScript("OnEvent", function(_, event)
    ApplyCtrlMove(event == "PLAYER_REGEN_DISABLED")
end)

function DBR.AddCtrlMove(frame)
    ctrlMove.frames[#ctrlMove.frames + 1] = frame
    frame:HookScript("OnDragStart", function() ctrlMove.dragging = true end)
    frame:HookScript("OnDragStop", function()
        ctrlMove.dragging = nil
        ApplyCtrlMove()
    end)
    ctrlMove.events:RegisterEvent("MODIFIER_STATE_CHANGED")
    ctrlMove.events:RegisterEvent("PLAYER_REGEN_DISABLED")
end

function DBR.ApplyLocked(locked)
    DBR.db.locked = locked == true
    ctrlMove.on = false
    DBR.RefreshReminders()
    DBR.RefreshSeal()
    DBR.RefreshConsumables()
    DBR.RefreshAspectBar()
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
    DBR.ReportAspectBarDebug()
    DBR.ReportChimesDebug(not DBR.IsSecret(class) and class or nil)
    DBR.ReportProcsDebug(not DBR.IsSecret(class) and class or nil)
    DBR.ReportCastsDebug(not DBR.IsSecret(class) and class or nil)
    DBR.ReportComboDebug()
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
    DBR.remindersFirstRun = type(saved) ~= "table" or type(saved.spells) ~= "table"
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
    -- After the saved settings load and before any widget exists.
    JoinProfile(DBR.toolkit)
    -- Before any widget exists: the toolkit's lock state is DBR's.
    DBR.db.locked = DBR.toolkit.IsLocked() ~= false
    local _, class = UnitClass("player")
    class = not DBR.IsSecret(class) and class or nil
    DBR.classFile = class
    if DBR.remindersFirstRun then
        DBR.ImportReminders(class)
    end
    DBR.InitializeReminders(class)
    DBR.InitializeSeal(class)
    DBR.InitializeConsumables(class)
    DBR.InitializeAspectBar(class)
    if #DBR.ClassReminders() == 0 then
        DBR.Report("There are no buff reminders for your class yet.")
    end
    if DBR.chimesFirstRun then
        DBR.ImportChimes(class)
    end
    DBR.ReportMissingSounds(class)
    DBR.ReportOtherChimes(class)
    DBR.InitializeChimes(class)
    -- DBR had proc settings: before this run, or copied now from WTF.
    local hadProcs = not DBR.procsFirstRun
    if DBR.procsFirstRun then
        hadProcs = DBR.ImportProcs(class) == true
    end
    -- Proc cues (1.13.0): once, from DSU 1.4 and DBR's own Proc Chimes.
    DBR.ImportProcCues(hadProcs)
    DBR.InitializeProcs(class)
    DBR.ReportOtherProcs(class)
    DBR.InitializeCasts(class)
    DBR.InitializeCombo(class)
    DBR.InitializeProbe()
    DBR.InitializeOptions()
    DBR.toolkit.RegisterAddOn({addon = addonName, title = DEFAULT_TITLE, setLocked = DBR.ApplyLocked,
        openSettings = DBR.OpenSettings})
end)
