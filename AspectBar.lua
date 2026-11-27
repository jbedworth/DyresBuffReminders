local addonName, DBR = ...

-- The aspect bar, for Hunters (John, 1.8.0: "I'm about to level my hunter,
-- so, can we add a Hunter aspect bar to DBR that one-click swaps aspects";
-- a player asked first for DBR "as a stance bar for aspects"). One secure
-- button per aspect you know, in DBR.ASPECT_BAR's order; a click casts
-- "/use !<Name>", as the Aspect reminder does, so it never takes an aspect
-- down. The class picks the list (data, not a gate).
--
-- The aspect that is up has a gold border. Out of combat DBR reads it from
-- the aura, by name. Aura reads are refused in combat, so there the
-- player's own UNIT_SPELLCAST_SUCCEEDED for an aspect moves the border (own
-- casts stay readable). A secret value counts as unknown: the border stays.
-- The border is a plain frame shown by alpha, so it changes in combat too.
--
-- The buttons are secure: they are made, placed, armed, shown, and hidden
-- only out of combat (SPELLS_CHANGED for a new aspect or rank; a change asked
-- for in combat waits for PLAYER_REGEN_ENABLED). Hidden while dead or on a
-- flight path, as the reminders; shown while mounted. Unlocked, the bar shows
-- to be placed and its clicks do nothing (dragging must not cast). A Dyre's
-- Toolkit widget: the toolkit places, drags, snaps, sizes, fades, and locks it.

