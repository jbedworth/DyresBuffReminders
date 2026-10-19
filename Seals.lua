local _, DBR = ...

-- The seal timer, for Paladins (author-approved): while any seal is up, its
-- icon with the time left (a cooldown sweep with numbers, and a bar under the
-- icon), in and out of combat. In combat with no seal up, the last seal you
-- used shows with the pulsing gold border, and a click casts it. Out of
-- combat with no seal up, nothing shows.
--
-- AddOn code cannot read auras in combat, so Blizzard's AuraContainer draws
-- the seal: the engine shows its slot while a seal is up and hides it the
-- moment the seal goes, also in combat (as Dyre's Shields Up's icon row). The
-- "missing" picture is a secure button under the slot, shown in combat by a
-- state driver; a seal's icon covers it, so it shows through only when no
-- seal is up. The slot takes no mouse, so a click reaches the button. Its
-- attributes change only out of combat: a seal you cast in combat becomes
-- the click after combat.

-- Classic IDs, every rank; the seal's buff has its spell's ID. Righteousness
-- has two rank 1 IDs (21084 for new Paladins).
DBR.SEALS = {
    {name = "Righteousness", spells = {21084, 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293}},
    {name = "Command", spells = {20375, 20915, 20918, 20919, 20920}},
    {name = "the Crusader", spells = {21082, 20162, 20305, 20306, 20307, 20308}},
    {name = "Justice", spells = {20164}},
    {name = "Light", spells = {20165, 20347, 20348, 20349}},
    {name = "Wisdom", spells = {20166, 20356, 20357}},
}
DBR.SEAL_CLASS = "PALADIN"

local ICON_SIZE = 40
local BAR_HEIGHT = 5
local BAR_GAP = 2
local BORDER = 3
local GOLD = {1, 0.82, 0}
local BAR_COLOR = {1, 0.82, 0}
local PULSE_SECONDS = 0.6
local PULSE_LOW_ALPHA = 0.15
-- Above the reminder row's default place.
local DEFAULT_POINT = {point = "CENTER", relativePoint = "CENTER", x = 0, y = 240}
local AURA_FILTER = "HELPFUL"
local CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local COMBAT_ONLY = "[combat] show; hide"
local NEVER = "hide"
-- The slot sits above the button, so a seal's icon covers the missing picture.
local SLOT_LEVELS_ABOVE = 5

local seal = {spellIDs = {}}

function DBR.SanitizeSeal(saved, sanitizePosition)
    saved = type(saved) == "table" and saved or {}
    return {enabled = saved.enabled ~= false, position = sanitizePosition(saved.position),
        scale = DBR.SanitizeReminderScale(saved.scale)}
end

local function Knows(id)
    return C_SpellBook.IsSpellKnown(id) == true
end

-- The seal a click casts: the last one you used, else Righteousness, else the
-- first you know; by name, so your highest rank.
local function ClickSeal()
    local last = DBR.db.last.seal
    local first
    for _, entry in ipairs(DBR.SEALS) do
        for _, id in ipairs(entry.spells) do
            if Knows(id) then
                local name = C_Spell.GetSpellName(id)
                if name and name == last then
                    return name, id
                end
                if not first then
                    first = {name, id}
                end
            end
        end
    end
    if first then
        return first[1], first[2]
    end
end

local function HasAuraContainer()
    if type(C_XMLUtil) ~= "table" or type(C_XMLUtil.GetTemplateInfo) ~= "function"
        or type(C_AddOns) ~= "table" or type(C_AddOns.LoadAddOn) ~= "function" then
        return false
    end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    return C_XMLUtil.GetTemplateInfo(CONTAINER_TEMPLATE) ~= nil
end

local function NoMouse(region)
    for _, method in ipairs({"SetMouseClickEnabled", "SetMouseMotionEnabled"}) do
        if type(region[method]) == "function" then
            region[method](region, false)
        end
    end
    region:EnableMouse(false)
end

