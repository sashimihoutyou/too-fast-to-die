class_name QuestData extends Resource

## サブストーリー（クエスト）定義。
## アウトカム（hunt / poison / ignore / lapse 等）は成功/失敗の二値ではなく名前付きで、
## 各アウトカムが「報酬束＋遅延ペイロード最大1」を持つ。設計の全体像は
## docs/scenarios/substories/devilf-pack.md を参照。

@export var id: StringName
@export var title: String
@export var summary: String
@export var required_act: int = -1
## 期限。導入ノードからこのノード数以内に追跡系アウトカム（hunt）を達成する。
@export var node_limit: int = 5

## hunt系アウトカムの追跡条件：敵idがこの文字列を含み、かつボスでない撃破を数える。
@export var objective_match: StringName = &""
@export var objective_count: int = 0

## 遅延ペイロード（特定アウトカムが装填する強制発火イベント）。
@export var payload_event: StringName = &""
## payload_event を装填するアウトカム一覧。既存クエスト互換のため既定は poison。
@export var payload_outcomes: Array[StringName] = [&"poison"]
## 装填から何ノード後に発火可能になるか。
@export var payload_min_gap: int = 1
## テレグラフを「知り得た」PCがペイロードを解決した時の追加カルマ（負値）。
@export var payload_knew_extra_karma: int = 0

## ボス修飾。boss_mods は outcome(String) -> { "hp_scale": float, "adds": int } のテーブル。
@export var boss_target: StringName = &""
@export var boss_add_enemy: StringName = &""
@export var boss_mods: Dictionary = {}
