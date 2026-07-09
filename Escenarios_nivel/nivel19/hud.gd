extends CanvasLayer

@onready var label_monedas = $LabelMonedas
@onready var label_mensaje = $LabelMensaje

func _ready():
	label_mensaje.visible = false
	$Minimapa/SubViewportContainer/SubViewport.world_2d = get_viewport().world_2d
	ControladorLogros.logro_desbloqueado.connect(_on_logro_desbloqueado)

func actualizar_monedas(recogidas: int, total: int):
	label_monedas.text = "Monedas: %d/%d" % [recogidas, total]

func _on_logro_desbloqueado(id: String, nombre: String, recompensa: int):
	_mostrar_mensaje("🏆 %s: +%d monedas" % [nombre, recompensa])

func _mostrar_mensaje(texto: String):
	label_mensaje.text = texto
	label_mensaje.visible = true
	await get_tree().create_timer(2.0).timeout
	label_mensaje.visible = false
