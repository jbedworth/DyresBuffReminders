local addonName, DBR = ...

-- The seal timer, for Paladins (author-approved): while any seal is up, its
-- icon with the time left (a cooldown sweep with numbers, and a bar under the
-- icon), in and out of combat. In combat with no seal up, the last seal you
-- used shows with the pulsing gold border, and a click casts it. Out of
-- combat with no seal up, nothing shows.
--
-- On Classic Era and Anniversary (no engine, nothing secret) AuraEngine.lua's
-- plain-Lua container draws the same slot from aura reads (author: "paladin
-- seals aren't showing up in era"; how the seals work does not change).
--
-- AddOn code cannot read auras in combat, so Blizzard's AuraContainer draws
-- the seal: the engine shows its slot while a seal is up and hides it the
-- moment the seal goes, also in combat (as Dyre's Shields Up's icon row). The
-- "missing" picture is a secure button under the slot, shown in combat by a
-- state driver; a seal's icon covers it, so it shows through only when no
-- seal is up. The slot takes no mouse, so a click reaches the button. Its
-- attributes change only out of combat: a seal you cast in combat becomes
-- the click after combat.
--
-- The timer is a Dyre's Toolkit widget (1.1.0): the toolkit places, drags,
-- sizes, and saves it, under the keys the timer had (db.seal.position and
-- scale), so a place from before carries over.

-- Every rank; the seal's buff has its spell's ID. Classic IDs, and Forever's
-- Seal of Fury (found in client: a seal Classic lacks, so the timer missed
-- it; IDs from ForeverAuras' spell table). Any other "Seal of" spell in your
-- spellbook counts too, so a seal Forever adds later is tracked.
DBR.SEALS = {
    {name = "Righteousness", spells = {21084, 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293}},
    {name = "Fury", spells = {20163, 20419, 20421, 20422, 20423, 1311649, 1311656}},
    {name = "Command", spells = {20375, 20915, 20918, 20919, 20920}},
    {name = "the Crusader", spells = {21082, 20162, 20305, 20306, 20307, 20308}},
    {name = "Justice", spells = {20164}},
    {name = "Light", spells = {20165, 20347, 20348, 20349}},
    {name = "Wisdom", spells = {20166, 20356, 20357}},
}
DBR.SEAL_CLASS = "PALADIN"

local ICON_SIZE = 40
local BAR_HEIGHT = 5
local BORDER = 3
-- Under the missing picture's pulsing border.
local BAR_GAP = BORDER + 3
-- The timer's track: opaque, so the missing picture's full gold bar never
-- shows through a draining one.
local TRACK_COLOR = {0.08, 0.06, 0.04}
local GOLD = {1, 0.82, 0}
local BAR_COLOR = {1, 0.82, 0}
local PULSE_SECONDS = 0.6
local PULSE_LOW_ALPHA = 0.15
-- Above the buff bars' default places.
local DEFAULT_POINT = {point = "CENTER", relativePoint = "CENTER", x = 0, y = 240}
local AURA_FILTER = "HELPFUL"
local COMBAT_ONLY = "[combat] show; hide"
local NEVER = "hide"
-- The slot sits above the button, so a seal's icon covers the missing picture.
local SLOT_LEVELS_ABOVE = 5
local SEAL_PREFIX = "^Seal of "

local seal = {ids = {}, count = 0}

function DBR.SanitizeSeal(saved, sanitizePosition)
    saved = type(saved) == "table" and saved or {}
    -- The toolkit clamps the sizes when it makes the widget.
    return {enabled = saved.enabled ~= false, position = sanitizePosition(saved.position), scale = saved.scale,
        opacity = saved.opacity}
end

local function Knows(id)
    return C_SpellBook.IsSpellKnown(id) == true
end

local function IsSealName(name)
    return type(name) == "string" and not DBR.IsSecret(name) and name:find(SEAL_PREFIX) ~= nil
end

-- Learned spellbook spells named "Seal of ...", as spell IDs.
local function SpellbookSeals()
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local learned = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    local found = {}
    if not bank or not learned or type(book.GetNumSpellBookSkillLines) ~= "function"
        or type(book.GetSpellBookSkillLineInfo) ~= "function" or type(book.GetSpellBookItemInfo) ~= "function" then
        return found
    end
    for line = 1, book.GetNumSpellBookSkillLines() do
        local info = book.GetSpellBookSkillLineInfo(line)
        if type(info) == "table" and type(info.itemIndexOffset) == "number"
            and type(info.numSpellBookItems) == "number" then
            for index = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = book.GetSpellBookItemInfo(index, bank)
                if type(item) == "table" and item.itemType == learned and type(item.spellID) == "number"
                    and IsSealName(item.name) then
                    found[#found + 1] = item.spellID
                end
            end
        end
    end
    return found
end

-- Every seal ID, in order: the list above, then spellbook seals it lacks.
-- Returns the IDs as a list and whether any is new since the last call.
local function SealIDs()
    local list, grew = {}, false
    local function Add(id)
        if not seal.ids[id] then
            seal.ids[id] = true
            seal.count = seal.count + 1
            grew = true
        end
        list[#list + 1] = id
    end
    for _, entry in ipairs(DBR.SEALS) do
        for _, id in ipairs(entry.spells) do
            Add(id)
        end
    end
    for _, id in ipairs(SpellbookSeals()) do
        Add(id)
    end
    return list, grew
end

-- The seal a click casts: the last one you used, else the first you know
-- (Righteousness, then Fury, and so on); by name, so your highest rank.
local function ClickSeal(list)
    local last = DBR.db.last.seal
    local first
    for _, id in ipairs(list) do
        if Knows(id) then
            local name = C_Spell.GetSpellName(id)
            if name and name == last then
                return name, id
            end
            if name and not first then
                first = {name, id}
            end
        end
    end
    if first then
        return first[1], first[2]
    end
end

-- The engine's container (Forever), else AuraEngine.lua's plain-Lua one.
local function HasAuraContainer()
    return type(DBR.AuraEngineKind) == "function" and DBR.AuraEngineKind() ~= nil
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
    bar.track = bar:CreateTexture(nil, "BACKGROUND")
    bar.track:SetAllPoints()
    bar.track:SetColorTexture(TRACK_COLOR[1], TRACK_COLOR[2], TRACK_COLOR[3], 1)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3])
    local direction = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
    button:SetDurationBar(bar, {direction = direction})
end

-- A slot's spell IDs are fixed once added, so a new seal in your spellbook
-- gets a new container (out of combat); the old one is hidden.
local function CreateContainer()
    if seal.container then
        seal.container:Hide()
    end
    local container = DBR.CreateAuraContainer(seal.display)
    container:SetPoint("CENTER", seal.display, "CENTER")
    container:SetSize(1, 1)
    container:SetFrameLevel(seal.button:GetFrameLevel() + SLOT_LEVELS_ABOVE)
    -- includeSpellIDs is a set, {[spellID] = true}, not a list (found in client).
    local ids = {}
    for id in pairs(seal.ids) do
        ids[id] = true
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
    -- A full gold bar where the timer's bar drains (author-approved), so the
    -- seal reminder never looks like another reminder with the same picture
    -- (Righteous Fury and Seal of Fury share one, found in client).
    local bar = button:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -BAR_GAP)
    bar:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -BAR_GAP)
    bar:SetHeight(BAR_HEIGHT)
    bar:SetColorTexture(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3], 1)
    button.bar = bar
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

