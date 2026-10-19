local addonName, DBR = ...

-- Dyre's Buff Reminders: the buff reminders from Mage Tools Forever and
-- Warlock Tools Forever on their own, for any class with buffs in Buffs.lua,
-- and the cooldown chimes from Dyre's Cooldown Chimes, which merged into it
-- (author).
-- This file owns saved settings, the login banner, install and API checks,
-- slash conflict reporting, the frame lock and its grid, and startup.
local DEFAULT_TITLE = "Dyre's Buff Reminders"
local READY_MESSAGE = "  Ready. Type /dbr to open the settings."
local SLASH_KEY = "DYRESBUFFREMINDERS"
local PRIMARY_SLASH = "/dbr"
local BACKUP_SLASH = "/buffreminders"
local MAX_SLASH_ALIASES = 10
local UNLOCK_HINT = "Drag to move Â· /dbr lock when done"
DBR.available = false

function DBR.Report(message)
    DEFAULT_CHAT_FRAME:AddMessage("DBR: " .. tostring(message))
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
    "ParseCommand", "HandleCommand", "RegisterMovable", "BeginDrag", "EndDrag", "ScaleKeepingCenter",
    "ClassReminders", "SanitizeReminders", "SanitizeReminderScale", "SanitizeLead", "InitializeReminders",
    "RefreshReminders", "ResetRemindersPosition", "ReportRemindersDebug", "SanitizeSeal", "InitializeSeal",
    "RefreshSeal", "ResetSealPosition", "ReportSealDebug", "HasSealTimer",
    "ClassChimes", "SoundLibrary", "ReportMissingSounds", "SanitizeChimes", "ImportChimes", "ReportOtherChimes",
    "InitializeChimes", "PreviewChime", "ReportChimesDebug", "InitializeOptions", "OpenSettings",
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
    if type(DBR.BUFFS) ~= "table" or type(DBR.SEALS) ~= "table" or type(DBR.CHIME_SPELLS) ~= "table" then
        return false, "AddOn files are from different versions (missing Buffs.lua, Seals.lua, or "
            .. "ChimeSpells.lua). Reinstall every Dyre's Buff Reminders file, then restart the client."
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
    db.locked = db.locked ~= false
    db.grid = db.grid ~= false
    if DBR.SanitizeReminders and type(DBR.BUFFS) == "table" then
        DBR.SanitizeReminders(db, SanitizePosition)
    end
    -- The seal size uses the reminders scale rules.
    if DBR.SanitizeSeal and DBR.SanitizeReminderScale then
        db.seal = DBR.SanitizeSeal(db.seal, SanitizePosition)
    end
    if DBR.SanitizeChimes and type(DBR.CHIME_SPELLS) == "table" then
        db.chimes = DBR.SanitizeChimes(db.chimes)
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

-- While unlocked, a frame shows a gold outline and a hint (author-approved,
-- as MTF's). A plain child, so it can show and hide also in combat.
function DBR.CreateMover(frame)
    local mover = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    mover:SetPoint("TOPLEFT", -4, 4)
    mover:SetPoint("BOTTOMRIGHT", 4, -4)
    mover:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14})
    mover:SetBackdropBorderColor(1, 0.82, 0)
    mover.hint = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mover.hint:SetPoint("BOTTOM", mover, "TOP", 0, 2)
    mover.hint:SetText(UNLOCK_HINT)
    mover:SetShown(not DBR.db.locked)
    return mover
end

