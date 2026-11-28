local addonName, DBR = ...

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

local NO_CHIME_SPELLS = "Your class has no chime spells yet."

local category, layout
-- The page being built: its context (Dyre's Toolkit 2.17.0's settings
-- sections) and the setting variable for a name. On a host's page (Mage or
-- Warlock Tools Forever) every variable gets the host's prefix, as Blizzard
-- refuses a variable registered twice; on DBR's own page names stay.
local page
local function Var(name)
    return page and page.variable(name) or name
end

-- Blizzard re-checks a row's greying only when its direct parent's setting
-- changes (Blizzard_SettingControls.lua, SettingsListElementMixin:Init and
-- OnParentSettingValueChanged), so a grandchild stayed bright with Enable off
-- (John, 2026-11-27: "This one only disables some"). Each row's predicate
-- checks its whole chain; and when a switch changes, every row under it that
-- has rows of its own is notified too, so theirs re-check, down the tree.
local parentRows, childRows = {}, {}

local function RowVariable(row)
    local data = type(row.GetData) == "function" and row:GetData() or row.data
    local setting = type(data) == "table" and (data.setting or data.cbSetting) or row.setting
    if type(setting) ~= "table" then
        return nil
    end
    if type(setting.GetVariable) == "function" then
        return setting:GetVariable()
    end
    return setting.variable
end

local function Cascade(row)
    for _, child in ipairs(childRows[row] or {}) do
        if childRows[child] then
            local variable = RowVariable(child)
            if variable and type(Settings.NotifyUpdate) == "function" then
                Settings.NotifyUpdate(variable)
            end
            Cascade(child)
        end
    end
end

local function Register(variable, varType, name, default, getValue, setValue)
    local full = Var(variable)
    return Settings.RegisterProxySetting(category, full, varType, name, default, getValue, function(value)
        setValue(value)
        if parentRows[full] then
            Cascade(parentRows[full])
        end
    end)
end

-- The page's part (Toolkit settings sections 3): "all" (DBR's own page),
-- "master" (only the section's Enable, on a host's top page), or "rest"
-- (all but it, on the host's sub-page: rows under it are greyed while it is
-- off, though it is not on that page).
local function Part()
    return page and page.part or "all"
end

-- A section's Enable: "Enable" under its heading; on a host's top page (part
-- "master") the three sit together, so each names its feature (Toolkit lead,
-- 2026-11-27). Its tooltip is the same one sentence: the host's sub-page sits
-- right under it (John, 2026-11-27: "MTF - fix this one").
local function MasterLabel(name, tooltip)
    if Part() == "master" then
        return name, tooltip
    end
    return "Enable", tooltip
end

-- A section's filter (the host's, as given): nil shows every row of the
-- class; a list of keys (or one key) shows only those.
local function Wanted(filter, key)
    if type(filter) == "string" then
        return filter == key
    end
    if type(filter) ~= "table" then
        return true
    end
    for _, wanted in ipairs(filter) do
        if wanted == key then
            return true
        end
    end
    return false
end

local function Own()
    return not page or page.own ~= false
end

