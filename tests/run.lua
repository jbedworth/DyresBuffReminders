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
-- Dyre's Toolkit's files the tests load. Not the minimap, which needs the
-- embedded libraries.
local TOOLKIT_FILES = {"Core.lua", "Layout.lua", "Widgets.lua", "Settings.lua", "Owners.lua", "Profiles.lua"}
-- Profiles.lua came with Toolkit 2.10.0 (RegisterProfilePart).
local TOOLKIT_PROFILES = "Profiles.lua"
-- Owners.lua came with Toolkit 2.5.0; the Pet Taunt warning's claim with 2.9.0.
local TOOLKIT_OWNERS = "Owners.lua"
-- Procs.lua comes with Toolkit 2.11.0 (the proc engine, PROC_KIND_PREFIX).
-- Loaded when the toolkit folder has it; the copy in tests/toolkit (CI) has
-- not, so the fixture then sets the one constant DBR reads, as Procs.lua does.
local TOOLKIT_PROCS = "Procs.lua"
-- The real toolkit in ../DyresToolkit when it is there; else the copy in
-- tests/toolkit (as in CI).
local function toolkitDir()
    for _, path in ipairs(TOOLKIT_FILES) do
        local file = io.open("../DyresToolkit/" .. path, "rb")
        if not file then
            return "tests/toolkit/"
        end
        file:close()
    end
    return "../DyresToolkit/"
end
local TOOLKIT_DIR = toolkitDir()
io.write("# Dyre's Toolkit from ", TOOLKIT_DIR, "\n")
local HAS_TOOLKIT_PROCS = (function()
    local file = io.open(TOOLKIT_DIR .. TOOLKIT_PROCS, "rb")
    if file then
        file:close()
        return true
    end
    return false
end)()
-- Proc engine 2 (Toolkit 2.12.0, PROC_ENGINE_VERSION in its Procs.lua) and
-- the toolkit's Auras.lua it draws with. The copy in tests/toolkit has
-- neither, so the 1.13.0 proc cue tests run only beside ../DyresToolkit.
-- Units.lua gives the engine IsSecret; Auras.lua its aura containers.
local TOOLKIT_ENGINE_FILES = {"Units.lua", "Auras.lua"}
local HAS_PROC_ENGINE = (function()
    local procs = io.open(TOOLKIT_DIR .. TOOLKIT_PROCS, "rb")
    if not procs then
        return false
    end
    local found = procs:read("*a"):find("PROC_ENGINE_VERSION = 2", 1, true) ~= nil
    procs:close()
    for _, path in ipairs(TOOLKIT_ENGINE_FILES) do
        local file = io.open(TOOLKIT_DIR .. path, "rb")
        if file then
            file:close()
        else
            found = false
        end
    end
    return found
end)()
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
name("Molten Armor", 30482)
name("Dampen Magic", 604, 8450, 8451, 10173, 10174)
name("Amplify Magic", 1008, 8455, 10169, 10170)
name("Demon Skin", 687, 696)
name("Demon Armor", 706, 1086, 11733, 11734, 11735)
name("Mark of the Wild", 1126, 5232, 6756, 5234, 8907, 9884, 9885)
name("Gift of the Wild", 21849, 21850)
name("Rebirth", 20484, 20739, 20742, 20747, 20748)
name("Dampen Magic", 604, 8450, 8451, 10173, 10174)
name("Amplify Magic", 1008, 8455, 10169, 10170)
name("Inferno", 1122)
name("Ritual of Doom", 18540)
name("Thorns", 467, 782, 1075, 8914, 9756, 9910)
name("Power Word: Fortitude", 1243, 1244, 1245, 2791, 10937, 10938)
name("Prayer of Fortitude", 21562, 21564)
name("Inner Fire", 588, 7128, 602, 1006, 10951, 10952)
name("Divine Spirit", 14752, 14818, 14819, 27841)
name("Prayer of Spirit", 27681)
name("Shadow Protection", 976, 10957, 10958)
name("Prayer of Shadow Protection", 27683)
name("Righteous Fury", 25780)
-- Forever's own ID for the talent is unknown: any ID not in Buffs.lua's list.
name("Improved Righteous Fury", 99001)
name("Blessing of Kings", 99002)
name("Aspect of the Hawk", 13165, 14318, 14319, 14320, 14321, 14322, 25296)
name("Aspect of the Monkey", 13163)
name("Aspect of the Wild", 20043, 20190)
name("Aspect of the Beast", 13161)
name("Aspect of the Cheetah", 5118)
name("Aspect of the Pack", 13159)
-- TBC's ranks and Aspect of the Viper (the aspect bar's data).
name("Aspect of the Hawk", 27044)
name("Aspect of the Wild", 27045)
name("Aspect of the Viper", 34074)
name("Travel Form", 783)
name("Bear Form", 5487)
name("Dire Bear Form", 9634)
name("Cat Form", 768)
name("Aquatic Form", 1066)
name("Dash", 1850, 9821, 9823)
name("Sprint", 8696, 11305)
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
name("Battle Shout", 6673, 5242, 6192, 11549, 11550, 11551, 25289)
name("Revenge", 6572)
name("Mongoose Bite", 1495)
name("Execute", 5308)
name("Charge", 100, 6178, 11578)
name("Eviscerate", 2098, 6760)
name("Sinister Strike", 1752)
name("Ferocious Bite", 22568)
name("Growl", 2649, 14916)
name("Torment", 3716)
name("Suffering", 17735)
name("Call Pet", 883)
name("Revive Pet", 982)
name("Summon Imp", 688)
name("Summon Voidwalker", 697)
name("Summon Succubus", 712)
name("Summon Felhunter", 691)
name("Burning Wish", 18789)
name("Fel Stamina", 18790)
name("Touch of Shadow", 18791, 35701)
name("Fel Energy", 18792)
name("Feral Charge", 16979)
name("Enrage", 5229)
name("Demoralizing Roar", 99, 1735)
name("Challenging Roar", 5209)
name("Intercept", 20252)
name("Whirlwind", 1680)
name("Intervene", 3411)
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
    -- Newer sounds (Dyre's Sounds 1.2.0's "Dyre's Aggression"), when the test installs them.
    for _, key in ipairs(state.newerSounds or {}) do labels[key] = key end
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
        -- A sound whose play errors (state.playFails[key]).
        if state.playFails and state.playFails[key] then
            error("Play failed: " .. key)
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

