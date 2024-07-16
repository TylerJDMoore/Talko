extends ColorRect
class_name BackgroundFlash


func _ready():
    color.a = 0.0


func _process(delta): # TODO lerp instead, dont use alpha
    color.a = clamp(color.a - (delta * 2.5), 0.0, 1.0)
