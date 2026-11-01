class_name AutoLevel
## Adversaires automatiques : leur vitesse suit celle de l'enfant.
##
## Le niveau de l'enfant est la médiane de ses frappes par minute sur ses
## dernières courses (au moins MIN_WORDS mots tapés). Les adversaires sont
## répartis autour : l'un un peu plus lent, l'un à son niveau, l'un un peu
## plus rapide… pour que l'enfant gagne parfois et progresse.

## Courses récentes prises en compte.
const RECENT := 5
## Une course compte si l'enfant y a tapé au moins ce nombre de mots.
const MIN_WORDS := 3
## Vitesse de chaque adversaire par rapport au niveau de l'enfant.
const FACTORS := [0.85, 1.0, 1.15, 0.92, 1.08]
const MIN_KPM := 5.0


## Niveau de l'enfant (frappes par minute), ou -1 sans course utilisable.
static func reference_kpm(history: Array) -> float:
	var values := []
	for h in history:
		if h is Dictionary and float(h.get("kpm", 0)) > 0.0 and int(h.get("words", 0)) >= MIN_WORDS:
			values.append(float(h.kpm))
	values = values.slice(maxi(0, values.size() - RECENT))
	if values.is_empty():
		return -1.0
	values.sort()
	var n := values.size()
	return values[n / 2] if n % 2 == 1 else (values[n / 2 - 1] + values[n / 2]) / 2.0


## Frappes par minute des adversaires : automatiques d'après l'historique, ou
## réglées à la main (manual) tant que l'enfant n'a pas de course utilisable.
static func bot_kpm(history: Array, count: int, manual: Array) -> Array:
	var ref := reference_kpm(history)
	var out := []
	for i in count:
		if ref > 0.0:
			out.append(maxf(MIN_KPM, roundf(ref * FACTORS[i % FACTORS.size()])))
		else:
			out.append(float(manual[i]) if i < manual.size() else 20.0)
	return out
