# Dyre's Buff Reminders

The buff reminders from Mage Tools Forever and Warlock Tools Forever, on their
own, for World of Warcraft: Forever (beta). Settings are in **Options →
AddOns → Dyre's Buff Reminders**, or type `/dbr`. They are saved per
character.

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

## With Mage Tools Forever or Warlock Tools Forever

Both have these reminders too. From their 0.3.0-beta on, they hide their own
reminders while Dyre's Buff Reminders is installed, and their reminder
settings are greyed out. With an older MTF or WTF you may see two sets of
icons on a Mage or Warlock; turn one off with MTF's or WTF's "Buff
reminders" switch, or DBR's.

## Commands

| Command | What it does |
|---|---|
| `/dbr`, `/dbr options` | Opens the settings (out of combat) |
| `/dbr unlock`, `/dbr lock` | Unlocks the icons to drag them, and locks them again |
| `/dbr reset` | Moves the icons back to their default places and sizes |
| `/dbr debug` | Diagnostics: each reminder, who lacks it, what a click casts, and any spell IDs the client does not know |

`/buffreminders` works the same, in case another AddOn uses `/dbr`.

## Compatibility

Beta, for the Forever beta client 1.60.1 (Interface 16001). DBR keeps working
on later beta builds; if a client update removes an API it needs, it says so
in chat and stays off.

**Verified in client:** the Paladin seal timer, with Seal of Fury.

**Not yet verified in client:** the rest. The reminders come
from Mage Tools Forever and Warlock Tools Forever, but the Druid and Priest
buffs, the group versions' spell IDs and reagents, and this AddOn itself have
not been checked in game. [TESTING.md](TESTING.md) has the checklist.

WowUp users (2.24.0 or later): install from the repository URL; GitHub releases
carry the Forever metadata WowUp needs.

## License

MIT. See [LICENSE](LICENSE).
