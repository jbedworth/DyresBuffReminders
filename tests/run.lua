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
-- Dyre's Toolkit's files the tests load (a copy in tests/toolkit, checked
-- against ../DyresToolkit when that folder is there). Not the minimap, which
-- needs the embedded libraries.
local TOOLKIT_FILES = {"Core.lua", "Layout.lua", "Widgets.lua", "Settings.lua"}
local PAGE = "Buff Reminders"

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
name("Aspect of the Hawk", 13165, 14318, 14319, 14320, 14321, 14322, 25296)
name("Aspect of the Monkey", 13163)
name("Aspect of the Wild", 20043, 20190)
name("Aspect of the Beast", 13161)
name("Aspect of the Cheetah", 5118)
name("Aspect of the Pack", 13159)
name("Seal of Righteousness", 21084, 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293)
name("Seal of Command", 20375, 20915, 20918, 20919, 20920)
name("Seal of Fury", 20163, 20419, 20421, 20422, 20423, 1311649, 1311656)
name("Seal of Zeal", 990001)
-- Chime spells (from Dyre's Cooldown Chimes' suite).
name("Blink", 1953)
name("Frost Nova", 122, 865, 10230)
name("Counterspell", 2139)
name("Ice Block", 11958)
name("Ice Barrier", 11426)
name("Mana Shield", 1463)
name("Evocation", 12051)
name("Cold Snap", 12472)
name("Fire Ward", 543)
name("Frost Ward", 6143)
name("Cone of Cold", 120)
name("Fire Blast", 2136)
name("Presence of Mind", 12043)
name("Arcane Power", 12042)
name("Combustion", 11129)
name("Fireball", 133)
name("Kick", 1766, 1767)
name("Sprint", 2983)
name("Evasion", 5277)
name("Vanish", 1856)
name("Preparation", 14185)
name("Death Coil", 6789)
-- Proc buffs (Classic IDs).
name("Shadow Trance", 17941)
name("Clearcasting", 12536, 16870, 16246)
name("Nature's Grace", 16886)
name("Flurry", 12966, 12967, 12968, 12969, 12970)
-- Reactive abilities (Classic rank 1).
name("Overpower", 7384)
name("Revenge", 6572)
name("Execute", 5308)
name("Riposte", 14251)
local BLINK, FROST_NOVA, FROST_NOVA_4, COLD_SNAP, FIREBALL = 1953, 122, 10230, 12472, 133
local KICK_2, SPRINT, PREPARATION = 1767, 2983, 14185
local SIBLING_SOUNDS = "../DyresSounds"

local function fileExists(path)
    local handle = io.open(path, "r")
    if handle then
        handle:close()
        return true
    end
    return false
end

