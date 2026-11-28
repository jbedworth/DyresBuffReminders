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

### The cue model (John, 2026-11-20; design in docs/CUE_MODEL.md)

- DBR is the home of every buff and proc cue, arcs and sounds (John: "a
  better fit for all buffs/procs (procs are really short-term triggered
  buffs) chimes and visuals"); Dyre's Shields Up keeps only the absorb-shield
  display. John: "Yes, write it into DBR's design doc and start".
- Every entry is one trigger with a list of cues (arc, icon, sound, message),
  each with its own switch and default; settings rows come from the data,
  grouped by family. Families: Upkeep, Proc, Window, Ready, Counter, Alert,
  and Feedback. An entry may use only a trigger whose family has a mechanism
  that works in combat on Forever. Only Upkeep icons are clickable.
- Boundaries: DBR = you, your group, your abilities; Dyre's Debuff Tracker =
  your effects on enemies; DSU = absorb shields; Dyre's Toolkit = engines;
  class Tools AddOns = class-only tools.
- The model guides new work and the proc move; existing code is not
  refactored to fit it. docs/CUE_MODEL.md maps every current feature to a
  family; keep that table current when a feature is added or moved.

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
  Powder 17020), Armor (Frost, Ice, Mage, Molten (TBC); recasts the last
  up, else Mage, Ice, Frost; author: "it should default to recasting
  whatever was up last"). Dampen or Amplify Magic (author, 1.3.0: "add to DBR, off by
  default"; left out in 1.2.0): one reminder, as MTF's, key `dampen` (the two
  cannot be on you together), every rank of both, `prefer` Dampen then
  Amplify, recasting the last one cast; on you only.
- Pet reminders (author, 1.5.0: "a 'no pet up' warning ... for warlocks
  and hunters"): Buffs.lua `pet` entries, `hunterPet` (Call Pet 883,
  `revive` Revive Pet 982) and `warlockPet` (Summon Imp 688, Voidwalker
  697, Succubus 712, Felhunter 691, Felguard 30146; `prefer` Imp first, so
  the last summoned is remembered in `db.last`). No aura and no slot: the
  icon's state driver `[mounted] hide; [nopet] show; [@pet,dead] show; hide`
  shows it, also in combat, with no reads (nothing secret). Out of combat
  the refresh hides it dead, on a taxi, without the spell, and for a
  Warlock after a Demonic Sacrifice (Burning Wish 18789, Fel Stamina 18790,
  Touch of Shadow 18791/35701, Fel Energy 18792; a secret read counts as
  sacrificed, no warning), and re-reads on `UNIT_PET`. Hunter click: macro
  `/use [@pet,dead] Revive Pet; Call Pet`, right-click Revive Pet; Warlock:
  the last demon (`SingleSpell`), its click set after combat. A dismissed
  Hunter pet looks like no pet: it shows (a reminder). No sound. The
  conditionals are C-side: confirm [nopet] and [@pet,dead] in client.
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
  Hunter (author, 1.1.0): Aspect (on by default; since 1.8.0 a problem
  indicator with a mode, see the aspect bar section): Hawk, Monkey, Viper,
  Wild, Beast, Cheetah, or Pack counts as up; a click recasts the last
  combat aspect cast (`db.last.aspect`), else Hawk, else Monkey. Cheetah and
  Pack (`forget`) are never remembered nor recast: they daze when you are
  hit. Casts are remembered by ID, else by name (a renumbered rank). Aspect
  clicks are macros "/use !Name" (author: "!" never toggles an aspect off;
  pinned SlashCommands.lua:377-387, /use hands the "!" name to
  CastSpellByName, as /cast does).
- Combat aspect (author, 1.1.0; folded into the Aspect reminder in 1.8.0,
  see the aspect bar section): the button `DyresBuffRemindersCombatAspect`
  is gone; the Aspect reminder shows in combat with Cheetah or Pack up. Its
  sound at combat start stays (Dyre's Sounds, its own switch, default
  "talent"). Invisible frames must not take clicks (one exception: the
  buff icons' Hidden look in combat, below; John, 2026-11-18).
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
  `ROLE_CHANGED_INFORM`, and roster changes in combat apply after it.
  A roster, role, or zone event (`GROUP_ROSTER_UPDATE`, `PLAYER_ROLES_ASSIGNED`,
  `ROLE_CHANGED_INFORM`, `PLAYER_ENTERING_WORLD`) is checked at once (0.2 s) and
  again 2 s later (`RECHECK_DELAY`; John, 2026-11-25, as Dyre's Toolkit's pet taunt
  fix: found in client there, the first check came before the group, role, or pet
  bar data was ready, and nothing fired again). One `C_Timer.After` with a token:
  a newer event makes the waiting check do nothing; in combat it does nothing.
  This covers the tank choice (Thorns, Righteous Fury) and the warnings (furyOff,
  DBR's own pet taunt copy); a group member's `UNIT_AURA` refreshes too, but no
  aura need change when a group forms. The
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
  Paladin: Righteous Fury (25780, self; `tankOnly`; author, 1.5.0, replacing
  1.2.0's talent rule: "the reminder should only come up if I'm a designated
  Tank in Group/Raid, or, if solo. We can remove the check for Improved
  Righteous Fury"): solo, or the group's designated tank (the Tank role via
  `UnitGroupRolesAssigned`, or a raid's main tank via
  `GetPartyAssignment("MAINTANK", "player")`, as the secure group headers
  read it; a secret or missing answer is not a tank), or the per-character
  "Always show Righteous Fury" (`db.alwaysShow`, off), re-checked on roles,
  roster, and `SPELLS_CHANGED`, out of combat. The talent scan (C_Traits)
  is gone. Warnings (Buffs.lua `DBR.WARNINGS`, author, 1.5.0: first amber
  icons, then "use the same mechanism (Message Box on-screen, like DCM) for
  the taunting-warnings ... instead of using icons"): in a group or raid
  where you are not the designated tank, `furyOff` (Righteous Fury on, and
  not "Always show") and `hunterPetTaunt` / `warlockPetTaunt` (Growl;
  Torment, Suffering, TBC's Anguish; with the Voidwalker or Felguard summon
  known; `GetPetActionInfo` over the pet bar, `PET_BAR_UPDATE`, `UNIT_PET`;
  a secret answer warns nothing). Each is a message, not an icon and no
  click: a toolkit widget (`warnings`, `db.warningPop`, "Warning messages:
  size") near the top center, a gold title over a line that fades (hold 4
  s, fade 1.5 s), as Dyre's Crit Mayhem's record pop (Records.lua; copied as
  a pattern, no dependency), no mouse, so no popup; plus one chat line.
  Shown when the condition becomes true or its text changes (checked with
  each out-of-combat refresh), again once at `PLAYER_REGEN_DISABLED` while
  still true, at most once per 30 s each, never while nothing changes. Each
  its own switch (`db.warnings`, `DBR_WARN_<KEY>`), on. `knownBy`: the
spells that make a warning apply. Ask the author before changing
  defaults.
- Pet Taunt and Dyre's Toolkit 2.9.0 (author, 2026-11-13: "Have DBR check
  to see if DT is installed, and if so, supress it's pet taunt warning and
  depend on DT's. If DT is not installed, keep it's copy for now."). The
  toolkit has DBR 1.5.0's warning (PetTaunt.lua) and claims the Owners kind
  `warn:petTaunt` (`DBR.PET_TAUNT_KIND`) as "DyresToolkit" at 50. From
  Toolkit 2.16.0 Dyre's Threat and Combat Tools has the warning and claims
  the kind as "DyresCombatTools" (its Tank.lua), so a fixed name let both
  warn (1.14.0 fix). `DBR.PetTauntOwner`: `toolkit.KindOwner(kind)` when it
  is a name other than DBR's folder; `DBR.ToolkitOwnsPetTaunt` is it being
  set, a feature test, not a version test. While true: no DBR pet taunt message,
  chat line, or unlocked sample (a Paladin's Righteous Fury warning stays
  DBR's), and `DBR_WARN_*PETTAUNT` is greyed (`AddModifyPredicate`, checked
  each time the page draws; its tooltip, a function, then adds "Greyed
  out: <title> gives this warning now.", the owner's TOC title, else its
  folder: `DBR.PetTauntOwnerTitle`).
  The message box (widget "warnings") hides, frame and all, so the toolkit's
  outline (its child) goes too, while DBR can give no warning: the reminders
  off, or every class warning switched off or given by another AddOn
  (`AnyWarningLive`; John, 2026-11-27, an empty "Warning messages" outline in
  layout mode beside DCT's: "I can't tell what the top warning messages are
  from"). Checked at each refresh (an owner change, a setting), on lock and
  unlock, and when a message fades; never hidden while a message shows. A
  hidden frame keeps its points, so its place stays. Unlocked, its sample is
  the first live warning's own message (`SampleText`: "Righteous Fury is on"
  for a Paladin; the pet taunt with the class's first taunt, Growl or
  Torment), not always the pet taunt (1.14.0 fix).
  Not `AddSettingsLink`: it opens a member AddOn's page, and the toolkit is
  not a member. Also with the toolkit's switch off: it keeps its claim (off
  means off). A toolkit before 2.9.0 (no `KindOwner`, or no claim) leaves
  DBR's copy on. The toolkit claims at its own login, which can come after
  DBR's, so `SetUpWarnings` listens with `OnOwnerChanged` and schedules a
  refresh (no polling). No toolkit at all: DBR is off anyway (it requires
  the toolkit). `/dbr debug` says `owner=<folder>` for a warning that yields (`owner=DBR`
  otherwise).
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
  icon), no mouse, shown by alpha only, so it
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
  answer counts as not). The Aspect reminder has its own red outline
  (1.8.0); the seal timer and ammo are unchanged.
