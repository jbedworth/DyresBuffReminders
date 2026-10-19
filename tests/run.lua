-- These mocks test AddOn logic, not Forever compatibility, protected actions,
-- secret-value behavior, layout, or taint.
-- Every test gets its own globals, clock, event frames, and namespace.
-- Run from the repository root: lua5.1 tests/run.lua

local tests = {}
local function test(name, body)
    tests[#tests + 1] = {name = name, body = body}
end
local function equal(actual, expected, context)
    if actual ~= expected then
        error((context or "value") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual), 2)
    end
end
local function contains(actual, fragment, context)
    if type(actual) ~= "string" or not actual:find(fragment, 1, true) then
        error((context or "text") .. ": expected text containing " .. fragment
            .. ", got " .. tostring(actual), 2)
    end
end

local ADDON = "DyresBuffReminders"
local function tocFiles()
    local files = {}
    for line in io.lines(ADDON .. ".toc") do
        if line:match("%S") and not line:match("^#") then
            files[#files + 1] = line
        end
    end
    return files
end
local RUNTIME_FILES = tocFiles()

-- Classic spell names for the IDs in Buffs.lua, as the client would name them.
local SPELLS = {}
local function name(text, ...)
    for _, id in ipairs({...}) do SPELLS[id] = text end
end
name("Arcane Intellect", 1459, 1460, 1461, 10156, 10157)
name("Arcane Brilliance", 23028)
name("Frost Armor", 168, 7300, 7301)
name("Ice Armor", 7302, 7320, 10219, 10220)
name("Mage Armor", 6117, 22782, 22783)
name("Dampen Magic", 604, 8450, 8451, 10173, 10174)
name("Amplify Magic", 1008, 8455, 10169, 10170)
name("Demon Skin", 687, 696)
name("Demon Armor", 706, 1086, 11733, 11734, 11735)
name("Mark of the Wild", 1126, 5232, 6756, 5234, 8907, 9884, 9885)
name("Gift of the Wild", 21849, 21850)
name("Thorns", 467, 782, 1075, 8914, 9756, 9910)
name("Power Word: Fortitude", 1243, 1244, 1245, 2791, 10937, 10938)
name("Prayer of Fortitude", 21562, 21564)
name("Inner Fire", 588, 7128, 602, 1006, 10951, 10952)
name("Divine Spirit", 14752, 14818, 14819, 27841)
name("Prayer of Spirit", 27681)
name("Shadow Protection", 976, 10957, 10958)
name("Prayer of Shadow Protection", 27683)
name("Righteous Fury", 25780)
name("Seal of Righteousness", 21084, 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293)
name("Seal of Command", 20375, 20915, 20918, 20919, 20920)
name("Seal of the Crusader", 21082, 20162, 20305, 20306, 20307, 20308)
name("Seal of Justice", 20164)
name("Seal of Light", 20165, 20347, 20348, 20349)
name("Seal of Wisdom", 20166, 20356, 20357)

local INTELLECT, BRILLIANCE, FROST_ARMOR, ICE_ARMOR = 1459, 23028, 168, 7302
local DEMON_SKIN, DEMON_ARMOR = 687, 706
local MARK, GIFT_1, GIFT_2, THORNS = 1126, 21849, 21850, 467
local FORTITUDE, PRAYER_1, PRAYER_2, INNER_FIRE = 1243, 21562, 21564, 588
local ARCANE_POWDER, WILD_BERRIES, WILD_THORNROOT, HOLY_CANDLE = 17020, 17021, 17026, 17028

-- A secret stands in for the client's opaque combat values; tests mark them with
-- issecretvalue, and any comparison or concatenation with one raises an error.
local function secret()
    return setmetatable({}, {
        __eq = function() error("compared a secret value") end,
        __lt = function() error("compared a secret value") end,
        __le = function() error("compared a secret value") end,
        __concat = function() error("concatenated a secret value") end,
        __tostring = function() error("printed a secret value") end,
        __index = function() error("indexed a secret value") end,
    })
end

local function fixture(options)
    options = options or {}
    local state = {frames = {}, messages = {}, now = 100, combat = false, secrets = {}, settings = {},
        categories = {}, known = options.known or {}, carried = {}, drivers = {}, timers = {}, auraReads = 0}
    state.combat = options.combat == true
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.SlashCmdList = options.slashCmdList or {}
    for key, value in pairs(options.globals or {}) do env[key] = value end
    env.DEFAULT_CHAT_FRAME = {AddMessage = function(_, message)
        state.messages[#state.messages + 1] = message
    end}
    state.toc = {}
    for text in io.lines(ADDON .. ".toc") do
        local key, value = text:match("^##%s*([^:]+):%s*(.-)%s*$")
        if key then state.toc[key] = value end
    end
    env.C_AddOns = {GetAddOnMetadata = function(addon, field)
        equal(addon, ADDON, "metadata uses the AddOn folder name")
        return state.toc[field] or ""
    end}
    env.C_AddOns.IsAddOnLoaded = function(addon) return state.loadedAddOns and state.loadedAddOns[addon] end
    env.C_AddOns.LoadAddOn = function(addon)
        state.loadedAddOns = state.loadedAddOns or {}
        state.loadedAddOns[addon] = true
    end
    env.C_XMLUtil = {GetTemplateInfo = function(template)
        if template == "CustomAuraContainerTemplate" and not options.noAuraContainer then return {} end
    end}
    env.Enum = {StatusBarTimerDirection = {ElapsedTime = 0, RemainingTime = 1}}
    env.GetTime = function() return state.now end
    env.InCombatLockdown = function() return state.combat end
    env.issecretvalue = function(value) return state.secrets[value] == true end
    function state.secret()
        local value = secret()
        state.secrets[value] = true
        return value
    end

    -- Units: player plus party or raid members, each {name, class, buffs, dead, far, offline}.
    state.units = {player = {name = "Me", class = options.class or "MAGE", buffs = {}}}
    state.group = nil
    env.UnitClass = function(unit)
        local data = state.units[unit]
        if not data then return end
        if data.secretClass then return state.secret(), state.secret() end
        return data.class:sub(1, 1) .. data.class:sub(2):lower(), data.class
    end
    env.UnitName = function(unit)
        local data = state.units[unit]
        if data and data.secretName then return state.secret() end
        return data and data.name
    end
    env.UnitExists = function(unit) return state.units[unit] ~= nil end
    env.UnitIsUnit = function(a, b) return a == b end
    env.UnitIsDeadOrGhost = function(unit) return state.units[unit] ~= nil and state.units[unit].dead == true end
    env.UnitIsConnected = function(unit) return state.units[unit] ~= nil and state.units[unit].offline ~= true end
    env.UnitIsVisible = function(unit) return state.units[unit] ~= nil and state.units[unit].far ~= true end
    env.IsInRaid = function() return state.group == "raid" end
    env.IsInGroup = function() return state.group ~= nil end

    env.C_Spell = {
        GetSpellName = function(id) if SPELLS[id] then return SPELLS[id] end end,
        GetSpellTexture = function(id) return 2000 + id end,
        GetSpellSubtext = function(id)
            if id == GIFT_1 then return "Rank 1" elseif id == GIFT_2 then return "Rank 2" end
            return ""
        end,
    }
    -- Druid forms: state.form is the active form's index (1 Bear, 2 Cat), or nil.
    env.GetNumShapeshiftForms = function() return 2 end
    env.GetShapeshiftFormInfo = function(index) return 3000 + index, state.form == index, true, nil end
    if not options.noRange then
        env.C_Spell.IsSpellInRange = function(spell, unit)
            if state.secretRange then return state.secret() end
            return not (state.outOfRange and state.outOfRange[unit])
        end
    end
    env.C_SpellBook = {IsSpellKnown = function(id) return state.known[id] == true end}
    env.C_Item = {GetItemCount = function(id) return state.carried[id] or 0 end}
    env.C_UnitAuras = {
        -- As in client, AddOn code cannot read auras in combat.
        GetAuraDataBySpellName = function(unit, spell, filter)
            equal(filter, "HELPFUL")
            if state.combat then error("Auras cannot be accessed when secret while tainted") end
            state.auraReads = state.auraReads + 1
            local data = state.units[unit]
            if data and data.secretAuras then return state.secret() end
            -- A buff is true (no end time), a number (when it runs out), or "secret".
            local buff = data and data.buffs and data.buffs[spell]
            if buff == "secret" then return {name = spell, expirationTime = state.secret()} end
            if type(buff) == "number" then return {name = spell, duration = 1800, expirationTime = buff} end
            if buff then return {name = spell, duration = 0, expirationTime = 0} end
        end,
    }
    env.C_Timer = {After = function(seconds, callback)
        state.timers[#state.timers + 1] = {at = state.now + seconds, callback = callback}
    end}
    function state.runTimers()
        local due = {}
        for index = #state.timers, 1, -1 do
            if state.timers[index].at <= state.now then
                due[#due + 1] = table.remove(state.timers, index)
            end
        end
        for _, timer in ipairs(due) do timer.callback() end
    end
    -- Time passes and every due timer runs.
    function state.wait(seconds)
        state.now = state.now + (seconds or 1)
        state.runTimers()
    end

    -- State drivers: only "[combat] hide; show" is used.
    function state.applyDrivers()
        for frame, driver in pairs(state.drivers) do
            if driver == "[combat] hide; show" then
                frame.shown = not state.combat
            elseif driver == "[combat] show; hide" then
                frame.shown = state.combat
            else
                equal(driver, "hide", "a known driver")
                frame.shown = false
            end
        end
    end
    env.RegisterStateDriver = function(frame, kind, driver)
        equal(kind, "visibility")
        if state.combat then error("RegisterStateDriver in combat") end
        state.drivers[frame] = driver
        state.applyDrivers()
    end
    env.GameTooltip = {
        SetOwner = function() state.tooltip = {} end,
        SetText = function(_, text) state.tooltip[#state.tooltip + 1] = text end,
        AddLine = function(_, text) state.tooltip[#state.tooltip + 1] = text end,
        Show = function() end,
        Hide = function() end,
    }

    -- Settings: proxy settings with getters and setters, as the client builds them.
    if not options.noSettings then
        local function initializer(category, setting, tooltip)
            local object = {setting = setting, tooltip = tooltip}
            function object:SetParentInitializer(parent, predicate)
                self.parentInitializer, self.predicate = parent, predicate
            end
            category.initializers[#category.initializers + 1] = object
            return object
        end
        env.Settings = {
            VarType = {Boolean = "boolean", Number = "number", String = "string"},
            RegisterVerticalLayoutCategory = function(title)
                local category = {name = title, initializers = {}}
                function category:GetID() return "id:" .. title end
                state.categories[title] = category
                return category
            end,
            RegisterProxySetting = function(category, variable, variableType, label, default, getValue, setValue)
                equal(state.settings[variable], nil, "setting variables are unique")
                local setting = {category = category, variable = variable, type = variableType, name = label,
                    default = default}
                function setting:GetValue() return getValue() end
                function setting:SetValue(value) setValue(value) end
                state.settings[variable] = setting
                return setting
            end,
            RegisterAddOnCategory = function(category) state.registered = category end,
            CreateCheckbox = function(category, setting, tooltip) return initializer(category, setting, tooltip) end,
            CreateSlider = function(category, setting, sliderOptions, tooltip)
                local object = initializer(category, setting, tooltip)
                object.options = sliderOptions
                return object
            end,
            CreateSliderOptions = function(minValue, maxValue, step)
                return {minValue = minValue, maxValue = maxValue, step = step}
            end,
            OpenToCategory = function(id) state.opened = id end,
        }
    end

    local SPOTS = {CENTER = {0.5, 0.5}, BOTTOMLEFT = {0, 0}, TOP = {0.5, 1}, TOPLEFT = {0, 1}, LEFT = {0, 0.5}}
    local function widget(kind, frameName, parent, template)
        local object = {kind = kind, name = frameName, parent = parent, template = template, events = {},
            unitEvents = {}, scripts = {}, attributes = {}, points = {}, shown = true, text = "", children = {}}
        if parent and parent.children then parent.children[#parent.children + 1] = object end
        function object:SetBackdropBorderColor(...) self.backdropBorder = {...} end
        function object:SetBackdrop(backdrop) self.backdrop = backdrop end
        function object:EnableMouse(value) self.mouse = value == true end
        function object:EnableMouseWheel(value) self.wheel = value == true end
        -- As in client, secure frames refuse changes in combat.
        function object:SetScale(value)
            if state.combat and self.protected then error("SetScale in combat") end
            self.scale = value
        end
        function object:GetEffectiveScale()
            local parentScale = 1
            if self.parent and self.parent.GetEffectiveScale then parentScale = self.parent:GetEffectiveScale() end
            return (self.scale or 1) * parentScale
        end
        function object:GetWidth() return self.width or 0 end
        function object:GetHeight() return self.height or 0 end
        function object:SetWidth(width) self.width = width end
        function object:SetHeight(height) self.height = height end
        function object:SetSize(width, height) self.width, self.height = width, height end
        function object:GetCenter()
            local x, y = state.absCenter(self)
            local scale = self:GetEffectiveScale()
            return x / scale, y / scale
        end
        function object:SetShown(value)
            if value then self:Show() else self:Hide() end
        end
        function object:Show()
            if state.combat and self.protected then error("Show in combat") end
            self.shown = true
        end
        function object:Hide()
            if state.combat and self.protected then error("Hide in combat") end
            self.shown = false
        end
        function object:IsShown() return self.shown end
        function object:SetAttribute(key, value)
            if state.combat then error("SetAttribute in combat") end
            self.attributes[key] = value
        end
        function object:GetAttribute(key) return self.attributes[key] end
        function object:IsProtected() return self.protected == true end
        function object:RegisterEvent(event)
            if event == "COMBAT_LOG_EVENT_UNFILTERED" then
                error("COMBAT_LOG_EVENT_UNFILTERED is restricted")
            end
            self.events[event] = true
        end
        function object:RegisterUnitEvent(event, unit) self.unitEvents[event] = unit end
        function object:UnregisterEvent(event) self.events[event] = nil end
        function object:SetScript(script, callback) self.scripts[script] = callback end
        function object:SetPoint(...)
            if state.combat and self.protected then error("SetPoint in combat") end
            self.points[#self.points + 1] = {...}
        end
        function object:ClearAllPoints()
            if state.combat and self.protected then error("ClearAllPoints in combat") end
            self.points = {}
        end
        function object:StartMoving() self.moving = true end
        function object:StopMovingOrSizing() self.moving = false end
        function object:SetText(text) self.text = text end
        function object:SetTexture(texture) self.texture = texture end
        function object:SetColorTexture(...) self.color = {...} end
        function object:CreateTexture() return widget("Texture", nil, self) end
        function object:CreateFontString() return widget("FontString", nil, self) end
        function object:SetFrameLevel(level) self.level = level end
        function object:GetFrameLevel()
            if self.level then return self.level end
            return self.parent and self.parent.GetFrameLevel and self.parent:GetFrameLevel() + 1 or 1
        end
        function object:GetScript(script) return self.scripts[script] end
        function object:SetHideCountdownNumbers(value) self.hideNumbers = value end
        -- An AuraContainer slot: the engine (here, the test) shows its frame.
        function object:AddAuraSlot(key, filter, slotOptions)
            local button = widget("Button", nil, self)
            button.shown = false
            button.display = {}
            function button:SetIcon(region) self.display.icon = region end
            function button:SetDurationCooldown(region) self.display.cooldown = region end
            function button:SetDurationBar(region, barOptions)
                self.display.bar, self.display.barOptions = region, barOptions
            end
            slotOptions.initializeFrame(button)
            self.slots = self.slots or {}
            self.slots[#self.slots + 1] = {key = key, filter = filter, button = button,
                ids = slotOptions.candidateFilters.includeSpellIDs}
            return button
        end
        function object:SetUnit(unit) self.unit = unit end
        function object:UpdateAllAuras() self.updates = (self.updates or 0) + 1 end
        function object:CreateAnimationGroup()
            local group = {playing = false}
            function group:SetLooping(looping) self.looping = looping end
            function group:CreateAnimation(animationKind)
                local animation = {kind = animationKind}
                function animation:SetFromAlpha(value) self.from = value end
                function animation:SetToAlpha(value) self.to = value end
                function animation:SetDuration(value) self.duration = value end
                group.animation = animation
                return animation
            end
            function group:Play() self.playing = true end
            function group:Stop() self.playing = false end
            function group:IsPlaying() return self.playing end
            self.animation = group
            return group
        end
        -- Unknown methods (layout, colors, and so on) do nothing here.
        return setmetatable(object, {__index = function(_, key)
            if type(key) == "string" and key:match("^%u") then return function() end end
        end})
    end
    env.CreateFrame = function(kind, frameName, parent, template)
        local frame = widget(kind, frameName, parent, template)
        if frameName then env[frameName] = frame end
        if template == "SecureActionButtonTemplate" then
            frame.protected = true
            if parent then parent.protected = true end
        end
        state.frames[#state.frames + 1] = frame
        return frame
    end
    env.UIParent = widget("Frame", "UIParent")
    env.UIParent.width, env.UIParent.height = 1000, 800
    env.IsShiftKeyDown = function() return state.shift == true end
    -- Screen position of a frame's center, from its last point.
    function state.absCenter(frame)
        if frame == env.UIParent or frame == nil then return 500, 400 end
        local point = frame.points[#frame.points]
        local relative = point[2] or env.UIParent
        local relativeScale = relative == env.UIParent and 1 or relative:GetEffectiveScale()
        local rx, ry = state.absCenter(relative)
        local spot = SPOTS[point[3]]
        local width = (relative.width or 0) * relativeScale
        local height = (relative.height or 0) * relativeScale
        local scale = frame:GetEffectiveScale()
        return rx + (spot[1] - 0.5) * width + point[4] * scale, ry + (spot[2] - 0.5) * height + point[5] * scale
    end
    function state.emit(event, ...)
        for _, frame in ipairs(state.frames) do
            local unit = frame.unitEvents[event]
            local first = ...
            if frame.events[event] or (unit and unit == first) then
                frame.scripts.OnEvent(frame, event, ...)
            end
        end
    end
    -- An event, then the coalesced refresh it schedules.
    function state.update(event, ...)
        state.emit(event, ...)
        state.wait(1)
    end

    for _, globalName in ipairs(options.remove or {}) do env[globalName] = nil end
    state.dbr = {}
    for _, path in ipairs(options.files or RUNTIME_FILES) do
        local chunk, message = loadfile(path)
        if not chunk then error(message) end
        setfenv(chunk, env)
        chunk(ADDON, state.dbr)
    end
    env.DyresBuffRemindersDB = options.db
    state.env = env
    state.emit("ADDON_LOADED", ADDON)
    state.emit("PLAYER_LOGIN")

    function state.slash(text) env.SlashCmdList.DYRESBUFFREMINDERS(text) end
    function state.last() return state.messages[#state.messages] end
    function state.clear() state.messages = {} end
    function state.said(fragment)
        for _, message in ipairs(state.messages) do
            if message:find(fragment, 1, true) then return true end
        end
        return false
    end
    function state.icon(key) return env["DyresBuffRemindersIcon_" .. key] end
    function state.cast(id) state.emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", id) end
    function state.buff(unit, spell, value)
        state.units[unit].buffs = state.units[unit].buffs or {}
        state.units[unit].buffs[spell] = value or true
    end
    function state.party(members)
        state.group = "party"
        for index, member in ipairs(members) do state.units["party" .. index] = member end
        state.update("GROUP_ROSTER_UPDATE")
    end
    return state
end

-- Loading, commands, and saved settings -----------------------------------------------

test("the TOC loads every runtime file in order, with the release metadata", function()
    equal(table.concat(RUNTIME_FILES, ","), "Commands.lua,Core.lua,Layout.lua,Buffs.lua,Reminders.lua,Seals.lua,Options.lua")
    local state = fixture()
    equal(state.toc.Category, "Buffs & Debuffs")
    equal(state.toc.Author, "Dyre")
    equal(state.toc.SavedVariablesPerCharacter, "DyresBuffRemindersDB")
end)
test("login says the version and author, and that DBR is ready", function()
    local state = fixture()
    equal(state.messages[1], "DBR: Dyre's Buff Reminders " .. state.toc.Version .. " by Dyre")
    equal(state.messages[2], "DBR:   Ready. Type /dbr to open the settings.")
    equal(#state.messages, 2, "nothing else on a Mage")
end)
test("a mixed install stays off and says what to do", function()
    local state = fixture({files = {"Commands.lua", "Core.lua", "Layout.lua", "Buffs.lua", "Seals.lua", "Options.lua"}})
    equal(state.dbr.available, false)
    contains(state.last(), "missing ClassReminders")
    state.clear()
    state.slash("unlock")
    contains(state.last(), "unavailable")
    state.slash("debug")
    contains(state.messages[2], "available=false", "debug still runs")
    local noBuffs = fixture({files = {"Commands.lua", "Core.lua", "Layout.lua", "Reminders.lua", "Seals.lua", "Options.lua"}})
    contains(noBuffs.last(), "missing Buffs.lua")
end)
test("a client without a required API stays off", function()
    local state = fixture({remove = {"RegisterStateDriver"}})
    equal(state.dbr.available, false)
    equal(state.last(), "DBR: This client lacks RegisterStateDriver, which the buff reminders need. DBR stays off.")
end)
test("commands are one word, and anything else shows the usage", function()
    local state = fixture()
    for _, text in ipairs({"nope", "unlock now", "debug_reminders"}) do
        state.clear()
        state.slash(text)
        equal(state.last(), "DBR: Use /dbr, /dbr options, /dbr unlock, /dbr lock, /dbr reset, or /dbr debug.")
    end
    state.slash("")
    equal(state.opened, "id:Dyre's Buff Reminders")
    state.opened = nil
    state.slash("  OPTIONS ")
    equal(state.opened, "id:Dyre's Buff Reminders")
end)
test("the settings never open in combat", function()
    local state = fixture()
    state.combat = true
    state.slash("")
    equal(state.opened, nil)
    contains(state.last(), "out of combat")
end)
test("without the settings API, /dbr says which commands to use", function()
    local state = fixture({noSettings = true})
    state.slash("")
    contains(state.last(), "/dbr unlock")
end)
test("another AddOn's /dbr is reported once at login", function()
    local state = fixture({slashCmdList = {OTHER = function() end}, globals = {SLASH_OTHER1 = "/DBR"}})
    equal(state.said("Another AddOn (OTHER) also uses /dbr. Use /buffreminders instead."), true)
    equal(state.env.SLASH_DYRESBUFFREMINDERS2, "/buffreminders")
end)
test("damaged or old saved settings are repaired", function()
    local state = fixture({db = {enabled = "yes", locked = false, grid = 0, spells = {arcaneIntellect = false,
        mageArmor = "on", gone = true}, groups = "bad", icons = {arcaneIntellect = {scale = 137,
        position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 10, y = 20}}, mageArmor = {scale = "x",
        position = {point = 1}}}, last = {mageArmor = "Frost Armor", arcaneIntellect = "Arcane Intellect"}}})
    local db = state.dbr.db
    equal(db.enabled, true)
    equal(db.locked, false)
    equal(db.grid, true)
    equal(db.spells.arcaneIntellect, false)
    equal(db.spells.mageArmor, true, "a bad value takes the default")
    equal(db.spells.gone, nil, "keys no class has are dropped")
    equal(db.spells.dampenMagic, false, "off by default")
    equal(db.spells.markOfTheWild, true, "every class's buffs keep a setting")
    equal(db.groups.arcaneIntellect, true)
    equal(db.groups.mageArmor, nil, "no group setting for a self buff")
    equal(db.icons.arcaneIntellect.scale, 140, "stepped by 10")
    equal(db.icons.arcaneIntellect.position.x, 10)
    equal(db.icons.mageArmor.scale, 100)
    equal(db.icons.mageArmor.position, nil)
    equal(db.last.mageArmor, "Frost Armor")
    equal(db.last.arcaneIntellect, nil, "only buffs with several spells remember")
    equal(db.lead, 5, "5 seconds by default")
    equal(state.dbr.SanitizeLead(99), 30)
    equal(state.dbr.SanitizeLead(-2), 0)
    equal(state.dbr.SanitizeLead(2.5), 5)
    equal(state.dbr.SanitizeReminderScale(10), 50)
    equal(state.dbr.SanitizeReminderScale(500), 200)
end)

-- The buff lists ---------------------------------------------------------------------

test("Buffs.lua: unique keys, and every group version has a reagent", function()
    local state = fixture()
    local keys = {}
    for class, list in pairs(state.dbr.BUFFS) do
        for _, reminder in ipairs(list) do
            equal(keys[reminder.key], nil, "key " .. reminder.key .. " is unique")
            keys[reminder.key] = class
            equal(type(reminder.label), "string")
            equal(#reminder.spells > 0, true)
            for _, id in ipairs(reminder.prefer or {}) do
                local listed = false
                for _, spell in ipairs(reminder.spells) do listed = listed or spell == id end
                equal(listed, true, reminder.key .. " prefers one of its own spells")
            end
            for _, entry in ipairs(reminder.group and reminder.group.spells or {}) do
                equal(type(entry.spell), "number")
                equal(type(entry.reagent), "number", reminder.key .. " group version has a reagent")
            end
        end
    end
    for _, class in ipairs({"MAGE", "WARLOCK", "DRUID", "PRIEST"}) do
        equal(#state.dbr.BUFFS[class] > 0, true, class .. " has buffs")
    end
end)
test("a class without buffs loads, says so once, and shows nothing", function()
    local state = fixture({class = "WARRIOR", known = {[INTELLECT] = true}})
    equal(state.dbr.available, true)
    contains(state.last(), "no buff reminders for your class yet")
    equal(state.env.DyresBuffRemindersHolder, nil)
    equal(state.icon("arcaneIntellect"), nil)
    equal(state.categories["Dyre's Buff Reminders"] ~= nil, true, "the settings page still opens")
    state.clear()
    state.slash("unlock")
    contains(state.last(), "no buff reminders for your class")
    state.slash("reset")
    state.slash("debug")
    contains(state.last(), "no buff reminders for this class")
end)

-- Mage --------------------------------------------------------------------------------

test("Mage: an icon shows while you lack a buff you know, with a pulsing border", function()
    local state = fixture({known = {[INTELLECT] = true, [FROST_ARMOR] = true}})
    local intellect, armor = state.icon("arcaneIntellect"), state.icon("mageArmor")
    equal(intellect.shown, true)
    equal(intellect.glow.animation.playing, true, "the border pulses")
    equal(intellect.glow.animation.looping, "BOUNCE")
    equal(intellect.texture.texture, 2000 + INTELLECT)
    equal(armor.shown, true)
    equal(state.icon("dampenMagic").shown, false, "off by default, and not known")
    state.buff("player", "Arcane Intellect")
    state.buff("player", "Ice Armor")
    state.update("UNIT_AURA", "player")
    equal(intellect.shown, false)
    equal(intellect.glow.animation.playing, false)
    equal(armor.shown, false, "any armor counts")
    state.units.player.buffs = {["Arcane Brilliance"] = true}
    state.update("UNIT_AURA", "player")
    equal(intellect.shown, false, "Arcane Brilliance counts")
    equal(armor.shown, true)
end)
test("Mage: unknown buffs never show, and learning one shows it", function()
    local state = fixture()
    equal(state.icon("arcaneIntellect").shown, false)
    state.known[INTELLECT] = true
    state.update("SPELLS_CHANGED")
    equal(state.icon("arcaneIntellect").shown, true)
end)
test("reminders hide in combat, never read auras then, and come back after", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect, holder = state.icon("arcaneIntellect"), state.env.DyresBuffRemindersHolder
    equal(intellect.shown, true)
    equal(holder.shown, true)
    equal(state.drivers[holder], "[combat] hide; show", "the game hides the secure icons for combat")
    state.combat = true
    state.applyDrivers()
    equal(holder.shown, false)
    state.buff("player", "Arcane Intellect")
    local reads = state.auraReads
    state.update("UNIT_AURA", "player")
    state.slash("unlock")
    contains(state.last(), "after combat")
    equal(state.auraReads, reads, "no aura read in combat")
    equal(intellect.shown, true, "no secure change in combat")
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
    equal(holder.shown, true)
    equal(intellect.shown, true, "unlocked after combat: a sample to drag")
    equal(intellect.attributes.type1, nil, "dragging never casts")
end)
test("a reload in combat waits for the end of combat to set up the icons", function()
    local state = fixture({known = {[INTELLECT] = true}, combat = true})
    equal(state.env.DyresBuffRemindersHolder, nil, "no secure frames set up in combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(state.drivers[state.env.DyresBuffRemindersHolder], "[combat] hide; show")
    equal(state.icon("arcaneIntellect").shown, true)
end)
test("Arcane Intellect counts group members who use mana", function()
    local state = fixture({known = {[INTELLECT] = true}})
    state.buff("player", "Arcane Intellect")
    state.party({{name = "Healy", class = "PRIEST"}, {name = "Stabby", class = "ROGUE"},
        {name = "Faraway", class = "DRUID", far = true}, {name = "Shocky", class = "SHAMAN"}})
    local intellect = state.icon("arcaneIntellect")
    equal(intellect.shown, true)
    equal(intellect.count.text, 2, "Healy and Shocky; not the rogue or someone out of sight")
    equal(table.concat(intellect.missing, ","), "Healy,Shocky")
    state.units.party1.buffs = {["Arcane Brilliance"] = true}
    state.units.party4.buffs = {["Arcane Intellect"] = true}
    state.update("UNIT_AURA", "party1")
    equal(intellect.shown, false)
    state.units.party1.buffs = nil
    state.settings.DBR_GROUP_ARCANEINTELLECT:SetValue(false)
    equal(intellect.shown, false, "only you when the group option is off")
end)
test("dead, offline, and secret members are handled without reading secrets", function()
    local state = fixture({known = {[INTELLECT] = true}})
    state.buff("player", "Arcane Intellect")
    state.party({{name = "Ghost", class = "PRIEST", dead = true}, {name = "Gone", class = "MAGE", offline = true},
        {name = "Hidden", class = "MAGE", secretName = true}, {name = "Masked", class = "MAGE",
        secretClass = true}, })
    local intellect = state.icon("arcaneIntellect")
    equal(table.concat(intellect.missing, ","), "party3,Masked", "a secret name shows the unit")
    state.units.party3.secretAuras = true
    state.units.party4.secretAuras = true
    state.update("UNIT_AURA", "party3")
    equal(intellect.shown, false, "a secret aura answer counts as buffed")
end)
test("clicking Arcane Intellect buffs you first, then each group member who lacks it", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    equal(intellect.protected, true, "a secure button")
    equal(intellect.attributes.type1, "spell")
    equal(intellect.attributes.spell1, "Arcane Intellect")
    equal(intellect.attributes.unit1, "player", "you first")
    state.buff("player", "Arcane Intellect")
    state.outOfRange = {party2 = true}
    state.party({{name = "Stabby", class = "ROGUE"}, {name = "Healy", class = "PRIEST"},
        {name = "Shocky", class = "SHAMAN"}})
    equal(intellect.attributes.unit1, "party3", "the first in range; never the rogue")
    state.buff("party3", "Arcane Intellect")
    state.update("UNIT_AURA", "party3")
    equal(intellect.attributes.unit1, "party2", "out of range but the only one left")
    state.buff("party2", "Arcane Intellect")
    state.update("UNIT_AURA", "party2")
    equal(intellect.shown, false)
    equal(intellect.attributes.type1, nil, "nothing to cast")
end)
test("a secret range answer counts as in range; no range API means in range", function()
    local state = fixture({known = {[INTELLECT] = true}})
    state.buff("player", "Arcane Intellect")
    state.secretRange = true
    state.party({{name = "Healy", class = "PRIEST"}})
    equal(state.icon("arcaneIntellect").attributes.unit1, "party1")
    local noRange = fixture({known = {[INTELLECT] = true}, noRange = true})
    noRange.buff("player", "Arcane Intellect")
    noRange.party({{name = "Healy", class = "PRIEST"}})
    equal(noRange.icon("arcaneIntellect").attributes.unit1, "party1")
end)
test("with two or more missing, Arcane Brilliance if you know it and carry Arcane Powder", function()
    local state = fixture({known = {[INTELLECT] = true, [BRILLIANCE] = true}})
    local intellect = state.icon("arcaneIntellect")
    state.party({{name = "Healy", class = "PRIEST"}})
    equal(intellect.attributes.spell1, "Arcane Intellect", "no Arcane Powder")
    state.carried[ARCANE_POWDER] = 5
    state.update("BAG_UPDATE_DELAYED")
    equal(intellect.attributes.spell1, BRILLIANCE, "the group version, by ID")
    intellect.scripts.OnEnter(intellect)
    equal(state.tooltip[3], "Click: Arcane Brilliance.")
    state.buff("player", "Arcane Intellect")
    state.update("UNIT_AURA", "player")
    equal(intellect.attributes.spell1, "Arcane Intellect", "one missing: the single buff")
    equal(intellect.attributes.unit1, "party1")
    intellect.scripts.OnEnter(intellect)
    equal(state.tooltip[2], "Missing: Healy")
    equal(state.tooltip[3], "Click: Arcane Intellect on Healy.")
end)
test("clicking Armor recasts the armor you used last, else your best", function()
    local state = fixture({known = {[FROST_ARMOR] = true, [ICE_ARMOR] = true}})
    local armor = state.icon("mageArmor")
    equal(armor.attributes.spell1, "Ice Armor", "your best")
    equal(armor.attributes.unit1, "player")
    state.cast(FROST_ARMOR)
    state.update("UNIT_AURA", "player")
    equal(armor.attributes.spell1, "Frost Armor", "the one you used")
    equal(state.dbr.db.last.mageArmor, "Frost Armor", "saved per character")
    state.cast(state.secret())
    equal(state.dbr.db.last.mageArmor, "Frost Armor", "a secret spell ID is ignored")
    state.cast(INTELLECT)
    equal(state.dbr.db.last.arcaneIntellect, nil)
end)
test("aura changes in a burst refresh once, and other units' auras are ignored", function()
    local state = fixture({known = {[INTELLECT] = true}})
    state.buff("player", "Arcane Intellect")
    local reads = state.auraReads
    state.emit("UNIT_AURA", "player")
    state.emit("UNIT_AURA", "player")
    state.emit("UNIT_AURA", "party1")
    equal(state.auraReads, reads, "nothing read until the refresh")
    equal(#state.timers, 1, "one refresh for the burst")
    state.wait(1)
    equal(state.icon("arcaneIntellect").shown, false)
    state.emit("UNIT_AURA", "nameplate3")
    state.emit("UNIT_AURA", "target")
    state.emit("UNIT_AURA", state.secret())
    equal(#state.timers, 0)
end)
test("dead, you see no reminders until you are alive", function()
    local state = fixture({known = {[INTELLECT] = true}})
    state.units.player.dead = true
    state.update("PLAYER_DEAD")
    equal(state.icon("arcaneIntellect").shown, false)
    state.units.player.dead = nil
    state.update("PLAYER_UNGHOST")
    equal(state.icon("arcaneIntellect").shown, true)
end)

-- Warlock -----------------------------------------------------------------------------

test("Warlock: Demon Skin counts as Demon Armor, and a click casts your best", function()
    local state = fixture({class = "WARLOCK", known = {[DEMON_SKIN] = true}})
    local armor = state.icon("demonArmor")
    equal(armor.shown, true)
    equal(armor.attributes.spell1, "Demon Skin")
    equal(state.icon("arcaneIntellect"), nil, "only your class's buffs")
    state.known[DEMON_ARMOR] = true
    state.update("SPELLS_CHANGED")
    equal(armor.attributes.spell1, "Demon Armor")
    equal(armor.texture.texture, 2000 + DEMON_ARMOR)
    state.buff("player", "Demon Skin")
    state.update("UNIT_AURA", "player")
    equal(armor.shown, false, "Demon Skin counts")
end)

-- Druid -------------------------------------------------------------------------------

test("Druid: Mark of the Wild for you and the whole group, warriors too", function()
    local state = fixture({class = "DRUID", known = {[MARK] = true, [THORNS] = true}})
    local mark, thorns = state.icon("markOfTheWild"), state.icon("thorns")
    equal(mark.shown, true)
    equal(thorns.shown, true)
    equal(mark.attributes.spell1, "Mark of the Wild")
    equal(thorns.attributes.spell1, "Thorns")
    state.buff("player", "Mark of the Wild")
    state.party({{name = "Tanky", class = "WARRIOR"}, {name = "Stabby", class = "ROGUE"}})
    equal(table.concat(mark.missing, ","), "Tanky,Stabby", "everyone counts for a buff that is not mana")
    equal(mark.attributes.unit1, "party1")
    state.buff("player", "Thorns")
    state.update("UNIT_AURA", "player")
    equal(thorns.shown, false)
    equal(thorns.count.text, "", "no group count on a self buff")
end)
test("Druid: Gift of the Wild casts the best rank you carry the reagent for", function()
    local state = fixture({class = "DRUID", known = {[MARK] = true, [GIFT_1] = true, [GIFT_2] = true}})
    local mark = state.icon("markOfTheWild")
    state.party({{name = "Tanky", class = "WARRIOR"}})
    equal(mark.attributes.spell1, "Mark of the Wild", "no reagent")
    state.carried[WILD_BERRIES] = 2
    state.update("BAG_UPDATE_DELAYED")
    equal(mark.attributes.spell1, GIFT_1, "rank 1 for Wild Berries")
    state.carried[WILD_THORNROOT] = 1
    state.update("BAG_UPDATE_DELAYED")
    equal(mark.attributes.spell1, GIFT_2, "rank 2 for Wild Thornroot")
    state.buff("player", "Gift of the Wild")
    state.buff("party1", "Gift of the Wild")
    state.update("UNIT_AURA", "party1")
    equal(mark.shown, false, "Gift of the Wild counts")
end)

test("Druid: in a form, a click leaves it first, then casts", function()
    local state = fixture({class = "DRUID", known = {[MARK] = true, [GIFT_1] = true}})
    local mark = state.icon("markOfTheWild")
    equal(mark.attributes.type1, "spell", "not in a form: a plain cast")
    state.form = 1
    state.update("UPDATE_SHAPESHIFT_FORM")
    equal(mark.attributes.type1, "macro")
    equal(mark.attributes.macrotext1, "/cancelform\n/cast [@player] Mark of the Wild")
    equal(mark.attributes.spell1, nil)
    mark.scripts.OnEnter(mark)
    equal(state.tooltip[3], "Click: Mark of the Wild on you (leaves your form first).")
    state.buff("player", "Mark of the Wild")
    state.carried[WILD_BERRIES] = 1
    state.party({{name = "Tanky", class = "WARRIOR"}, {name = "Stabby", class = "ROGUE"}})
    equal(mark.attributes.macrotext1, "/cancelform\n/cast [@party1] Gift of the Wild(Rank 1)",
        "the group version by rank, for its reagent")
    state.form = nil
    state.update("UPDATE_SHAPESHIFT_FORM")
    equal(mark.attributes.type1, "spell")
    equal(mark.attributes.macrotext1, nil)
    equal(mark.attributes.spell1, GIFT_1)
end)

-- Priest ------------------------------------------------------------------------------

test("Priest: Fortitude and Inner Fire on by default; the others are options", function()
    local state = fixture({class = "PRIEST", known = {[FORTITUDE] = true, [INNER_FIRE] = true, [14752] = true,
        [976] = true}})
    equal(state.icon("fortitude").shown, true)
    equal(state.icon("innerFire").shown, true)
    equal(state.icon("divineSpirit").shown, false, "off by default")
    equal(state.icon("shadowProtection").shown, false, "off by default")
    state.settings.DBR_BUFF_DIVINESPIRIT:SetValue(true)
    equal(state.icon("divineSpirit").shown, true)
    state.buff("player", "Divine Spirit")
    state.party({{name = "Tanky", class = "WARRIOR"}, {name = "Zappy", class = "MAGE"}})
    equal(table.concat(state.icon("divineSpirit").missing, ","), "Zappy", "Divine Spirit: only mana users")
    equal(table.concat(state.icon("fortitude").missing, ","), "you,Tanky,Zappy")
end)
test("Priest: Prayer of Fortitude rank 1 with Holy Candles", function()
    local state = fixture({class = "PRIEST", known = {[FORTITUDE] = true, [PRAYER_1] = true, [PRAYER_2] = true}})
    state.carried[HOLY_CANDLE] = 3
    state.party({{name = "Tanky", class = "WARRIOR"}})
    equal(state.icon("fortitude").attributes.spell1, PRAYER_1, "rank 2 needs Sacred Candles")
end)

-- Paladin -----------------------------------------------------------------------------

test("Paladin: Righteous Fury, on you only", function()
    local state = fixture({class = "PALADIN", known = {[25780] = true}})
    local fury = state.icon("righteousFury")
    equal(fury.shown, true)
    equal(fury.attributes.spell1, "Righteous Fury")
    equal(fury.attributes.unit1, "player")
    state.party({{name = "Tanky", class = "WARRIOR"}})
    equal(table.concat(fury.missing, ","), "you", "a self buff")
    equal(state.settings.DBR_GROUP_RIGHTEOUSFURY, nil, "no group switch")
    state.buff("player", "Righteous Fury")
    state.update("UNIT_AURA", "player")
    equal(fury.shown, false)
end)

-- Paladin seal timer ----------------------------------------------------------------------

local RIGHTEOUSNESS, COMMAND = 21084, 20375

local function sealFixture(options)
    options = options or {}
    options.class = options.class or "PALADIN"
    options.known = options.known or {[RIGHTEOUSNESS] = true, [COMMAND] = true}
    return fixture(options)
end

test("Paladin: the seal timer shows a seal's time left, drawn by the aura container", function()
    local state = sealFixture()
    local display, button = state.env.DyresBuffRemindersSeal, state.env.DyresBuffRemindersSealButton
    equal(display.shown, true)
    equal(button.protected, true, "a secure button")
    equal(state.loadedAddOns.Blizzard_AuraContainer, true)
    local container
    for _, frame in ipairs(state.frames) do
        if frame.kind == "AuraContainer" then container = frame end
    end
    equal(container.unit, "player")
    local slot = container.slots[1]
    equal(slot.filter, "HELPFUL")
    for _, id in ipairs({21084, 20293, 20375, 20920, 21082, 20308, 20164, 20165, 20349, 20166, 20357}) do
        equal(slot.ids[id], true, "seal ID " .. id)
    end
    equal(slot.button.display.cooldown.hideNumbers, false, "the time left as numbers")
    equal(slot.button.display.barOptions.direction, 1, "a bar that drains")
    equal(slot.button.mouse, false, "the seal never takes the click")
    equal(container:GetFrameLevel() > button:GetFrameLevel(), true, "a seal covers the missing picture")
end)
test("Paladin: no seal in combat pulses your last seal, and a click casts it", function()
    local state = sealFixture()
    local button = state.env.DyresBuffRemindersSealButton
    equal(state.drivers[button], "[combat] show; hide")
    equal(button.shown, false, "out of combat with no seal: nothing")
    equal(button.attributes.type1, "spell")
    equal(button.attributes.spell1, "Seal of Righteousness", "Righteousness first")
    equal(button.attributes.unit1, "player")
    equal(button.glow.animation.playing, true)
    equal(button.texture.texture, 2000 + RIGHTEOUSNESS)
    state.combat = true
    state.applyDrivers()
    equal(button.shown, true, "in combat, under the seal icon")
    state.cast(COMMAND)
    equal(button.attributes.spell1, "Seal of Righteousness", "nothing secure changes in combat")
    equal(state.dbr.db.last.seal, "Seal of Command")
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
    equal(button.attributes.spell1, "Seal of Command", "the seal you used last")
    button.scripts.OnEnter(button)
    equal(state.tooltip[2], "Click: Seal of Command.")
end)
test("the seal timer: only for Paladins who know a seal; a switch; unlocks with the reminders", function()
    equal(sealFixture({class = "PRIEST"}).env.DyresBuffRemindersSeal, nil)
    local unknown = sealFixture({known = {}})
    equal(unknown.drivers[unknown.env.DyresBuffRemindersSealButton], "hide", "no seal known: never shows")
    local state = sealFixture()
    local display, button = state.env.DyresBuffRemindersSeal, state.env.DyresBuffRemindersSealButton
    state.settings.DBR_SEAL:SetValue(false)
    equal(display.shown, false)
    equal(state.drivers[button], "hide")
    equal(button.attributes.type1, nil)
    state.settings.DBR_SEAL:SetValue(true)
    equal(state.drivers[button], "[combat] show; hide")
    state.slash("unlock")
    equal(state.drivers[button], "hide", "unlocked, the drag reaches the display")
    equal(display.mouse, true)
    equal(display.sample.shown, true)
    equal(button.attributes.type1, nil, "dragging never casts")
    display.scripts.OnMouseWheel(display, 1)
    equal(state.dbr.db.seal.scale, 110)
    display.scripts.OnDragStart(display)
    display:ClearAllPoints()
    display:SetPoint("CENTER", nil, "BOTTOMLEFT", 100 / display:GetEffectiveScale(),
        100 / display:GetEffectiveScale())
    display.scripts.OnDragStop(display)
    equal(state.dbr.db.seal.position.relativePoint, "BOTTOMLEFT")
    state.slash("lock")
    equal(display.mouse, false)
    equal(state.drivers[button], "[combat] show; hide")
    state.slash("reset")
    equal(state.dbr.db.seal.position, nil)
    equal(state.dbr.db.seal.scale, 100)
    state.clear()
    state.slash("debug")
    contains(state.last(), "debug seal on=true click=Seal of Righteousness driver=[combat] show; hide unknownIDs=none")
end)
test("the seal timer waits for the end of combat after a reload, and needs the aura container", function()
    local state = sealFixture({combat = true})
    equal(state.env.DyresBuffRemindersSealButton, nil)
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(state.drivers[state.env.DyresBuffRemindersSealButton], "[combat] show; hide")
    local bare = sealFixture({noAuraContainer = true, known = {[RIGHTEOUSNESS] = true, [25780] = true}})
    equal(bare.said("The seal timer stays off"), true)
    equal(bare.env.DyresBuffRemindersSeal, nil)
    equal(bare.icon("righteousFury").shown, true, "Righteous Fury still reminds")
    equal(bare.settings.DBR_SEAL, nil, "no switch without the timer")
end)
test("damaged seal settings are repaired", function()
    local state = sealFixture({db = {seal = {enabled = "no", scale = 999, position = "x"}}})
    equal(state.dbr.db.seal.enabled, true)
    equal(state.dbr.db.seal.scale, 200)
    equal(state.dbr.db.seal.position, nil)
end)

-- Running out ---------------------------------------------------------------------------

test("an icon shows the lead time before your buff runs out, from one timer", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    state.buff("player", "Arcane Intellect", state.now + 60)
    state.update("UNIT_AURA", "player")
    equal(intellect.shown, false, "55 seconds before the lead time")
    local reads = state.auraReads
    state.wait(50)
    equal(intellect.shown, false)
    equal(state.auraReads, reads, "no polling: nothing read before the timer")
    state.wait(5)
    equal(intellect.shown, true, "5 seconds left")
    equal(intellect.attributes.spell1, "Arcane Intellect", "a click recasts it")
    equal(intellect.attributes.unit1, "player")
    intellect.scripts.OnEnter(intellect)
    equal(state.tooltip[2], "Running out: you")
    state.buff("player", "Arcane Intellect", state.now + 1800)
    state.update("UNIT_AURA", "player")
    equal(intellect.shown, false, "recast")
end)
test("group members' buffs running out show too, and the earliest sets the timer", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    state.buff("player", "Arcane Intellect", state.now + 600)
    state.party({{name = "Healy", class = "PRIEST", buffs = {["Arcane Intellect"] = state.now + 30}},
        {name = "Zappy", class = "MAGE"}})
    equal(table.concat(intellect.missing, ","), "Zappy")
    equal(#intellect.soon, 0)
    state.wait(25)
    equal(table.concat(intellect.missing, ","), "Zappy")
    equal(table.concat(intellect.soon, ","), "Healy")
    equal(intellect.count.text, 2)
    intellect.scripts.OnEnter(intellect)
    equal(state.tooltip[2], "Missing: Zappy")
    equal(state.tooltip[3], "Running out: Healy")
end)
test("a buff with no readable end counts as on; the lead time is a setting", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    state.buff("player", "Arcane Intellect", "secret")
    state.update("UNIT_AURA", "player")
    equal(intellect.shown, false, "a secret end time counts as on")
    equal(#state.timers, 0, "and sets no timer")
    state.settings.DBR_LEAD:SetValue(0)
    equal(state.dbr.db.lead, 0)
    state.buff("player", "Arcane Intellect", state.now + 3)
    state.update("UNIT_AURA", "player")
    equal(intellect.shown, false, "0: only once it is gone")
    state.settings.DBR_LEAD:SetValue(10)
    equal(intellect.shown, true)
    state.settings.DBR_LEAD:SetValue(99)
    equal(state.dbr.db.lead, 30)
end)
test("a buff running out in combat shows after combat", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    state.buff("player", "Arcane Intellect", state.now + 20)
    state.update("UNIT_AURA", "player")
    state.combat = true
    state.wait(16)
    equal(intellect.shown, false, "nothing changes in combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(intellect.shown, true)
end)

-- Moving and resizing -----------------------------------------------------------------

local function iconCenter(state, key)
    local x, y = state.absCenter(state.icon(key))
    return math.floor(x + 0.5), math.floor(y + 0.5)
end
local function drop(icon, x, y)
    icon.scripts.OnDragStart(icon)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", nil, "BOTTOMLEFT", x / icon:GetEffectiveScale(), y / icon:GetEffectiveScale())
    icon.scripts.OnDragStop(icon)
end

test("unlocked, every reminder shows to drag, casts nothing, and the grid shows", function()
    local state = fixture({known = {[INTELLECT] = true}})
    state.slash("unlock")
    contains(state.last(), "unlocked")
    local intellect, armor = state.icon("arcaneIntellect"), state.icon("mageArmor")
    equal(intellect.shown, true)
    equal(armor.shown, true, "shown to drag even before you know it")
    equal(intellect.mover.shown, true)
    equal(intellect.attributes.type1, nil)
    equal(state.dbr.grid.shown, true)
    equal(state.settings.DBR_UNLOCKED:GetValue(), true, "the switch follows the command")
    state.settings.DBR_GRID:SetValue(false)
    equal(state.dbr.grid.shown, false)
    state.settings.DBR_UNLOCKED:SetValue(false)
    equal(state.dbr.db.locked, true)
    contains(state.last(), "locked")
    equal(intellect.mover.shown, false)
    equal(intellect.attributes.type1, "spell")
    equal(armor.shown, false)
end)
test("icons start in a row 20 apart, and a drop near another snaps beside it", function()
    local state = fixture()
    state.dbr.db.spells.dampenMagic = true
    state.slash("unlock")
    local intellect, armor, dampen = state.icon("arcaneIntellect"), state.icon("mageArmor"), state.icon("dampenMagic")
    local ix, iy = iconCenter(state, "arcaneIntellect")
    local ax = iconCenter(state, "mageArmor")
    equal(ax - ix, 60, "40 wide, 20 apart")
    equal(select(1, iconCenter(state, "dampenMagic")) - ax, 60)
    equal(iy, 400 + 180)
    drop(intellect, ax + 64, iy + 9)
    local nx, ny = iconCenter(state, "arcaneIntellect")
    equal(nx, ax + 60, "snapped 20 past Armor")
    equal(ny, iy, "aligned")
    drop(dampen, 100, 100)
    equal(select(1, iconCenter(state, "dampenMagic")), 100, "far from everything: stays")
    equal(state.dbr.db.icons.dampenMagic.position.relativePoint, "BOTTOMLEFT", "saved on its own")
    for _ = 1, 5 do armor.scripts.OnMouseWheel(armor, 1) end
    equal(state.dbr.db.icons.mageArmor.scale, 150)
    equal(armor.scale, 1.5)
    state.slash("lock")
    armor.scripts.OnMouseWheel(armor, 1)
    equal(state.dbr.db.icons.mageArmor.scale, 150, "locked icons do not resize")
    state.slash("reset")
    contains(state.last(), "default places")
    equal(state.dbr.db.icons.mageArmor.scale, 100)
    equal(state.dbr.db.icons.dampenMagic.position, nil)
    equal(select(1, iconCenter(state, "dampenMagic")) - ax, 60, "back in the row")
end)
test("reset in combat waits for the end of combat", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    state.slash("unlock")
    drop(intellect, 100, 100)
    state.slash("lock")
    state.combat = true
    state.slash("reset")
    contains(state.last(), "after combat")
    equal(select(1, iconCenter(state, "arcaneIntellect")), 100)
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(select(1, iconCenter(state, "arcaneIntellect")), 500 - 60)
end)
test("Shift-dragging an icon moves every icon snapped to it", function()
    local state = fixture()
    state.slash("unlock")
    local intellect = state.icon("arcaneIntellect")
    local ix, iy = iconCenter(state, "arcaneIntellect")
    local ax, ay = iconCenter(state, "mageArmor")
    state.shift = true
    drop(intellect, ix - 300, iy - 100)
    local mx, my = iconCenter(state, "mageArmor")
    equal(mx, ax - 300, "the row moves together")
    equal(my, ay - 100)
end)

-- Settings page, tooltips, and debug ---------------------------------------------------

test("the settings page lists your class's buffs, each group switch under its buff", function()
    local state = fixture({class = "PRIEST", known = {[FORTITUDE] = true}})
    local page = state.categories["Dyre's Buff Reminders"]
    equal(state.registered, page)
    local names = {}
    for _, row in ipairs(page.initializers) do names[#names + 1] = row.setting.name end
    equal(table.concat(names, "|"), "Buff reminders|Power Word: Fortitude|Power Word: Fortitude: also your group|"
        .. "Inner Fire|Divine Spirit|Divine Spirit: also your group|Shadow Protection|"
        .. "Shadow Protection: also your group|Remind before a buff runs out (seconds)|Unlock to move them|"
        .. "Show a grid while unlocked")
    local group = page.initializers[3]
    equal(group.parentInitializer, page.initializers[2])
    contains(group.tooltip, "Prayer of Fortitude")
    contains(page.initializers[6].tooltip, "who uses mana")
    state.settings.DBR_ENABLED:SetValue(false)
    equal(state.icon("fortitude").shown, false)
    equal(group.predicate(), false)
    state.settings.DBR_ENABLED:SetValue(true)
    equal(state.icon("fortitude").shown, true)
    state.settings.DBR_BUFF_FORTITUDE:SetValue(false)
    equal(state.icon("fortitude").shown, false)
    equal(state.dbr.db.spells.fortitude, false)
end)
test("the unlocked tooltip says how to move; /dbr debug lists each reminder", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    intellect.scripts.OnEnter(intellect)
    equal(state.tooltip[1], "Arcane Intellect")
    equal(state.tooltip[2], "Missing: you")
    equal(state.tooltip[3], "Click: Arcane Intellect on you.")
    state.slash("unlock")
    intellect.scripts.OnEnter(intellect)
    contains(state.tooltip[2], "Drag to move")
    state.slash("lock")
    state.clear()
    state.slash("debug")
    contains(state.messages[1], "debug class=MAGE available=true enabled=true locked=true combat=false")
    contains(state.messages[2], "debug arcaneIntellect on=true group=true known=true shown=true missing=you "
        .. "click=Arcane Intellect@player unknownIDs=none")
    contains(state.messages[3], "debug mageArmor on=true group=nil known=false")
    state.combat = true
    state.slash("debug")
    contains(state.last(), "not checked in combat")
end)
test("/dbr debug names spell IDs the client does not know", function()
    local state = fixture({known = {[INTELLECT] = true}})
    SPELLS[10157] = nil
    local ok, message = pcall(function()
        state.clear()
        state.slash("debug")
    end)
    SPELLS[10157] = "Arcane Intellect"
    equal(ok, true, tostring(message))
    contains(state.messages[2], "unknownIDs=10157")
end)
test("the master switch hides every icon", function()
    local state = fixture({known = {[INTELLECT] = true}})
    state.settings.DBR_ENABLED:SetValue(false)
    equal(state.icon("arcaneIntellect").shown, false)
    equal(state.icon("arcaneIntellect").attributes.type1, nil)
end)

local failed = 0
for index, entry in ipairs(tests) do
    local ok, message = xpcall(entry.body, debug.traceback)
    if ok then
        io.write("ok ", index, " - ", entry.name, "\n")
    else
        failed = failed + 1
        io.write("not ok ", index, " - ", entry.name, "\n", tostring(message), "\n")
    end
end
io.write(string.format("\n%d tests: %d passed, %d failed\n", #tests, #tests - failed, failed))
io.write("Mock results do not establish in-client compatibility.\n")
os.exit(failed == 0 and 0 or 1)
