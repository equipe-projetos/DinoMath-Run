extends Node

## Trilha sonora de fundo persistente. Registrada como autoload, o nó
## atravessa as trocas de cena: a música começa no menu principal e
## continua em Como Jogar e durante a partida. Ela só para quando o
## jogador perde (Game Over) e volta a tocar ao reiniciar a partida ou
## retornar ao menu.
##
## Enquanto uma pergunta de matemática está na tela o volume é reduzido
## (duck) para os efeitos sonoros respirarem, e volta ao normal quando o
## jogador acerta, erra ou o tempo esgota.

const MUSIC_STREAM: AudioStream = preload("res://assets/audio/mfcc-retro-arcade-game-music-297305.mp3")

## Volume normal da trilha, em dB.
const VOLUME_DB: float = -6.0
## Volume reduzido enquanto a pergunta está na tela, em dB.
const DUCK_VOLUME_DB: float = -14.0
## Duração do fade entre os dois volumes, em segundos.
const VOLUME_FADE_TIME: float = 0.35

var _player: AudioStreamPlayer
var _volume_tween: Tween


func _ready() -> void:
	# Continua ativo com a árvore pausada (menu de pausa da partida).
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.stream = MUSIC_STREAM
	_player.volume_db = VOLUME_DB
	_player.bus = "Master"
	add_child(_player)

	# A trilha precisa repetir indefinidamente durante toda a sessão.
	if _player.stream is AudioStreamMP3:
		(_player.stream as AudioStreamMP3).loop = true

	play_music()


## Começa a tocar a trilha do início se ela estiver parada. Chamado no
## menu principal e quando uma nova partida começa. Se a música já estiver
## tocando, apenas garante o volume normal (a partida segue com a trilha
## em curso, sem reiniciar).
func play_music() -> void:
	_kill_volume_tween()
	_player.volume_db = VOLUME_DB
	if _player.playing:
		return
	_player.play()


## Para a trilha (derrota / Game Over).
func stop_music() -> void:
	_kill_volume_tween()
	_player.volume_db = VOLUME_DB
	_player.stop()


## Reduz o volume enquanto a pergunta de matemática está na tela.
func duck() -> void:
	_fade_volume_to(DUCK_VOLUME_DB)


## Volta o volume ao normal quando o jogador acerta, erra ou o tempo
## esgota.
func unduck() -> void:
	_fade_volume_to(VOLUME_DB)


func _fade_volume_to(target_db: float) -> void:
	_kill_volume_tween()
	_volume_tween = create_tween()
	_volume_tween.tween_property(_player, "volume_db", target_db, VOLUME_FADE_TIME)


func _kill_volume_tween() -> void:
	if _volume_tween != null and _volume_tween.is_valid():
		_volume_tween.kill()
	_volume_tween = null
