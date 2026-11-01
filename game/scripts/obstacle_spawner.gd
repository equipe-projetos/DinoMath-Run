class_name ObstacleSpawner
extends Node3D

## Gera obstáculos à frente do player respeitando distâncias mínima/máxima
## e reutilizando instâncias por meio de object pooling.

signal obstacle_spawned(obstacle: Obstacle)
signal obstacle_recycled(obstacle: Obstacle)

const DEFAULT_OBSTACLE_SCENE: PackedScene = preload("res://scenes/obstacle.tscn")

@export_group("Referências")
## Cena usada para criar os obstáculos do pool.
@export var obstacle_scene: PackedScene = DEFAULT_OBSTACLE_SCENE
## Player seguido pelo spawner. Se vazio, procura no grupo "player".
@export var player: Node3D

@export_group("Geração")
## Distância à frente do player em que o obstáculo nasce.
@export var spawn_ahead: float = 30.0
## Distância mínima entre obstáculos, medida na velocidade base.
@export var min_gap: float = 38.0
## Distância máxima entre obstáculos, medida na velocidade base.
@export var max_gap: float = 52.0
## Velocidade de referência usada para escalar as distâncias.
@export var base_speed: float = 5.0
## Atraso antes do primeiro obstáculo, em segundos.
@export var initial_delay: float = 2.5
## Quantidade de obstáculos mantidos no pool.
@export var pool_size: int = 12
## Altura em que o obstáculo é posicionado no mundo.
@export var spawn_height: float = 0.5
## Distância atrás do player a partir da qual o obstáculo é reciclado.
@export var recycle_behind: float = 6.0

@export_group("Variação")
## Velocidade própria do obstáculo. Zero mantém o obstáculo parado no mundo.
@export var obstacle_speed: float = 0.0
## Escala mínima aplicada a cada obstáculo gerado.
@export var min_scale: float = 0.8
## Escala máxima aplicada a cada obstáculo gerado.
@export var max_scale: float = 1.1
## Sorteia uma rotação em torno do eixo Y.
@export var random_yaw: bool = true
## Sorteia uma das variações de modelo do obstáculo.
@export var vary_model: bool = true
## Semente do gerador aleatório. Zero usa uma semente aleatória.
@export var random_seed: int = 0

@export_group("Fair Play")
## Tempo extra reservado para o salto depois da resposta.
@export var jump_time_margin: float = 1.0

var _pool: Array[Obstacle] = []
var _player: Node3D
var _difficulty: Node
var _score: Node
var _rng := RandomNumberGenerator.new()

var _started: bool = false
var _delay_remaining: float = 0.0
var _last_player_z: float = 0.0
var _distance_since_spawn: float = 0.0
var _next_gap: float = 0.0


func _ready() -> void:
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()

	_player = player if is_instance_valid(player) else get_tree().get_first_node_in_group("player")
	_difficulty = get_node_or_null("/root/DifficultyManager")
	_score = get_node_or_null("/root/ScoreManager")

	_build_pool()

	if not is_instance_valid(_player):
		push_warning("ObstacleSpawner: nenhum player encontrado; geração desativada.")
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _ensure_player():
		return

	if not _started:
		_start()

	var current_z: float = _player.global_position.z
	var travelled: float = maxf(0.0, _last_player_z - current_z)
	_last_player_z = current_z

	if _delay_remaining > 0.0:
		_delay_remaining -= delta
		if _delay_remaining > 0.0:
			return

	_distance_since_spawn += travelled

	while _distance_since_spawn >= _next_gap:
		if not _spawn():
			# Pool cheio: mantém apenas um spawn pendente para evitar
			# obstáculos sobrepostos quando uma vaga for liberada.
			_distance_since_spawn = _next_gap
			break
		_distance_since_spawn -= _next_gap
		_next_gap = _choose_gap()

	_recycle_passed_obstacles()


## Cria todas as instâncias do pool uma única vez.
func _build_pool() -> void:
	_pool.clear()

	if obstacle_scene == null:
		push_error("ObstacleSpawner: obstacle_scene não definida.")
		return

	for _index in maxi(pool_size, 0):
		var obstacle: Obstacle = obstacle_scene.instantiate() as Obstacle
		if obstacle == null:
			push_error("ObstacleSpawner: a cena de obstáculo não possui o script Obstacle.")
			continue

		obstacle.free_on_despawn = false
		obstacle.is_active = false
		add_child(obstacle)
		obstacle.deactivate()
		obstacle.despawned.connect(_on_obstacle_despawned)
		_pool.append(obstacle)


