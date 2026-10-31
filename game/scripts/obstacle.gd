class_name Obstacle
extends AnimatableBody3D

## Obstáculo móvel do endless runner. Avança em direção ao player e é
## removido automaticamente ao sair do campo de visão da câmera.

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


func _physics_process(delta: float) -> void:
	global_position += move_direction.normalized() * move_speed * delta

	if _is_out_of_view():
		despawn()


func despawn() -> void:
	if is_queued_for_deletion():
		return

	set_physics_process(false)
	despawned.emit(self)
	queue_free()


func _is_out_of_view() -> bool:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()

	if is_instance_valid(_camera):
		return (
			_camera.is_position_behind(global_position)
			and _camera.global_position.distance_to(global_position) > despawn_margin
		)

	return global_position.z > fallback_despawn_z
