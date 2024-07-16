extends SceneHandler
class_name MulipleChoice # todo option to not scramble, for questions where answers are always the same? i/pa/etc


@export var bg_correct: BackgroundFlash
@export var bg_incorrect: BackgroundFlash
@export var buttons: Array[Button]
@export var question_label: Label
@export var progress: ProgressBar

@export var previous_scene: String

const questions_per_set: int = 6 #TODO maybe this is configureable TODO add button options for keyboard(asdf/1234)
const threshold: float = 80.0
const default_proficiency: float = 50.0

var correct_index: int
var correct_count: int = 0

var correct_ids: Array[int] = [] # TODO string for IDs?
var incorrect_ids: Array[int] = []
var question_queue: Array[Dictionary] = []

var proficiencies: Dictionary = {}

var example_question_from_queue0 = {
        "id": "idA",
        "question": "QuestionA",
        "correct_answer": "CorrectA",
        "incorrect_answers": ["IncorrectA0", "IncorrectA1", "IncorrectA2"]
}

var database: SQLite


func _ready():
    _init_db()
    _initialize_minigame()


func map_questions(element: Dictionary) -> Dictionary:
    return {
        "id": element["id"],
        "question": str(element["question"]),
        "correct_answer": str(element["correct_answer"]),
        "incorrect_answers": [str(element["incorrect_answer_0"]), str(element["incorrect_answer_1"]), str(element["incorrect_answer_2"])]
    }


func _init_db():
    database = SQLite.new()
    database.path = "res://data.db"
    database.open_db() #TODO close when done

    var table = {
        "id": {"data_type": "int", "primary_key": true, "not_null": true, "auto_increment": true},
        "proficiency": {"data_type": "real", "not_null": false,}, # todo index here
        "question": {"data_type": "string", "not_null": true, "unique": true},
        "correct_answer": {"data_type" :"string", "not_null": true,},
        "incorrect_answer_0": {"data_type": "string", "not_null": true,},
        "incorrect_answer_1": {"data_type": "string", "not_null": true,},
        "incorrect_answer_2": {"data_type": "string", "not_null": true,}
    }

    database.create_table("multiple_choice", table) #TODO configureable table name, so can have diff minigames per category. and maybe there's an "all" category
    database.query("CREATE INDEX IF NOT EXISTS idx_proficiency ON multiple_choice (proficiency)")

    database.insert_row("multiple_choice", make_question("ねこ", "猫", "犬", "狼", "大")) # TODO populate db, but only once. dont rely on unique failure
    database.insert_row("multiple_choice", make_question("0ねこ", "猫", "脳", "狼", "惱"))
    database.insert_row("multiple_choice", make_question("1ねこ", "猫", "脳", "狼", "惱"))
    database.insert_row("multiple_choice", make_question("2ねこ", "猫", "脳", "狼", "惱"))
    database.insert_row("multiple_choice", make_question("3ねこ", "猫", "脳", "狼", "惱"))
    database.insert_row("multiple_choice", make_question("4ねこ", "猫", "脳", "狼", "惱"))
    database.insert_row("multiple_choice", make_question("5ねこ", "猫", "脳", "狼", "惱"))
    database.insert_row("multiple_choice", make_question("5ねこ", "猫", "脳", "狼", "惱"))
    database.insert_row("multiple_choice", make_question("5ねこ", "猫", "脳", "狼", "惱"))
    database.insert_row("multiple_choice", make_question("5ねこ", "猫", "脳", "狼", "惱"))


func make_question(question: String, answer: String, incorrect_0: String, incorrect_1: String, incorrect_2: String) -> Dictionary:
    var dict: Dictionary = {
        "question": question,
        "correct_answer": answer,
        "incorrect_answer_0": incorrect_0,
        "incorrect_answer_1": incorrect_1,
        "incorrect_answer_2": incorrect_2
    }
    return dict


func _initialize_minigame():
    database.query("SELECT AVG(proficiency) AS average_proficiency, COUNT(proficiency) AS rows_with_proficiency FROM multiple_choice WHERE proficiency IS NOT NULL")
    
    var row_count = database.query_result[0]["rows_with_proficiency"]
    var avg_proficiency = database.query_result[0]["average_proficiency"]
    var questions_to_add: int = 0 #TODO
    if (row_count < questions_per_set):
        questions_to_add = questions_per_set - row_count
    elif database.query_result[0]["average_proficiency"] >= threshold:
        questions_to_add = find_min_to_add(database.query_result[0]["rows_with_proficiency"], avg_proficiency)

    if (questions_to_add > 0):
        #TODO athreshold should maybe be lower?
        var new_proficiency_query: String = "WITH RankedRows AS (SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS row_num FROM multiple_choice WHERE proficiency IS NULL) UPDATE multiple_choice SET proficiency = %s WHERE id IN (SELECT id FROM RankedRows WHERE row_num <= %s)" % [default_proficiency, questions_to_add]
        database.query(new_proficiency_query)

    var query: String = "SELECT * FROM multiple_choice WHERE proficiency IS NOT NULL ORDER BY proficiency ASC, id ASC LIMIT %s" % questions_per_set
    database.query(query)
    
    proficiencies = {}
    var result: Array[Dictionary] = database.query_result
    for elem in result:
        proficiencies[elem["id"]] = elem["proficiency"]

    var new_question_queue: Array[Dictionary] = []
    new_question_queue.assign(result.map(map_questions))

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


func find_min_to_add(count: float, avg: float): # This assumes default_proficiency < threshold
    if avg <= threshold:
        return 0
    var n: int = 0
    while (true):
        var new_average = (count * avg + default_proficiency * n) / (count + n)
        if new_average < threshold:
            return n
        n += 1


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


func _selected_correct_answer():
    correct_count += 100
    bg_correct.color.a = 1.0


func _selected_incorrect_answer():
    bg_incorrect.color.a = 1.0


func _on_answer_pressed(index: int):
    var question: Dictionary = question_queue[0]
    var current_id: int = question["id"]
    var is_new_question: bool = correct_ids.find(current_id) == -1 && incorrect_ids.find(current_id) == -1

    if index == correct_index:
        _selected_correct_answer()
        if is_new_question:
            correct_ids.append(question["id"])
    else:
        _selected_incorrect_answer()
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
        _record_result()
        


func _record_result():
    for id in correct_ids:
        proficiencies[id] = clamp(proficiencies[id] * 4.0 / 3.0, 1.0, 100.0)

    for id in incorrect_ids:
        proficiencies[id] = clamp(proficiencies[id] * 11.0 / 16.0, 1.0, 100.0)

    for key in proficiencies:
        database.update_rows("multiple_choice", str("id = '", key, "'"), {"proficiency": proficiencies[key]})
        database.close_db()
        scene_transition_requested.emit(previous_scene)

#TODO this app doesnt handle concurrancies. not an issue for now, since it only uses sqlite. will need transaction locking in future?
#TODo check for success on all queries, some queries can be directly get/update etc, instead of just query
#TOdo add time decay?