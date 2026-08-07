extends Control

@export var apariencias: Array[SpriteFrames]
@export var menu: PackedScene
@export var costos_personajes: Array[int] = [0, 50, 150, 200, 300]
@onready var preview = $AnimatedSprite2D
@onready var nombre = $Nombre
@onready var label_monedas = $LabelMonedas
@onready var label_mensaje = $LabelMensaje
@export var musica_de_esta_escena: AudioStream
const RUTA_SELECCION_PERSONAJE ="res://escenas/menuprincipal/menu_principal.tscn"
@onready var fondo_oscuro = $FondoOscuro
@onready var panel_confirmacion = $PanelConfirmacion
@onready var label_pregunta = $PanelConfirmacion/LabelPregunta
@onready var boton_confirmar = $PanelConfirmacion/BotonConfirmar
@onready var boton_cancelar = $PanelConfirmacion/BotonCancelar
@export var menup = "res://escenas/menuprincipal/menu_principal.gd"
# Botón de "Comenzar" — AJUSTA la ruta al nombre real del nodo en tu escena
@onready var boton_comenzar = $comenzar

var personaje := 0
var _indice_pendiente_compra := -1
var nombres_personajes := ["Asesino", "Salvaje", "Vikingo", "Valkyrie", "Vidente"]

@onready var botones_personaje = [
	$HBoxContainer/personaje1, $HBoxContainer/personaje2, $HBoxContainer/personaje3,
	$HBoxContainer/personaje4, $HBoxContainer/personaje5
]

# ── botón de modo cooperativo (LOCAL, mismo dispositivo) ──
@onready var boton_cooperativo = $BotonCooperativo   # ajusta la ruta según dónde lo pongas en la escena
@onready var label_estado_cooperativo = $BotonCooperativo/LabelEstado  # ej. "Desactivado" / "Activado"

# ── selección de personaje por jugador (solo relevante si el cooperativo LOCAL está activo) ──
@onready var contenedor_selector_coop = $ContenedorSelectorCoop   # agrupa todo lo de abajo, se oculta si no hay coop
@onready var boton_elegir_jugador1 = $ContenedorSelectorCoop/BotonElegirJugador1
@onready var boton_elegir_jugador2 = $ContenedorSelectorCoop/BotonElegirJugador2
@onready var preview_jugador2 = $ContenedorSelectorCoop/PreviewJugador2   # AnimatedSprite2D
@onready var nombre_jugador2 = $ContenedorSelectorCoop/NombreJugador2    # Label
var _eligiendo_jugador := 1   # 1 o 2: a cuál de los dos le asigna el próximo personaje que toques

# ── cooperativo EN RED ──
@onready var contenedor_red = $ContenedorRed                          # agrupa todo lo de abajo, oculto si no hay partida en red
@onready var label_estado_red = $ContenedorRed/LabelEstadoRed         # "Esperando a que el otro jugador elija..."
@onready var boton_listo_red = $ContenedorRed/BotonListoRed           # reemplaza a "Comenzar" en modo red
var _ya_confirme_en_red := false

# Controles de fondo que deben bloquearse cuando el panel de confirmación está abierto
var _controles_fondo: Array

func _ready():
	ResourceLoader.load_threaded_request(RUTA_SELECCION_PERSONAJE)
	ControladorMusica.reproducir(musica_de_esta_escena)
	label_mensaje.visible = false
	fondo_oscuro.visible = false
	panel_confirmacion.visible = false
	boton_confirmar.pressed.connect(_on_confirmar_compra)
	boton_cancelar.pressed.connect(_on_cancelar_compra)
	boton_cooperativo.pressed.connect(_on_boton_cooperativo_pressed)
	boton_elegir_jugador1.pressed.connect(func(): _cambiar_a_quien_elijo(1))
	boton_elegir_jugador2.pressed.connect(func(): _cambiar_a_quien_elijo(2))
	_actualizar_botones_bloqueo()
	_actualizar_label_monedas()
	_actualizar_boton_cooperativo_visual()
	seleccionar_personaje(0)
	_actualizar_preview_jugador2()

	# Navegación por mando
	_controles_fondo = botones_personaje + [boton_cooperativo, boton_elegir_jugador1, boton_elegir_jugador2, boton_comenzar]

	# ── si venimos de una partida en red, esta pantalla se comporta distinto ──
	if ControladorGlobal.es_partida_en_red:
		_preparar_modo_red()
	else:
		contenedor_red.visible = false

	NavegacionMando.conectar_efecto_foco(_controles_fondo + [boton_confirmar, boton_cancelar, boton_listo_red])
	botones_personaje[0].grab_focus()

