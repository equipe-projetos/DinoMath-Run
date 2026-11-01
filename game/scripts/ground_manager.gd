class_name GroundManager
extends Node3D

## Mantém o cenário infinito reciclando módulos de chão: quando um módulo
## fica atrás do player, ele é reposicionado à frente do último módulo ativo.

const DEFAULT_SEGMENT_SCENE: PackedScene = preload("res://scenes/ground_segment.tscn")

@export_group("Referências")
## Cena de um módulo de chão.
@export var segment_scene: PackedScene = DEFAULT_SEGMENT_SCENE
## Player seguido pelo gerenciador. Se vazio, procura no grupo "player".
@export var player: Node3D

@export_group("Segmentos")
## Quantidade inicial de módulos ativos.
@export var segment_count: int = 8
## Limite de módulos caso a velocidade exija mais cobertura à frente.
@export var max_segment_count: int = 16
## Comprimento de cada módulo. Zero calcula automaticamente pela colisão.
@export var segment_length: float = 0.0
## Distância atrás do player onde o primeiro módulo começa.
@export var start_behind: float = 12.0
## Distância de chão que permanece atrás do player antes de reciclar o módulo.
@export var recycle_margin: float = 12.0

@export_group("Velocidade")
## Segundos de cenário que devem existir à frente do player.
@export var lookahead_seconds: float = 4.0
## Cobertura mínima à frente, independente da velocidade.
@export var min_lookahead_distance: float = 24.0
## Velocidade usada quando nem o player nem o DifficultyManager estão disponíveis.
@export var fallback_speed: float = 3.0
## Folga de chão além do ponto onde o próximo obstáculo nasce.
@export var spawn_ahead_margin: float = 8.0

var _segments: Array[Node3D] = []
var _player: Node3D
var _difficulty: Node
var _score: Node
var _obstacle_spawner: Node
var _length: float = 0.0
var _far_edge: float = 0.0
var _initialized: bool = false


func _ready() -> void:
	# Roda depois do player para detectar a posição atualizada no mesmo frame.
	process_physics_priority = 50

	_player = player if is_instance_valid(player) else get_tree().get_first_node_in_group("player")
	_difficulty = get_node_or_null("/root/DifficultyManager")
	_score = get_node_or_null("/root/ScoreManager")
	_ensure_obstacle_spawner()

	if not is_instance_valid(_player):
		push_warning("GroundManager: nenhum player encontrado; cenário desativado.")
		set_physics_process(false)
		return

	_initialize()


func _physics_process(_delta: float) -> void:
	if not _ensure_player():
		return

	if not _initialized:
		_initialize()
		return

	_ensure_coverage()
	_recycle_segments()


## Cria a quantidade inicial de módulos e guarda a borda da frente.
func _initialize() -> void:
	if segment_scene == null:
		push_error("GroundManager: segment_scene não definida.")
		set_physics_process(false)
		return

	_length = segment_length if segment_length > 0.0 else _measure_segment_length()
	if _length <= 0.0:
		push_error("GroundManager: não foi possível determinar o comprimento do módulo.")
		set_physics_process(false)
		return

	_far_edge = _player.global_position.z + maxf(start_behind, 0.0)
	var desired: int = _desired_segment_count()

	for _index in desired:
		if not _add_segment():
			break

	_initialized = true


## Adiciona módulos se a velocidade atual exigir mais cobertura à frente.
func _ensure_coverage() -> void:
	var desired: int = _desired_segment_count()
	while _segments.size() < desired:
		if not _add_segment():
			break


## Reposiciona para a frente todos os módulos que já ficaram para trás.
func _recycle_segments() -> void:
	var cutoff: float = _player.global_position.z + recycle_margin
	var recycled: bool = true

	while recycled:
		recycled = false
		for segment in _segments:
			if _far_edge_of(segment) >= cutoff - 0.001:
				_move_to_front(segment)
				recycled = true
				break


func _add_segment() -> bool:
	var segment: Node3D = segment_scene.instantiate() as Node3D
	if segment == null:
		push_error("GroundManager: a cena de chão não é um Node3D.")
		return false

	add_child(segment)
	_segments.append(segment)
	_move_to_front(segment)
	return true


## Coloca o módulo imediatamente à frente da cobertura atual.
func _move_to_front(segment: Node3D) -> void:
	segment.global_position = Vector3(0.0, 0.0, _far_edge - _length * 0.5)
	_far_edge -= _length
	segment.reset_physics_interpolation()


func _far_edge_of(segment: Node3D) -> float:
	return segment.global_position.z - _length * 0.5


func _desired_segment_count() -> int:
	var speed_lookahead: float = lookahead_seconds * get_scroll_speed()
	var spawn_lookahead: float = _get_obstacle_spawn_ahead() + maxf(spawn_ahead_margin, 0.0)
	var lookahead: float = maxf(min_lookahead_distance, maxf(speed_lookahead, spawn_lookahead))
	# A cobertura à frente é mínima imediatamente antes de reciclar um módulo,
	# quando ainda restam (N - 1) módulos menos a margem atrás do player.
	var required: int = ceili((lookahead + maxf(recycle_margin, 0.0)) / _length) + 1
	var minimum: int = maxi(segment_count, 1)
	var maximum: int = maxi(max_segment_count, minimum)
	return clampi(maxi(minimum, required), minimum, maximum)


func _get_obstacle_spawn_ahead() -> float:
	if not is_instance_valid(_obstacle_spawner):
		_ensure_obstacle_spawner()
	if not is_instance_valid(_obstacle_spawner):
		return 0.0
	if not _obstacle_spawner.has_method("get_spawn_ahead_distance"):
		return 0.0
	return maxf(float(_obstacle_spawner.call("get_spawn_ahead_distance")), 0.0)


func _ensure_obstacle_spawner() -> bool:
	if is_instance_valid(_obstacle_spawner):
		return true
	_obstacle_spawner = get_tree().get_first_node_in_group("obstacle_spawner")
	return is_instance_valid(_obstacle_spawner)


## Lê o comprimento do módulo a partir da caixa de colisão da cena.
func _measure_segment_length() -> float:
	var probe: Node = segment_scene.instantiate()
	if probe == null:
		return 0.0

	var length: float = 0.0
	for child in probe.find_children("*", "CollisionShape3D", true, false):
		var collision := child as CollisionShape3D
		if collision.shape is BoxShape3D:
			length = collision.shape.size.z * collision.transform.basis.get_scale().z
			break

	probe.free()
	return length


## Velocidade de referência para dimensionar a cobertura. Usa o maior valor
## entre a velocidade real do player e a velocidade planejada pelo manager.
func get_scroll_speed() -> float:
	var player_speed: float = fallback_speed
	if is_instance_valid(_player):
		var value: Variant = _player.get("run_speed")
		if value is float or value is int:
			player_speed = maxf(float(value), 0.001)

	var difficulty_speed: float = 0.0
	if is_instance_valid(_difficulty) and _difficulty.has_method("get_speed"):
		difficulty_speed = float(_difficulty.get_speed(_get_score()))

	return maxf(maxf(player_speed, difficulty_speed), 0.001)


func _get_score() -> int:
	if is_instance_valid(_score) and _score.has_method("get_score"):
		return int(_score.get_score())
	return 0


func _ensure_player() -> bool:
	if is_instance_valid(_player):
		return true

	_player = get_tree().get_first_node_in_group("player")
	return is_instance_valid(_player)


## Quantidade de módulos ativos no momento.
func get_segment_count() -> int:
	return _segments.size()


## Borda mais distante (negativa) coberta pelo chão.
func get_far_edge() -> float:
	return _far_edge
