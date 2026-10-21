# Changelog

Player-facing changes for each Dyre's Buff Reminders release, newest first.
The release builder copies the section for the TOC version into the GitHub
release notes and the CurseForge changelog, and fails if that section is
missing.

## 1.1.0

### Features

- Druid: Thorns follows your group's tank. With a member set to the Tank role, it reminds you when the tank lacks Thorns, and a click casts it on them. Solo, with no tank, as the tank yourself, or when the tank is dead, offline, or out of range, it watches you and a click casts it on you; it switches back to you as the tank's party frame greys out. The tooltip says whom it watches.
- Hunter: an Aspect reminder in My buffs. Any aspect counts as up; with none up, a click recasts the last combat aspect you cast (Hawk, Monkey, Wild, or Beast), else Hawk, else Monkey. Cheetah and Pack are never recast, since they daze you when you are hit, and a click never takes down an aspect that is already up.
- Hunter: a combat aspect reminder. Start a fight with Aspect of the Cheetah or the Pack up, and an icon with your combat aspect appears the moment combat starts; one click puts it up and the icon goes away. Cast a combat aspect yourself and the icon dims. It sits on the Aspect slot of My buffs, with an optional sound at combat start (its own switch and sound choice). Turn it off with "Combat aspect reminder" under Aspect in `/dbr`.
- Ammo for any bow, gun, or crossbow, Warriors and Rogues too: a new Consumables bar shows your equipped arrows or bullets and how many are left, also in combat. At or below "Warn at" (200 at first) the count and the icon's border turn red and pulse; out of ammo, or with none equipped, it shows as missing, and its tooltip says to equip the ones in your bags. Turn it off under "Consumables" in `/dbr`.
- Two buff bars: Group buffs, for buffs that can go on another player (Arcane Intellect, Mark of the Wild, Thorns, Fortitude, Divine Spirit, Shadow Protection), and My buffs, for buffs only you can have (armors, aspects, Inner Fire, Righteous Fury). Each shows only the buffs you are missing, side by side from its left edge, and a click on its empty part goes through to the world. Unlocked, a bar shows all of its buffs, those already on dimmed.
- Each bar, the ammo bar, and the Paladin seal timer has its own Size (50-200%) and Opacity, with Reset size, under "Size and Opacity" in `/dbr`.

### Fixes

- No buff reminders show on a flight path, where you cannot cast them; they come back when you land.
- A reminder's icon now always shows the spell a click casts, as its tooltip says: your armor shows the armor you cast last, and a group buff shows Arcane Brilliance, Gift of the Wild, or a Prayer when a click casts it. Before, it showed your highest-ranked spell of the reminder.

### Other changes

- DBR now needs Dyre's Toolkit 2.0 or later, which places, drags, snaps, and sizes its bars for all Dyre's AddOns alike. The CurseForge app installs it with DBR; without it, DBR stays off and says where to get it.
- The seal timer keeps its place and size. The buff icons' own places from 1.0.0 cannot carry over to a bar: the bars start in their default places, once.
- Scrolling over an icon no longer resizes it: use Size in the settings. `/dbr reset` puts the bars back in place; Reset size puts back their size.
- In the settings, the sections are now "Reminders", "Chimes", and "Procs", and each one's on/off switch is "Enable". Your settings stay as they were.
- Dampen and Amplify Magic are no longer reminded: you cast them on chosen members when a fight needs them, as with Paladin Blessings.
- DBR's own grid and "Unlock to move them" switch are gone: the toolkit's grid and "Unlock frames" are the ones for every Dyre's AddOn.

## 1.0.0

The first full release for WoW: Forever, no longer marked beta: it was play tested on the Forever beta client 1.60.1, build 70450. CurseForge now offers it as a release, so the app updates it and installs what it needs for every player.

- The CurseForge app installs Dyre's Toolkit and Dyre's Sounds with it.

## 0.3.1-beta