# ── modo cooperativo en red ──
func _preparar_modo_red() -> void:
	boton_cooperativo.visible = false
	contenedor_selector_coop.visible = false
	boton_comenzar.visible = false
	contenedor_red.visible = true

	# En red no existen ni el cooperativo local ni "Comenzar" — se bloquean
	# para que el mando no intente enfocarlos, y se reconstruye la lista de
	# controles navegables reemplazando "Comenzar" por "Listo"
	# (BotonListoRed), que es el que de verdad existe en este modo.
	NavegacionMando.bloquear_controles(
		[boton_cooperativo, boton_elegir_jugador1, boton_elegir_jugador2, boton_comenzar],
		true
	)
	_controles_fondo = botones_personaje + [boton_listo_red]
	_configurar_navegacion_vertical_red()

	if NetworkDiscovery.soy_host():
		label_estado_red.text = "Elige tu personaje. Esperando al Jugador 2..."
	else:
		label_estado_red.text = "Elige tu personaje. Esperando al Jugador 1..."

	if not boton_listo_red.pressed.is_connected(_on_boton_listo_red_pressed):
		boton_listo_red.pressed.connect(_on_boton_listo_red_pressed)
	if not NetworkDiscovery.jugador_listo.is_connected(_on_jugador_listo_red):
		NetworkDiscovery.jugador_listo.connect(_on_jugador_listo_red)
	if not NetworkDiscovery.nivel_debe_iniciar.is_connected(_on_nivel_debe_iniciar_red):
		NetworkDiscovery.nivel_debe_iniciar.connect(_on_nivel_debe_iniciar_red)

# Conecta cada botón de personaje hacia abajo con BotonListoRed,
# y este de vuelta hacia arriba con el primer personaje.
func _configurar_navegacion_vertical_red() -> void:
	for boton in botones_personaje:
		boton.focus_neighbor_bottom = boton_listo_red.get_path()
	boton_listo_red.focus_neighbor_top = botones_personaje[0].get_path()

func _on_boton_listo_red_pressed() -> void:
	if _ya_confirme_en_red:
		return
	if not ControladorGlobal.personajes_desbloqueados[personaje]:
		_mostrar_mensaje("Ese personaje no está desbloqueado")
		return

	_ya_confirme_en_red = true
	boton_listo_red.disabled = true
	label_estado_red.text = "Listo. Esperando al otro jugador..."
	NetworkDiscovery.enviar_mi_personaje(personaje)

func _on_jugador_listo_red(id: int, _indice_personaje: int) -> void:
	# Feedback opcional: si el que se puso listo fue el OTRO jugador, avisamos.
	if id != NetworkDiscovery.mi_id():
		label_estado_red.text = "El otro jugador ya eligió. Confirma el tuyo."

func _on_nivel_debe_iniciar_red(selecciones: Dictionary) -> void:
	# El host (id 1) siempre es Jugador 1, el cliente es Jugador 2.
	var indice_host: int = selecciones.get(1, 0)
	var id_cliente := -1
	for id in selecciones.keys():
		if id != 1:
			id_cliente = id
	var indice_cliente: int = selecciones.get(id_cliente, 0) if id_cliente != -1 else 0

	ControladorGlobal.personaje_seleccionado = indice_host
	ControladorGlobal.personaje_seleccionado_jugador2 = indice_cliente
	ControladorGlobal.modo_cooperativo_activo = true
	ControladorGlobal.mi_id_jugador_red = 1 if NetworkDiscovery.soy_host() else 2
	marcar_personajes_usados_en_red(selecciones)

	get_tree().change_scene_to_packed(menu)

func marcar_personajes_usados_en_red(selecciones: Dictionary) -> void:
	for id in selecciones.keys():
		ControladorGlobal.marcar_personaje_usado(selecciones[id])

# ── coop LOCAL: cambia a cuál jugador le vas a asignar el próximo personaje que toques ──
func _cambiar_a_quien_elijo(jugador: int):
	_eligiendo_jugador = jugador
	boton_elegir_jugador1.modulate = Color(1, 1, 0.6, 1) if jugador == 1 else Color(1, 1, 1, 1)
	boton_elegir_jugador2.modulate = Color(1, 1, 0.6, 1) if jugador == 2 else Color(1, 1, 1, 1)

