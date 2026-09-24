## Звуки «Опушки». Файлы синтезированы скриптом tools/make-village-sounds.js — свои, без
## чужих лицензий.
##
## На каждый звук — две дорожки по очереди: второй удар топора, пришедший, пока первый
## звучит, не обрывает его. Шаг — двумя разными файлами: одинаковые шаги подряд звучат как
## метроном. Фон — день (ветер и птицы) и ночь (сверчки), со сменой через затухание.
extends Node

const EFFECTS := ["step1", "step2", "twig", "pebble", "chop", "stone", "berries", "water", "eat",
	"craft", "place", "pickup", "sleep", "goal", "nope", "ui", "bag", "dig", "plant", "pour", "harvest",
	"cluck", "pet"]
## Насколько тише остальных: шаги — фон, их не должно быть слышно громче топора.
const LEVEL := {"step1": -7.0, "step2": -7.0, "ui": -4.0, "nope": -3.0}

var effects_on := true
var effects_db := -6.0
var ambience_on := true
var ambience_db := -16.0

var _players := {}
var _turn := {}
var _foot := 0
var _day: AudioStreamPlayer
var _night: AudioStreamPlayer
var _want := ""

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
	_day = _loop("amb_day")
	_night = _loop("amb_night")

func _loop(id: String) -> AudioStreamPlayer:
	var stream: AudioStreamWAV = load("res://sounds/%s.wav" % id)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -80.0
	add_child(p)
	return p

func configure(s: Settings) -> void:
	effects_on = s.sound
	effects_db = Settings.VOLUME[s.volume][0]
	ambience_on = s.ambience
	ambience_db = Settings.VOLUME[s.volume][1]
	set_ambience(_want)

func play(id: String) -> void:
	if not effects_on or id == "":
		return
	if id == "step":
		id = "step1" if _foot % 2 == 0 else "step2"
		_foot += 1
	if not _players.has(id):
		return
	var n: int = _turn.get(id, 0)
	_turn[id] = n + 1
	var p: AudioStreamPlayer = _players[id][n % 2]
	p.volume_db = effects_db + LEVEL.get(id, 0.0)
	p.play()

## "day", "night" или "" — тишина.
func set_ambience(kind: String) -> void:
	_want = kind
	var target := kind if ambience_on else ""
	_fade(_day, target == "day")
	_fade(_night, target == "night")

func _fade(p: AudioStreamPlayer, on: bool) -> void:
	var goal := ambience_db if on else -80.0
	if on and not p.playing:
		p.volume_db = -60.0
		p.play()
	var t := create_tween()
	t.tween_property(p, "volume_db", goal, 1.5)
	if not on:
		t.tween_callback(p.stop)
