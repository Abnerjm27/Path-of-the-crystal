extends Node2D
class_name RayoCielo

const DURACION_ADVERTENCIA: float = 0.7
const FRAME_IMPACTO_MORTAL: int = 3  # frame del sheet "rayo" donde ya debería matar (la explosión de base)

@onready var circulo: AnimatedSprite2D = $AnimatedSprite2D_Circulo
@onready var rayo: AnimatedSprite2D = $AnimatedSprite2D_Rayo
@onready var area_golpe: Area2D = $AreaGolpe

var _ya_golpeo: bool = false

func _ready():
	rayo.visible = false
	area_golpe.monitoring = false
	area_golpe.body_entered.connect(_on_area_golpe_body_entered)

	circulo.play("advertencia")
	await get_tree().create_timer(DURACION_ADVERTENCIA).timeout

	circulo.visible = false
	rayo.visible = true
	rayo.play("impacto")
	area_golpe.monitoring = true

	rayo.animation_finished.connect(func(): queue_free())

func _on_area_golpe_body_entered(body: Node2D) -> void:
	_intentar_matar(body)

func _process(_delta):
	# Revisa continuamente mientras el área está activa, por si el jugador
	# entra a mitad del frame de impacto en vez de justo al activarse
	if area_golpe.monitoring and not _ya_golpeo:
		for cuerpo in area_golpe.get_overlapping_bodies():
			_intentar_matar(cuerpo)

func _intentar_matar(body: Node2D) -> void:
	if _ya_golpeo:
		return
	if ControladorGlobal.es_partida_en_red and not multiplayer.is_server():
		return
	if body.is_in_group("personajes") and body.has_method("morir"):
		_ya_golpeo = true
		body.morir()