-- Whether a buff's reminder can be seen: shown, and not under its aura slot
-- (where the engine draws the buff while it is up).
local function visible(icon)
    if not icon.shown then return false end
    local slot = icon.parent and icon.parent.slot
    if not slot then return true end
    return icon:GetFrameLevel() > slot:GetFrameLevel()
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
    -- Other AddOns' TOC titles, as the client gives them.
    local titles = {DyresToolkit = "Dyre's Toolkit", DyresCombatTools = "Dyre's Threat and Combat Tools"}
    env.C_AddOns = {GetAddOnMetadata = function(addon, field)
        if addon ~= ADDON then
            if field == "Title" then
                return titles[addon]
            end
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
        AddOnRestrictionType = {Combat = 0, Encounter = 1, Chat = 5}, PowerType = {ComboPoints = 4}}
    -- Combo points: state.comboPoints (or secret with state.comboSecret), state.comboMax;
    -- a Druid's form ID in state.formID (1 Cat Form).
    env.UnitPower = function(unit, power)
        if power ~= 4 then return 0 end
        if state.comboSecret then return state.secret() end
        return state.comboPoints or 0
    end
    env.UnitPowerMax = function(unit, power) return power == 4 and (state.comboMax or 5) or 0 end
    env.GetShapeshiftFormID = function() return state.formID end
    -- Era knows COMBO_TARGET_CHANGED (options.comboTargetEvent); registering
    -- an event the client does not know is an error.
    if options.comboTargetEvent then
        env.C_EventUtils = {IsEventValid = function(event) return event == "COMBO_TARGET_CHANGED" end}
    end
    -- Classic's combo points on the target: state.targetCombo (else none).
    env.GetComboPoints = function(unit, target)
        equal(unit, "player")
        return state.targetCombo or 0
    end
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
    -- The toolkit profile's key is "Name - Realm".
    env.GetRealmName = function() return "Forever" end
    env.UnitGUID = function(unit) return unit == "player" and "Player-1-0001" or nil end
    env.UnitIsUnit = function(a, b)
        local target = state.units.target
        if a == "target" and target and target.is then a = target.is end
        return a == b
    end
    env.UnitCanAssist = function(_, unit) return state.units[unit] ~= nil and state.units[unit].friend == true end
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
    env.GetPartyAssignment = function(kind, unit)
        equal(kind, "MAINTANK")
        if unit == "player" and state.secretMainTank then return state.secret() end
        return unit == "player" and state.mainTank == true
    end
    -- The pet bar: state.petActions[slot] = {name, auto (autocast on), token, secret}.
    env.GetPetActionInfo = function(slot)
        local action = state.petActions and state.petActions[slot]
        if not action then return nil end
        local auto = action.secret and state.secret() or action.auto == true
        return action.name, "", action.token == true, false, true, auto, nil
    end

    -- The glow's art, only where a test asks for it (else the red border).
    if options.glowArt then
        env.C_Texture = {GetAtlasInfo = function(atlas)
            if atlas == "UI-HUD-ActionBar-Proc-Loop-Flipbook" then return {width = 64, height = 64} end
        end}
    end
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
            -- An ended cooldown reads as none, as in client.
            if cooldown and cooldown.start + cooldown.duration > state.now then
                return {startTime = cooldown.start, duration = cooldown.duration}
            end
            return {startTime = 0, duration = 0}
        end,
        GetSpellSubtext = function(id)
            if id == GIFT_1 then return "Rank 1" elseif id == GIFT_2 then return "Rank 2" end
            return ""
        end,
    }
    -- Druid forms: state.form is the active form's index (1 Bear, 2 Cat, 3 Aquatic, 4 Travel, 5 Dire
    -- Bear), or nil; the fourth value is the form's spell, as the pinned StanceBar.lua reads it.
    state.formSpells = {5487, 768, 1066, 783, 9634}
    env.GetNumShapeshiftForms = function() return #state.formSpells end
    env.GetShapeshiftFormInfo = function(index)
        return 3000 + index, state.form == index, true, state.formSpells[index]
    end
    if not options.noRange then
        env.C_Spell.IsSpellInRange = function(spell, unit)
            if state.secretRange then return state.secret() end
            return not (state.outOfRange and state.outOfRange[unit])
        end
    end
    env.C_SpellBook = {IsSpellKnown = function(id) return state.known[id] == true end}
    -- The talent tree: state.talents holds {spellID, rank} nodes, one entry each.
    state.talents = options.talents or {}
    state.talentReads = 0
    env.C_ClassTalents = {GetActiveConfigID = function() return 7 end}
    env.C_Traits = {
        GetConfigInfo = function(configID)
            if configID == 7 then return {treeIDs = {1}} end
        end,
        GetTreeNodes = function()
            state.talentReads = state.talentReads + 1
            local nodes = {}
            for index in ipairs(state.talents) do nodes[index] = index end
            return nodes
        end,
        GetNodeInfo = function(_, nodeID)
            return {activeRank = state.talents[nodeID].rank, entryIDs = {nodeID}}
        end,
        GetEntryInfo = function(_, entryID) return {definitionID = entryID} end,
        GetDefinitionInfo = function(definitionID) return {spellID = state.talents[definitionID].spellID} end,
    }
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
        [5069] = {2, 19, 4005}, [2512] = {6, 2, 3001, "Rough Arrow"}, [2515] = {6, 2, 3003, "Sharp Arrow"}, [2516] = {6, 3, 3002, "Light Shot"},
        -- Reagents (class 5): Rebirth's seeds and Gift of the Wild's.
        [17034] = {5, 0, 5034, "Maple Seed"}, [17035] = {5, 0, 5035, "Stranglethorn Seed"},
        [17036] = {5, 0, 5036, "Ashwood Seed"}, [17037] = {5, 0, 5037, "Hornbeam Seed"},
        [17038] = {5, 0, 5038, "Ironwood Seed"}, [17021] = {5, 0, 5021, "Wild Berries"},
        [17026] = {5, 0, 5026, "Wild Thornroot"}, [17020] = {5, 0, 5020, "Arcane Powder"},
        [5565] = {5, 0, 5565, "Infernal Stone"}, [16583] = {5, 0, 6583, "Demonic Figurine"}}
    env.C_Item.GetItemInfoInstant = function(id)
        local item = ITEMS[id]
        if item then return id, "", "", "", item[3], item[1], item[2] end
    end
    -- state.uncached[id]: the client has not loaded that item (its name is nil).
    state.uncached, state.loadRequests = {}, {}
    env.C_Item.GetItemNameByID = function(id)
        if state.uncached[id] then return nil end
        return ITEMS[id] and ITEMS[id][4]
    end
    env.C_Item.RequestLoadItemDataByID = function(id) state.loadRequests[#state.loadRequests + 1] = id end
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
            if state.combat then error("Auras cannot be accessed when secret while tainted") end
            state.auraReads = state.auraReads + 1
            local data = state.units[unit]
            -- A debuff on a unit: state.units[unit].debuffs[name] = {spellId, applications, sourceUnit}.
            if filter == "HARMFUL" then
                return data and data.debuffs and data.debuffs[spell]
            end
            equal(filter, "HELPFUL")
            if data and data.secretAuras then return state.secret() end
            -- A buff is true (no end time), a number (when it runs out), or "secret".
            local buff = data and data.buffs and data.buffs[spell]
            if buff == "secret" then return {name = spell, expirationTime = state.secret()} end
            if type(buff) == "number" then return {name = spell, duration = 1800, expirationTime = buff} end
            -- A table: {spellId}, no end; or {expires, duration}, a buff of its own length.
            if type(buff) == "table" then
                return {name = spell, spellId = buff.spellId, duration = buff.duration or 0,
                    expirationTime = buff.expires or 0}
            end
            if buff then return {name = spell, duration = 0, expirationTime = 0} end
        end,
    }
    -- Classic Era and Anniversary (options.classicAuras): aura reads by index,
    -- also in combat, nothing secret. A buff is a table {spellId, expires, duration}.
    if options.classicAuras then
        env.C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
            local list = {}
            for spell, value in pairs(state.units[unit] and state.units[unit].buffs or {}) do
                if type(value) == "table" and value.spellId then
                    list[#list + 1] = {name = spell, spellId = value.spellId, icon = 9000 + value.spellId,
                        duration = value.duration or 0, expirationTime = value.expires or 0}
                end
            end
            table.sort(list, function(a, b) return a.spellId < b.spellId end)
            return list[index]
        end
    end
    -- By spell ID, as the client allows also in combat for never-secret auras;
    -- state.secretAuraIDs[id] makes one secret (it then returns no values in combat).
    env.C_UnitAuras.GetPlayerAuraBySpellID = function(id)
        local name = SPELLS[id]
        local data = state.units.player
        local buff = name and data.buffs and data.buffs[name]
        if not buff then return nil end
        if state.combat and state.secretAuraIDs and state.secretAuraIDs[id] then return end
        if type(buff) == "number" then return {name = name, spellId = id, expirationTime = buff} end
        return {name = name, spellId = id, expirationTime = 0}
    end
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

    -- State drivers, as the client's SecureStateDriverManager (pinned
    -- SecureStateDriver.lua): each update (every 0.2 s, and at events) a
    -- visibility driver shows or hides its frame, changed or not (:95-105,
    -- :119-129), so a secure Hide under a "show" driver lasts until the next
    -- update; an attribute driver sets its attribute only on a change
    -- (:106-115), which runs the frame's `_onstate-<name>` handler (the
    -- restricted snippet, run here with self as the frame and newstate).
    -- state.tick() is one update.
    state.driverStates = {}
    state.attributeDrivers = {}
    local function RunOnState(frame, name, value)
        local body = frame.attributes["_onstate-" .. name]
        if not body then return end
        local handle = {
            Show = function() frame.shown = true end,
            Hide = function() frame.shown = false end,
            GetAttribute = function(_, key) return frame.attributes[key] end,
        }
        local chunk = assert(loadstring("local self, stateid, newstate = ...\n" .. body))
        chunk(handle, name, value)
    end
    function state.applyDrivers()
        for frame, drivers in pairs(state.attributeDrivers) do
            for name, driver in pairs(drivers) do
                equal(driver, "[combat] 1; 0", "a known attribute driver")
                local value = state.combat and 1 or 0
                if frame.attributes["state-" .. name] ~= value then
                    frame.attributes["state-" .. name] = value
                    RunOnState(frame, name, value)
                end
            end
        end
        for frame, driver in pairs(state.drivers) do
            local value
            if driver == "[combat] hide; show" then
                value = not state.combat
            elseif driver == "[combat] show; hide" then
                value = state.combat
            elseif driver == "show" then
                value = true
            elseif driver == "[mounted] hide; [nopet] show; [@pet,dead] show; hide" then
                -- The pet reminder: state.units.pet (dead or not), state.mounted.
                local pet = state.units.pet
                value = not state.mounted and (pet == nil or pet.dead == true)
            else
                equal(driver, "hide", "a known driver")
                value = false
            end
            state.driverStates[frame] = value
            frame.shown = value
        end
    end
    state.tick = state.applyDrivers
    env.RegisterStateDriver = function(frame, kind, driver)
        if state.combat then error("RegisterStateDriver in combat") end
        if kind == "visibility" then
            equal(state.attributeDrivers[frame], nil, "a visibility driver on a frame with an attribute driver")
            state.drivers[frame] = driver
            state.driverStates[frame] = nil
        else
            equal(state.drivers[frame], nil, "an attribute driver on a frame with a visibility driver")
            state.attributeDrivers[frame] = state.attributeDrivers[frame] or {}
            state.attributeDrivers[frame][kind] = driver
            frame.attributes["state-" .. kind] = nil
        end
        state.applyDrivers()
    end
    -- Secure wraps: recorded; state.secureClick runs a wrapped frame's click as
    -- the game would (the cast, then the post-body, which may Hide in combat).
    state.wraps = {}
    if not options.noSecureWrap then
        env.SecureHandlerWrapScript = function(frame, script, header, preBody, postBody)
            if state.combat then error("SecureHandlerWrapScript in combat") end
            state.wraps[frame] = {script = script, header = header, pre = preBody, post = postBody}
        end
        env.SecureHandlerSetFrameRef = function(frame, label, ref)
            if state.combat then error("SecureHandlerSetFrameRef in combat") end
            frame.attributes["frameref-" .. label] = ref
        end
    end
    function state.secureClick(frame)
        state.clicked = state.clicked or {}
        state.clicked[#state.clicked + 1] = frame.attributes.macrotext1 or frame.attributes.spell1
        local wrap = state.wraps[frame]
        if wrap and wrap.post == "self:Hide()" then frame.shown = false end
        -- The aspect bar's post-body (Reminders.lua's BAR_CLICK), as the
        -- restricted code would run it: in combat only, through the frame ref.
        if wrap and wrap.post and wrap.post:find("dbrAspectReminder", 1, true) and state.combat then
            local reminder = frame.attributes["frameref-dbrAspectReminder"]
            local role = frame.attributes["dbr-reminder"]
            if reminder and role == "hide" then reminder.shown = false end
            if reminder and role == "show" then reminder.shown = true end
        end
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
            object.modifyPredicates = {}
            function object:InitFrame() end
            function object:SetParentInitializer(parent, predicate)
                self.parentInitializer, self.predicate = parent, predicate
            end
            function object:AddModifyPredicate(predicate)
                self.modifyPredicates[#self.modifyPredicates + 1] = predicate
            end
            -- Blizzard's per-row watch on any setting variable (Toolkit's WatchSettings).
            function object:AddEvaluateStateCVar(variable)
                self.watched = self.watched or {}
                self.watched[#self.watched + 1] = variable
            end
            function object:AddShownPredicate(predicate)
                self.shownPredicates = self.shownPredicates or {}
                self.shownPredicates[#self.shownPredicates + 1] = predicate
            end
            return object
        end
    end
    state.soundsWithoutCheckboxMenu = options.soundsWithoutCheckboxMenu
    state.newerSounds = options.newerSounds
    env.C_Secrets = {GetSpellCooldownSecrecy = function() return state.combat and state.secret() or 2 end,
        ShouldSpellAuraBeSecret = function(id) return state.secretAuraIDs ~= nil and state.secretAuraIDs[id] == true end}
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
            local object = {kind = "button", label = label, buttonText = buttonText, click = click, tooltip = tooltip,
                modifyPredicates = {}}
            function object:AddModifyPredicate(predicate)
                self.modifyPredicates[#self.modifyPredicates + 1] = predicate
            end
            function object:AddEvaluateStateCVar(variable)
                self.watched = self.watched or {}
                self.watched[#self.watched + 1] = variable
            end
            return object
        end
        local function initializer(category, setting, tooltip)
            local object = {setting = setting, tooltip = tooltip, modifyPredicates = {}}
            -- The row setup the toolkit's gold default mark hooks (AddDefaultTick).
            function object:InitFrame() end
            function object:SetParentInitializer(parent, predicate)
                self.parentInitializer, self.predicate = parent, predicate
            end
            function object:AddModifyPredicate(predicate)
                self.modifyPredicates[#self.modifyPredicates + 1] = predicate
            end
            -- Blizzard's per-row watch on any setting variable (Toolkit's WatchSettings).
            function object:AddEvaluateStateCVar(variable)
                self.watched = self.watched or {}
                self.watched[#self.watched + 1] = variable
            end
            function object:AddShownPredicate(predicate)
                self.shownPredicates = self.shownPredicates or {}
                self.shownPredicates[#self.shownPredicates + 1] = predicate
            end
            category.initializers[#category.initializers + 1] = object
            return object
        end
        -- The pinned MinimalSlider label enum (MakeEnum: 1-based).
        env.MinimalSliderWithSteppersMixin = {Label = {Left = 1, Right = 2, Top = 3, Min = 4, Max = 5}}
        env.Settings = {
            VarType = {Boolean = "boolean", Number = "number", String = "string"},
            RegisterVerticalLayoutCategory = function(title)
                local category = {name = title, initializers = {}}
                function category:GetID() return "id:" .. title end
                state.categories[title] = category
                local layout = {}
                function layout:AddInitializer(initializer)
                    -- DBR's own headings: the toolkit's home page has its own (2.16.0's Profile).
                    if initializer.heading and title ~= "Dyre's AddOns" then
                        state.headings[#state.headings + 1] = initializer
                    end
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
            CreateControlTextContainer = function()
                local data = {}
                return {Add = function(_, value, label) data[#data + 1] = {value = value, label = label} end,
                    GetData = function() return data end}
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
            -- A custom row (the toolkit's primer box).
            CreateElementInitializer = function(template, data)
                local object = {template = template, data = data, modifyPredicates = {}}
                function object:AddShownPredicate(predicate)
                    self.shownPredicates = self.shownPredicates or {}
                    self.shownPredicates[#self.shownPredicates + 1] = predicate
                end
                return object
            end,
            CreateSliderOptions = function(minValue, maxValue, step)
                local options = {minValue = minValue, maxValue = maxValue, step = step, formatters = {}}
                -- As the pinned CreateMinimalSliderFormatter: a function, a fixed text, or nil (the value).
                function options:SetLabelFormatter(label, value)
                    self.formatters[label] = type(value) == "function" and value
                        or (value ~= nil and function() return value end) or function(v) return v end
                end
                return options
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
            if event == "COMBO_TARGET_CHANGED" and not options.comboTargetEvent then
                error("unknown event COMBO_TARGET_CHANGED")
            end
            self.events[event] = true
        end
        function object:RegisterUnitEvent(event, unit) self.unitEvents[event] = unit end
        function object:UnregisterEvent(event) self.events[event], self.unitEvents[event] = nil, nil end
        function object:SetScript(script, callback) self.scripts[script] = callback end
        function object:HookScript(script, callback)
            local old = self.scripts[script]
            self.scripts[script] = function(...)
                if old then old(...) end
                callback(...)
            end
        end
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
        function object:SetCooldown(start, duration) self.cooldown = {start, duration} end
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
                function animation:SetStartDelay(value) self.delay = value end
                function animation:SetTarget(region) self.target = region end
                function animation:SetFlipBookRows(value) self.rows = value end
                function animation:SetFlipBookColumns(value) self.columns = value end
                function animation:SetFlipBookFrames(value) self.frames = value end
                function animation:SetFlipBookFrameWidth(value) self.frameWidth = value end
                function animation:SetFlipBookFrameHeight(value) self.frameHeight = value end
                group.animation = animation
                return animation
            end
            function group:Play() self.playing = true end
            function group:Stop() self.playing = false end
            function group:IsPlaying() return self.playing end
            group.scripts = {}
            function group:SetScript(script, callback) self.scripts[script] = callback end
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
    env.IsControlKeyDown = function() return state.ctrl == true end
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
    -- it out; options.oldToolkit offers contract 1 only. Toolkit 2.9.0 claims
    -- the Pet Taunt warning at its login (Tank.lua, not loaded here): the
    -- fixture claims it the same way. options.toolkitBefore29 leaves out
    -- Owners.lua and the claim; options.lateClaim makes the test claim it.
    if not options.noToolkit then
        -- The class Tools AddOns are Dyre's AddOns (a TOC with "## Group: DyresToolkit"), so they may claim.
        local family = {WarlockToolsForever = true, MageToolsForever = true, DyresBuffReminders = true,
            DyresCombatTools = true}
        state.toolkitNS = {InitializeMinimap = function() end,
            InFamily = function(addon) return family[addon] == true end}
        for _, path in ipairs(TOOLKIT_FILES) do
            if not (options.toolkitBefore29 and path == TOOLKIT_OWNERS)
                and not (options.toolkitBefore210 and path == TOOLKIT_PROFILES) then
                local chunk = assert(loadfile(TOOLKIT_DIR .. path))
                setfenv(chunk, env)
                chunk("DyresToolkit", state.toolkitNS)
            end
        end
        -- Macros.lua (OutOfCombat, which Toolkit 2.18.0's LayoutButtons calls),
        -- when the toolkit folder has it; the copy in tests/toolkit has not.
        local macros = io.open(TOOLKIT_DIR .. "Macros.lua", "rb")
        if macros then
            macros:close()
            local chunk = assert(loadfile(TOOLKIT_DIR .. "Macros.lua"))
            setfenv(chunk, env)
            chunk("DyresToolkit", state.toolkitNS)
        end
        -- An older toolkit had no Profile section either: its Core (2.16.0) calls
        -- Profiles.lua's AddProfileSettings at login.
        if options.toolkitBefore210 then
            state.toolkitNS.AddProfileSettings = function() end
        end
        -- The proc engine (Toolkit 2.11.0): its Procs.lua when there, else
        -- its constant; options.toolkitBefore211 has neither.
        if not options.toolkitBefore211 then
            if HAS_TOOLKIT_PROCS then
                local chunk = assert(loadfile(TOOLKIT_DIR .. TOOLKIT_PROCS))
                setfenv(chunk, env)
                chunk("DyresToolkit", state.toolkitNS)
            else
                env.DyresToolkit.PROC_KIND_PREFIX = "proc:"
            end
            -- Proc engine 2 (Toolkit 2.12.0) takes DBR's procs over (1.13.0).
            -- Only options.procEngine keeps it (with the toolkit's Auras.lua,
            -- which the engine draws with); every other test sees an engine
            -- before 2, so Proc Chimes as before.
            if options.procEngine and HAS_PROC_ENGINE then
                for _, path in ipairs(TOOLKIT_ENGINE_FILES) do
                    local chunk = assert(loadfile(TOOLKIT_DIR .. path))
                    setfenv(chunk, env)
                    chunk("DyresToolkit", state.toolkitNS)
                end
            else
                env.DyresToolkit.PROC_ENGINE_VERSION = nil
            end
        end
        state.toolkit = env.DyresToolkit
        -- A class Tools AddOn plays a proc through the proc engine: it joins
        -- the toolkit, then RegisterProcs claims "proc:<key>" at 10 (as
        -- Procs.lua does; its frames are not needed here).
        function state.claimProc(key, addon, title)
            addon = addon or "WarlockToolsForever"
            local titles = {WarlockToolsForever = "Warlock Tools Forever", MageToolsForever = "Mage Tools Forever"}
            env.DyresToolkit.RegisterAddOn({addon = addon, title = title or titles[addon]})
            return env.DyresToolkit.ClaimOwner("proc:" .. key, addon, 10)
        end
        for key, addon in pairs(options.procClaims or {}) do
            state.claimProc(key, addon)
        end
        -- The toolkit's profile (Profiles.lua, 2.10.0): Copy, Export, Import.
        state.profile = state.toolkitNS.profile
        function state.claimPetTaunt()
            return state.toolkit.ClaimOwner("warn:petTaunt", "DyresToolkit", 50)
        end
        if not options.toolkitBefore29 and not options.lateClaim then
            state.claimPetTaunt()
        end
        if options.oldToolkit then
            env.DyresToolkit.RequireContract = function(n)
                if n == 1 then return env.DyresToolkit end
            end
        end
        -- Toolkit 2.2.1 snaps to the grid by default; these tests drop frames without it.
        env.DyresToolkitDB = options.toolkitDB or {snapToGrid = false}
        -- Toolkit 2.14.0's "Welcome messages at login": options.welcome is what
        -- ShowWelcome gives; options.noShowWelcome is a toolkit before 2.14.0.
        if options.welcome ~= nil then
            env.DyresToolkit.ShowWelcome = function() return options.welcome end
        elseif options.noShowWelcome then
            env.DyresToolkit.ShowWelcome = nil
        end
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
    -- options.beforeLogin(env): a test's change to the globals before startup.
    if options.beforeLogin then options.beforeLogin(env) end
    state.emit("ADDON_LOADED", "DyresToolkit")
    state.emit("ADDON_LOADED", ADDON)
    state.emit("PLAYER_LOGIN")
    -- The combo note set, as the player would choose it.
    if options.comboSet then
        state.settings.DBR_COMBO_NOTESET:SetValue(options.comboSet)
    end

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
    -- A buff's widget (the holder the toolkit places).
    function state.widget(key) return env["DyresBuffRemindersBuff_" .. key] end
    -- The aura slot a buff's widget has (the engine shows it while the buff is up).
    function state.slotOf(key)
        local holder = state.widget(key)
        return holder and holder.slot
    end
    function state.page() return state.categories[PAGE] end
    function state.cast(id, cooldown)
        if cooldown then state.cooldowns[id] = {start = state.now, duration = cooldown} end
        state.emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", id)
    end
    -- A cast, then the cast chimes' wait (DBR.CAST_CHIME_DELAY).
    function state.castChime(id)
        state.cast(id)
        state.advance(0.75)
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
        "Commands.lua,Core.lua,Buffs.lua,Reminders.lua,AuraEngine.lua,Seals.lua,Consumables.lua,AspectBar.lua,"
            .. "ChimeSpells.lua,"
            .. "Chimes.lua,"
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
test("welcome: the banner follows Toolkit 2.14.0's switch; problems always show", function()
    local banner = "DBR: Dyre's Buff Reminders "
    for _, options in ipairs({{noShowWelcome = true}, {welcome = true}}) do
        local state = fixture(options)
        contains(state.messages[1], banner)
        equal(state.messages[2], "DBR:   Ready. Type /dbr to open the settings.")
    end
    local off = fixture({welcome = false})
    equal(#off.messages, 0, "switch off: no banner, no Ready line")
    equal(off.dbr.available, true, "DBR still starts")
    -- A problem still shows with the switch off, the banner with it for the version.
    local mixed = fixture({welcome = false, files = {"Commands.lua", "Core.lua", "Buffs.lua", "Seals.lua",
        "ChimeSpells.lua", "Chimes.lua", "ProcSpells.lua", "Procs.lua", "Options.lua"}})
    contains(mixed.messages[1], banner)
    contains(mixed.last(), "missing ClassReminders")
    local shaman = fixture({welcome = false, class = "SHAMAN"})
    for _, line in ipairs(shaman.messages) do
        equal(line:find(banner, 1, true), nil, "no banner")
    end
    -- The toolkit's own switch, when its files have it (2.14.0).
    local real = fixture({toolkitDB = {snapToGrid = false, welcome = false}})
    if type(real.toolkit.ShowWelcome) == "function" then
        equal(#real.messages, 0, "the toolkit's saved switch off: no banner")
    end
    -- No toolkit at all: the banner and the problem, as before.
    local none = fixture({noToolkit = true})
    contains(none.messages[1], banner)
    equal(none.dbr.available, false)
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
        "Seals.lua", "Consumables.lua", "AspectBar.lua", "ChimeSpells.lua", "ProcSpells.lua", "Procs.lua", "Options.lua"}})
    contains(noChimes.last(), "missing ClassChimes")
    local noProcs = fixture({files = {"Commands.lua", "Core.lua", "Buffs.lua", "Reminders.lua",
        "Seals.lua", "Consumables.lua", "AspectBar.lua", "ChimeSpells.lua", "Chimes.lua", "ProcSpells.lua", "Options.lua"}})
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
        equal(state.last(), "DBR: Use /dbr (settings: Reminders, Consumables, Chimes, Procs, Cast Chimes, Combo Point Chimes), "
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
    equal(db.buffs.arcaneIntellect.scale, 100, "the toolkit's default")
    equal(db.buffs.mageArmor.position, nil)
    equal(db.bars, nil, "no 1.1.0 bar places to carry over")
    equal(db.last.mageArmor, "Frost Armor")
    equal(db.last.arcaneIntellect, nil, "only buffs with several spells remember")
    equal(db.leadPercent, 10, "10% by default")
    equal(db.lead, nil)
    equal(state.dbr.SanitizeLead(99), 20)
    equal(state.dbr.SanitizeLead(-2), 0)
    equal(state.dbr.SanitizeLead(2.5), 10)
    local bad = fixture({db = {buffs = {arcaneIntellect = {scale = 137, opacity = "x",
        position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 10, y = 20}}, mageArmor = "bad",
        gone = {scale = 100}}}})
    equal(bad.dbr.db.buffs.arcaneIntellect.scale, 140, "stepped by 10")
    equal(bad.dbr.db.buffs.arcaneIntellect.opacity, 100)
    equal(bad.dbr.db.buffs.arcaneIntellect.position.x, 10)
    equal(bad.dbr.db.buffs.mageArmor.scale, 100)
    equal(bad.dbr.db.buffs.gone, nil, "unknown keys are dropped")
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
    for _, class in ipairs({"MAGE", "WARLOCK", "DRUID", "PRIEST", "HUNTER", "PALADIN", "WARRIOR"}) do
        equal(#state.dbr.BUFFS[class] > 0, true, class .. " has buffs")
    end
end)
test("a class without buffs loads, says so once, and shows nothing", function()
    local state = fixture({class = "ROGUE", known = {[INTELLECT] = true}})
    equal(state.dbr.available, true)
    contains(state.last(), "no buff reminders for your class yet")
    equal(state.widget("arcaneIntellect"), nil)
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

test("Mage: an icon shows while you lack a buff you know, with a red border", function()
    local state = fixture({known = {[INTELLECT] = true, [FROST_ARMOR] = true},
        db = {needed = {arcaneIntellect = false, mageArmor = false}}})
    local intellect, armor = state.icon("arcaneIntellect"), state.icon("mageArmor")
    equal(visible(intellect), true)
    equal(intellect.glow.shown, true)
    equal(intellect.glow.backdropBorder[1], 1)
    equal(intellect.glow.backdropBorder[2], 0.2, "red: missing")
    equal(intellect.texture.texture, 2000 + INTELLECT)
    equal(visible(armor), true)
    equal(state.icon("dampenMagic"), nil, "no Dampen or Amplify Magic reminder (author: situational)")
    state.buff("player", "Arcane Intellect")
    state.buff("player", "Ice Armor")
    state.update("UNIT_AURA", "player")
    equal(visible(intellect), false, "up: hidden out of combat")
    equal(state.drivers[intellect], "show", "always shown, under its aura slot, armed to recast it")
    equal(visible(armor), false, "any armor counts")
    state.units.player.buffs = {["Arcane Brilliance"] = true}
    state.update("UNIT_AURA", "player")
    equal(visible(intellect), false, "Arcane Brilliance counts")
    equal(visible(armor), true)
end)
test("Mage: unknown buffs never show, and learning one shows it", function()
    local state = fixture()
    equal(visible(state.icon("arcaneIntellect")), false)
    state.known[INTELLECT] = true
    state.update("SPELLS_CHANGED")
    equal(visible(state.icon("arcaneIntellect")), true)
end)
test("in combat a missing buff stays shown; DBR never reads auras then and changes nothing secure", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    equal(visible(intellect), true)
    equal(state.drivers[intellect], "show", "missing: shown, in and out of combat")
    state.combat = true
    state.applyDrivers()
    equal(visible(intellect), true, "still shown in combat")
    equal(intellect.attributes.spell1, "Arcane Intellect", "its click still casts")
    state.buff("player", "Arcane Intellect")
    local reads = state.auraReads
    state.update("UNIT_AURA", "player")
    state.slash("unlock")
    contains(state.last(), "after combat")
    equal(state.auraReads, reads, "no aura read in combat")
    equal(visible(intellect), true, "no secure change in combat")
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
    equal(visible(intellect), true, "unlocked after combat: a sample to drag")
    equal(intellect.attributes.type1, nil, "dragging never casts")
end)
test("a reload in combat waits for the end of combat to set up the icons", function()
    local state = fixture({known = {[INTELLECT] = true}, combat = true})
    equal(state.widget("arcaneIntellect"), nil, "no secure frames set up in combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(state.widget("arcaneIntellect").dyre ~= nil, true, "a widget")
    equal(visible(state.icon("arcaneIntellect")), true)
end)
test("Arcane Intellect counts group members who use mana", function()
    local state = fixture({known = {[INTELLECT] = true}})
    state.buff("player", "Arcane Intellect")
    state.party({{name = "Healy", class = "PRIEST"}, {name = "Stabby", class = "ROGUE"},
        {name = "Faraway", class = "DRUID", far = true}, {name = "Shocky", class = "SHAMAN"}})
    local intellect = state.icon("arcaneIntellect")
    equal(visible(intellect), true)
    equal(intellect.count.text, 2, "Healy and Shocky; not the rogue or someone out of sight")
    equal(table.concat(intellect.missing, ","), "Healy,Shocky")
    state.units.party1.buffs = {["Arcane Brilliance"] = true}
    state.units.party4.buffs = {["Arcane Intellect"] = true}
    state.update("UNIT_AURA", "party1")
    equal(visible(intellect), false)
    state.units.party1.buffs = nil
    state.settings.DBR_GROUP_ARCANEINTELLECT:SetValue(false)
    equal(visible(intellect), false, "only you when the group option is off")
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
    equal(visible(intellect), false, "a secret aura answer counts as buffed")
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
    equal(visible(intellect), false)
    equal(intellect.attributes.unit1, "player", "all have it: armed for combat, on you")
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
    equal(visible(state.icon("arcaneIntellect")), false)
    state.emit("UNIT_AURA", "nameplate3")
    state.emit("UNIT_AURA", "target")
    state.emit("UNIT_AURA", state.secret())
    equal(#state.timers, 0)
end)
test("dead, you see no reminders until you are alive", function()
    local state = fixture({known = {[INTELLECT] = true}})
    state.units.player.dead = true
    state.update("PLAYER_DEAD")
    equal(visible(state.icon("arcaneIntellect")), false)
    state.units.player.dead = nil
    state.update("PLAYER_UNGHOST")
    equal(visible(state.icon("arcaneIntellect")), true)
end)

-- Warlock -----------------------------------------------------------------------------

test("Warlock: Demon Skin counts as Demon Armor, and a click casts your best", function()
    local state = fixture({class = "WARLOCK", known = {[DEMON_SKIN] = true}})
    local armor = state.icon("demonArmor")
    equal(visible(armor), true)
    equal(armor.attributes.spell1, "Demon Skin")
    equal(state.icon("arcaneIntellect"), nil, "only your class's buffs")
    state.known[DEMON_ARMOR] = true
    state.update("SPELLS_CHANGED")
    equal(armor.attributes.spell1, "Demon Armor")
    equal(armor.texture.texture, 2000 + DEMON_ARMOR)
    state.buff("player", "Demon Skin")
    state.update("UNIT_AURA", "player")
    equal(visible(armor), false, "Demon Skin counts")
end)

-- Druid -------------------------------------------------------------------------------

test("Druid: Mark of the Wild for you and the whole group, warriors too", function()
    local state = fixture({class = "DRUID", known = {[MARK] = true, [THORNS] = true}})
    local mark, thorns = state.icon("markOfTheWild"), state.icon("thorns")
    equal(visible(mark), true)
    equal(visible(thorns), true)
    equal(mark.attributes.spell1, "Mark of the Wild")
    equal(thorns.attributes.spell1, "Thorns")
    state.buff("player", "Mark of the Wild")
    state.party({{name = "Tanky", class = "WARRIOR"}, {name = "Stabby", class = "ROGUE"}})
    equal(table.concat(mark.missing, ","), "Tanky,Stabby", "everyone counts for a buff that is not mana")
    equal(mark.attributes.unit1, "party1")
    state.buff("player", "Thorns")
    state.update("UNIT_AURA", "player")
    equal(visible(thorns), false)
    equal(thorns.count.text, "", "no group count on a self buff")
end)
local function tooltip(state, icon)
    icon.scripts.OnEnter(icon)
    return table.concat(state.tooltip, "|")
end
test("Druid: Thorns watches you solo and in a group with no tank; a click casts it on you", function()
    local state = fixture({class = "DRUID", known = {[THORNS] = true}})
    local thorns = state.icon("thorns")
    equal(visible(thorns), true)
    equal(thorns.attributes.unit1, "player")
    contains(tooltip(state, thorns), "Thorns: on you")
    state.party({{name = "Stabby", class = "ROGUE"}, {name = "Healy", class = "PRIEST", role = "HEALER"}})
    equal(thorns.attributes.unit1, "player", "no tank: you")
    equal(table.concat(thorns.missing, ","), "you", "group members without Thorns do not count")
    state.buff("player", "Thorns")
    state.update("UNIT_AURA", "player")
    equal(visible(thorns), false)
    local bare = fixture({class = "DRUID", known = {[THORNS] = true}, noRoles = true})
    bare.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    equal(bare.icon("thorns").attributes.unit1, "player", "without the role API: you")
end)
test("Druid: in a group with a tank, Thorns watches the tank and a click casts it on them", function()
    local state = fixture({class = "DRUID", known = {[THORNS] = true}, db = {needed = {thorns = false}}})
    local thorns = state.icon("thorns")
    state.buff("player", "Thorns")
    state.party({{name = "Stabby", class = "ROGUE"}, {name = "Tanky", class = "WARRIOR", role = "TANK"},
        {name = "Backup", class = "PALADIN", role = "TANK"}})
    equal(visible(thorns), true, "the tank lacks it, though you have it")
    equal(thorns.attributes.unit1, "party2", "the first tank in group order")
    equal(table.concat(thorns.missing, ","), "Tanky")
    contains(tooltip(state, thorns), "Thorns: on Tanky")
    state.units.party2.dead = true
    state.update("UNIT_AURA", "party2")
    equal(thorns.attributes.unit1, "party3", "a dead tank is skipped")
    state.units.party3.far = true
    state.update("UNIT_AURA", "party3")
    equal(thorns.attributes.unit1, nil, "no tank in reach: you, who have it")
    equal(visible(thorns), false)
    contains(tooltip(state, thorns), "Thorns: on you")
    state.units.party2.dead, state.units.party3.far = false, false
    state.buff("party2", "Thorns")
    state.update("UNIT_AURA", "party2")
    equal(visible(thorns), true, "the tank has it: ours shows it, the slot draws only yours")
    equal(thorns.glow.alpha, 0, "and no red")
    local secret = fixture({class = "DRUID", known = {[THORNS] = true}})
    secret.party({{name = "Tanky", class = "WARRIOR", role = "TANK", secretRole = true}})
    equal(secret.icon("thorns").attributes.unit1, "player", "a secret role is not read as a tank")
end)
test("Druid: Thorns up on the tank shows the tank's time left, yellow, then red at its end, also in combat", function()
    local state = fixture({class = "DRUID", known = {[THORNS] = true}, db = {needed = {thorns = false}}})
    local thorns = state.icon("thorns")
    local warn = state.widget("thorns").warn
    state.party({{name = "Tanky", class = "WARRIOR", role = "TANK", buffs = {Thorns = state.now + 601}}})
    equal(visible(thorns), true, "you lack it, the tank has it: ours, above your empty slot")
    equal(thorns.glow.alpha, 0, "no red while the tank has it")
    equal(thorns.timeLeft.shown, true, "the tank's time left")
    equal(thorns.timeLeft.cooldown[1] + thorns.timeLeft.cooldown[2], state.now + 600)
    equal(thorns.attributes.macrotext1, "/cancelform\n/use [@party1] Thorns", "a click recasts it on the tank")
    contains(tooltip(state, thorns), "Thorns: on Tanky")
    state.combat = true
    state.emit("PLAYER_REGEN_DISABLED")
    state.advance(419)
    equal(warn.alpha, 0)
    state.advance(1)
    equal(warn.alpha, 1, "3 minutes before the tank's runs out: yellow, timed in combat")
    state.units.target = {is = "party1"}
    state.cast(THORNS)
    equal(warn.alpha, 0, "recast on the tank, targeted: its time restarts")
    equal(thorns.timeLeft.cooldown[1], state.now, "and its countdown")
    state.units.target = nil
    state.advance(1620)
    equal(warn.alpha, 1)
    equal(thorns.glow.alpha, 0)
    state.advance(180)
    equal(warn.alpha, 0)
    equal(thorns.glow.alpha, 1, "run out on the tank: red, in combat")
    state.units.party1.buffs.Thorns = nil
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(visible(thorns), true, "after the fight: checked again, the tank lacks it")
    equal(thorns.glow.alpha, 1)
    equal(thorns.glow.shown, true)
end)

test("Druid: whom a Thorns click casts on is set out of combat and kept through a fight", function()
    local state = fixture({class = "DRUID", known = {[THORNS] = true}})
    local thorns = state.icon("thorns")
    local function onWhom()
        local macro = thorns.attributes.macrotext1
        return macro and macro:match("%[@(%w+)%]") or thorns.attributes.unit1
    end
    equal(onWhom(), "player", "solo: you")
    state.party({{name = "Stabby", class = "ROGUE"}, {name = "Tanky", class = "WARRIOR", role = "TANK"}})
    equal(onWhom(), "party2", "a Tank-role member: them")
    state.units.player.role = "TANK"
    state.update("PLAYER_ROLES_ASSIGNED")
    equal(onWhom(), "player", "you are the tank: you")
    state.units.player.role = nil
    state.update("PLAYER_ROLES_ASSIGNED")
    equal(onWhom(), "party2")
    state.combat = true
    state.units.party2 = nil
    state.units.party1 = {name = "Tanky", class = "WARRIOR", role = "TANK"}
    state.update("GROUP_ROSTER_UPDATE")
    equal(onWhom(), "party2", "the roster changes in combat: the click keeps its unit")
    state.units.party1.dead = true
    state.update("UNIT_AURA", "party1")
    equal(onWhom(), "party2", "nor does a death in combat change it")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(onWhom(), "player", "after combat: the tank is dead, so you")
    state.units.party1.dead = false
    state.update("UNIT_AURA", "party1")
    equal(onWhom(), "party1", "and the tank in their new slot")
end)

test("settings: each buff's tooltip says what it shows; Thorns says whom it watches and casts on", function()
    local state = fixture({class = "DRUID", known = {[THORNS] = true, [MARK] = true}})
    local thorns = state.row("DBR_BUFF_THORNS").tooltip
    equal(thorns, "Show an icon while Thorns is missing on you, or on your group's tank; click it to cast it.")
    local mark = state.row("DBR_BUFF_MARKOFTHEWILD").tooltip
    equal(mark, "Show an icon while Mark of the Wild is missing or about to run out; click it to cast it.")
    equal(mark:find("Tank", 1, true), nil, "only a tank buff names the tank")
    equal(state.row("DBR_GROUP_MARKOFTHEWILD").tooltip, "Also remind you when a party or raid member lacks Mark of the Wild.")
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
        equal(visible(thorns), false, case .. ": you have it, so nothing shows")
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
    equal(visible(thorns), false)
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
    equal(visible(mark), false, "Gift of the Wild counts")
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
    equal(visible(state.icon("fortitude")), true)
    equal(visible(state.icon("innerFire")), true)
    equal(visible(state.icon("divineSpirit")), false, "off by default")
    equal(visible(state.icon("shadowProtection")), false, "off by default")
    state.settings.DBR_BUFF_DIVINESPIRIT:SetValue(true)
    equal(visible(state.icon("divineSpirit")), true)
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
test("Hunter: no aspect shows the Aspect reminder with its click; out of combat any aspect hides it", function()
    local state = fixture({class = "HUNTER", known = {[HAWK] = true, [MONKEY] = true, [CHEETAH] = true,
        [PACK] = true, [WILD] = true, [BEAST] = true}, db = {aspectBar = {enabled = false}}})
    local aspect = state.icon("aspect")
    equal(aspect.parent, state.widget("aspect"), "its own widget")
    equal(visible(aspect), true)
    equal(aspect.attributes.type1, "macro")
    equal(aspect.attributes.macrotext1, "/use !Aspect of the Hawk", "nothing cast yet: Hawk, with \"!\" so it never toggles")
    for _, name in ipairs({"Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Wild", "Aspect of the Beast",
            "Aspect of the Cheetah", "Aspect of the Pack"}) do
        state.units.player.buffs = {[name] = true}
        state.update("UNIT_AURA", "player")
        equal(visible(aspect), false, name .. " counts as up")
    end
    state.units.player.buffs = {}
    state.update("UNIT_AURA", "player")
    equal(visible(aspect), true)
    equal(state.find("no buff reminders") == nil, true, "Hunters have a reminder now")
end)
test("Hunter: a click recasts the last combat aspect, never Cheetah or Pack", function()
    local state = fixture({class = "HUNTER", known = {[HAWK] = true, [MONKEY] = true, [CHEETAH] = true,
        [PACK] = true, [WILD] = true}, db = {aspectBar = {enabled = false}}})
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
        db = {last = {aspect = "Aspect of the Cheetah"}, aspectBar = {enabled = false}}})
    equal(saved.icon("aspect").attributes.macrotext1, "/use !Aspect of the Hawk", "a saved Cheetah is never cast")
end)
test("a reminder's picture is always the spell its click casts, as its tooltip says", function()
    local hunter = fixture({class = "HUNTER", known = {[HAWK] = true, [MONKEY] = true, [CHEETAH] = true,
        [PACK] = true}, db = {aspectBar = {enabled = false}}})
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
    local monkey = fixture({class = "HUNTER", known = {[MONKEY] = true, [CHEETAH] = true}, db = {aspectBar = {enabled = false}}})
    equal(monkey.icon("aspect").attributes.macrotext1, "/use !Aspect of the Monkey", "no Hawk yet: Monkey")
    local cheetah = fixture({class = "HUNTER", known = {[CHEETAH] = true}, db = {aspectBar = {enabled = false}}})
    equal(cheetah.icon("aspect").attributes.macrotext1, nil, "only Cheetah known: nothing to cast")
    local none = fixture({class = "HUNTER"})
    equal(none.widget("aspect").shown, false, "no aspect known: no widget")
    local off = fixture({class = "HUNTER", known = {[HAWK] = true}})
    off.settings.DBR_ASPECT_MODE:SetValue("off")
    equal(off.widget("aspect").shown, false, "switched off: no widget")
    equal(visible(off.icon("aspect")), false)
    off.clear()
    off.slash("debug")
    contains(off.find("debug aspect"), "unknownIDs=none last=nil")
end)
-- The Aspect reminder (John, 1.8.0): one widget, shown only when there is a problem.
local function hunterFixture(options)
    options = options or {}
    options.class = "HUNTER"
    options.known = options.known or {[HAWK] = true, [MONKEY] = true, [CHEETAH] = true, [PACK] = true}
    local state = fixture(options)
    return state, state.icon("aspect")
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
    contains(tooltip(state, icon), "You have ammunition in your inventory. Remember to equip your ammo.")
    state.bags[0] = {6948}
    state.emit("BAG_UPDATE_DELAYED")
    contains(tooltip(state, icon), "You do not have ammunition in your inventory. Remember to equip your ammo.")
    local crossbow, _, crossbowIcon = ammoFixture()
    crossbow.bags[1] = {ARROW}
    equip(crossbow, CROSSBOW, nil, 0)
    contains(tooltip(crossbow, crossbowIcon), "You have ammunition in your inventory. Remember to equip your ammo.", "a crossbow takes arrows")
end)
test("ammo: a tier switch (John): arrows used up, the slot empty, the next tier in the bags", function()
    local state, frame, icon = ammoFixture()
    equip(state, BOW, ARROW, 1000)
    equal(icon.count.text, "1000")
    -- All Rough Arrows used up: the ammo slot is empty (found in client), no arrows in the bags.
    state.bags[0] = {6948}
    equip(state, BOW, nil, 0)
    equal(frame.shown, true)
    equal(icon.count.text, "0")
    equal(isRed(icon), true)
    equal(icon.texture.desaturated, true)
    equal(icon.texture.texture, "Interface\\Icons\\INV_Ammo_Arrow_02", "the default arrow icon")
    contains(tooltip(state, icon), "You do not have ammunition in your inventory. Remember to equip your ammo.")
    -- Sharp Arrows bought, not yet equipped.
    state.bags[0] = {6948, 2515}
    state.bags[1] = {2515, 2515}
    state.emit("BAG_UPDATE_DELAYED")
    equal(icon.count.text, "0", "not in the ammo slot: the game does not fire them")
    equal(isRed(icon), true)
    contains(tooltip(state, icon), "You have ammunition in your inventory. Remember to equip your ammo.")
    -- A used-up item left in the slot at 0 gives the same two texts.
    equip(state, BOW, ARROW, 0)
    contains(tooltip(state, icon), "You have ammunition in your inventory. Remember to equip your ammo.")
    state.bags[0], state.bags[1] = {6948}, nil
    state.emit("BAG_UPDATE_DELAYED")
    contains(tooltip(state, icon), "You do not have ammunition in your inventory. Remember to equip your ammo.")
    -- Sharp Arrows in the ammo slot: their count.
    equip(state, BOW, 2515, 1600)
    equal(icon.count.text, "1600")
    equal(icon.texture.texture, 3003, "the new arrows' icon")
    equal(icon.texture.desaturated, false)
    equal(isRed(icon), false)
end)
test("ammo: a gun takes bullets; a Warrior with a gun counts too", function()
    local state, _, icon = ammoFixture({class = "WARRIOR"})
    state.bags[2] = {ARROW, BULLET}
    equip(state, GUN, nil, 0)
    equal(icon.texture.texture, "Interface\\Icons\\INV_Ammo_Bullet_02")
    contains(tooltip(state, icon), "You have ammunition in your inventory. Remember to equip your ammo.")
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
    local tick = warn.dyreDefault
    equal(tick ~= nil, true, "the toolkit's gold default mark (John: \"set notches on the sliders default values\")")
    equal(tick.min, state.dbr.AMMO_WARN_MIN)
    equal(tick.max, state.dbr.AMMO_WARN_MAX)
    equal(tick.default, state.dbr.DEFAULT_AMMO_WARN)
    equal(state.row("DYRE_DYRESBUFFREMINDERS_CONSUMABLES_SCALE").setting.name, "Consumables: size")
    equal(frame.dyre.widgetKey, "consumables")
    equal(select(1, state.absCenter(frame)), 500 + 150, "beside My buffs")
    equal(select(2, state.absCenter(frame)), 400 + 130)
    local db = fixture({db = {consumables = {enabled = "x", ammo = 0, ammoWarn = 237}}}).dbr.db.consumables
    equal(db.enabled, true)
    equal(db.ammo, true)
    equal(db.ammoWarn, 250, "stepped by 50")
    equal(state.dbr.SanitizeAmmoWarn(5000), 1000)
end)
local REBIRTH_1, REBIRTH_3, MAPLE, ASHWOOD = 20484, 20742, 17034, 17036
test("consumables by class: ammo only for Hunters, Warriors, and Rogues; none at all for a Priest", function()
    local priest = fixture({class = "PRIEST"})
    equal(priest.env.DyresBuffRemindersConsumables, nil, "a Priest: no Consumables bar")
    equal(priest.row("DBR_CONSUMABLES_ENABLED"), nil, "and no section")
    equal(priest.row("DYRE_DYRESBUFFREMINDERS_CONSUMABLES_SCALE"), nil, "nor its size")
    local mage = fixture()
    equal(mage.env.DyresBuffRemindersConsumables.shown, false, "a Mage without Arcane Brilliance: nothing")
    equal(mage.row("DBR_CONSUMABLES_ENABLED"), nil, "and no section until a reagent spell is known")
    mage.slash("unlock")
    equal(mage.env.DyresBuffRemindersAmmo, nil, "no ammo sample to place")
    equal(mage.env.DyresBuffRemindersConsumables.shown, false)
    local druid = fixture({class = "DRUID"})
    equal(druid.env.DyresBuffRemindersAmmo, nil, "a Druid: no ammo icon")
    equal(druid.row("DBR_CONSUMABLE_AMMO"), nil, "and no Ammo or Warn at")
    druid.slash("unlock")
    equal(druid.env.DyresBuffRemindersConsumables.shown, false, "unlocked, no Rebirth: nothing to show")
    for _, class in ipairs({"HUNTER", "WARRIOR", "ROGUE"}) do
        local state = fixture({class = class})
        equal(state.row("DBR_CONSUMABLE_AMMO") ~= nil, true, class .. ": Ammo")
        equal(state.env.DyresBuffRemindersConsumables.shown, false, class .. ": hidden without a weapon")
        state.slash("unlock")
        equal(state.env.DyresBuffRemindersConsumables.shown, true, class .. ": the sample, to place it")
    end
end)

test("Druid: the Rebirth counter counts the seed of your highest rank, red at Warn at, greyed at 0", function()
    local state = fixture({class = "DRUID", known = {[REBIRTH_1] = true, [REBIRTH_3] = true}})
    local frame, icon = state.env.DyresBuffRemindersConsumables, state.env.DyresBuffRemindersReagent_rebirth
    state.carried[MAPLE], state.carried[ASHWOOD] = 9, 5
    state.emit("BAG_UPDATE_DELAYED")
    equal(frame.shown, true)
    equal(icon.texture.texture, 5036, "Rank 3: Ashwood Seed")
    equal(icon.count.text, "5")
    equal(isRed(icon), false)
    equal(icon.glow.animation.playing, false)
    contains(tooltip(state, icon), "Ashwood Seed")
    contains(tooltip(state, icon), "5 left; warns at 2.")
    contains(tooltip(state, icon), "For Rebirth (Rank 3).")
    equal(icon.mouseClicks, false, "click-through, hover only")
    state.carried[ASHWOOD] = 2
    state.emit("BAG_UPDATE_DELAYED")
    equal(isRed(icon), true, "at Warn at (2): red")
    equal(icon.glow.animation.playing, true, "and pulsing")
    state.carried[ASHWOOD] = 0
    state.emit("BAG_UPDATE_DELAYED")
    equal(icon.texture.desaturated, true, "none left: missing")
    local row = state.row("DBR_REAGENT_WARN_REBIRTH")
    equal(row.options.minValue, 0)
    equal(row.options.maxValue, 10)
    equal(row.options.step, 1)
    equal(row.setting.default, 2)
    equal(row.parentInitializer, state.row("DBR_REAGENT_REBIRTH"))
    equal(state.row("DBR_REAGENT_REBIRTH").setting.name, "Rebirth reagent")
    state.settings.DBR_REAGENT_WARN_REBIRTH:SetValue(0)
    state.carried[ASHWOOD] = 1
    state.emit("BAG_UPDATE_DELAYED")
    equal(isRed(icon), false, "Warn at 0: only none left is red")
    state.settings.DBR_REAGENT_REBIRTH:SetValue(false)
    equal(frame.shown, false, "switched off")
    state.settings.DBR_REAGENT_REBIRTH:SetValue(true)
    state.combat = true
    state.carried[ASHWOOD] = 0
    state.emit("BAG_UPDATE_DELAYED")
    equal(icon.texture.desaturated, true, "also in combat")
    local db = fixture({class = "DRUID", db = {consumables = {reagents = {rebirth = {on = "x", warn = 99}}}}})
    equal(db.dbr.db.consumables.reagents.rebirth.warn, 10, "repaired: clamped")
    equal(db.dbr.db.consumables.reagents.rebirth.on, true)
    equal(db.dbr.db.consumables.reagents.giftOfTheWild.warn, 5)
end)

test("sizes sit in their sections: the reminder icons', then the seal timer's, at the end of Reminders", function()
    local state = fixture({class = "PALADIN", known = {[25780] = true, [21084] = true}})
    local _, leadAt = state.row("DBR_LEAD")
    local icons, iconsAt = state.row("DBR_BUFF_ICONS_SCALE")
    equal(icons.setting.name, "Reminder icons: size")
    equal(state.row("DBR_BUFF_ICONS_OPACITY").setting.name, "Reminder icons: opacity")
    equal(iconsAt > leadAt, true, "after the Reminders settings")
    local seal, sealAt = state.row("DYRE_DYRESBUFFREMINDERS_SEAL_SCALE")
    equal(seal.setting.name, "Seal timer: size")
    equal(sealAt > iconsAt, true, "then the seal timer's")
    local headings = {}
    for _, row in ipairs(state.headings) do headings[#headings + 1] = row.heading end
    equal(table.concat(headings, "|"), "Reminders|Chimes", "no Size and Opacity section")
    local _, chimesAt = state.row("DBR_CHIMES_ENABLED")
    equal(sealAt < chimesAt, true)
end)

test("the Consumables bar's Size, Opacity, and Reset size sit in the Consumables section", function()
    local state = fixture({class = "DRUID", known = {[REBIRTH_1] = true}})
    local _, warnAt = state.row("DBR_REAGENT_WARN_REBIRTH")
    local size, sizeAt = state.row("DYRE_DYRESBUFFREMINDERS_CONSUMABLES_SCALE")
    local _, opacityAt = state.row("DYRE_DYRESBUFFREMINDERS_CONSUMABLES_OPACITY")
    equal(size.setting.name, "Consumables: size")
    equal(sizeAt > warnAt, true, "under the reagent rows")
    equal(opacityAt, sizeAt + 1)
    local initializers = state.page().initializers
    equal(initializers[opacityAt + 1].heading, nil)
    equal(initializers[opacityAt + 1].label ~= nil, true, "then its Reset size")
    local headingAt
    for index, row in ipairs(initializers) do
        if row.heading == "Chimes" then headingAt = index end
    end
    equal(headingAt, opacityAt + 2, "the section's last rows, then Chimes")
    equal(size.setting.default, 100, "the buff icons' default too: both 40 pixels at 100%")
end)

test("Druid: nothing without Rebirth; learning it shows it; Gift of the Wild waits until it is known", function()
    local state = fixture({class = "DRUID"})
    local frame = state.env.DyresBuffRemindersConsumables
    equal(frame.shown, false, "no Rebirth: nothing")
    equal(state.row("DBR_REAGENT_REBIRTH"), nil, "no setting before you know it")
    state.known[REBIRTH_1] = true
    state.carried[MAPLE] = 3
    state.emit("SPELLS_CHANGED")
    equal(frame.shown, true, "learned: the Maple Seed count")
    equal(state.env.DyresBuffRemindersReagent_rebirth.count.text, "3")
    equal(state.env.DyresBuffRemindersReagent_giftOfTheWild.shown, false, "Gift of the Wild: not known yet")
    equal(frame.dyre.contentWidth, 40, "one icon wide")
    state.known[21849] = true
    state.carried[17021] = 20
    state.emit("SPELLS_CHANGED")
    local gift = state.env.DyresBuffRemindersReagent_giftOfTheWild
    equal(gift.shown, true, "known: its Wild Berries")
    equal(gift.count.text, "20")
    equal(frame.dyre.contentWidth, 90, "two icons side by side")
    local point = gift.points[#gift.points]
    equal(point[4], 50, "the second, right of the first")
    local both = fixture({class = "DRUID", known = {[REBIRTH_1] = true, [21849] = true}})
    equal(both.row("DBR_REAGENT_WARN_GIFTOFTHEWILD").options.maxValue, 40)
    equal(both.row("DBR_REAGENT_WARN_GIFTOFTHEWILD").setting.default, 5)
end)

test("Druid: /dbr debug loads a seed the client has not cached, and says when an ID is wrong", function()
    local state = fixture({class = "DRUID", known = {[REBIRTH_1] = true, [REBIRTH_3] = true}})
    state.uncached[ASHWOOD], state.uncached[17037] = true, true
    state.carried[ASHWOOD] = 3
    state.emit("BAG_UPDATE_DELAYED")
    local icon = state.env.DyresBuffRemindersReagent_rebirth
    equal(icon.count.text, "3", "the counter needs no item name")
    contains(tooltip(state, icon), "Ashwood Seed", "the tooltip falls back to the seed's name in the data")
    state.slash("debug")
    equal(state.find("debug reagent rebirth r3 spell=20742 spellName=Rebirth known=true item=17036 "
        .. "itemName=(not cached, loading) count=3") ~= nil, true)
    equal(table.concat(state.loadRequests, ","), "17036,17037", "the client is asked for both")
    state.uncached[ASHWOOD] = nil
    state.emit("ITEM_DATA_LOAD_RESULT", ASHWOOD, true)
    equal(state.find("debug reagent item=17036 itemName=Ashwood Seed (loaded)") ~= nil, true)
    state.emit("ITEM_DATA_LOAD_RESULT", 17037, false)
    equal(state.find("debug reagent item=17037 not found: the ID is wrong on this client") ~= nil, true)
    local lines = #state.messages
    state.emit("ITEM_DATA_LOAD_RESULT", 17037, true)
    state.emit("ITEM_DATA_LOAD_RESULT", 9999, true)
    equal(#state.messages, lines, "only the items it asked for, once each")
end)

test("Druid: /dbr debug prints each Rebirth rank's spell and seed by name, to confirm the IDs", function()
    local state = fixture({class = "DRUID", known = {[REBIRTH_1] = true}})
    state.carried[MAPLE] = 4
    state.emit("BAG_UPDATE_DELAYED")
    state.slash("debug")
    equal(state.find("debug reagent rebirth r1 spell=20484 spellName=Rebirth known=true item=17034 "
        .. "itemName=Maple Seed count=4") ~= nil, true)
    equal(state.find("debug reagent rebirth r5 spell=20748 spellName=Rebirth known=false item=17038 "
        .. "itemName=Ironwood Seed count=0") ~= nil, true)
    equal(state.find("debug reagent rebirth on=true rank=1 count=4 countAPI=ok warnAt=2 state=ok") ~= nil, true)
    equal(state.find("debug reagent giftOfTheWild r1 spell=21849") ~= nil, true)
    equal(state.find("debug reagent giftOfTheWild on=true rank=not known warnAt=5") ~= nil, true,
        "an unknown spell: not known")
    local priest = fixture({class = "PRIEST"})
    priest.slash("debug")
    equal(priest.find("debug consumables none for this class") ~= nil, true)
end)

local DAMPEN, AMPLIFY = 604, 1008
test("Mage: Dampen or Amplify Magic, off at first; either counts; a click recasts the last one", function()
    local state = fixture({known = {[DAMPEN] = true, [AMPLIFY] = true}})
    local holder = state.widget("dampen")
    equal(state.dbr.db.spells.dampen, false, "off at first (author)")
    equal(holder.shown, false)
    local switch = state.row("DBR_BUFF_DAMPEN")
    equal(switch.setting.name, "Dampen or Amplify Magic")
    state.settings.DBR_BUFF_DAMPEN:SetValue(true)
    local icon = state.icon("dampen")
    equal(visible(icon), true, "missing: the reminder")
    equal(icon.glow.backdropBorder[2], 0.2, "red, as every buff")
    equal(icon.attributes.spell1, "Dampen Magic", "else Dampen")
    state.cast(AMPLIFY)
    state.buff("player", "Amplify Magic", state.now + 600)
    state.update("UNIT_AURA", "player")
    equal(visible(icon), false, "Amplify counts: up, under its slot")
    state.units.player.buffs["Amplify Magic"] = nil
    state.update("UNIT_AURA", "player")
    equal(icon.attributes.spell1, "Amplify Magic", "the one you cast last")
end)

test("Mage and Warlock reagents: Arcane Powder, Infernal Stone, and Demonic Figurine, once their spell is known", function()
    local mage = fixture({known = {[BRILLIANCE] = true}})
    mage.carried[17020] = 6
    mage.emit("BAG_UPDATE_DELAYED")
    local powder = mage.env.DyresBuffRemindersReagent_arcanePowder
    equal(mage.env.DyresBuffRemindersConsumables.shown, true)
    equal(powder.count.text, "6")
    equal(isRed(powder), false)
    mage.carried[17020] = 5
    mage.emit("BAG_UPDATE_DELAYED")
    equal(isRed(powder), true, "Arcane Powder: red at 5")
    equal(mage.row("DBR_REAGENT_WARN_ARCANEPOWDER").setting.default, 5)
    equal(mage.row("DBR_REAGENT_WARN_ARCANEPOWDER").options.maxValue, 40)
    equal(mage.row("DBR_REAGENT_ARCANEPOWDER").setting.name, "Arcane Brilliance reagent")
    local lock = fixture({class = "WARLOCK", known = {[1122] = true}})
    lock.carried[5565] = 1
    lock.emit("BAG_UPDATE_DELAYED")
    local stone = lock.env.DyresBuffRemindersReagent_infernalStone
    equal(stone.shown, true)
    equal(isRed(stone), true, "Infernal Stone: red at 1")
    equal(lock.env.DyresBuffRemindersReagent_demonicFigurine.shown, false, "no Ritual of Doom: no figurine")
    equal(lock.row("DBR_REAGENT_WARN_INFERNALSTONE").setting.default, 1)
    equal(lock.row("DBR_REAGENT_WARN_INFERNALSTONE").options.maxValue, 10)
    equal(lock.row("DBR_REAGENT_DEMONICFIGURINE"), nil, "its setting waits until the spell is known")
    lock.known[18540] = true
    lock.carried[16583] = 3
    lock.emit("SPELLS_CHANGED")
    equal(lock.env.DyresBuffRemindersReagent_demonicFigurine.count.text, "3")
    equal(lock.env.DyresBuffRemindersConsumables.dyre.contentWidth, 90, "both, side by side")
    lock.slash("debug")
    equal(lock.find("debug reagent infernalStone r1 spell=1122 spellName=Inferno known=true item=5565 "
        .. "itemName=Infernal Stone count=1") ~= nil, true)
    equal(lock.find("debug reagent demonicFigurine r1 spell=18540 spellName=Ritual of Doom known=true "
        .. "item=16583 itemName=Demonic Figurine count=3") ~= nil, true)
    local none = fixture({class = "WARLOCK"})
    equal(none.env.DyresBuffRemindersConsumables.shown, false, "neither spell: nothing")
    equal(none.row("DBR_CONSUMABLES_ENABLED"), nil, "and no section")
end)

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for key, item in pairs(a) do if not same(item, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
test("first run: a Mage's reminder settings come from Mage Tools Forever, once, read only", function()
    local mtf = {reminders = {enabled = true, group = false,
        spells = {intellect = false, armor = true, dampen = true}, last = {armor = "Ice Armor", dampen = "Amplify Magic"},
        icons = {armor = {position = {point = "CENTER", relativePoint = "CENTER", x = 1, y = 2}}}}}
    local before = copy(mtf)
    local state = fixture({known = {[INTELLECT] = true, [FROST_ARMOR] = true, [ICE_ARMOR] = true},
        globals = {MageToolsForeverDB = mtf}})
    local db = state.dbr.db
    equal(db.spells.arcaneIntellect, false, "intellect")
    equal(db.groups.arcaneIntellect, false, "group")
    equal(db.spells.mageArmor, true)
    equal(db.spells.dampen, true, "dampen, off in DBR at first")
    equal(db.last.mageArmor, "Ice Armor", "the last armor")
    equal(db.last.dampen, "Amplify Magic")
    equal(state.icon("mageArmor").attributes.spell1, "Ice Armor", "a click recasts the armor cast last in MTF")
    equal(db.buffs.mageArmor.position, nil, "places start fresh (author)")
    equal(state.count("Copied your buff reminder settings from Mage Tools Forever."), 1)
    equal(same(mtf, before), true, "MTF's table is never written")
    local again = fixture({globals = {MageToolsForeverDB = mtf}, db = {spells = {arcaneIntellect = true}}})
    equal(again.dbr.db.spells.arcaneIntellect, true, "an existing DBR setting wins: no import")
    equal(again.dbr.db.spells.dampen, false)
    equal(again.count("Copied your buff reminder settings"), 0)
    local bad = fixture({globals = {MageToolsForeverDB = {reminders = {enabled = "x", spells = {armor = 1},
        last = {armor = 7}}}}})
    equal(bad.dbr.db.enabled, true, "only true or false is taken")
    equal(bad.dbr.db.spells.mageArmor, true)
    equal(bad.dbr.db.last.mageArmor, nil)
    local none = fixture()
    equal(none.count("Copied your buff reminder settings"), 0, "nothing to import: no line")
end)

test("first run: a Warlock's from Warlock Tools Forever; a Mage never reads WTF's", function()
    local wtf = {reminders = {enabled = false, spells = {armor = false}, last = {armor = "Demon Skin"}}}
    local state = fixture({class = "WARLOCK", known = {[DEMON_SKIN] = true, [DEMON_ARMOR] = true},
        globals = {WarlockToolsForeverDB = wtf}})
    local db = state.dbr.db
    equal(db.enabled, false, "WTF's reminders were off: DBR's too")
    equal(db.spells.demonArmor, false, "its armor switch")
    equal(db.last.demonArmor, "Demon Skin")
    equal(state.count("Copied your buff reminder settings from Warlock Tools Forever."), 1)
    db.enabled, db.spells.demonArmor = true, true
    state.update("PLAYER_ENTERING_WORLD")
    equal(state.icon("demonArmor").attributes.spell1, "Demon Skin", "a click recasts the armor cast last, as WTF")
    local mage = fixture({globals = {WarlockToolsForeverDB = wtf}})
    equal(mage.dbr.db.enabled, true, "another class's AddOn is not read")
end)

test("locked, the Consumables bar and the seal timer take a Ctrl-drag; never in combat", function()
    local state = fixture({class = "DRUID", known = {[REBIRTH_1] = true}})
    state.carried[MAPLE] = 3
    state.emit("BAG_UPDATE_DELAYED")
    local frame, icon = state.env.DyresBuffRemindersConsumables, state.env.DyresBuffRemindersReagent_rebirth
    equal(frame.mouse, false, "locked: click-through")
    equal(icon.mouseClicks, false, "the icon takes hover only")
    state.ctrl = true
    state.emit("MODIFIER_STATE_CHANGED")
    equal(frame.mouse, true, "Ctrl held: the bar takes the mouse")
    frame.scripts.OnDragStart(frame)
    state.ctrl = false
    state.emit("MODIFIER_STATE_CHANGED")
    equal(frame.mouse, true, "Ctrl let go mid-drag: kept until the drop")
    frame.scripts.OnDragStop(frame)
    equal(frame.mouse, false, "dropped with Ctrl up: click-through again")
    state.ctrl = true
    state.emit("MODIFIER_STATE_CHANGED")
    equal(frame.mouse, true)
    state.emit("PLAYER_REGEN_DISABLED")
    equal(frame.mouse, false, "combat starts: off, Ctrl or not")
    state.combat = true
    state.emit("MODIFIER_STATE_CHANGED")
    equal(frame.mouse, false, "nothing changes in combat")
    state.combat = false
    state.ctrl = false
    state.slash("unlock")
    equal(frame.mouse, true, "unlocked: the toolkit's")
    local paladin = fixture({class = "PALADIN", known = {[21084] = true}})
    local display = paladin.env.DyresBuffRemindersSeal
    equal(display.mouse, false)
    paladin.ctrl = true
    paladin.emit("MODIFIER_STATE_CHANGED")
    equal(display.mouse, true, "the seal timer too")
    local button = paladin.env.DyresBuffRemindersSealButton
    equal(type(button.scripts.OnDragStart), "function", "its button is a drag handle")
end)

local CALL_PET, REVIVE_PET, SUMMON_IMP, SUMMON_VOIDWALKER = 883, 982, 688, 697
local PET_DRIVER = "[mounted] hide; [nopet] show; [@pet,dead] show; hide"
test("Hunter: a Pet reminder the game shows with no pet or a dead one, also in combat; a click calls or revives", function()
    local state = fixture({class = "HUNTER", known = {[CALL_PET] = true, [REVIVE_PET] = true}})
    local icon = state.icon("hunterPet")
    equal(state.dbr.db.spells.hunterPet, true, "on at first")
    equal(state.drivers[icon], PET_DRIVER, "the game decides: no pet or a dead one, not mounted")
    equal(icon.glow.backdropBorder[2], 0.2, "red")
    equal(icon.attributes.type1, "macro")
    equal(icon.attributes.macrotext1, "/use [@pet,dead] Revive Pet; Call Pet")
    equal(icon.attributes.type2, "spell")
    equal(icon.attributes.spell2, "Revive Pet", "a right-click always revives")
    equal(icon.texture.texture, 2000 + CALL_PET)
    contains(tooltip(state, icon), "Click: Call Pet (Revive Pet if it is dead")
    equal(state.widget("hunterPet").slot, nil, "no aura slot for a pet")
    equal(icon.shown, true, "no pet: shown")
    state.combat = true
    state.units.pet = {}
    state.applyDrivers()
    state.emit("UNIT_PET", "player")
    equal(icon.shown, false, "the pet came, in combat: the game hides it")
    state.units.pet.dead = true
    state.applyDrivers()
    equal(icon.shown, true, "it died mid-fight: shown")
    state.mounted = true
    state.applyDrivers()
    equal(icon.shown, false, "mounted: hidden")
    state.mounted = nil
    state.units.pet = nil
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    local young = fixture({class = "HUNTER"})
    equal(young.widget("hunterPet").shown, false, "no Call Pet yet (before 10): no reminder")
    local early = fixture({class = "HUNTER", known = {[CALL_PET] = true}})
    equal(early.icon("hunterPet").attributes.macrotext1, "/use Call Pet", "no Revive Pet yet")
    equal(early.icon("hunterPet").attributes.type2, nil)
    early.units.player.dead = true
    early.update("PLAYER_DEAD")
    equal(early.drivers[early.icon("hunterPet")], "hide", "dead: no reminder")
    early.units.player.dead = false
    early.update("PLAYER_ALIVE")
    early.taxi = true
    early.update("PLAYER_CONTROL_LOST")
    equal(early.drivers[early.icon("hunterPet")], "hide", "on a taxi: no reminder")
    early.taxi = false
    early.settings.DBR_BUFF_HUNTERPET:SetValue(false)
    equal(early.widget("hunterPet").shown, false, "switched off")
end)

test("Warlock: the Pet reminder summons your last demon, else the Imp; none after a Demonic Sacrifice", function()
    local state = fixture({class = "WARLOCK", known = {[SUMMON_IMP] = true, [SUMMON_VOIDWALKER] = true}})
    local icon = state.icon("warlockPet")
    equal(state.drivers[icon], PET_DRIVER)
    equal(icon.attributes.type1, "spell")
    equal(icon.attributes.spell1, "Summon Imp", "at first: the Imp")
    equal(icon.attributes.unit1, nil)
    contains(tooltip(state, icon), "Click: Summon Imp.")
    state.combat = true
    state.cast(SUMMON_VOIDWALKER)
    equal(icon.attributes.spell1, "Summon Imp", "in combat the click cannot change")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    state.wait(1)
    equal(icon.attributes.spell1, "Summon Voidwalker", "after combat: the last demon you summoned")
    equal(state.dbr.db.last.warlockPet, "Summon Voidwalker", "remembered per character")
    state.buff("player", "Fel Stamina", state.now + 1800)
    state.update("UNIT_AURA", "player")
    equal(state.drivers[icon], "hide", "Demonic Sacrifice (Fel Stamina): no pet wanted")
    state.units.player.buffs["Fel Stamina"] = nil
    state.update("UNIT_AURA", "player")
    equal(state.drivers[icon], PET_DRIVER, "the sacrifice ran out: the reminder is back")
    state.buff("player", "Touch of Shadow", "secret")
    state.units.player.secretAuras = true
    state.update("UNIT_AURA", "player")
    equal(state.drivers[icon], "hide", "a secret answer: DBR cannot tell, so no warning")
    state.units.player.secretAuras = nil
    local none = fixture({class = "WARLOCK"})
    equal(none.widget("warlockPet").shown, false, "no Summon spell yet: no reminder")
    none.slash("debug")
    contains(none.find("debug warlockPet"), "pet=")
end)

test("Mage on a client without the aura container (Era): every armor and Arcane Intellect rank counts as up", function()
    for _, case in ipairs({
        {known = 168, buff = "Frost Armor", key = "mageArmor", rank = "Frost Armor rank 1"},
        {known = 7320, buff = "Ice Armor", key = "mageArmor", rank = "Ice Armor, a middle rank"},
        {known = 10220, buff = "Ice Armor", key = "mageArmor", rank = "Ice Armor, the highest rank"},
        {known = 22783, buff = "Mage Armor", key = "mageArmor", rank = "Mage Armor, the highest rank"},
        {known = 1459, buff = "Arcane Intellect", key = "arcaneIntellect", rank = "Arcane Intellect rank 1"},
        {known = 10157, buff = "Arcane Intellect", key = "arcaneIntellect", rank = "Arcane Intellect rank 5"},
        {known = 1459, buff = "Arcane Brilliance", key = "arcaneIntellect", rank = "Arcane Brilliance counts"},
    }) do
        local state = fixture({noAuraContainer = true, known = {[case.known] = true, [1459] = true}})
        local icon = state.icon(case.key)
        equal(visible(icon), true, case.rank .. ": missing at first")
        state.buff("player", case.buff, state.now + 1500)
        state.update("UNIT_AURA", "player")
        equal(visible(icon), false, case.rank .. ": up")
        equal(state.drivers[icon], "hide", case.rank .. ": hidden while up (no slot to draw it)")
    end
end)

test("the armor up on you is what a click recasts, also one cast before DBR saw it; else your best", function()
    local state = fixture({known = {[FROST_ARMOR] = true, [6117] = true}})
    local icon = state.icon("mageArmor")
    equal(icon.attributes.spell1, "Mage Armor", "nothing remembered: the best known")
    state.buff("player", "Frost Armor", state.now + 1500)
    state.update("UNIT_AURA", "player")
    equal(visible(icon), false, "Frost Armor counts as up")
    equal(state.dbr.db.last.mageArmor, "Frost Armor", "seen up: remembered, with no cast")
    state.units.player.buffs["Frost Armor"] = nil
    state.update("UNIT_AURA", "player")
    equal(icon.attributes.spell1, "Frost Armor", "it dropped: a click recasts Frost Armor, not Mage Armor")
    equal(icon.texture.texture, 2000 + FROST_ARMOR, "and the icon shows it")
    local tbc = fixture({known = {[30482] = true}})
    tbc.buff("player", "Molten Armor", tbc.now + 1500)
    tbc.update("UNIT_AURA", "player")
    equal(visible(tbc.icon("mageArmor")), false, "Molten Armor (TBC) counts")
    local lock = fixture({class = "WARLOCK", known = {[DEMON_SKIN] = true, [DEMON_ARMOR] = true}})
    lock.buff("player", "Demon Skin", lock.now + 1500)
    lock.update("UNIT_AURA", "player")
    lock.units.player.buffs["Demon Skin"] = nil
    lock.update("UNIT_AURA", "player")
    equal(lock.icon("demonArmor").attributes.spell1, "Demon Skin", "a Warlock's the same: the one up last")
end)

-- On Classic Era: what the player sees of a reminder, its slot drawn by AuraEngine.lua from aura reads.
local function eraSlot(state, key)
    local layer = state.widget(key).slot
    for _, child in ipairs(layer.children) do
        if child.slots then return child.slots[1].button end
    end
end
local function eraSeen(state, key)
    local icon, slot = state.icon(key), eraSlot(state, key)
    if not icon.shown or icon.alpha == 0 then return false end
    return not slot.shown or icon:GetFrameLevel() > state.widget(key).slot:GetFrameLevel()
end
test("Classic Era: Battle Shout cast in combat drops its reminder; it comes back as it runs out, and a click casts it", function()
    local state = fixture({class = "WARRIOR", known = {[6673] = true}, noAuraContainer = true,
        classicAuras = true})
    equal(state.widget("battleShout").slot ~= nil, true, "a slot, from AuraEngine.lua")
    equal(eraSeen(state, "battleShout"), true, "missing out of combat: the reminder")
    state.combat = true
    state.applyDrivers()
    state.emit("PLAYER_REGEN_DISABLED")
    equal(eraSeen(state, "battleShout"), true, "missing at combat start: shown")
    equal(state.icon("battleShout").attributes.spell1, "Battle Shout", "a click casts it")
    state.buff("player", "Battle Shout", {spellId = 6673, expires = state.now + 120, duration = 120})
    state.cast(6673)
    state.emit("UNIT_AURA", "player")
    equal(state.icon("battleShout").alpha, 0, "cast in combat: the reminder hides at once (Hidden, the default)")
    equal(eraSlot(state, "battleShout").shown, true, "the buff's slot, read in combat")
    state.advance(60)
    equal(state.icon("battleShout").alpha, 1, "60 s left: back, as on Forever")
    state.units.player.buffs["Battle Shout"] = nil
    state.advance(60)
    state.emit("UNIT_AURA", "player")
    equal(eraSlot(state, "battleShout").shown, false, "run out: the slot goes")
    equal(eraSeen(state, "battleShout"), true, "the red reminder shows")
    equal(state.icon("battleShout").attributes.spell1, "Battle Shout", "and a click casts it")
end)

test("Classic Era: a long buff dropped in combat shows its red reminder at once; a recast covers it again", function()
    local state = fixture({known = {[INTELLECT] = true}, noAuraContainer = true, classicAuras = true,
        db = {needed = {arcaneIntellect = false}}})
    state.buff("player", "Arcane Intellect", {spellId = 1459, expires = state.now + 1800, duration = 1800})
    state.update("UNIT_AURA", "player")
    equal(eraSeen(state, "arcaneIntellect"), false, "up: the slot draws it over the reminder")
    equal(state.icon("arcaneIntellect").glow.shown, true, "the red reminder waits under it")
    state.combat = true
    state.applyDrivers()
    state.emit("PLAYER_REGEN_DISABLED")
    state.units.player.buffs["Arcane Intellect"] = nil
    state.emit("UNIT_AURA", "player")
    equal(eraSeen(state, "arcaneIntellect"), true, "dispelled in combat: the reminder at once")
    equal(state.icon("arcaneIntellect").attributes.spell1, "Arcane Intellect", "a click recasts it")
    equal(state.icon("arcaneIntellect").attributes.unit1, "player", "on you")
    state.buff("player", "Arcane Intellect", {spellId = 1460, expires = state.now + 1800, duration = 1800})
    state.emit("UNIT_AURA", "player")
    equal(eraSeen(state, "arcaneIntellect"), false, "recast (rank 2): covered again")
    local forever = fixture({known = {[INTELLECT] = true}})
    equal(forever.widget("arcaneIntellect").slot.children[1].template, "CustomAuraContainerTemplate",
        "Forever keeps the engine's container")
end)

test("on a flight path no buff reminders show; after landing they come back; unlocked, samples stay", function()
    local state = fixture({known = {[INTELLECT] = true, [FROST_ARMOR] = true}})
    local intellect, armor = state.icon("arcaneIntellect"), state.icon("mageArmor")
    equal(visible(intellect), true)
    state.taxi = true
    state.update("PLAYER_CONTROL_LOST")
    equal(visible(intellect), false, "on a taxi: nothing you can act on")
    equal(visible(armor), false)
    equal(intellect.attributes.type1, nil, "no click either")
    state.slash("unlock")
    equal(visible(intellect), true, "unlocked: samples to place, also on a taxi")
    equal(visible(armor), true)
    state.slash("lock")
    equal(visible(intellect), false)
    state.taxi = false
    state.update("PLAYER_CONTROL_GAINED")
    equal(visible(intellect), true, "landed: the missing ones are back")
    equal(intellect.attributes.type1, "spell")
    local hunter = fixture({class = "HUNTER", known = {[HAWK] = true, [CHEETAH] = true}})
    hunter.equipped[18], hunter.equipped[0], hunter.ammoCount = BOW, ARROW, 500
    hunter.emit("PLAYER_EQUIPMENT_CHANGED")
    hunter.taxi = true
    hunter.update("PLAYER_CONTROL_LOST")
    equal(visible(hunter.icon("aspect")), false, "no Aspect reminder in flight")
    equal(hunter.env.DyresBuffRemindersConsumables.shown, true, "the ammo count stays: it is information")
end)
-- Warrior -----------------------------------------------------------------------------
local BATTLE_SHOUT = 6673
test("Warrior: Battle Shout reminds you in Group buffs, and a click casts it", function()
    local state = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true}})
    local shout = state.icon("battleShout")
    equal(shout.parent, state.widget("battleShout"), "its own widget")
    equal(visible(shout), true)
    equal(shout.attributes.spell1, "Battle Shout")
    equal(shout.attributes.unit1, "player")
    equal(state.find("no buff reminders") == nil, true, "Warriors have a reminder now")
    state.buff("player", "Battle Shout")
    state.update("UNIT_AURA", "player")
    equal(visible(shout), false)
    local unknown = fixture({class = "WARRIOR"})
    equal(unknown.widget("battleShout").shown, false, "not known: no widget")
end)
test("Warrior: Battle Shout has its own lead time, 60 seconds at first; other buffs keep the shared one", function()
    local state = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true}})
    local shout = state.icon("battleShout")
    -- update() lets one second pass, so 61 seconds are left after it.
    state.buff("player", "Battle Shout", state.now + 62)
    state.update("UNIT_AURA", "player")
    equal(visible(shout), false, "61 seconds left: not yet")
    local reads = state.auraReads
    state.wait(1)
    equal(visible(shout), true, "60 seconds left: shown, from the expiry timer")
    equal(state.auraReads > reads, true, "the timer refreshed it")
    shout.scripts.OnEnter(shout)
    equal(state.tooltip[2], "Running out: you")
    local row = state.row("DBR_LEAD_BATTLESHOUT")
    equal(row.setting.name, "Remind before it runs out (sec)")
    equal(row.parentInitializer, state.row("DBR_BUFF_BATTLESHOUT"), "under the Battle Shout switch")
    equal(row.options.minValue, 5)
    equal(row.options.maxValue, 120)
    equal(row.options.step, 5)
    equal(row.setting.default, 60)
    state.settings.DBR_LEAD_BATTLESHOUT:SetValue(30)
    equal(visible(shout), false, "30 seconds: not yet at 60 left")
    state.settings.DBR_LEAD_BATTLESHOUT:SetValue(33)
    equal(state.dbr.db.leads.battleShout, 35, "stepped by 5")
    equal(state.dbr.db.leadPercent, 10, "the shared setting is unchanged")
    local mage = fixture({known = {[INTELLECT] = true}})
    mage.buff("player", "Arcane Intellect", mage.now + 300)
    mage.update("UNIT_AURA", "player")
    equal(visible(mage.icon("arcaneIntellect")), false, "other buffs: the shared 10% (3 minutes of 30)")
    equal(mage.row("DBR_LEAD_ARCANEINTELLECT"), nil, "no own setting")
    equal(state.row("DBR_LEAD"), nil, "a Warrior: only Battle Shout's own slider, no shared one")
    equal(mage.row("DBR_LEAD") ~= nil, true, "a Mage: the shared one")
    local db = fixture({class = "WARRIOR", db = {leads = {battleShout = 999, gone = 3}}}).dbr.db
    equal(db.leads.battleShout, 120, "repaired: clamped")
    equal(db.leads.gone, nil, "only buffs with their own lead")
    equal(fixture({class = "WARRIOR", db = {leads = "bad"}}).dbr.db.leads.battleShout, 60, "repaired: default")
end)
test("a buff running out shows its time left, unlike a missing one; after combat it is back with it", function()
    local state = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true}})
    local shout = state.icon("battleShout")
    equal(visible(shout), true, "missing")
    equal(shout.timeLeft.shown, false, "missing: no countdown")
    state.buff("player", "Battle Shout", state.now + 31)
    state.update("UNIT_AURA", "player")
    equal(visible(shout), true, "30 seconds left, within the 60 s warning")
    equal(shout.timeLeft.shown, true, "running out: a countdown, so it does not look gone")
    equal(shout.timeLeft.hideNumbers, false, "with numbers")
    equal(shout.timeLeft.cooldown[1] + shout.timeLeft.cooldown[2], state.now + 30, "to when it runs out")
    equal(shout.timeLeft.cooldown[2], 1800, "over its full duration")
    state.combat = true
    state.applyDrivers()
    equal(visible(shout), true, "combat: still shown, still recastable")
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
    equal(visible(shout), true, "still running out after combat")
    equal(shout.timeLeft.shown, true, "with its countdown")
    state.buff("player", "Battle Shout", state.now + 120)
    state.update("UNIT_AURA", "player")
    equal(visible(shout), false, "recast: gone")
    equal(shout.timeLeft.shown, false)
    local mage = fixture({known = {[INTELLECT] = true}})
    mage.buff("player", "Arcane Intellect", mage.now + 4)
    mage.party({{name = "Healy", class = "PRIEST"}})
    equal(mage.icon("arcaneIntellect").timeLeft.shown, false, "someone lacks it: no countdown, it is missing")
end)
test("Warrior: Battle Shout shows only when needed: missing or within its 60 s, in and out of combat", function()
    local state = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true}})
    local shout, slot = state.icon("battleShout"), state.slotOf("battleShout")
    equal(slot.alpha, 0, "its slot is transparent out of combat: no countdown while up")
    -- update() lets one second pass: 90 seconds are left after it.
    state.buff("player", "Battle Shout", state.now + 91)
    state.update("UNIT_AURA", "player")
    equal(shout.shown, false, "out of combat, up and outside the window: hidden")
    state.combat = true
    state.applyDrivers()
    state.emit("PLAYER_REGEN_DISABLED")
    equal(shout.shown, true, "in combat under its slot...")
    equal(shout.alpha, 0, "...but hidden by default (John, 2026-11-18): 90 s left, outside the 60 s window")
    equal(slot.alpha, 0)
    state.advance(29)
    equal(shout.alpha, 0, "61 s left: still outside")
    state.advance(1)
    equal(shout.alpha, 1, "60 s left: the window opens, from DBR's own timer")
    equal(slot.alpha, 1, "the game's icon with its time left, and ours under it")
    state.advance(50)
    state.cast(BATTLE_SHOUT)
    equal(shout.alpha, 0, "recast in combat: its full length again (the last read's: 1800 here)")
    state.advance(1739)
    equal(shout.alpha, 0)
    state.advance(1)
    equal(shout.alpha, 1, "60 s before the recast's end")
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
    equal(shout.alpha, 1, "after combat: solid; the out-of-combat rules decide")
    equal(slot.alpha, 0, "and the slot transparent again")
    local missing = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true}})
    equal(visible(missing.icon("battleShout")), true, "missing: the reminder")
    missing.combat = true
    missing.applyDrivers()
    missing.emit("PLAYER_REGEN_DISABLED")
    equal(missing.icon("battleShout").alpha, 1, "missing at combat start: shown")
    missing.cast(BATTLE_SHOUT)
    equal(missing.icon("battleShout").alpha, 0, "cast in combat with no earlier read: Classic's 2 minutes")
    missing.advance(60)
    equal(missing.icon("battleShout").alpha, 1, "60 s left of 120")
    local mage = fixture({known = {[INTELLECT] = true}, db = {needed = {arcaneIntellect = false}}})
    mage.buff("player", "Arcane Intellect", mage.now + 3000)
    mage.update("UNIT_AURA", "player")
    equal(mage.slotOf("arcaneIntellect").alpha, nil, "Show only when needed off: the slot never transparent")
    equal(mage.icon("arcaneIntellect").shown, true)
end)
-- Show only in combat (John, 2026-11-26).
local function rowIndex(state, variable)
    for index, row in ipairs(state.page().initializers) do
        if row.setting and row.setting.variable == variable then return index end
    end
end
test("Warrior: Show only in combat: off by default, under Battle Shout, just beneath Show only when needed", function()
    local state = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true}})
    equal(state.dbr.db.combatOnly.battleShout, false, "off by default")
    local row = state.row("DBR_COMBATONLY_BATTLESHOUT")
    equal(row.setting.name, "Show only in combat")
    equal(row.setting.default, false)
    equal(row.parentInitializer, state.row("DBR_BUFF_BATTLESHOUT"), "under the Battle Shout switch")
    equal(rowIndex(state, "DBR_COMBATONLY_BATTLESHOUT"), rowIndex(state, "DBR_NEEDED_BATTLESHOUT") + 1,
        "the row right after Show only when needed")
    local mage = fixture({known = {[INTELLECT] = true}})
    equal(mage.row("DBR_COMBATONLY_ARCANEINTELLECT"), nil, "a long buff has none")
    equal(mage.dbr.db.combatOnly.arcaneIntellect, nil)
    local saved = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true}, db = {combatOnly = {battleShout = "yes"}}})
    equal(saved.dbr.db.combatOnly.battleShout, false, "a damaged value: repaired to off")
