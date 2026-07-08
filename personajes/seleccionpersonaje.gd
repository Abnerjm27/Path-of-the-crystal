extends Control

@export var apariencias: Array[SpriteFrames]
@export var menu: PackedScene
@onready var preview = $AnimatedSprite2D
@onready var nombre = $Nombre
@export var musica_de_esta_escena: AudioStream
var personaje := 0
func _ready():
	ControladorMusica.reproducir(musica_de_esta_escena)
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


func _on_personaje_4_pressed() -> void:
	personaje = 3

	preview.sprite_frames = apariencias[3]
	preview.play("idle")

	nombre.text = "Valkyrie"


func _on_personaje_5_pressed() -> void:
	personaje = 4

	preview.sprite_frames = apariencias[4]
	preview.play("idle")

	nombre.text = "Vidente"
