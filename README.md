# GRAVITY IS BROKEN

Three-level edition

A short 2D top-down sci-fi puzzle made with Godot 4.7.2.

## Play

Open `project.godot` in Godot 4.7.2 and press the run button.

- **WASD**: Move
- **Arrow keys**: Change gravity
- **R**: Restart the current level
- **Escape**: Pause or resume

## Objective

Complete three gravity puzzles:

1. **The Awakening:** activate one pressure plate.
2. **The Orbital Shift:** activate two pressure plates.
3. **The Core:** activate both reactor mechanisms.

In every level, change gravity to move the cargo crates, activate the required mechanisms, and walk through the exit door.

## Level selection

Levels unlock in sequence after completion. Completed levels are marked in the level-selection screen and can be replayed.

## Project structure

- `scenes/` — game and reusable object scenes
- `scripts/` — GDScript gameplay and UI logic
- `assets/` — reserved for future art and audio
- `README.md` — this guide

All room art is drawn procedurally in GDScript, so no download or plugin is required. The game needs no internet connection to run.

## Beginner notes

No puzzle requires perfect timing. Press R whenever you want to place the player and crate back at their starting positions.

## Windows export

In Godot, open **Project > Export**, add **Windows Desktop**, install the matching export templates, set an output path, and choose **Export Project**.

## Known limitations

- Uses procedural visuals rather than external artwork.
- Level progression lasts for the current game session; it does not save after closing the game.
- This repository is intended to be built with Godot 4.7.2 Standard.
