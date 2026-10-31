class_name UIManager
extends CanvasLayer

@onready var question_manager: QuestionManager = get_node("/root/QuestionManager")
@onready var score_manager: ScoreManager = get_node("/root/ScoreManager")
@onready var difficulty: DifficultyManager = get_node("/root/DifficultyManager")

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

@export_group("Configuração")
@export var max_lives: int = 3
@export var response_time: float = 5.0

var current_lives: int = 3
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

	for i in range(alternative_buttons.size()):
		alternative_buttons[i].pressed.connect(func(): _on_answer_button_pressed(i))

	current_lives = max_lives
	_update_hud()
	_hide_question()


func reset() -> void:
	current_lives = max_lives
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


func _on_answer_wrong() -> void:
	_timer_node.stop()
	current_lives -= 1
	_update_hud()
	_hide_question()


func _on_answer_timeout() -> void:
	_timer_node.stop()
	current_lives -= 1
	_update_hud()
	_hide_question()


func _on_score_changed(_new_score: int) -> void:
	_update_hud()


func _on_combo_changed(_new_combo: int) -> void:
	_update_hud()


func _update_hud() -> void:
	if score_label:
		score_label.text = "Score: %d" % score_manager.get_score()
	if lives_label:
		lives_label.text = "Vidas: %d" % current_lives
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
	if _timer_node == null or _timer_node.is_stopped():
		return
	timer_label.text = "Tempo: %.1fs" % _timer_node.time_left


func _input(event: InputEvent) -> void:
	if not question_manager.is_question_active() or current_alternatives.is_empty():
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP or event.keycode == KEY_W:
			selected_index = (selected_index - 1) % current_alternatives.size()
			_update_alternatives_visual()
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			selected_index = (selected_index + 1) % current_alternatives.size()
			_update_alternatives_visual()
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			selected_index = (selected_index - 1) % current_alternatives.size()
			_update_alternatives_visual()
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			selected_index = (selected_index + 1) % current_alternatives.size()
			_update_alternatives_visual()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_submit_selected()


func get_lives() -> int:
	return current_lives

func is_game_over() -> bool:
	return current_lives <= 0
