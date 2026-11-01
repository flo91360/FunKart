class_name MusicSynth
extends RefCounted
## Musique de course, jouée par le code (aucun fichier audio).
##
## Chaque morceau de SONGS est décrit par des données : tempo, instrument de
## la mélodie, accords (un par mesure de 4 temps), mélodie (une note par
## croche, numéros MIDI : 60 = do 4, 72 = do 5 ; -1 = silence) et ordre des
## parties (« form »). Une partie suivie de « + » est jouée plus riche
## (arpège aigu, charleston). Un morceau dure de 35 à 45 s avant de recommencer.
##
## render() calcule les échantillons au fur et à mesure (MusicPlayer les envoie
## au haut-parleur ; les tests les vérifient). Chaque voix est calculée d'un
## bloc entre deux doubles croches : peu de calcul pour les ordinateurs modestes.

const RATE := 22050.0
## Durée de la montée d'une note (en échantillons, ~3 ms) : pas de « clic ».
const ATTACK := 60.0

enum { WAVE_SINE, WAVE_TRIANGLE, WAVE_SQUARE, WAVE_SAW, WAVE_NOISE, WAVE_HAT }
const WAVES := {"sine": WAVE_SINE, "triangle": WAVE_TRIANGLE, "square": WAVE_SQUARE, "saw": WAVE_SAW}

## Basse : doubles croches de chaque temps où elle joue (« octave » : la
## deuxième note une octave plus haut).
const BASS_PATTERNS := {"beat": [0], "offbeat": [2], "octave": [0, 2], "gallop": [0, 2, 3]}
const NOTE_NAMES := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

const SONGS := {
	"prairie": {
		"title": "Prairie", "bpm": 150.0, "lead": "triangle", "lead_decay": 3.0, "lead_vol": 0.12,
		"bass": "beat", "hats": "full",
		"form": ["A", "A+", "B", "A+", "B+", "A"],
		"sections": {
			"A": {"chords": ["C", "G", "Am", "F"], "melody": [
				79, 76, 79, 81, 79, 76, 74, 76,
				74, 71, 74, 76, 74, 71, 67, 71,
				72, 76, 81, 79, 76, 72, 74, 76,
				77, 76, 74, 72, 74, 76, 74, 72]},
			"B": {"chords": ["F", "G", "Em", "Am"], "melody": [
				77, -1, 76, 77, 81, -1, 79, 77,
				79, -1, 77, 79, 83, -1, 81, 79,
				76, 79, 83, 79, 76, 74, 71, 74,
				76, -1, 72, -1, 69, -1, -1, -1]},
		},
	},
	"plage": {
		"title": "Plage", "bpm": 128.0, "lead": "sine", "lead_decay": 7.0, "lead_vol": 0.16,
		"bass": "offbeat", "hats": "full",
		"form": ["A", "A+", "B", "A+", "B+", "A"],
		"sections": {
			"A": {"chords": ["F", "Bb", "C", "F"], "melody": [
				72, -1, 69, 72, 77, -1, 76, 74,
				74, -1, 70, 74, 77, -1, 74, 72,
				72, -1, 67, 72, 76, 74, 72, 70,
				69, -1, 72, -1, 65, -1, -1, -1]},
			"B": {"chords": ["Dm", "Bb", "C", "C"], "melody": [
				69, 69, 74, -1, 72, 69, 65, -1,
				70, 70, 74, -1, 72, 70, 65, -1,
				67, 69, 70, 72, 74, 72, 70, 69,
				67, -1, 72, -1, 76, -1, 79, -1]},
		},
	},
	"montagne": {
		"title": "Montagne", "bpm": 160.0, "lead": "square", "lead_decay": 4.0, "lead_vol": 0.07,
		"bass": "octave", "hats": "always",
		"form": ["A", "A+", "B", "B+", "A+", "A"],
		"sections": {
			"A": {"chords": ["G", "Em", "C", "D"], "melody": [
				79, 78, 79, 74, 71, 74, 79, -1,
				76, 74, 76, 71, 67, 71, 76, -1,
				76, 74, 72, 74, 76, 79, 76, 72,
				74, -1, 78, -1, 81, -1, 78, 74]},
			"B": {"chords": ["C", "D", "Bm", "Em"], "melody": [
				72, 74, 76, 79, 76, 74, 72, -1,
				74, 76, 78, 81, 78, 76, 74, -1,
				71, 74, 78, 74, 71, 74, 78, 83,
				79, -1, 76, -1, 71, -1, -1, -1]},
		},
	},
	"canyon": {
		"title": "Canyon", "bpm": 140.0, "lead": "saw", "lead_decay": 3.5, "lead_vol": 0.07,
		"bass": "gallop", "hats": "full",
		"form": ["A", "A+", "B", "A+", "B+", "A"],
		"sections": {
			"A": {"chords": ["Am", "G", "F", "E"], "melody": [
				69, -1, 72, 76, -1, 74, 72, 69,
				67, -1, 71, 74, -1, 72, 71, 67,
				65, -1, 69, 72, -1, 74, 72, 69,
				68, -1, 71, -1, 76, -1, 74, 71]},
			"B": {"chords": ["Dm", "Am", "E", "Am"], "melody": [
				74, 76, 77, 76, 74, -1, 69, -1,
				72, 74, 76, 74, 72, -1, 69, -1,
				71, 72, 74, 76, 80, -1, 76, -1,
				81, -1, 76, -1, 69, -1, -1, -1]},
		},
	},
}


