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
var table_name: String = "multiple_choice"

var correct_index: int
var correct_count: int = 0

var correct_ids: Array[String] = [] # TODO string for IDs?
var incorrect_ids: Array[String] = []
var question_queue: Array[Dictionary] = []

var proficiencies: Dictionary = {}

var database: SQLite


func _ready():
    _init_db()
    _initialize_minigame()


func map_questions(element: Dictionary) -> Dictionary:
    return {
        "id": str(element["id"]),
        "question": str(element["question"]),
        "correct_answer": str(element["correct_answer"]),
        "incorrect_answers": [str(element["incorrect_answer_0"]), str(element["incorrect_answer_1"]), str(element["incorrect_answer_2"])]
    }


func _init_db():
    database = SQLite.new()
    database.path = "res://data.db"
    database.open_db() #TODO close when done

    var table = {
        "id": {"data_type": "string", "primary_key": true, "not_null": true},
        "order_index": {"data_type": "real", "not_null": true, "unique": true},
        "proficiency": {"data_type": "real", "not_null": false},
        "question": {"data_type": "string", "not_null": true, "unique": true},
        "correct_answer": {"data_type" :"string", "not_null": true},
        "incorrect_answer_0": {"data_type": "string", "not_null": true},
        "incorrect_answer_1": {"data_type": "string", "not_null": true},
        "incorrect_answer_2": {"data_type": "string", "not_null": true}
    }

    database.create_table(table_name, table) #TODO configureable table name, so can have diff minigames per category. and maybe there's an "all" category
    database.query("CREATE INDEX IF NOT EXISTS idx_proficiency ON %s (proficiency)" % table_name)
    database.query("CREATE INDEX IF NOT EXISTS idx_order_index ON %s (order_index)" % table_name)

    # TODO populate db, but only once. dont rely on unique failure. maybe there should be a set? one q for visually similar and one for not? would need to manually assign id and remove unique for question. maybe a speech to text where you ahve to say the kanji
    database.insert_row(table_name, make_question("79B1E82D", 1.0, "いち", "一", "二", "三", "千"))
    database.insert_row(table_name, make_question("D359DB68", 2.0, "に", "二", "一", "三", "千"))
    database.insert_row(table_name, make_question("555EC98C", 3.0, "さん", "三", "二", "一", "六"))
    database.insert_row(table_name, make_question("8BAD934E", 4.0, "よん", "四", "五", "六", "西"))
    database.insert_row(table_name, make_question("AF1140AC", 5.0, "ご", "五", "六", "九", "七"))
    database.insert_row(table_name, make_question("4020ABA7", 6.0, "ろく", "六", "四", "八", "五"))
    database.insert_row(table_name, make_question("EFFCB599", 7.0, "なな", "七", "五", "六", "九"))
    database.insert_row(table_name, make_question("1065DDC3", 8.0, "はち", "八", "七", "六", "四"))
    database.insert_row(table_name, make_question("A6CF68CF", 9.0, "きゅ", "九", "七", "五", "万"))
    database.insert_row(table_name, make_question("CE8DA569", 10.0, "じゅ", "十", "千", "田", "六"))
    database.insert_row(table_name, make_question("588DB112", 11.0, "ひゃく", "百", "言", "月", "白"))
    database.insert_row(table_name, make_question("0AF3A713", 12.0, "せん", "千", "七", "大", "九"))
    database.insert_row(table_name, make_question("9892B78A", 13.0, "いちまんえん", "一万", "一千", "一七", "一九"))
    database.insert_row(table_name, make_question("5D669375", 14.0, "えん", "円", "間", "田", "百"))
    database.insert_row(table_name, make_question("DE2A3616", 15.0, "いちじ", "一時", "一語", "一間", "一円"))

func make_question(id: String, order: float, question: String, answer: String, incorrect_0: String, incorrect_1: String, incorrect_2: String) -> Dictionary:
    var dict: Dictionary = {
        "id": id,
        "order_index": order,
        "question": question,
        "correct_answer": answer,
        "incorrect_answer_0": incorrect_0,
        "incorrect_answer_1": incorrect_1,
        "incorrect_answer_2": incorrect_2
    }
    return dict


func _initialize_minigame():
    database.query("SELECT AVG(proficiency) AS average_proficiency, COUNT(proficiency) AS rows_with_proficiency FROM %s WHERE proficiency IS NOT NULL" % table_name)
    
    var row_count = database.query_result[0]["rows_with_proficiency"]
    var avg_proficiency = database.query_result[0]["average_proficiency"]
    var questions_to_add: int = 0
    if (row_count < questions_per_set):
        questions_to_add = questions_per_set - row_count
    elif database.query_result[0]["average_proficiency"] >= threshold:
        questions_to_add = find_min_to_add(database.query_result[0]["rows_with_proficiency"], avg_proficiency)

    if (questions_to_add > 0):
        #TODO threshold should maybe be lower?
        var new_proficiency_query: String = "WITH RankedRows AS (SELECT id, ROW_NUMBER() OVER (ORDER BY order_index ASC) AS row_num FROM %s WHERE proficiency IS NULL) UPDATE %s SET proficiency = %s WHERE id IN (SELECT id FROM RankedRows WHERE row_num <= %s)" % [table_name, table_name, default_proficiency, questions_to_add]
        database.query(new_proficiency_query)

    var query: String = "SELECT * FROM %s WHERE proficiency IS NOT NULL ORDER BY proficiency ASC, id ASC LIMIT %s" % [table_name, questions_per_set]
    database.query(query)
    
    proficiencies = {}
    database.query_result.shuffle() #TODO why isnt this working
    var result: Array[Dictionary] = database.query_result
    for elem in result:
        proficiencies[str(elem["id"])] = elem["proficiency"]

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
    var current_id: String = question["id"]
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
        question_label.text = str(correct_ids.size(), "/", str(correct_ids.size() + incorrect_ids.size()))
        _record_result()
        


func _record_result():
    for id in correct_ids:
        proficiencies[id] = clamp(proficiencies[id] * 4.0 / 3.0, 1.0, 100.0)

    for id in incorrect_ids:
        proficiencies[id] = clamp(proficiencies[id] * 11.0 / 16.0, 1.0, 100.0)

    for key in proficiencies:
        database.update_rows(table_name, str("id = '", key, "'"), {"proficiency": proficiencies[key]})
    
    database.close_db()
    scene_transition_requested.emit(previous_scene)

#TODO this app doesnt handle concurrancies. not an issue for now, since it only uses sqlite. will need transaction locking in future?
#TODo check for success on all queries, some queries can be directly get/update etc, instead of just query
#TOdo add time decay?
