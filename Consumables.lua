local addonName, DBR = ...

-- Class consumables (author-approved, Part B), starting with ammo (author:
-- "an ammo consumable tracker for any ranged weapon equipped that takes
-- ammo"). Not by class: any character with a Bow, Crossbow, or Gun in the
-- ranged slot. Thrown weapons and wands take none.
--
-- The count is the equipped ammo slot's (GetInventoryItemCount on slot 0, the
-- total of that ammo across your bags). It and GetInventoryItemID are legacy
-- globals the generated docs do not list, so each is guarded: missing or
-- secret, the last readable count stays, and /dbr debug says so. The
-- Consumables bar is a plain frame with no secure parts, so it updates in
-- combat too. It is a Dyre's Toolkit widget, click-through while locked: the
-- icon then takes the mouse for its tooltip only. Unlocked, the icon is a
-- drag handle (found in client: it covers the bar, so the bar could not be
-- dragged), and a sample shows even without a ranged weapon, to place it.

DBR.AMMO_WARN_MIN, DBR.AMMO_WARN_MAX, DBR.AMMO_WARN_STEP = 0, 1000, 50
DBR.DEFAULT_AMMO_WARN = 200

local ICON_SIZE = 40
local BORDER = 3
local GOLD = {1, 0.82, 0}
local RED = {1, 0.2, 0.2}
local WHITE = {1, 1, 1}
local PULSE_SECONDS = 0.6
-- The count's font when its template gives none.
local COUNT_FONT = "Fonts\\ARIALN.TTF"
local COUNT_FONT_SIZE = 12
local PULSE_LOW_ALPHA = 0.15
local AMMO_SLOT = 0
local RANGED_SLOT = rawget(_G, "INVSLOT_RANGED") or 18
local BACKPACK, LAST_BAG = 0, rawget(_G, "NUM_BAG_SLOTS") or 4
-- Pinned ItemConstantsDocumentation.lua: Enum.ItemClass Weapon 2, Projectile
-- 6; Enum.ItemWeaponSubclass Bows 2, Guns 3, Crossbow 18 (Thrown 16 and
-- Wand 19 take no ammo).
local WEAPON_CLASS, PROJECTILE_CLASS = 2, 6
local AMMO_KINDS = {[2] = "arrow", [18] = "arrow", [3] = "bullet"}
-- Classic's projectile subclasses (the generated docs list none): Arrow 2, Bullet 3.
local PROJECTILE_KINDS = {[2] = "arrow", [3] = "bullet"}
local WORDS = {arrow = "arrows", bullet = "bullets"}
local DEFAULT_ICONS = {arrow = "Interface\\Icons\\INV_Ammo_Arrow_02",
    bullet = "Interface\\Icons\\INV_Ammo_Bullet_02"}
-- Beside My buffs' default place.
local DEFAULT_POINT = {point = "CENTER", relativePoint = "CENTER", x = 150, y = 130}

local ammo = {}

function DBR.SanitizeAmmoWarn(value)
    if type(value) ~= "number" or value ~= value then
        return DBR.DEFAULT_AMMO_WARN
    end
    local stepped = math.floor(value / DBR.AMMO_WARN_STEP + 0.5) * DBR.AMMO_WARN_STEP
    return math.max(DBR.AMMO_WARN_MIN, math.min(DBR.AMMO_WARN_MAX, stepped))
end

-- Core calls this from SanitizeDB; the toolkit clamps the sizes.
function DBR.SanitizeConsumables(saved, sanitizePosition)
    saved = type(saved) == "table" and saved or {}
    return {enabled = saved.enabled ~= false, ammo = saved.ammo ~= false,
        ammoWarn = DBR.SanitizeAmmoWarn(saved.ammoWarn), position = sanitizePosition(saved.position),
        scale = saved.scale, opacity = saved.opacity}
end

-- A readable, non-secret number, or nil.
local function Plain(value)
    if DBR.IsSecret(value) or type(value) ~= "number" then
        return nil
    end
    return value
end

local function ItemInfo(itemID)
    if not itemID or type(C_Item) ~= "table" or type(C_Item.GetItemInfoInstant) ~= "function" then
        return nil
    end
    local _, _, _, _, icon, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    return Plain(classID), Plain(subClassID), icon
end

