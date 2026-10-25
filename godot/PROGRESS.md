# Progress

Build log for the Godot remake. Each entry says what was done and how to test it.
Run the project with F5 (main scene). Debug keys (editor runs only): F1 win, F2 lose, F3 hero run, F4 hero slash.

- **Step 1: battle scene and castles.** Lane, two ink-style castles with HP bars, camera. Test: F5, hold ← → to pan.
- **Step 2: unit data and AI.** `data/units.gd` holds all stats; units walk, fight, die. Test: spawn swordsmen and watch them fight.
- **Step 3: HUD and enemy spawner.** Energy bar, pop counter, spawn buttons, timed enemy waves. Test: click the swordsman button once energy >= 20.
- **Step 4: win/lose screen.** Destroy a castle (or press F1/F2) to get Victory/Defeat with Next Level / Retry. Test: press F1, click Next Level.
- **Step 6: stickmen and hero model.** Units are ink-style 3D stickmen with weapons (`scripts/stickman.gd`); the hero uses `hero_anim.glb`. Test: set `start_level` to 10 on the Battle node and watch all unit types; F3/F4 preview hero animations.
  (Built before step 5 at the user's request; committed together with step 4.)
- **Step 5: hero.** The hero (`scripts/hero.gd`, model `hero_anim.glb`) moves with ← → (or A/D), auto-attacks the nearest enemy or castle in range (every 3rd hit is a ×2.2 crit), can die and respawns after 5 s. **Q** Slash hits everything within 7 m in front for 70. Camera follows the hero. HUD has a skill bar bottom-right. Hero and skill stats live in `data/units.gd`. Test: F5, move with ← →, press Q next to enemies. `scenes/dev_smoke.tscn` is a developer smoke test (run headless: `godot --headless --path . res://scenes/dev_smoke.tscn`).
- **Step 7: unit specials.** Archers shoot arrows (shield knights in front soak them), witches and catapults throw splash projectiles (catapult ×2 vs castles), spearmen ×2 vs big units, shield knights take 35% less damage, assassins crit 30% (×2.5), priests heal the lowest-HP ally for 16, giants hit everything near the target and knock it back, cavalry's first hit is ×2 with knockback, dragons fly (ground melee can't hit them). Data lives in `data/units.gd`, code in `unit.gd` / `projectile.gd`. Test: set `start_level` to 10 on the Battle node and watch the mixed armies; `dev_smoke.tscn` checks all of these headless.
