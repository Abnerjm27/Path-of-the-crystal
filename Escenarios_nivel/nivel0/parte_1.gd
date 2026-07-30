extends TextureButton
@export var numero_nivel: int = 1
@export var ruta_escena_principal: String
@onready var icono_candado: TextureRect = $IconoCandado

func _ready() -> void:
	pressed.connect(jugar)
	actualizar_estado()  

func actualizar_estado():
	var progreso_actual = ControladorGlobal.nivel_cooperativo if ControladorGlobal.modo_cooperativo_activo else ControladorGlobal.nivel
	var desbloqueado = numero_nivel <= progreso_actual
	disabled = not desbloqueado
	modulate = Color(1, 1, 1, 1) if desbloqueado else Color(0.5, 0.5, 0.5, 1)
	icono_candado.visible = not desbloqueado
	focus_mode = Control.FOCUS_ALL if desbloqueado else Control.FOCUS_NONE

	# NUEVO: en red, solo el host puede elegir nivel
	if ControladorGlobal.es_partida_en_red and not NetworkDiscovery.soy_host():
		disabled = true
		focus_mode = Control.FOCUS_NONE

func jugar():
	if disabled:
		return
	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.enviar_nivel_elegido(ruta_escena_principal)
	else:
		ControladorCarga.ir_a_escena(ruta_escena_principal)