-- While unlocked, an alignment grid over the screen (author-approved, as
-- MTF's): faint lines every GRID_SPACING from the center out, and the center
-- lines in red, so frames line up with the middle of the screen. Under every
-- frame, it takes no mouse. Rebuilt when the screen size or UI scale changes.
local GRID_SPACING = 32
local GRID_LINE = {1, 1, 1, 0.12}
local GRID_CENTER = {1, 0.2, 0.2, 0.7}
local grid

local function GridLine(vertical, offset, color, thickness)
    local line = grid:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(color[1], color[2], color[3], color[4])
    if vertical then
        line:SetPoint("TOP", grid, "TOP", offset, 0)
        line:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
        line:SetWidth(thickness)
    else
        line:SetPoint("LEFT", grid, "LEFT", 0, offset)
        line:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
        line:SetHeight(thickness)
    end
    grid.lines[#grid.lines + 1] = line
end

local function BuildGrid()
    for _, line in ipairs(grid.lines) do
        line:Hide()
    end
    grid.lines = {}
    local halfWidth, halfHeight = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
    for step = 1, math.floor(halfWidth / GRID_SPACING) do
        GridLine(true, step * GRID_SPACING, GRID_LINE, 1)
        GridLine(true, -step * GRID_SPACING, GRID_LINE, 1)
    end
    for step = 1, math.floor(halfHeight / GRID_SPACING) do
        GridLine(false, step * GRID_SPACING, GRID_LINE, 1)
        GridLine(false, -step * GRID_SPACING, GRID_LINE, 1)
    end
    GridLine(true, 0, GRID_CENTER, 2)
    GridLine(false, 0, GRID_CENTER, 2)
    grid.built = true
end

function DBR.RefreshGrid()
    local wanted = not DBR.db.locked and DBR.db.grid
    if not grid then
        if not wanted then
            return
        end
        grid = CreateFrame("Frame", nil, UIParent)
        grid:SetAllPoints(UIParent)
        grid:SetFrameStrata("BACKGROUND")
        grid:EnableMouse(false)
        grid.lines = {}
        grid:SetScript("OnEvent", function() grid.built = false; DBR.RefreshGrid() end)
        grid:RegisterEvent("DISPLAY_SIZE_CHANGED")
        grid:RegisterEvent("UI_SCALE_CHANGED")
    end
    if wanted and not grid.built then
        BuildGrid()
    end
    grid:SetShown(wanted)
    DBR.grid = grid
end

-- Nothing to move or show for a class without buffs in Buffs.lua.
local function HasReminders()
    if #DBR.ClassReminders() > 0 or DBR.HasSealTimer() then
        return true
    end
    DBR.Report("There are no buff reminders for your class yet.")
    return false
end

-- /dbr unlock and /dbr lock, and the settings page's "Unlock to move them".
function DBR.SetLocked(locked)
    DBR.db.locked = locked
    DBR.RefreshReminders()
    DBR.RefreshSeal()
    DBR.RefreshGrid()
    if not HasReminders() then
        return
    end
    if locked then
        DBR.Report("Buff reminders locked.")
    elseif InCombatLockdown() then
        DBR.Report("Buff reminders unlocked: they show to drag after combat.")
    else
        DBR.Report("Buff reminders unlocked: drag them where you want (Shift-drag moves a snapped group; "
            .. "scroll over one to resize it), then type /dbr lock.")
    end
end

function DBR.Unlock()
    DBR.SetLocked(false)
end

function DBR.Lock()
    DBR.SetLocked(true)
end

-- /dbr reset: every icon back to its default place and size.
function DBR.ResetPositions()
    local now = DBR.ResetRemindersPosition()
    now = DBR.ResetSealPosition() and now
    if not HasReminders() then
        return
    end
    if now then
        DBR.Report("Buff reminders moved back to their default places.")
    else
        DBR.Report("Buff reminders move back to their default places after combat.")
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
    DBR.ReportChimesDebug(not DBR.IsSecret(class) and class or nil)
end

SLASH_DYRESBUFFREMINDERS1 = PRIMARY_SLASH
SLASH_DYRESBUFFREMINDERS2 = BACKUP_SLASH
SlashCmdList[SLASH_KEY] = function(message) DBR.HandleCommand(message) end

local function LoadDB()
    -- No chime settings yet: the chimes' first run on this character.
    local saved = DyresBuffRemindersDB
    DBR.chimesFirstRun = type(saved) ~= "table" or type(saved.chimes) ~= "table"
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
    local _, class = UnitClass("player")
    class = not DBR.IsSecret(class) and class or nil
    DBR.classFile = class
    DBR.InitializeReminders(class)
    DBR.InitializeSeal(class)
    if #DBR.ClassReminders() == 0 then
        DBR.Report("There are no buff reminders for your class yet.")
    end
    if DBR.chimesFirstRun then
        DBR.ImportChimes(class)
    end
    DBR.ReportMissingSounds(class)
    DBR.ReportOtherChimes(class)
    DBR.InitializeChimes(class)
    DBR.RefreshGrid()
    DBR.InitializeOptions()
end)