func _actualizar_preview_jugador2():
	var indice = ControladorGlobal.personaje_seleccionado_jugador2
	preview_jugador2.sprite_frames = apariencias[indice]
	preview_jugador2.play("idle")
	nombre_jugador2.text = nombres_personajes[indice]

# ── activar/desactivar cooperativo LOCAL con validación de plataforma ──
func _on_boton_cooperativo_pressed():
	if ControladorGlobal.modo_cooperativo_activo:
		ControladorGlobal.modo_cooperativo_activo = false
		_actualizar_boton_cooperativo_visual()
		return
	
	if _intentar_activar_cooperativo():
		ControladorGlobal.modo_cooperativo_activo = true
	_actualizar_boton_cooperativo_visual()

func _intentar_activar_cooperativo() -> bool:
	var mandos_conectados = Input.get_connected_joypads()
	var es_movil = OS.has_feature("mobile")
	
	if es_movil:
		# En móvil exigimos 2 mandos conectados, uno por jugador.
		if mandos_conectados.size() < 2:
			_mostrar_mensaje("Conecta 2 mandos para jugar cooperativo en móvil")
			return false
		ControladorGlobal.esquema_jugador1 = "mando"
		ControladorGlobal.indice_mando_jugador1 = mandos_conectados[0]
		ControladorGlobal.configurar_input_map_mando("mando1", mandos_conectados[0])
		ControladorGlobal.esquema_jugador2 = "mando"
		ControladorGlobal.indice_mando_jugador2 = mandos_conectados[1]
		ControladorGlobal.configurar_input_map_mando("mando2", mandos_conectados[1])
	else:
		# En PC: si hay 2+ mandos, cada jugador toma el suyo.
		# Con 1 mando, el Jugador 1 se queda en teclado y el Jugador 2 toma ese mando.
		# Sin mandos, ambos van por teclado (Jugador 2 con IJKL).
		if mandos_conectados.size() >= 2:
			ControladorGlobal.esquema_jugador1 = "mando"
			ControladorGlobal.indice_mando_jugador1 = mandos_conectados[0]
			ControladorGlobal.configurar_input_map_mando("mando1", mandos_conectados[0])
			ControladorGlobal.esquema_jugador2 = "mando"
			ControladorGlobal.indice_mando_jugador2 = mandos_conectados[1]
			ControladorGlobal.configurar_input_map_mando("mando2", mandos_conectados[1])
			_mostrar_mensaje("Cooperativo activado: cada jugador con su mando")
		elif mandos_conectados.size() == 1:
			ControladorGlobal.esquema_jugador1 = "teclado"
			ControladorGlobal.esquema_jugador2 = "mando"
			ControladorGlobal.indice_mando_jugador2 = mandos_conectados[0]
			ControladorGlobal.configurar_input_map_mando("mando2", mandos_conectados[0])
		else:
			ControladorGlobal.esquema_jugador1 = "teclado"
			ControladorGlobal.esquema_jugador2 = "teclado"
			_mostrar_mensaje("Cooperativo activado: Jugador 2 usa I J K L")
	
	return true

func _actualizar_boton_cooperativo_visual():
	if ControladorGlobal.modo_cooperativo_activo:
		label_estado_cooperativo.text = "Cooperativo: ACTIVADO"
		boton_cooperativo.modulate = Color(0.6, 1, 0.6, 1)
	else:
		label_estado_cooperativo.text = "Cooperativo: desactivado"
		boton_cooperativo.modulate = Color(1, 1, 1, 1)
	# el selector de "para quién elijo" solo importa si hay 2 jugadores locales
	contenedor_selector_coop.visible = ControladorGlobal.modo_cooperativo_activo
	NavegacionMando.bloquear_controles([boton_elegir_jugador1, boton_elegir_jugador2], not ControladorGlobal.modo_cooperativo_activo)
	if ControladorGlobal.modo_cooperativo_activo:
		_cambiar_a_quien_elijo(1)

func _actualizar_label_monedas():
	label_monedas.text = "Cristales: %d" % ControladorGlobal.monedas_totales

func _actualizar_botones_bloqueo():
	for i in botones_personaje.size():
		var boton = botones_personaje[i]
		var desbloqueado = ControladorGlobal.personajes_desbloqueados[i]
		var icono_candado = boton.get_node("IconoCandado")
		var label_costo = boton.get_node("LabelCosto")
		
		boton.modulate = Color(1, 1, 1, 1) if desbloqueado else Color(0.5, 0.5, 0.5, 1)
		icono_candado.visible = not desbloqueado
		label_costo.visible = not desbloqueado
		if not desbloqueado:
			label_costo.text = str(costos_personajes[i])

