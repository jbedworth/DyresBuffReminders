# Testing

## Method

1. **Pinned source review.** Client behavior is read from Blizzard's FrameXML
   and generated API documentation at Gethe/wow-ui-source commit
   `943764493e6b16d63ded3ab304150d1f05e58b57` (`1.60.1.70338`, the source; the client was tested on
   build 70450, still Interface 16001). Source
   establishes declared APIs, templates, and code paths, not operational behavior.
2. **Automated mock tests.** `tests/run.lua` exercises commands, saved
   settings, each class's reminders, group counts and click targets, combat
   handling, the buff widgets (one Dyre's Toolkit widget per buff: places, sizes,
   opacity, the mouse, combat waits, settings rows), the seal timer, the cooldown chimes (timing,
   ranks, resets, sounds through a stand-in Dyre's Sounds and, when a sibling
   checkout exists, the real one), and the settings page against a minimal mock
   of the client. Mocks model secret values as values that raise errors on
   comparison, concatenation, indexing, or printing.
   The suite loads Dyre's Toolkit's real Core, Layout, Widgets, and Settings
   from tests/toolkit; a test fails when that copy differs from
   ../DyresToolkit (skipped where there is no sibling checkout, as in CI).
3. **In-client checks.** The checklist below covers everything mocks cannot.

```sh
.tools/luarocks-3.13.0-win32/win32/lua5.1/bin/lua5.1.exe tests/run.lua
.tools/luarocks-3.13.0-win32/win32/lua5.1/bin/luac5.1.exe -p Commands.lua Core.lua Buffs.lua Reminders.lua Seals.lua Consumables.lua ChimeSpells.lua Chimes.lua ProcSpells.lua Procs.lua Probe.lua Options.lua tests/run.lua
.tools/python-3.13.7/python.exe -m unittest discover -s tests -p 'test_*.py'
.tools/actionlint-1.7.12/actionlint.exe .github/workflows/*.yml
```

