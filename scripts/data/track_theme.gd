@tool
class_name TrackTheme
extends Resource
## Thème visuel d'un circuit (couleurs, ciel, décor). Un même tracé peut
## changer d'ambiance en changeant de thème.

@export var id := ""
@export var title := ""
@export_group("Sol et route")
@export var grass_a := Color("#78ba54")
@export var grass_b := Color("#6bab4a")
@export var road_color := Color("#575a63")
@export var line_color := Color("#f2f2f2")
@export var curb_a := Color("#e61f26")
@export var curb_b := Color("#f7f7f7")
@export_group("Ciel et lumière")
@export var sky_top := Color("#2f7fe0")
@export var sky_horizon := Color("#b8dcff")
@export var fog_color := Color("#cfe6ff")
@export var fog_density := 0.0007
@export var ambient_color := Color("#c9d6e8")
@export var ambient_energy := 0.35
@export var sun_energy := 0.8
@export var sun_rotation := Vector3(-55, -35, 0)
@export_group("Décor")
@export var tree_trunk := Color("#7a4b2a")
@export var tree_leaves := PackedColorArray([Color("#2d9a3e"), Color("#3fb24f"), Color("#23863a"), Color("#56c25a")])
@export var tree_count := 170
@export var hills_color := Color("#4caf50")
@export var cloud_count := 22
@export var grandstand := true
@export var flags := PackedColorArray([Color("#e63946"), Color("#ffd60a"), Color("#2d7ff9"), Color("#17b169")])
