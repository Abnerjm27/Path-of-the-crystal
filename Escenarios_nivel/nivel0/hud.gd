extends CanvasLayer
@onready var label_monedas = $LabelMonedas
@onready var label_mensaje = $LabelMensaje
@onready var label_dash = $LabelDashEnfriamiento
@onready var boton_dash = $BotonDash
@onready var reloj_enfriamiento = $BotonDash/RelojEnfriamiento
var _en_cooldown := false
var _mostrando_bloqueo := false  # NUEVO: evita que se pisen mensajes si spamean el botón
var _jugador_actual: Node
func _ready():
	label_mensaje.visible = false
	label_dash.visible = false
	# PATCH: oculta el botón de dash táctil en PC (solo tiene sentido en mobile)
	if not OS.has_feature("mobile"):
		boton_dash.visible = false
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
	jugador.dash_bloqueado.connect(_on_dash_bloqueado)  # NUEVO
	jugador.tree_exited.connect(_on_jugador_eliminado)
func _on_jugador_eliminado():
	_jugador_actual = null
	if is_inside_tree():
		_conectar_jugador.call_deferred()
func actualizar_monedas(recogidas: int, total: int):
	label_monedas.text = "Cristales: %d/%d" % [recogidas, total]
func _on_logro_desbloqueado(_id: String, nombre: String, recompensa: int):
	_mostrar_mensaje("🏆 %s: +%d Cristales" % [nombre, recompensa])
func _mostrar_mensaje(texto: String):
	label_mensaje.text = texto
	label_mensaje.visible = true
	await get_tree().create_timer(2.0).timeout
	label_mensaje.visible = false
func _on_dash_iniciado(duracion_cooldown: float):
	_en_cooldown = true
	
	if not OS.has_feature("mobile"):
		label_dash.visible = true
		label_dash.modulate = Color.WHITE  # NUEVO: por si quedó en rojo de un aviso de bloqueo previo
		label_dash.text = "Dash en enfriamiento..."
	
	reloj_enfriamiento.value = 1.0
	var tween = create_tween()
	tween.tween_property(reloj_enfriamiento, "value", 0.0, duracion_cooldown)
func _on_dash_listo():
	_en_cooldown = false
	label_dash.visible = false

# NUEVO: el jugador intentó usar el dash pero todavía no llega al nivel que lo desbloquea
func _on_dash_bloqueado():
	if _en_cooldown or _mostrando_bloqueo:
		return
	_mostrando_bloqueo = true
	label_dash.visible = true
	label_dash.modulate = Color(1.0, 0.4, 0.4)  # rojizo, para diferenciarlo del aviso normal de cooldown
	label_dash.text = "Pasa el nivel %d para desbloquear el dash" % ControladorGlobal.NIVEL_DESBLOQUEO_DASH
	await get_tree().create_timer(1.5).timeout
	_mostrando_bloqueo = false
	if not _en_cooldown:
		label_dash.visible = false
