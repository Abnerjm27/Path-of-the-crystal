extends Area2D
class_name BolaFuego

@export var velocidad: float = 300.0
@export var radio_splash: float = 60.0

var direccion: Vector2 = Vector2.ZERO
var ha_explotado: bool = false
var es_host: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	es_host = multiplayer.is_server()
	$AreaExplosion.monitoring = false
	$AreaExplosion/CollisionShape2D.shape.radius = radio_splash

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	sprite.animation_finished.connect(_on_animation_finished)

	sprite.play("volando")
	_orientar_sprite()

func _physics_process(delta):
	if ha_explotado:
		return
	global_position += direccion.normalized() * velocidad * delta

func _orientar_sprite():
	# El sprite base apunta a la derecha, así que rotarlo directo al ángulo
	# de la dirección cubre cualquier ángulo: horizontal, vertical o diagonal.
	sprite.rotation = direccion.angle() + deg_to_rad(90)

func _on_body_entered(body):
	if ha_explotado:
		return
	if body.is_in_group("suelo"):
		_explotar()
	elif body.is_in_group("personajes"):
		_matar_jugador(body)
		_explotar()

func _on_area_entered(area):
	if ha_explotado:
		return
	if area.is_in_group("suelo"):
		_explotar()

func _explotar():
	if ha_explotado:
		return
	ha_explotado = true
	direccion = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$AreaExplosion.monitoring = true

	if es_host:
		await get_tree().physics_frame
		_aplicar_daño_splash()

	sprite.rotation = 0.0
	sprite.play("explosion")

func _on_animation_finished():
	if sprite.animation == "explosion":
		queue_free()

func _aplicar_daño_splash():
	var cuerpos = $AreaExplosion.get_overlapping_bodies()
	for cuerpo in cuerpos:
		if cuerpo.is_in_group("personajes"):
			_matar_jugador(cuerpo)

func _matar_jugador(cuerpo: Node2D) -> void:
	if ControladorGlobal.es_partida_en_red and not multiplayer.is_server():
		return
	if cuerpo.has_method("morir"):
		cuerpo.morir()
