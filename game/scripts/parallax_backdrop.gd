class_name ParallaxBackdrop
extends Node3D

## Parallax de fundo da partida, feito só para complementar o cenário:
## duas faixas de silhueta — dunas onduladas ao meio e mesas recortadas ao
## fundo — deslocando-se em velocidades diferentes conforme a câmera avança
## e emoldurando o horizonte atrás do deserto.
##
## Godot desenha os nós 2D por cima do 3D no mesmo viewport, então um
## ParallaxBackground 2D cobriria o jogo inteiro. O parallax "2D" é obtido
## aqui com planos verticais achatados dentro do mundo: silhuetas em
## distâncias diferentes ganham a paralaxe natural da perspectiva e ainda
## acompanham a câmera um pouco abaixo da velocidade dela (fator `follow`),
## o que mantém as faixas sempre em quadro mesmo em partidas longas.
##
## A base de cada faixa vai bem abaixo do nível do solo: só as cristas
## aparecem, acima da borda do chão — assim não sobra fresta de céu entre
## o deserto e a silhueta. As nuvens 3D (mais próximas) seguem passando
## na frente das faixas, reforçando a profundidade.

@export_group("Faixas")
## Distância lateral da faixa das dunas até a pista, em m (lado -X, que é
## o que a câmera enxerga).
@export var mid_distance_x: float = 65.0
## Distância lateral da faixa das mesas, em m.
@export var far_distance_x: float = 110.0
## Quanto da viagem da câmera a faixa repete. Menos de 1.0 faz a faixa
## deslizar mais devagar que a corrida — é o parallax.
@export var mid_follow: float = 0.9
@export var far_follow: float = 0.95
## Comprimento de cada faixa ao longo do eixo Z.
@export var layer_length: float = 7000.0
## Distância atrás do ponto de vista em que as faixas começam.
@export var start_offset: float = 220.0
## Semente dos perfis de silhueta (mesmo deserto a cada partida).
@export var profile_seed: int = 7331

## Passo de amostragem do perfil, em m.
const STEP_Z: float = 8.0
## Base das silhuetas: abaixo do solo para não aparecer céu sob a borda.
const MID_BASE_Y: float = -10.0
const FAR_BASE_Y: float = -16.0
## Dunas quentes mais próximas; mesas mais claras, já com neblina.
const MID_COLOR := Color(0.804, 0.612, 0.435)
const FAR_COLOR := Color(0.784, 0.706, 0.608)

var _layers: Array[Node3D] = []
var _follows: Array[float] = []
var _origin_z: float = 0.0
var _start_camera_z: float = 0.0
var _tracking: bool = false


func _ready() -> void:
	_add_layer("Dunas", mid_distance_x, mid_follow, MID_BASE_Y, MID_COLOR, false)
	_add_layer("Mesas", far_distance_x, far_follow, FAR_BASE_Y, FAR_COLOR, true)

	var camera := get_viewport().get_camera_3d() if get_viewport() else null
	if camera != null:
		_begin_tracking(camera)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	if not _tracking:
		_begin_tracking(camera)

	var travel: float = camera.global_position.z - _start_camera_z
	for index in _layers.size():
		_layers[index].position.z = _origin_z + travel * _follows[index]


func _begin_tracking(camera: Camera3D) -> void:
	_start_camera_z = camera.global_position.z
	_origin_z = _start_camera_z - start_offset
	_tracking = true
	for index in _layers.size():
		_layers[index].position.z = _origin_z


func _add_layer(
	layer_name: String,
	distance_x: float,
	follow: float,
	base_y: float,
	color: Color,
	mesas: bool
) -> void:
	var layer := Node3D.new()
	layer.name = layer_name
	layer.position.x = -absf(distance_x)
	add_child(layer)
	layer.add_child(_build_ridge(base_y, color, mesas))
	_layers.append(layer)
	_follows.append(follow)


## Gera a silhueta como uma tira de triângulos: uma linha de base fixa e
## uma crista variando ao longo do Z. As mesas usam um passeio aleatório
## quantizado em degraus (platações e escarpas); as dunas usam senoides
## somadas (ondulação suave).
func _build_ridge(base_y: float, color: Color, mesas: bool) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var steps := ceili(layer_length / STEP_Z)
	var rng := RandomNumberGenerator.new()
	rng.seed = profile_seed
	var walk_y := -7.0

	for index in steps + 1:
		var z: float = -layer_length * 0.5 + float(index) * STEP_Z
		var crest_y: float
		if mesas:
			walk_y = clampf(walk_y + rng.randf_range(-3.5, 3.5), -13.0, 0.5)
			crest_y = roundf(walk_y / 3.0) * 3.0
		else:
			crest_y = (
				-4.5
				+ 2.8 * sin(z * 0.0062 + 1.7)
				+ 1.9 * sin(z * 0.0131 + 0.4)
			)
		tool.add_vertex(Vector3(0.0, base_y, z))
		tool.add_vertex(Vector3(0.0, crest_y, z))

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Silhouette"
	mesh_instance.mesh = tool.commit()
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance
