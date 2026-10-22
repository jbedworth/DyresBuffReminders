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

Missing buffs, one click to cast, also in combat. Thorns that follows your tank, Hunter aspect reminders, an ammo count, a seal timer, cooldown chimes, and proc sounds, for World of Warcraft: Forever.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
**Dyre's Buff Reminders** shows the class buffs you are missing, each in its own icon, and casts them with one click. It also tracks your ammo, times your seal, chimes before your cooldowns are ready, and sounds your procs. Made for World of Warcraft: Forever.

### What's new in 1.3.0
- **Mage: Dampen or Amplify Magic** (off at first) and an **Arcane Powder** count for Arcane Brilliance.
- **Warlock: Infernal Stone and Demonic Figurine** counts for Inferno and Ritual of Doom.
- **From Mage Tools Forever or Warlock Tools Forever:** DBR copies your reminder settings on its first run.

### What's new in 1.2.0
- **Buff warnings in combat.** Each buff is now its own icon, always shown, in a place you choose that never moves. If a buff on you expires or is dispelled, even mid-fight, the reminder shows at once with a red border and a click recasts it.
- **Thorns on your tank, in the fight too.** While the tank has Thorns, its icon shows the tank's time left, then turns yellow before it runs out and red when it does, also in combat. Whom a click casts on is set before the fight: the tank, or you when solo or tanking.
- **Druid: Rebirth seeds.** How many seeds you carry for your highest rank of Rebirth, red when you are down to 2 (you choose), also in combat. Gift of the Wild's reagents count the same way once you know it.
- **Ammo only where it applies.** Only Hunters, Warriors, and Rogues see the ammo count and its settings.
- **Warnings that fit the buff.** The border turns yellow and flashes a share of each buff's own length before it runs out (10% at first: 3 minutes before a 30-minute buff ends), also in combat; red means missing.
- **Warrior: Battle Shout, Overpower, and Revenge.** A Battle Shout reminder, and a sound the moment Overpower or Revenge becomes usable, also in combat.

### What's new in 1.1.0
- **Druid: Thorns follows your tank.** In a party or raid with a member set to the Tank role, Thorns watches that tank, and a click casts it on them. Solo, with no tank, as the tank yourself, or when the tank is dead, offline, or out of range, it watches you, and a click casts it on you. It switches back to you as soon as the tank's party frame greys out. The tooltip always says whom it watches.
- **Hunter: Aspect reminder.** No aspect up? A click recasts the last combat aspect you used (Hawk, Monkey, Wild, or Beast), never Cheetah or Pack, and it never takes down an aspect that is already up.
- **Hunter: combat aspect reminder.** Start a fight with Cheetah or Pack still up, and an icon with your combat aspect appears the moment combat starts: one click puts it up. An optional sound warns you too.
- **Ammo for any bow, gun, or crossbow** (Hunters, Warriors, and Rogues): your arrows or bullets and how many are left, also in combat. Running low, the count and border turn red and pulse; with none equipped, it tells you to equip the ones in your bags.
- Reminders hide on flight paths, and every icon shows the exact spell a click casts.

### Which buffs
- **Druid:** Mark of the Wild (also for your group) and Thorns, on your tank.
- **Hunter:** Aspect, plus the combat aspect reminder.
- **Mage:** Arcane Intellect (also for group members who use mana) and your armor (Frost, Ice, or Mage Armor).
- **Priest:** Power Word: Fortitude (also for your group) and Inner Fire; Divine Spirit and Shadow Protection as options.
- **Warlock:** Demon Armor (Demon Skin counts).
- **Warrior:** Battle Shout, a full minute before it runs out (you choose the seconds); it needs rage, so cast it while you still have some after a fight.
- **Paladin:** Righteous Fury, and a seal timer: while a seal is up, its time left counts down, also in combat; in combat with no seal, your last seal pulses and a click casts it.

Every rank counts, and only buffs you know show. Rogues and Shamans have no buff reminders yet (ammo works for Hunters, Warriors, and Rogues with a bow, gun, or crossbow).

### Click to cast
- A click buffs you first, then the next group member in range who lacks it. The icon shows how many lack it, and its tooltip who.
- With two or more missing, it casts the group version (Arcane Brilliance, Gift of the Wild, Prayer of Fortitude, Prayer of Spirit, Prayer of Shadow Protection) if you know it and carry its reagent.
- Your armor and your aspect recast the one you used last.
- Druids in a form: a click leaves the form, then casts the buff.

### Before it runs out
The border turns yellow and flashes before a buff on you or your group runs out, so you can recast it in time. You choose how early, as a share of the buff's own length (0-20%, 10% at first), so a long buff warns minutes ahead and a short one seconds ahead. It works in combat too, and your own recast resets it.

### In combat, and after
The game does not let AddOns read buffs in combat, so in a fight the game itself draws each buff on you in its place; if one expires or is dispelled, it disappears and DBR's reminder, with its red border, shows through at once, and a click recasts it on you. Your group's buffs, and Thorns on the tank, are checked again after the fight.

### Cooldown chimes
A sound just before your chosen spells are ready again, also in combat, for every class. Every rank of a spell counts, unlike the Cooldown Manager on Forever. Each spell has its own switch and sound (Text to Speech can say "Blink ready"), and you choose how early it chimes. The sounds come from **Dyre's Sounds**, which installs with it.

### Proc sounds
A sound the moment a proc appears on you, also in combat: Nightfall, Clearcasting, Nature's Grace, and Flurry, plus a Warrior's Overpower and Revenge the moment they become usable. Each has its own switch and sound.

### Put them where you like
Unlock with `/dbr unlock` to drag each buff icon, the ammo bar, and the seal timer; they snap to your other Dyre's frames and to a grid. The buff icons share one size and opacity; the Consumables bar (under Consumables) and the seal timer have their own. `/dbr reset` puts them back. Moving and sizing come from **Dyre's Toolkit**, which installs with it. Settings are saved per character.

### Commands
- `/dbr` opens the settings: Reminders, Consumables, Chimes, and Proc Chimes.
- `/dbr unlock`, `/dbr lock`, `/dbr reset`, `/dbr debug`.
- `/buffreminders` works the same, in case another AddOn uses `/dbr`.

### Compatibility
For the Forever beta client 1.60.1. If a client update removes an API it needs, it says so in chat and stays off.

WowUp users (2.24.0 or later): install from the repository URL; GitHub releases carry the Forever metadata WowUp needs.

Source, issues, and license (MIT): https://github.com/jbedworth/DyresBuffReminders
```
