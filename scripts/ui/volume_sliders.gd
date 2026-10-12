class_name VolumeSliders
extends GridContainer
## Curseurs de volume (général, musique, effets), enregistrés dans AppSettings.
## Utilisé dans le menu pause et dans les réglages.

const ROWS := [["Volume général", "volume_master"], ["Musique", "volume_music"], ["Effets", "volume_effects"]]

var _sliders := {}


func _ready() -> void:
	columns = 3
	add_theme_constant_override("h_separation", 14)
	add_theme_constant_override("v_separation", 8)
	for row in ROWS:
		var key: String = row[1]
		add_child(Ui.label(row[0], 22))
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.custom_minimum_size = Vector2(240, 36)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(slider)
		var value_label := Ui.label("", 22)
		value_label.custom_minimum_size.x = 64
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(value_label)
		slider.value_changed.connect(func(v):
			value_label.text = "%d %%" % int(v)
			AppSettings.set_value(key, v / 100.0))
		_sliders[key] = [slider, value_label]
	refresh()


func refresh() -> void:
	for key in _sliders:
		var v := roundf(float(AppSettings.get_value(key)) * 100.0)
		_sliders[key][0].set_value_no_signal(v)
		_sliders[key][1].text = "%d %%" % int(v)
