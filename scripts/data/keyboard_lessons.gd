class_name KeyboardLessons
## Leçons du clavier AZERTY, rangée par rangée : des listes de mots générées
## à partir des listes du jeu, proposées avec elles (identifiants « lecon_… »).
##
## 1. rangée du milieu (celle où reposent les doigts : q s d f … m) : elle n'a
##    pas de voyelle en AZERTY, ce sont des exercices de lettres ;
## 2. + rangée du haut ; 3. + rangée du bas ; 4. les accents.
## À partir de la leçon 2, chaque mot contient au moins une touche de la
## nouvelle rangée et n'utilise que les rangées déjà vues.

const ROW_HOME := "qsdfghjklm"
const ROW_TOP := "azertyuiop"
const ROW_BOTTOM := "wxcvbn"
const ACCENTS := "éèàçù"

const LESSONS := [
	{
		"id": "lecon_1", "title": "Leçon 1 : rangée du milieu (q s d f g h j k l m)",
		"letters": ROW_HOME, "new": ROW_HOME,
		"drills": ["f", "j", "d", "k", "s", "l", "q", "m", "g", "h", "ff", "jj", "fj", "jf", "dk", "kd",
			"sl", "ls", "qm", "mq", "fg", "hj", "fjf", "jfj", "dfj", "jkl", "sdf", "qsd", "klm", "fgh",
			"hjk", "fjdk", "sldk", "qsdf", "jklm", "fghj", "dfjk"],
	},
	{
		"id": "lecon_2", "title": "Leçon 2 : + rangée du haut (a z e r t y u i o p)",
		"letters": ROW_HOME + ROW_TOP, "new": ROW_TOP,
		"drills": ["fa", "je", "du", "ki", "lo", "sa", "ma", "ge", "ho", "fe", "ja", "ri", "to", "pu", "ze"],
	},
	{
		"id": "lecon_3", "title": "Leçon 3 : + rangée du bas (w x c v b n)",
		"letters": ROW_HOME + ROW_TOP + ROW_BOTTOM, "new": ROW_BOTTOM,
		"drills": ["va", "be", "ne", "ci", "xo", "wa", "vu", "bo", "na", "ce"],
	},
	{
		"id": "lecon_4", "title": "Leçon 4 : les accents (é è à ç ù)",
		"letters": ROW_HOME + ROW_TOP + ROW_BOTTOM + ACCENTS, "new": ACCENTS,
		"drills": ["é", "è", "à", "ç", "ù", "école", "élève", "télé", "fée", "clé", "thé", "blé", "café",
			"bébé", "père", "mère", "frère", "très", "après", "là", "voilà", "déjà", "où", "garçon", "leçon",
			"glaçon", "maçon", "hérisson", "éléphant"],
	},
]

static var _lists: Array = []


## Le mot n'utilise que ces lettres (majuscules acceptées).
static func uses_only(word: String, letters: String) -> bool:
	for c in word.to_lower():
		if not letters.contains(c):
			return false
	return true


static func uses_any(word: String, letters: String) -> bool:
	for c in word.to_lower():
		if letters.contains(c):
			return true
	return false


## Mots d'une leçon : ses exercices, puis les mots de pool qui conviennent.
static func words_for(lesson: Dictionary, pool: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for w in lesson.drills:
		if not out.has(w):
			out.append(w)
	for w in pool:
		var lw := w.to_lower()
		if not out.has(lw) and uses_only(lw, lesson.letters) and uses_any(lw, lesson.new):
			out.append(lw)
	return out


## Les leçons comme listes de mots : [{ id, title, words, builtin: true }].
static func lists() -> Array:
	if _lists.is_empty():
		var pool := PackedStringArray()
		for wl in GameContent.get_content().word_lists:
			pool.append_array(wl.words)
		for lesson in LESSONS:
			_lists.append({"id": lesson.id, "title": lesson.title, "words": words_for(lesson, pool), "builtin": true})
	return _lists
