class_name GameManager
extends Node

## Orquestra o estado da partida, as vidas e a transição para o Game Over.
## Também controla o slow motion manual aplicado ao mundo durante as perguntas.

signal state_changed(new_state: int)
signal game_over_requested()
signal lives_changed(lives: int)

enum State { MENU, PLAYING, PAUSED, GAME_OVER }

const MAX_LIVES: int = 3
## Distância mínima para disparar a pergunta, em unidades do mundo.
const MIN_TRIGGER_DISTANCE: float = 5.0
## Folga extra entre o fim da janela de resposta e o início do salto.
const TRIGGER_MARGIN: float = 0.75

## Fração da velocidade normal aplicada ao mundo durante a pergunta.
## Mais baixa que o padrão do GDD para que o dinossauro fique visivelmente
## próximo do cacto sem alcançá-lo antes de o jogador responder.
const SLOW_MOTION_SCALE: float = 0.12
## Velocidade da transição de slow motion, em escala por segundo.
const SLOW_MOTION_TRANSITION: float = 3.0

## Distância entre o dinossauro e o cacto no momento em que o salto começa.
## Metade do comprimento do player + metade da profundidade do cacto.
const JUMP_CLEAR_DISTANCE: float = 1.5
## Tempo necessário para o dinossauro subir acima da altura do cacto.
const JUMP_RISE_TIME: float = 0.13
## Folga de segurança do salto.
const JUMP_LEAD_MARGIN: float = 0.5
## O salto automático só começa depois que o mundo retomou parte da velocidade.
const JUMP_MIN_SPEED_SCALE: float = 0.85

## Evita perder duas vidas pelo mesmo erro (resposta errada seguida da colisão
## com o obstáculo que gerou a pergunta).
const LIFE_LOSS_COOLDOWN: float = 3.0

const GAME_SCENE_PATH: String = "res://scenes/Game.tscn"
const GAME_OVER_SCENE_PATH: String = "res://scenes/game_over.tscn"

var current_state: State = State.MENU
var lives: int = MAX_LIVES
## Multiplicador de velocidade lido pelo Player e pelos obstáculos.
var world_speed_scale: float = 1.0

@onready var question_manager: QuestionManager = get_node("/root/QuestionManager")
@onready var score_manager: ScoreManager = get_node("/root/ScoreManager")
@onready var difficulty: DifficultyManager = get_node("/root/DifficultyManager")

var _player: Player
var _ui: UIManager
var _triggered_obstacle: Obstacle
var _target_speed_scale: float = 1.0
var _life_loss_cooldown: float = 0.0
var _current_scene_id: int = 0

## Salto automático agendado após o acerto: em vez de saltar imediatamente
## (e pousar antes do cacto), o jogador salta quando a distância correta é
## atingida.
var _jump_pending: bool = false
var _jump_obstacle: Obstacle


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	score_manager.score_changed.connect(_on_score_changed)
	question_manager.answer_correct.connect(_on_answer_correct)
	question_manager.answer_wrong.connect(_on_question_failed)
	question_manager.answer_timeout.connect(_on_question_failed)
	question_manager.cycle_finished.connect(_on_question_cycle_finished)


func _process(delta: float) -> void:
	_life_loss_cooldown = maxf(_life_loss_cooldown - delta, 0.0)
	_update_speed_scale(delta)
	_sync_current_scene()


func _physics_process(_delta: float) -> void:
	if current_state != State.PLAYING:
		return
	if not _ensure_player():
		return
	if question_manager.is_question_active():
		return

	_update_pending_jump()

	if _player.current_state == Player.State.HIT:
		return

	if not is_instance_valid(_triggered_obstacle):
		_triggered_obstacle = null

	var obstacle: Obstacle = _nearest_obstacle_ahead()
	if obstacle == null:
		_triggered_obstacle = null
		return
	if obstacle == _triggered_obstacle:
		return

	var distance: float = _player.global_position.z - obstacle.global_position.z
	if distance <= _get_trigger_distance():
		_triggered_obstacle = obstacle
		_target_speed_scale = SLOW_MOTION_SCALE
		question_manager.start_question()


