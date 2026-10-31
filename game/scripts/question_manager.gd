class_name QuestionManager
extends Node

signal question_asked(question: Dictionary)
signal answer_correct(is_combo: bool, points: int)
signal answer_wrong()
signal answer_timeout()
signal cycle_finished()

enum State { IDLE, ASKING, WAITING, RESULT }

var current_state: State = State.IDLE

var _current_question: Dictionary = {}
var _current_answer: Variant = 0
var _question_active: bool = false
var _timer_node: Timer

@onready var difficulty: DifficultyManager = get_node("/root/DifficultyManager")
@onready var score: ScoreManager = get_node("/root/ScoreManager")

func _ready() -> void:
	_timer_node = Timer.new()
	_timer_node.one_shot = true
	_timer_node.timeout.connect(_on_timeout)
	add_child(_timer_node)

func start_question() -> void:
	if _question_active:
		return
	_current_question = generate_question(difficulty.get_current_score())
	_current_answer = _current_question["answer"]
	_question_active = true
	current_state = State.WAITING
	var response_time: float = difficulty.get_response_time(difficulty.get_current_score())
	_timer_node.start(response_time)
	question_asked.emit(_current_question)

func submit_answer(answer: Variant) -> void:
	if not _question_active or current_state != State.WAITING:
		return
	_timer_node.stop()
	_question_active = false
	current_state = State.RESULT
	if answer == _current_answer:
		_on_correct()
	else:
		_on_wrong()

func _on_correct() -> void:
	score.add_combo_points()
	answer_correct.emit(score.get_combo() > 1, score.get_score())
	var player: Node = get_tree().get_first_node_in_group("player")
	if player is Player:
		player.request_jump()
	current_state = State.IDLE
	cycle_finished.emit()

func _on_wrong() -> void:
	score.reset_combo()
	answer_wrong.emit()
	current_state = State.IDLE
	cycle_finished.emit()

func _on_timeout() -> void:
	if not _question_active:
		return
	_question_active = false
	score.reset_combo()
	answer_timeout.emit()
	current_state = State.IDLE
	cycle_finished.emit()

func cancel_question() -> void:
	if not _question_active:
		return
	_timer_node.stop()
	_question_active = false
	current_state = State.IDLE

func is_question_active() -> bool:
	return _question_active

func get_current_answer() -> Variant:
	return _current_answer

func generate_question(difficulty_score: int) -> Dictionary:
	var operations: Array = difficulty.get_allowed_operations(difficulty_score)
	var op: String = operations[randi() % operations.size()]
	var a: int = 0
	var b: int = 0
	var result: int = 0
	var text: String = ""
	var answer_value: Variant = 0
	var unknown_type: String = "result"

	var unknown_chance: float = difficulty.get_unknown_chance(difficulty_score)
	if randf() < unknown_chance:
		unknown_type = _pick_unknown_type(difficulty_score)

	match unknown_type:
		"result":
			match op:
				"+":
					a = randi() % 100
					b = randi() % 100
					result = a + b
					text = "%d + %d = ?" % [a, b]
				"-":
					a = randi() % 100
					b = randi() % 100
					if a < b:
						var temp: int = a
						a = b
						b = temp
					result = a - b
					text = "%d - %d = ?" % [a, b]
				"*":
					a = randi() % 12 + 1
					b = randi() % 12 + 1
					result = a * b
					text = "%d × %d = ?" % [a, b]
				"/":
					b = randi() % 9 + 1
					result = randi() % 12 + 1
					a = b * result
					text = "%d ÷ %d = ?" % [a, b]
			answer_value = result
		"operand1":
			match op:
				"+":
					b = randi() % 100
					result = randi() % 100 + b
					a = result - b
					text = "? + %d = %d" % [b, result]
				"-":
					b = randi() % 100
					result = randi() % 100
					a = result + b
					text = "? - %d = %d" % [b, result]
				"*":
					b = randi() % 12 + 1
					result = randi() % 12 + 1
					a = b * result
					text = "? × %d = %d" % [b, result]
				"/":
					b = randi() % 9 + 1
					result = randi() % 12 + 1
					a = b * result
					text = "? ÷ %d = %d" % [b, result]
			answer_value = a
		"operand2":
			match op:
				"+":
					a = randi() % 100
					result = randi() % 100 + a
					b = result - a
					text = "%d + ? = %d" % [a, result]
				"-":
					a = randi() % 100
					result = randi() % 100
					b = a - result
					if b < 0:
						b = -b
						result = a - b
					text = "%d - ? = %d" % [a, result]
				"*":
					a = randi() % 12 + 1
					b = randi() % 12 + 1
					result = a * b
					text = "%d × ? = %d" % [a, result]
				"/":
					b = randi() % 9 + 1
					result = randi() % 12 + 1
					a = b * result
					text = "%d ÷ ? = %d" % [a, result]
			answer_value = b
		"operator":
			a = randi() % 20 + 1
			b = randi() % 9 + 1
			op = operations[randi() % operations.size()]
			match op:
				"+":
					result = a + b
				"-":
					if a < b:
						var temp: int = a
						a = b
						b = temp
					result = a - b
				"*":
					a = randi() % 12 + 1
					b = randi() % 12 + 1
					result = a * b
				"/":
					b = randi() % 9 + 1
					result = randi() % 12 + 1
					a = b * result
			text = "%d ? %d = %d" % [a, b, result]
			answer_value = op

	var alternatives: Array
	if unknown_type == "operator":
		alternatives = _generate_operator_alternatives(str(answer_value))
	else:
		alternatives = _generate_alternatives(int(answer_value))
	var question: Dictionary = {
		"text": text,
		"answer": answer_value,
		"alternatives": alternatives,
		"operation": op,
		"unknown_type": unknown_type
	}
	return question

func _pick_unknown_type(difficulty_score: int) -> String:
	var tier: int
	if difficulty_score >= 100:
		tier = 2
	elif difficulty_score >= 50:
		tier = 1
	else:
		tier = 0
	var types: Array = []
	if tier >= 1:
		types.append("operand1")
		types.append("operand2")
	if tier >= 2:
		types.append("operator")
	if types.size() > 0:
		return types[randi() % types.size()]
	return "result"

func _generate_alternatives(correct: int) -> Array:
	var alternatives: Array = [correct]
	while alternatives.size() < 4:
		var distractor: int = correct + (randi() % 10 - 5)
		if distractor <= 0:
			distractor = correct + (randi() % 5 + 1)
		if distractor in alternatives:
			continue
		alternatives.append(distractor)
	alternatives.shuffle()
	return alternatives


func _generate_operator_alternatives(correct_op: String) -> Array:
	var all_ops: Array = ["+", "-", "*", "/"]
	var alternatives: Array = [correct_op]
	for op in all_ops:
		if op != correct_op and alternatives.size() < 4:
			alternatives.append(op)
	alternatives.shuffle()
	return alternatives
