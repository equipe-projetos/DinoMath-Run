class_name CameraController
extends Camera3D

## Câmera lateral com acompanhamento suave do movimento vertical do player.

@export var target: Node3D
@export var offset: Vector3 = Vector3(5.0, 2.4, 1.8)
@export var look_offset: Vector3 = Vector3(0.0, 0.8, -1.5)
@export_range(0.0, 1.0, 0.05) var vertical_follow: float = 0.5
@export var vertical_smoothing: float = 5.0

var _ground_y: float
var _current_y: float


func _ready() -> void:
	process_physics_priority = 100

	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")

	if not is_instance_valid(target):
		push_warning("CameraController: nenhum player encontrado.")
		set_physics_process(false)
		return

	_ground_y = target.global_position.y
	_current_y = _ground_y + offset.y
	_update_position()
	_look_at_player()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var desired_y := _ground_y + offset.y + (target.global_position.y - _ground_y) * vertical_follow
	var weight := 1.0 - exp(-vertical_smoothing * delta)
	_current_y = lerp(_current_y, desired_y, weight)
	_update_position()


func _update_position() -> void:
	global_position = Vector3(
		target.global_position.x + offset.x,
		_current_y,
		target.global_position.z + offset.z
	)


func _look_at_player() -> void:
	var look_target := target.global_position + look_offset

	if global_position.is_equal_approx(look_target):
		return

	look_at(look_target, Vector3.UP)
