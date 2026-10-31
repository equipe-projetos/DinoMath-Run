class_name DifficultyManager
extends Node

const INITIAL_SPEED: float = 5.0
const MAX_SPEED: float = 12.0
const SPEED_ACCELERATION: float = 0.0032

const INITIAL_RESPONSE_TIME: float = 5.0
const MIN_RESPONSE_TIME: float = 2.0

const INITIAL_OBSTACLE_FREQUENCY: float = 3.0
const MAX_OBSTACLE_FREQUENCY: float = 1.5

const SCORE_TIER_EASY: int = 0
const SCORE_TIER_MEDIUM: int = 50
const SCORE_TIER_HARD: int = 100

var current_score: int = 0

func _ready() -> void:
	current_score = 0

func set_score(score: int) -> void:
	current_score = score

func get_current_score() -> int:
	return current_score

func get_speed(score: int) -> float:
	return min(INITIAL_SPEED + (score * SPEED_ACCELERATION), MAX_SPEED)

func get_response_time(score: int) -> float:
	var tier: int = _get_tier(score)
	match tier:
		SCORE_TIER_EASY:
			return INITIAL_RESPONSE_TIME
		SCORE_TIER_MEDIUM:
			return lerp(INITIAL_RESPONSE_TIME, MIN_RESPONSE_TIME, 0.5)
		SCORE_TIER_HARD:
			return lerp(INITIAL_RESPONSE_TIME, MIN_RESPONSE_TIME, 0.8)
		_:
			return MIN_RESPONSE_TIME

func get_allowed_operations(score: int) -> Array:
	var tier: int = _get_tier(score)
	var operations: Array = ["+", "-"]
	if tier >= SCORE_TIER_MEDIUM:
		operations.append("*")
	if tier >= SCORE_TIER_HARD:
		operations.append("/")
	return operations

func get_unknown_chance(score: int) -> float:
	var tier: int = _get_tier(score)
	match tier:
		SCORE_TIER_EASY:
			return 0.0
		SCORE_TIER_MEDIUM:
			return 0.2
		SCORE_TIER_HARD:
			return 0.4
		_:
			return 0.6

func get_obstacle_frequency(score: int) -> float:
	var tier: int = _get_tier(score)
	match tier:
		SCORE_TIER_EASY:
			return INITIAL_OBSTACLE_FREQUENCY
		SCORE_TIER_MEDIUM:
			return lerp(INITIAL_OBSTACLE_FREQUENCY, MAX_OBSTACLE_FREQUENCY, 0.5)
		SCORE_TIER_HARD:
			return lerp(INITIAL_OBSTACLE_FREQUENCY, MAX_OBSTACLE_FREQUENCY, 0.8)
		_:
			return MAX_OBSTACLE_FREQUENCY

func get_obstacle_gap_factor(score: int) -> float:
	## Fator de 0 a 1 usado pelo ObstacleSpawner: 0 gera obstáculos mais
	## espaçados e 1 os aproxima da distância mínima.
	var frequency: float = get_obstacle_frequency(score)
	return clampf(
		inverse_lerp(INITIAL_OBSTACLE_FREQUENCY, MAX_OBSTACLE_FREQUENCY, frequency),
		0.0,
		1.0
	)

func _get_tier(score: int) -> int:
	if score >= SCORE_TIER_HARD:
		return SCORE_TIER_HARD
	if score >= SCORE_TIER_MEDIUM:
		return SCORE_TIER_MEDIUM
	return SCORE_TIER_EASY