-- key: saved and in frame names. spells: every rank, lowest first (Classic
-- IDs, and TBC's where known); a rank counts by ID, the click by name, which
-- casts your highest rank. Combat aspects first (author's order), then the
-- travel aspects.
DBR.ASPECT_BAR = {
    HUNTER = {
        {key = "hawk", spells = {13165, 14318, 14319, 14320, 14321, 14322, 25296, 27044}},
        {key = "monkey", spells = {13163}},
        {key = "viper", spells = {34074}},
        {key = "beast", spells = {13161}},
        {key = "wild", spells = {20043, 20190, 27045}},
        {key = "cheetah", spells = {5118}},
        {key = "pack", spells = {13159}},
    },
}

local BUTTON_SIZE = 36
local BUTTON_GAP = 4
local BORDER = 3
local GOLD = {1, 0.82, 0}
local AURA_FILTER = "HELPFUL"
-- Under My buffs' default row (y 130, icons 40 tall), the toolkit's snap gap
-- (20) below it; the Consumables bar sits to the right of that row.
local DEFAULT_POINT = {point = "CENTER", relativePoint = "CENTER", x = 0, y = 72}

local bar = {buttons = {}, names = {}}

function DBR.SanitizeAspectBar(saved, sanitizePosition)
    saved = type(saved) == "table" and saved or {}
    -- On at first for Hunters (John, 2026-11-13: "make it on by default for
    -- hunters"); only a saved false turns it off. The toolkit clamps the sizes.
    -- The layout is the toolkit's `orientation` ("vertical", else nil:
    -- horizontal; Toolkit 2.18.0's button bars). DBR 1.8.0 to 1.14.0 saved
    -- `vertical = true`: moved once, then dropped, so a later horizontal stays.
    local orientation = saved.orientation
    if orientation == nil and saved.vertical == true then
        orientation = "vertical"
    end
    return {enabled = saved.enabled ~= false, orientation = orientation == "vertical" and "vertical" or nil,
        position = sanitizePosition(saved.position), scale = saved.scale, opacity = saved.opacity}
end

-- Toolkit 2.18.0's button bars (a feature test): the toolkit lays the
-- buttons out and gives the Layout row; before it, DBR's own code below.
local function ToolkitLayout()
    local toolkit = DBR.toolkit
    return type(toolkit) == "table" and type(toolkit.BAR_LAYOUT_VERSION) == "number"
        and toolkit.BAR_LAYOUT_VERSION >= 1 and bar.frame ~= nil and type(bar.frame.LayoutButtons) == "function"
end
DBR.AspectBarUsesToolkitLayout = ToolkitLayout

function DBR.AspectBarVertical()
    if ToolkitLayout() then
        return bar.frame:GetOrientation() == "vertical"
    end
    return DBR.db.aspectBar.orientation == "vertical"
end

local function Plain(value)
    return not DBR.IsSecret(value) and value or nil
end

-- The aspect's name and the ID of its highest rank you know; nil when you
-- know none (or the client does not know the spell).
local function KnownRank(aspect)
    for index = #aspect.spells, 1, -1 do
        local id = aspect.spells[index]
        if C_SpellBook.IsSpellKnown(id) == true then
            local name = Plain(C_Spell.GetSpellName(id))
            if type(name) == "string" then
                return name, id
            end
        end
    end
end

-- Out of combat: the key of the aspect up on you, false for none, nil when a
-- read was secret (unknown: the border stays).
local function AspectUp()
    local unknown = false
    for _, button in ipairs(bar.buttons) do
        if button.spell then
            local aura = C_UnitAuras.GetAuraDataBySpellName("player", button.spell, AURA_FILTER)
            if DBR.IsSecret(aura) then
                unknown = true
            elseif aura ~= nil then
                return button.aspect.key
            end
        end
    end
    if not unknown then
        return false
    end
end

local function ShowActive()
    for _, button in ipairs(bar.buttons) do
        button.glow:SetAlpha(bar.active == button.aspect.key and 1 or 0)
    end
end

local function SetActive(key)
    if key == nil then
        return
    end
    bar.active = key or nil
    ShowActive()
end

-- Out of combat, while the bar is on: the border from the aura.
local function ReadAura()
    if bar.ready and DBR.db.aspectBar.enabled then
        SetActive(AspectUp())
    end
end

-- A secret or missing answer counts as alive and not on a taxi.
local function CanUse()
    local dead = UnitIsDeadOrGhost("player")
    if not DBR.IsSecret(dead) and dead == true then
        return false
    end
    if type(UnitOnTaxi) == "function" then
        local onTaxi = UnitOnTaxi("player")
        if not DBR.IsSecret(onTaxi) and onTaxi == true then
            return false
        end
    end
    return true
end

-- Out of combat only: which buttons show, their places, clicks, and the bar.
function DBR.RefreshAspectBar()
    if not bar.ready then
        return
    end
    if InCombatLockdown() then
        bar.dirty = true
        return
    end
    bar.dirty = false
    local db = DBR.db
    local saved = db.aspectBar
    local unlocked = not db.locked
    local shown = {}
    for _, button in ipairs(bar.buttons) do
        local name, id = KnownRank(button.aspect)
        button.spell = name
        if name then
            button.texture:SetTexture(C_Spell.GetSpellTexture(id))
            shown[#shown + 1] = button
        end
    end
    -- Unlocked with no aspect yet (a Hunter before level 10): one sample to place.
    local sample = unlocked and #shown == 0 and bar.buttons[1] or nil
    if sample then
        sample.texture:SetTexture(C_Spell.GetSpellTexture(sample.aspect.spells[1]))
        shown[1] = sample
    end
    local visible = saved.enabled and #shown > 0 and (unlocked or CanUse())
    for _, button in ipairs(bar.buttons) do
        button:Hide()
        button:SetAttribute("type1", nil)
        button:SetAttribute("macrotext1", nil)
    end
    local toolkitLayout = ToolkitLayout()
    local vertical = DBR.AspectBarVertical()
    for index, button in ipairs(shown) do
        if not toolkitLayout then
            local offset = (index - 1) * (BUTTON_SIZE + BUTTON_GAP)
            button:ClearAllPoints()
            if vertical then
                button:SetPoint("TOP", bar.frame, "TOP", 0, -offset)
            else
                button:SetPoint("LEFT", bar.frame, "LEFT", offset, 0)
            end
        end
        -- Dragging must not cast.
        if visible and not unlocked and button.spell then
            button:SetAttribute("type1", "macro")
            button:SetAttribute("macrotext1", "/use !" .. button.spell)
        end
        button:Show()
    end
    if toolkitLayout then
        -- The top-left corner stays as the bar grows: the left edge of a row,
        -- the top of a column, as before (one anchor, because the toolkit
        -- keeps it for a change of layout made on the settings page).
        bar.frame:LayoutButtons(shown, {size = BUTTON_SIZE, gap = BUTTON_GAP, anchor = "TOPLEFT"})
    else
        local length = math.max(#shown, 1) * BUTTON_SIZE + math.max(#shown - 1, 0) * BUTTON_GAP
        if vertical then
            bar.frame:SetContentSize(BUTTON_SIZE, length, "TOP")
        else
            bar.frame:SetContentSize(length, BUTTON_SIZE, "LEFT")
        end
    end
    bar.frame:SetShown(visible)
    bar.shown = #shown
    ReadAura()
end

-- Your own aspect cast, readable in combat too: the border moves to it.
local function OwnCast(spellID)
    if DBR.IsSecret(spellID) or type(spellID) ~= "number" then
        return
    end
    local name = Plain(C_Spell.GetSpellName(spellID))
    local key = type(name) == "string" and bar.names[name]
    if key then
        SetActive(key)
    end
end

local function ShowTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    local name = button.spell or C_Spell.GetSpellName(button.aspect.spells[1])
    GameTooltip:SetText(Plain(name) or "Aspect", GOLD[1], GOLD[2], GOLD[3])
    if not DBR.db.locked then
        GameTooltip:AddLine("Drag to move the aspect bar.", 1, 1, 1, true)
    elseif button.spell then
        if bar.active == button.aspect.key then
            GameTooltip:AddLine("It is up now.", 1, 1, 1, true)
        end
        GameTooltip:AddLine("Click: cast " .. button.spell .. ". A click never turns an aspect off.", 0.7, 0.7, 0.7,
            true)
    end
    GameTooltip:Show()
end

local function CreateButton(aspect)
    local button = CreateFrame("Button", "DyresBuffRemindersAspect_" .. aspect.key, bar.frame,
        "SecureActionButtonTemplate")
    button.aspect = aspect
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("useOnKeyDown", false)
    button.texture = button:CreateTexture(nil, "ARTWORK")
    button.texture:SetAllPoints()
    button.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    -- The up aspect's border: inside the button, so the gap stays small.
    local glow = CreateFrame("Frame", nil, button, "BackdropTemplate")
    glow:SetAllPoints(button)
    glow:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = BORDER})
    glow:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
    glow:EnableMouse(false)
    glow:SetAlpha(0)
    button.glow = glow
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
    -- A click in combat hides or shows the Aspect reminder (Reminders.lua).
    DBR.LinkAspectBarButton(button, aspect.spells[1])
    bar.buttons[#bar.buttons + 1] = button
    for _, id in ipairs(aspect.spells) do
        local name = Plain(C_Spell.GetSpellName(id))
        if type(name) == "string" then
            bar.names[name] = aspect.key
        end
    end
    return button
end

local events = CreateFrame("Frame")
local SetUp

events:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        OwnCast(spellID)
        return
    end
    if InCombatLockdown() then
        -- A new aspect or rank, death, a flight path: the buttons change
        -- after combat (before 1.15.0 only a settings change in combat
        -- marked this, so an aspect learned in combat waited for the next
        -- event). Aura reads are refused in combat: casts move the border.
        if event ~= "UNIT_AURA" and event ~= "PLAYER_REGEN_ENABLED" then
            bar.dirty = true
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if bar.setupPending then
            bar.setupPending = false
            SetUp()
            return
        end
        -- Auras are readable again: the border follows the aura, not the casts.
        if not bar.dirty then
            ReadAura()
            return
        end
    end
    if event == "UNIT_AURA" then
        ReadAura()
        return
    end
    DBR.RefreshAspectBar()
end)

function SetUp()
    bar.frame = CreateFrame("Frame", "DyresBuffRemindersAspectBar", UIParent)
    for _, aspect in ipairs(bar.list) do
        CreateButton(aspect)
    end
    -- After the secure buttons exist, so the toolkit treats the bar as
    -- protected: it moves and resizes only out of combat.
    DBR.toolkit.CreateWidget({
        addon = addonName, key = "aspectBar", title = "Aspect bar", frame = bar.frame, store = DBR.db.aspectBar,
        width = BUTTON_SIZE, height = BUTTON_SIZE, point = DEFAULT_POINT, sizes = DBR.WIDGET_SIZES,
    })
    -- The buttons cover the bar: a drag that starts on one moves it (Ctrl
    -- while locked, the toolkit's free move).
    for _, button in ipairs(bar.buttons) do
        bar.frame:AddDragHandle(button)
    end
    bar.ready = true
    for _, event in ipairs({"SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE",
        "PLAYER_UNGHOST", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED"}) do
        events:RegisterEvent(event)
    end
    events:RegisterUnitEvent("UNIT_AURA", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    DBR.RefreshAspectBar()
end

function DBR.InitializeAspectBar(class)
    bar.list = class and DBR.ASPECT_BAR[class]
    if not bar.list then
        return
    end
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- After a reload in combat, the secure buttons are made only after it.
    if InCombatLockdown() then
        bar.setupPending = true
        return
    end
    SetUp()
end

-- The bar's widget, for the settings page; nil for other classes.
function DBR.AspectBarWidget()
    return bar.ready and bar.frame or nil
end

-- /dbr debug: the bar's state, and aspect IDs the client does not know.
function DBR.ReportAspectBarDebug()
    if not bar.ready then
        return
    end
    local known, unknown = {}, {}
    for _, button in ipairs(bar.buttons) do
        if button.spell then
            known[#known + 1] = button.aspect.key
        end
        for _, id in ipairs(button.aspect.spells) do
            if not C_Spell.GetSpellName(id) then
                unknown[#unknown + 1] = id
            end
        end
    end
    DBR.Report(string.format("debug aspectBar on=%s vertical=%s known=%s active=%s shown=%s dirty=%s unknownIDs=%s",
        tostring(DBR.db.aspectBar.enabled), tostring(DBR.AspectBarVertical()),
        #known > 0 and table.concat(known, ",") or "none", tostring(bar.active), tostring(bar.frame:IsShown()),
        tostring(bar.dirty == true), #unknown > 0 and table.concat(unknown, ",") or "none"))
end
