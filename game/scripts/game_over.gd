class_name GameOver
extends Control

## Tela de fim de partida. Exibe a pontuação final, o recorde local e as
## opções de reiniciar a corrida ou voltar ao menu principal.

const GAME_SCENE_PATH: String = "res://scenes/Game.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"
const HIGH_SCORE_PATH: String = "user://high_score.save"
const HIGH_SCORE_SECTION: String = "score"
const HIGH_SCORE_KEY: String = "high_score"

const SOUND_GAME_OVER: AudioStream = preload("res://assets/audio/game_over.wav")

## Pontuação recebida ao final da partida. Pode ser definida pelo editor ou
## pelo GameManager através de `setup()`.
@export var final_score: int = 0

var _high_score: int = 0
var _is_new_record: bool = false

@onready var content: VBoxContainer = %Content
@onready var score_value: Label = %ScoreValue
@onready var high_score_value: Label = %HighScoreValue
@onready var new_record_label: Label = %NewRecordLabel
@onready var play_again_button: Button = %PlayAgainButton
@onready var menu_button: Button = %MenuButton
@onready var game_over_sound: AudioStreamPlayer = %GameOverSound


func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	_prepare_result()
	_play_intro()
	play_again_button.grab_focus()

	game_over_sound.stream = SOUND_GAME_OVER
	game_over_sound.play()


## Preenche a tela com a pontuação final da partida. Deve ser chamado antes de
## adicionar a cena à árvore (ou a qualquer momento, se ela já estiver ativa).
func setup(score: int) -> void:
	final_score = maxi(score, 0)

	if is_node_ready():
		_prepare_result()


func _prepare_result() -> void:
	var previous_high_score: int = _read_high_score()
	_is_new_record = final_score > previous_high_score
	_high_score = maxi(previous_high_score, final_score)

	if _is_new_record:
		_save_high_score(_high_score)

	_refresh_labels()
	_animate_score()
	_animate_new_record()


func _refresh_labels() -> void:
	score_value.text = str(final_score)
	high_score_value.text = str(_high_score)
	new_record_label.visible = _is_new_record


func _animate_score() -> void:
	score_value.text = "0"

	if final_score <= 0:
		return

	var tween: Tween = create_tween()
	tween.tween_method(_set_displayed_score, 0.0, float(final_score), 0.65) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)


func _set_displayed_score(value: float) -> void:
	score_value.text = str(roundi(value))


func _animate_new_record() -> void:
	if not _is_new_record:
		return

	new_record_label.modulate.a = 1.0

	var tween: Tween = create_tween().set_loops()
	tween.tween_property(new_record_label, "modulate:a", 0.45, 0.55)
	tween.tween_property(new_record_label, "modulate:a", 1.0, 0.55)


func _play_intro() -> void:
	modulate.a = 0.0
	content.modulate.a = 0.0

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.30)
	tween.tween_property(content, "modulate:a", 1.0, 0.45).set_delay(0.10)


func _read_high_score() -> int:
	var config: ConfigFile = ConfigFile.new()

	if config.load(HIGH_SCORE_PATH) != OK:
		return 0

	return int(config.get_value(HIGH_SCORE_SECTION, HIGH_SCORE_KEY, 0))


func _save_high_score(value: int) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(HIGH_SCORE_PATH)
	config.set_value(HIGH_SCORE_SECTION, HIGH_SCORE_KEY, value)

	var err: Error = config.save(HIGH_SCORE_PATH)
	if err != OK:
		push_warning("GameOver: não foi possível salvar o recorde (%s)." % error_string(err))


func _on_play_again_pressed() -> void:
	_play_click()
	_change_scene(GAME_SCENE_PATH)


func _on_menu_pressed() -> void:
	_play_click()
	_change_scene(MAIN_MENU_SCENE_PATH)


func _play_click() -> void:
	Sfx.play_click(get_tree())


func _change_scene(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("GameOver: cena não encontrada em %s." % scene_path)
		return

	# Garante que a próxima cena comece com o tempo normal, mesmo se o jogo
	# estiver pausado ou em slow motion no momento do Game Over.
	get_tree().paused = false
	Engine.time_scale = 1.0

	var err: Error = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_warning("GameOver: falha ao trocar para %s (%s)." % [scene_path, error_string(err)])
