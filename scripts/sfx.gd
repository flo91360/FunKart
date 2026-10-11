class_name Sfx
extends Node
## Sons, musique et voix, générés par le code (aucun fichier audio).

const RATE := 22050.0

var engine := AudioStreamPlayer.new()
var music := AudioStreamPlayer.new()
var _pool: Array[AudioStreamPlayer] = []
var _sounds := {}


func _ready() -> void:
	_sounds["key_ok"] = _wav(_tones([[1046.0, 0.05]], "triangle", 0.25))
	_sounds["key_error"] = _wav(_tones([[150.0, 0.16]], "square", 0.15))
	_sounds["count"] = _wav(_tones([[440.0, 0.3]], "square", 0.2))
	_sounds["go"] = _wav(_tones([[880.0, 0.6]], "square", 0.2))
	_sounds["word"] = _wav(_tones([[523.0, 0.07], [659.0, 0.07], [784.0, 0.07], [1047.0, 0.18]], "triangle", 0.35))
	_sounds["finish"] = _wav(_tones([[523.0, 0.15], [523.0, 0.15], [523.0, 0.15], [659.0, 0.3], [784.0, 0.2],
		[659.0, 0.15], [784.0, 0.6]], "square", 0.18))
	_sounds["boost"] = _wav(_whoosh())
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	engine.stream = _wav(_engine_loop(), true)
	engine.volume_db = -18.0
	add_child(engine)
	music.stream = _wav(_music_loop(), true)
	music.volume_db = -14.0
	add_child(music)


func play(sound_name: String) -> void:
	if not GameSettings.data.sound:
		return
	for p in _pool:
		if not p.playing:
			p.stream = _sounds[sound_name]
			p.play()
			return
	_pool[0].stream = _sounds[sound_name]
	_pool[0].play()


func start_race_audio() -> void:
	if GameSettings.data.sound:
		engine.play()
	if GameSettings.data.music and not music.playing:
		music.play()
	elif not GameSettings.data.music:
		music.stop()


func stop_engine() -> void:
	engine.stop()


func set_engine_speed(mult: float) -> void:
	engine.pitch_scale = clampf(0.6 + mult * 0.55, 0.3, 3.0)


func speak(text: String) -> void:
	if not GameSettings.data.speak or DisplayServer.get_name() == "headless":
		return
	var voices := DisplayServer.tts_get_voices_for_language("fr")
	if voices.is_empty():
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voices[0], 80, 1.0, 0.8)


# ---------- synthèse ----------

static func _osc(wave: String, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match wave:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(p - 0.5) - 1.0
		"saw":
			return 2.0 * p - 1.0
	return sin(p * TAU)


func _tones(seq: Array, wave: String, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for note in seq:
		var freq: float = note[0]
		var dur: float = note[1]
		var n := int(dur * RATE)
		var phase := 0.0
		for i in n:
			var t := i / RATE
			var env := minf(1.0, i / (0.004 * RATE)) * exp(-2.5 * t / dur)
			out.append(_osc(wave, phase) * env * vol)
			phase += freq / RATE
	return out


func _whoosh() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(0.5 * RATE)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var noise := randf() * 2.0 - 1.0
		var k := lerpf(0.05, 0.5, t)
		lp += (noise - lp) * k
		out.append(lp * sin(t * PI) * 0.5)
	return out


func _engine_loop() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(0.5 * RATE)
	for i in n:
		var t := i / RATE
		var v := _osc("saw", t * 56.0) * 0.5 + _osc("square", t * 112.0) * 0.2 + (randf() - 0.5) * 0.08
		out.append(v * 0.6)
	return out


## Petite boucle musicale joyeuse (do - sol - la mineur - fa).
func _music_loop() -> PackedFloat32Array:
	var beat := 60.0 / 150.0
	var chords := [[261.6, 329.6, 392.0], [196.0, 246.9, 293.7], [220.0, 261.6, 329.6], [174.6, 220.0, 261.6]]
	var melody := [784.0, 659.0, 784.0, 880.0, 784.0, 659.0, 587.0, 659.0,
		587.0, 494.0, 587.0, 659.0, 587.0, 494.0, 392.0, 494.0,
		523.0, 659.0, 880.0, 784.0, 659.0, 523.0, 587.0, 659.0,
		698.0, 659.0, 587.0, 523.0, 587.0, 659.0, 587.0, 523.0]
	var total := int(beat * 16.0 * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var eighth := beat / 2.0
	for i in total:
		var t := i / RATE
		var bar := int(t / (beat * 4.0)) % 4
		var chord: Array = chords[bar]
		var e := int(t / eighth)
		var te := t - e * eighth
		var arp: float = chord[[0, 1, 2, 1][e % 4]] * 2.0
		var v := _osc("square", t * arp) * 0.05 * exp(-6.0 * te)
		var mel: float = melody[e % melody.size()]
		v += _osc("triangle", t * mel) * 0.12 * exp(-3.0 * te)
		var q := int(t / beat)
		var tq := t - q * beat
		v += _osc("triangle", t * chord[0] / 2.0) * 0.2 * exp(-2.0 * tq)
		if q % 2 == 1 and tq < 0.04:
			v += (randf() - 0.5) * 0.15 * (1.0 - tq / 0.04)
		out[i] = v
	return out


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w
