extends Node2D
class_name RayoCielo

const DURACION_ADVERTENCIA: float = 0.7
const FRAME_IMPACTO_MORTAL: int = 3

@onready var circulo: AnimatedSprite2D = $AnimatedSprite2D_Circulo
@onready var rayo: AnimatedSprite2D = $AnimatedSprite2D_Rayo
@onready var area_golpe: Area2D = $AreaGolpe

var _ya_golpeo: bool = false


func _ready() -> void:
	rayo.visible = false
	area_golpe.monitoring = false
	area_golpe.body_entered.connect(_on_area_golpe_body_entered)

	circulo.play("advertencia")
	await get_tree().create_timer(DURACION_ADVERTENCIA).timeout

	if not is_instance_valid(self):
		return

	circulo.visible = false
	rayo.visible = true
	rayo.play("impacto")
	area_golpe.monitoring = true

	if not rayo.animation_finished.is_connected(_on_rayo_animation_finished):
		rayo.animation_finished.connect(_on_rayo_animation_finished)


func _on_rayo_animation_finished() -> void:
	queue_free()


func _on_area_golpe_body_entered(body: Node2D) -> void:
	_intentar_matar(body)


func _process(_delta: float) -> void:
	if area_golpe.monitoring and not _ya_golpeo:
		var cuerpos: Array[Node2D] = area_golpe.get_overlapping_bodies()
		for cuerpo in cuerpos:
			_intentar_matar(cuerpo)


func _intentar_matar(body: Node2D) -> void:
	if _ya_golpeo or not is_instance_valid(body):
		return

	if body.is_in_group("personajes"):
		var personaje := body as Personaje
		if personaje and personaje.has_method("morir"):
			# En red, procesa el daño el Host o el dueño local del personaje
			if not ControladorGlobal.es_partida_en_red or NetworkDiscovery.soy_host() or personaje.es_mio_localmente():
				_ya_golpeo = true
				personaje.morir()
