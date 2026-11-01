class_name LetterStats
## Statistiques par lettre : quelles lettres l'enfant rate ou cherche longtemps.
##
## Pendant une course, RaceLogic note pour chaque lettre attendue (en
## minuscule) : [bonnes frappes, erreurs, temps total pour la trouver (s),
## nombre de temps mesurés]. Le temps de la première lettre d'un mot n'est pas
## compté (il comprend le temps de lire le mot). Ces chiffres sont enregistrés
## dans l'historique (clé « letters ») et réunis ici sur les dernières courses.

const OK := 0
const ERRORS := 1
const TIME := 2
const TIMED := 3

## Nombre de courses récentes prises en compte.
const RECENT_RACES := 20


static func empty() -> Array:
	return [0, 0, 0.0, 0]


## Ajoute les chiffres « letters » d'une course à un total.
static func merge(total: Dictionary, letters: Variant) -> void:
	if not (letters is Dictionary):
		return
	for key in letters:
		var v: Variant = letters[key]
		if not (v is Array) or v.size() < 4:
			continue
		var t: Array = total.get(key, empty())
		for i in 4:
			t[i] += float(v[i])
		total[key] = t


## Total des dernières courses d'un historique.
static func from_history(history: Array, last := RECENT_RACES) -> Dictionary:
	var total := {}
	for h in history.slice(maxi(0, history.size() - last)):
		if h is Dictionary:
			merge(total, h.get("letters", {}))
	return total


## Les lettres à travailler, la plus difficile d'abord :
## [{ "letter", "error_rate" (0..1), "avg_time" (s), "score" }].
## Une lettre compte si elle a été demandée au moins min_seen fois ; elle est
## difficile si l'enfant se trompe souvent, ou s'il la cherche bien plus
## longtemps que les autres.
static func difficult(total: Dictionary, count := 5, min_seen := 3) -> Array:
	var time_sum := 0.0
	var timed := 0.0
	for key in total:
		time_sum += float(total[key][TIME])
		timed += float(total[key][TIMED])
	var mean_time := time_sum / timed if timed > 0.0 else 0.0
	var out := []
	for key in total:
		var t: Array = total[key]
		var seen := float(t[OK]) + float(t[ERRORS])
		if seen < min_seen:
			continue
		var error_rate := float(t[ERRORS]) / seen
		var avg_time := float(t[TIME]) / float(t[TIMED]) if float(t[TIMED]) > 0.0 else 0.0
		var slow := maxf(0.0, avg_time / mean_time - 1.0) if mean_time > 0.0 else 0.0
		var score := error_rate + 0.3 * slow
		if score >= 0.1:
			out.append({"letter": key, "error_rate": error_rate, "avg_time": avg_time, "score": score})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out.slice(0, count)


## « b (40 % d'erreurs), n (lente : 1,8 s) »
static func describe(list: Array) -> String:
	var parts := PackedStringArray()
	for d in list:
		if d.error_rate >= 0.1:
			parts.append("%s (%d %% d'erreurs)" % [d.letter, roundi(d.error_rate * 100.0)])
		else:
			parts.append("%s (lente : %s s)" % [d.letter, ("%.1f" % d.avg_time).replace(".", ",")])
	return ", ".join(parts)


static func letters_of(list: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for d in list:
		out.append(d.letter)
	return out


## Mots d'entraînement : ceux qui contiennent le plus de ces lettres, puis les
## lettres seules.
static func practice_words(words: PackedStringArray, letters: PackedStringArray, max_words := 30) -> PackedStringArray:
	var scored := []
	var seen := {}
	for w in words:
		var lw := w.to_lower()
		if seen.has(lw):
			continue
		seen[lw] = true
		var n := 0
		for i in lw.length():
			if letters.has(lw[i]):
				n += 1
		if n > 0:
			scored.append([w, n])
	scored.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0].length() < b[0].length()))
	var out := PackedStringArray()
	for s in scored.slice(0, max_words):
		out.append(s[0])
	for l in letters:
		if not out.has(l):
			out.append(l)
	return out
