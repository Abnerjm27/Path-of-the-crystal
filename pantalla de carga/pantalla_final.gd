extends CanvasLayer

signal reiniciar
signal salir

@onready var boton_reiniciar = $BotonReiniciar
@onready var boton_salir = $BotonSalir
@onready var boton_siguiente = $BotonSiguienteNivel
@onready var label_monedas = $LabelMonedas
@onready var imagen_felicidades = $ImagenFelicidades
@onready var label_logro = $LabelLogro

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	boton_reiniciar.pressed.connect(_on_reiniciar_pressed)
	boton_salir.pressed.connect(_on_salir_pressed)
	label_logro.visible = false
	ControladorLogros.logro_desbloqueado.connect(_on_logro_desbloqueado)

func mostrar(recogidas: int, total: int, es_ultimo_nivel: bool = false):
	label_monedas.text = "Monedas: %d/%d" % [recogidas, total]
	label_logro.visible = false  # oculta cualquier mensaje viejo al mostrar de nuevo
	
	if es_ultimo_nivel:
		boton_siguiente.visible = false
		imagen_felicidades.visible = true
	else:
		boton_siguiente.visible = true
		imagen_felicidades.visible = false
	
	visible = true
	get_tree().paused = true

func _on_logro_desbloqueado(_id: String, nombre: String, recompensa: int):
	if visible:  # solo muestra el aviso si esta pantalla está activa en este momento
		label_logro.text = "🏆 %s: +%d monedas" % [nombre, recompensa]
		label_logro.visible = true

func _on_reiniciar_pressed():
	visible = false
	get_tree().paused = false
	reiniciar.emit()

func _on_salir_pressed():
	visible = false
	get_tree().paused = false
	salir.emit()