local function tocFilesAt(path)
    local files = {}
    for line in io.lines(path) do
        if line:match("%S") and not line:match("^#") then
            files[#files + 1] = line
        end
    end
    return files
end

-- A stand-in for Dyre's Sounds' contract 1, recording what it plays. It knows
-- talent, magical (MTF's old key effectmagical), and voice; voice plays only
-- when state.voice is set, as the library offers it only with a voice.
local function fakeSounds(state, contract)
    local labels = {talent = "Interface: Talent ready", magical = "Dyre's Picks: Magical disappear",
        voice = "Text to Speech", impspell = "Imp: Spell chirp"}
    -- As Dyre's Sounds: only file sounds can be aura sounds.
    local files = {magical = {soundFileName = "Interface\\AddOns\\DyresSounds\\Sounds\\MagicalDisappear.mp3"},
        impspell = {soundFileID = 639156}}
    local aliases = {effectmagical = "magical"}
    local library = {}
    function library.RequireContract(minimum)
        if type(minimum) == "number" and minimum <= contract then
            return library
        end
    end
    function library.Resolve(key)
        key = aliases[key] or key
        return labels[key] and key or nil
    end
    function library.Label(key)
        return labels[library.Resolve(key) or ""]
    end
    function library.List() return {} end
    function library.Groups() return {} end
    function library.Play(key, speech)
        key = library.Resolve(key)
        if not key or (key == "voice" and not state.voice) then
            return false
        end
        state.played[#state.played + 1] = {key = key, speech = speech, at = state.now}
        return true
    end
    function library.Choices(filter)
        state.choicesFilters = state.choicesFilters or {}
        state.choicesFilters[#state.choicesFilters + 1] = filter or "all"
        return function() return {{value = "talent"}, {value = "magical"}} end
    end
    function library.AuraSound(key)
        return files[library.Resolve(key) or ""]
    end
    function library.SetupMenu(initializer, filter)
        initializer.nestedMenu, initializer.menuFilter = true, filter
    end
    if not state.soundsWithoutCheckboxMenu then
        -- Dyre's Sounds 0.1.2-beta: the nested menu on a checkbox-and-dropdown row.
        function library.SetupCheckboxMenu(initializer, filter)
            equal(type(initializer.InitFrame), "function", "a settings initializer")
            equal(type(initializer.data.dropdownSetting), "table")
            initializer.checkboxMenu, initializer.menuFilter = true, filter
        end
    end
    return library
end
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
        categories = {}, known = options.known or {}, carried = {}, drivers = {}, timers = {}, auraReads = 0,
        played = {}, cooldowns = {}, headings = {}}
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
        if addon ~= ADDON then
            -- options.versions: other AddOns' TOC versions, as {MageToolsForever = "0.3.0-beta"}.
            return field == "Version" and (options.versions or {})[addon] or nil
        end
        return state.toc[field] or ""
    end}
    state.loadedAddOns = {}
    for addon, loaded in pairs(options.loaded or {}) do state.loadedAddOns[addon] = loaded end
    env.C_AddOns.IsAddOnLoaded = function(addon) return state.loadedAddOns[addon] == true, false end
    env.C_AddOns.LoadAddOn = function(addon)
        state.loadedAddOns = state.loadedAddOns or {}
        state.loadedAddOns[addon] = true
    end
    env.C_XMLUtil = {GetTemplateInfo = function(template)
        if template == "CustomAuraContainerTemplate" and not options.noAuraContainer then return {} end
    end}
    env.Enum = {StatusBarTimerDirection = {ElapsedTime = 0, RemainingTime = 1},
        SpellBookSpellBank = {Player = 0}, SpellBookItemType = {None = 0, Spell = 1, FutureSpell = 2},
        UnitAuraSoundTrigger = {Added = 0, ApplicationsIncreased = 1, Removed = 2},
        AddOnRestrictionType = {Combat = 0, Encounter = 1, Chat = 5}}
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
    env.UnitOnTaxi = function(unit) return unit == "player" and state.taxi == true end
    if not options.noRoles then
        env.UnitGroupRolesAssigned = function(unit)
            local data = state.units[unit]
            if data and data.secretRole then return state.secret() end
            return data and data.role or "NONE"
        end
    end
    env.IsInGroup = function() return state.group ~= nil end

    env.C_Spell = {
        GetSpellName = function(id) if SPELLS[id] then return SPELLS[id] end end,
        GetSpellTexture = function(id) return 2000 + id end,
        -- state.usable[name] is {usable, noMana}, or "secret" for secret answers.
        IsSpellUsable = function(spell)
            local answer = state.usable and state.usable[spell]
            if answer == "secret" then return state.secret(), state.secret() end
            if answer then return answer[1], answer[2] end
            return false, false
        end,
        GetSpellCooldown = function(id)
            if state.combat then
                return {startTime = state.secret(), duration = state.secret(), isEnabled = true}
            end
            local cooldown = state.cooldowns[id]
            if cooldown then return {startTime = cooldown.start, duration = cooldown.duration} end
            return {startTime = 0, duration = 0}
        end,
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
    -- The spellbook: one skill line holding state.spellbook entries {spellID, name, itemType}.
    state.spellbook = options.spellbook or {}
    env.C_SpellBook.GetNumSpellBookSkillLines = function() return 1 end
    env.C_SpellBook.GetSpellBookSkillLineInfo = function()
        return {itemIndexOffset = 0, numSpellBookItems = #state.spellbook}
    end
    env.C_SpellBook.GetSpellBookItemInfo = function(index, bank)
        equal(bank, 0, "the player's spellbook")
        local item = state.spellbook[index]
        if item then return {spellID = item.spellID, name = item.name, itemType = item.itemType or 1} end
    end
    env.C_Item = {GetItemCount = function(id) return state.carried[id] or 0 end}
    -- Equipment and bags: state.equipped[slot] = itemID (18 ranged, 0 ammo),
    -- state.ammoCount (a number or "secret"), state.bags[bag] = {itemIDs}.
    state.equipped, state.bags = {}, {}
    local ITEMS = {[2504] = {2, 2, 4001}, [2508] = {2, 3, 4002}, [15807] = {2, 18, 4003}, [2947] = {2, 16, 4004},
        [5069] = {2, 19, 4005}, [2512] = {6, 2, 3001, "Rough Arrow"}, [2516] = {6, 3, 3002, "Light Shot"}}
    env.C_Item.GetItemInfoInstant = function(id)
        local item = ITEMS[id]
        if item then return id, "", "", "", item[3], item[1], item[2] end
    end
    env.C_Item.GetItemNameByID = function(id) return ITEMS[id] and ITEMS[id][4] end
    env.GetInventoryItemID = function(unit, slot)
        equal(unit, "player")
        return state.equipped[slot]
    end
    if not options.noAmmoAPI then
        env.GetInventoryItemCount = function(unit, slot)
            equal(slot, 0, "the ammo slot")
            if state.ammoCount == "secret" then return state.secret() end
            return state.ammoCount or 0
        end
    end
    env.C_Container = {
        GetContainerNumSlots = function(bag) return state.bags[bag] and #state.bags[bag] or 0 end,
        GetContainerItemID = function(bag, slot) return state.bags[bag] and state.bags[bag][slot] end,
    }
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
            if type(buff) == "table" then return {name = spell, spellId = buff.spellId, expirationTime = 0} end
            if buff then return {name = spell, duration = 0, expirationTime = 0} end
        end,
    }
    -- The game's aura sounds: registrations by handle; refused during an encounter.
    state.auraSounds, state.auraSoundCount = {}, 0
    if not options.noAuraSounds then
        env.C_UnitAuras.AddAuraSound = function(trigger, info)
            if state.encounter then error("AddAuraSound during an encounter") end
            state.auraSoundCount = state.auraSoundCount + 1
            state.auraSounds[state.auraSoundCount] = {trigger = trigger, info = info}
            return state.auraSoundCount
        end
        env.C_UnitAuras.RemoveAuraSound = function(handle)
            if state.encounter then error("RemoveAuraSound during an encounter") end
            state.auraSounds[handle] = nil
        end
    end
    env.C_RestrictedActions = {IsAddOnRestrictionActive = function(kind)
        return kind == 1 and state.encounter == true
    end}
    -- The spell IDs with a registered aura sound, sorted.
    function state.soundIDs()
        local ids = {}
        for _, entry in pairs(state.auraSounds) do ids[#ids + 1] = entry.info.spellID end
        table.sort(ids)
        return table.concat(ids, ",")
    end
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
            elseif driver == "show" then
                frame.shown = true
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
    -- Secure wraps: recorded; state.secureClick runs a wrapped frame's click as
    -- the game would (the cast, then the post-body, which may Hide in combat).
    state.wraps = {}
    if not options.noSecureWrap then
        env.SecureHandlerWrapScript = function(frame, script, header, preBody, postBody)
            state.wraps[frame] = {script = script, header = header, pre = preBody, post = postBody}
        end
    end
    function state.secureClick(frame)
        state.clicked = state.clicked or {}
        state.clicked[#state.clicked + 1] = frame.attributes.macrotext1 or frame.attributes.spell1
        local wrap = state.wraps[frame]
        if wrap and wrap.post == "self:Hide()" then frame.shown = false end
    end
    env.GameTooltip = {
        SetOwner = function() state.tooltip = {} end,
        SetText = function(_, text) state.tooltip[#state.tooltip + 1] = text end,
        AddLine = function(_, text) state.tooltip[#state.tooltip + 1] = text end,
        Show = function() end,
        Hide = function() end,
    }

    -- Settings: proxy settings with getters and setters, as the client builds them.
    env.CreateSettingsListSectionHeaderInitializer = function(text) return {heading = text} end
    -- As the client builds it (Blizzard_SettingControls.lua): a settings
    -- initializer whose data holds both settings; added through the layout.
    if not options.noCheckboxDropdown then
        env.CreateSettingsCheckboxDropdownInitializer = function(cbSetting, cbLabel, cbTooltip, dropdownSetting,
                dropdownOptions, dropDownLabel, dropDownTooltip)
            local object = {kind = "checkboxdropdown", data = {name = cbLabel, tooltip = cbTooltip,
                cbSetting = cbSetting, cbLabel = cbLabel, cbTooltip = cbTooltip, dropdownSetting = dropdownSetting,
                dropdownOptions = dropdownOptions, dropDownLabel = dropDownLabel, dropDownTooltip = dropDownTooltip}}
            function object:InitFrame() end
            function object:SetParentInitializer(parent, predicate)
                self.parentInitializer, self.predicate = parent, predicate
            end
            return object
        end
    end
    state.soundsWithoutCheckboxMenu = options.soundsWithoutCheckboxMenu
    env.C_Secrets = {GetSpellCooldownSecrecy = function() return state.combat and state.secret() or 2 end}
    local sounds = options.sounds or "fake"
    if sounds == "fake" then
        env.DyresSounds = fakeSounds(state, 1)
    elseif sounds == "old" then
        env.DyresSounds = fakeSounds(state, 0)
    elseif sounds == "real" then
        env.SOUNDKIT = {UI_ORDERHALL_TALENT_READY_TOAST = 73280}
        env.PlaySound = function(kit) state.played[#state.played + 1] = {kit = kit, at = state.now} end
        env.PlaySoundFile = function(file) state.played[#state.played + 1] = {file = file, at = state.now} end
        local libraryNamespace = {}
        for _, path in ipairs(tocFilesAt(SIBLING_SOUNDS .. "/DyresSounds.toc")) do
            local chunk = assert(loadfile(SIBLING_SOUNDS .. "/" .. path))
            setfenv(chunk, env)
            chunk("DyresSounds", libraryNamespace)
        end
    end
    if not options.noSettings then
        env.CreateSettingsButtonInitializer = function(label, buttonText, click, tooltip)
            return {kind = "button", label = label, buttonText = buttonText, click = click, tooltip = tooltip}
        end
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
                local layout = {}
                function layout:AddInitializer(initializer)
                    if initializer.heading then state.headings[#state.headings + 1] = initializer end
                    category.initializers[#category.initializers + 1] = initializer
                end
                return category, layout
            end,
            RegisterVerticalLayoutSubcategory = function(parent, title)
                local category, layout = env.Settings.RegisterVerticalLayoutCategory(title)
                category.parent = parent
                return category, layout
            end,
            NotifyUpdate = function() end,
            CreateDropdown = function(category, setting, choices, tooltip)
                local object = initializer(category, setting, tooltip)
                object.choices, object.kind = choices, "dropdown"
                return object
            end,
            CreateControlTextContainer = function() return {} end,
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
        function object:EnableMouse(value)
            if state.combat and self.protected then error("EnableMouse in combat") end
            self.mouse = value == true
        end
        function object:SetAlpha(value) self.alpha = value end
        function object:GetAlpha() return self.alpha or 1 end
        function object:EnableMouseWheel(value) self.wheel = value == true end
        -- As in client, secure frames refuse changes in combat.
        function object:SetScale(value)
            if state.combat and self.protected then error("SetScale in combat") end
            self.scale = value
        end
        function object:GetScale() return self.scale or 1 end
        function object:GetNumPoints() return #self.points end
        function object:GetEffectiveScale()
            local parentScale = 1
            if self.parent and self.parent.GetEffectiveScale then parentScale = self.parent:GetEffectiveScale() end
            return (self.scale or 1) * parentScale
        end
        function object:GetWidth() return self.width or 0 end
        function object:GetHeight() return self.height or 0 end
        function object:SetWidth(width) self.width = width end
        function object:SetHeight(height) self.height = height end
        function object:SetSize(width, height)
            if state.combat and self.protected then error("SetSize in combat") end
            self.width, self.height = width, height
        end
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
        function object:SetTextColor(...) self.textColor = {...} end
        function object:SetFont(file, size, flags) self.font = {file, size, flags} end
        function object:GetFont() return "Fonts\ARIALN.TTF", 14, "" end
        function object:SetJustifyH(value) self.justifyH = value end
        function object:SetShadowColor(...) self.shadowColor = {...} end
        function object:SetShadowOffset(...) self.shadowOffset = {...} end
        function object:SetWordWrap(value) self.wordWrap = value end
        function object:SetDesaturated(value) self.desaturated = value == true end
        function object:SetMouseClickEnabled(value) self.mouseClicks = value == true end
        function object:SetMouseMotionEnabled(value) self.mouseMotion = value == true end
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
        if template and template:find("SecureActionButtonTemplate", 1, true) then
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
    -- Dyre's Toolkit, its real files: DBR requires it. options.noToolkit leaves
    -- it out; options.oldToolkit offers contract 1 only.
    if not options.noToolkit then
        state.toolkitNS = {InitializeMinimap = function() end}
        for _, path in ipairs(TOOLKIT_FILES) do
            local chunk = assert(loadfile("tests/toolkit/" .. path))
            setfenv(chunk, env)
            chunk("DyresToolkit", state.toolkitNS)
        end
        state.toolkit = env.DyresToolkit
        if options.oldToolkit then
            env.DyresToolkit.RequireContract = function(n)
                if n == 1 then return env.DyresToolkit end
            end
        end
        env.DyresToolkitDB = options.toolkitDB
    end
    state.dbr = {}
    for _, path in ipairs(options.files or RUNTIME_FILES) do
        local chunk, message = loadfile(path)
        if not chunk then error(message) end
        setfenv(chunk, env)
        chunk(ADDON, state.dbr)
    end
    env.DyresBuffRemindersDB = options.db
    state.env = env
    state.emit("ADDON_LOADED", "DyresToolkit")
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
    function state.bar(key)
        return env[key == "group" and "DyresBuffRemindersGroupBuffs" or "DyresBuffRemindersMyBuffs"]
    end
    function state.page() return state.categories[PAGE] end
    function state.cast(id, cooldown)
        if cooldown then state.cooldowns[id] = {start = state.now, duration = cooldown} end
        state.emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", id)
    end
    -- Time passes; due timers run in time order, each at its own time.
    function state.advance(seconds)
        local target = state.now + seconds
        while true do
            local nextIndex
            for index, timer in ipairs(state.timers) do
                if timer.at <= target and (not nextIndex or timer.at < state.timers[nextIndex].at) then
                    nextIndex = index
                end
            end
            if not nextIndex then break end
            local timer = table.remove(state.timers, nextIndex)
            state.now = math.max(state.now, timer.at)
            timer.callback()
        end
        state.now = target
    end
    function state.count(fragment)
        local count = 0
        for _, message in ipairs(state.messages) do
            if message:find(fragment, 1, true) then count = count + 1 end
        end
        return count
    end
    function state.find(fragment)
        for _, message in ipairs(state.messages) do
            if message:find(fragment, 1, true) then return message end
        end
    end
    function state.chimes() return state.dbr.db.chimes end
    -- A settings row by its setting variable (a checkbox-and-dropdown row by
    -- either of its settings).
    function state.row(variable)
        for _, category in pairs(state.categories) do
            for index, row in ipairs(category.initializers) do
                if row.setting and row.setting.variable == variable then return row, index end
                local data = row.data
                if data and ((data.cbSetting and data.cbSetting.variable == variable)
                    or (data.dropdownSetting and data.dropdownSetting.variable == variable)) then
                    return row, index
                end
            end
        end
    end
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
    equal(table.concat(RUNTIME_FILES, ","),
        "Commands.lua,Core.lua,Buffs.lua,Reminders.lua,Seals.lua,Consumables.lua,ChimeSpells.lua,Chimes.lua,"
            .. "ProcSpells.lua,Procs.lua,Probe.lua,Options.lua")
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
    local state = fixture({files = {"Commands.lua", "Core.lua", "Buffs.lua", "Seals.lua",
        "ChimeSpells.lua", "Chimes.lua", "ProcSpells.lua", "Procs.lua", "Options.lua"}})
    equal(state.dbr.available, false)
    contains(state.last(), "missing ClassReminders")
    state.clear()
    state.slash("unlock")
    contains(state.last(), "unavailable")
    state.slash("debug")
    contains(state.messages[2], "available=false", "debug still runs")
    local noBuffs = fixture({files = {"Commands.lua", "Core.lua", "Reminders.lua", "Seals.lua", "Options.lua"}})
    contains(noBuffs.last(), "missing Buffs.lua, Seals.lua, ChimeSpells.lua, or ProcSpells.lua")
    local noChimes = fixture({files = {"Commands.lua", "Core.lua", "Buffs.lua", "Reminders.lua",
        "Seals.lua", "Consumables.lua", "ChimeSpells.lua", "ProcSpells.lua", "Procs.lua", "Options.lua"}})
    contains(noChimes.last(), "missing ClassChimes")
    local noProcs = fixture({files = {"Commands.lua", "Core.lua", "Buffs.lua", "Reminders.lua",
        "Seals.lua", "Consumables.lua", "ChimeSpells.lua", "Chimes.lua", "ProcSpells.lua", "Options.lua"}})
    contains(noProcs.last(), "missing ClassProcs")
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
        equal(state.last(), "DBR: Use /dbr (settings: Reminders, Consumables, Size and Opacity, Chimes, Procs), "
            .. "/dbr unlock, /dbr lock, /dbr reset, /dbr debug, or /dbr probe on|off.")
    end
    state.slash("")
    equal(state.opened, "id:" .. PAGE)
    state.opened = nil
    state.slash("  OPTIONS ")
    equal(state.opened, "id:" .. PAGE)
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
        mageArmor = "on", gone = true, dampenMagic = true}, groups = "bad", icons = {arcaneIntellect = {scale = 137,
        position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 10, y = 20}}, mageArmor = {scale = "x",
        position = {point = 1}}}, last = {mageArmor = "Frost Armor", arcaneIntellect = "Arcane Intellect",
        dampenMagic = "Amplify Magic"}}})
    local db = state.dbr.db
    equal(db.enabled, true)
    equal(db.locked, true, "frames start locked, as the toolkit's")
    equal(db.grid, nil, "the toolkit draws the one grid")
    equal(db.spells.arcaneIntellect, false)
    equal(db.spells.mageArmor, true, "a bad value takes the default")
    equal(db.spells.gone, nil, "keys no class has are dropped")
    equal(db.spells.dampenMagic, nil, "Dampen or Amplify Magic is no longer a reminder: dropped")
    equal(db.last.dampenMagic, nil)
    equal(db.spells.markOfTheWild, true, "every class's buffs keep a setting")
    equal(db.groups.arcaneIntellect, true)
    equal(db.groups.mageArmor, nil, "no group setting for a self buff")
    equal(db.icons, nil, "the loose icons' places are dropped: no bar can take them")
    equal(db.bars.groupbuffs.scale, 100, "the toolkit's default")
    equal(db.bars.mybuffs.position, nil)
    equal(db.last.mageArmor, "Frost Armor")
    equal(db.last.arcaneIntellect, nil, "only buffs with several spells remember")
    equal(db.lead, 5, "5 seconds by default")
    equal(state.dbr.SanitizeLead(99), 30)
    equal(state.dbr.SanitizeLead(-2), 0)
    equal(state.dbr.SanitizeLead(2.5), 5)
    local bad = fixture({db = {bars = {groupbuffs = {scale = 137, opacity = "x",
        position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 10, y = 20}}, mybuffs = "bad"}}})
    equal(bad.dbr.db.bars.groupbuffs.scale, 140, "stepped by 10")
    equal(bad.dbr.db.bars.groupbuffs.opacity, 100)
    equal(bad.dbr.db.bars.groupbuffs.position.x, 10)
    equal(bad.dbr.db.bars.mybuffs.scale, 100)
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
    equal(state.bar("group"), nil)
    equal(state.bar("my"), nil)
    equal(state.icon("arcaneIntellect"), nil)
    equal(#state.toolkit.Widgets(ADDON), 1, "only the Consumables bar (any class may carry a gun)")
    equal(state.env.DyresBuffRemindersConsumables.shown, false, "hidden without an ammo weapon")
    equal(state.page() ~= nil, true, "the settings page still opens")
    state.clear()
    state.slash("unlock")
    contains(state.last(), "Frames unlocked", "the toolkit's one lock")
    state.slash("reset")
    state.slash("debug")
    equal(state.find("no buff reminders for this class") ~= nil, true)
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
    equal(state.icon("dampenMagic"), nil, "no Dampen or Amplify Magic reminder (author: situational)")
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
    local intellect, holder = state.icon("arcaneIntellect"), state.bar("group")
    equal(intellect.shown, true)
    equal(holder.shown, true)
    equal(state.drivers[holder], "[combat] hide; show", "the game hides the bar for combat")
    equal(state.drivers[state.bar("my")], "hide", "nothing it can show: hidden")
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
    equal(state.bar("group"), nil, "no secure frames set up in combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(state.drivers[state.bar("group")], "[combat] hide; show")
    equal(state.bar("group").dyre ~= nil, true, "a widget")
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
    equal(intellect.texture.texture, 2000 + BRILLIANCE, "the picture is what the click casts")
    intellect.scripts.OnEnter(intellect)
    equal(state.tooltip[3], "Click: Arcane Brilliance.")
    state.buff("player", "Arcane Intellect")
    state.update("UNIT_AURA", "player")
    equal(intellect.attributes.spell1, "Arcane Intellect", "one missing: the single buff")
    equal(intellect.texture.texture, 2000 + INTELLECT)
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
local function tooltip(state, icon)
    icon.scripts.OnEnter(icon)
    return table.concat(state.tooltip, "|")
end
test("Druid: Thorns watches you solo and in a group with no tank; a click casts it on you", function()
    local state = fixture({class = "DRUID", known = {[THORNS] = true}})
    local thorns = state.icon("thorns")
    equal(thorns.shown, true)
    equal(thorns.attributes.unit1, "player")
    contains(tooltip(state, thorns), "Thorns: on you")
    state.party({{name = "Stabby", class = "ROGUE"}, {name = "Healy", class = "PRIEST", role = "HEALER"}})
    equal(thorns.attributes.unit1, "player", "no tank: you")
    equal(table.concat(thorns.missing, ","), "you", "group members without Thorns do not count")
    state.buff("player", "Thorns")
    state.update("UNIT_AURA", "player")
    equal(thorns.shown, false)
    local bare = fixture({class = "DRUID", known = {[THORNS] = true}, noRoles = true})
    bare.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    equal(bare.icon("thorns").attributes.unit1, "player", "without the role API: you")
end)
test("Druid: in a group with a tank, Thorns watches the tank and a click casts it on them", function()
    local state = fixture({class = "DRUID", known = {[THORNS] = true}})
    local thorns = state.icon("thorns")
    state.buff("player", "Thorns")
    state.party({{name = "Stabby", class = "ROGUE"}, {name = "Tanky", class = "WARRIOR", role = "TANK"},
        {name = "Backup", class = "PALADIN", role = "TANK"}})
    equal(thorns.shown, true, "the tank lacks it, though you have it")
    equal(thorns.attributes.unit1, "party2", "the first tank in group order")
    equal(table.concat(thorns.missing, ","), "Tanky")
    contains(tooltip(state, thorns), "Thorns: on Tanky")
    state.units.party2.dead = true
    state.update("UNIT_AURA", "party2")
    equal(thorns.attributes.unit1, "party3", "a dead tank is skipped")
    state.units.party3.far = true
    state.update("UNIT_AURA", "party3")
    equal(thorns.attributes.unit1, nil, "no tank in reach: you, who have it")
    equal(thorns.shown, false)
    contains(tooltip(state, thorns), "Thorns: on you")
    state.units.party2.dead, state.units.party3.far = false, false
    state.buff("party2", "Thorns")
    state.update("UNIT_AURA", "party2")
    equal(thorns.shown, false, "the tank has it")
    local secret = fixture({class = "DRUID", known = {[THORNS] = true}})
    secret.party({{name = "Tanky", class = "WARRIOR", role = "TANK", secretRole = true}})
    equal(secret.icon("thorns").attributes.unit1, "player", "a secret role is not read as a tank")
end)
test("Druid: with the tank dead, offline, out of sight, or out of range, Thorns watches you", function()
    for _, case in ipairs({"dead", "offline", "far", "range"}) do
        local state = fixture({class = "DRUID", known = {[THORNS] = true}})
        local thorns = state.icon("thorns")
        state.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
        equal(thorns.attributes.unit1, "party1", case .. ": the tank first")
        if case == "range" then
            state.outOfRange = {party1 = true}
        else
            state.units.party1[case] = true
        end
        state.update("UNIT_AURA", "party1")
        equal(thorns.attributes.unit1, "player", case .. ": a click casts it on you")
        equal(table.concat(thorns.missing, ","), "you", case)
        contains(tooltip(state, thorns), "Thorns: on you")
        state.buff("player", "Thorns")
        state.update("UNIT_AURA", "player")
        equal(thorns.shown, false, case .. ": you have it, so nothing shows")
    end
    local secret = fixture({class = "DRUID", known = {[THORNS] = true}})
    secret.secretRange = true
    secret.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    equal(secret.icon("thorns").attributes.unit1, "party1", "an unreadable range counts as in range")
    local noRange = fixture({class = "DRUID", known = {[THORNS] = true}, noRange = true})
    noRange.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    equal(noRange.icon("thorns").attributes.unit1, "party1", "no range API: in range")
end)
test("Druid: walking out of or into the tank's range re-checks Thorns, from the game's range event", function()
    local state = fixture({class = "DRUID", known = {[THORNS] = true}})
    local thorns = state.icon("thorns")
    state.buff("player", "Thorns")
    state.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    equal(thorns.attributes.unit1, "party1")
    state.outOfRange = {party1 = true}
    state.update("UNIT_IN_RANGE_UPDATE", "party1", false)
    equal(thorns.attributes.unit1, nil, "out of range: watches you, who have it")
    equal(thorns.shown, false)
    state.outOfRange = {}
    state.update("UNIT_IN_RANGE_UPDATE", "party1", true)
    equal(thorns.attributes.unit1, "party1", "back in range: the tank again")
    state.units.party1.offline = true
    state.update("UNIT_CONNECTION", "party1", false)
    equal(thorns.attributes.unit1, nil, "offline: you")
    local reads = state.auraReads
    state.update("UNIT_IN_RANGE_UPDATE", "nameplate1", true)
    equal(state.auraReads, reads, "units outside your group are ignored")
    local mage = fixture({known = {[INTELLECT] = true}})
    local frame
    for _, candidate in ipairs(mage.frames) do
        if candidate.events.UNIT_AURA then frame = candidate end
    end
    equal(frame.events.UNIT_IN_RANGE_UPDATE, nil, "only a class with a tank buff listens")
end)
test("Druid: as the tank yourself, Thorns watches you", function()
    local state = fixture({class = "DRUID", known = {[THORNS] = true}})
    state.units.player.role = "TANK"
    state.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    local thorns = state.icon("thorns")
    equal(thorns.attributes.unit1, "player")
    contains(tooltip(state, thorns), "Thorns: on you")
end)
test("Druid: role and roster changes in combat apply after combat", function()
    local state = fixture({class = "DRUID", known = {[THORNS] = true}})
    local thorns = state.icon("thorns")
    state.party({{name = "Tanky", class = "WARRIOR"}})
    equal(thorns.attributes.unit1, "player")
    state.combat = true
    state.applyDrivers()
    state.units.party1.role = "TANK"
    state.update("PLAYER_ROLES_ASSIGNED")
    state.update("ROLE_CHANGED_INFORM")
    state.update("GROUP_ROSTER_UPDATE")
    equal(thorns.attributes.unit1, "player", "no secure change in combat")
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
    equal(thorns.attributes.unit1, "party1")
    state.units.party1.role = "DAMAGER"
    state.update("ROLE_CHANGED_INFORM")
    equal(thorns.attributes.unit1, "player", "out of combat, a role change applies at once")
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
    equal(mark.attributes.macrotext1, "/cancelform\n/use [@player] Mark of the Wild", "/use: every character counts")
    equal(mark.attributes.spell1, nil)
    mark.scripts.OnEnter(mark)
    equal(state.tooltip[3], "Click: Mark of the Wild on you (leaves your form first).")
    state.buff("player", "Mark of the Wild")
    state.carried[WILD_BERRIES] = 1
    state.party({{name = "Tanky", class = "WARRIOR"}, {name = "Stabby", class = "ROGUE"}})
    equal(mark.attributes.macrotext1, "/cancelform\n/use [@party1] Gift of the Wild(Rank 1)",
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

local HAWK, HAWK_7, MONKEY, WILD, BEAST, CHEETAH, PACK = 13165, 25296, 13163, 20043, 13161, 5118, 13159
test("Hunter: no aspect shows the Aspect reminder in My buffs; any aspect counts as up", function()
    local state = fixture({class = "HUNTER", known = {[HAWK] = true, [MONKEY] = true, [CHEETAH] = true,
        [PACK] = true, [WILD] = true, [BEAST] = true}})
    local aspect = state.icon("aspect")
    equal(aspect.parent, state.bar("my"))
    equal(state.bar("group"), nil)
    equal(aspect.shown, true)
    equal(aspect.attributes.type1, "macro")
    equal(aspect.attributes.macrotext1, "/use !Aspect of the Hawk", "nothing cast yet: Hawk, with \"!\" so it never toggles")
    for _, name in ipairs({"Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Wild", "Aspect of the Beast",
            "Aspect of the Cheetah", "Aspect of the Pack"}) do
        state.units.player.buffs = {[name] = true}
        state.update("UNIT_AURA", "player")
        equal(aspect.shown, false, name .. " counts as up")
    end
    state.units.player.buffs = {}
    state.update("UNIT_AURA", "player")
    equal(aspect.shown, true)
    equal(state.find("no buff reminders") == nil, true, "Hunters have a reminder now")
end)
test("Hunter: a click recasts the last combat aspect, never Cheetah or Pack", function()
    local state = fixture({class = "HUNTER", known = {[HAWK] = true, [MONKEY] = true, [CHEETAH] = true,
        [PACK] = true, [WILD] = true}})
    local aspect = state.icon("aspect")
    state.cast(MONKEY)
    state.update("UNIT_AURA", "player")
    equal(state.dbr.db.last.aspect, "Aspect of the Monkey")
    equal(aspect.attributes.macrotext1, "/use !Aspect of the Monkey")
    state.cast(CHEETAH)
    state.cast(PACK)
    state.update("UNIT_AURA", "player")
    equal(state.dbr.db.last.aspect, "Aspect of the Monkey", "Cheetah and Pack are not remembered")
    equal(aspect.attributes.macrotext1, "/use !Aspect of the Monkey")
    state.cast(WILD)
    state.update("UNIT_AURA", "player")
    equal(aspect.attributes.macrotext1, "/use !Aspect of the Wild")
    state.known[HAWK_7] = true
    state.cast(HAWK_7)
    state.update("UNIT_AURA", "player")
    equal(state.dbr.db.last.aspect, "Aspect of the Hawk", "every rank counts")
    local saved = fixture({class = "HUNTER", known = {[HAWK] = true, [CHEETAH] = true},
        db = {last = {aspect = "Aspect of the Cheetah"}}})
    equal(saved.icon("aspect").attributes.macrotext1, "/use !Aspect of the Hawk", "a saved Cheetah is never cast")
end)
test("a reminder's picture is always the spell its click casts, as its tooltip says", function()
    local hunter = fixture({class = "HUNTER", known = {[HAWK] = true, [MONKEY] = true, [CHEETAH] = true,
        [PACK] = true}})
    local aspect = hunter.icon("aspect")
    equal(aspect.texture.texture, 2000 + HAWK, "nothing cast: Hawk, not the last aspect in the list (Pack)")
    hunter.cast(HAWK)
    hunter.buff("player", "Aspect of the Cheetah")
    hunter.cast(CHEETAH)
    hunter.update("UNIT_AURA", "player")
    hunter.units.player.buffs = {}
    hunter.update("UNIT_AURA", "player")
    equal(aspect.attributes.macrotext1, "/use !Aspect of the Hawk")
    equal(aspect.texture.texture, 2000 + HAWK, "after Cheetah was up and cancelled: Hawk's picture")
    contains(tooltip(hunter, aspect), "Click: Aspect of the Hawk on you.")
    hunter.cast(MONKEY)
    hunter.wait(1)
    equal(aspect.texture.texture, 2000 + MONKEY, "a remembered cast changes the picture")
    local mage = fixture({known = {[FROST_ARMOR] = true, [ICE_ARMOR] = true, [6117] = true}})
    local armor = mage.icon("mageArmor")
    equal(armor.texture.texture, 2000 + 6117, "nothing cast: your best, Mage Armor")
    mage.cast(ICE_ARMOR)
    mage.wait(1)
    equal(armor.attributes.spell1, "Ice Armor")
    equal(armor.texture.texture, 2000 + ICE_ARMOR, "last Ice Armor: Ice Armor's picture")
    mage.slash("unlock")
    equal(armor.texture.texture, 2000 + ICE_ARMOR, "the sample too")
    contains(tooltip(mage, armor), "Drag to move")
    mage.slash("lock")
    contains(tooltip(mage, armor), "Click: Ice Armor on you.")
end)
test("Hunter: without a combat aspect cast, Hawk, then Monkey; off or unknown takes no slot", function()
    local monkey = fixture({class = "HUNTER", known = {[MONKEY] = true, [CHEETAH] = true}})
    equal(monkey.icon("aspect").attributes.macrotext1, "/use !Aspect of the Monkey", "no Hawk yet: Monkey")
    local cheetah = fixture({class = "HUNTER", known = {[CHEETAH] = true}})
    equal(cheetah.icon("aspect").attributes.macrotext1, nil, "only Cheetah known: nothing to cast")
    local none = fixture({class = "HUNTER"})
    equal(none.drivers[none.bar("my")], "hide", "no aspect known: no slot")
    local off = fixture({class = "HUNTER", known = {[HAWK] = true}})
    off.settings.DBR_BUFF_ASPECT:SetValue(false)
    equal(off.drivers[off.bar("my")], "hide", "switched off: no slot")
    equal(off.icon("aspect").shown, false)
    off.clear()
    off.slash("debug")
    contains(off.find("debug aspect"), "unknownIDs=none last=nil")
end)
-- The combat aspect button.
local function hunterFixture(options)
    options = options or {}
    options.class = "HUNTER"
    options.known = options.known or {[HAWK] = true, [MONKEY] = true, [CHEETAH] = true, [PACK] = true}
    local state = fixture(options)
    return state, state.env.DyresBuffRemindersCombatAspect
end
local function enterCombat(state)
    state.combat = true
    state.applyDrivers()
    state.emit("PLAYER_REGEN_DISABLED")
end
local function leaveCombat(state)
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
end
test("combat aspect: armed out of combat while Cheetah or Pack is up; the game shows it in combat", function()
    local state, button = hunterFixture()
    equal(state.drivers[button], "hide", "no travel aspect: never shows")
    state.cast(MONKEY)
    state.buff("player", "Aspect of the Cheetah")
    state.update("UNIT_AURA", "player")
    equal(state.drivers[button], "[combat] show; hide")
    equal(button.attributes.type1, "macro")
    equal(button.attributes.macrotext1, "/use !Aspect of the Monkey", "the last combat aspect, with \"!\"")
    equal(button.texture.texture, 2000 + MONKEY)
    equal(button.shown, false, "out of combat: hidden")
    enterCombat(state)
    equal(button.shown, true, "combat starts: shown by the game")
    leaveCombat(state)
    state.units.player.buffs = {}
    state.update("UNIT_AURA", "player")
    equal(state.drivers[button], "hide", "no travel aspect: hidden again")
    equal(button.attributes.macrotext1, nil)
    local pack, packButton = hunterFixture()
    pack.buff("player", "Aspect of the Pack")
    pack.update("UNIT_AURA", "player")
    equal(packButton.attributes.macrotext1, "/use !Aspect of the Hawk", "Pack too; nothing cast: Hawk")
    local monkey, monkeyButton = hunterFixture({known = {[MONKEY] = true, [CHEETAH] = true}})
    monkey.buff("player", "Aspect of the Cheetah")
    monkey.update("UNIT_AURA", "player")
    equal(monkeyButton.attributes.macrotext1, "/use !Aspect of the Monkey", "no Hawk: Monkey")
end)
test("combat aspect: a click casts with \"!\" and hides it; your own cast dims it, never to invisible", function()
    local state, button = hunterFixture()
    state.buff("player", "Aspect of the Cheetah")
    state.update("UNIT_AURA", "player")
    enterCombat(state)
    state.secureClick(button)
    equal(state.clicked[1], "/use !Aspect of the Hawk", "\"!\": a stray click never takes an aspect down")
    equal(button.shown, false, "the secure wrap hides it after the click")
    equal(state.wraps[button].script, "OnClick")
    leaveCombat(state)
    enterCombat(state)
    equal(button.shown, true, "the next fight with Cheetah up: shown again")
    state.cast(CHEETAH)
    equal(button.texture.alpha, 1, "a travel aspect cast does not dim it")
    state.cast(HAWK)
    equal(button.texture.alpha, 0.4, "your own Hawk cast dims it")
    equal(button.glow.animation.playing, false, "and stops its pulse")
    equal(button.shown, true, "still visible where it takes clicks")
    equal(button.alpha ~= 0, true, "never faded to invisible")
    equal(button.attributes.macrotext1, "/use !Aspect of the Hawk", "no secure change in combat")
    leaveCombat(state)
    equal(button.texture.alpha, 1, "reset after combat")
end)
test("combat aspect: a sound at combat start, with its own switch and choice", function()
    local state, button = hunterFixture()
    enterCombat(state)
    equal(#state.played, 0, "not armed: no sound")
    leaveCombat(state)
    state.buff("player", "Aspect of the Cheetah")
    state.update("UNIT_AURA", "player")
    enterCombat(state)
    equal(state.played[1].key, "talent", "the default sound")
    equal(state.played[1].speech, "Aspect of the Cheetah is up")
    leaveCombat(state)
    state.settings.DBR_COMBAT_ASPECT_SOUND:SetValue("magical")
    equal(state.dbr.db.combatAspect.sound, "magical")
    equal(state.played[#state.played].key, "magical", "choosing a sound plays it")
    local before = #state.played
    enterCombat(state)
    equal(state.played[#state.played].key, "magical")
    leaveCombat(state)
    state.settings.DBR_COMBAT_ASPECT_SOUND_ON:SetValue(false)
    before = #state.played
    enterCombat(state)
    equal(#state.played, before, "sound switched off")
    equal(button.shown, true, "the button still shows")
end)
test("combat aspect: settings, unlock, its widget, and who gets it", function()
    local state, button = hunterFixture()
    local row = state.row("DBR_COMBAT_ASPECT")
    equal(row.setting.name, "Combat aspect reminder")
    equal(row.parentInitializer, state.row("DBR_BUFF_ASPECT"), "under the Aspect switch")
    local sound = state.row("DBR_COMBAT_ASPECT_SOUND_ON")
    equal(sound.kind, "checkboxdropdown", "the switch and the sound on one row")
    equal(sound.parentInitializer, row)
    equal(state.row("DYRE_DYRESBUFFREMINDERS_COMBATASPECT_SCALE"), nil, "no size rows of its own")
    state.buff("player", "Aspect of the Cheetah")
    state.update("UNIT_AURA", "player")
    state.settings.DBR_COMBAT_ASPECT:SetValue(false)
    equal(state.drivers[button], "hide", "switched off: never shows")
    state.settings.DBR_COMBAT_ASPECT:SetValue(true)
    state.slash("unlock")
    equal(state.drivers[button], "hide", "unlocked: no sample of its own; the Aspect slot is the one to drag")
    equal(button.attributes.macrotext1, nil, "dragging never casts")
    state.slash("lock")
    equal(state.drivers[button], "[combat] show; hide")
    state.clear()
    state.slash("debug")
    contains(state.find("debug combatAspect"), "armed=true travel=Aspect of the Cheetah macro=/use !Aspect of the Hawk")
    equal(fixture({known = {[INTELLECT] = true}}).env.DyresBuffRemindersCombatAspect, nil, "a Mage: none")
    local bare, bareButton = hunterFixture({noSecureWrap = true})
    equal(bareButton, nil, "without the secure wrap: no button")
    equal(bare.row("DBR_COMBAT_ASPECT"), nil)
    local db = fixture({class = "HUNTER", db = {combatAspect = {enabled = "x", soundOn = 0, sound = 5,
        position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 1, y = 2}, scale = 150, opacity = 50}}}).dbr.db
    equal(db.combatAspect.enabled, true)
    equal(db.combatAspect.soundOn, true)
    equal(db.combatAspect.sound, "talent")
    equal(db.combatAspect.position, nil, "its own place is dropped: it is My buffs'")
    equal(db.combatAspect.scale, nil)
    equal(db.combatAspect.opacity, nil)
end)
test("combat aspect: one widget to the player: it sits on My buffs' Aspect slot and follows the bar", function()
    local state, button = hunterFixture()
    local my = state.bar("my")
    equal(button.parent, state.env.UIParent, "not the bar's child: the bar hides in combat")
    for _, widget in ipairs(state.toolkit.Widgets(ADDON)) do
        equal(widget ~= button, true, "not a widget of its own")
    end
    local function slotOf(icon)
        local point = icon.points[#icon.points]
        return point[1], point[2], point[4]
    end
    local anchor, relative, x = slotOf(button)
    equal(anchor, "LEFT")
    equal(relative, my, "anchored to My buffs")
    equal(x, 0, "the Aspect slot, the bar's first")
    state.slash("unlock")
    local aspect = state.icon("aspect")
    equal(select(3, slotOf(aspect)), x, "on the Aspect icon's own slot")
    state.icon("aspect").scripts.OnDragStart(state.icon("aspect"))
    my:ClearAllPoints()
    my:SetPoint("CENTER", nil, "BOTTOMLEFT", 300, 200)
    state.icon("aspect").scripts.OnDragStop(state.icon("aspect"))
    state.slash("lock")
    local bx, by = state.absCenter(button)
    local ax, ay = state.absCenter(aspect)
    equal(math.floor(bx + 0.5), math.floor(ax + 0.5), "dragging My buffs moves it too")
    equal(math.floor(by + 0.5), math.floor(ay + 0.5))
    state.settings.DYRE_DYRESBUFFREMINDERS_MYBUFFS_SCALE:SetValue(150)
    equal(button.scale, my.scale, "the bar's size")
    equal(button.scale, 1.5)
    state.settings.DYRE_DYRESBUFFREMINDERS_MYBUFFS_OPACITY:SetValue(60)
    equal(button.alpha, 0.6, "the bar's opacity")
    state.buff("player", "Aspect of the Cheetah")
    state.update("UNIT_AURA", "player")
    state.combat = true
    state.applyDrivers()
    equal(my.shown, false, "the bar hides in combat")
    equal(button.shown, true, "the combat aspect still shows")
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
    state.settings.DBR_BUFF_ASPECT:SetValue(false)
    equal(select(2, slotOf(button)), my, "Aspect off: still on My buffs")
    equal(select(3, slotOf(button)), 0, "at its start edge")
    equal(state.drivers[button], "[combat] show; hide", "Aspect off, Cheetah up: still armed")
    equal(state.row("DBR_COMBAT_ASPECT").predicate(), true, "its switch stays usable with Aspect off")
end)
-- Ammo (Consumables) ------------------------------------------------------------------
local BOW, GUN, CROSSBOW, THROWN, WAND, ARROW, BULLET = 2504, 2508, 15807, 2947, 5069, 2512, 2516
local function ammoFixture(options)
    options = options or {}
    options.class = options.class or "HUNTER"
    local state = fixture(options)
    return state, state.env.DyresBuffRemindersConsumables, state.env.DyresBuffRemindersAmmo
end
local function equip(state, ranged, ammoItem, count)
    state.equipped[18], state.equipped[0], state.ammoCount = ranged, ammoItem, count
    state.emit("PLAYER_EQUIPMENT_CHANGED")
end
local function isRed(icon) return icon.count.textColor[1] == 1 and icon.count.textColor[2] < 0.5 end
test("ammo: a bow with arrows shows the count, red and pulsing at or below Warn at, missing at 0", function()
    local state, frame, icon = ammoFixture()
    equal(frame.shown, false, "no ranged weapon: no slot")
    equip(state, BOW, ARROW, 500)
    equal(frame.shown, true)
    equal(icon.texture.texture, 3001, "the equipped arrows' icon")
    equal(icon.count.text, "500")
    equal(isRed(icon), false)
    equal(icon.glow.animation.playing, false)
    state.ammoCount = 200
    state.emit("BAG_UPDATE_DELAYED")
    equal(icon.count.text, "200")
    equal(isRed(icon), true, "at Warn at (200): red")
    equal(icon.glow.animation.playing, true, "and pulsing")
    state.settings.DBR_AMMO_WARN:SetValue(150)
    equal(isRed(icon), false, "Warn at 150: fine again")
    state.ammoCount = 0
    state.emit("UNIT_INVENTORY_CHANGED", "player")
    equal(icon.count.text, "0")
    equal(icon.texture.desaturated, true, "out of ammo: missing")
    equal(icon.glow.animation.playing, true)
    equal(frame.mouse, false, "locked: click-through")
    equal(icon.mouseClicks, false, "the icon never takes clicks")
    equal(icon.mouseMotion, true, "only hover, for its tooltip")
end)
test("ammo: arrows in your bags but none equipped shows missing, with what to do", function()
    local state, frame, icon = ammoFixture()
    state.bags[0] = {6948, ARROW}
    equip(state, BOW, nil, 0)
    equal(frame.shown, true)
    equal(icon.texture.desaturated, true)
    equal(icon.texture.texture, "Interface\\Icons\\INV_Ammo_Arrow_02", "the default arrow icon")
    contains(tooltip(state, icon), "Equip your arrows.")
    state.bags[0] = {6948}
    state.emit("BAG_UPDATE_DELAYED")
    contains(tooltip(state, icon), "No arrows in your bags.")
    local crossbow, _, crossbowIcon = ammoFixture()
    crossbow.bags[1] = {ARROW}
    equip(crossbow, CROSSBOW, nil, 0)
    contains(tooltip(crossbow, crossbowIcon), "Equip your arrows.", "a crossbow takes arrows")
end)
test("ammo: a gun takes bullets; a Warrior with a gun counts too", function()
    local state, _, icon = ammoFixture({class = "WARRIOR"})
    state.bags[2] = {ARROW, BULLET}
    equip(state, GUN, nil, 0)
    equal(icon.texture.texture, "Interface\\Icons\\INV_Ammo_Bullet_02")
    contains(tooltip(state, icon), "Equip your bullets.")
    equip(state, GUN, BULLET, 900)
    equal(icon.texture.texture, 3002)
    equal(icon.count.text, "900")
end)
test("ammo: a thrown weapon, a wand, or none takes no slot; so do its switches", function()
    local state, frame = ammoFixture()
    for _, weapon in ipairs({THROWN, WAND}) do
        equip(state, weapon, nil, 0)
        equal(frame.shown, false, "no ammo for " .. weapon)
    end
    equip(state, BOW, ARROW, 300)
    equal(frame.shown, true)
    state.settings.DBR_CONSUMABLE_AMMO:SetValue(false)
    equal(frame.shown, false, "Ammo off")
    state.settings.DBR_CONSUMABLE_AMMO:SetValue(true)
    state.settings.DBR_CONSUMABLES_ENABLED:SetValue(false)
    equal(frame.shown, false, "Consumables off")
    state.settings.DBR_CONSUMABLES_ENABLED:SetValue(true)
    state.settings.DBR_ENABLED:SetValue(false)
    equal(frame.shown, true, "the Reminders switch is not the Consumables one")
end)
test("ammo: it updates in combat; a secret or missing count keeps the last one, and debug says so", function()
    local state, _, icon = ammoFixture()
    equip(state, BOW, ARROW, 500)
    state.combat = true
    state.ammoCount = 180
    state.emit("UNIT_INVENTORY_CHANGED", "player")
    equal(icon.count.text, "180", "in combat too")
    equal(isRed(icon), true)
    state.ammoCount = "secret"
    state.emit("BAG_UPDATE_DELAYED")
    equal(icon.count.text, "180", "a secret count: the last readable one")
    state.clear()
    state.slash("debug")
    contains(state.find("debug ammo"), "on=true weapon=2 kind=arrow ammoID=2512 name=Rough Arrow count=180 "
        .. "countAPI=secret warnAt=200 state=low shown=true")
    local bare, _, bareIcon = ammoFixture({noAmmoAPI = true})
    equip(bare, BOW, ARROW, 500)
    equal(bareIcon.count.text, "?", "no count API, nothing read yet")
    bare.clear()
    bare.slash("debug")
    contains(bare.find("debug ammo"), "countAPI=missing")
end)
test("ammo: unlocked, a drag that starts on the icon moves and saves the bar; hover keeps its tooltip", function()
    local state, frame, icon = ammoFixture()
    state.slash("unlock")
    equal(frame.shown, true, "no ranged weapon: still a sample to place")
    equal(icon.texture.texture, "Interface\\Icons\\INV_Ammo_Arrow_02")
    equal(frame.mouse, true, "the bar takes the drag")
    equal(icon.mouseClicks, true, "unlocked, the icon takes the drag too")
    equal(type(icon.scripts.OnDragStart), "function", "the icon is a drag handle")
    icon.scripts.OnDragStart(icon)
    equal(frame.moving, true, "the drag moves the bar")
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", nil, "BOTTOMLEFT", 222, 333)
    icon.scripts.OnDragStop(icon)
    equal(frame.moving, false)
    local position = state.dbr.db.consumables.position
    equal(position ~= nil, true, "saved")
    equal(position.relativePoint ~= nil, true)
    contains(tooltip(state, icon), "Drag to move the Consumables bar.")
    state.slash("lock")
    equal(frame.shown, false, "locked without a ranged weapon: hidden")
    equal(icon.mouseClicks, false, "locked: click-through again")
    equip(state, BOW, ARROW, 500)
    contains(tooltip(state, icon), "500 left")
end)
test("ammo: a four-digit count fits inside the icon: a small outlined font, bottom-right", function()
    local state, frame, icon = ammoFixture()
    equip(state, BOW, ARROW, 1600)
    equal(icon.count.text, "1600")
    equal(icon.count.font[2], 12, "small: four digits fit in 40")
    equal(icon.count.font[3], "THICKOUTLINE", "a thick outline, to read on light icons")
    equal(icon.count.shadowColor[4], 1, "and a solid shadow")
    equal(icon.count.shadowOffset[1], 1)
    equal(icon.count.shadowOffset[2], -1)
    equal(icon.count.justifyH, "RIGHT")
    equal(icon.count.wordWrap, false)
    local anchors = {}
    for _, point in ipairs(icon.count.points) do anchors[point[1]] = point end
    equal(anchors.BOTTOMRIGHT ~= nil and anchors.BOTTOMLEFT ~= nil, true, "held inside the icon's width")
    equal(icon.count.parent, icon, "it scales with the bar, so it fits at every Size")
    equal(icon.glow.backdropBorder[1], 1)
    equal(icon.glow.backdropBorder[2], 0.82, "plenty: the gold border")
    state.ammoCount = 150
    state.emit("BAG_UPDATE_DELAYED")
    equal(isRed(icon), true, "the low warning stays red")
    equal(icon.glow.backdropBorder[2], 0.2, "low: the border is red too, the count text's red")
    equal(icon.glow.animation.playing, true, "and it pulses")
    state.ammoCount = 0
    state.emit("BAG_UPDATE_DELAYED")
    equal(icon.glow.backdropBorder[2], 0.2, "missing: red")
    state.ammoCount = 900
    state.emit("BAG_UPDATE_DELAYED")
    equal(icon.glow.backdropBorder[2], 0.82, "above Warn at again: gold")
    equal(icon.glow.animation.playing, false)
end)
test("ammo: settings, its widget, and saved settings repaired", function()
    local state, frame = ammoFixture()
    equal(state.settings.DBR_CONSUMABLES_ENABLED.name, "Enable")
    equal(state.row("DBR_CONSUMABLE_AMMO").parentInitializer, state.row("DBR_CONSUMABLES_ENABLED"))
    local warn = state.row("DBR_AMMO_WARN")
    equal(warn.parentInitializer, state.row("DBR_CONSUMABLE_AMMO"))
    equal(warn.options.minValue, 0)
    equal(warn.options.maxValue, 1000)
    equal(warn.options.step, 50)
    equal(state.row("DYRE_DYRESBUFFREMINDERS_CONSUMABLES_SCALE").setting.name, "Consumables: size (%)")
    equal(frame.dyre.widgetKey, "consumables")
    equal(select(1, state.absCenter(frame)), 500 + 150, "beside My buffs")
    equal(select(2, state.absCenter(frame)), 400 + 130)
    local db = fixture({db = {consumables = {enabled = "x", ammo = 0, ammoWarn = 237}}}).dbr.db.consumables
    equal(db.enabled, true)
    equal(db.ammo, true)
    equal(db.ammoWarn, 250, "stepped by 50")
    equal(state.dbr.SanitizeAmmoWarn(5000), 1000)
end)
test("on a flight path no buff reminders show; after landing they come back; unlocked, samples stay", function()
    local state = fixture({known = {[INTELLECT] = true, [FROST_ARMOR] = true}})
    local intellect, armor = state.icon("arcaneIntellect"), state.icon("mageArmor")
    equal(intellect.shown, true)
    state.taxi = true
    state.update("PLAYER_CONTROL_LOST")
    equal(intellect.shown, false, "on a taxi: nothing you can act on")
    equal(armor.shown, false)
    equal(intellect.attributes.type1, nil, "no click either")
    state.slash("unlock")
    equal(intellect.shown, true, "unlocked: samples to place, also on a taxi")
    equal(armor.shown, true)
    state.slash("lock")
    equal(intellect.shown, false)
    state.taxi = false
    state.update("PLAYER_CONTROL_GAINED")
    equal(intellect.shown, true, "landed: the missing ones are back")
    equal(intellect.attributes.type1, "spell")
    local hunter = fixture({class = "HUNTER", known = {[HAWK] = true, [CHEETAH] = true}})
    hunter.equipped[18], hunter.equipped[0], hunter.ammoCount = BOW, ARROW, 500
    hunter.emit("PLAYER_EQUIPMENT_CHANGED")
    hunter.taxi = true
    hunter.update("PLAYER_CONTROL_LOST")
    equal(hunter.icon("aspect").shown, false, "no Aspect reminder in flight")
    equal(hunter.env.DyresBuffRemindersConsumables.shown, true, "the ammo count stays: it is information")
end)
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
    equal(button.bar.color[1] .. "," .. button.bar.color[2] .. "," .. button.bar.color[3], "1,0.82,0",
        "a full gold bar under the reminder")
    equal(button.bar.height, 5)
    local container
    for _, frame in ipairs(state.frames) do
        if frame.kind == "AuraContainer" then container = frame end
    end
    local timerBar = container.slots[1].button.display.bar
    equal(timerBar.track.color[4], 1, "an opaque track hides the gold bar under a draining one")
    equal(timerBar.points[1][5], button.bar.points[1][5], "both bars in the same place")
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
    equal(display.dyre.mover.shown, true, "the toolkit's outline")
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
    state.clear()
    state.slash("debug")
    contains(state.find("debug seal "), "debug seal on=true click=Seal of Righteousness last=nil "
        .. "driver=[combat] show; hide sealIDs=35 spellbook=none unknownIDs=none")
end)
test("Paladin: Seal of Fury (Forever's seal) counts, and the last seal cast is the click", function()
    local FURY = 20423
    local state = sealFixture({known = {[RIGHTEOUSNESS] = true, [FURY] = true}})
    local button = state.env.DyresBuffRemindersSealButton
    local container
    for _, frame in ipairs(state.frames) do
        if frame.kind == "AuraContainer" then container = frame end
    end
    for _, id in ipairs({20163, 20419, 20421, 20422, 20423, 1311649, 1311656}) do
        equal(container.slots[1].ids[id], true, "Seal of Fury ID " .. id)
    end
    equal(button.attributes.spell1, "Seal of Righteousness", "before any cast: the first known")
    state.cast(FURY)
    equal(state.dbr.db.last.seal, "Seal of Fury")
    equal(button.attributes.spell1, "Seal of Fury")
    equal(button.texture.texture, 2000 + FURY, "the picture shows the seal you use")
end)
test("Paladin: a seal found only in the spellbook joins the timer, also when learned later", function()
    local ZEAL = 990001
    local state = sealFixture()
    local containers = {}
    for _, frame in ipairs(state.frames) do
        if frame.kind == "AuraContainer" then containers[#containers + 1] = frame end
    end
    equal(#containers, 1)
    equal(containers[1].slots[1].ids[ZEAL], nil)
    state.known[ZEAL] = true
    state.spellbook[#state.spellbook + 1] = {spellID = ZEAL, name = "Seal of Zeal"}
    state.spellbook[#state.spellbook + 1] = {spellID = 585, name = "Smite"}
    state.spellbook[#state.spellbook + 1] = {spellID = 990002, name = "Seal of Later", itemType = 2}
    state.emit("SPELLS_CHANGED")
    containers = {}
    for _, frame in ipairs(state.frames) do
        if frame.kind == "AuraContainer" then containers[#containers + 1] = frame end
    end
    equal(#containers, 2, "a new container for the new seal")
    equal(containers[1].shown, false, "the old one hidden")
    equal(containers[2].slots[1].ids[ZEAL], true)
    equal(containers[2].slots[1].ids[990002], nil, "not learned yet")
    equal(containers[2].slots[1].ids[RIGHTEOUSNESS], true, "the listed seals stay")
    state.emit("SPELLS_CHANGED")
    local count = 0
    for _, frame in ipairs(state.frames) do
        if frame.kind == "AuraContainer" then count = count + 1 end
    end
    equal(count, 2, "no new container without a new seal")
    state.cast(ZEAL)
    equal(state.dbr.db.last.seal, "Seal of Zeal")
    equal(state.env.DyresBuffRemindersSealButton.attributes.spell1, "Seal of Zeal")
    state.cast(585)
    equal(state.dbr.db.last.seal, "Seal of Zeal", "only seals count")
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
-- A drag that starts on an icon moves its bar to x, y (the bar's center).
local function dragBar(state, icon, bar, x, y)
    icon.scripts.OnDragStart(icon)
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", nil, "BOTTOMLEFT", x / bar:GetEffectiveScale(), y / bar:GetEffectiveScale())
    icon.scripts.OnDragStop(icon)
end
local DIVINE_SPIRIT, SHADOW_PROTECTION = 14752, 976
local GROUP_SCALE = "DYRE_DYRESBUFFREMINDERS_GROUPBUFFS_SCALE"

test("two bars, group buffs and my buffs, each as wide as the icons you can show", function()
    local mage = fixture({known = {[INTELLECT] = true, [FROST_ARMOR] = true}})
    local group, my = mage.bar("group"), mage.bar("my")
    equal(mage.icon("arcaneIntellect").parent, group)
    equal(mage.icon("mageArmor").parent, my)
    equal(group.width, 40, "Arcane Intellect")
    equal(my.width, 40, "Armor")
    equal(my.height, 40)
    equal(select(2, mage.absCenter(group)), 400 + 180, "default places above the center")
    equal(select(2, mage.absCenter(my)), 400 + 130)
    local priest = fixture({class = "PRIEST", known = {[FORTITUDE] = true, [INNER_FIRE] = true}})
    equal(priest.icon("innerFire").parent, priest.bar("my"))
    equal(priest.bar("group").width, 40, "Divine Spirit and Shadow Protection are off")
    equal(priest.bar("my").width, 40, "Inner Fire")
    local druid = fixture({class = "DRUID", known = {[MARK] = true, [THORNS] = true}})
    equal(druid.icon("thorns").parent, druid.bar("group"), "Thorns can go on another player")
    equal(druid.bar("group").width, 88)
    equal(druid.bar("my"), nil, "no self-only buffs: no bar")
    local warlock = fixture({class = "WARLOCK", known = {[DEMON_SKIN] = true}})
    equal(warlock.bar("group"), nil, "no group buffs: no bar")
    equal(warlock.bar("my").width, 40)
    equal(#warlock.toolkit.Widgets(ADDON), 2, "My buffs and Consumables")
    local paladin = fixture({class = "PALADIN", known = {[25780] = true}})
    equal(paladin.icon("righteousFury").parent, paladin.bar("my"))
end)
test("each reminder's bar: Group buffs for what can go on another player, My buffs for self only", function()
    local state = fixture()
    local function bar(reminder) return (reminder.group or reminder.others) and "group" or "my" end
    local wanted = {arcaneIntellect = "group", mageArmor = "my", demonArmor = "my",
        markOfTheWild = "group", thorns = "group", righteousFury = "my", fortitude = "group", innerFire = "my",
        divineSpirit = "group", shadowProtection = "group", aspect = "my"}
    local count = 0
    for _, list in pairs(state.dbr.BUFFS) do
        for _, reminder in ipairs(list) do
            equal(bar(reminder), wanted[reminder.key], reminder.key)
            count = count + 1
        end
    end
    equal(count, 11, "every reminder is listed here")
end)
test("Priest: Divine Spirit, known, switched off: no slot; switched on: Group buffs has two", function()
    local state = fixture({class = "PRIEST", known = {[FORTITUDE] = true, [INNER_FIRE] = true,
        [DIVINE_SPIRIT] = true}})
    local group, my = state.bar("group"), state.bar("my")
    equal(group.width, 40)
    equal(my.width, 40)
    state.slash("unlock")
    equal(state.icon("divineSpirit").shown, false, "switched off: no sample either")
    state.slash("lock")
    state.settings.DBR_BUFF_DIVINESPIRIT:SetValue(true)
    equal(group.width, 88, "two slots")
    equal(my.width, 40, "My buffs unchanged")
    state.slash("unlock")
    equal(state.icon("fortitude").shown, true)
    equal(state.icon("divineSpirit").shown, true, "every slot holds its own icon")
    state.slash("lock")
    state.settings.DBR_BUFF_DIVINESPIRIT:SetValue(false)
    equal(group.width, 40, "switched off: back to one")
    local unknown = fixture({class = "PRIEST", known = {[FORTITUDE] = true}})
    unknown.settings.DBR_BUFF_DIVINESPIRIT:SetValue(true)
    equal(unknown.bar("group").width, 40, "switched on but not known: no slot")
    unknown.known[DIVINE_SPIRIT] = true
    unknown.update("SPELLS_CHANGED")
    equal(unknown.bar("group").width, 88, "learned: the bar grows")
end)
test("a bar with nothing you can show is hidden, also while unlocked", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local my = state.bar("my")
    equal(state.drivers[my], "hide")
    equal(my.shown, false)
    state.slash("unlock")
    equal(my.shown, false, "no outline around nothing")
    state.slash("lock")
    state.known[FROST_ARMOR] = true
    state.update("SPELLS_CHANGED")
    equal(state.drivers[my], "[combat] hide; show", "learned Frost Armor: it shows")
    equal(my.shown, true)
end)
test("a spell learned in combat grows its bar only after combat", function()
    local state = fixture({class = "PRIEST", known = {[FORTITUDE] = true}})
    local bar = state.bar("group")
    state.settings.DBR_BUFF_DIVINESPIRIT:SetValue(true)
    state.combat = true
    state.applyDrivers()
    state.known[DIVINE_SPIRIT] = true
    state.update("SPELLS_CHANGED")
    equal(bar.width, 40, "no secure change in combat")
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
    equal(bar.width, 88)
end)
test("the missing icons pack in from the left edge; the empty part takes no clicks while locked", function()
    local state = fixture({class = "PRIEST", known = {[FORTITUDE] = true, [DIVINE_SPIRIT] = true,
        [SHADOW_PROTECTION] = true}})
    state.settings.DBR_BUFF_DIVINESPIRIT:SetValue(true)
    state.settings.DBR_BUFF_SHADOWPROTECTION:SetValue(true)
    local bar = state.bar("group")
    local function slot(key)
        local point = state.icon(key).points[#state.icon(key).points]
        equal(point[1], "LEFT")
        equal(point[2], bar)
        return point[4]
    end
    equal(slot("fortitude"), 0)
    equal(slot("divineSpirit"), 48)
    equal(slot("shadowProtection"), 96)
    state.buff("player", "Power Word: Fortitude")
    state.update("UNIT_AURA", "player")
    equal(state.icon("fortitude").shown, false)
    equal(slot("divineSpirit"), 0, "moves up to the left edge")
    equal(slot("shadowProtection"), 48)
    equal(bar.width, 136, "the bar keeps its size")
    equal(bar.mouse, false, "locked: click-through where no icon shows")
    state.slash("unlock")
    equal(bar.mouse, true, "unlocked: the bar takes the drag")
    state.slash("lock")
    equal(bar.mouse, false)
end)
test("unlocked, each bar is outlined and shows its icons to drag; a drag on an icon moves the bar", function()
    local state = fixture({known = {[INTELLECT] = true, [FROST_ARMOR] = true}})
    state.buff("player", "Frost Armor")
    state.update("UNIT_AURA", "player")
    state.slash("unlock")
    contains(state.last(), "Frames unlocked")
    local group, my = state.bar("group"), state.bar("my")
    local intellect, armor = state.icon("arcaneIntellect"), state.icon("mageArmor")
    equal(group.dyre.mover.shown, true, "the toolkit's outline, the bar's full size")
    equal(intellect.shown, true)
    equal(armor.shown, true, "a buff that is on shows too, to drag")
    equal(armor.texture.alpha, 0.4, "dimmed: it is not missing")
    equal(armor.glow.animation.playing, false)
    equal(intellect.texture.alpha, 1, "missing: solid and pulsing")
    equal(intellect.glow.animation.playing, true)
    equal(intellect.attributes.type1, nil, "dragging never casts")
    dragBar(state, armor, my, 200, 150)
    equal(my.moving, false)
    equal(state.dbr.db.bars.mybuffs.position.relativePoint ~= nil, true, "the toolkit saves the bar's place")
    equal(state.dbr.db.icons, nil, "never a place per icon")
    local ax = iconCenter(state, "mageArmor")
    state.slash("lock")
    equal(group.dyre.mover.shown, false)
    equal(intellect.attributes.type1, "spell")
    equal(armor.shown, false)
    state.slash("reset")
    contains(state.last(), "default places")
    equal(state.dbr.db.bars.mybuffs.position, nil)
    equal(select(2, state.absCenter(my)), 400 + 130, "back in its default place")
    equal(ax ~= iconCenter(state, "mageArmor"), true)
end)
test("in combat a bar never changes; its size and place wait for the end of combat, opacity does not", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local bar = state.bar("group")
    state.combat = true
    state.applyDrivers()
    state.settings[GROUP_SCALE]:SetValue(150)
    equal(state.dbr.db.bars.groupbuffs.scale, 150, "saved at once")
    equal(bar.scale ~= 1.5, true, "applied after combat")
    state.settings.DYRE_DYRESBUFFREMINDERS_GROUPBUFFS_OPACITY:SetValue(50)
    equal(bar.alpha, 0.5, "opacity at once, also in combat")
    state.clear()
    state.slash("reset")
    contains(state.last(), "after combat")
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
    equal(bar.scale, 1.5)
end)
test("the settings page: each widget's size and opacity, then Reset size", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local scale = state.row(GROUP_SCALE)
    equal(scale.setting.name, "Group buffs: size (%)")
    equal(scale.options.minValue, 50)
    equal(scale.options.maxValue, 200)
    equal(scale.options.step, 10)
    equal(state.row("DYRE_DYRESBUFFREMINDERS_GROUPBUFFS_OPACITY").setting.name, "Group buffs: opacity")
    equal(state.row("DYRE_DYRESBUFFREMINDERS_MYBUFFS_SCALE").setting.name, "My buffs: size (%)")
    local headings = {}
    for _, heading in ipairs(state.headings) do headings[#headings + 1] = heading.heading end
    equal(headings[2], "Consumables")
    equal(headings[3], "Size and Opacity")
    local reset
    for _, row in ipairs(state.page().initializers) do
        if row.kind == "button" and row.label == "Group buffs" then reset = row end
    end
    equal(reset.buttonText, "Reset size")
    state.settings[GROUP_SCALE]:SetValue(170)
    reset.click()
    equal(state.dbr.db.bars.groupbuffs.scale, 100)
    local paladin = fixture({class = "PALADIN", known = {[25780] = true, [21084] = true}})
    equal(paladin.row("DYRE_DYRESBUFFREMINDERS_SEAL_SCALE").setting.name, "Seal timer: size (%)")
    equal(paladin.row(GROUP_SCALE), nil, "a Paladin has no group buffs")
    equal(fixture({class = "WARRIOR"}).row(GROUP_SCALE), nil)
end)
test("from 1.0.0: the seal timer keeps its place and size; the loose icons start in their bar", function()
    local state = fixture({class = "PALADIN", known = {[25780] = true, [21084] = true}, db = {
        seal = {enabled = true, scale = 130, position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 300,
            y = 500}},
        icons = {righteousFury = {scale = 150, position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 10,
            y = 20}}}}})
    local display = state.env.DyresBuffRemindersSeal
    equal(display.scale, 1.3)
    local point = display.points[#display.points]
    equal(point[4], 300)
    equal(point[5], 500)
    equal(state.dbr.db.icons, nil)
    equal(state.dbr.db.bars.mybuffs.scale, 100)
    equal(state.icon("righteousFury").parent, state.bar("my"))
end)

-- Settings page, tooltips, and debug ---------------------------------------------------

test("the settings page lists your class's buffs, each group switch under its buff", function()
    local state = fixture({class = "PRIEST", known = {[FORTITUDE] = true}})
    local page = state.page()
    equal(page.parent, state.categories["Dyre's AddOns"], "under Dyre's AddOns")
    local names = {}
    for _, row in ipairs(page.initializers) do
        if row.setting then
            if row.setting.variable == "DBR_CHIMES_ENABLED" then break end
            names[#names + 1] = row.setting.name
        end
    end
    equal(table.concat(names, "|"), "Enable|Power Word: Fortitude|Power Word: Fortitude: also your group|"
        .. "Inner Fire|Divine Spirit|Divine Spirit: also your group|Shadow Protection|"
        .. "Shadow Protection: also your group|Remind before a buff runs out (seconds)|"
        .. "Enable|Ammo|Warn at|Group buffs: size (%)|Group buffs: opacity|My buffs: size (%)|My buffs: opacity|"
        .. "Consumables: size (%)|Consumables: opacity")
    local group = state.row("DBR_GROUP_FORTITUDE")
    equal(group.parentInitializer, state.row("DBR_BUFF_FORTITUDE"))
    contains(group.tooltip, "Prayer of Fortitude")
    contains(state.row("DBR_GROUP_DIVINESPIRIT").tooltip, "who uses mana")
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
    contains(state.messages[2], "debug arcaneIntellect bar=groupbuffs on=true group=true known=true shown=true "
        .. "missing=you "
        .. "click=Arcane Intellect@player unknownIDs=none")
    contains(state.messages[3], "debug mageArmor bar=mybuffs on=true group=nil known=false")
    state.combat = true
    state.clear()
    state.slash("debug")
    contains(state.find("debug arcaneIntellect"), "not checked in combat")
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

-- Cooldown chimes (merged from Dyre's Cooldown Chimes) -------------------------------------

test("out of combat a chime plays half a second before the cooldown read after the cast", function()
    local state = fixture()
    state.cast(FROST_NOVA, 23)
    equal(state.chimes().learned.frostnova, nil, "read 0.1 s after the cast")
    state.advance(0.1)
    equal(state.chimes().learned.frostnova, 23, "the real length is learned")
    state.advance(22.3)
    equal(#state.played, 0, "not before the lead")
    state.advance(0.2)
    equal(#state.played, 1, "one chime, from the read cooldown, not Classic's 25 s")
    equal(state.played[1].key, "talent", "Talent ready by default")
    equal(state.played[1].speech, "Frost Nova ready")
    state.advance(5)
    equal(#state.played, 1, "the Classic schedule was replaced")
end)
test("chimes: every rank counts, matched by name", function()
    local state = fixture()
    state.cast(FROST_NOVA_4, 25)
    state.advance(30)
    equal(#state.played, 1)
    equal(state.played[1].speech, "Frost Nova ready")
end)
test("chimes in combat: the secret cooldown is never read; Classic's or a learned length is used", function()
    local state = fixture()
    state.combat = true
    state.cast(BLINK)
    state.advance(14.4)
    equal(#state.played, 0)
    state.advance(0.2)
    equal(#state.played, 1, "Blink's Classic 15 s minus the 0.5 s lead")
    equal(state.chimes().learned.blink, nil, "nothing learned from a secret cooldown")
    local learned = fixture()
    learned.cast(BLINK, 13)
    learned.advance(20)
    equal(learned.chimes().learned.blink, 13)
    local again = fixture({db = learned.dbr.db})
    again.combat = true
    again.cast(BLINK)
    again.advance(12.4)
    equal(#again.played, 0)
    again.advance(0.2)
    equal(#again.played, 1, "13 s learned, kept across sessions, minus the lead")
end)
test("chimes: the lead moves them, in steps of half a second from 0 to 3", function()
    local state = fixture()
    state.settings.DBR_CHIME_LEAD:SetValue(2)
    state.combat = true
    state.cast(BLINK)
    state.advance(12.9)
    equal(#state.played, 0)
    state.advance(0.2)
    equal(#state.played, 1)
    local dbr = state.dbr
    equal(dbr.SanitizeChimeLead(1.3), 1.5)
    equal(dbr.SanitizeChimeLead(9), 3)
    equal(dbr.SanitizeChimeLead(-1), 0)
    equal(dbr.SanitizeChimeLead(0 / 0), 0.5, "NaN")
    equal(dbr.SanitizeChimeLead("2"), 0.5)
    equal(dbr.db.lead, 5, "the buff reminders' own lead is separate")
end)
test("chimes: casting again replaces the earlier chime; other casts are ignored", function()
    local state = fixture()
    state.combat = true
    state.cast(BLINK)
    state.advance(5)
    state.cast(BLINK)
    state.cast(FIREBALL)
    state.cast(999999)
    state.cast(state.secret())
    state.emit("UNIT_SPELLCAST_SUCCEEDED", "target", "Cast-2", BLINK)
    state.advance(14.4)
    equal(#state.played, 0, "the first schedule was replaced")
    state.advance(0.2)
    equal(#state.played, 1)
    state.advance(60)
    equal(#state.played, 1)
end)
test("chimes: Cold Snap cancels the Frost chimes; Preparation the Rogue's", function()
    local state = fixture()
    state.combat = true
    state.cast(FROST_NOVA)
    state.cast(BLINK)
    state.advance(3)
    state.cast(COLD_SNAP)
    state.advance(30)
    equal(#state.played, 1, "Blink chimes; Frost Nova was reset")
    equal(state.played[1].speech, "Blink ready")
    local rogue = fixture({class = "ROGUE"})
    rogue.combat = true
    rogue.cast(KICK_2)
    rogue.cast(SPRINT)
    rogue.cast(PREPARATION)
    rogue.advance(400)
    equal(#rogue.played, 0, "Preparation itself is off by default")
    rogue.settings.DBR_CHIME_PREPARATION:SetValue(true)
    rogue.cast(PREPARATION)
    rogue.advance(600)
    equal(#rogue.played, 1)
    equal(rogue.played[1].speech, "Preparation ready")
end)
test("chimes: only your own class's spells chime, and the switches silence them", function()
    local priest = fixture({class = "PRIEST"})
    priest.combat = true
    priest.cast(BLINK)
    priest.advance(60)
    equal(#priest.played, 0)
    local state = fixture()
    state.combat = true
    state.settings.DBR_CHIME_BLINK:SetValue(false)
    state.cast(BLINK)
    state.advance(20)
    equal(#state.played, 0, "Blink switched off")
    state.settings.DBR_CHIME_BLINK:SetValue(true)
    state.settings.DBR_CHIMES_ENABLED:SetValue(false)
    state.cast(BLINK)
    state.advance(20)
    equal(#state.played, 0, "all chimes off")
    state.settings.DBR_CHIMES_ENABLED:SetValue(true)
    state.settings.DBR_ENABLED:SetValue(false)
    state.cast(BLINK)
    state.advance(20)
    equal(#state.played, 1, "the buff reminders' switch does not silence the chimes")
    equal(state.chimes().spells.coldsnap, false, "Cold Snap starts off, as in MTF")
end)
test("chimes: choosing a sound saves it and plays it once; Text to Speech says the spell", function()
    local state = fixture()
    local sound = state.settings.DBR_CHIME_BLINK_SOUND
    equal(sound:GetValue(), "talent")
    sound:SetValue("magical")
    equal(state.chimes().sounds.blink, "magical")
    equal(#state.played, 1, "a preview")
    equal(state.played[1].key, "magical")
    sound:SetValue("kazoo")
    equal(state.chimes().sounds.blink, "magical", "an unknown key is refused")
    state.combat = true
    state.cast(BLINK)
    state.advance(20)
    equal(state.played[#state.played].key, "magical")
    local voice = fixture()
    voice.voice = true
    voice.settings.DBR_CHIME_BLINK_SOUND:SetValue("voice")
    equal(voice.played[1].speech, "Blink ready")
    voice.voice = false
    voice.dbr.PreviewChime("blink")
    equal(voice.played[2].key, "talent", "the default when the voice cannot play")
end)
test("the settings page: a Chimes section with its own switch, lead, and spells", function()
    local state = fixture()
    local page = state.page()
    equal(state.headings[1].heading, "Reminders")
    equal(state.settings.DBR_ENABLED.name, "Enable", "the page already says Buff Reminders")
    equal(state.settings.DBR_CHIMES_ENABLED.name, "Enable")
    equal(state.headings[2].heading, "Consumables")
    equal(state.headings[3].heading, "Size and Opacity")
    equal(state.headings[4].heading, "Chimes")
    local switch, switchAt = state.row("DBR_CHIMES_ENABLED")
    equal(page.initializers[switchAt - 1], state.headings[4], "the section starts with its heading")
    local _, leadAt = state.row("DBR_LEAD")
    equal(leadAt < switchAt, true, "after the buff reminders")
    local lead = state.row("DBR_CHIME_LEAD")
    equal(lead.parentInitializer, switch)
    local blink = state.row("DBR_CHIME_BLINK")
    equal(blink.kind, "checkboxdropdown", "the switch and the sound on one row")
    equal(state.row("DBR_CHIME_BLINK_SOUND"), blink)
    equal(blink.data.cbLabel, "Blink")
    equal(blink.data.dropDownLabel, "Sound")
    contains(blink.data.cbTooltip, "just before Blink is ready again")
    contains(blink.data.dropDownTooltip, "Blink ready")
    equal(type(blink.data.dropdownOptions), "function", "Dyre's Sounds' choices")
    equal(blink.checkboxMenu, true, "Dyre's Sounds' nested menu on the row")
    equal(blink.parentInitializer, switch)
    equal(blink.predicate(), true)
    state.settings.DBR_CHIMES_ENABLED:SetValue(false)
    equal(blink.predicate(), false)
    state.settings.DBR_CHIMES_ENABLED:SetValue(true)
    blink.data.dropdownSetting:SetValue("magical")
    equal(state.chimes().sounds.blink, "magical", "the same saved key as before")
    blink.data.cbSetting:SetValue(false)
    equal(state.chimes().spells.blink, false)
    local count = 0
    for _, row in ipairs(page.initializers) do
        if row.kind == "checkboxdropdown" and row.data.cbSetting.variable:find("^DBR_CHIME_") then
            count = count + 1
        end
    end
    equal(count, 15, "one row for every Mage spell")
    -- Dyre's Sounds 0.1.1 (no SetupCheckboxMenu), or a client without the row:
    -- the switch, then the sound under it, as before.
    for _, older in ipairs({{soundsWithoutCheckboxMenu = true}, {noCheckboxDropdown = true}}) do
        local old = fixture(older)
        local oldSwitch, oldDropdown = old.row("DBR_CHIME_BLINK"), old.row("DBR_CHIME_BLINK_SOUND")
        equal(oldSwitch ~= oldDropdown, true, "two rows")
        equal(oldDropdown.kind, "dropdown")
        equal(oldDropdown.parentInitializer, oldSwitch, "the sound sits under its switch")
        equal(oldDropdown.nestedMenu, true, "Dyre's Sounds' nested menu")
        equal(oldSwitch.parentInitializer, old.row("DBR_CHIMES_ENABLED"))
        old.settings.DBR_CHIME_BLINK:SetValue(false)
        equal(oldDropdown.predicate(), false)
    end
    local knight = fixture({class = "DEATHKNIGHT"})
    equal(knight.headings[5].heading, "Your class has no chime spells yet.")
end)
test("without Dyre's Sounds chimes are timed, nothing plays, and DBR says so once", function()
    local state = fixture({sounds = "none", db = {chimes = {sounds = {blink = "effectmagical"}}}})
    equal(state.count("Install Dyre's Sounds"), 1)
    local message = state.find("Install Dyre's Sounds")
    contains(message, "DBR: ")
    contains(message, "Get it from CurseForge.", "says where to get it")
    contains(message, "the buff reminders work as usual")
    equal(message:lower():find("github", 1, true), nil, "CurseForge only, for now")
    state.combat = true
    state.cast(BLINK)
    state.advance(20)
    equal(#state.played, 0)
    state.dbr.ReportMissingSounds("MAGE")
    state.dbr.PreviewChime("blink")
    equal(state.count("Install Dyre's Sounds"), 1, "once per session")
    equal(state.chimes().sounds.blink, "effectmagical", "a saved choice is kept for when it is installed")
    equal(state.settings.DBR_CHIME_BLINK_SOUND, nil, "no sound menus to fill")
    contains(state.row("DBR_CHIMES_ENABLED").tooltip, "Install Dyre's Sounds")
    state.combat = false
    state.slash("debug")
    contains(state.find("debug chimes enabled="), "sounds=missing")
    local quiet = fixture({sounds = "none", db = {chimes = {enabled = false}}})
    equal(quiet.find("Install Dyre's Sounds"), nil, "not when the chimes are off")
    local noSpells = fixture({sounds = "none", class = "DEATHKNIGHT"})
    equal(noSpells.find("Install Dyre's Sounds"), nil, "not for a class with no chime spells")
    local old = fixture({sounds = "old"})
    equal(old.count("Update Dyre's Sounds"), 1)
end)
test("with the real Dyre's Sounds, a preview plays and old MTF keys carry over", function()
    if not fileExists(SIBLING_SOUNDS .. "/DyresSounds.toc") then
        print("# skipped: no sibling Dyre's Sounds checkout")
        return
    end
    local state = fixture({sounds = "real", db = {chimes = {sounds = {blink = "effectmagical", frostnova = "kazoo"}}}})
    equal(state.chimes().sounds.blink, "magical", "MTF's and WTF's keys map to the library's")
    equal(state.chimes().sounds.frostnova, "talent")
    state.dbr.PreviewChime("blink")
    equal(state.played[1].file, "Interface\\AddOns\\DyresSounds\\Sounds\\MagicalDisappear.mp3")
    state.combat = true
    state.cast(FROST_NOVA)
    state.advance(30)
    equal(state.played[2].kit, 73280, "Talent ready")
end)
test("chime settings are repaired: wrong types, unknown keys, and implausible lengths", function()
    local state = fixture({db = {chimes = {enabled = "yes", lead = 7,
        spells = {blink = false, frostnova = "on", bogus = true},
        sounds = {blink = "magical", frostnova = 5, counterspell = "kazoo"},
        learned = {blink = 14, frostnova = 0.5, iceblock = 99999, evocation = "8"}, extra = true}}})
    local chimes = state.chimes()
    equal(chimes.enabled, true)
    equal(chimes.lead, 3)
    equal(chimes.spells.blink, false, "a saved switch is kept")
    equal(chimes.spells.frostnova, true, "a damaged switch takes its default")
    equal(chimes.spells.bogus, nil)
    equal(chimes.sounds.blink, "magical")
    equal(chimes.sounds.frostnova, "talent")
    equal(chimes.sounds.counterspell, "talent")
    equal(chimes.learned.blink, 14)
    equal(chimes.learned.frostnova, nil)
    equal(chimes.learned.iceblock, nil)
    equal(chimes.learned.evocation, nil)
    equal(chimes.extra, nil)
    local fresh = state.dbr.SanitizeChimes("broken")
    equal(fresh.enabled, true)
    equal(fresh.lead, 0.5)
    equal(fresh.spells.deathcoil, true, "every class's spells have defaults")
    equal(fresh.sounds.kick, "talent")
    local chime = state.dbr.CHIME_SPELLS.MAGE[1]
    chime.sound = "magical"
    equal(state.dbr.SanitizeChimes({}).sounds[chime.key], "magical", "a spell's own default sound")
    chime.sound = nil
end)
test("the chime spell lists: unique keys, Classic IDs, defaults, and reset groups", function()
    local dbr = fixture().dbr
    local seen = {}
    for _, classFile in ipairs(dbr.CHIME_CLASS_ORDER) do
        local list = dbr.CHIME_SPELLS[classFile]
        equal(type(list), "table", classFile)
        local groups = {}
        for _, chime in ipairs(list) do
            equal(seen[chime.key], nil, "unique key " .. chime.key)
            seen[chime.key] = true
            equal(type(chime.spell), "number", chime.key)
            equal(type(chime.label), "string", chime.key)
            equal(type(chime.on), "boolean", chime.key)
            if chime.group then groups[chime.group] = true end
        end
        for _, chime in ipairs(list) do
            if chime.resets then
                equal(groups[chime.resets], true, chime.key .. " resets a group of its class")
            end
        end
    end
    equal(#dbr.CHIME_SPELLS.MAGE, 15, "MTF's list")
    equal(#dbr.CHIME_SPELLS.WARLOCK, 10, "WTF's list")
end)
test("/dbr debug lists the chimes: library, spells, and recent events", function()
    local state = fixture()
    state.known[BLINK] = true
    state.cast(BLINK, 15)
    state.advance(0.1)
    state.slash("debug")
    contains(state.find("debug chimes enabled="), "enabled=true lead=0.5 sounds=installed dccLoaded=false "
        .. "otherChimes=none")
    contains(state.find("debug chimes blink "), "name=Blink known=true on=true sound=talent classic=15 learned=15")
    contains(state.find("debug chimes manashield "), "classic=nil")
    contains(state.find("debug chimes lastCast="), "blink")
    contains(state.find("debug chimes log "), "scheduled blink")
    equal(state.find("debug chimes kick "), nil, "only your class's spells")
end)

-- Dyre's Cooldown Chimes, Mage Tools Forever, and Warlock Tools Forever ---------------------

test("first run: the chime settings come from Dyre's Cooldown Chimes, which then stays the one that plays", function()
    local dcc = {enabled = true, lead = 1, spells = {blink = false, coldsnap = true},
        sounds = {frostnova = "magical"}, learned = {frostnova = 22}}
    local state = fixture({loaded = {DyresCooldownChimes = true}, globals = {DyresCooldownChimesDB = dcc},
        db = {enabled = true}})
    local chimes = state.chimes()
    equal(chimes.lead, 1)
    equal(chimes.spells.blink, false)
    equal(chimes.spells.coldsnap, true)
    equal(chimes.sounds.frostnova, "magical")
    equal(chimes.learned.frostnova, 22)
    equal(state.count("Copied your chime settings from Dyre's Cooldown Chimes."), 1)
    equal(state.count("Remove its AddOn folder (DyresCooldownChimes)"), 1)
    equal(state.env.DyresCooldownChimesDB, dcc, "its settings are only read")
    equal(dcc.lead, 1)
    state.combat = true
    state.cast(FROST_NOVA)
    state.advance(30)
    equal(#state.played, 0, "while DCC is installed, it plays the chimes and DBR plays none")
    local again = fixture({globals = {DyresCooldownChimesDB = dcc}, db = {chimes = {lead = 2}}})
    equal(again.chimes().lead, 2, "only on the first run: DBR's own settings win after")
    equal(again.find("Copied your chime settings"), nil)
end)
test("first run without DCC: a Mage's chime settings come from Mage Tools Forever, once", function()
    local mtf = {chimes = {enabled = true, lead = 1.5, spells = {blink = false, coldsnap = true},
        sounds = {blink = "effectmagical"}, learned = {blink = 13}}}
    local state = fixture({loaded = {MageToolsForever = true}, globals = {MageToolsForeverDB = mtf}})
    local chimes = state.chimes()
    equal(chimes.lead, 1.5)
    equal(chimes.spells.blink, false)
    equal(chimes.spells.frostnova, true, "a spell they never set keeps DBR's default")
    equal(chimes.sounds.blink, "magical", "their old sound keys are mapped by Dyre's Sounds")
    equal(chimes.learned.blink, 13)
    equal(state.count("Copied your chime settings from Mage Tools Forever."), 1)
    equal(state.env.MageToolsForeverDB, mtf, "their settings are only read")
    local priest = fixture({class = "PRIEST", loaded = {MageToolsForever = true},
        globals = {MageToolsForeverDB = mtf}})
    equal(priest.find("Copied your chime settings"), nil, "only from the class's own AddOn")
end)
test("with an MTF or WTF that still chimes, the player is told once to turn theirs off", function()
    local state = fixture({loaded = {MageToolsForever = true}, versions = {MageToolsForever = "0.3.0-beta"},
        globals = {MageToolsForeverDB = {chimes = {enabled = true}}}, db = {chimes = {}}})
    equal(state.count("Mage Tools Forever also plays cooldown chimes"), 1)
    equal(state.find("also plays"), "DBR: Mage Tools Forever also plays cooldown chimes, so you may hear "
        .. "some twice. Turn off its Cooldown chimes until its next update.")
    state.slash("debug")
    contains(state.find("debug chimes enabled="), "otherChimes=Mage Tools Forever")
    for _, version in ipairs({"0.3.1-beta", "0.3.1", "0.2.2-beta", "bad"}) do
        local older = fixture({loaded = {MageToolsForever = true}, versions = {MageToolsForever = version},
            globals = {MageToolsForeverDB = {chimes = {enabled = true}}}, db = {chimes = {}}})
        equal(older.count("Mage Tools Forever also plays cooldown chimes"), 1, "MTF " .. version .. " still chimes")
    end
    for _, version in ipairs({"0.3.2-beta", "0.3.10", "0.4.0", "1.0.0", "0.10.0-beta"}) do
        local aside = fixture({loaded = {MageToolsForever = true}, versions = {MageToolsForever = version},
            globals = {MageToolsForeverDB = {chimes = {enabled = true}}}, db = {chimes = {}}})
        equal(aside.find("also plays"), nil, "MTF " .. version .. " plays no chimes while DBR is loaded")
    end
    local off = fixture({loaded = {MageToolsForever = true},
        globals = {MageToolsForeverDB = {chimes = {enabled = false}}}, db = {chimes = {}}})
    equal(off.find("also plays"), nil)
    local priest = fixture({class = "PRIEST", loaded = {MageToolsForever = true, WarlockToolsForever = true}})
    equal(priest.find("also plays"), nil, "MTF runs only on a Mage, WTF only on a Warlock")
    local warlock = fixture({class = "WARLOCK", loaded = {WarlockToolsForever = true}})
    equal(warlock.count("Warlock Tools Forever also plays cooldown chimes"), 1, "their default is on")
    local quiet = fixture({class = "WARLOCK", loaded = {WarlockToolsForever = true},
        db = {chimes = {enabled = false}}})
    equal(quiet.find("also plays"), nil)
end)

-- Proc sounds -------------------------------------------------------------------------------

local NATURES_GRACE, DRUID_CLEARCASTING, SHADOW_TRANCE = 16886, 16870, 17941

test("procs: the game plays a switched-on proc's sound, registered by its buff's IDs", function()
    local state = fixture({class = "DRUID"})
    equal(state.soundIDs(), tostring(NATURES_GRACE), "Nature's Grace is on by default; Clearcasting is off")
    local entry = state.auraSounds[1]
    equal(entry.trigger, 0, "when the buff is added")
    equal(entry.info.unitToken, "player")
    equal(entry.info.outputChannel, "master")
    equal(entry.info.throttleSeconds, 1)
    contains(entry.info.soundFileName, "MagicalDisappear.mp3", "the default proc sound, a file")
    state.settings.DBR_PROC_DRUIDCLEARCASTING:SetValue(true)
    equal(state.soundIDs(), DRUID_CLEARCASTING .. "," .. NATURES_GRACE)
    state.settings.DBR_PROC_NATURESGRACE:SetValue(false)
    equal(state.soundIDs(), tostring(DRUID_CLEARCASTING))
    state.settings.DBR_PROCS_ENABLED:SetValue(false)
    equal(state.soundIDs(), "", "the section's switch removes them all")
    local warrior = fixture({class = "WARRIOR"})
    equal(warrior.soundIDs(), "", "Flurry is off by default")
    warrior.settings.DBR_PROC_FLURRY:SetValue(true)
    equal(warrior.soundIDs(), "12966,12967,12968,12969,12970", "every rank's buff ID")
    local mage = fixture()
    equal(mage.soundIDs(), "", "Mage Clearcasting is off by default (the game plays a sound for it)")
    equal(fixture({class = "PRIEST"}).soundIDs(), "", "no procs for a Priest")
end)
test("procs: only IDs the client names as the buff are used", function()
    local saved = SPELLS[NATURES_GRACE]
    SPELLS[NATURES_GRACE] = "Something Else"
    local ok, message = pcall(function()
        local state = fixture({class = "DRUID"})
        equal(state.soundIDs(), "", "a listed ID with another name is left out")
        state.slash("debug")
        contains(state.find("debug procs naturesgrace"), "ids=16886=Something Else")
        contains(state.find("debug procs naturesgrace"), "registered=none status=unverified")
    end)
    SPELLS[NATURES_GRACE] = saved
    equal(ok, true, tostring(message))
end)
test("procs: out of combat the real buff ID is read, saved, and registered; never in combat", function()
    local state = fixture({class = "DRUID"})
    state.slash("debug")
    contains(state.find("debug procs naturesgrace"), "learned=nil registered=16886 status=unverified")
    state.combat = true
    state.buff("player", "Nature's Grace", {spellId = 990016})
    local reads = state.auraReads
    state.emit("UNIT_AURA", "player")
    equal(state.auraReads, reads, "no aura read in combat")
    equal(state.dbr.db.procs.learned.naturesgrace, nil)
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(state.dbr.db.procs.learned.naturesgrace, 990016, "read after the fight, while the buff is still up")
    equal(state.soundIDs(), "16886,990016", "Forever's own ID joins the Classic one")
    state.clear()
    state.slash("debug")
    contains(state.find("debug procs naturesgrace"), "learned=990016 registered=16886,990016 status=confirmed")
    local again = fixture({class = "DRUID", db = state.dbr.db})
    equal(again.soundIDs(), "16886,990016", "the learned ID is kept across sessions")
    local same = fixture({class = "DRUID"})
    same.buff("player", "Nature's Grace", {spellId = NATURES_GRACE})
    same.emit("UNIT_AURA", "player")
    equal(same.dbr.db.procs.learned.naturesgrace, NATURES_GRACE, "the Classic ID confirmed")
    equal(same.soundIDs(), tostring(NATURES_GRACE), "registered once")
    local hidden = fixture({class = "DRUID"})
    hidden.buff("player", "Nature's Grace", {spellId = hidden.secret()})
    hidden.emit("UNIT_AURA", "player")
    equal(hidden.dbr.db.procs.learned.naturesgrace, nil, "a secret ID is not read")
    hidden.units.player.secretAuras = true
    hidden.emit("UNIT_AURA", "player")
    equal(hidden.dbr.db.procs.learned.naturesgrace, nil, "a secret aura is not read")
    local off = fixture({class = "DRUID"})
    off.buff("player", "Clearcasting", {spellId = 990017})
    off.emit("UNIT_AURA", "player")
    equal(off.dbr.db.procs.learned.druidclearcasting, nil, "a switched-off proc is not read")
end)
test("procs: during a boss encounter registration waits until it ends", function()
    local state = fixture({class = "DRUID"})
    equal(state.soundIDs(), tostring(NATURES_GRACE))
    state.encounter = true
    state.settings.DBR_PROC_DRUIDCLEARCASTING:SetValue(true)
    equal(state.soundIDs(), tostring(NATURES_GRACE), "nothing changes during the encounter")
    state.clear()
    state.slash("debug")
    contains(state.find("debug procs enabled="), "deferred=true")
    state.encounter = false
    state.emit("ADDON_RESTRICTION_STATE_CHANGED")
    equal(state.soundIDs(), DRUID_CLEARCASTING .. "," .. NATURES_GRACE)
end)
test("procs: the settings page has a Procs section, one row per proc, aura sounds only", function()
    local state = fixture({class = "DRUID"})
    local headings = {}
    for _, heading in ipairs(state.headings) do headings[#headings + 1] = heading.heading end
    equal(table.concat(headings, "|"), "Reminders|Consumables|Size and Opacity|Chimes|Procs")
    equal(state.settings.DBR_PROCS_ENABLED.name, "Enable")
    local switch, switchAt = state.row("DBR_PROCS_ENABLED")
    local _, chimesAt = state.row("DBR_CHIMES_ENABLED")
    equal(switchAt > chimesAt, true, "after the cooldown chimes")
    local grace = state.row("DBR_PROC_NATURESGRACE")
    equal(grace.kind, "checkboxdropdown")
    equal(grace.menuFilter, "aura", "only sounds the game can play for a buff")
    equal(grace.parentInitializer, switch)
    equal(grace.data.cbLabel, "Nature's Grace")
    equal(state.row("DBR_PROC_DRUIDCLEARCASTING").data.cbLabel, "Clearcasting (Omen of Clarity)")
    local found = false
    for _, filter in ipairs(state.choicesFilters) do found = found or filter == "aura" end
    equal(found, true, "the choices are the aura sounds")
    grace.data.dropdownSetting:SetValue("talent")
    equal(state.dbr.db.procs.sounds.naturesgrace, "magical", "a sound kit cannot be an aura sound")
    local played = #state.played
    grace.data.dropdownSetting:SetValue("impspell")
    equal(state.dbr.db.procs.sounds.naturesgrace, "impspell")
    equal(#state.played, played + 1, "a preview")
    equal(state.auraSounds[state.auraSoundCount].info.soundFileID, 639156, "registered again with the new sound")
    local old = fixture({class = "DRUID", soundsWithoutCheckboxMenu = true})
    local oldSwitch, oldDropdown = old.row("DBR_PROC_NATURESGRACE"), old.row("DBR_PROC_NATURESGRACE_SOUND")
    equal(oldDropdown.parentInitializer, oldSwitch, "two rows with Dyre's Sounds 0.1.1")
    equal(oldDropdown.menuFilter, "aura")
    for _, other in ipairs({fixture({class = "PRIEST"}), fixture({class = "DRUID", noAuraSounds = true})}) do
        equal(other.row("DBR_PROCS_ENABLED"), nil, "no section without procs or aura sounds")
    end
end)
test("procs: first run on a Warlock copies WTF's Nightfall sound setting, once", function()
    local wtf = {alerts = {nightfall = true, nightfallSound = "magical"}}
    local state = fixture({class = "WARLOCK", known = {[687] = true}, loaded = {WarlockToolsForever = true},
        globals = {WarlockToolsForeverDB = wtf}})
    equal(state.dbr.db.procs.spells.nightfall, true)
    equal(state.dbr.db.procs.sounds.nightfall, "magical")
    equal(state.count("Copied your Nightfall sound setting from Warlock Tools Forever."), 1)
    equal(state.soundIDs(), tostring(SHADOW_TRANCE))
    equal(wtf.alerts.nightfall, true, "WTF's settings are only read")
    local again = fixture({class = "WARLOCK", globals = {WarlockToolsForeverDB = wtf},
        db = {procs = {spells = {nightfall = false}}}})
    equal(again.dbr.db.procs.spells.nightfall, false, "only on the first run")
    equal(again.find("Copied your Nightfall"), nil)
    local fresh = fixture({class = "WARLOCK"})
    equal(fresh.dbr.db.procs.spells.nightfall, false, "off by default, as in WTF")
    equal(fresh.dbr.db.procs.sounds.nightfall, "impspell", "WTF's default sound")
end)
test("procs: an older WTF that still plays Nightfall gets one warning; DBR keeps playing", function()
    local wtf = {alerts = {nightfall = true, nightfallSound = "impspell"}}
    for _, version in ipairs({"0.3.2-beta", "0.3.2", "0.2.2-beta", "bad"}) do
        local state = fixture({class = "WARLOCK", loaded = {WarlockToolsForever = true},
            versions = {WarlockToolsForever = version}, globals = {WarlockToolsForeverDB = wtf}})
        equal(state.count("Warlock Tools Forever also plays the Nightfall sound"), 1, "WTF " .. version)
        local message = state.find("also plays the Nightfall sound")
        equal(message, "DBR: Warlock Tools Forever also plays the Nightfall sound, so you may hear it twice. "
            .. "Turn off its Nightfall sound, or update it: get it from CurseForge.")
        equal(message:lower():find("github", 1, true), nil, "CurseForge only")
        equal(state.soundIDs(), tostring(SHADOW_TRANCE), "DBR still plays it, as with older MTF and WTF chimes")
        state.clear()
        state.slash("debug")
        contains(state.find("debug procs enabled="), "otherProcs=Warlock Tools Forever")
    end
    for _, version in ipairs({"0.3.3-beta", "0.3.10", "0.4.0", "1.0.0"}) do
        local aside = fixture({class = "WARLOCK", loaded = {WarlockToolsForever = true},
            versions = {WarlockToolsForever = version}, globals = {WarlockToolsForeverDB = wtf}})
        equal(aside.find("also plays the Nightfall sound"), nil, "WTF " .. version .. " stands aside for DBR")
    end
    local off = fixture({class = "WARLOCK", loaded = {WarlockToolsForever = true},
        versions = {WarlockToolsForever = "0.3.2-beta"},
        globals = {WarlockToolsForeverDB = {alerts = {nightfall = false}}}})
    equal(off.find("also plays the Nightfall sound"), nil, "not when WTF's Nightfall is off")
    local dbrOff = fixture({class = "WARLOCK", loaded = {WarlockToolsForever = true},
        versions = {WarlockToolsForever = "0.3.2-beta"}, globals = {WarlockToolsForeverDB = wtf},
        db = {procs = {spells = {nightfall = false}}}})
    equal(dbrOff.find("also plays the Nightfall sound"), nil, "not when DBR's Nightfall is off")
    local mage = fixture({loaded = {WarlockToolsForever = true}, versions = {WarlockToolsForever = "0.3.2-beta"},
        globals = {WarlockToolsForeverDB = wtf}})
    equal(mage.find("also plays the Nightfall sound"), nil, "WTF runs only on a Warlock")
end)
test("procs: without Dyre's Sounds nothing registers, and DBR says once to install it", function()
    local state = fixture({class = "DRUID", sounds = "none", db = {chimes = {enabled = false}}})
    equal(state.soundIDs(), "")
    equal(state.count("Install Dyre's Sounds to hear the cooldown chimes and proc sounds."), 1,
        "Nature's Grace is on, so the sounds are wanted even with the chimes off")
    local quiet = fixture({class = "PRIEST", sounds = "none", db = {chimes = {enabled = false}}})
    equal(quiet.find("Install Dyre's Sounds"), nil)
end)
test("procs: saved settings are repaired, and the proc list is well formed", function()
    local state = fixture({db = {procs = {enabled = "x", spells = {naturesgrace = "on", flurry = true},
        sounds = {naturesgrace = "talent", flurry = 5}, learned = {naturesgrace = "16886", flurry = 1.5,
        nightfall = 17941}}}})
    local procs = state.dbr.db.procs
    equal(procs.enabled, true)
    equal(procs.spells.naturesgrace, true, "a damaged switch takes its default")
    equal(procs.spells.flurry, true, "a saved switch is kept")
    equal(procs.sounds.naturesgrace, "magical", "only aura sounds")
    equal(procs.sounds.flurry, "magical")
    equal(procs.learned.naturesgrace, nil)
    equal(procs.learned.flurry, nil)
    equal(procs.learned.nightfall, 17941)
    local keys = {}
    for class, list in pairs(state.dbr.PROC_SOUNDS) do
        for _, proc in ipairs(list) do
            equal(keys[proc.key], nil, "unique key " .. proc.key)
            keys[proc.key] = class
            equal(type(proc.buff), "string", proc.key)
            equal(type(proc.label), "string", proc.key)
            equal(type(proc.on), "boolean", proc.key)
            equal(#proc.spells > 0, true, proc.key)
        end
    end
    equal(keys.nightfall, "WARLOCK")
    equal(keys.flurry, "WARRIOR")
end)

-- Reactive-ability probe (debug only) ------------------------------------------------------

local OVERPOWER, REVENGE, EXECUTE = 7384, 6572, 5308

local function probeLines(state)
    local lines = {}
    for _, message in ipairs(state.messages) do
        if message:find("^DBR: probe ") then lines[#lines + 1] = message end
    end
    return lines
end

test("probe: off by default; on lists the known reactive spells and their state", function()
    local state = fixture({class = "WARRIOR", known = {[OVERPOWER] = true, [REVENGE] = true}})
    equal(state.dbr.db.probe, false)
    equal(#probeLines(state), 0)
    state.emit("SPELL_UPDATE_USABLE")
    equal(#probeLines(state), 0, "nothing while off")
    state.slash("probe on")
    equal(state.dbr.db.probe, true, "saved per character")
    contains(state.find("probe on:"), "Overpower, Revenge.", "only the spells you know (no Execute)")
    contains(state.find("probe Overpower "), "usable=false noMana=false secret=no combat=no")
    contains(state.find("probe Revenge "), "usable=false noMana=false secret=no combat=no")
    state.slash("debug")
    contains(state.find("debug probe "), "on=true spells=Overpower,Revenge")
end)
test("probe: one line only when a spell's usable state changes, in or out of combat", function()
    local state = fixture({class = "WARRIOR", known = {[OVERPOWER] = true, [REVENGE] = true, [EXECUTE] = true}})
    state.slash("probe on")
    state.clear()
    state.emit("SPELL_UPDATE_USABLE")
    equal(#probeLines(state), 0, "no change, no line")
    state.combat = true
    state.usable = {Overpower = {true, false}}
    state.emit("SPELL_UPDATE_USABLE")
    state.emit("SPELL_UPDATE_USABLE")
    local lines = probeLines(state)
    equal(#lines, 1, "one line for one change")
    equal(lines[1], "DBR: probe Overpower usable=true noMana=false secret=no combat=yes")
    state.usable = {Overpower = {false, true}}
    state.emit("SPELL_UPDATE_USABLE")
    equal(probeLines(state)[2], "DBR: probe Overpower usable=false noMana=true secret=no combat=yes")
end)
test("probe: a secret answer is reported as secret, never compared or printed", function()
    local state = fixture({class = "WARRIOR", known = {[OVERPOWER] = true}})
    state.slash("probe on")
    state.clear()
    state.combat = true
    state.usable = {Overpower = "secret"}
    state.emit("SPELL_UPDATE_USABLE")
    state.emit("SPELL_UPDATE_USABLE")
    local lines = probeLines(state)
    equal(#lines, 1, "the secret state counts as one state")
    equal(lines[1], "DBR: probe Overpower usable=secret noMana=secret secret=yes combat=yes")
end)
test("probe: spell glows are printed with their spell ID and name; secret IDs as secret", function()
    local state = fixture({class = "WARRIOR", known = {[OVERPOWER] = true}})
    state.slash("probe on")
    state.clear()
    state.emit("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", OVERPOWER)
    state.combat = true
    state.emit("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", OVERPOWER)
    state.emit("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", state.secret())
    local lines = probeLines(state)
    equal(lines[1], "DBR: probe glow show spellID=7384 name=Overpower combat=no")
    equal(lines[2], "DBR: probe glow hide spellID=7384 name=Overpower combat=yes")
    equal(lines[3], "DBR: probe glow show spellID=secret name=nil combat=yes")
end)
test("probe: off stops it; it starts again after a reload; output is capped", function()
    local state = fixture({class = "WARRIOR", known = {[OVERPOWER] = true}})
    state.slash("probe on")
    state.slash("probe off")
    equal(state.dbr.db.probe, false)
    contains(state.last(), "probe off.")
    state.clear()
    state.emit("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", OVERPOWER)
    equal(#probeLines(state), 0, "nothing after off")
    local again = fixture({class = "WARRIOR", known = {[OVERPOWER] = true}, db = {probe = true}})
    equal(again.find("probe on:") ~= nil, true, "on again after a reload")
    again.clear()
    for _ = 1, 30 do again.emit("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", OVERPOWER) end
    equal(#probeLines(again), 19, "at most 20 lines per 10 seconds; the state line at login was one")
    equal(again.count("too many lines"), 1)
    again.advance(11)
    again.emit("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", OVERPOWER)
    equal(#probeLines(again), 20, "lines again after the window")
    local priest = fixture({class = "PRIEST"})
    priest.slash("probe on")
    contains(priest.find("probe on:"), "none known")
    priest.slash("probe maybe")
    contains(priest.last(), "/dbr probe on|off", "anything else shows the usage")
end)

-- Dyre's Toolkit -----------------------------------------------------------------------------

test("toolkit: the TOC nests under it and lists it as a dependency", function()
    local text = assert(io.open(ADDON .. ".toc")):read("*a")
    contains(text, "## Dependencies: DyresToolkit")
    contains(text, "## OptionalDeps: DyresSounds\n")
    contains(text, "## Group: DyresToolkit")
    contains(text, "## Category: Buffs & Debuffs", "kept for when the AddOn list does not group")
end)
test("toolkit: without Dyre's Toolkit 2.0 DBR stays off and says where to get it", function()
    for _, options in ipairs({{noToolkit = true}, {oldToolkit = true}}) do
        options.known = {[INTELLECT] = true}
        local state = fixture(options)
        equal(state.dbr.available, false)
        equal(state.last(), "DBR: Dyre's Buff Reminders needs Dyre's Toolkit 2.0 or later: install or update it "
            .. "from CurseForge. DBR stays off until then.")
        equal(state.icon("arcaneIntellect"), nil, "no frames")
        state.clear()
        state.slash("unlock")
        contains(state.last(), "unavailable")
    end
end)
test("toolkit: DBR registers, and its page sits under Dyre's AddOns with no grid or unlock row", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local list = state.toolkit.AddOns()
    equal(#list, 1)
    equal(list[1].addon, "DyresBuffReminders")
    equal(list[1].title, "Dyre's Buff Reminders")
    equal(state.page().parent, state.categories["Dyre's AddOns"])
    equal(state.row("DBR_GRID"), nil, "the toolkit draws the one grid")
    equal(state.row("DBR_UNLOCKED"), nil, "the toolkit's page has the one unlock switch")
    list[1].openSettings()
    equal(state.opened, "id:" .. PAGE)
end)
test("toolkit: one lock for every AddOn; DBR shows its frames quietly", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local bar = state.bar("group")
    equal(state.dbr.db.locked, true, "frames start locked")
    state.clear()
    state.slash("unlock")
    equal(state.toolkit.IsLocked(), false, "/dbr unlock asks the toolkit")
    equal(state.dbr.db.locked, false)
    equal(bar.dyre.mover.shown, true)
    equal(#state.messages, 1, "one line, the toolkit's")
    contains(state.messages[1], "Dyre: Frames unlocked")
    state.slash("lock")
    equal(state.toolkit.IsLocked(), true, "/dbr lock asks the toolkit too")
    equal(bar.dyre.mover.shown, false)
    state.toolkit.Unlock()
    equal(state.dbr.db.locked, false, "/dyre unlock or another AddOn's unlock unlocks DBR")
    equal(state.icon("arcaneIntellect").attributes.type1, nil, "unlocked: no cast")
    state.toolkit.Lock()
    equal(state.icon("arcaneIntellect").attributes.type1, "spell")
end)
test("toolkit: every DBR frame is a widget; DBR never moves, scales, or saves one itself", function()
    local state = fixture({class = "PALADIN", known = {[25780] = true, [21084] = true}})
    local widgets = state.toolkit.Widgets(ADDON)
    local keys = {}
    for _, widget in ipairs(widgets) do keys[#keys + 1] = widget.dyre.widgetKey end
    equal(table.concat(keys, ","), "mybuffs,seal,consumables")
    local fury, seal = state.icon("righteousFury"), state.env.DyresBuffRemindersSeal
    equal(fury.scripts.OnMouseWheel, nil, "no wheel resize of DBR's own")
    equal(seal.scripts.OnMouseWheel, nil)
    equal(seal.scripts.OnDragStart, state.toolkit.BeginDrag)
    equal(seal.dyre.store, state.dbr.db.seal, "saved under the keys it had")
    equal(state.bar("my").dyre.store, state.dbr.db.bars.mybuffs)
end)
test("toolkit: the copy the tests load matches ../DyresToolkit when it is there", function()
    for _, path in ipairs(TOOLKIT_FILES) do
        local own = io.open("../DyresToolkit/" .. path, "rb")
        if own then
            local copy = assert(io.open("tests/toolkit/" .. path, "rb"))
            equal(copy:read("*a") == own:read("*a"), true, "tests/toolkit/" .. path .. " is stale: copy it again")
            copy:close()
            own:close()
        end
    end
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
