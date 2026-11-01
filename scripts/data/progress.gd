class_name Progress
## Progression de l'enfant : records et courbe des frappes par minute,
## d'après l'historique de son profil.
##
## Une course compte si l'enfant y a tapé au moins AutoLevel.MIN_WORDS mots.
## Un record bat toutes les courses précédentes (la toute première course
## n'est pas un record : il n'y a rien à battre).


static func counts(h: Variant) -> bool:
	return h is Dictionary and float(h.get("kpm", 0)) > 0.0 and int(h.get("words", 0)) >= AutoLevel.MIN_WORDS


## Meilleures frappes par minute de l'historique, ou -1 sans course qui compte.
static func best_kpm(history: Array) -> float:
	var best := -1.0
	for h in history:
		if counts(h):
			best = maxf(best, float(h.kpm))
	return best


## Cette course est-elle un nouveau record par rapport à l'historique d'avant ?
static func is_record(previous_best: float, kpm: float, words: int) -> bool:
	return previous_best > 0.0 and words >= AutoLevel.MIN_WORDS and kpm > previous_best


## Points de la courbe (les last dernières courses qui comptent, la plus
## ancienne d'abord) : [{ "kpm", "accuracy", "record" }].
static func series(history: Array, last := 30) -> Array:
	var out := []
	var best := -1.0
	for h in history:
		if not counts(h):
			continue
		var kpm := float(h.kpm)
		out.append({"kpm": kpm, "accuracy": float(h.get("accuracy", 0)), "record": is_record(best, kpm, int(h.words))})
		best = maxf(best, kpm)
	return out.slice(maxi(0, out.size() - last))
