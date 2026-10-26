extends Area2D
class_name BolaFuego

@export var velocidad: float = 300.0
@export var radio_splash: float = 60.0

var direccion: Vector2 = Vector2.ZERO
var ha_explotado: bool = false
var es_host: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	es_host = NetworkDiscovery.soy_host() if ControladorGlobal.es_partida_en_red else true

	if has_node("AreaExplosion"):
		$AreaExplosion.monitoring = false
		if $AreaExplosion.has_node("CollisionShape2D") and $AreaExplosion/CollisionShape2D.shape:
			$AreaExplosion/CollisionShape2D.shape.radius = radio_splash

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	sprite.play("volando")
	_orientar_sprite()


func _physics_process(delta: float) -> void:
	if ha_explotado:
		return
	# En red, solo el host mueve el proyectil; el cliente lo ve vía RPC de explosión
	if ControladorGlobal.es_partida_en_red and not es_host:
		return
	global_position += direccion.normalized() * velocidad * delta


func _orientar_sprite() -> void:
	# Rotación dinámica para cualquier dirección
	sprite.rotation = direccion.angle() + deg_to_rad(90)


func _on_body_entered(body: Node2D) -> void:
	if ha_explotado:
		return

	if body.is_in_group("suelo"):
		_solicitar_explosion_red()
	elif body.is_in_group("personajes"):
		# Si toca directamente a un personaje, el cliente/host valida el daño
		var personaje := body as Personaje
		if personaje and personaje.es_mio_localmente():
			if personaje.has_method("morir"):
				personaje.morir()
		_solicitar_explosion_red()


func _on_area_entered(area: Area2D) -> void:
	if ha_explotado:
		return
	if area.is_in_group("suelo"):
		_solicitar_explosion_red()


# ── Sincronización de la Explosión en Red ──
func _solicitar_explosion_red() -> void:
	if ha_explotado:
		return

	if ControladorGlobal.es_partida_en_red:
		# Transmite la explosión de forma confiable a ambos peers
		rpc("rpc_explotar")
	else:
		_explotar()


@rpc("any_peer", "call_local", "reliable")
func rpc_explotar() -> void:
	_explotar()


func _explotar() -> void:
	if ha_explotado:
		return
	ha_explotado = true
	direccion = Vector2.ZERO

	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	if has_node("AreaExplosion"):
		$AreaExplosion.monitoring = true

	if es_host:
		await get_tree().physics_frame
		_aplicar_daño_splash()

	sprite.rotation = 0.0
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("explosion"):
		sprite.play("explosion")
	else:
		queue_free()


func _on_animation_finished() -> void:
	if sprite.animation == "explosion":
		queue_free()


func _aplicar_daño_splash() -> void:
	if not has_node("AreaExplosion"):
		return
		
	var cuerpos: Array[Node2D] = $AreaExplosion.get_overlapping_bodies()
	for cuerpo in cuerpos:
		if cuerpo.is_in_group("personajes"):
			_matar_jugador(cuerpo)

func _matar_jugador(cuerpo: Node2D) -> void:
	if ControladorGlobal.es_partida_en_red and not NetworkDiscovery.soy_host():
		return
	if cuerpo.has_method("morir"):
		cuerpo.morir()
