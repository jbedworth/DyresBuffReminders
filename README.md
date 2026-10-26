# Dyre's Buff Reminders

Your class buffs, each in its own icon, cast with one click, with a red
border when one drops, also in combat; ammo and reagent counts; a Paladin seal
timer; cooldown chimes; and proc chimes. For World of Warcraft: Forever. Settings are in **Options → AddOns → Dyre's
AddOns → Buff Reminders**, or type `/dbr`. They are saved per character.

- **Druid: Thorns follows your tank.** With a member set to the Tank role,
  Thorns watches that tank and a click casts it on them. Solo, with no tank,
  as the tank yourself, or when the tank is dead, offline, or out of range,
  it watches you.
- **Hunter: Aspect and combat aspect.** A click recasts your last combat
  aspect, never Cheetah or Pack, and never takes an aspect down. Start a
  fight with Cheetah or Pack up, and an icon with your combat aspect appears
  at once: one click puts it up, with an optional sound.
- **Warrior: Battle Shout, Overpower, and Revenge.** A Battle Shout
  reminder, and a sound the moment Overpower or Revenge
  becomes usable, also in combat.
- **Ammo for any bow, gun, or crossbow** (Hunters, Warriors, and Rogues): the
  count, red and pulsing when low, and "Equip your arrows" when none are
  equipped. It counts in combat too.
- **Each buff its own icon**, always shown, in a place you choose that never
  moves: the buff with its time left while it is up, a red border you click
  to cast when it is missing, yellow and flashing before it runs out, moved
  and sized with Dyre's Toolkit.
- **Also in combat:** if a buff on you expires, is dispelled, or is
  cancelled, its red reminder shows at once, and a click recasts it.
- **Reagents:** Rebirth's seeds (Druid), Arcane Powder (Mage), Infernal
  Stones and Demonic Figurines (Warlock), counted with the ammo.
- Hidden on flight paths; each icon shows the spell a click casts.
- In combat AddOns cannot read buffs, so group members' buffs (and Thorns on
  the tank) are checked again after the fight; the seal timer, the combat
  aspect icon, the ammo and reagent counts, the chimes, and the proc sounds
  keep working.

## Buff reminders

An icon for each of your class buffs, with a border that tells you where it
stands: red while it is missing, yellow and flashing while it is about to run
out, none while it is up. Each buff has its own icon in its own place,
which never moves on its own; one you do not know or have switched off shows
nothing. They start in two rows: buffs that can go on another player above,
your own below.

- **Always shown.** While the buff is on you, the game draws it in its place
  with its time left, in and out of combat alike, so nothing appears or
  disappears when a fight starts or ends.
- **When it is missing** (expired, dispelled, or cancelled) the reminder
  shows there at once with its red border, also in combat, and a click recasts it on
  you. In combat the game itself hides the buff's icon (AddOns cannot read
  buffs then), so the reminder underneath shows through.
- **Out of combat** the reminder also shows while anyone in your group lacks
  the buff, or yours is about to run out (with a countdown), with the smart
  click (group members, the tank, the group version). That stays as it is
  through a fight; your group is checked again after it.
- Unlocked, every icon shows (the buffs that are on, dimmed).

