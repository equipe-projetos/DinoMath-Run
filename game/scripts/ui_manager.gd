class_name UIManager
extends CanvasLayer

@onready var question_manager: QuestionManager = get_node("/root/QuestionManager")
@onready var score_manager: ScoreManager = get_node("/root/ScoreManager")
@onready var difficulty: DifficultyManager = get_node("/root/DifficultyManager")
@onready var game_manager: GameManager = get_node("/root/GameManager") as GameManager

@onready var question_container: Control = $MarginContainer/VBoxContainer/QuestionContainer
@onready var score_label: Label = $MarginContainer/VBoxContainer/HBoxContainer_Score/ScoreLabel
@onready var lives_label: Label = $MarginContainer/VBoxContainer/HBoxContainer_Lives/LivesLabel
@onready var combo_label: Label = $MarginContainer/VBoxContainer/HBoxContainer_Combo/ComboLabel
@onready var question_label: Label = $MarginContainer/VBoxContainer/QuestionContainer/QuestionLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/QuestionContainer/TimerLabel
@onready var alternative_buttons: Array = [
	$MarginContainer/VBoxContainer/QuestionContainer/AlternativesContainer/AltBtn1,
	$MarginContainer/VBoxContainer/QuestionContainer/AlternativesContainer/AltBtn2,
	$MarginContainer/VBoxContainer/QuestionContainer/AlternativesContainer/AltBtn3,
	$MarginContainer/VBoxContainer/QuestionContainer/AlternativesContainer/AltBtn4,
]
@onready var feedback_flash: ColorRect = $FeedbackFlash

## Duração do flash de feedback (issue #37).
const FLASH_DURATION: float = 0.35
## Intensidade máxima do alpha do flash, para não poluir a tela.
const FLASH_ALPHA: float = 0.35
## Amplitude do screen shake ao errar, em unidades do mundo (3D).
const SHAKE_STRENGTH: float = 0.35
## Tempo de decaimento do screen shake.
const SHAKE_DURATION: float = 0.25

var current_alternatives: Array = []
var current_correct_answer: Variant = 0
var selected_index: int = 0
var _timer_node: Timer

func _ready() -> void:
	_timer_node = Timer.new()
	_timer_node.one_shot = true
	add_child(_timer_node)

	question_manager.question_asked.connect(_on_question_asked)
	question_manager.answer_correct.connect(_on_answer_correct)
	question_manager.answer_wrong.connect(_on_answer_wrong)
	question_manager.answer_timeout.connect(_on_answer_timeout)
	score_manager.score_changed.connect(_on_score_changed)
	score_manager.combo_changed.connect(_on_combo_changed)
	game_manager.lives_changed.connect(_on_lives_changed)

	for i in range(alternative_buttons.size()):
		alternative_buttons[i].pressed.connect(func(): _on_answer_button_pressed(i))

	_update_hud()
	_hide_question()


func reset() -> void:
	_update_hud()
	_hide_question()


func _on_question_asked(question: Dictionary) -> void:
	question_label.text = question["text"]
	current_alternatives = question["alternatives"]
	current_correct_answer = question["answer"]
	selected_index = 0
	_update_alternatives_visual()
	_show_question()

	var time_limit: float = difficulty.get_response_time(score_manager.get_score())
	_timer_node.start(time_limit)


func _on_answer_correct(_is_combo: bool, _points: int) -> void:
	_timer_node.stop()
	_hide_question()
	_play_flash(Color(0.35, 0.95, 0.4, FLASH_ALPHA))


func _on_answer_wrong() -> void:
	_timer_node.stop()
	_hide_question()
	_play_flash(Color(1.0, 0.35, 0.25, FLASH_ALPHA))
	_start_shake()


func _on_answer_timeout() -> void:
	_timer_node.stop()
	_hide_question()
	_play_flash(Color(1.0, 0.35, 0.25, FLASH_ALPHA))
	_start_shake()


func _on_lives_changed(_new_lives: int) -> void:
	_update_hud()


func _on_score_changed(_new_score: int) -> void:
	_update_hud()


func _on_combo_changed(_new_combo: int) -> void:
	_update_hud()


func _update_hud() -> void:
	if score_label:
		score_label.text = "Score: %d" % score_manager.get_score()
	if lives_label:
		lives_label.text = "Vidas: %d" % game_manager.lives
	if combo_label:
		var combo: int = score_manager.get_combo()
		combo_label.text = "Combo: x%d" % combo if combo > 1 else "Combo:"


func _show_question() -> void:
	question_container.visible = true
	question_label.visible = true
	for i in range(alternative_buttons.size()):
		alternative_buttons[i].visible = true
		alternative_buttons[i].disabled = false
	_update_alternatives_visual()


func _hide_question() -> void:
	question_container.visible = false
	question_label.visible = false
	for i in range(alternative_buttons.size()):
		alternative_buttons[i].visible = false


func _update_alternatives_visual() -> void:
	for i in range(alternative_buttons.size()):
		if i < current_alternatives.size():
			alternative_buttons[i].text = str(current_alternatives[i])
			alternative_buttons[i].button_group = null
			alternative_buttons[i].button_pressed = (i == selected_index)
		else:
			alternative_buttons[i].text = ""
			alternative_buttons[i].visible = false


func _on_answer_button_pressed(index: int) -> void:
	selected_index = index
	_update_alternatives_visual()
	_submit_selected()


func _submit_selected() -> void:
	if not question_manager.is_question_active():
		return
	if selected_index < current_alternatives.size():
		var answer: Variant = current_alternatives[selected_index]
		question_manager.submit_answer(answer)


func _process(_delta: float) -> void:
	if _timer_node != null and not _timer_node.is_stopped():
		timer_label.text = "Tempo: %.1fs" % _timer_node.time_left


## Mostra um flash de cor sobre a tela e o esvanece (issue #37).
func _play_flash(color: Color) -> void:
	if feedback_flash == null:
		return

	feedback_flash.color = color
	var tween: Tween = create_tween()
	tween.tween_property(feedback_flash, "color:a", 0.0, FLASH_DURATION) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)


## Aciona o screen shake da câmera 3D ao errar a resposta (issue #37).
func _start_shake() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	if camera.has_method("shake"):
		camera.shake(SHAKE_STRENGTH, SHAKE_DURATION)


func _input(event: InputEvent) -> void:
	# Só aceita teclado com uma pergunta ativa e durante a partida: evita
	# navegação fantasmas nas telas de menu e de fim de jogo.
	if game_manager.get_state() != GameManager.State.PLAYING:
		return
	if not question_manager.is_question_active() or current_alternatives.is_empty():
		return

	# Ignora o eco da tecla segurada: senão a seleção salta várias casas.
	if event is InputEventKey and event.pressed and not event.echo:
		var size: int = current_alternatives.size()
		var handled: bool = true

		if event.keycode == KEY_UP or event.keycode == KEY_W or event.keycode == KEY_LEFT or event.keycode == KEY_A:
			selected_index = posmod(selected_index - 1, size)
			_update_alternatives_visual()
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S or event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			selected_index = posmod(selected_index + 1, size)
			_update_alternatives_visual()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_submit_selected()
		else:
			handled = false

		# Evita que o mesmo tecla chegue a outros tratadores durante a resposta.
		if handled:
			get_viewport().set_input_as_handled()


func get_lives() -> int:
	return game_manager.lives

func is_game_over() -> bool:
	return game_manager.lives <= 0