Tooling: portable Lua 5.1 (LuaRocks 3.13.0 Windows bundle), the official
python.org 3.13.7 embeddable archive, and actionlint 1.7.12 under the ignored
`.tools/` folder (copied from Dyre's Shields Up); CI uses ubuntu-24.04's
`lua5.1` package and native `python3`.

## Source findings

- `SECURE_ACTIONS.spell` (Blizzard_FrameXML/SecureTemplates.lua) calls
  `CastSpellByID(spellID, unit)` when the `spell` attribute is a number, else
  `CastSpellByName(spell, unit)`. Single buffs are cast by name (the client
  picks your highest rank); group versions by ID, because each rank has its
  own reagent.
- `C_SpellBook.IsSpellKnown(spellID)` returns a bool (`AllowedWhenUntainted`
  arguments). `C_Spell.GetSpellName` and `GetSpellTexture` may return nothing
  for an unknown ID. `C_Spell.IsSpellInRange(spell, unit)` returns true, false,
  or nil when the check is invalid; DBR treats only false as out of range.
- `C_UnitAuras.GetAuraDataBySpellName` is `SecretWhenUnitAuraRestricted` and
  `RequiresNonSecretAura`. A secret answer counts as buffed.

## Found in client

- Forever has a seal Classic lacks, Seal of Fury; with only Classic seal IDs,
  the seal timer showed no timer for it and the "no seal" picture stayed up
  in combat. With its IDs added (0.1.2-beta), the timer works (confirmed on
  a Paladin).

- Proc sounds and the Nightfall hand-over: the author's Warlock tests passed
  (0.3.0-beta with Warlock Tools Forever 0.3.3-beta).
- Righteous Fury on a Protection Paladin with Improved Righteous Fury: the
  reminder shows (1.2.0, which also reads the talent tree). A respec that
  drops the talent hides it, as designed.
- Reactive-ability probe on a Protection Warrior: `C_Spell.IsSpellUsable` for
  Revenge was readable in combat (`secret=no`), changing on
  `SPELL_UPDATE_USABLE`; no `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`/`_HIDE`
  came. Overpower is assumed the same, not yet seen. Flurry could not be
  tested on that Warrior (it stays off by default).
- Buffs in combat (aura probe, Druid, three pulls): out of combat
  `C_UnitAuras.GetPlayerAuraBySpellID` found Mark of the Wild and Thorns and
  `C_Secrets.ShouldSpellAuraBeSecret` said false. On the first in-combat
  UNIT_AURA both read `present=no secret=true` while both were still up: in
  combat these auras are secret and the API returns nothing, so DBR cannot
  read a buff's presence in combat by spell ID. Blizzard's AuraContainer
  slots still draw them in combat (the comment in
  Blizzard_CustomAuraContainer.lua:78-85 about "never-secret spells" does not
  hold for AddOn queries, or the container is exempt). The engine's slot
  frames are forbidden to AddOn code in combat (`IsShown` errors on them).

### Carried over from MTF and WTF

- Aura APIs error in combat for AddOn code; own cast events stay readable.
- Forever uses Classic spell IDs for the spells checked so far (Mana Shield,
  Fire Ward, Power Word: Shield, Paladin bubbles; see Dyre's Shields Up).

## Unverified spell IDs and reagents

Classic IDs from Classic data, not in the pinned source. `/dbr debug` lists
any ID the client does not know (`unknownIDs=`), so each class's line should
say `unknownIDs=none`.

| Buff | Rank IDs | Group version (reagent) |
|---|---|---|
| Arcane Intellect | 1459, 1460, 1461, 10156, 10157 | Arcane Brilliance 23028 (Arcane Powder 17020) |
| Frost / Ice / Mage Armor | 168, 7300, 7301 / 7302, 7320, 10219, 10220 / 6117, 22782, 22783 | |
| Demon Skin / Demon Armor | 687, 696 / 706, 1086, 11733, 11734, 11735 | |
| Aspect of the Hawk / Monkey / Wild / Beast / Cheetah / Pack | 13165, 14318, 14319, 14320, 14321, 14322, 25296 / 13163 / 20043, 20190 / 13161 / 5118 / 13159 | |
| Mark of the Wild | 1126, 5232, 6756, 5234, 8907, 9884, 9885 | Gift of the Wild 21849 (Wild Berries 17021), 21850 (Wild Thornroot 17026) |
| Thorns | 467, 782, 1075, 8914, 9756, 9910 | |
| Power Word: Fortitude | 1243, 1244, 1245, 2791, 10937, 10938 | Prayer of Fortitude 21562 (Holy Candle 17028), 21564 (Sacred Candle 17029) |
| Inner Fire | 588, 7128, 602, 1006, 10951, 10952 | |
| Divine Spirit | 14752, 14818, 14819, 27841 | Prayer of Spirit 27681 (Sacred Candle 17029) |
| Shadow Protection | 976, 10957, 10958 | Prayer of Shadow Protection 27683 (Sacred Candle 17029) |
| Righteous Fury | 25780 | |
| Seal of Righteousness | 21084, 20154, 20287, 20288, 20289, 20290, 20291, 20292, 20293 | |
| Seal of Command | 20375, 20915, 20918, 20919, 20920 | |
| Seal of the Crusader | 21082, 20162, 20305, 20306, 20307, 20308 | |
| Seal of Justice / Light / Wisdom | 20164 / 20165, 20347, 20348, 20349 / 20166, 20356, 20357 | |
| Seal of Fury (Forever) | 20163, 20419, 20421, 20422, 20423, 1311649, 1311656 | |

The seal timer assumes each seal's buff has its spell's ID; the aura
container matches by ID.

Prayer of Spirit and Prayer of Shadow Protection came late in Classic (books);
they may be missing on Forever.

ForeverAuras (installed by the author) keeps a table of Forever's spell names
and IDs in its saved variables. It lists every ID above under its name, but
not Seal of Righteousness 21084, and it gave Seal of Fury's IDs. Its table is
evidence from another AddOn, not the client's own answer: `/dbr debug` stays
the check.

### Open client questions

1. Whether a group version cast by ID (`CastSpellByID`) casts that rank, with
   its own reagent, from a secure button.
2. Whether a single buff cast by name on a low-level group member is refused
   (Classic has no automatic lower rank for buffs).
3. Whether a group version reaches only the target's party in a raid, as in
   Classic.
4. Whether `expirationTime` is readable (not secret, not 0) out of combat for
   your own buffs and for buffs on group members; where it is not, the icon
   shows only once the buff is gone.
5. Whether `/cancelform` then `/use` in one secure macro click casts the buff
   in Bear or Cat Form, and whether `Gift of the Wild(Rank 1)` casts that rank.
6. Seal timer: whether the aura container's slot (seal icon, sweep, bar)
   fully covers the secure button's "missing" picture while a seal is up, in
   combat; whether the sweep shows numbers (they may follow the game's own
   cooldown-numbers option); and whether the button, anchored inside a plain
   movable frame, clicks in combat.

### Cooldown chimes (carried over from Dyre's Cooldown Chimes)

- The chime spell IDs are Classic's. Mage's and Warlock's lists are MTF's and
  WTF's; the other classes' are new and unchecked: `/dbr debug` should show
  `name=` for every chime spell, never `nil`.
- Open: whether `C_Spell.GetSpellCooldown` stays readable right after an
  out-of-combat cast for every class's spells.

### Proc sounds: Classic IDs to confirm in client

Started from Classic's buff IDs (author). None is confirmed on Forever: no
source names the proc buffs' IDs (ForeverAuras lists only spells the author
has had; TalentsForeverBook says Forever changed Nightfall, Nature's Grace,
and Flurry). DBR confirms an ID in client the first time the buff is on you
out of combat; `/dbr debug` then shows `status=confirmed` and `learned=`.

| Proc | Buff | Classic IDs |
|---|---|---|
| Warlock Nightfall | Shadow Trance | 17941 |
| Mage Arcane Concentration | Clearcasting | 12536 |
| Druid Omen of Clarity | Clearcasting | 16870 |
| Druid Nature's Grace | Nature's Grace | 16886 |
| Shaman Elemental Focus | Clearcasting | 16246 |
| Warrior Flurry | Flurry | 12966, 12967, 12968, 12969, 12970 |

## In-client checklist

- [ ] With Dyre's Toolkit 2.0 installed: the AddOn list shows DBR under
      "Dyre's AddOns"; Options > AddOns > Dyre's AddOns > Buff Reminders is
      DBR's page (no grid row, no unlock switch: the toolkit's "Unlock
      frames" is the one); each size sits at the end of its section. `/dbr unlock`
      (or `/dyre unlock`) unlocks DBR's bars and the seal timer together with
      the other AddOns' frames, with one chat line from the toolkit; they
      snap to another AddOn's frames and, with "Snap to the grid", to the
      toolkit's grid; `/dbr lock` locks them all.
- [ ] Without Dyre's Toolkit, or with one older than 2.0: one login line
      naming CurseForge, and no DBR frames.

One class at a time. Reload after each copy (`/reload` loads new files).

- [ ] Any class: the login banner shows the version and Dyre; `/dbr` opens
      Options > AddOns > Dyre's Buff Reminders; `/dbr debug` runs. A
      Rogue or Shaman gets one line saying there are no
      reminders for the class, and no icons.
- [ ] Mage: Arcane Intellect and armor icons show a red border while missing
      and are covered by the game's icon when cast; Arcane Brilliance counts. A click casts Arcane Intellect on
      you, then on a party member; with Arcane Powder and two missing,
      Arcane Brilliance. Armor recasts the one you used last.
- [ ] Warlock: Demon Armor shows red while neither armor is on; a click casts
      Demon Armor (Demon Skin before you learn it).
- [ ] Hunter: with no aspect up, the Aspect icon shows red; any
      aspect (Cheetah and Pack too) hides it. Cast Monkey, then remove it:
      a click casts Monkey. Cast Cheetah, then remove it: a click still casts
      Monkey. `/dbr debug` shows `debug aspect ... unknownIDs=none
      last=Aspect of the Monkey`.
- [ ] Hunter, combat aspect: with Aspect of the Cheetah up, out of combat,
      nothing shows; pull a mob: the combat aspect icon shows at once (your
      last combat aspect, else Hawk), with the sound if on. Click it: the
      aspect goes up and the icon goes away. Again with Cheetah, but cast
      Hawk from your own bar: the icon dims to about 40% and stays where it
      was. Click the dimmed icon with Hawk up: Hawk stays up ("!"). Pack
      works the same. It shows on the Aspect icon; `/dbr unlock` shows
      one outline (Aspect), and after dragging that icon the combat icon
      appears at its new place. After combat, `/dbr debug` shows
      `debug combatAspect`.
- [ ] Warrior: Battle Shout shows while it is off, and a click
      casts it (with rage). Out of combat it shows from 60 seconds left; its own
      "Remind before it runs out" changes that. While up with more than 60 s
      left it does not show, in or out of combat; in combat it appears at
      60 s left (timed by DBR) and a recast hides it again. A drop in combat
      shows only at the 60 s mark (accepted).
      In combat, a dodge brings the Overpower sound and
      a block, dodge, or parry the Revenge sound, once per window; switching
      each off under Proc Chimes silences it. `/dbr probe off` if the probe is on.
- [ ] Druid, Rebirth reagent: `/dbr debug` prints a `debug reagent rebirth
      rN` line per rank; each shows spellName=Rebirth and the seed's name
      (Maple, Stranglethorn, Ashwood, Hornbeam, Ironwood Seed), and
      known=true for the ranks you have. A seed you have never seen reads
      "(not cached, loading)", then a line "debug reagent item=<id>
      itemName=<name> (loaded)" follows; "not found" means a wrong ID. The Consumables bar shows the seed
      of your highest rank with its count; at 2 or fewer it turns red and
      pulses, at 0 it greys. "Rebirth reagent" and its Warn at (0-10, 2,
      gold mark) are under Consumables. No ammo icon, sample, or Ammo rows.
- [ ] A Mage, Priest, or other class with no consumables: no Consumables
      section or size rows, and nothing shows when unlocked.
- [ ] Ammo, on a Hunter (and a Warrior with a gun if you have one): with a
      bow and arrows equipped, the Consumables bar shows the arrows' icon and
      count, also in combat as you shoot. Set Warn at above your count: the
      count turns red and pulses. Unequip the arrows (keep them in a bag):
      missing, tooltip "Equip your arrows." A thrown weapon or wand: nothing
      shows. `/dbr debug` shows `debug ammo ... countAPI=ok`.
- [ ] Paladin, Righteous Fury: with no Tank role, no Improved Righteous Fury,
      and "Always show" off, nothing shows. Set yourself as Tank in a group
      (or learn Improved Righteous Fury, or switch on "Always show"): it shows.
      With only the talent (no group), it shows: found by the talent tree,
      not the spell ID. Removing the point hides it.
- [ ] Paladin: Righteous Fury shows red while off; a click casts it; no group
      count.
- [ ] Paladin seal timer: out of combat, a seal shows its icon with the time
      counting down (numbers and a bar), and nothing shows with no seal. In
      combat with no seal, your last seal pulses with the gold border; a
      click casts it; once a seal is up, only the seal and its timer show.
      Judgement (which uses up the seal) brings the pulse back at once.
      Seal of Fury shows its timer and covers the pulse; casting it makes it
      the click. `/dbr debug` shows `last=` the seal you cast. A
      seal cast in combat becomes the click after combat. Every seal counts;
      `/dbr debug` shows a seal line with `unknownIDs=none`.
- [ ] Druid, Thorns: solo, it watches you ("Thorns: on you"); in a group
      with yourself as Tank, still you; with another member as Tank, it
      watches them and a click casts it on them ("Thorns: on <name>"); with
      the tank dead or offline, it watches you again; walking far from the
      tank (past the group frames' range, where their frame greys) switches
      it to you at once, and coming back to the tank; between Thorns' range
      and that, the switch waits for the next buff, roster, or role change;
      a role
      change in combat applies after combat. `/dbr debug` shows `click=` the
      unit.
- [ ] Druid, Thorns on the tank: without Thorns on yourself, give the tank
      Thorns: the icon shows Thorns with the tank's time left and no border
      (not red); a click recasts it on the tank. In a fight it turns yellow
      1 minute before the tank's runs out (10% of its 10 minutes) and red when it does;
      target the tank and recast it: the yellow goes and the countdown
      restarts. The Thorns setting's tooltip reads "Maintains Thorns on you,
      or on the group's Tank if there is one. Red when it's missing, yellow
      before it runs out."
- [ ] Druid: Mark of the Wild and Thorns show red while missing; in a party, the count and
      tooltip name members without it (warriors too); a click casts on the
      next one; Gift of the Wild with Wild Berries or Wild Thornroot. In Bear
      or Cat Form a click leaves the form and casts (the tooltip says "leaves
      your form first"); nothing errors in chat. Thorns has no group count.
- [ ] Priest: Power Word: Fortitude and Inner Fire show red while missing; Divine Spirit and
      Shadow Protection show once switched on (Divine Spirit skips warriors
      and rogues); Prayer of Fortitude with Holy or Sacred Candles.
- [ ] `/dbr debug` shows `unknownIDs=none` on each class.
- [ ] Running out: "Remind before a buff runs out" shows "10%" on the
      right, no end labels, and the gold default mark under the thumb at
      10%. Every size and opacity value shows a "%" ("100%"), and no label
      ends in "(%)". With a 30-minute buff (Arcane Intellect, Mark of
      the Wild), the border turns yellow and flashes at 3 minutes left
      ("Running out: you" in the tooltip, and a countdown); a click refreshes
      it and the yellow goes. At 20%, 6 minutes; at 0%, nothing until it is
      gone. With a party member whose buff is running out, the border is
      yellow and the tooltip names them; with one missing it, red. A 1.1.0
      character's old seconds setting shows 10%.
- [ ] Borders in combat: start a fight with a 30-minute buff 3 minutes 30 seconds
      from its end: no border at first; at 3 minutes left it turns yellow
      and flashes over the game's icon; recast it (no friendly target): the
      yellow goes, as it does when it runs out, when the game's icon goes and
      ours shows red underneath. Have it dispelled or cancel it mid-fight:
      red at once. Nothing errors in chat. Battle Shout still appears only
      at 60 s left in combat.
- [ ] In combat the icons hide, and come back after; nothing errors in chat.
- [ ] Take a flight path with a buff missing: the icons hide in flight (the
      ammo count stays) and come back on landing.
- [ ] Ammo: with 1000 or more arrows the count fits inside the icon, at 100%
      and at the bar's smallest Size.
- [ ] `/reload` in combat: the icons appear once combat ends.
- [ ] Buff icons: each buff its own icon, two rows at first (group buffs
      above). Out of combat an icon shows only while its buff is missing or
      running out (countdown). Nothing ever moves on its own.
- [ ] Always shown (the key check): with your buffs up, each icon shows the
      buff with its time left, out of combat and in it; nothing appears or
      disappears when a fight starts or ends. In a fight, cancel one
      (right-click the buff) or get it dispelled: its pulsing reminder shows
      at once, and a click recasts it on you; no Lua error. Out of combat, a
      group member without Arcane Intellect, Mark of the Wild, or Fortitude
      brings the reminder with its count and click. Try a Druid in Bear Form
      (the click leaves the form).
- [ ] Unlock: each buff icon is outlined and can be dragged on its own;
      Shift-drag moves a snapped row. "Reminder icons: size" and "opacity" (at
      the end of Reminders, then the seal timer's) change every buff icon; "Reset size" works; `/dbr reset` puts them back.
- [ ] Coming from 1.1.0: each buff icon starts where its bar was.
- [ ] Coming from 1.0.0: the seal timer keeps its place and size; the
      buff icons start in their bars' default places.
- [ ] With Mage Tools Forever on a Mage, or Warlock Tools Forever on a
      Warlock: from MTF/WTF 0.3.0-beta, only DBR's icons show, and their
      reminder settings are greyed out; with an older MTF or WTF, two sets
      show.
- [ ] Cooldown chimes, with Dyre's Sounds installed: nothing about it at
      login; `/dbr` shows a "Chimes" section after the reminders,
      with one row per class spell: its switch, and its sound on the same
      row, greyed while the switch is off; the sound menu shows the full name
      of the choice, its submenus open, and choosing a sound plays it. With
      Dyre's Sounds 0.1.1, the sound sits on its own row under the switch.
- [ ] As a Mage: Blink and Frost Nova chime half a second before they are
      ready, in and out of combat; a higher rank of Frost Nova chimes too;
      Cold Snap cancels Frost Nova's chime; Text to Speech says "Blink ready";
      the "Chime early" slider moves the chime; "Enable" under Chimes off
      silences them while the buff reminders keep working.
- [ ] On each other class: `/dbr debug` shows `name=` for every chime spell,
      and a spell on by default chimes after a cast in combat. As a Rogue,
      Preparation cancels Sprint's chime.
- [ ] Without Dyre's Sounds: DBR says once to install it (naming
      CurseForge); the chime switches show without sound menus; no Lua errors
      when a chime is due; the buff reminders work.
- [ ] First run with Dyre's Cooldown Chimes still installed: DBR says it
      copied your chime settings from it and to remove its folder, and you
      hear each chime once. After removing it and `/reload`, DBR plays them
      with the same settings.
- [ ] With MTF on a Mage (or WTF on a Warlock) that still chimes: DBR says
      once at login to turn theirs off; with theirs off, it says nothing.
- [ ] Proc sounds, one class at a time: `/dbr` shows a "Proc Chimes" section
      with one row per proc; the sound menu lists only file sounds; choosing
      one plays it. Switch the proc on, get the proc in combat: the sound
      plays. After the fight, while the buff is still on you (or the next time
      it is on you out of combat), `/dbr debug` shows `status=confirmed` with
      `learned=` the buff's ID. Report each proc's `debug procs` line.
- [ ] Mage Clearcasting: note whether the game's own sound also plays, with
      DBR's switch on and off.
- [ ] Warlock with Warlock Tools Forever: on DBR's first run, "Copied your
      Nightfall sound setting from Warlock Tools Forever"; with WTF's
      Nightfall still on, note whether you hear it twice (until WTF stands
      aside for DBR).
- [ ] Reactive-ability probe, on a Warrior (then a Rogue and a Hunter):
      `/dbr probe on` lists the spells you know. Fight until a dodge (Overpower)
      or a block/dodge/parry (Revenge), and a target under 20% (Execute): a
      line says `usable=true`, then `false` again, with `secret=` and
      `combat=`; any `probe glow` lines with a spell ID. Report whether the
      lines show `secret=no` in combat, and whether any glow lines appear.
      `/dbr probe off` stops it.
