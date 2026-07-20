extends AnimatableBody2D  # antes Node2D — cambiar el tipo de nodo raíz también en el editor

@onready var zona_peligro: Area2D = $zonapeligrosa
@onready var zona_segura: Area2D = $zonasegura

var _jugador_en_zona_segura := false

func _ready() -> void:
	zona_segura.body_entered.connect(_on_zona_segura_entrada)
	zona_segura.body_exited.connect(_on_zona_segura_salida)
	zona_peligro.body_entered.connect(_on_zona_peligro_entrada)

func _on_zona_segura_entrada(cuerpo: Node2D) -> void:
	if cuerpo.is_in_group("personajes"):
		_jugador_en_zona_segura = true

func _on_zona_segura_salida(cuerpo: Node2D) -> void:
	if cuerpo.is_in_group("personajes"):
		_jugador_en_zona_segura = false

func _on_zona_peligro_entrada(cuerpo: Node2D) -> void:
	if not cuerpo.is_in_group("personajes"):
		return
	if _jugador_en_zona_segura:
		return  # está parado en el lomo, zona segura anula el daño
	if cuerpo.has_method("morir"):
		cuerpo.morir()