func seleccionar_personaje(indice: int):
	# En red, ya confirmaste tu personaje, no dejes cambiarlo hasta que
	# el otro jugador también responda (o hasta que reinicies la selección).
	if ControladorGlobal.es_partida_en_red and _ya_confirme_en_red:
		return

	if ControladorGlobal.modo_cooperativo_activo and not ControladorGlobal.es_partida_en_red and _eligiendo_jugador == 2:
		ControladorGlobal.personaje_seleccionado_jugador2 = indice
		_actualizar_preview_jugador2()
		return
	
	personaje = indice
	preview.sprite_frames = apariencias[indice]
	preview.play("idle")
	nombre.text = nombres_personajes[indice]

func _mostrar_mensaje(texto: String):
	label_mensaje.text = texto
	label_mensaje.visible = true
	await get_tree().create_timer(2.0).timeout
	label_mensaje.visible = false

func _intentar_seleccionar_o_comprar(indice: int):
	if ControladorGlobal.personajes_desbloqueados[indice]:
		seleccionar_personaje(indice)
		return
	
	var costo = costos_personajes[indice]
	if ControladorGlobal.monedas_totales >= costo:
		_pedir_confirmacion(indice, costo)
	else:
		var faltan = costo - ControladorGlobal.monedas_totales
		_mostrar_mensaje("Necesitas %d cristales más" % faltan)

func _pedir_confirmacion(indice: int, costo: int):
	_indice_pendiente_compra = indice
	label_pregunta.text = "¿Comprar %s por %d cristales?" % [nombres_personajes[indice], costo]
	fondo_oscuro.visible = true
	panel_confirmacion.visible = true
	NavegacionMando.bloquear_controles(_controles_fondo, true)
	NavegacionMando.enfocar_con_seguridad(boton_cancelar)

func _on_confirmar_compra():
	fondo_oscuro.visible = false
	panel_confirmacion.visible = false
	NavegacionMando.bloquear_controles(_controles_fondo, false)
	if _indice_pendiente_compra == -1:
		return
	
	var indice = _indice_pendiente_compra
	var costo = costos_personajes[indice]
	var comprado = ControladorGlobal.comprar_personaje(indice, costo)
	if comprado:
		_actualizar_botones_bloqueo()
		_actualizar_label_monedas()
		seleccionar_personaje(indice)
		_mostrar_mensaje("¡%s desbloqueado!" % nombres_personajes[indice])
	NavegacionMando.enfocar_con_seguridad(botones_personaje[indice])
	
	_indice_pendiente_compra = -1

func _on_cancelar_compra():
	fondo_oscuro.visible = false
	panel_confirmacion.visible = false
	NavegacionMando.bloquear_controles(_controles_fondo, false)
	if _indice_pendiente_compra != -1:
		NavegacionMando.enfocar_con_seguridad(botones_personaje[_indice_pendiente_compra])
	_indice_pendiente_compra = -1

func _on_personaje_1_pressed():
	_intentar_seleccionar_o_comprar(0)

func _on_personaje_2_pressed():
	_intentar_seleccionar_o_comprar(1)

func _on_personaje_3_pressed():
	_intentar_seleccionar_o_comprar(2)

func _on_personaje_4_pressed() -> void:
	_intentar_seleccionar_o_comprar(3)

func _on_personaje_5_pressed() -> void:
	_intentar_seleccionar_o_comprar(4)

func _on_comenzar_pressed():
	# NOTA: en modo red este botón está oculto (ver _preparar_modo_red);
	# el flujo de red pasa por _on_boton_listo_red_pressed en su lugar.
	if not ControladorGlobal.personajes_desbloqueados[personaje]:
		return
	if ControladorGlobal.modo_cooperativo_activo and not ControladorGlobal.personajes_desbloqueados[ControladorGlobal.personaje_seleccionado_jugador2]:
		return
	
	ControladorGlobal.personaje_seleccionado = personaje
	ControladorGlobal.marcar_personaje_usado(personaje)
	if ControladorGlobal.modo_cooperativo_activo:
		ControladorGlobal.marcar_personaje_usado(ControladorGlobal.personaje_seleccionado_jugador2)
	get_tree().change_scene_to_packed(menu)
