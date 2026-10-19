local _, DBR = ...

-- Buff reminders (author-approved, from Mage Tools Forever and Warlock Tools
-- Forever, for any class): one icon per buff, shown while the buff is missing
-- or about to run out (author-approved: a few seconds before, a setting), with
-- a pulsing gold border that draws the eye. Each icon moves and
-- resizes on its own while frames are unlocked (drag to move, scroll to
-- resize), then locks with everything else. Icons are magnetic (Layout.lua).
--
-- Clicking an icon casts the missing buff: on you first, then the first group
-- member in range who lacks it, so each click moves down the list as the buff
-- lands; the group-wide version instead when two or more lack it, you know it,
-- and you carry its reagent. Buffs with several spells (armors) recast the
-- last one you used, else your best. The buff lists are in Buffs.lua.
--
-- Aura APIs refuse AddOn code in combat on Forever, so DBR checks only out of
-- combat. The icons are secure buttons, which change only out of combat, so
-- they sit in a holder the game hides for combat with a state driver: a
-- reminder is for between pulls. A buff that runs out in combat shows after.
--
-- "About to run out" needs the aura's expirationTime, read out of combat; a
-- one-shot timer refreshes the icons when the earliest buff reaches the lead
-- time (no polling). A buff without a readable time counts as on.

DBR.REMINDER_SCALE_MIN = 50
DBR.REMINDER_SCALE_MAX = 200
DBR.REMINDER_SCALE_STEP = 10
DBR.DEFAULT_REMINDER_SCALE = 100
-- Seconds before a buff runs out that its icon shows; 0 shows it as it falls.
DBR.LEAD_MIN = 0
DBR.LEAD_MAX = 30
DBR.DEFAULT_LEAD = 5

local ICON_SIZE = 40
-- The default row's gap, the snapped gap.
local ICON_GAP = 20
local BORDER = 3
local GOLD = {1, 0.82, 0}
local PULSE_SECONDS = 0.6
local PULSE_LOW_ALPHA = 0.15
local DEFAULT_Y = 180
local COMBAT_DRIVER = "[combat] hide; show"
-- Classes without mana need no mana buffs (Arcane Intellect, Divine Spirit).
local NO_MANA = {WARRIOR = true, ROGUE = true}
local MAX_PARTY = 4
local MAX_RAID = 40
local GROUP_SPELL_AT = 2
-- Aura changes come in bursts (a group buff lands on five people at once):
-- one refresh this long after the first covers each burst.
local REFRESH_DELAY = 0.2
-- A timer can fire a hair early; this much past the lead time still counts.
local TIMER_SLACK = 0.05

local reminders = {list = {}, icons = {}, names = {}, spellKeys = {}}
local holder

-- The reminders for your class, or an empty list.
function DBR.ClassReminders()
    return reminders.list
end

function DBR.SanitizeLead(value)
    if type(value) ~= "number" or value ~= math.floor(value) then
        return DBR.DEFAULT_LEAD
    end
    return math.max(DBR.LEAD_MIN, math.min(DBR.LEAD_MAX, value))
end

function DBR.SanitizeReminderScale(value)
    if type(value) ~= "number" or value ~= math.floor(value) then
        return DBR.DEFAULT_REMINDER_SCALE
    end
    local stepped = math.floor(value / DBR.REMINDER_SCALE_STEP + 0.5) * DBR.REMINDER_SCALE_STEP
    return math.max(DBR.REMINDER_SCALE_MIN, math.min(DBR.REMINDER_SCALE_MAX, stepped))
end

