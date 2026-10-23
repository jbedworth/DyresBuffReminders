# Agent Guidelines

## Project purpose and scope

Dyre's Buff Reminders (DBR, `/dbr`) is a World of Warcraft: Forever AddOn
that ships the buff reminders from Mage Tools Forever (MTF) and Warlock Tools
Forever (WTF) on their own, for any class with a buff list, and the cooldown
chimes (author: Dyre's Cooldown Chimes, DCC, merged into DBR before it
shipped; the name stays Dyre's Buff Reminders). Keep this feature set; do
not add speculative features or frameworks without agreement.

Ownership (coordinator): this session owns DBR only. Never edit MTF or WTF;
ask the coordinator (Dyre's Addons Lead) for changes there. The shared-layout
plan across AddOns is on hold; bring it to the coordinator first.

Naming (author-approved): the title starts with "Dyre's", so players can find
all of the author's AddOns by searching for it. The apostrophe is only in the
title: the folder, TOC, repository, saved variables, and globals use
`DyresBuffReminders`. Commands `/dbr` and `/buffreminders` (backup), chat
prefix `DBR:`. Listings say plainly that it is for WoW: Forever.

### Shared AddOns (author-approved)

- Features duplicated between MTF, WTF, and other classes move into their own
  "Dyre's" AddOns: Dyre's Sounds (library), Dyre's Shields Up, this one, and
  Dyre's Cooldown Chimes.
- The move is in two steps: first DBR ships while MTF and WTF keep their own
  reminders and stand aside when `DyresBuffReminders` is loaded (from their
  0.3.0-beta: `C_AddOns.IsAddOnLoaded("DyresBuffReminders")` hides their
  icons and greys out their reminder settings); later MTF and WTF drop
  theirs, with a CHANGELOG note and a chat message.
- The rule for every shared feature (author): the stand-alone Dyre's AddOn
  wins when it is installed; MTF and WTF grey out their settings for it and
  do not draw it. This holds until everything is published and the class
  AddOns drop their copies.
- Chat and error messages name only CurseForge as where to get something
  ("Get it from CurseForge."), never GitHub, for now (author).
- DBR plays no sounds. If it ever does, they come from Dyre's Sounds (never
  shipped here), and it says "install Dyre's Sounds" at most once (author).
- All layout, dragging, snapping, modifier keys, resizing, and saving live
  in Dyre's Toolkit (author's rule, 2026-10-20): every DBR frame is a toolkit
  widget, and DBR never moves, scales, or saves a frame itself.

### The reminders (built)

- Buffs.lua holds the lists, by class (author-approved for v1: Mage, Warlock,
  Druid, Priest, and Paladin self buffs only, and from 1.1.0 the Hunter's
  Aspect, plus the seal timer). Classic spell IDs, matched by name, so every rank counts;
  only buffs you know show. Keys are saved per character and unique across
  classes. The class picks the list (data, not a gate); a class without one
  says so once at login and shows nothing. Paladin: Righteous Fury only
  (author: self buffs; blessings are per member and situational, and
  PallyPower exists).
- Mage: Arcane Intellect (group, mana users; Arcane Brilliance 23028, Arcane
  Powder 17020), Armor (Frost, Ice, Mage; recasts the last used, else Mage,
  Ice, Frost). Dampen or Amplify Magic (author, 1.3.0: "add to DBR, off by
  default"; left out in 1.2.0): one reminder, as MTF's, key `dampen` (the two
  cannot be on you together), every rank of both, `prefer` Dampen then
  Amplify, recasting the last one cast; on you only.