- Missing buff (built 1.13.1; John, 2026-11-20, from a player: "so the glow
  shows instead of the red border for buffs missing"; Design A, "glow only for
  gone", then in client, "new effect looks good, ship it"): `db.missingStyle`,
  "glow" (default) or "border", a dropdown after "Visibility when not
  needed"; repaired on load; in the profile. Glow: every red border (buffs,
  pets, the Aspect reminder) shows the action bars' proc glow instead, and
  its red edge is clear (alpha 0). Running out stays yellow. The art is
  `ActionButtonSpellAlertTemplate`'s loop, atlas
  `UI-HUD-ActionBar-Proc-Loop-Flipbook`, a 6 by 5 flipbook of 30 frames in 1
  second (Blizzard_ActionBar Shared/ActionButtonSpellAlerts.xml, in the pinned
  Forever source and Era's; FlipBook setters in SimpleAnimFlipBook docs). Our
  own frame and FlipBook animation, not the template: its mixin stops the
  loop on hide and never starts it again (its OnShow is bound as a second
  OnHide), and our icons hide and show by drivers in combat. The glow is a
  child of the border frame, so every alpha set on the border (RedAtEnd,
  your own casts, the Aspect reminder) drives it; no scripts, no mouse. Under
  the slot (`Raise` below it) it is the icon's size, so the slot covers it
  while the buff is up; elsewhere 1.4 times, as on the action bars. Without
  the atlas (`C_Texture.GetAtlasInfo`), the red border. Its look was checked in
  client by John before 1.13.1.
- Boss encounters (built 1.13.2; found in client by John, 2026-11-20: "for
  every 'named mob' fight, the buffs became visible, like they were off, even
  though they were up every time", Dire Maul; "build it"): out of combat
  during an encounter, `GetAuraDataBySpellName` returned nothing (not a
  secret) for every buff on you, so they read as missing and were raised.
  While `DBR.AuraRestriction()` names one of Encounter, ChallengeMode, or
  PvPMatch (`C_RestrictedActions.IsAddOnRestrictionActive`, pinned
  RestrictedActionsConstantsDocumentation.lua), `RefreshReminders` changes
  nothing, as in combat: ours stays under the slot, armed, and a buff that
  really drops shows through. `ADDON_RESTRICTION_STATE_CHANGED` (registered
  only where `C_RestrictedActions` exists) reads again at its end. Map is not
  in the list: Deadmines has it and reads there worked (John's paste,
  `Map true`, Frost Armor found). `/dbr debug` prints every restriction type
  and `auraHidden`. Encounter as the restriction is inferred from John's
  pattern, not yet seen in a debug line.
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
  or, out of combat, the one read up on you (`db.last`). Unlocked icons cast nothing, so dragging is safe. An icon's
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
  Fortitude, and the like) were always shown. Since 2026-11-18 every buff
  shows only when needed by default (per-buff switch, below);
  `combatWindow = true` in Buffs.lua (only Battle Shout) now only marks the
  short buff with its own lead. A buff shown only when needed has its slot
  at "Visibility when not needed" out of combat and its icon hidden (0) or
  at that alpha while up outside its lead; in combat DBR's own timer
  (expiry from the last out-of-combat read, reset by your own cast,
  `duration` 120 without a read) opens it at the lead, by alpha; outside it,
  `db.faintPercent` / 100 (0, the default, to 80). Until 2026-11-17
  it was alpha 0 (author: "I can live with that", a click on the invisible
  icon cast it); 1.11.0 made it faint ("Yes, faint always"). Players asked
  for the old look ("Previous version had it perfect"), and John, 2026-11-18,
  waived the "never alpha 0 on a clickable secure button" rule for it:
  "waive it; default Hidden, apply to all". In combat AddOn code cannot Hide
  a secure button or turn its mouse off, so the hidden icon still takes
  clicks and casts the buff (accepted). A drop in
  combat shows at the window time (author: accepted for Battle Shout). The
  seal timer is its own design, unchanged.
- "Show only when needed", per buff (John, 2026-11-18: "A yes, per buff";
  replaces 1.11.0's one opt-in switch `db.onlyNeeded`, which is dropped):
  `db.needed[key]`, default `DBR.NeededDefault`: on for a short buff
  (`combatWindow`, Battle Shout), off for a long one. 1.12.0 had every buff
  on (John: "default all short and long term buffs to on"); John reversed
  it for long buffs on 2026-11-19 ("1a") after Arcane Intellect dropped in a
  fight and showed only after it: on, our icon sits faint or hidden under
  the slot, so a drop in combat cannot show (the probe below found no
  signal). A save without `db.neededLongOff` (1.12.0 and older, and their
  profiles) sets the long ones off once, then sets the flag. For every buff
  with an aura slot (`DBR.CanShowOnlyWhenNeeded`: not a pet, not the Aspect
  reminder), a checkbox (`DBR_NEEDED_<KEY>`) under its buff's switch. On
  (and locked), `Windowed(reminder)` is true, so it follows Battle Shout's
  window: the same drivers, `ScheduleWindow` (with the buff's duration, for
  the shared percent lead), `StartWindows`, `OwnCast`, `EndWindows`;
  nothing is duplicated. Off: always in full. "Visibility when not needed"
  (`DBR_FAINT`, a slider under Enable; `db.faintPercent`, 0 to 80 in 5s,
  default 0; John: "consistent alpha both in and out of combat"): while up
  outside its lead the icon and its slot are at that alpha, in and out of
  combat. Out of combat at 0 the icon has the combat-only driver (hidden,
  no clicks); above 0 the shown driver and that alpha. 80 at most (John:
  100 would be the switch off). It replaced 1.11.0's "Faint look in
  combat" (15 or 25). 1.11.0 saved 15 for everyone, so a save without
  `db.faintHidden` moves 15 to 0 once (25 stays), then sets it; profiles go
  through the same repair. A group
  member lacking it before the fight (`icon.othersNeed`) keeps it in full:
  DBR times only the watched unit; a group-version cast in combat fades it.
- "Show only in combat" (John, 2026-11-26: "an option to Battle Shout to only
  show in combat, just beneath the only when needed"): `db.combatOnly[key]`,
  default off, for a short buff only (`DBR.CanShowOnlyInCombat`:
  `combatWindow`, Battle Shout), a checkbox (`DBR_COMBATONLY_<KEY>`) under its
  buff's switch, right after "Show only when needed". On (and locked;
  `CombatOnly(reminder)`), out of combat nothing shows, missing or not: the
  icon gets the combat-only driver in every case, the slot alpha 0
  (`SlotAlpha`, also at `CreateSlot`), and `SetWarn` keeps the running-out
  border's wanted state (`reminders.warnOn`) but shows it only in combat.
  At combat's edges (`CombatOnlyEdge`, from `StartWindows` and `EndWindows`)
  the border and, for a buff not also shown only when needed, the slot follow.
  `reminders.combat` is set by PLAYER_REGEN_DISABLED, which comes before
  `InCombatLockdown()` is true. With "Show only when needed" also on, its
  window decides in combat, as before. Unlocked, every icon shows.
  The slot's out-of-combat alpha is set only on a change
  (`SetSlotAlpha`), so with the switch off nothing is touched; every icon
  faded in combat (`reminders.faded`) is set solid at combat's end, also
  after the setting changed in combat. PLAYER_REGEN_DISABLED is registered
  whenever there is an aura container. In the toolkit profile as every other
  key.
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
  combat, since a slot's IDs are fixed). That name test is English only
  (1.12.2, left as it is: no one prefix is known to fit every language,
  and some write no spaces); the seven listed seals work by ID everywhere.
  The last seal cast is remembered by name.
- Classic Era and Anniversary (author, 1.5.0: "paladin seals aren't showing
  up in era"; how seals work must not change): no engine, so AuraEngine.lua
  (copied from WTF with a provenance header, as DSU and MTF) gives the same
  container in plain Lua from `C_UnitAuras.GetAuraDataByIndex` on
  `UNIT_AURA`, also in combat (nothing is secret there); its bar and time
  redraw on a 0.1 s OnUpdate only while a timed seal shows. Forever keeps the
  engine (`DBR.CreateAuraContainer` picks). The buff widgets use it too
  (author: "battle shout reminder doesn't drop when bs is applied in combat
  in classic era"), so Era has Forever's layering: the slot, read in
  combat, covers the armed icon and goes when the buff does. The slot
  matches by spell ID (`includeSpellIDs`), so a rank missing from Buffs.lua
  (TBC's new ranks, on Anniversary) is not drawn: add those IDs with the
  Anniversary data.
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

### The aspect bar (built 1.8.0; John, 2026-11-13)

- John: "I'm about to level my hunter, so, can we add a Hunter aspect bar to
  DBR that one-click swaps aspects"; a player on the MTF forum asked first
  for DBR "as a stance bar for aspects". AspectBar.lua; data
  `DBR.ASPECT_BAR[class]` (Hunter only, as `DBR.CONSUMABLES`: data, not a
  gate), in order, combat aspects first: Hawk, Monkey, Viper (TBC 34074),
  Beast, Wild, then Cheetah, Pack. Every rank by ID (TBC's Hawk 27044 and
  Wild 27045 too); the click and the aura read by name.
- One secure button per data entry (`DyresBuffRemindersAspect_<key>`), in the
  widget `DyresBuffRemindersAspectBar` (key `aspectBar`, store
  `db.aspectBar`: `enabled`, default on (author decision, John,
  2026-11-13: "make it on by default for hunters", replacing the first
  build's default off; only a saved false turns it off, and other classes
  get no bar, sample, or settings rows); `orientation`, "vertical" or nil
  (horizontal, the default; 1.15.0, the toolkit's button bar key: DBR 1.8.0
  to 1.14.0's `vertical = true` moves to it once, in `SanitizeAspectBar`,
  and is dropped); place, scale,
  opacity; Size 50-200%). Only known aspects show, packed in order; a click is
  "/use !<Name>" (as the Aspect reminder: "!" never toggles it off). Made,
  placed, armed, shown, and hidden out of combat only: SPELLS_CHANGED (a new
  aspect or rank), lock, death (PLAYER_DEAD, ALIVE, UNGHOST), and taxi
  (PLAYER_CONTROL_LOST, GAINED); asked in combat, it waits for
  PLAYER_REGEN_ENABLED. After a reload in combat, it is made after combat.
  Hidden while dead or on a taxi (a secret answer counts as alive and not on
  a taxi); mounted: shown. Unlocked: shown, no clicks; with no aspect known,
  Hawk as a sample. Content size per shown button, 36 and 4 apart, from the
  LEFT edge (vertical: the TOP edge). With Toolkit 2.18.0's button bars
  (`BAR_LAYOUT_VERSION` 1, a feature test, `DBR.AspectBarUsesToolkitLayout`):
  `frame:LayoutButtons(shown, {size 36, gap 4, anchor "TOPLEFT"})` places them
  (TOPLEFT points) and sizes the bar; one anchor, because the toolkit keeps it
  when the settings page changes the layout, and the top-left corner keeps
  both the row's left edge and the column's top. Without it, DBR's own code
  as above (John, 2026-11-27: button bars horizontal or vertical are a
  Toolkit feature). In combat, every event but UNIT_AURA and the end of
  combat marks the bar dirty (1.15.0 fix: an aspect learned in combat waited
  for the next event). Default place CENTER (0, 72): under My
  buffs' row at 130, the toolkit's snap gap apart; vertical grows down from
  its top. A test checks it clears every other DBR widget of a Hunter.
- The border (a plain BackdropTemplate frame inside the button, shown by
  alpha, so it changes in combat): out of combat the aura by name
  (`GetAuraDataBySpellName`, on the player's UNIT_AURA, after combat, and at
  each refresh, only while the bar is on); a secret read is unknown and keeps
  the border. In combat the player's own UNIT_SPELLCAST_SUCCEEDED for an
  aspect name moves it; a secret spell ID changes nothing. A cancel in combat
  cannot be seen until combat ends.
- The Aspect reminder (John's final design, 2026-11-13; it replaces the
  "No aspect!" warning of a test build, which never shipped). John: "The
  'Aspect Reminder' widget does 2 main things: 1) gives a visual indicator in
  or out of combat if you have no aspect at all up - Red Outline. If I enter
  combat without an aspect up, or with Cheeta or Pack up, it should similarly
  show a visual indicator - Red Outline. If none of those things are true
  (combat appropriate aspect is up, in combat or out) no indicator should
  show. The widget should be resizable (scale from 50% - 200%, default 100%)
  and movable (obviously). The ability to click it and have the last combat
  aspect cast is now just nice to have; now that we have the aspect bar. I
  like it, would like to keep it, but it is somewhat redundant. Oh, sometimes
  hunters fight with Cheeta up in the open world to kill fast, there should
  be 3 settings for this: Normal (Remind me always), Speed-Running (only
  remind me if no aspect is up or if Pack is up), or Disabled (don't show at
  all). Default is normal."
- Built (Buffs.lua's `combatAspect`, `forget` Cheetah and Pack, `speedOk`
  Cheetah): one widget (`buff_aspect`), one secure icon with a red outline
  and the click's picture, no aura slot. A problem: no aspect up (in or out
  of combat); in combat, Pack (Normal, Speed-Running) or Cheetah (Normal).
  Cheetah or Pack out of combat is travel, no problem. Out of combat, from
  the aura read (`AspectNow`; a secret read keeps the last state): no aspect,
  "always"; a travel aspect that is a problem in combat, "combat"; else
  "never" (the attribute `dbr-show`), and the frame is shown or hidden
  then. It has NO visibility driver: the game's driver manager shows or
  hides a frame with one every 0.2 s, changed or not (pinned
  SecureStateDriver.lua:95-105, :119-129), so a secure Hide in combat held
  at most 0.2 s (found in client, John, 2026-11-14: after a click in combat
  it "faded, and then went away when combat ended"). Instead an attribute
  driver `state-dbrcombat` ("[combat] 1; 0"), set only on a change
  (:106-115), runs the icon's `_onstate-dbrcombat` (template
  SecureHandlerStateTemplate) at combat's edges: shown for "always", and for
  "combat" when combat starts; else hidden. The test mock re-applies
  visibility drivers on every `state.tick()`, as the client does. Dead or
  on a taxi: hidden. Unlocked:
  the sample, no click. The click, always (bar on or off): "/use !<last
  combat aspect>". It does the 1.1.0 combat aspect button's job, so that
  button is gone (red outline, not the pulsing gold border).
- In combat: its own click hides it (secure wrap, post-body `self:Hide()`,
  clicks on release); each aspect bar button is wrapped with the reminder as
  header and a frame ref (`SecureHandlerSetFrameRef`, pinned
  SecureHandlers.lua:702; `HANDLE:GetFrameRef`, RestrictedFrames.lua:205;
  `HANDLE:Show`/`Hide` on a protected frame, :394-408), and its post-body,
  only when `PlayerInCombat()` (RestrictedEnvironment.lua:200), hides the
  reminder (a combat aspect) or shows it (Pack; Cheetah in Normal), per the
  attribute `dbr-reminder` set out of combat. A cast from anywhere else
  (the player's own UNIT_SPELLCAST_SUCCEEDED): a combat aspect dims it to 0.4
  and sets the outline's alpha 0; a problem aspect sets both back to 1;
  never alpha 0 on the button (it still takes clicks); a secret spell ID
  changes nothing. A cancel in combat cannot be seen until combat ends.
- The mode (`db.aspectMode`: "normal", "speed", "off"; a dropdown,
  `DBR_ASPECT_MODE`, in place of the Aspect switch, under Reminders' Enable;
  without the dropdown API, a switch, on = Normal) keeps `db.spells.aspect`
  (= not "off"). Migration: a saved switch off, with no mode, is "off".
  "Disabled (don't show at all)" is read as the whole widget off. The sound
  (`db.combatAspect.soundOn`, `sound`; the button's `enabled` is dropped)
  sits under the mode and plays only when combat starts with a problem
  (speech "<travel aspect> is up" or "No aspect up").
- Size: its own `scale` (50-200%, default 100%), opacity, Reset size
  ("Aspect reminder: size", "opacity"); the reminder icons' sliders skip it.
  The same saved key as the shared size, so a size set there stays, with its
  place. Default place: My buffs' row beside the Pet icon, as before. A
  test build's `warnScale` place is converted once to the size now (its
  center stays) and dropped. `/dbr debug`: `debug aspectReminder mode=
  state= problem= driver= macro= sound=`.
- Settings: heading "Aspect bar" after the reminder sizes: "Enable"
  (`DBR_ASPECT_BAR`), then nested under it the toolkit's "Layout" row
  (`AddBarLayoutSetting`, Horizontal or Vertical; 1.15.0), or before Toolkit
  2.18.0 DBR's own "Vertical" (`DBR_ASPECT_BAR_VERTICAL`, the same
  `orientation`), then the toolkit's AddWidgetSettings
  ("Aspect bar: size", "Aspect bar: opacity", Reset size). Independent of the
  reminders' Enable (as the Consumables). Each button is wrapped for the
  Aspect reminder (above). `/dbr debug`: `debug aspectBar`.

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
- No ammo equipped, or a count of 0: missing (count 0, red, pulsing), with
  John's text (1.8.0): "You have ammunition in your inventory. Remember to
  equip your ammo." when a bag holds that kind (Classic projectile
  subclasses Arrow 2, Bullet 3; the generated docs list none), else "You do
  not have ammunition in your inventory. Remember to equip your ammo." Found
  in client: used-up arrows leave the ammo slot empty, and a new tier in the
  bags is not fired until it is equipped.
- Ctrl-drag while locked (toolkit free move): the Consumables bar and the
  seal timer are click-through while locked, so `DBR.AddCtrlMove` (Core.lua)
  has each take the mouse while Ctrl is held, out of combat
  (`MODIFIER_STATE_CHANGED`; off at `PLAYER_REGEN_DISABLED`; kept during a
  drag; player report, 1.4.1, WTF's fix). The seal button is also a drag
  handle. Buff icons are secure buttons that always take the mouse.
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
  1.5 s to 1 h), else the built-in one (Forever's), minus the lead (0-3 s in 0.5 s steps,
  default 0.5). 0.1 s after a cast DBR reads the real cooldown when readable
  (never secret, longer than the global cooldown), learns it, and
  reschedules; a newer cast replaces the schedule. `resets` cancels a group
  (Cold Snap the Frost spells, Preparation the Rogue's). A cast in combat is
  kept (`chimes.unread`) and read 0.1 s after PLAYER_REGEN_ENABLED
  (`ReadAfterCombat`; John, 2026-11-26, after players said Counterspell
  chimed 5-6 s early): a spell cast only in combat (Counterspell needs an
  enemy) never had an out-of-combat read and kept its built-in length. A
  cooldown that ended before combat did reads as none: nothing is learned.
  Counterspell's `cooldown` was 24 s, a data error (the Vanilla WoW Wiki
  says 24); it is 30 s in Classic and on Forever (both in-game tooltips,
  John, 2026-11-26). After it, every chime spell was checked against
  Wowhead's Forever database (https://www.wowhead.com/forever/spell=<ID>,
  John's source): ten lengths, Death Wish's ID (12328; 12292 is Sweeping
  Strikes there), and Lightning Mastery's name were fixed (CHANGELOG
  1.13.4).