| Class | Buffs |
|---|---|
| Mage | **Arcane Intellect** (also for group members who use mana), **Armor** (Frost, Ice, or Mage Armor), **Dampen or Amplify Magic** (off at first; either counts, a click recasts the last one) |
| Warlock | In a group where you aren't the tank, a message on screen while the Voidwalker's Torment or Suffering is on autocast; **Demon Armor** (Demon Skin counts before you learn it); **Pet (your demon)**: red while you have no demon, also in combat, and a click summons the last demon you summoned, else the Imp (not after a Demonic Sacrifice, nor while mounted) |
| Warrior | **Battle Shout** (it reaches your party; watched on you). Unlike long buffs it shows only when needed: missing, or in its last 60 seconds (its own **Remind before it runs out**, 5-120 s), out of combat and in it (in combat timed from your own casts); it needs rage, which runs out soon after a fight |
| Hunter | In a group where you aren't the tank, a message on screen while your pet's Growl is on autocast. **Aspect**: any aspect counts; a click recasts the last combat aspect you cast (Hawk, Monkey, Wild, or Beast), never Cheetah or Pack, else Hawk, else Monkey; **Pet**: red while you have no pet or it is dead, also in combat (not while mounted); a click calls it, or revives it when it is dead, and a right-click revives it |
| Druid | **Mark of the Wild** (also for your group), **Thorns** (on your group's tank, else on you) |
| Priest | **Power Word: Fortitude** (also for your group), **Inner Fire**, and as options **Divine Spirit** (group members who use mana) and **Shadow Protection** (your group) |
| Paladin | **Righteous Fury** (on you; solo, or as your group's tank: the Tank role, or a raid's main tank; or with **Always show Righteous Fury** switched on; blessings are left to AddOns such as PallyPower). In a group where you aren't the tank, a message on screen while it is on. And the seal timer below |

Coming from Mage Tools Forever or Warlock Tools Forever? On DBR's first run
on a character it copies that AddOn's reminder settings (which are on, the
group switch, and your last armor) once; icon places start fresh.

- Every rank counts, and only buffs you know show. Rogues and Shamans
  have no reminders yet; DBR says so once at login and
  shows nothing.
- For group buffs, the icon shows how many lack the buff, and its tooltip
  who. Dead, offline, or out-of-sight members are skipped. Each group buff
  has a switch to remind you only about yourself.
- **Click an icon to cast the buff.** It goes to you first, then to the next
  group member in range who lacks it, so each click moves down the list. With
  two or more missing, it casts the group version instead (Arcane Brilliance,
  Gift of the Wild, Prayer of Fortitude, Prayer of Spirit, or Prayer of Shadow
  Protection) if you know it and carry its reagent.
- **Before it runs out:** a share of the buff's own length before it ends,
  its border turns yellow and flashes, so you can recast it in time: 10% at
  first, so 3 minutes before a 30-minute buff ends and 1 minute before a
  10-minute one. **Remind before a buff runs out** sets the share (0-20%; 0
  warns only once it is gone). Out of combat the icon also shows a
  countdown of the time left, and group members' buffs count too. In combat
  the yellow border comes from when your buff runs out, as DBR last read it,
  and your own recast resets it (a single-target cast counts when it went on
  you: no friendly target, or yourself targeted). Battle Shout keeps its own
  time in seconds.
- Your armor icon recasts the one you used last, else your best.
- **Hunters: combat aspect.** When a fight starts while Aspect of the
  Cheetah or the Pack is up, an icon shows your last combat aspect (else
  Hawk, else Monkey); a click casts it and the icon goes away. It is set up
  before the fight (AddOns cannot change it during one), so it shows the
  moment combat starts. It sits on the Aspect icon, so moving and sizing
  that icon moves and sizes it too. Cast a combat aspect yourself
  and it dims; it never turns invisible. An optional sound plays at combat start (its own switch
  and choice). Aspect clicks cast with "!", so they never take an aspect
  down that is already up.
