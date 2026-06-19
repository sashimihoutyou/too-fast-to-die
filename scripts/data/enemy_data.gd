class_name EnemyData extends Resource

enum Category { HUMAN, BEAST, MACHINE }
enum RangeType { GROUND, MOUNTED }

@export var id: StringName
@export var display_name: String
@export var category: Category
@export var base_hp: int
@export var range_type: RangeType
@export var act: int
@export var is_elite: bool = false
@export var is_boss: bool = false
@export var art: Texture2D