- A chime spell you have not learned is listed with its row greyed, the
  label and the sound menu too (John, 2026-11-27, WTF's Chimes page: "listed
  and greyed, never hidden", as the procs). `DBR.ChimeKnown`: the entry's ID
  known, else a learned spellbook spell of its name (any rank; the spellbook
  may list only the highest), as a modify predicate the page checks as it
  draws, on DBR's page and on MTF's and WTF's. Saved values are untouched.
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
  English buff name, for docs and a fallback), spells (Classic IDs; author:
  start with Classic's; the first is the buff itself),
  on, sound. Warlock Nightfall (Shadow Trance 17941, off, sound impspell, as
  WTF); Mage Clearcasting 12536 (off: author, the game plays a sound for it);
  Druid Clearcasting 16870 (off, same reason) and Nature's Grace 16886 (on);
  Shaman Clearcasting 16246 (off); Warrior Flurry 12966-12970 (off).
  Reactive (author, 1.2.0): Warrior Overpower 7384 and Revenge 6572 (on),
  and (1.13.4; John, 2026-11-24: "Mongoose Bite is like Overpower/Revenge,
  it's only available after a dodge ... We should add that to DBR") Hunter
  Mongoose Bite 1495 (on, sound "talent"; not Counterattack, not asked for),
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
- Every language (author, 1.12.2, "Go for A"; a French player report: the
  chimes were silent): "the buff" is Procs.lua's `BuffName`, the client's own
  name for `spells[1]` (not secret, a string; French "Idées claires"), else
  the English `buff`. Both the ID check and the out-of-combat read use it. So
  the check guards the other listed IDs (a renumbered one is left out), not
  `spells[1]` itself.
- Saved in `db.procs` (enabled, spells, sounds, learned). Sounds must be
  aura sounds (files): menus use filter "aura"; a saved non-file key falls
  back to the default (`magical`, Nightfall's `impspell`). First run (no
  `db.procs`): on a Warlock, copy `WarlockToolsForeverDB.alerts.nightfall`
  and `.nightfallSound` (read only). WTF's Nightfall stands aside for DBR
  0.3.0+ from WTF 0.3.3-beta (`OTHER_PROCS`, `asideFrom` {0, 3, 3}); with an
  older WTF whose Nightfall is on while DBR's is on too, DBR warns once at
  login (naming only CurseForge to update) and keeps playing, as it treats
  older MTF and WTF chimes (author's rule, chosen for consistency).
- Settings: a "Procs" section (named "Proc Chimes" from 1.4 to 1.13; John, 2026-11-27: one name per section everywhere) (switch "Enable", `DBR_PROCS_ENABLED`) after the chimes, for a class with
  procs: Enable, then one row per proc (switch and sound, aura filter),
  with the same two-row fallback as the chimes.
- Steps aside for the toolkit's proc cues (1.12.0; John, 2026-11-18, one
  sound per proc): Dyre's Toolkit's proc engine (planned 2.11.0, its
  Procs.lua) lets an AddOn show a proc with arcs and a sound. Since John's
  2026-11-18 choice ("DSU is the right home for our 'spell activation
  overlays'"), that AddOn is Dyre's Shields Up (Nightfall, Decimation,
  Missile Barrage, Fingers of Frost); MTF and WTF register none. Its `RegisterProcs`
  claims the Owners kind `PROC_KIND_PREFIX .. key` ("proc:nightfall") at
  priority 10; the keys match `PROC_SOUNDS`. `DBR.ProcOwner(proc)` is that
  owner when it is not DBR: then `ApplyProcSounds` registers no aura sound
  for it, `Learn` skips it, its row (switch, or the switch-and-sound row)
  gets an `AddModifyPredicate` (greyed), and its tooltip (a function, read
  when it shows: Settings.InitTooltip calls one) adds "Greyed out: <title>
  plays this sound now." (`DBR.ProcOwnerTitle`: the title it joined the
  toolkit with, else its folder). Settings still save. A feature test, as
  the Pet Taunt yield: without `PROC_KIND_PREFIX` (no Procs.lua) or
  `KindOwner`, nothing changes. Reactive abilities (Overpower, Revenge) are
  no auras and never step aside. The class AddOn claims at its own
  PLAYER_LOGIN, maybe after DBR's: `OnOwnerChanged` per aura proc applies
  the sounds again, out of combat (in combat `procs.deferred`, applied at
  PLAYER_REGEN_ENABLED; an encounter waits as always). `/dbr debug` prints
  `owner=<addon>` (or `none`) per aura proc. Tests: tests/toolkit (CI) has
  no Procs.lua, so the fixture sets `PROC_KIND_PREFIX` itself there and loads
  ../DyresToolkit/Procs.lua when present; `toolkitBefore211` has neither;
  `procClaims` and `claimProc` claim as `RegisterProcs` does.

### Proc cues (built 1.13.0; John, 2026-11-20)

John: DBR is "a better fit for all buffs/procs (procs are really short-term
triggered buffs) chimes and visuals ... This lets DSU focus on managing just
absorption shield rendering", and "I do not want users to have to go to DBR
to change the chime sounds for Overpower and Revenge, when the visual arc
toggle lives in DSU". docs/CUE_MODEL.md: families Proc and Window.

- With Dyre's Toolkit's proc engine 2 (`PROC_ENGINE_VERSION >= 2`, Toolkit
  2.12.0; `DBR.ProcEngine`, a feature test), DBR passes ProcSpells.lua's
  `PROC_CUES` and `PROC_ART` to `RegisterProcs` at
  `PROC_OWNER_PRIORITY_HOME` (20; DSU 1.4 claims at 10, so the engine makes an
  older DSU step aside by itself) with `usableSounds = true`. The engine draws
  the arcs and plays the sounds only for the owner of "proc:<key>"; its
  settings rows (`AddProcSettings`, header "Procs") replace the Proc Chimes
  section. Decided once at login (`DBR.procEngine`); then the Proc Chimes
  code (above) registers nothing and its reactive check stays off.
- The catalog: DSU 1.4.1's eight (Missile Barrage, Fingers of Frost with
  `stacks = 2`, Nightfall, Decimation, the Druid and Shaman Clearcastings,
  Overpower and Revenge as usable procs), with their notes, plus Proc Chimes'
  Mage Clearcasting, Nature's Grace, and Flurry with `arcOn = false` (sound
  only by default, as before), and Mongoose Bite (1.13.4, usable 1495, arcs and
  sound; no talents, so the engine shows it once you know the spell). Same keys as Proc Chimes and DSU. Sound
  defaults are Proc Chimes' (Nightfall off; Overpower "talent", Revenge
  "magical"). A proc shows only with its talent known (the engine's rule;
  Proc Chimes had no talent check): the talent IDs are Classic ranks and
  TalentsForeverBook's, not confirmed in client (TESTING.md).
