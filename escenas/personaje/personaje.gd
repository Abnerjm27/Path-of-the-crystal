class_name Personaje
extends CharacterBody2D
signal personaje_muerto
var _velocidad: float = 100.0
var _velocidad_salto: float = -320.0
var _muerto : bool
@export var apariencias: Array[SpriteFrames]
@onready var animacion1 = $animacion
@export var animacion : Node 
@export var area_2d: Area2D
@export var material_personaje_rojo= ShaderMaterial
func _ready(): 

	animacion1.sprite_frames = apariencias[
			ControladorGlobal.personaje_seleccionado
		]
	animacion.play("idle")
	animacion.sprite_frames = apariencias[ControladorGlobal.personaje_seleccionado]
	area_2d.body_entered.connect(_on_area_2d_body_entered)
	add_to_group("personajes")
func _physics_process(delta):
	if _muerto:
		return
	#gravedad
	velocity += get_gravity()*delta
	#salto
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = _velocidad_salto

	#movimiento lateral
	if Input.is_action_pressed("derecha"):
		velocity.x  = _velocidad
		animacion.flip_h=false
	elif Input.is_action_pressed("izquierda"):
		velocity.x = -_velocidad
		animacion.flip_h=true
	else:
		velocity.x = 0
	move_and_slide()

	#ANIMACION
	if !is_on_floor():
		animacion.play("saltar")
	elif velocity.x != 0:
			animacion.play("correr")
	else:
		animacion.play("idle")
var vida := 1
func _on_area_2d_body_entered(_body: Node2D) -> void:
	animacion.material = material_personaje_rojo
	_muerto=true
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
