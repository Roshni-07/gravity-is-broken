# Event Horizon: Two Worlds

A fresh two-level 2D game merged from Asteroid Dodge and ANTIGRAVITY.

## Controls
- **A/D or arrow keys:** move
- **W/S or up/down:** move in the asteroid level
- **Space:** jump in the gravity level
- **Arrow keys:** switch gravity in the gravity level
- **R:** restart
- **Esc:** pause

## Run
Open `project.godot` in Godot 4.7 (Import Project). Press F6 to test a scene or F5 to run.

## What changed
- Added a clean `levels`, `player`, `enemies`, `ui`, `audio`, and `autoload` structure.
- Reused assets from both source games.
- Added unified player abilities, one score/lives/level manager, crossfading audio, HUD, menu screens, settings, particles, and a transition.
- Original source projects were not modified or deleted.

## Could not test
- A Godot executable was not available in the environment, so editor parsing/import and live gameplay could not be run here.
- `gl_compatibility` is retained for broad compatibility, while the target is kept on Godot 4.7.