local function Picked(list, filter)
    local picked = {}
    for _, entry in ipairs(list) do
        if Wanted(filter, entry.key) then
            picked[#picked + 1] = entry
        end
    end
    return picked
end

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
    local setting = Register(variable, Settings.VarType.Boolean, name, default,
        function() return Table()[key] end,
        function(value)
            Table()[key] = value == true
            onChange()
        end)
    return Settings.CreateCheckbox(category, setting, tooltip)
end

-- Without a parent row, a row re-checks its predicate live when one of the
-- watched settings changes (Toolkit 2.17.0's WatchSettings: Blizzard's
-- AddEvaluateStateCVar, which takes any setting variable); names as given.
local function Watch(row, names)
    local toolkit = DBR.toolkit
    if type(toolkit) ~= "table" or type(toolkit.WatchSettings) ~= "function" then
        return
    end
    local variables = {}
    for _, name in ipairs(names) do
        variables[#variables + 1] = Var(name)
    end
    toolkit.WatchSettings(row, variables)
end

-- predicate checks the whole chain above the row (every switch, the
-- section's Enable included). Without the parent on this page (part "rest",
-- or a size row), the predicate alone greys it, re-checked live as watch
-- (a list of setting names) changes.
local function Nest(child, parent, predicate, watch)
    if type(child) ~= "table" then
        return
    end
    if parent and type(child.SetParentInitializer) == "function" then
        child:SetParentInitializer(parent, predicate)
        childRows[parent] = childRows[parent] or {}
        table.insert(childRows[parent], child)
        local variable = RowVariable(parent)
        if variable then
            parentRows[variable] = parent
        end
    elseif predicate and type(child.AddModifyPredicate) == "function" then
        child:AddModifyPredicate(predicate)
        if watch then
            Watch(child, watch)
        end
    end
end

-- The toolkit's size rows, greyed while modify gives false (Toolkit settings
-- sections 3; ignored before it).
local function WidgetSettings(widget, labels, modify, watch, skip)
    local variables = {}
    for _, name in ipairs(watch) do
        variables[#variables + 1] = Var(name)
    end
    DBR.toolkit.AddWidgetSettings(category, layout, widget, {labels = labels, modify = modify, variable = Var,
        watch = variables, skip = skip})
end

-- The value on the right; a percent slider shows it with "%" (author: "this
-- way, everything looks consistent"), as the toolkit's do. No end labels
-- (found in client: they crowded the next row).
local function SliderOptions(minValue, maxValue, step, percent)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
        local labels = MinimalSliderWithSteppersMixin.Label
        if percent then
            options:SetLabelFormatter(labels.Right, function(value) return string.format("%d%%", value) end)
        else
            options:SetLabelFormatter(labels.Right)
        end
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
-- A spell you have not learned is listed with its rows greyed (John,
-- 2026-11-27); its saved choices stay.
local function GreyUntilKnown(row, chime)
    if type(row) == "table" and type(row.AddModifyPredicate) == "function" then
        row:AddModifyPredicate(function() return DBR.ChimeKnown(chime) end)
    end
    return row
end

local function AddChime(chime, library, chimesSwitch)
    local variable = "DBR_CHIME_" .. chime.key:upper()
    local tooltip = "Play a sound just before " .. chime.label .. " is ready again."
    local setting = Register(variable, Settings.VarType.Boolean, chime.label,
        chime.on,
        function() return DBR.db.chimes.spells[chime.key] end,
        function(value) DBR.db.chimes.spells[chime.key] = value == true end)
    local function ChimesOn() return DBR.db.chimes.enabled end
    if not library or (type(Settings.CreateDropdown) ~= "function" and not HasCheckboxDropdown(library)) then
        Nest(GreyUntilKnown(Settings.CreateCheckbox(category, setting, tooltip), chime), chimesSwitch, ChimesOn,
            {"DBR_CHIMES_ENABLED"})
        return
    end
    local sound = Register(variable .. "_SOUND", Settings.VarType.String, "Sound",
        chime.sound or DBR.DEFAULT_CHIME_SOUND,
        function() return DBR.db.chimes.sounds[chime.key] end,
        function(value)
            local key = library.Resolve(value)
            if key then
                DBR.db.chimes.sounds[chime.key] = key
                DBR.PreviewChime(chime.key)
            end
        end)
    local soundTooltip = "The sound for " .. chime.label .. "; Text to Speech says \"" .. chime.label .. " ready\"."
    if HasCheckboxDropdown(library) then
        local row = CreateSettingsCheckboxDropdownInitializer(setting, chime.label, tooltip, sound,
            library.Choices(), "Sound", soundTooltip)
        layout:AddInitializer(row)
        library.SetupCheckboxMenu(row)
        GreyUntilKnown(row, chime)
        Nest(row, chimesSwitch, ChimesOn, {"DBR_CHIMES_ENABLED"})
        return
    end
    local switch = GreyUntilKnown(Settings.CreateCheckbox(category, setting, tooltip), chime)
    Nest(switch, chimesSwitch, ChimesOn, {"DBR_CHIMES_ENABLED"})
    local dropdown = GreyUntilKnown(Settings.CreateDropdown(category, sound, library.Choices(), soundTooltip), chime)
    library.SetupMenu(dropdown)
    Nest(dropdown, switch, function() return DBR.db.chimes.enabled and DBR.db.chimes.spells[chime.key] end)
end

-- One proc under the procs' switch: its switch and its sound (aura sounds
-- only, the files the game can play for a buff) on one row, or two rows with
-- an older Dyre's Sounds or client. The settings and saved keys are the same.
local function AddProc(proc, library, procsSwitch)
    local variable = "DBR_PROC_" .. proc.key:upper()
    local tooltip = "Play a sound the moment " .. (proc.buff or "") .. " appears on you."
    -- A reactive ability: DBR plays it, so any sound.
    local filter = "aura"
    if proc.reactive then
            tooltip = "Play a sound the moment " .. proc.label .. " becomes usable."
        filter = nil
    end
    -- Another Dyre's AddOn can play it with its proc arcs (Toolkit 2.11.0's
    -- proc engine), also after this page is built: then the row is greyed and
    -- its tooltip names that AddOn; read each time the row draws or shows.
    local plain = tooltip
    local toolkit = DBR.toolkit
    local canYield = not proc.reactive and type(toolkit) == "table" and type(toolkit.PROC_KIND_PREFIX) == "string"
    if canYield then
        tooltip = function()
            local owner = DBR.ProcOwner(proc)
            if owner then
                return plain .. "\n\nGreyed out: " .. DBR.ProcOwnerTitle(owner) .. " plays this sound now."
            end
            return plain
        end
    end
    local function Live(row)
        if canYield and type(row) == "table" and type(row.AddModifyPredicate) == "function" then
            row:AddModifyPredicate(function() return not DBR.ProcOwner(proc) end)
        end
        return row
    end
    local setting = Register(variable, Settings.VarType.Boolean, proc.label, proc.on,
        function() return DBR.db.procs.spells[proc.key] end,
        function(value)
            DBR.db.procs.spells[proc.key] = value == true
            DBR.ApplyProcSounds()
        end)
    local function ProcsOn() return DBR.db.procs.enabled end
    if not library or (type(Settings.CreateDropdown) ~= "function" and not HasCheckboxDropdown(library)) then
        Nest(Live(Settings.CreateCheckbox(category, setting, tooltip)), procsSwitch, ProcsOn, {"DBR_PROCS_ENABLED"})
        return
    end
    local sound = Register(variable .. "_SOUND", Settings.VarType.String, "Sound",
        proc.sound or DBR.DEFAULT_PROC_SOUND,
        function() return DBR.db.procs.sounds[proc.key] end,
        function(value)
            local key = library.Resolve(value)
            if key and (not filter or library.AuraSound(key)) then
                DBR.db.procs.sounds[proc.key] = key
                DBR.ApplyProcSounds()
                DBR.PreviewProc(proc.key)
            end
        end)
    local soundTooltip = "The sound for " .. proc.label .. "."
    if HasCheckboxDropdown(library) then
        local row = CreateSettingsCheckboxDropdownInitializer(setting, proc.label, tooltip, sound,
            library.Choices(filter), "Sound", soundTooltip)
        layout:AddInitializer(row)
        library.SetupCheckboxMenu(row, filter)
        Nest(Live(row), procsSwitch, ProcsOn, {"DBR_PROCS_ENABLED"})
        return
    end
    local switch = Live(Settings.CreateCheckbox(category, setting, tooltip))
    Nest(switch, procsSwitch, ProcsOn, {"DBR_PROCS_ENABLED"})
    local dropdown = Live(Settings.CreateDropdown(category, sound, library.Choices(filter), soundTooltip))
    library.SetupMenu(dropdown, filter)
    Nest(dropdown, switch, function() return DBR.db.procs.enabled and DBR.db.procs.spells[proc.key] end)
end

-- The proc cues (1.13.0, Dyre's Toolkit's proc engine 2): the engine's rows,
-- a "Procs" header and per proc its arc and sound switches and its sound,
-- then the arcs' size; then, with SpellActivationOverlay loaded, the switch
-- to show the arcs beside it (from DSU 1.4; applies after a /reload). While
-- the arcs step aside for it, each arc switch is greyed.
local SAO_ROW = "Show proc arcs with SpellActivationOverlay"
local SAO_TOOLTIP = "You also use SpellActivationOverlay, so only the sounds play; tick this to show the arcs too "
    .. "(after a /reload)."

-- On a host's page the toolkit's rows need Toolkit settings sections 2
-- (AddProcSettings with opts.variable and opts.keys); before it, nothing, so
-- the host keeps its link to this page.
local HOST_PROC_ROWS = 2

-- The engine's master switch (Toolkit 2.17.0's AddProcMasterSetting; John,
-- 2026-11-27: "Add the Procs master switch"): every arc and sound gives way
-- while it is off, each proc's own switches keep their values.
local PROC_MASTER_TOOLTIP = "Shows an arc and plays a chime when a proc makes an important spell or ability ready."

