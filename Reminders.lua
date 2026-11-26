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
-- The missing look (John, 2026-11-20, from a player's request: "so the glow
-- shows instead of the red border"; "glow only for gone", running out stays
-- yellow): "glow", the action bars' proc glow, or "border", the red border.
-- Glow is the default (John, in client: "new effect looks good, ship it").
DBR.MISSING_STYLE_ORDER = {"glow", "border"}
DBR.MISSING_STYLE_LABELS = {glow = "Glow", border = "Red border"}
DBR.DEFAULT_MISSING_STYLE = "glow"
-- The art of ActionButtonSpellAlertTemplate's loop (Blizzard_ActionBar
-- Shared/ActionButtonSpellAlerts.xml, loaded on Forever and Era): a 6 by 5
-- flipbook of 30 frames in 1 second, 1.4 times the button on the action bars.
local GLOW_ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
local GLOW_ROWS, GLOW_COLUMNS, GLOW_FRAMES = 6, 5, 30
local GLOW_SECONDS = 1
local GLOW_OUTSIDE = 1.4
-- The default rows, where 1.1.0's bars were: buffs that can go on another
-- player above, self-only buffs below; y is above the screen's center.
local ROWS = {
    {key = "groupbuffs", y = 180},
    {key = "mybuffs", y = 130},
}
local HIDDEN_DRIVER = "hide"
local SHOWN_DRIVER = "show"
local COMBAT_ONLY_DRIVER = "[combat] show; hide"
-- A pet reminder: the game decides, also in combat (no reads, so nothing
-- secret): shown with no pet or a dead one, hidden while mounted.
local PET_DRIVER = "[mounted] hide; [nopet] show; [@pet,dead] show; hide"
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
-- A group, role, or zone change is checked again this many seconds later
-- (John, 2026-11-25, as Dyre's Toolkit's pet taunt fix: "Yes, both"; found
-- in client in the toolkit: the first check came before the group, role, or
-- pet bar data was ready, and nothing fired again while autocast stayed on).
-- One timer; a newer event makes the waiting one do nothing.
local RECHECK_DELAY = 2
local RECHECK_EVENTS = {GROUP_ROSTER_UPDATE = true, PLAYER_ROLES_ASSIGNED = true, ROLE_CHANGED_INFORM = true,
    PLAYER_ENTERING_WORLD = true}
-- A timer can fire a hair early; this much past the lead time still counts.
local TIMER_SLACK = 0.05
-- AddOn restrictions that hide auras out of combat (found in client, 1.13.2:
-- every boss fight in Dire Maul showed buffs that were up as missing; a
-- read during the encounter, out of combat, returned nothing, not a secret).
-- Map is left out: Deadmines has it, and reads there worked (John, in client).
-- Pinned RestrictedActionsConstantsDocumentation.lua.
local AURA_RESTRICTIONS = {"Encounter", "ChallengeMode", "PvPMatch"}

-- The Aspect reminder's modes (Buffs.lua's combatAspect; John, 1.8.0):
-- Normal (default), Speed-Running (Cheetah is fine in combat), Disabled.
DBR.ASPECT_MODE_ORDER = {"normal", "speed", "off"}
DBR.ASPECT_MODE_LABELS = {normal = "Normal", speed = "Speed-Running", off = "Disabled"}

