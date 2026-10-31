class_name Player
extends CharacterBody3D

enum State { IDLE, RUNNING, JUMPING, FALLING, HIT }

@export_group("Animações")
@export var anim_idle: StringName = &"Idle"
@export var anim_run: StringName = &"Run"
@export var anim_walk: StringName = &"Walk"
@export var anim_jump: StringName = &"Jump"
@export var anim_fall: StringName = &"Fall"
@export var anim_hit: StringName = &"Hit"
@export var anim_roar: StringName = &"Roar"
@export var anim_bite: StringName = &"Bite"

@export_group("Movimento")
@export var run_speed: float = 5.0
@export var jump_velocity: float = 7.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var current_state: State = State.IDLE
var jump_requested: bool = false

signal jump_performed()

func _ready() -> void:
	add_to_group("player")
	animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	_set_state(State.RUNNING)

func _physics_process(delta: float) -> void:
	if jump_requested and current_state == State.RUNNING:
		jump_requested = false
		_do_jump()

	if not is_on_floor():
		velocity += get_gravity() * delta

	match current_state:
		State.IDLE, State.HIT:
			velocity.x = 0.0
			velocity.z = 0.0
		State.JUMPING:
			_apply_forward_motion()
			if velocity.y <= 0.0:
				_set_state(State.RUNNING if is_on_floor() else State.FALLING)
		State.FALLING:
			_apply_forward_motion()
			if is_on_floor():
				_set_state(State.RUNNING)
		State.RUNNING:
			_apply_forward_motion()
			if not is_on_floor():
				_set_state(State.FALLING)

	move_and_slide()


func handle_obstacle_collision() -> void:
	if current_state == State.JUMPING or current_state == State.FALLING:
		return
	hit()


func request_jump() -> void:
	jump_requested = true


func _do_jump() -> void:
	if current_state != State.RUNNING:
		return
	velocity.y = jump_velocity
	_set_state(State.JUMPING)
	jump_performed.emit()


func hit() -> void:
	_set_state(State.HIT)


func start_running() -> void:
	if current_state == State.IDLE or current_state == State.HIT:
		_set_state(State.RUNNING)


func _apply_forward_motion() -> void:
	velocity.x = 0.0
	velocity.z = -run_speed


func _set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	_play_animation(_animation_for_state(new_state))


func _animation_for_state(state: State) -> StringName:
	match state:
		State.IDLE:
			return anim_idle
		State.RUNNING:
			return anim_run
		State.JUMPING:
			return anim_jump
		State.FALLING:
			return anim_fall
		State.HIT:
			return anim_hit
	return anim_idle


func _play_animation(anim_name: StringName) -> void:
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		anim_jump:
			if current_state == State.JUMPING:
				_set_state(State.RUNNING if is_on_floor() else State.FALLING)
		anim_hit:
			if current_state == State.HIT:
				_set_state(State.IDLE)
