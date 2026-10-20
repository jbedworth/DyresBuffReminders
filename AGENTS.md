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
- Layout.lua (magnetic frames) stays copied, not a library: the same file as
  MTF's and WTF's but for the namespace (`DBR`). tests/test_layout_copy.py
  compares the copies, namespace names normalized, when sibling checkouts
  exist. A behavior change goes into all three copies together.

### The reminders (built)

- Buffs.lua holds the lists, by class (author-approved for v1: Mage, Warlock,
  Druid, Priest, and Paladin self buffs only, plus the seal timer). Classic spell IDs, matched by name, so every rank counts;
  only buffs you know show. Keys are saved per character and unique across
  classes. The class picks the list (data, not a gate); a class without one
  says so once at login and shows nothing. Paladin: Righteous Fury only
  (author: self buffs; blessings are per member and situational, and
  PallyPower exists).
- Mage: Arcane Intellect (group, mana users; Arcane Brilliance 23028, Arcane
  Powder 17020), Armor (Frost, Ice, Mage; recasts the last used, else Mage,
  Ice, Frost), Dampen or Amplify Magic (off by default). Warlock: Demon Armor
  (Demon Skin counts; recasts the last used, else Demon Armor, Demon Skin).
  Druid: Mark of the Wild (group, everyone; Gift of the Wild ranks with Wild
  Berries or Wild Thornroot), Thorns (self only, author). Priest: Power Word: Fortitude
  (group, everyone; Prayer of Fortitude ranks with Holy or Sacred Candles),
  Inner Fire (self), Divine Spirit (off; group, mana users; Prayer of Spirit),
  Shadow Protection (off; group, everyone; Prayer of Shadow Protection).
  Paladin: Righteous Fury (25780, self). Ask the author before changing
  defaults.
- Running out (author-approved, for every buff, also group members'): the
  icon also shows while a buff has at most `db.lead` seconds left (default
  5, 0-30, a slider; 0 shows it only once gone), from the aura's
  `expirationTime` read out of combat. One `C_Timer.After` timer, tokened so
  a newer refresh makes older ones do nothing, refreshes when the earliest
  buff reaches the lead time; no polling. A secret or missing end time
  counts as on. In combat nothing changes; a buff that ran out shows after.
  The tooltip splits "Missing" from "Running out".
- Druid forms (author-approved): buffs with `cancelForm` (Mark of the Wild,
  Thorns) click as a `macrotext` "/cancelform" then "/use [@unit] Name"
  while any form is active (`GetShapeshiftFormInfo`, refreshed on
  `UPDATE_SHAPESHIFT_FORM`); a group version is cast as `Name(Rank N)`
  (`C_Spell.GetSpellSubtext`) for its reagent. Going back into the form
  cannot be automatic: casts need a hardware press and the form waits for
  the global cooldown.
- One icon per buff, shown only while the buff is missing, with a solid gold
  border that pulses (an Alpha animation, BOUNCE). Group buffs (a switch each,
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
  (`db.last`). Unlocked icons cast nothing, so dragging is safe.
- Aura APIs refuse AddOn code in combat, so DBR reads auras only out of
  combat. Secure icons change only out of combat, so they sit in a holder
  (`DyresBuffRemindersHolder`) hidden for combat by
  `RegisterStateDriver(holder, "visibility", "[combat] hide; show")`; changes
  asked for in combat wait for `PLAYER_REGEN_ENABLED`. After a reload in
  combat, the holder and icons are created only when combat ends.
- Events in bursts (`UNIT_AURA` from a group buff) refresh once, 0.2 s after
  the first; only the player's, party, and raid units' auras count.
- Each icon has its own position and size (50-200%, mouse wheel while
  unlocked, 10% steps), saved per character; `/dbr reset` restores a row, 20
  apart. Unlocking shows every switched-on icon and the alignment grid (faint
  lines every 32, red center lines; a setting).

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
  attributes change only out of combat. Unlocked, the button is hidden
  (`hide`) so the plain display frame takes the drag; it snaps with the
  reminder icons and resizes the same way. After a reload in combat, it is
  set up when combat ends. Without the aura container, it stays off with one
  message.

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
  Shaman Clearcasting 16246 (off); Warrior Flurry 12966-12970 (off). No source
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
- Settings: a "Proc Sounds" section after the chimes, for a class with
  procs: Proc sounds, then one row per proc (switch and sound, aura filter),
  with the same two-row fallback as the chimes.

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
  edit it here; ask the coordinator). TOC `## OptionalDeps: DyresSounds,
  DyresToolkit`; CurseForge `requiredDependency` on `dyres-toolkit`
  (`RELATIONS`, tested).
- With `DyresToolkit.RequireContract(1)` and the functions DBR uses
  (`DBR.Toolkit`, checked at login before any frame exists): DBR's
  `RegisterMovable`, `BeginDrag`, `EndDrag`, and `ScaleKeepingCenter` are the
  toolkit's (frames snap across AddOns and to its grid; DBR saves its own
  positions through `save`); DBR draws no grid and has no grid setting; its
  lock state is the toolkit's (`IsLocked` at login; frames start locked).
  `/dbr unlock`, `/dbr lock`, and the settings switch call
  `toolkit.SetLocked`, which calls back `DBR.ApplyLocked` (quietly; the
  toolkit says one line). At the end of login DBR registers with
  `RegisterAddOn({addon, title, setLocked = DBR.ApplyLocked, openSettings =
  DBR.OpenSettings})`. Its settings page is
  `RegisterSettingsCategory("Dyre's Buff Reminders")` under "Dyre's AddOns";
  when that returns nil, DBR's own top-level page.
