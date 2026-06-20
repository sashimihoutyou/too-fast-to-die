class_name ItemData extends Resource

enum ItemType { CONSUMABLE, RELIC }
enum Rarity { COMMON, UNCOMMON, RARE }
enum TriggerTiming { ON_USE, PASSIVE, ON_COMBAT_START, ON_TURN_START, ON_TURN_END, ON_COMBAT_END }

@export var id: StringName
@export var display_name: String
@export var description: String
@export var item_type: ItemType
@export var rarity: Rarity
@export var trigger: TriggerTiming = TriggerTiming.ON_USE
@export var fuel_cost: int = 0
@export var max_stack: int = 1
@export var hp_change: int = 0
@export var fuel_change: int = 0
@export var scrap_change: int = 0
@export var block_change: int = 0
@export var draw_change: int = 0
@export var special_effect: StringName = &""
@export var effect_value: int = 0
@export var art: Texture2D