func start_game() -> void:
	get_tree().paused = false
	score_manager.reset_score()
	difficulty.set_score(0)
	lives = MAX_LIVES
	lives_changed.emit(lives)
	_life_loss_cooldown = 0.0
	world_speed_scale = 1.0
	_target_speed_scale = 1.0
	_triggered_obstacle = null
	_jump_pending = false
	_jump_obstacle = null

	_bind_player()

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


## Remove uma vida e encerra a partida quando não restar nenhuma.
func lose_life() -> void:
	if current_state != State.PLAYING:
		return
	if _life_loss_cooldown > 0.0:
		return

	_life_loss_cooldown = LIFE_LOSS_COOLDOWN
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)

	if lives <= 0:
		request_game_over()


## Chamado quando as vidas chegam a zero. Troca para a tela de Game Over.
func request_game_over() -> void:
	if current_state == State.GAME_OVER:
		return

	question_manager.cancel_question()
	world_speed_scale = 1.0
	_target_speed_scale = 1.0
	_set_state(State.GAME_OVER)
	game_over_requested.emit()

	if is_instance_valid(_player):
		_player.set_physics_process(false)

	_show_game_over()


func get_state() -> State:
	return current_state


func get_lives() -> int:
	return lives


func _set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)


## Inicia a partida ao entrar na cena de jogo e volta ao estado de menu ao
## retornar para a tela inicial. Usa o ID da instância para detectar recargas
## da mesma cena (reinício).
func _sync_current_scene() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var scene_id: int = scene.get_instance_id()
	if scene_id == _current_scene_id:
		return

	_current_scene_id = scene_id
	if scene.name == "Game":
		start_game()
	elif scene.name == "MainMenu":
		_set_state(State.MENU)


func _update_speed_scale(delta: float) -> void:
	if is_equal_approx(world_speed_scale, _target_speed_scale):
		world_speed_scale = _target_speed_scale
		return

	world_speed_scale = move_toward(
		world_speed_scale,
		_target_speed_scale,
		SLOW_MOTION_TRANSITION * delta
	)


func _show_game_over() -> void:
	if ResourceLoader.exists(GAME_OVER_SCENE_PATH):
		_show_game_over_scene()
	else:
		_show_game_over_fallback()


## Usa a cena de Game Over quando ela existir (issue #35). Enquanto as telas
## de UI estiverem fora da main, o fallback abaixo mantém o jogo jogável.
func _show_game_over_scene() -> void:
	var packed: PackedScene = load(GAME_OVER_SCENE_PATH) as PackedScene
	if packed == null:
		_show_game_over_fallback()
		return

	var game_over_scene: Node = packed.instantiate()
	if game_over_scene == null:
		_show_game_over_fallback()
		return

	if game_over_scene.has_method("setup"):
		game_over_scene.call("setup", score_manager.get_score())

	var tree: SceneTree = get_tree()
	var previous_scene: Node = tree.current_scene

	tree.root.add_child(game_over_scene)
	tree.current_scene = game_over_scene

	if previous_scene != null:
		previous_scene.queue_free()


func _show_game_over_fallback() -> void:
	get_tree().paused = false

	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Game Over"
	dialog.dialog_text = "Pontuação final: %d\nRecorde: %d" % [
		score_manager.get_score(),
		score_manager.get_high_score(),
	]
	dialog.ok_button_text = "Jogar novamente"
	dialog.cancel_button_text = "Sair"
	dialog.confirmed.connect(restart_game)
	dialog.canceled.connect(_quit_game)

	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(dialog)
	else:
		get_tree().root.add_child(dialog)

	dialog.popup_centered(Vector2i(460, 200))


## Reinicia a partida a partir da tela de Game Over.
func restart_game() -> void:
	get_tree().paused = false
	_current_scene_id = 0

	var err: Error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if err != OK:
		push_warning("GameManager: falha ao reiniciar (%s)." % error_string(err))


