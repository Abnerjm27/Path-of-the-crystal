extends Camera2D

func _ready():
	position_smoothing_enabled = false  # asegura que el suavizado nativo esté apagado

func _physics_process(_delta):
	global_position = get_parent().global_position
