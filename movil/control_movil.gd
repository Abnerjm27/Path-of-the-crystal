extends CanvasLayer

@onready var label_dash = $LabelDashEnfriamiento
@onready var boton_dash = $BotonDash
@onready var reloj_enfriamiento = $BotonDash/RelojEnfriamiento
@onready var boton_volar = $BotonVolar   # AJUSTA el nombre/ruta real del nodo

var _en_cooldown := false
var _mostrando_bloqueo := false  # evita que se pisen mensajes si spamean el botón
var _jugador_actual: Node

func _ready():
	label_dash.visible = false
	# oculta los botones táctiles en PC (solo tienen sentido en mobile)
	if not OS.has_feature("mobile"):
		boton_dash.visible = false
		if boton_volar:
			boton_volar.visible = false
	reloj_enfriamiento.value = 0.0
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
	jugador.dash_bloqueado.connect(_on_dash_bloqueado)
	jugador.vuelo_bloqueado.connect(_on_vuelo_bloqueado)
	jugador.tree_exited.connect(_on_jugador_eliminado)

func _on_jugador_eliminado():
	_jugador_actual = null
	if is_inside_tree():
		_conectar_jugador.call_deferred()

func _on_dash_iniciado(duracion_cooldown: float):
	_en_cooldown = true
	label_dash.visible = true
	label_dash.modulate = Color.WHITE
	label_dash.text = "Dash en enfriamiento..."
	reloj_enfriamiento.value = 1.0
	var tween = create_tween()
	tween.tween_property(reloj_enfriamiento, "value", 0.0, duracion_cooldown)

func _on_dash_listo():
	_en_cooldown = false
	label_dash.visible = false

func _on_dash_bloqueado():
	if _en_cooldown or _mostrando_bloqueo:
		return
	_mostrando_bloqueo = true
	label_dash.visible = true
	label_dash.modulate = Color(1.0, 0.4, 0.4)
	label_dash.text = "Pasa el nivel %d para desbloquear el dash" % ControladorGlobal.NIVEL_DESBLOQUEO_DASH
	await get_tree().create_timer(1.5).timeout
	_mostrando_bloqueo = false
	if not _en_cooldown:
		label_dash.visible = false

func _on_vuelo_bloqueado():
	if _en_cooldown or _mostrando_bloqueo:
		return
	_mostrando_bloqueo = true
	label_dash.visible = true
	label_dash.modulate = Color(1.0, 0.4, 0.4)
	label_dash.text = "Pasa el nivel %d para desbloquear el vuelo" % ControladorGlobal.NIVEL_DESBLOQUEO_VUELO
	await get_tree().create_timer(1.5).timeout
	_mostrando_bloqueo = false
	if not _en_cooldown:
		label_dash.visible = false
