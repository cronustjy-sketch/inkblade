# AGENTS.md — Ink Blade Era (墨刃纪元) · Godot Remake

## What this project is
A 3D remake of the web game **Ink Blade Era (墨刃纪元)**, originally HTML/JS at inkblade.cronuschores.xyz.
It is a **lane battle game** (like Stick War): the player's castle is on the left, the enemy castle on the right.
The player spends energy to spawn stickman soldiers, controls a hero, and can take direct control of any soldier.
Win by destroying the enemy castle (and the boss on boss levels). Lose if your castle falls.

Creator credit in-game must read **"Junyuan"**.

## Engine and target
- **Godot 4** (standard build, not .NET). Language: **GDScript only**.
- Renderer: **Compatibility** (must run well on Intel Iris Xe and export to Web).
- Final target: **Web export**, played in a browser on PC and phone. Keep it light.
- You are connected to the Godot editor through an MCP server. You can also edit `.gd` and `.tscn` files directly.

## Rules for the agent
- Do ONE build step per task. After each step, stop and tell me exactly how to test it (which scene to run, what keys to press, what I should see).
- Run the project after changes and read the debug output. Fix errors before saying you're done.
- Do not delete files without asking. Do not touch `.godot/`.
- Keep all unit stats in `data/units.gd` (one dictionary) so balance changes never need gameplay code edits.
- Use static typing in GDScript (`var hp: float = 60.0`).
- Keep performance in mind: up to ~100 units on screen on a weak laptop GPU. No real-time shadows, no heavy post-processing.
- UI text is Chinese with English underneath, matching the original game.

## Folder layout
```
res://
  scenes/      battle.tscn, unit.tscn, hero.tscn, castle.tscn, hud.tscn
  scripts/     battle.gd, unit.gd, hero.gd, castle.gd, spawner.gd, hud.gd
  data/        units.gd, bosses.gd, levels.gd
  models/      imported .glb files (hero, warden, colossus, faceless, dragon, ender, pk)
  ui/          fonts, icons
```

## Core game rules (from the original)
**Scale:** the original used pixels. Divide distances and speeds by 30 to get meters (soldier speed 44 → ~1.5 m/s, archer range 155 → ~5 m).

**Layout:** one straight lane along the X axis. Player castle at x = 0, enemy castle at x = 40.
Units get a small random Z offset (±1 m; big units ±0.4 m) so they don't stand in one file.
Camera: angled 3/4 side view that follows the hero, clamped between the castles.

**Energy:** starts at 0, regenerates 10/sec, max 200. Spawning costs energy.

**Army cap:** 50 population. Big units take more pop (see table).

**Unit AI:** walk toward the enemy castle. If an enemy is within `range`, stop and attack every `cooldown` seconds.
If no enemy is in range and the enemy castle is in range, attack the castle.

**Orders (buttons):** Attack (push forward) · Defend (hold a line ~7 m in front of own castle) · Retreat (go back into the castle and heal 8% max HP/sec).

**Take control:** clicking/tapping a soldier lets the player move it with ← →; it deals **+40% damage** while controlled. Tab cycles soldiers, H returns to the hero.