- Imports (author, 1.3.0): on DBR's first run on a character (no
  `db.spells` saved yet; an existing DBR setting wins), `ImportReminders`
  reads `MageToolsForeverDB.reminders` for a Mage (enabled, group →
  arcaneIntellect's group, spells intellect/armor/dampen → arcaneIntellect,
  mageArmor, dampen, last armor/dampen) or `WarlockToolsForeverDB.reminders`
  for a Warlock (enabled, spells.armor → demonArmor, last.armor), booleans
  and strings only, read only, never their icon places (author: "start
  fresh"), with one chat line naming the source. MTF's and WTF's armor
  clicks used the same rule (last cast, else `prefer`), so the click is
  unchanged; DBR's also works in combat.
  Hunter (author, 1.1.0): Aspect (My buffs, on by default): Hawk, Monkey,
  Wild, Beast, Cheetah, or Pack counts as up; a click recasts the last
  combat aspect cast (`db.last.aspect`), else Hawk, else Monkey. Cheetah and
  Pack (`forget`) are never remembered nor recast: they daze when you are
  hit. Casts are remembered by ID, else by name (a renumbered rank). Aspect
  clicks are macros "/use !Name" (author: "!" never toggles an aspect off;
  pinned SlashCommands.lua:377-387, /use hands the "!" name to
  CastSpellByName, as /cast does).
- Combat aspect (author, 1.1.0): a secure button
  (`DyresBuffRemindersCombatAspect`) that is no widget of its own (author:
  to the player "this should behave like 1 widget"): parented to UIParent
  and anchored, out of combat, CENTER on the Aspect widget, above its aura
  slot; it takes that widget's scale (onLayout) and opacity (onOpacity). No sample when unlocked: the Aspect slot
  is the one to drag. `db.combatAspect` keeps only enabled, soundOn, and
  sound (a pre-release's place, scale, and opacity are dropped). Its switch
  works with the Aspect reminder off. Armed out of combat only: while
  Cheetah or Pack is up, macrotext "/use !<combat aspect>" and driver
  "[combat] show; hide"; else "hide". `SecureHandlerWrapScript` (pinned
  Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua:602) hides it after
  a click (post-body `self:Hide()`; clicks on release only); without it,
  no button. The player's own combat-aspect cast in combat dims its texture
  to 0.4 and stops the pulse, never alpha 0 (invisible frames must not take
  clicks). Optional sound at `PLAYER_REGEN_DISABLED` (Dyre's Sounds, its
  own switch, default "talent"). Nothing changes secure state in combat.
  Warrior (author, 1.2.0): Battle Shout (others, so Group buffs; watched on
  you; 6673, 5242, 6192, 11549, 11550, 11551, 25289). Its own lead
  (Buffs.lua `lead`, author: "I usually don't let BS get below 1 min"):
  5-120 s, step 5, default 60, saved in `db.leads`; any reminder with
  `lead` gets this setting under its switch, the rest use the shared one.
  No in-combat timing (author, after a probe: "let's go back to the somewhat
  simpler solution"): AddOns cannot see a buff drop in combat. Found in
  client: the engine's slot frame is forbidden to AddOn code then (IsShown
  errors on it, though IsForbidden says false), and a buff cannot be read by
  spell ID then (aura probe: Mark of the Wild and Thorns turn secret,
  `ShouldSpellAuraBeSecret` true, `GetPlayerAuraBySpellID` returns
  nothing). Never touch the engine's slot frames outside initializeFrame.
  Warlock: Demon Armor
  (Demon Skin counts; recasts the last used, else Demon Armor, Demon Skin).
  Druid: Mark of the Wild (group, everyone; Gift of the Wild ranks with Wild
  Berries or Wild Thornroot), Thorns (author, a Druid player: on the tank). Thorns watches one unit and a
  click casts on it: the first group member in group order whose
  `UnitGroupRolesAssigned` is "TANK" (pinned UnitDocumentation.lua:1318; may
  be secret, then not a tank) and who is alive, online, in sight, and in
  Thorns' range (`C_Spell.IsSpellInRange`; unreadable counts as in range);
  you when you are the tank, solo, with no tank, with no tank in reach
  (author: "Tank dead, out of range, etc., watch me"), or without the API
  (TankHelper calls it on Forever). Range has no polling (family rule): a
  Druid's DBR also listens to `UNIT_IN_RANGE_UPDATE` (pinned
  UnitDocumentation.lua:4328, the group frames' range, about 40 yards, not
  Thorns' 30) and `UNIT_CONNECTION`, for group units only, so walking past
  the group frames' range re-checks at once; a tank between 30 and 40 yards
  is re-checked at the next aura, roster, role, or combat-end event. Out of combat only, so `PLAYER_ROLES_ASSIGNED`,
  `ROLE_CHANGED_INFORM`, and roster changes in combat apply after it. The
  tooltip says "Thorns: on you" or "on <name>". The click's unit is the
  tank's token (`party2`), set out of combat: a roster change in combat can
  shift the token to another player until combat ends (documented to the
  player). A name instead was not taken: `CastSpellByName` is a legacy
  global, not in the pinned generated docs, so whether its unit accepts a
  name cannot be confirmed from source, and names can be secret. While the
  watched tank has it (author, 1.2.0, "Go with A"): the slot draws only your
  own buffs, so our icon shows above it with the tank's time left (a
  cooldown set out of combat), no border, armed to recast on the tank
  (`TankAction`, with /cancelform); yellow from the lead and red at the
  tank's known end, by alpha, also in combat; a recast on the targeted tank
  in combat restarts both. A dispel on the tank in combat is not seen until
  after. The Thorns switch's tooltip keeps to the key points (author: "Maintains
  Thorns on you or the designated group Tank"); README and this file hold
  the rest. Priest: Power Word: Fortitude
  (group, everyone; Prayer of Fortitude ranks with Holy or Sacred Candles),
  Inner Fire (self), Divine Spirit (off; group, mana users; Prayer of Spirit),
  Shadow Protection (off; group, everyone; Prayer of Shadow Protection).
  Paladin: Righteous Fury (25780, self; author, 1.2.0: a long buff shown only for
  a tank, `tankOnly`: the Tank role via `UnitGroupRolesAssigned` (secret or
  missing counts as no), Improved Righteous Fury (`IsSpellKnown` on Classic
  20468-20470, or a point in a talent whose spell name holds the buff's
  name, from the active C_Traits config: node `activeRank`, entry,
  definition `spellID`, so a renumbered ID or another language still finds
  it; confirmed in client on a prot Paladin), or the per-character "Always
  show Righteous Fury" (`db.alwaysShow`, off); re-checked on roles, roster,
  `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED`, and `SPELLS_CHANGED`, out of
  combat; the talent names are read again only after those events or
  `PLAYER_ENTERING_WORLD`). Ask the author before changing
  defaults.
- Running out (author, 1.2.0: "For a buff that lasts 30-60 min, a 0-60
  second reminder might need a bigger window"; for every buff, also group
  members'): a buff runs out while it has at most `db.leadPercent` percent
  of its own length left (0-20, default 10, a slider with the toolkit's
  default mark, its value as "10%"; no end labels, found in client: the
  pinned MinimalSlider's Min and Max labels crowded the next row; 0 warns
  only once gone). Labels whose value shows "%" carry no "(%)" (author:
  "everything looks consistent"), and DBR's own percent sliders show "%" as
  the toolkit's do. The length is the aura's `duration`
  read out of combat, per unit and rank, else Buffs.lua's `duration`, else
  it counts as running out at once. A buff with its own `lead` (Battle
  Shout) keeps that in seconds. 1.1.0's `db.lead` (seconds) is dropped; the
  percent starts at its default. From the aura's `expirationTime` read out of
  combat; one `C_Timer.After` timer, tokened so a newer refresh makes older
  ones do nothing, refreshes when the earliest buff reaches the lead time;
  no polling. A secret or missing end time counts as on. The tooltip splits
  "Missing" from "Running out".
- Borders (author: "our 'watcher' should give a red outline if it's at 0
  (or down), a yellow flashing if it's in the warning window, otherwise, no
  border"): red (1, 0.2, 0.2), steady, on our icon while the buff is missing,
  also while it waits under the slot, so it shows the moment the slot goes;
  none while ours is raised and only running out. Yellow (1, 1, 0), flashing
  (Alpha, BOUNCE), on a plain frame above the slot (and above our raised
  icon, below the combat aspect button), no mouse, shown by alpha only, so it
  changes in combat: from the lead until the known end of the watched unit's
  buff (yours, or the tank's), one tokened `C_Timer` per edge; at the end it
  goes, and the red one under the slot shows. Out of combat a group
  member's running out turns it on until the next refresh; anyone missing it
  makes it red instead. In combat your own cast (`UNIT_SPELLCAST_SUCCEEDED`,
  readable then) restarts the time, with the last read's length, else
  `duration`: a group version, a `castOnYou` buff (Battle Shout), or a
  self-only buff always; a single-target one when it went on the timed unit
  (the event names no target: you, with no target, yourself targeted, or a
  target you cannot help; another unit, when it is your target; a secret
  answer counts as not). The combat aspect button keeps its pulsing gold
  border; the seal timer and ammo are unchanged.
- Druid forms (author-approved): buffs with `cancelForm` (Mark of the Wild,
  Thorns) click as a `macrotext` "/cancelform" then "/use [@unit] Name"
  while any form is active (`GetShapeshiftFormInfo`, refreshed on
  `UPDATE_SHAPESHIFT_FORM`); a group version is cast as `Name(Rank N)`
  (`C_Spell.GetSpellSubtext`) for its reagent. Going back into the form
  cannot be automatic: casts need a hardware press and the form waits for
  the global cooldown.
- One icon per buff, with the borders above. Group buffs (a switch each,
  on by default) count party or raid members, skipping dead, offline, or
  out-of-sight members, and for mana buffs warriors and rogues; the icon
  shows the count and its tooltip who.
- A click casts the buff (`SecureActionButtonTemplate`, `type1` spell,
  `spell1`, `unit1`): you first, then the first member who lacks it and is
  in range (`C_Spell.IsSpellInRange` not false), else the first. Single buffs
  are cast by name (the highest rank); with two or more missing, the best
  group version you know and carry the reagent for, by ID, since each rank
  has its own reagent (`SECURE_ACTIONS.spell` casts a number with
  `CastSpellByID`). Buffs with `prefer` remember the last one you cast
  (`db.last`). Unlocked icons cast nothing, so dragging is safe. An icon's
  picture is always the spell its click casts (author), also unlocked: the
  action's spell, else the spell a click would cast now.
- Aura APIs refuse AddOn code in combat, so DBR reads auras only out of
  combat. Secure icons change only out of combat; changes asked for in
  combat wait for `PLAYER_REGEN_ENABLED`. After a reload in combat, the
  widgets and icons are created only when combat ends.
- Design rule (author, 1.2.0: "there is a difference between how short
  duration/situational and long duration buffs should behave"): short or
  situational buffs (the seal timer, Battle Shout) show only when needed or
  ticking; long buffs (Mark of the Wild, Thorns, Arcane Intellect, armors,
  Fortitude, and the like) are always shown, drawn by the engine while up,
  with our reminder when missing. In Buffs.lua, `combatWindow = true` marks a
  short buff (only Battle Shout now): its slot is transparent out of combat
  and its icon hidden while up outside its lead; in combat DBR's own timer
  (expiry from the last out-of-combat read, reset by your own cast,
  `duration` 120 without a read) opens it at the lead, by alpha. A drop in
  combat shows at the window time (author: accepted for Battle Shout). The
  seal timer is its own design, unchanged.
- Always shown (author, 1.2.0: "If it's always there, it might not be as
  jarring"): each buff widget has a Blizzard AuraContainer slot (player
  only, every rank and group-version ID as `includeSpellIDs`, set up only in
  initializeFrame, no mouse, no duration text or bar), visible in and out of
  combat, that draws the buff while it is up. Our icon is always shown while
  the buff is known and switched on (not dead, not on a taxi), its red
  border inside the icon so the slot covers it whole. Out of combat, DBR
  sets its level: under the slot while the buff is up on everyone (armed to
  recast it on you, `ArmedAction`, a Druid's with /cancelform), above it
  while anyone lacks it or yours runs out (smart click, countdown). In
  combat our icon's level does not change: when a buff drops the engine
  hides its slot and the red-bordered icon shows through. A state above the slot at combat start
  stays until combat ends. Without the container, up buffs' icons hide, as
  before 1.2.0.
- No reminders on a flight path (author: one you cannot act on is noise):
  `UnitOnTaxi("player")` (pinned UnitDocumentation.lua:2570; secret or
  missing counts as no) hides the icons like being dead, re-checked on
  `PLAYER_CONTROL_LOST` and `PLAYER_CONTROL_GAINED` (pinned
  LossOfControlDocumentation.lua:133-139); unlocked, samples still show.
  Mounted, they show (a click while mounted is the game's to refuse, and you
  can dismount). The Consumables bar stays (information).
- Events in bursts (`UNIT_AURA` from a group buff) refresh once, 0.2 s after
  the first; only the player's, party, and raid units' auras count.
- Each buff is its own toolkit widget (author, 1.2.0), like the seal timer:
  `DyresBuffRemindersBuff_<key>`, key `buff_<key>`, its own store
  `db.buffs[key]` (toolkit owner: one store per widget, for 2.3.0 stacks),
  40x40, mouse "unlocked", the icon a drag handle. Its place never changes
  on its own (author: "I don't want the bars to change order or position").
  A buff not known or switched off hides its holder; otherwise the holder
  stays shown and only its icon hides. Defaults: two rows, 20 apart (the
  toolkit's snap gap): buffs that can go on another player (Buffs.lua's
  `group` or `others`) at 180 above the center, self buffs at 130. 1.1.0's
  bar places (`db.bars`) seed each buff's place once (bar center plus its
  slot, with the bar's scale), then are dropped. One "Reminder icons" Size and
  Opacity for all, set on every buff widget, with "Reset size". Toolkit
  2.3.0 stacks (Alt to detach) are planned for these and the seal widget.

### The seal timer (built; author-approved)

- Paladins only, a setting (on by default). Every rank of every seal counts:
  the six Classic seals and Forever's Seal of Fury (found in client: the
  timer missed it; IDs from ForeverAuras' spell table), plus any learned
  spellbook spell named "Seal of ..." (a new one gets a new container out of
  combat, since a slot's IDs are fixed). The last seal cast is remembered by
  name.
- Aura APIs refuse AddOn code in combat, so Blizzard's AuraContainer
  (`CustomAuraContainerTemplate`, `includeSpellIDs` as a set) draws the seal:
  one slot with every seal ID shows the seal's icon, a cooldown sweep with
  numbers, and a draining bar (`SetDurationBar`, RemainingTime), in and out
  of combat. The slot takes no mouse.
- Under it, a secure button (`DyresBuffRemindersSealButton`) shows in combat
  only (`[combat] show; hide`): the last seal you used (else Righteousness,
  else the first known) with the pulsing gold border and a full gold bar where
  the timer's bar drains (author-approved: Righteous Fury and Seal of Fury
  share a picture, so the bar tells the seal reminder apart; the timer's bar
  has an opaque track, so the gold bar never shows through); a click casts
  it. A seal
  up covers it (the slot is drawn above), so it shows through only with no
  seal. Out of combat with no seal, nothing shows (author: see how it feels).
- A seal cast (readable in combat) is saved (`db.last.seal`); the button's
  attributes change only out of combat. The display
  (`DyresBuffRemindersSeal`) is a toolkit widget (key `seal`, store
  `db.seal`, whose `position` and `scale` keys carry over from 1.0.0; Size
  50-200%, Opacity). Unlocked, the button is hidden (`hide`) so the display
  takes the drag, and a sample shows. After a reload in combat, it is set up
  when combat ends. Without the aura container, it stays off with one
  message.

### Consumables: ammo (built, 1.1.0; author-approved, Part B's first item)

- By class since 1.2.0 (author: "only classes that could equip a ranged
  weapon that requires ammo should see that"): `DBR.CONSUMABLES[class]`,
  data that picks the list as Buffs.lua does, `ammo = true` for Hunter,
  Warrior, and Rogue. A class with no entry gets no Consumables bar, no
  unlocked sample, and no Consumables or size rows.
- With a Bow, Crossbow, or Gun in the ranged slot:
  `C_Item.GetItemInfoInstant` on `GetInventoryItemID("player",
  INVSLOT_RANGED)`, classID 2 and subclass Bows 2, Guns 3, Crossbow 18
  (pinned ItemConstantsDocumentation.lua). Thrown 16, Wand 19, or none: no
  slot. Bows and crossbows take arrows, guns bullets.
- Count: `GetInventoryItemCount("player", 0)` (the ammo slot; the total of
  the equipped ammo across your bags). It and `GetInventoryItemID` are
  legacy globals not in the generated docs: guarded, and a missing API or a
  secret count keeps the last readable count ("?" before any); `/dbr debug`
  shows `countAPI=ok|secret|missing`.
- No ammo equipped: missing, with "Equip your arrows/bullets." when a bag
  holds that kind (Classic projectile subclasses Arrow 2, Bullet 3; the
  generated docs list none), else "No arrows/bullets in your bags."
- The Consumables bar (`DyresBuffRemindersConsumables`, widget
  `consumables`, store `db.consumables`, default 150 right of My buffs'
  place): a plain frame, mouse "unlocked" (click-through while locked); the
  icon takes hover only (`SetMouseClickEnabled(false)`, motion on) for its
  tooltip. The equipped ammo's icon, else a default arrow or bullet icon,
  and the count (size 12, THICKOUTLINE and a black 1,-1 shadow, held inside the icon so four digits
  fit): red count and red pulsing border (the count's red) at or below Warn
  at (0-1000, step 50, default 200), missing (greyed, red pulsing border)
  at 0; else a gold border. Updates on
  `BAG_UPDATE_DELAYED`, `UNIT_INVENTORY_CHANGED` (player), and
  `PLAYER_EQUIPMENT_CHANGED`, also in combat (no secure parts).
- Settings: a "Consumables" section, for a class with an entry: Enable
  (`DBR_CONSUMABLES_ENABLED`), Ammo (`DBR_CONSUMABLE_AMMO`), Warn at
  (`DBR_AMMO_WARN`) for an ammo class, then each reagent; not tied to the
  Reminders switch.

### Consumables: reagents (built, 1.2.0; author-approved: "In")

- `DBR.CONSUMABLES[class].reagents`: {key, label, warn = {min, max, step,
  default}, ranks = {{spell, item, name}...}}, general for any class, only
  DRUID, MAGE, and WARLOCK now (1.3.0, author: "mage Arcane Powder, add.
  Keep portal runes in MTF. Infernal Stones and Demonic Figurine add"):
  Arcane Brilliance 23028 Arcane Powder 17020 (0-40, default 5); Inferno
  1122 Infernal Stone 5565 and Ritual of Doom 18540 Demonic Figurine 16583
  (0-10, default 1). The Consumables section shows only with ammo or a
  reagent spell known at login. Rebirth (20484, 20739, 20742, 20747, 20748: Maple 17034,
  Stranglethorn 17035, Ashwood 17036, Hornbeam 17037, Ironwood 17038 Seed;
  Warn at 0-10, default 2, author) and Gift of the Wild (21849 Wild Berries
  17021, 21850 Wild Thornroot 17026; 0-40, default 5; not on Forever before
  launch, so data only: it shows once known). Classic IDs, not in the
  pinned source; `/dbr debug` prints each rank's spell and item names to
  confirm them (found in client: all seven spell IDs and Rebirth R1-R2's
  seeds resolve). An item the client has not loaded reads "(not cached,
  loading)": DBR asks for it (`C_Item.RequestLoadItemDataByID`) and prints
  its name on `ITEM_DATA_LOAD_RESULT`, or that the ID is wrong when the load
  fails; an unknown spell's summary reads "rank=not known". The counter and
  tooltip never need the item's name (the data's name is the fallback).
- The highest rank known (`C_SpellBook.IsSpellKnown`, re-read on
  `SPELLS_CHANGED`) picks the item; none known, nothing. Count:
  `C_Item.GetItemCount`, a secret or missing answer keeps the last readable
  count for that item. As ammo: red count and red pulsing border at or below
  Warn at, greyed at 0, gold and white otherwise; hover-only tooltip with
  the item's name, "N left; warns at W.", and "For Rebirth (Rank N).".
- The same Consumables bar: ammo first, then each reagent, 10 apart, the bar
  as wide as its shown icons (`SetContentSize`, anchored LEFT), hidden with
  none. Saved in `db.consumables.reagents[key] = {on, warn}`, repaired for
  every class's reagents. Settings: "<label> reagent" (`DBR_REAGENT_<KEY>`)
  and its Warn at (`DBR_REAGENT_WARN_<KEY>`, the toolkit's default mark),
  for each reagent whose spell is known when the page is built (at login).

### Cooldown chimes (built; merged from DCC)

- Every rank counts (author's reason for the chimes, central): Blizzard's
  Cooldown Manager on Forever makes you manage each rank as a different
  spell. Each ChimeSpells.lua entry holds one Classic spell ID, whose name
  (read at login) is looked up for every cast. Never match chimes by spell
  ID, and never add one entry per rank. Spell data stays data-driven in
  ChimeSpells.lua (`CHIME_SPELLS`, `CHIME_CLASS_ORDER`); Mage is MTF's list
  and Warlock WTF's; the other classes are new and not yet checked in client.
- The combat log is closed and `C_Spell.GetSpellCooldown` is secret in
  combat, and no event fires when a cooldown ends; the player's own
  `UNIT_SPELLCAST_SUCCEEDED` stays readable. So each chime is timed with
  `C_Timer.After` from the cast: the length last read out of combat (saved,
  1.5 s to 1 h), else Classic's, minus the lead (0-3 s in 0.5 s steps,
  default 0.5). 0.1 s after a cast DBR reads the real cooldown when readable
  (never secret, longer than the global cooldown), learns it, and
  reschedules; a newer cast replaces the schedule. `resets` cancels a group
  (Cold Snap the Frost spells, Preparation the Rogue's).
- Saved in `db.chimes` (enabled, lead, spells, sounds, learned), separate
  from the reminders: their own switch (author: "its own on/off switch"), and
  the chime lead is not the reminders' `db.lead`.
- Sounds come only from Dyre's Sounds (contract 1: `RequireContract`,
  `Resolve`, `Play(key, speech)`, `Choices`, `SetupMenu`, plus `List`,
  `Groups`, `Label`); default "talent"; Dyre's Picks first in its menu. DBR
  ships no sound files. TOC `## OptionalDeps: DyresSounds` (never
  `## Dependencies`); CurseForge `requiredDependency` on slug `dyres-sounds`
  (`RELATIONS` in scripts/publish_curseforge.py, tested). Without the
  library (or an older contract) chimes are timed but silent, saved sound keys
  are kept, the page shows switches without sound menus, and DBR says once
  per session to install it (only with chimes on and a class list), naming
  only CurseForge; the reminders work as usual.
- First run (no `db.chimes` yet): copy DCC's saved settings
  (`DyresCooldownChimesDB`, read only, never written; only the author ever
  ran DCC) when present, else MTF's or WTF's chimes for the player's class,
  as DCC did. While DCC itself is loaded it plays and DBR plays none, and DBR
  says once to remove its folder. MTF and WTF still chime unless their
  version stands aside for DBR (`asideFrom` in `OTHER_CHIMES`: 0.3.2-beta,
  author); DBR warns once about older ones
  with their chimes on.

### Proc sounds (built; author-approved)

- A sound when a proc buff appears on the player, also in combat, played by
  the game: `C_UnitAuras.AddAuraSound` (trigger Added, `unitToken` player,
  `outputChannel` master, `throttleSeconds` 1, one registration per buff ID,
  the file from `DyresSounds.AuraSound`), as WTF plays Nightfall.
  Registration waits out an Encounter restriction
  (`C_RestrictedActions.IsAddOnRestrictionActive`) and runs again on
  `ADDON_RESTRICTION_STATE_CHANGED`. Without the API the section is hidden.
- Data in ProcSpells.lua `PROC_SOUNDS`, per class: key, label, buff (the
  client's buff name), spells (Classic IDs; author: start with Classic's),
  on, sound. Warlock Nightfall (Shadow Trance 17941, off, sound impspell, as
  WTF); Mage Clearcasting 12536 (off: author, the game plays a sound for it);
  Druid Clearcasting 16870 (off, same reason) and Nature's Grace 16886 (on);
  Shaman Clearcasting 16246 (off); Warrior Flurry 12966-12970 (off).
  Reactive (author, 1.2.0): Warrior Overpower 7384 and Revenge 6572 (on),
  not buffs: DBR plays their sound itself when `C_Spell.IsSpellUsable`
  (by name, so every rank) turns true on `SPELL_UPDATE_USABLE`, also in
  combat (readable then: found in client with the probe), at most once per 3
  seconds each (rage makes the answer flicker); a secret answer is skipped.
  Any Dyre's Sounds sound (no aura filter). No source
  confirmed these on Forever (ForeverAuras lists only spells the author has
  had; TalentsForeverBook says Forever changed Nightfall, Nature's Grace, and
  Flurry): an ID is used only when `C_Spell.GetSpellName` names it the buff,
  and out of combat only (`UNIT_AURA` for the player, `PLAYER_REGEN_ENABLED`)
  DBR reads `GetAuraDataBySpellName(player, buff).spellId` for switched-on
  procs, saves it (`db.procs.learned`), and registers it too. Never read
  auras in combat. `/dbr debug` shows confirmed (learned) or unverified.
- Saved in `db.procs` (enabled, spells, sounds, learned). Sounds must be
  aura sounds (files): menus use filter "aura"; a saved non-file key falls
  back to the default (`magical`, Nightfall's `impspell`). First run (no
  `db.procs`): on a Warlock, copy `WarlockToolsForeverDB.alerts.nightfall`
  and `.nightfallSound` (read only). WTF's Nightfall stands aside for DBR
  0.3.0+ from WTF 0.3.3-beta (`OTHER_PROCS`, `asideFrom` {0, 3, 3}); with an
  older WTF whose Nightfall is on while DBR's is on too, DBR warns once at
  login (naming only CurseForge to update) and keeps playing, as it treats
  older MTF and WTF chimes (author's rule, chosen for consistency).
- Settings: a "Proc Chimes" section (author: renamed from "Procs") (switch "Enable", `DBR_PROCS_ENABLED`) after the chimes, for a class with
  procs: Enable, then one row per proc (switch and sound, aura filter),
  with the same two-row fallback as the chimes.

### Cast chimes (built 1.4.0; author: "a sound when Travel Form, Pact of Cheeta and Sprint fire off")

- Data in ProcSpells.lua `CAST_SOUNDS`, per class: key, label, spells
  (Classic IDs, every rank by name), on, speech (else "Meep meep"), form.
  Druid forms (author: "Shifting INTO form only, not out"; all on): Travel
  783, Bear 5487 and Dire Bear 9634 ("Rawr"), Cat 768 ("Meow"), Aquatic 1066
  ("Splash"), Moonkin 24858 ("Hoot hoot"); Dash 1850/9821/9823 (off); Hunter Aspect of the Cheetah 5118
  ("Pact of Cheeta", author's name; on) and Aspect of the Pack 13159 (off);
  Rogue Sprint 2983/8696/11305 (on). Travel Form and the aspects have no
  cooldown in Classic; Sprint and Dash are also cooldown chimes.
- A form chimes on `UPDATE_SHAPESHIFT_FORM` when the active form (the
  `GetShapeshiftFormInfo` entry that is active; its fourth value is the
  spell, as the pinned Blizzard_ActionBar/Shared/StanceBar.lua:70 reads it)
  changes to a new one, `FORM_CHIME_DELAY` (0.75 s, ProcSpells.lua) later
  and only if that form is still active then (author: "add a .75 second
  delay ... and debounce it (powershifting)"): every change, leaving too,
  bumps a token that cancels the pending chime, so Cat, caster, Cat chimes
  once and in-and-out none. Non-form cast chimes (Sprint, the aspects) stay
  immediate. Leaving a form (no form) and the same form again
  (the event repeats, also on loading) never chime, nor the form you log
  in in; a form's cast event is ignored, since leaving a form is a cast too.
- Other spells: on the player's `UNIT_SPELLCAST_SUCCEEDED` (readable in combat; a secret
  spell ID is skipped), DBR plays the spell's sound through Dyre's Sounds;
  one the client cannot play falls back to the chimes' default. Default
  sound "voice" saying "Meep meep" (`CAST_SPEECH`; the Road Runner's own
  sound is copyrighted, so DBR cannot ship it). Saved in
  `db.casts = {enabled, spells, sounds}`, repaired for every class.
- Settings: a "Cast Chimes" section after Proc Chimes, for a class with
  any: Enable (`DBR_CASTS_ENABLED`), then one row per spell (switch
  `DBR_CAST_<KEY>` and sound, any sound), with the chimes' two-row
  fallback. `/dbr debug` adds `debug casts enabled=... <key>=on|off:<sound>
  ... last=<spell>`.
- A recast that cancels an aspect may also chime: the event cannot tell (to
  confirm in client).

### Reactive-ability probe (debug only; author-approved for a test)

- `/dbr probe on|off` (saved per character as `db.probe`, off by default; no
  frames, no settings). While on, for the class's reactive spells you know
  (`PROBE_SPELLS`: Warrior Overpower 7384, Revenge 6572, Execute 5308; Rogue
  Riposte 14251; Hunter Mongoose Bite 1495, Counterattack 19306; asked for by
  name), on `SPELL_UPDATE_USABLE` it reads `C_Spell.IsSpellUsable` and prints
  one line only when a spell's state changes (usable, noMana, whether either
  is secret, in combat or not); it prints each
  `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`/`_HIDE` with its spellID and name.
  State is kept as text, "secret" for a secret value, so nothing secret is
  compared or printed. At most 20 lines per 10 seconds. It answers the
  phase 2 questions in the notes for the tracker design (reactive abilities).

### Dyre's Toolkit (author-approved, 2026-10-19)

- Shared infrastructure owned by the coordinator (src/DyresToolkit; never
  edit it here; ask the coordinator). Required from 1.1.0 (author): TOC
  `## Dependencies: DyresToolkit` and `## OptionalDeps: DyresSounds`;
  CurseForge `requiredDependency` on `dyres-toolkit` (`RELATIONS`, tested).
- At login DBR needs `DyresToolkit.RequireContract(2)` and the functions it
  uses (`DBR.Toolkit`, checked before any frame exists). Without them (no
  toolkit, or one older than 2.0.0) DBR stays off and says: "Dyre's Buff
  Reminders needs Dyre's Toolkit 2.0 or later: install or update it from
  CurseForge. DBR stays off until then."
- The toolkit owns placement, the outline and hint, dragging and snapping,
  sizes, opacity, the mouse, and combat waits (`CreateWidget`). DBR's lock
  state is the toolkit's (`IsLocked` at login; frames start locked);
  `/dbr unlock` and `/dbr lock` call `toolkit.SetLocked`, which calls back
  `DBR.ApplyLocked` (quietly; the toolkit says one line). `/dbr reset` is
  `ResetWidgets` (places only; sizes have "Reset size"). At the end of login
  DBR registers with `RegisterAddOn({addon, title, setLocked =
  DBR.ApplyLocked, openSettings = DBR.OpenSettings})`. Its settings page is
  `RegisterSettingsCategory("Dyre's Buff Reminders")` under "Dyre's AddOns",
  with `AddWidgetSettings` per widget; with no page (no settings API), `/dbr`
  says which commands to use.
- tests/run.lua loads the toolkit's real Core, Layout, Widgets, and Settings
  from a copy in tests/toolkit; a test fails when the copy differs from
  ../DyresToolkit. Copy the files again after a toolkit change.

### Commands and settings

- `/dbr` and `/dbr options` (not in combat), `unlock`, `lock`, `reset`,
  `debug` (runs even when DBR is unavailable; lists spell IDs the client does
  not know, the seal timer, and the chimes: Dyre's Sounds, other AddOns'
  chimes, each class spell, the last cast, and the latest 12 events). There
  is no `/dcc`. Backup slash `/buffreminders`; a clash on `/dbr` is reported once
  at login.
- One settings page (vertical layout, proxy settings on
  `DyresBuffRemindersDB`), under the heading "Reminders" (author: the page is
  already "Buff Reminders"): Enable (`DBR_ENABLED`), one switch per class buff with its
  group switch nested under it, Seal timer (Paladins), Remind before a buff
  runs out, then the sizes (author: "the size settings should be in
  the area of the thing they are resizing"; no shared "Size and Opacity"
  section): "Reminder icons: size" and opacity for every buff widget,
  "Reset size", then the toolkit's `AddWidgetSettings` for the seal; the
  Consumables bar's are at the end of its own section; the toolkit's "Dyre's AddOns" page has
  the one unlock switch and grid); then a
  "Chimes" section: Enable (`DBR_CHIMES_ENABLED`), Chime early (seconds), and one
  row per class spell (author-approved): its switch and Sound dropdown on
  the same row, Blizzard's `CreateSettingsCheckboxDropdownInitializer`
  (pinned Blizzard_SettingControls.lua:1670) added through the layout, with
  Dyre's Sounds' `SetupCheckboxMenu` for the nested menu (Dyre's Sounds
  0.1.2-beta; Blizzard's control greys the sound while the switch is off).
  With an older Dyre's Sounds (no `SetupCheckboxMenu`) or a client without
  that initializer, the switch, then its dropdown on its own row nested under
  it (`SetupMenu`). The settings and saved keys are the same either way. Then
  the "Proc Chimes" section (see above). Section headings appear where the
  client has
  `CreateSettingsListSectionHeaderInitializer`.

## Project structure

- Runtime files: DyresBuffReminders.toc, Commands.lua, Core.lua,
  Buffs.lua, Reminders.lua, Seals.lua, Consumables.lua, ChimeSpells.lua, Chimes.lua,
  ProcSpells.lua, Procs.lua, Probe.lua, Options.lua, loaded in that order. Commands
  parses `/dbr`; Core owns saved
  settings and their repair, the login banner, install and API checks, slash
  conflict reporting, joining Dyre's Toolkit, the lock, and startup;
  Buffs holds the buff lists; Reminders the bars and icons; Seals the Paladin seal
  timer; Consumables the Consumables bar (ammo); ChimeSpells the chime lists; Chimes the chimes and Dyre's Sounds;
  ProcSpells the proc lists; Procs the proc sounds; Probe the debug-only
  reactive-ability probe; Options the settings page.
- artwork/ holds the logo (SVG source, 1024 and 512 PNG renders) and
  screenshots/ for listings; it is never packaged.
- tests/run.lua holds the Lua 5.1 mock suite. tests/test_*.py cover the
  release helpers in scripts/; tests/toolkit holds the toolkit copy the
  suite loads. .github/workflows/
  holds CI, opt-in publishing, and the approval gate check.
- README.md is the user-facing overview, TESTING.md the verification method,
  source evidence, unverified IDs, and in-client checklist,
  docs/RELEASE_PLAN.md the release process, docs/CURSEFORGE_LISTING.md the
  CurseForge form text, docs/CLASS_COVERAGE.md the per-class coverage plan, and CHANGELOG.md the per-release change list.
- Documentation describes purpose, design, rules, and methodology. Do not add
  dated status reports or test-result logs to the docs; CHANGELOG.md is the
  release record. Keep README's claims true.
- The project uses the MIT License. The public author name is `Dyre` (TOC
  `## Author`, login banner, listings); LICENSE keeps the legal name, John
  Bedworth, and the release builder requires that exact notice.
- The TOC has `## Group: DyresToolkit` (author, 2026-10-19), so DBR nests
  under Dyre's Toolkit's "Dyre's AddOns" section in the in-game AddOn list;
  `## Category: Buffs & Debuffs` stays for when the toolkit is missing (a child
  without its parent shows at the top level) and matches the CurseForge main
  category.
- No runtime assets. Add none without agreement.
- Git origin: git@github.com:jbedworth/DyresBuffReminders.git (public, as all
  of the author's AddOns). Inspect Git state before acting and preserve user
  work. Text is LF under
  .gitattributes.

## Client and API verification

- Target: Forever beta 1.60.1, build 70450 (tested in client), Interface
  16001, Lua 5.1. Pin source review to Gethe/wow-ui-source commit
  `943764493e6b16d63ded3ab304150d1f05e58b57` (the 70338 source; the client
  was tested on 70450, still Interface 16001). Treat target-client
  documentation and FrameXML as authoritative; Retail and Classic examples are
  references only.
- Do not gate the runtime on client version, build, or Interface. Gate only on
  required APIs (Core's `REQUIRED_APIS`); the class only picks the buff list.
- The target client has Midnight's secret values and AddOn restrictions. Never
  compare, concatenate, index, or print a value that may be secret: check
  `DBR.IsSecret` first and print with `DBR.Describe`.
- Never register `COMBAT_LOG_EVENT_UNFILTERED`: the client refuses it.
- WoW APIs can return no values rather than nil; store results in locals before
  passing them to `tostring`. The client may not show Lua error popups, so
  diagnostics report errors in chat.

## Clean coding

- Lua 5.1 syntax and libraries only. Four-space indentation. Prefer local
  variables and functions; share state through the AddOn namespace. Expose
  globals only when WoW requires them (slash commands, saved variables, named
  frames), prefixed `DyresBuffReminders` or `DBR`.
- Centralize meaningful constants; avoid unexplained magic numbers.
- Comment sparingly: non-obvious intent, API constraints, or tradeoffs.
- Event-driven work only; no polling or idle `OnUpdate` handlers.

## Safety and error reporting

- Validate commands before changing settings. Treat bad commands, missing APIs,
  and mixed installs as expected failures with concise feedback prefixed
  `DBR:`.
- Never prompt or open popups in combat. Never swallow errors with blanket
  `pcall` handlers or replace the error handler.
- Repair saved settings on load so a damaged or older table cannot break DBR.
- Startup is driven by Core at `PLAYER_LOGIN`; never rely on event handler
  order between files.

## Testing and documentation

- Run `.tools/luarocks-3.13.0-win32/win32/lua5.1/bin/lua5.1.exe tests/run.lua`
  and the bundled `luac5.1.exe -p` on every Lua file. Run
  `.tools/python-3.13.7/python.exe -m unittest discover -s tests -p 'test_*.py'`
  and actionlint on workflow changes. Report actual results; never invent them.
- Add focused tests alongside behavior changes. Mocks cannot prove
  protected-action rules, secret-value behavior, layout, or taint; those need
  the in-client checks in TESTING.md.

## Releases and collaboration

- Read docs/RELEASE_PLAN.md before packaging or changing release automation.
- Do not create commits, repositories, tags, uploads, or releases unless asked.
- Every release needs a `## <version>` section in CHANGELOG.md with
  player-facing changes; the builder puts it at the top of release-notes.md
  and fails without it.
- Package only DyresBuffReminders.toc, Commands.lua, Core.lua,
  Buffs.lua, Reminders.lua, Seals.lua, Consumables.lua, ChimeSpells.lua, Chimes.lua,
  ProcSpells.lua, Procs.lua, Probe.lua, Options.lua, and LICENSE under the top-level
  `DyresBuffReminders/` folder, named `DyresBuffReminders-<version>-forever.zip`,
  with the builder's BigWigs-format `release.json` (flavor `forever`) attached
  for WowUp.
- Publishing requires repository variables `ENABLE_GITHUB_RELEASES='true'`
  and, for CurseForge, `ENABLE_CURSEFORGE_UPLOADS='true'`, plus
  `CURSEFORGE_PROJECT_ID`, `CURSEFORGE_GAME_VERSION_ID`, and the `release`
  environment secret `CF_API_TOKEN` (an environment secret, never a repository
  secret). Both publish jobs use the `release` environment with a required
  reviewer; verify the gate with `gate-check.yml` before enabling publishing.
- Action pins are full commit SHAs; review any pin change against the GitHub API.
- Commit messages, when requested: imperative, capitalized subject, at most
  about 50 characters, no ending punctuation; short wrapped body when useful.