local function ProcKeys(filter)
    return type(filter) == "string" and {filter} or type(filter) == "table" and filter or nil
end

local function AnyProcListed(handle, keys)
    for _, proc in ipairs(handle.List()) do
        if Wanted(keys, proc.key) then
            return true
        end
    end
    return false
end

local function AddProcCuesSection(filter)
    local handle = DBR.ProcCuesHandle()
    local toolkit = DBR.toolkit
    if not handle or type(toolkit.AddProcSettings) ~= "function" then
        return false
    end
    local keys = not Own() and ProcKeys(filter) or nil
    local hasMaster = type(toolkit.AddProcMasterSetting) == "function"
        and (tonumber(toolkit.SETTINGS_SECTIONS_VERSION) or 0) >= 3
    if not Own() and (tonumber(toolkit.SETTINGS_SECTIONS_VERSION) or 0) < HOST_PROC_ROWS then
        return false
    end
    if Part() == "master" then
        -- A top page: the switch alone, named, for a class with these procs.
        if not hasMaster or not AnyProcListed(handle, keys) then
            return false
        end
        local label, text = MasterLabel("Procs", PROC_MASTER_TOOLTIP)
        return toolkit.AddProcMasterSetting(category, layout, handle, {label = label, tooltip = text,
            variable = Var}) ~= nil
    end
    -- The heading on DBR's page; a host names its own section. With the
    -- master, the toolkit draws it under the heading, shown as the heading is.
    local opts = {header = Own() and "Procs" or false, variable = not Own() and Var or nil, keys = keys}
    if Part() == "all" and hasMaster then
        opts.master = {label = "Enable", tooltip = PROC_MASTER_TOOLTIP}
    end
    local rows = DBR.toolkit.AddProcSettings(category, layout, handle, opts)
    if type(rows) ~= "table" then
        return false
    end
    if DBR.ProcArcsSteppedAside() then
        for _, row in pairs(rows) do
            if type(row) == "table" and type(row.arc) == "table" and type(row.arc.AddModifyPredicate) == "function" then
                row.arc:AddModifyPredicate(function() return false end)
            end
        end
    end
    if not DBR.SpellActivationOverlayLoaded() then
        return true
    end
    local setting = Register("DBR_PROCS_WITH_SAO", Settings.VarType.Boolean,
        SAO_ROW, false,
        function() return DBR.db.procsWithSAO end,
        function(value)
            local wanted = value == true
            if wanted ~= DBR.db.procsWithSAO then
                DBR.db.procsWithSAO = wanted
                DBR.Report("Your proc arc choice applies after a /reload.")
            end
        end)
    Settings.CreateCheckbox(category, setting, SAO_TOOLTIP)
    return true
end

-- The proc sounds section, for a class with procs on a client that can play them.
local function AddProcsSection(filter)
    if DBR.procEngine then
        return AddProcCuesSection(filter)
    end
    local spells = Picked(DBR.ClassProcs(DBR.classFile), filter)
    if #spells == 0 or not DBR.HasProcSounds() then
        return false
    end
    local library = DBR.SoundLibrary()
    if Own() and Part() == "all" then
        Heading("Procs")
    end
    local tooltip = "Play a sound the moment a proc appears on you, such as Clearcasting."
    if not library then
            tooltip = tooltip .. " Install Dyre's Sounds to hear them."
    end
    local procsSwitch
    if Part() ~= "rest" then
        local label, text = MasterLabel("Procs", tooltip)
        procsSwitch = Flag("DBR_PROCS_ENABLED", label, "procs", "enabled", true, text, DBR.ApplyProcSounds)
        if Part() == "master" then
            return true
        end
    end
    for _, proc in ipairs(spells) do
        AddProc(proc, library, procsSwitch)
    end
    return true
end

-- One cast chime under its section's switch: its switch and its sound on one
-- row, or two with an older Dyre's Sounds or client (as a chime).
local function AddCast(cast, library, castsSwitch)
    local variable = "DBR_CAST_" .. cast.key:upper()
    local tooltip = "Play a sound just after you cast " .. cast.label .. "."
    if cast.form then
            tooltip = "Play a sound just after you shift into " .. cast.label .. "."
    end
    local setting = Register(variable, Settings.VarType.Boolean, cast.label, cast.on,
        function() return DBR.db.casts.spells[cast.key] end,
        function(value) DBR.db.casts.spells[cast.key] = value == true end)
    local function CastsOn() return DBR.db.casts.enabled end
    if not library or (type(Settings.CreateDropdown) ~= "function" and not HasCheckboxDropdown(library)) then
        Nest(Settings.CreateCheckbox(category, setting, tooltip), castsSwitch, CastsOn)
        return
    end
    local sound = Register(variable .. "_SOUND", Settings.VarType.String, "Sound",
        cast.sound or DBR.DEFAULT_CAST_SOUND,
        function() return DBR.db.casts.sounds[cast.key] end,
        function(value)
            local key = library.Resolve(value)
            if key then
                DBR.db.casts.sounds[cast.key] = key
                DBR.PreviewCast(cast.key)
            end
        end)
    local soundTooltip = "The sound for " .. cast.label .. "; Text to Speech says \"" .. (cast.speech or DBR.CAST_SPEECH)
        .. "\"."
    if HasCheckboxDropdown(library) then
        local row = CreateSettingsCheckboxDropdownInitializer(setting, cast.label, tooltip, sound,
            library.Choices(), "Sound", soundTooltip)
        layout:AddInitializer(row)
        library.SetupCheckboxMenu(row)
        Nest(row, castsSwitch, CastsOn)
        return
    end
    local switch = Settings.CreateCheckbox(category, setting, tooltip)
    Nest(switch, castsSwitch, CastsOn)
    local dropdown = Settings.CreateDropdown(category, sound, library.Choices(), soundTooltip)
    library.SetupMenu(dropdown)
    Nest(dropdown, switch, function() return DBR.db.casts.enabled and DBR.db.casts.spells[cast.key] end)
end