## Une voix (mélodie, arpège, basse, batterie) : forme d'onde et enveloppe.
class Voice:
	var wave := 0
	var vol := 0.1
	var decay := 0.9997 # facteur par échantillon
	var freq := 440.0
	var glide := 1.0 # la grosse caisse descend en fréquence
	var min_freq := 0.0
	var phase := 0.0
	var env := 0.0
	var age := 0
	var last := 0.0 # bruit précédent (charleston)

	func _init(p_wave: int, p_vol: float, decay_per_second: float, rate: float, p_glide := 1.0, p_min_freq := 0.0) -> void:
		wave = p_wave
		vol = p_vol
		decay = exp(-decay_per_second / rate)
		glide = p_glide
		min_freq = p_min_freq

	func trigger(f: float) -> void:
		freq = f
		phase = 0.0
		env = 1.0
		age = 0


var song_id := ""
var _song: Dictionary
var _step_samples := 1.0 # échantillons par double croche
var _n := 0 # échantillons déjà calculés
var _step := -1
var _out := PackedFloat32Array()
var _lead: Voice
var _arp: Voice
var _arp_hi: Voice
var _bass: Voice
var _kick: Voice
var _snare: Voice
var _hat: Voice
var _voices: Array[Voice] = []


func _init(p_song_id: String) -> void:
	song_id = p_song_id if SONGS.has(p_song_id) else "prairie"
	_song = SONGS[song_id]
	_step_samples = RATE * 60.0 / float(_song.bpm) / 4.0
	_lead = Voice.new(WAVES.get(_song.lead, WAVE_TRIANGLE), float(_song.lead_vol), float(_song.lead_decay), RATE)
	_arp = Voice.new(WAVE_SQUARE, 0.045, 6.0, RATE)
	_arp_hi = Voice.new(WAVE_TRIANGLE, 0.035, 8.0, RATE)
	_bass = Voice.new(WAVE_TRIANGLE, 0.18, 2.5, RATE)
	_kick = Voice.new(WAVE_SINE, 0.22, 14.0, RATE, 0.9993, 45.0)
	_snare = Voice.new(WAVE_NOISE, 0.07, 28.0, RATE)
	_hat = Voice.new(WAVE_HAT, 0.035, 55.0, RATE)
	_voices = [_lead, _arp, _arp_hi, _bass, _kick, _snare, _hat]