### Units (data/units.gd) — original pixel values
| Key | Name | HP | ATK | Range | Speed | Cooldown | Cost | Pop | Unlock lvl | Special |
|---|---|---|---|---|---|---|---|---|---|---|
| soldier | Swordsman 剑兵 | 60 | 10 | 24 | 44 | 0.9 | 20 | 1 | 1 | — |
| archer | Archer 弓手 | 36 | 9 | 155 | 36 | 1.35 | 30 | 1 | 2 | shoots arrows |
| spear | Spearman 长枪兵 | 75 | 12 | 42 | 40 | 1.1 | 35 | 1 | 3 | ×2 damage vs big units |
| shield | Shield Knight 盾卫 | 240 | 15 | 26 | 32 | 1.0 | 45 | 1 | 4 | 35% armor, blocks arrows |
| witch | Witch 女巫 | 42 | 15 | 135 | 32 | 2.0 | 60 | 1 | 5 | magic orb, splash 48 |
| assassin | Assassin 刺客 | 48 | 20 | 22 | 85 | 0.6 | 50 | 1 | 6 | 30% crit (×2.5) |
| priest | Priest 牧师 | 55 | 0 | 110 | 36 | 1.4 | 55 | 1 | 7 | heals lowest-HP ally 16 |
| giant | Giant 巨人 | 620 | 38 | 52 | 18 | 2.2 | 150 | 3 | 8 | AOE 62, knockback |
| cavalry | Cavalry 骑兵 | 170 | 20 | 30 | 95 | 1.0 | 90 | 2 | 9 | first hit ×2 + knockback |
| catapult | Catapult 投石车 | 220 | 50 | 330 | 16 | 4.2 | 140 | 3 | 10 | rock, splash 55, ×2 vs castle |
| dragon | Dragon 苍龙 | 900 | 16 | 40 | 80 | 1.0 | 190 | 4 | 201 | flies; ground melee can't hit it |

### Hero skills
| Key | Skill | Effect | Unlock |
|---|---|---|---|
| Q | Slash 怒斩 | 70 damage to all enemies in a 7 m area in front; cooldown 11 s | 1 |
| E | Dash 冲锋 | fast dash forward, 40 damage to each enemy passed, invincible 0.45 s; cooldown 6 s | 2 |
| R | Rally 战吼 | whole army heals 30% and attacks ~45% faster for 6 s; cooldown 18 s | 4 |
| F | Sword Rain 剑雨 | swords fall on a 9 m area in front for 2.2 s; cooldown 22 s | 6 |
| G | Hero skill 专属技 | unique per hero | 12 |
Every 3rd hero hit is a crit (×2.2).
Ultimate: **墨刃·终 (Ink Blade · Final)** — an ink meter fills from dealing damage; at 100 the hero does a screen-wide strike.

### Levels and enemies
- Enemy castle HP = 420 + 70 × level. Player castle HP = 500.
- Enemy stat multiplier = 1 + 0.11 × (level − 1) for levels 1–20.
- Enemy spawn interval = max(0.9, 3.2 − 0.2 × level) seconds.
- Enemy cap = min(36, 10 + 2 × level).
- Enemy unit pool: L1 soldier · L2 +archer · L3 +spear · L4 +shield · L6 +witch · L7 +assassin · L8 +priest · L9 +giant · L10 +cavalry · L13+ adds catapult.
- Bosses every 5 levels: L5 石拳首领 (950 HP, 26 ATK), L10 草原霸主 (1900/34), L15 熔岩巨魔 (3600/46), L20 墨刃魔王 (6000/58).
- The boss spawns 3 s into the level. The enemy castle can't be damaged while the boss is alive.
- Levels 11–20 have lava terrain.

## Art direction
Black ink on parchment, stickmen, gold `#e8b44a` for the player, red `#de4b3f` for enemies, dark UI `#13161b`.
Unshaded or toon materials with black outlines suit the ink look and are cheap to render.
Existing 3D models (.glb, some with Mixamo animations: `hero_anim`, `warden_anim`, `colossus_anim`, `faceless_anim`) go in `res://models/`.

## Build order (do these in order, one per task)
1. `battle.tscn`: ground lane, two castles (boxes are fine, gold and red) with HP bars, camera.
2. `data/units.gd` + `unit.tscn`/`unit.gd` (capsule placeholder): walk, find nearest enemy, attack, die. Spawn one of each team to test.
3. HUD: energy bar, pop counter, spawn buttons for unlocked units. Enemy spawner on a timer.
4. Win/lose screen with "Next level" and "Retry".
5. Hero with ← → movement and Q Slash.
6. Swap capsules for the imported .glb models with walk/attack animations.
7. Remaining unit specials (arrows, splash, heal, armor, AOE, knockback, cavalry charge).
8. Orders (attack/defend/retreat) and take-control.
9. Skills E, R, F and the ultimate.
10. Levels 1–20 with bosses and a level-select map.
11. Web export and test on phone.
