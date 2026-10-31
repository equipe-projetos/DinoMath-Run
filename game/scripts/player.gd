class_name Player
extends CharacterBody3D

enum State { IDLE, RUNNING, JUMPING, FALLING, HIT }

@export_group("Animações")
## O modelo T_Rex.glb não possui animações de corrida/salto próprias, então a
## caminhada é reaproveitada para os estados de deslocamento e o rugido para o
## impacto.
@export var anim_idle: StringName = &"Idle"
@export var anim_run: StringName = &"Walk"
@export var anim_jump: StringName = &"Walk"
@export var anim_fall: StringName = &"Walk"
@export var anim_hit: StringName = &"Roar"
@export var anim_roar: StringName = &"Roar"
@export var anim_bite: StringName = &"Bite"
## Multiplicador base da animação de deslocamento. A caminhada do GLB é mais
## lenta que a corrida do jogo, então ela é acelerada para não parecer um
## deslize.
@export var run_animation_speed: float = 1.5
## Velocidade mínima da animação durante o slow motion (nunca congela).
@export var min_animation_speed: float = 0.2

@export_group("Movimento")
@export var run_speed: float = 5.0
@export var jump_velocity: float = 7.0
## Tempo parado após uma colisão, mesmo quando o modelo não tem animação de dano.
@export var hit_recovery_time: float = 0.6

@onready var animation_player: AnimationPlayer = $T_Rex/AnimationPlayer
@onready var _game_manager: GameManager = get_node("/root/GameManager") as GameManager

var current_state: State = State.IDLE
var jump_requested: bool = false
var _hit_recovery_left: float = 0.0

signal jump_performed()
signal hit_started()

func _ready() -> void:
	add_to_group("player")
	_configure_animations()
	if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	_update_animation_speed()
	_set_state(State.RUNNING)

func _process(_delta: float) -> void:
	_update_animation_speed()

func _physics_process(delta: float) -> void:
	if jump_requested and current_state == State.RUNNING:
		jump_requested = false
		_do_jump()

	if not is_on_floor():
		velocity += get_gravity() * delta

	match current_state:
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
		State.HIT:
			velocity.x = 0.0
			velocity.z = 0.0
			_hit_recovery_left -= delta
			if _hit_recovery_left <= 0.0:
				_set_state(State.RUNNING)
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


## Retorna true quando o impacto realmente causa dano.
func handle_obstacle_collision() -> bool:
	if current_state == State.JUMPING or current_state == State.FALLING:
		return false
	if current_state == State.HIT:
		return false
	hit()
	return true


func request_jump() -> void:
	jump_requested = true


func _do_jump() -> void:
	if current_state != State.RUNNING:
		return
	velocity.y = jump_velocity
	_set_state(State.JUMPING)
	jump_performed.emit()


func hit() -> void:
	if current_state == State.HIT:
		return
	_hit_recovery_left = maxf(hit_recovery_time, 0.0)
	_set_state(State.HIT)
	hit_started.emit()


func start_running() -> void:
	if current_state == State.IDLE or current_state == State.HIT:
		_set_state(State.RUNNING)


func _apply_forward_motion() -> void:
	var speed_scale: float = 1.0
	if is_instance_valid(_game_manager):
		speed_scale = _game_manager.world_speed_scale
	velocity.x = 0.0
	velocity.z = -run_speed * speed_scale


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


## O GLB importa todas as animações sem loop. Idle e Walk precisam repetir
## enquanto o estado durar.
func _configure_animations() -> void:
	for anim_name in [anim_idle, anim_run]:
		if not animation_player.has_animation(anim_name):
			continue
		var animation: Animation = animation_player.get_animation(anim_name)
		animation.loop_mode = Animation.LOOP_LINEAR


func _play_animation(anim_name: StringName) -> void:
	if not animation_player.has_animation(anim_name):
		return
	# Evita reiniciar o ciclo quando dois estados usam a mesma animação
	# (RUNNING, JUMPING e FALLING usam Walk).
	if animation_player.current_animation == anim_name and animation_player.is_playing():
		return
	animation_player.play(anim_name)


func _update_animation_speed() -> void:
	if not is_instance_valid(animation_player):
		return
	var world_scale: float = 1.0
	if is_instance_valid(_game_manager):
		world_scale = _game_manager.world_speed_scale

	var base_speed: float = 1.0
	if current_state == State.RUNNING or current_state == State.JUMPING or current_state == State.FALLING:
		base_speed = run_animation_speed

	animation_player.speed_scale = maxf(world_scale * base_speed, min_animation_speed)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		anim_jump:
			if current_state == State.JUMPING:
				_set_state(State.RUNNING if is_on_floor() else State.FALLING)
		anim_hit:
			if current_state == State.HIT:
				_set_state(State.RUNNING)
