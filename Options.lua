local _, DBR = ...

-- One settings page in Blizzard's vertical layout, with proxy settings that
-- read and write DyresBuffRemindersDB directly. Only your class's buffs show.
local TITLE = "Dyre's Buff Reminders"
local UNAVAILABLE = "The AddOn settings page is unavailable on this client. Use /dbr unlock, /dbr lock, "
    .. "and /dbr reset."

local REQUIRED_SETTINGS = {
    "RegisterVerticalLayoutCategory", "RegisterProxySetting", "RegisterAddOnCategory", "CreateCheckbox",
    "CreateSlider", "CreateSliderOptions", "OpenToCategory",
}

local category

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
    category = Settings.RegisterVerticalLayoutCategory(TITLE)
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