end)
test("Warrior: Show only in combat, on: missing shows only in combat", function()
    local state = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true}})
    local shout = state.icon("battleShout")
    equal(visible(shout), true, "off: missing shows out of combat")
    state.settings.DBR_COMBATONLY_BATTLESHOUT:SetValue(true)
    equal(state.dbr.db.combatOnly.battleShout, true)
    state.applyDrivers()
    equal(shout.shown, false, "on: missing, out of combat: hidden")
    enterCombat(state)
    equal(visible(shout), true, "in combat: the game shows it")
    equal(shout.alpha, 1, "in full")
    equal(shout.border ~= nil and shout.border[1] == 1 and shout.border[2] == 0.2, true, "red: missing")
    leaveCombat(state)
    equal(shout.shown, false, "after combat: hidden again")
    -- Unlocked: every icon shows, to move it.
    state.dbr.db.locked = false
    state.dbr.RefreshReminders()
    state.applyDrivers()
    equal(shout.shown, true, "unlocked: shown out of combat")
end)
test("Warrior: Show only in combat, on: running out, its slot and border wait for combat", function()
    local state = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true},
        db = {combatOnly = {battleShout = true}, needed = {battleShout = false}}})
    local shout, slot = state.icon("battleShout"), state.slotOf("battleShout")
    local warn = state.widget("battleShout").warn
    -- update() lets one second pass: 30 s left, inside the 60 s lead.
    state.buff("player", "Battle Shout", state.now + 31)
    state.update("UNIT_AURA", "player")
    state.applyDrivers()
    equal(shout.shown, false, "running out, out of combat: our icon hidden")
    equal(slot.alpha, 0, "the game's slot transparent")
    equal(warn.alpha, 0, "no running-out border")
    enterCombat(state)
    equal(shout.shown, true, "in combat: our icon")
    equal(slot.alpha, 1, "the game's slot with its time left")
    equal(warn.alpha, 1, "and the running-out border")
    leaveCombat(state)
    equal(slot.alpha, 0, "after combat: the slot transparent again")
    equal(warn.alpha, 0, "and no border")
    equal(shout.shown, false)
    -- Up and outside the lead: also hidden out of combat, in full in combat (Show only when needed off).
    state.buff("player", "Battle Shout", state.now + 91)
    state.update("UNIT_AURA", "player")
    state.applyDrivers()
    equal(shout.shown, false, "up, out of combat: hidden")
    equal(slot.alpha, 0)
    enterCombat(state)
    equal(slot.alpha, 1, "in combat: the slot in full")
    equal(shout.alpha, 1)
    -- Both on: in combat, Show only when needed decides, as before.
    local both = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true}, db = {combatOnly = {battleShout = true}}})
    both.buff("player", "Battle Shout", both.now + 91)
    both.update("UNIT_AURA", "player")
    both.applyDrivers()
    equal(both.icon("battleShout").shown, false, "both on: hidden out of combat")
    enterCombat(both)
    equal(both.icon("battleShout").alpha, 0, "in combat outside the window: hidden (only when needed)")
    equal(both.slotOf("battleShout").alpha, 0)
    both.advance(30)
    equal(both.icon("battleShout").alpha, 1, "60 s left: the window opens")
    equal(both.slotOf("battleShout").alpha, 1)
end)
test("Warrior: Overpower and Revenge sound when they turn usable, also in combat, once per window", function()
    local state = fixture({class = "WARRIOR", known = {[7384] = true, [6572] = true}})
    state.usable = {Overpower = {false, false}, Revenge = {false, false}}
    state.combat = true
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 0, "not usable: silent")
    state.usable.Overpower = {true, false}
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 1, "Overpower turned usable, in combat")
    equal(state.played[1].key, "talent")
    equal(state.played[1].speech, "Overpower", "Text to Speech says its name")
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 1, "still usable: no second sound")
    state.usable.Overpower = {false, true}
    state.emit("SPELL_UPDATE_USABLE")
    state.usable.Overpower = {true, false}
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 1, "rage flickering within the window: no repeat")
    state.now = state.now + 4
    state.usable.Overpower = {false, false}
    state.emit("SPELL_UPDATE_USABLE")
    state.usable.Overpower = {true, false}
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 2, "a new window: a new sound")
    state.usable.Revenge = {true, false}
    state.emit("SPELL_UPDATE_USABLE")
    equal(state.played[3].key, "magical", "Revenge has its own sound")
    state.usable.Revenge = "secret"
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 3, "a secret answer is skipped")
    state.combat = false
    state.clear()
    state.slash("debug")
    contains(state.find("debug procs overpower"), "on=true sound=talent reactive=7384=Overpower usable=true")
end)
test("Hunter: Mongoose Bite sounds when it turns usable, as Overpower; on by default, any sound", function()
    local state = fixture({class = "HUNTER", known = {[1495] = true}})
    equal(state.dbr.db.procs.spells.mongoosebite, true, "on by default")
    local row = state.row("DBR_PROC_MONGOOSEBITE")
    equal(row.kind, "checkboxdropdown")
    contains(row.data.cbTooltip, "Mongoose Bite becomes usable")
    equal(row.menuFilter, nil, "any sound: DBR plays it")
    state.usable = {["Mongoose Bite"] = {false, false}}
    state.combat = true
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 0, "not usable: silent")
    state.usable["Mongoose Bite"] = {true, false}
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 1, "usable after a dodge, in combat")
    equal(state.played[1].key, "talent")
    equal(state.played[1].speech, "Mongoose Bite")
    state.usable["Mongoose Bite"] = {false, true}
    state.emit("SPELL_UPDATE_USABLE")
    state.usable["Mongoose Bite"] = {true, false}
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 1, "within 3 seconds: no repeat")
    state.now = state.now + 4
    state.usable["Mongoose Bite"] = "secret"
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 1, "a secret answer is skipped")
    state.usable["Mongoose Bite"] = {false, false}
    state.emit("SPELL_UPDATE_USABLE")
    state.usable["Mongoose Bite"] = {true, false}
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 2, "a new window: a new sound")
    state.combat = false
    state.dbr.db.procs.spells.mongoosebite = false
    state.now = state.now + 4
    state.usable["Mongoose Bite"] = {false, false}
    state.emit("SPELL_UPDATE_USABLE")
    state.usable["Mongoose Bite"] = {true, false}
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 2, "switched off: silent")
    for _, entry in ipairs(state.dbr.ClassProcs("HUNTER")) do
        equal(entry.key == "counterattack", false, "Counterattack is not a cue")
    end
end)
test("Warrior: the reactive sounds are in Procs, each with its switch and any sound", function()
    local state = fixture({class = "WARRIOR", known = {[7384] = true, [6572] = true}})
    local row = state.row("DBR_PROC_OVERPOWER")
    equal(row.kind, "checkboxdropdown")
    contains(row.data.cbTooltip, "Overpower becomes usable")
    equal(row.menuFilter, nil, "any sound: DBR plays it, not the game")
    equal(state.row("DBR_PROC_FLURRY").menuFilter, "aura", "Flurry still aura sounds only")
    state.settings.DBR_PROC_OVERPOWER_SOUND:SetValue("magical")
    equal(state.dbr.db.procs.sounds.overpower, "magical")
    state.settings.DBR_PROC_OVERPOWER:SetValue(false)
    state.usable = {Overpower = {true, false}}
    local before = #state.played
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, before, "switched off: silent")
    state.settings.DBR_PROC_OVERPOWER:SetValue(true)
    state.settings.DBR_PROCS_ENABLED:SetValue(false)
    state.usable = {Overpower = {false, false}}
    state.emit("SPELL_UPDATE_USABLE")
    state.usable = {Overpower = {true, false}}
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, before, "Procs off: silent")
    equal(state.soundIDs(), "", "no aura sound registered for a reactive ability")
end)
local FURY = 25780
test("Paladin: Righteous Fury reminds solo, or as the group's designated tank; the talent no longer matters", function()
    local state = fixture({class = "PALADIN", known = {[FURY] = true, [20468] = true}})
    local holder = state.widget("righteousFury")
    equal(holder.shown, true, "solo (with or without Improved Righteous Fury): shown while down")
    equal(visible(state.icon("righteousFury")), true)
    state.party({{name = "Healy", class = "PRIEST"}})
    equal(holder.shown, false, "in a group, not the tank: no reminder")
    state.units.player.role = "TANK"
    state.update("PLAYER_ROLES_ASSIGNED")
    equal(holder.shown, true, "the Tank role")
    state.units.player.secretRole = true
    state.update("PLAYER_ROLES_ASSIGNED")
    equal(holder.shown, false, "a secret role: can't tell, so not the tank in a group")
    state.units.player.secretRole = nil
    state.units.player.role = nil
    state.group = "raid"
    state.mainTank = true
    state.update("GROUP_ROSTER_UPDATE")
    equal(holder.shown, true, "a raid's main tank")
    state.secretMainTank = true
    state.update("GROUP_ROSTER_UPDATE")
    equal(holder.shown, false, "a secret main-tank answer: not the tank")
    state.secretMainTank, state.mainTank = nil, nil
    state.update("GROUP_ROSTER_UPDATE")
    equal(holder.shown, false, "a raid, not main tank")
    local row = state.row("DBR_ALWAYS_RIGHTEOUSFURY")
    equal(row.parentInitializer, state.row("DBR_BUFF_RIGHTEOUSFURY"), "Always show stays, under its switch")
    state.settings.DBR_ALWAYS_RIGHTEOUSFURY:SetValue(true)
    equal(holder.shown, true, "Always show: shown")
    state.settings.DBR_ALWAYS_RIGHTEOUSFURY:SetValue(false)
    state.group = nil
    state.combat = true
    state.update("GROUP_ROSTER_UPDATE")
    equal(holder.shown, false, "leaving the group in combat waits")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(holder.shown, true, "solo again, after combat")
    local db = fixture({class = "PALADIN", db = {alwaysShow = {righteousFury = "yes", gone = true}}}).dbr.db
    equal(db.alwaysShow.righteousFury, false, "repaired")
    equal(db.alwaysShow.gone, nil)
end)

local function warningShown(state)
    local frame = state.env.DyresBuffRemindersWarning
    local content = frame and frame.children[1]
    return content ~= nil and content.shown == true, content
end
test("Paladin: Righteous Fury on in a group where you aren't the tank: an on-screen message, not an icon", function()
    local state = fixture({class = "PALADIN", known = {[FURY] = true}})
    local MESSAGE = "Righteous Fury is on: You're not the tank. Turn it off."
    equal(state.icon("furyOff"), nil, "no icon")
    state.buff("player", "Righteous Fury")
    state.update("UNIT_AURA", "player")
    equal(state.count(MESSAGE), 0, "solo: nothing")
    state.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    equal(state.count(MESSAGE), 1, "joining a group, not the tank: once in chat")
    local shown, content = warningShown(state)
    equal(shown, true, "and on screen")
    equal(content.animation.playing, true, "fading")
    equal(content.animation.animation.delay, 4, "after a few seconds")
    state.update("UNIT_AURA", "player")
    state.update("GROUP_ROSTER_UPDATE")
    equal(state.count(MESSAGE), 1, "nothing changed: not again")
    state.combat = true
    state.emit("PLAYER_REGEN_DISABLED")
    equal(state.count(MESSAGE), 1, "combat starts within 30 s: not again")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    state.advance(31)
    state.combat = true
    state.emit("PLAYER_REGEN_DISABLED")
    equal(state.count(MESSAGE), 2, "combat starts later, still on: once more")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    state.advance(31)
    state.update("UNIT_AURA", "player")
    equal(state.count(MESSAGE), 2, "still nothing changed, past 30 s: not again")
    state.units.player.buffs["Righteous Fury"] = nil
    state.update("UNIT_AURA", "player")
    state.advance(31)
    state.buff("player", "Righteous Fury")
    state.update("UNIT_AURA", "player")
    equal(state.count(MESSAGE), 3, "off, then on again: again")
    state.units.player.buffs["Righteous Fury"] = nil
    state.update("UNIT_AURA", "player")
    state.advance(31)
    state.units.player.role = "TANK"
    state.buff("player", "Righteous Fury")
    state.update("PLAYER_ROLES_ASSIGNED")
    equal(state.count(MESSAGE), 3, "the tank: no message")
    state.units.player.role = nil
    state.settings.DBR_ALWAYS_RIGHTEOUSFURY:SetValue(true)
    equal(state.count(MESSAGE), 3, "Always show Righteous Fury: no message")
    state.settings.DBR_ALWAYS_RIGHTEOUSFURY:SetValue(false)
    equal(state.count(MESSAGE), 4)
    state.units.player.buffs["Righteous Fury"] = nil
    state.update("UNIT_AURA", "player")
    state.advance(31)
    state.settings.DBR_WARN_FURYOFF:SetValue(false)
    state.buff("player", "Righteous Fury")
    state.update("UNIT_AURA", "player")
    equal(state.count(MESSAGE), 4, "its own switch off")
    equal(state.row("DBR_WARN_FURYOFF").setting.name, "Warn: Righteous Fury on when not tanking")
    equal(state.row("DYRE_DYRESBUFFREMINDERS_WARNINGS_SCALE").setting.name, "Warning messages: size")
    local secret = fixture({class = "PALADIN", known = {[FURY] = true}})
    secret.units.player.secretAuras = true
    secret.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    equal(secret.count("Righteous Fury is on"), 0, "a secret read: can't tell, no message")
end)

test("Hunter and Warlock: a pet taunt on autocast in a group where you aren't the tank: an on-screen message", function()
    local state = fixture({class = "HUNTER", known = {[883] = true}, toolkitBefore29 = true})
    local MESSAGE = "Pet taunt on: Growl is on autocast in a group. Turn it off."
    equal(state.icon("hunterPetTaunt"), nil, "no icon")
    state.units.pet = {}
    state.petActions = {[1] = {name = "Attack", token = true, auto = true}, [4] = {name = "Growl", auto = true}}
    state.update("PET_BAR_UPDATE")
    equal(state.count(MESSAGE), 0, "solo: nothing")
    state.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    equal(state.count(MESSAGE), 1, "in a group, not the tank, Growl on autocast")
    equal(warningShown(state), true)
    state.petActions[4].auto = false
    state.update("PET_BAR_UPDATE")
    state.advance(31)
    state.petActions[4].auto = true
    state.update("PET_BAR_UPDATE")
    equal(state.count(MESSAGE), 2, "turned on again: again")
    state.petActions[4].auto = false
    state.update("PET_BAR_UPDATE")
    state.advance(31)
    state.petActions[4].secret = true
    state.petActions[4].auto = true
    state.update("PET_BAR_UPDATE")
    equal(state.count(MESSAGE), 2, "a secret answer: no message")
    state.petActions[4].secret = nil
    state.units.pet = nil
    state.update("UNIT_PET", "player")
    equal(state.count(MESSAGE), 2, "no pet: no message")
    state.units.player.role = "TANK"
    state.units.pet = {}
    state.update("UNIT_PET", "player")
    equal(state.count(MESSAGE), 2, "the tank: no message")
    local lock = fixture({class = "WARLOCK", known = {[697] = true}, toolkitBefore29 = true})
    lock.units.pet = {}
    lock.petActions = {[5] = {name = "Torment", auto = true}, [6] = {name = "Suffering", auto = true}}
    lock.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    equal(lock.count("Pet taunt on: Torment and Suffering are on autocast in a group. Turn it off."), 1,
        "the Voidwalker's taunts")
    local imp = fixture({class = "WARLOCK", known = {[688] = true}})
    imp.units.pet = {}
    imp.petActions = {[5] = {name = "Torment", auto = true}}
    imp.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    equal(imp.count("Pet taunt on"), 0, "no Voidwalker or Felguard summon: no warning")
    local priest = fixture({class = "PRIEST"})
    equal(priest.env.DyresBuffRemindersWarning, nil, "a class without warnings: no message box")
end)

