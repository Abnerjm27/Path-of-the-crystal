extends AnimatableBody2D

@export var flip_h_manual: bool = false:
	set(valor):
		flip_h_manual = valor
		if animacion:
			animacion.flip_h = valor

@onready var zona_peligro: Area2D = $zonapeligrosa
@onready var zona_segura: Area2D = $zonasegura
@onready var animador: AnimationPlayer = $AnimationPlayer
@onready var animacion: AnimatedSprite2D = $AnimatedSprite2D

var _jugador_en_zona_segura := false

func _ready() -> void:
	animacion.flip_h = flip_h_manual
	zona_segura.body_entered.connect(_on_zona_segura_entrada)
	zona_segura.body_exited.connect(_on_zona_segura_salida)
	zona_peligro.body_entered.connect(_on_zona_peligro_entrada)
	# NUEVO: se suma al grupo central en vez de tener su propio RPC
	animador.add_to_group(NetworkDiscovery.GRUPO_ANIMADORES_SINCRONIZABLES)

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
		return
	if cuerpo.has_method("morir"):
		cuerpo.morir()
