extends SceneHandler
class_name MulipleChoice # todo option to not scramble, for questions where answers are always the same? i/pa/etc


@export var bg_correct: BackgroundFlash
@export var bg_incorrect: BackgroundFlash
@export var buttons: Array[Button]
@export var question_label: Label
@export var progress: ProgressBar

var correct_index: int
var correct_count: int = 0

var correct_ids: Array[String] = []
var incorrect_ids: Array[String] = []
var question_queue: Array[Dictionary] = []

var question_progresss_dict: Dictionary = { # TODO put this in db
    "id0": {
        "proficiency": 50.0,
        "question": "Question0",
        "correct_answer": "Correct0",
        "incorrect_answers": ["Incorrect0", "Incorrect1", "Incorrect2"]
    },
    "id1": {
        "proficiency": 50.0,
        "question": "Question1",
        "correct_answer": "Correct1",
        "incorrect_answers": ["Incorrect3", "Incorrect4", "Incorrect5"]
    }
}

var example_question_from_queue0 = {
        "id": "idA",
        "question": "QuestionA",
        "correct_answer": "CorrectA",
        "incorrect_answers": ["IncorrectA0", "IncorrectA1", "IncorrectA2"]
}

var example_question_from_queue1 = {
        "id": "idB",
        "question": "QuestionB",
        "correct_answer": "CorrectB",
        "incorrect_answers": ["IncorrectB0", "IncorrectB1", "IncorrectB2"]
}

var example_question_from_queue2 = {
        "id": "idC",
        "question": "QuestionC",
        "correct_answer": "CorrectC",
        "incorrect_answers": ["IncorrectC0", "IncorrectC1", "IncorrectC2"]
}


func _ready():
    _initialize_minigame(
        [
            example_question_from_queue0,
            example_question_from_queue1,
            example_question_from_queue2
        ]
    )

func _initialize_minigame(new_question_queue: Array[Dictionary]):
    correct_ids = []
    incorrect_ids = []
    question_queue = new_question_queue
    correct_count = 0
    progress.value = 0

    var question_count = new_question_queue.size()
    progress.max_value = question_count * 100

    for i in range(4):
        buttons[i].disabled = false
    
    init_next_question(question_queue[0])


func _process(delta):
    progress.value = clamp(progress.value + (800.0 * delta), 0.0, float(correct_count))


func init_next_question(question: Dictionary):
    var correct_answer: String = question["correct_answer"]
    var incorrect_answers: Array[String] = []
    incorrect_answers.assign(question["incorrect_answers"])
    incorrect_answers.shuffle()

    question_label.text = question["question"]
    correct_index = randi() % 4
    buttons[correct_index].text = correct_answer
    for i in range(4):
        if i != correct_index:
            buttons[i].text = incorrect_answers[0]
            incorrect_answers.remove_at(0)


func selected_correct_answer():
    correct_count += 100
    bg_correct.color.a = 1.0


func selected_incorrect_answer():
    bg_incorrect.color.a = 1.0


func _on_answer_pressed(index: int):
    var question: Dictionary = question_queue[0]
    var current_id: String = question["id"]
    var is_new_question: bool = correct_ids.find(current_id) == -1 && incorrect_ids.find(current_id) == -1

    if index == correct_index:
        selected_correct_answer()
        if is_new_question:
            correct_ids.append(question["id"])
    else:
        selected_incorrect_answer()
        question_queue.append(question)
        if is_new_question:
            incorrect_ids.append(question["id"])
    question_queue.remove_at(0)
    if (question_queue.size() != 0):
        init_next_question(question_queue[0])
    else:
        
        for i in range(4):
            buttons[i].disabled = true
        question_label.text = (str(correct_ids.size()) + "/" + str(correct_ids.size() + incorrect_ids.size()))
        print("Done") #TODO, do db call here and update