-- The saved reminder settings for every class's buffs, repaired; Core calls
-- this from SanitizeDB. Keys no class has are dropped.
function DBR.SanitizeReminders(db, sanitizePosition)
    local spells = type(db.spells) == "table" and db.spells or {}
    local groups = type(db.groups) == "table" and db.groups or {}
    local icons = type(db.icons) == "table" and db.icons or {}
    local last = type(db.last) == "table" and db.last or {}
    db.spells, db.groups, db.icons, db.last = {}, {}, {}, {}
    db.lead = DBR.SanitizeLead(db.lead)
    for _, list in pairs(DBR.BUFFS) do
        for _, reminder in ipairs(list) do
            local key = reminder.key
            if type(spells[key]) == "boolean" then
                db.spells[key] = spells[key]
            else
                db.spells[key] = reminder.on
            end
            if reminder.group then
                db.groups[key] = groups[key] ~= false
            end
            local icon = type(icons[key]) == "table" and icons[key] or {}
            db.icons[key] = {position = sanitizePosition(icon.position),
                scale = DBR.SanitizeReminderScale(icon.scale)}
            if reminder.prefer and type(last[key]) == "string" then
                db.last[key] = last[key]
            end
        end
    end
end

local function Knows(id)
    return C_SpellBook.IsSpellKnown(id) == true
end

local function Known(reminder)
    for _, id in ipairs(reminder.spells) do
        if Knows(id) then
            return true
        end
    end
    return false
end

local function BestTexture(reminder)
    for index = #reminder.spells, 1, -1 do
        local id = reminder.spells[index]
        if Knows(id) then
            return C_Spell.GetSpellTexture(id)
        end
    end
    return C_Spell.GetSpellTexture(reminder.spells[1])
end

-- Every name the buff can have on a unit: its ranks and its group versions.
local function BuffNames(reminder)
    local names, seen = {}, {}
    local function Add(id)
        local name = C_Spell.GetSpellName(id)
        if name and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    for _, id in ipairs(reminder.spells) do
        Add(id)
    end
    for _, entry in ipairs(reminder.group and reminder.group.spells or {}) do
        Add(entry.spell)
    end
    return names
end

-- Seconds the aura has left, or nil when it has no readable end (a secret,
-- or no duration).
local function TimeLeft(aura)
    local expires = aura.expirationTime
    if DBR.IsSecret(expires) or type(expires) ~= "number" or expires <= 0 then
        return nil
    end
    return expires - GetTime()
end

-- Out of combat only. "on", "soon" (runs out within the lead time), or
-- "missing". A secret answer counts as on: DBR cannot tell. A buff still on
-- notes when it reaches the lead time, for the refresh timer.
local function BuffState(unit, reminder)
    local lead = DBR.db.lead
    local found, longest = false, nil
    for _, name in ipairs(reminders.names[reminder.key]) do
        local aura = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL")
        if DBR.IsSecret(aura) then
            return "on"
        end
        if aura ~= nil then
            found = true
            local left = TimeLeft(aura)
            if not left then
                return "on"
            end
            longest = math.max(longest or left, left)
        end
    end
    if not found then
        return "missing"
    end
    if longest <= lead + TIMER_SLACK then
        return "soon"
    end
    local due = longest - lead
    if not reminders.nextCheck or due < reminders.nextCheck then
        reminders.nextCheck = due
    end
    return "on"
end

local function Usable(unit, reminder)
    if not UnitExists(unit) or UnitIsUnit(unit, "player") then
        return false
    end
    local dead, connected = UnitIsDeadOrGhost(unit), UnitIsConnected(unit)
    if DBR.IsSecret(dead) or dead == true or DBR.IsSecret(connected) or connected == false then
        return false
    end
    -- Out of sight, a unit's buffs may not be known.
    local visible = UnitIsVisible(unit)
    if DBR.IsSecret(visible) or visible == false then
        return false
    end
    if not reminder.group.mana then
        return true
    end
    local _, class = UnitClass(unit)
    return DBR.IsSecret(class) or not NO_MANA[class]
end