-- A combo point sound: its switch and its sound on one row, or two with an
-- older Dyre's Sounds or client (as a chime).
local function AddComboSound(which, label, tooltip, default, comboSwitch)
    local saved = DBR.db.combo
    local soundKey = which .. "Sound"
    local variable = "DBR_COMBO_" .. which:upper()
    local library = DBR.SoundLibrary()
    local setting = Register(variable, Settings.VarType.Boolean, label, true,
        function() return saved[which] end,
        function(value) saved[which] = value == true end)
    local function ComboOn() return saved.enabled end
    if not library or (type(Settings.CreateDropdown) ~= "function" and not HasCheckboxDropdown(library)) then
        Nest(Settings.CreateCheckbox(category, setting, tooltip), comboSwitch, ComboOn)
        return
    end
    local sound = Register(variable .. "_SOUND", Settings.VarType.String, "Sound",
        default, function() return saved[soundKey] end,
        function(value)
            local key = library.Resolve(value)
            if key then
                saved[soundKey] = key
                DBR.PreviewCombo(which)
            end
        end)
    local soundTooltip = "The sound for " .. label .. "."
    if HasCheckboxDropdown(library) then
        local row = CreateSettingsCheckboxDropdownInitializer(setting, label, tooltip, sound, library.Choices(),
            "Sound", soundTooltip)
        layout:AddInitializer(row)
        library.SetupCheckboxMenu(row)
        Nest(row, comboSwitch, ComboOn)
        return
    end
    local switch = Settings.CreateCheckbox(category, setting, tooltip)
    Nest(switch, comboSwitch, ComboOn)
    local dropdown = Settings.CreateDropdown(category, sound, library.Choices(), soundTooltip)
    library.SetupMenu(dropdown)
    Nest(dropdown, switch, function() return saved.enabled and saved[which] end)
end

-- The combo point chimes section (author, 1.6.0), for Rogues and Druids.
local function AddComboSection()
    if not DBR.HasComboChimes() then
        return
    end
    Heading("Combo Point Chimes")
    local tooltip = "Play a note for each combo point you earn, and a sound when you spend them."
    if not DBR.SoundLibrary() then
        tooltip = tooltip .. " Install Dyre's Sounds to hear them."
    end
    local comboSwitch = Flag("DBR_COMBO_ENABLED", "Enable", "combo", "enabled", true, tooltip, function() end)
    local function ComboOn() return DBR.db.combo.enabled end
    AddComboSound("full", "Full", "Play a sound when you reach the most combo points.", DBR.COMBO_FULL_SOUND,
        comboSwitch)
    AddComboSound("spend", "Spend", "Play a sound when you spend your combo points.", DBR.COMBO_SPEND_SOUND,
        comboSwitch)
    Nest(Flag("DBR_COMBO_ONLYFULL", "Only when full", "combo", "onlyFull", false, "Play only Full's sound (and "
        .. "Spend's), not a note for each point.", function() end), comboSwitch, ComboOn)
    if type(Settings.CreateDropdown) ~= "function" or type(Settings.CreateControlTextContainer) ~= "function" then
        return
    end
    -- The note set (author, 1.7.0): Full and Spend follow it, unless chosen.
    local setting = Register("DBR_COMBO_NOTESET", Settings.VarType.String, "Note set",
        DBR.COMBO_DEFAULT_SET, function() return DBR.db.combo.noteSet end,
        function(value)
            DBR.SetComboNoteSet(value)
            Settings.NotifyUpdate(Var("DBR_COMBO_FULL_SOUND"))
            Settings.NotifyUpdate(Var("DBR_COMBO_SPEND_SOUND"))
        end)
    local function Choices()
        local container = Settings.CreateControlTextContainer()
        for _, key in ipairs(DBR.COMBO_SET_ORDER) do
            container:Add(key, DBR.COMBO_SETS[key].label)
        end
        return container:GetData()
    end
    Nest(Settings.CreateDropdown(category, setting, Choices, "The notes played for each combo point."), comboSwitch,
        ComboOn)
end

-- The cast chimes section (author, 1.4.0), for a class with any.
local function AddCastsSection()
    local spells = DBR.ClassCasts(DBR.classFile)
    if #spells == 0 then
        return
    end
    local library = DBR.SoundLibrary()
    Heading("Cast Chimes")
    local tooltip = "Play a sound just after you cast a travel spell, Charge, and others, or shift into a Druid "
        .. "form."
    if not library then
            tooltip = tooltip .. " Install Dyre's Sounds to hear them."
    end
    local castsSwitch = Flag("DBR_CASTS_ENABLED", "Enable", "casts", "enabled", true, tooltip, function() end)
    for _, cast in ipairs(spells) do
        local known = not cast.whenKnown
        for _, id in ipairs(cast.whenKnown and cast.spells or {}) do
            known = known or C_SpellBook.IsSpellKnown(id) == true
        end
        if known then
            AddCast(cast, library, castsSwitch)
        end
    end
end

-- The cooldown chimes section: its own switch, the lead, then your class's spells.
local function AddChimesSection(filter)
    local spells = Picked(DBR.ClassChimes(DBR.classFile), filter)
    if #spells == 0 and not Own() then
        return false
    end
    local library = DBR.SoundLibrary()
    if Own() and Part() == "all" then
        Heading("Chimes")
    end
    local tooltip = "Play a sound just before your chosen spells are ready again."
    if not library then
            tooltip = tooltip .. " Install Dyre's Sounds to hear them."
    end
    local chimesSwitch
    if Part() ~= "rest" then
        local label, text = MasterLabel("Chimes", tooltip)
        chimesSwitch = Flag("DBR_CHIMES_ENABLED", label, "chimes", "enabled", true, text, function() end)
        if Part() == "master" then
            return true
        end
    end
    local lead = Register("DBR_CHIME_LEAD", Settings.VarType.Number,
        "Chime early (seconds)", DBR.DEFAULT_CHIME_LEAD,
        function() return DBR.db.chimes.lead end,
        function(value) DBR.db.chimes.lead = DBR.SanitizeChimeLead(value) end)
    local leadSlider = Settings.CreateSlider(category, lead,
        SliderOptions(DBR.CHIME_LEAD_MIN, DBR.CHIME_LEAD_MAX, DBR.CHIME_LEAD_STEP),
        "How long before a cooldown ends the chime plays.")
    if type(DBR.toolkit.AddDefaultTick) == "function" then
        DBR.toolkit.AddDefaultTick(leadSlider, {min = DBR.CHIME_LEAD_MIN, max = DBR.CHIME_LEAD_MAX,
            default = DBR.DEFAULT_CHIME_LEAD})
    end
    Nest(leadSlider, chimesSwitch, function() return DBR.db.chimes.enabled end, {"DBR_CHIMES_ENABLED"})
    if #spells == 0 and Own() then
        Heading(NO_CHIME_SPELLS)
    end
    for _, chime in ipairs(spells) do
        AddChime(chime, library, chimesSwitch)
    end
    return true
end

