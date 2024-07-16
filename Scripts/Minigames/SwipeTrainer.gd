extends SceneHandler

@onready var textInput = $TextEdit
@onready var label = $Label

var placeholderText;
var characters = ["あ","い","う","え","お"]

func _ready():
	textInput.language = "JP";
	label.text = characters[0];

func _on_text_edit_text_changed():
	var input = textInput.text;
	var target = characters.pop_front();
	if (input == target):
		print("correct")
	else:
		print("incorrect")
		characters.push_back(target);
	if (!characters.is_empty()):
		label.text = characters[0];
	else:
		label.text = "";
		textInput.editable = false;
		print("complete")
	textInput.clear();
	textInput.clear_undo_history();

func _on_text_edit_focus_entered():
	textInput.placeholder_text = "" ##TODO why does this call twice

func _on_text_edit_focus_exited():
	textInput.placeholder_text = placeholderText;
#＃TODO background should flash red/green when correct or incorrect