local function GroupUnits()
    local units = {}
    if IsInRaid() then
        for index = 1, MAX_RAID do
            units[#units + 1] = "raid" .. index
        end
    elseif IsInGroup() then
        for index = 1, MAX_PARTY do
            units[#units + 1] = "party" .. index
        end
    end
    return units
end

-- Who needs the buff, as {unit, name, soon}: you first, then group members.
-- soon: still on, but about to run out.
local function Missing(reminder)
    local missing = {}
    local state = BuffState("player", reminder)
    if state ~= "on" then
        missing[#missing + 1] = {unit = "player", name = "you", soon = state == "soon"}
    end
    if reminder.group and DBR.db.groups[reminder.key] then
        for _, unit in ipairs(GroupUnits()) do
            if Usable(unit, reminder) then
                state = BuffState(unit, reminder)
                if state ~= "on" then
                    local name = UnitName(unit)
                    missing[#missing + 1] = {unit = unit, name = (not DBR.IsSecret(name) and name) or unit,
                        soon = state == "soon"}
                end
            end
        end
    end
    return missing
end

-- Names of those who lack it (soon false) or whose buff runs out (soon true).
local function MissingNames(missing, soon)
    local names = {}
    for _, entry in ipairs(missing) do
        if soon == nil or entry.soon == soon then
            names[#names + 1] = entry.name
        end
    end
    return names
end

-- Click target -----------------------------------------------------------------

local function InRange(spell, unit)
    if unit == "player" or type(C_Spell.IsSpellInRange) ~= "function" then
        return true
    end
    local inRange = C_Spell.IsSpellInRange(spell, unit)
    return DBR.IsSecret(inRange) or inRange ~= false
end

local function Carries(item)
    if type(C_Item) ~= "table" or type(C_Item.GetItemCount) ~= "function" then
        return false
    end
    local count = C_Item.GetItemCount(item)
    return not DBR.IsSecret(count) and type(count) == "number" and count > 0
end

-- The spell a click casts on you or one member: for buffs with several
-- spells, the last one you cast, else your best known; else the buff's name,
-- which the client casts at your highest rank.
local function SingleSpell(reminder)
    if not reminder.prefer then
        return Known(reminder) and C_Spell.GetSpellName(reminder.spells[1]) or nil
    end
    local last = DBR.db.last[reminder.key]
    if last then
        for _, id in ipairs(reminder.spells) do
            if Knows(id) and C_Spell.GetSpellName(id) == last then
                return last
            end
        end
    end
    for _, id in ipairs(reminder.prefer) do
        if Knows(id) then
            return C_Spell.GetSpellName(id)
        end
    end
end

-- The best group version you know and carry the reagent for, as a spell ID:
-- each rank has its own reagent, so the click casts that rank by ID.
local function GroupSpell(reminder)
    local spells = reminder.group and reminder.group.spells or {}
    for index = #spells, 1, -1 do
        local entry = spells[index]
        if Knows(entry.spell) and Carries(entry.reagent) then
            return entry.spell
        end
    end
end

-- What a click does now: {cast, spell, unit, name, group}, or nil. cast is
-- what the button casts (a name, or a group version's ID), spell its name.
local function ClickAction(reminder, missing)
    if #missing == 0 then
        return nil
    end
    if #missing >= GROUP_SPELL_AT then
        local id = GroupSpell(reminder)
        local name = id and C_Spell.GetSpellName(id)
        if name then
            for _, entry in ipairs(missing) do
                if InRange(id, entry.unit) then
                    return {cast = id, spell = name, unit = entry.unit, name = "your group", group = true}
                end
            end
        end
    end
    local spell = SingleSpell(reminder)
    if not spell then
        return nil
    end
    for _, entry in ipairs(missing) do
        if InRange(spell, entry.unit) then
            return {cast = spell, spell = spell, unit = entry.unit, name = entry.name}
        end
    end
    return {cast = spell, spell = spell, unit = missing[1].unit, name = missing[1].name}
end

-- Whether you are shapeshifted (Bear, Cat, Travel, ...). A secret answer
-- counts as not: the click then casts plainly, as before.
local function InForm()
    if type(GetNumShapeshiftForms) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then
        return false
    end
    local count = GetNumShapeshiftForms()
    if DBR.IsSecret(count) or type(count) ~= "number" then
        return false
    end
    for index = 1, count do
        local _, active = GetShapeshiftFormInfo(index)
        if not DBR.IsSecret(active) and active == true then
            return true
        end
    end
    return false
end

-- The /cast text for an action: a group version by name and rank, since its
-- rank decides the reagent.
local function CastText(action)
    if type(action.cast) ~= "number" or type(C_Spell.GetSpellSubtext) ~= "function" then
        return action.spell
    end
    local rank = C_Spell.GetSpellSubtext(action.cast)
    if type(rank) == "string" and rank ~= "" and not DBR.IsSecret(rank) then
        return action.spell .. "(" .. rank .. ")"
    end
    return action.spell
end

-- Out of combat only. A Druid in a form (author-approved) leaves it first:
-- the click runs "/cancelform" then the cast, as one macro.
local function ApplyClick(icon, reminder, action)
    if action and reminder.cancelForm and InForm() then
        action.leavesForm = true
        icon.action = action
        icon:SetAttribute("type1", "macro")
        icon:SetAttribute("macrotext1", "/cancelform\n/cast [@" .. action.unit .. "] " .. CastText(action))
        icon:SetAttribute("spell1", nil)
        icon:SetAttribute("unit1", nil)
        return
    end
    icon.action = action
    icon:SetAttribute("type1", action and "spell" or nil)
    icon:SetAttribute("macrotext1", nil)
    icon:SetAttribute("spell1", action and action.cast or nil)
    icon:SetAttribute("unit1", action and action.unit or nil)
end

-- Display ----------------------------------------------------------------------

local function Pulse(icon, on)
    if on and not icon.pulse:IsPlaying() then
        icon.pulse:Play()
    elseif not on then
        icon.pulse:Stop()
    end
end

local function ShowIcon(icon, shown, count)
    icon.count:SetText(count and count > 1 and count or "")
    icon:SetShown(shown)
    Pulse(icon, shown)
end

function DBR.RefreshReminders()
    reminders.scheduled = false
    if not reminders.ready then
        return
    end
    -- Secure icons change only out of combat; the holder hides them for combat.
    if InCombatLockdown() then
        reminders.dirty = true
        return
    end
    reminders.dirty = false
    local db = DBR.db
    local unlocked = not db.locked
    reminders.nextCheck = nil
    local canCheck = db.enabled and UnitIsDeadOrGhost("player") ~= true
    for _, reminder in ipairs(reminders.list) do
        local icon = reminders.icons[reminder.key]
        icon:SetScale(db.icons[reminder.key].scale / 100)
        icon.texture:SetTexture(BestTexture(reminder))
        icon.mover:SetShown(unlocked)
        icon:EnableMouseWheel(unlocked)
        local wanted = db.enabled and db.spells[reminder.key]
        icon.missing, icon.soon = nil, nil
        if unlocked then
            -- Dragging must not cast.
            ApplyClick(icon, reminder, nil)
            ShowIcon(icon, wanted, nil)
        elseif wanted and canCheck and Known(reminder) then
            local missing = Missing(reminder)
            icon.missing, icon.soon = MissingNames(missing, false), MissingNames(missing, true)
            ApplyClick(icon, reminder, ClickAction(reminder, missing))
            ShowIcon(icon, #missing > 0, #missing)
        else
            ApplyClick(icon, reminder, nil)
            ShowIcon(icon, false)
        end
    end
    -- One timer for the next buff to reach the lead time; a newer refresh
    -- makes older timers do nothing.
    reminders.expiryToken = (reminders.expiryToken or 0) + 1
    if reminders.nextCheck then
        local token = reminders.expiryToken
        C_Timer.After(math.max(reminders.nextCheck, 0), function()
            if reminders.expiryToken == token then
                DBR.RefreshReminders()
            end
        end)
    end
end

local function ScheduleRefresh()
    if not reminders.scheduled then
        reminders.scheduled = true
        C_Timer.After(REFRESH_DELAY, DBR.RefreshReminders)
    end
end

local function DefaultPoint(index)
    local offset = (index - (#reminders.list + 1) / 2) * (ICON_SIZE + ICON_GAP)
    return {point = "CENTER", relativePoint = "CENTER", x = offset, y = DEFAULT_Y}
end

local function Place(icon, index)
    local position = DBR.db.icons[icon.key].position or DefaultPoint(index)
    icon:ClearAllPoints()
    icon:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

local function PlaceAll()
    for index, reminder in ipairs(reminders.list) do
        Place(reminders.icons[reminder.key], index)
    end
end

-- Returns false when the icons move after combat.
function DBR.ResetRemindersPosition()
    for _, reminder in ipairs(reminders.list) do
        local saved = DBR.db.icons[reminder.key]
        saved.position, saved.scale = nil, DBR.DEFAULT_REMINDER_SCALE
    end
    if not reminders.ready then
        return true
    end
    if InCombatLockdown() then
        reminders.placeDirty = true
        return false
    end
    PlaceAll()
    DBR.RefreshReminders()
    return true
end

-- Dragging and snapping: Layout.lua. The mouse wheel resizes in 10% steps,
-- keeping the icon's center.
local function Resize(icon, delta)
    if DBR.db.locked or InCombatLockdown() then
        return
    end
    local saved = DBR.db.icons[icon.key]
    local step = delta > 0 and DBR.REMINDER_SCALE_STEP or -DBR.REMINDER_SCALE_STEP
    saved.scale = DBR.SanitizeReminderScale(saved.scale + step)
    DBR.ScaleKeepingCenter(icon, saved.scale / 100)
end

local function ShowTooltip(icon)
    GameTooltip:SetOwner(icon, "ANCHOR_TOP")
    GameTooltip:SetText(icon.label, GOLD[1], GOLD[2], GOLD[3])
    if not DBR.db.locked then
        GameTooltip:AddLine("Drag to move; drop near another to snap; Shift-drag to move a snapped group; "
            .. "scroll to resize.", 1, 1, 1, true)
    else
        if icon.missing and #icon.missing > 0 then
            GameTooltip:AddLine("Missing: " .. table.concat(icon.missing, ", "), 1, 1, 1, true)
        end
        if icon.soon and #icon.soon > 0 then
            GameTooltip:AddLine("Running out: " .. table.concat(icon.soon, ", "), 1, 1, 1, true)
        end
        local action = icon.action
        if action then
            local whom = action.group and "" or (" on " .. action.name)
            local form = action.leavesForm and " (leaves your form first)" or ""
            GameTooltip:AddLine("Click: " .. action.spell .. whom .. form .. ".", 0.7, 0.7, 0.7, true)
        end
    end
    GameTooltip:Show()
end

local function CreateIcon(reminder)
    local icon = CreateFrame("Button", "DyresBuffRemindersIcon_" .. reminder.key, holder,
        "SecureActionButtonTemplate")
    icon.key, icon.label = reminder.key, reminder.label
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetMovable(true)
    icon:SetClampedToScreen(true)
    icon:RegisterForClicks("AnyUp", "AnyDown")
    icon:SetAttribute("useOnKeyDown", false)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", DBR.BeginDrag)
    icon:SetScript("OnDragStop", DBR.EndDrag)
    icon:SetScript("OnMouseWheel", Resize)
    icon:SetScript("OnEnter", ShowTooltip)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    icon.count:SetPoint("BOTTOMRIGHT", -2, 2)
    -- The attention border: a solid gold edge that pulses.
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
    icon.mover = DBR.CreateMover(icon)
    icon.mover.hint:SetText("")
    DBR.RegisterMovable(icon, function(position) DBR.db.icons[reminder.key].position = position end)
    icon:Hide()
    return icon
end

-- The armor (or Dampen/Amplify Magic) you cast is what a click recasts.
local function RememberCast(spellID)
    local key = not DBR.IsSecret(spellID) and reminders.spellKeys[spellID]
    if key then
        DBR.db.last[key] = C_Spell.GetSpellName(spellID)
    end
end

-- Only your own and your group's auras matter.
local function GroupUnit(unit)
    return type(unit) == "string" and (unit == "player" or unit:find("^party%d") ~= nil
        or unit:find("^raid%d") ~= nil)
end

local events = CreateFrame("Frame")

-- The holder, the icons, and their events; out of combat only.
local function SetUp()
    holder = CreateFrame("Frame", "DyresBuffRemindersHolder", UIParent)
    holder:SetAllPoints(UIParent)
    holder:EnableMouse(false)
    for _, reminder in ipairs(reminders.list) do
        reminders.icons[reminder.key] = CreateIcon(reminder)
    end
    PlaceAll()
    RegisterStateDriver(holder, "visibility", COMBAT_DRIVER)
    reminders.ready = true
    for _, event in ipairs({"UNIT_AURA", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
        "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "BAG_UPDATE_DELAYED",
        "UPDATE_SHAPESHIFT_FORM"}) do
        events:RegisterEvent(event)
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    DBR.RefreshReminders()
end

events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        RememberCast(spellID)
        return
    end
    if event == "UNIT_AURA" and (DBR.IsSecret(unit) or not GroupUnit(unit)) then
        return
    end
    if InCombatLockdown() then
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if reminders.setupPending then
            reminders.setupPending = false
            SetUp()
            return
        end
        if reminders.placeDirty then
            reminders.placeDirty = false
            PlaceAll()
        end
        DBR.RefreshReminders()
        return
    end
    ScheduleRefresh()
end)

function DBR.InitializeReminders(class)
    reminders.list = DBR.BUFFS[class] or {}
    for _, reminder in ipairs(reminders.list) do
        reminders.names[reminder.key] = BuffNames(reminder)
        if reminder.prefer then
            for _, id in ipairs(reminder.spells) do
                reminders.spellKeys[id] = reminder.key
            end
        end
    end
    if #reminders.list == 0 then
        return
    end
    -- After a reload in combat, secure icons can be set up only once combat ends.
    if InCombatLockdown() then
        reminders.setupPending = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    SetUp()
end

-- /dbr debug: each reminder, whether you know it, who lacks it, and the click.
-- IDs the client does not know (no name) are listed, to check Buffs.lua.
function DBR.ReportRemindersDebug()
    if #reminders.list == 0 then
        DBR.Report("debug: no buff reminders for this class.")
        return
    end
    for _, reminder in ipairs(reminders.list) do
        local icon = reminders.icons[reminder.key]
        local unknown = {}
        for _, id in ipairs(reminder.spells) do
            if not C_Spell.GetSpellName(id) then
                unknown[#unknown + 1] = id
            end
        end
        for _, entry in ipairs(reminder.group and reminder.group.spells or {}) do
            if not C_Spell.GetSpellName(entry.spell) then
                unknown[#unknown + 1] = entry.spell
            end
        end
        local missing = "not checked in combat"
        if not InCombatLockdown() then
            missing = table.concat(MissingNames(Missing(reminder)), ",")
        end
        local action = icon and icon.action
        DBR.Report(string.format("debug %s on=%s group=%s known=%s shown=%s missing=%s click=%s unknownIDs=%s",
            reminder.key, tostring(DBR.db.spells[reminder.key]), tostring(DBR.db.groups[reminder.key]),
            tostring(Known(reminder)), tostring(icon and icon:IsShown()), missing,
            action and (tostring(action.cast) .. "@" .. action.unit) or "none",
            #unknown > 0 and table.concat(unknown, ",") or "none"))
    end
end
