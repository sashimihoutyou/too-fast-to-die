class_name CharacterData extends Resource

@export var id: StringName
@export var display_name: String
@export var max_hp: int
@export var starter_deck_ids: Array[StringName]
@export var unique_system: StringName
@export var unlock_condition: String
@export var portrait: Texture2D
@export var is_playable: bool = true
@export var can_use_guns: bool = true
@export var can_use_heavy_weapons: bool = true
@export var deck_limit: int = -1
@export var final_boss_id: StringName = &""
