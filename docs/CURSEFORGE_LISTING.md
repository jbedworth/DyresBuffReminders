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

Your class buffs, always in view and one click to cast, with a red border when one drops, also in combat. Reagent and ammo counts, a seal timer, and cooldown, proc, and cast chimes.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
**Dyre's Buff Reminders** keeps your class buffs in view, each in its own icon, and casts them with one click. It also counts your ammo and reagents, times your seal, chimes before your cooldowns are ready, and chimes your procs and travel spells. Made for World of Warcraft: Forever.

**Mage Tools Forever** and **Warlock Tools Forever** rely on it for their buff reminders and chimes, and it works on every class.

### What's new in 1.4.0
- **Cast Chimes:** "Meep meep" just after you cast Aspect of the Cheetah or Sprint, or shift into Travel Form, and a sound for shifting into Bear ("Rawr"), Cat ("Meow"), Aquatic, or Moonkin Form, also in combat; never when you leave a form. Choose any sound for each.

Mage Tools Forever and Warlock Tools Forever players: the first time DBR runs on a character, it copies that AddOn's buff reminder settings.

### Always in view
Each buff has its own icon, in a place you choose that never moves. While a buff is on you, the game draws it there with its time left, in and out of combat. The border tells you where it stands:
- **Red:** missing (it ran out, was dispelled, or was cancelled). This shows at once, also in combat, and a click recasts it on you.
- **Yellow and flashing:** about to run out. **Remind before a buff runs out** sets how early, as a share of the buff's own length (0-20%, 10% at first: 3 minutes before a 30-minute buff ends). Also in combat; your own recast resets it.
- **No border:** it is up.

### Which buffs
- **Druid:** Mark of the Wild (also for your group) and Thorns. In a group with a member set to the Tank role, Thorns watches that tank and a click casts it on them; solo, as the tank yourself, or with no tank in reach, it watches you. While the tank has Thorns, its icon shows the tank's time left, yellow before it runs out and red when it does, also in combat.
- **Hunter:** Aspect (any aspect counts; a click recasts your last combat aspect, never Cheetah or Pack), plus the combat aspect reminder: start a fight with Cheetah or Pack up, and one click puts your combat aspect up. And a Pet reminder: no pet, or a dead one, also mid-fight, and one click calls or revives it.
- **Mage:** Arcane Intellect (also for group members who use mana), your armor (Frost, Ice, or Mage Armor), and Dampen or Amplify Magic (off at first).
- **Paladin:** Righteous Fury, solo or as your group's tank (the Tank role, or a raid's main tank), or with **Always show Righteous Fury** on; in a group where you aren't the tank, a message on screen while it's on. And a seal timer: while a seal is up, its time left counts down, also in combat; in combat with no seal, your last seal pulses and a click casts it.
- **Priest:** Power Word: Fortitude (also for your group) and Inner Fire; Divine Spirit and Shadow Protection as options.
- **Hunter and Warlock, in a group where you aren't the tank:** a message on screen while your pet's taunt (Growl, Torment, Suffering) is on autocast.
- **Warlock:** Demon Armor (Demon Skin counts), and a Pet reminder: no demon, also mid-fight, and one click summons your last one (not after a Demonic Sacrifice).
- **Warrior:** Battle Shout, which shows only when it is missing or in its last minute (you choose the seconds), also in combat; it needs rage, so cast it while you still have some after a fight.

Every rank counts, and only buffs you know show. Rogues and Shamans have no buff reminders yet.

### Click to cast
- A click buffs you first, then the next group member in range who lacks it. The icon shows how many lack it, and its tooltip who.
- With two or more missing, it casts the group version (Arcane Brilliance, Gift of the Wild, Prayer of Fortitude, Prayer of Spirit, Prayer of Shadow Protection) if you know it and carry its reagent.
- Your armor, your aspect, and Dampen or Amplify Magic recast the one you used last.
- Druids in a form: a click leaves the form, then casts the buff.
- Your group's buffs are checked out of combat; the game does not let AddOns read them in a fight.

### Ammo and reagents
A Consumables bar counts, also in combat, and turns red and pulses at or below each one's **Warn at**:
- **Ammo** (Hunters, Warriors, and Rogues, with a bow, gun, or crossbow): your arrows or bullets; with none equipped, it tells you to equip the ones in your bags.
- **Druid:** Rebirth's seed for your highest rank (Maple Seed to Ironwood Seed; 2 at first), and Gift of the Wild's Wild Berries or Wild Thornroot once you know it.
- **Mage:** Arcane Powder (5 at first).
- **Warlock:** Infernal Stones and Demonic Figurines (1 at first).

Each reagent shows once you know its spell.

### Cooldown chimes
A sound just before your chosen spells are ready again, also in combat, for every class. Every rank of a spell counts, unlike the Cooldown Manager on Forever. Each spell has its own switch and sound (Text to Speech can say "Blink ready"), and **Chime early (seconds)** sets how early. The sounds come from **Dyre's Sounds**, which installs with it.

### Proc chimes
A sound the moment a proc appears on you, also in combat: Nightfall, Clearcasting, Nature's Grace, and Flurry, plus a Warrior's Overpower and Revenge the moment they become usable. Each has its own switch and sound.

### Cast chimes
A sound just after you cast a travel spell or shift into a Druid form (0.75 seconds later, after the game's own sound), also in combat: shifting into Travel, Bear or Dire Bear, Cat, Aquatic, or Moonkin Form (never out of one), and Dash; Hunter Aspect of the Cheetah and Aspect of the Pack; Rogue Sprint; Warrior Charge, Intercept, and Execute (on), and Whirlwind, the shouts, Taunt, and Rend (off at first), with Dyre's Sounds' "Dyre's Aggression" sounds. At first, Text to Speech says "Meep meep" (or "Rawr", "Meow", and so on for the forms); each has its own switch and sound under **Cast Chimes**.

### Put them where you like
Unlock with `/dbr unlock` to drag each buff icon, the Consumables bar, and the seal timer; they snap to your other Dyre's frames and to a grid. Each one's size and opacity sit at the end of its own section in `/dbr`: **Reminder icons** (all buff icons) and the seal timer under Reminders, the Consumables bar under Consumables. `/dbr reset` puts them back. Moving and sizing come from **Dyre's Toolkit**, which installs with it. Settings are saved per character.

### Commands
- `/dbr` (or `/dbr options`) opens the settings: Reminders, Consumables, Chimes, Proc Chimes, and Cast Chimes.
- `/dbr unlock`, `/dbr lock`, `/dbr reset`, `/dbr debug`.
- `/buffreminders` works the same, in case another AddOn uses `/dbr`.

### Compatibility
For World of Warcraft: Forever 1.60.1 (tested on build 70450). If a client update removes an API it needs, it says so in chat and stays off.

WowUp users (2.24.0 or later): install from the repository URL; GitHub releases carry the Forever metadata WowUp needs.

Source, issues, and license (MIT): https://github.com/jbedworth/DyresBuffReminders
```
