extends Node3D

## Névoa que esconde o fim do chão dando a continuidade do deserto.
##
## A borda lateral do deserto aparece na tela como uma linha dura: o chão
## escuro termina e, atrás dele, só há as dunas claras do parallax e o céu.
##
## A névoa é uma cortina vertical pendurada exatamente na aresta do chão.
## Como é 3D, o teste de profundidade faz o trabalho sozinho:
##   - o chão e tudo que está na pista (dino, cactos, pedras) fica NA FRENTE
##     e nunca é lavado — nem durante o salto;
##   - atrás da cortina só existe fundo (dunas, parallax, céu), que recebe a
##     névoa e passa a parecer deserto continuando até o horizonte.
##
## O alfa é máximo rente ao nível do solo (é ali que o corte aparece) e
## some suavemente subindo, então a cortina nunca é vista contra o céu.
##
## (Um CanvasLayer 2D desenharia a mesma faixa POR CIMA do dino — ele vira
## um fantasma branco a cada salto. Mesma ideia do parallax: visual 2D,
## geometria 3D.)

## Alfa máximo junto à borda do chão.
@export var peak_alpha: float = 0.92
## Cor da névoa rente ao solo e, mais acima, a tinta clara das dunas.
@export var haze_color := Color(0.909804, 0.827451, 0.678431)
@export var haze_color_top := Color(0.94902, 0.905882, 0.819608)
## Altura da cortina (o topo fica invisível: o alfa já zerou bem antes).
@export var curtain_height: float = 8.0
## Comprimento da cortina ao longo de Z (cobre todo o horizonte visível).
@export var curtain_length: float = 700.0
## Base um pouco abaixo do solo: essa faixa nunca aparece em tela, mas
## garante que nenhuma fresta abra na linha de corte.
@export var base_y: float = 0.1
## Alfa máximo até esta altura (mundo) e zero a partir daqui.
@export var peak_top_y: float = 1.3
@export var fade_top_y: float = 3.0
## A cortina acompanha a câmera em Z (é uniforme, então o movimento não
## muda nada visualmente — só evita sair do campo visível).
@export var camera_z_offset: float = -220.0

## Névoa calculada por fragmento (sem textura: filtragem/mipmap em um quad
## visto em ângulo rasante deixava uma linha fina na borda superior).
const MIST_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 haze_color : source_color = vec4(0.909804, 0.827451, 0.678431, 0.92);
uniform vec4 haze_top : source_color = vec4(0.94902, 0.905882, 0.819608, 0.0);
uniform float base_y = 0.1;
uniform float peak_top_y = 1.3;
uniform float fade_top_y = 3.0;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	// Alfa máximo rente ao solo, sumindo em suavidade até fade_top_y.
	float t = 1.0;
	if (world_y > peak_top_y) {
		float u = (world_y - peak_top_y) / max(fade_top_y - peak_top_y, 0.001);
		t = 1.0 - smoothstep(0.0, 1.0, u);
	}
	ALBEDO = mix(
		haze_color.rgb,
		haze_top.rgb,
		clamp((world_y - base_y) / max(fade_top_y - base_y, 0.001), 0.0, 1.0)
	);
	ALPHA = haze_color.a * t;
}
"""

var _camera: Camera3D
var _edge_x: float = -15.0455


func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	_resolve_edge()
	_build_curtain()
	_update_position()


func _process(_delta: float) -> void:
	_update_position()


## Aresta esquerda do deserto: AABB real do mesh do primeiro segmento de
## chão (largura nominal alargada como fallback).
func _resolve_edge() -> void:
	var ground: Node = get_parent().get_node_or_null("GroundManager")
	if ground == null or ground.get_child_count() == 0:
		return

	var mesh_instance: MeshInstance3D = _find_mesh(ground.get_child(0))
	if mesh_instance == null or mesh_instance.mesh == null:
		return

	var aabb: AABB = mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
	_edge_x = aabb.position.x


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh(child)
		if found != null:
			return found
	return null


func _update_position() -> void:
	if _camera != null and is_instance_valid(_camera):
		global_position.z = _camera.global_position.z + camera_z_offset
	global_position.x = _edge_x


## Gera o quad vertical com o gradiente de névoa (alfa máximo embaixo,
## sumindo ao chegar na altura das dunas).
func _build_curtain() -> void:
	var half: float = curtain_length * 0.5
	var top: float = base_y + curtain_height

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# uv.x percorre Z (só para completar); uv.y percorre a altura.
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(0.0, base_y, -half))
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(Vector3(0.0, base_y, half))
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(Vector3(0.0, top, half))
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(Vector3(0.0, top, -half))

	st.add_index(0)
	st.add_index(1)
	st.add_index(2)
	st.add_index(0)
	st.add_index(2)
	st.add_index(3)

	var mesh: Mesh = st.commit()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mist"
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = _build_material()
	add_child(mesh_instance)


func _build_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = MIST_SHADER

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(
		"haze_color", Color(haze_color.r, haze_color.g, haze_color.b, peak_alpha)
	)
	material.set_shader_parameter("haze_top", haze_color_top)
	material.set_shader_parameter("base_y", base_y)
	material.set_shader_parameter("peak_top_y", peak_top_y)
	material.set_shader_parameter("fade_top_y", fade_top_y)
	return material
