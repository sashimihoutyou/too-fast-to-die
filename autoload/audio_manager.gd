extends Node

var bgm_player: AudioStreamPlayer
var se_player: AudioStreamPlayer

var bgm_bus := &"Master"
var se_bus := &"Master"

var _current_bgm_path: String = ""

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = bgm_bus
	add_child(bgm_player)
	se_player = AudioStreamPlayer.new()
	se_player.bus = se_bus
	add_child(se_player)

func play_bgm(path: String, volume_db: float = -10.0) -> void:
	if path == _current_bgm_path and bgm_player.playing:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_current_bgm_path = path
	bgm_player.stream = stream
	bgm_player.volume_db = volume_db
	bgm_player.play()

func stop_bgm() -> void:
	bgm_player.stop()
	_current_bgm_path = ""

func play_se(path: String, volume_db: float = -5.0) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = se_bus
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func set_bgm_volume(db: float) -> void:
	bgm_player.volume_db = db

func set_se_volume(db: float) -> void:
	se_player.volume_db = db
