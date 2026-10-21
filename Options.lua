local _, DBR = ...

-- One settings page under Dyre's Toolkit's "Dyre's AddOns", in Blizzard's
-- vertical layout, with proxy settings that read and write
-- DyresBuffRemindersDB directly: the buff reminders, each widget's size and
-- opacity (the toolkit's sliders), then the cooldown chimes (author-approved:
-- Dyre's Cooldown Chimes merged into DBR, with its own switch) and the proc
-- sounds. Only your class's buffs and spells show.
local TITLE = "Dyre's Buff Reminders"
local UNAVAILABLE = "The AddOn settings page is unavailable on this client. Use /dbr unlock, /dbr lock, "
    .. "and /dbr reset."

local REQUIRED_SETTINGS = {
    "RegisterProxySetting", "CreateCheckbox", "CreateSlider", "CreateSliderOptions", "OpenToCategory",
}
local BAR_TITLES = {groupbuffs = "Group buffs", mybuffs = "My buffs"}

local NO_CHIME_SPELLS = "Your class has no chime spells yet."

local category, layout

local function HasSettingsAPI()
    if type(Settings) ~= "table" or type(Settings.VarType) ~= "table" then
        return false
    end
    for _, name in ipairs(REQUIRED_SETTINGS) do
        if type(Settings[name]) ~= "function" then
            return false
        end
    end
    return true
end

-- A checkbox for db[group][key] (or db[key] without a group); onChange runs
-- after the value is stored.
local function Flag(variable, name, group, key, default, tooltip, onChange)
    local function Table()
        return group and DBR.db[group] or DBR.db
    end
    local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, name, default,
        function() return Table()[key] end,
        function(value)
            Table()[key] = value == true
            onChange()
        end)
    return Settings.CreateCheckbox(category, setting, tooltip)
end

local function Nest(child, parent, predicate)
    if type(child.SetParentInitializer) == "function" then
        child:SetParentInitializer(parent, predicate)
    end
end

local function SliderOptions(minValue, maxValue, step)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end
    return options
end

-- A section heading, where the client offers them.
local function Heading(text)
    if type(CreateSettingsListSectionHeaderInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

-- Blizzard's checkbox-and-dropdown row, with Dyre's Sounds' nested menu in it
-- (SetupCheckboxMenu, from Dyre's Sounds 0.1.2-beta), when both are there.
local function HasCheckboxDropdown(library)
    return type(CreateSettingsCheckboxDropdownInitializer) == "function" and type(layout) == "table"
        and type(layout.AddInitializer) == "function" and type(library.SetupCheckboxMenu) == "function"
end

-- One chime spell under the chimes' switch: its switch and, when Dyre's Sounds
-- is installed, its sound on the same row (author-approved: one row per
-- spell; Blizzard's control greys the sound while the switch is off). With an
-- older Dyre's Sounds or client, the sound sits on its own row under the
-- switch. The settings and their saved keys are the same either way.
local function AddChime(chime, library, chimesSwitch)
    local variable = "DBR_CHIME_" .. chime.key:upper()
    local tooltip = "Play a sound just before " .. chime.label .. " is ready again."
    local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, chime.label,
        chime.on,
        function() return DBR.db.chimes.spells[chime.key] end,
        function(value) DBR.db.chimes.spells[chime.key] = value == true end)
    local function ChimesOn() return DBR.db.chimes.enabled end
    if not library or (type(Settings.CreateDropdown) ~= "function" and not HasCheckboxDropdown(library)) then
        Nest(Settings.CreateCheckbox(category, setting, tooltip), chimesSwitch, ChimesOn)
        return
    end
    local sound = Settings.RegisterProxySetting(category, variable .. "_SOUND", Settings.VarType.String, "Sound",
        chime.sound or DBR.DEFAULT_CHIME_SOUND,
        function() return DBR.db.chimes.sounds[chime.key] end,
        function(value)
            local key = library.Resolve(value)
            if key then
                DBR.db.chimes.sounds[chime.key] = key
                DBR.PreviewChime(chime.key)
            end
        end)
    local soundTooltip = "The sound for " .. chime.label .. ". Choosing one plays it once. Text to Speech says \""
        .. chime.label .. " ready\"."
    if HasCheckboxDropdown(library) then
        local row = CreateSettingsCheckboxDropdownInitializer(setting, chime.label, tooltip, sound,
            library.Choices(), "Sound", soundTooltip)
        layout:AddInitializer(row)
        library.SetupCheckboxMenu(row)
        Nest(row, chimesSwitch, ChimesOn)
        return
    end
    local switch = Settings.CreateCheckbox(category, setting, tooltip)
    Nest(switch, chimesSwitch, ChimesOn)
    local dropdown = Settings.CreateDropdown(category, sound, library.Choices(), soundTooltip)
    library.SetupMenu(dropdown)
    Nest(dropdown, switch, function() return DBR.db.chimes.enabled and DBR.db.chimes.spells[chime.key] end)
end

-- One proc under the procs' switch: its switch and its sound (aura sounds
-- only, the files the game can play for a buff) on one row, or two rows with
-- an older Dyre's Sounds or client. The settings and saved keys are the same.
local function AddProc(proc, library, procsSwitch)
    local variable = "DBR_PROC_" .. proc.key:upper()
    local tooltip = "Play a sound the moment " .. proc.buff .. " appears on you, also in combat."
    local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, proc.label, proc.on,
        function() return DBR.db.procs.spells[proc.key] end,
        function(value)
            DBR.db.procs.spells[proc.key] = value == true
            DBR.ApplyProcSounds()
        end)
    local function ProcsOn() return DBR.db.procs.enabled end
    if not library or (type(Settings.CreateDropdown) ~= "function" and not HasCheckboxDropdown(library)) then
        Nest(Settings.CreateCheckbox(category, setting, tooltip), procsSwitch, ProcsOn)
        return
    end
    local sound = Settings.RegisterProxySetting(category, variable .. "_SOUND", Settings.VarType.String, "Sound",
        proc.sound or DBR.DEFAULT_PROC_SOUND,
        function() return DBR.db.procs.sounds[proc.key] end,
        function(value)
            local key = library.Resolve(value)
            if key and library.AuraSound(key) then
                DBR.db.procs.sounds[proc.key] = key
                DBR.ApplyProcSounds()
                DBR.PreviewProc(proc.key)
            end
        end)
    local soundTooltip = "The sound for " .. proc.label .. ". Choosing one plays it once. Only sounds the game "
        .. "can play for a buff are listed."
    if HasCheckboxDropdown(library) then
        local row = CreateSettingsCheckboxDropdownInitializer(setting, proc.label, tooltip, sound,
            library.Choices("aura"), "Sound", soundTooltip)
        layout:AddInitializer(row)
        library.SetupCheckboxMenu(row, "aura")
        Nest(row, procsSwitch, ProcsOn)
        return
    end
    local switch = Settings.CreateCheckbox(category, setting, tooltip)
    Nest(switch, procsSwitch, ProcsOn)
    local dropdown = Settings.CreateDropdown(category, sound, library.Choices("aura"), soundTooltip)
    library.SetupMenu(dropdown, "aura")
    Nest(dropdown, switch, function() return DBR.db.procs.enabled and DBR.db.procs.spells[proc.key] end)
