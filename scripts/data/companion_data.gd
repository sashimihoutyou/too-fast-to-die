class_name CompanionData extends Resource

enum CompanionType { FIGHTER, TECHNICIAN, MERCHANT, INFORMANT, REFUGEE, TRAITOR, DOG, LOVE_SLAVE }

@export var id: StringName
@export var display_name: String
@export var companion_type: CompanionType
@export var is_unique: bool = false
@export var dedicated_character_id: StringName = &""
@export var non_dedicated_duration_nodes: int = -999
@export var duration_nodes: int = -1
@export var passive_description: String
@export var risk_description: String
@export var departure_reward_description: String
@export var deck_card_ids: Array[StringName] = []
@export var allowed_character_ids: Array[StringName] = []
@export var required_karma_min: int = -100
@export var required_karma_max: int = 100
@export var extra_travel_cost: int = 0
@export var pursuit_gain_per_node: int = 0
@export var euphoria_per_node: int = 0
@export var info_node_bonus: int = 0
@export var rest_heal_bonus_percent: int = 0
@export var sleep_interval_combats: int = 0
@export var max_hp: int = 0
@export var death_karma_penalty: int = 0
@export var settle_chance_percent: int = 0
@export var portrait: Texture2D
