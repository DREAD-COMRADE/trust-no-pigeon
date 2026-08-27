extends Node
class_name GovernmentAggressionManager

signal aggression_changed(level: int, status_text: String)

var gov_kills: int = 0
var aggression_level: int = 0

func reset() -> void:
	gov_kills = 0
	aggression_level = 0
	aggression_changed.emit(0, "NORMAL")

func on_government_killed(total_gov_kills: int) -> void:
	gov_kills = total_gov_kills
	if gov_kills <= 3:
		aggression_level = 0
		aggression_changed.emit(0, "NORMAL")
	else:
		aggression_level = gov_kills - 3
		aggression_changed.emit(aggression_level, "AGGRESSION LEVEL " + str(aggression_level))

func get_attack_speed_multiplier() -> float:
	return min(1.25, 1.0 + (aggression_level * 0.04))

func get_gov_spawn_chance() -> float:
	return min(0.65, 0.2 + (aggression_level * 0.08))

func get_spawn_interval() -> float:
	return max(0.9, 2.2 - (aggression_level * 0.15))