- Works with Dyre's Toolkit: one layout mode for all Dyre's AddOns (unlocking DBR unlocks them all, and their frames snap to each other and to the toolkit's grid), and DBR's settings sit under "Dyre's AddOns" in Options > AddOns and in the AddOn list. Without the toolkit DBR works as before and says once where to get it (CurseForge).
- With Dyre's Toolkit, DBR's settings page no longer has its own "Unlock to move them" switch: use "Unlock frames" on the Dyre's AddOns page, the minimap button, `/dyre unlock`, or `/dbr unlock`. Without the toolkit the switch stays.

## 0.3.0-beta

- New: proc sounds. A sound the moment a proc appears on you, also in combat: a Warlock's Nightfall (Shadow Trance), Clearcasting for Mages, Druids, and Shamans, a Druid's Nature's Grace, and a Warrior's Flurry. Each has its own switch and sound (only sounds the game can play for a buff); turn them all on or off under "Proc Sounds" in `/dbr`.
- On at first: Nature's Grace. Off at first: Nightfall (as in Warlock Tools Forever), Clearcasting (on a Mage the game already plays a sound for it), and Flurry.
- On a Warlock, your Nightfall sound setting carries over from Warlock Tools Forever. With a Warlock Tools Forever older than 0.3.3-beta that still plays Nightfall, DBR says so once, so you can turn one off or update it.
- DBR checks each proc's spell ID in game the first time the buff is on you out of combat, so a proc Forever changed still sounds.
- A test aid, off by default: `/dbr probe on` says in chat when a Warrior's, Rogue's, or Hunter's reactive abilities (Overpower, Revenge, Execute, Riposte, Mongoose Bite, Counterattack) become usable, for a planned tracker bar. `/dbr probe off` stops it.

## 0.2.0-beta

- New: cooldown chimes, from Dyre's Cooldown Chimes, which is now part of Dyre's Buff Reminders. A sound just before your chosen spells are ready again, also in combat, for every class. Every rank of a spell counts. Each spell has its own switch and sound; turn them all on or off under "Cooldown Chimes" in `/dbr`.
- In the settings, each chime spell takes one row: its switch and its sound side by side (with Dyre's Sounds 0.1.2-beta; with an older Dyre's Sounds the sound sits under the switch).
- The chime sounds come from Dyre's Sounds. Without it, the chimes play nothing and DBR says once to install it; the buff reminders work as usual.
- Your chime settings carry over from Dyre's Cooldown Chimes, or else from Mage Tools Forever or Warlock Tools Forever. While Dyre's Cooldown Chimes is still installed, it plays the chimes and DBR plays none: remove it.

## 0.1.2-beta

- Paladin seal timer: Seal of Fury now counts. Before, a Seal of Fury on you showed no timer, and the "no seal" reminder stayed up in combat.
- Any other seal in your spellbook counts too, and the reminder now shows the seal you cast last, whichever it is.
- The seal reminder has a gold bar under it, where the timer's bar drains, so it no longer looks like the Righteous Fury reminder (the two share a picture).

## 0.1.1-beta

- First release on CurseForge (0.1.0-beta reached GitHub only).
- Buff reminders for Mages, Warlocks, Druids, Priests, and Paladins, on their own: an icon with a pulsing gold border for each of your class buffs you lack, out of combat. Click it to cast the buff.
- The icon also shows 5 seconds before a buff on you or your group runs out, so you can recast it in time. Choose the seconds in the settings (0 waits until it is gone).
- Mage: Arcane Intellect (also for group members who use mana), your armor, and Dampen or Amplify Magic (off at first). Warlock: Demon Armor (Demon Skin counts). Druid: Mark of the Wild (also for your group) and Thorns. Priest: Power Word: Fortitude (also for your group) and Inner Fire, with Divine Spirit and Shadow Protection as options. Paladin: Righteous Fury.
- Druids in a form: a click leaves the form, then casts the buff.
- Paladin seal timer: while a seal is up, its icon counts down its time left, also in combat. In combat with no seal, your last seal pulses; click it to cast it.
- Group buffs show how many lack the buff, and the tooltip says who. A click buffs you first, then the next group member in range; with two or more missing, it casts the group version (Arcane Brilliance, Gift of the Wild, Prayer of Fortitude, and so on) if you know it and carry its reagent.
- Every rank counts, and only buffs you know show. Your armor icon recasts the armor you used last.
- Unlock to drag each icon, scroll to resize it; icons snap beside each other, with a grid to line them up. `/dbr reset` puts them back.
- Settings are saved per character.

## 0.1.0-beta

- First release, on GitHub only; the same as 0.1.1-beta.
