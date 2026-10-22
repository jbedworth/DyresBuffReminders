local addonName, DBR = ...

-- Buff reminders (author-approved, from Mage Tools Forever and Warlock Tools
-- Forever, for any class): one icon per buff, shown while the buff is missing
-- or about to run out (author-approved: a few seconds before, a setting), with
-- a pulsing gold border that draws the eye.
--
-- Each buff is its own Dyre's Toolkit widget (author, 1.2.0: "move all
-- tracked buffs to widgets", like the seal timer), in a fixed place that
-- never moves on its own: the toolkit places, drags, sizes, and saves it.
-- 1.1.0's two bars are gone; their places seed the icons' places once. A
-- buff you do not know or have switched off shows no widget. Unlocked, every
-- one shows (the buffs that are on, dimmed).
--
-- Each widget shows all the time, in and out of combat (author: "If it's
-- always there, it might not be as jarring"). While the buff is up on you,
-- Blizzard's AuraContainer draws it there (its icon and time left), the same
-- in and out of combat. Under it sits our icon, armed to recast it on you:
-- when the buff expires, is dispelled, or is cancelled, the engine hides its
-- slot and our pulsing icon shows through, also in combat. Out of combat,
-- while anyone lacks the buff or yours is running out, our icon is raised
-- above the slot, with its smart click (group members, the tank, the group
-- version) and countdown; that state stays through a fight. AddOn code can
-- read none of this in combat (found in client: these auras are secret
-- then), so only the engine's slot tells you in combat.
--
-- Clicking an icon casts the missing buff: on you first, then the first group
-- member in range who lacks it, so each click moves down the list as the buff
-- lands; the group-wide version instead when two or more lack it, you know it,
-- and you carry its reagent. Buffs with several spells (armors) recast the
-- last one you used, else your best. The buff lists are in Buffs.lua.
--
-- Aura APIs refuse AddOn code in combat on Forever, so DBR checks only out of
-- combat. The icons are secure buttons, which change only out of combat, so
-- each icon's state driver and level are set out of combat: shown while
-- the buff is known and switched on, hidden when off, dead, or on a taxi.
-- Without the aura container, an up buff's icon hides, as before 1.2.0.
--
-- "About to run out" needs the aura's expirationTime, read out of combat; a
-- one-shot timer refreshes the icons when the earliest buff reaches the lead
-- time (no polling). A buff without a readable time counts as on. The lead
-- is a share of the buff's own length (author: "a 0-60 second reminder might
-- need a bigger window" for a 30-60 minute buff), except a buff with its own
-- lead in seconds (Buffs.lua's lead: Battle Shout).
--
-- The border tells the state (author): red while the buff is missing (gone,
-- dispelled, or cancelled), yellow and flashing while it runs out, none
-- while it is up. The red one is on our icon, under the aura slot, so it
-- shows the moment the slot goes, also in combat; the yellow one is a plain
-- frame above the slot, timed from the known end and your own casts.

-- Every DBR widget's sizes: Size 50-200% (the range the loose icons had),
-- and Opacity.
DBR.WIDGET_SIZES = {scale = {min = 50, max = 200, step = 10, default = 100}, opacity = true}
-- The share of a buff's length, in percent, before it runs out that its
-- icon warns (author: 0-20%, default 10%); 0 warns only once it is gone.
DBR.LEAD_MIN = 0
DBR.LEAD_MAX = 20
DBR.DEFAULT_LEAD = 10

local ICON_SIZE = 40
-- The default row's spacing: the toolkit's snap gap, so the default row is snapped.
local ICON_SPACING = 20
local BORDER = 3
local GOLD = {1, 0.82, 0}
local RED = {1, 0.2, 0.2}
local YELLOW = {1, 1, 0}
local PULSE_SECONDS = 0.6
local PULSE_LOW_ALPHA = 0.15
-- The default rows, where 1.1.0's bars were: buffs that can go on another
-- player above, self-only buffs below; y is above the screen's center.
local ROWS = {
    {key = "groupbuffs", y = 180},
    {key = "mybuffs", y = 130},
}
local HIDDEN_DRIVER = "hide"
local SHOWN_DRIVER = "show"
local COMBAT_ONLY_DRIVER = "[combat] show; hide"
local CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
-- The aura slot sits above the icon, so a buff that is up covers it.
local SLOT_LEVELS_ABOVE = 5
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

local reminders = {list = {}, icons = {}, names = {}, spellKeys = {}, spellNames = {}, widgets = {},
    seen = {}, windows = {}, warns = {}, timed = {}, casts = {}}

-- The default row a reminder starts in: the upper for any buff that can go on
-- another player (Buffs.lua's group or others), the lower for self-only ones.
local function BarKey(reminder)
    return (reminder.group or reminder.others) and "groupbuffs" or "mybuffs"
end

-- The reminders for your class, or an empty list.
function DBR.ClassReminders()
    return reminders.list
end

-- A buff's own lead time (Buffs.lua's lead), stepped and clamped; else its default.
function DBR.SanitizeBuffLead(reminder, value)
    local range = reminder.lead
    if type(value) ~= "number" or value ~= value then
        return range.default
    end
    local stepped = range.min + math.floor((value - range.min) / range.step + 0.5) * range.step
    return math.max(range.min, math.min(range.max, stepped))
end

-- The seconds before this buff runs out that it warns: its own setting in
-- seconds (Battle Shout), else the shared share of its length (duration,
-- from the aura read; else Buffs.lua's duration). With no length known, it
-- warns at once (math.huge): better early than never.
local function LeadSeconds(reminder, duration)
    if reminder.lead then
        return DBR.db.leads[reminder.key]
    end
    local percent = DBR.db.leadPercent
    if percent == 0 then
        return 0
    end
    duration = duration or reminder.duration
    if not duration then
        return math.huge
    end
    return duration * percent / 100
end

-- The shared lead, a whole percent; anything else (1.1.0's seconds were
-- saved as db.lead, which is dropped) is the default.
function DBR.SanitizeLead(value)
    if type(value) ~= "number" or value ~= math.floor(value) then
        return DBR.DEFAULT_LEAD
    end
    return math.max(DBR.LEAD_MIN, math.min(DBR.LEAD_MAX, value))
end

-- Mage Tools Forever's and Warlock Tools Forever's reminder settings, read
-- once on DBR's first run on this character (author, 1.3.0), never written.
-- Their keys, mapped to DBR's; their places are not taken (author: "start
-- fresh").
local IMPORTS = {
    MAGE = {db = "MageToolsForeverDB", title = "Mage Tools Forever", group = "arcaneIntellect",
        spells = {intellect = "arcaneIntellect", armor = "mageArmor", dampen = "dampen"},
        last = {armor = "mageArmor", dampen = "dampen"}},
    WARLOCK = {db = "WarlockToolsForeverDB", title = "Warlock Tools Forever",
        spells = {armor = "demonArmor"}, last = {armor = "demonArmor"}},
}

function DBR.ImportReminders(classFile)
    local import = classFile and IMPORTS[classFile]
    local saved = import and rawget(_G, import.db)
    local theirs = type(saved) == "table" and saved.reminders
    if type(theirs) ~= "table" then
        return false
    end
    local db = DBR.db
    if type(theirs.enabled) == "boolean" then
        db.enabled = theirs.enabled
    end
    if import.group and type(theirs.group) == "boolean" then
        db.groups[import.group] = theirs.group
    end
    local spells = type(theirs.spells) == "table" and theirs.spells or {}
    for from, to in pairs(import.spells) do
        if type(spells[from]) == "boolean" then
            db.spells[to] = spells[from]
        end
    end
    local last = type(theirs.last) == "table" and theirs.last or {}
    for from, to in pairs(import.last) do
        if type(last[from]) == "string" then
            db.last[to] = last[from]
        end
    end
    DBR.Report("Copied your buff reminder settings from " .. import.title .. ".")
    return true
end

-- The saved reminder settings for every class's buffs, repaired; Core calls
-- this from SanitizeDB. Keys no class has are dropped. Each buff widget has
-- its own table, db.buffs[key] (the coordinator: each widget its own store),
-- whose place and sizes the toolkit clamps. 1.1.0's bars (db.bars) are kept
-- only until their places seed the buff widgets, once.
function DBR.SanitizeReminders(db, sanitizePosition)
    local spells = type(db.spells) == "table" and db.spells or {}
    local groups = type(db.groups) == "table" and db.groups or {}
    local last = type(db.last) == "table" and db.last or {}
    local bars = type(db.bars) == "table" and db.bars or {}
    local buffs = type(db.buffs) == "table" and db.buffs or {}
    db.spells, db.groups, db.last, db.buffs, db.icons = {}, {}, {}, {}, nil
    db.bars = nil
    for _, row in ipairs(ROWS) do
        local saved = type(bars[row.key]) == "table" and bars[row.key] or nil
        local position = saved and sanitizePosition(saved.position)
        if position then
            db.bars = db.bars or {}
            db.bars[row.key] = {position = position, scale = saved.scale}
        end
    end
    -- 1.1.0's lead was seconds (db.lead): the percent starts at its default.
    db.leadPercent = DBR.SanitizeLead(db.leadPercent)
    db.lead = nil
    local leads = type(db.leads) == "table" and db.leads or {}
    db.leads = {}
    local alwaysShow = type(db.alwaysShow) == "table" and db.alwaysShow or {}
    db.alwaysShow = {}
    local aspect = type(db.combatAspect) == "table" and db.combatAspect or {}
    -- Its place, size, and opacity are My buffs' (a pre-release had its own).
    db.combatAspect = {enabled = aspect.enabled ~= false, soundOn = aspect.soundOn ~= false,
        sound = DBR.SanitizeChimeSound and DBR.SanitizeChimeSound(aspect.sound) or aspect.sound}
    for _, list in pairs(DBR.BUFFS) do
        for _, reminder in ipairs(list) do
            local key = reminder.key
            local widget = type(buffs[key]) == "table" and buffs[key] or {}
            db.buffs[key] = {position = sanitizePosition(widget.position), scale = widget.scale,
                opacity = widget.opacity}
            if type(spells[key]) == "boolean" then
                db.spells[key] = spells[key]
            else
                db.spells[key] = reminder.on
            end
            if reminder.group then
                db.groups[key] = groups[key] ~= false
            end
            if reminder.lead then
                db.leads[key] = DBR.SanitizeBuffLead(reminder, leads[key])
            end
            if reminder.tankOnly then
                db.alwaysShow[key] = alwaysShow[key] == true
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
-- notes when it reaches the lead time, for the refresh timer. "on" and
-- "soon" also return when the buff runs out and its full duration, when
-- readable, for the countdown and the running-out border.
local function BuffState(unit, reminder)
    local found, longest, duration = false, nil, nil
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
            if not longest or left > longest then
                longest = left
                duration = not DBR.IsSecret(aura.duration) and type(aura.duration) == "number"
                    and aura.duration > 0 and aura.duration or nil
            end
        end
    end
    if not found then
        return "missing"
    end
    local lead = LeadSeconds(reminder, duration)
    if longest <= lead + TIMER_SLACK then
        return "soon", GetTime() + longest, duration
    end
    local due = longest - lead
    if not reminders.nextCheck or due < reminders.nextCheck then
        reminders.nextCheck = due
    end
    return "on", GetTime() + longest, duration
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
    local state, expires, duration = BuffState(watched, reminder)
    -- The end DBR times in combat: the watched unit's (yours, or the tank's).
    reminders.timed[reminder.key] = watched
    reminders.seen[reminder.key] = state ~= "missing" and expires and {expires = expires, duration = duration}
        or nil
    if state ~= "on" then
        missing[#missing + 1] = {unit = watched, name = UnitLabel(watched), soon = state == "soon",
            expires = expires, duration = duration}
    end
    if reminder.group and DBR.db.groups[reminder.key] then
        for _, unit in ipairs(GroupUnits()) do
            if Usable(unit, reminder) then
                state, expires, duration = BuffState(unit, reminder)
                if state ~= "on" then
                    local name = UnitName(unit)
                    missing[#missing + 1] = {unit = unit, name = (not DBR.IsSecret(name) and name) or unit,
                        soon = state == "soon", expires = expires, duration = duration}
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

-- The click armed for combat while the buff is up: what a click would cast
-- now, on you; a Druid's leaves any form first (it cannot be checked then).
local function ArmedAction(reminder)
    local spell = SingleSpell(reminder)
    if spell then
        return {cast = spell, spell = spell, unit = "player", name = "you", armed = true}
    end
end

-- Up on the tank: armed to recast it on them (with /cancelform, as above).
-- The unit is the tank's token, set out of combat; it stays through a fight.
local function TankAction(reminder, unit)
    local spell = SingleSpell(reminder)
    if spell then
        return {cast = spell, spell = spell, unit = unit, name = UnitLabel(unit), armed = true}
    end
end

local function ApplyClick(icon, reminder, action)
    if action and reminder.cancelForm and (action.armed or InForm()) then
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

-- A buff still on but running out shows its time left (author: it looked
-- already gone): a cooldown sweep with numbers to when the first one runs
-- out. Drawn by the game, so no polling. None while anyone lacks it.
local function ShowTimeLeft(icon, missing)
    local first
    for _, entry in ipairs(missing or {}) do
        if not entry.soon or not entry.expires then
            first = nil
            break
        end
        if not first or entry.expires < first.expires then
            first = entry
        end
    end
    if first then
        local duration = first.duration or (first.expires - GetTime())
        icon.timeLeft:SetCooldown(first.expires - duration, duration)
        icon.timeLeft:Show()
    else
        icon.timeLeft:Hide()
    end
    icon.runningOut = first ~= nil
end

local function ShowIcon(icon, shown, count)
    icon.count:SetText(count and count > 1 and count or "")
    icon.wanted = shown == true
end

-- Out of combat: our icon's own border, red while missing, else none. Under
-- the aura slot it stays red, so it shows the moment the slot goes.
local function SetBorder(icon, color)
    icon.border = color
    icon.redAtEnd = false
    icon.glow:SetShown(color ~= nil)
    icon.glow:SetAlpha(1)
    if color then
        icon.glow:SetBackdropBorderColor(color[1], color[2], color[3])
    end
end

-- Watching another unit (a tank buff): no slot draws their buff, so ours
-- does, red only from its known end (by alpha, so also in combat).
local function RedAtEnd(icon)
    SetBorder(icon, RED)
    icon.glow:SetAlpha(0)
    icon.redAtEnd = true
end

-- The running-out border, above the aura slot: alpha and its animation only,
-- so it changes in combat too.
local function SetWarn(key, on)
    local holder = reminders.widgets[key]
    local warn = holder and holder.warn
    if not warn then
        return
    end
    if on then
        warn:SetAlpha(1)
        if not warn.flash:IsPlaying() then
            warn.flash:Play()
        end
    else
        warn.flash:Stop()
        warn:SetAlpha(0)
    end
end

-- Off; any timer set before does nothing.
local function StopWarn(key)
    reminders.warns[key] = (reminders.warns[key] or 0) + 1
    SetWarn(key, false)
end

-- From the buff's known end: flashing from its lead until it runs out, when
-- the slot goes and the red border under it shows (or, on a tank, ours turns
-- red). One C_Timer per edge (no polling); a newer schedule makes the older
-- timers do nothing.
local function ScheduleWarn(reminder, expires, duration)
    local key = reminder.key
    StopWarn(key)
    local token = reminders.warns[key]
    local left = expires - GetTime()
    if left <= TIMER_SLACK then
        return
    end
    C_Timer.After(left, function()
        if reminders.warns[key] == token then
            SetWarn(key, false)
            local icon = reminders.icons[key]
            if icon.redAtEnd then
                icon.glow:SetAlpha(1)
            end
        end
    end)
    local lead = LeadSeconds(reminder, duration)
    if lead <= 0 then
        return
    end
    local due = left - lead
    if due <= TIMER_SLACK then
        SetWarn(key, true)
        return
    end
    C_Timer.After(due, function()
        if reminders.warns[key] == token then
            SetWarn(key, true)
        end
    end)
end

-- Whether this character can show the reminder: known and switched on.
-- The names of the talents with a point in them, on the active talent
-- config. Forever's talents are a C_Traits tree (pinned Camelot
-- Blizzard_ClassTalentsFrame.lua): node rank, entry, definition, spell.
-- Kept until a talent or spell event (no rescan on every refresh).
local function TalentNames()
    if reminders.talents then
        return reminders.talents
    end
    local names = {}
    reminders.talents = names
    if type(C_ClassTalents) ~= "table" or type(C_ClassTalents.GetActiveConfigID) ~= "function"
        or type(C_Traits) ~= "table" or type(C_Traits.GetConfigInfo) ~= "function" then
        return names
    end
    local configID = C_ClassTalents.GetActiveConfigID()
    local config = type(configID) == "number" and C_Traits.GetConfigInfo(configID)
    if type(config) ~= "table" or type(config.treeIDs) ~= "table" then
        return names
    end
    for _, treeID in ipairs(config.treeIDs) do
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
            local node = C_Traits.GetNodeInfo(configID, nodeID)
            local rank = type(node) == "table" and node.activeRank
            if type(rank) == "number" and rank > 0 then
                for _, entryID in ipairs(node.entryIDs or {}) do
                    local entry = C_Traits.GetEntryInfo(configID, entryID)
                    local definition = type(entry) == "table" and entry.definitionID
                        and C_Traits.GetDefinitionInfo(entry.definitionID)
                    local spellID = type(definition) == "table" and definition.spellID
                    local name = type(spellID) == "number" and C_Spell.GetSpellName(spellID)
                    if type(name) == "string" and not DBR.IsSecret(name) then
                        names[#names + 1] = name
                    end
                end
            end
        end
    end
    return names
end

-- A talent for the buff: one of its talent spells known, or a point in a
-- talent whose name holds the buff's own (Improved Righteous Fury), so a
-- renumbered ID or another language still finds it.
local function HasTalent(reminder)
    for _, id in ipairs(reminder.tankOnly.talent or {}) do
        if Knows(id) then
            return true
        end
    end
    local buff = C_Spell.GetSpellName(reminder.spells[1])
    if type(buff) ~= "string" or DBR.IsSecret(buff) then
        return false
    end
    for _, name in ipairs(TalentNames()) do
        if name ~= buff and name:find(buff, 1, true) then
            return true
        end
    end
    return false
end

-- A tank-only buff (Buffs.lua's tankOnly, author: Righteous Fury): the Tank
-- role (a secret or missing answer is not a tank), its talent, or the
-- player's "Always show" switch.
local function ForTank(reminder)
    if DBR.db.alwaysShow[reminder.key] then
        return true
    end
    if type(UnitGroupRolesAssigned) == "function" and IsTank("player") then
        return true
    end
    return HasTalent(reminder)
end

local function Countable(reminder)
    if reminder.tankOnly and not ForTank(reminder) then
        return false
    end
    return DBR.db.enabled and DBR.db.spells[reminder.key] and Known(reminder) or false
end

-- Out of combat: our icon above the slot (anyone lacks it, it runs out, or
-- unlocked) or under it (the slot covers it while the buff is up).
local function Raise(icon, holder, above)
    if holder.slot then
        icon:SetFrameLevel(holder.slot:GetFrameLevel() + (above and SLOT_LEVELS_ABOVE or -SLOT_LEVELS_ABOVE + 1))
    end
end

-- Out of combat: whether the icon shows at all.
local function SetDriver(icon, driver)
    if icon.driver ~= driver then
        icon.driver = driver
        RegisterStateDriver(icon, "visibility", driver)
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
    -- Secure icons change only out of combat.
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
        icon.timeLeft:Hide()
        local holder = reminders.widgets[reminder.key]
        holder:SetShown(countable)
        if unlocked then
            -- Dragging must not cast. A buff that is on shows dimmed, still.
            ApplyClick(icon, reminder, nil)
            local missing = countable and canCheck and #Missing(reminder) > 0
            ShowIcon(icon, countable, nil)
            SetBorder(icon, missing and RED or nil)
            StopWarn(reminder.key)
            icon.texture:SetAlpha((missing or not canCheck) and 1 or DIM_ALPHA)
            SetDriver(icon, countable and SHOWN_DRIVER or HIDDEN_DRIVER)
            Raise(icon, holder, true)
        elseif countable and canCheck then
            local missing = Missing(reminder)
            icon.missing, icon.soon = MissingNames(missing, false), MissingNames(missing, true)
            if #missing > 0 then
                -- Someone lacks it, or yours runs out: ours, above the slot;
                -- red while anyone lacks it, else yellow and flashing.
                ApplyClick(icon, reminder, ClickAction(reminder, missing))
                ShowIcon(icon, true, #missing)
                ShowTimeLeft(icon, missing)
                SetDriver(icon, SHOWN_DRIVER)
                Raise(icon, holder, true)
                local lacking = #icon.missing > 0
                local timed = reminders.timed[reminder.key]
                if not lacking and timed ~= "player" then
                    RedAtEnd(icon)
                else
                    SetBorder(icon, lacking and RED or nil)
                end
                local seen = reminders.seen[reminder.key]
                if lacking then
                    StopWarn(reminder.key)
                elseif seen and missing[1].unit == reminders.timed[reminder.key] then
                    ScheduleWarn(reminder, seen.expires, seen.duration)
                else
                    -- Only a group member's runs out: until the next refresh.
                    StopWarn(reminder.key)
                    SetWarn(reminder.key, true)
                end
            elseif reminders.timed[reminder.key] ~= "player" then
                -- Up on the tank (Thorns): the slot draws only your own
                -- buffs, so ours shows it, above the slot, with the tank's
                -- time left (a cooldown, set now, runs on in combat); a click
                -- recasts it on them. Red from its known end.
                local seen = reminders.seen[reminder.key]
                local timed = reminders.timed[reminder.key]
                ApplyClick(icon, reminder, TankAction(reminder, timed))
                ShowIcon(icon, true, nil)
                ShowTimeLeft(icon, {{soon = true, expires = seen and seen.expires,
                    duration = seen and seen.duration}})
                SetDriver(icon, SHOWN_DRIVER)
                Raise(icon, holder, true)
                RedAtEnd(icon)
                if seen then
                    ScheduleWarn(reminder, seen.expires, seen.duration)
                else
                    StopWarn(reminder.key)
                end
            else
                -- Up on everyone: the slot shows it; ours waits under it,
                -- armed to recast it on you if it drops.
                ApplyClick(icon, reminder, ArmedAction(reminder))
                ShowIcon(icon, true, nil)
                -- A short buff (combatWindow) shows only when needed: hidden
                -- out of combat while up; in combat its window decides.
                local driver = reminder.combatWindow and COMBAT_ONLY_DRIVER or SHOWN_DRIVER
                SetDriver(icon, reminders.container and driver or HIDDEN_DRIVER)
                Raise(icon, holder, false)
                SetBorder(icon, RED)
                local seen = reminders.seen[reminder.key]
                if seen then
                    ScheduleWarn(reminder, seen.expires, seen.duration)
                else
                    StopWarn(reminder.key)
                end
            end
        else
            ApplyClick(icon, reminder, nil)
            ShowIcon(icon, false)
            SetDriver(icon, HIDDEN_DRIVER)
            SetBorder(icon, nil)
            StopWarn(reminder.key)
        end
    end
    for _, reminder in ipairs(reminders.list) do
        local icon = reminders.icons[reminder.key]
        icon.texture:SetTexture(ClickTexture(reminder, icon.action))
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
        GameTooltip:AddLine("Drag to move it.", 1, 1, 1, true)
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
    -- The time left while the buff is running out (ShowTimeLeft).
    icon.timeLeft = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.timeLeft:SetAllPoints()
    icon.timeLeft:SetHideCountdownNumbers(false)
    icon.timeLeft:EnableMouse(false)
    icon.timeLeft:Hide()
    -- The attention border: gold and pulsing on the combat aspect button; a
    -- reminder's is red while its buff is missing (SetBorder).
    local glow = CreateFrame("Frame", nil, icon, "BackdropTemplate")
    -- Inside the icon, so the aura slot above it covers it whole.
    glow:SetAllPoints(icon)
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
-- To the player it is the Aspect widget (author: "this should behave like 1
-- widget"): not a widget of its own, it sits on the Aspect widget, above its
-- aura slot, with its scale and opacity, and has no sample of its own. It is
-- anchored to the widget, not its child, so its own driver alone decides
-- when it shows. Anchors and scale change out of combat only.
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

-- Out of combat: on the Aspect widget, with its scale, above its aura slot.
local function PlaceCombatAspect()
    local button, holder = combat.button, combat.holder
    if not button or not holder or InCombatLockdown() then
        return
    end
    button:SetScale(holder:GetScale())
    button:ClearAllPoints()
    button:SetPoint("CENTER", holder, "CENTER", 0, 0)
    button:SetFrameLevel(holder:GetFrameLevel() + SLOT_LEVELS_ABOVE * 3)
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
    combat.holder = reminders.widgets[reminder.key]
    if combat.holder then
        button:SetAlpha(combat.holder:GetAlpha())
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
-- Events after which the talent names are read again (also in combat).
local TALENT_EVENTS = {PLAYER_TALENT_UPDATE = true, TRAIT_CONFIG_UPDATED = true, SPELLS_CHANGED = true,
    PLAYER_ENTERING_WORLD = true}
-- For a tank buff (Thorns): the game says when a group member comes into or
-- leaves its party range (UNIT_IN_RANGE_UPDATE, pinned
-- UnitDocumentation.lua:4328; the group frames' range, not the spell's, so a
-- tank between the two is re-checked at the next event) or goes offline
-- (UNIT_CONNECTION). No polling: the family rule.
local TANK_EVENTS = {"UNIT_IN_RANGE_UPDATE", "UNIT_CONNECTION"}

-- Whether the client has Blizzard's aura container (as the seal timer).
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

-- Every spell ID the buff can be on you as: its ranks and group versions, as
-- the set includeSpellIDs wants (found in client with the seal timer).
local function BuffIDs(reminder)
    local ids = {}
    for _, id in ipairs(reminder.spells) do
        ids[id] = true
    end
    for _, entry in ipairs(reminder.group and reminder.group.spells or {}) do
        ids[entry.spell] = true
    end
    return ids
end

-- The aura slot over a buff's icon: the engine shows it while the buff is on
-- you, also in combat, with its icon and time left; set up only here, in
-- initializeFrame (family rule). It takes no mouse, so a click reaches the
-- icon. Shown in and out of combat alike.
local function CreateSlot(reminder, holder, icon)
    local layer = CreateFrame("Frame", nil, holder)
    layer:SetAllPoints(holder)
    layer:SetFrameLevel(icon:GetFrameLevel() + SLOT_LEVELS_ABOVE)
    NoMouse(layer)
    -- A short buff's slot is transparent out of combat: shown only when needed.
    if reminder.combatWindow then
        layer:SetAlpha(0)
    end
    local container = CreateFrame("AuraContainer", nil, layer, CONTAINER_TEMPLATE)
    container:SetPoint("CENTER", holder, "CENTER")
    container:SetSize(1, 1)
    container:AddAuraSlot(reminder.key, "HELPFUL", {
        candidateFilters = {includeSpellIDs = BuffIDs(reminder)},
        initializeFrame = function(button)
            NoMouse(button)
            button:SetAllPoints(holder)
            local texture = button:CreateTexture(nil, "ARTWORK")
            texture:SetAllPoints()
            texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            cooldown:SetAllPoints(button)
            cooldown:SetHideCountdownNumbers(false)
            button:SetIcon(texture)
            button:SetDurationCooldown(cooldown)
        end,
    })
    container:SetUnit("player")
    container:UpdateAllAuras()
    return layer
end

-- The running-out border above the aura slot (and above our icon when it is
-- raised): plain, not secure, no mouse; shown by its alpha (SetWarn).
local function CreateWarn(holder, slot)
    local warn = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    warn:SetAllPoints(holder)
    warn:SetFrameLevel(slot:GetFrameLevel() + SLOT_LEVELS_ABOVE + 1)
    warn:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = BORDER})
    warn:SetBackdropBorderColor(YELLOW[1], YELLOW[2], YELLOW[3])
    NoMouse(warn)
    warn:SetAlpha(0)
    local flash = warn:CreateAnimationGroup()
    flash:SetLooping("BOUNCE")
    local fade = flash:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(PULSE_LOW_ALPHA)
    fade:SetDuration(PULSE_SECONDS)
    warn.flash = flash
    return warn
end

-- A buff's default place: its row, centered, the toolkit's snap gap apart;
-- or, once, its 1.1.0 bar's place plus its slot there.
local function DefaultPoint(reminder, row, index, count)
    local offset = (index - (count + 1) / 2) * (ICON_SIZE + ICON_SPACING)
    return {point = "CENTER", relativePoint = "CENTER", x = offset, y = row.y}
end

local function SeedFromBar(reminder, index, count)
    local bar = DBR.db.bars and DBR.db.bars[BarKey(reminder)]
    if not bar then
        return
    end
    local saved = DBR.db.buffs[reminder.key]
    -- In the bar's own scaled units, as its place was saved: the bar was as
    -- wide as its icons, 40 apart plus 8.
    local offset = (index - (count + 1) / 2) * (ICON_SIZE + 8)
    saved.position = {point = bar.position.point, relativePoint = bar.position.relativePoint,
        x = bar.position.x + offset, y = bar.position.y}
    saved.scale = saved.scale or bar.scale
end

-- One buff's widget: a holder the toolkit places and sizes; our secure icon
-- in it, and the aura slot above. The toolkit owns its mouse ("unlocked":
-- only to drag); the icon takes clicks itself.
local function CreateBuffWidget(reminder, row, index, count)
    if not DBR.db.buffs[reminder.key].position then
        SeedFromBar(reminder, index, count)
    end
    local holder = CreateFrame("Frame", "DyresBuffRemindersBuff_" .. reminder.key, UIParent)
    local icon = CreateIcon(reminder, holder)
    icon:SetAllPoints(holder)
    reminders.icons[reminder.key] = icon
    reminders.widgets[reminder.key] = holder
    if reminders.container then
        holder.slot = CreateSlot(reminder, holder, icon)
        holder.warn = CreateWarn(holder, holder.slot)
    end
    local function OnLayout()
        if combat.holder == holder then
            PlaceCombatAspect()
        end
    end
    local function OnOpacity(_, alpha)
        if combat.holder == holder and combat.button then
            combat.button:SetAlpha(alpha)
        end
    end
    DBR.toolkit.CreateWidget({
        addon = addonName, key = "buff_" .. reminder.key, title = reminder.label, frame = holder,
        store = DBR.db.buffs[reminder.key], width = ICON_SIZE, height = ICON_SIZE,
        point = DefaultPoint(reminder, row, index, count), sizes = DBR.WIDGET_SIZES,
        onLayout = OnLayout, onOpacity = OnOpacity,
    })
    -- The icon covers the widget: a drag that starts on it moves the widget.
    holder:AddDragHandle(icon)
end

-- In combat, a short buff (Buffs.lua's combatWindow, author: Battle Shout)
-- shows only while missing or within its lead. Its time is secret in combat,
-- so DBR times it: from the last out-of-combat read, reset by your own cast
-- (readable in combat), with one C_Timer to the window (no polling). Out of
-- the window its icon and slot are transparent (SetAlpha is allowed in combat
-- on a secure button). A drop in combat cannot be seen (AddOns cannot read
-- buffs then), so it shows at the window time (author: accepted for Battle
-- Shout). It counts YOUR casts (author: "a helper to maintain YOUR battle
-- shout's up-time"). The transparent icon still takes clicks (it casts the
-- buff; author: "I can live with that").
local function WindowAlpha(key, shown)
    local alpha = shown and 1 or 0
    reminders.icons[key]:SetAlpha(alpha)
    local holder = reminders.widgets[key]
    if holder and holder.slot then
        holder.slot:SetAlpha(alpha)
    end
end

local function ScheduleWindow(reminder, expires)
    local key = reminder.key
    local token = (reminders.windows[key] or 0) + 1
    reminders.windows[key] = token
    local due = expires - LeadSeconds(reminder) - GetTime()
    if due <= TIMER_SLACK then
        WindowAlpha(key, true)
        return
    end
    WindowAlpha(key, false)
    C_Timer.After(due, function()
        if reminders.windows[key] == token and InCombatLockdown() then
            WindowAlpha(key, true)
        end
    end)
end

local function OpenWindow(key)
    reminders.windows[key] = (reminders.windows[key] or 0) + 1
    WindowAlpha(key, true)
end

local function WindowReminders()
    local list = {}
    for _, reminder in ipairs(reminders.list) do
        if reminder.combatWindow and reminders.widgets[reminder.key] and reminders.container then
            list[#list + 1] = reminder
        end
    end
    return list
end

-- Combat starts: up and outside its lead, transparent until the window.
local function StartWindows()
    for _, reminder in ipairs(WindowReminders()) do
        local seen = reminders.seen[reminder.key]
        if seen then
            ScheduleWindow(reminder, seen.expires)
        else
            OpenWindow(reminder.key)
        end
    end
end

-- In combat: whether a single-target cast went on the unit DBR times. The
-- cast event names no target, so: you, with no target, yourself targeted,
-- or a target you cannot help (the client casts it on you); another unit,
-- when it is your target. A secret answer counts as not.
local function CastOn(timed)
    local exists = UnitExists("target")
    if DBR.IsSecret(exists) then
        return false
    end
    if timed ~= "player" then
        local same = exists and UnitIsUnit("target", timed)
        return not DBR.IsSecret(same) and same == true
    end
    if not exists then
        return true
    end
    local you = UnitIsUnit("target", "player")
    if DBR.IsSecret(you) then
        return false
    end
    if you then
        return true
    end
    if type(UnitCanAssist) ~= "function" then
        return false
    end
    local friend = UnitCanAssist("player", "target")
    return not DBR.IsSecret(friend) and friend == false
end

-- In combat: your own cast of a buff restarts its time (the length from the
-- last read, else Buffs.lua's duration): the running-out border and, for a
-- short buff, its window. A group version, a buff that always lands on you
-- (castOnYou), or a self-only buff always counts; a single-target one, when
-- CastOn says it went on the timed unit.
local function OwnCast(name)
    for _, reminder in ipairs(reminders.list) do
        local key = reminder.key
        local kind = reminders.casts[key] and reminders.casts[key][name]
        local holder = reminders.widgets[key]
        local mine = kind == "group" or reminder.castOnYou
            or not (reminder.group or reminder.others or reminder.tank)
        if kind and holder and holder.warn and (mine or CastOn(reminders.timed[key] or "player")) then
            local seen = reminders.seen[key]
            local duration = seen and seen.duration or reminder.duration
            if duration then
                local expires = GetTime() + duration
                reminders.seen[key] = {expires = expires, duration = duration}
                local icon = reminders.icons[key]
                if icon.redAtEnd then
                    icon.glow:SetAlpha(0)
                    icon.timeLeft:SetCooldown(GetTime(), duration)
                end
                ScheduleWarn(reminder, expires, duration)
                if reminder.combatWindow then
                    ScheduleWindow(reminder, expires)
                end
            end
        end
    end
end

-- Combat ends: the icon solid, the slot transparent again (out of combat
-- the refresh decides).
local function EndWindows()
    for _, reminder in ipairs(WindowReminders()) do
        OpenWindow(reminder.key)
        local holder = reminders.widgets[reminder.key]
        if holder.slot then
            holder.slot:SetAlpha(0)
        end
    end
end

-- The widgets, the icons, and their events; out of combat only.
local function SetUp()
    reminders.container = HasAuraContainer()
    for _, row in ipairs(ROWS) do
        local list = {}
        for _, reminder in ipairs(reminders.list) do
            if BarKey(reminder) == row.key then
                list[#list + 1] = reminder
            end
        end
        for index, reminder in ipairs(list) do
            CreateBuffWidget(reminder, row, index, #list)
        end
    end
    -- 1.1.0's bar places have seeded the icons: drop them.
    DBR.db.bars = nil
    for _, reminder in ipairs(reminders.list) do
        -- Needs the secure wrap that hides it on a click; without it, no button.
        if reminder.combatAspect and type(SecureHandlerWrapScript) == "function" then
            CreateCombatAspect(reminder)
            events:RegisterEvent("PLAYER_REGEN_DISABLED")
        end
    end
    reminders.ready = true
    if #WindowReminders() > 0 then
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
    end
    for _, event in ipairs({"UNIT_AURA", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
        "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "BAG_UPDATE_DELAYED",
        "UPDATE_SHAPESHIFT_FORM", "PLAYER_ROLES_ASSIGNED", "ROLE_CHANGED_INFORM",
        -- Talent changes, for a tank-only buff's talent (pinned
        -- SpecializationInfoDocumentation.lua:503, SharedTraitsDocumentation.lua:873).
        "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
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
        if InCombatLockdown() and not DBR.IsSecret(spellID) then
            local name = C_Spell.GetSpellName(spellID)
            if combat.button then
                CombatAspectCast(name)
            end
            OwnCast(name)
        end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        StartWindows()
        CombatStarts()
        return
    end
    if TALENT_EVENTS[event] then
        reminders.talents = nil
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
        EndWindows()
        DBR.RefreshReminders()
        return
    end
    ScheduleRefresh()
end)

function DBR.InitializeReminders(class)
    reminders.list = DBR.BUFFS[class] or {}
    for _, reminder in ipairs(reminders.list) do
        reminders.names[reminder.key] = BuffNames(reminder)
        local casts = {}
        for _, id in ipairs(reminder.spells) do
            local name = C_Spell.GetSpellName(id)
            if name then
                casts[name] = "single"
            end
        end
        for _, entry in ipairs(reminder.group and reminder.group.spells or {}) do
            local name = C_Spell.GetSpellName(entry.spell)
            if name then
                casts[name] = "group"
            end
        end
        reminders.casts[reminder.key] = casts
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

-- The buff widgets, for the settings page, in Buffs.lua's order.
function DBR.BuffWidgets()
    local list = {}
    for _, reminder in ipairs(reminders.list) do
        local holder = reminders.widgets[reminder.key]
        if holder then
            list[#list + 1] = holder
        end
    end
    return list
end

-- Whether the buff widgets have the aura container (in-combat display).
function DBR.HasBuffSlots()
    return reminders.container == true
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
        DBR.Report(string.format("debug %s row=%s on=%s group=%s known=%s shown=%s missing=%s click=%s "
            .. "unknownIDs=%s last=%s", reminder.key, BarKey(reminder), tostring(DBR.db.spells[reminder.key]), tostring(DBR.db.groups[reminder.key]),
            tostring(Known(reminder)), tostring(icon and icon:IsShown()), missing,
            action and (tostring(action.cast) .. "@" .. action.unit) or "none",
            #unknown > 0 and table.concat(unknown, ",") or "none", tostring(DBR.db.last[reminder.key])))
    end
    ReportCombatAspectDebug()
end
