# Progress

Build log for the Godot remake. Each entry says what was done and how to test it.
Run the project with F5 (main scene). Debug keys (editor runs only): F1 win, F2 lose, F3 hero run, F4 hero slash.

- **Step 1: battle scene and castles.** Lane, two ink-style castles with HP bars, camera. Test: F5, hold ← → to pan.
- **Step 2: unit data and AI.** `data/units.gd` holds all stats; units walk, fight, die. Test: spawn swordsmen and watch them fight.
- **Step 3: HUD and enemy spawner.** Energy bar, pop counter, spawn buttons, timed enemy waves. Test: click the swordsman button once energy >= 20.
- **Step 4: win/lose screen.** Destroy a castle (or press F1/F2) to get Victory/Defeat with Next Level / Retry. Test: press F1, click Next Level.
- **Step 6: stickmen and hero model.** Units are ink-style 3D stickmen with weapons (`scripts/stickman.gd`); the hero uses `hero_anim.glb`. Test: set `start_level` to 10 on the Battle node and watch all unit types; F3/F4 preview hero animations.
  (Built before step 5 at the user's request; committed together with step 4.)
