class_name EventChoiceData extends Resource

@export var label: String
@export var requirement: String = ""
@export var result_text: String
@export var fuel_change: int = 0
@export var karma_change: int = 0
@export var hp_change: int = 0
@export var scrap_change: int = 0
@export var medicine_change: int = 0
@export var triggers_combat: bool = false
## サブストーリー連携（QuestManager で消費）。
@export var starts_quest: StringName = &""
@export var quest_outcome: StringName = &""
## イベントフラグ（GameManager.event_flags）に立てるキー。後続イベント/評判の条件に使う。
@export var sets_flag: StringName = &""
