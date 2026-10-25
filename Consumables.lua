local addonName, DBR = ...

-- Class consumables (author-approved, Part B): ammo (author: "an ammo
-- consumable tracker for any ranged weapon equipped that takes ammo") and,
-- 1.2.0, reagents (author: a Druid's Rebirth seed). The class picks the list
-- (DBR.CONSUMABLES, data as Buffs.lua; author: "only classes that could
-- equip a ranged weapon that requires ammo should see that"); a class with
-- none has no Consumables bar or settings. Ammo also needs a Bow, Crossbow,
-- or Gun in the ranged slot; thrown weapons and wands take none.
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

-- ammo: the class can equip a bow, gun, or crossbow (Classic: Hunter,
-- Warrior, Rogue). reagents: per spell, the item each rank uses (Classic
-- IDs; /dbr debug prints each one's names to confirm them on Forever), the
-- item's name for its tooltip before the client knows it, and Warn at's
-- range (author: Rebirth "default to 2, 0-10 range").
DBR.CONSUMABLES = {
    -- Author, 1.3.0: "mage Arcane Powder, add"; "Infernal Stones and Demonic
    -- Figurine add" (portal runes stay in Mage Tools Forever).
    MAGE = {reagents = {
        {key = "arcanePowder", label = "Arcane Brilliance", warn = {min = 0, max = 40, step = 1, default = 5},
            ranks = {{spell = 23028, item = 17020, name = "Arcane Powder"}}},
    }},
    WARLOCK = {reagents = {
        {key = "infernalStone", label = "Inferno", warn = {min = 0, max = 10, step = 1, default = 1},
            ranks = {{spell = 1122, item = 5565, name = "Infernal Stone"}}},
        {key = "demonicFigurine", label = "Ritual of Doom", warn = {min = 0, max = 10, step = 1, default = 1},
            ranks = {{spell = 18540, item = 16583, name = "Demonic Figurine"}}},
    }},
    HUNTER = {ammo = true},
    WARRIOR = {ammo = true},
    ROGUE = {ammo = true},
    DRUID = {reagents = {
        {key = "rebirth", label = "Rebirth", warn = {min = 0, max = 10, step = 1, default = 2},
            ranks = {{spell = 20484, item = 17034, name = "Maple Seed"},
                {spell = 20739, item = 17035, name = "Stranglethorn Seed"},
                {spell = 20742, item = 17036, name = "Ashwood Seed"},
                {spell = 20747, item = 17037, name = "Hornbeam Seed"},
                {spell = 20748, item = 17038, name = "Ironwood Seed"}}},
        -- Not on Forever before launch (author): it shows once a rank is known.
        {key = "giftOfTheWild", label = "Gift of the Wild", warn = {min = 0, max = 40, step = 1, default = 5},
            ranks = {{spell = 21849, item = 17021, name = "Wild Berries"},
                {spell = 21850, item = 17026, name = "Wild Thornroot"}}},
    }},
}

local ICON_SIZE = 40
-- Between the bar's icons: their borders stand 4 outside each.
local ICON_GAP = 10
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

local ammo = {icons = {}, reagents = {}}

function DBR.SanitizeAmmoWarn(value)
    if type(value) ~= "number" or value ~= value then
        return DBR.DEFAULT_AMMO_WARN
    end
    local stepped = math.floor(value / DBR.AMMO_WARN_STEP + 0.5) * DBR.AMMO_WARN_STEP
    return math.max(DBR.AMMO_WARN_MIN, math.min(DBR.AMMO_WARN_MAX, stepped))
end

-- A reagent's Warn at, stepped and clamped; else its default.
function DBR.SanitizeReagentWarn(reagent, value)
    local range = reagent.warn
    if type(value) ~= "number" or value ~= value then
        return range.default
    end
    local stepped = range.min + math.floor((value - range.min) / range.step + 0.5) * range.step
    return math.max(range.min, math.min(range.max, stepped))
end

-- Core calls this from SanitizeDB; the toolkit clamps the sizes. Every
-- class's reagents keep a setting, as the buffs do.
function DBR.SanitizeConsumables(saved, sanitizePosition)
    saved = type(saved) == "table" and saved or {}
    local old = type(saved.reagents) == "table" and saved.reagents or {}
    local reagents = {}
    for _, list in pairs(DBR.CONSUMABLES) do
        for _, reagent in ipairs(list.reagents or {}) do
            local entry = type(old[reagent.key]) == "table" and old[reagent.key] or {}
            reagents[reagent.key] = {on = entry.on ~= false, warn = DBR.SanitizeReagentWarn(reagent, entry.warn)}
        end
    end
    return {enabled = saved.enabled ~= false, ammo = saved.ammo ~= false,
        ammoWarn = DBR.SanitizeAmmoWarn(saved.ammoWarn), reagents = reagents,
        position = sanitizePosition(saved.position), scale = saved.scale, opacity = saved.opacity}
end

-- Your class's consumables, or nil.
function DBR.ClassConsumables()
    return ammo.list
end

-- The highest rank of the reagent's spell you know, and its number; or nil.
function DBR.ReagentRank(reagent)
    for index = #reagent.ranks, 1, -1 do
        local rank = reagent.ranks[index]
        if C_SpellBook.IsSpellKnown(rank.spell) == true then
            return rank, index
        end
    end
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

local function Pulse(icon, on)
    local pulse = icon.pulse
    if on and not pulse:IsPlaying() then
        pulse:Play()
    elseif not on then
        pulse:Stop()
    end
end

-- Count and border, as ammo (author): white and gold while fine; red and
-- pulsing at or below Warn at; greyed, red, and pulsing at 0.
local function ShowCount(icon, state, count)
    icon.count:SetText(count and tostring(count) or "?")
    local color = state == "ok" and WHITE or RED
    icon.count:SetTextColor(color[1], color[2], color[3])
    local border = state == "ok" and GOLD or RED
    icon.glow:SetBackdropBorderColor(border[1], border[2], border[3])
    icon.texture:SetDesaturated(state == "missing")
    Pulse(icon, state ~= "ok")
end

-- Whether the ammo icon shows.
local function RefreshAmmo()
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
            Pulse(icon, false)
            return true
        end
        return false
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
    -- Low or missing: the border (the part that pulses) is red too (author).
    ShowCount(icon, state, count)
    return true
end

-- Whether a reagent's icon shows: with a rank of its spell known (author:
-- nothing without Rebirth), the item that rank uses and how many you carry.
-- A missing or secret count keeps the last readable one for that item.
local function RefreshReagent(entry)
    local saved = DBR.db.consumables
    local reagent, icon = entry.reagent, entry.icon
    local wanted = saved.enabled and saved.reagents[reagent.key].on
    local rank, index
    if wanted then
        rank, index = DBR.ReagentRank(reagent)
    end
    entry.rank, entry.rankIndex = rank, index
    if ammo.hover then
        icon:SetMouseClickEnabled(not DBR.db.locked)
    end
    if not rank then
        entry.state = nil
        return false
    end
    if entry.item ~= rank.item then
        entry.item, entry.count = rank.item, nil
    end
    local count = type(C_Item) == "table" and type(C_Item.GetItemCount) == "function"
        and C_Item.GetItemCount(rank.item) or nil
    if DBR.IsSecret(count) then
        entry.countState = "secret"
    elseif type(count) ~= "number" then
        entry.countState = "missing"
    else
        entry.countState, entry.count = "ok", count
    end
    count = entry.count
    local _, _, texture = ItemInfo(rank.item)
    icon.texture:SetTexture(texture or C_Spell.GetSpellTexture(rank.spell))
    local state = "ok"
    if count and count <= 0 then
        state = "missing"
    elseif count and count <= saved.reagents[reagent.key].warn then
        state = "low"
    end
    entry.state = state
    ShowCount(icon, state, count)
    return true
end

-- The shown icons side by side from the bar's left edge; the bar as wide as
-- they are (the toolkit's SetContentSize keeps its left edge), hidden with none.
local function Layout(shown)
    local frame = ammo.frame
    for _, icon in ipairs(ammo.icons) do
        icon:Hide()
    end
    for index, icon in ipairs(shown) do
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", frame, "LEFT", (index - 1) * (ICON_SIZE + ICON_GAP), 0)
        icon:Show()
    end
    if #shown > 0 and type(frame.SetContentSize) == "function" then
        frame:SetContentSize(#shown * ICON_SIZE + (#shown - 1) * ICON_GAP, ICON_SIZE, "LEFT")
    end
    frame:SetShown(#shown > 0)
end

-- Also in combat: nothing here is secure.
function DBR.RefreshConsumables()
    if not ammo.frame then
        return
    end
    local shown = {}
    if ammo.icon and RefreshAmmo() then
        shown[#shown + 1] = ammo.icon
    end
    for _, entry in ipairs(ammo.reagents) do
        if RefreshReagent(entry) then
            shown[#shown + 1] = entry.icon
        end
    end
    Layout(shown)
end

local function ItemName(rank)
    local name = type(C_Item) == "table" and type(C_Item.GetItemNameByID) == "function"
        and C_Item.GetItemNameByID(rank.item) or nil
    return (type(name) == "string" and not DBR.IsSecret(name)) and name or rank.name
end

local function ShowReagentTooltip(icon)
    local entry = icon.entry
    local rank = entry.rank
    GameTooltip:SetOwner(icon, "ANCHOR_TOP")
    GameTooltip:SetText(rank and ItemName(rank) or entry.reagent.label, GOLD[1], GOLD[2], GOLD[3])
    if not DBR.db.locked then
        GameTooltip:AddLine("Drag to move the Consumables bar.", 1, 1, 1, true)
    elseif rank then
        local warn = DBR.db.consumables.reagents[entry.reagent.key].warn
        if entry.count then
            GameTooltip:AddLine(entry.count .. " left; warns at " .. warn .. ".", 1, 1, 1, true)
        end
        GameTooltip:AddLine("For " .. entry.reagent.label .. " (Rank " .. entry.rankIndex .. ").", 1, 1, 1, true)
    end
    GameTooltip:Show()
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

local function CreateIcon(frame, name, onEnter)
    local icon = CreateFrame("Frame", name, frame)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    -- Hover for the tooltip, never clicks: the bar stays click-through.
    if type(icon.SetMouseClickEnabled) == "function" and type(icon.SetMouseMotionEnabled) == "function" then
        ammo.hover = true
        icon:SetMouseMotionEnabled(true)
        icon:SetMouseClickEnabled(false)
        icon:SetScript("OnEnter", onEnter)
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

function DBR.InitializeConsumables(class)
    local list = class and DBR.CONSUMABLES[class]
    ammo.list = list
    if not list then
        return
    end
    local frame = CreateFrame("Frame", "DyresBuffRemindersConsumables", UIParent)
    ammo.frame = frame
    if list.ammo then
        ammo.icon = CreateIcon(frame, "DyresBuffRemindersAmmo", ShowTooltip)
        ammo.icons[#ammo.icons + 1] = ammo.icon
    end
    for _, reagent in ipairs(list.reagents or {}) do
        local icon = CreateIcon(frame, "DyresBuffRemindersReagent_" .. reagent.key, ShowReagentTooltip)
        local entry = {reagent = reagent, icon = icon}
        icon.entry = entry
        ammo.reagents[#ammo.reagents + 1] = entry
        ammo.icons[#ammo.icons + 1] = icon
    end
    DBR.toolkit.CreateWidget({
        addon = addonName, key = "consumables", title = "Consumables", frame = frame,
        store = DBR.db.consumables, width = ICON_SIZE, height = ICON_SIZE, point = DEFAULT_POINT,
        sizes = DBR.WIDGET_SIZES,
    })
    -- The icons cover the bar: a drag that starts on one moves the bar.
    -- Locked they let clicks through, so the bar itself takes a Ctrl-drag.
    for _, icon in ipairs(ammo.icons) do
        frame:AddDragHandle(icon)
    end
    DBR.AddCtrlMove(frame)
    -- SPELLS_CHANGED: a new rank of a reagent's spell uses another item.
    for _, event in ipairs({"BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD",
        "SPELLS_CHANGED"}) do
        events:RegisterEvent(event)
    end
    events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    DBR.RefreshConsumables()
end

function DBR.ConsumablesWidget()
    return ammo.frame
end

-- /dbr debug asks the client for items it has not loaded yet (found in
-- client: an unseen seed's name is nil, not a wrong ID); the answer
-- (ITEM_DATA_LOAD_RESULT, pinned ItemDocumentation.lua) prints its name, or
-- that no such item exists.
local loading = {pending = {}}

local function CachedName(item)
    local name = type(C_Item) == "table" and type(C_Item.GetItemNameByID) == "function"
        and C_Item.GetItemNameByID(item) or nil
    return (type(name) == "string" and not DBR.IsSecret(name)) and name or nil
end

local function LoadName(item)
    if type(C_Item) ~= "table" or type(C_Item.RequestLoadItemDataByID) ~= "function" then
        return "(not cached)"
    end
    if not loading.frame then
        loading.frame = CreateFrame("Frame")
        loading.frame:SetScript("OnEvent", function(_, _, itemID, success)
            if DBR.IsSecret(itemID) or not loading.pending[itemID] then
                return
            end
            loading.pending[itemID] = nil
            if success == true then
                DBR.Report(string.format("debug reagent item=%d itemName=%s (loaded)", itemID,
                    DBR.Describe(CachedName(itemID))))
            else
                DBR.Report(string.format("debug reagent item=%d not found: the ID is wrong on this client", itemID))
            end
            if next(loading.pending) == nil then
                loading.frame:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
            end
        end)
    end
    loading.pending[item] = true
    loading.frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    C_Item.RequestLoadItemDataByID(item)
    return "(not cached, loading)"
end

-- /dbr debug, a reagent's lines: each rank's spell and item, with the
-- names the client gives, so one run confirms the IDs on Forever.
local function ReportReagent(entry)
    local reagent = entry.reagent
    for index, rank in ipairs(reagent.ranks) do
        local spellName = C_Spell.GetSpellName(rank.spell)
        local itemName = CachedName(rank.item) or LoadName(rank.item)
        local count = type(C_Item) == "table" and type(C_Item.GetItemCount) == "function"
            and C_Item.GetItemCount(rank.item) or nil
        DBR.Report(string.format("debug reagent %s r%d spell=%d spellName=%s known=%s item=%d itemName=%s count=%s",
            reagent.key, index, rank.spell, DBR.Describe(spellName),
            tostring(C_SpellBook.IsSpellKnown(rank.spell) == true), rank.item, DBR.Describe(itemName),
            DBR.Describe(count)))
    end
    local saved = DBR.db.consumables.reagents[reagent.key]
    if not entry.rankIndex then
        DBR.Report(string.format("debug reagent %s on=%s rank=not known warnAt=%s", reagent.key,
            tostring(saved.on), tostring(saved.warn)))
        return
    end
    DBR.Report(string.format("debug reagent %s on=%s rank=%s count=%s countAPI=%s warnAt=%s state=%s",
        reagent.key, tostring(DBR.db.consumables.reagents[reagent.key].on), tostring(entry.rankIndex),
        tostring(entry.count), tostring(entry.countState), tostring(DBR.db.consumables.reagents[reagent.key].warn),
        tostring(entry.state)))
end

-- /dbr debug: what John needs to confirm ammo on Forever in one line.
function DBR.ReportConsumablesDebug()
    if not ammo.list then
        DBR.Report("debug consumables none for this class")
        return
    end
    for _, entry in ipairs(ammo.reagents) do
        ReportReagent(entry)
    end
    if not ammo.icon then
        return
    end
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
