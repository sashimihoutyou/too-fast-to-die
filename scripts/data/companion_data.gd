class_name CompanionData extends Resource

enum CompanionType { FIGHTER, TECHNICIAN, MERCHANT, INFORMANT, REFUGEE, TRAITOR, DOG, LOVE_SLAVE }

## 同行者が加入時に提示する「希望」の種別。
## NONE   = 希望なし（犬など。無期限に同行し、定着判定も発生しない）
## TRAVEL = ランダムなノード数の同行を希望する（request_nodes_min〜max でロール）
## ESCORT = 特定の施設種別（request_site_types）への送り届けを希望する。
##          期限は request_nodes_min〜max ノード（ロール）。期限切れで失敗。
enum RequestType { NONE, TRAVEL, ESCORT }

@export var id: StringName
@export var display_name: String
@export var companion_type: CompanionType
@export var is_unique: bool = false
@export var dedicated_character_id: StringName = &""
@export var request_type: RequestType = RequestType.TRAVEL
@export var request_nodes_min: int = 4
@export var request_nodes_max: int = 6
## MapGenerator.SiteType の int 値。ESCORT の目的地として満たせる施設種別。
@export var request_site_types: Array[int] = []
## 加入時に表示する希望の台詞。空ならタイプ既定文を使う。
@export var request_line: String = ""
## 希望達成後の永続同行打診の台詞。空ならタイプ既定文を使う。
@export var settle_offer_line: String = ""
## 希望を満たせなかった（期限切れ/途中で降ろした）場合のペナルティ。
@export var fail_karma_penalty: int = -8
@export var fail_fuel_penalty: int = 0
@export var fail_pursuit_penalty: int = 0
## 永続同行（定着）エンディングの余韻に差し込む個別文。空ならタイプ既定文を使う。
@export var ending_fragment: String = ""
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
## 希望達成時に永続同行を打診する基礎確率（%）。絆1につき+15%される。
@export var settle_chance_percent: int = 0
@export var portrait: Texture2D
