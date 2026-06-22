extends Node

## サブストーリー（クエスト）の実行時状態を一元管理する Autoload。
## 期限は GameManager.total_nodes_visited（単調増加）を基準にする。
## 設計の全体像は docs/substory-devilf-pack.md を参照。

var _defs: Dictionary = {}             # id(StringName) -> QuestData
var _state: Dictionary = {}            # id(StringName) -> 実行時状態 Dictionary
var _armed: Array[Dictionary] = []     # 強制発火待ちの遅延ペイロード

func _ready() -> void:
	_load_defs("res://resources/quests")

func reset() -> void:
	_state.clear()
	_armed.clear()

func get_def(id: StringName) -> QuestData:
	return _defs.get(id, null)

# イベント選択でアウトカムが確定した時に event_screen から呼ばれる。
# 追跡系（hunt）は進捗を持ち、遅延系（poison）はペイロードを装填する。
func record_outcome(quest_id: StringName, outcome: StringName) -> void:
	var def: QuestData = _defs.get(quest_id, null)
	if def == null:
		return
	var st: Dictionary = {
		"outcome": outcome,
		"complete": false,
		"lapsed": false,
		"progress": 0,
		"deadline": GameManager.total_nodes_visited + def.node_limit,
		"knew": _pc_can_read(),
	}
	_state[quest_id] = st
	# 遅延ペイロードを装填するアウトカムか（このクエストでは poison）。
	if outcome == &"poison" and def.payload_event != &"":
		_armed.append({
			"quest_id": quest_id,
			"event_id": def.payload_event,
			"act": GameManager.current_act,
			"ready_at": GameManager.total_nodes_visited + def.payload_min_gap,
		})

# 敵撃破時に CombatManager から呼ばれる。hunt 追跡を進める。
func on_enemy_defeated(data: EnemyData) -> void:
	if data == null:
		return
	for quest_id: StringName in _state:
		var st: Dictionary = _state[quest_id]
		var outcome: StringName = st.get("outcome", &"")
		var complete: bool = st.get("complete", false)
		var lapsed: bool = st.get("lapsed", false)
		if outcome != &"hunt" or complete or lapsed:
			continue
		var def: QuestData = _defs.get(quest_id, null)
		if def == null or def.objective_match == &"" or data.is_boss:
			continue
		if String(data.id).contains(String(def.objective_match)):
			var progress: int = int(st.get("progress", 0)) + 1
			st["progress"] = progress
			if progress >= def.objective_count:
				st["complete"] = true
				KarmaManager.add_karma(5)  # 完遂報酬（遅延・小）

# ノード入場時に GameManager から呼ばれる。hunt の期限切れを lapse に落とす。
func on_node_advanced() -> void:
	for quest_id: StringName in _state:
		var st: Dictionary = _state[quest_id]
		var outcome: StringName = st.get("outcome", &"")
		var complete: bool = st.get("complete", false)
		var lapsed: bool = st.get("lapsed", false)
		if outcome != &"hunt" or complete or lapsed:
			continue
		var deadline: int = int(st.get("deadline", 0))
		if GameManager.total_nodes_visited > deadline:
			st["lapsed"] = true

# EVENTノード入場時に event_screen から呼ばれる。発火可能な遅延ペイロードidを返す。
func get_pending_payload(act: int) -> StringName:
	for entry: Dictionary in _armed:
		var entry_act: int = int(entry.get("act", -1))
		var ready_at: int = int(entry.get("ready_at", 0))
		if entry_act != act or GameManager.total_nodes_visited < ready_at:
			continue
		var eid: StringName = entry.get("event_id", &"")
		var already_seen: bool = GameManager.event_flags.get(eid, false)
		if eid != &"" and not already_seen:
			return eid
	return &""

# ペイロード解決時に event_screen から呼ばれる。発火済みにし、知り得たPCへ追加カルマ。
func notify_event_resolved(event_id: StringName) -> void:
	for i in range(_armed.size() - 1, -1, -1):
		var entry: Dictionary = _armed[i]
		var eid: StringName = entry.get("event_id", &"")
		if eid != event_id:
			continue
		var quest_id: StringName = entry.get("quest_id", &"")
		var def: QuestData = _defs.get(quest_id, null)
		var st: Dictionary = _state.get(quest_id, {})
		var knew: bool = st.get("knew", false)
		if def != null and knew and def.payload_knew_extra_karma != 0:
			KarmaManager.add_karma(def.payload_knew_extra_karma)
		_armed.remove_at(i)

# ボス戦の修飾（HP倍率・追加ザコ数・追加ザコid）を返す。
func get_boss_modifier(act: int) -> Dictionary:
	for quest_id: StringName in _state:
		var def: QuestData = _defs.get(quest_id, null)
		if def == null or def.required_act != act or def.boss_mods.is_empty():
			continue
		var key: String = _effective_outcome(quest_id)
		var mod: Dictionary = def.boss_mods.get(key, {})
		if not mod.is_empty():
			return {
				"hp_scale": float(mod.get("hp_scale", 1.0)),
				"adds": int(mod.get("adds", 0)),
				"add_enemy": def.boss_add_enemy,
			}
	return {"hp_scale": 1.0, "adds": 0, "add_enemy": &""}

# マップHUD用：追跡中（hunt）クエストの一行サマリ。なければ空文字。
func get_hud_summary() -> String:
	for quest_id: StringName in _state:
		var st: Dictionary = _state[quest_id]
		var outcome: StringName = st.get("outcome", &"")
		var complete: bool = st.get("complete", false)
		var lapsed: bool = st.get("lapsed", false)
		if outcome != &"hunt" or complete or lapsed:
			continue
		var def: QuestData = _defs.get(quest_id, null)
		if def == null:
			continue
		var progress: int = int(st.get("progress", 0))
		var remaining: int = int(st.get("deadline", 0)) - GameManager.total_nodes_visited
		return "🗺 %s  %d/%d（あと%dノード）" % [def.title, progress, def.objective_count, maxi(0, remaining)]
	return ""

# hunt は完遂なら "hunt"、未完遂（途中/期限切れ）なら "lapse" をボス修飾キーとする。
func _effective_outcome(quest_id: StringName) -> String:
	var st: Dictionary = _state.get(quest_id, {})
	var outcome: StringName = st.get("outcome", &"")
	if outcome == &"hunt":
		var complete: bool = st.get("complete", false)
		return "hunt" if complete else "lapse"
	return String(outcome)

# テレグラフを「知り得た」PC：調教師（獣読み）・放浪者（観察眼）。
# 犬/密告者の同行による看破は同行者システム実装後に追加する（TODO）。
func _pc_can_read() -> bool:
	if GameManager.current_character == null:
		return false
	var cid: StringName = GameManager.current_character.id
	return cid == &"beast_master" or cid == &"wanderer"

func _load_defs(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := path.path_join(file_name)
			var def: QuestData = load(full_path)
			if def != null and def.id != &"":
				_defs[def.id] = def
		file_name = dir.get_next()