-- Each widget's Size and Opacity, then "Reset size" (Dyre's Toolkit's
-- sliders, with a gold mark at the default). Moving them is the toolkit's
-- unlock: /dbr unlock, /dyre unlock, or "Unlock frames" on Dyre's AddOns.
-- One Size and one Opacity for every buff icon (author-approved), then
-- "Reset size": each buff widget keeps its own saved table (toolkit owner:
-- one store per widget), and these set the same value on all of them.
local function AddBuffSizes(widgets)
    local first = widgets[1]
    local function Slider(name, label, tooltip)
        local range = DBR.WIDGET_SIZES[name]
        if range == true then
            range = {min = 10, max = 100, step = 5, default = 100}
        end
        local setting = Register("DBR_BUFF_ICONS_" .. name:upper(),
            Settings.VarType.Number, label, range.default,
            function() return first:GetSetting(name) end,
            function(value)
                for _, widget in ipairs(widgets) do
                    widget:SetSetting(name, value)
                end
            end)
        local options = SliderOptions(range.min, range.max, range.step, true)
        local slider = Settings.CreateSlider(category, setting, options, tooltip)
        if type(DBR.toolkit.AddDefaultTick) == "function" then
            DBR.toolkit.AddDefaultTick(slider, range)
        end
        Nest(slider, nil, function() return DBR.db.enabled end, {"DBR_ENABLED"})
    end
    Slider("scale", "Reminder icons: size", "The size of every reminder icon.")
    Slider("opacity", "Reminder icons: opacity", "How solid every reminder icon is.")
    if type(CreateSettingsButtonInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        local reset = CreateSettingsButtonInitializer("Reminder icons", "Reset size", function()
            for _, widget in ipairs(widgets) do
                widget:ResetSize()
            end
            Settings.NotifyUpdate(Var("DBR_BUFF_ICONS_SCALE"))
        end, "Put every reminder icon back to its default size.", true)
        Nest(reset, nil, function() return DBR.db.enabled end, {"DBR_ENABLED"})
        -- A greyed button keeps its gold label on Forever; the toolkit greys it.
        if type(DBR.toolkit.GreyButtonLabel) == "function" then
            DBR.toolkit.GreyButtonLabel(reset)
        end
        layout:AddInitializer(reset)
    end
end

-- At the end of Reminders (author: "the size settings should be in the area
-- of the thing they are resizing"): the reminder icons' Size and Opacity,
-- then the seal timer's.
local function AddReminderSizes()
    local buffs = DBR.BuffWidgets()
    if #buffs > 0 then
        AddBuffSizes(buffs)
    end
    -- The Aspect reminder has its own size (John: "resizable (scale from 50% -
    -- 200%, default 100%)").
    local aspectWidget = DBR.AspectReminderWidget()
    if aspectWidget then
        WidgetSettings(aspectWidget, {scale = "Aspect reminder: size", opacity = "Aspect reminder: opacity"},
            function() return DBR.db.enabled and DBR.db.aspectMode ~= "off" end,
            {"DBR_ENABLED", "DBR_ASPECT_MODE", "DBR_BUFF_ASPECT"})
    end
    local sealWidget = DBR.SealWidget()
    if sealWidget then
        WidgetSettings(sealWidget, {scale = "Seal timer: size", opacity = "Seal timer: opacity"},
            function() return DBR.db.enabled and DBR.db.seal.enabled end, {"DBR_ENABLED", "DBR_SEAL"})
    end
    local warningWidget = _G.DyresBuffRemindersWarning
    if warningWidget and #DBR.ClassWarnings() > 0 then
        WidgetSettings(warningWidget, {scale = "Warning messages: size"}, function() return DBR.db.enabled end,
            {"DBR_ENABLED"})
    end
end

-- The Aspect reminder's mode (John, 1.8.0), in place of its switch:
-- Normal, Speed-Running, or Disabled. Without the dropdown API, a switch
-- (on: Normal).
local ASPECT_MODE_TOOLTIP = "When the Aspect reminder shows: Normal (no aspect up, or Cheetah or Pack in combat), "
    .. "Speed-Running (Cheetah is fine in combat), or Disabled."

local function AddAspectMode(reminder)
    local key = reminder.key
    local function Set(value)
        if not DBR.ASPECT_MODE_LABELS[value] then
            return
        end
        DBR.db.aspectMode = value
        DBR.db.spells[key] = value ~= "off"
        DBR.RefreshReminders()
    end
    if type(Settings.CreateDropdown) ~= "function" or type(Settings.CreateControlTextContainer) ~= "function" then
        local setting = Register("DBR_BUFF_" .. key:upper(), Settings.VarType.Boolean,
            reminder.label, true, function() return DBR.db.aspectMode ~= "off" end,
            function(value) Set(value and "normal" or "off") end)
        return Settings.CreateCheckbox(category, setting, ASPECT_MODE_TOOLTIP)
    end
    local setting = Register("DBR_ASPECT_MODE", Settings.VarType.String,
        reminder.label, "normal", function() return DBR.db.aspectMode end, Set)
    local function Choices()
        local container = Settings.CreateControlTextContainer()
        for _, mode in ipairs(DBR.ASPECT_MODE_ORDER) do
            container:Add(mode, DBR.ASPECT_MODE_LABELS[mode])
        end
        return container:GetData()
    end
    return Settings.CreateDropdown(category, setting, Choices, ASPECT_MODE_TOOLTIP)
end

-- Under the Aspect reminder's mode: its sound when combat starts with a
-- problem (its own switch and choice, Dyre's Sounds) on one row, or two
-- with an older Dyre's Sounds or client, or the switch alone without it.
local function AddCombatAspect(combat)
    local function CombatOn()
        return DBR.db.enabled and DBR.db.aspectMode ~= "off"
    end
    local saved = DBR.db.combatAspect
    local label, tooltip = "Sound at combat start", "Play a sound when combat starts with no aspect up, or with "
        .. "Cheetah or Pack up."
    local setting = Register("DBR_COMBAT_ASPECT_SOUND_ON", Settings.VarType.Boolean,
        label, true, function() return saved.soundOn end,
        function(value) saved.soundOn = value == true end)
    local library = DBR.SoundLibrary()
    if not library or (type(Settings.CreateDropdown) ~= "function" and not HasCheckboxDropdown(library)) then
        Nest(Settings.CreateCheckbox(category, setting, tooltip), combat, CombatOn)
        return
    end
    local sound = Register("DBR_COMBAT_ASPECT_SOUND", Settings.VarType.String, "Sound",
        DBR.DEFAULT_CHIME_SOUND, function() return saved.sound end,
        function(value)
            local resolved = library.Resolve(value)
            if resolved then
                saved.sound = resolved
                DBR.PreviewCombatAspect()
            end
        end)
    local soundTooltip = "The sound at combat start; Text to Speech says which aspect is up."
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

-- The aspect bar (1.8.0), for a Hunter: Enable (on at first), Layout
-- (Toolkit 2.18.0's row, "Horizontal" or "Vertical", as every Dyre's button
-- bar; before it, DBR's own Vertical), then its Size and Opacity. With
-- Toolkit 2.19.0 (BAR_OPACITY_VERSION) the Layout row brings "Opacity out of
-- combat", the same value as the plain Opacity slider, and "Opacity in
-- combat"; the plain slider is then left out, so it shows once.
local function AddAspectBarSection()
    local widget = DBR.AspectBarWidget()
    if not widget then
        return
    end
    Heading("Aspect bar")
    local saved = DBR.db.aspectBar
    local master = Flag("DBR_ASPECT_BAR", "Enable", "aspectBar", "enabled", true,
            "Show a bar with a button for each aspect you know; click one to swap to it.", DBR.RefreshAspectBar)
    local function Enabled() return saved.enabled end
    local skip
    if DBR.AspectBarUsesToolkitLayout() and type(DBR.toolkit.AddBarLayoutSetting) == "function" then
        local row = DBR.toolkit.AddBarLayoutSetting(category, layout, widget,
            {variable = Var, tooltip = "Lay the aspect buttons out in a row or a column.", modify = Enabled,
                watch = {Var("DBR_ASPECT_BAR")}})
        Nest(row, master, Enabled)
        if type(DBR.toolkit.BAR_OPACITY_VERSION) == "number" then
            skip = {"opacity"}
        end
    else
        local vertical = Register("DBR_ASPECT_BAR_VERTICAL", Settings.VarType.Boolean, "Vertical", false,
            function() return saved.orientation == "vertical" end,
            function(value)
                saved.orientation = value and "vertical" or nil
                DBR.RefreshAspectBar()
            end)
        local row = Settings.CreateCheckbox(category, vertical,
            "Stack the buttons top to bottom instead of left to right.")
        Nest(row, master, Enabled)
    end
    WidgetSettings(widget, {scale = "Aspect bar: size", opacity = "Aspect bar: opacity"},
        function() return saved.enabled end, {"DBR_ASPECT_BAR"}, skip)
end

-- Consumables (Part B), for a class with any (DBR.CONSUMABLES): Enable, then
-- Ammo and its Warn at (bow, gun, and crossbow classes), then each reagent
-- whose spell you know at login, with its own Warn at.
local function AddReagent(reagent, master)
    local key = reagent.key
    local saved = DBR.db.consumables
    local items = {}
    for _, rank in ipairs(reagent.ranks) do
        items[#items + 1] = rank.name
    end
    local on = Register("DBR_REAGENT_" .. key:upper(), Settings.VarType.Boolean,
        reagent.label .. " reagent", true, function() return saved.reagents[key].on end,
        function(value)
            saved.reagents[key].on = value == true
            DBR.RefreshConsumables()
        end)
    local switch = Settings.CreateCheckbox(category, on,
            "Show how many of " .. reagent.label .. "'s reagent you carry (" .. table.concat(items, ", ") .. ").")
    local range = reagent.warn
    local warn = Register("DBR_REAGENT_WARN_" .. key:upper(), Settings.VarType.Number,
        "Warn at", range.default, function() return saved.reagents[key].warn end,
        function(value)
            saved.reagents[key].warn = DBR.SanitizeReagentWarn(reagent, value)
            DBR.RefreshConsumables()
        end)
    local slider = Settings.CreateSlider(category, warn, SliderOptions(range.min, range.max, range.step),
        "The " .. reagent.label .. " reagent count that turns red and pulses.")
    if type(DBR.toolkit.AddDefaultTick) == "function" then
        DBR.toolkit.AddDefaultTick(slider, range)
    end
    Nest(switch, master, function() return saved.enabled end)
    Nest(slider, switch, function() return saved.enabled and saved.reagents[key].on end)
end

local function AddConsumablesSection()
    local list = DBR.ClassConsumables()
    local known = {}
    for _, reagent in ipairs(list and list.reagents or {}) do
        if DBR.ReagentRank(reagent) then
            known[#known + 1] = reagent
        end
    end
    -- Nothing to count yet (a Mage before Arcane Brilliance): no section.
    if not list or (not list.ammo and #known == 0) then
        return
    end
    Heading("Consumables")
    local saved = DBR.db.consumables
    local master = Flag("DBR_CONSUMABLES_ENABLED", "Enable", "consumables", "enabled", true,
            "Show how much ammo or reagents you have left.", DBR.RefreshConsumables)
    if list.ammo then
        local ammoSwitch = Flag("DBR_CONSUMABLE_AMMO", "Ammo", "consumables", "ammo", true,
                    "Show your equipped arrows or bullets and how many are left.", DBR.RefreshConsumables)
        Nest(ammoSwitch, master, function() return saved.enabled end)
        local warn = Register("DBR_AMMO_WARN", Settings.VarType.Number, "Warn at",
            DBR.DEFAULT_AMMO_WARN, function() return saved.ammoWarn end,
            function(value)
                saved.ammoWarn = DBR.SanitizeAmmoWarn(value)
                DBR.RefreshConsumables()
            end)
        local slider = Settings.CreateSlider(category, warn,
            SliderOptions(DBR.AMMO_WARN_MIN, DBR.AMMO_WARN_MAX, DBR.AMMO_WARN_STEP),
            "The ammo count that turns red and pulses.")
        if type(DBR.toolkit.AddDefaultTick) == "function" then
            DBR.toolkit.AddDefaultTick(slider, {min = DBR.AMMO_WARN_MIN, max = DBR.AMMO_WARN_MAX,
                default = DBR.DEFAULT_AMMO_WARN})
        end
        Nest(slider, ammoSwitch, function() return saved.enabled and saved.ammo end)
    end
    for _, reagent in ipairs(known) do
        AddReagent(reagent, master)
    end
    -- Its own Size and Opacity here, where you look for them (author).
    WidgetSettings(DBR.ConsumablesWidget(), {scale = "Consumables: size", opacity = "Consumables: opacity"},
        function() return saved.enabled end, {"DBR_CONSUMABLES_ENABLED"})
end

-- A buff's own "remind before it runs out" (Buffs.lua's lead), under its
-- switch, with the toolkit's gold default mark where the toolkit offers it.
local function AddBuffLead(reminder, buffSwitch)
    local key, range = reminder.key, reminder.lead
    local setting = Register("DBR_LEAD_" .. key:upper(), Settings.VarType.Number,
        "Remind before it runs out (sec)", range.default,
        function() return DBR.db.leads[key] end,
        function(value)
            DBR.db.leads[key] = DBR.SanitizeBuffLead(reminder, value)
            DBR.RefreshReminders()
        end)
    local slider = Settings.CreateSlider(category, setting, SliderOptions(range.min, range.max, range.step),
            "Show " .. reminder.label .. "'s icon this many seconds before it runs out.")
    if type(DBR.toolkit.AddDefaultTick) == "function" then
        DBR.toolkit.AddDefaultTick(slider, range)
    end
    Nest(slider, buffSwitch, function() return DBR.db.enabled and DBR.db.spells[key] end)
end

-- The shared "Remind before a buff runs out", in percent of each buff's own
-- length (author), for every buff without its own lead.
local function AddSharedLead(master, Enabled)
    local lead = Register("DBR_LEAD", Settings.VarType.Number,
        "Remind before a buff runs out", DBR.DEFAULT_LEAD,
        function() return DBR.db.leadPercent end,
        function(value)
            DBR.db.leadPercent = DBR.SanitizeLead(value)
            DBR.RefreshReminders()
        end)
    local leadSlider = Settings.CreateSlider(category, lead, SliderOptions(DBR.LEAD_MIN, DBR.LEAD_MAX, 1, true),
            "Warn when this share of a buff's time is left (10% of a 30-minute buff is 3 minutes).")
    if type(DBR.toolkit.AddDefaultTick) == "function" then
        DBR.toolkit.AddDefaultTick(leadSlider, {min = DBR.LEAD_MIN, max = DBR.LEAD_MAX, default = DBR.DEFAULT_LEAD})
    end
    Nest(leadSlider, master, Enabled, {"DBR_ENABLED"})
end

-- "Visibility when not needed" (John, 2026-11-18): one slider for every buff
-- whose "Show only when needed" is on; 0 hides it.
local function AddNotNeededAlpha(master, Enabled)
    local setting = Register("DBR_FAINT", Settings.VarType.Number,
        "Visibility when not needed", DBR.DEFAULT_FAINT, function() return DBR.db.faintPercent end,
        function(value)
            DBR.db.faintPercent = DBR.SanitizeFaint(value)
            DBR.RefreshReminders()
        end)
    local slider = Settings.CreateSlider(category, setting,
        SliderOptions(DBR.FAINT_MIN, DBR.FAINT_MAX, DBR.FAINT_STEP, true),
            "How visible a buff with \"Show only when needed\" is while it is up; 0% hides it.")
    if type(DBR.toolkit.AddDefaultTick) == "function" then
        DBR.toolkit.AddDefaultTick(slider, {min = DBR.FAINT_MIN, max = DBR.FAINT_MAX, default = DBR.DEFAULT_FAINT})
    end
    Nest(slider, master, Enabled, {"DBR_ENABLED"})
end

-- "Missing buff" (John, 2026-11-20): the glow or the red border while a buff
-- is gone; running out stays yellow.
local function AddMissingStyle(master, Enabled)
    local setting = Register("DBR_MISSING_STYLE", Settings.VarType.String,
        "Missing buff", DBR.DEFAULT_MISSING_STYLE, function() return DBR.db.missingStyle end,
        function(value)
            if not DBR.MISSING_STYLE_LABELS[value] then
                return
            end
            DBR.db.missingStyle = value
            DBR.RefreshReminders()
        end)
    local function Choices()
        local container = Settings.CreateControlTextContainer()
        for _, style in ipairs(DBR.MISSING_STYLE_ORDER) do
            container:Add(style, DBR.MISSING_STYLE_LABELS[style])
        end
        return container:GetData()
    end
    local dropdown = Settings.CreateDropdown(category, setting, Choices,
            "How a reminder shows that its buff is gone: Glow or Red border.")
    Nest(dropdown, master, Enabled, {"DBR_ENABLED"})
end

-- A buff switch's tooltip: what it shows, and for a tank buff whom it watches.
local function BuffTooltip(reminder)
    -- One plain sentence (John, 2026-11-27); README has the rest.
    if reminder.tank then
        return "Show an icon while " .. reminder.label .. " is missing on you, or on your group's tank; click it to "
            .. "cast it."
    end
    return "Show an icon while " .. reminder.label .. " is missing or about to run out; click it to cast it."
end

local function GroupTooltip(reminder)
    local who = reminder.group.mana and "party or raid member who uses mana" or "party or raid member"
    return "Also remind you when a " .. who .. " lacks " .. reminder.label .. "."
end

-- The buff reminders (section "reminders"): Enable, then each of your
-- class's buffs (a filter lists reminder keys; "seal" and the warnings' keys
-- too), then the shared rows those buffs use. On a host's page with nothing
-- to show, no rows at all.
local function AddRemindersSection(filter)
    local reminders = Picked(DBR.ClassReminders(), filter)
    local seal = DBR.HasSealTimer() and Wanted(filter, "seal")
    local warnings = Picked(DBR.ClassWarnings(), filter)
    if not Own() and #reminders == 0 and not seal and #warnings == 0 then
        return false
    end
    if Own() and Part() == "all" then
        Heading("Reminders")
    end
    local master
    if Part() ~= "rest" then
        local label, text = MasterLabel("Reminders", "Show an icon for each of your buffs while it is missing "
            .. "or about to run out.")
        master = Flag("DBR_ENABLED", label, nil, "enabled", true, text,
            function()
                DBR.RefreshReminders()
                DBR.RefreshSeal()
            end)
        if Part() == "master" then
            return true
        end
    end
    local function Enabled() return DBR.db.enabled end
    for _, reminder in ipairs(reminders) do
        local key = reminder.key
        local buff
        if reminder.combatAspect then
            buff = AddAspectMode(reminder)
        else
            buff = Flag("DBR_BUFF_" .. key:upper(), reminder.label, "spells", key, reminder.on,
                BuffTooltip(reminder), DBR.RefreshReminders)
        end
        Nest(buff, master, Enabled, {"DBR_ENABLED"})
        if reminder.group then
            local group = Flag("DBR_GROUP_" .. key:upper(), reminder.label .. ": also your group", "groups", key,
                true, GroupTooltip(reminder), DBR.RefreshReminders)
            Nest(group, buff, function() return DBR.db.enabled and DBR.db.spells[key] end)
        end
        if reminder.lead then
            AddBuffLead(reminder, buff)
        end
        if DBR.CanShowOnlyWhenNeeded(reminder) then
            local needed = Flag("DBR_NEEDED_" .. key:upper(), "Show only when needed", "needed", key,
                DBR.NeededDefault(reminder),
                "Show " .. reminder.label .. "'s icon in full only while it is missing or about to run out.",
                DBR.RefreshReminders)
            Nest(needed, buff, function() return DBR.db.enabled and DBR.db.spells[key] end)
        end
        if DBR.CanShowOnlyInCombat(reminder) then
            local combatOnly = Flag("DBR_COMBATONLY_" .. key:upper(), "Show only in combat", "combatOnly", key,
                false,
                "Show " .. reminder.label .. " only in combat.",
                DBR.RefreshReminders)
            Nest(combatOnly, buff, function() return DBR.db.enabled and DBR.db.spells[key] end)
        end
        if reminder.tankOnly then
            local always = Flag("DBR_ALWAYS_" .. key:upper(), "Always show " .. reminder.label, "alwaysShow", key,
                false, "Show " .. reminder.label .. " even when you are not tanking.", DBR.RefreshReminders)
            Nest(always, buff, function() return DBR.db.enabled and DBR.db.spells[key] end)
        end
        if reminder.combatAspect then
            AddCombatAspect(buff)
        end
    end
    if seal then
        local sealSwitch = Flag("DBR_SEAL", "Seal timer", "seal", "enabled", true,
            "Show your seal and its time left; in combat with none up, click it to cast your last seal.",
            DBR.RefreshSeal)
        Nest(sealSwitch, master, Enabled, {"DBR_ENABLED"})
    end
    -- The warnings (on-screen messages), each its own switch.
    for _, warning in ipairs(warnings) do
        local text = warning.kind == "fury"
            and "Warn on screen while Righteous Fury is on in a group where you are not the tank."
            or "Warn on screen while your pet's taunt is on autocast in a group where you are not the tank."
        if warning.kind == "petTaunt" then
            local plain = text
            text = function()
                local owner = DBR.PetTauntOwner()
                if owner then
                    return plain .. "\n\nGreyed out: " .. DBR.PetTauntOwnerTitle(owner) .. " gives this warning now."
                end
                return plain
            end
        end
        local switch = Flag("DBR_WARN_" .. warning.key:upper(), warning.label, "warnings", warning.key, true, text,
            DBR.RefreshReminders)
        Nest(switch, master, Enabled, {"DBR_ENABLED"})
        -- Checked each time the page draws: the toolkit can claim it later.
        if warning.kind == "petTaunt" and type(switch.AddModifyPredicate) == "function" then
            switch:AddModifyPredicate(function() return not DBR.ToolkitOwnsPetTaunt() end)
        end
    end
    -- The shared lead only where a buff uses it (author: a Warrior's Battle
    -- Shout has its own, so a second slider would do nothing); db.leadPercent stays.
    local shared, needed = false, false
    for _, reminder in ipairs(reminders) do
        shared = shared or not reminder.lead
        needed = needed or DBR.CanShowOnlyWhenNeeded(reminder)
    end
    if shared then
        AddSharedLead(master, Enabled)
    end
    if needed or Own() then
        AddNotNeededAlpha(master, Enabled)
    end
    AddMissingStyle(master, Enabled)
    return true
end

-- The sections other Dyre's AddOns can show on their own page (Dyre's Toolkit
-- 2.17.0; John, 2026-11-26: a class AddOn "should surface every setting in
-- the wrapped addon's settings, and just pass-through the setting"). Each
-- row reads and writes DBR's own settings, so a change on one page is the
-- change on the other. Sizes, the aspect bar, consumables, and the cast and
-- combo chimes stay on DBR's page only.
local SECTIONS = {
    -- One name per section (John, 2026-11-27: "let's use the same name
    -- consistently everywhere"): DBR's headings, the host's sub-page title
    -- (SettingsSectionTitle), and its top-page switch.
    {key = "reminders", title = "Reminders", build = AddRemindersSection},
    {key = "chimes", title = "Chimes", build = AddChimesSection},
    {key = "procs", title = "Procs", build = AddProcsSection},
}

-- Builds one section on a page. Every DBR state a row reads exists only
-- after DBR's own login (a host lists DBR in OptionalDeps, so DBR's comes
-- first); before it, or for another class, nothing.
local started = false

local function BuildSection(section, pageCategory, pageLayout, ctx)
    if not started or not HasSettingsAPI() or type(ctx) ~= "table" or type(ctx.variable) ~= "function"
            or (ctx.class ~= nil and ctx.class ~= DBR.classFile) then
        return false
    end
    local before = {category, layout, page}
    category, layout, page = pageCategory, pageLayout, ctx
    local ok, added = pcall(section.build, ctx.filter)
    category, layout, page = before[1], before[2], before[3]
    if not ok then
        error(added, 0)
    end
    return added == true
end

local function OwnContext(key)
    local toolkit = DBR.toolkit
    if type(toolkit) == "table" and type(toolkit.OwnSettingsContext) == "function" then
        return toolkit.OwnSettingsContext(addonName, key)
    end
    return {host = addonName, owner = addonName, key = key, class = DBR.classFile, own = true,
        variable = function(name) return name end}
end

-- At ADDON_LOADED, after the saved settings are repaired: a host builds its
-- page at its own PLAYER_LOGIN. Without Dyre's Toolkit 2.17.0, nothing (the
-- hosts keep their links to this page).
function DBR.RegisterSettingsSections()
    local toolkit = rawget(_G, "DyresToolkit")
    if type(toolkit) ~= "table" or (tonumber(toolkit.SETTINGS_SECTIONS_VERSION) or 0) < 1
            or type(toolkit.RegisterSettingsSection) ~= "function" then
        return false
    end
    for _, section in ipairs(SECTIONS) do
        toolkit.RegisterSettingsSection({addon = addonName, key = section.key, title = section.title,
            build = function(pageCategory, pageLayout, ctx)
                return BuildSection(section, pageCategory, pageLayout, ctx)
            end})
    end
    return true
end

function DBR.InitializeOptions()
    started = true
    if not HasSettingsAPI() then
        return
    end
    category, layout = DBR.toolkit.RegisterSettingsCategory(TITLE)
    if not category then
        return
    end
    local pageCategory, pageLayout = category, layout
    local function Section(index)
        BuildSection(SECTIONS[index], pageCategory, pageLayout, OwnContext(SECTIONS[index].key))
    end
    Section(1)
    AddReminderSizes()
    AddAspectBarSection()
    AddConsumablesSection()
    Section(2)
    Section(3)
    AddCastsSection()
    AddComboSection()
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
