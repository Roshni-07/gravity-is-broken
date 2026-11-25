# GRAVITY IS BROKEN

A short 2D top-down sci-fi puzzle made with Godot 4.7.2.

## Play

Open `project.godot` in Godot 4.7.2 and press the run button.

- **WASD**: Move
- **Arrow keys**: Change gravity
- **R**: Restart the puzzle
- **Escape**: Pause or resume

## Objective

The exit is locked. Change gravity to slide the amber cargo crate onto the yellow floor plate. Once the plate activates, the exit unlocks. Walk through the open door to escape.

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
- Gravity affects the cargo crate only.
- This repository is intended to be built with Godot 4.7.2 Standard.
