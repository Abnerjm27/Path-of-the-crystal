class_name MiniJefe
extends CharacterBody2D

@onready var animacion = $animacion1
var vida := 1
var jugador

func _ready():
	jugador = get_tree().get_first_node_in_group("personajes")
	$Areadebil.body_entered.connect(_on_areadebil_body_entered)

func _on_areadebil_body_entered(body):

	if body is Personaje:

		# Solo si cae encima
		if body.velocity.y > 0:

			vida -= 1

			print("Vida restante:", vida)

			# Rebote del jugador
			body.velocity.y = -200

			if vida <= 0:
				queue_free()