- Settings: `db.procCues` (the engine's arc, sound, sounds, position, scale;
  in the profile) and `db.procIDs` (buff IDs read in client; a profile
  character key). Without engine 2 both stay as saved, unrepaired, so a
  toolkit update finds them. `db.procs` (Proc Chimes) stays as it was.
- One-time import (`ImportProcCues`, flag `db.procCuesImported`), at the
  first login with engine 2: from `DyresShieldsUpDB` (DSU 1.4's `procs`,
  `procIDs`, `procsWithSAO`; read only, never written; DSU 1.5 keeps them for
  this) the arc and sound switches, sounds, the arcs' place and size, learned
  IDs, and `procsWithSAO`; then DBR's own Proc Chimes (switches, with its
  Enable off meaning every sound off; sounds; learned IDs) win where DBR had
  settings (lead: "An existing DBR setting wins"). One chat line when DSU
  gave something. A profile written at login or copied later marks it done
  (the profile wins). DSU's data is per character, so a character that never
  ran DSU gets the defaults.
- SpellActivationOverlay (from DSU 1.4; John: "We'll plan to coexist"):
  loaded at login and `db.procsWithSAO` off, DBR still registers (the sounds
  play, as Proc Chimes did beside it) but gives the engine a store whose arc
  switches read off and drop writes; the arc rows are greyed; one chat line.
  The row "Show proc arcs with SpellActivationOverlay" shows only with SAO
  loaded; a change applies after a /reload.
