extends TextureButton

@export var numero_nivel: int = 1
@export var ruta_escena_principal: String

@onready var icono_candado: TextureRect = $IconoCandado

func _ready() -> void:
	pressed.connect(jugar)
	_actualizar_estado()

func _actualizar_estado():
	var desbloqueado = numero_nivel <= ControladorGlobal.nivel
	disabled = not desbloqueado
	modulate = Color(1, 1, 1, 1) if desbloqueado else Color(0.5, 0.5, 0.5, 1)
	icono_candado.visible = not desbloqueado

func jugar():
	if disabled:
		return
	ControladorCarga.ir_a_escena(ruta_escena_principal)