local function InventoryItemID(slot)
    if type(GetInventoryItemID) ~= "function" then
        return nil
    end
    local itemID = GetInventoryItemID("player", slot)
    return Plain(itemID)
end

-- "arrow", "bullet", or nil: what the ranged weapon takes.
local function AmmoKind()
    local weapon = InventoryItemID(RANGED_SLOT)
    local classID, subClassID = ItemInfo(weapon)
    ammo.weapon = subClassID
    if classID ~= WEAPON_CLASS then
        return nil
    end
    return AMMO_KINDS[subClassID]
end

-- Ammo of that kind in your bags, for the "equip it" hint.
local function InBags(kind)
    if type(C_Container) ~= "table" or type(C_Container.GetContainerNumSlots) ~= "function"
            or type(C_Container.GetContainerItemID) ~= "function" then
        return false
    end
    for bag = BACKPACK, LAST_BAG do
        local slots = Plain(C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, slots do
            local classID, subClassID = ItemInfo(Plain(C_Container.GetContainerItemID(bag, slot)))
            if classID == PROJECTILE_CLASS and PROJECTILE_KINDS[subClassID] == kind then
                return true
            end
        end
    end
    return false
end

-- The equipped ammo's count; on a missing API or a secret answer, the last
-- readable one (nil before any).
local function ReadCount()
    if type(GetInventoryItemCount) ~= "function" then
        ammo.countState = "missing"
        return ammo.count
    end
    local count = GetInventoryItemCount("player", AMMO_SLOT)
    if DBR.IsSecret(count) then
        ammo.countState = "secret"
        return ammo.count
    end
    if type(count) ~= "number" then
        ammo.countState = "missing"
        return ammo.count
    end
    ammo.countState = "ok"
    ammo.count = count
    return count
end

local function Pulse(on)
    local pulse = ammo.icon.pulse
    if on and not pulse:IsPlaying() then
        pulse:Play()
    elseif not on then
        pulse:Stop()
    end
end

-- Also in combat: nothing here is secure.
function DBR.RefreshConsumables()
    if not ammo.frame then
        return
    end
    local saved = DBR.db.consumables
    local kind = saved.enabled and saved.ammo and AmmoKind() or nil
    ammo.kind = kind
    local icon = ammo.icon
    local unlocked = not DBR.db.locked
    if ammo.hover then
        icon:SetMouseClickEnabled(unlocked)
    end
    if not kind then
        ammo.state = nil
        if unlocked and saved.enabled and saved.ammo then
            icon.texture:SetTexture(DEFAULT_ICONS.arrow)
            icon.texture:SetDesaturated(false)
            icon.glow:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
            icon.count:SetText("")
            Pulse(false)
            ammo.frame:Show()
        else
            ammo.frame:Hide()
        end
        return
    end
    local itemID = InventoryItemID(AMMO_SLOT)
    ammo.itemID = itemID
    -- Nothing equipped counts as 0; an unreadable count (no API yet) stays nil, shown as "?".
    local count = 0
    if itemID then
        count = ReadCount()
    end
    local _, _, texture = ItemInfo(itemID)
    icon.texture:SetTexture(texture or DEFAULT_ICONS[kind])
    local state
    if not itemID then
        state = "missing"
        ammo.hint = InBags(kind) and ("Equip your " .. WORDS[kind] .. ".")
            or ("No " .. WORDS[kind] .. " in your bags.")
    elseif count and count <= 0 then
        state, ammo.hint = "missing", "Out of " .. WORDS[kind] .. "."
    elseif count and count <= saved.ammoWarn then
        state, ammo.hint = "low", "Running low."
    else
        state, ammo.hint = "ok", nil
    end
    ammo.state = state
    icon.count:SetText(count and tostring(count) or "?")
    local color = state == "ok" and WHITE or RED
    icon.count:SetTextColor(color[1], color[2], color[3])
    -- Low or missing: the border (the part that pulses) is red too (author).
    local border = state == "ok" and GOLD or RED
    icon.glow:SetBackdropBorderColor(border[1], border[2], border[3])
    icon.texture:SetDesaturated(state == "missing")
    Pulse(state ~= "ok")
    ammo.frame:Show()
end

local function ShowTooltip(icon)
    GameTooltip:SetOwner(icon, "ANCHOR_TOP")
    GameTooltip:SetText(ammo.kind == "bullet" and "Bullets" or "Arrows", GOLD[1], GOLD[2], GOLD[3])
    if not DBR.db.locked then
        GameTooltip:AddLine("Drag to move the Consumables bar.", 1, 1, 1, true)
    else
        if ammo.count then
            GameTooltip:AddLine(ammo.count .. " left; warns at " .. DBR.db.consumables.ammoWarn .. ".", 1, 1, 1,
                true)
        end
        if ammo.hint then
            GameTooltip:AddLine(ammo.hint, 1, 1, 1, true)
        end
    end
    GameTooltip:Show()
end

local function CreateIcon(frame)
    local icon = CreateFrame("Frame", "DyresBuffRemindersAmmo", frame)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    -- Hover for the tooltip, never clicks: the bar stays click-through.
    if type(icon.SetMouseClickEnabled) == "function" and type(icon.SetMouseMotionEnabled) == "function" then
        ammo.hover = true
        icon:SetMouseMotionEnabled(true)
        icon:SetMouseClickEnabled(false)
        icon:SetScript("OnEnter", ShowTooltip)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- Small and outlined, held inside the icon, so four digits (1600 arrows) fit inside the icon
    -- (author); it scales with the bar, so it fits at every Size.
    icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    local font = icon.count:GetFont()
    icon.count:SetFont(type(font) == "string" and font or COUNT_FONT, COUNT_FONT_SIZE, "THICKOUTLINE")
    -- A thick outline and a shadow, to read on light icons (author).
    icon.count:SetShadowColor(0, 0, 0, 1)
    icon.count:SetShadowOffset(1, -1)
    icon.count:SetPoint("BOTTOMLEFT", 1, 2)
    icon.count:SetPoint("BOTTOMRIGHT", -2, 2)
    icon.count:SetJustifyH("RIGHT")
    icon.count:SetWordWrap(false)
    local glow = CreateFrame("Frame", nil, icon, "BackdropTemplate")
    glow:SetPoint("TOPLEFT", -BORDER - 1, BORDER + 1)
    glow:SetPoint("BOTTOMRIGHT", BORDER + 1, -BORDER - 1)
    glow:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = BORDER})
    glow:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
    glow:EnableMouse(false)
    icon.glow = glow
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(PULSE_LOW_ALPHA)
    fade:SetDuration(PULSE_SECONDS)
    icon.pulse = pulse
    return icon
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function()
    DBR.RefreshConsumables()
