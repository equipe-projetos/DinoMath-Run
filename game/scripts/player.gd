class_name Player
extends CharacterBody3D

enum State { IDLE, RUNNING, JUMPING, FALLING, HIT }

const ANIM_IDLE: StringName = &"Idle"
const ANIM_RUN: StringName = &"Run"
const ANIM_JUMP: StringName = &"Jump"
const ANIM_FALL: StringName = &"Fall"
const ANIM_HIT: StringName = &"Hit"

@export var run_speed: float = 5.0
@export var jump_velocity: float = 4.5

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var current_state: State = State.IDLE


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	_set_state(State.RUNNING)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		jump()

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


func jump() -> void:
	if current_state != State.RUNNING:
		return
	velocity.y = jump_velocity
	_set_state(State.JUMPING)


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
			return ANIM_IDLE
		State.RUNNING:
			return ANIM_RUN
		State.JUMPING:
			return ANIM_JUMP
		State.FALLING:
			return ANIM_FALL
		State.HIT:
			return ANIM_HIT
	return ANIM_IDLE


func _play_animation(anim_name: StringName) -> void:
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		ANIM_JUMP:
			if current_state == State.JUMPING:
				_set_state(State.RUNNING if is_on_floor() else State.FALLING)
		ANIM_HIT:
			if current_state == State.HIT:
				_set_state(State.IDLE)
