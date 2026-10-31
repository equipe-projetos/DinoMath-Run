class_name Obstacle
extends AnimatableBody3D

## Obstáculo móvel do endless runner. Pode ser removido ao sair do campo de
## visão da câmera ou reciclado por um ObstacleSpawner (object pooling).

signal despawned(obstacle: Obstacle)
signal hit_player(player_node: Node)

@export_group("Movimento")
## Velocidade de deslocamento, em unidades por segundo.
@export var move_speed: float = 5.0
## Direção do movimento. Por padrão, avança em +Z (em direção ao player).
@export var move_direction: Vector3 = Vector3.BACK
## Distância além da câmera para considerar o obstáculo fora da tela.
@export var despawn_margin: float = 4.0

@export_group("Fallback")
## Posição Z usada para despawnar quando não há câmera ativa.
@export var fallback_despawn_z: float = 20.0

@export_group("Colisão")
## Raio da área de detecção de colisão com o player.
@export var hit_radius: float = 0.7
@export_group("Pooling")
## Se verdadeiro, o obstáculo é destruído ao sair de cena. Spawners configuram
## como falso para reutilizar a mesma instância.
@export var free_on_despawn: bool = true
## Indica se o obstáculo está ativo no pool.
var is_active: bool = true

@onready var _cactus: Node3D = $Cactus

var _camera: Camera3D
var _variations: Array[Node3D] = []
var _base_collision_layer: int
var _base_collision_mask: int

var _camera: Camera3D
var _hit_area: Area3D

func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	add_to_group("obstacle")
	_setup_hit_area()


func _setup_hit_area() -> void:
	_hit_area = Area3D.new()
	var shape = CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = hit_radius
	_hit_area.add_child(shape)
	_hit_area.position = Vector3(0, 0.5, 0)
	add_child(_hit_area)
	_hit_area.body_entered.connect(_on_hit_area_body_entered)


func _on_hit_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		hit_player.emit(body)
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask
	_cache_variations()

	if not is_active:
		_apply_active_state(false)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	global_position += move_direction.normalized() * move_speed * delta

	if _is_out_of_view():
		despawn()


## Ativa o obstáculo em uma posição, com velocidade, escala, rotação e variação.
func activate(
	spawn_position: Vector3,
	speed: float,
	size_scale: float = 1.0,
	yaw: float = 0.0,
	variation: int = -1
) -> void:
	global_position = spawn_position
	move_speed = speed
	scale = Vector3.ONE * maxf(size_scale, 0.01)
	rotation = Vector3(0.0, yaw, 0.0)

	if variation >= 0:
		set_variation(variation)

	is_active = true
	_apply_active_state(true)
	reset_physics_interpolation()


## Desativa e esconde o obstáculo para que ele volte ao pool.
func deactivate() -> void:
	if not is_active and not visible:
		return

	is_active = false
	_apply_active_state(false)


func despawn() -> void:
	if not is_active or is_queued_for_deletion():
		return

	set_physics_process(false)
	is_active = false
	despawned.emit(self)

	if free_on_despawn:
		queue_free()
	else:
		_apply_active_state(false)


## Alterna entre as variações de modelo disponíveis na cena.
func set_variation(index: int) -> void:
	if _variations.is_empty():
		return

	var selected: int = posmod(index, _variations.size())
	for variation_index in _variations.size():
		_variations[variation_index].visible = variation_index == selected


func get_variation_count() -> int:
	return _variations.size()


func _cache_variations() -> void:
	_variations.clear()

	if not is_instance_valid(_cactus):
		return

	for child in _cactus.get_children():
		if child is Node3D:
			_variations.append(child)


func _apply_active_state(active: bool) -> void:
	visible = active
	set_physics_process(active)
	collision_layer = _base_collision_layer if active else 0
	collision_mask = _base_collision_mask if active else 0

	if active:
		if not is_in_group("obstacles"):
			add_to_group("obstacles")
	elif is_in_group("obstacles"):
		remove_from_group("obstacles")


func _is_out_of_view() -> bool:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()

	if is_instance_valid(_camera):
		return (
			_camera.is_position_behind(global_position)
			and _camera.global_position.distance_to(global_position) > despawn_margin
		)

	return global_position.z > fallback_despawn_z
