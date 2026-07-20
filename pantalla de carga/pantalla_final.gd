extends CanvasLayer

signal reiniciar
signal salir

@onready var boton_reiniciar = $BotonReiniciar
@onready var boton_salir = $BotonSalir
@onready var boton_siguiente = $BotonSiguienteNivel
@onready var label_monedas = $LabelMonedas
@onready var label_muertes = $LabelMuertes
@onready var label_tiempo = $LabelTiempo
@onready var label_score = $LabelScore
@onready var imagen_felicidades = $ImagenFelicidades
@onready var label_logro = $LabelLogro

@onready var estrella_1 = $Estrellas/Estrella1
@onready var estrella_2 = $Estrellas/Estrella2
@onready var estrella_3 = $Estrellas/Estrella3

@export var tiempo_para_3_estrellas: float = 60.0
@export var tiempo_para_2_estrellas: float = 120.0
@export var muertes_para_3_estrellas: int = 0
@export var muertes_para_2_estrellas: int = 2

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	boton_reiniciar.pressed.connect(_on_reiniciar_pressed)
	boton_salir.pressed.connect(_on_salir_pressed)
	label_logro.visible = false
	ControladorLogros.logro_desbloqueado.connect(_on_logro_desbloqueado)

func mostrar(recogidas: int, total: int, es_ultimo_nivel: bool, muertes_nivel: int, tiempo_nivel: float):
	label_monedas.text = "Monedas: %d/%d" % [recogidas, total]
	label_muertes.text = "Muertes: %d" % muertes_nivel
	
	var minutos = int(tiempo_nivel) / 60
	var segundos = int(tiempo_nivel) % 60
	label_tiempo.text = "Tiempo: %02d:%02d" % [minutos, segundos]
	
	var score = _calcular_score(recogidas, total, muertes_nivel, tiempo_nivel)
	label_score.text = "Puntuación: %d" % score
	
	_mostrar_estrellas(recogidas, total, muertes_nivel, tiempo_nivel)
	
	label_logro.visible = false
	
	if es_ultimo_nivel:
		boton_siguiente.visible = false
		imagen_felicidades.visible = true
	else:
		boton_siguiente.visible = true
		imagen_felicidades.visible = false
	
	visible = true
	get_tree().paused = true

func _calcular_score(recogidas: int, total: int, muertes: int, tiempo: float) -> int:
	var puntos_monedas = recogidas * 20
	var bonus_completo = 50 if recogidas == total else 0
	var penalizacion_muertes = muertes * 15
	var bonus_tiempo = max(0, 300 - int(tiempo))  # bonus si es rápido
	
	return max(0, puntos_monedas + bonus_completo - penalizacion_muertes + bonus_tiempo)

func _mostrar_estrellas(recogidas: int, total: int, muertes: int, tiempo: float):
	var num_estrellas := 1  # completar el nivel siempre da al menos 1 estrella
	
	var todas_las_monedas = recogidas == total
	var pocas_muertes_3 = muertes <= muertes_para_3_estrellas
	var pocas_muertes_2 = muertes <= muertes_para_2_estrellas
	var rapido_3 = tiempo <= tiempo_para_3_estrellas
	var rapido_2 = tiempo <= tiempo_para_2_estrellas
	
	if todas_las_monedas and pocas_muertes_3 and rapido_3:
		num_estrellas = 3
	elif todas_las_monedas and pocas_muertes_2 and rapido_2:
		num_estrellas = 2
	
	estrella_1.visible = true  # siempre visible si completó el nivel
	estrella_2.modulate = Color(1,1,1,1) if num_estrellas >= 2 else Color(0.3,0.3,0.3,0.5)
	estrella_3.modulate = Color(1,1,1,1) if num_estrellas >= 3 else Color(0.3,0.3,0.3,0.5)

func _on_logro_desbloqueado(_id: String, nombre: String, recompensa: int):
	if visible:
		label_logro.text = "🏆 %s: +%d monedas" % [nombre, recompensa]
		label_logro.visible = true

func _on_reiniciar_pressed():
	visible = false
	get_tree().paused = false
	reiniciar.emit()

func _on_salir_pressed():
	visible = false
	get_tree().paused = false
	salir.emit()