static func midi_freq(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## Notes MIDI d'un accord (« C », « Am », « F#m », « Bb »…), fondamentale à l'octave 3.
static func chord_tones(chord: String) -> Array:
	var root: int = NOTE_NAMES[chord[0]]
	var rest := chord.substr(1)
	if rest.begins_with("#"):
		root += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		root -= 1
		rest = rest.substr(1)
	var r := 48 + root
	return [r, r + (3 if rest == "m" else 4), r + 7]


## Durée d'un morceau avant qu'il recommence (secondes).
static func song_seconds(id: String) -> float:
	var song: Dictionary = SONGS[id]
	return song.form.size() * 4 * 4 * 60.0 / float(song.bpm)


## Les count échantillons suivants (entre -1 et 1).
func render(count: int) -> PackedFloat32Array:
	_out.resize(count)
	_out.fill(0.0)
	var done := 0
	while done < count:
		var step := int(_n / _step_samples)
		if step != _step:
			_step = step
			_on_step(step)
		# jusqu'à la double croche suivante : aucune nouvelle note
		var seg := mini(count - done, int(ceil((_step + 1) * _step_samples)) - _n)
		if seg <= 0:
			seg = 1
		for v in _voices:
			_render_voice(v, done, seg)
		_n += seg
		done += seg
	for i in count:
		_out[i] = clampf(_out[i], -1.0, 1.0)
	return _out


## Nouvelle double croche : notes de la mélodie, de l'arpège, de la basse et
## de la batterie qui commencent maintenant.
func _on_step(step: int) -> void:
	var form: Array = _song.form
	var bar := step / 16
	var item: String = form[(bar / 4) % form.size()]
	var rich := item.ends_with("+")
	var section: Dictionary = _song.sections[item.trim_suffix("+")]
	var bar_in := bar % 4
	var pos := step % 16
	var tones := chord_tones(section.chords[bar_in])
	if pos % 2 == 0:
		var eighth := pos / 2
		var note: int = section.melody[bar_in * 8 + eighth]
		if note >= 0:
			_lead.trigger(midi_freq(note))
		_arp.trigger(midi_freq(tones[[0, 1, 2, 1][eighth % 4]] + 24))
		if rich:
			_arp_hi.trigger(midi_freq(tones[[2, 1, 0, 1][eighth % 4]] + 36))
	var in_beat := pos % 4
	var pattern: Array = BASS_PATTERNS[_song.bass]
	var k := pattern.find(in_beat)
	if k != -1:
		# basse entre fa 2 et mi 3
		var root: int = tones[0] - 12 if tones[0] >= 53 else tones[0]
		_bass.trigger(midi_freq(root + (12 if _song.bass == "octave" and k == 1 else 0)))
	if in_beat == 0:
		if (pos / 4) % 2 == 0:
			_kick.trigger(150.0)
		else:
			_snare.trigger(1.0)
	if in_beat % 2 == 0 and (_song.hats == "always" or (_song.hats == "full" and rich)):
		_hat.trigger(1.0)


func _render_voice(v: Voice, start: int, count: int) -> void:
	if v.env < 0.0003:
		return
	var p := v.phase
	var f := v.freq
	var e := v.env
	var d := v.decay
	var age := v.age
	var vol := v.vol
	var end := start + count
	match v.wave:
		WAVE_SQUARE:
			var inc := f / RATE
			for i in range(start, end):
				_out[i] += (1.0 if p < 0.5 else -1.0) * e * minf(1.0, age / ATTACK) * vol
				p += inc
				if p >= 1.0:
					p -= 1.0
				e *= d
				age += 1
		WAVE_TRIANGLE:
			var inc := f / RATE
			for i in range(start, end):
				_out[i] += (4.0 * absf(p - 0.5) - 1.0) * e * minf(1.0, age / ATTACK) * vol
				p += inc
				if p >= 1.0:
					p -= 1.0
				e *= d
				age += 1
		WAVE_SAW:
			var inc := f / RATE
			for i in range(start, end):
				_out[i] += (2.0 * p - 1.0) * e * minf(1.0, age / ATTACK) * vol
				p += inc
				if p >= 1.0:
					p -= 1.0
				e *= d
				age += 1
		WAVE_SINE:
			for i in range(start, end):
				_out[i] += sin(p * TAU) * e * minf(1.0, age / ATTACK) * vol
				p += f / RATE
				if p >= 1.0:
					p -= 1.0
				f = maxf(v.min_freq, f * v.glide)
				e *= d
				age += 1
		WAVE_NOISE:
			for i in range(start, end):
				_out[i] += (randf() * 2.0 - 1.0) * e * vol
				e *= d
		WAVE_HAT:
			# bruit « aigu » : différence de deux bruits successifs
			var last := v.last
			for i in range(start, end):
				var n := randf() * 2.0 - 1.0
				_out[i] += (n - last) * e * vol
				last = n
				e *= d
			v.last = last
	v.phase = p
	v.freq = f
	v.env = e
	v.age = age
