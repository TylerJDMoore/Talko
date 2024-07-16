extends Button
class_name SelectMinigame

@export var target_scene: String = ""


signal scene_transition_requested(path: String)


func _ready():
    disabled = target_scene.length() == 0


func _on_pressed():
    scene_transition_requested.emit(target_scene)
