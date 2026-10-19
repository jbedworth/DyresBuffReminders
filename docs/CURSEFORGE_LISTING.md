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
| Relations | Dyre's Sounds, required dependency (slug `dyres-sounds`), for the cooldown chimes' sounds. CI uploads set it; add it by hand on any file uploaded through the website. |
| Screenshots | artwork/screenshots/ (none taken yet; see artwork/README.md) |
| Source | https://github.com/jbedworth/DyresBuffReminders |
| Issues | https://github.com/jbedworth/DyresBuffReminders/issues |

## Summary

A pulsing icon for each class buff missing on you or your group, and a chime just before your cooldowns are ready, in World of Warcraft: Forever.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
**Dyre's Buff Reminders** shows an icon with a pulsing gold border for each of your class buffs that is missing or about to run out, out of combat. Click the icon to cast the buff. Made for World of Warcraft: Forever.

Want reminders you can put anywhere, that still snap neatly into line, and that stay light and flexible? This is for you!

### Which buffs
- **Mage:** Arcane Intellect (also for group members who use mana), your armor (Frost, Ice, or Mage Armor), and Dampen or Amplify Magic (off at first).
- **Warlock:** Demon Armor (Demon Skin counts).
- **Druid:** Mark of the Wild (also for your group) and Thorns.
- **Priest:** Power Word: Fortitude (also for your group) and Inner Fire; Divine Spirit and Shadow Protection as options.
- **Paladin:** Righteous Fury, and a seal timer: while a seal is up, its time left counts down, also in combat; in combat with no seal, your last seal pulses and a click casts it.

Every rank counts, and only buffs you know show. Other classes are not covered yet.

### Click to cast
- A click buffs you first, then the next group member in range who lacks it. The icon shows how many lack it, and its tooltip who.
- With two or more missing, it casts the group version (Arcane Brilliance, Gift of the Wild, Prayer of Fortitude, Prayer of Spirit, Prayer of Shadow Protection) if you know it and carry its reagent.
- Your armor icon recasts the armor you used last.
- Druids in Bear or Cat Form: a click leaves the form, then casts the buff.

### Before it runs out
The icon shows 5 seconds before a buff on you or your group runs out (you choose the seconds), so you can recast it in time.

### Out of combat only
The game does not let AddOns read buffs in combat, so the icons hide when a fight starts and come back after. The Paladin seal timer is the exception: the game itself draws the seal, so it keeps counting in combat.

### Cooldown chimes
A sound just before your chosen spells are ready again, also in combat, for every class. Every rank of a spell counts, unlike the Cooldown Manager on Forever. Each spell has its own switch and sound (Text to Speech can say "Blink ready"), and you choose how early it chimes. The sounds come from **Dyre's Sounds**, which installs with it.

### Move them where you like
Unlock to drag each icon and scroll to resize it. Icons snap beside each other, and a grid helps you line them up. `/dbr reset` puts them back. Settings are saved per character.

### Commands
- `/dbr` opens the settings: the buff reminders, then the cooldown chimes.
- `/dbr unlock`, `/dbr lock`, `/dbr reset`, `/dbr debug`.
- `/buffreminders` works the same, in case another AddOn uses `/dbr`.

### Compatibility
Beta, for the Forever beta client 1.60.1. If a client update removes an API it needs, it says so in chat and stays off.

WowUp users (2.24.0 or later): install from the repository URL; GitHub releases carry the Forever metadata WowUp needs.

Source, issues, and license (MIT): https://github.com/jbedworth/DyresBuffReminders
```
