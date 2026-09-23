# Ajyal Al Salihiya — Flutter + Flame Game Showcase

A client-facing demo proving that the BRD's educational mini-game direction can be implemented as real games in Flutter.

The app opens on a **Game Hub** (Arabic, RTL) with a card for each mini-game. Every game runs on the Flame engine inside a shared game page with **Back** and **Restart** buttons.

## Included

1. **Ocean Rescue — أنقذ البحر** 🌊
   - Falling-object arcade loop: catch the trash, avoid the sea animals
   - Press-and-drag boat steering (horizontal only, smooth follow, stays inside the screen)
   - Collision detection with good/bad targets
   - Score, combo, timer

2. **Recycling Factory — مصنع التدوير** ♻️
   - Moving conveyor belt
   - Drag & drop objects into recycling bins
   - Correct/incorrect classification
   - Score, lives, timer

3. **Animal Adventure — مغامرة الحيوانات** 🐰
   - Press-and-drag the child freely in X/Y (smooth follow, stays in the play area below the HUD)
   - Collect the requested food
   - Deliver it to the correct animal
   - Multiple randomized rounds
   - Score and timer

4. **Icy Tower — البرج الجليدي** 🧊
   - Endless vertical platformer: climb a frozen tower by jumping between platforms
   - Controls: left/right pad (hold, slide across to switch direction) + Jump button (tap = small jump, hold = higher jump / keep bouncing). Keyboard: arrows or A/D, Space or ↑
   - Physics: gravity, acceleration, icy momentum, wall bounces, speed-based jump height, one-way platform collision, forgiving jump timing
   - Platforms: normal, moving (from floor 12), crumbling (from floor 20), and full-width golden milestones every 25 floors
   - Difficulty ramps up: narrower platforms, bigger gaps, and a camera that starts scrolling at floor 5 and speeds up over time
   - Scoring: 10 points per floor + combo bonus (jump 2+ floors at once, keep chaining within 3 s, bonus = floors²)
   - Visuals: animated kid drawn in code (squash & stretch, blinking, running, spins), layered background (sky, stars, moon, mountains, tower wall), snowfall, penguins, landing puffs, sparkles, confetti, camera shake
   - Game Over card with floor, score, best combo, session best and a Restart button

## Project structure

```
lib/
  main.dart              Game Hub, shared GamePage, Ocean Rescue, Recycling Factory, Animal Adventure
  games/icy_tower.dart   Icy Tower (self-contained module)
test/
  widget_test.dart       Game Hub renders
  icy_tower_test.dart    Icy Tower played with real touch gestures: pad, jump, landing, game over, restart
```

To add a new game, create it as a `FlameGame` (ideally in `lib/games/`) and add a `_GameCardData` entry to the `cards` list in `GameHub`.

## Work log

- **Fixed build errors:** removed the unsupported `textAlign` from Flame `TextComponent`s, added the missing `super` calls in drag handlers, and replaced the default `MyApp` counter test with a Game Hub test.
- **Ocean Rescue controls:** replaced tap-to-move with press-and-drag steering. The boat keeps its grab offset (no jump to the finger), follows smoothly at the same speed on any frame rate, stops instantly on release, and the boat's icon stays in sync with its collision box.
- **Animal Adventure controls:** same press-and-drag steering, but in both X and Y. The child moves before the collision checks each frame so food and animal hits use the current position.
- **New game: Icy Tower:** added as a separate module with a Game Hub card. Tuned with a test bot to make sure the tower stays climbable (a quick tap always clears one floor). Screen-space layers are drawn in the camera viewport so they sit above the world.

## Run

Requires Flutter with Dart >= 3.4.

```bash
flutter pub get
flutter run
```

For iPhone simulator:
```bash
open -a Simulator
flutter devices
flutter run -d <simulator-id>
```

Checks:
```bash
flutter analyze
flutter test
```

## Notes
- Uses Flutter + Flame, no Unity.
- Emoji are placeholders for production sprites in the first three games so the demo runs without an asset pack. Icy Tower is drawn entirely in code.
- For a production/client-polish pass, replace the Emoji components with animated sprite sheets and add SFX/music, particles and illustrated backgrounds.
- Icy Tower tuning constants (`maxRun`, `baseJump`, `groundFriction`, `comboWindow`, …) are at the top of `IcyTowerGame`.
