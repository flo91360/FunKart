class_name Characters
## Les pilotes : des animaux construits à partir de formes simples.
## ears : cat, round, floppy, long, mouse, monkey, none
## extra : unicorn, panda, lion, penguin, turtle, frog, monkey

const PLAYER_IDS := ["chat", "chien", "grenouille", "licorne", "panda", "lion", "singe", "pingouin"]
const BOT_IDS := ["tortue", "lapin", "renard", "ours", "souris"]

const ALL := {
	"chat": {"name": "Chat", "fur": Color("#f4a340"), "kart": Color("#ff4f2e"), "shirt": Color("#2d7ff9"),
		"ears": "cat", "ear": Color("#f4a340"), "snout": Color("#fff3e0")},
	"chien": {"name": "Chien", "fur": Color("#d9a066"), "kart": Color("#2d7ff9"), "shirt": Color("#ffd23f"),
		"ears": "floppy", "ear": Color("#7a4b2a"), "snout": Color("#f5deb3")},
	"grenouille": {"name": "Grenouille", "fur": Color("#5cc85a"), "kart": Color("#17b169"), "shirt": Color("#ff7aa2"),
		"ears": "none", "extra": "frog"},
	"licorne": {"name": "Licorne", "fur": Color("#fbf7ff"), "kart": Color("#b46cff"), "shirt": Color("#ff9ad5"),
		"ears": "cat", "ear": Color("#fbf7ff"), "snout": Color("#ffe1f0"), "extra": "unicorn"},
	"panda": {"name": "Panda", "fur": Color("#ffffff"), "kart": Color("#3d3d4e"), "shirt": Color("#7bd389"),
		"ears": "round", "ear": Color("#1c1c1c"), "snout": Color("#ffffff"), "extra": "panda"},
	"lion": {"name": "Lion", "fur": Color("#f2c14e"), "kart": Color("#ffb400"), "shirt": Color("#d7263d"),
		"ears": "round", "ear": Color("#f2c14e"), "snout": Color("#fff1c9"), "extra": "lion"},
	"singe": {"name": "Singe", "fur": Color("#8b5a2b"), "kart": Color("#ff8c00"), "shirt": Color("#3ec1d3"),
		"ears": "monkey", "ear": Color("#f1c27d"), "extra": "monkey"},
	"pingouin": {"name": "Pingouin", "fur": Color("#22252b"), "kart": Color("#00a6fb"), "shirt": Color("#22252b"),
		"ears": "none", "extra": "penguin"},
	"tortue": {"name": "Tortue", "fur": Color("#8bc34a"), "kart": Color("#2a9d8f"), "shirt": Color("#f4d35e"),
		"ears": "none", "extra": "turtle"},
	"lapin": {"name": "Lapin", "fur": Color("#f2f2f2"), "kart": Color("#e63946"), "shirt": Color("#457b9d"),
		"ears": "long", "ear": Color("#f2f2f2"), "snout": Color("#ffffff")},
	"renard": {"name": "Renard", "fur": Color("#f26b1d"), "kart": Color("#f4a261"), "shirt": Color("#264653"),
		"ears": "cat", "ear": Color("#f26b1d"), "snout": Color("#ffffff")},
	"ours": {"name": "Ours", "fur": Color("#8d5524"), "kart": Color("#6a4c93"), "shirt": Color("#ff595e"),
		"ears": "round", "ear": Color("#8d5524"), "snout": Color("#d9b38c")},
	"souris": {"name": "Souris", "fur": Color("#b0b7c3"), "kart": Color("#ff99c8"), "shirt": Color("#fcf6bd"),
		"ears": "mouse", "ear": Color("#b0b7c3"), "snout": Color("#e5e5e5")},
}


static func get_info(id: String) -> Dictionary:
	return ALL.get(id, ALL["chat"])