-- The engine shows this while a seal is up: the seal's icon, a sweep with
-- numbers for its time left, and a bar under it that drains.
local function InitializeSlot(button)
    NoMouse(button)
    button:SetAllPoints(seal.display)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetHideCountdownNumbers(false)
    button:SetIcon(icon)
    button:SetDurationCooldown(cooldown)
    local bar = CreateFrame("StatusBar", nil, button)
    bar:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -BAR_GAP)
    bar:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -BAR_GAP)
    bar:SetHeight(BAR_HEIGHT)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3])
    local direction = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
    button:SetDurationBar(bar, {direction = direction})
    seal.slot = button
end

local function CreateContainer()
    local container = CreateFrame("AuraContainer", nil, seal.display, CONTAINER_TEMPLATE)
    container:SetPoint("CENTER", seal.display, "CENTER")
    container:SetSize(1, 1)
    container:SetFrameLevel(seal.button:GetFrameLevel() + SLOT_LEVELS_ABOVE)
    -- includeSpellIDs is a set, {[spellID] = true}, not a list (found in client).
    local ids = {}
    for _, entry in ipairs(DBR.SEALS) do
        for _, id in ipairs(entry.spells) do
            ids[id] = true
        end
    end
    container:AddAuraSlot("seal", AURA_FILTER, {
        candidateFilters = {includeSpellIDs = ids},
        initializeFrame = InitializeSlot,
    })
    container:SetUnit("player")
    container:UpdateAllAuras()
    seal.container = container
end

-- The missing picture: a secure button, so a click casts your seal.
local function CreateButton()
    local button = CreateFrame("Button", "DyresBuffRemindersSealButton", seal.display,
        "SecureActionButtonTemplate")
    button:SetAllPoints(seal.display)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("useOnKeyDown", false)
    button.texture = button:CreateTexture(nil, "ARTWORK")
    button.texture:SetAllPoints()
    button.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local glow = CreateFrame("Frame", nil, button, "BackdropTemplate")
    glow:SetPoint("TOPLEFT", -BORDER - 1, BORDER + 1)
    glow:SetPoint("BOTTOMRIGHT", BORDER + 1, -BORDER - 1)
    glow:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = BORDER})
    glow:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
    glow:EnableMouse(false)
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(PULSE_LOW_ALPHA)
    fade:SetDuration(PULSE_SECONDS)
    pulse:Play()
    button.glow, button.pulse = glow, pulse
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("No seal", GOLD[1], GOLD[2], GOLD[3])
        if self.spell then
            GameTooltip:AddLine("Click: " .. self.spell .. ".", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    seal.button = button
end

local function Place()
    local position = DBR.db.seal.position or DEFAULT_POINT
    seal.display:ClearAllPoints()
    seal.display:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

-- Dragging and snapping: Layout.lua, as the reminder icons.
local function Resize(display, delta)
    if DBR.db.locked or InCombatLockdown() then
        return
    end
    local saved = DBR.db.seal
    local step = delta > 0 and DBR.REMINDER_SCALE_STEP or -DBR.REMINDER_SCALE_STEP
    saved.scale = DBR.SanitizeReminderScale(saved.scale + step)
    DBR.ScaleKeepingCenter(display, saved.scale / 100)
end

local function CreateDisplay()
    local display = CreateFrame("Frame", "DyresBuffRemindersSeal", UIParent)
    display:SetSize(ICON_SIZE, ICON_SIZE)
    display:SetMovable(true)
    display:SetClampedToScreen(true)
    display:RegisterForDrag("LeftButton")
    display:SetScript("OnDragStart", DBR.BeginDrag)
    display:SetScript("OnDragStop", DBR.EndDrag)
    display:SetScript("OnMouseWheel", Resize)
    display:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Seal timer", GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine("Drag to move; drop near another to snap; Shift-drag to move a snapped group; "
            .. "scroll to resize.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    display:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- While unlocked, a sample to drag.
    display.sample = display:CreateTexture(nil, "BACKGROUND")
    display.sample:SetAllPoints()
    display.sample:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    seal.display = display
    display.mover = DBR.CreateMover(display)
    display.mover.hint:SetText("")
    DBR.RegisterMovable(display, function(position) DBR.db.seal.position = position end)
end

-- Out of combat only: the click, the missing picture, size, lock, and
-- whether the timer shows at all.
function DBR.RefreshSeal()
    if not seal.ready then
        return
    end
    if InCombatLockdown() then
        seal.dirty = true
        return
    end
    seal.dirty = false
    local db = DBR.db
    local name, id = ClickSeal()
    local wanted = db.enabled and db.seal.enabled and name ~= nil
    local unlocked = not db.locked
    local button = seal.button
    button.spell = name
    button:SetAttribute("type1", (wanted and not unlocked) and "spell" or nil)
    button:SetAttribute("spell1", (wanted and not unlocked) and name or nil)
    button:SetAttribute("unit1", (wanted and not unlocked) and "player" or nil)
    local texture = id and C_Spell.GetSpellTexture(id)
    button.texture:SetTexture(texture)
    seal.display.sample:SetTexture(texture)
    seal.display:SetScale(db.seal.scale / 100)
    seal.display:SetShown(db.enabled and db.seal.enabled)
    seal.display.sample:SetShown(unlocked)
    seal.display.mover:SetShown(unlocked)
    seal.display:EnableMouse(unlocked)
    seal.display:EnableMouseWheel(unlocked)
    -- Unlocked, the button stays hidden so the drag reaches the display.
    local driver = (wanted and not unlocked) and COMBAT_ONLY or NEVER
    if seal.driver ~= driver then
        seal.driver = driver
        RegisterStateDriver(button, "visibility", driver)
    end
end

function DBR.ResetSealPosition()
    if not DBR.db.seal then
        return true
    end
    DBR.db.seal.position, DBR.db.seal.scale = nil, DBR.DEFAULT_REMINDER_SCALE
    if not seal.ready then
        return true
    end
    if InCombatLockdown() then
        seal.placeDirty = true
        return false
    end
    Place()
    DBR.RefreshSeal()
    return true
end

-- Whether this character has the seal timer (a Paladin with the container).
function DBR.HasSealTimer()
    return seal.ready == true
end

-- A seal you cast becomes the click; own casts stay readable in combat.
local function RememberCast(spellID)
    if not DBR.IsSecret(spellID) and seal.spellIDs[spellID] then
        DBR.db.last.seal = C_Spell.GetSpellName(spellID)
        DBR.RefreshSeal()
    end
end

local events = CreateFrame("Frame")
local SetUp

events:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        RememberCast(spellID)
        return
    end
    if InCombatLockdown() then
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        -- After a reload in combat, the secure button is set up only now.
        if seal.setupPending then
            seal.setupPending = false
            SetUp()
            return
        end
        if seal.placeDirty then
            seal.placeDirty = false
            Place()
        end
        if not seal.dirty then
            return
        end
    end
    DBR.RefreshSeal()
end)

