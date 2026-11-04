class_name PauseMenu
extends Control

## Overlay de pausa da partida. Esc ou P pausam/retomam durante o jogo e o
## botão "PAUSA" na HUD faz o mesmo pelo mouse. O painel oferece Continuar,
## Reiniciar e Menu.
##
## Como `get_tree().paused` congela os nós INHERIT (player, obstáculos e os
## timers das perguntas), este nó roda com PROCESS_MODE_ALWAYS para continuar
## recebendo input com a árvore parada. A visibilidade não afeta o input:
## mesmo escondido, o overlay escuta o Esc para abrir a pausa.

const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"

@onready var game_manager: GameManager = get_node("/root/GameManager")
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton
@onready var pause_button: Button = %PauseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# O botão da HUD é só atalho de mouse: sem foco, o Enter/Space seguem
	# dedicados às respostas e o teclado usa Esc/P para pausar.
	pause_button.focus_mode = Control.FOCUS_NONE

	game_manager.state_changed.connect(_on_state_changed)

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_toggle_event(event):
		return

	# Fora de partida (menu, Game Over) o Esc não pausa nada.
	var state: int = game_manager.get_state()
	if state == GameManager.State.PLAYING:
		get_viewport().set_input_as_handled()
		game_manager.pause_game()
	elif state == GameManager.State.PAUSED:
		get_viewport().set_input_as_handled()
		game_manager.resume_game()


func _is_toggle_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_P
	)


func _on_state_changed(new_state: int) -> void:
	var should_show: bool = new_state == GameManager.State.PAUSED
	visible = should_show
	if should_show:
		# Permite navegar pelos botões com setas e confirmar com Enter.
		resume_button.grab_focus()


func _on_resume_pressed() -> void:
	# Despausa antes do clique: os players de SFX ficam na raiz e tocam
	# normalmente, mas assim o som não depende da ordem de processamento.
	game_manager.resume_game()
	Sfx.play_click(get_tree())


func _on_restart_pressed() -> void:
	if game_manager.get_state() != GameManager.State.PAUSED:
		return
	game_manager.resume_game()
	# O clique vem antes da troca de cena: ela destaca esta cena da árvore
	# imediatamente e o get_tree() deixaria de existir aqui. O player de
	# SFX fica na raiz e sobrevive à transição.
	Sfx.play_click(get_tree())
	# restart_game troca de cena; o _sync_current_scene inicia a partida.
	game_manager.restart_game()


func _on_menu_pressed() -> void:
	if game_manager.get_state() != GameManager.State.PAUSED:
		return
	game_manager.resume_game()
	Sfx.play_click(get_tree())
	var err: Error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if err != OK:
		push_warning("PauseMenu: falha ao abrir o menu (%s)." % error_string(err))


func _on_pause_button_pressed() -> void:
	var state: int = game_manager.get_state()
	if state == GameManager.State.PLAYING:
		Sfx.play_click(get_tree())
		game_manager.pause_game()
	elif state == GameManager.State.PAUSED:
		game_manager.resume_game()
		Sfx.play_click(get_tree())