- Without the toolkit (or with a newer contract only): DBR behaves as
  before (Layout.lua, its own grid and page) and says once at login: "Install
  Dyre's Toolkit from CurseForge for one layout mode and settings home for all
  Dyre's AddOns." Layout.lua and its copy test stay for this.

### Commands and settings

- `/dbr` and `/dbr options` (not in combat), `unlock`, `lock`, `reset`,
  `debug` (runs even when DBR is unavailable; lists spell IDs the client does
  not know, the seal timer, and the chimes: Dyre's Sounds, other AddOns'
  chimes, each class spell, the last cast, and the latest 12 events). There
  is no `/dcc`. Backup slash `/buffreminders`; a clash on `/dbr` is reported once
  at login.
- One settings page (vertical layout, proxy settings on
  `DyresBuffRemindersDB`): Buff reminders, one switch per class buff with its
  group switch nested under it, Seal timer (Paladins), Remind before a buff
  runs out (seconds), and only without the toolkit Unlock to move them and
  Show a grid while unlocked (author: with the toolkit, its "Dyre's AddOns"
  page has the one unlock switch and grid); then a
  "Cooldown Chimes" section: Cooldown chimes, Chime early (seconds), and one
  row per class spell (author-approved): its switch and Sound dropdown on
  the same row, Blizzard's `CreateSettingsCheckboxDropdownInitializer`
  (pinned Blizzard_SettingControls.lua:1670) added through the layout, with
  Dyre's Sounds' `SetupCheckboxMenu` for the nested menu (Dyre's Sounds
  0.1.2-beta; Blizzard's control greys the sound while the switch is off).
  With an older Dyre's Sounds (no `SetupCheckboxMenu`) or a client without
  that initializer, the switch, then its dropdown on its own row nested under
  it (`SetupMenu`). The settings and saved keys are the same either way. Then
  the "Proc Sounds" section (see above). Section headings appear where the
  client has
  `CreateSettingsListSectionHeaderInitializer`.

## Project structure

- Runtime files: DyresBuffReminders.toc, Commands.lua, Core.lua, Layout.lua,
  Buffs.lua, Reminders.lua, Seals.lua, ChimeSpells.lua, Chimes.lua,
  ProcSpells.lua, Procs.lua, Probe.lua, Options.lua, loaded in that order. Commands
  parses `/dbr`; Core owns saved
  settings and their repair, the login banner, install and API checks, slash
  conflict reporting, the lock and grid, and startup; Layout snaps frames;
  Buffs holds the buff lists; Reminders the icons; Seals the Paladin seal
  timer; ChimeSpells the chime lists; Chimes the chimes and Dyre's Sounds;
  ProcSpells the proc lists; Procs the proc sounds; Probe the debug-only
  reactive-ability probe; Options the settings page.
- artwork/ holds the logo (SVG source, 1024 and 512 PNG renders) and
  screenshots/ for listings; it is never packaged.
- tests/run.lua holds the Lua 5.1 mock suite. tests/test_*.py cover the
  release helpers in scripts/ and the Layout.lua copy. .github/workflows/
  holds CI, opt-in publishing, and the approval gate check.
- README.md is the user-facing overview, TESTING.md the verification method,
  source evidence, unverified IDs, and in-client checklist,
  docs/RELEASE_PLAN.md the release process, docs/CURSEFORGE_LISTING.md the
  CurseForge form text, and CHANGELOG.md the per-release change list.
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
- Package only DyresBuffReminders.toc, Commands.lua, Core.lua, Layout.lua,
  Buffs.lua, Reminders.lua, Seals.lua, ChimeSpells.lua, Chimes.lua,
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
