# CurseForge listing

Copy-ready text for the CurseForge project form. Keep it aligned with README.md
and the tested client; do not advertise clients or versions that have not been
tested.

## Project fields

| Field | Value |
| --- | --- |
| Name | Dyre's Buff Reminders |
| Project ID | 1753804 (the value for the `CURSEFORGE_PROJECT_ID` repository variable; see docs/RELEASE_PLAN.md) |
| Class | Addons |
| Main category | Buffs & Debuffs. Keep it identical to the TOC `## Category`, which groups the AddOn in the in-game AddOn list. |
| Additional categories | None yet (CurseForge allows up to 4; unrelated ones can send the project back for changes). |
| Author shown | Dyre, set through the CurseForge account's username |
| License | MIT License |
| Logo | artwork/dyres-buff-reminders-logo.png (1024 x 1024); artwork/dyres-buff-reminders-logo-512.png if a smaller square is wanted |
| Relations | Dyre's Sounds (slug `dyres-sounds`), for the chimes' and procs' sounds, and Dyre's Toolkit (slug `dyres-toolkit`), which places and sizes DBR's bars and holds its settings: both required dependencies. CI uploads set them; add them by hand on any file uploaded through the website. |
| Screenshots | None yet (no artwork/screenshots/ folder; see artwork/README.md). Any old gallery image showing the 1.1.0 buff bars is out of date. |
| Source | https://github.com/jbedworth/DyresBuffReminders |
| Issues | https://github.com/jbedworth/DyresBuffReminders/issues |
| Donation | Ko-fi, https://ko-fi.com/dyre_janelle (the project's Donation field) |

## Summary

Your class buffs in view and one click to cast, with a glow when one drops, even in combat. Plus ammo, seals, chimes, and procs. For WoW: Forever and Classic Era.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
I kept pulling mobs without my armor on, and I kept noticing a group member running around without Fortitude halfway through a dungeon. So I made Dyre's Buff Reminders. Each of your class buffs gets its own icon in a spot you pick, and the moment one drops, that icon tells you, even in combat. One click casts it again.

Over time I added the other things I wanted on every character: ammo and reagent counts, a Paladin seal timer, chimes before your cooldowns are ready, and proc arcs. It works on every class. If you play Warlock Tools Forever or Mage Tools Forever, you already have it, because they use it for their buff reminders, chimes, and procs, and you can change those settings from their pages too.

### Your buffs, always in view
- Each buff has its own icon in a place you choose, and it never moves on its own. While the buff is up, the icon shows its time left.
- A missing buff glows right away, also in combat, and a click casts it again. A player asked for the glow. If you'd rather have the old red border, you can pick it in the settings.
- When a buff is about to run out, its border turns yellow and flashes. You choose how early. At first it's 10% of the buff's length, so 3 minutes before a 30-minute buff ends.
- **Show only when needed** is a switch on each buff. Turn it on and a buff that's up stays hidden, or faint if you like, until it's about to run out. Battle Shout can also show only in combat.
- The game hides your buffs from AddOns during a boss encounter. DBR waits for the encounter to end before it checks again, so it won't tell you a buff is missing when you still have it.

### Which buffs
- Druids get Mark of the Wild, also for the group, and Thorns. In a group with a tank, Thorns watches the tank, and a click casts it on them.
- Hunters get an **Aspect reminder** that only shows up when something's wrong: no aspect, or Cheetah or Pack up in a fight. One click puts your last combat aspect back up.
- Hunters also get an **aspect bar** that swaps aspects in one click. It can be a row or a column, and the aspect that's up has a gold border. A Pet reminder calls or revives your pet.
- Mages get Arcane Intellect, also for group members who use mana, and their armor. Dampen and Amplify Magic are there too, off at first.
- Paladins get Righteous Fury when they tank, and a message on screen if it's on when they don't. A **seal timer** counts down your seal, also in combat. With no seal in a fight, your last seal pulses, and a click casts it.
- Priests get Power Word: Fortitude, also for the group, and Inner Fire. Divine Spirit and Shadow Protection are options.
- Warlocks get Demon Armor, and Demon Skin counts. A Pet reminder shows when you have no demon, and one click summons your last one.
- Warriors get Battle Shout, which shows only when it's missing or in its last minute.
- Hunters and Warlocks get a message on screen while the pet's taunt is on autocast in a group where they're not the tank. With Dyre's Threat and Combat Tools installed, that AddOn gives the warning instead, so you never see it twice.

