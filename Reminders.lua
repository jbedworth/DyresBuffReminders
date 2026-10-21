local addonName, DBR = ...

-- Buff reminders (author-approved, from Mage Tools Forever and Warlock Tools
-- Forever, for any class): one icon per buff, shown while the buff is missing
-- or about to run out (author-approved: a few seconds before, a setting), with
-- a pulsing gold border that draws the eye.
--
-- The icons sit in two bars (author-approved, 1.1.0): "Group buffs" (buffs
-- that can go on another player) and "My buffs" (self-only buffs). Each bar is a Dyre's
-- Toolkit widget, so the toolkit places, drags, sizes, and saves it; DBR only
-- fills it. A bar is as wide as the icons this character can show (the buff
-- is known and switched on), and grows or shrinks from its left edge when
-- that changes, out of combat. Unlocked, every one of them shows (the buffs
-- that are on, dimmed), so the outline holds a real icon in every slot.
-- Locked, the missing ones pack in from the left edge, and the bar itself
-- takes no mouse, so its empty part is click-through. A bar with none to show
-- is hidden, also while unlocked.
--
-- Clicking an icon casts the missing buff: on you first, then the first group
-- member in range who lacks it, so each click moves down the list as the buff
-- lands; the group-wide version instead when two or more lack it, you know it,
-- and you carry its reagent. Buffs with several spells (armors) recast the
-- last one you used, else your best. The buff lists are in Buffs.lua.
--
-- Aura APIs refuse AddOn code in combat on Forever, so DBR checks only out of
-- combat. The icons are secure buttons, which change only out of combat, so
-- the game hides each bar for combat with a state driver: a reminder is for
-- between pulls. A buff that runs out in combat shows after.
--
-- "About to run out" needs the aura's expirationTime, read out of combat; a
-- one-shot timer refreshes the icons when the earliest buff reaches the lead
-- time (no polling). A buff without a readable time counts as on.

-- Every DBR widget's sizes: Size 50-200% (the range the loose icons had),
-- and Opacity.
DBR.WIDGET_SIZES = {scale = {min = 50, max = 200, step = 10, default = 100}, opacity = true}
-- Seconds before a buff runs out that its icon shows; 0 shows it as it falls.
DBR.LEAD_MIN = 0
DBR.LEAD_MAX = 30
DBR.DEFAULT_LEAD = 5

local ICON_SIZE = 40
-- Wide enough that two icons' pulsing borders never touch.
local ICON_GAP = 8
local BORDER = 3
local GOLD = {1, 0.82, 0}
local PULSE_SECONDS = 0.6
local PULSE_LOW_ALPHA = 0.15
-- In the order they are made; y is each bar's default place above the center.
local BARS = {
    {key = "groupbuffs", name = "DyresBuffRemindersGroupBuffs", title = "Group buffs", y = 180},
    {key = "mybuffs", name = "DyresBuffRemindersMyBuffs", title = "My buffs", y = 130},
}
local COMBAT_DRIVER = "[combat] hide; show"
local HIDDEN_DRIVER = "hide"
local COMBAT_ONLY_DRIVER = "[combat] show; hide"
-- Unlocked, a buff that is on shows this solid, so the missing ones stand out.
local DIM_ALPHA = 0.4
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

local reminders = {list = {}, icons = {}, names = {}, spellKeys = {}, spellNames = {}, bars = {}}