end)

function DBR.InitializeConsumables()
    local frame = CreateFrame("Frame", "DyresBuffRemindersConsumables", UIParent)
    ammo.frame = frame
    ammo.icon = CreateIcon(frame)
    DBR.toolkit.CreateWidget({
        addon = addonName, key = "consumables", title = "Consumables", frame = frame,
        store = DBR.db.consumables, width = ICON_SIZE, height = ICON_SIZE, point = DEFAULT_POINT,
        sizes = DBR.WIDGET_SIZES,
    })
    -- The icon covers the bar: a drag that starts on it moves the bar.
    frame:AddDragHandle(ammo.icon)
    for _, event in ipairs({"BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD"}) do
        events:RegisterEvent(event)
    end
    events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    DBR.RefreshConsumables()
end

function DBR.ConsumablesWidget()
    return ammo.frame
end

-- /dbr debug: what John needs to confirm ammo on Forever in one line.
function DBR.ReportConsumablesDebug()
    local itemID = ammo.itemID
    local name = itemID and type(C_Item) == "table" and type(C_Item.GetItemNameByID) == "function"
        and C_Item.GetItemNameByID(itemID) or nil
    DBR.Report(string.format("debug ammo on=%s weapon=%s kind=%s ammoID=%s name=%s count=%s countAPI=%s "
        .. "warnAt=%s state=%s shown=%s",
        tostring(DBR.db.consumables.enabled and DBR.db.consumables.ammo), tostring(ammo.weapon),
        tostring(ammo.kind), tostring(itemID), DBR.Describe(name), tostring(ammo.count),
        tostring(ammo.countState), tostring(DBR.db.consumables.ammoWarn), tostring(ammo.state),
        tostring(ammo.frame and ammo.frame:IsShown())))
end
