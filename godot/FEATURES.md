# FEATURES.md — Ink Blade Era (墨刃纪元): web game vs. Godot version

Source of truth: `public/index.html` (the web game, ~10,000 lines of readable code + embedded art/audio; never edited).
Godot version: `godot/` on branch `godot`.

Legend: ✅ ported · ⚠️ partial (what exists / what is missing) · ❌ missing

> **Scale warning.** The web game is far bigger than the first Godot brief described: 60+ chapters and 1,500 2D levels,
> a 3D campaign with 100 chapters / 1,000 levels and 99 bosses, online duels, a battle pass, gacha, pets, events and more.
> This list is complete at feature level; part 6 of the plan ports the most important items first.

---

## 1. Menus, navigation and meta

| Feature (web) | Godot |
|---|---|
| Main menu: logo 墨刃纪元 / INK BLADE ERA, player-name card (title, ★, 💎, 🪙), big tiles "开始游戏 (2D 战役 · 3D 墨境)" and "模式", quick row (装备, 商店, 好友对决, 排行榜, 军械库, 通行证, 更新内容, 设置) | ⚠️ simple menu (Campaign / Boss Raid) → being rebuilt in part 3 |
| "开始游戏" screen: 2D card (progress, continue, world map), 3D 墨境 card (continue, chapters, 墨神试炼, 影之章, 首领之路, 首领连战, 墨境试炼, 墨技道场), 未完之卷 card | ❌ |
| World map (SVG islands, 27 + 23 + 10 + more chapters, fog on locked chapters, flags on cleared, ★ per chapter) | ⚠️ simple 20-node level path; no islands/fog/chapters |
| Chapter level-select (10 levels per chapter, ★ 0–3 per level) | ⚠️ levels only, no stars |
| Settings: art style (墨刃 / classic), language (中文 / English / Bahasa Melayu), screen rotate, blood on/off, sfx, music, scream | ❌ (Chinese + English text only; no settings screen) |
| Tutorial (coach arrows: move, spawn, orders, take control…) | ❌ |
| Story (STORY intro), chapter story scenes (CHS), credits 制作团队, welcome | ❌ → part 3 |
| Cloud save (Google login / Firebase), cross-device merge | ❌ (local `user://` save only; web export has no login) |
| Admin tools (owner/admin panel, reset player, error log) | ❌ (not applicable) |
| News / patch notes (NEWS list, "更新内容") | ❌ |
| Daily login rewards (DAILY 50…500 coins) | ❌ |
| Leaderboard (stars, endless, rush, trial…) | ❌ (needs online backend) |
| Title splash (showSplash) with Origin video | ❌ → part 3 (Origin 起源 button) |

## 2. The 2D campaign (stickman lane battle)