## Primeiro obstáculo é gerado logo após o atraso inicial.
func _start() -> void:
	_started = true
	_delay_remaining = maxf(initial_delay, 0.0)
	_last_player_z = _player.global_position.z
	_next_gap = _choose_gap()
	_distance_since_spawn = _next_gap


## Reaproveita uma instância inativa do pool. Retorna false se o pool estiver cheio.
func _spawn() -> bool:
	for obstacle in _pool:
		if not is_instance_valid(obstacle) or obstacle.is_active:
			continue

		var spawn_position := Vector3(
			_player.global_position.x,
			spawn_height,
			_player.global_position.z - _get_effective_spawn_ahead()
		)
		var size_scale: float = _rng.randf_range(
			minf(min_scale, max_scale),
			maxf(min_scale, max_scale)
		)
		var yaw: float = _rng.randf_range(-PI, PI) if random_yaw else 0.0
		var variation: int = -1
		if vary_model:
			variation = _rng.randi_range(0, maxi(obstacle.get_variation_count() - 1, 0))

		obstacle.activate(spawn_position, obstacle_speed, size_scale, yaw, variation)
		obstacle_spawned.emit(obstacle)
		return true

	return false


## Recicla obstáculos que já passaram do player, mesmo sem câmera ativa.
func _recycle_passed_obstacles() -> void:
	var cutoff: float = _player.global_position.z + recycle_behind

	for obstacle in _pool:
		if is_instance_valid(obstacle) and obstacle.is_active and obstacle.global_position.z > cutoff:
			obstacle.despawn()


## Calcula a distância entre dois obstáculos consecutivos.
func _choose_gap() -> float:
	var gap_range := _get_gap_range()
	var gap_min: float = gap_range.x
	var gap_max: float = gap_range.y

	if gap_max <= gap_min + 0.001:
		return gap_min

	var target: float = lerpf(gap_max, gap_min, _get_gap_factor())
	var jitter: float = (gap_max - gap_min) * 0.15
	return clampf(_rng.randf_range(target - jitter, target + jitter), gap_min, gap_max)


## Faixa efetiva de distâncias. Cresce com a velocidade e nunca fica abaixo do
## tempo necessário para responder à pergunta e concluir o salto.
func _get_gap_range() -> Vector2:
	var speed: float = _get_player_speed()
	var speed_ratio: float = speed / maxf(base_speed, 0.001)
	var gap_min: float = minf(min_gap, max_gap) * speed_ratio
	var gap_max: float = maxf(min_gap, max_gap) * speed_ratio
	var required: float = (_get_response_time() + maxf(jump_time_margin, 0.0)) * speed

	gap_min = maxf(gap_min, required)
	gap_max = maxf(gap_max, gap_min)
	return Vector2(gap_min, gap_max)


## Distância à frente do player suficiente para o obstáculo ser percebido.
func _get_effective_spawn_ahead() -> float:
	var closing_speed: float = _get_player_speed() + maxf(obstacle_speed, 0.0)
	var required: float = (_get_response_time() + maxf(jump_time_margin, 0.0)) * closing_speed
	return maxf(spawn_ahead, required)


## Integração opcional com o DifficultyManager: 0 = mais espaço, 1 = mais denso.
func _get_gap_factor() -> float:
	if is_instance_valid(_difficulty) and _difficulty.has_method("get_obstacle_gap_factor"):
		return clampf(float(_difficulty.get_obstacle_gap_factor(_get_score())), 0.0, 1.0)
	return 0.5


func _get_response_time() -> float:
	if is_instance_valid(_difficulty) and _difficulty.has_method("get_response_time"):
		return float(_difficulty.get_response_time(_get_score()))
	return 0.0


func _get_score() -> int:
	if is_instance_valid(_score) and _score.has_method("get_score"):
		return int(_score.get_score())
	return 0


func _get_player_speed() -> float:
	var speed: Variant = _player.get("run_speed") if is_instance_valid(_player) else null
	if speed is float or speed is int:
		return maxf(float(speed), 0.001)
	return base_speed


func _ensure_player() -> bool:
	if is_instance_valid(_player):
		return true

	_player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_player):
		return true

	return false


func _on_obstacle_despawned(obstacle: Obstacle) -> void:
	obstacle_recycled.emit(obstacle)


## Quantidade de obstáculos ativos no momento (útil para testes e HUD).
func get_active_count() -> int:
	var count: int = 0
	for obstacle in _pool:
		if is_instance_valid(obstacle) and obstacle.is_active:
			count += 1
	return count


## Quantidade de instâncias mantidas no pool.
func get_pool_size() -> int:
	return _pool.size()
