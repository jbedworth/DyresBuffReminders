local _, DBR = ...

-- One settings page in Blizzard's vertical layout, with proxy settings that
-- read and write DyresBuffRemindersDB directly, in two sections: the buff
-- reminders, then the cooldown chimes (author-approved: Dyre's Cooldown
-- Chimes merged into DBR, with its own switch). Only your class's buffs and
-- chime spells show; each spell's sound sits in a dropdown under its switch.
local TITLE = "Dyre's Buff Reminders"
local UNAVAILABLE = "The AddOn settings page is unavailable on this client. Use /dbr unlock, /dbr lock, "
    .. "and /dbr reset."

local REQUIRED_SETTINGS = {
    "RegisterVerticalLayoutCategory", "RegisterProxySetting", "RegisterAddOnCategory", "CreateCheckbox",
    "CreateSlider", "CreateSliderOptions", "OpenToCategory",
}

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

-- One chime spell: its switch under the chimes' switch, and its sound under
-- it when Dyre's Sounds is installed.
local function AddChime(chime, library, chimesSwitch)
    local variable = "DBR_CHIME_" .. chime.key:upper()
    local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, chime.label,
        chime.on,
        function() return DBR.db.chimes.spells[chime.key] end,
        function(value) DBR.db.chimes.spells[chime.key] = value == true end)
    local switch = Settings.CreateCheckbox(category, setting, "Play a sound just before " .. chime.label
        .. " is ready again.")
    Nest(switch, chimesSwitch, function() return DBR.db.chimes.enabled end)
    if not library or type(Settings.CreateDropdown) ~= "function" then
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
    local dropdown = Settings.CreateDropdown(category, sound, library.Choices(),
        "The sound for " .. chime.label .. ". Choosing one plays it once. Text to Speech says \""
            .. chime.label .. " ready\".")
    library.SetupMenu(dropdown)
    Nest(dropdown, switch, function() return DBR.db.chimes.enabled and DBR.db.chimes.spells[chime.key] end)
end

-- The cooldown chimes section: its own switch, the lead, then your class's spells.
local function AddChimesSection()
    local library = DBR.SoundLibrary()
    Heading("Cooldown Chimes")
    local tooltip = "A sound just before your chosen spells are ready again, also in combat. Every rank of a "
        .. "spell counts."
    if not library then
        tooltip = tooltip .. " Install Dyre's Sounds to hear them and to choose each spell's sound."
    end
    local chimesSwitch = Flag("DBR_CHIMES_ENABLED", "Cooldown chimes", "chimes", "enabled", true, tooltip,
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
    category, layout = Settings.RegisterVerticalLayoutCategory(TITLE)
    Heading("Buff Reminders")
    local master = Flag("DBR_ENABLED", "Buff reminders", nil, "enabled", true,
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
    local unlocked = Settings.RegisterProxySetting(category, "DBR_UNLOCKED", Settings.VarType.Boolean,
        "Unlock to move them", false,
        function() return not DBR.db.locked end,
        function(value) DBR.SetLocked(value ~= true) end)
    Settings.CreateCheckbox(category, unlocked,
        "Outline every buff reminder so you can drag it, and scroll over one to resize it; untick to lock them "
            .. "again. Drop one near another and it snaps beside it. /dbr unlock and /dbr lock do the same, and "
            .. "/dbr reset moves them back to their default places.")
    Flag("DBR_GRID", "Show a grid while unlocked", nil, "grid", true,
        "While the reminders are unlocked, draw a faint grid over the screen with the center lines in red, "
            .. "so you can line them up.", DBR.RefreshGrid)
    AddChimesSection()
    Settings.RegisterAddOnCategory(category)
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
    Settings.OpenToCategory(category:GetID())
end
