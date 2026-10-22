# Class coverage spec

What each class maintains or watches in WoW: Forever, what Dyre's Buff
Reminders covers today, and what to build next. This is a planning spec for
whoever builds the next features; it is not a promise to players. Keep it in
step with Buffs.lua, ProcSpells.lua, ChimeSpells.lua, Consumables.lua, and
the in-client results in TESTING.md.

## Sources and how sure we are

- **Classic 1.12** is the base: spell names, ranks, and reagents. Classic
  IDs are a starting point only; Forever renumbers some spells (Seal of Fury,
  found in client).
- **Blizzard's WoW Forever Beta Development Notes** (official forum thread
  https://us.forums.blizzard.com/en/wow/t/2360696, Sept 24 and Oct 1 read
  directly; Oct 8 and Oct 15/16 read as a summary). Marked **[B]**.
- **Fan summaries** (https://wowforeverguides.com/classes/changes and
  https://lfcarry.com/guides/wow-forever-class-changes, both mid-October).
  Marked **[fan]**: plausible, unconfirmed.
- **In client** (John's tests and `/dbr probe`). Marked **[client]**. This is
  the only proof that counts for IDs and combat behavior.
- Forever is still in beta: anything here can change with a patch.

## What DBR can watch, and when

| Kind | How DBR does it | In combat? |
|---|---|---|
| Buff reminder (missing or running out) | reads auras, secure click-to-cast icon | **No**: auras are unreadable and secure frames are locked in combat; the bars hide and come back after |
| Pre-armed combat icon (Hunter combat aspect) | set up out of combat, shown by a state driver | **Yes**, shows; cannot change in combat |
| Proc sound (a buff appears on you) | the game plays it (`C_UnitAuras.AddAuraSound`) | **Yes** |
| Reactive sound (ability becomes usable) | `C_Spell.IsSpellUsable` on `SPELL_UPDATE_USABLE` | **Yes** [client: Revenge] |
| Cooldown chime | DBR's own timer from your cast | **Yes** (timed from the cast; the real cooldown is secret) |
| Seal-style timer (game-drawn aura) | Blizzard's AuraContainer | **Yes** |
| Consumable count | item counts on bag events | **Yes**, while the count is not secret |
| Weapon enchant (poisons, imbues) | `GetWeaponEnchantInfo`, legacy global | **Out of combat only** (not in the generated docs; to probe) |

Out of reach for any AddOn on Forever: buffs on other players in combat,
the real cooldown in combat, and anything needing `COMBAT_LOG_EVENT_UNFILTERED`
(refused by the client).

## Summary: coverage today

| Class | Buff reminders | Procs / reactive | Chimes | Consumables | Overall |
|---|---|---|---|---|---|
| Mage | Arcane Intellect, Armor | Clearcasting | 15 spells | ammo n/a | **Good** |
| Warlock | Demon Armor | Nightfall | 10 spells | none yet | **Good** (no shards yet) |
| Druid | Mark of the Wild, Thorns (tank) | Clearcasting, Nature's Grace | 10 spells | none yet | **Good**, gaps below |
| Hunter | Aspect, combat aspect | none | 10 spells | Ammo | **Partial** |
| Paladin | Righteous Fury, seal timer | none | 10 spells | none | **Partial** |
| Warrior | Battle Shout (1.2.0) | Flurry, Overpower, Revenge (1.2.0) | 12 spells | Ammo (gun/bow) | **Partial** |
| Priest | Fortitude, Inner Fire, Divine Spirit, Shadow Protection | none | 8 spells | none | **Partial** |
| Rogue | none | none | 11 spells | Ammo (gun/bow) | **Thin** |
| Shaman | none | Clearcasting | 10 spells | none | **Thin** |

## Per class

Columns: **Have** (in DBR now), **Proposed** (what to add), **Notes** (Forever
changes and limits). Priority: **P1** next release, **P2** soon, **P3** later.

### Warrior

| Kind | Have | Proposed | Notes |
|---|---|---|---|
| Self/group buff | Battle Shout (Group buffs, 60 s lead) | — | Battle Shout is raid-wide on Forever [B, Oct 16]; needs rage, so it shows out of combat when you have none (author: keep it). Improved Battle Shout baseline [fan]. |
| Stance | — | **P3** "wrong stance" hint is not a buff; skip | Stances are not auras; out of scope. |
| Proc | Flurry (off) | **P2** Enrage (talent) sound | Bear/Warrior crit rage +100% on Forever [fan]; Bloodthrill changed [B]. |
| Reactive | Overpower, Revenge (1.2.0) | **P1** Execute (target below 20%) sound | Execute in probe list already; Overpower works vs much lower-level enemies on Forever [B-sum]. Revenge confirmed readable in combat [client]. |
| Cooldown chimes | 12 | **P3** Sweeping Strikes, Shield Block, Slam (18 s on Forever [B]) | Slam no longer pushed back [B-sum]. |
| Consumable | Ammo (gun/bow/crossbow) | — | Thrown takes no ammo [client]. |

### Paladin

| Kind | Have | Proposed | Notes |
|---|---|---|---|
| Self buff | Righteous Fury | — | Holy threat 90% again [fan, Oct 15]. |
| Seal | Seal timer, all seals incl. Seal of Fury | — | Seal of Fury is Forever-only [client]; not overwritten by Power Word: Shield [fan]. |
| Aura | — | **P1** Aura reminder (Devotion, Retribution, Concentration, Shadow/Frost/Fire Resistance): missing out of combat; recast the last | Retribution Aura scales with spell power [B]. Auras are self buffs on the Paladin. |
| Blessings | — (author: PallyPower; situational) | **P3** group-assign button (later feature, author) | Salvation becomes "Salvation"/"Mass Salvation", not exclusive with other blessings; "Revoke" added [fan]. Blessing of Kings baseline [fan]. |
| Proc | — | **P2** Vengeance (crit buff) sound | Vengeance caps at 3 stacks on non-periodic crits [B]. |
| Reactive | — | **P2** Hammer of Wrath (target below 20%) sound | — |
| Cooldown chimes | 10 | **P2** Holy Strike (10 s base on Forever [B]), Judgement | Holy Strike's 10 s cooldown is baseline [B]. |
| Consumable | — | **P3** Symbol of Divinity (Divine Intervention), Symbol of Kings | — |

### Hunter

| Kind | Have | Proposed | Notes |
|---|---|---|---|
| Self buff | Aspect (recasts last combat aspect, "!") | — | — |
| Combat icon | Combat aspect (Cheetah/Pack up when combat starts) | — | — |
| Group buff | — | **P1** Trueshot Aura reminder (Group buffs; it is raid-wide on Forever) | Trueshot Aura raid-wide [B-sum, Oct 16]. |
| Pet | — | **P2** "Pet missing / pet unhappy" reminder: out of combat; Call Pet / Revive Pet click | Pet happiness API to probe. |
| Proc | — | **P3** Quick Shots (Improved Aspect of the Hawk) sound | — |
| Reactive | — (probe only) | **P2** Mongoose Bite, Counterattack sounds | Same mechanism as Revenge; confirm with `/dbr probe`. |
| Cooldown chimes | 10 | — | Aimed Shot no longer shares a cooldown with Arcane Shot [fan]. |
| Consumable | Ammo | **P2** Pet food count (by pet diet) | Auto Shot needs 0.5 s standing still [B-sum]. Ammo bug fixed [B]. |

### Druid

| Kind | Have | Proposed | Notes |
|---|---|---|---|
| Group buff | Mark of the Wild (Gift of the Wild) | — | Improved Mark of the Wild baseline [fan]. |
| Group buff | Thorns (follows the tank) | — | Thorns scales with spell power and reverts when the caster is far [B]. |
| Aura | — | **P3** Leader of the Pack / Moonkin Aura: form auras, raid-wide on Forever [B-sum]; they come with the form, so no reminder | — |
| Proc | Clearcasting (off), Nature's Grace (on) | — | Omen of Clarity procs less from low ranks [fan]. Omen baseline at 20 [fan]. |
| Self buff | — | **P2** Omen of Clarity (the buff itself, 10 min) reminder | Omen of Clarity is a castable self buff in Classic. |
| Cooldown chimes | 10 | **P2** Shifting Power (new, Cat Form, 16 s [B]) | Tiger's Fury removed [B] (not in DBR's list); Mangle renamed Primal Bite [B]. |
| Consumable | — | **P3** Rebirth seeds (Maple/Stranglethorn/Ashwood/Hornbeam/Ironwood), Wild Berries / Wild Thornroot for Gift | — |

### Priest

| Kind | Have | Proposed | Notes |
|---|---|---|---|
| Group buff | Fortitude, Divine Spirit (option), Shadow Protection (option) | — | Divine Spirit baseline at 30 [fan]: make it on by default once confirmed. |
| Self buff | Inner Fire | **P2** Shadowform reminder (Shadow spec: out of combat, recast) | Shadowform is a self aura. |
| Self buff | — | **P3** Fear Ward (now baseline [fan]): on yourself only, situational | — |
| Proc | — | **P2** Inner Focus / Surge-type procs as sounds; Spirit Tap | Dark Inspiration is new (party Spirit) [fan]. |
| Reactive | — | **P3** Shadow Word: Death (cooldown 18 s on Forever [B-sum]) chime | — |
| Cooldown chimes | 8 | **P2** Devouring Plague (24 s on Forever [B-sum]), Vampiric Embrace (30 s [fan]) | — |
| Consumable | — | **P3** Holy/Sacred Candles count (Prayer of Fortitude) | Already read for the group cast. |

### Mage

| Kind | Have | Proposed | Notes |
|---|---|---|---|
| Group buff | Arcane Intellect (Brilliance) | — | — |
| Self buff | Armor (Frost/Ice/Mage) | — | — |
| Situational | — (author: Dampen/Amplify left out) | — | — |
| Proc | Clearcasting (off) | **P2** "Heating Up" (renamed Hot Streak, 20 s on Forever [B]) sound | Arcane Blast stacking buff [fan]: probe. |
| Cooldown chimes | 15 | **P3** Frost Blast (new, level 24 [fan/B-sum]), Frostfire Bolt (new [fan]) only if they have cooldowns | Combustion has 3 charges [B]. |
| Consumable | — (MTF handles conjured items, author) | — | Mana gem in MTF. |

### Warlock

| Kind | Have | Proposed | Notes |
|---|---|---|---|
| Self buff | Demon Armor / Demon Skin | **P2** Soul Link / Demonic Sacrifice buff (talented) | — |
| Pet | — | **P2** "No demon summoned" reminder, out of combat | — |
| Proc | Nightfall (off) | **P3** Soul Harvest (renamed, mana regen [B]) if it is a buff | — |
| Cooldown chimes | 10 | — | Curse of Agony and Curse of Doom become "Banes", one per Warlock per target [fan]; Doom chime name may change. |
| Consumable | — | **P1** Soul Shard count and warn-at (Class Consumables, John-approved design: DBR shows, WTF deletes) | No shard change found on Forever. Firestone/Spellstone become weapon imbues [fan]: probe. Healthstone/Soulstone stay in WTF (author). |

### Rogue

| Kind | Have | Proposed | Notes |
|---|---|---|---|
| Weapon buff | — | **P1** Poisons on each weapon: reminder out of combat, click applies your last-used poison | Poisons get more charges on Forever [fan]. `GetWeaponEnchantInfo` (legacy global) to probe; out of combat only. CM cannot track poisons [B]. |
| Self buff | — | **P3** Slice and Dice is a combat finisher: not a reminder | — |
| Reactive | — (probe only) | **P2** Riposte (after a parry) sound | Same mechanism as Revenge. |
| Proc | — | **P3** Remorseless Attacks, Relentless Strikes | — |
| Cooldown chimes | 11 | — | Setup now only on the dodging/resisting target [B]. |
| Consumable | Ammo (bow/gun/crossbow) | **P2** Flash Powder (Vanish), Blinding Powder (Blind) counts | Rogues can use 1-handed axes [fan]. |

### Shaman

| Kind | Have | Proposed | Notes |
|---|---|---|---|
| Self buff | — | **P1** Lightning Shield / Water Shield reminder (self, out of combat, recast) | Water Shield exists on Forever and triggers from any critical Shaman spell [fan]: confirm the name and ID. |
| Weapon buff | — | **P1** Weapon imbue (Rockbiter/Flametongue/Frostbrand/Windfury Weapon) reminder, out of combat | Imbues last 60 min on Forever [fan]. Same API as Rogue poisons. |
| Totems | — | **P3** totems are placed in combat and not auras on you; a reminder is not possible in combat | Several totems raid-wide [B-sum]; totem stacking closed [B]. |
| Proc | Clearcasting (off) | **P2** Elemental Mastery as chime (exists); Stormstrike buff | — |
| Cooldown chimes | 10 | **P2** Lava Burst (moved to row 5, 4 ranks [fan]) if it has a cooldown | Chain Lightning: no cooldown change confirmed. |
| Consumable | — | **P2** Ankh (Reincarnation) count; totems in bags (Earth/Fire/Water/Air) | — |

## Priorities for the next releases

1. **P1, self-contained, same patterns as today:** Paladin aura reminder;
   Hunter Trueshot Aura; Shaman Lightning/Water Shield; Warrior Execute
   sound; Warlock Soul Shard count (Consumables bar).
2. **P1, needs a probe first:** weapon enchants for Rogue poisons and
   Shaman imbues (`GetWeaponEnchantInfo`: exists? secret? item IDs?), shown
   out of combat only.
3. **P2:** reactive sounds for Riposte, Mongoose Bite, Counterattack, Hammer
   of Wrath; pet missing reminders (Hunter, Warlock); Priest Shadowform;
   Druid Omen of Clarity; Paladin Vengeance and Mage Heating Up proc sounds;
   Rogue powders and Shaman Ankh counts; chime list updates (Shifting Power,
   Holy Strike, Devouring Plague).
4. **P3:** class reagent counts for candles, seeds, symbols; Paladin and
   Priest situational buffs; any group-assign feature (author: later).

## Verify in client before shipping each item

- Every spell and buff ID through `/dbr debug` (`unknownIDs=none`), since
  Forever renumbers some spells.
- New Forever names: Primal Bite, Blood Frenzy, Shifting Power, Heating Up,
  Soul Harvest, Banes, Salvation / Mass Salvation, Frost Blast, Frostfire
  Bolt, Water Shield.
- Reactive spells with `/dbr probe on`, one class at a time (Riposte,
  Mongoose Bite, Counterattack, Execute, Hammer of Wrath): readable in
  combat, not secret.
- Weapon enchants with a new probe line before any poison or imbue reminder.
