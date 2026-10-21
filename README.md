# Dyre's Buff Reminders

The class buffs you are missing, in two tidy bars, cast with one click; an
ammo count; a Paladin seal timer; cooldown chimes; and proc sounds. For World
of Warcraft: Forever (beta). Settings are in **Options → AddOns → Dyre's
AddOns → Buff Reminders**, or type `/dbr`. They are saved per character.

- **Druid: Thorns follows your tank.** With a member set to the Tank role,
  Thorns watches that tank and a click casts it on them. Solo, with no tank,
  as the tank yourself, or when the tank is dead, offline, or out of range,
  it watches you. Mark of the Wild sits in Group buffs.
- **Hunter: Aspect and combat aspect.** A click recasts your last combat
  aspect, never Cheetah or Pack, and never takes an aspect down. Start a
  fight with Cheetah or Pack up, and an icon with your combat aspect appears
  at once: one click puts it up, with an optional sound.
- **Ammo for any bow, gun, or crossbow** (Warriors and Rogues too): the
  count, red and pulsing when low, and "Equip your arrows" when none are
  equipped. It counts in combat too.
- **Two buff bars**, My buffs and Group buffs, showing only what is missing,
  click to cast, moved and sized with Dyre's Toolkit.
- Hidden on flight paths; each icon shows the spell a click casts.
- In combat the buff bars hide (the game hides buffs from AddOns then); the
  seal timer, the combat aspect icon, the ammo count, the chimes, and the
  proc sounds keep working.

## Buff reminders

An icon with a pulsing gold border for each of your class buffs that is
missing or about to run out, out of combat. It goes away once the buff is on.
The icons sit in two bars, **Group buffs** (buffs that can go on another player)
and **My buffs**, each as wide as the buffs you know and have switched on;
the missing ones line up from its left edge, and a click on a bar's empty
part goes through to the world. Unlocked, a bar shows all of its buffs (those
already on, dimmed).

| Class | Buffs |
|---|---|
| Mage | **Arcane Intellect** (also for group members who use mana), **Armor** (Frost, Ice, or Mage Armor) |
| Warlock | **Demon Armor** (Demon Skin counts before you learn it) |
| Hunter | **Aspect**: any aspect counts; a click recasts the last combat aspect you cast (Hawk, Monkey, Wild, or Beast), never Cheetah or Pack, else Hawk, else Monkey |
| Druid | **Mark of the Wild** (also for your group), **Thorns** (on your group's tank, else on you) |
| Priest | **Power Word: Fortitude** (also for your group), **Inner Fire**, and as options **Divine Spirit** (group members who use mana) and **Shadow Protection** (your group) |
| Paladin | **Righteous Fury** (on you; blessings are left to AddOns such as PallyPower), and the seal timer below |

Dampen and Amplify Magic are not reminded: you cast them on chosen members
when a fight needs them, as with Paladin Blessings.

- Every rank counts, and only buffs you know show. Warriors, Rogues,
  and Shamans have no reminders yet; DBR says so once at login and
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
- Your armor icon recasts the one you used last, else your best.
- **Hunters: combat aspect.** When a fight starts while Aspect of the
  Cheetah or the Pack is up, an icon shows your last combat aspect (else
  Hawk, else Monkey); a click casts it and the icon goes away. It is set up
  before the fight (AddOns cannot change it during one), so it shows the
  moment combat starts. It sits on the Aspect slot of My buffs, so moving
  and sizing that bar moves and sizes it too. Cast a combat aspect yourself
  and it dims; it never turns invisible. An optional sound plays at combat start (its own switch
  and choice). Aspect clicks cast with "!", so they never take an aspect
  down that is already up.
- **Thorns follows the tank.** In a party or raid with a member in the Tank
  role, Thorns watches that tank, and a click casts it on them (with several,
  the first in group order who is alive, online, in sight, and in range).
  Solo, with no tank, as the tank yourself, or with the tank dead, offline,
  or out of range, it watches you, and a click casts it on you.
  The tooltip says whom.
- **Druids in Bear, Cat, or another form:** a click leaves the form and casts
  the buff. It cannot put you back in your form: the game lets only your own
  key press cast, and changing form has to wait for the global cooldown.
- The game does not let AddOns read buffs in combat, so the icons hide when a
  fight starts and come back after. They also hide on a flight path, and
  come back when you land.

## Seal timer (Paladins)

While a seal is up, its icon shows with the time left counting down, and a
bar under it, also in combat. In combat with no seal up, your last seal
shows with the pulsing gold border and a full gold bar under it; click it to
cast that seal. Out of
combat with no seal up, nothing shows. Every seal counts, Forever's Seal of Fury
and any other seal in your spellbook included. **Seal timer**
turns it off.

## Ammo

With a bow, crossbow, or gun in your ranged slot (any class), the
**Consumables** bar shows your equipped arrows or bullets and how many are
left, also in combat. At or below **Warn at** (200 at first) the count turns
red and pulses; out of ammo it shows as missing. With none equipped it shows
as missing too, and its tooltip says to equip the ones in your bags. Thrown
weapons and wands take no ammo, so they show nothing. **Enable** and
**Ammo** under **Consumables** in `/dbr` turn it off.

## Moving the bars

DBR needs **Dyre's Toolkit** 2.0 or later (the CurseForge app installs it
with DBR). Without it, DBR stays off and says once at login where to get it.

