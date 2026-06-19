class_name BikePartData extends Resource

enum Slot { ENGINE, TIRES, FRAME, TANK, DECORATION }
enum PartRarity { NORMAL, UPPER, RARE }

@export var id: StringName
@export var display_name: String
@export var slot: Slot
@export var rarity: PartRarity
@export var stats: Dictionary
@export var special_effect: String
@export var art: Texture2D