Every rank counts, and only buffs you know show up. Rogues and Shamans don't have buff reminders yet.

### One click to cast
- Your first click buffs you, and each click after that buffs the next group member in range who lacks it. The icon shows how many still need it, and the tooltip says who.
- With two or more missing, it casts the group version, like Arcane Brilliance, Gift of the Wild, or Prayer of Fortitude, if you know it and carry the reagent.
- A Druid in a form leaves the form and casts the buff.
- The game doesn't let AddOns read your group's buffs during a fight, so DBR checks them again when the fight ends.

### Ammo and reagents
A **Consumables bar** counts them, also in combat. When you're low, the count turns red and pulses, and you set the number for each one.
- Hunters, Warriors, and Rogues with a bow, gun, or crossbow see their ammo. With none equipped, the bar tells you to equip the ammo in your bags.
- Druids see Rebirth's seeds and Gift of the Wild's berries. Mages see Arcane Powder. Warlocks see Infernal Stones and Demonic Figurines. Each one is there once you know its spell.

### Cooldown chimes
A sound plays just before your chosen spells are ready again, for every class and also in combat. Every rank counts, which the Cooldown Manager on Forever can't do. Each spell has its own switch and sound, and you choose how early the chime plays. Text to Speech can say "Blink ready". The sounds come from Dyre's Sounds.

### Procs
While a proc is up, an arc shows on each side of your character, and a sound plays the moment it appears, also in combat. That covers Missile Barrage, Fingers of Frost, Nightfall, Decimation, Clearcasting, Nature's Grace, and Flurry, plus a Warrior's Overpower and Revenge and a Hunter's Mongoose Bite while they're usable.

Every proc of your class is listed and greyed out until you learn its talent. Each one has its own arc and sound switches, and one switch turns them all off. The arcs need Dyre's Toolkit 2.12 or later. With an older one, you get the sounds only.

### Combo point chimes
Rogues, and Druids in Cat Form, hear a rising note for each combo point, a held note at the most points, and a sound when they spend them. The default is a comic bassoon climb. You can pick a sax scale instead, or one sound for every point.

### Cast chimes
A short sound plays right after you cast a travel spell or shift into a Druid form, also in combat. Aspect of the Cheetah, Sprint, Dash, and Travel Form say "Meep meep". Bear Form says "Rawr" and Cat Form says "Meow". Warriors can add Charge, Intercept, Execute, and a few other moves, and each one has its own switch and sound.

### Put them where you like
Type `/dbr unlock` and drag each buff icon, the Consumables bar, the aspect bar, the seal timer, and the proc arcs where you want them. They snap to your other Dyre's frames and to a grid. Each one's size and opacity are in its own section of `/dbr`, and `/dbr reset` puts everything back.

Settings are saved per character. With Dyre's Toolkit 2.10 or later, you can copy them from another character or share them as one line of text.

### Settings in one place
Each section has its own on/off switch, so you can keep just the parts you want: Reminders, Consumables, Chimes, Procs, and Cast Chimes. With Dyre's Toolkit 2.17 or later, your class's Reminders, Chimes, and Procs also show on the Warlock Tools Forever and Mage Tools Forever pages. They're the same settings, so a change on one page is a change on the other.

### Commands
- `/dbr` opens the settings.
- `/dbr unlock`, `/dbr lock`, `/dbr reset`, and `/dbr debug` do what they say.
- `/buffreminders` works the same, in case another AddOn uses `/dbr`.

### What gets installed with it
DBR needs Dyre's Toolkit, which moves and sizes the icons and holds the settings. It also uses Dyre's Sounds for the chimes and proc sounds. The CurseForge app installs both for you.

### Compatibility
I made it for World of Warcraft: Forever 1.60.1 and tested it on build 70450. It also loads on Classic Era. If a game update removes something it needs, it tells you in chat and stays off.

WowUp users with 2.24.0 or later can install from the repository URL, because the GitHub releases carry what WowUp needs.

Let me know what you think in the comments, or open an issue at https://github.com/jbedworth/DyresBuffReminders/issues for a bug.

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

Source (MIT): https://github.com/jbedworth/DyresBuffReminders
```
