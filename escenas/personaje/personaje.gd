class_name Personaje
extends CharacterBody2D
signal dash_iniciado
signal dash_listo
signal personaje_muerto
var _velocidad: float = 160.0
var _velocidad_salto: float = -320.0
var _muerto: bool
@export var apariencias: Array[SpriteFrames]
@onready var animacion1 = $animacion
@export var animacion: Node
@export var area_2d: Area2D
@export var material_personaje_rojo = ShaderMaterial

# --- SALTO ---
@export var saltos_maximos: int = 2
@export var multiplicador_segundo_salto: float = 0.75
var _saltos_disponibles: int

# --- DASH ---
@export var velocidad_dash: float = 320.0
@export var duracion_dash: float = 0.12
@export var cooldown_dash: float = 1.0
@export var colores_estela: Array[Color] = [
	Color(0.8, 0.1, 0.1, 0.6),   # Asesino - rojo sangre
	Color(0.4, 0.6, 0.2, 0.6),   # Salvaje - verde selva
	Color(0.3, 0.5, 1.0, 0.6),   # Vikingo - azul hielo
	Color(1.0, 0.85, 0.3, 0.6),  # Valkyrie - dorado
	Color(0.6, 0.2, 0.8, 0.6),   # Vidente - morado místico
]
var _puede_dash := true
var _dashing := false
var _timer_estela: Timer

func _ready(): 
	animacion1.sprite_frames = apariencias[ControladorGlobal.personaje_seleccionado]
	animacion.play("idle")
	animacion.sprite_frames = apariencias[ControladorGlobal.personaje_seleccionado]
	area_2d.body_entered.connect(_on_area_2d_body_entered)
	add_to_group("personajes")
	
	_saltos_disponibles = saltos_maximos
	
	_timer_estela = Timer.new()
	_timer_estela.wait_time = 0.03
	_timer_estela.timeout.connect(_crear_estela)
	add_child(_timer_estela)

func _physics_process(delta):
	if _muerto:
		return
	
	if _dashing:
		move_and_slide()
		return
	
	velocity += get_gravity() * delta
	
	if is_on_floor():
		_saltos_disponibles = saltos_maximos
	
	if Input.is_action_just_pressed("dash") and _puede_dash:
		_iniciar_dash()
		return
	
	if Input.is_action_just_pressed("saltar") and _saltos_disponibles > 0:
		var era_doble_salto = not is_on_floor() and _saltos_disponibles < saltos_maximos
		
		if era_doble_salto:
			velocity.y = _velocidad_salto * multiplicador_segundo_salto
		else:
			velocity.y = _velocidad_salto
		
		_saltos_disponibles -= 1
		if era_doble_salto:
			_efecto_doble_salto()
	
	if Input.is_action_pressed("derecha"):
		velocity.x = _velocidad
		animacion.flip_h = false
	elif Input.is_action_pressed("izquierda"):
		velocity.x = -_velocidad
		animacion.flip_h = true
	else:
		velocity.x = 0
	
	move_and_slide()
	
	if !is_on_floor():
		animacion.play("saltar")
	elif velocity.x != 0:
		animacion.play("correr")
	else:
		animacion.play("idle")

var vida := 1
func _efecto_doble_salto():
	var particulas = CPUParticles2D.new()
	particulas.global_position = animacion.global_position
	particulas.z_index = z_index
	particulas.z_as_relative = z_as_relative
	get_parent().add_child(particulas)
	
	particulas.emitting = true
	particulas.one_shot = true
	particulas.amount = 12
	particulas.lifetime = 0.4
	particulas.explosiveness = 1.0
	particulas.direction = Vector2(0, -1)
	particulas.spread = 180
	particulas.initial_velocity_min = 40
	particulas.initial_velocity_max = 80
	particulas.gravity = Vector2(0, 200)
	particulas.scale_amount_min = 2
	particulas.scale_amount_max = 4
	particulas.color = colores_estela[ControladorGlobal.personaje_seleccionado]
	
	await get_tree().create_timer(0.6).timeout
	particulas.queue_free()
func _iniciar_dash():
	_dashing = true
	_puede_dash = false
	dash_iniciado.emit(cooldown_dash)
	
	var direccion := -1.0 if animacion.flip_h else 1.0
	velocity = Vector2(direccion * velocidad_dash, 0)
	
	_timer_estela.start()
	
	await get_tree().create_timer(duracion_dash).timeout
	_dashing = false
	_timer_estela.stop()
	
	await get_tree().create_timer(cooldown_dash - duracion_dash).timeout
	_puede_dash = true
	dash_listo.emit()

func _crear_estela():
	if not animacion.sprite_frames:
		return
	
	var textura = animacion.sprite_frames.get_frame_texture(animacion.animation, animacion.frame)
	if not textura:
		return
	
	var color_personaje = colores_estela[ControladorGlobal.personaje_seleccionado]
	
	var estela = Sprite2D.new()
	estela.texture = textura
	estela.global_transform = animacion.global_transform
	estela.flip_h = animacion.flip_h
	estela.z_index = z_index
	estela.z_as_relative = z_as_relative
	get_parent().add_child(estela)
	
	estela.modulate = Color(1, 1, 1, 0.8)
	var tween = estela.create_tween()
	tween.tween_property(estela, "modulate", color_personaje, 0.1)
	tween.tween_property(estela, "modulate:a", 0.0, 0.2)
	tween.tween_callback(estela.queue_free)

func _on_area_2d_body_entered(_body: Node2D) -> void:
	if _muerto:
		return
	animacion.material = material_personaje_rojo
	_muerto = true
	animacion.stop()
	await get_tree().create_timer(0.5).timeout
	personaje_muerto.emit()
	ControladorGlobal.sumar_muerte()

func morir():
	if _muerto:
		return
	animacion.material = material_personaje_rojo
	_muerto = true
	animacion.stop()
	await get_tree().create_timer(0.5).timeout
	personaje_muerto.emit()
	ControladorGlobal.sumar_muerte()
