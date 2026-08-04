extends Control

@export var velocidad_scroll: float = 50.0  # píxeles por segundo
@export var escena_menu_principal: String = "res://escenas/menuprincipal/menu_principal.tscn"

@onready var contenedor: VBoxContainer = $ContenedorCreditos
@onready var boton_volver = $BotonVolver

var altura_pantalla: float

func _ready() -> void:
	altura_pantalla = get_viewport_rect().size.y
	contenedor.position.y = altura_pantalla
	boton_volver.pressed.connect(_volver_al_menu)
	await get_tree().process_frame  # para que el VBoxContainer calcule su tamaño real

func _process(delta: float) -> void:
	contenedor.position.y -= velocidad_scroll * delta

	# Cuando termina de subir todo el texto, lo dejamos quieto arriba (o lo reinicias, a tu gusto)
	if contenedor.position.y + contenedor.size.y < 0:
		set_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_volver_al_menu()

func _volver_al_menu() -> void:
	ControladorCarga.ir_a_escena(escena_menu_principal)
