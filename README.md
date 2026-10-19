# Dyre's Buff Reminders

The buff reminders from Mage Tools Forever and Warlock Tools Forever, and the
cooldown chimes from Dyre's Cooldown Chimes, on their own, for World of
Warcraft: Forever (beta). Settings are in **Options → AddOns → Dyre's Buff
Reminders**, or type `/dbr`. They are saved per character.

## Buff reminders

An icon with a pulsing gold border for each of your class buffs that is
missing or about to run out, out of combat. It goes away once the buff is on.

| Class | Buffs |
|---|---|
| Mage | **Arcane Intellect** (also for group members who use mana), **Armor** (Frost, Ice, or Mage Armor), **Dampen or Amplify Magic** (off at first) |
| Warlock | **Demon Armor** (Demon Skin counts before you learn it) |
| Druid | **Mark of the Wild** (also for your group), **Thorns** |
| Priest | **Power Word: Fortitude** (also for your group), **Inner Fire**, and as options **Divine Spirit** (group members who use mana) and **Shadow Protection** (your group) |
| Paladin | **Righteous Fury** (on you; blessings are left to AddOns such as PallyPower), and the seal timer below |

- Every rank counts, and only buffs you know show. Warriors, Rogues,
  Hunters, and Shamans have no reminders yet; DBR says so once at login and
  shows nothing.
- For group buffs, the icon shows how many lack the buff, and its tooltip
  who. Dead, offline, or out-of-sight members are skipped. Each group buff
  has a switch to remind you only about yourself.
- **Click an icon to cast the buff.** It goes to you first, then to the next
  group member in range who lacks it, so each click moves down the list. With
  two or more missing, it casts the group version instead (Arcane Brilliance,
  Gift of the Wild, Prayer of Fortitude, Prayer of Spirit, or Prayer of Shadow
  Protection) if you know it and carry its reagent.
- **Before it runs out:** the icon shows 5 seconds before a buff on you or
  your group runs out, so you can recast it in time. **Remind before a buff
  runs out** sets the seconds (0-30; 0 waits until it is gone). A buff that
  runs out in a fight shows after the fight.
- Your armor icon (and Dampen or Amplify Magic) recasts the one you used
  last, else your best.
- **Druids in Bear, Cat, or another form:** a click leaves the form and casts
  the buff. It cannot put you back in your form: the game lets only your own
  key press cast, and changing form has to wait for the global cooldown.
- The game does not let AddOns read buffs in combat, so the icons hide when a
  fight starts and come back after.

## Seal timer (Paladins)

While a seal is up, its icon shows with the time left counting down, and a
bar under it, also in combat. In combat with no seal up, your last seal
shows with the pulsing gold border and a full gold bar under it; click it to
cast that seal. Out of
combat with no seal up, nothing shows. Every seal counts, Forever's Seal of Fury
and any other seal in your spellbook included. **Seal timer**
turns it off.

## Moving the icons

**Unlock to move them** (or `/dbr unlock`) shows every icon (and the seal
timer) to drag; scroll
over one to resize it (50-200%). Drop one near another and it snaps beside
it, lined up; Shift-drag moves a snapped group. A faint grid with red center
lines helps you line them up (it can be turned off). `/dbr lock` locks them
again and `/dbr reset` puts them back in a row.

## Cooldown chimes

A sound just before your chosen spells are ready again, so you can act the
moment they are, also in combat. Every class has a list (a Mage's Blink,
Frost Nova, and Counterspell; a Warlock's Death Coil; a Druid's Barkskin; and
so on).

- **Every rank counts.** A spell is matched by its name. Blizzard's Cooldown
  Manager on Forever treats each rank as a different spell; the chimes do
  not.
- Each spell has its own switch and its own sound, in a menu under the
  switch; choosing a sound plays it. Text to Speech says "Blink ready".
  **Chime early** moves every chime 0-3 seconds before the cooldown ends
  (default half a second). **Cooldown chimes** turns them all off.
- The game hides cooldowns from AddOns in combat, so DBR times each one from
  your cast: the length it last read out of combat, else Classic's. Cold Snap
  and Preparation cancel the chimes of the spells they reset.
- **The sounds come from Dyre's Sounds.** Install it from CurseForge (the
  CurseForge app installs it with DBR). Without it, the chimes play nothing,
  DBR says so once at login, and the buff reminders work as usual.
- Your chime settings carry over on the first run: from Dyre's Cooldown
  Chimes if you used it, else from Mage Tools Forever or Warlock Tools
  Forever. Dyre's Cooldown Chimes is now part of DBR: remove its folder;
  while it is installed, it plays the chimes and DBR plays none.

## With Mage Tools Forever or Warlock Tools Forever

Both have these reminders and cooldown chimes too. From their 0.3.0-beta on,
they hide their own reminders while Dyre's Buff Reminders is installed, and
their reminder settings are greyed out. From their 0.3.2-beta on, they also
play no chimes while DBR is installed. An older MTF or WTF may still play
its own chimes; DBR says so once at login, and you can turn off its
"Cooldown chimes". With an older MTF or WTF you may see two sets of
icons on a Mage or Warlock; turn one off with MTF's or WTF's "Buff
reminders" switch, or DBR's.

## Commands

| Command | What it does |
|---|---|
| `/dbr`, `/dbr options` | Opens the settings (out of combat): the buff reminders, then the cooldown chimes |
| `/dbr unlock`, `/dbr lock` | Unlocks the icons to drag them, and locks them again |
| `/dbr reset` | Moves the icons back to their default places and sizes |
| `/dbr debug` | Diagnostics: each reminder, who lacks it, what a click casts, and any spell IDs the client does not know; the seal timer; and each chime spell, Dyre's Sounds, and the latest chime events |

`/buffreminders` works the same, in case another AddOn uses `/dbr`.

## Compatibility

Beta, for the Forever beta client 1.60.1 (Interface 16001). DBR keeps working
on later beta builds; if a client update removes an API it needs, it says so
in chat and stays off.

**Verified in client:** the Paladin seal timer, with Seal of Fury.

**Not yet verified in client:** the rest. The reminders come from Mage Tools
Forever and Warlock Tools Forever and the chimes from Dyre's Cooldown Chimes,
but the Druid and Priest buffs, the group versions' spell IDs and reagents,
the chime lists of classes other than Mage and Warlock, and this AddOn
itself have not been checked in game. [TESTING.md](TESTING.md) has the checklist.

WowUp users (2.24.0 or later): install from the repository URL; GitHub releases
carry the Forever metadata WowUp needs.

## License

MIT. See [LICENSE](LICENSE).
