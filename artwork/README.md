# Dyre's Buff Reminders artwork

Publishing images for project pages and distribution listings (CurseForge
screenshots and the like). Keep this directory out of the runtime release
ZIP; the TOC uses a built-in client icon (Spell_Holy_WordFortitude).

## Logo

Original vector artwork: a gold-framed hourglass tilted 30 degrees, its last
glowing sand slipping through the neck (a buff running out), on a blue buff
icon whose glowing gold border pulses outward in fading rings, as the
reminders do in game, on a rich dark-brown background.
It shares its frame and colors with the Mage Tools Forever, Warlock Tools
Forever, Weapon Sets Forever, Weapon Skills Forever, Dyre's Shields Up, and
Dyre's Quest Targeting logos. The design has no font or external-image
dependencies.

- `dyres-buff-reminders-logo.svg`: editable, resolution-independent source.
- `dyres-buff-reminders-logo.png`: 1024 x 1024 PNG master.
- `dyres-buff-reminders-logo-512.png`: 512 x 512 PNG for square project
  images.

The PNGs are rendered from the SVG with headless Chrome, for example:

```sh
chrome --headless=new --hide-scrollbars --window-size=1024,1024 --force-device-scale-factor=0.5 --screenshot=dyres-buff-reminders-logo-512.png dyres-buff-reminders-logo.svg
```

## Screenshots

In-game captures by the author, saved in `screenshots/`. Taken:

| File | Shows |
| --- | --- |
| forever-hunter-aspect-reminder-no-aspect.webp | Forever, level 9 Hunter, out of combat, no aspect: the Aspect reminder (Monkey, red outline) behind the player, and the Aspect bar (one Monkey button, no border) at the bottom; the ammo count beside the player frame (1.8.0) |
| forever-hunter-aspect-bar-monkey-up.webp | The same, Monkey up: no reminder, and the bar's Monkey button with the gold border (1.8.0) |
| forever-hunter-aspect-reminder-combat.webp | In combat with a Strigid Owl and no aspect: the reminder with its red outline; Dyre's Debuff Tracker's Serpent Sting row shows top left (1.8.0) |

Raw screenshots: never change or overwrite them; crop copies for listings.
Still suggested:

- `screenshots/reminders.png`: a row of reminder icons pulsing, with a group
  count and the tooltip naming who lacks the buff.
- `screenshots/seal-timer.png`: a Paladin's seal timer counting down.
- `screenshots/unlocked.png`: the icons unlocked over the grid.
- `screenshots/settings.png`: the settings page.

List each screenshot here once it is added. Retake a screenshot when the
feature it shows changes visibly.

This artwork is covered by the repository's MIT License. Copyright (c) 2026
John Bedworth. Include the applicable license notice with distributed copies.
