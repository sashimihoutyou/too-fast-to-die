class_name EventData extends Resource

@export var id: StringName
@export var title: String
@export var body_text: String
@export var required_character: StringName = &""
@export var required_karma_min: int = -100
@export var required_karma_max: int = 100
@export var required_act: int = -1
## true のイベントはランダム抽選から除外され、QuestManager の強制発火でのみ出現する遅延ペイロード。
@export var payload_only: bool = false
## キャラID→本文テキストのマッピング。該当キャラなら body_text の代わりに使う。
@export var character_reactions: Dictionary = {}
@export var choices: Array[EventChoiceData]
