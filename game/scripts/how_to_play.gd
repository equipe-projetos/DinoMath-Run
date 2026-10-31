class_name HowToPlay
extends Control

## Tela de instruções. Explica controles, regras e o sistema de vidas, e
## retorna ao menu principal pelo botão "Voltar" ou pela tecla Esc.

const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"

var _leaving: bool = false

@onready var content: VBoxContainer = %Content
@onready var back_button: Button = %BackButton


func _ready() -> void:
	# A tela pode ser aberta depois de uma partida pausada ou em slow motion.
	get_tree().paused = false
	Engine.time_scale = 1.0

	back_button.pressed.connect(_on_back_pressed)

	_play_intro()
	back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Marca o evento antes de trocar de cena: a troca remove este nó da
		# árvore e `get_viewport()` passaria a ser nulo.
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	if _leaving:
		return

	_leaving = true
	Sfx.play_click(get_tree())

	if not ResourceLoader.exists(MAIN_MENU_SCENE_PATH):
		push_warning("HowToPlay: menu não encontrado em %s." % MAIN_MENU_SCENE_PATH)
		_leaving = false
		return

	var err: Error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if err != OK:
		push_warning("HowToPlay: falha ao voltar ao menu (%s)." % error_string(err))
		_leaving = false


func _play_intro() -> void:
	modulate.a = 0.0
	content.modulate.a = 0.0

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.30)
	tween.tween_property(content, "modulate:a", 1.0, 0.45).set_delay(0.08)
