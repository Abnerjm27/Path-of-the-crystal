class_name Personaje
extends CharacterBody2D
signal dash_iniciado
signal dash_listo
signal personaje_muerto

var _velocidad: float = 100.0
var _velocidad_salto: float = -320.0
var _muerto: bool

@export var apariencias: Array[SpriteFrames]
@onready var animacion1 = $animacion
@export var animacion: Node
@export var area_2d: Area2D
@export var material_personaje_rojo = ShaderMaterial

# --- DASH ---
@export var velocidad_dash: float = 250.0
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
	
	if Input.is_action_just_pressed("dash") and _puede_dash:
		_iniciar_dash()
		return
	
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = _velocidad_salto
	
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
	
	estela.modulate = Color(1, 1, 1, 0.8)  # destello blanco inicial
	var tween = estela.create_tween()
	tween.tween_property(estela, "modulate", color_personaje, 0.1)  # transición al color del personaje
	tween.tween_property(estela, "modulate:a", 0.0, 0.2)  # luego se desvanece
	tween.tween_callback(estela.queue_free)

func _on_area_2d_body_entered(_body: Node2D) -> void:
	if _muerto:
		return  # <- nueva protección, evita doble disparo de muerte
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