-- "Show only when needed", per buff (db.needed[key]; John, 2026-11-18: "A
-- yes, per buff"). Default on for a short buff (combatWindow: Battle Shout),
-- off for a long one (John, 2026-11-19, "1a", reversing "default all short
-- and long term buffs to on"): on, a buff dropped in a fight (dispelled or
-- cancelled) stays hidden until its timed warning, because AddOn code
-- cannot see it go (found in client, 2026-11-19: UNIT_AURA's removed IDs
-- are secret in combat, and the engine's slot button takes no script). Off,
-- the engine's slot goes and our red icon under it shows at once. 1.12.0
-- turned every buff on, so a save without db.neededLongOff turns the long
-- ones off once. While the buff is up and outside its lead, its icon and the game's
-- buff icon in its place show at "Visibility when not needed"
-- (db.faintPercent, 0 to 80%, default 0: hidden), the same alpha in and out
-- of combat (John: "it should be consistent alpha both in and out of
-- combat"). Off, the icon always shows in full. 80% at most: more would be
-- the switch off (John). Players asked for 1.10's invisible Battle Shout
-- back, so 0 is the default (John: "waive it; default Hidden, apply to
-- all"). A hidden icon still takes clicks in combat (a click there casts
-- the buff): in combat AddOn code cannot hide a secure button or turn its
-- mouse off, only change its alpha. Out of combat at 0 it is hidden.
DBR.FAINT_MIN, DBR.FAINT_MAX, DBR.FAINT_STEP = 0, 80, 5
DBR.DEFAULT_FAINT = 0

function DBR.SanitizeFaint(value)
    if type(value) ~= "number" or value ~= value then
        return DBR.DEFAULT_FAINT
    end
    value = math.floor(value / DBR.FAINT_STEP + 0.5) * DBR.FAINT_STEP
    return math.max(DBR.FAINT_MIN, math.min(DBR.FAINT_MAX, value))
end

-- Whether a buff can be shown only when needed: one with an aura slot (not
-- a pet, not the Aspect reminder).
function DBR.CanShowOnlyWhenNeeded(reminder)
    return not reminder.pet and not reminder.combatAspect
end

-- Its default: on for a short buff only (above).
function DBR.NeededDefault(reminder)
    return reminder.combatWindow == true
end

-- "Show only in combat" (db.combatOnly[key], default off; John, 2026-11-26),
-- for a short buff (combatWindow: Battle Shout). On, out of combat nothing of
-- it shows (our icon, the game's slot, the running-out border), missing or
-- not; in combat it shows as before. The icon's driver lets the game show it
-- when combat starts; the slot and the border are alpha only, set at
-- combat's edges.
function DBR.CanShowOnlyInCombat(reminder)
    return reminder.combatWindow == true and DBR.CanShowOnlyWhenNeeded(reminder)
end

local reminders = {list = {}, icons = {}, names = {}, spellKeys = {}, spellNames = {}, widgets = {},
    seen = {}, windows = {}, faded = {}, warns = {}, warnOn = {}, combatOnly = {}, timed = {}, casts = {}, upNames = {},
    travelNames = {}, speedNames = {}}

-- Whether a buff hides out of combat ("Show only in combat"), while locked.
local function CombatOnly(reminder)
    return DBR.CanShowOnlyInCombat(reminder) and DBR.db.locked and DBR.db.combatOnly[reminder.key] == true
        or false
end

-- In combat: also during PLAYER_REGEN_DISABLED, before the lockdown starts.
local function InCombat()
    return reminders.combat or InCombatLockdown()
end

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

-- The Aspect reminder's saved place and sizes: its own Size now (the same
-- key, scale, so a size set with the shared reminder size stays, and so does
-- its place). A 1.8.0 test build had its own warnScale and saved its place in
-- that size's units, without scale: once, that place is converted to the
-- size now (scale, else 100), which keeps its center where it was on screen.
local function SanitizeAspectWidget(widget, sanitizePosition)
    local position = sanitizePosition(widget.position)
    local scale = widget.scale
    local from = widget.warnScale
    if type(from) == "number" and from == from and from > 0 then
        local to = (type(scale) == "number" and scale == scale and scale > 0) and scale or 100
        if position and position.point == "CENTER" and position.relativePoint == "BOTTOMLEFT" then
            position.x, position.y = position.x * from / to, position.y * from / to
        end
    end
    return {position = position, scale = scale, opacity = widget.opacity}
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
    -- 1.11.0's one switch (db.onlyNeeded) is per buff now. 1.12.0 turned
    -- every buff on: once, the long ones go to their default, off.
    db.onlyNeeded = nil
    local needed = type(db.needed) == "table" and db.needed or {}
    local longOff = db.neededLongOff ~= true
    db.needed = {}
    local combatOnly = type(db.combatOnly) == "table" and db.combatOnly or {}
    db.combatOnly = {}
    db.neededLongOff = true
    -- 1.11.0 saved its default, 15, for everyone: once, 15 becomes 0, the
    -- new default (a 15 chosen by hand too; 25 stays).
    if db.faintHidden ~= true and db.faintPercent == 15 then
        db.faintPercent = 0
    end
    db.faintHidden = true
    db.faintPercent = DBR.SanitizeFaint(db.faintPercent)
    if not DBR.MISSING_STYLE_LABELS[db.missingStyle] then
        db.missingStyle = DBR.DEFAULT_MISSING_STYLE
    end
    local leads = type(db.leads) == "table" and db.leads or {}
    db.leads = {}
    local alwaysShow = type(db.alwaysShow) == "table" and db.alwaysShow or {}
    db.alwaysShow = {}
    local warned = type(db.warnings) == "table" and db.warnings or {}
    db.warnings = {}
    for _, list in pairs(DBR.WARNINGS or {}) do
        for _, warning in ipairs(list) do
            db.warnings[warning.key] = warned[warning.key] ~= false
        end
    end
    local pop = type(db.warningPop) == "table" and db.warningPop or {}
    db.warningPop = {position = sanitizePosition(pop.position), scale = pop.scale}
    local aspect = type(db.combatAspect) == "table" and db.combatAspect or {}
    -- The combat-start sound (1.8.0: the combat aspect button is the Aspect
    -- reminder's job now; its switch and a pre-release's place are dropped).
    db.combatAspect = {soundOn = aspect.soundOn ~= false,
        sound = DBR.SanitizeChimeSound and DBR.SanitizeChimeSound(aspect.sound) or aspect.sound}
    for _, list in pairs(DBR.BUFFS) do
        for _, reminder in ipairs(list) do
            local key = reminder.key
            local widget = type(buffs[key]) == "table" and buffs[key] or {}
            if reminder.combatAspect then
                db.buffs[key] = SanitizeAspectWidget(widget, sanitizePosition)
            else
                db.buffs[key] = {position = sanitizePosition(widget.position), scale = widget.scale,
                    opacity = widget.opacity}
            end
            if type(spells[key]) == "boolean" then
                db.spells[key] = spells[key]
            else
                db.spells[key] = reminder.on
            end
            if reminder.combatAspect then
                -- The mode replaces the switch (John, 1.8.0): a switch saved off is Disabled.
                if not DBR.ASPECT_MODE_LABELS[db.aspectMode] then
                    db.aspectMode = spells[key] == false and "off" or "normal"
                end
                db.spells[key] = db.aspectMode ~= "off"
            end
            if reminder.group then
                db.groups[key] = groups[key] ~= false
            end
            if DBR.CanShowOnlyWhenNeeded(reminder) then
                local value = needed[key]
                if type(value) ~= "boolean" or (longOff and not reminder.combatWindow) then
                    value = DBR.NeededDefault(reminder)
                end
                db.needed[key] = value
            end
            if DBR.CanShowOnlyInCombat(reminder) then
                db.combatOnly[key] = combatOnly[key] == true
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
    for _, id in ipairs(reminder.knownBy or reminder.spells) do
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

-- The first active restriction that hides auras, or nil. Classic Era has
-- no C_RestrictedActions: never restricted there.
function DBR.AuraRestriction()
    if type(C_RestrictedActions) ~= "table" or type(C_RestrictedActions.IsAddOnRestrictionActive) ~= "function"
        or type(Enum) ~= "table" or type(Enum.AddOnRestrictionType) ~= "table" then
        return nil
    end
    for _, name in ipairs(AURA_RESTRICTIONS) do
        local kind = Enum.AddOnRestrictionType[name]
        if kind ~= nil and C_RestrictedActions.IsAddOnRestrictionActive(kind) == true then
            return name
        end
    end
    return nil
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
            -- The one up on you is what a click recasts (author: "recasting
            -- whatever was up last"), also when it was cast before DBR saw it.
            if unit == "player" and reminder.prefer and reminders.spellNames[name] == reminder.key then
                DBR.db.last[reminder.key] = name
            end
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
    -- Right-click (a pet's Revive Pet), or nothing.
    icon:SetAttribute("type2", action and action.right and "spell" or nil)
    icon:SetAttribute("spell2", action and action.right or nil)
    if action and action.macro then
        icon.action = action
        icon:SetAttribute("type1", "macro")
        icon:SetAttribute("macrotext1", action.macro)
        icon:SetAttribute("spell1", nil)
        icon:SetAttribute("unit1", nil)
        return
    end
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

-- A pet reminder's click. A Hunter's calls the pet, or revives it when it is
-- dead ("/use", author's rule, with [@pet,dead]); a right-click always
-- revives. A Warlock's summons the last demon summoned, else the Imp.
local function PetAction(reminder)
    if reminder.pet == "hunter" then
        local call = C_Spell.GetSpellName(reminder.spells[1])
        local revive = reminder.revive and Knows(reminder.revive) and C_Spell.GetSpellName(reminder.revive) or nil
        if not call then
            return nil
        end
        local macro = revive and ("/use [@pet,dead] " .. revive .. "; " .. call) or ("/use " .. call)
        return {macro = macro, cast = call, right = revive, noTarget = true,
            spell = revive and (call .. " (" .. revive .. " if it is dead; right-click: " .. revive .. ")") or call}
    end
    local spell = SingleSpell(reminder)
    if spell then
        return {cast = spell, spell = spell, noTarget = true}
    end
end

-- A Warlock's Demonic Sacrifice is on: no pet is wanted. A secret answer
-- counts as on: DBR cannot tell, so no warning. Out of combat only.
local function Sacrificed(reminder)
    for _, id in ipairs(reminder.sacrifice or {}) do
        local name = C_Spell.GetSpellName(id)
        if name then
            local aura = C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
            if DBR.IsSecret(aura) or aura ~= nil then
                return true
            end
        end
    end
    return false
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

-- Whether the client has the glow's art; else the red border shows.
local glowArt
function DBR.GlowArt()
    if glowArt == nil then
        local GetAtlasInfo = C_Texture and C_Texture.GetAtlasInfo
        local info = type(GetAtlasInfo) == "function" and GetAtlasInfo(GLOW_ATLAS) or nil
        glowArt = info ~= nil
    end
    return glowArt
end

-- Under the aura slot the glow stays inside our icon, so the slot covers it
-- while the buff is up; elsewhere it is the action bars' size, around it.
local function SizeAlert(icon)
    local alert = icon.alert
    local size = ICON_SIZE * (icon.underSlot and 1 or GLOW_OUTSIDE)
    if alert and alert.size ~= size then
        alert.size = size
        alert:ClearAllPoints()
        alert:SetPoint("CENTER", icon, "CENTER", 0, 0)
        alert:SetSize(size, size)
    end
end

local function ShowAlert(icon, on)
    local alert = icon.alert
    if not alert then
        return
    end
    if on then
        SizeAlert(icon)
        alert:Show()
        if not alert.flip:IsPlaying() then
            alert.flip:Play()
        end
    else
        alert.flip:Stop()
        alert:Hide()
    end
end

-- Out of combat: our icon's own border, red while missing, else none. Under
-- the aura slot it stays red, so it shows the moment the slot goes. With
-- "Missing buff" on Glow, the glow shows instead of the red edge; it is a
-- child of the border frame, so every alpha set on the border drives it too.
local function SetBorder(icon, color)
    icon.border = color
    icon.redAtEnd = false
    icon.glow:SetShown(color ~= nil)
    icon.glow:SetAlpha(1)
    local glowing = color == RED and DBR.db.missingStyle == "glow" and DBR.GlowArt()
    if color then
        icon.glow:SetBackdropBorderColor(color[1], color[2], color[3], glowing and 0 or 1)
    end
    icon.glowing = glowing or nil
    ShowAlert(icon, glowing)
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
    reminders.warnOn[key] = on or nil
    -- Kept for combat's start (CombatOnlyEdge), not shown before it.
    if on and reminders.combatOnly[key] and not InCombat() then
        on = false
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
-- Your group's designated tank: the Tank role, or a raid's main tank
-- (GetPartyAssignment, as the secure group headers read it). A secret or
-- missing answer is not a tank.
local function DesignatedTank()
    if type(UnitGroupRolesAssigned) == "function" and IsTank("player") then
        return true
    end
    if IsInRaid() and type(GetPartyAssignment) == "function" then
        local main = GetPartyAssignment("MAINTANK", "player")
        return not DBR.IsSecret(main) and main == true
    end
    return false
end

-- A tank-only buff (Buffs.lua's tankOnly, author, 1.5.0: Righteous Fury):
-- solo, or your group's designated tank, or the player's "Always show".
local function ForTank(reminder)
    if DBR.db.alwaysShow[reminder.key] then
        return true
    end
    return not IsInGroup() or DesignatedTank()
end

-- A warning's spells, by name, on you (Righteous Fury) or on your pet's bar
-- with autocast on (a taunt). A secret answer: cannot tell, so no warning.
local function FuryUp(reminder)
    for _, id in ipairs(reminder.spells) do
        local name = C_Spell.GetSpellName(id)
        local aura = name and C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
        if aura ~= nil and not DBR.IsSecret(aura) then
            return name
        end
    end
end

local PET_ACTION_SLOTS = rawget(_G, "NUM_PET_ACTION_SLOTS") or 10

local function TauntsOn(reminder)
    local names, on = {}, {}
    for _, id in ipairs(reminder.petTaunts or {}) do
        local name = C_Spell.GetSpellName(id)
        if name then
            names[name] = true
        end
    end
    if type(GetPetActionInfo) ~= "function" or not UnitExists("pet") then
        return on
    end
    for slot = 1, PET_ACTION_SLOTS do
        local name, _, isToken, _, _, autoCastEnabled = GetPetActionInfo(slot)
        if not DBR.IsSecret(name) and not DBR.IsSecret(autoCastEnabled) and not isToken and names[name]
            and autoCastEnabled == true then
            on[#on + 1] = name
        end
    end
    return on
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
    icon.underSlot = holder.slot ~= nil and not above
    SizeAlert(icon)
end

-- Whether a buff shows only when needed (missing or within its lead): its
-- own "Show only when needed" while locked (unlocked, every icon shows, to
-- move it). Never a pet or the Aspect reminder (no aura slot).
local function Windowed(reminder)
    return DBR.CanShowOnlyWhenNeeded(reminder) and DBR.db.locked and DBR.db.needed[reminder.key] ~= false
        or false
end

-- "Visibility when not needed", as an alpha.
local function FaintAlpha()
    return DBR.db.faintPercent / 100
end

-- The alpha of a buff's aura slot: "Visibility when not needed" while shown
-- only when needed, else in full; only a change is set.
local function SetSlotAlpha(holder, alpha)
    if holder.slot and holder.slotAlpha ~= alpha then
        holder.slotAlpha = alpha
        holder.slot:SetAlpha(alpha)
    end
end

local function SlotAlpha(reminder)
    if CombatOnly(reminder) and not InCombat() then
        return 0
    end
    return Windowed(reminder) and FaintAlpha() or 1
end

-- Out of combat: whether the icon shows at all.
local function SetDriver(icon, driver)
    if icon.driver ~= driver then
        icon.driver = driver
        RegisterStateDriver(icon, "visibility", driver)
    end
end

-- The Aspect reminder has no visibility driver: the game's driver manager
-- shows or hides a frame with one every 0.2 s, changed or not (pinned
-- SecureStateDriver.lua:95-105 and :119-129), so a secure Hide in combat held
-- for at most 0.2 s (found in client, John, 2026-11-14: after a click on the
-- reminder in combat it "faded, and then went away when combat ended"). An
-- attribute driver sets its attribute only on a change (:106-115), so the
-- icon gets "state-dbrcombat" (1 in combat, else 0) and this handler (a
-- SecureHandlerStateTemplate `_onstate-`) shows or hides it at the change,
-- by "dbr-show", set out of combat: "always", "combat" (the game shows it
-- when combat starts), or "never". Between changes a secure Hide or Show
-- holds.
local ASPECT_COMBAT_DRIVER = "[combat] 1; 0"
local ASPECT_ON_COMBAT = [[
local show = self:GetAttribute("dbr-show")
if show == "always" or (show == "combat" and (newstate == 1 or newstate == "1")) then
    self:Show()
else
    self:Hide()
end
]]
local ASPECT_SHOW = {[SHOWN_DRIVER] = "always", [COMBAT_ONLY_DRIVER] = "combat", [HIDDEN_DRIVER] = "never"}

-- Out of combat: the Aspect reminder's mode (no visibility driver, above).
local function SetAspectShow(icon, driver)
    icon.driver = driver
    icon:SetAttribute("dbr-show", ASPECT_SHOW[driver])
end

-- A secret or missing answer counts as not on a taxi.
local function OnTaxi()
    if type(UnitOnTaxi) ~= "function" then
        return false
    end
    local onTaxi = UnitOnTaxi("player")
    return not DBR.IsSecret(onTaxi) and onTaxi == true
end

-- The Aspect reminder (Buffs.lua's combatAspect; John, 1.8.0): "gives a
-- visual indicator in or out of combat if you have no aspect at all up - Red
-- Outline. If I enter combat without an aspect up, or with Cheeta or Pack up,
-- it should similarly show a visual indicator". One secure icon with a red
-- outline, shown only when there is a problem, else nothing (no aura slot).
-- It shows the combat aspect a click casts (your last, else Hawk, else
-- Monkey); a click casts it with "!", with the aspect bar on or off. It does
-- the 1.1.0 combat aspect button's job, so that button is gone.
--
-- AddOn code cannot read auras or change secure frames in combat, so it is
-- set out of combat from the aura read: no aspect, shown ("show"); a travel
-- aspect that is a problem in combat (Pack; Cheetah in Normal), shown by the
-- game when combat starts ("[combat] show; hide"); else hidden. In combat:
-- its own click hides it (a secure wrap); a click on an aspect bar button
-- hides or shows it in secure code (RefreshBarRoles); your own aspect cast
-- from anywhere else dims it to 0.4 and takes the outline away (both allowed
-- in combat; never alpha 0: it still takes clicks), or, for a travel aspect
-- that is a problem, makes it solid again. After combat the aura decides. A
-- cancel in combat cannot be seen until combat ends.

-- Out of combat: "none" (no aspect on you), the travel aspect's name
-- (Buffs.lua's forget: Cheetah, Pack), "fine" (a combat aspect is up), or
-- false when a read was secret (cannot tell). The combat aspect up is what
-- a click recasts.
local function AspectNow(reminder)
    local key = reminder.key
    local travel
    for _, name in ipairs(reminders.names[key]) do
        local aura = C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
        if DBR.IsSecret(aura) then
            return false
        end
        if aura ~= nil then
            if not reminders.travelNames[key][name] then
                if reminders.spellNames[name] == key then
                    DBR.db.last[key] = name
                end
                return "fine"
            end
            travel = name
        end
    end
    return travel or "none"
end

-- Whether an aspect up in combat is a problem (John): Pack in Normal and
-- Speed-Running; Cheetah in Normal only ("sometimes hunters fight with Cheeta
-- up in the open world to kill fast"); a combat aspect never.
local function BadInCombat(reminder, name)
    local key = reminder.key
    if not reminders.travelNames[key][name] then
        return false
    end
    return not (DBR.db.aspectMode == "speed" and reminders.speedNames[key][name])
end

-- The aspect bar's buttons (AspectBar.lua links each). A click on one in
-- combat hides the reminder when its aspect fixes the problem, or shows it
-- when it makes one, in secure code: the wrap's post-body (pinned
-- SecureHandlers.lua:602, run after the click, header explicitly protected)
-- reaches the reminder through a frame ref (SecureHandlers.lua:702,
-- RestrictedFrames.lua:205), whose handle may Show and Hide a protected frame
-- (RestrictedFrames.lua:394-408). PlayerInCombat (RestrictedEnvironment.lua:200)
-- keeps it out of the way out of combat, where the aura read decides. Each
-- button's role is an attribute, set out of combat.
local BAR_CLICK = [[
if PlayerInCombat() then
    local reminder = self:GetFrameRef("dbrAspectReminder")
    local role = self:GetAttribute("dbr-reminder")
    if reminder and role == "hide" then
        reminder:Hide()
    elseif reminder and role == "show" then
        reminder:Show()
    end
end
]]
local barButtons = {}

-- Out of combat only.
local function WireBarButton(entry, icon)
    SecureHandlerSetFrameRef(entry.button, "dbrAspectReminder", icon)
    SecureHandlerWrapScript(entry.button, "OnClick", icon, "return nil, true", BAR_CLICK)
    entry.wired = true
end

function DBR.LinkAspectBarButton(button, spellID)
    if type(SecureHandlerWrapScript) ~= "function" or type(SecureHandlerSetFrameRef) ~= "function" then
        return
    end
    local entry = {button = button, name = C_Spell.GetSpellName(spellID)}
    barButtons[#barButtons + 1] = entry
    local reminder = reminders.aspect
    local icon = reminder and reminders.icons[reminder.key]
    if icon and icon.wrapped and not InCombatLockdown() then
        WireBarButton(entry, icon)
    end
end

-- Out of combat: each bar button's role in combat (none while the reminder
-- is off, unlocked, or you are dead or on a taxi).
local function RefreshBarRoles(reminder, icon, active)
    for _, entry in ipairs(barButtons) do
        if not entry.wired and icon.wrapped then
            WireBarButton(entry, icon)
        end
        if entry.wired then
            local role
            if active and entry.name and reminders.upNames[reminder.key][entry.name] then
                role = BadInCombat(reminder, entry.name) and "show" or "hide"
            end
            entry.button:SetAttribute("dbr-reminder", role)
        end
    end
end

-- Out of combat: the Aspect reminder's state, click, and driver.
local function RefreshAspectReminder(reminder, icon, countable, canCheck, unlocked)
    local state
    if countable and canCheck then
        state = AspectNow(reminder)
        -- A secret read changes nothing.
        if state == false then
            state = reminders.aspectState or "fine"
        end
    end
    reminders.aspectState = state
    local travel = state and state ~= "none" and state ~= "fine" and state or nil
    local problem
    if not unlocked and state == "none" then
        problem = "now"
    elseif not unlocked and travel and BadInCombat(reminder, travel) then
        problem = "combat"
    end
    reminders.aspectProblem, reminders.aspectTravel = problem, travel
    icon.alarm = problem == "now" and "No aspect is up." or problem == "combat"
        and (travel .. " is up: a problem in combat.") or nil
    StopWarn(reminder.key)
    local driver
    if unlocked then
        ApplyClick(icon, reminder, nil)
        driver = countable and SHOWN_DRIVER or HIDDEN_DRIVER
    else
        ApplyClick(icon, reminder, countable and canCheck and ArmedAction(reminder) or nil)
        driver = problem == "now" and SHOWN_DRIVER or problem == "combat" and COMBAT_ONLY_DRIVER or HIDDEN_DRIVER
    end
    ShowIcon(icon, driver ~= HIDDEN_DRIVER, nil)
    if icon.wrapped then
        SetAspectShow(icon, driver)
    else
        SetDriver(icon, driver)
    end
    -- A wrap may have hidden or shown it in combat, and the combat driver
    -- acts only at combat's edges, so out of combat it is set here.
    local wanted = driver == SHOWN_DRIVER
    if icon:IsShown() ~= wanted then
        if wanted then
            icon:Show()
        else
            icon:Hide()
        end
    end
    icon:SetAlpha(1)
    SetBorder(icon, RED)
    icon.texture:SetAlpha(unlocked and canCheck and state ~= "none" and DIM_ALPHA or 1)
    RefreshBarRoles(reminder, icon, countable and canCheck and not unlocked)
end

function DBR.RefreshReminders()
    reminders.scheduled = false
    if not reminders.ready then
        return
    end
    -- Secure icons change only out of combat. While a restriction hides
    -- auras, a read says "missing" for a buff that is up, so everything stays
    -- as in combat (ours under the slot, armed) until it ends.
    if InCombatLockdown() or DBR.AuraRestriction() then
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
        icon.missing, icon.soon, icon.othersNeed = nil, nil, nil
        icon.watching = reminder.tank and UnitLabel(Watched(reminder)) or nil
        icon.texture:SetAlpha(1)
        icon.timeLeft:Hide()
        local holder = reminders.widgets[reminder.key]
        holder:SetShown(countable)
        local windowed = Windowed(reminder)
        local combatOnly = CombatOnly(reminder)
        reminders.combatOnly[reminder.key] = combatOnly or nil
        SetSlotAlpha(holder, SlotAlpha(reminder))
        -- Up and not needed, out of combat: "Visibility when not needed";
        -- at 0 hidden (no clicks), else shown at that alpha.
        local faint = windowed and FaintAlpha() or 1
        local upDriver = faint > 0 and not combatOnly and SHOWN_DRIVER or COMBAT_ONLY_DRIVER
        -- Missing or running out: shown, or only in combat.
        local neededDriver = combatOnly and COMBAT_ONLY_DRIVER or SHOWN_DRIVER
        if not reminder.combatAspect then
            icon:SetAlpha(1)
        end
        if reminder.combatAspect then
            RefreshAspectReminder(reminder, icon, countable, canCheck, unlocked)
        elseif unlocked then
            -- Dragging must not cast. A buff that is on shows dimmed, still.
            ApplyClick(icon, reminder, nil)
            local missing = countable and canCheck and #Missing(reminder) > 0
            ShowIcon(icon, countable, nil)
            SetBorder(icon, missing and RED or nil)
            StopWarn(reminder.key)
            icon.texture:SetAlpha((missing or not canCheck) and 1 or DIM_ALPHA)
            SetDriver(icon, countable and SHOWN_DRIVER or HIDDEN_DRIVER)
            Raise(icon, holder, true)
        elseif reminder.pet and countable and canCheck then
            if Sacrificed(reminder) then
                ApplyClick(icon, reminder, nil)
                ShowIcon(icon, false)
                SetDriver(icon, HIDDEN_DRIVER)
                SetBorder(icon, nil)
            else
                -- Red while there is no pet: the game shows and hides it.
                ApplyClick(icon, reminder, PetAction(reminder))
                ShowIcon(icon, true, nil)
                SetBorder(icon, RED)
                SetDriver(icon, PET_DRIVER)
            end
            StopWarn(reminder.key)
        elseif countable and canCheck then
            local missing = Missing(reminder)
            icon.missing, icon.soon = MissingNames(missing, false), MissingNames(missing, true)
            if #missing > 0 then
                -- Someone lacks it, or yours runs out: ours, above the slot;
                -- red while anyone lacks it, else yellow and flashing.
                ApplyClick(icon, reminder, ClickAction(reminder, missing))
                ShowIcon(icon, true, #missing)
                ShowTimeLeft(icon, missing)
                SetDriver(icon, neededDriver)
                Raise(icon, holder, true)
                local lacking = #icon.missing > 0
                local timed = reminders.timed[reminder.key]
                -- Someone but the unit DBR times needs it: in combat, DBR
                -- cannot time theirs, so it stays in full.
                for _, entry in ipairs(missing) do
                    if entry.unit ~= timed then
                        icon.othersNeed = true
                    end
                end
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
                -- Only when needed: faint or hidden out of combat while up on them.
                SetDriver(icon, upDriver)
                icon:SetAlpha(faint)
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
                -- A buff shown only when needed (Windowed): faint or hidden
                -- out of combat while up; in combat its window decides.
                SetDriver(icon, reminders.container and upDriver or HIDDEN_DRIVER)
                icon:SetAlpha(faint)
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
    DBR.CheckWarnings()
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

-- The second check after a group, role, or zone change (RECHECK_DELAY). In
-- combat it does nothing: combat's end refreshes anyway.
local function ScheduleRecheck()
    reminders.recheckToken = (reminders.recheckToken or 0) + 1
    local token = reminders.recheckToken
    C_Timer.After(RECHECK_DELAY, function()
        if reminders.recheckToken == token and not InCombatLockdown() then
            DBR.RefreshReminders()
        end
    end)
end

local function ShowTooltip(icon)
    GameTooltip:SetOwner(icon, "ANCHOR_TOP")
    GameTooltip:SetText(icon.label, GOLD[1], GOLD[2], GOLD[3])
    if not DBR.db.locked then
        GameTooltip:AddLine("Drag to move it.", 1, 1, 1, true)
    else
        if icon.alarm then
            GameTooltip:AddLine(icon.alarm, 1, 1, 1, true)
        end
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
            local whom = (action.group or action.noTarget) and "" or (" on " .. action.name)
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
    -- The missing glow (SetBorder), a child of the border frame. Our own
    -- frame with the template's art, not ActionButtonSpellAlertTemplate: its
    -- mixin stops the loop on hide and does not start it again, and our icon
    -- hides and shows by its driver in combat. A plain frame with an engine
    -- animation: no clicks, no scripts, no OnUpdate.
    local alert = CreateFrame("Frame", nil, glow)
    alert:EnableMouse(false)
    alert:Hide()
    local art = alert:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints()
    art:SetAtlas(GLOW_ATLAS)
    local flip = alert:CreateAnimationGroup()
    flip:SetLooping("REPEAT")
    local book = flip:CreateAnimation("FlipBook")
    book:SetTarget(art)
    book:SetFlipBookRows(GLOW_ROWS)
    book:SetFlipBookColumns(GLOW_COLUMNS)
    book:SetFlipBookFrames(GLOW_FRAMES)
    book:SetFlipBookFrameWidth(0)
    book:SetFlipBookFrameHeight(0)
    book:SetDuration(GLOW_SECONDS)
    alert.art, alert.flip = art, flip
    icon.alert = alert
    icon:Hide()
    return icon
end

-- In combat: your own cast of an aspect (readable then). One that fixes the
-- problem dims the reminder to 0.4 and takes its outline away; one that
-- makes a problem (Pack; Cheetah in Normal) makes it solid and red again.
-- Neither is protected; it is never faded to 0, as it still takes clicks
-- (MTF 0.3.2's bug). Hidden, it stays hidden until combat ends.
local function AspectCast(name)
    local reminder = reminders.aspect
    if not reminder or not name or not reminders.upNames[reminder.key][name] then
        return
    end
    local icon = reminders.icons[reminder.key]
    if BadInCombat(reminder, name) then
        icon:SetAlpha(1)
        icon.glow:SetAlpha(1)
    else
        icon:SetAlpha(DIM_ALPHA)
        icon.glow:SetAlpha(0)
    end
end

-- Combat starts with a problem: the optional sound (Dyre's Sounds, its own
-- switch and choice).
local function CombatStarts()
    local saved = DBR.db.combatAspect
    local problem = reminders.aspectProblem
    if not problem or not saved.soundOn then
        return
    end
    local speech = reminders.aspectTravel and (reminders.aspectTravel .. " is up") or "No aspect up"
    local library = DBR.SoundLibrary()
    if library and not library.Play(saved.sound, speech) then
        library.Play(DBR.DEFAULT_CHIME_SOUND, speech)
    end
end

-- The preview speaks the Cheetah's name in the client's language, as the
-- combat start does; the English name when the client gives none.
local CHEETAH = 5118

function DBR.PreviewCombatAspect()
    local library = DBR.SoundLibrary()
    if library then
        local name = C_Spell.GetSpellName(CHEETAH)
        if type(name) ~= "string" or DBR.IsSecret(name) or name == "" then
            name = "Aspect of the Cheetah"
        end
        library.Play(DBR.db.combatAspect.sound, name .. " is up")
    end
end

-- The Aspect reminder's widget, for its own size settings (a Hunter's); nil without.
function DBR.AspectReminderWidget()
    local reminder = reminders.aspect
    return reminder and reminders.widgets[reminder.key] or nil
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

-- Whether the client has Blizzard's aura container (as the seal timer).
-- The engine's container (Forever), else AuraEngine.lua's plain-Lua one
-- (Classic Era and Anniversary, where AddOn code may read auras in combat;
-- author: "battle shout reminder doesn't drop when bs is applied in combat in
-- classic era"): the same slot over the same icon, so a buff cast or lost in
-- combat shows at once there too.
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
    -- Shown only when needed: "Visibility when not needed" while up; shown
    -- only in combat: transparent out of combat.
    local alpha = SlotAlpha(reminder)
    if alpha ~= 1 then
        layer:SetAlpha(alpha)
    end
    local container = DBR.CreateAuraContainer(layer)
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
    local aspect = reminder.combatAspect
    if not DBR.db.buffs[reminder.key].position then
        SeedFromBar(reminder, index, count)
    end
    local holder = CreateFrame("Frame", "DyresBuffRemindersBuff_" .. reminder.key, UIParent)
    local wrap = aspect and type(SecureHandlerWrapScript) == "function"
    local icon = CreateIcon(reminder, holder, nil,
        wrap and "SecureActionButtonTemplate, SecureHandlerStateTemplate" or nil)
    icon:SetAllPoints(holder)
    if wrap then
        -- A click hides it at once, also in combat (its cast fixes the
        -- problem); clicks on release only, so the cast comes first. Out of
        -- combat a refresh then shows it again if the cast failed.
        icon:RegisterForClicks("AnyUp")
        SecureHandlerWrapScript(icon, "OnClick", icon, "return nil, true", "self:Hide()")
        -- Shown and hidden by combat's edges and the out-of-combat refresh,
        -- never by a visibility driver (SetAspectShow).
        icon:SetAttribute("dbr-show", "never")
        icon:SetAttribute("_onstate-dbrcombat", ASPECT_ON_COMBAT)
        RegisterStateDriver(icon, "dbrcombat", ASPECT_COMBAT_DRIVER)
        icon:HookScript("OnClick", function()
            if not InCombatLockdown() then
                ScheduleRefresh()
            end
        end)
        icon.wrapped = true
    end
    reminders.icons[reminder.key] = icon
    reminders.widgets[reminder.key] = holder
    -- A pet has no aura for the slot to draw; the Aspect reminder shows only
    -- when there is a problem, so it has none either.
    if reminders.container and not reminder.pet and not aspect then
        holder.slot = CreateSlot(reminder, holder, icon)
        holder.slotAlpha = SlotAlpha(reminder)
        holder.warn = CreateWarn(holder, holder.slot)
    end
    DBR.toolkit.CreateWidget({
        addon = addonName, key = "buff_" .. reminder.key, title = reminder.label, frame = holder,
        store = DBR.db.buffs[reminder.key], width = ICON_SIZE, height = ICON_SIZE,
        point = DefaultPoint(reminder, row, index, count), sizes = DBR.WIDGET_SIZES,
    })
    -- The icon covers the widget: a drag that starts on it moves the widget.
    holder:AddDragHandle(icon)
end

-- In combat, a short buff (Buffs.lua's combatWindow, author: Battle Shout)
-- shows only while missing or within its lead. Its time is secret in combat,
-- so DBR times it: from the last out-of-combat read, reset by your own cast
-- (readable in combat), with one C_Timer to the window (no polling). Out of
-- the window its icon and slot are hidden or faint (SetAlpha is allowed in
-- combat on a secure button). A drop in combat cannot be seen (AddOns cannot
-- read buffs then), so it shows at the window time (author: accepted for
-- Battle Shout). It counts YOUR casts (author: "a helper to maintain YOUR
-- battle shout's up-time"). A hidden icon still takes clicks (it casts the
-- buff). Transparent until 2026-11-17, faint in 1.11.0, transparent again by
-- default (John, 2026-11-18). "Show buffs only when needed" (John,
-- 2026-11-17) used the same window for every buff (Windowed); since
-- 2026-11-18 each buff has its own switch, and all use db.faintPercent.

local function WindowAlpha(key, shown)
    local alpha = shown and 1 or FaintAlpha()
    -- Combat's end sets each one touched here solid again (EndWindows).
    reminders.faded[key] = true
    reminders.icons[key]:SetAlpha(alpha)
    local holder = reminders.widgets[key]
    if holder and holder.slot then
        holder.slot:SetAlpha(alpha)
    end
end

-- The lead is the buff's own (Battle Shout), else the shared share of its
-- length (duration, from the last read; else Buffs.lua's).
local function ScheduleWindow(reminder, expires, duration)
    local key = reminder.key
    local token = (reminders.windows[key] or 0) + 1
    reminders.windows[key] = token
    local due = expires - LeadSeconds(reminder, duration) - GetTime()
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
        if Windowed(reminder) and reminders.widgets[reminder.key] and reminders.container then
            list[#list + 1] = reminder
        end
    end
    return list
end

-- "Show only in combat" at combat's edges: the slot and the running-out
-- border (alpha only) show from its start and hide at its end. A buff also
-- shown only when needed gets its slot's alpha from its window instead.
local function CombatOnlyEdge()
    for _, reminder in ipairs(reminders.list) do
        local key = reminder.key
        if reminders.combatOnly[key] then
            SetWarn(key, reminders.warnOn[key])
            if not Windowed(reminder) then
                local holder = reminders.widgets[key]
                if holder then
                    SetSlotAlpha(holder, SlotAlpha(reminder))
                end
            end
        end
    end
end

-- Combat starts: up and outside its lead, faint until the
-- window. Missing, its end unknown, or a group member lacking it: in full.
local function StartWindows()
    CombatOnlyEdge()
    for _, reminder in ipairs(WindowReminders()) do
        local seen = reminders.seen[reminder.key]
        if seen and not reminders.icons[reminder.key].othersNeed then
            ScheduleWindow(reminder, seen.expires, seen.duration)
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
                -- A single-target cast leaves a group member who lacked it
                -- lacking: then it stays in full.
                if Windowed(reminder) and (kind == "group" or not icon.othersNeed) then
                    ScheduleWindow(reminder, expires, duration)
                end
            end
        end
    end
end

-- Combat ends: each icon faded in combat solid, its slot at "Visibility when
-- not needed" again while shown only when needed (out of combat the refresh decides). Also one
-- whose setting changed in combat.
local function EndWindows()
    CombatOnlyEdge()
    for _, reminder in ipairs(reminders.list) do
        if reminders.faded[reminder.key] then
            OpenWindow(reminder.key)
            reminders.faded[reminder.key] = nil
            local holder = reminders.widgets[reminder.key]
            holder.slotAlpha = nil
            SetSlotAlpha(holder, SlotAlpha(reminder))
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
    if reminders.aspect then
        -- The sound when combat starts with a problem.
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
    end
    reminders.ready = true
    if DBR.SetUpWarnings() then
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
    end
    -- Any buff with an aura slot can be shown only when needed (the setting
    -- can change later), so combat's start is always heard.
    if reminders.container then
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
    end
    -- "Show only in combat" shows its running-out border at combat's start.
    for _, reminder in ipairs(reminders.list) do
        if DBR.CanShowOnlyInCombat(reminder) then
            events:RegisterEvent("PLAYER_REGEN_DISABLED")
        end
    end
    for _, event in ipairs({"UNIT_AURA", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
        "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "BAG_UPDATE_DELAYED",
        "UPDATE_SHAPESHIFT_FORM", "PLAYER_ROLES_ASSIGNED", "ROLE_CHANGED_INFORM",
        -- Taking off and landing on a flight path (pinned LossOfControlDocumentation.lua:133-139).
        "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED"}) do
        events:RegisterEvent(event)
    end
    -- A restriction's end reads the auras again (the generic refresh below).
    if type(C_RestrictedActions) == "table" then
        events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    end
    for _, reminder in ipairs(reminders.list) do
        if reminder.tank then
            for _, event in ipairs(TANK_EVENTS) do
                events:RegisterEvent(event)
            end
        end
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    for _, reminder in ipairs(reminders.list) do
        if reminder.pet then
            -- The pet came or went: the click (Revive Pet) and the sacrifice.
            events:RegisterUnitEvent("UNIT_PET", "player")
        end
    end
    DBR.RefreshReminders()
end

events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        RememberCast(spellID)
        if InCombatLockdown() and not DBR.IsSecret(spellID) then
            local name = C_Spell.GetSpellName(spellID)
            AspectCast(name)
            OwnCast(name)
        end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        reminders.combat = true
        StartWindows()
        CombatStarts()
        DBR.WarningsAtCombat()
        return
    end
    if UNIT_EVENTS[event] and (DBR.IsSecret(unit) or not GroupUnit(unit)) then
        return
    end
    if InCombatLockdown() then
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        reminders.combat = nil
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
    if RECHECK_EVENTS[event] then
        ScheduleRecheck()
    end
end)

-- Warnings, on screen ------------------------------------------------------------------

-- A short message near the top of the screen that fades, as Dyre's Crit
-- Mayhem's record pop does (its Records.lua: a gold title over a line, held,
-- then faded by an Alpha animation; copied as a pattern, DBR does not need
-- DCM). It takes no mouse, so it is no popup and fine in combat. A Dyre's
-- Toolkit widget, so it can be moved and sized; unlocked, a sample shows.
local WARNING_GAP = 30
local POP_WIDTH, POP_HEIGHT = 420, 58
local POP_PLACE = {point = "CENTER", relativePoint = "CENTER", x = 0, y = 300}
local POP_HOLD, POP_FADE = 4, 1.5
local warnings = {list = {}, state = {}}

-- Whether Dyre's Toolkit owns the Pet Taunt warning. Also with its switch
-- off: the toolkit keeps its claim (off means off). A toolkit before 2.9.0
-- has no Owners or no claim, so DBR's copy works.
function DBR.ToolkitOwnsPetTaunt()
    local toolkit = DBR.toolkit
    return type(toolkit) == "table" and type(toolkit.KindOwner) == "function"
        and toolkit.KindOwner(DBR.PET_TAUNT_KIND) == DBR.PET_TAUNT_OWNER
end

local function Yields(warning)
    return warning.kind == "petTaunt" and DBR.ToolkitOwnsPetTaunt()
end

local function AnyWarningLive()
    for _, warning in ipairs(warnings.list) do
        if not Yields(warning) then
            return true
        end
    end
    return false
end

local function BuildPop()
    local frame = CreateFrame("Frame", "DyresBuffRemindersWarning", UIParent)
    frame:SetFrameStrata("HIGH")
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    content:Hide()
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", content, "TOP", 0, -2)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local line = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    line:SetPoint("TOP", title, "BOTTOM", 0, -4)
    local fader = content:CreateAnimationGroup()
    local fade = fader:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetStartDelay(POP_HOLD)
    fade:SetDuration(POP_FADE)
    fader:SetScript("OnFinished", function() content:Hide() end)
    warnings.pop = {frame = frame, content = content, title = title, line = line, fader = fader}
    local pop = warnings.pop
    DBR.toolkit.CreateWidget({
        addon = addonName, key = "warnings", title = "Warning messages", frame = frame, store = DBR.db.warningPop,
        width = POP_WIDTH, height = POP_HEIGHT, point = POP_PLACE, sizes = {scale = true},
        onUnlock = function(_, unlocked)
            if unlocked and AnyWarningLive() then
                pop.fader:Stop()
                pop.title:SetText("Pet taunt on")
                pop.line:SetText("Growl is on autocast in a group. Turn it off.")
                pop.content:SetAlpha(1)
                pop.content:Show()
            elseif not pop.fader:IsPlaying() then
                pop.content:Hide()
            end
        end,
    })
end

local function ShowPop(title, line)
    local pop = warnings.pop
    pop.title:SetText(title)
    pop.line:SetText(line)
    pop.fader:Stop()
    pop.content:SetAlpha(1)
    pop.content:Show()
    pop.fader:Play()
end

local function KnownBy(warning)
    for _, id in ipairs(warning.knownBy) do
        if Knows(id) then
            return true
        end
    end
    return false
end

-- A warning's message while it applies (in a group where you are not the
-- designated tank), as a title and a line; else nil. Out of combat only.
local function WarningText(warning)
    if not DBR.db.enabled or not DBR.db.warnings[warning.key] or Yields(warning) or not KnownBy(warning) then
        return nil
    end
    if not IsInGroup() or DesignatedTank() then
        return nil
    end
    if warning.kind == "fury" then
        local name = not DBR.db.alwaysShow.righteousFury and FuryUp(warning)
        if name then
            return name .. " is on", "You're not the tank. Turn it off."
        end
        return nil
    end
    local on = TauntsOn(warning)
    if #on > 0 then
        return "Pet taunt on", table.concat(on, " and ") .. (#on > 1 and " are" or " is")
            .. " on autocast in a group. Turn it off."
    end
end

-- On screen and in chat, at most once per WARNING_GAP seconds per warning.
local function Announce(warning, state)
    if GetTime() - (state.shown or -math.huge) < WARNING_GAP then
        return
    end
    state.shown = GetTime()
    ShowPop(state.title, state.line)
    DBR.Report(state.title .. ": " .. state.line)
end

-- With each refresh (out of combat): a warning shows when it becomes true
-- (joining a group, a role change, the buff gained, autocast turned on, the
-- pet summoned) or its message changes; never again while nothing changes.
function DBR.CheckWarnings()
    for _, warning in ipairs(warnings.list) do
        local state = warnings.state[warning.key]
        local title, line = WarningText(warning)
        local text = title and (title .. "\n" .. line) or nil
        local changed = text ~= nil and text ~= state.text
        state.title, state.line, state.text = title, line, text
        if changed then
            Announce(warning, state)
        end
    end
end

-- Combat starts: once more for each still true.
function DBR.WarningsAtCombat()
    for _, warning in ipairs(warnings.list) do
        local state = warnings.state[warning.key]
        if state.text then
            Announce(warning, state)
        end
    end
end

-- Out of combat, at setup: the class's warnings and their message box.
-- Returns whether there are any.
function DBR.SetUpWarnings()
    warnings.list = DBR.ClassWarnings()
    if #warnings.list == 0 then
        return false
    end
    for _, warning in ipairs(warnings.list) do
        warnings.state[warning.key] = {}
        if warning.kind == "petTaunt" then
            -- The pet came or went, or a pet spell's autocast turned on or off.
            events:RegisterUnitEvent("UNIT_PET", "player")
            events:RegisterEvent("PET_BAR_UPDATE")
        end
    end
    -- The toolkit can claim the Pet Taunt warning after DBR's login.
    if type(DBR.toolkit.OnOwnerChanged) == "function" then
        DBR.toolkit.OnOwnerChanged(DBR.PET_TAUNT_KIND, ScheduleRefresh)
    end
    BuildPop()
    return true
end

function DBR.ClassWarnings()
    return DBR.WARNINGS[DBR.classFile] or {}
end

function DBR.ReportWarningsDebug()
    for _, warning in ipairs(warnings.list) do
        local state = warnings.state[warning.key]
        DBR.Report(string.format("debug warning %s on=%s known=%s toolkit=%s now=%s", warning.key,
            tostring(DBR.db.warnings[warning.key]), tostring(KnownBy(warning)), tostring(Yields(warning)),
            state.text and (state.title .. ": " .. state.line) or "none"))
    end
end

function DBR.InitializeReminders(class)
    reminders.list = DBR.BUFFS[class] or {}
    for _, reminder in ipairs(reminders.list) do
        reminders.names[reminder.key] = BuffNames(reminder)
        local up = {}
        for _, name in ipairs(reminders.names[reminder.key]) do
            up[name] = true
        end
        reminders.upNames[reminder.key] = up
        if reminder.combatAspect then
            reminders.aspect = reminder
            local travel, speed = {}, {}
            for _, id in ipairs(reminder.forget or {}) do
                local name = C_Spell.GetSpellName(id)
                if name then
                    travel[name] = true
                end
            end
            for _, id in ipairs(reminder.speedOk or {}) do
                local name = C_Spell.GetSpellName(id)
                if name then
                    speed[name] = true
                end
            end
            reminders.travelNames[reminder.key], reminders.speedNames[reminder.key] = travel, speed
        end
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

-- The buff widgets that share the reminder icons' size, for the settings
-- page, in Buffs.lua's order (the Aspect reminder has its own).
function DBR.BuffWidgets()
    local list = {}
    for _, reminder in ipairs(reminders.list) do
        local holder = reminders.widgets[reminder.key]
        if holder and not reminder.combatAspect then
            list[#list + 1] = holder
        end
    end
    return list
end


-- Whether the buff widgets have the aura container (in-combat display).
function DBR.HasBuffSlots()
    return reminders.container == true
end

local function ReportAspectReminderDebug()
    local reminder = reminders.aspect
    local icon = reminder and reminders.icons[reminder.key]
    if icon then
        DBR.Report(string.format("debug aspectReminder mode=%s state=%s problem=%s driver=%s macro=%s sound=%s",
            tostring(DBR.db.aspectMode), tostring(reminders.aspectState), tostring(reminders.aspectProblem),
            tostring(icon.driver), tostring(icon:GetAttribute("macrotext1")),
            DBR.db.combatAspect.soundOn and tostring(DBR.db.combatAspect.sound) or "off"))
    end
end

-- /dbr debug: each reminder, whether you know it, who lacks it, and the click.
-- IDs the client does not know (no name) are listed, to check Buffs.lua.
-- /dbr debug: what each of the buff's names reads on you, so a client that
-- fills an aura differently shows it (found, its spell ID, time left, length).
local function ReportAuraReads(reminder)
    local parts = {}
    for _, name in ipairs(reminders.names[reminder.key] or {}) do
        local aura = C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
        local text = "none"
        if DBR.IsSecret(aura) then
            text = "secret"
        elseif aura ~= nil then
            local left = TimeLeft(aura)
            text = string.format("found(id=%s left=%s dur=%s)", DBR.Describe(aura.spellId),
                left and string.format("%d", left) or "none", DBR.Describe(aura.duration))
        end
        parts[#parts + 1] = name .. "=" .. text
    end
    local state, expires = BuffState("player", reminder)
    DBR.Report(string.format("debug aura %s state=%s expires=%s %s", reminder.key, tostring(state),
        expires and string.format("%d", expires - GetTime()) or "none", table.concat(parts, " ")))
end

-- Every restriction type the client has, so a paste shows which was on.
local function RestrictionsLine()
    if type(C_RestrictedActions) ~= "table" or type(C_RestrictedActions.IsAddOnRestrictionActive) ~= "function"
        or type(Enum) ~= "table" or type(Enum.AddOnRestrictionType) ~= "table" then
        return "debug restrictions none (no C_RestrictedActions)"
    end
    local names = {}
    for name in pairs(Enum.AddOnRestrictionType) do
        names[#names + 1] = name
    end
    table.sort(names)
    local parts = {}
    for _, name in ipairs(names) do
        local active = C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType[name])
        parts[#parts + 1] = name .. "=" .. DBR.Describe(active)
    end
    return string.format("debug restrictions %s auraHidden=%s", table.concat(parts, " "),
        tostring(DBR.AuraRestriction()))
end

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
        if reminder.pet then
            local exists = UnitExists("pet")
            missing = "pet=" .. DBR.Describe(exists) .. " sacrificed=" .. tostring(Sacrificed(reminder))
        elseif DBR.AuraRestriction() then
            missing = "not checked during " .. DBR.AuraRestriction()
        elseif not InCombatLockdown() then
            missing = table.concat(MissingNames(Missing(reminder)), ",")
        end
        local action = icon and icon.action
        DBR.Report(string.format("debug %s row=%s on=%s group=%s known=%s shown=%s missing=%s click=%s "
            .. "unknownIDs=%s last=%s", reminder.key, BarKey(reminder), tostring(DBR.db.spells[reminder.key]), tostring(DBR.db.groups[reminder.key]),
            tostring(Known(reminder)), tostring(icon and icon:IsShown()), missing,
            action and (tostring(action.cast) .. "@" .. tostring(action.unit)) or "none",
            #unknown > 0 and table.concat(unknown, ",") or "none", tostring(DBR.db.last[reminder.key])))
        if not reminder.pet and not InCombatLockdown() then
            ReportAuraReads(reminder)
        end
    end
    DBR.Report(string.format("debug missing style=%s glowArt=%s", tostring(DBR.db.missingStyle),
        tostring(DBR.GlowArt())))
    DBR.Report(RestrictionsLine())
    ReportAspectReminderDebug()
    DBR.ReportWarningsDebug()
end
