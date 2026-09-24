## Звуки. Файлы синтезированы скриптом tools/make-sounds.js — свои, без чужих лицензий.
##
## На каждый звук — две дорожки по очереди: второй укус, пришедший, пока первый звучит,
## не обрывает его. Фон — тихий гул глубины с пузырьками, включается и гаснет плавно.
extends Node

const EFFECTS := ["eat", "eat_meat", "bite", "hit", "hurt", "kill", "pickup", "newpart", "levelup",
	"dash", "zap", "poison", "death", "ui", "place", "remove", "nope", "goal", "drop", "rock", "mate",
	"parasite", "ability", "boss", "wave", "chirp", "growl", "boom", "hiss", "spit", "split", "whale",
	"heart", "bubbles", "creak", "deep", "swell"]
## Звуки меню и подсказок — чистые, мимо «воды».
const DRY := ["ui", "nope", "goal", "place", "remove"]
## Насколько тише остальных: частые звуки не должны заглушать редкие.
const LEVEL := {"eat": -6.0, "ui": -4.0, "place": -3.0, "nope": -3.0, "hit": -2.0, "dash": -3.0, "chirp": -8.0, "hiss": -6.0, "spit": -5.0,
	"heart": -1.0, "bubbles": -10.0, "creak": -9.0, "deep": -7.0, "swell": -5.0}

var effects_on := true
var effects_db := -6.0
var ambience_on := true
var ambience_db := -16.0

var music_on := true
var music_db := -18.0
## Какая музыка должна играть: "" — никакая, "calm" — спокойная, "fight" — бой.
var music_state := ""

var _players := {}
var _music := {}
var _turn := {}
var _water: AudioStreamPlayer
## Не чаще раза в столько секунд — чтобы десять водорослей подряд не слились в треск.
var _last := {}
const GAP := 0.06

## Шины звука: «Вода» — всё, что в океане: с глубиной глуше (фильтр верхов); «Даль» —
## то, что далеко: ещё глуше и с отзвуком, как сквозь толщу воды.
var _water_bus := -1
var _far_bus := -1
var _depth_filter: AudioEffectLowPassFilter

func _buses() -> void:
	_water_bus = AudioServer.get_bus_index("Вода")
	if _water_bus != -1:
		return
	# Игра звучала тихо (около −31 LUFS по записи, у мобильных игр обычно −16…−20):
	# на общем выходе — ограничитель, он поднимает всё на 7 дБ и не пускает пики к потолку.
	var lim := AudioEffectHardLimiter.new()
	lim.pre_gain_db = 7.0
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, lim)
	_water_bus = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(_water_bus, "Вода")
	AudioServer.set_bus_send(_water_bus, "Master")
	_depth_filter = AudioEffectLowPassFilter.new()
	_depth_filter.cutoff_hz = 16000.0
	AudioServer.add_bus_effect(_water_bus, _depth_filter)
	_far_bus = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(_far_bus, "Даль")
	AudioServer.set_bus_send(_far_bus, "Вода")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 900.0
	AudioServer.add_bus_effect(_far_bus, lp)
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.7
	rev.damping = 0.6
	rev.wet = 0.35
	rev.dry = 0.8
	AudioServer.add_bus_effect(_far_bus, rev)

## Глубина (размер 1–10): чем глубже, тем глуше всё в воде.
func set_depth(level: int) -> void:
	if _depth_filter:
		_depth_filter.cutoff_hz = lerpf(16000.0, 3200.0, clampf((level - 1) / 9.0, 0.0, 1.0))

func _ready() -> void:
	_buses()
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
	_water.bus = "Вода"
	_water.stream = loop
	_water.volume_db = -80.0
	add_child(_water)
	for id in ["calm", "fight"]:
		var m: AudioStreamWAV = load("res://sounds/music_%s.wav" % id)
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		m.loop_end = int(m.get_length() * m.mix_rate)
		var mp := AudioStreamPlayer.new()
		mp.stream = m
		mp.volume_db = -80.0
		add_child(mp)
		_music[id] = mp

func configure(s: Settings) -> void:
	effects_on = s.sound
	effects_db = Settings.VOLUME[s.volume][0]
	ambience_on = s.ambience
	ambience_db = Settings.VOLUME[s.volume][1]
	music_on = s.music
	music_db = Settings.VOLUME[s.volume][1] - 2.0
	set_ambience(true)
	var want := music_state
	music_state = "-"
	set_music(want)

## far — насколько далеко (0 — рядом, 1 — у края видимого): дальше — тише и глуше.
func play(id: String, pitch := 1.0, far := 0.0) -> void:
	if not effects_on or not _players.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -1.0)) < GAP:
		return
	_last[id] = now
	var n: int = _turn.get(id, 0)
	_turn[id] = n + 1
	var p: AudioStreamPlayer = _players[id][n % 2]
	far = clampf(far, 0.0, 1.0)
	p.bus = "Master" if DRY.has(id) else ("Даль" if far > 0.3 else "Вода")
	p.volume_db = effects_db + LEVEL.get(id, 0.0) - 12.0 * far
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

## Музыка: спокойная или боевая, переход — плавный. Выключена в настройках — тишина.
func set_music(state: String) -> void:
	if state == music_state:
		return
	music_state = state
	for id in _music:
		var mp: AudioStreamPlayer = _music[id]
		var on: bool = music_on and id == state
		if on:
			if not mp.playing:
				mp.volume_db = -50.0
				mp.play()
			create_tween().tween_property(mp, "volume_db", music_db, 2.0 if id == "calm" else 0.8)
		elif mp.playing:
			var t := create_tween()
			t.tween_property(mp, "volume_db", -60.0, 1.6)
			t.tween_callback(mp.stop)
