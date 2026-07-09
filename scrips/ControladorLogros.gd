extends Node

signal logro_desbloqueado(id: String, nombre: String, recompensa: int)

const RUTA_CONFIG = "user://configuracion.cfg"

var logros := {
	"primeros_pasos": {
		"nombre": "Primeros pasos",
		"descripcion": "Completa el nivel 1",
		"recompensa": 20,
		"condicion": func(): return ControladorGlobal.nivel >= 2
	},
	"veterano": {
		"nombre": "Veterano",
		"descripcion": "Alcanza el nivel 10",
		"recompensa": 50,
		"condicion": func(): return ControladorGlobal.nivel >= 10
	},
	"maestro": {
		"nombre": "Maestro",
		"descripcion": "Completa el juego",
		"recompensa": 100,
		"condicion": func(): return ControladorGlobal.nivel >= 20
	},
	"coleccionista": {
		"nombre": "Coleccionista",
		"descripcion": "Acumula 200 monedas en total",
		"recompensa": 30,
		"condicion": func(): return ControladorGlobal.monedas_totales >= 200
	},
	"casi_perfecto": {
		"nombre": "Casi perfecto",
		"descripcion": "Llega al nivel 10 con menos de 10 muertes",
		"recompensa": 40,
		"condicion": func(): return ControladorGlobal.nivel >= 10 and ControladorGlobal.muertes < 10
	},
	"coleccionista_heroes": {
		"nombre": "Coleccionista de héroes",
		"descripcion": "Desbloquea los 5 personajes",
		"recompensa": 50,
		"condicion": func(): return not ControladorGlobal.personajes_desbloqueados.has(false)
	},
}

var desbloqueados: Array[String] = []

func _ready():
	cargar_logros()

func revisar_logros():
	for id in logros.keys():
		if id in desbloqueados:
			continue
		if logros[id]["condicion"].call():
			_desbloquear(id)

func _desbloquear(id: String):
	desbloqueados.append(id)
	var recompensa = logros[id]["recompensa"]
	ControladorGlobal.sumar_monedas(recompensa)
	logro_desbloqueado.emit(id, logros[id]["nombre"], recompensa)
	guardar_logros()

func esta_desbloqueado(id: String) -> bool:
	return id in desbloqueados

func guardar_logros():
	var config = ConfigFile.new()
	config.load(RUTA_CONFIG)
	config.set_value("logros", "desbloqueados", desbloqueados)
	config.save(RUTA_CONFIG)

func cargar_logros():
	var config = ConfigFile.new()
	var error = config.load(RUTA_CONFIG)
	if error == OK:
		var array_cargado = config.get_value("logros", "desbloqueados", [])
		desbloqueados.assign(array_cargado)
