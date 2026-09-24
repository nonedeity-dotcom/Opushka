## Звуки. Файлы синтезированы скриптом tools/make-sounds.js — свои, без чужих лицензий.
##
## На каждый звук — две дорожки по очереди: второй укус, пришедший, пока первый звучит,
## не обрывает его. Фон — тихий гул глубины с пузырьками, включается и гаснет плавно.
extends Node

const EFFECTS := ["eat", "eat_meat", "bite", "hit", "hurt", "kill", "pickup", "newpart", "levelup",
	"dash", "zap", "poison", "death", "ui", "place", "remove", "nope", "goal", "drop", "rock", "mate"]
## Насколько тише остальных: частые звуки не должны заглушать редкие.
const LEVEL := {"eat": -6.0, "ui": -4.0, "nope": -3.0, "hit": -2.0, "dash": -3.0}

var effects_on := true
var effects_db := -6.0
var ambience_on := true
var ambience_db := -16.0

var _players := {}
var _turn := {}
var _water: AudioStreamPlayer
## Не чаще раза в столько секунд — чтобы десять водорослей подряд не слились в треск.
var _last := {}
const GAP := 0.06

func _ready() -> void:
	for id in EFFECTS:
		var stream: AudioStream = load("res://sounds/%s.wav" % id)
		var pair: Array[AudioStreamPlayer] = []
		for i in 2:
			var p := AudioStreamPlayer.new()
			p.stream = stream
			add_child(p)
			pair.append(p)
		_players[id] = pair
	var loop: AudioStreamWAV = load("res://sounds/amb_water.wav")
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	_water = AudioStreamPlayer.new()
	_water.stream = loop
	_water.volume_db = -80.0
	add_child(_water)

func configure(s: Settings) -> void:
	effects_on = s.sound
	effects_db = Settings.VOLUME[s.volume][0]
	ambience_on = s.ambience
	ambience_db = Settings.VOLUME[s.volume][1]
	set_ambience(true)

func play(id: String, pitch := 1.0) -> void:
	if not effects_on or not _players.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -1.0)) < GAP:
		return
	_last[id] = now
	var n: int = _turn.get(id, 0)
	_turn[id] = n + 1
	var p: AudioStreamPlayer = _players[id][n % 2]
	p.volume_db = effects_db + LEVEL.get(id, 0.0)
	p.pitch_scale = pitch
	p.play()

func set_ambience(on: bool) -> void:
	var want := on and ambience_on
	var goal := ambience_db if want else -80.0
	if want and not _water.playing:
		_water.volume_db = -60.0
		_water.play()
	var t := create_tween()
	t.tween_property(_water, "volume_db", goal, 1.5)
	if not want:
		t.tween_callback(_water.stop)
