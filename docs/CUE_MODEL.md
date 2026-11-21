# The cue model

John, 2026-11-20: "I'm just trying to generalize what we do so there are
patterns we can use as we expand to more classes and abilities." DBR is the
home of every buff and proc cue, arcs and sounds alike: "a better fit for
all buffs/procs (procs are really short-term triggered buffs) chimes and
visuals (can be an arc or widget, depending on our design for each buff)".
Dyre's Shields Up keeps only the absorb-shield display.

This model guides new work and the proc move from DSU (1.13.0). Existing
code is not refactored to fit it; a feature moves to the shared shape only
when it is changed for another reason.

## Entries, triggers, and cues

Every entry is one trigger with a list of cues:

```lua
{
    key = "overpower",          -- unique, saved; never reused
    class = "WARRIOR",          -- data, not a gate
    family = "window",          -- one of the families below
    trigger = {usable = 7384},  -- what fires it (family-specific fields)
    requires = {7384},          -- talent or spell IDs; shown only when known
    cues = {
        arc = {on = true},      -- each cue: its own switch and default
        sound = {on = true, sound = "orcfury"},
    },
}
```

- Each cue has its own switch and default, saved per entry and cue.
- Settings rows come from the table, grouped by family, then by class.
- A new class or ability is data only: an entry in the family's table.
- Names come from `C_Spell.GetSpellName(id)` (the client's language), never
  from English text in the table; English is a fallback and a label.

## Families

The rule: an entry may use a trigger only when its family has a mechanism
that works in combat on Forever. Out of combat AddOn code can read auras;
in combat aura reads, cooldowns, and the combat log are refused or secret,
and secure frames cannot be shown, hidden, or changed.

| # | Family | Fires when | In combat on Forever | Cues |
|---|--------|-----------|----------------------|------|
| 1 | Upkeep | A buff, aspect, seal, pet, or weapon enchant should be up but is missing or fading | The engine aura slot (draws the buff while up), plus DBR's own timer from the out-of-combat read and your own casts | Clickable secure icon; yellow when fading; red (or a glow) when missing; optional sound at combat start |
| 2 | Proc | A short buff appears, with stacks | The toolkit engine's AuraContainer arcs; `C_UnitAuras.AddAuraSound` | Arcs; sound. Never clickable |
| 3 | Window | An ability becomes usable | `C_Spell.IsSpellUsable` (readable in combat) | Arcs (dim when short of rage); sound. Never clickable |
| 4 | Ready | A cooldown ends | Timed from your own cast (the real cooldown is secret), corrected out of combat | Sound; a visual "ready" pulse may come later from the same timer |
| 5 | Counter | Stacks or resources change | Power events and your own casts | Rising notes; arcs per stack; a count on an icon |
| 6 | Alert | A wrong state | Checked out of combat, repeated at combat start | Message pop; sound |
| 7 | Feedback | You cast a spell | `UNIT_SPELLCAST_SUCCEEDED` for the player | Confirmation sound |

Notes per family:

- Upkeep: the only family with clickable icons. A secure icon cannot change
  in combat, so it waits under the engine slot, armed, and alpha (allowed in
  combat) does the rest. Never put a script on or in a slot button (found in
  client, 1.12.1). Later: Rogue poisons, Shaman imbues, oils and stones.
- Proc: the engine draws and plays; DBR gives data. Without the engine,
  sound only through `AddAuraSound`.
- Window: later Execute, Riposte, Mongoose Bite, Counterattack.
- Ready: Forever's Cooldown Manager and the action bars already show
  cooldowns, so the cue is a sound first.
- Counter: Winter's Chill reads the combat log, which works only on Classic
  Era (Forever refuses `COMBAT_LOG_EVENT_UNFILTERED`), so it is Era-only.
- Everything outside Upkeep must show and hide at once, also in combat, so
  it is never a secure frame.

## Boundaries

- DBR: you, your group, your abilities (all families above).
- Dyre's Debuff Tracker: your effects on enemies.
- Dyre's Shields Up: absorb-shield display only.
- Dyre's Toolkit: engines (aura slots, proc arcs, owners, layout, profiles).
- Class Tools AddOns (MTF, WTF): class-only tools (shards, portals,
  conjure).

## Current features by family

| Feature (AGENTS.md section) | Family | Notes |
|-----------------------------|--------|-------|
| Buff reminders: Arcane Intellect, Mage armor, Dampen/Amplify, Battle Shout, Demon Armor, Mark of the Wild, Thorns, Fortitude, Inner Fire, Divine Spirit, Shadow Protection, Righteous Fury | Upkeep | Clickable; group versions; running-out and missing borders; "Show only when needed" |
| Pet reminders (Hunter, Warlock) | Upkeep | Click calls or revives (Hunter), summons (Warlock) |
| Aspect reminder (Hunter) | Upkeep | The combat-aspect check inside it is an Alert cue (sound at combat start) |
| Aspect bar (Hunter) | Upkeep | Clickable; gold border on the aspect that is up |
| Seal timer (Paladin) | Upkeep | Clickable; timer bar from your own cast |
| Ammo and reagents | Counter | A count on an icon; red when low; not clickable |
| Cooldown chimes | Ready | Timed from your own cast |
| Procs (1.13.0): Missile Barrage, Fingers of Frost, Nightfall, Decimation, Clearcastings, Nature's Grace, Flurry | Proc | Arcs and sound through the toolkit's proc engine 2; Proc Chimes (sound only) with an older toolkit |
| Procs (1.13.0): Overpower, Revenge | Window | Usable procs in the same engine: arcs and sound |
| Combo point chimes (Rogue, Druid) | Counter | Rising notes |
| Winter's Chill stack chimes (Mage, Era) | Counter | Rising notes; combat log, Era only |
| Righteous Fury when not the tank (`furyOff`) | Alert | Message and sound |
| Pet taunt on (`hunterPetTaunt`, `warlockPetTaunt`) | Alert | Yields to Dyre's Toolkit 2.9.0's warning when present |
| Cast chimes (forms, Dash, Cheetah, Sprint, Charge, shouts) | Feedback | Sound with Text to Speech |
| Reactive-ability probe | none | Debug only, not a cue |

## Adding an entry

1. Pick the family by the trigger, and check that its in-combat mechanism
   covers the case. If none does, the entry is not built.
2. Add data to the family's table: key, class, trigger IDs, requires, cues
   with defaults.
3. Add tests for the trigger in and out of combat, and for each cue's switch.
4. Say in AGENTS.md who asked for it and what was found in client.
