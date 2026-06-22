class_name CardData extends Resource

enum Tag { MELEE, RANGED, BIKE, DEFENSE, SKILL, CHARACTER }
enum Rarity { COMMON, UNCOMMON, RARE }
enum CharacterRestriction { NONE, CULTIST, EX_RAIDER, WANDERER, BEAST_MASTER, CONQUEROR }

@export var id: StringName
@export var display_name: String
@export var description: String
@export var ap_cost: int
@export var fuel_cost: int = 0
@export var tags: Array[Tag]
@export var rarity: Rarity
@export var restriction: CharacterRestriction = CharacterRestriction.NONE
@export var excluded_characters: Array[CharacterRestriction] = []
@export var is_starter: bool = false
@export var is_exhaustible: bool = false
@export var is_unplayable: bool = false
@export var upgraded: bool = false
@export var base_damage: int = 0
@export var base_block: int = 0
@export var hit_count: int = 1
@export var is_aoe: bool = false
@export var requires_target: bool = false  # ダメージが動的(base_damage=0)でも対象選択を要求する
@export var self_damage: int = 0
@export var draw_count: int = 0
@export var bonus_ap: int = 0
@export var status_effect: StringName = &""
@export var status_stacks: int = 0
@export var ap_cost_reduction: int = 0
@export var upgrade_description: String
@export var upgraded_damage: int = 0
@export var upgraded_block: int = 0
@export var art: Texture2D

var instance_id: int = 0

func get_effective_damage() -> int:
	return upgraded_damage if upgraded and upgraded_damage > 0 else base_damage

func get_effective_block() -> int:
	return upgraded_block if upgraded and upgraded_block > 0 else base_block

func duplicate_card() -> CardData:
	var copy := duplicate(true) as CardData
	copy.instance_id = randi()
	return copy
