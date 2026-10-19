# Changelog

Player-facing changes for each Dyre's Buff Reminders release, newest first.
The release builder copies the section for the TOC version into the GitHub
release notes and the CurseForge changelog, and fails if that section is
missing.

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