end

-- The proc sounds section, for a class with procs on a client that can play them.
local function AddProcsSection()
    local spells = DBR.ClassProcs(DBR.classFile)
    if #spells == 0 or not DBR.HasProcSounds() then
        return
    end
    local library = DBR.SoundLibrary()
    Heading("Procs")
    local tooltip = "A sound the moment a proc appears on you (Clearcasting, Nightfall, and so on), also in "
        .. "combat. The game plays it, from a sound you choose."
    if not library then
        tooltip = tooltip .. " Install Dyre's Sounds to hear them and to choose each proc's sound."
    end
    local procsSwitch = Flag("DBR_PROCS_ENABLED", "Enable", "procs", "enabled", true, tooltip,
        DBR.ApplyProcSounds)
    for _, proc in ipairs(spells) do
        AddProc(proc, library, procsSwitch)
    end
end

-- The cooldown chimes section: its own switch, the lead, then your class's spells.
local function AddChimesSection()
    local library = DBR.SoundLibrary()
    Heading("Chimes")
    local tooltip = "A sound just before your chosen spells are ready again, also in combat. Every rank of a "
        .. "spell counts."
    if not library then
        tooltip = tooltip .. " Install Dyre's Sounds to hear them and to choose each spell's sound."
    end
    local chimesSwitch = Flag("DBR_CHIMES_ENABLED", "Enable", "chimes", "enabled", true, tooltip,
        function() end)
    local lead = Settings.RegisterProxySetting(category, "DBR_CHIME_LEAD", Settings.VarType.Number,
        "Chime early (seconds)", DBR.DEFAULT_CHIME_LEAD,
        function() return DBR.db.chimes.lead end,
        function(value) DBR.db.chimes.lead = DBR.SanitizeChimeLead(value) end)
    local leadSlider = Settings.CreateSlider(category, lead,
        SliderOptions(DBR.CHIME_LEAD_MIN, DBR.CHIME_LEAD_MAX, DBR.CHIME_LEAD_STEP),
        "How long before a cooldown ends the chime plays, so you can act the moment it is ready.")
    Nest(leadSlider, chimesSwitch, function() return DBR.db.chimes.enabled end)
    local spells = DBR.ClassChimes(DBR.classFile)
    if #spells == 0 then
        Heading(NO_CHIME_SPELLS)
    end
    for _, chime in ipairs(spells) do
        AddChime(chime, library, chimesSwitch)
    end
