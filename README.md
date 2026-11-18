# Tales of a Mercenary

An 80s action-hero survivors-like made in **Godot 4.3**, with SNES-style pixel art.
Miami, 1986. You're a mullet-and-headband mercenary with nothing but a 9mm pistol.
Survive 15 minutes against punks, ninjas, bikers, robots and the Kingpin himself.

**Play in the browser:** https://mongoosebo.github.io/Tales-of-a-Mercenary/

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | WASD / arrow keys | Left stick / D-pad | Drag anywhere |
| Pick upgrade | Up/Down + Enter, or 1-3, or click | D-pad + A | Tap a card |
| Pause | Esc / P | Start | |
| Mute | M | | |

Weapons fire by themselves. Collect the gems enemies drop to level up and choose
new weapons or upgrades.

## What's in it

- **7 weapons:** 9mm pistol, Uzi, shotgun, grenades, boombox (sound-wave aura),
  nunchucks (orbiting), bazooka (homing rockets). Each goes up to level 6.
- **9 passive items:** Aerobics Tape (speed), Pumping Iron (damage), Kevlar Vest (armor),
  Jolt Cola (cooldown), Hairspray (area), Walkman (XP), Magnet Belt (pickup range),
  Beef Jerky (max HP + regen), Lucky Headband (+projectiles).
- **Enemies:** punks, ninjas, bikers, robots; "surrounded" ring events, ninja swarms,
  and a Kingpin boss at 5:00, 10:00 and 14:00 who drops a briefcase (free level-up).
- Pickups: pizza (heal), magnet (pulls in every gem).
- Synthwave chiptune soundtrack and sound effects.

## How it's built

There are no binary art assets: every sprite, icon and the pixel font are text grids
in [`src/art.gd`](src/art.gd), turned into textures at startup. Edit a grid to change a
sprite. Music and sounds are synthesized by [`tools/make_audio.py`](tools/make_audio.py)
(`python3 tools/make_audio.py` regenerates `audio/`).

| File | What it does |
| --- | --- |
| `src/game.gd` | Main loop: player, enemies, weapons, pickups, level-ups, drawing |
| `src/data.gd` | Balance data: weapon stats per level, passives, enemy stats |
| `src/hud.gd` | Title screen, HUD, level-up cards, pause and game-over screens |
| `src/art.gd` | Palette, sprites, icons, 5x7 pixel font |
| `src/sfx.gd` | Sound effect pool and music |

The game renders at 320x180 and scales up with nearest-neighbour filtering.

## Building without installing Godot

Every push to `main` runs [`.github/workflows/build.yml`](.github/workflows/build.yml), which:

1. runs a 3-minute automated play-through as a smoke test,
2. exports Web, Windows and Linux builds,
3. publishes the Web build to GitHub Pages.

Windows and Linux builds can be downloaded from the **Artifacts** section of each run
on the Actions tab.

**One-time setup:** in the repo go to *Settings → Pages* and set *Source* to
**GitHub Actions**.

## Running locally (if you do have Godot 4.3)

Open the folder in Godot and press F5. A headless test run:

```
godot --headless --fixed-fps 60 -- --autotest=180 --god
```
