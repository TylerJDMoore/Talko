extends SceneHandler
class_name SplashEntity


@export var dropdown: Control
@export var label: Label
@export var minigame_select_scenes: Array[String]

var current_scene_state = 0 # todo const


func _input(event):
	if event is InputEventMouseButton && current_scene_state == 0:
		current_scene_state = 1
		label.queue_free()
		dropdown.call_deferred("show")

		
func _on_option_button_item_selected(index:int):
	scene_transition_requested.emit(minigame_select_scenes[index])
