extends CanvasLayer

signal reiniciar
signal salir

@onready var boton_reiniciar = $BotonReiniciar
@onready var boton_salir = $BotonSalir

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	boton_reiniciar.pressed.connect(_on_reiniciar_pressed)
	boton_salir.pressed.connect(_on_salir_pressed)

func mostrar():
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
