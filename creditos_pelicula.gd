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
	
	_configurar_navegacion_mando()
	
	await get_tree().process_frame  # para que el VBoxContainer calcule su tamaño real

func _process(delta: float) -> void:
	contenedor.position.y -= velocidad_scroll * delta

	# Cuando termina de subir todo el texto, lo dejamos quieto arriba
	if contenedor.position.y + contenedor.size.y < 0:
		set_process(false)

func _configurar_navegacion_mando() -> void:
	# Asegurar que el botón volver pueda recibir el foco
	boton_volver.focus_mode = Control.FOCUS_ALL
	
	# Registrar en el Autoload para los efectos visuales (escala/brillo)
	NavegacionMando.conectar_efecto_foco([boton_volver])
	
	# Enfocar inmediatamente el botón volver
	NavegacionMando.enfocar_con_seguridad(boton_volver)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_volver_al_menu()

func _volver_al_menu() -> void:
	ControladorCarga.ir_a_escena(escena_menu_principal)
