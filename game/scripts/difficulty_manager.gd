class_name DifficultyManager
extends Node

const INITIAL_SPEED: float = 5.0
const MAX_SPEED: float = 12.0
const SPEED_ACCELERATION: float = 0.0032

const INITIAL_RESPONSE_TIME: float = 10.0
const MIN_RESPONSE_TIME: float = 2.0
const RESPONSE_TIME_MEDIUM: float = 8.0
const RESPONSE_TIME_HARD: float = 6.0
const RESPONSE_TIME_EXPERT: float = 4.0

const INITIAL_OBSTACLE_FREQUENCY: float = 3.0
const MAX_OBSTACLE_FREQUENCY: float = 1.5

const SCORE_TIER_EASY: int = 0
const SCORE_TIER_MEDIUM: int = 150
const SCORE_TIER_HARD: int = 400
const SCORE_TIER_EXPERT: int = 800
const SCORE_TIER_MAX: int = 1500
const SCORE_TIER_FREQUENCY_MAX: int = 800

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
	var clamped_score: float = clampf(float(score), float(SCORE_TIER_EASY), float(SCORE_TIER_MAX))
	if clamped_score >= SCORE_TIER_MAX:
		return MIN_RESPONSE_TIME
	if clamped_score >= SCORE_TIER_EXPERT:
		return lerpf(
			RESPONSE_TIME_EXPERT,
			MIN_RESPONSE_TIME,
			inverse_lerp(float(SCORE_TIER_EXPERT), float(SCORE_TIER_MAX), clamped_score)
		)
	if clamped_score >= SCORE_TIER_HARD:
		return lerpf(
			RESPONSE_TIME_HARD,
			RESPONSE_TIME_EXPERT,
			inverse_lerp(float(SCORE_TIER_HARD), float(SCORE_TIER_EXPERT), clamped_score)
		)
	if clamped_score >= SCORE_TIER_MEDIUM:
		return lerpf(
			RESPONSE_TIME_MEDIUM,
			RESPONSE_TIME_HARD,
			inverse_lerp(float(SCORE_TIER_MEDIUM), float(SCORE_TIER_HARD), clamped_score)
		)
	return lerpf(
		INITIAL_RESPONSE_TIME,
		RESPONSE_TIME_MEDIUM,
		inverse_lerp(float(SCORE_TIER_EASY), float(SCORE_TIER_MEDIUM), clamped_score)
	)

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
	var progress: float = clampf(
		inverse_lerp(float(SCORE_TIER_EASY), float(SCORE_TIER_FREQUENCY_MAX), float(score)),
		0.0,
		1.0
	)
	return lerpf(INITIAL_OBSTACLE_FREQUENCY, MAX_OBSTACLE_FREQUENCY, progress)

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
