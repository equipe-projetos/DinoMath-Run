class_name MainMenu
extends Control

## Menu principal do jogo: inicia a partida, abre as instruções e encerra o
## executável. Também exibe o recorde local salvo entre sessões.

const GAME_SCENE_PATH: String = "res://scenes/Game.tscn"
const HOW_TO_PLAY_SCENE_PATH: String = "res://scenes/how_to_play.tscn"
const HIGH_SCORE_PATH: String = "user://high_score.save"
const HIGH_SCORE_SECTION: String = "score"
const HIGH_SCORE_KEY: String = "high_score"

## Tempo para o clique terminar antes de fechar o jogo.
const QUIT_DELAY: float = 0.18

var _leaving: bool = false

@onready var menu_content: VBoxContainer = %MenuContent
@onready var play_button: Button = %PlayButton
@onready var how_to_play_button: Button = %HowToPlayButton
@onready var quit_button: Button = %QuitButton
@onready var high_score_value: Label = %HighScoreValue


func _ready() -> void:
	# O menu pode ser carregado depois de uma partida pausada ou em slow motion.
	get_tree().paused = false
	Engine.time_scale = 1.0

	play_button.pressed.connect(_on_play_pressed)
	how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	high_score_value.text = str(_read_high_score())

	_play_intro()
	play_button.grab_focus()


func _on_play_pressed() -> void:
	_play_click()
	_change_scene(GAME_SCENE_PATH)


func _on_how_to_play_pressed() -> void:
	_play_click()
	_change_scene(HOW_TO_PLAY_SCENE_PATH)


func _on_quit_pressed() -> void:
	if _leaving:
		return

	_leaving = true
	_play_click()

	# Sem a espera, o processo encerraria e o som do clique seria cortado.
	await get_tree().create_timer(QUIT_DELAY).timeout
	get_tree().quit()


func _play_intro() -> void:
	modulate.a = 0.0
	menu_content.modulate.a = 0.0

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	tween.tween_property(menu_content, "modulate:a", 1.0, 0.50).set_delay(0.10)


func _play_click() -> void:
	Sfx.play_click(get_tree())


func _change_scene(scene_path: String) -> void:
	if _leaving:
		return

	if not ResourceLoader.exists(scene_path):
		push_warning("MainMenu: cena não encontrada em %s." % scene_path)
		return

	_leaving = true
	var err: Error = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_warning("MainMenu: falha ao trocar para %s (%s)." % [scene_path, error_string(err)])
		_leaving = false


func _read_high_score() -> int:
	var config: ConfigFile = ConfigFile.new()

	if config.load(HIGH_SCORE_PATH) != OK:
		return 0

	return int(config.get_value(HIGH_SCORE_SECTION, HIGH_SCORE_KEY, 0))
