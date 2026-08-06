class_name MiniJefe
extends CharacterBody2D

@onready var animacion = $animacion1
var vida := 1
var jugador
var _indice_sincronizacion := -1
var _es_autoridad := true

func _enter_tree() -> void:
	if ControladorGlobal.es_partida_en_red:
		add_to_group(NetworkDiscovery.GRUPO_ENEMIGOS_SINCRONIZABLES)

func _ready():
	jugador = get_tree().get_first_node_in_group("personajes")
	$Areadebil.body_entered.connect(_on_areadebil_body_entered)
	if ControladorGlobal.es_partida_en_red:
		var lista := get_tree().get_nodes_in_group(NetworkDiscovery.GRUPO_ENEMIGOS_SINCRONIZABLES)
		_indice_sincronizacion = lista.find(self)
		_es_autoridad = multiplayer.is_server()
		if not _es_autoridad:
			NetworkDiscovery.enemigo_golpeado_recibido.connect(_on_golpeado_remoto)
			NetworkDiscovery.enemigo_muerto_recibido.connect(_on_muerto_remoto)

func _on_areadebil_body_entered(body):
	if ControladorGlobal.es_partida_en_red and not _es_autoridad:
		return
	if body is Personaje:
		if body.velocity.y > 0:
			vida -= 1
			print("Vida restante:", vida)

			if ControladorGlobal.es_partida_en_red and not body.es_mio_localmente():
				# Golpeó el dummy de un jugador remoto: avisarle por RPC para que rebote en su propia máquina
				NetworkDiscovery.enviar_rebote_jugador(body.jugador_id)
			else:
				# Jugador local (host) o partida sin red: rebote directo
				body.velocity.y = -200

			if ControladorGlobal.es_partida_en_red:
				NetworkDiscovery.enviar_enemigo_golpeado(_indice_sincronizacion, vida)
			if vida <= 0:
				if ControladorGlobal.es_partida_en_red:
					NetworkDiscovery.enviar_enemigo_muerto(_indice_sincronizacion)
				queue_free()

func _on_golpeado_remoto(indice: int, vida_restante: int) -> void:
	if indice != _indice_sincronizacion:
		return
	vida = vida_restante

func _on_muerto_remoto(indice: int) -> void:
	if indice != _indice_sincronizacion:
		return
	queue_free()