| Feature | Godot |
|---|---|
| Lane battle, base left/right, energy 10/s (max 200), pop cap 50 | ✅ |
| 11 unit types with the original stats (soldier … catapult, dragon) | ✅ stats; dragon not spawnable by the player (needs chapter 21) |
| Unit specials: arrows (shield blocks), witch splash, spear ×2 vs big, shield 35% armor, assassin crit, priest heal, giant AOE + knockback, cavalry charge, catapult ×2 vs base, dragon flies | ✅ |
| Orders attack / defend / retreat (Z X C), take control of a unit (click / Tab) +40% dmg | ✅ (defend line and retreat-heal like the original) |
| Hero movement, auto attack, every 3rd hit crit ×2.2 | ✅ |
| Hero skills Q slash, E dash, R rally, F sword rain | ✅ (numbers from the web's SKILLS list) |
| Hero skill G (per-hero "专属技") and ultimate 墨刃·终 | ⚠️ one generic vortex for G; ultimate ported |
| **Unit abilities** (UAB: 旋风斩, 箭雨齐射, 突刺冲锋, 铁壁, 毒雾结界, 影袭, 圣光, 地裂, 铁骑冲锋, 火油弹, 冰龙吐息) usable on the possessed unit with Q | ❌ |
| **Spells** bought in the shop (天雷, 千箭齐发, 狂暴, 圣盾, 冰封, 能量泉, …) | ❌ |
| Levels 1–20 (formulas for HP, interval, cap, pool) | ✅ |
| Levels 21–30 chapter rules (zombie, swords-only, giants, night, rush, no hero, ranged-only, survive 90 s, final) | ❌ |
| Levels 31–1500 (chapters 4–60: frost storms, random events, sand, tide, ambush, armor + laser, mirror, candy, moon, thunder, grave, time, crystal, inferno, holy shield, chaos…) | ❌ (only chapters 1–3 data: grassland, desert, lava) |
| Random battle events (陨石雨, 雷暴, 地震, 援军, 狂风, 黑洞, 巨大化, 金币雨, 暴风雪) | ❌ |
| Chapters 21–22 dragon valley (dragon eggs, king's roar), 23 football pitch, 24 solo duels, 25–27 3D ink realm / storm isles / shadow blade | ❌ |
| Chapters 28–50 "墨海彼岸" (each with relic skills + swords + accessories rewards) and 51–60 "腐墨" (corrupt ink: black crystals, hunter, seal tentacles, voice, domain) | ❌ |
| 2D bosses: 石拳首领 L5, 草原霸主 L10, 熔岩巨魔 L15, 墨刃魔王 L20 (+ L25 僵尸王, L30 墨刃魔王·真, 35–60 and 14 more chapters' bosses) | ⚠️ L5/10/15/20 ported with their stats, castle ward while alive |
| Result screen, next level, retry | ✅ |
| Ink identity: ink splashes, brush slashes, ink burst on death | ⚠️ part 2 |
| Auto-battle toggle (🤖 自动), pause, rotate, emote bar | ❌ |
| Blood effects toggle, screams, voices, music (pentatonic), sfx | ❌ (no audio at all) |
| Army size scaling with 统帅, base HP with 防御 | ❌ (growth system missing) |

## 3. Progression, shop and equipment

| Feature | Godot |
|---|---|
| **Upgrades 力量 / 防御 / 速度 / 统帅** (GROWTH: +15% atk, +15% hp & +60 base, +10% speed & shorter skill CD, +2 cap & +1.5 regen) | ❌ → part 6 |
| **Heroes**: 金焰剑客 (free), 重甲骑士 (400), 疾影刺客 (500), 烈焰法师 (600), 巨力蛮王 (900) with stats and per-hero ex skill (旋风斩 / 钢铁壁垒 / 影袭 / 陨星术 / 震地) | ❌ → part 6 |
| **Gear** (8 items, 5 levels): 精钢铠甲, 锋利兵刃, 疾行战靴, 统帅军旗, 坚固城墙, 精钢头盔, 墨玉护符, 战鼓 | ❌ → part 6 |
| **Shop**: hero skins (金焰英雄, 暗影紫刃, 翡翠剑客, 白银骑士), army skins (苍蓝/紫晶/翠林军团), potions (能量/城墙/狂暴/疾风), spells, pets | ❌ → part 6 |
| Coins 🪙 earned per level; gems 💎 per chapter | ❌ |
| **Armory 军械库**: per-unit HP / ATK upgrade ×5, per-unit colours, preview | ❌ |
| **Pets 宠物**: 赤焰龙, 雷鹰, 灵狐, 金麒麟, 冰霜龙, 骨龙 | ❌ |
| Vault 宝库: relic 2D skills (怒涛, 沙暴, 电磁脉冲, 糖果雨, 火山爆发, 时之停滞, 圣光审判, 镜之军团, 雷神降临, 龙魂召唤, 万墨归一), 3D skills, swords, accessories — all unlocked by chapters 28–50 | ❌ |
| Ink colours 墨色 (10), titles 称号 (12), boss book 首领图鉴 | ❌ |
| Gacha 抽奖 (army skins SKV), battle pass 通行证 (40 tiers, quests, luxury lane) | ❌ |
| Rank system 排位 (青铜 → 墨刃传奇, seasons) | ❌ (online) |

## 4. Story content

| Feature | Godot |
|---|---|
| STORY intro (4 pages: ink world, 抹除者, 墨刃, "墨刃选中了你") | ❌ → part 3 |
| CHS: chapter story dialogues (chapters 1–27 + 28, 50, 51–60) between 你 / 墨老 / enemy / 影 | ❌ → part 3 |
| Chapter names + intros + rules (CHAPTERS 1–27, NEWCH 28–50, DARKCH 51–60, LEGX 61–100…) | ❌ → part 3 |
| 3D campaign story: 墨境 · 白蚀之战 (Part I), 墨之彼岸 (Part II), 未完之卷 (Part III), 影之章 | ❌ |
| Boss intro banners (name + one-line taunt/tip) | ❌ → part 3 |
| Origin video (`media/origin.mp4`), other videos (trailer, newlook, raid trailer, shorts) | ❌ → part 3 (origin → .ogv) |
| Halloween event 诅咒之月 / 首领之夜 / 空壳南瓜王 | ❌ |

## 5. Game modes

| Mode | Godot |
|---|---|
| 2D campaign (chapters 1–60, 1500 levels) | ⚠️ 20 levels |
| 3D 墨境 campaign: 100 chapters × 10 levels (C3CH / GB3 bosses), elites, variants (巨/疾/爆/白蚀/金墨/分裂 foes), awakening, 墨阶 stages, 墨三刃 | ⚠️ replaced by a simple 5-fight 3D Boss Raid (not the real thing) → part 4 |
| 3D 墨境 · 白蚀之战 earlier fights W3 (纸鸢将军, 抹除者, 朱砂狐, 石砚巨像, 墨魇) | ❌ |
| 墨神试炼 (10 boss gauntlet from GB3), 首领连战 (rush, timed), 墨境试炼 (endless 3D + perk cards), 首领之路 ladder | ❌ |
| 墨技道场 (dojo: pick 3D skills 墨刃风暴, 瞬影连斩, 墨龙卷, 天降巨剑, 墨龙降临, 月蚀一闪, …) | ❌ |
| 觉醒 forms: 基础觉醒, 血之安魂曲, 巨像之魂, 黑铁誓约, 空白, 自由之笔 | ❌ |
| Fracture chapters 断界 (FRB: 赤狱, 墨岳, 无面, 终焉, 裂隙…) and weekly **World Boss Raid** (online) | ❌ |
| Online duels / friends / co-op / ranked | ❌ (needs backend) |
| **Lava arena PvP** (kick the opponent into lava, random skills 火球/闪现/震地/钩锁/冰冻/反弹盾, chests, collapsing floors; local 2-player + CPU) | ❌ → part 6 |
| Race mode (cars on an oval, DRS) | ❌ |
| Endless defence 无尽守城 (perk cards 攻击/血量/能量/修城/箭塔/援军…), 无尽墨战 | ❌ |
| Football chapter (23): goals instead of castles, kick the ball, hero power shot, mutators (双球, 雨天, 加速球, 巨人守门员, 红牌), keeper bosses | ❌ |
| Solo chapter (24): hero alone vs one giant boss (雷霆巨像, 炎魔君主, 岩石泰坦, 冰霜巨人, 暗影魔王, 墨神·孤影), double jump, Q E R F G skills | ❌ |
| Imp / true-ink finale levels (9901, 9905), 首领之夜 (Halloween boss night) | ❌ |
| Hollow Pumpkin King (秘密首领), 闹鬼试炼 | ❌ |

## 6. 3D campaign bosses (`GB3` — "50 unique 3D campaign bosses")

Each is data: `b` body (blade / spirit / giant / brute / flyer), colours `c`, parts `p`, moves `m`, phase-2 moves `p2`, `hp`, `sp`. 15 moves with telegraphs:
dash 冲锋, slam 跃击, wave 震波, meteor 墨陨, fan 扇射, summon 召唤, beam 墨光, blink 瞬斩, spin 旋风, pillars 墨柱, rain 墨雨, cross 十字斩, orbit 环刃, pull 吸墨, stroke 空白一笔 (+ paint, hand).

| Feature | Godot |
|---|---|
| The 49 + 20 + 80 boss definitions in `GB3`, `P3B`, `LEGX`, `FRB` | ⚠️ → part 4 ports GB3 (49 bosses) + the 15 moves |
| Boss models: warden / colossus / faceless animated `.glb`, ender / pk / dragon static, others built from parts (stick body + horns, crown, halo, wings, plates, mask, hat, tail, brush, scarf) | ⚠️ part 4 |
| Boss phase 2 at 50% HP with new moves, boss HP bar + name banner | ✅ in the raid; GB3 data → part 4 |

## 7. 3D hero and arena (web `init3D`, ~2,900 lines)

| Feature | Godot |
|---|---|
| 3D hero `hero_anim.glb` with idle / run / slash1-3 / spin / roll / hit / jump / power, textured, emissive | ⚠️ model loads; textures render too dark → part 4 |
| Swords `sw_*.glb` (blank, blood, colossus, free, ink, iron) per awakening form + vault swords | ❌ → part 4 (choose sword in a menu) |
| Skills 1–4 (墨龙降临, 月蚀一闪, 百鬼夜行, 天墨崩落), 5 relic skill, I domain, T 三刃 stance, H stage-up, G 画符 (draw glyph) | ❌ |
| Arenas with decorations: lava, temple, hall, bamboo, pumpkin, sky islands (fall = out) | ⚠️ one stone arena |
| Dodge roll, jump + double jump, air attack, ground slam, launcher | ⚠️ roll + combo only |

## 8. Visuals and audio

| Feature | Godot |
|---|---|
| Ink-brush title font (ZCOOL QingKe HuangYou) | ❌ → part 2/3 |
| Rigged stickman art (head/torso/limbs sprites per unit), horses, catapult, dragon | ⚠️ replaced by generated sprite sheets |
| Parallax backgrounds per chapter theme (frost, sky, abyss, desert, coast, jungle, mech, mirror, candy, moon, storm, grave, time, crystal, inferno, holy, void, dvalley, skycity, pitch, corrupt) | ⚠️ 3 palettes (grassland, desert, lava) |
| Ink splash on hit, ink-stroke slashes, ink burst on death, ink wash paper | ❌ → part 2 |
| Procedural sfx / music / screams / voices | ❌ |

## 9. Event and live-ops systems (all ❌, listed for completeness)

Halloween (candy, 首领之夜, 空壳南瓜王), world boss raid (weekly, online), battle pass + quests, daily login, news popup, stars/leaderboards, owner gifts and announcements, friends / invites / emotes, season ranks.

---

## Port plan (see PROGRESS.md for status)

1. Part 2 battle fixes · 2. Part 3 menu + story · 3. Part 4/5 raid with the real GB3 bosses · 4. Part 6 in this order:
heroes (5) → upgrades (力量/防御/速度/统帅) + coins → gear → shop/skins → chapter rules → lava-arena PvP → solo chapter → football → endless.
Things that need a server (cloud save, online duels, leaderboards, world raid, ranks) are out of scope for a Godot/offline port.