end

-- Each widget's Size and Opacity, then "Reset size" (Dyre's Toolkit's
-- sliders, with a gold mark at the default). Moving them is the toolkit's
-- unlock: /dbr unlock, /dyre unlock, or "Unlock frames" on Dyre's AddOns.
local function AddSizesSection()
    local rows = {}
    for _, bar in ipairs(DBR.ReminderBars()) do
        rows[#rows + 1] = {widget = bar.widget, title = BAR_TITLES[bar.key]}
    end
    local consumables = DBR.ConsumablesWidget()
    if consumables then
        rows[#rows + 1] = {widget = consumables, title = "Consumables"}
    end
    local sealWidget = DBR.SealWidget()
    if sealWidget then
        rows[#rows + 1] = {widget = sealWidget, title = "Seal timer"}
    end
    if #rows == 0 then
        return
    end
    Heading("Size and Opacity")
    for _, row in ipairs(rows) do
        DBR.toolkit.AddWidgetSettings(category, layout, row.widget, {
            labels = {scale = row.title .. ": size (%)", opacity = row.title .. ": opacity"},
        })
    end
end

-- A Hunter's combat aspect button, under the Aspect switch, then its sound at
-- combat start (its own switch and choice, Dyre's Sounds) on one row, or two
-- with an older Dyre's Sounds or client, or the switch alone without it.
local function AddCombatAspect(aspectSwitch, key)
    local combat = Flag("DBR_COMBAT_ASPECT", "Combat aspect reminder", "combatAspect", "enabled", true,
        "When combat starts with Aspect of the Cheetah or the Pack up, show the combat aspect a click casts "
            .. "(your last, else Hawk, else Monkey). It is set up out of combat, so the game shows it the moment "
            .. "the fight starts.", DBR.RefreshReminders)
    -- Listed under Aspect, but its own switch: it works with the Aspect reminder off.
    Nest(combat, aspectSwitch, function() return DBR.db.enabled end)
    local function CombatOn()
        return DBR.db.enabled and DBR.db.combatAspect.enabled
    end
    local saved = DBR.db.combatAspect
    local label, tooltip = "Sound at combat start", "Play a sound when combat starts with Aspect of the "
        .. "Cheetah or the Pack up."
    local setting = Settings.RegisterProxySetting(category, "DBR_COMBAT_ASPECT_SOUND_ON", Settings.VarType.Boolean,
        label, true, function() return saved.soundOn end,
        function(value) saved.soundOn = value == true end)
    local library = DBR.SoundLibrary()
    if not library or (type(Settings.CreateDropdown) ~= "function" and not HasCheckboxDropdown(library)) then
        Nest(Settings.CreateCheckbox(category, setting, tooltip), combat, CombatOn)
        return
    end
    local sound = Settings.RegisterProxySetting(category, "DBR_COMBAT_ASPECT_SOUND", Settings.VarType.String, "Sound",
        DBR.DEFAULT_CHIME_SOUND, function() return saved.sound end,
        function(value)
            local resolved = library.Resolve(value)
            if resolved then
                saved.sound = resolved
                DBR.PreviewCombatAspect()
            end
        end)
    local soundTooltip = "The sound at combat start. Choosing one plays it once. Text to Speech says which aspect "
        .. "is up."
    if HasCheckboxDropdown(library) then
        local row = CreateSettingsCheckboxDropdownInitializer(setting, label, tooltip, sound, library.Choices(),
            "Sound", soundTooltip)
        layout:AddInitializer(row)
        library.SetupCheckboxMenu(row)
        Nest(row, combat, CombatOn)
        return
    end
    local switch = Settings.CreateCheckbox(category, setting, tooltip)
    Nest(switch, combat, CombatOn)
    local dropdown = Settings.CreateDropdown(category, sound, library.Choices(), soundTooltip)
    library.SetupMenu(dropdown)
    Nest(dropdown, switch, function() return CombatOn() and saved.soundOn end)
end

-- Consumables (Part B): Enable, then Ammo and its Warn at.
local function AddConsumablesSection()
    Heading("Consumables")
    local saved = DBR.db.consumables
    local master = Flag("DBR_CONSUMABLES_ENABLED", "Enable", "consumables", "enabled", true,
        "Show what your class's abilities use up, also in combat: for now, your ammo.", DBR.RefreshConsumables)
    local ammoSwitch = Flag("DBR_CONSUMABLE_AMMO", "Ammo", "consumables", "ammo", true,
        "With a bow, crossbow, or gun in your ranged slot: your equipped arrows or bullets and how many are left. "
            .. "The count turns red and pulses at or below Warn at; out of ammo, or none equipped, it shows as "
            .. "missing.", DBR.RefreshConsumables)
    Nest(ammoSwitch, master, function() return saved.enabled end)
    local warn = Settings.RegisterProxySetting(category, "DBR_AMMO_WARN", Settings.VarType.Number, "Warn at",
        DBR.DEFAULT_AMMO_WARN, function() return saved.ammoWarn end,
        function(value)
            saved.ammoWarn = DBR.SanitizeAmmoWarn(value)
            DBR.RefreshConsumables()
        end)
    local slider = Settings.CreateSlider(category, warn,
        SliderOptions(DBR.AMMO_WARN_MIN, DBR.AMMO_WARN_MAX, DBR.AMMO_WARN_STEP),
        "The ammo count that turns red and pulses.")
    Nest(slider, ammoSwitch, function() return saved.enabled and saved.ammo end)
end

local function GroupTooltip(reminder)
    local who = reminder.group.mana and "party or raid member who uses mana" or "party or raid member"
    local versions = {}
    for _, entry in ipairs(reminder.group.spells) do
        local name = C_Spell.GetSpellName(entry.spell)
        if name and versions[#versions] ~= name then
            versions[#versions + 1] = name
        end
    end
    local text = "Also remind you when a " .. who .. " lacks " .. reminder.label
        .. ". The icon shows how many, and its tooltip who."
    if #versions > 0 then
        text = text .. " With two or more missing, a click casts " .. versions[1]
            .. " if you know it and carry its reagent."
    end
    return text
end

function DBR.InitializeOptions()
    if not HasSettingsAPI() then
        return
    end
    category, layout = DBR.toolkit.RegisterSettingsCategory(TITLE)
    if not category then
        return
    end
    Heading("Reminders")
    local master = Flag("DBR_ENABLED", "Enable", nil, "enabled", true,
        "An icon with a pulsing border for each buff you lack, out of combat. Click it to cast the buff.",
        function()
            DBR.RefreshReminders()
            DBR.RefreshSeal()
        end)
    local function Enabled() return DBR.db.enabled end
    for _, reminder in ipairs(DBR.ClassReminders()) do
        local key = reminder.key
        local buff = Flag("DBR_BUFF_" .. key:upper(), reminder.label, "spells", key, reminder.on,
            "Show an icon with a pulsing border while you lack " .. reminder.label .. ", out of combat.",
            DBR.RefreshReminders)
        Nest(buff, master, Enabled)
        if reminder.group then
            local group = Flag("DBR_GROUP_" .. key:upper(), reminder.label .. ": also your group", "groups", key,
                true, GroupTooltip(reminder), DBR.RefreshReminders)
            Nest(group, buff, function() return DBR.db.enabled and DBR.db.spells[key] end)
        end
        if reminder.combatAspect and DBR.CombatAspectWidget() then
            AddCombatAspect(buff, key)
        end
    end
    if DBR.HasSealTimer() then
        local sealSwitch = Flag("DBR_SEAL", "Seal timer", "seal", "enabled", true,
            "While a seal is up, its icon with the time left. In combat with no seal up, your last seal "
                .. "pulses; click it to cast that seal. Out of combat with no seal up, nothing shows.",
            DBR.RefreshSeal)
        Nest(sealSwitch, master, Enabled)
    end
    local lead = Settings.RegisterProxySetting(category, "DBR_LEAD", Settings.VarType.Number,
        "Remind before a buff runs out (seconds)", DBR.DEFAULT_LEAD,
        function() return DBR.db.lead end,
        function(value)
            DBR.db.lead = DBR.SanitizeLead(value)
            DBR.RefreshReminders()
        end)
    local leadSlider = Settings.CreateSlider(category, lead, SliderOptions(DBR.LEAD_MIN, DBR.LEAD_MAX, 1),
        "Show the icon this many seconds before a buff on you or your group runs out, so you can recast it in "
            .. "time. 0 shows it when the buff is gone. Out of combat only: a buff that runs out in a fight "
            .. "shows after it.")
    Nest(leadSlider, master, Enabled)
    AddConsumablesSection()
    AddSizesSection()
    AddChimesSection()
    AddProcsSection()
end

function DBR.OpenSettings()
    if not category then
        DBR.Report(UNAVAILABLE)
        return
    end
    -- No panels in combat.
    if InCombatLockdown() then
        DBR.Report("The settings open out of combat. Type /dbr again when the fight is over.")
        return
    end
    DBR.toolkit.OpenSettings(category)
end
