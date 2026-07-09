extends CanvasLayer

signal reiniciar
signal salir

@onready var boton_reiniciar = $BotonReiniciar
@onready var boton_salir = $BotonSalir
@onready var boton_siguiente = $BotonSiguienteNivel
@onready var label_monedas = $LabelMonedas
@onready var label_mensaje = $LabelMensaje  # nuevo: para el mensaje especial

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	boton_reiniciar.pressed.connect(_on_reiniciar_pressed)
	boton_salir.pressed.connect(_on_salir_pressed)

func mostrar(recogidas: int, total: int, es_ultimo_nivel: bool = false):
	label_monedas.text = "Monedas: %d/%d" % [recogidas, total]
	
	if es_ultimo_nivel:
		boton_siguiente.visible = false
		label_mensaje.visible = true
		label_mensaje.text = "¡Felicidades, completaste el juego!"
	else:
		boton_siguiente.visible = true
		label_mensaje.visible = false
	
	visible = true
	get_tree().paused = true

func _on_reiniciar_pressed():
	visible = false
	get_tree().paused = false
	reiniciar.emit()

func _on_salir_pressed():
	visible = false
	get_tree().paused = false
	salir.emit()