`/dbr unlock` (or `/dyre unlock`, or **Unlock frames** on the Dyre's AddOns
page) unlocks every Dyre's AddOn at once: each bar shows its outline and its
icons, and the seal timer shows too. Drag a bar by any of its icons; it snaps
to the other Dyre's frames and, if you choose, to the toolkit's grid.
`/dbr lock` locks them again and `/dbr reset` puts them back in their default
places. **Size and Opacity** on DBR's settings page sets each bar's and the
seal timer's size (50-200%) and opacity, with **Reset size**.

## Cooldown chimes

A sound just before your chosen spells are ready again, so you can act the
moment they are, also in combat. Every class has a list (a Mage's Blink,
Frost Nova, and Counterspell; a Warlock's Death Coil; a Druid's Barkskin; and
so on).

- **Every rank counts.** A spell is matched by its name. Blizzard's Cooldown
  Manager on Forever treats each rank as a different spell; the chimes do
  not.
- Each spell has its own switch and its own sound, side by side on one row
  (with an older Dyre's Sounds, the sound sits under the switch); choosing a
  sound plays it. Text to Speech says "Blink ready".
  **Chime early** moves every chime 0-3 seconds before the cooldown ends
  (default half a second). **Enable** under **Chimes** turns them all off.
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

## Proc sounds

A sound the moment a proc appears on you, so you can use it, also in combat:

| Class | Procs |
|---|---|
| Warlock | **Nightfall** (Shadow Trance: your next Shadow Bolt is instant), off at first |
| Mage | **Clearcasting** (Arcane Concentration), off at first: the game already plays a sound for it |
| Druid | **Nature's Grace**, on; **Clearcasting** (Omen of Clarity), off at first |
| Shaman | **Clearcasting** (Elemental Focus), off at first |
| Warrior | **Flurry**, off at first |

- Each proc has its own switch and sound, on one row; only sounds the game
  can play for a buff are listed (files, not interface sounds or Text to
  Speech). **Enable** under **Procs** turns them all off.
- The game plays the sound itself when the buff appears, because AddOns
  cannot read your buffs in combat. During a boss encounter the game does not
  let AddOns change these sounds, so a change you make then applies after it.
- DBR starts from Classic's spell IDs and checks them in game: the first
  time a proc's buff is on you out of combat (for example right after a
  fight), DBR reads its real ID and uses it from then on.
- On a Warlock, your Nightfall sound setting carries over from Warlock Tools
  Forever on the first run. From its 0.3.3-beta on, Warlock Tools Forever
  leaves Nightfall to DBR; with an older one still playing it, DBR says so
  once at login.

## With Mage Tools Forever or Warlock Tools Forever

Both have these reminders and cooldown chimes too. From their 0.3.0-beta on,
they hide their own reminders while Dyre's Buff Reminders is installed, and
their reminder settings are greyed out. From their 0.3.2-beta on, they also
play no chimes while DBR is installed. An older MTF or WTF may still play
its own chimes; DBR says so once at login, and you can turn off its
"Cooldown chimes". With an older MTF or WTF you may see two sets of
icons on a Mage or Warlock; turn one off with MTF's or WTF's "Buff
reminders" switch, or DBR's **Enable** under **Reminders**.

## Commands

| Command | What it does |
|---|---|
| `/dbr`, `/dbr options` | Opens the settings (out of combat): the buff reminders, then the cooldown chimes |
| `/dbr unlock`, `/dbr lock` | Unlocks every Dyre's AddOn's frames to drag them, and locks them again |
| `/dbr reset` | Moves DBR's bars and the seal timer back to their default places |
| `/dbr debug` | Diagnostics: each reminder, who lacks it, what a click casts, and any spell IDs the client does not know; the seal timer; each chime spell, Dyre's Sounds, and the latest chime events; and each proc, its spell IDs, and whether it is confirmed in game |
| `/dbr probe on`, `/dbr probe off` | A test aid: chat lines when a Warrior's, Rogue's, or Hunter's reactive abilities (Overpower, Revenge, Execute, Riposte, Mongoose Bite, Counterattack) become usable or glow; off by default |

`/buffreminders` works the same, in case another AddOn uses `/dbr`.

## Compatibility

For the Forever beta client 1.60.1 (Interface 16001). DBR keeps working
on later beta builds; if a client update removes an API it needs, it says so
in chat and stays off.

**Verified in client:** the Paladin seal timer, with Seal of Fury; the proc
sounds on a Warlock (Nightfall).

**Not yet verified in client:** the rest. The reminders come from Mage Tools
Forever and Warlock Tools Forever and the chimes from Dyre's Cooldown Chimes,
but the Druid and Priest buffs, the group versions' spell IDs and reagents,
the chime lists of classes other than Mage and Warlock, and this AddOn
itself have not been checked in game. [TESTING.md](TESTING.md) has the checklist.

WowUp users (2.24.0 or later): install from the repository URL; GitHub releases
carry the Forever metadata WowUp needs.

## Support

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

## License

MIT. See [LICENSE](LICENSE).
