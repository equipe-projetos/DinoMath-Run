class_name ScoreManager
extends Node

signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal high_score_changed(new_high_score: int)

const POINTS_CORRECT: int = 10
const POINTS_OBSTACLE: int = 10

const COMBO_TIER_2: int = 3
const COMBO_TIER_3: int = 5
const COMBO_TIER_4: int = 8
const COMBO_TIER_5: int = 12

const HIGH_SCORE_PATH: String = "user://high_score.save"

var score: int = 0
var combo: int = 0
var high_score: int = 0

var _save_file: ConfigFile

func _ready() -> void:
	_load_high_score()

func add_points(points: int) -> void:
	score += points
	_combo_increment()
	score_changed.emit(score)
	_check_high_score()

func add_combo_points() -> void:
	var multiplier: int = _get_combo_multiplier()
	var points: int = POINTS_CORRECT * multiplier
	add_points(points)

func add_obstacle_points() -> void:
	add_points(POINTS_OBSTACLE)

func reset_combo() -> void:
	combo = 0
	combo_changed.emit(combo)

func _combo_increment() -> void:
	combo += 1
	combo_changed.emit(combo)

func _get_combo_multiplier() -> int:
	if combo >= COMBO_TIER_5:
		return 10
	if combo >= COMBO_TIER_4:
		return 5
	if combo >= COMBO_TIER_3:
		return 3
	if combo >= COMBO_TIER_2:
		return 2
	return 1

func _check_high_score() -> void:
	if score > high_score:
		high_score = score
		high_score_changed.emit(high_score)
		_save_high_score()

func _save_high_score() -> void:
	_save_file = ConfigFile.new()
	_save_file.set_value("score", "high_score", high_score)
	var err: Error = _save_file.save(HIGH_SCORE_PATH)
	if err != OK:
		push_error("Falha ao salvar recorde: %s" % str(err))

func _load_high_score() -> void:
	var file: FileAccess = FileAccess.open(HIGH_SCORE_PATH, FileAccess.READ)
	if file == null:
		high_score = 0
		return
	_save_file = ConfigFile.new()
	var err: Error = _save_file.load(HIGH_SCORE_PATH)
	if err == OK:
		high_score = _save_file.get_value("score", "high_score", 0)
	else:
		high_score = 0

func get_score() -> int:
	return score

func get_combo() -> int:
	return combo

func get_high_score() -> int:
	return high_score

func reset_score() -> void:
	score = 0
	combo = 0
	score_changed.emit(score)
	combo_changed.emit(combo)
