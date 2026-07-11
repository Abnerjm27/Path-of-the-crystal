extends CanvasLayer

@onready var label_monedas = $LabelMonedas
@onready var label_mensaje = $LabelMensaje
@onready var label_dash = $LabelDashEnfriamiento
@onready var reloj_enfriamiento = $BotonDash/RelojEnfriamiento

var _en_cooldown := false
var _jugador_actual: Node

func _ready():
	label_mensaje.visible = false
	label_dash.visible = false
	reloj_enfriamiento.value = 0.0
	ControladorLogros.logro_desbloqueado.connect(_on_logro_desbloqueado)
	
	_conectar_jugador()

func _conectar_jugador():
	if not is_inside_tree():
		return
	
	var jugador = get_tree().get_first_node_in_group("personajes")
	if not jugador:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_conectar_jugador()
		return
	
	_jugador_actual = jugador
	jugador.dash_iniciado.connect(_on_dash_iniciado)
	jugador.dash_listo.connect(_on_dash_listo)
	jugador.tree_exited.connect(_on_jugador_eliminado)

func _on_jugador_eliminado():
	_jugador_actual = null
	if is_inside_tree():
		_conectar_jugador.call_deferred()

func actualizar_monedas(recogidas: int, total: int):
	label_monedas.text = "Monedas: %d/%d" % [recogidas, total]

func _on_logro_desbloqueado(_id: String, nombre: String, recompensa: int):
	_mostrar_mensaje("🏆 %s: +%d monedas" % [nombre, recompensa])

func _mostrar_mensaje(texto: String):
	label_mensaje.text = texto
	label_mensaje.visible = true
	await get_tree().create_timer(2.0).timeout
	label_mensaje.visible = false

func _on_dash_iniciado(duracion_cooldown: float):
	_en_cooldown = true
	
	if not OS.has_feature("mobile"):
		label_dash.visible = true
		label_dash.text = "Dash en enfriamiento..."
	
	reloj_enfriamiento.value = 1.0
	var tween = create_tween()
	tween.tween_property(reloj_enfriamiento, "value", 0.0, duracion_cooldown)

func _on_dash_listo():
	_en_cooldown = false
	label_dash.visible = false
