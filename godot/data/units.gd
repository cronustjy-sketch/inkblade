extends RefCounted

# Original pixel values; divide by PX_PER_M for meters (range, speed).
const PX_PER_M: float = 30.0

const UNITS: Dictionary = {
	"soldier": {"name_cn": "剑兵", "name_en": "Swordsman", "hp": 60.0, "atk": 10.0, "range": 24.0, "speed": 44.0, "cooldown": 0.9, "cost": 20, "pop": 1, "unlock": 1},
	"archer": {"name_cn": "弓手", "name_en": "Archer", "hp": 36.0, "atk": 9.0, "range": 155.0, "speed": 36.0, "cooldown": 1.35, "cost": 30, "pop": 1, "unlock": 2},
	"spear": {"name_cn": "长枪兵", "name_en": "Spearman", "hp": 75.0, "atk": 12.0, "range": 42.0, "speed": 40.0, "cooldown": 1.1, "cost": 35, "pop": 1, "unlock": 3},
	"shield": {"name_cn": "盾卫", "name_en": "Shield Knight", "hp": 240.0, "atk": 15.0, "range": 26.0, "speed": 32.0, "cooldown": 1.0, "cost": 45, "pop": 1, "unlock": 4},
	"witch": {"name_cn": "女巫", "name_en": "Witch", "hp": 42.0, "atk": 15.0, "range": 135.0, "speed": 32.0, "cooldown": 2.0, "cost": 60, "pop": 1, "unlock": 5},
	"assassin": {"name_cn": "刺客", "name_en": "Assassin", "hp": 48.0, "atk": 20.0, "range": 22.0, "speed": 85.0, "cooldown": 0.6, "cost": 50, "pop": 1, "unlock": 6},
	"priest": {"name_cn": "牧师", "name_en": "Priest", "hp": 55.0, "atk": 0.0, "range": 110.0, "speed": 36.0, "cooldown": 1.4, "cost": 55, "pop": 1, "unlock": 7},
	"giant": {"name_cn": "巨人", "name_en": "Giant", "hp": 620.0, "atk": 38.0, "range": 52.0, "speed": 18.0, "cooldown": 2.2, "cost": 150, "pop": 3, "unlock": 8},
	"cavalry": {"name_cn": "骑兵", "name_en": "Cavalry", "hp": 170.0, "atk": 20.0, "range": 30.0, "speed": 95.0, "cooldown": 1.0, "cost": 90, "pop": 2, "unlock": 9},
	"catapult": {"name_cn": "投石车", "name_en": "Catapult", "hp": 220.0, "atk": 50.0, "range": 330.0, "speed": 16.0, "cooldown": 4.2, "cost": 140, "pop": 3, "unlock": 10},
	"dragon": {"name_cn": "苍龙", "name_en": "Dragon", "hp": 900.0, "atk": 16.0, "range": 40.0, "speed": 80.0, "cooldown": 1.0, "cost": 190, "pop": 4, "unlock": 201},
}
