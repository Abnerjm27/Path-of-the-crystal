extends CanvasLayer
@onready var label_monedas = $LabelMonedas
@onready var label_mensaje = $LabelMensaje
var _jugador_actual: Node
func _ready():
	label_mensaje.visible = false
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
