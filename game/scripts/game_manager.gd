class_name GameManager
extends Node

## Orquestra o estado da partida e conecta os sistemas de gameplay.
## Por enquanto inicia direto em PLAYING, pois o menu (#32) ainda não existe.

signal state_changed(new_state: int)
signal game_over_requested()

enum State { MENU, PLAYING, PAUSED, GAME_OVER }

const MIN_TRIGGER_DISTANCE: float = 12.0
const TRIGGER_MARGIN: float = 1.0

var current_state: State = State.MENU

@onready var question_manager: QuestionManager = get_node("/root/QuestionManager")
@onready var score_manager: ScoreManager = get_node("/root/ScoreManager")
@onready var difficulty: DifficultyManager = get_node("/root/DifficultyManager")

var _player: Node3D
var _ui: UIManager
var _triggered_obstacle: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	score_manager.score_changed.connect(_on_score_changed)

	# Aguarda a cena principal entrar na árvore para localizar Player e UI.
	await get_tree().process_frame
	start_game()


func _physics_process(_delta: float) -> void:
	if current_state != State.PLAYING:
		return
	if question_manager.is_question_active():
		return
	if not _ensure_player():
		return

	if not is_instance_valid(_triggered_obstacle):
		_triggered_obstacle = null

	var obstacle: Node3D = _nearest_obstacle_ahead()
	if obstacle == null:
		_triggered_obstacle = null
		return
	if obstacle == _triggered_obstacle:
		return

	var distance: float = _player.global_position.z - obstacle.global_position.z
	if distance <= _get_trigger_distance():
		_triggered_obstacle = obstacle
		question_manager.start_question()


func start_game() -> void:
	get_tree().paused = false
	score_manager.reset_score()
	difficulty.set_score(0)
	_triggered_obstacle = null

	var ui: UIManager = _get_ui()
	if ui != null:
		ui.reset()

	_set_state(State.PLAYING)


func pause_game() -> void:
	if current_state != State.PLAYING:
		return
	_set_state(State.PAUSED)
	get_tree().paused = true


func resume_game() -> void:
	if current_state != State.PAUSED:
		return
	get_tree().paused = false
	_set_state(State.PLAYING)


## Chamado pelo sistema de vidas (#31) quando as vidas chegam a zero.
func request_game_over() -> void:
	if current_state == State.GAME_OVER:
		return
	question_manager.cancel_question()
	_set_state(State.GAME_OVER)
	game_over_requested.emit()


func get_state() -> State:
	return current_state


func _set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)


func _on_score_changed(new_score: int) -> void:
	difficulty.set_score(new_score)


func _get_ui() -> UIManager:
	if is_instance_valid(_ui):
		return _ui
	_ui = get_tree().get_first_node_in_group("ui") as UIManager
	return _ui


func _ensure_player() -> bool:
	if is_instance_valid(_player):
		return true
	_player = get_tree().get_first_node_in_group("player") as Node3D
	return is_instance_valid(_player)


func _nearest_obstacle_ahead() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = INF

	for node in get_tree().get_nodes_in_group("obstacles"):
		var obstacle: Node3D = node as Node3D
		if obstacle == null or not is_instance_valid(obstacle):
			continue
		var distance: float = _player.global_position.z - obstacle.global_position.z
		if distance < 0.0 or distance >= nearest_distance:
			continue
		nearest = obstacle
		nearest_distance = distance

	return nearest


## Distância suficiente para o jogador responder antes de alcançar o obstáculo.
func _get_trigger_distance() -> float:
	var speed: float = 5.0
	if is_instance_valid(_player):
		var value: Variant = _player.get("run_speed")
		if value is float or value is int:
			speed = maxf(float(value), 0.001)

	var response: float = difficulty.get_response_time(score_manager.get_score())
	return maxf(speed * (response + TRIGGER_MARGIN), MIN_TRIGGER_DISTANCE)