-- The 2 s re-check (John, 2026-11-25, as Dyre's Toolkit's pet taunt fix): a
-- group, role, or zone event is checked again 2 s later, for data that comes late.
test("re-check: a group formed with Growl on autocast, the pet bar late, warns 2 s later", function()
    local state = fixture({class = "HUNTER", known = {[883] = true}, toolkitBefore29 = true})
    local MESSAGE = "Pet taunt on: Growl is on autocast in a group. Turn it off."
    state.units.pet = {}
    state.petActions = {[1] = {name = "Attack", token = true, auto = true}, [4] = {name = "Growl", auto = true}}
    state.update("PET_BAR_UPDATE")
    equal(state.count(MESSAGE), 0, "solo: nothing")
    -- The group forms; at the first check the pet bar is not ready yet.
    local actions = state.petActions
    state.petActions = {}
    state.group = "party"
    state.units.party1 = {name = "Tanky", class = "WARRIOR", role = "TANK"}
    state.emit("GROUP_ROSTER_UPDATE")
    state.wait(0.5)
    equal(state.count(MESSAGE), 0, "the first check: no pet bar data yet")
    state.petActions = actions
    state.wait(1.6)
    equal(state.count(MESSAGE), 1, "2 s later: the warning, with no new event")
    equal(warningShown(state), true)
end)
test("re-check: a newer event replaces the waiting check", function()
    local state = fixture({class = "HUNTER", known = {[883] = true}, toolkitBefore29 = true})
    local MESSAGE = "Pet taunt on: Growl is on autocast in a group. Turn it off."
    state.units.pet = {}
    local actions = {[1] = {name = "Attack", token = true, auto = true}, [4] = {name = "Growl", auto = true}}
    state.petActions = {}
    state.group = "party"
    state.units.party1 = {name = "Tanky", class = "WARRIOR", role = "TANK"}
    state.emit("GROUP_ROSTER_UPDATE")
    state.wait(1.5)
    state.emit("PLAYER_ROLES_ASSIGNED")
    state.wait(0.3)
    state.petActions = actions
    state.wait(0.4)
    equal(state.count(MESSAGE), 0, "the first event's check (at 2 s) was replaced: nothing yet")
    state.wait(1.4)
    equal(state.count(MESSAGE), 1, "the newer event's check, 2 s after it")
    local fighting = fixture({class = "HUNTER", known = {[883] = true}, toolkitBefore29 = true})
    fighting.units.pet = {}
    fighting.petActions = {}
    fighting.group = "party"
    fighting.units.party1 = {name = "Tanky", class = "WARRIOR", role = "TANK"}
    fighting.emit("GROUP_ROSTER_UPDATE")
    fighting.wait(0.5)
    fighting.petActions = actions
    fighting.combat = true
    fighting.wait(2)
    equal(fighting.count(MESSAGE), 0, "in combat the re-check does nothing")
end)
test("re-check: Righteous Fury and Thorns follow a tank role that comes after the group event", function()
    local paladin = fixture({class = "PALADIN", known = {[FURY] = true}})
    local holder = paladin.widget("righteousFury")
    paladin.group = "party"
    paladin.units.party1 = {name = "Healy", class = "PRIEST"}
    paladin.emit("GROUP_ROSTER_UPDATE")
    paladin.wait(0.5)
    equal(holder.shown, false, "the first check: no role yet, not the tank")
    paladin.units.player.role = "TANK"
    paladin.wait(1.6)
    equal(holder.shown, true, "2 s later: the designated tank, the reminder shows")
    local druid = fixture({class = "DRUID", known = {[THORNS] = true}, db = {needed = {thorns = false}}})
    local thorns = druid.icon("thorns")
    druid.group = "party"
    druid.units.party1 = {name = "Tanky", class = "WARRIOR"}
    druid.emit("GROUP_ROSTER_UPDATE")
    druid.wait(0.5)
    equal(thorns.attributes.unit1, "player", "the first check: no tank yet, you")
    druid.units.party1.role = "TANK"
    druid.wait(1.6)
    equal(thorns.attributes.unit1, "party1", "2 s later: the tank")
end)

-- A Hunter in a group (not the tank) with Growl on autocast.
local function growlInGroup(state)
    state.units.pet = {}
    state.petActions = {[1] = {name = "Attack", token = true, auto = true}, [4] = {name = "Growl", auto = true}}
    state.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    state.update("PET_BAR_UPDATE")
    state.advance(1)
end
local GROWL = "Pet taunt on: Growl is on autocast in a group. Turn it off."
local function petTauntSwitch(state)
    local row = state.row("DBR_WARN_HUNTERPETTAUNT")
    local live = true
    for _, predicate in ipairs(row.modifyPredicates) do
        live = live and predicate()
    end
    return row, live
end
test("Pet taunt with Dyre's Toolkit 2.9.0: the toolkit warns, DBR stays quiet and greys its switch", function()
    local state = fixture({class = "HUNTER", known = {[883] = true}})
    equal(state.toolkit.KindOwner("warn:petTaunt"), "DyresToolkit", "the toolkit's claim")
    equal(state.dbr.ToolkitOwnsPetTaunt(), true)
    growlInGroup(state)
    equal(state.count("Pet taunt on"), 0, "no chat line")
    equal(warningShown(state), false, "no message box")
    state.emit("PLAYER_REGEN_DISABLED")
    equal(state.count("Pet taunt on"), 0, "nothing as combat starts")
    local row, live = petTauntSwitch(state)
    equal(live, false, "the switch is greyed")
    contains(row.tooltip(), "Dyre's Toolkit gives this warning now")
    state.slash("debug")
    contains(state.find("debug warning hunterPetTaunt"), "owner=DyresToolkit")
    -- The toolkit's own switch off keeps its claim (off means off): it does
    -- not call SetOwnerEnabled, so the owner stays.
    local lock = fixture({class = "WARLOCK", known = {[697] = true}})
    lock.units.pet = {}
    lock.petActions = {[5] = {name = "Torment", auto = true}}
    lock.party({{name = "Tanky", class = "WARRIOR", role = "TANK"}})
    lock.advance(1)
    equal(lock.toolkit.KindOwner("warn:petTaunt"), "DyresToolkit", "its switch off: still the owner")
    equal(lock.count("Pet taunt on"), 0, "the toolkit's switch off: DBR still quiet")
    -- Unlocked: no sample "Pet taunt on" from DBR beside the toolkit's.
    lock.slash("unlock")
    equal(warningShown(lock), false, "no DBR sample")
end)

test("Pet taunt: a claim after DBR's login silences DBR; an older or no toolkit keeps DBR's copy", function()
    local state = fixture({class = "HUNTER", known = {[883] = true}, lateClaim = true})
    equal(state.dbr.ToolkitOwnsPetTaunt(), false, "no claim yet")
    local _, live = petTauntSwitch(state)
    equal(live, true, "no claim: the switch works")
    growlInGroup(state)
    equal(state.count(GROWL), 1, "no claim yet: DBR warns")
    state.claimPetTaunt()
    state.advance(1)
    _, live = petTauntSwitch(state)
    equal(live, false, "claimed later: greyed")
    state.advance(31)
    state.emit("PLAYER_REGEN_DISABLED")
    equal(state.count(GROWL), 1, "claimed later: no warning again, not even as combat starts")
    local older = fixture({class = "HUNTER", known = {[883] = true}, toolkitBefore29 = true})
    equal(older.dbr.ToolkitOwnsPetTaunt(), false, "no Owners: not the toolkit's")
    growlInGroup(older)
    equal(older.count(GROWL), 1, "a toolkit before 2.9.0: DBR warns")
    local olderRow
    olderRow, live = petTauntSwitch(older)
    equal(live, true)
    equal(olderRow.tooltip():find('gives this warning now', 1, true), nil, 'no note while DBR warns')
    -- Owners (2.5.0 to 2.8.0) with no claim: DBR's copy too.
    local noClaim = fixture({class = "HUNTER", known = {[883] = true}, lateClaim = true})
    growlInGroup(noClaim)
    equal(noClaim.count(GROWL), 1, "Owners but no claim: DBR warns")
    -- No toolkit: DBR needs it and stays off (no warning of its own either).
    local none = fixture({class = "HUNTER", known = {[883] = true}, noToolkit = true})
    equal(none.dbr.available, false, "no toolkit: DBR is off")
    equal(none.env.DyresBuffRemindersWarning, nil, "no message box")
    -- A Paladin's Righteous Fury warning is DBR's alone.
    local paladin = fixture({class = "PALADIN", known = {[25780] = true}})
    equal(paladin.row("DBR_WARN_FURYOFF").modifyPredicates[1], nil, "not greyed by the toolkit")
end)