function SetUp()
    CreateDisplay()
    CreateButton()
    CreateContainer()
    Place()
    seal.ready = true
    events:RegisterEvent("SPELLS_CHANGED")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    DBR.RefreshSeal()
end

function DBR.InitializeSeal(class)
    if class ~= DBR.SEAL_CLASS then
        return
    end
    for _, entry in ipairs(DBR.SEALS) do
        for _, id in ipairs(entry.spells) do
            seal.spellIDs[id] = true
        end
    end
    if not HasAuraContainer() then
        DBR.Report("The seal timer stays off: this client lacks Blizzard's aura container.")
        return
    end
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    if InCombatLockdown() then
        seal.setupPending = true
        return
    end
    SetUp()
end

-- /dbr debug: the seal timer's state, and seal IDs the client does not know.
function DBR.ReportSealDebug()
    if not seal.ready then
        return
    end
    local unknown = {}
    for _, entry in ipairs(DBR.SEALS) do
        for _, id in ipairs(entry.spells) do
            if not C_Spell.GetSpellName(id) then
                unknown[#unknown + 1] = id
            end
        end
    end
    DBR.Report(string.format("debug seal on=%s click=%s driver=%s unknownIDs=%s",
        tostring(DBR.db.seal.enabled), tostring(seal.button.spell), tostring(seal.driver),
        #unknown > 0 and table.concat(unknown, ",") or "none"))
end
