class_name Sfx
extends RefCounted

## Efeitos sonoros curtos da interface. O player é preso à raiz da árvore
## (e não à cena) para que o som continue tocando mesmo quando a cena atual
## é trocada — caso dos botões "Jogar", "Como Jogar", "Voltar" e "Menu".

const CLICK: AudioStream = preload("res://assets/audio/click.wav")
const JUMP: AudioStream = preload("res://assets/audio/jump.wav")
const CORRECT: AudioStream = preload("res://assets/audio/correct.wav")
const WRONG: AudioStream = preload("res://assets/audio/wrong.wav")
const HIT: AudioStream = preload("res://assets/audio/hit.mp3")


static func play_click(tree: SceneTree) -> void:
	play(tree, CLICK)


static func play_jump(tree: SceneTree) -> void:
	play(tree, JUMP, -2.0)


static func play_correct(tree: SceneTree) -> void:
	play(tree, CORRECT, -2.0)


static func play_wrong(tree: SceneTree) -> void:
	play(tree, WRONG, -2.0)


static func play_hit(tree: SceneTree) -> void:
	play(tree, HIT, -3.0)


static func play(tree: SceneTree, stream: AudioStream, volume_db: float = 0.0) -> void:
	if tree == null or stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(player)

	# O player se libera sozinho ao terminar; a cena que pediu o som pode
	# desaparecer antes disso sem interromper o áudio.
	player.finished.connect(player.queue_free)
	player.play()
