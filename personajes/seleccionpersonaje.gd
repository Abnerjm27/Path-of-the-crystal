extends Control

@export var apariencias: Array[SpriteFrames]
@export var menu: PackedScene
@onready var preview = $AnimatedSprite2D
@onready var nombre = $Nombre

var personaje := 0
func _ready():
	preview.sprite_frames = apariencias[0]
	preview.play("idle")

	nombre.text = "Asesino"
func _on_personaje_1_pressed():

	personaje = 0

	preview.sprite_frames = apariencias[0]
	preview.play("idle")

	nombre.text = "Asesino"
func _on_personaje_2_pressed():

	personaje = 1

	preview.sprite_frames = apariencias[1]
	preview.play("idle")

	nombre.text = "Salvaje"
func _on_personaje_3_pressed():

	personaje = 2

	preview.sprite_frames = apariencias[2]
	preview.play("idle")

	nombre.text = "Vikingo"
func _on_comenzar_pressed():

	ControladorGlobal.personaje_seleccionado = personaje

	get_tree().change_scene_to_packed(menu)