-- The bar a reminder sits in: Group buffs for any buff that can go on
-- another player (Buffs.lua's group or others), My buffs for self-only ones.
local function BarKey(reminder)
    return (reminder.group or reminder.others) and "groupbuffs" or "mybuffs"
end

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

-- The saved reminder settings for every class's buffs, repaired; Core calls
-- this from SanitizeDB. Keys no class has are dropped. Each bar's place and
-- sizes are the toolkit's to clamp; before 1.1.0 each icon had its own place
-- (db.icons), which no bar can take, so the bars start at their defaults.
function DBR.SanitizeReminders(db, sanitizePosition)
    local spells = type(db.spells) == "table" and db.spells or {}
    local groups = type(db.groups) == "table" and db.groups or {}
    local last = type(db.last) == "table" and db.last or {}
    local bars = type(db.bars) == "table" and db.bars or {}
    db.spells, db.groups, db.last, db.bars, db.icons = {}, {}, {}, {}, nil
    db.lead = DBR.SanitizeLead(db.lead)
    local aspect = type(db.combatAspect) == "table" and db.combatAspect or {}
    -- Its place, size, and opacity are My buffs' (a pre-release had its own).
    db.combatAspect = {enabled = aspect.enabled ~= false, soundOn = aspect.soundOn ~= false,
        sound = DBR.SanitizeChimeSound and DBR.SanitizeChimeSound(aspect.sound) or aspect.sound}
    for _, bar in ipairs(BARS) do
        local saved = type(bars[bar.key]) == "table" and bars[bar.key] or {}
        db.bars[bar.key] = {position = sanitizePosition(saved.position), scale = saved.scale,
            opacity = saved.opacity}
    end
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

-- Another group member who is alive, online, and in sight (out of sight, a
-- unit's buffs may not be known).
local function Reachable(unit)
    if not UnitExists(unit) or UnitIsUnit(unit, "player") then
        return false
    end
    local dead, connected = UnitIsDeadOrGhost(unit), UnitIsConnected(unit)
    if DBR.IsSecret(dead) or dead == true or DBR.IsSecret(connected) or connected == false then
        return false
    end
    local visible = UnitIsVisible(unit)
    return not DBR.IsSecret(visible) and visible ~= false
end

local function Usable(unit, reminder)
    if not Reachable(unit) then
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

local function IsTank(unit)
    local role = UnitGroupRolesAssigned(unit)
    return not DBR.IsSecret(role) and role == "TANK"
end

-- In range of the buff's spell; an unreadable (secret or missing) answer
-- counts as in range, as for the click.
local function SpellInRange(reminder, unit)
    if type(C_Spell.IsSpellInRange) ~= "function" then
        return true
    end
    local inRange = C_Spell.IsSpellInRange(reminder.spells[1], unit)
    return DBR.IsSecret(inRange) or inRange ~= false
end

-- A tank buff's unit (author): your group's tank, the first in group order
-- who is alive, online, in sight, and in range; else you (author: "Tank dead,
-- out of range, etc., watch me"): also when you are the tank, are not in a
-- group, the group has no tank, or without the role API. A secret role
-- counts as not a tank. Out of combat only, as every aura read.
local function Watched(reminder)
    if not reminder.tank or type(UnitGroupRolesAssigned) ~= "function" or IsTank("player") then
        return "player"
    end
    for _, unit in ipairs(GroupUnits()) do
        if Reachable(unit) and IsTank(unit) and SpellInRange(reminder, unit) then
            return unit
        end
    end
    return "player"
end

local function UnitLabel(unit)
    if unit == "player" then
        return "you"
    end
    local name = UnitName(unit)
    return (not DBR.IsSecret(name) and name) or unit
end

-- Who needs the buff, as {unit, name, soon}: you (or, for a tank buff, the
-- unit it watches) first, then group members. soon: still on, but about to
-- run out.
local function Missing(reminder)
    local missing = {}
    local watched = Watched(reminder)
    local state = BuffState(watched, reminder)
    if state ~= "on" then
        missing[#missing + 1] = {unit = watched, name = UnitLabel(watched), soon = state == "soon"}
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
    -- Only a spell that may be remembered: never a forgotten one (Cheetah).
    local last = DBR.db.last[reminder.key]
    if last and reminders.spellNames[last] == reminder.key then
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

-- The spell text for an action's macro line: a group version by name and
-- rank, since its rank decides the reagent.
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
-- the click runs "/cancelform" then the cast, as one macro. /use rather than
-- /cast (author: every character counts): /use tries an item of that name
-- first, then casts the spell (pinned SlashCommands.lua:378-388); no item is
-- known to share these buffs' names.
-- The picture is always the spell the click casts, the one the tooltip names
-- (author): the action's spell, else (unlocked, or nothing missing) the spell
-- a click would cast now, else your best rank. A name is drawn from your
-- highest known rank of it.
local function ClickTexture(reminder, action)
    local cast = action and action.cast or SingleSpell(reminder)
    if type(cast) == "number" then
        return C_Spell.GetSpellTexture(cast)
    end
    if cast then
        for index = #reminder.spells, 1, -1 do
            local id = reminder.spells[index]
            if Knows(id) and C_Spell.GetSpellName(id) == cast then
                return C_Spell.GetSpellTexture(id)
            end
        end
    end
    return BestTexture(reminder)
end

local function ApplyClick(icon, reminder, action)
    if action and reminder.cancelForm and InForm() then
        action.leavesForm = true
        icon.action = action
        icon:SetAttribute("type1", "macro")
        icon:SetAttribute("macrotext1", "/cancelform\n/use [@" .. action.unit .. "] " .. CastText(action))
        icon:SetAttribute("spell1", nil)
        icon:SetAttribute("unit1", nil)
        return
    end
    -- "/use !Name" (author): never toggles an aspect that is already up.
    -- /use hands the "!" name to CastSpellByName, as /cast does (pinned
    -- SlashCommands.lua:377-387).
    if action and reminder.bang then
        icon.action = action
        icon:SetAttribute("type1", "macro")
        icon:SetAttribute("macrotext1", "/use !" .. CastText(action))
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
    icon.wanted = shown == true
    icon:SetShown(shown)
    Pulse(icon, shown)
end

local function BarWidth(count)
    return math.max(count, 1) * ICON_SIZE + math.max(count - 1, 0) * ICON_GAP
end

-- Whether this character can show the reminder: known and switched on.
local function Countable(reminder)
    return DBR.db.enabled and DBR.db.spells[reminder.key] and Known(reminder) or false
end

-- Out of combat: the bar's size follows its countable icons (from its left
-- edge), it hides with none, and the icons shown pack in from the left, in
-- Buffs.lua's order.
local function Pack(bar)
    local count = 0
    for _, icon in ipairs(bar.icons) do
        if icon.countable then
            count = count + 1
        end
    end
    if bar.count ~= count then
        bar.count = count
        bar.frame:SetContentSize(BarWidth(count), ICON_SIZE, "LEFT")
    end
    local driver = count > 0 and COMBAT_DRIVER or HIDDEN_DRIVER
    if bar.driver ~= driver then
        bar.driver = driver
        RegisterStateDriver(bar.frame, "visibility", driver)
    end
    local slot = 0
    for _, icon in ipairs(bar.icons) do
        if icon.wanted then
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", bar.frame, "LEFT", slot * (ICON_SIZE + ICON_GAP), 0)
            slot = slot + 1
        end
    end
end

-- A secret or missing answer counts as not on a taxi.
local function OnTaxi()
    if type(UnitOnTaxi) ~= "function" then
        return false
    end
    local onTaxi = UnitOnTaxi("player")
    return not DBR.IsSecret(onTaxi) and onTaxi == true
end

function DBR.RefreshReminders()
    reminders.scheduled = false
    if not reminders.ready then
        return
    end
    -- Secure icons change only out of combat; their bars hide for combat.
    if InCombatLockdown() then
        reminders.dirty = true
        return
    end
    reminders.dirty = false
    local db = DBR.db
    local unlocked = not db.locked
    reminders.nextCheck = nil
    -- No reminders you cannot act on: dead, or on a flight path (author;
    -- pinned UnitDocumentation.lua:2570). Unlocked, the samples still show.
    local canCheck = db.enabled and UnitIsDeadOrGhost("player") ~= true and not OnTaxi()
    for _, reminder in ipairs(reminders.list) do
        local icon = reminders.icons[reminder.key]
        local countable = Countable(reminder)
        icon.countable = countable
        icon.missing, icon.soon = nil, nil
        icon.watching = reminder.tank and UnitLabel(Watched(reminder)) or nil
        icon.texture:SetAlpha(1)
        if unlocked then
            -- Dragging must not cast. A buff that is on shows dimmed, still.
            ApplyClick(icon, reminder, nil)
            local missing = countable and canCheck and #Missing(reminder) > 0
            ShowIcon(icon, countable, nil)
            Pulse(icon, missing)
            icon.texture:SetAlpha((missing or not canCheck) and 1 or DIM_ALPHA)
        elseif countable and canCheck then
            local missing = Missing(reminder)
            icon.missing, icon.soon = MissingNames(missing, false), MissingNames(missing, true)
            ApplyClick(icon, reminder, ClickAction(reminder, missing))
            ShowIcon(icon, #missing > 0, #missing)
        else
            ApplyClick(icon, reminder, nil)
            ShowIcon(icon, false)
        end
    end
    for _, reminder in ipairs(reminders.list) do
        local icon = reminders.icons[reminder.key]
        icon.texture:SetTexture(ClickTexture(reminder, icon.action))
    end
    for _, bar in ipairs(reminders.bars) do
        Pack(bar)
    end
    DBR.RefreshCombatAspect(canCheck)
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

local function ShowTooltip(icon)
    GameTooltip:SetOwner(icon, "ANCHOR_TOP")
    GameTooltip:SetText(icon.label, GOLD[1], GOLD[2], GOLD[3])
    if not DBR.db.locked then
        GameTooltip:AddLine("Drag to move this bar.", 1, 1, 1, true)
    else
        if icon.watching then
            GameTooltip:AddLine(icon.label .. ": on " .. icon.watching, 1, 1, 1, true)
        end
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

local function CreateIcon(reminder, bar, name, template)
    local icon = CreateFrame("Button", name or ("DyresBuffRemindersIcon_" .. reminder.key), bar,
        template or "SecureActionButtonTemplate")
    icon.key, icon.label = reminder.key, reminder.label
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:RegisterForClicks("AnyUp", "AnyDown")
    icon:SetAttribute("useOnKeyDown", false)
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
    icon:Hide()
    return icon
end

-- The armor you cast is what a click recasts.
-- The combat aspect button (author, a Hunter player: "I commonly forget and
-- end up fighting with Cheetah up by accident"). When combat starts with
-- Aspect of the Cheetah or the Pack up, it shows the combat aspect a click
-- casts (the Aspect reminder's: your last, else Hawk, else Monkey). AddOn code
-- cannot read auras or change secure frames in combat, so it is armed out of
-- combat only: while a travel aspect is up, its click is set and the game
-- shows it for combat ("[combat] show; hide"); otherwise "hide". A click
-- casts with "!" and hides it (a secure wrap may Hide in combat). Your own
-- combat-aspect cast from elsewhere dims it (alpha 0.4, no pulse), never to
-- 0: an invisible frame must not take clicks (MTF 0.3.2's bug); a stray
-- click casts with "!", which takes nothing down.
--
-- To the player it is the Aspect slot of My buffs (author: "this should
-- behave like 1 widget"): not a widget of its own, it sits on that slot (or
-- the bar's start edge when the Aspect reminder is off) with the bar's scale
-- and opacity, and has no sample of its own. It is anchored to the bar, not
-- its child: the bar's state driver hides the bar in combat, when this must
-- show. Anchors and scale change out of combat only; an anchor to a hidden
-- frame still places it.
local combat = {}

-- Out of combat: the travel aspect on you, by name, or nil. A secret aura
-- reads as none.
local function TravelUp(reminder)
    for _, id in ipairs(reminder.forget or {}) do
        local name = C_Spell.GetSpellName(id)
        if name then
            local aura = C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
            if not DBR.IsSecret(aura) and aura ~= nil then
                return name
            end
        end
    end
end

-- Out of combat: on the Aspect slot of My buffs, with its scale.
local function PlaceCombatAspect()
    local button, bar = combat.button, combat.bar
    if not button or not bar or InCombatLockdown() then
        return
    end
    local aspectIcon = reminders.icons[combat.reminder.key]
    local slot = 0
    if aspectIcon.countable then
        for _, icon in ipairs(bar.icons) do
            if icon == aspectIcon then
                break
            end
            if icon.countable then
                slot = slot + 1
            end
        end
    end
    button:SetScale(bar.frame:GetScale())
    button:ClearAllPoints()
    button:SetPoint("LEFT", bar.frame, "LEFT", slot * (ICON_SIZE + ICON_GAP), 0)
end

-- Out of combat only.
function DBR.RefreshCombatAspect(canCheck)
    local button = combat.button
    if not button then
        return
    end
    PlaceCombatAspect()
    local reminder = combat.reminder
    local saved = DBR.db.combatAspect
    -- Its own switch: it works with the Aspect reminder off too.
    local wanted = DBR.db.enabled and saved.enabled and Known(reminder)
    local unlocked = not DBR.db.locked
    local spell = SingleSpell(reminder)
    local travel = wanted and canCheck and not unlocked and spell and TravelUp(reminder) or nil
    combat.travel, combat.spell = travel, spell
    button.texture:SetTexture(ClickTexture(reminder, nil))
    button.texture:SetAlpha(1)
    Pulse(button, true)
    local macro = travel and ("/use !" .. spell) or nil
    button:SetAttribute("type1", macro and "macro" or nil)
    button:SetAttribute("macrotext1", macro)
    local driver = travel and COMBAT_ONLY_DRIVER or HIDDEN_DRIVER
    if combat.driver ~= driver then
        combat.driver = driver
        RegisterStateDriver(button, "visibility", driver)
    end
end

-- In combat: your own combat-aspect cast (readable then) dims the button.
local function CombatAspectCast(name)
    if combat.travel and name and reminders.spellNames[name] == combat.reminder.key then
        combat.button.texture:SetAlpha(DIM_ALPHA)
        Pulse(combat.button, false)
    end
end

-- Combat starts: the optional sound (Dyre's Sounds, its own switch and choice).
local function CombatStarts()
    local saved = DBR.db.combatAspect
    if not combat.travel or not saved.soundOn then
        return
    end
    local library = DBR.SoundLibrary()
    if library and not library.Play(saved.sound, combat.travel .. " is up") then
        library.Play(DBR.DEFAULT_CHIME_SOUND, combat.travel .. " is up")
    end
end

function DBR.PreviewCombatAspect()
    local library = DBR.SoundLibrary()
    if library then
        library.Play(DBR.db.combatAspect.sound, "Aspect of the Cheetah is up")
    end
end

local function CombatAspectTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText("Combat aspect", GOLD[1], GOLD[2], GOLD[3])
    if combat.travel then
        GameTooltip:AddLine(combat.travel .. " is up.", 1, 1, 1, true)
        GameTooltip:AddLine("Click: " .. combat.spell .. ".", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end

local function CreateCombatAspect(reminder)
    local button = CreateIcon(reminder, UIParent, "DyresBuffRemindersCombatAspect",
        "SecureActionButtonTemplate, SecureHandlerBaseTemplate")
    -- One click event per click (on release), so the wrap hides it after the cast.
    button:RegisterForClicks("AnyUp")
    button:SetScript("OnEnter", CombatAspectTooltip)
    SecureHandlerWrapScript(button, "OnClick", button, "return nil, true", "self:Hide()")
    combat.button, combat.reminder = button, reminder
    for _, bar in ipairs(reminders.bars) do
        if bar.key == BarKey(reminder) then
            combat.bar = bar
        end
    end
    if combat.bar then
        button:SetAlpha(combat.bar.frame:GetAlpha())
    end
    PlaceCombatAspect()
end

-- The combat aspect button, for the settings page (a Hunter's); nil without.
function DBR.CombatAspectWidget()
    return combat.button
end

-- By ID, else by name (a rank Forever renumbered); forgotten spells never.
local function RememberCast(spellID)
    if DBR.IsSecret(spellID) then
        return
    end
    local name = C_Spell.GetSpellName(spellID)
    local key = reminders.spellKeys[spellID] or (name and reminders.spellNames[name])
    if key then
        DBR.db.last[key] = name
        -- The click and its picture change with it (after combat, in combat).
        ScheduleRefresh()
    end
end

-- Only your own and your group's auras matter.
local function GroupUnit(unit)
    return type(unit) == "string" and (unit == "player" or unit:find("^party%d") ~= nil
        or unit:find("^raid%d") ~= nil)
end

local events = CreateFrame("Frame")
-- Events about one unit; only your own and your group's count.
local UNIT_EVENTS = {UNIT_AURA = true, UNIT_IN_RANGE_UPDATE = true, UNIT_CONNECTION = true}
-- For a tank buff (Thorns): the game says when a group member comes into or
-- leaves its party range (UNIT_IN_RANGE_UPDATE, pinned
-- UnitDocumentation.lua:4328; the group frames' range, not the spell's, so a
-- tank between the two is re-checked at the next event) or goes offline
-- (UNIT_CONNECTION). No polling: the family rule.
local TANK_EVENTS = {"UNIT_IN_RANGE_UPDATE", "UNIT_CONNECTION"}

-- A bar for the class's reminders that go in it, sized for all of them; nil
-- when none do. The toolkit owns its place, size, opacity, and mouse (the
-- default, "unlocked": the bar takes clicks only while unlocked, to drag).
local function CreateBar(spec)
    local list = {}
    for _, reminder in ipairs(reminders.list) do
        if BarKey(reminder) == spec.key then
            list[#list + 1] = reminder
        end
    end
    if #list == 0 then
        return nil
    end
    local frame = CreateFrame("Frame", spec.name, UIParent)
    local bar = {key = spec.key, frame = frame, icons = {}, count = 0}
    -- The combat aspect button follows its bar's size and opacity.
    local function OnLayout()
        if combat.bar == bar then
            PlaceCombatAspect()
        end
    end
    local function OnOpacity(_, alpha)
        if combat.bar == bar then
            combat.button:SetAlpha(alpha)
        end
    end
    for _, reminder in ipairs(list) do
        local icon = CreateIcon(reminder, frame)
        reminders.icons[reminder.key] = icon
        bar.icons[#bar.icons + 1] = icon
        if Countable(reminder) then
            bar.count = bar.count + 1
        end
    end
    -- Made at its size now, so it does not jump at the first refresh.
    DBR.toolkit.CreateWidget({
        addon = addonName, key = spec.key, title = spec.title, frame = frame, store = DBR.db.bars[spec.key],
        width = BarWidth(bar.count), height = ICON_SIZE,
        point = {point = "CENTER", relativePoint = "CENTER", x = 0, y = spec.y}, sizes = DBR.WIDGET_SIZES,
        onLayout = OnLayout, onOpacity = OnOpacity,
    })
    -- The icons cover the bar: a drag that starts on one moves it.
    for _, icon in ipairs(bar.icons) do
        frame:AddDragHandle(icon)
    end
    bar.driver = bar.count > 0 and COMBAT_DRIVER or HIDDEN_DRIVER
    RegisterStateDriver(frame, "visibility", bar.driver)
    return bar
end

-- The bars, the icons, and their events; out of combat only.
local function SetUp()
    for _, spec in ipairs(BARS) do
        reminders.bars[#reminders.bars + 1] = CreateBar(spec)
    end
    for _, reminder in ipairs(reminders.list) do
        -- Needs the secure wrap that hides it on a click; without it, no button.
        if reminder.combatAspect and type(SecureHandlerWrapScript) == "function" then
            CreateCombatAspect(reminder)
            events:RegisterEvent("PLAYER_REGEN_DISABLED")
        end
    end
    reminders.ready = true
    for _, event in ipairs({"UNIT_AURA", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
        "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "BAG_UPDATE_DELAYED",
        "UPDATE_SHAPESHIFT_FORM", "PLAYER_ROLES_ASSIGNED", "ROLE_CHANGED_INFORM",
        -- Taking off and landing on a flight path (pinned LossOfControlDocumentation.lua:133-139).
        "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED"}) do
        events:RegisterEvent(event)
    end
    for _, reminder in ipairs(reminders.list) do
        if reminder.tank then
            for _, event in ipairs(TANK_EVENTS) do
                events:RegisterEvent(event)
            end
        end
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    DBR.RefreshReminders()
end

events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        RememberCast(spellID)
        if combat.button and InCombatLockdown() and not DBR.IsSecret(spellID) then
            CombatAspectCast(C_Spell.GetSpellName(spellID))
        end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        CombatStarts()
        return
    end
    if UNIT_EVENTS[event] and (DBR.IsSecret(unit) or not GroupUnit(unit)) then
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
            local forget = {}
            for _, id in ipairs(reminder.forget or {}) do
                forget[id] = true
                local name = C_Spell.GetSpellName(id)
                if name then
                    forget[name] = true
                end
            end
            for _, id in ipairs(reminder.spells) do
                local name = C_Spell.GetSpellName(id)
                if not forget[id] and not (name and forget[name]) then
                    reminders.spellKeys[id] = reminder.key
                    if name then
                        reminders.spellNames[name] = reminder.key
                    end
                end
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

-- The bars' widgets, for the settings page: {key, widget}, in BARS order.
function DBR.ReminderBars()
    local list = {}
    for _, bar in ipairs(reminders.bars) do
        list[#list + 1] = {key = bar.key, widget = bar.frame}
    end
    return list
end

local function ReportCombatAspectDebug()
    if combat.button then
        DBR.Report(string.format("debug combatAspect on=%s armed=%s travel=%s macro=%s driver=%s sound=%s",
            tostring(DBR.db.combatAspect.enabled), tostring(combat.travel ~= nil), tostring(combat.travel),
            tostring(combat.button:GetAttribute("macrotext1")), tostring(combat.driver),
            DBR.db.combatAspect.soundOn and tostring(DBR.db.combatAspect.sound) or "off"))
    end
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
        DBR.Report(string.format("debug %s bar=%s on=%s group=%s known=%s shown=%s missing=%s click=%s "
            .. "unknownIDs=%s last=%s", reminder.key, BarKey(reminder), tostring(DBR.db.spells[reminder.key]), tostring(DBR.db.groups[reminder.key]),
            tostring(Known(reminder)), tostring(icon and icon:IsShown()), missing,
            action and (tostring(action.cast) .. "@" .. action.unit) or "none",
            #unknown > 0 and table.concat(unknown, ",") or "none", tostring(DBR.db.last[reminder.key])))
    end
    ReportCombatAspectDebug()
end