- **Thorns follows the tank.** In a party or raid with a member in the Tank
  role, Thorns watches that tank, and a click casts it on them (with several,
  the first in group order who is alive, online, in sight, and in range).
  Solo, with no tank, as the tank yourself, or with the tank dead, offline,
  or out of range, it watches you, and a click casts it on you.
  The tooltip says whom. Whom a click casts on is set before a fight and
  stays through it: group and role changes apply after it; a tank who dies
  or moves out of range mid-fight makes the game refuse the cast, and if
  someone joins or leaves mid-fight the click can reach whoever takes the
  tank's party slot. While the tank has Thorns, its icon shows the tank's
  time left (the game's icon in its place shows only your own buffs); in a
  fight AddOns cannot see the tank's buffs, so it turns yellow before and
  red when it runs out by the time DBR read before the fight, and a dispel
  on the tank shows only after it. Recasting it on the tank while you
  target them restarts that time.
- **Druids in Bear, Cat, or another form:** a click leaves the form and casts
  the buff. It cannot put you back in your form: the game lets only your own
  key press cast, and changing form has to wait for the global cooldown.
- The game does not let AddOns read buffs in combat, so your group's buffs
  are checked again after a fight. The icons hide on a flight path, and come
  back when you land.

## Seal timer (Paladins)

While a seal is up, its icon shows with the time left counting down, and a
bar under it, also in combat. In combat with no seal up, your last seal
shows with the pulsing gold border and a full gold bar under it; click it to
cast that seal. Out of
combat with no seal up, nothing shows. Every seal counts, Forever's Seal of Fury
and any other seal in your spellbook included. **Seal timer**
turns it off.

## Ammo and reagents

Hunters, Warriors, and Rogues: with a bow, crossbow, or gun in your ranged slot, the
**Consumables** bar shows your equipped arrows or bullets and how many are
left, also in combat. At or below **Warn at** (200 at first) the count turns
red and pulses; out of ammo it shows as missing. With none equipped it shows
as missing too, and its tooltip says to equip the ones in your bags. Thrown
weapons and wands take no ammo, so they show nothing. **Enable** and
**Ammo** under **Consumables** in `/dbr` turn it off.

Mages: once you know Arcane Brilliance, the bar counts your Arcane Powder
(**Warn at** 5 at first, 0-40). Warlocks: Infernal Stones once you know
Inferno and Demonic Figurines once you know Ritual of Doom (**Warn at** 1
each at first, 0-10).

Druids: once you know Rebirth, the same bar counts the seeds your highest
rank uses (Maple, Stranglethorn, Ashwood, Hornbeam, or Ironwood Seed), also in
combat. At or below its own **Warn at** (2 at first, 0-10) the count turns
red and pulses; with none left it shows as missing. Gift of the Wild's Wild
Berries or Wild Thornroot count the same way once you know it (**Warn at** 5
at first). **Rebirth reagent** under **Consumables** turns it off; a new
rank or spell shows its setting after a `/reload`.

Classes with nothing to count (for now Priests, Paladins, and Shamans), and
characters who do not know a reagent spell yet, have no Consumables
settings.

## Moving the icons

DBR needs **Dyre's Toolkit** 2.0 or later (the CurseForge app installs it
with DBR). Without it, DBR stays off and says once at login where to get it.

`/dbr unlock` (or `/dyre unlock`, or **Unlock frames** on the Dyre's AddOns
page) unlocks every Dyre's AddOn at once: each buff icon, the ammo bar, and
the seal timer show their outline. Drag each where you like; it snaps to
the other Dyre's frames (Shift-drag moves a snapped row together) and, if
you choose, to the toolkit's grid. `/dbr lock` locks them again and
`/dbr reset` puts them back in their default places. Each thing's size
(50-200%) and opacity, with **Reset size**, sit at the end of its own
section on DBR's settings page: **Reminder icons** (every buff icon) and
the seal timer at the end of **Reminders**, the Consumables bar at the end
of **Consumables**.

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
| Warrior | **Overpower** and **Revenge**, on: a sound the moment one becomes usable (DBR plays it, so any sound; at most once per 3 seconds each); **Flurry**, off at first |

- Each proc has its own switch and sound, on one row; only sounds the game
  can play for a buff are listed (files, not interface sounds or Text to
  Speech). **Enable** under **Proc Chimes** turns them all off.
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

## Cast chimes

