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

var personaje := 0
var _indice_pendiente_compra := -1
var nombres_personajes := ["Asesino", "Salvaje", "Vikingo", "Valkyrie", "Vidente"]

@onready var botones_personaje = [
	$HBoxContainer/personaje1, $HBoxContainer/personaje2, $HBoxContainer/personaje3,
	$HBoxContainer/personaje4, $HBoxContainer/personaje5
]

# ── NUEVO: botón de modo cooperativo ──
@onready var boton_cooperativo = $BotonCooperativo   # ajusta la ruta según dónde lo pongas en la escena
@onready var label_estado_cooperativo = $BotonCooperativo/LabelEstado  # ej. "Desactivado" / "Activado"

# ── NUEVO: selección de personaje por jugador (solo relevante si el cooperativo está activo) ──
@onready var contenedor_selector_coop = $ContenedorSelectorCoop   # agrupa todo lo de abajo, se oculta si no hay coop
@onready var boton_elegir_jugador1 = $ContenedorSelectorCoop/BotonElegirJugador1
@onready var boton_elegir_jugador2 = $ContenedorSelectorCoop/BotonElegirJugador2
@onready var preview_jugador2 = $ContenedorSelectorCoop/PreviewJugador2   # AnimatedSprite2D
@onready var nombre_jugador2 = $ContenedorSelectorCoop/NombreJugador2    # Label
var _eligiendo_jugador := 1   # 1 o 2: a cuál de los dos le asigna el próximo personaje que toques

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

# ── NUEVO: cambia a cuál jugador le vas a asignar el próximo personaje que toques ──
func _cambiar_a_quien_elijo(jugador: int):
	_eligiendo_jugador = jugador
	boton_elegir_jugador1.modulate = Color(1, 1, 0.6, 1) if jugador == 1 else Color(1, 1, 1, 1)
	boton_elegir_jugador2.modulate = Color(1, 1, 0.6, 1) if jugador == 2 else Color(1, 1, 1, 1)

func _actualizar_preview_jugador2():
	var indice = ControladorGlobal.personaje_seleccionado_jugador2
	preview_jugador2.sprite_frames = apariencias[indice]
	preview_jugador2.play("idle")
	nombre_jugador2.text = nombres_personajes[indice]

# ── NUEVO: activar/desactivar cooperativo con validación de plataforma ──
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
	# NUEVO: el selector de "para quién elijo" solo importa si hay 2 jugadores
	contenedor_selector_coop.visible = ControladorGlobal.modo_cooperativo_activo
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
	if ControladorGlobal.modo_cooperativo_activo and _eligiendo_jugador == 2:
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

func _on_confirmar_compra():
	fondo_oscuro.visible = false
	panel_confirmacion.visible = false
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
	
	_indice_pendiente_compra = -1

func _on_cancelar_compra():
	fondo_oscuro.visible = false
	panel_confirmacion.visible = false
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
	if not ControladorGlobal.personajes_desbloqueados[personaje]:
		return
	if ControladorGlobal.modo_cooperativo_activo and not ControladorGlobal.personajes_desbloqueados[ControladorGlobal.personaje_seleccionado_jugador2]:
		return
	
	ControladorGlobal.personaje_seleccionado = personaje
	ControladorGlobal.marcar_personaje_usado(personaje)
	if ControladorGlobal.modo_cooperativo_activo:
		ControladorGlobal.marcar_personaje_usado(ControladorGlobal.personaje_seleccionado_jugador2)
	get_tree().change_scene_to_packed(menu)
