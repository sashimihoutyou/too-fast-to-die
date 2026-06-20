class_name CompanionData extends Resource

enum CompanionType { FIGHTER, TECHNICIAN, MERCHANT, INFORMANT, REFUGEE, TRAITOR, DOG }

@export var id: StringName
@export var display_name: String
@export var companion_type: CompanionType
@export var duration_nodes: int = -1
@export var passive_description: String
@export var risk_description: String
@export var departure_reward_description: String
@export var portrait: Texture2D
