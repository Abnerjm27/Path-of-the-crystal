class_name JefeFinal1
extends CharacterBody2D

@export var velocidad := 50.0

@onready var animacion = $animacion
@onready var timer_ataque = $Timerataque
var vida := 1
var jugador
var puede_atacar := true

func _ready():
	jugador = get_tree().get_first_node_in_group("personajes")

	timer_ataque.timeout.connect(_on_timer_ataque_timeout)
	$Areadebil.body_entered.connect(_on_areadebil_body_entered)

func _physics_process(_delta):

	if jugador == null:
		return

	var distancia = global_position.distance_to(jugador.global_position)

	# Si está cerca ataca
	if distancia < 80:

		velocity.x = 0


	else:

		# Persigue al jugador
		var direccion = sign(jugador.global_position.x - global_position.x)

		velocity.x = direccion * velocidad

		animacion.flip_h = direccion > 0

		if animacion.animation != "atak":
			animacion.play("atak")

	move_and_slide()

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
func _on_timer_ataque_timeout():
	puede_atacar = true
