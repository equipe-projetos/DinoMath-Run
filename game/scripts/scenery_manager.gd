class_name SceneryManager
extends Node3D

## Recicla os elementos decorativos do cenário (nuvens e pedras) conforme o
## player avança, mantendo o deserto infinito sem instanciar cenas novas.
## As pedras são apenas decoração: não possuem colisão nem interagem com o gameplay.

const DEFAULT_CLOUD_SCENE: PackedScene = preload("res://assets/models/clouds.glb")
const DEFAULT_ROCK_SCENES: Array[PackedScene] = [
	preload("res://scenes/rock_small.tscn"),
	preload("res://scenes/rock_medium.tscn"),
	preload("res://scenes/rock_cone.tscn"),
]

@export_group("Referências")
## Player seguido pelo gerenciador. Se vazio, procura no grupo "player".
@export var player: Node3D
## Semente do sorteio das posições. Zero sorteia uma nova a cada partida.
@export var random_seed: int = 0

@export_group("Nuvens")
## Cena de uma nuvem.
@export var cloud_scene: PackedScene = DEFAULT_CLOUD_SCENE
## Quantidade de nuvens simultâneas.
@export var cloud_count: int = 10
## Altura mínima e máxima das nuvens.
@export var cloud_height_min: float = 8.0
@export var cloud_height_max: float = 14.0
## Deslocamento lateral máximo em relação ao centro do cenário.
@export var cloud_lateral_range: float = 32.0
## Distância à frente do player onde as nuvens são reposicionadas.
@export var cloud_ahead_min: float = 30.0
@export var cloud_ahead_max: float = 120.0
## Distância atrás do player em que uma nuvem é reciclada.
@export var cloud_behind: float = 20.0
@export var cloud_scale_min: float = 1.8
@export var cloud_scale_max: float = 3.0

@export_group("Pedras")
## Cenas de pedra usadas como decoração.
@export var rock_scenes: Array[PackedScene] = DEFAULT_ROCK_SCENES
## Quantidade de pedras simultâneas.
@export var rock_count: int = 6
## Distância lateral mínima e máxima do centro (mantém as pedras fora do caminho).
@export var rock_edge_min: float = 3.4
@export var rock_edge_max: float = 5.2
## Distância à frente do player onde as pedras são reposicionadas.
@export var rock_ahead_min: float = 10.0
@export var rock_ahead_max: float = 24.0
## Distância atrás do player em que uma pedra é reciclada.
@export var rock_behind: float = 8.0
## Altura do topo do chão, onde as pedras são apoiadas.
@export var rock_ground_y: float = 0.5
@export var rock_scale_min: float = 0.45
@export var rock_scale_max: float = 0.75

var _clouds: Array[Node3D] = []
var _rocks: Array[Node3D] = []
var _player: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_player = player if is_instance_valid(player) else get_tree().get_first_node_in_group("player")

	if not is_instance_valid(_player):
		push_warning("SceneryManager: nenhum player encontrado; decoração desativada.")
		set_process(false)
		return

	_rng.seed = random_seed if random_seed != 0 else int(Time.get_unix_time_from_system())
	_build_pools()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var player_z: float = _player.global_position.z

	for cloud in _clouds:
		if cloud.position.z > player_z + cloud_behind:
			_place_cloud(cloud)

	for rock in _rocks:
		if rock.position.z > player_z + rock_behind:
			_place_rock(rock)


func _build_pools() -> void:
	if cloud_scene == null:
		push_error("SceneryManager: cloud_scene não definida.")
	else:
		for index in cloud_count:
			var cloud: Node3D = cloud_scene.instantiate() as Node3D
			if cloud == null:
				continue
			cloud.name = "Cloud%02d" % index
			add_child(cloud)
			_clouds.append(cloud)
			_place_cloud(cloud, index)

	if rock_scenes.is_empty():
		push_error("SceneryManager: nenhuma cena de pedra definida.")
	else:
		for index in rock_count:
			var scene: PackedScene = rock_scenes[index % rock_scenes.size()]
			var rock: Node3D = scene.instantiate() as Node3D
			if rock == null:
				continue
			rock.name = "Rock%02d" % index
			add_child(rock)
			_rocks.append(rock)
			_place_rock(rock, index)


## Distribui a posição inicial ao longo da faixa à frente para evitar que todas
## as decorações comecem empilhadas no mesmo ponto.
func _place_cloud(cloud: Node3D, index: int = -1) -> void:
	var z: float = _player.global_position.z - _spread(
		cloud_ahead_min, cloud_ahead_max, index, cloud_count
	)
	cloud.position = Vector3(
		_rng.randf_range(-cloud_lateral_range, cloud_lateral_range),
		_rng.randf_range(cloud_height_min, cloud_height_max),
		z
	)
	cloud.rotation.y = _rng.randf_range(0.0, TAU)
	var cloud_scale: float = _rng.randf_range(cloud_scale_min, cloud_scale_max)
	cloud.scale = Vector3.ONE * cloud_scale


func _place_rock(rock: Node3D, index: int = -1) -> void:
	var z: float = _player.global_position.z - _spread(
		rock_ahead_min, rock_ahead_max, index, rock_count
	)
	var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
	rock.position = Vector3(
		side * _rng.randf_range(rock_edge_min, rock_edge_max),
		rock_ground_y - 0.03,
		z
	)
	rock.rotation.y = _rng.randf_range(0.0, TAU)
	var rock_scale: float = _rng.randf_range(rock_scale_min, rock_scale_max)
	rock.scale = Vector3.ONE * rock_scale


## Na primeira distribuição usa uma faixa dividida igualmente entre os itens;
## nas reciclagens usa uma posição aleatória dentro da faixa.
func _spread(minimum: float, maximum: float, index: int, total: int) -> float:
	if index < 0 or total <= 1:
		return _rng.randf_range(minimum, maximum)

	var step: float = (maximum - minimum) / float(total)
	return minimum + step * (float(index) + _rng.randf_range(0.15, 0.85))


## Quantidade de nuvens ativas (para testes/diagnóstico).
func get_cloud_count() -> int:
	return _clouds.size()


## Quantidade de pedras ativas (para testes/diagnóstico).
func get_rock_count() -> int:
	return _rocks.size()
