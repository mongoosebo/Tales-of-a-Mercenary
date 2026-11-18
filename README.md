# Tales of a Mercenary

An 80s action-hero survivors-like made in **Godot 4.3**, with SNES-style pixel art.
Miami, 1986. You wake up on a beach next to your wrecked speedboat, with nothing but
a 9mm pistol. Fight your way along the shore to the pier, take down Don Flamingo,
then head north into Main Street.

## Levels

1. **The Beach** - an endless strip of sand between the dunes and the ocean; you can only
   go sideways. Survive 20:00 and a pier appears with **Don Flamingo** on it: a coked-up
   boss in a pink suit and wraparound shades who sweeps a minigun across the screen
   (watch for the "!" wind-up and dodge-roll through the bullets). Beat him and follow
   the arrow north from the pier.
2. **Main Street** - the open city. Survive 15:00 against the Kingpin's crew.

Your weapons, items and level carry over between levels.

**Play in the browser:** https://mongoosebo.github.io/Tales-of-a-Mercenary/

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | WASD / arrow keys | Left stick / D-pad | Drag anywhere |
| Dodge roll (invincible) | Shift / Space / K / X | B / RB | ROLL button, bottom-right |
| Pick upgrade | Up/Down + Enter, or 1-3, or click | D-pad + A | Tap a card |
| Pause | Esc / P | Start | |
| Mute | M | | |

Weapons fire by themselves. Collect the gems enemies drop to level up and choose
new weapons or upgrades.

## What's in it

- **10 weapons:** 9mm pistol, Uzi, shotgun, grenades, boombox (sound-wave aura),
  nunchucks (orbiting), bazooka (homing rockets), AK-47 (bursts), crossbow (piercing bolts)
  and the yellow dildo mace (melee swing). Each goes up to level 6; you can carry 6.
- **Supercharge powerup:** a glittering white pile shows up every so often. Grab it for
  20 seconds of a high-RPM M-16 with an under-barrel grenade launcher (every 2 s),
  extra speed and a faster soundtrack.
- **9 passive items:** Aerobics Tape (speed), Pumping Iron (damage), Kevlar Vest (armor),
  Jolt Cola (cooldown), Hairspray (area), Walkman (XP), Magnet Belt (pickup range),
  Beef Jerky (max HP + regen), Lucky Headband (+projectiles).
- **Enemies:** punks, ninjas, bikers, robots; "surrounded" ring events, ninja swarms,
  and a Kingpin boss at 5:00, 10:00 and 14:00 who drops a briefcase (free level-up).
- Pickups: pizza (heal), magnet (pulls in every gem), briefcase (free level-up).
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

Handy test flags (after `--`): `--time=1190` starts the beach at 19:50 (just before the
boss), `--level=2` starts on Main Street, `--super` keeps you supercharged,
`--don-hp=100` makes the boss weak.
