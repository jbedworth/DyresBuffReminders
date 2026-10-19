# Changelog

Player-facing changes for each Dyre's Buff Reminders release, newest first.
The release builder copies the section for the TOC version into the GitHub
release notes and the CurseForge changelog, and fails if that section is
missing.

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