func _quit_game() -> void:
	get_tree().quit()


func _on_score_changed(new_score: int) -> void:
	difficulty.set_score(new_score)


func _on_answer_correct(_is_combo: bool, _points: int) -> void:
	# O cacto continua no cenário. O salto é agendado para acontecer na
	# distância correta, em vez de removê-lo ou saltar longe dele.
	if is_instance_valid(_triggered_obstacle):
		_jump_obstacle = _triggered_obstacle
		_jump_pending = true
	else:
		_jump_obstacle = null
		_jump_pending = false


func _on_question_failed() -> void:
	_jump_pending = false
	_jump_obstacle = null
	lose_life()


## Executa o salto automático quando o dinossauro está na distância de
## decolagem. Só roda depois que a pergunta terminou e o mundo retomou a
## velocidade, para o salto não ficar curto demais.
func _update_pending_jump() -> void:
	if not _jump_pending:
		return
	if not is_instance_valid(_jump_obstacle):
		_jump_pending = false
		return
	if not is_instance_valid(_player):
		return
	if _player.current_state != Player.State.RUNNING:
		return
	if world_speed_scale < JUMP_MIN_SPEED_SCALE:
		return

	var distance: float = _player.global_position.z - _jump_obstacle.global_position.z
	if distance <= 0.0:
		_jump_pending = false
		_jump_obstacle = null
		return

	if distance <= _get_jump_lead():
		_player.request_jump()
		_jump_pending = false
		_jump_obstacle = null


func _on_question_cycle_finished() -> void:
	_target_speed_scale = 1.0


func _on_player_hit() -> void:
	lose_life()


func _bind_player() -> void:
	if not _ensure_player():
		return
	if not _player.hit_started.is_connected(_on_player_hit):
		_player.hit_started.connect(_on_player_hit)


func _get_ui() -> UIManager:
	if is_instance_valid(_ui):
		return _ui
	_ui = get_tree().get_first_node_in_group("ui") as UIManager
	return _ui


func _ensure_player() -> bool:
	if is_instance_valid(_player):
		return true
	_player = get_tree().get_first_node_in_group("player") as Player
	return is_instance_valid(_player)


func _nearest_obstacle_ahead() -> Obstacle:
	var nearest: Obstacle = null
	var nearest_distance: float = INF

	for node in get_tree().get_nodes_in_group("obstacles"):
		var obstacle: Obstacle = node as Obstacle
		if obstacle == null or not is_instance_valid(obstacle):
			continue
		var distance: float = _player.global_position.z - obstacle.global_position.z
		if distance < 0.0 or distance >= nearest_distance:
			continue
		nearest = obstacle
		nearest_distance = distance

	return nearest


## Distância suficiente para o jogador responder antes de alcançar o obstáculo
## e ainda ter espaço para o salto. Inclui a distância percorrida durante a
## transição para o slow motion, que começa em velocidade cheia.
func _get_trigger_distance() -> float:
	var speed: float = _get_player_speed()
	var response: float = difficulty.get_response_time(score_manager.get_score())

	var slow_distance: float = speed * response * SLOW_MOTION_SCALE
	var transition_distance: float = (
		speed * pow(1.0 - SLOW_MOTION_SCALE, 2.0) / (2.0 * SLOW_MOTION_TRANSITION)
	)
	var required: float = slow_distance + transition_distance + _get_jump_lead() + TRIGGER_MARGIN
	return maxf(required, MIN_TRIGGER_DISTANCE)


## Distância do cacto em que o salto automático deve começar. Garante que o
## dinossauro já esteja acima da altura do cacto quando a hitbox se aproximar.
func _get_jump_lead() -> float:
	return JUMP_CLEAR_DISTANCE + _get_player_speed() * JUMP_RISE_TIME + JUMP_LEAD_MARGIN


func _get_player_speed() -> float:
	if is_instance_valid(_player):
		return maxf(_player.run_speed, 0.001)
	return 5.0