local function CreateDisplay()
    local display = CreateFrame("Frame", "DyresBuffRemindersSeal", UIParent)
    display:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Seal timer", GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine("Drag to move it.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    display:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- While unlocked, a sample to drag.
    display.sample = display:CreateTexture(nil, "BACKGROUND")
    display.sample:SetAllPoints()
    display.sample:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    seal.display = display
end

-- After the secure button exists, so the toolkit treats the timer as
-- protected: it moves and resizes only out of combat.
local function CreateWidget()
    DBR.toolkit.CreateWidget({
        addon = addonName, key = "seal", title = "Seal timer", frame = seal.display, store = DBR.db.seal,
        width = ICON_SIZE, height = ICON_SIZE, point = DEFAULT_POINT, sizes = DBR.WIDGET_SIZES,
    })
end

-- Out of combat only: the click, the missing picture, the sample while
-- unlocked, and whether the timer shows at all.
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
    local list, grew = SealIDs()
    if grew and seal.container then
        CreateContainer()
    end
    local name, id = ClickSeal(list)
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
    seal.display:SetShown(db.enabled and db.seal.enabled)
    seal.display.sample:SetShown(unlocked)
    -- Unlocked, the button stays hidden so the drag reaches the display.
    local driver = (wanted and not unlocked) and COMBAT_ONLY or NEVER
    if seal.driver ~= driver then
        seal.driver = driver
        RegisterStateDriver(button, "visibility", driver)
    end
end

-- Whether this character has the seal timer (a Paladin with the container).
function DBR.HasSealTimer()
    return seal.ready == true
end

-- The timer's widget, for the settings page; nil without the timer.
function DBR.SealWidget()
    return seal.ready and seal.display or nil
end

-- A seal you cast becomes the click, by name, so any seal counts; own casts
-- stay readable in combat.
local function RememberCast(spellID)
    if DBR.IsSecret(spellID) or type(spellID) ~= "number" then
        return
    end
    local name = C_Spell.GetSpellName(spellID)
    if seal.ids[spellID] or IsSealName(name) then
        DBR.db.last.seal = name
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
        if not seal.dirty then
            return
        end
    end
    DBR.RefreshSeal()
end)

function SetUp()
    SealIDs()
    CreateDisplay()
    CreateButton()
    CreateContainer()
    CreateWidget()
    -- The seal button (shown in combat with no seal, and unlocked) is a drag
    -- handle; locked, the timer itself takes a Ctrl-drag.
    seal.display:AddDragHandle(seal.button)
    DBR.AddCtrlMove(seal.display)
    seal.ready = true
    events:RegisterEvent("SPELLS_CHANGED")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    DBR.RefreshSeal()
end

function DBR.InitializeSeal(class)
    if class ~= DBR.SEAL_CLASS then
        return
    end
    if not HasAuraContainer() then
        DBR.Report("The seal timer stays off: this client lacks Blizzard's aura container and aura reads.")
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
    local book = {}
    for _, id in ipairs(SpellbookSeals()) do
        book[#book + 1] = id
    end
    DBR.Report(string.format("debug seal on=%s click=%s last=%s driver=%s sealIDs=%d spellbook=%s unknownIDs=%s",
        tostring(DBR.db.seal.enabled), tostring(seal.button.spell), tostring(DBR.db.last.seal),
        tostring(seal.driver), seal.count, #book > 0 and table.concat(book, ",") or "none",
        #unknown > 0 and table.concat(unknown, ",") or "none"))
end
