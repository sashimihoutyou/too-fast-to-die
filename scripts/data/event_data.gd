class_name EventData extends Resource

@export var id: StringName
@export var title: String
@export var body_text: String
@export var required_character: StringName = &""
@export var required_karma_min: int = -100
@export var required_karma_max: int = 100
@export var required_act: int = -1
@export var choices: Array[EventChoiceData]
