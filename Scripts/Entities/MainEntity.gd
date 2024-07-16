extends Control
class_name Main


@export var current_scene: SceneHandler
@export var initial_scene: String


func _ready():
	_change_scene(initial_scene)


func _on_scene_transition_requested(path: String):
	_change_scene(path)


func _change_scene(path: String):
	var new_scene = load(path)
	var instance = new_scene.instantiate()
	add_child(instance)
	#todo connect new signal
	if (current_scene != null):
		#TODO disconnect old signal
		current_scene.scene_transition_requested.disconnect(_on_scene_transition_requested)
		current_scene.queue_free()
	current_scene = instance
	current_scene.scene_transition_requested.connect(_on_scene_transition_requested)
	#todo unload
