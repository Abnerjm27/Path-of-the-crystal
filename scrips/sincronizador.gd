class_name SincronizadorDeLoop
extends Node

## Colgar como hijo de cualquier cosa con un AnimationPlayer en loop que
## necesite estar en fase entre host y cliente (plataformas, enemigos, etc).

@export var animador: AnimationPlayer

func _ready() -> void:
	add_to_group("sincronizadores_loop")
	if ControladorGlobal.es_partida_en_red and not multiplayer.is_server():
		animador.stop()  # se queda quieto hasta que llegue la sincronización en bloque

# Llamado por NetworkDiscovery cuando llega la sincronización del nivel
func aplicar_sincronizacion(nombre_animacion: String, posicion: float) -> void:
	if nombre_animacion == "":
		return
	animador.play(nombre_animacion)
	animador.seek(posicion, true)
