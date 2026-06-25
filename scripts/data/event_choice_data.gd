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
## ヒートがこの値以下でないと選択不可（-1 = 制限なし）。元レイダー専用。
@export var heat_max: int = -1
## 同行者を加入させるID（空なら加入なし）。
@export var companion_id: StringName = &""
## 信仰度変化（カルティスト専用）。正で教義的、負で世俗的。
@export var faith_change: int = 0
## イベント戦闘で出現する敵のID指定（空ならActランダム）。
@export var combat_enemy_ids: Array[StringName] = []
