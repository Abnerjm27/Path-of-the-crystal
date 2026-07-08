extends CanvasLayer

@onready var label_monedas = $LabelMonedas

func actualizar_monedas(recogidas: int, total: int):
	label_monedas.text = "Monedas: %d/%d" % [recogidas, total]
