extends Control
# AJUSTA esta ruta a donde tengas la escena de selección de personaje
const RUTA_SELECCION_PERSONAJE := "res://personajes/seleccionpersonaje.tscn"
var _ya_cambio_de_escena := false

# NUEVO: referencia al botón de volver (ajusta la ruta si no está donde crees)
@onready var boton_volver = $Contenedor/volver_menuprincipal

func _ready() -> void:
	_ya_cambio_de_escena = false
	NetworkDiscovery.partida_encontrada.connect(_on_partida_encontrada)
	NetworkDiscovery.conexion_exitosa.connect(_on_conexion_exitosa)      # se dispara en el CLIENTE
	NetworkDiscovery.conexion_fallida.connect(_on_conexion_fallida)
	NetworkDiscovery.jugador_remoto_conectado.connect(_on_jugador_remoto_conectado) # se dispara en el HOST

	# NUEVO: navegación por mando en los botones fijos
	NavegacionMando.conectar_efecto_foco([
		$Contenedor/BotonCrear,
		$Contenedor/BotonBuscar,
		boton_volver,
	])
	_configurar_vecinos_iniciales()
	NavegacionMando.enfocar_con_seguridad($Contenedor/BotonCrear)

func _configurar_vecinos_iniciales() -> void:
	$Contenedor/BotonCrear.focus_neighbor_bottom = $Contenedor/BotonBuscar.get_path()
	$Contenedor/BotonBuscar.focus_neighbor_top = $Contenedor/BotonCrear.get_path()
	boton_volver.focus_neighbor_bottom = $Contenedor/BotonCrear.get_path()
	$Contenedor/BotonCrear.focus_neighbor_top = boton_volver.get_path()

func _on_boton_crear_pressed() -> void:
	# NUEVO: si ya se está creando/buscando una partida, ignorar
	if $Contenedor/BotonCrear.disabled or $Contenedor/BotonBuscar.disabled:
		return

	NetworkDiscovery.reiniciar_estado_partida()
	NetworkDiscovery.iniciar_partida("Partida de %s" % OS.get_unique_id())
	$Contenedor/EstadoLabel.text = "Esperando que alguien se una..."
	$Contenedor/BotonCrear.disabled = true
	$Contenedor/BotonBuscar.disabled = true
	NavegacionMando.bloquear_controles([$Contenedor/BotonCrear, $Contenedor/BotonBuscar], true)
	NavegacionMando.enfocar_con_seguridad(boton_volver)

func _on_boton_buscar_pressed() -> void:
	# NUEVO: si ya se está creando/buscando una partida, ignorar
	if $Contenedor/BotonCrear.disabled or $Contenedor/BotonBuscar.disabled:
		return

	$Contenedor/EstadoLabel.text = "Buscando partidas en la red..."
	NetworkDiscovery.buscar_partidas()

	# NUEVO: bloqueo igual que en "Crear", para evitar la doble acción
	$Contenedor/BotonCrear.disabled = true
	$Contenedor/BotonBuscar.disabled = true
	NavegacionMando.bloquear_controles([$Contenedor/BotonCrear, $Contenedor/BotonBuscar], true)
	NavegacionMando.enfocar_con_seguridad(boton_volver)

func _on_partida_encontrada(ip: String, nombre_partida: String) -> void:
	for hijo in $Contenedor/ListaPartidas.get_children():
		if hijo.get_meta("ip") == ip:
			return
	var boton := Button.new()
	boton.text = nombre_partida
	boton.set_meta("ip", ip)
	boton.pressed.connect(func(): _unirse_a_partida(ip))
	$Contenedor/ListaPartidas.add_child(boton)

	# NUEVO: navegación por mando para el botón recién creado
	NavegacionMando.conectar_efecto_foco([boton])
	_reconectar_vecinos_lista()
	# Si es la primera partida encontrada, la enfocamos directo
	if $Contenedor/ListaPartidas.get_child_count() == 1:
		NavegacionMando.enfocar_con_seguridad(boton)

func _reconectar_vecinos_lista() -> void:
	# NUEVO: conecta arriba/abajo entre los botones de partidas encontradas,
	# y de la lista hacia BotonBuscar
	var botones := $Contenedor/ListaPartidas.get_children()
	for i in botones.size():
		botones[i].focus_neighbor_top = botones[i - 1].get_path() if i > 0 else $Contenedor/BotonBuscar.get_path()
		botones[i].focus_neighbor_bottom = botones[i + 1].get_path() if i < botones.size() - 1 else NodePath()
	if botones.size() > 0:
		$Contenedor/BotonBuscar.focus_neighbor_bottom = botones[0].get_path()

func _unirse_a_partida(ip: String) -> void:
	NetworkDiscovery.reiniciar_estado_partida()
	$Contenedor/EstadoLabel.text = "Conectando a %s..." % ip
	NetworkDiscovery.conectarse_a(ip)
	# NUEVO: bloquea toda la navegación mientras se conecta
	var todos := [$Contenedor/BotonCrear, $Contenedor/BotonBuscar]
	todos.append_array($Contenedor/ListaPartidas.get_children())
	NavegacionMando.bloquear_controles(todos, true)
	NavegacionMando.enfocar_con_seguridad(boton_volver)

func _on_conexion_fallida() -> void:
	$Contenedor/EstadoLabel.text = "Falló la conexión, intenta de nuevo"
	$Contenedor/BotonCrear.disabled = false
	$Contenedor/BotonBuscar.disabled = false
	# NUEVO: reactiva navegación tras un fallo
	var todos := [$Contenedor/BotonCrear, $Contenedor/BotonBuscar]
	todos.append_array($Contenedor/ListaPartidas.get_children())
	NavegacionMando.bloquear_controles(todos, false)
	NavegacionMando.enfocar_con_seguridad($Contenedor/BotonCrear)

# --- Transición a la pantalla de selección de personaje ---
func _on_conexion_exitosa() -> void:
	# Esto corre en el CLIENTE, apenas se confirma la conexión al host
	_ir_a_seleccion_personaje()

func _on_jugador_remoto_conectado(_id: int) -> void:
	# Esto corre en el HOST, apenas se une el cliente
	_ir_a_seleccion_personaje()

func _ir_a_seleccion_personaje() -> void:
	if _ya_cambio_de_escena:
		return
	_ya_cambio_de_escena = true
	ControladorGlobal.es_partida_en_red = true
	call_deferred("_cambiar_escena_diferido")

func _cambiar_escena_diferido() -> void:
	get_tree().change_scene_to_file(RUTA_SELECCION_PERSONAJE)
func _exit_tree() -> void:
	if not _ya_cambio_de_escena:
		NetworkDiscovery.detener_host()
		NetworkDiscovery.dejar_de_buscar()
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.close()
			multiplayer.multiplayer_peer = null
