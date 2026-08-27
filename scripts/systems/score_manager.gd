extends Node
class_name ScoreManager

signal score_updated(current_score, high_score)
signal government_pigeon_killed(total_gov_kills)

var current_score: int = 0
var high_score: int = 0
var total_kills: int = 0
var government_kills: int = 0
var shots_fired: int = 0

func reset() -> void:
	current_score = 0
	total_kills = 0
	government_kills = 0
	shots_fired = 0
	score_updated.emit(current_score, high_score)

func record_shot() -> void:
	shots_fired += 1

func add_score(amount: int, is_gov: bool = false) -> void:
	current_score += amount
	total_kills += 1

	if current_score > high_score:
		high_score = current_score

	if is_gov:
		government_kills += 1
		government_pigeon_killed.emit(government_kills)

	score_updated.emit(current_score, high_score)