A sound just after you cast a travel spell or shift into a Druid form, also
in combat: every cast chime waits 0.75 seconds, so it follows the game's own
spell sound instead of playing over it. Druid: shifting into **Travel Form** ("Meep meep"), **Bear** or
**Dire Bear Form** ("Rawr"), **Cat Form** ("Meow"), **Aquatic Form**
("Splash"), or **Moonkin Form** ("Hoot hoot"), 0.75 seconds after you shift
and only if you are still in that form (powershifting chimes once), never
when you leave a form;
**Dash** (off at first). Hunter: **Aspect of the Cheetah** (on) and **Aspect
of the Pack** (off at first). Rogue: **Sprint** (on). Warrior: **Charge**, **Intercept**, and **Execute** (on);
**Whirlwind**, **Battle Shout**, **Demoralizing**, **Challenging**, and
**Intimidating Shout**, **Taunt**, and **Rend** (off at first); on
Anniversary also **Intervene**, **Commanding Shout**, and **Victory Rush**,
once known. Druid, in Bear Form: **Feral Charge** (once you have the
talent) and **Enrage** (on), **Demoralizing** and **Challenging Roar**,
**Bash**, and **Frenzied Regeneration** (off at first). The Warrior's and
these play Dyre's Sounds 1.2.0's "Dyre's Aggression"
sounds at first (an older Dyre's Sounds plays its default chime). Every rank counts. At
first Text to Speech says those words ("Meep meep" for the travel spells)
(set up a voice under the game's Text to Speech options; without one, the
chimes' default sound plays); choose any Dyre's Sounds sound per spell under
**Cast Chimes** in `/dbr`, whose **Enable** turns them all off. Sprint and
Dash also have a cooldown chime under **Chimes**; Travel Form and the
aspects have no cooldown.

## Combo point chimes

Rogues, and Druids in Cat Form: a note as you earn each combo point, rising
from low Bb (Dyre's Sounds 1.3.0's "Dyre's Sax"), the held high Bb when you
reach the most, and low Bb again when you spend them, also in combat. Several
points at once play in order. One point fading out of combat, a new target,
and leaving Cat Form are silent. Under **Combo Point Chimes** in `/dbr`:
**Enable**, **Full** and **Spend** (each with its own sound), **Only when
full**, and **Point notes: Dyre's Sax scale** (off: each point plays Full's
sound). With an older Dyre's Sounds, its default chime plays.

## With Mage Tools Forever or Warlock Tools Forever

Mage Tools Forever (from 1.2.0) and Warlock Tools Forever (from 1.3.0) rely
on Dyre's Buff Reminders for their buff reminders and cooldown chimes, and
install it with them. The first time DBR runs on a character, it copies that
AddOn's reminder settings once (see above). An older MTF or WTF may still
show its own reminders or play its own chimes; DBR says so once at login, and
you can turn them off in MTF or WTF.

## Commands

| Command | What it does |
|---|---|
| `/dbr`, `/dbr options` | Opens the settings (out of combat): Reminders, Consumables, Chimes, Proc Chimes, and Cast Chimes |
| `/dbr unlock`, `/dbr lock` | Unlocks every Dyre's AddOn's frames to drag them, and locks them again |
| `/dbr reset` | Moves the buff icons, the Consumables bar, and the seal timer back to their default places |
| `/dbr debug` | Diagnostics: each reminder, who lacks it, what a click casts, and any spell IDs the client does not know; the seal timer; each chime spell, Dyre's Sounds, and the latest chime events; and each proc, its spell IDs, and whether it is confirmed in game |
| `/dbr probe on`, `/dbr probe off` | A test aid: chat lines when a Warrior's, Rogue's, or Hunter's reactive abilities (Overpower, Revenge, Execute, Riposte, Mongoose Bite, Counterattack) become usable or glow; off by default |

`/buffreminders` works the same, in case another AddOn uses `/dbr`.

## Compatibility

For World of Warcraft: Forever 1.60.1 (tested on build 70450, Interface
16001). If a client update removes an API it needs, it says so in chat and
stays off.

**Verified in client:** the Paladin seal timer, with Seal of Fury, and
Righteous Fury; Druid Mark of the Wild, Thorns, and the Rebirth seed count;
the Hunter aspects; the always-shown buffs and recasting in combat; the proc
sounds on a Warlock (Nightfall) and a Warrior's Revenge.

**Not yet verified in client:** the Priest buffs, the group versions' spell
IDs and reagents, the Mage and Warlock reagents, and the chime lists of
classes other than Mage and Warlock. [TESTING.md](TESTING.md) has the
checklist.

WowUp users (2.24.0 or later): install from the repository URL; GitHub releases
carry the Forever metadata WowUp needs.

## Support

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

## License

MIT. See [LICENSE](LICENSE).
