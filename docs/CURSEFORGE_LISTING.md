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
| Screenshots | artwork/screenshots/ (none taken yet; see artwork/README.md) |
| Source | https://github.com/jbedworth/DyresBuffReminders |
| Issues | https://github.com/jbedworth/DyresBuffReminders/issues |
| Donation | Ko-fi, https://ko-fi.com/dyre_janelle (the project's Donation field) |

## Summary

Missing buffs in two tidy bars, one click to cast. Thorns that follows your tank, Hunter aspect reminders, an ammo count, a seal timer, cooldown chimes, and proc sounds, for World of Warcraft: Forever.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
**Dyre's Buff Reminders** shows the class buffs you are missing, in two tidy bars, and casts them with one click. It also tracks your ammo, times your seal, chimes before your cooldowns are ready, and sounds your procs. Made for World of Warcraft: Forever.

### What's new in 1.1.0
- **Druid: Thorns follows your tank.** In a party or raid with a member set to the Tank role, Thorns watches that tank, and a click casts it on them. Solo, with no tank, as the tank yourself, or when the tank is dead, offline, or out of range, it watches you, and a click casts it on you. It switches back to you as soon as the tank's party frame greys out. The tooltip always says whom it watches.
- **Hunter: Aspect reminder.** No aspect up? A click recasts the last combat aspect you used (Hawk, Monkey, Wild, or Beast), never Cheetah or Pack, and it never takes down an aspect that is already up.
- **Hunter: combat aspect reminder.** Start a fight with Cheetah or Pack still up, and an icon with your combat aspect appears the moment combat starts: one click puts it up. An optional sound warns you too.
- **Ammo for any bow, gun, or crossbow** (Hunters, Warriors, and Rogues): your arrows or bullets and how many are left, also in combat. Running low, the count and border turn red and pulse; with none equipped, it tells you to equip the ones in your bags.
- **Two buff bars**, My buffs and Group buffs, that show only what is missing. Click to cast; the empty part of a bar lets clicks through to the world.
- Reminders hide on flight paths, and every icon shows the exact spell a click casts.

### Which buffs
- **Druid:** Mark of the Wild (also for your group) and Thorns, on your tank.
- **Hunter:** Aspect, plus the combat aspect reminder.
- **Mage:** Arcane Intellect (also for group members who use mana) and your armor (Frost, Ice, or Mage Armor).
- **Priest:** Power Word: Fortitude (also for your group) and Inner Fire; Divine Spirit and Shadow Protection as options.
- **Warlock:** Demon Armor (Demon Skin counts).
- **Paladin:** Righteous Fury, and a seal timer: while a seal is up, its time left counts down, also in combat; in combat with no seal, your last seal pulses and a click casts it.

Every rank counts, and only buffs you know show. Warriors, Rogues, and Shamans have no buff reminders yet (ammo works for anyone with a bow, gun, or crossbow).

### Click to cast
- A click buffs you first, then the next group member in range who lacks it. The icon shows how many lack it, and its tooltip who.
- With two or more missing, it casts the group version (Arcane Brilliance, Gift of the Wild, Prayer of Fortitude, Prayer of Spirit, Prayer of Shadow Protection) if you know it and carry its reagent.
- Your armor and your aspect recast the one you used last.
- Druids in a form: a click leaves the form, then casts the buff.

### Before it runs out
The icon shows 5 seconds before a buff on you or your group runs out (you choose the seconds), so you can recast it in time.

### In combat, and after
The game does not let AddOns read buffs in combat, so the buff bars hide when a fight starts and come back after; a buff that runs out in a fight shows then. These keep working in combat: the Paladin seal timer, the Hunter combat aspect icon (set up before the fight), the ammo count, the cooldown chimes, and the proc sounds.

### Cooldown chimes
A sound just before your chosen spells are ready again, also in combat, for every class. Every rank of a spell counts, unlike the Cooldown Manager on Forever. Each spell has its own switch and sound (Text to Speech can say "Blink ready"), and you choose how early it chimes. The sounds come from **Dyre's Sounds**, which installs with it.

### Proc sounds
A sound the moment a proc appears on you, also in combat: Nightfall, Clearcasting, Nature's Grace, and Flurry. Each has its own switch and sound.

### Put them where you like
Unlock with `/dbr unlock` to drag the buff bars, the ammo bar, and the seal timer; they snap to your other Dyre's frames and to a grid. Each has its own size and opacity. `/dbr reset` puts them back. Moving and sizing come from **Dyre's Toolkit**, which installs with it. Settings are saved per character.

### Commands
- `/dbr` opens the settings: Reminders, Consumables, Size and Opacity, Chimes, and Procs.
- `/dbr unlock`, `/dbr lock`, `/dbr reset`, `/dbr debug`.
- `/buffreminders` works the same, in case another AddOn uses `/dbr`.

### Compatibility
For the Forever beta client 1.60.1. If a client update removes an API it needs, it says so in chat and stays off.

WowUp users (2.24.0 or later): install from the repository URL; GitHub releases carry the Forever metadata WowUp needs.

Source, issues, and license (MIT): https://github.com/jbedworth/DyresBuffReminders
```
