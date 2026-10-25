extends Node

# Developer smoke test: run scenes/dev_smoke.tscn to drive the battle from code and print PASS/FAIL lines.
# Not part of the game; used to check gameplay logic without keyboard input.

const Levels := preload("res://data/levels.gd")
const BATTLE: PackedScene = preload("res://scenes/battle.tscn")

var battle: Node3D
var failures: int = 0

func _ready() -> void:
	Levels.current_level = 1
	battle = BATTLE.instantiate()
	add_child(battle)
	await get_tree().create_timer(0.5).timeout
	await _step5()
	print("SMOKE DONE failures=%d" % failures)
	get_tree().quit()

func check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _step5() -> void:
	var hero: Node3D = battle.hero
	var x0: float = hero.position.x
	hero.move(1.0, 0.5)
	check("hero moves right with input", hero.position.x > x0)
	hero.position.x = 20.0
	battle.spawn_unit(1, "soldier")
	var foe: Node3D = get_tree().get_nodes_in_group("team_1")[0]
	foe.position = Vector3(24.0, 0.0, 0.0)
	var foe_hp: float = foe.hp
	check("slash cast succeeds", hero.cast("slash"))
	check("slash damages enemy in front", not is_instance_valid(foe) or foe.hp < foe_hp)
	check("slash goes on cooldown", not hero.can_cast("slash"))
	check("second cast refused during cooldown", not hero.cast("slash"))
	await wait(0.2)
	hero.take_damage(9999.0)
	check("hero dies at 0 hp", hero.is_dead())
	await wait(5.3)
	check("hero respawns", not hero.is_dead() and hero.hp == hero.max_hp)