- The Missile Barrage tooltip's macro (from DSU 1.4.1) names Arcane Missiles
  (5143) in the client's language at login, English without a name.
- Tests: the proc cue tests need ../DyresToolkit with engine 2 (and its
  Units.lua and Auras.lua); with tests/toolkit (CI) they say "skipped" and
  pass. Every other test sees an engine before 2 (Proc Chimes).

### Combo point chimes (built 1.6.0; author: "mimic the Hear Kitty addon in DBR")

- Rogues and Druids (`DBR.COMBO_CLASSES`), a Druid only in Cat Form
  (`GetShapeshiftFormID` 1, Classic's `CAT_FORM`, or the active form being
  Cat Form by its spell's name; either is enough). Where the points are
  (author: "in classic (era) combo points are on the caster (Rogue, Druid
  Cat), in Forever, the points reside on the mob"): picked by what the
  client returns, never by version. The count is the higher of
  `UnitPower("player", Enum.PowerType.ComboPoints)` and
  `GetComboPoints("player", "target")`, a readable one over a secret one
  (player report: "Not working on the druid"). Read on the player's
  `UNIT_POWER_UPDATE` and `UNIT_POWER_FREQUENT` of any power, as Era's
  ComboFrame (which never checks the power type; a Druid's points may come
  with Energy); a repeat count changes nothing, and an event of another
  power is read only when the count is readable, so a secret count plays no
  note per Energy tick. `/dbr debug`'s `lastPowerEvent` names the last
  one. The most from `UnitPowerMax` (else
  `MAX_COMBO_POINTS`, else 5). With no count taken yet (just shifted, or
  the form read late) the count starts from none, so the first point plays.
  Hear Kitty was read, not copied.
- `/dbr debug` prints three `debug combo` lines: the reads, the settings
  (with whether the queue is playing and how many notes wait), and the
  last 8 actions (counts read with their event, baselines, notes queued
  and played, silent drops), for a player report such as "I only hear
  tone 5".
- Rising: one note per point gained, queued `COMBO_NOTE_GAP` (0.13 s) apart
  by `C_Timer` (no OnUpdate); a change queues all its notes before the
  first plays, and the next note's timer is set before each plays, so a
  failing Play loses no other note: the note set's notes upward for the
  points below the most, Full's sound at the most. Falling: Spend's sound;
  one point lost out of combat is decay,
  silent. A target switch is no spend (author: "on era, it's the worst of
  both worlds, the points are on you, and if you switch targets, you lose
  them and have to start over. In forever, switching targets maintains the
  points, because they live on the mob being targeted"):
  `PLAYER_TARGET_CHANGED` and Era's `COMBO_TARGET_CHANGED` (registered only
  when `C_EventUtils.IsEventValid` knows it) take the count silently (the
  new mob's on Forever, higher or lower; 0 on Era, so the next point plays
  the first note), and a drop within `COMBO_TARGET_WINDOW` (0.3 s) of one,
  before or after, is silent too. So a spend with no finisher seen waits
  that window. Your own finisher (`UNIT_SPELLCAST_SUCCEEDED`, by name, also
  readable counts) within the window makes the drop a spend after all: at
  once when the cast came first, on the cast when the drop came first.
  `UPDATE_SHAPESHIFT_FORM` and `PLAYER_ENTERING_WORLD` take the count
  silently. A gain is never held back, so one reported before its target
  event would play (not seen; Forever's count follows the target).
- A secret count (Forever: UnitPower is SecretWhenUnitPowerRestricted):
  one mid note (the set's third; Same as Full: Full's sound) per change,
  and Spend's sound from your own finisher
  (`UNIT_SPELLCAST_SUCCEEDED`, `COMBO_FINISHERS` by name: Eviscerate, Slice
  and Dice, Kidney Shot, Rupture, Expose Armor, TBC's Deadly Throw and
  Envenom; Ferocious Bite, Rip, TBC's Maim). To confirm on Forever.
- Note sets (`DBR.COMBO_SETS`; author, 1.7.0: "Try this as the primary
  theme for combo-point notes, move what we have to a second theme"):
  "Bassoon" (default; Dyre's Sounds 1.4.0, bassoon1 upward, Full bassoon8,
  the held F, Spend bassoon1), "Sax" (1.3.0, sax1 upward, Full sax8, Spend
  sax1), and "Same as Full" (each point plays Full's sound). Full and Spend
  follow a set with notes when they hold some set's default (the player
  chose nothing); a sound of the player's own stays, and "Same as Full"
  keeps both. (Chosen over showing the set's sound while not overridden, as
  DCM does: the saved sounds stay plain keys, as every other chime.) A
  bassoon key an older Dyre's Sounds lacks plays the sax note of the same
  number, then the chimes' default.
- Settings `db.combo` = {enabled, full, spend, onlyFull, noteSet,
  fullSound, spendSound}: a "Combo Point Chimes" section (Rogues and
  Druids): Enable, Full and Spend (switch and sound, the chimes' two-row
  fallback), "Only when full" (off), "Note set" (a dropdown; none without
  `Settings.CreateDropdown` and `CreateControlTextContainer`). 1.6.0's
  `scale`: off becomes "full"; on (the default) becomes Bassoon with its
  Full and Spend, unless Full or Spend was the player's own (not sax8,
  sax1), which keeps Sax and those sounds. DBR 1.7.0's release follows
  Dyre's Sounds 1.4.0.

### Winter's Chill stack chimes (removed 1.13.3; John, 2026-11-22: "Remove it now")

Built in 1.9.0 (Classic Era only, from the combat log). Winter's Chill is a
debuff on mobs, so it moves to Dyre's Debuff Tracker (DDT). Removed: the
data, the "Winter's Chill Chimes" section, the combat log code, and the
probe's target debuff part. `db.wintersChill` ({enabled, noteSet}) stays as
saved, not repaired, so DDT can import it: SanitizeDB leaves it alone, and it
is a profile characterKey, so a profile copy, import, or the Defaults never
remove it. Drop it after DDT imports it, in a later release. DBR registers
no `COMBAT_LOG_EVENT_UNFILTERED` at all now; every feature gates only on APIs.

### Cast chimes (built 1.4.0; author: "a sound when Travel Form, Pact of Cheeta and Sprint fire off")

- Data in ProcSpells.lua `CAST_SOUNDS`, per class: key, label, spells
  (Classic IDs, every rank by name), on, speech (else "Meep meep"), form.
  Druid forms (author: "Shifting INTO form only, not out"; all on): Travel
  783, Bear 5487 and Dire Bear 9634 ("Rawr"), Cat 768 ("Meow"), Aquatic 1066
  ("Splash"), Moonkin 24858 ("Hoot hoot"); Dash 1850/9821/9823 (off); Hunter Aspect of the Cheetah 5118
  ("Pact of Cheeta", author's name; on) and Aspect of the Pack 13159 (off);
  Rogue Sprint 2983/8696/11305 (on). Warrior (author, 1.5.0, from a look
  at Full Steel, read only): Charge, Intercept, Execute on; Whirlwind, Battle
  Shout, Demoralizing, Challenging, and Intimidating Shout, Taunt, Rend off;
  TBC's Intervene, Commanding Shout, and Victory Rush `whenKnown` (listed
  only when known at login). Each has its own default `sound` from Dyre's
  Sounds 1.2.0's "Dyre's Aggression" (an older Dyre's Sounds: the chimes'
  default plays; DBR's release follows Sounds 1.2.0), and speech its name.
  Druid (author: "druid has some warrior-like abilities/talents"): Feral
  Charge 16979 (talent, `whenKnown`, on, orccharge), Enrage 5229 (on,
  rageattack), Demoralizing Roar (off, orcangry), Challenging Roar (off,
  crowdcharge), Bash and Frenzied Regeneration (off, orcfury and
  raspyshout). Casts: each waits the same 0.2 s, undebounced. Travel Form and the aspects have no
  cooldown in Classic; Sprint and Dash are also cooldown chimes.
- A form chimes on `UPDATE_SHAPESHIFT_FORM` when the active form (the
  `GetShapeshiftFormInfo` entry that is active; its fourth value is the
  spell, as the pinned Blizzard_ActionBar/Shared/StanceBar.lua:70 reads it)
  changes to a new one, `CAST_CHIME_DELAY` (0.2 s, ProcSpells.lua; 0.75 s until
  John, 2026-11-17: "reduce the delay by about 75%") later
  and only if that form is still active then (author: "add a .75 second
  delay ... and debounce it (powershifting)"): every change, leaving too,
  bumps a token that cancels the pending chime, so Cat, caster, Cat chimes
  once and in-and-out none. Non-form cast chimes (Sprint, the aspects, the
  Warrior's) wait the same `CAST_CHIME_DELAY`, each cast its own timer, no
  debounce (author, 1.5.0: "the half-second delay on cast chimes means we do
  NOT have to disable the built-in sounds ... Make sure all cast chimes have
  the same delay"). Leaving a form (no form) and the same form again
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
- The buff drop probe (John, 2026-11-19: "do 3, build the probe"; removed
  the same day, "remove the probe code"): no signal tells AddOn code in
  combat which buff dropped. Found in client: `UNIT_AURA` "player" in combat
  gives `removedAuraInstanceIDs` and `isFullUpdate` as secret values, so the
  IDs read before combat cannot be matched; the engine's slot button takes
  no script: HookScript on it, and SetScript on a frame of our own inside
  it, both fail with "Cannot assign script handler for 'onshow' (blocked by
  secret aspects)" and taint DBR. Never put a script on or in a slot
  button. Only the bare fact that some aura was removed is left (not used:
  it cannot tell which).

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
- tests/run.lua loads the toolkit's real Core, Layout, Widgets, Settings,
  Owners, and Profiles from ../DyresToolkit when that folder is there, else
  from the copy in tests/toolkit (as in CI; refreshed from 2.10.2). The
  fixture claims `warn:petTaunt` as
  Toolkit 2.9.0's Tank.lua does at login; `toolkitBefore210` leaves out
  Profiles.lua; `toolkitBefore29` leaves out
  Owners.lua and the claim, `lateClaim` lets a test claim after login. No test compares the copy with the toolkit
  (author: "that's a stupid thing to test for a shared resource"); refresh
  the copy when CI needs a newer toolkit.

### Settings sections (built 1.14.0; John, 2026-11-26)

Every label and tooltip is for players (John, 2026-11-27, of another
AddOn's tooltip that "sounds like an instruction to an agent/dev", then
"every one of the tooltips seems to start with a good one sentence
description, but then has nonsensical follow-on text"): ONE plain sentence
that says what the setting does or what you see; a short second one only
when a player would otherwise be confused or lose something (Install Dyre's
Sounds; why a row is greyed, shown only while it is). No how-to tips, combat timing, defaults, versions,
owners, engines, or history (README has the details). A test checks every
tooltip on DBR's page for each class: at most two sentences, 160 letters.

John: class AddOns "should surface every setting in the wrapped addon's
settings, and just pass-through the setting to the wrapped addon"; the same
settings stay on DBR's own page. Dyre's Toolkit 2.17.0's settings sections
(../DyresToolkit AGENTS.md "Settings sections"); MTF and WTF are the hosts.

- At ADDON_LOADED, after `LoadDB`, `DBR.RegisterSettingsSections` registers
  three sections when `SETTINGS_SECTIONS_VERSION` is 1 or more and
  `RegisterSettingsSection` exists; otherwise nothing (hosts keep their
  link). The keys are the hosts' contract:
  - `reminders`: Enable, then the class's buffs with every row under each
    (group, lead, Show only when needed, Show only in combat, Always show,
    the Aspect mode and its combat sound), the seal timer, the warnings, then
    the shared lead (when a shown buff uses it), Visibility when not needed
    (when a shown buff can use it), and Missing buff. Filter: reminder keys,
    `seal`, warning keys.
  - `chimes`: Enable, Chime early, each spell with its sound. Filter: chime
    keys.
  - `procs`: Proc Chimes (Enable, each proc and its sound), or with proc
    engine 2 the toolkit's `AddProcSettings` rows and the SpellActivationOverlay
    switch. Filter: proc keys (`opts.keys` to the toolkit). On a host the
    toolkit's rows need `SETTINGS_SECTIONS_VERSION` 2 (`opts.variable`), else
    the section returns false and the host keeps its link.
  - A filter is nil (every row of the class), a list of keys, or one key.
    WTF passes none from 1.14.0 (all Warlock reminders, the pet and its taunt
    warning, every chime and proc; tested).
- One builder per section serves both pages (`BuildSection`): it swaps
  Options.lua's `category`, `layout`, and `page` (the context) while it
  builds, and puts them back (an error is raised again, not swallowed). Every
  setting variable goes through `Var` (`Register`, `NotifyUpdate`): on a host
  `DYRE_<HOST>__<name>`, on DBR's page unchanged. DBR's page builds its
  sections with `OwnSettingsContext` (or the same context by hand on an older
  toolkit) in the same order as before.
- A host section has no heading (the host names it); DBR's page keeps its
  headings. Every proc of the class is listed, on every page (John,
  2026-11-27: "I expect to see every setting available for warlocks, but
  only enabled if I have it. Not a generic banner"): Toolkit 2.17.0's
  `AddProcSettings` always shows its header, master, rows, and arc size rows,
  and greys a proc's rows while its talent is unknown (the size rows while
  none is). DBR hides nothing until a talent is known and adds no banner
  (an empty host page from hidden rows was the bug that led here). Reminders,
  chimes, and Proc Chimes rows never waited for a spell. A host section with nothing to show (another class, a filter
  that lists nothing of the class) adds no rows and returns false.
- Every row reads DBR state made at DBR's login (`ClassReminders`, the proc
  engine, Dyre's Sounds); the hosts list DBR in OptionalDeps, so DBR's login
  comes first. Before it (`started`), or for a context of another class, a
  build returns false. Get, set, and predicates read the live tables.
- Sizes, the aspect bar, consumables, cast chimes, and combo point chimes are
  DBR's page only (no section).
- Parts (Toolkit settings sections 3; John, 2026-11-27: "the top-level
  disable for each section should be on the top-level MTF panel"):
  `ctx.part` "all" (DBR's page), "master" (only the section's Enable:
  `DBR_ENABLED`, `DBR_CHIMES_ENABLED`, `DBR_PROCS_ENABLED` (Proc Chimes), or
  with proc engine 2 the toolkit's master (`AddProcMasterSetting`,
  `DYRE_DYRESBUFFREMINDERS_PROCS_ENABLED`, `procCues.enabled`; John,
  2026-11-27: "Add the Procs master switch"; feature-tested, else false);
  there they sit together, each named as its section, "Reminders",
  "Chimes", "Procs" (John, 2026-11-27: "let's use the same name consistently
  everywhere"; the registered titles, `SettingsSectionTitle`, and DBR's
  headings are the same words), with the same one-sentence
  tooltip as on DBR's page (no note: the host's sub-page sits right under
  it; John, 2026-11-27); "Enable" on DBR's page. With engine 2 and part "all",
  `AddProcSettings` draws the "Procs" heading (DBR's page only; `header =
  false` on a host), then the master (`opts.master = {label = "Enable"}`),
  then the rows; the toolkit greys its rows while the master is off and
  watches its variable), "rest" (all but the Enable; the rows that hang
  under it get its predicate as a modify predicate, as the parent is not on
  that page). Before 3, no part: "all".
- Greying (John, 2026-11-27: "when the top-level is off, the settings that
  are controlling a disabled feature should be disabled too"; "This one only
  disables some"): every row's predicate checks its whole chain (each switch
  above it and the section's Enable). Blizzard re-checks a row only when its
  direct parent's setting changes (Blizzard_SettingControls.lua,
  SettingsListElementMixin:Init and OnParentSettingValueChanged; the panel's
  RepairDisplay only adds and removes rows), so `Register` wraps each setter:
  after a change, `Cascade` calls `Settings.NotifyUpdate` for every row under
  it that has rows of its own, down the tree (`Nest` records the rows). The
  sizes take the predicate of their feature (`WidgetSettings`: the toolkit's
  `opts.modify`, ignored before 3; DBR's own icon size rows a modify
  predicate). A row with no parent row on its page (the sizes; on a host's
  "rest" page, each row under the section switch) also watches its switches
  (`Watch`, Toolkit's `WatchSettings`, Blizzard's AddEvaluateStateCVar on any
  setting variable; `opts.watch` on the toolkit's rows), so it greys live,
  not only on a redraw. A greyed button keeps its gold label on Forever
  (John, 2026-11-27: "the inconsistent label enable/disable"), so DBR's own
  button (the reminder icons' Reset size) goes through the toolkit's
  `GreyButtonLabel` (feature-tested); the toolkit's own buttons already do.

### Dyre's Toolkit profile (built 1.10.0; John, 2026-11-17)

John: "start working on the global "all Dyre addons settings" syncing with
DT's profile, so there is one place to go to persist your profile." The
design is the toolkit's (../DyresToolkit/docs/PROFILES.md; John,
2026-11-15): one profile per character, owned by the toolkit; DBR's live
settings stay in DyresBuffRemindersDB; no DBR Profile section, no
switching; no account table.

- Core.lua `JoinProfile`, at PLAYER_LOGIN after the saved settings load and
  before any widget: `RegisterProfilePart{addon, title, current =
  DyresBuffRemindersDB, sanitize = DBR.SanitizeProfile, characterKeys,
  refresh = DBR.ApplyProfile}`, only when the toolkit has
  `RegisterProfilePart` (2.10.0); with an older toolkit nothing changes,
  and the minimum stays 2.0.
- In the profile: every other key of DyresBuffRemindersDB, as SanitizeDB
  makes it: `enabled`, `spells`, `groups`, `leads`, `leadPercent`,
  `alwaysShow`, `warnings`, `aspectMode`, `combatAspect`, `buffs` and
  `warningPop` (places, sizes, opacity), `seal`, `consumables`,
  `aspectBar`, `chimes`, `procs`, `casts`, `combo`.
- characterKeys (never copied, exported, or imported): `locked` (the
  toolkit's account-wide lock, mirrored), `probe` (a debug switch), `last`
  (the spell each button casts, remembered from your casts, and class
  spells), `bars` (1.1.0's places, kept only until they seed the icons),
  `procIDs`, `wintersChill` (the removed chime's settings, kept for DDT).
- Read in client, nested, so not characterKeys (the engine skips top-level
  keys only): `chimes.learned` (cooldown lengths) and `procs.learned` (real
  buff IDs). `SanitizeProfile` puts this character's own back before
  `SanitizeDB`, also for the Defaults. They still travel in an export line,
  but an import never applies them.
- `SanitizeProfile` is SanitizeDB (every class's keys, so another class's
  part is fine), then drops top-level keys SanitizeDB does not make (a
  newer version's). It never errors. Run at registration, it means a part
  copied or imported while DBR was not loaded here: then the first run's
  imports (MTF, WTF, DCC) are skipped, so the profile wins.
- `ApplyProfile` (live, no reload): the lock again, `ReapplyWidgets` (place,
  size, opacity from the same store tables), `RefreshReminders`,
  `RefreshSeal`, `RefreshConsumables`, `RefreshAspectBar`, `ApplyProcSounds`
  (the aura sounds again). The chimes, cast chimes, and
  combo chimes read the settings when they play. The toolkit refuses a copy
  in combat and tells the settings pages to read their values again.
  Nothing needs a reload.

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
  group switch, its "Show only when needed" (`DBR_NEEDED_<KEY>`), and Battle Shout's "Show only in combat" (`DBR_COMBATONLY_<KEY>`) nested
  under it, Seal timer (Paladins), Remind before a buff runs out,
  Visibility when not needed (`DBR_FAINT`, a slider), then the sizes (author: "the size settings should be in
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

### Welcome switch (built 1.13.3; John, 2026-11-23: "toggle off our welcome messages unless there is an error/problem", then "A: one Toolkit switch")

- Dyre's Toolkit 2.14.0's "Welcome messages at login" (`DyresToolkitDB.welcome`,
  account-wide): when `DyresToolkit.ShowWelcome` is a function and gives false,
  Core skips the banner and the "Ready" line. Without the function (an older
  toolkit, or none), they print as before. No DBR switch; the minimum toolkit
  stays 2.0. Problems always print (missing toolkit, old contract, missing API,
  mixed install, slash conflict, missing sounds, no reminders for the class).
  When DBR cannot start, the banner prints too, so the problem line has the
  version.

## Project structure

- Runtime files: DyresBuffReminders.toc, Commands.lua, Core.lua,
  Buffs.lua, Reminders.lua, AuraEngine.lua, Seals.lua, Consumables.lua, AspectBar.lua, ChimeSpells.lua,
  Chimes.lua,
  ProcSpells.lua, Procs.lua, Probe.lua, Options.lua, loaded in that order. Commands
  parses `/dbr`; Core owns saved
  settings and their repair, the login banner, install and API checks, slash
  conflict reporting, joining Dyre's Toolkit and its profile, the lock, and startup;
  Buffs holds the buff lists; Reminders the bars and icons; Seals the Paladin seal
  timer; Consumables the Consumables bar (ammo); AspectBar the Hunter aspect bar; ChimeSpells the chime lists; Chimes the chimes and Dyre's Sounds;
  ProcSpells the proc lists; Procs the proc sounds and the proc cues; Probe the debug-only
  reactive-ability probe; Options the settings page.
- artwork/ holds the logo (SVG source, 1024 and 512 PNG renders) and
  screenshots/ for listings; it is never packaged.
- tests/run.lua holds the Lua 5.1 mock suite. tests/test_*.py cover the
  release helpers in scripts/; tests/toolkit holds the toolkit copy the
  suite loads without ../DyresToolkit. .github/workflows/
  holds CI, opt-in publishing, and the approval gate check.
- README.md is the user-facing overview, TESTING.md the verification method,
  source evidence, unverified IDs, and in-client checklist,
  docs/RELEASE_PLAN.md the release process, docs/CURSEFORGE_LISTING.md the
  CurseForge form text, docs/CLASS_COVERAGE.md the per-class coverage plan,
  docs/CUE_MODEL.md the cue model (families, triggers, cues), and CHANGELOG.md the per-release change list.
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
- Runtime assets: only the proc arcs, Textures/ArcaneArc.tga and
  ArcaneArcLeft.tga (1.13.0, moved from Dyre's Shields Up with the procs; John,
  2026-11-20; John's own art, made by scripts/make_arcane_arcs.py). The
  builder checks them as 32-bit square TGAs (MEDIA_FILES). Add no other
  without agreement.
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
  Buffs.lua, Reminders.lua, AuraEngine.lua, Seals.lua, Consumables.lua, AspectBar.lua, ChimeSpells.lua,
  Chimes.lua,
  ProcSpells.lua, Procs.lua, Probe.lua, Options.lua, Textures/ArcaneArc.tga,
  Textures/ArcaneArcLeft.tga, and LICENSE under the top-level
  `DyresBuffReminders/` folder, named `DyresBuffReminders-<version>-forever.zip`,
  with the builder's BigWigs-format `release.json` (flavors `forever` and `classic`; the TOC lists Interface `16001, 11509`, and each CurseForge upload names Forever 1.60.1 and Classic Era 1.15.9, `CURSEFORGE_CLASSIC_GAME_VERSION_ID`) attached
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
