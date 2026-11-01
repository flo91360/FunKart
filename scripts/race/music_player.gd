class_name MusicPlayer
extends AudioStreamPlayer
## Lecteur de la musique de course : les échantillons de MusicSynth sont
## calculés et envoyés au fur et à mesure (AudioStreamGenerator), sans fichier
## audio et sans calcul au lancement du jeu.

var song_id := ""
var _synth: MusicSynth
var _playback: AudioStreamGeneratorPlayback
var _frames := PackedVector2Array()


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MusicSynth.RATE
	if "mix_rate_mode" in gen:
		gen.set("mix_rate_mode", 2) # fréquence choisie ici (MIX_RATE_CUSTOM)
	gen.buffer_length = 0.5
	stream = gen
	bus = AppSettings.BUS_MUSIC
	volume_db = -14.0


## Joue un morceau de MusicSynth.SONGS depuis le début.
func play_song(id: String) -> void:
	_synth = MusicSynth.new(id)
	song_id = _synth.song_id
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	_fill()


func _process(_delta: float) -> void:
	if playing:
		_fill()


func _fill() -> void:
	if _playback == null or _synth == null:
		return
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	var samples := _synth.render(n)
	_frames.resize(n)
	for i in n:
		_frames[i] = Vector2(samples[i], samples[i])
	_playback.push_buffer(_frames)
