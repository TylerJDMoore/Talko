extends SceneHandler
class_name MinigamesEntity


func _on_button_scene_transition_requested(path: String):
    scene_transition_requested.emit(path)