test("Paladin: Righteous Fury, on you only", function()
    local state = fixture({class = "PALADIN", known = {[25780] = true}})
    local fury = state.icon("righteousFury")
    equal(visible(fury), true)
    equal(fury.attributes.spell1, "Righteous Fury")
    equal(fury.attributes.unit1, "player")
    state.units.player.role = "TANK"
    state.party({{name = "Healy", class = "PRIEST"}})
    equal(table.concat(fury.missing, ","), "you", "a self buff")
    equal(state.settings.DBR_GROUP_RIGHTEOUSFURY, nil, "no group switch")
    state.buff("player", "Righteous Fury")
    state.update("UNIT_AURA", "player")
    equal(visible(fury), false)
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
    local display = state.env.DyresBuffRemindersSeal
    local function sealContainers()
        local found = {}
        for _, frame in ipairs(state.frames) do
            if frame.kind == "AuraContainer" and frame.parent == display then found[#found + 1] = frame end
        end
        return found
    end
    local containers = sealContainers()
    equal(#containers, 1)
    equal(containers[1].slots[1].ids[ZEAL], nil)
    state.known[ZEAL] = true
    state.spellbook[#state.spellbook + 1] = {spellID = ZEAL, name = "Seal of Zeal"}
    state.spellbook[#state.spellbook + 1] = {spellID = 585, name = "Smite"}
    state.spellbook[#state.spellbook + 1] = {spellID = 990002, name = "Seal of Later", itemType = 2}
    state.emit("SPELLS_CHANGED")
    containers = sealContainers()
    equal(#containers, 2, "a new container for the new seal")
    equal(containers[1].shown, false, "the old one hidden")
    equal(containers[2].slots[1].ids[ZEAL], true)
    equal(containers[2].slots[1].ids[990002], nil, "not learned yet")
    equal(containers[2].slots[1].ids[RIGHTEOUSNESS], true, "the listed seals stay")
    state.emit("SPELLS_CHANGED")
    equal(#sealContainers(), 2, "no new container without a new seal")
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
    local bare = sealFixture({noAuraContainer = true, known = {[RIGHTEOUSNESS] = true, [25780] = true,
        [20468] = true}})
    equal(bare.said("The seal timer stays off"), true)
    equal(bare.env.DyresBuffRemindersSeal, nil)
    equal(visible(bare.icon("righteousFury")), true, "Righteous Fury still reminds")
    equal(bare.settings.DBR_SEAL, nil, "no switch without the timer")
end)
test("Classic Era: the seal timer shows from plain aura reads, also in combat; nothing else changes", function()
    local state = sealFixture({noAuraContainer = true, classicAuras = true})
    equal(state.said("The seal timer stays off"), false, "it starts on Era")
    local display = state.env.DyresBuffRemindersSeal
    equal(display ~= nil, true)
    local container
    for _, child in ipairs(display.children) do
        if child.slots then container = child end
    end
    equal(container ~= nil and container.unit, "player", "AuraEngine's plain container, on you")
    local slot = container.slots[1].button
    equal(slot.shown, false, "no seal: nothing")
    state.buff("player", "Seal of Righteousness", {spellId = 20154, expires = state.now + 30, duration = 30})
    state.emit("UNIT_AURA", "player")
    equal(slot.shown, true, "a seal (rank 2, by its ID): its icon")
    equal(slot.display.icon.texture, 9000 + 20154)
    equal(slot.display.cooldown.cooldown[2], 30, "and its time left")
    state.combat = true
    state.units.player.buffs["Seal of Righteousness"] = nil
    state.emit("UNIT_AURA", "player")
    equal(slot.shown, false, "Judgement in combat: the slot goes, the missing seal shows through")
    equal(state.drivers[state.env.DyresBuffRemindersSealButton], "[combat] show; hide", "as on Forever")
    state.buff("player", "Seal of Command", {spellId = 20375, expires = state.now + 30, duration = 30})
    state.emit("UNIT_AURA", "player")
    equal(slot.shown, true, "another seal in combat, read at once")
    state.combat = false
    local forever = sealFixture()
    for _, child in ipairs(forever.env.DyresBuffRemindersSeal.children) do
        equal(child.slots ~= nil and child.template == nil, false, "Forever keeps the engine's container")
    end
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
    state.buff("player", "Arcane Intellect", state.now + 240)
    state.update("UNIT_AURA", "player")
    equal(visible(intellect), false, "59 seconds before the lead time")
    local reads = state.auraReads
    state.wait(50)
    equal(visible(intellect), false)
    equal(state.auraReads, reads, "no polling: nothing read before the timer")
    state.wait(9)
    equal(visible(intellect), true, "3 minutes left: 10% of its 30")
    equal(intellect.attributes.spell1, "Arcane Intellect", "a click recasts it")
    equal(intellect.attributes.unit1, "player")
    intellect.scripts.OnEnter(intellect)
    equal(state.tooltip[2], "Running out: you")
    state.buff("player", "Arcane Intellect", state.now + 1800)
    state.update("UNIT_AURA", "player")
    equal(visible(intellect), false, "recast")
end)
test("group members' buffs running out show too, and the earliest sets the timer", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    state.buff("player", "Arcane Intellect", state.now + 600)
    state.party({{name = "Healy", class = "PRIEST", buffs = {["Arcane Intellect"] = state.now + 200}},
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
    equal(visible(intellect), false, "a secret end time counts as on")
    equal(#state.timers, 0, "and sets no timer")
    state.settings.DBR_LEAD:SetValue(0)
    equal(state.dbr.db.leadPercent, 0)
    state.buff("player", "Arcane Intellect", state.now + 3)
    state.update("UNIT_AURA", "player")
    equal(visible(intellect), false, "0: only once it is gone")
    state.settings.DBR_LEAD:SetValue(10)
    equal(visible(intellect), true)
    state.settings.DBR_LEAD:SetValue(99)
    equal(state.dbr.db.leadPercent, 20)
end)
test("a buff running out in combat shows after combat", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    state.buff("player", "Arcane Intellect", state.now + 200)
    state.update("UNIT_AURA", "player")
    state.combat = true
    state.wait(30)
    equal(visible(intellect), false, "our icon stays under the slot in combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(visible(intellect), true)
end)

test("the lead is a share of the buff's own length: 60 minutes at 10% is 6 minutes; 0% and 20%", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    local row = state.row("DBR_LEAD")
    equal(row.setting.name, "Remind before a buff runs out")
    equal(row.options.minValue, 0)
    equal(row.options.maxValue, 20)
    equal(row.setting.default, 10)
    local labels = state.env.MinimalSliderWithSteppersMixin.Label
    equal(row.options.formatters[labels.Right](10), "10%", "the value with its percent sign")
    equal(row.options.formatters[labels.Min], nil, "no end labels: they crowded the next row")
    equal(row.options.formatters[labels.Max], nil)
    local icons = state.row("DBR_BUFF_ICONS_SCALE").options.formatters
    equal(icons[labels.Right](100), "100%", "the reminder icons' size with its percent sign")
    equal(state.row("DBR_BUFF_ICONS_OPACITY").options.formatters[labels.Right](60), "60%", "and opacity")
    local lead = state.row("DBR_LEAD_BATTLESHOUT")
    equal(lead, nil, "a Mage has no Battle Shout")
    local warrior = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true}})
    local seconds = warrior.row("DBR_LEAD_BATTLESHOUT").options.formatters
    equal(seconds[labels.Right](60), 60, "seconds: the plain value, no ends")
    equal(seconds[labels.Min], nil)
    -- update() lets one second pass.
    state.buff("player", "Arcane Intellect", {expires = state.now + 362, duration = 3600})
    state.update("UNIT_AURA", "player")
    equal(visible(intellect), false, "6 minutes 1 second left of 60: not yet")
    state.wait(1)
    equal(visible(intellect), true, "6 minutes left: 10%")
    state.settings.DBR_LEAD:SetValue(20)
    state.buff("player", "Arcane Intellect", {expires = state.now + 721, duration = 3600})
    state.update("UNIT_AURA", "player")
    equal(visible(intellect), true, "20%: 12 minutes")
    state.buff("player", "Arcane Intellect", {expires = state.now + 723, duration = 3600})
    state.update("UNIT_AURA", "player")
    equal(visible(intellect), false, "12 minutes 2 seconds: not yet")
    state.settings.DBR_LEAD:SetValue(0)
    state.buff("player", "Arcane Intellect", {expires = state.now + 3, duration = 3600})
    state.update("UNIT_AURA", "player")
    equal(visible(intellect), false, "0%: not while it is up")
    state.wait(2)
    state.units.player.buffs["Arcane Intellect"] = nil
    state.update("UNIT_AURA", "player")
    equal(visible(intellect), true, "only once it is gone")
    state.settings.DBR_LEAD:SetValue(10)
    state.buff("player", "Arcane Intellect", {expires = state.now + 100, duration = 600})
    state.update("UNIT_AURA", "player")
    equal(visible(intellect), false, "per buff and rank: 10% of a 10-minute one is 60 seconds")
end)

test("Missing buff Glow: the glow shows instead of the red edge only while the buff is gone", function()
    local state = fixture({glowArt = true, known = {[INTELLECT] = true}})
    equal(state.dbr.db.missingStyle, "glow", "the default")
    local intellect = state.icon("arcaneIntellect")
    local alert = intellect.alert
    local warn = state.widget("arcaneIntellect").warn
    equal(alert.parent, intellect.glow, "a child of the border frame: its alpha drives the glow")
    equal(alert.mouse, false, "it never takes the mouse")
    equal(next(alert.scripts), nil, "no scripts")
    equal(alert.flip.looping, "REPEAT")
    equal(alert.flip.animation.kind, "FlipBook")
    equal(alert.flip.animation.target, alert.art)
    equal(alert.flip.animation.frames, 30)
    equal(intellect.glow.shown, true)
    equal(intellect.glow.backdropBorder[4], 0, "missing: the red edge is clear")
    equal(alert.shown, true, "and the glow shows")
    equal(alert.flip.playing, true)
    equal(alert.width, 56, "raised above the slot: the action bars' 1.4 times")
    state.buff("player", "Arcane Intellect", state.now + 600)
    state.update("UNIT_AURA", "player")
    equal(alert.shown, true, "up: armed under the slot, for the moment it drops")
    equal(alert.width, 40, "under the slot: inside the icon, so the slot covers it")
    equal(intellect.level + 2 < state.slotOf("arcaneIntellect").level, true, "below the slot")
    state.wait(419)
    equal(warn.alpha, 1, "running out: the yellow flash, as before")
    equal(alert.shown, false, "no glow while it runs out")
    equal(intellect.glow.shown, false)
    state.units.player.buffs["Arcane Intellect"] = nil
    state.update("UNIT_AURA", "player")
    equal(alert.shown, true, "gone: the glow")
    equal(alert.width, 56)
    state.settings.DBR_MISSING_STYLE:SetValue("border")
    equal(state.dbr.db.missingStyle, "border")
    equal(alert.shown, false, "Red border: no glow")
    equal(alert.flip.playing, false)
    equal(intellect.glow.backdropBorder[2], 0.2)
    equal(intellect.glow.backdropBorder[4], 1, "the red edge again")
    state.settings.DBR_MISSING_STYLE:SetValue("sparkle")
    equal(state.dbr.db.missingStyle, "border", "an unknown choice changes nothing")
end)

test("Missing buff Glow: in combat the drop shows the armed glow; a tank buff's glows from its end", function()
    local state = fixture({glowArt = true, known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    state.buff("player", "Arcane Intellect", state.now + 600)
    state.update("UNIT_AURA", "player")
    state.combat = true
    state.update("PLAYER_REGEN_DISABLED")
    equal(intellect.alert.shown, true, "armed before the fight: the slot going shows it")
    equal(intellect.glow.alpha, 1)
    state.combat = false
    state.update("PLAYER_REGEN_ENABLED")
end)

test("Missing buff Glow: the red border without the glow's art, and the setting is repaired", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    equal(state.dbr.GlowArt(), false, "no C_Texture: no art")
    equal(intellect.alert.shown, false)
    equal(intellect.glow.backdropBorder[4], 1, "the red edge")
    equal(fixture({db = {missingStyle = "border"}}).dbr.db.missingStyle, "border")
    equal(fixture({db = {missingStyle = 7}}).dbr.db.missingStyle, "glow")
    state.clear()
    state.slash("debug")
    equal(state.find("debug missing style=glow glowArt=false") ~= nil, true)
end)

test("Missing buff Glow: the player's case, a Warlock's missing Demon Armor, glows", function()
    local state = fixture({glowArt = true, class = "WARLOCK", known = {[DEMON_ARMOR] = true},
        db = {needed = {demonArmor = false}}})
    local armor = state.icon("demonArmor")
    equal(armor ~= nil, true)
    equal(armor.alert.shown, true, "the player's report: Demon Armor missing glows")
    equal(armor.glow.backdropBorder[4], 0)
end)

-- Found in client (1.13.2): in Dire Maul every boss fight showed buffs that
-- were up as missing; a read during the encounter, out of combat, returned
-- nothing. Here the hidden read is a buff the mock no longer has.
test("Boss encounter: a hidden aura read changes nothing until the encounter ends", function()
    local state = fixture({glowArt = true, known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    state.buff("player", "Arcane Intellect", state.now + 3000)
    state.update("UNIT_AURA", "player")
    equal(intellect.alert.width, 40, "up: ours waits under the slot")
    state.encounter = true
    state.emit("ADDON_RESTRICTION_STATE_CHANGED", 1, 2)
    state.units.player.buffs["Arcane Intellect"] = nil
    state.update("UNIT_AURA", "player")
    equal(intellect.alert.width, 40, "the read says nothing: still under the slot, not raised")
    equal(#intellect.missing, 0, "not counted as missing")
    state.clear()
    state.slash("debug")
    contains(state.find("debug arcaneIntellect"), "missing=not checked during Encounter")
    contains(state.find("debug restrictions"), "Encounter=true")
    contains(state.find("debug restrictions"), "auraHidden=Encounter")
    -- The buff really dropped during the encounter: the slot empties and the
    -- armed glow under it shows through (as in combat).
    equal(intellect.alert.shown, true, "armed: the slot going shows the glow")
    state.encounter = false
    state.update("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
    equal(intellect.alert.width, 56, "the encounter ended: read again, missing, raised")
    equal(intellect.missing[1] ~= nil, true)
    state.buff("player", "Arcane Intellect", state.now + 3000)
    state.update("UNIT_AURA", "player")
    equal(intellect.alert.width, 40)
    state.clear()
    state.slash("debug")
    contains(state.find("debug restrictions"), "Encounter=false")
    contains(state.find("debug restrictions"), "auraHidden=nil")
end)

test("Boss encounter: the Map restriction alone does not stop the reads", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    state.buff("player", "Arcane Intellect", state.now + 3000)
    state.update("UNIT_AURA", "player")
    state.env.Enum.AddOnRestrictionType.Map = 4
    state.env.C_RestrictedActions.IsAddOnRestrictionActive = function(kind) return kind == 4 end
    equal(state.dbr.AuraRestriction(), nil, "Deadmines: Map only, reads worked (John, in client)")
    state.units.player.buffs["Arcane Intellect"] = nil
    state.update("UNIT_AURA", "player")
    equal(intellect.missing[1] ~= nil, true, "a real drop still counts")
end)

test("Boss encounter: no C_RestrictedActions (Classic Era) is never restricted", function()
    local state = fixture({known = {[INTELLECT] = true}, remove = {"C_RestrictedActions"}})
    equal(state.dbr.AuraRestriction(), nil)
    equal(state.icon("arcaneIntellect").missing[1] ~= nil, true, "reads as before")
    state.clear()
    state.slash("debug")
    contains(state.find("debug restrictions"), "none (no C_RestrictedActions)")
end)

test("1.1.0's lead in seconds is repaired to the 10% default", function()
    local old = fixture({db = {lead = 30}}).dbr.db
    equal(old.leadPercent, 10)
    equal(old.lead, nil, "the seconds are dropped")
    equal(fixture({db = {leadPercent = 15}}).dbr.db.leadPercent, 15, "a percent stays")
    equal(fixture({db = {leadPercent = 7.5}}).dbr.db.leadPercent, 10)
    equal(fixture({db = {leadPercent = "x"}}).dbr.db.leadPercent, 10)
end)

test("the border: red while missing, yellow and flashing while running out, none while up", function()
    local state = fixture({known = {[INTELLECT] = true}})
    local intellect = state.icon("arcaneIntellect")
    local warn = state.widget("arcaneIntellect").warn
    equal(warn.mouse, false, "it never takes the mouse")
    equal(warn.level > state.slotOf("arcaneIntellect").level, true, "above the slot")
    equal(warn.backdropBorder[1] == 1 and warn.backdropBorder[2] == 1, true, "yellow")
    equal(intellect.glow.backdropBorder[2], 0.2, "missing: red")
    equal(warn.alpha, 0)
    state.buff("player", "Arcane Intellect", state.now + 600)
    state.update("UNIT_AURA", "player")
    equal(intellect.glow.shown, true, "up: red still, under the slot, for the moment it drops")
    equal(intellect.glow.backdropBorder[2], 0.2)
    equal(visible(intellect), false, "covered by the slot: no border shows")
    equal(warn.alpha, 0, "up and outside the window: no yellow")
    state.wait(419)
    equal(warn.alpha, 1, "3 minutes left: yellow")
    equal(warn.flash.playing, true, "and flashing")
    equal(warn.flash.looping, "BOUNCE")
    equal(intellect.glow.shown, false, "ours raised out of combat, with no red")
    state.buff("player", "Arcane Intellect", state.now + 1800)
    state.update("UNIT_AURA", "player")
    equal(warn.alpha, 0, "recast: off")
    equal(warn.flash.playing, false)
    state.units.player.buffs["Arcane Intellect"] = nil
    state.update("UNIT_AURA", "player")
    equal(intellect.glow.shown, true, "gone: red")
    equal(warn.alpha, 0)
    state.party({{name = "Healy", class = "PRIEST", buffs = {["Arcane Intellect"] = state.now + 100}}})
    state.buff("player", "Arcane Intellect", state.now + 1800)
    state.update("UNIT_AURA", "player")
    equal(warn.alpha, 1, "a group member's runs out: yellow")
    equal(intellect.glow.shown, false)
    state.party({{name = "Healy", class = "PRIEST", buffs = {["Arcane Intellect"] = state.now + 100}},
        {name = "Zappy", class = "MAGE"}})
    equal(intellect.glow.shown, true, "anyone lacks it: red wins")
    equal(warn.alpha, 0)
    state.slash("unlock")
    equal(warn.alpha, 0, "unlocked: no yellow")
    equal(intellect.glow.shown, true, "red while one is missing")
end)

test("in combat: yellow from the known end, gone when it runs out; your recast resets it", function()
    local state = fixture({known = {[INTELLECT] = true, [FROST_ARMOR] = true}})
    local warn = state.widget("arcaneIntellect").warn
    state.buff("player", "Arcane Intellect", state.now + 201)
    state.buff("player", "Frost Armor", state.now + 201)
    state.update("UNIT_AURA", "player")
    state.combat = true
    state.emit("PLAYER_REGEN_DISABLED")
    equal(warn.alpha, 0, "200 seconds left: not yet")
    state.advance(20)
    equal(warn.alpha, 1, "3 minutes left, timed in combat")
    state.advance(180)
    equal(warn.alpha, 0, "run out: the slot goes and the red border under it shows")
    state.cast(INTELLECT)
    equal(warn.alpha, 0, "recast with no target: on you, its full length again")
    state.advance(1619)
    equal(warn.alpha, 0)
    state.advance(1)
    equal(warn.alpha, 1, "3 minutes before the recast's end")
    state.units.target = {friend = true}
    state.cast(INTELLECT)
    equal(warn.alpha, 1, "cast on a friendly target: not on you, nothing reset")
    state.units.target = {}
    state.cast(INTELLECT)
    equal(warn.alpha, 0, "a hostile target: the client casts it on you")
    local armor = state.widget("mageArmor").warn
    state.advance(20)
    equal(armor.alpha, 0, "the armor ran out earlier")
    state.units.target = {friend = true}
    state.cast(FROST_ARMOR)
    equal(armor.alpha, 0, "a self-only buff: any cast is on you")
    state.advance(1620)
    equal(armor.alpha, 1)
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
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

test("each buff is its own widget, in a row where the bars were; only buffs you can show have one", function()
    local mage = fixture({known = {[INTELLECT] = true, [FROST_ARMOR] = true}})
    local intellect, armor = mage.widget("arcaneIntellect"), mage.widget("mageArmor")
    equal(mage.icon("arcaneIntellect").parent, intellect)
    equal(intellect.dyre.widgetKey, "buff_arcaneIntellect")
    equal(intellect.dyre.store, mage.dbr.db.buffs.arcaneIntellect, "its own saved table")
    equal(intellect.width, 40)
    equal(select(2, mage.absCenter(intellect)), 400 + 180, "group buffs in the upper row")
    equal(select(2, mage.absCenter(armor)), 400 + 130, "self buffs in the lower row")
    local priest = fixture({class = "PRIEST", known = {[FORTITUDE] = true, [INNER_FIRE] = true,
        [DIVINE_SPIRIT] = true}})
    local fx = priest.absCenter(priest.widget("fortitude"))
    local dx = priest.absCenter(priest.widget("divineSpirit"))
    equal(dx - fx, 60, "40 wide, the toolkit's 20 apart")
    equal(priest.widget("divineSpirit").shown, false, "known but switched off: no widget")
    priest.settings.DBR_BUFF_DIVINESPIRIT:SetValue(true)
    equal(priest.widget("divineSpirit").shown, true, "switched on: it shows, in its own place")
    equal(priest.absCenter(priest.widget("divineSpirit")), dx, "nothing else moved")
    equal(priest.widget("shadowProtection").shown, false, "not known: no widget")
    priest.known[SHADOW_PROTECTION] = true
    priest.settings.DBR_BUFF_SHADOWPROTECTION:SetValue(true)
    priest.update("SPELLS_CHANGED")
    equal(priest.widget("shadowProtection").shown, true, "learned: it shows")
end)
test("each reminder's bar: Group buffs for what can go on another player, My buffs for self only", function()
    local state = fixture()
    local function bar(reminder) return (reminder.group or reminder.others) and "group" or "my" end
    local wanted = {arcaneIntellect = "group", mageArmor = "my", demonArmor = "my",
        markOfTheWild = "group", thorns = "group", righteousFury = "my", fortitude = "group", innerFire = "my",
        divineSpirit = "group", shadowProtection = "group", aspect = "my", battleShout = "group", dampen = "my",
        hunterPet = "my", warlockPet = "my"}
    local count = 0
    for _, list in pairs(state.dbr.BUFFS) do
        for _, reminder in ipairs(list) do
            equal(bar(reminder), wanted[reminder.key], reminder.key)
            count = count + 1
        end
    end
    equal(count, 15, "every reminder is listed here")
end)
test("always shown: the slot draws a buff that is up, in and out of combat; ours under it, armed", function()
    local state = fixture({known = {[INTELLECT] = true}, db = {needed = {arcaneIntellect = false}}})
    local icon, slot = state.icon("arcaneIntellect"), state.slotOf("arcaneIntellect")
    local holder = state.widget("arcaneIntellect")
    local container
    for _, frame in ipairs(state.frames) do
        if frame.kind == "AuraContainer" and frame.parent == slot then container = frame end
    end
    equal(container.unit, "player", "on you")
    equal(container.slots[1].ids[1459], true, "every rank")
    equal(container.slots[1].ids[10157], true)
    equal(container.slots[1].ids[BRILLIANCE], true, "and the group version")
    equal(container.slots[1].button.mouse, false, "the slot takes no mouse: a click reaches our icon")
    equal(slot.alpha, nil, "the slot is never made transparent: it shows in and out of combat")
    equal(visible(icon), true, "missing: ours, above the slot")
    state.buff("player", "Arcane Intellect")
    state.update("UNIT_AURA", "player")
    equal(icon.shown, true, "up: still shown...")
    equal(icon:GetFrameLevel() < slot:GetFrameLevel(), true, "...under the slot, which draws the buff")
    equal(icon.glow.points[1] == nil or icon.glow.points[1][1] ~= "TOPLEFT", true,
        "its pulsing border is inside it, so the slot covers it whole")
    equal(icon.attributes.spell1, "Arcane Intellect", "armed: if the buff drops, a click recasts it")
    equal(icon.attributes.unit1, "player", "on you")
    equal(holder.shown, true)
    state.combat = true
    state.applyDrivers()
    state.emit("PLAYER_REGEN_DISABLED")
    equal(icon.shown, true, "combat starts: nothing appears or disappears")
    equal(holder.shown, true)
    equal(icon:GetFrameLevel() < slot:GetFrameLevel(), true, "still under the slot")
    state.combat = false
    state.applyDrivers()
    state.emit("PLAYER_REGEN_ENABLED")
    equal(icon.shown, true, "combat ends: nothing appears or disappears")
    state.party({{name = "Healy", class = "PRIEST"}})
    equal(visible(icon), true, "a group member lacks it: ours above the slot, with its smart click")
    equal(icon.attributes.unit1, "party1")
    local druid = fixture({class = "DRUID", known = {[THORNS] = true}})
    druid.buff("player", "Thorns")
    druid.update("UNIT_AURA", "player")
    equal(druid.icon("thorns").attributes.macrotext1, "/cancelform\n/use [@player] Thorns",
        "a Druid's armed click leaves any form first")
    local bare = fixture({known = {[INTELLECT] = true}, noAuraContainer = true})
    bare.buff("player", "Arcane Intellect")
    bare.update("UNIT_AURA", "player")
    equal(bare.slotOf("arcaneIntellect"), nil, "no aura container: no slot")
    equal(bare.drivers[bare.icon("arcaneIntellect")], "hide", "and an up buff is hidden, as before")
end)
test("each buff widget moves and saves on its own; one Size and Opacity for every buff icon", function()
    local state = fixture({known = {[INTELLECT] = true, [FROST_ARMOR] = true}})
    local intellect, armor = state.widget("arcaneIntellect"), state.widget("mageArmor")
    state.slash("unlock")
    equal(intellect.dyre.mover.shown, true, "outlined while unlocked")
    local icon = state.icon("mageArmor")
    icon.scripts.OnDragStart(icon)
    armor:ClearAllPoints()
    armor:SetPoint("CENTER", nil, "BOTTOMLEFT", 200, 150)
    icon.scripts.OnDragStop(icon)
    equal(state.dbr.db.buffs.mageArmor.position ~= nil, true, "the toolkit saves its place")
    equal(state.dbr.db.buffs.arcaneIntellect.position, nil, "the other stays where it was")
    state.slash("lock")
    local scale = state.row("DBR_BUFF_ICONS_SCALE")
    equal(scale.setting.name, "Reminder icons: size")
    equal(scale.options.minValue, 50)
    equal(scale.options.maxValue, 200)
    state.settings.DBR_BUFF_ICONS_SCALE:SetValue(150)
    equal(intellect.scale, 1.5, "every buff icon")
    equal(armor.scale, 1.5)
    equal(state.dbr.db.buffs.arcaneIntellect.scale, 150, "saved in each one's own table")
    equal(state.dbr.db.buffs.mageArmor.scale, 150)
    state.settings.DBR_BUFF_ICONS_OPACITY:SetValue(60)
    equal(intellect.alpha, 0.6)
    equal(armor.alpha, 0.6)
    local reset
    for _, row in ipairs(state.page().initializers) do
        if row.kind == "button" and row.label == "Reminder icons" then reset = row end
    end
    reset.click()
    equal(intellect.scale, 1, "Reset size: every buff icon")
    equal(armor.scale, 1)
    equal(state.dbr.db.buffs.mageArmor.opacity, 60, "opacity stays")
    state.combat = true
    state.settings.DBR_BUFF_ICONS_SCALE:SetValue(120)
    equal(intellect.scale, 1, "in combat: after combat")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(intellect.scale, 1.2)
    state.clear()
    state.slash("reset")
    contains(state.last(), "default places")
    equal(state.dbr.db.buffs.mageArmor.position, nil)
end)
test("from 1.1.0: each buff starts where its bar was, once; then the bar places are dropped", function()
    local state = fixture({class = "PALADIN", known = {[25780] = true, [21084] = true}, db = {
        bars = {mybuffs = {scale = 120, position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 300,
            y = 200}}},
        seal = {enabled = true, scale = 130, position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 300,
            y = 500}}}})
    local saved = state.dbr.db.buffs.righteousFury
    equal(saved.position.x, 300, "the bar's one slot: its center")
    equal(saved.position.y, 200)
    equal(saved.scale, 120, "with the bar's size")
    equal(state.widget("righteousFury").scale, 1.2)
    equal(state.dbr.db.bars, nil, "the bar places are dropped")
    equal(state.env.DyresBuffRemindersSeal.scale, 1.3, "the seal timer keeps its place and size")
    local mage = fixture({known = {[INTELLECT] = true, [FROST_ARMOR] = true}, db = {
        bars = {mybuffs = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 300, y = 200}}}}})
    equal(mage.dbr.db.buffs.mageArmor.position.x, 276, "Armor, the first of the bar's two self buffs (Dampen)")
    equal(mage.dbr.db.buffs.arcaneIntellect.position, nil, "no group bar was saved: its default row")
end)
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
        .. "Show only when needed|Inner Fire|Show only when needed|Divine Spirit|Divine Spirit: also your group|"
        .. "Show only when needed|Shadow Protection|Shadow Protection: also your group|Show only when needed|"
        .. "Remind before a buff runs out|Visibility when not needed|Missing buff|"
        .. "Reminder icons: size|Reminder icons: opacity", "a Priest has no consumables: no section, no bar")
    local group = state.row("DBR_GROUP_FORTITUDE")
    equal(group.parentInitializer, state.row("DBR_BUFF_FORTITUDE"))
    equal(group.tooltip, "Also remind you when a party or raid member lacks Power Word: Fortitude.")
    contains(state.row("DBR_GROUP_DIVINESPIRIT").tooltip, "who uses mana")
    state.settings.DBR_ENABLED:SetValue(false)
    equal(visible(state.icon("fortitude")), false)
    equal(group.predicate(), false)
    state.settings.DBR_ENABLED:SetValue(true)
    equal(visible(state.icon("fortitude")), true)
    state.settings.DBR_BUFF_FORTITUDE:SetValue(false)
    equal(visible(state.icon("fortitude")), false)
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
    contains(state.messages[2], "debug arcaneIntellect row=groupbuffs on=true group=true known=true shown=true "
        .. "missing=you "
        .. "click=Arcane Intellect@player unknownIDs=none")
    contains(state.messages[3], "debug aura arcaneIntellect state=missing expires=none Arcane Intellect=none "
        .. "Arcane Brilliance=none", "what each name reads on you")
    contains(state.messages[4], "debug mageArmor row=mybuffs on=true group=nil known=false")
    state.buff("player", "Arcane Intellect", state.now + 600)
    state.clear()
    state.slash("debug")
    contains(state.find("debug aura arcaneIntellect"), "state=on expires=600 Arcane Intellect=found(id=nil left=600 "
        .. "dur=1800)")
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
    equal(visible(state.icon("arcaneIntellect")), false)
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
local COUNTERSPELL = 2139
test("chimes: Counterspell's own length is 30 s, as its tooltip in Classic and Forever (John, 2026-11-26)", function()
    local state = fixture()
    state.combat = true
    state.cast(COUNTERSPELL)
    state.advance(29.4)
    equal(#state.played, 0, "not at 24 s, the old wrong length")
    state.advance(0.2)
    equal(#state.played, 1, "30 s minus the 0.5 s lead, with nothing learned")
end)
test("chimes: the lengths, IDs, and names Wowhead's Forever database gives (checked 2026-11-26)", function()
    local state = fixture()
    local byKey = {}
    for _, list in pairs(state.dbr.CHIME_SPELLS) do
        for _, chime in ipairs(list) do byKey[chime.key] = chime end
    end
    local expected = {counterspell = 30, fearward = 180, layonhands = 1200, holyshock = 10, shieldwall = 900,
        laststand = 180, deathwish = 180, retaliation = 900, freezingtrap = 30, multishot = 6,
        elementalmastery = 180, stormstrike = 8}
    for key, seconds in pairs(expected) do
        equal(byKey[key].cooldown, seconds, key)
    end
    equal(byKey.deathwish.spell, 12328, "Death Wish; 12292 is Sweeping Strikes on Forever")
    equal(byKey.elementalmastery.label, "Lightning Mastery", "Forever's name; the saved key stays")
end)
-- Blink's real length here is 13 s, so the learned one differs from the built-in 15 s.
test("chimes after combat: a cooldown cast in combat is read when combat ends, learned, and its chime moved", function()
    local state = fixture()
    state.combat = true
    state.cast(BLINK, 13)
    state.advance(5)
    equal(state.chimes().learned.blink, nil, "in combat: secret, nothing learned")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    state.advance(0.1)
    equal(state.chimes().learned.blink, 13, "combat ends with 8 s left: the real 13 s is learned")
    state.advance(7.2)
    equal(#state.played, 0)
    state.advance(0.2)
    equal(#state.played, 1, "at the real 13 s, minus the 0.5 s lead, not the built-in 15 s")
    state.advance(5)
    equal(#state.played, 1, "once: the built-in schedule was replaced")
    -- The next cast in combat uses it.
    state.combat = true
    state.cast(BLINK)
    state.advance(12.4)
    equal(#state.played, 1)
    state.advance(0.2)
    equal(#state.played, 2, "the learned 13 s, also in combat")
    -- A cooldown over before combat ends: nothing to read, nothing learned.
    local over = fixture()
    over.combat = true
    over.cast(BLINK, 13)
    over.advance(14)
    over.combat = false
    over.emit("PLAYER_REGEN_ENABLED")
    over.advance(0.1)
    equal(over.chimes().learned.blink, nil, "ended before combat did: the built-in 15 s stays")
    -- Out of combat casts are read as before, not again after the next fight.
    local calm = fixture()
    calm.cast(BLINK, 13)
    calm.advance(0.1)
    equal(calm.chimes().learned.blink, 13)
    calm.cooldowns[BLINK] = {start = calm.now, duration = 99}
    calm.emit("PLAYER_REGEN_ENABLED")
    calm.advance(0.1)
    equal(calm.chimes().learned.blink, 13, "a spell not cast in the fight is not read")
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
    equal(dbr.db.leadPercent, 10, "the buff reminders' own lead is separate")
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
local TRAVEL_FORM, AQUATIC_FORM, CHEETAH = 783, 1066, 5118
test("cast chimes: shifting into Travel Form says \"Meep meep\" 0.2 s later, also in combat; leaving it says nothing", function()
    local state = fixture({class = "DRUID", known = {[TRAVEL_FORM] = true}})
    state.voice = true
    local function shift(index, settle)
        state.form = index
        state.emit("UPDATE_SHAPESHIFT_FORM")
        if settle ~= false then state.advance(0.75) end
    end
    shift(4, false)
    equal(#state.played, 0, "not at once")
    state.advance(0.15)
    equal(#state.played, 0)
    state.advance(0.05)
    equal(#state.played, 1, "0.2 s after the shift")
    equal(state.played[1].key, "voice", "Text to Speech at first")
    equal(state.played[1].speech, "Meep meep")
    state.emit("UPDATE_SHAPESHIFT_FORM")
    state.advance(1)
    equal(#state.played, 1, "the same form again (the event repeats): nothing")
    state.cast(TRAVEL_FORM)
    equal(#state.played, 1, "the cast itself (also leaving it) does not chime: the form change does")
    shift(nil)
    equal(#state.played, 1, "leaving it: nothing")
    state.combat = true
    shift(4)
    equal(#state.played, 2, "also in combat")
    shift(1)
    equal(state.played[3].speech, "Rawr", "Bear Form, straight from Travel Form")
    shift(5)
    equal(state.played[4].speech, "Rawr", "Dire Bear counts as Bear Form")
    shift(2)
    equal(state.played[5].speech, "Meow", "Cat Form")
    shift(3)
    equal(state.played[6].speech, "Splash", "Aquatic Form")
    state.cast(1850)
    equal(#state.played, 6, "Dash: off at first")
    state.settings.DBR_CAST_CATFORM:SetValue(false)
    shift(2)
    equal(#state.played, 6, "Cat Form switched off")
    state.settings.DBR_CASTS_ENABLED:SetValue(false)
    shift(4)
    equal(#state.played, 6, "the section's switch off: silent")
    state.settings.DBR_CASTS_ENABLED:SetValue(true)
    state.settings.DBR_CAST_TRAVELFORM_SOUND:SetValue("magical")
    equal(state.played[#state.played].key, "magical", "choosing a sound plays it")
    shift(1)
    shift(4)
    equal(state.played[#state.played].key, "magical")
    state.voice = false
    shift(1)
    equal(state.played[#state.played].key, "talent", "no voice installed: the chimes' default")
    equal(state.row("DBR_CAST_BEARFORM").data.cbTooltip, "Play a sound just after you shift into Bear Form (and Dire Bear).")
end)

test("cast chimes: powershifting chimes once, for the form you settle in", function()
    local state = fixture({class = "DRUID"})
    state.voice = true
    local function shift(index, wait)
        state.form = index
        state.emit("UPDATE_SHAPESHIFT_FORM")
        state.advance(wait)
    end
    shift(2, 0.05)
    shift(1, 0.05)
    shift(nil, 0)
    state.advance(2)
    equal(#state.played, 0, "Cat, Bear, then out, all within 0.2 s: nothing")
    shift(2, 0.05)
    shift(1, 0.75)
    equal(#state.played, 1, "two shifts within 0.2 s: one chime")
    equal(state.played[1].speech, "Rawr", "for the last form")
    shift(2, 0.05)
    shift(nil, 0.05)
    shift(2, 0.75)
    equal(#state.played, 2, "Cat, caster, Cat within the window: one Cat chime")
    equal(state.played[2].speech, "Meow")
    state.advance(5)
    equal(#state.played, 2, "the cancelled timers do nothing")
    shift(4, 0)
    state.form = nil
    state.advance(0.75)
    equal(#state.played, 2, "left without the event yet: the re-read finds no form, nothing")
end)

test("cast chimes: a Hunter's Cheetah, a Rogue's Sprint at every rank; none for a Priest", function()
    local hunter = fixture({class = "HUNTER"})
    hunter.voice = true
    hunter.castChime(CHEETAH)
    equal(hunter.played[1].speech, "Meep meep", "Aspect of the Cheetah")
    hunter.castChime(13159)
    equal(#hunter.played, 1, "the Pack: off at first")
    local rogue = fixture({class = "ROGUE"})
    rogue.voice = true
    rogue.castChime(11305)
    equal(#rogue.played, 1, "Sprint's highest rank, by name")
    rogue.castChime(1767)
    equal(#rogue.played, 1, "other spells: nothing")
    rogue.slash("debug")
    contains(rogue.find("debug casts enabled="), "sprint=on:voice")
    contains(rogue.find("debug casts enabled="), "last=Sprint")
    local priest = fixture({class = "PRIEST"})
    equal(priest.row("DBR_CASTS_ENABLED"), nil, "no Cast Chimes section")
    local db = fixture({db = {casts = {enabled = "x", spells = {travelform = 1, sprint = false},
        sounds = {travelform = "nope"}}}}).dbr.db.casts
    equal(db.enabled, true, "repaired")
    equal(db.spells.travelform, true)
    equal(db.spells.sprint, false)
    equal(db.sounds.travelform, "voice", "an unknown sound: the default")
end)

test("cast chimes: a Warrior's Charge, Intercept, and Execute, with Dyre's Aggression sounds", function()
    local state = fixture({class = "WARRIOR", newerSounds = {"militarycharge", "orccharge", "angryscream",
        "rageattack"}})
    state.castChime(11578)
    equal(#state.played, 1, "Charge, its highest rank")
    equal(state.played[1].key, "militarycharge", "Dyre's Aggression at first")
    state.combat = true
    state.castChime(20252)
    equal(state.played[2].key, "orccharge", "Intercept, also in combat")
    state.castChime(5308)
    equal(state.played[3].key, "angryscream", "Execute")
    state.castChime(1680)
    equal(#state.played, 3, "Whirlwind: off at first")
    state.settings.DBR_CAST_WHIRLWIND:SetValue(true)
    state.castChime(1680)
    equal(state.played[4].key, "rageattack")
    state.castChime(6673)
    equal(#state.played, 4, "Battle Shout's cast chime: off at first")
    equal(state.row("DBR_CAST_INTERVENE"), nil, "Intervene (TBC): listed only once known")
    equal(state.row("DBR_CAST_TAUNT") ~= nil, true)
    local tbc = fixture({class = "WARRIOR", known = {[3411] = true}})
    equal(tbc.row("DBR_CAST_INTERVENE") ~= nil, true, "known: listed")
    local older = fixture({class = "WARRIOR"})
    older.castChime(100)
    equal(older.played[1].key, "talent", "an older Dyre's Sounds without the key: the chimes' default")
    equal(older.dbr.db.casts.sounds.charge, "militarycharge", "the saved default waits for the newer sounds")
    local mage = fixture()
    equal(mage.row("DBR_CAST_CHARGE"), nil, "a Warrior's only")
end)

test("cast chimes: a Druid's Feral Charge and Enrage, also in combat; the roars off; no clash with forms", function()
    local state = fixture({class = "DRUID", known = {[16979] = true}, newerSounds = {"orccharge", "rageattack",
        "orcangry"}})
    state.voice = true
    equal(state.row("DBR_CAST_FERALCHARGE") ~= nil, true, "Feral Charge (talent): listed once known")
    state.form = 1
    state.emit("UPDATE_SHAPESHIFT_FORM")
    state.cast(16979)
    state.advance(0.15)
    equal(#state.played, 0, "Feral Charge waits like the form (the game's own sound plays first)")
    state.advance(0.05)
    equal(#state.played, 2, "both 0.2 s later: the form's chime and Feral Charge's")
    local keys = {state.played[1].speech or state.played[1].key, state.played[2].speech or state.played[2].key}
    table.sort(keys)
    equal(table.concat(keys, ","), "Feral Charge,Rawr")
    state.combat = true
    state.castChime(5229)
    equal(state.played[3].key, "rageattack", "Enrage, in combat")
    state.castChime(99)
    state.castChime(5209)
    equal(#state.played, 3, "the roars: off at first")
    state.settings.DBR_CAST_DEMOROAR:SetValue(true)
    state.castChime(1735)
    equal(state.played[4].key, "orcangry", "Demoralizing Roar, any rank")
    state.castChime(1850)
    equal(#state.played, 4, "Dash keeps its own switch (off)")
    local untalented = fixture({class = "DRUID"})
    equal(untalented.row("DBR_CAST_FERALCHARGE"), nil, "without the talent: not listed")
    equal(untalented.row("DBR_CAST_ENRAGE") ~= nil, true)
    equal(untalented.row("DBR_CAST_BASH") ~= nil, true, "Bash and Frenzied Regeneration: off, listed")
end)

local SAX = {"sax1", "sax2", "sax3", "sax4", "sax5", "sax6", "sax7", "sax8"}
-- Dyre's Sounds 1.4.0: the sax and the bassoon.
local SOUNDS = {"sax1", "sax2", "sax3", "sax4", "sax5", "sax6", "sax7", "sax8", "bassoon1", "bassoon2", "bassoon3",
    "bassoon4", "bassoon5", "bassoon6", "bassoon7", "bassoon8"}
local function points(state, count)
    state.comboPoints = count
    state.emit("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
end
local function played(state, from)
    local keys = {}
    for index = from or 1, #state.played do keys[#keys + 1] = state.played[index].key end
    return table.concat(keys, ",")
end
test("combo point chimes: a rising note per point, the held high note at five, in order; a spend sound", function()
    local state = fixture({class = "ROGUE", newerSounds = SOUNDS, comboSet = "sax"})
    for count = 1, 5 do
        points(state, count)
        state.advance(0.2)
    end
    equal(played(state), "sax1,sax2,sax3,sax4,sax8", "points 1-4, then full")
    local before = #state.played
    points(state, 0)
    equal(played(state, before + 1), "", "spent with no finisher seen: it waits the target-change window")
    state.advance(0.3)
    equal(played(state, before + 1), "sax1", "spent: low Bb")
    state.advance(0.2)
    before = #state.played
    points(state, 2)
    equal(played(state, before + 1), "sax1", "a jump of two: the first note at once")
    state.advance(0.13)
    equal(played(state, before + 1), "sax1,sax2", "the second one gap later, queued")
    state.advance(0.2)
    before = #state.played
    points(state, 1)
    equal(#state.played, before, "one point fading out of combat: silent")
    state.combat = true
    points(state, 0)
    state.advance(0.3)
    equal(played(state, before + 1), "sax1", "one point spent in combat: the spend sound")
    state.combat = false
    state.comboMax = 6
    before = #state.played
    points(state, 5)
    state.advance(1)
    points(state, 6)
    state.advance(1)
    equal(played(state, before + 1), "sax1,sax2,sax3,sax4,sax5,sax8", "a most of six: the most plays the held note")
    state.comboMax = nil
    points(state, 0)
    state.advance(0.3)
    state.settings.DBR_COMBO_ONLYFULL:SetValue(true)
    before = #state.played
    for count = 1, 5 do
        points(state, count)
        state.advance(0.2)
    end
    equal(played(state, before + 1), "sax8", "only when full")
    state.settings.DBR_COMBO_ONLYFULL:SetValue(false)
    state.settings.DBR_COMBO_NOTESET:SetValue("full")
    points(state, 0)
    state.advance(0.5)
    before = #state.played
    points(state, 1)
    equal(played(state, before + 1), "sax8", "without the scale: Full's sound for each point")
    state.advance(0.2)
    state.settings.DBR_COMBO_SPEND:SetValue(false)
    before = #state.played
    points(state, 0)
    state.advance(1)
    points(state, 3)
    state.advance(1)
    points(state, 0)
    equal(played(state, before + 1):find("sax1") == nil, true, "Spend off: no spend sound")
    state.settings.DBR_COMBO_ENABLED:SetValue(false)
    before = #state.played
    points(state, 2)
    equal(#state.played, before, "the section's switch off: silent")
    equal(state.row("DBR_COMBO_FULL").data.cbLabel, "Full")
    equal(state.row("DBR_COMBO_SPEND").data.cbLabel, "Spend")
end)

local function climb(state, from, to)
    for count = from, to do
        points(state, count)
        state.advance(0.6)
    end
end
test("combo point chimes, note sets: Bassoon by default, Sax, Same as Full; Full and Spend follow the set", function()
    local state = fixture({class = "ROGUE", newerSounds = SOUNDS})
    local row = state.row("DBR_COMBO_NOTESET")
    equal(row.kind, "dropdown")
    local labels = {}
    for _, choice in ipairs(row.choices()) do labels[#labels + 1] = choice.value .. "=" .. choice.label end
    equal(table.concat(labels, ","), "bassoon=Bassoon,sax=Sax,full=Same as Full")
    equal(state.dbr.db.combo.noteSet, "bassoon", "Bassoon is the default")
    equal(state.settings.DBR_COMBO_FULL_SOUND:GetValue(), "bassoon8")
    equal(state.settings.DBR_COMBO_SPEND_SOUND:GetValue(), "bassoon1")
    climb(state, 1, 5)
    equal(played(state), "bassoon1,bassoon2,bassoon3,bassoon4,bassoon8", "1-4 climb, 5 the held F")
    local before = #state.played
    points(state, 0)
    state.advance(0.6)
    equal(played(state, before + 1), "bassoon1", "spend: the low Bb")
    row.setting:SetValue("sax")
    equal(state.dbr.db.combo.fullSound .. "," .. state.dbr.db.combo.spendSound, "sax8,sax1",
        "Full and Spend follow the set")
    before = #state.played
    climb(state, 1, 5)
    points(state, 0)
    state.advance(0.6)
    equal(played(state, before + 1), "sax1,sax2,sax3,sax4,sax8,sax1", "Sax as in 1.6.0, its spend too")
    state.settings.DBR_COMBO_FULL_SOUND:SetValue("talent")
    row.setting:SetValue("bassoon")
    equal(state.dbr.db.combo.fullSound .. "," .. state.dbr.db.combo.spendSound, "talent,bassoon1",
        "a Full sound of your own stays; Spend follows")
    row.setting:SetValue("full")
    before = #state.played
    climb(state, 1, 3)
    points(state, 0)
    state.advance(0.6)
    equal(played(state, before + 1), "talent,talent,talent,bassoon1", "Same as Full: Full's sound per point")
    local secret = fixture({class = "ROGUE", newerSounds = SOUNDS, remove = {"GetComboPoints"}})
    secret.comboSecret = true
    secret.combat = true
    points(secret, 1)
    equal(played(secret), "bassoon3", "a secret count: the set's third note")
end)

test("combo point chimes, note sets: 1.6.0's settings repaired; an older Dyre's Sounds plays the sax", function()
    local function repaired(combo)
        local state = fixture({class = "ROGUE", newerSounds = SOUNDS, db = {combo = combo}})
        local saved = state.dbr.db.combo
        equal(saved.scale, nil, "the old switch is gone")
        return saved.noteSet .. "," .. saved.fullSound .. "," .. saved.spendSound
    end
    equal(repaired({scale = true, fullSound = "sax8", spendSound = "sax1"}), "bassoon,bassoon8,bassoon1",
        "1.6.0's defaults: the new default, Bassoon")
    equal(repaired({}), "bassoon,bassoon8,bassoon1", "nothing saved: Bassoon")
    equal(repaired({scale = true, fullSound = "talent", spendSound = "sax1"}), "sax,talent,sax1",
        "a Full sound of your own: Sax kept")
    equal(repaired({scale = false, fullSound = "sax8", spendSound = "sax1"}), "full,bassoon8,bassoon1",
        "the switch off: Same as Full")
    equal(repaired({scale = false, fullSound = "talent"}), "full,talent,bassoon1", "off, with your own Full")
    equal(repaired({noteSet = "sax", fullSound = "sax8", spendSound = "sax1"}), "sax,sax8,sax1", "a set stays")
    equal(repaired({noteSet = "kazoo"}), "bassoon,bassoon8,bassoon1", "an unknown set: the default")
    local older = fixture({class = "ROGUE", newerSounds = SAX})
    climb(older, 1, 5)
    points(older, 0)
    older.advance(0.6)
    equal(played(older), "sax1,sax2,sax3,sax4,sax8,sax1", "Dyre's Sounds 1.3.0: each bassoon note as its sax note")
    older.slash("debug")
    contains(older.find("debug combo history"), "play bassoon1 as sax1")
    local oldest = fixture({class = "ROGUE"})
    points(oldest, 1)
    equal(played(oldest), "talent", "no sax either: the chimes' default")
end)

test("combo point chimes, a Druid on Era: Cat Form by ID or by spell, the first point after shifting, either count", function()
    local byID = fixture({class = "DRUID", newerSounds = SOUNDS, comboSet = "sax"})
    byID.formID = 1
    points(byID, 1)
    equal(played(byID), "sax1", "Cat Form by its ID (1), with no shift event first: the first point plays")
    local bySpell = fixture({class = "DRUID", newerSounds = SOUNDS, comboSet = "sax"})
    bySpell.formID = 0
    bySpell.form = 2
    bySpell.emit("UPDATE_SHAPESHIFT_FORM")
    points(bySpell, 1)
    equal(played(bySpell), "sax1", "Cat Form by its spell, though the ID reads otherwise")
    local late = fixture({class = "DRUID", newerSounds = SOUNDS, comboSet = "sax"})
    late.emit("UPDATE_SHAPESHIFT_FORM")
    late.formID = 1
    points(late, 1)
    equal(played(late), "sax1", "the shift event came before the form read as Cat: the first point still plays")
    late.advance(0.2)
    points(late, 2)
    equal(played(late), "sax1,sax2")
    local target = fixture({class = "DRUID", newerSounds = SOUNDS, comboSet = "sax"})
    target.formID = 1
    target.emit("UPDATE_SHAPESHIFT_FORM")
    target.targetCombo = 1
    points(target, 0)
    equal(played(target), "sax1", "UnitPower reads 0, GetComboPoints on the target 1: the target's counts")
    local frequent = fixture({class = "ROGUE", newerSounds = SOUNDS, comboSet = "sax"})
    frequent.comboPoints = 1
    frequent.emit("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
    frequent.emit("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
    equal(played(frequent), "sax1", "UNIT_POWER_FREQUENT counts; the matching UPDATE adds nothing")
    frequent.slash("debug")
    contains(frequent.find("debug combo"), "unitPower=1 getComboPoints=0")
    contains(frequent.find("debug combo"), "lastPowerEvent=UNIT_POWER_UPDATE COMBO_POINTS")
end)

test("combo point chimes, a Druid on Era: points that come with an Energy event; Energy ticks alone change nothing", function()
    local druid = fixture({class = "DRUID", newerSounds = SOUNDS, comboSet = "sax", comboTargetEvent = true})
    druid.formID = 1
    druid.emit("UPDATE_SHAPESHIFT_FORM")
    druid.emit("UNIT_POWER_FREQUENT", "player", "ENERGY")
    equal(#druid.played, 0, "an Energy tick, no points: silent")
    druid.comboPoints = 1
    druid.emit("UNIT_POWER_FREQUENT", "player", "ENERGY")
    equal(played(druid), "sax1", "Claw: the point came with the Energy event")
    druid.emit("UNIT_POWER_FREQUENT", "player", "ENERGY")
    druid.emit("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
    equal(played(druid), "sax1", "more Energy ticks and the matching combo event: nothing more")
    druid.advance(0.2)
    druid.comboPoints = 2
    druid.emit("PLAYER_TARGET_CHANGED")
    druid.emit("COMBO_TARGET_CHANGED")
    equal(played(druid), "sax1", "a target event takes the count quietly")
    druid.slash("debug")
    contains(druid.find("debug combo"), "lastPowerEvent=UNIT_POWER_UPDATE COMBO_POINTS")
    local forever = fixture({class = "ROGUE", newerSounds = SOUNDS, comboSet = "sax", remove = {"GetComboPoints"}})
    forever.comboSecret = true
    forever.combat = true
    forever.emit("UNIT_POWER_FREQUENT", "player", "ENERGY")
    equal(#forever.played, 0, "a secret count: an Energy tick plays no note")
    points(forever, 1)
    equal(played(forever), "sax3", "the combo event still plays the mid note")
end)

test("combo point chimes, an Era Druid in combat: every point's note with Energy events between; jumps queue all; the queue drains", function()
    local druid = fixture({class = "DRUID", newerSounds = SOUNDS, comboSet = "sax", comboTargetEvent = true})
    druid.formID = 1
    druid.emit("UPDATE_SHAPESHIFT_FORM")
    druid.combat = true
    druid.slash("debug")
    contains(druid.find("debug combo settings"), "full=true spend=true onlyFull=false noteSet=sax fullSound=sax8")
    for count = 1, 5 do
        druid.emit("UNIT_POWER_FREQUENT", "player", "ENERGY")
        druid.comboPoints = count
        druid.emit("UNIT_POWER_FREQUENT", "player", "ENERGY")
        druid.emit("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
        druid.emit("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
        druid.advance(1.5)
        druid.emit("UNIT_POWER_FREQUENT", "player", "ENERGY")
    end
    equal(played(druid), "sax1,sax2,sax3,sax4,sax8", "Claw by Claw: points 1-4 rise, 5 is the held high note")
    druid.cast(22568)
    druid.comboPoints = 0
    druid.emit("UNIT_POWER_FREQUENT", "player", "ENERGY")
    druid.advance(1)
    local before = #druid.played
    druid.comboPoints = 3
    druid.emit("UNIT_POWER_FREQUENT", "player", "ENERGY")
    equal(played(druid, before + 1), "sax1", "a jump of three: the first note at once")
    druid.advance(0.5)
    equal(played(druid, before + 1), "sax1,sax2,sax3", "then every queued note, none dropped")
    druid.messages = {}
    druid.slash("debug")
    contains(druid.find("debug combo settings"), "playing=false queued=0")
    local history = druid.find("debug combo history")
    contains(history, "UNIT_POWER_FREQUENT ENERGY 0>3 of 5")
    contains(history, "queue sax3 behind 2")
    contains(history, "play sax3")
    equal(select(2, history:gsub(" | ", "")), 7, "the last 8 actions only")
    -- A note whose Play errors does not stop the ones after it.
    local failing = fixture({class = "ROGUE", newerSounds = SOUNDS, comboSet = "sax"})
    failing.playFails = {sax1 = true}
    equal(pcall(points, failing, 2), false, "sax1's Play errors")
    failing.advance(0.5)
    equal(played(failing), "sax2", "the queue goes on to sax2")
    failing.playFails = nil
    failing.advance(1)
    points(failing, 3)
    equal(played(failing), "sax2,sax3", "and is not stuck")
end)

test("combo point chimes: a target switch is no spend (Era loses the points, Forever shows the new mob's); a finisher is", function()
    -- Era: the points are on you and a switch drops them; the power event
    -- may come before or after the target event.
    for _, order in ipairs({"before", "after"}) do
        local era = fixture({class = "ROGUE", newerSounds = SOUNDS, comboSet = "sax", comboTargetEvent = true})
        era.combat = true
        for count = 1, 3 do
            points(era, count)
            era.advance(0.2)
        end
        local before = #era.played
        if order == "before" then
            points(era, 0)
            era.advance(0.1)
            era.emit("PLAYER_TARGET_CHANGED")
        else
            era.emit("PLAYER_TARGET_CHANGED")
            era.advance(0.1)
            points(era, 0)
        end
        era.advance(1)
        equal(played(era, before + 1), "", "Era, the drop " .. order .. " the target event: no spend")
        points(era, 1)
        equal(played(era, before + 1), "sax1", "Era, " .. order .. ": the next point starts again at the first note")
    end
    -- Forever: the points stay on each mob; switching shows the new one's.
    local forever = fixture({class = "ROGUE", newerSounds = SOUNDS, comboSet = "sax"})
    forever.combat = true
    for count = 1, 3 do
        forever.targetCombo = count
        forever.emit("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
        forever.advance(0.2)
    end
    local before = #forever.played
    forever.targetCombo = 1
    forever.emit("PLAYER_TARGET_CHANGED")
    forever.emit("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
    forever.advance(1)
    equal(played(forever, before + 1), "", "to mob B with 1: silent")
    forever.targetCombo = 3
    forever.emit("PLAYER_TARGET_CHANGED")
    forever.emit("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
    forever.advance(1)
    equal(played(forever, before + 1), "", "back to mob A with 3: silent")
    forever.targetCombo = 4
    forever.emit("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
    equal(played(forever, before + 1), "sax4", "a gain on A plays the next note")
    -- A finisher just before a switch is a spend; with the cast first it
    -- plays at once, with the drop first when the cast comes.
    for _, order in ipairs({"cast first", "drop first"}) do
        local rogue = fixture({class = "ROGUE", newerSounds = SOUNDS, comboSet = "sax"})
        rogue.combat = true
        for count = 1, 3 do
            points(rogue, count)
            rogue.advance(0.2)
        end
        before = #rogue.played
        if order == "cast first" then
            rogue.cast(2098)
            points(rogue, 0)
            equal(played(rogue, before + 1), "sax1", "cast first: the spend at once")
        else
            points(rogue, 0)
            rogue.cast(2098)
            equal(played(rogue, before + 1), "sax1", "drop first: the spend when Eviscerate comes")
        end
        rogue.emit("PLAYER_TARGET_CHANGED")
        rogue.advance(1)
        equal(played(rogue, before + 1), "sax1", order .. ": one spend, though the target changed")
    end
end)

test("combo point chimes: a Druid only in Cat Form; a secret count, and an older Dyre's Sounds, fall back", function()
    local druid = fixture({class = "DRUID", newerSounds = SOUNDS, comboSet = "sax"})
    points(druid, 1)
    equal(#druid.played, 0, "not in Cat Form: silent")
    druid.formID = 1
    druid.emit("UPDATE_SHAPESHIFT_FORM")
    points(druid, 2)
    equal(played(druid), "sax2", "in Cat Form")
    druid.formID = nil
    druid.emit("UPDATE_SHAPESHIFT_FORM")
    points(druid, 0)
    equal(played(druid), "sax2", "shifted out: no spend for the fading points")
    local readable = fixture({class = "ROGUE", newerSounds = SOUNDS, comboSet = "sax"})
    readable.comboSecret = true
    readable.targetCombo = 1
    points(readable, 1)
    equal(played(readable), "sax1", "UnitPower secret but GetComboPoints readable: the readable one, as usual")
    local forever = fixture({class = "ROGUE", newerSounds = SOUNDS, comboSet = "sax", remove = {"GetComboPoints"}})
    forever.comboSecret = true
    forever.combat = true
    points(forever, 1)
    equal(played(forever), "sax3", "a secret count: one mid note per change")
    forever.advance(0.2)
    forever.cast(2098)
    equal(played(forever), "sax3,sax1", "your Eviscerate: the spend sound")
    forever.advance(0.2)
    forever.cast(1752)
    equal(played(forever), "sax3,sax1", "another spell: nothing")
    local older = fixture({class = "ROGUE"})
    points(older, 1)
    equal(older.played[1].key, "talent", "an older Dyre's Sounds without sax: the chimes' default")
    local target = fixture({class = "ROGUE", newerSounds = SOUNDS, comboSet = "sax"})
    points(target, 3)
    target.advance(1)
    local before = #target.played
    target.comboPoints = 0
    target.emit("PLAYER_TARGET_CHANGED")
    points(target, 0)
    equal(#target.played, before, "a new target (Classic keeps points on the target): no spend")
    local mage = fixture()
    equal(mage.row("DBR_COMBO_ENABLED"), nil, "not a Rogue or Druid: no section")
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
    rogue.dbr.db.casts.enabled = false -- Sprint's cast chime is tested on its own
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
    equal(state.headings[2].heading, "Chimes", "a Mage has no consumables; sizes sit in their sections")
    local switch, switchAt = state.row("DBR_CHIMES_ENABLED")
    equal(page.initializers[switchAt - 1], state.headings[2], "the section starts with its heading")
    local _, leadAt = state.row("DBR_LEAD")
    equal(leadAt < switchAt, true, "after the buff reminders")
    local lead = state.row("DBR_CHIME_LEAD")
    equal(lead.parentInitializer, switch)
    equal(lead.dyreDefault ~= nil, true, "the toolkit's gold default mark")
    equal(lead.dyreDefault.min, state.dbr.CHIME_LEAD_MIN)
    equal(lead.dyreDefault.max, state.dbr.CHIME_LEAD_MAX)
    equal(lead.dyreDefault.default, state.dbr.DEFAULT_CHIME_LEAD)
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
    equal(knight.headings[3].heading, "Your class has no chime spells yet.")
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
    local saved, first = SPELLS[12968], SPELLS[NATURES_GRACE]
    SPELLS[12968] = "Something Else"
    SPELLS[NATURES_GRACE] = nil
    local ok, message = pcall(function()
        local warrior = fixture({class = "WARRIOR"})
        warrior.settings.DBR_PROC_FLURRY:SetValue(true)
        equal(warrior.soundIDs(), "12966,12967,12969,12970", "a listed ID with another name is left out")
        warrior.slash("debug")
        contains(warrior.find("debug procs flurry"), "12968=Something Else")
        local state = fixture({class = "DRUID"})
        equal(state.soundIDs(), "", "an ID the client does not know is left out")
        state.buff("player", "Nature's Grace", {spellId = 990016})
        state.emit("UNIT_AURA", "player")
        equal(state.dbr.db.procs.learned.naturesgrace, 990016, "the English name is the fallback")
    end)
    SPELLS[12968], SPELLS[NATURES_GRACE] = saved, first
    equal(ok, true, tostring(message))
end)
test("procs: a client in another language registers and reads the buff by its own name", function()
    local french = {[DRUID_CLEARCASTING] = "Idées claires", [SHADOW_TRANCE] = "Transe de l'ombre",
        [NATURES_GRACE] = "Grâce de la nature"}
    local saved = {}
    for id, text in pairs(french) do
        saved[id] = SPELLS[id]
        SPELLS[id] = text
    end
    local ok, message = pcall(function()
        local warlock = fixture({class = "WARLOCK"})
        warlock.settings.DBR_PROC_NIGHTFALL:SetValue(true)
        equal(warlock.soundIDs(), tostring(SHADOW_TRANCE), "Nightfall registers under its French name")
        warlock.buff("player", "Transe de l'ombre", {spellId = 990018})
        warlock.emit("UNIT_AURA", "player")
        equal(warlock.dbr.db.procs.learned.nightfall, 990018, "read by its French name")
        local druid = fixture({class = "DRUID"})
        druid.settings.DBR_PROC_DRUIDCLEARCASTING:SetValue(true)
        equal(druid.soundIDs(), DRUID_CLEARCASTING .. "," .. NATURES_GRACE)
        druid.buff("player", "Idées claires", {spellId = 990017})
        druid.emit("UNIT_AURA", "player")
        equal(druid.dbr.db.procs.learned.druidclearcasting, 990017, "Clearcasting read by its French name")
        equal(druid.soundIDs(), DRUID_CLEARCASTING .. "," .. NATURES_GRACE .. ",990017")
    end)
    for id in pairs(french) do SPELLS[id] = saved[id] end
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
    equal(table.concat(headings, "|"), "Reminders|Chimes|Procs|Cast Chimes|Combo Point Chimes",
        "no Consumables before Rebirth; Combo Point Chimes last")
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
-- Proc cues in Dyre's Toolkit (2.11.0; John, 2026-11-18): a class Tools AddOn plays
-- its procs with arcs and a sound, so DBR steps aside for those procs.
local function procRowLive(state, variable)
    local row = state.row(variable)
    local live = true
    for _, predicate in ipairs(row.modifyPredicates or {}) do
        live = live and predicate()
    end
    return row, live
end
local function procTooltip(row)
    local tooltip = row.data and row.data.cbTooltip or row.tooltip
    if type(tooltip) == "function" then
        return tooltip()
    end
    return tooltip
end
local function nightfallOn(options)
    options = options or {}
    options.class = "WARLOCK"
    options.db = {procs = {spells = {nightfall = true}}}
    return fixture(options)
end
test("procs: a proc another Dyre's AddOn plays through the toolkit's proc engine: no DBR sound, row greyed", function()
    local state = nightfallOn({procClaims = {nightfall = "WarlockToolsForever"}})
    equal(state.toolkit.KindOwner("proc:nightfall"), "WarlockToolsForever")
    equal(state.dbr.ProcOwner(state.dbr.ClassProcs("WARLOCK")[1]), "WarlockToolsForever")
    equal(state.soundIDs(), "", "no aura sound from DBR: one sound per proc")
    equal(state.auraSoundCount, 0, "never registered")
    local row, live = procRowLive(state, "DBR_PROC_NIGHTFALL")
    equal(live, false, "its row is greyed")
    contains(procTooltip(row), "Warlock Tools Forever plays this sound now")
    -- The switch still saves, and still registers nothing.
    state.settings.DBR_PROC_NIGHTFALL:SetValue(false)
    state.settings.DBR_PROC_NIGHTFALL:SetValue(true)
    equal(state.dbr.db.procs.spells.nightfall, true)
    equal(state.auraSoundCount, 0, "no registration from the settings either")
    -- Not learned either: the buff on you out of combat.
    state.buff("player", "Shadow Trance", {spellId = 990017})
    state.update("UNIT_AURA", "player")
    equal(state.dbr.db.procs.learned.nightfall, nil, "nothing to learn for a proc DBR does not play")
    state.slash("debug")
    contains(state.find("debug procs nightfall"), "owner=WarlockToolsForever")
    contains(state.find("debug procs nightfall"), "registered=none")
    -- DBR's own claim (none today) is no yield.
    local own = nightfallOn()
    equal(own.toolkit.ClaimOwner("proc:nightfall", "DyresBuffReminders", 10), true)
    equal(own.toolkit.KindOwner("proc:nightfall"), "DyresBuffReminders")
    equal(own.dbr.ProcOwner(own.dbr.ClassProcs("WARLOCK")[1]), nil, "DBR's own claim: DBR plays")
    equal(own.soundIDs(), tostring(SHADOW_TRANCE))
    own.buff("player", "Shadow Trance", {spellId = 990017})
    own.update("UNIT_AURA", "player")
    equal(own.dbr.db.procs.learned.nightfall, 990017, "DBR plays it, so it learns its ID")
    own.slash("debug")
    contains(own.find("debug procs nightfall"), "owner=none")
    -- Only the claimed proc yields: a Druid with only Clearcasting claimed.
    local druid = fixture({class = "DRUID", db = {procs = {spells = {druidclearcasting = true}}},
        procClaims = {druidclearcasting = "MageToolsForever"}})
    equal(druid.soundIDs(), tostring(NATURES_GRACE), "Nature's Grace still DBR's; Clearcasting yields")
    local _, naturesLive = procRowLive(druid, "DBR_PROC_NATURESGRACE")
    equal(naturesLive, true)
    contains(procTooltip(druid.row("DBR_PROC_DRUIDCLEARCASTING")), "Mage Tools Forever plays this sound now")
end)
test("procs: a claim after DBR's login yields out of combat, after combat in it; a release plays again, once", function()
    local state = nightfallOn()
    equal(state.soundIDs(), tostring(SHADOW_TRANCE), "no claim: DBR plays Nightfall")
    local row, live = procRowLive(state, "DBR_PROC_NIGHTFALL")
    equal(live, true, "no claim: the row works")
    equal(procTooltip(row):find("plays this sound now", 1, true), nil)
    equal(state.claimProc("nightfall"), true)
    equal(state.soundIDs(), "", "claimed later (the class AddOn's own login): DBR steps aside")
    _, live = procRowLive(state, "DBR_PROC_NIGHTFALL")
    equal(live, false, "and greys its row")
    state.toolkit.SetOwnerEnabled("proc:nightfall", "WarlockToolsForever", false)
    equal(state.soundIDs(), tostring(SHADOW_TRANCE), "released: DBR plays again")
    local count = 0
    for _ in pairs(state.auraSounds) do count = count + 1 end
    equal(count, 1, "one registration, not two")
    -- In combat: the change waits for the end of combat.
    state.combat = true
    state.toolkit.SetOwnerEnabled("proc:nightfall", "WarlockToolsForever", true)
    equal(state.soundIDs(), tostring(SHADOW_TRANCE), "in combat: no aura sound change")
    state.combat = false
    state.emit("PLAYER_REGEN_ENABLED")
    equal(state.soundIDs(), "", "after combat: stepped aside")
    -- During an encounter it waits for its end, as every proc sound change.
    state.toolkit.SetOwnerEnabled("proc:nightfall", "WarlockToolsForever", false)
    equal(state.soundIDs(), tostring(SHADOW_TRANCE))
    state.encounter = true
    state.toolkit.SetOwnerEnabled("proc:nightfall", "WarlockToolsForever", true)
    equal(state.soundIDs(), tostring(SHADOW_TRANCE), "no change during an encounter")
    state.encounter = false
    state.emit("ADDON_RESTRICTION_STATE_CHANGED")
    equal(state.soundIDs(), "", "after it")
end)
test("procs: an older toolkit (no proc engine) and reactive abilities never step aside", function()
    local older = nightfallOn({toolkitBefore211 = true})
    equal(older.toolkit.PROC_KIND_PREFIX, nil, "no Procs.lua")
    older.toolkit.ClaimOwner("proc:nightfall", "WarlockToolsForever", 10)
    equal(older.dbr.ProcOwner(older.dbr.ClassProcs("WARLOCK")[1]), nil, "a feature test: no prefix, no yield")
    equal(older.soundIDs(), tostring(SHADOW_TRANCE), "DBR plays, as before")
    local row, live = procRowLive(older, "DBR_PROC_NIGHTFALL")
    equal(live, true)
    equal(type(row.data and row.data.cbTooltip or row.tooltip), "string", "a plain tooltip")
    local noOwners = nightfallOn({toolkitBefore29 = true, toolkitBefore211 = true})
    equal(noOwners.soundIDs(), tostring(SHADOW_TRANCE), "no Owners either: DBR plays")
    local warrior = fixture({class = "WARRIOR", procClaims = {overpower = "WarlockToolsForever"}})
    local overpower
    for _, proc in ipairs(warrior.dbr.ClassProcs("WARRIOR")) do
        if proc.key == "overpower" then overpower = proc end
    end
    equal(warrior.dbr.ProcOwner(overpower), nil, "a reactive ability is no aura: never steps aside")
    local _, overLive = procRowLive(warrior, "DBR_PROC_OVERPOWER")
    equal(overLive, true)
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
            equal(type(proc.label), "string", proc.key)
            equal(type(proc.on), "boolean", proc.key)
            if proc.reactive then
                equal(type(proc.reactive), "number", proc.key .. " is a spell ID")
            else
                equal(type(proc.buff), "string", proc.key)
                equal(#proc.spells > 0, true, proc.key)
            end
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
    local bar = state.widget("arcaneIntellect")
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
    equal(table.concat(keys, ","), "buff_righteousFury,warnings,seal",
        "a Paladin has no consumables; its warnings' message box is a widget")
    local fury, seal = state.icon("righteousFury"), state.env.DyresBuffRemindersSeal
    equal(fury.scripts.OnMouseWheel, nil, "no wheel resize of DBR's own")
    equal(seal.scripts.OnMouseWheel, nil)
    equal(type(seal.scripts.OnDragStart), "function", "the toolkit's drag (hooked only to keep a Ctrl move's mouse)")
    equal(seal.dyre.store, state.dbr.db.seal, "saved under the keys it had")
    equal(state.widget("righteousFury").dyre.store, state.dbr.db.buffs.righteousFury)
end)

-- The aspect bar (1.8.0) ------------------------------------------------------------------

local VIPER, HAWK_TBC, WILD_TBC = 34074, 27044, 27045
local ASPECT_ORDER = {"hawk", "monkey", "viper", "beast", "wild", "cheetah", "pack"}
local function aspectButton(state, key) return state.env["DyresBuffRemindersAspect_" .. key] end
local function aspectBar(state) return state.env.DyresBuffRemindersAspectBar end
-- The shown buttons, left to right (or top to bottom), as keys.
local function shownAspects(state)
    local list = {}
    for _, key in ipairs(ASPECT_ORDER) do
        local button = aspectButton(state, key)
        if button.shown then
            local point = button.points[#button.points]
            -- DBR's own layout: TOP (a column) or LEFT (a row); Toolkit
            -- 2.18.0's: TOPLEFT, x for a row, -y for a column.
            list[#list + 1] = {key = key, offset = (point[4] or 0) - (point[5] or 0), at = point[1],
                vertical = point[1] == "TOP" or (point[5] or 0) < 0}
        end
    end
    table.sort(list, function(a, b) return a.offset < b.offset end)
    local keys = {}
    for _, entry in ipairs(list) do keys[#keys + 1] = entry.key end
    return table.concat(keys, ","), list
end
local function glowing(state)
    local keys = {}
    for _, key in ipairs(ASPECT_ORDER) do
        if aspectButton(state, key).glow:GetAlpha() == 1 then keys[#keys + 1] = key end
    end
    return table.concat(keys, ",")
end
local function aspectBarOn(state)
    state.settings.DBR_ASPECT_BAR:SetValue(true)
end
-- Toolkit 2.18.0's button bars (BAR_LAYOUT_VERSION 1): its Layout row;
-- before it, DBR's own Vertical.
local LAYOUT_ROW = "DYRE_DYRESBUFFREMINDERS_ASPECTBAR_ORIENTATION"
local function barLayout(state)
    return type(state.toolkit.BAR_LAYOUT_VERSION) == "number" and state.toolkit.BAR_LAYOUT_VERSION >= 1
end
local function setVertical(state, value)
    if barLayout(state) then
        state.settings[LAYOUT_ROW]:SetValue(value and "vertical" or "horizontal")
    else
        state.settings.DBR_ASPECT_BAR_VERTICAL:SetValue(value)
    end
end

test("Aspect bar: a new Hunter gets it on; other classes get no bar, sample, or settings", function()
    -- A new character: no saved settings at all (John: "make it on by default for hunters").
    local state = hunterFixture({known = {[HAWK] = true, [MONKEY] = true}})
    equal(state.dbr.db.aspectBar.enabled, true, "on at first for a Hunter")
    equal(aspectBar(state).shown, true, "shown at login")
    equal(shownAspects(state), "hawk,monkey")
    equal(aspectButton(state, "hawk").attributes.macrotext1, "/use !Aspect of the Hawk", "armed at login")
    equal(state.row("DBR_ASPECT_BAR").setting.default, true, "the setting's default")
    equal(state.row("DBR_ASPECT_BAR").setting:GetValue(), true)
    -- Off stays off: a saved false is kept.
    local off = hunterFixture({db = {aspectBar = {enabled = false}}})
    equal(off.dbr.db.aspectBar.enabled, false, "a saved off stays off")
    equal(aspectBar(off).shown, false)
    -- Other classes: no bar, no sample when unlocked, no settings rows.
    for _, class in ipairs({"PALADIN", "WARRIOR", "MAGE", "ROGUE"}) do
        local other = fixture({class = class})
        other.slash("unlock")
        equal(other.env.DyresBuffRemindersAspectBar, nil, class .. ": no bar")
        equal(other.env.DyresBuffRemindersAspect_hawk, nil, class .. ": no sample")
        equal(other.row("DBR_ASPECT_BAR"), nil, class .. ": no Enable row")
        equal(other.row("DBR_ASPECT_BAR_VERTICAL"), nil, class .. ": no Vertical row")
        equal(other.row(LAYOUT_ROW), nil, class .. ": no Layout row")
        equal(other.row("DYRE_DYRESBUFFREMINDERS_ASPECTBAR_SCALE"), nil, class .. ": no size row")
        for _, heading in ipairs(other.headings) do
            equal(heading.heading ~= "Aspect bar", true, class .. ": no heading")
        end
    end
end)

test("Aspect bar: a button per aspect you know, in order, each casting /use !Name", function()
    local state = hunterFixture({known = {[HAWK] = true, [14318] = true, [MONKEY] = true, [CHEETAH] = true,
        [PACK] = true}})
    local frame = aspectBar(state)
    state.settings.DBR_ASPECT_BAR:SetValue(false)
    equal(frame.shown, false, "off: hidden")
    equal(aspectButton(state, "hawk").attributes.macrotext1, nil, "off: no click")
    aspectBarOn(state)
    equal(frame.shown, true)
    equal(shownAspects(state), "hawk,monkey,cheetah,pack", "combat aspects first; unknown ones hidden")
    equal(aspectButton(state, "hawk").attributes.macrotext1, "/use !Aspect of the Hawk", "by name: every rank")
    equal(aspectButton(state, "hawk").attributes.type1, "macro")
    equal(aspectButton(state, "hawk").texture.texture, 2000 + 14318, "the highest known rank's picture")
    equal(aspectButton(state, "pack").attributes.macrotext1, "/use !Aspect of the Pack")
    equal(aspectButton(state, "viper").attributes.macrotext1, nil, "not known: no click")
    equal(frame.dyre.contentWidth, 4 * 36 + 3 * 4, "the bar fits its buttons")
    equal(frame.dyre.contentHeight, 36)
    state.secureClick(aspectButton(state, "monkey"))
    equal(state.clicked[#state.clicked], "/use !Aspect of the Monkey")
    -- Viper and the TBC ranks are data: known, they show in their place.
    local tbc = hunterFixture({known = {[HAWK_TBC] = true, [VIPER] = true, [WILD_TBC] = true, [BEAST] = true},
        db = {aspectBar = {enabled = true}}})
    equal(shownAspects(tbc), "hawk,viper,beast,wild")
    equal(aspectButton(tbc, "viper").attributes.macrotext1, "/use !Aspect of the Viper")
    -- Saved settings are repaired; another class has no bar and no section.
    local repaired = hunterFixture({db = {aspectBar = {enabled = "yes", vertical = 1, position = "x"}}})
    equal(repaired.dbr.db.aspectBar.enabled, true, "damaged: back to on")
    equal(repaired.dbr.db.aspectBar.orientation, nil, "a damaged vertical: horizontal")
    equal(repaired.dbr.db.aspectBar.vertical, nil, "the old key is dropped")
    equal(type(repaired.dbr.db.aspectBar.position), "table", "a damaged place: the toolkit's default")
    equal(repaired.dbr.db.aspectBar.position.y, 400 + 72, "its default place, as the toolkit saves it")
    local paladin = fixture({class = "PALADIN", known = {[25780] = true}})
    equal(paladin.env.DyresBuffRemindersAspectBar, nil, "no bar for a Paladin")
    equal(paladin.row("DBR_ASPECT_BAR"), nil, "no section for a Paladin")
end)

test("Aspect bar: a gold border on the aspect that is up, from the aura out of combat and own casts in combat",
    function()
    local state = hunterFixture()
    aspectBarOn(state)
    equal(glowing(state), "", "no aspect up")
    state.buff("player", "Aspect of the Hawk")
    state.update("UNIT_AURA", "player")
    equal(glowing(state), "hawk")
    -- In combat auras are refused (the mock raises an error on a read): the
    -- player's own cast moves the border.
    enterCombat(state)
    state.update("UNIT_AURA", "player")
    state.cast(CHEETAH)
    equal(glowing(state), "cheetah", "own cast in combat")
    state.cast(BLINK)
    equal(glowing(state), "cheetah", "not an aspect: no change")
    state.emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", state.secret())
    equal(glowing(state), "cheetah", "a secret spell ID: unknown, no change")
    -- After combat the aura decides again.
    state.units.player.buffs = {["Aspect of the Monkey"] = true}
    leaveCombat(state)
    equal(glowing(state), "monkey", "after combat: the aura")
    -- A secret aura is unknown: the border stays.
    state.units.player.secretAuras = true
    state.update("UNIT_AURA", "player")
    equal(glowing(state), "monkey", "secret: the border stays")
    state.units.player.secretAuras = nil
    state.units.player.buffs = {}
    state.update("UNIT_AURA", "player")
    equal(glowing(state), "", "no aspect up: no border")
    -- The tooltip: the name and what a click does.
    state.buff("player", "Aspect of the Hawk")
    state.update("UNIT_AURA", "player")
    local text = tooltip(state, aspectButton(state, "hawk"))
    contains(text, "Aspect of the Hawk|It is up now.")
    contains(text, "Click: cast Aspect of the Hawk. A click never turns an aspect off.")
    state.slash("debug")
    contains(state.find("debug aspectBar"), "on=true vertical=false known=hawk,monkey,cheetah,pack active=hawk")
end)

test("Aspect bar: rebuilt only out of combat; a newly learned aspect or rank waits for combat to end", function()
    local state = hunterFixture({known = {[HAWK] = true, [MONKEY] = true}, db = {aspectBar = {enabled = true}}})
    equal(shownAspects(state), "hawk,monkey")
    enterCombat(state)
    -- The mock raises an error on any secure change in combat.
    state.known[WILD] = true
    state.known[14318] = true
    state.update("SPELLS_CHANGED")
    equal(shownAspects(state), "hawk,monkey", "in combat: nothing changes")
    equal(aspectButton(state, "wild").attributes.macrotext1, nil)
    setVertical(state, true)
    leaveCombat(state)
    equal(shownAspects(state), "hawk,monkey,wild", "after combat: the new aspect, in its place")
    equal(aspectButton(state, "wild").attributes.macrotext1, "/use !Aspect of the Wild")
    equal(aspectButton(state, "hawk").texture.texture, 2000 + 14318, "the new rank's picture")
    local _, list = shownAspects(state)
    equal(list[3].vertical, true, "vertical, set in combat, applies after it")
    equal(list[3].offset, 2 * 40)
    equal(aspectBar(state).dyre.contentWidth, 36)
    equal(aspectBar(state).dyre.contentHeight, 3 * 36 + 2 * 4)
    -- A reload in combat: the bar is made only once combat ends.
    local reload = hunterFixture({combat = true, db = {aspectBar = {enabled = true}}})
    equal(reload.env.DyresBuffRemindersAspectBar, nil, "not made in combat")
    leaveCombat(reload)
    equal(shownAspects(reload), "hawk,monkey,cheetah,pack", "made after combat")
end)

test("Aspect bar: hidden while dead or on a flight path, shown while mounted; unlocked it never casts", function()
    local state = hunterFixture({db = {aspectBar = {enabled = true}}})
    local frame = aspectBar(state)
    equal(frame.shown, true)
    state.taxi = true
    state.update("PLAYER_CONTROL_LOST")
    equal(frame.shown, false, "on a flight path")
    state.taxi = false
    state.update("PLAYER_CONTROL_GAINED")
    equal(frame.shown, true, "landed")
    state.units.player.dead = true
    state.update("PLAYER_DEAD")
    equal(frame.shown, false, "dead")
    state.units.player.dead = false
    state.update("PLAYER_ALIVE")
    equal(frame.shown, true, "alive")
    state.mounted = true
    state.update("PLAYER_ENTERING_WORLD")
    equal(frame.shown, true, "mounted: shown")
    state.slash("unlock")
    equal(frame.shown, true)
    equal(aspectButton(state, "hawk").attributes.macrotext1, nil, "unlocked: dragging must not cast")
    contains(tooltip(state, aspectButton(state, "hawk")), "Drag to move the aspect bar.")
    state.slash("lock")
    equal(aspectButton(state, "hawk").attributes.macrotext1, "/use !Aspect of the Hawk", "locked again")
    -- No aspect yet: nothing locked, one sample unlocked to place the bar.
    local fresh = hunterFixture({known = {}, db = {aspectBar = {enabled = true}}})
    equal(aspectBar(fresh).shown, false, "no aspect: nothing")
    fresh.slash("unlock")
    equal(aspectBar(fresh).shown, true)
    equal(shownAspects(fresh), "hawk", "a sample to place")
    equal(aspectButton(fresh, "hawk").attributes.macrotext1, nil)
end)

test("Aspect bar: an aspect learned in combat shows after it, with no other change", function()
    local state = hunterFixture({known = {[HAWK] = true}, db = {aspectBar = {enabled = true}}})
    enterCombat(state)
    state.known[MONKEY] = true
    state.update("SPELLS_CHANGED")
    equal(shownAspects(state), "hawk", "in combat: nothing changes")
    leaveCombat(state)
    equal(shownAspects(state), "hawk,monkey", "after combat: the new aspect")
    equal(aspectButton(state, "monkey").attributes.macrotext1, "/use !Aspect of the Monkey")
end)

-- John, 2026-11-27: button bars horizontal or vertical are a Toolkit feature
-- (2.18.0); DBR's own Vertical moves onto it, its saved choice once.
test("Aspect bar layout: DBR 1.14's Vertical moves once to the toolkit's orientation; the Layout row", function()
    local moved = hunterFixture({known = {[HAWK] = true, [MONKEY] = true, [CHEETAH] = true},
        db = {aspectBar = {enabled = true, vertical = true}}})
    local saved = moved.dbr.db.aspectBar
    equal(saved.orientation, "vertical", "the saved choice moves")
    equal(saved.vertical, nil, "the old key is dropped")
    local _, list = shownAspects(moved)
    equal(list[3].vertical, true, "a column")
    equal(list[3].offset, 2 * 40)
    equal(aspectBar(moved).dyre.contentWidth, 36)
    equal(aspectBar(moved).dyre.contentHeight, 3 * 36 + 2 * 4)
    moved.slash("debug")
    contains(moved.find("debug aspectBar"), "vertical=true")
    -- Horizontal later stays horizontal (no second move).
    setVertical(moved, false)
    equal(saved.orientation, nil)
    local again = hunterFixture({known = {[HAWK] = true}, db = {aspectBar = saved}})
    equal(again.dbr.db.aspectBar.orientation, nil, "horizontal stays")
    _, list = shownAspects(moved)
    equal(list[3].vertical, false, "a row again")
    equal(list[3].offset, 2 * 40)
    equal(aspectBar(moved).dyre.contentWidth, 3 * 36 + 2 * 4)
    if barLayout(moved) then
        local row = moved.row(LAYOUT_ROW)
        equal(row.setting.name, "Layout")
        equal(moved.row("DBR_ASPECT_BAR_VERTICAL"), nil, "no second row")
        equal(list[3].at, "TOPLEFT", "the toolkit lays the buttons out")
        equal(aspectBar(moved).dyre.lastAnchor, "TOPLEFT", "the top-left corner stays as it grows")
        moved.settings[LAYOUT_ROW]:SetValue("vertical")
        equal(saved.orientation, "vertical", "saved in the widget's store, DBR's aspectBar table")
        equal(moved.dbr.AspectBarVertical(), true)
        moved.settings.DBR_ASPECT_BAR:SetValue(false)
        local live = true
        for _, predicate in ipairs(row.modifyPredicates or {}) do live = live and predicate() end
        if row.parentInitializer then
            equal(row.parentInitializer, (moved.row("DBR_ASPECT_BAR")), "under Enable")
        else
            equal(live, false, "greyed while the bar is off")
        end
    else
        io.write("# Layout row: no BAR_LAYOUT_VERSION in ", TOOLKIT_DIR, "; DBR's own Vertical\n")
        equal(moved.row("DBR_ASPECT_BAR_VERTICAL").setting.name, "Vertical")
    end
end)

test("Aspect bar: its settings, and a default place clear of every other DBR widget", function()
    local all = {}
    for _, aspect in ipairs({HAWK, MONKEY, VIPER, BEAST, WILD, CHEETAH, PACK}) do all[aspect] = true end
    all[883] = true
    local state = hunterFixture({known = all, db = {aspectBar = {enabled = true}}})
    local _, enableIndex = state.row("DBR_ASPECT_BAR")
    local vertical, verticalIndex = state.row(barLayout(state) and LAYOUT_ROW or "DBR_ASPECT_BAR_VERTICAL")
    equal(verticalIndex, enableIndex + 1, "Layout (or Vertical) under Enable")
    equal(vertical.parentInitializer, (state.row("DBR_ASPECT_BAR")))
    local size = state.row("DYRE_DYRESBUFFREMINDERS_ASPECTBAR_SCALE")
    equal(size.setting.name, "Aspect bar: size")
    equal(state.row("DYRE_DYRESBUFFREMINDERS_ASPECTBAR_OPACITY").setting.name, "Aspect bar: opacity")
    equal(shownAspects(state), "hawk,monkey,viper,beast,wild,cheetah,pack")
    local function rect(widget)
        local x, y = widget:GetCenter()
        local scale = widget:GetEffectiveScale()
        local w, h = widget:GetWidth() * scale / 2, widget:GetHeight() * scale / 2
        return {x * scale - w, y * scale - h, x * scale + w, y * scale + h}
    end
    local function clear(widgets)
        for i = 1, #widgets do
            for j = i + 1, #widgets do
                local a, b = rect(widgets[i]), rect(widgets[j])
                local overlap = a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
                equal(overlap, false, widgets[i].dyre.widgetKey .. " and " .. widgets[j].dyre.widgetKey)
            end
        end
    end
    local widgets = state.toolkit.Widgets(ADDON)
    local keys = {}
    for _, widget in ipairs(widgets) do keys[#keys + 1] = widget.dyre.widgetKey end
    equal(table.concat(keys, ","), "buff_aspect,buff_hunterPet,warnings,consumables,aspectBar")
    clear(widgets)
    -- Vertical keeps the top edge, so it grows down, away from the reminders.
    setVertical(state, true)
    clear(widgets)
end)

-- The Aspect reminder (John, 1.8.0) -------------------------------------------------
local function aspectUp(state, name)
    state.units.player.buffs = name and {[name] = true} or {}
    state.update("UNIT_AURA", "player")
end
-- Shown, and red: the indicator.
local function indicator(icon)
    return icon.shown == true and icon.glow.shown == true and icon.glow:GetAlpha() == 1 and icon.alpha ~= 0.4
end
test("Aspect reminder, Normal: a red outline with no aspect up, and in combat with Cheetah or Pack up", function()
    local state, icon = hunterFixture()
    equal(state.dbr.db.aspectMode, "normal", "Normal at first")
    equal(state.widget("aspect").slot, nil, "no aura slot draws the aspect")
    equal(indicator(icon), true, "no aspect, out of combat: shown, red")
    equal(icon.glow.backdropBorder[1], 1, "red")
    equal(icon.glow.backdropBorder[2], 0.2)
    equal(icon.texture.texture, 2000 + HAWK, "the last combat aspect's icon, else Hawk")
    equal(icon.driver, "show")
    enterCombat(state)
    equal(indicator(icon), true, "no aspect, in combat: shown")
    leaveCombat(state)
    aspectUp(state, "Aspect of the Hawk")
    equal(icon.shown, false, "a combat aspect up: nothing shows")
    equal(icon.driver, "hide")
    enterCombat(state)
    equal(icon.shown, false, "nor in combat")
    leaveCombat(state)
    for _, name in ipairs({"Aspect of the Cheetah", "Aspect of the Pack"}) do
        aspectUp(state, name)
        equal(icon.shown, false, name .. " out of combat: travel, no indicator")
        equal(icon.driver, "[combat] show; hide", name .. ": the game shows it when combat starts")
        equal(icon.attributes.macrotext1, "/use !Aspect of the Hawk", "armed for the fight")
        enterCombat(state)
        equal(indicator(icon), true, name .. " in combat: shown, red")
        leaveCombat(state)
        equal(icon.shown, false, name .. ": hidden again after combat")
    end
    aspectUp(state, nil)
    state.cast(MONKEY)
    state.wait(1)
    equal(icon.texture.texture, 2000 + MONKEY, "the last combat aspect's icon")
end)
test("Aspect reminder, Speed-Running: Cheetah is fine in combat; no aspect or Pack still shows it", function()
    local state, icon = hunterFixture()
    state.settings.DBR_ASPECT_MODE:SetValue("speed")
    equal(state.dbr.db.aspectMode, "speed")
    equal(indicator(icon), true, "no aspect: shown")
    enterCombat(state)
    equal(indicator(icon), true, "no aspect in combat: shown")
    leaveCombat(state)
    aspectUp(state, "Aspect of the Cheetah")
    equal(icon.driver, "hide", "Cheetah: no indicator, in or out of combat")
    enterCombat(state)
    equal(icon.shown, false, "Cheetah in combat: fine")
    leaveCombat(state)
    aspectUp(state, "Aspect of the Pack")
    equal(icon.driver, "[combat] show; hide")
    enterCombat(state)
    equal(indicator(icon), true, "Pack in combat: shown")
    leaveCombat(state)
    aspectUp(state, "Aspect of the Monkey")
    enterCombat(state)
    equal(icon.shown, false, "a combat aspect: nothing")
end)
test("Aspect reminder, Disabled: it never shows; a saved switch off becomes Disabled", function()
    local state, icon = hunterFixture()
    state.settings.DBR_ASPECT_MODE:SetValue("off")
    equal(state.dbr.db.spells.aspect, false)
    equal(state.widget("aspect").shown, false, "no widget")
    equal(icon.shown, false)
    enterCombat(state)
    equal(icon.shown, false, "not in combat either")
    leaveCombat(state)
    aspectUp(state, "Aspect of the Pack")
    enterCombat(state)
    equal(icon.shown, false, "not with Pack in combat")
    leaveCombat(state)
    equal(state.row("DBR_COMBAT_ASPECT_SOUND_ON").predicate(), false, "its sound greyed out")
    state.slash("unlock")
    equal(icon.shown, false, "no sample")
    state.slash("lock")
    state.settings.DBR_ASPECT_MODE:SetValue("bogus")
    equal(state.dbr.db.aspectMode, "off", "an unknown mode changes nothing")
    local function mode(db) return fixture({class = "HUNTER", known = {[HAWK] = true}, db = db}).dbr.db end
    local off = mode({spells = {aspect = false}})
    equal(off.aspectMode, "off", "a saved Aspect switch off: Disabled")
    equal(off.spells.aspect, false)
    equal(mode({spells = {aspect = true}}).aspectMode, "normal", "on: Normal")
    equal(mode({}).aspectMode, "normal", "new: Normal")
    equal(mode({aspectMode = "x", spells = {aspect = false}}).aspectMode, "off", "damaged: from the switch")
    local speed = mode({aspectMode = "speed", spells = {aspect = false}})
    equal(speed.aspectMode, "speed", "a saved mode wins")
    equal(speed.spells.aspect, true, "and decides the switch")
    local sound = mode({combatAspect = {enabled = false, soundOn = false, sound = "magical"}}).combatAspect
    equal(sound.enabled, nil, "the combat aspect button's switch is dropped")
    equal(sound.soundOn, false)
    equal(sound.sound, "magical")
end)
test("Aspect reminder: the mode dropdown replaces the switch; the sound sits under it", function()
    local state = hunterFixture()
    local row = state.row("DBR_ASPECT_MODE")
    equal(row.setting.name, "Aspect")
    equal(row.parentInitializer, state.row("DBR_ENABLED"), "under Reminders' Enable")
    equal(state.row("DBR_BUFF_ASPECT"), nil, "no switch")
    equal(state.row("DBR_COMBAT_ASPECT"), nil, "no combat aspect button switch")
    local sound = state.row("DBR_COMBAT_ASPECT_SOUND_ON")
    equal(sound.parentInitializer, row, "the sound under the mode")
    equal(sound.predicate(), true)
    equal(state.env.DyresBuffRemindersCombatAspect, nil, "one widget: no combat aspect button")
    local keys = {}
    for _, widget in ipairs(state.toolkit.Widgets(ADDON)) do
        if widget.dyre.widgetKey:find("aspect", 1, true) then keys[#keys + 1] = widget.dyre.widgetKey end
    end
    equal(table.concat(keys, ","), "buff_aspect,aspectBar")
end)
test("Aspect reminder: its own size, 50-200%, default 100%; a size set before stays, with its place", function()
    local state, icon = hunterFixture()
    local holder = state.widget("aspect")
    local scale = state.row("DYRE_DYRESBUFFREMINDERS_BUFF_ASPECT_SCALE")
    equal(scale.setting.name, "Aspect reminder: size")
    equal(scale.options.minValue, 50)
    equal(scale.options.maxValue, 200)
    equal(holder.dyre.sizes.scale.default, 100)
    equal(holder.scale, 1, "100% at first")
    equal(state.row("DYRE_DYRESBUFFREMINDERS_BUFF_ASPECT_OPACITY").setting.name, "Aspect reminder: opacity")
    state.settings.DBR_BUFF_ICONS_SCALE:SetValue(150)
    equal(holder.scale, 1, "the shared size no longer changes it")
    equal(state.widget("hunterPet").scale, 1.5)
    state.settings.DYRE_DYRESBUFFREMINDERS_BUFF_ASPECT_SCALE:SetValue(300)
    equal(holder.scale, 2, "at most 200%")
    -- Its default place: the old one, in My buffs' row beside the Pet icon.
    local fresh = hunterFixture()
    local ax, ay = fresh.absCenter(fresh.widget("aspect"))
    local px, py = fresh.absCenter(fresh.widget("hunterPet"))
    equal(ay, py, "in My buffs' row")
    equal(px - ax, 60, "beside the Pet icon")
    -- A size set with the shared slider (150%) stays, so its place does too.
    local shared = hunterFixture({db = {buffs = {aspect = {scale = 150,
        position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 200, y = 100}}}}})
    equal(shared.dbr.db.buffs.aspect.scale, 150, "its own size starts at the size it had")
    local sx, sy = shared.absCenter(shared.widget("aspect"))
    equal(sx, 300, "its center stays on the same screen spot")
    equal(sy, 150)
    -- The 1.8.0 test build (warnScale 200, its place in those units, no scale): converted once to 100%.
    local test = hunterFixture({db = {buffs = {aspect = {warnScale = 200,
        position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 150, y = 100}}}}})
    local saved = test.dbr.db.buffs.aspect
    equal(saved.warnScale, nil, "the test build's size is dropped")
    equal(saved.scale, 100)
    equal(saved.position.x, 300, "in the new size's units")
    local tx, ty = test.absCenter(test.widget("aspect"))
    equal(tx, 300, "its center stays where it was")
    equal(ty, 200)
    equal(test.dbr.SanitizeDB(test.dbr.db).buffs.aspect.position.x, 300, "converted once only")
end)
test("Aspect reminder: a click casts the last combat aspect with the aspect bar on or off", function()
    for _, barOn in ipairs({true, false}) do
        local state, icon = hunterFixture({db = {aspectBar = {enabled = barOn}}})
        local label = barOn and "bar on: " or "bar off: "
        equal(icon.attributes.type1, "macro", label .. "a macro")
        equal(icon.attributes.macrotext1, "/use !Aspect of the Hawk", label .. "\"!\": never takes an aspect down")
        contains(tooltip(state, icon), "Click: Aspect of the Hawk on you.")
        contains(tooltip(state, icon), "No aspect is up.")
        state.slash("unlock")
        equal(icon.attributes.macrotext1, nil, label .. "unlocked: dragging never casts")
        equal(icon.shown, true, label .. "unlocked: the sample")
        contains(tooltip(state, icon), "Drag to move")
        state.slash("lock")
    end
    local cheetah = hunterFixture({known = {[CHEETAH] = true}})
    equal(cheetah.icon("aspect").attributes.macrotext1, nil, "only Cheetah known: nothing to cast")
    local bare, bareIcon = hunterFixture({noSecureWrap = true})
    equal(indicator(bareIcon), true, "without the secure wrap: still shown")
    equal(bareIcon.attributes.macrotext1, "/use !Aspect of the Hawk")
end)
test("Aspect reminder in combat: its own click hides it; an aspect bar click hides or shows it", function()
    local state, icon = hunterFixture()
    equal(state.wraps[icon].post, "self:Hide()")
    equal(state.drivers[icon], nil, "no visibility driver: the game's would show it again within 0.2 s")
    equal(icon.attributes["dbr-show"], "always")
    enterCombat(state)
    state.secureClick(icon)
    equal(state.clicked[1], "/use !Aspect of the Hawk")
    equal(icon.shown, false, "its own click hides it")
    state.tick()
    state.tick()
    equal(icon.shown, false, "and it stays hidden (John, 2026-11-14: it came back, dimmed, until combat ended)")
    leaveCombat(state)
    equal(indicator(icon), true, "still no aspect after combat: shown again")
    local hawk, pack, cheetah = aspectButton(state, "hawk"), aspectButton(state, "pack"), aspectButton(state, "cheetah")
    equal(hawk.attributes["frameref-dbrAspectReminder"], icon, "each bar button reaches the reminder")
    equal(state.wraps[hawk].header, icon)
    equal(hawk.attributes["dbr-reminder"], "hide")
    equal(pack.attributes["dbr-reminder"], "show")
    equal(cheetah.attributes["dbr-reminder"], "show", "Normal: Cheetah is a problem")
    enterCombat(state)
    state.secureClick(hawk)
    equal(icon.shown, false, "Hawk from the bar: hidden in secure code")
    state.tick()
    equal(icon.shown, false, "and it stays hidden")
    state.secureClick(pack)
    equal(icon.shown, true, "Pack from the bar: shown again")
    state.tick()
    equal(icon.shown, true, "and it stays shown")
    leaveCombat(state)
    state.secureClick(hawk)
    equal(icon.shown, true, "out of combat the bar click does nothing; the aura decides")
    state.settings.DBR_ASPECT_MODE:SetValue("speed")
    equal(cheetah.attributes["dbr-reminder"], "hide", "Speed-Running: Cheetah fixes it")
    state.settings.DBR_ASPECT_MODE:SetValue("off")
    equal(hawk.attributes["dbr-reminder"], nil, "Disabled: no role")
    state.settings.DBR_ASPECT_MODE:SetValue("normal")
    aspectUp(state, "Aspect of the Hawk")
    enterCombat(state)
    equal(icon.shown, false)
    equal(icon.attributes["dbr-show"], "never")
    state.secureClick(pack)
    equal(icon.shown, true, "hidden with Hawk up, then Pack from the bar: shown")
    state.units.player.buffs = {["Aspect of the Hawk"] = true}
    leaveCombat(state)
    equal(icon.shown, false, "after combat the aura decides")
end)
test("Aspect reminder: combat's start shows it for a travel aspect, and its click then hides it for good", function()
    local state, icon = hunterFixture()
    aspectUp(state, "Aspect of the Cheetah")
    equal(icon.attributes["dbr-show"], "combat")
    equal(icon.shown, false, "Cheetah out of combat: travel, no problem")
    enterCombat(state)
    equal(icon.shown, true, "combat starts with Cheetah up: shown by the combat edge")
    state.tick()
    equal(icon.shown, true)
    state.secureClick(icon)
    state.tick()
    equal(icon.shown, false, "its click hides it, and no update shows it again")
    state.combat = false
    state.tick()
    equal(icon.shown, false, "combat's end with mode combat: hidden")
end)
test("Aspect reminder in combat: a cast from elsewhere dims it, never to invisible", function()
    local state, icon = hunterFixture()
    enterCombat(state)
    state.cast(MONKEY)
    equal(icon.alpha, 0.4, "a combat aspect from the action bar dims it")
    equal(icon.glow:GetAlpha(), 0, "and takes the red outline away")
    equal(icon.shown, true, "still where it takes clicks")
    equal(icon.alpha ~= 0, true, "never alpha 0")
    equal(icon.attributes.macrotext1, "/use !Aspect of the Hawk", "no secure change in combat")
    state.cast(BLINK)
    equal(icon.alpha, 0.4, "not an aspect: no change")
    state.emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", state.secret())
    equal(icon.alpha, 0.4, "a secret spell ID: no change")
    state.cast(PACK)
    equal(indicator(icon), true, "Pack: a problem again, solid and red")
    state.cast(HAWK)
    equal(icon.alpha, 0.4)
    state.units.player.buffs = {["Aspect of the Hawk"] = true}
    leaveCombat(state)
    equal(icon.shown, false, "after combat: hidden")
    equal(icon.alpha, 1, "reset")
    equal(icon.glow:GetAlpha(), 1)
end)
test("Aspect reminder: the sound plays only when combat starts with a problem", function()
    local state = hunterFixture()
    enterCombat(state)
    equal(state.played[1].speech, "No aspect up", "no aspect")
    equal(state.played[1].key, "talent", "the default sound")
    leaveCombat(state)
    aspectUp(state, "Aspect of the Cheetah")
    enterCombat(state)
    equal(state.played[2].speech, "Aspect of the Cheetah is up")
    leaveCombat(state)
    aspectUp(state, "Aspect of the Hawk")
    enterCombat(state)
    equal(#state.played, 2, "a combat aspect: no sound")
    leaveCombat(state)
    state.settings.DBR_ASPECT_MODE:SetValue("speed")
    aspectUp(state, "Aspect of the Cheetah")
    enterCombat(state)
    equal(#state.played, 2, "Speed-Running with Cheetah: no sound")
    leaveCombat(state)
    state.settings.DBR_COMBAT_ASPECT_SOUND:SetValue("magical")
    equal(state.played[#state.played].key, "magical", "choosing a sound plays it")
    equal(state.played[#state.played].speech, "Aspect of the Cheetah is up")
    local before = #state.played
    aspectUp(state, "Aspect of the Pack")
    enterCombat(state)
    equal(state.played[#state.played].key, "magical")
    equal(#state.played, before + 1)
    leaveCombat(state)
    state.settings.DBR_COMBAT_ASPECT_SOUND_ON:SetValue(false)
    before = #state.played
    enterCombat(state)
    equal(#state.played, before, "sound switched off")
end)
test("Aspect reminder: the sound's preview says the Cheetah's name in the client's language", function()
    local saved = SPELLS[CHEETAH]
    local ok, message = pcall(function()
        SPELLS[CHEETAH] = "Aspect du guépard"
        local state = hunterFixture()
        state.settings.DBR_COMBAT_ASPECT_SOUND:SetValue("magical")
        equal(state.played[#state.played].speech, "Aspect du guépard is up")
        SPELLS[CHEETAH] = nil
        state.settings.DBR_COMBAT_ASPECT_SOUND:SetValue("talent")
        equal(state.played[#state.played].speech, "Aspect of the Cheetah is up", "the English name without one")
    end)
    SPELLS[CHEETAH] = saved
    equal(ok, true, tostring(message))
end)
test("Aspect reminder: hidden while dead or on a taxi; debug; a secret aura changes nothing", function()
    local state, icon = hunterFixture()
    state.units.player.dead = true
    state.update("PLAYER_DEAD")
    equal(icon.shown, false, "dead: hidden")
    equal(icon.attributes.macrotext1, nil)
    state.units.player.dead = false
    state.update("PLAYER_ALIVE")
    equal(indicator(icon), true)
    state.taxi = true
    state.update("PLAYER_CONTROL_LOST")
    equal(icon.shown, false, "on a flight path: hidden")
    state.taxi = false
    state.update("PLAYER_CONTROL_GAINED")
    equal(indicator(icon), true)
    state.clear()
    state.slash("debug")
    contains(state.find("debug aspectReminder"), "mode=normal state=none problem=now driver=show "
        .. "macro=/use !Aspect of the Hawk sound=talent")
    aspectUp(state, "Aspect of the Hawk")
    state.units.player.secretAuras = true
    state.update("UNIT_AURA", "player")
    equal(icon.shown, false, "a secret read: the last state stays")
    state.units.player.secretAuras = nil
    aspectUp(state, nil)
    state.units.player.secretAuras = true
    state.update("UNIT_AURA", "player")
    equal(indicator(icon), true, "no aspect, then a secret read: still shown")
    state.units.player.secretAuras = nil
    equal(fixture({known = {[INTELLECT] = true}}).env.DyresBuffRemindersIcon_aspect, nil, "a Mage: none")
end)

-- Proc cues (1.13.0, Toolkit 2.12.0's proc engine 2) -----------------------------------------
-- Only beside ../DyresToolkit with engine 2 (HAS_PROC_ENGINE); the copy in
-- tests/toolkit (CI) has no Procs.lua, so there these say so and pass.
local NIGHTFALL_TALENT, OVERPOWER = 18094, 7384
local function engineTest(name, body)
    test(name, function()
        if not HAS_PROC_ENGINE then
            io.write("# skipped (no proc engine 2 in ", TOOLKIT_DIR, "): ", name, "\n")
            return
        end
        body()
    end)
end
local function cueRow(state, key, part)
    return state.row(("DYRE_DYRESBUFFREMINDERS_PROC_" .. key .. "_" .. part):upper())
end

engineTest("proc cues: with engine 2, DBR registers its procs at the home priority; Proc Chimes stay off", function()
    local state = fixture({class = "WARLOCK", procEngine = true, known = {[NIGHTFALL_TALENT] = true}})
    equal(state.dbr.procEngine, true, "decided at login")
    local handle = state.dbr.ProcCuesHandle()
    equal(type(handle), "table", "a handle for a Warlock")
    equal(state.toolkit.KindOwner("proc:nightfall"), "DyresBuffReminders")
    equal(state.dbr.db.procCues.arc.nightfall, true, "the arcs on by default")
    equal(state.dbr.db.procCues.sound.nightfall, false, "the sound off by default, as Proc Chimes")
    equal(state.soundIDs(), "", "no sound while it is off")
    equal(state.row("DBR_PROCS_ENABLED"), nil, "no Proc Chimes section")
    equal(type(cueRow(state, "nightfall", "arc")), "table", "the engine's arc row")
    state.settings.DYRE_DYRESBUFFREMINDERS_PROC_NIGHTFALL_SOUND:SetValue(true)
    equal(state.soundIDs(), "17941", "the engine registers Shadow Trance")
    equal(state.dbr.db.procs.spells.nightfall, false, "Proc Chimes' own settings are left as they were")
    state.clear()
    state.slash("debug")
    contains(state.find("debug procs engine="), "handle=true")
    contains(state.find("debug procs Nightfall"), "talent known")
end)

engineTest("proc cues: a Dyre's Shields Up 1.4 claim at 10 loses to DBR's 20", function()
    local state = fixture({class = "WARLOCK", procEngine = true, known = {[NIGHTFALL_TALENT] = true},
        procClaims = {nightfall = "DyresShieldsUp"}})
    equal(state.toolkit.KindOwner("proc:nightfall"), "DyresBuffReminders")
    local owns = state.dbr.ProcCuesHandle().Owns("nightfall")
    equal(owns, true)
end)

engineTest("proc cues: Overpower is one row with arcs and sound; the engine plays it once, Proc Chimes never", function()
    local state = fixture({class = "WARRIOR", procEngine = true, known = {[OVERPOWER] = true, [6572] = true}})
    equal(state.toolkit.KindOwner("proc:overpower"), "DyresBuffReminders", "a usable proc claims too")
    equal(type(cueRow(state, "overpower", "sound")), "table")
    equal(state.row("DBR_PROC_OVERPOWER"), nil, "no Proc Chimes row")
    state.usable = {Overpower = {false, false}, Revenge = {false, false}}
    state.emit("SPELL_UPDATE_USABLE")
    state.combat = true
    state.usable.Overpower = {true, false}
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 1, "one sound, in combat")
    equal(state.played[1].key, "talent", "Proc Chimes' Overpower sound")
    equal(state.played[1].speech, "Overpower")
    equal(state.dbr.db.procCues.arc.flurry, false, "Flurry: arcs off by default (sound only before)")
    equal(state.dbr.db.procCues.sound.flurry, false)
end)

engineTest("proc cues: Mongoose Bite has arcs and sound once the Hunter knows it; not before", function()
    local state = fixture({class = "HUNTER", procEngine = true, known = {[1495] = true}})
    equal(state.toolkit.KindOwner("proc:mongoosebite"), "DyresBuffReminders")
    equal(state.dbr.ProcCuesHandle().Known("mongoosebite"), true)
    equal(type(cueRow(state, "mongoosebite", "sound")), "table")
    equal(state.row("DBR_PROC_MONGOOSEBITE"), nil, "no Proc Chimes row")
    state.usable = {["Mongoose Bite"] = {false, false}}
    state.emit("SPELL_UPDATE_USABLE")
    state.combat = true
    state.usable["Mongoose Bite"] = {true, false}
    state.emit("SPELL_UPDATE_USABLE")
    equal(#state.played, 1, "one sound, in combat")
    equal(state.played[1].key, "talent")
    equal(state.played[1].speech, "Mongoose Bite")
    local early = fixture({class = "HUNTER", procEngine = true, known = {}})
    equal(early.dbr.ProcCuesHandle().Known("mongoosebite"), false, "not trained yet: no cue")
    early.usable = {["Mongoose Bite"] = {false, false}}
    early.emit("SPELL_UPDATE_USABLE")
    early.usable["Mongoose Bite"] = {true, false}
    early.emit("SPELL_UPDATE_USABLE")
    equal(#early.played, 0, "silent")
end)

engineTest("proc cues: the first run copies DSU 1.4's choices once; DBR's own Proc Chimes win where it had them", function()
    local dsu = {procs = {arc = {nightfall = false, decimation = false}, sound = {nightfall = true, decimation = true},
        sounds = {nightfall = "impspell", decimation = "magical"}, position = {point = "TOP", relativePoint = "TOP", x = 5, y = -40},
        scale = 125}, procIDs = {nightfall = 990020, decimation = 990021}, procsWithSAO = true}
    local saved = {procs = {enabled = true, spells = {nightfall = false}, sounds = {nightfall = "magical"},
        learned = {nightfall = 990030}}}
    local state = fixture({class = "WARLOCK", procEngine = true, known = {[NIGHTFALL_TALENT] = true, [440870] = true},
        globals = {DyresShieldsUpDB = dsu}, db = saved})
    local cues = state.dbr.db.procCues
    equal(state.count(state.dbr.PROC_CUES_IMPORTED), 1, "one chat line")
    equal(cues.arc.nightfall, false, "DSU's arc switch")
    equal(cues.sound.nightfall, false, "DBR's own sound switch wins")
    equal(cues.sounds.nightfall, "magical", "DBR's own sound wins")
    equal(cues.sound.decimation, true, "DSU's, where DBR had none")
    equal(cues.sounds.decimation, "magical")
    equal(cues.position.x, 5, "the arcs' place")
    equal(cues.scale, 125, "and size (percent)")
    equal(state.dbr.db.procIDs.nightfall, 990030, "DBR's learned ID wins")
    equal(state.dbr.db.procIDs.decimation, 990021, "DSU's learned ID")
    equal(state.dbr.db.procsWithSAO, true)
    equal(state.dbr.db.procCuesImported, true)
    equal(dsu.procs.arc.nightfall, false, "DSU's table is never written")
    equal(dsu.procs.sound.nightfall, true)
    cues.arc.nightfall = true
    local again = fixture({class = "WARLOCK", procEngine = true, known = {[NIGHTFALL_TALENT] = true},
        globals = {DyresShieldsUpDB = dsu}, db = state.dbr.db})
    equal(again.find(state.dbr.PROC_CUES_IMPORTED), nil, "once only")
    equal(again.dbr.db.procCues.arc.nightfall, true, "a later choice stays")
end)

engineTest("proc cues: a new player with no DSU gets the defaults and no chat line", function()
    local state = fixture({class = "DRUID", procEngine = true, known = {[16880] = true, [16864] = true}})
    equal(state.find("Dyre's Shields Up"), nil)
    local cues = state.dbr.db.procCues
    equal(cues.arc.naturesgrace, false, "Nature's Grace: sound only by default")
    equal(cues.sound.naturesgrace, true)
    equal(cues.arc.druidclearcasting, true)
    equal(cues.sound.druidclearcasting, false, "Clearcasting's sound off: the game plays one")
    equal(state.dbr.db.procCuesImported, true)
    equal(state.soundIDs(), "16886", "Nature's Grace sounds")
end)

engineTest("proc cues: Proc Chimes switched off as a whole import as every sound off", function()
    local state = fixture({class = "DRUID", procEngine = true, known = {[16880] = true},
        db = {procs = {enabled = false, spells = {naturesgrace = true}}}})
    equal(state.dbr.db.procCues.sound.naturesgrace, false)
    equal(state.soundIDs(), "")
end)

engineTest("proc cues: beside SpellActivationOverlay the arcs stay off, the sounds play; procsWithSAO shows both", function()
    local state = fixture({class = "DRUID", procEngine = true, known = {[16880] = true, [16864] = true},
        loaded = {SpellActivationOverlay = true}})
    contains(state.find("SpellActivationOverlay is loaded"), "their sounds still play")
    equal(state.dbr.ProcArcsSteppedAside(), true)
    equal(state.soundIDs(), "16886", "the sound still plays")
    local store = state.dbr.ProcCuesHandle().Store()
    equal(store.arc.druidclearcasting, false, "every arc reads off")
    store.arc.druidclearcasting = true
    equal(state.dbr.db.procCues.arc.druidclearcasting, true, "the saved switch is kept, not written")
    local row = state.row("DBR_PROCS_WITH_SAO")
    equal(type(row), "table", "the switch to show both")
    state.settings.DBR_PROCS_WITH_SAO:SetValue(true)
    contains(state.find("applies after a /reload"), "proc arc")
    local both = fixture({class = "DRUID", procEngine = true, known = {[16864] = true},
        loaded = {SpellActivationOverlay = true}, db = state.dbr.db})
    equal(both.dbr.ProcArcsSteppedAside(), false, "after a reload: both")
    equal(both.find("SpellActivationOverlay is loaded"), nil)
    local plain = fixture({class = "DRUID", procEngine = true, known = {[16864] = true}})
    equal(plain.row("DBR_PROCS_WITH_SAO"), nil, "no row without SpellActivationOverlay")
end)

engineTest("proc cues: the Missile Barrage tooltip's macro names Arcane Missiles in the client's language", function()
    local saved = SPELLS[5143]
    local ok, message = pcall(function()
        SPELLS[5143] = "Projectiles des arcanes"
        local state = fixture({class = "MAGE", procEngine = true, known = {[400588] = true}})
        equal(state.dbr.MissileBarrageMacro(), "/stopcasting\n/use Projectiles des arcanes")
        local missiles
        for _, proc in ipairs(state.dbr.PROC_CUES) do
            if proc.key == "missilebarrage" then missiles = proc end
        end
        contains(missiles.tooltip, "/use Projectiles des arcanes")
        SPELLS[5143] = nil
        equal(state.dbr.MissileBarrageMacro(), "/stopcasting\n/use Arcane Missiles", "English without a name")
    end)
    SPELLS[5143] = saved
    equal(ok, true, tostring(message))
end)

engineTest("proc cues: the profile copies the settings, keeps this character's buff IDs, and a copy ends the import", function()
    local state = fixture({class = "WARLOCK", procEngine = true, known = {[NIGHTFALL_TALENT] = true},
        db = {procIDs = {nightfall = 990040}}})
    local part = state.dbr.SanitizeProfile({procCues = {arc = {nightfall = false}}, procIDs = {nightfall = 1}})
    equal(part.procCues.arc.nightfall, false, "in the profile")
    state.dbr.db.procCuesImported = false
    state.dbr.ApplyProfile()
    equal(state.dbr.db.procCuesImported, true, "a copy wins over a later import")
    local known = state.dbr.SanitizeDB({})
    equal(type(known.procCues), "table")
    equal(type(known.procIDs), "table")
    equal(known.procsWithSAO, false)
end)

test("proc cues: without engine 2, Proc Chimes as before, and the proc cue settings stay as saved", function()
    local saved = {procCues = {arc = {nightfall = "junk"}}}
    local state = fixture({class = "WARLOCK", db = saved})
    equal(state.dbr.procEngine, false)
    equal(state.dbr.ProcCuesHandle(), nil)
    equal(type(state.row("DBR_PROCS_ENABLED")), "table", "Proc Chimes' section")
    equal(state.dbr.db.procCues.arc.nightfall, "junk", "kept for a later toolkit")
    equal(state.dbr.db.procCuesImported, false, "the import waits for engine 2")
end)

local failed = 0
-- Winter's Chill chimes removed (1.13.3; John, 2026-11-22: "Remove it now"): it moves to
-- Dyre's Debuff Tracker, which can import the saved table DBR keeps for it.

test("Winter's Chill (removed): no section, no combat log, no target probe; the saved table stays", function()
    local saved = {enabled = false, noteSet = "full", extra = 7}
    local state = fixture({class = "MAGE", newerSounds = SOUNDS, db = {wintersChill = saved}})
    for _, heading in ipairs(state.headings) do
        equal(heading.heading:find("Winter's Chill", 1, true), nil, "no section")
    end
    equal(state.row("DBR_WINTERSCHILL_ENABLED"), nil)
    for _, frame in ipairs(state.frames) do
        equal(frame.events.COMBAT_LOG_EVENT_UNFILTERED, nil, "no combat log")
    end
    equal(state.dbr.HasWintersChill, nil)
    equal(state.dbr.WINTERS_CHILL, nil)
    equal(state.dbr.PROBE_TARGET_DEBUFFS, nil)
    local db = state.dbr.db.wintersChill
    equal(db.enabled, false, "kept as saved")
    equal(db.noteSet, "full", "not repaired")
    equal(db.extra, 7, "not rebuilt")
    equal(fixture().dbr.db.wintersChill, nil, "no table is made for a new character")
    state.slash("debug")
    equal(state.find("debug wintersChill"), nil)
    local before = state.auraSoundCount
    state.slash("probe on")
    equal(state.auraSoundCount, before, "the probe adds no target sound")
    for _, entry in pairs(state.auraSounds) do
        equal(entry.info.unitToken, "player")
    end
    equal(state.find("probe target"), nil)
end)

-- Dyre's Toolkit profile (Toolkit 2.10.0) ------------------------------------------------

local PROFILE_KEY = "Me - Forever"
local function savedPart(state, key)
    local entry = state.env.DyresToolkitDB.profiles[key or PROFILE_KEY]
    return entry and entry.parts[ADDON]
end
-- A Mage with this character's own keys and data read in client.
local function profileMage(extra)
    local options = {known = {[INTELLECT] = true, [FROST_ARMOR] = true, [ICE_ARMOR] = true}, newerSounds = SOUNDS,
        db = {last = {mageArmor = "Ice Armor"}, probe = false, chimes = {learned = {blink = 13}},
            procs = {spells = {mageclearcasting = true}, learned = {mageclearcasting = 99999}},
            buffs = {arcaneIntellect = {scale = 100}}}}
    for key, value in pairs(extra or {}) do options[key] = value end
    return fixture(options)
end
-- Another character's part: a Druid's choices, its own keys, and its data.
local function druidPart()
    return {enabled = true, leadPercent = 5, probe = true, locked = false, last = {mageArmor = "Molten Armor"},
        bars = {self = {position = {point = "CENTER", relativePoint = "CENTER", x = 1, y = 1}}},
        spells = {arcaneIntellect = false, markOfTheWild = false},
        buffs = {arcaneIntellect = {scale = 150, opacity = 60,
            position = {point = "CENTER", relativePoint = "CENTER", x = 40, y = -30}}},
        chimes = {enabled = false, lead = 1, learned = {blink = 7}},
        procs = {enabled = false, learned = {mageclearcasting = 5}},
        consumables = {enabled = false}, combo = {noteSet = "sax"}, futureKey = {a = 1}}
end
local function playerSounds(state)
    local count = 0
    for _, entry in pairs(state.auraSounds) do
        if entry.info.unitToken == "player" then count = count + 1 end
    end
    return count
end
test("profile: DBR joins the toolkit's profile; the copy leaves out this character's keys", function()
    local state = profileMage()
    local found = false
    for _, addon in ipairs(state.toolkit.ProfileParts()) do found = found or addon == ADDON end
    equal(found, true, "registered")
    local part = savedPart(state)
    equal(type(part), "table", "the toolkit keeps a copy")
    for _, key in ipairs({"locked", "probe", "last", "bars"}) do
        equal(part[key], nil, key .. " stays with this character")
    end
    equal(part.leadPercent, 10)
    equal(part.buffs.arcaneIntellect.scale, 100)
    -- An older toolkit (no RegisterProfilePart): DBR works as before, no error.
    local old = profileMage({toolkitBefore210 = true})
    equal(old.toolkit.RegisterProfilePart, nil)
    equal(old.dbr.available, true)
    equal(old.env.DyresToolkitDB.profiles, nil, "no profile")
    equal(old.find("rror"), nil)
end)
test("profile: sanitize({}) gives DBR's defaults; junk, partial, or newer parts are repaired", function()
    local state = profileMage()
    local fresh = state.dbr.SanitizeDB(nil)
    local defaults = state.dbr.SanitizeProfile({})
    for key, value in pairs(fresh) do
        if key ~= "chimes" and key ~= "procs" then
            equal(same(defaults[key], value), true, "default " .. key)
        end
    end
    for key in pairs(defaults) do
        equal(fresh[key] ~= nil, true, "no extra key " .. key)
    end
    equal(defaults.chimes.lead, fresh.chimes.lead)
    equal(same(defaults.chimes.spells, fresh.chimes.spells), true)
    equal(same(defaults.procs.spells, fresh.procs.spells), true)
    equal(same(defaults.procs.sounds, fresh.procs.sounds), true)
    equal(defaults.chimes.learned.blink, 13, "this character's cooldowns read in client stay")
    equal(defaults.procs.learned.mageclearcasting, 99999, "and its real buff IDs")
    for _, junk in ipairs({{enabled = "yes", chimes = "x", procs = 4, buffs = {arcaneIntellect = "big"},
            spells = {arcaneIntellect = 3}, seal = false, combo = {noteSet = "nope"}, leadPercent = 0 / 0},
            {leadPercent = 15}, druidPart(), {}}) do
        local clean = state.dbr.SanitizeProfile(junk)
        equal(type(clean.chimes.spells), "table")
        equal(type(clean.procs.sounds), "table")
        equal(type(clean.buffs.arcaneIntellect), "table")
        equal(type(clean.seal.enabled), "boolean")
        equal(clean.leadPercent == clean.leadPercent, true, "a number, not NaN")
        equal(clean.combo.noteSet ~= "nope", true)
    end
    equal(state.dbr.SanitizeProfile({leadPercent = 15}).leadPercent, 15, "a partial part keeps what it has")
end)
test("profile: a copy from a Druid changes DBR live, with no reload, and keeps this character's keys", function()
    local state = profileMage({toolkitDB = {snapToGrid = false,
        profiles = {["Alt - Forever"] = {class = "Druid", parts = {[ADDON] = druidPart()}, pending = {}}}}})
    local db = state.dbr.db
    local store = db.buffs.arcaneIntellect
    local holder = state.widget("arcaneIntellect")
    equal(playerSounds(state) > 0, true, "the proc sound is registered")
    equal(state.icon("arcaneIntellect"):IsShown(), true)
    db.wintersChill = {enabled = false, noteSet = "sax"}
    local chill = db.wintersChill
    local ok, reload = state.profile:CopyFrom("Alt - Forever")
    equal(ok, true)
    equal(#reload, 0, "live: no reload asked")
    equal(db.leadPercent, 5)
    equal(db.chimes.enabled, false)
    equal(db.chimes.lead, 1)
    equal(db.combo.noteSet, "sax")
    equal(db.futureKey, nil, "a newer version's key is dropped")
    equal(db.buffs.arcaneIntellect == store, true, "the widget's store is the same table")
    equal(store.scale, 150)
    equal(store.opacity, 60)
    equal(holder:GetScale(), 1.5, "the widget's new size, live")
    equal(store.position.x, 40)
    equal(playerSounds(state), 0, "procs off: the aura sounds are removed, live")
    equal(state.icon("arcaneIntellect"):IsShown(), false, "Arcane Intellect off: its icon hides, live")
    -- This character's own keys and data read in client.
    equal(db.last.mageArmor, "Ice Armor")
    equal(db.probe, false)
    equal(db.locked, true)
    equal(db.bars, nil)
    equal(db.chimes.learned.blink, 13)
    equal(db.procs.learned.mageclearcasting, 99999)
    equal(db.wintersChill == chill and chill.noteSet, "sax", "the removed chime's settings stay, for DDT")
    equal(savedPart(state).wintersChill, nil, "and are never copied")
    equal(savedPart(state).leadPercent, 5, "the toolkit's copy follows")
    -- The Defaults: a clean slate, live; the same keys and data stay.
    ok, reload = state.profile:CopyFrom(state.toolkit.PROFILE_DEFAULTS)
    equal(ok, true)
    equal(#reload, 0)
    equal(db.leadPercent, 10)
    equal(store.scale, 100)
    equal(holder:GetScale(), 1)
    equal(playerSounds(state), 0, "Clearcasting is off by default")
    equal(state.icon("arcaneIntellect"):IsShown(), true)
    equal(db.last.mageArmor, "Ice Armor")
    equal(db.procs.learned.mageclearcasting, 99999)
end)
test("profile: export and import; a bad line, a bad part, or combat changes nothing", function()
    local from = profileMage()
    from.dbr.db.leadPercent = 15
    from.dbr.db.chimes.lead = 2
    local text = from.profile:Export()
    equal(text:find("|", 1, true), nil)
    local to = profileMage({db = {last = {mageArmor = "Frost Armor"}}})
    local db = to.dbr.db
    local ok, reload = to.profile:Import(text)
    equal(ok, true)
    equal(#reload, 0)
    equal(db.leadPercent, 15)
    equal(db.chimes.lead, 2)
    equal(db.last.mageArmor, "Frost Armor", "an import keeps this character's keys")
    local before = copy(db)
    ok = to.profile:Import("DYRE2:profile:garbage:0")
    equal(ok, nil)
    equal(same(db, before), true, "a damaged line: nothing changed")
    -- Another AddOn's part that fails: all or nothing.
    to.toolkit.RegisterProfilePart({addon = "DyresBroken", current = function() return {} end,
        sanitize = function() error("broken") end})
    ok = to.profile:CopyFrom(to.toolkit.PROFILE_DEFAULTS)
    equal(ok, nil, "a part that fails refuses the whole copy")
    equal(same(db, before), true, "nothing changed")
    local clean = profileMage()
    clean.combat = true
    ok = clean.profile:CopyFrom(clean.toolkit.PROFILE_DEFAULTS)
    equal(ok, nil, "never in combat")
    equal(clean.dbr.db.last.mageArmor, "Ice Armor")
    equal(same(db, before), true)
end)
test("profile: a part copied while DBR was not loaded here is written at login, before the first run's imports", function()
    local mtf = {reminders = {enabled = true, spells = {intellect = false}}}
    local state = fixture({known = {[INTELLECT] = true}, globals = {MageToolsForeverDB = mtf},
        toolkitDB = {snapToGrid = false, profiles = {[PROFILE_KEY] = {class = "Mage", parts = {},
            pending = {[ADDON] = {leadPercent = 5, spells = {arcaneIntellect = true}}}}}}})
    local db = state.dbr.db
    equal(db.leadPercent, 5, "the waiting part")
    equal(db.spells.arcaneIntellect, true, "the profile wins over Mage Tools Forever's settings")
    equal(state.count("Copied your buff reminder settings"), 0, "no first-run import")
    equal(state.env.DyresToolkitDB.profiles[PROFILE_KEY].pending[ADDON], nil)
end)

-- Show only when needed (John, 2026-11-17; per buff 2026-11-18) ----------------------------------------------

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
local function isRed(icon)
    return icon.glow.shown ~= false and icon.border ~= nil and icon.border[1] == 1 and icon.border[2] == 0.2
end
-- A save with a long buff's "Show only when needed" on (off by default since 2026-11-19).
local function neededOn(keys, extra)
    local db = {needed = {}, neededLongOff = true}
    for _, key in ipairs(keys) do db.needed[key] = true end
    for key, value in pairs(extra or {}) do db[key] = value end
    return db
end
test("only when needed: on for a short buff, off for a long one by default, Visibility 0; off shows it in full",
    function()
    local state = fixture({known = {[INTELLECT] = true}, db = neededOn({"arcaneIntellect"})})
    equal(fixture({}).dbr.db.needed.arcaneIntellect, false, "a long buff: off by default (John, 2026-11-19, 1a)")
    equal(fixture({}).dbr.db.needed.mageArmor, false)
    equal(fixture({class = "WARRIOR"}).dbr.db.needed.battleShout, true, "a short buff: on by default")
    equal(state.row("DBR_NEEDED_ARCANEINTELLECT").setting.default, false, "the checkbox's default too")
    local db = state.dbr.db
    equal(db.needed.arcaneIntellect, true, "turned on, it stays on")
    equal(db.faintPercent, 0, "Visibility when not needed: 0 by default")
    equal(db.onlyNeeded, nil, "1.11.0's one switch is gone")
    local hunter = fixture({class = "HUNTER", known = {[883] = true}})
    equal(hunter.dbr.db.needed.hunterPet, nil, "a pet reminder has none")
    equal(hunter.row("DBR_NEEDED_HUNTERPET"), nil)
    equal(state.row("DBR_NEEDED_ARCANEINTELLECT").parentInitializer, state.row("DBR_BUFF_ARCANEINTELLECT"),
        "under its buff's switch")
    equal(state.row("DBR_FAINT").parentInitializer, state.row("DBR_ENABLED"), "one slider for every buff")
    -- Off for one buff: in full, as before 1.11.0's switch.
    state.settings.DBR_NEEDED_ARCANEINTELLECT:SetValue(false)
    equal(db.needed.arcaneIntellect, false)
    local icon, slot = state.icon("arcaneIntellect"), state.slotOf("arcaneIntellect")
    state.buff("player", "Arcane Intellect", state.now + 201)
    state.update("UNIT_AURA", "player")
    equal(icon.shown, true, "up: shown")
    equal(icon.alpha, 1)
    enterCombat(state)
    equal(icon.alpha, 1, "never faded in combat")
    state.advance(20)
    equal(icon.alpha, 1)
    state.buff("player", "Arcane Intellect", state.now + 1000)
    leaveCombat(state)
    equal(icon.alpha, 1)
    equal(icon.shown, true)
    equal(slot.alpha == nil or slot.alpha == 1, true, "the slot in full")
    -- Battle Shout can be off too now.
    local warrior = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true}, db = {needed = {battleShout = false}}})
    warrior.buff("player", "Battle Shout", warrior.now + 91)
    warrior.update("UNIT_AURA", "player")
    equal(warrior.icon("battleShout").shown, true, "off: Battle Shout shown while up")
    enterCombat(warrior)
    equal(warrior.icon("battleShout").alpha, 1, "and in full in combat")
end)
test("only when needed, on: up hides out of combat and in combat (0%); window full and yellow; missing full and red",
    function()
    local state = fixture({known = {[INTELLECT] = true}, db = neededOn({"arcaneIntellect"})})
    local icon, slot = state.icon("arcaneIntellect"), state.slotOf("arcaneIntellect")
    local warn = state.widget("arcaneIntellect").warn
    equal(visible(icon), true, "missing: shown out of combat")
    equal(isRed(icon), true, "with the red border")
    enterCombat(state)
    equal(icon.alpha, 1, "missing at combat start: in full")
    leaveCombat(state)
    -- update() lets one second pass: 200 s left of 1800; the lead is 10%, 180 s.
    state.buff("player", "Arcane Intellect", state.now + 201)
    state.update("UNIT_AURA", "player")
    equal(icon.shown, false, "up and outside its warning time: hidden out of combat")
    equal(slot.alpha, 0, "its slot too: no countdown while up")
    equal(warn.alpha, 0)
    enterCombat(state)
    equal(icon.shown, true, "in combat it is there...")
    equal(icon.alpha, 0, "...but hidden: it still takes clicks")
    equal(slot.alpha, 0, "the game's icon hidden too")
    equal(icon.attributes.spell1, "Arcane Intellect", "armed: a click still casts it")
    state.advance(19)
    equal(icon.alpha, 0, "181 s left: still hidden")
    state.advance(1)
    equal(icon.alpha, 1, "180 s left: its warning time, in full, from DBR's own timer")
    equal(slot.alpha, 1)
    equal(warn.alpha, 1, "with the yellow flashing border")
    equal(warn.flash:IsPlaying(), true)
    state.advance(180)
    equal(warn.alpha, 0, "run out: no yellow...")
    equal(icon.alpha, 1, "...in full...")
    equal(isRed(icon), true, "...with the red border under the slot that went")
    state.cast(INTELLECT)
    equal(icon.alpha, 0, "recast in combat: hidden again for its full length")
    state.buff("player", "Arcane Intellect", state.now + 1000)
    leaveCombat(state)
    equal(icon.shown, false, "after combat: hidden again while up")
    equal(slot.alpha, 0)
    -- Within the warning time out of combat: shown, yellow.
    state.buff("player", "Arcane Intellect", state.now + 171)
    state.update("UNIT_AURA", "player")
    equal(visible(icon), true, "170 s left: shown above the slot")
    equal(icon.alpha, 1, "in full")
    equal(warn.alpha, 1, "yellow and flashing")
    enterCombat(state)
    equal(icon.alpha, 1, "in its warning time at combat start: in full")
    -- Off: as before at once (out of combat).
    state.buff("player", "Arcane Intellect", state.now + 1000)
    leaveCombat(state)
    state.settings.DBR_NEEDED_ARCANEINTELLECT:SetValue(false)
    equal(icon.shown, true, "off: up and shown")
    equal(slot.alpha, 1, "the slot draws it again")
end)
test("only when needed: Visibility when not needed is the same alpha in and out of combat, 0 to 80% in 5s",
    function()
    local state = fixture({known = {[INTELLECT] = true}, db = neededOn({"arcaneIntellect"}, {faintPercent = 25})})
    local icon, slot = state.icon("arcaneIntellect"), state.slotOf("arcaneIntellect")
    state.buff("player", "Arcane Intellect", state.now + 1001)
    state.update("UNIT_AURA", "player")
    equal(icon.shown, true, "25%: shown out of combat...")
    equal(icon.driver, "show", "(the combat-only driver only at 0)")
    equal(icon.alpha, 0.25, "...at 25%")
    equal(slot.alpha, 0.25, "the game's icon too")
    enterCombat(state)
    equal(icon.alpha, 0.25, "the same in combat")
    equal(slot.alpha, 0.25)
    state.buff("player", "Arcane Intellect", state.now + 1000)
    leaveCombat(state)
    equal(icon.alpha, 0.25, "and after it")
    equal(slot.alpha, 0.25)
    -- Within the warning time: in full.
    state.buff("player", "Arcane Intellect", state.now + 171)
    state.update("UNIT_AURA", "player")
    equal(icon.alpha, 1, "about to run out: in full")
    -- The slider: live out of combat.
    state.buff("player", "Arcane Intellect", state.now + 1001)
    state.update("UNIT_AURA", "player")
    state.settings.DBR_FAINT:SetValue(60)
    equal(icon.alpha, 0.6, "60% at once")
    equal(slot.alpha, 0.6)
    state.settings.DBR_FAINT:SetValue(0)
    equal(icon.shown, false, "0%: hidden out of combat")
    equal(slot.alpha, 0)
    local sanitize = state.dbr.SanitizeFaint
    equal(sanitize(20), 20)
    equal(sanitize(23), 25, "steps of 5")
    equal(sanitize(100), 80, "80% at most: more is the switch off")
    equal(sanitize(-5), 0)
    equal(sanitize("25"), 0)
    equal(sanitize(0 / 0), 0)
    -- Thorns up on the tank (ours shows it): 25% too.
    local druid = fixture({class = "DRUID", known = {[THORNS] = true}, db = neededOn({"thorns"}, {faintPercent = 25})})
    druid.party({{name = "Tanky", class = "WARRIOR", role = "TANK", buffs = {Thorns = druid.now + 601}}})
    equal(druid.icon("thorns").shown, true, "up on the tank, 25%: shown...")
    equal(druid.icon("thorns").alpha, 0.25, "...at 25%")
    -- Battle Shout at 15%, in combat; its own 60 s window.
    local warrior = fixture({class = "WARRIOR", known = {[BATTLE_SHOUT] = true},
        db = {faintPercent = 15, faintHidden = true}})
    warrior.buff("player", "Battle Shout", warrior.now + 91)
    warrior.update("UNIT_AURA", "player")
    equal(warrior.icon("battleShout").alpha, 0.15, "15% out of combat")
    enterCombat(warrior)
    equal(warrior.icon("battleShout").alpha, 0.15, "15% in combat")
    warrior.advance(30)
    equal(warrior.icon("battleShout").alpha, 1, "its own 60 s window")
end)
test("only when needed: a group member lacking it, unlocked, pets and the Aspect reminder stay in full", function()
    local state = fixture({known = {[INTELLECT] = true}, db = neededOn({"arcaneIntellect"})})
    local icon = state.icon("arcaneIntellect")
    state.buff("player", "Arcane Intellect", state.now + 1001)
    state.party({{name = "Healy", class = "PRIEST"}})
    equal(visible(icon), true, "Healy lacks it: shown")
    enterCombat(state)
    equal(icon.alpha, 1, "in combat DBR cannot time theirs: in full")
    state.cast(INTELLECT)
    equal(icon.alpha, 1, "your cast on you leaves Healy lacking: still in full")
    state.cast(BRILLIANCE)
    equal(icon.alpha, 0, "the group version covers everyone: hidden")
    leaveCombat(state)
    local unlocked = fixture({known = {[INTELLECT] = true}, db = neededOn({"arcaneIntellect"})})
    unlocked.slash("unlock")
    unlocked.buff("player", "Arcane Intellect", unlocked.now + 1001)
    unlocked.update("UNIT_AURA", "player")
    equal(unlocked.icon("arcaneIntellect").shown, true, "unlocked: every icon shows, to move it")
    enterCombat(unlocked)
    equal(unlocked.icon("arcaneIntellect").alpha, 1, "unlocked: never faded in combat either")
    -- Thorns up on the tank: hidden out of and in combat, in full in its window.
    local druid = fixture({class = "DRUID", known = {[THORNS] = true}, db = neededOn({"thorns"})})
    local thorns = druid.icon("thorns")
    druid.party({{name = "Tanky", class = "WARRIOR", role = "TANK", buffs = {Thorns = druid.now + 601}}})
    equal(thorns.shown, false, "up on the tank: hidden out of combat")
    enterCombat(druid)
    equal(thorns.alpha, 0, "hidden in combat")
    druid.advance(420)
    equal(thorns.alpha, 1, "3 minutes before the tank's runs out: in full")
    equal(druid.widget("thorns").warn.alpha, 1, "and yellow")
    local hunter = fixture({class = "HUNTER", known = {[883] = true}, db = {faintPercent = 25}})
    enterCombat(hunter)
    equal(hunter.icon("hunterPet").alpha, 1, "a pet reminder is never faded")
end)
test("only when needed: older saves: long buffs off once; a saved 15% becomes 0 once; 25% and a later 15% stay",
    function()
    local old = fixture({db = {onlyNeeded = false, faintPercent = 15}})
    equal(old.dbr.db.needed.arcaneIntellect, false, "1.11.0's switch: a long buff off")
    equal(old.dbr.db.neededLongOff, true)
    local v120 = fixture({class = "WARRIOR", db = {needed = {battleShout = false}}})
    equal(v120.dbr.db.needed.battleShout, false, "a short buff turned off by hand stays off")
    local mage120 = fixture({db = {needed = {arcaneIntellect = true, mageArmor = true}}})
    equal(mage120.dbr.db.needed.arcaneIntellect, false, "1.12.0 turned every buff on: long ones off once")
    equal(mage120.dbr.db.needed.mageArmor, false)
    equal(mage120.dbr.SanitizeDB(mage120.dbr.db).needed.arcaneIntellect, false)
    mage120.settings.DBR_NEEDED_ARCANEINTELLECT:SetValue(true)
    equal(mage120.dbr.SanitizeDB(mage120.dbr.db).needed.arcaneIntellect, true, "turned on after the move: stays")
    equal(old.dbr.SanitizeProfile({needed = {arcaneIntellect = true}}).needed.arcaneIntellect, false,
        "a 1.12.0 profile copy: off too")
    local kept = old.dbr.SanitizeProfile({needed = {arcaneIntellect = true}, neededLongOff = true})
    equal(kept.needed.arcaneIntellect, true)
    equal(kept.neededLongOff, true, "the flag goes with the profile")
    equal(old.dbr.db.onlyNeeded, nil)
    equal(old.dbr.db.faintPercent, 0, "1.11.0 saved 15 for everyone: now 0")
    equal(old.dbr.db.faintHidden, true)
    equal(fixture({db = {faintPercent = 25}}).dbr.db.faintPercent, 25, "25% was a choice: it stays")
    local chosen = fixture({db = {faintPercent = 15, faintHidden = true}})
    equal(chosen.dbr.db.faintPercent, 15, "15% chosen after the move: it stays")
    old.settings.DBR_FAINT:SetValue(15)
    equal(old.dbr.SanitizeDB(old.dbr.db).faintPercent, 15, "a repair later keeps it")
    equal(old.dbr.SanitizeProfile({faintPercent = 15}).faintPercent, 0, "a 1.11.0 profile copy: 0 too")
    equal(old.dbr.SanitizeProfile({faintPercent = 15, faintHidden = true}).faintPercent, 15)
    equal(fixture({db = {needed = {arcaneIntellect = "no"}, neededLongOff = true}}).dbr.db.needed.arcaneIntellect,
        false, "repaired: its default")
    equal(fixture({class = "WARRIOR", db = {needed = {battleShout = "no"}}}).dbr.db.needed.battleShout, true)
end)
test("only when needed: in the toolkit profile; a copy turns a buff's switch off live", function()
    local state = profileMage()
    local part = savedPart(state)
    equal(part.needed.arcaneIntellect, false, "in the profile")
    equal(part.neededLongOff, true)
    equal(part.faintPercent, 0)
    local clean = state.dbr.SanitizeProfile({needed = {arcaneIntellect = false}, faintPercent = 25})
    equal(clean.needed.arcaneIntellect, false)
    equal(clean.needed.mageArmor, false)
    equal(clean.faintPercent, 25)
    local alt = druidPart()
    alt.needed, alt.faintPercent = {arcaneIntellect = false}, 25
    local copy = profileMage({toolkitDB = {snapToGrid = false,
        profiles = {["Alt - Forever"] = {class = "Druid", parts = {[ADDON] = alt}, pending = {}}}}})
    copy.dbr.db.spells.arcaneIntellect = true
    copy.dbr.db.needed.arcaneIntellect = true
    copy.buff("player", "Arcane Intellect", copy.now + 1001)
    copy.update("UNIT_AURA", "player")
    equal(copy.icon("arcaneIntellect").shown, false, "on: hidden while up")
    copy.profile:CopyFrom("Alt - Forever")
    equal(copy.dbr.db.needed.arcaneIntellect, false)
    equal(copy.dbr.db.faintPercent, 25)
    copy.dbr.db.spells.arcaneIntellect = true
    copy.dbr.RefreshReminders()
    equal(copy.icon("arcaneIntellect").shown, true, "off: shown, live")
end)

-- Settings sections (Dyre's Toolkit 2.17.0; John, 2026-11-26: a class AddOn
-- "should surface every setting in the wrapped addon's settings, and just
-- pass-through the setting"). Only with a toolkit that has sections; the copy
-- in tests/toolkit (CI) may not, so there these say so and pass.
local function sectionTest(name, body)
    test(name, function()
        local probe = fixture({class = "MAGE", known = {[INTELLECT] = true}})
        if type(probe.toolkit.RegisterSettingsSection) ~= "function" then
            io.write("# skipped (no settings sections in ", TOOLKIT_DIR, "): ", name, "\n")
            return
        end
        body()
    end)
end
-- A host's page (Mage or Warlock Tools Forever) drawing one of DBR's sections.
local function hostSection(state, host, key, filter)
    local page, layout = state.env.Settings.RegisterVerticalLayoutCategory(host .. " " .. key)
    local result = state.toolkit.AddSettingsSection(page, layout, {addon = ADDON, key = key,
        host = host, filter = filter, link = {name = "Open Buff Reminders", button = "Open"}})
    return result, page
end
local function hosted(host, variable)
    return "DYRE_" .. host:upper() .. "__" .. variable
end

sectionTest("sections: DBR registers reminders, chimes, and procs at ADDON_LOADED", function()
    local state = fixture({class = "MAGE", known = {[INTELLECT] = true}})
    equal(table.concat(state.toolkit.SettingsSections(ADDON), ","), "chimes,procs,reminders")
    -- An older toolkit: nothing registered, no error.
    state.toolkit.SETTINGS_SECTIONS_VERSION = nil
    equal(state.dbr.RegisterSettingsSections(), false)
end)

sectionTest("sections: a host's chimes rows have its prefix and write DBR's live settings", function()
    local state = fixture({class = "MAGE", known = {[INTELLECT] = true}, newerSounds = SOUNDS})
    equal(hostSection(state, "MageToolsForever", "chimes"), "rows")
    local host = state.settings[hosted("MageToolsForever", "DBR_CHIMES_ENABLED")]
    equal(type(host), "table", "the host's Enable")
    equal(type(state.settings.DBR_CHIMES_ENABLED), "table", "DBR's own page keeps its names")
    equal(type(state.settings[hosted("MageToolsForever", "DBR_CHIME_LEAD")]), "table", "the lead")
    equal(type(state.row(hosted("MageToolsForever", "DBR_CHIME_BLINK"))), "table", "a spell row")
    equal(type(state.row(hosted("MageToolsForever", "DBR_CHIME_BLINK_SOUND"))), "table", "its sound")
    host:SetValue(false)
    equal(state.chimes().enabled, false, "the host's switch is DBR's")
    equal(state.settings.DBR_CHIMES_ENABLED:GetValue(), false, "and DBR's page shows it")
    state.settings.DBR_CHIMES_ENABLED:SetValue(true)
    equal(host:GetValue(), true, "back on from DBR's page")
    state.settings[hosted("MageToolsForever", "DBR_CHIME_BLINK")]:SetValue(false)
    equal(state.chimes().spells.blink, false)
end)

sectionTest("sections: a filter keeps only the listed chimes; a host section has no heading", function()
    local state = fixture({class = "MAGE", known = {[INTELLECT] = true}})
    local headings = #state.headings
    equal(hostSection(state, "MageToolsForever", "chimes", {"counterspell"}), "rows")
    equal(type(state.row(hosted("MageToolsForever", "DBR_CHIME_COUNTERSPELL"))), "table")
    equal(state.row(hosted("MageToolsForever", "DBR_CHIME_BLINK")), nil, "not listed")
    equal(#state.headings, headings, "the host names its own section")
    -- Nothing of the class listed: the host's link instead, and no rows.
    equal(hostSection(state, "WarlockToolsForever", "chimes", {"nosuchspell"}), "link")
    equal(state.settings[hosted("WarlockToolsForever", "DBR_CHIMES_ENABLED")], nil)
end)

sectionTest("sections: a host's reminders show its class's buffs, filtered, on DBR's live settings", function()
    local state = fixture({class = "MAGE", known = {[INTELLECT] = true, [FROST_ARMOR] = true}})
    equal(hostSection(state, "MageToolsForever", "reminders"), "rows")
    local intellect = state.settings[hosted("MageToolsForever", "DBR_BUFF_ARCANEINTELLECT")]
    equal(type(intellect), "table")
    equal(type(state.settings[hosted("MageToolsForever", "DBR_ENABLED")]), "table", "the Enable it depends on")
    equal(type(state.settings[hosted("MageToolsForever", "DBR_BUFF_DAMPEN")]), "table", "Dampen or Amplify")
    equal(state.settings[hosted("MageToolsForever", "DBR_BUFF_ICONS_SCALE")], nil, "sizes stay on DBR's page")
    intellect:SetValue(false)
    equal(state.dbr.db.spells.arcaneIntellect, false)
    equal(state.settings.DBR_BUFF_ARCANEINTELLECT:GetValue(), false)
    local filtered = fixture({class = "MAGE", known = {[INTELLECT] = true}})
    equal(hostSection(filtered, "MageToolsForever", "reminders", {"mageArmor"}), "rows")
    equal(type(filtered.settings[hosted("MageToolsForever", "DBR_BUFF_MAGEARMOR")]), "table")
    equal(filtered.settings[hosted("MageToolsForever", "DBR_BUFF_ARCANEINTELLECT")], nil, "not listed")
    -- A class without reminders: the host's link.
    local rogue = fixture({class = "ROGUE", known = {[INTELLECT] = true}})
    equal(hostSection(rogue, "MageToolsForever", "reminders"), "link")
end)

sectionTest("sections: Proc Chimes on a host, filtered to Nightfall; a Mage has none", function()
    local state = fixture({class = "WARLOCK", newerSounds = SOUNDS})
    equal(state.dbr.procEngine, false, "Proc Chimes in this fixture")
    equal(hostSection(state, "WarlockToolsForever", "procs", {"nightfall"}), "rows")
    local nightfall = state.settings[hosted("WarlockToolsForever", "DBR_PROC_NIGHTFALL")]
    equal(type(nightfall), "table")
    equal(state.settings[hosted("WarlockToolsForever", "DBR_PROC_DECIMATION")], nil, "not listed")
    nightfall:SetValue(true)
    equal(state.dbr.db.procs.spells.nightfall, true)
    equal(state.settings.DBR_PROC_NIGHTFALL:GetValue(), true, "DBR's page shows it")
    local mage = fixture({class = "MAGE", known = {[INTELLECT] = true}, newerSounds = SOUNDS})
    equal(hostSection(mage, "MageToolsForever", "procs", {"nightfall"}), "link", "a Mage has no Nightfall")
end)

sectionTest("sections: proc cues on a host need sections 2; the toolkit's rows get the host's names", function()
    if not HAS_PROC_ENGINE then
        io.write("# skipped (no proc engine 2 in ", TOOLKIT_DIR, ")\n")
        return
    end
    local state = fixture({class = "WARLOCK", procEngine = true, known = {[NIGHTFALL_TALENT] = true}})
    local version = state.toolkit.SETTINGS_SECTIONS_VERSION
    state.toolkit.SETTINGS_SECTIONS_VERSION = 1
    equal(hostSection(state, "WarlockToolsForever", "procs", {"nightfall"}), "link", "sections 1: the link")
    state.toolkit.SETTINGS_SECTIONS_VERSION = version
    if (tonumber(version) or 0) < 2 then
        io.write("# skipped (sections ", tostring(version), " in ", TOOLKIT_DIR, ")\n")
        return
    end
    equal(hostSection(state, "WarlockToolsForever", "procs", {"nightfall"}), "rows")
    local arc = state.settings[hosted("WarlockToolsForever", "DYRE_DYRESBUFFREMINDERS_PROC_NIGHTFALL_ARC")]
    equal(type(arc), "table", "the host's arc switch")
    equal(type(state.settings.DYRE_DYRESBUFFREMINDERS_PROC_NIGHTFALL_ARC), "table", "DBR's own stays")
    arc:SetValue(false)
    equal(state.dbr.db.procCues.arc.nightfall, false, "the host's switch is DBR's")
end)

-- Fit and finish (John, 2026-11-27): "when the top-level is off, the settings
-- that are controlling a disabled feature should be disabled too", and "the
-- top-level disable for each section should be on the top-level MTF panel".
local function active(row)
    for _, predicate in ipairs(row.modifyPredicates or {}) do
        if predicate() == false then return false end
    end
    return not row.predicate or row.predicate() ~= false
end
local function partTest(name, body)
    sectionTest(name, function()
        local probe = fixture({class = "MAGE", known = {[INTELLECT] = true}})
        if (tonumber(probe.toolkit.SETTINGS_SECTIONS_VERSION) or 0) < 3 then
            io.write("# skipped (settings sections before 3 in ", TOOLKIT_DIR, "): ", name, "\n")
            return
        end
        body()
    end)
end
local function hostPart(state, host, key, part, filter)
    local page, layout = state.env.Settings.RegisterVerticalLayoutCategory(host .. " " .. key .. " " .. part)
    return state.toolkit.AddSettingsSection(page, layout, {addon = ADDON, key = key, host = host, part = part,
        filter = filter, link = {name = "Open Buff Reminders", button = "Open"}}), page
end

test("greying: Enable off greys every row under it, grandchildren too, and they are told to re-check", function()
    local state = fixture({class = "MAGE", known = {[INTELLECT] = true}})
    local notified = {}
    state.env.Settings.NotifyUpdate = function(variable) notified[#notified + 1] = variable end
    local group = state.row("DBR_GROUP_ARCANEINTELLECT")
    local needed = state.row("DBR_NEEDED_ARCANEINTELLECT")
    equal(active(group), true)
    state.settings.DBR_ENABLED:SetValue(false)
    equal(active(state.row("DBR_BUFF_ARCANEINTELLECT")), false, "a buff")
    equal(active(group), false, "its group switch")
    equal(active(needed), false, "its Show only when needed")
    equal(active(state.row("DBR_BUFF_ICONS_SCALE")), false, "the icons' size")
    contains(table.concat(notified, ","), "DBR_BUFF_ARCANEINTELLECT", "the buff row is told, so its rows re-check")
    state.settings.DBR_ENABLED:SetValue(true)
    equal(active(group), true, "back")
    state.settings.DBR_BUFF_ARCANEINTELLECT:SetValue(false)
    equal(active(group), false, "its own switch off")
end)

partTest("parts: \"master\" draws only each section's Enable, on the host's names", function()
    local state = fixture({class = "MAGE", known = {[INTELLECT] = true}, newerSounds = SOUNDS})
    equal(hostPart(state, "MageToolsForever", "reminders", "master"), "rows")
    equal(hostPart(state, "MageToolsForever", "chimes", "master"), "rows")
    equal(type(state.settings[hosted("MageToolsForever", "DBR_ENABLED")]), "table")
    equal(type(state.settings[hosted("MageToolsForever", "DBR_CHIMES_ENABLED")]), "table")
    equal(state.settings[hosted("MageToolsForever", "DBR_BUFF_ARCANEINTELLECT")], nil, "no buff rows")
    equal(state.settings[hosted("MageToolsForever", "DBR_CHIME_BLINK")], nil, "no chime rows")
    equal(state.settings[hosted("MageToolsForever", "DBR_CHIME_LEAD")], nil, "no lead")
    state.settings[hosted("MageToolsForever", "DBR_CHIMES_ENABLED")]:SetValue(false)
    equal(state.chimes().enabled, false, "DBR's own switch")
    local warlock = fixture({class = "WARLOCK", newerSounds = SOUNDS})
    equal(hostPart(warlock, "WarlockToolsForever", "procs", "master", {"nightfall"}), "rows")
    equal(type(warlock.settings[hosted("WarlockToolsForever", "DBR_PROCS_ENABLED")]), "table")
    equal(warlock.settings[hosted("WarlockToolsForever", "DBR_PROC_NIGHTFALL")], nil)
end)

partTest("parts: \"rest\" leaves Enable out, and its rows are greyed while Enable is off", function()
    local state = fixture({class = "MAGE", known = {[INTELLECT] = true}, newerSounds = SOUNDS})
    equal(hostPart(state, "MageToolsForever", "reminders", "rest"), "rows")
    equal(hostPart(state, "MageToolsForever", "chimes", "rest"), "rows")
    equal(state.settings[hosted("MageToolsForever", "DBR_ENABLED")], nil, "Enable is on the top page")
    equal(state.settings[hosted("MageToolsForever", "DBR_CHIMES_ENABLED")], nil)
    local buff = state.row(hosted("MageToolsForever", "DBR_BUFF_ARCANEINTELLECT"))
    local group = state.row(hosted("MageToolsForever", "DBR_GROUP_ARCANEINTELLECT"))
    local chime = state.row(hosted("MageToolsForever", "DBR_CHIME_BLINK"))
    local lead = state.row(hosted("MageToolsForever", "DBR_CHIME_LEAD"))
    equal(active(buff) and active(group) and active(chime) and active(lead), true, "on")
    state.settings.DBR_ENABLED:SetValue(false)
    state.settings.DBR_CHIMES_ENABLED:SetValue(false)
    equal(active(buff), false, "a buff, its Enable not on this page")
    equal(active(group), false, "and the row under it")
    equal(active(chime), false, "a chime")
    equal(active(lead), false, "the lead")
    equal(state.row(hosted("MageToolsForever", "DBR_BUFF_ICONS_SCALE")), nil, "sizes stay on DBR's page")
end)

partTest("procs master (engine 2): named on a top page, \"Enable\" under DBR's heading; off greys and silences", function()
    if not HAS_PROC_ENGINE then
        io.write("# skipped (no proc engine 2 in ", TOOLKIT_DIR, ")\n")
        return
    end
    local probe = fixture({class = "WARLOCK", procEngine = true, known = {[NIGHTFALL_TALENT] = true}})
    if type(probe.toolkit.AddProcMasterSetting) ~= "function" then
        io.write("# skipped (no proc master switch in ", TOOLKIT_DIR, ")\n")
        return
    end
    local state = fixture({class = "WARLOCK", procEngine = true, known = {[NIGHTFALL_TALENT] = true},
        db = {procCues = {sound = {nightfall = true}}}})
    -- DBR's own page: heading, "Enable", then the rows; no second heading.
    local master = state.settings.DYRE_DYRESBUFFREMINDERS_PROCS_ENABLED
    equal(master.name, "Enable")
    equal(state.row("DYRE_DYRESBUFFREMINDERS_PROCS_ENABLED").tooltip,
        "Shows an arc and plays a chime when a proc makes an important spell or ability ready.", "what the feature does")
    local procHeadings = 0
    for _, heading in ipairs(state.headings) do
        if heading.heading == "Procs" then procHeadings = procHeadings + 1 end
    end
    equal(procHeadings, 1, "one Procs heading")
    local _, masterAt = state.row("DYRE_DYRESBUFFREMINDERS_PROCS_ENABLED")
    local _, arcAt = cueRow(state, "nightfall", "arc")
    equal(masterAt < arcAt, true, "Enable before the rows")
    equal(state.soundIDs(), "17941", "Nightfall's sound on")
    master:SetValue(false)
    equal(state.dbr.db.procCues.enabled, false, "saved")
    equal(state.soundIDs(), "", "every sound gives way")
    equal(active(cueRow(state, "nightfall", "arc")), false, "the rows are greyed")
    equal(state.dbr.db.procCues.sound.nightfall, true, "each proc keeps its own switch")
    master:SetValue(true)
    equal(state.soundIDs(), "17941", "back")
    -- WTF's top page: the switch alone, named; its sub-page: the rows, greyed while it is off.
    equal(hostPart(state, "WarlockToolsForever", "procs", "master", {"nightfall"}), "rows")
    local hostMaster = state.settings[hosted("WarlockToolsForever", "DYRE_DYRESBUFFREMINDERS_PROCS_ENABLED")]
    equal(hostMaster.name, "Procs")
    equal(state.row(hosted("WarlockToolsForever", "DYRE_DYRESBUFFREMINDERS_PROCS_ENABLED")).tooltip,
        "Shows an arc and plays a chime when a proc makes an important spell or ability ready.", "one sentence")
    equal(state.settings[hosted("WarlockToolsForever", "DYRE_DYRESBUFFREMINDERS_PROC_NIGHTFALL_ARC")], nil,
        "no rows on the top page")
    local headings = #state.headings
    equal(hostPart(state, "WarlockToolsForever", "procs", "rest", {"nightfall"}), "rows")
    equal(#state.headings, headings, "the host names its section: no Procs heading")
    local arc = state.row(hosted("WarlockToolsForever", "DYRE_DYRESBUFFREMINDERS_PROC_NIGHTFALL_ARC"))
    equal(type(arc), "table")
    equal(state.settings[hosted("WarlockToolsForever", "DYRE_DYRESBUFFREMINDERS_PROCS_ENABLED")] == hostMaster, true,
        "no second switch on the sub-page")
    hostMaster:SetValue(false)
    equal(master:GetValue(), false, "the same switch as DBR's")
    equal(active(arc), false, "the sub-page rows greyed")
    -- A Mage has no Nightfall: nothing on MTF's top page.
    local mage = fixture({class = "MAGE", procEngine = true, known = {[INTELLECT] = true}})
    equal(hostPart(mage, "MageToolsForever", "procs", "master", {"nightfall"}), nil)
end)

-- John (2026-11-27): "extend the same logic/checks to WTF and make sure it
-- works the same here for delegated settings". Both hosts, as each passes
-- its sections: MTF (Mage) all of the class, WTF (Warlock) Demon Armor and
-- Nightfall.
local HOSTS = {
    {host = "MageToolsForever", class = "MAGE", known = {[INTELLECT] = true, [FROST_ARMOR] = true},
        buff = "ARCANEINTELLECT", child = "DBR_GROUP_ARCANEINTELLECT", chime = "DBR_CHIME_BLINK",
        filters = {}},
    {host = "WarlockToolsForever", class = "WARLOCK", known = {},
        buff = "DEMONARMOR", child = "DBR_NEEDED_DEMONARMOR", chime = "DBR_CHIME_DEATHCOIL",
        filters = {reminders = {"demonArmor"}, procs = {"nightfall"}}},
}
local MASTERS = {
    reminders = {variable = "DBR_ENABLED", label = "Reminders"},
    chimes = {variable = "DBR_CHIMES_ENABLED", label = "Chimes"},
    procs = {variable = "DBR_PROCS_ENABLED", label = "Procs"},
}

partTest("hosts: MTF and WTF top pages show each section's switch by its name, DBR's page \"Enable\"", function()
    for _, case in ipairs(HOSTS) do
        local state = fixture({class = case.class, known = case.known, newerSounds = SOUNDS})
        for _, key in ipairs({"reminders", "chimes", "procs"}) do
            local master = MASTERS[key]
            local result = hostPart(state, case.host, key, "master", case.filters[key])
            equal(result, "rows", case.host .. " " .. key)
            local setting = state.settings[hosted(case.host, master.variable)]
            equal(type(setting), "table", case.host .. " " .. key .. " switch")
            equal(setting.name, master.label, case.host .. " " .. key .. " named")
            local tip = state.row(hosted(case.host, master.variable)).tooltip
            equal(select(2, tip:gsub("[%.%?!]%s", "")), 0, case.host .. " " .. key .. ": one sentence: " .. tip)
            equal(tip, state.row(master.variable).tooltip, "the same sentence as on DBR's page")
            equal(state.settings[master.variable].name, "Enable", "DBR's own page: " .. key)
        end
    end
end)

partTest("hosts: MTF and WTF sub-pages grey every row while a switch above it is off", function()
    for _, case in ipairs(HOSTS) do
        local state = fixture({class = case.class, known = case.known, newerSounds = SOUNDS})
        equal(hostPart(state, case.host, "reminders", "rest", case.filters.reminders), "rows", case.host)
        equal(hostPart(state, case.host, "chimes", "rest"), "rows", case.host)
        local buff = state.row(hosted(case.host, "DBR_BUFF_" .. case.buff))
        local child = state.row(hosted(case.host, case.child))
        local chime = state.row(hosted(case.host, case.chime))
        equal(type(buff) == "table" and type(child) == "table" and type(chime) == "table", true, case.host .. " rows")
        equal(active(buff) and active(child) and active(chime), true, case.host .. " on")
        -- The section switches live on the top page (here, DBR's own settings).
        state.settings.DBR_ENABLED:SetValue(false)
        equal(active(buff), false, case.host .. " buff, Enable on the other page")
        equal(active(child), false, case.host .. " the row under the buff")
        state.settings.DBR_ENABLED:SetValue(true)
        state.settings[hosted(case.host, "DBR_BUFF_" .. case.buff)]:SetValue(false)
        equal(active(child), false, case.host .. " its buff off")
        state.settings.DBR_CHIMES_ENABLED:SetValue(false)
        equal(active(chime), false, case.host .. " a chime")
        if case.filters.procs and not state.dbr.procEngine then
            equal(hostPart(state, case.host, "procs", "rest", case.filters.procs), "rows")
            local proc = state.row(hosted(case.host, "DBR_PROC_NIGHTFALL"))
            equal(active(proc), true)
            state.settings.DBR_PROCS_ENABLED:SetValue(false)
            equal(active(proc), false, case.host .. " Nightfall")
            equal(state.row(hosted(case.host, "DBR_PROC_DECIMATION")), nil, "WTF lists Nightfall only")
        end
        if case.filters.reminders then
            equal(state.row(hosted(case.host, "DBR_BUFF_WARLOCKPET")), nil, "WTF lists Demon Armor only")
        end
    end
end)


partTest("watch: rows without their switch on the page re-check live as it changes", function()
    local state = fixture({class = "MAGE", known = {[INTELLECT] = true}})
    local scale = state.row("DBR_BUFF_ICONS_SCALE")
    contains(table.concat(scale.watched or {}, ","), "DBR_ENABLED", "the icons' size watches Enable")
    equal(active(scale), true)
    state.settings.DBR_ENABLED:SetValue(false)
    equal(active(scale), false, "greyed")
    equal(hostPart(state, "MageToolsForever", "chimes", "rest"), "rows")
    local chime = state.row(hosted("MageToolsForever", "DBR_CHIME_BLINK"))
    contains(table.concat(chime.watched or {}, ","), hosted("MageToolsForever", "DBR_CHIMES_ENABLED"),
        "a sub-page row watches its section switch, by the host's name")
    equal(hostPart(state, "MageToolsForever", "reminders", "rest"), "rows")
    local buff = state.row(hosted("MageToolsForever", "DBR_BUFF_ARCANEINTELLECT"))
    contains(table.concat(buff.watched or {}, ","), hosted("MageToolsForever", "DBR_ENABLED"))
    -- With Enable on the same page, its rows hang under it: no watch needed.
    equal(state.row("DBR_BUFF_ARCANEINTELLECT").watched, nil, "DBR's page: a parent row")
end)


test("tooltips: one plain sentence each (John, 2026-11-27), a short second one at most", function()
    local classes = {"MAGE", "WARLOCK", "DRUID", "PRIEST", "PALADIN", "WARRIOR", "ROGUE", "HUNTER", "SHAMAN"}
    for _, class in ipairs(classes) do
        local state = fixture({class = class, known = {[INTELLECT] = true}, newerSounds = SOUNDS})
        -- DBR's own page (the toolkit's home page has its own text).
        for _, category in pairs({state.categories[PAGE]}) do
            for _, row in ipairs(category.initializers) do
                local texts = {row.tooltip, row.data and row.data.cbTooltip, row.data and row.data.dropDownTooltip}
                for _, text in pairs(texts) do
                    if type(text) == "function" then text = text() end
                    if type(text) == "string" and text ~= "" then
                        local _, sentences = text:gsub("[%.%?!]\"?%s", "")
                        equal(sentences <= 1, true, class .. ": at most two sentences: " .. text)
                        equal(#text <= 160, true, class .. ": short: " .. text)
                        for _, word in ipairs({"Toolkit 2", "engine", "claim", "/dbr", "author", "John"}) do
                            equal(text:find(word, 1, true), nil, class .. ": no \"" .. word .. "\": " .. text)
                        end
                    end
                end
            end
        end
    end
end)


test("Pet taunt with Dyre's Threat and Combat Tools: it warns, DBR stays quiet, and the switch names it", function()
    local state = fixture({class = "HUNTER", known = {[883] = true}, lateClaim = true})
    equal(state.dbr.PetTauntOwner(), nil, "no owner: DBR warns")
    local row, live = petTauntSwitch(state)
    equal(live, true)
    equal(row.tooltip():find("Greyed out", 1, true), nil, "no note")
    state.toolkit.ClaimOwner("warn:petTaunt", "DyresCombatTools", 10)
    state.advance(1)
    equal(state.dbr.PetTauntOwner(), "DyresCombatTools")
    growlInGroup(state)
    equal(state.count("Pet taunt on"), 0, "one warning only: Dyre's Threat and Combat Tools'")
    state.emit("PLAYER_REGEN_DISABLED")
    equal(state.count("Pet taunt on"), 0, "nothing as combat starts")
    row, live = petTauntSwitch(state)
    equal(live, false, "greyed")
    contains(row.tooltip(), "Greyed out: Dyre's Threat and Combat Tools gives this warning now.")
    state.slash("debug")
    contains(state.find("debug warning hunterPetTaunt"), "owner=DyresCombatTools")
    -- DBR's own claim (none today) would not count as another AddOn's.
    local own = fixture({class = "HUNTER", known = {[883] = true}, lateClaim = true})
    own.toolkit.ClaimOwner("warn:petTaunt", ADDON, 10)
    equal(own.dbr.PetTauntOwner(), nil, "DBR itself: DBR warns")
end)


-- John, 2026-11-27, layout mode: an empty "Warning messages" outline (DBR's)
-- beside Dyre's Threat and Combat Tools' one. DBR's box, outline and all,
-- hides while it can give no warning.
test("Warning box: hidden while DBR can give no warning (another AddOn owns pet taunt, or the switch is off)", function()
    local state = fixture({class = "HUNTER", known = {[883] = true}, lateClaim = true})
    local frame = state.env.DyresBuffRemindersWarning
    equal(frame.shown, true, "no owner: DBR's box")
    local points = #frame.points
    state.toolkit.ClaimOwner("warn:petTaunt", "DyresCombatTools", 10)
    state.advance(1)
    equal(frame.shown, false, "Dyre's Threat and Combat Tools warns: DBR's box hides")
    state.slash("unlock")
    equal(frame.shown, false, "unlocked: no empty outline (it is the box's child)")
    equal(warningShown(state), false, "no sample")
    state.slash("lock")
    equal(#frame.points, points, "its place stays")
    state.toolkit.SetOwnerEnabled("warn:petTaunt", "DyresCombatTools", false)
    state.advance(1)
    equal(frame.shown, true, "the owner steps aside: DBR's box again")
    state.settings.DBR_WARN_HUNTERPETTAUNT:SetValue(false)
    state.advance(1)
    equal(frame.shown, false, "DBR's switch off: hidden")
    state.settings.DBR_WARN_HUNTERPETTAUNT:SetValue(true)
    state.advance(1)
    equal(frame.shown, true, "on again: shown")
    state.settings.DBR_ENABLED:SetValue(false)
    state.advance(1)
    equal(frame.shown, false, "the reminders off: hidden")
    state.settings.DBR_ENABLED:SetValue(true)
    state.advance(1)
    -- A warning that shows is never cut off: the box hides when it fades.
    growlInGroup(state)
    equal(state.count(GROWL), 1)
    local shown, content = warningShown(state)
    equal(shown, true)
    state.toolkit.SetOwnerEnabled("warn:petTaunt", "DyresCombatTools", true)
    state.advance(1)
    equal(frame.shown, true, "still showing: the box stays")
    content.animation:Stop()
    content.animation.scripts.OnFinished()
    equal(frame.shown, false, "faded: the box hides")
    -- A Paladin's Righteous Fury warning keeps its box.
    local paladin = fixture({class = "PALADIN", known = {[25780] = true}})
    equal(paladin.env.DyresBuffRemindersWarning.shown, true)
end)

test("Warning box: unlocked, the sample is the class's own warning, not always the pet taunt", function()
    local cases = {
        {"PALADIN", {[25780] = true}, "Righteous Fury is on", "You're not the tank. Turn it off."},
        {"HUNTER", {[883] = true}, "Pet taunt on", "Growl is on autocast in a group. Turn it off."},
        {"WARLOCK", {[697] = true}, "Pet taunt on", "Torment is on autocast in a group. Turn it off."},
    }
    for _, case in ipairs(cases) do
        local state = fixture({class = case[1], known = case[2]})
        if case[1] ~= "PALADIN" then
            state.toolkit.SetOwnerEnabled("warn:petTaunt", "DyresToolkit", false)
            state.advance(1)
        end
        state.slash("unlock")
        local shown, content = warningShown(state)
        equal(shown, true, case[1] .. ": a sample")
        local pop = state.env.DyresBuffRemindersWarning
        equal(pop.shown, true, case[1] .. ": the box")
        local texts = {}
        for _, region in ipairs(content.children) do
            if region.text then texts[#texts + 1] = region.text end
        end
        equal(table.concat(texts, "|"), case[3] .. "|" .. case[4], case[1])
        state.slash("lock")
        equal(warningShown(state), false, case[1] .. ": locked, no sample")
    end
end)

partTest("procs: every Warlock proc is listed, greyed until learned, on a host and on DBR's page (no banner)", function()
    if not HAS_PROC_ENGINE then
        io.write("# skipped (no proc engine 2 in ", TOOLKIT_DIR, ")\n")
        return
    end
    local function shown(row)
        for _, predicate in ipairs(row.shownPredicates or {}) do
            if not predicate() then return false end
        end
        return true
    end
    local state = fixture({class = "WARLOCK", procEngine = true, known = {}})
    local result, page = hostPart(state, "WarlockToolsForever", "procs", "rest")
    equal(result, "rows")
    for _, row in ipairs(page.initializers) do
        equal(row.template == state.toolkit.SETTINGS_PRIMER_TEMPLATE, false, "no banner")
    end
    for _, key in ipairs({"nightfall", "decimation"}) do
        local arc = state.row(hosted("WarlockToolsForever", ("DYRE_DYRESBUFFREMINDERS_PROC_" .. key .. "_ARC"):upper()))
        equal(type(arc), "table", key .. " listed")
        equal(shown(arc), true, key .. " shown")
        equal(active(arc), false, key .. " greyed while not learned")
    end
    local ownArc = cueRow(state, "nightfall", "arc")
    equal(shown(ownArc) and not active(ownArc), true, "DBR's page: listed, greyed")
    state.known[NIGHTFALL_TALENT] = true
    state.emit("SPELLS_CHANGED")
    state.advance(1)
    equal(active(state.row(hosted("WarlockToolsForever", "DYRE_DYRESBUFFREMINDERS_PROC_NIGHTFALL_ARC"))), true,
        "learned: Nightfall's row is live")
    equal(active(state.row(hosted("WarlockToolsForever", "DYRE_DYRESBUFFREMINDERS_PROC_DECIMATION_ARC"))), false,
        "Decimation still greyed")
end)

-- One name per section (John, 2026-11-27: "let's use the same name
-- consistently everywhere"), and WTF with no filters shows all of a Warlock's.
partTest("names: Reminders, Chimes, Procs on DBR's page, as section titles, and on a host's top page", function()
    local state = fixture({class = "WARLOCK", newerSounds = SOUNDS})
    if type(state.toolkit.SettingsSectionTitle) == "function" then
        equal(state.toolkit.SettingsSectionTitle(ADDON, "reminders"), "Reminders")
        equal(state.toolkit.SettingsSectionTitle(ADDON, "chimes"), "Chimes")
        equal(state.toolkit.SettingsSectionTitle(ADDON, "procs"), "Procs")
    end
    local headings = {}
    for _, row in ipairs(state.headings) do headings[row.heading] = true end
    equal(headings.Reminders and headings.Chimes and headings.Procs, true, "DBR's headings")
    for key, variable in pairs({reminders = "DBR_ENABLED", chimes = "DBR_CHIMES_ENABLED", procs = "DBR_PROCS_ENABLED"}) do
        equal(hostPart(state, "WarlockToolsForever", key, "master"), "rows")
        equal(state.settings[hosted("WarlockToolsForever", variable)].name,
            state.toolkit.SettingsSectionTitle and state.toolkit.SettingsSectionTitle(ADDON, key)
                or ({reminders = "Reminders", chimes = "Chimes", procs = "Procs"})[key], key)
    end
end)

partTest("WTF without filters: every Warlock reminder, warning, chime, and proc", function()
    local state = fixture({class = "WARLOCK", newerSounds = SOUNDS})
    equal(hostPart(state, "WarlockToolsForever", "reminders", "rest"), "rows")
    equal(hostPart(state, "WarlockToolsForever", "chimes", "rest"), "rows")
    equal(hostPart(state, "WarlockToolsForever", "procs", "rest"), "rows")
    for _, variable in ipairs({"DBR_BUFF_DEMONARMOR", "DBR_BUFF_WARLOCKPET", "DBR_WARN_WARLOCKPETTAUNT",
            "DBR_CHIME_DEATHCOIL", "DBR_CHIME_FELDOMINATION", "DBR_PROC_NIGHTFALL"}) do
        equal(type(state.row(hosted("WarlockToolsForever", variable))), "table", variable)
    end
    for _, reminder in ipairs(state.dbr.ClassReminders()) do
        equal(type(state.row(hosted("WarlockToolsForever", "DBR_BUFF_" .. reminder.key:upper()))), "table",
            reminder.key)
    end
    for _, chime in ipairs(state.dbr.ClassChimes("WARLOCK")) do
        equal(type(state.row(hosted("WarlockToolsForever", "DBR_CHIME_" .. chime.key:upper()))), "table", chime.key)
    end
    if HAS_PROC_ENGINE then
        local engine = fixture({class = "WARLOCK", procEngine = true, known = {[NIGHTFALL_TALENT] = true}})
        equal(hostPart(engine, "WarlockToolsForever", "procs", "rest"), "rows")
        for _, proc in ipairs(engine.dbr.ProcCuesHandle().List()) do
            equal(type(engine.row(hosted("WarlockToolsForever",
                ("DYRE_DYRESBUFFREMINDERS_PROC_" .. proc.key .. "_ARC"):upper()))), "table", proc.key)
        end
    end
end)

partTest("buttons: the icons' Reset size greys its label with the rows (Toolkit's GreyButtonLabel)", function()
    local probe = fixture({class = "MAGE", known = {[INTELLECT] = true}})
    if type(probe.toolkit.GreyButtonLabel) ~= "function" then
        io.write("# skipped (no GreyButtonLabel in ", TOOLKIT_DIR, ")\n")
        return
    end
    local greyed = {}
    local state = fixture({class = "MAGE", known = {[INTELLECT] = true}, beforeLogin = function(env)
        local original = env.DyresToolkit.GreyButtonLabel
        env.DyresToolkit.GreyButtonLabel = function(row) greyed[#greyed + 1] = row; return original(row) end
    end})
    local reset
    for _, row in ipairs(state.categories[PAGE].initializers) do
        if row.kind == "button" and row.label == "Reminder icons" then reset = row end
    end
    equal(type(reset), "table")
    local found = false
    for _, row in ipairs(greyed) do found = found or row == reset end
    equal(found, true, "the Reset size button")
end)

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
