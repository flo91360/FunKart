class_name Gifts
## Cases cadeau : les cadeaux (attaques et défenses), leurs règles et tous
## leurs réglages (durées, intensités, probabilités), regroupés ici pour être
## faciles à ajuster après essais.
##
## Des rangées de cases cadeau sont posées en travers de la piste. Un kart qui
## passe sur une case reçoit un cadeau, s'il n'en a pas déjà un (un seul à la
## fois) :
## - charge électrique : le même turbo qu'un mot bien tapé (une fois sur deux) ;
## - plaque d'huile : posée derrière le kart, le kart suivant glisse ;
## - clou : posé derrière le kart, le kart suivant crève et ralentit fortement ;
## - tempête : pluie sur le premier (ralenti, prochain mot flou) ; jamais
##   donnée au premier ;
## - fusée : rattrape une place ; jamais donnée au premier.
## Huile et clou s'évitent en tapant DODGE_WORD à temps.

const CHARGE := "charge"
const OIL := "huile"
const NAIL := "clou"
const STORM := "tempete"
const ROCKET := "fusee"
const KINDS := [CHARGE, OIL, NAIL, STORM, ROCKET]

## Nom affiché à l'enfant.
const NAMES := {
	CHARGE: "Charge électrique",
	OIL: "Plaque d'huile",
	NAIL: "Clou",
	STORM: "Tempête",
	ROCKET: "Fusée",
}
## Couleur de chaque cadeau (cadre de l'affichage en haut à gauche).
const COLORS := {
	CHARGE: Color("#2d7ff9"),
	OIL: Color("#3d3a4b"),
	NAIL: Color("#8d99ae"),
	STORM: Color("#5e60ce"),
	ROCKET: Color("#e63946"),
}

# ---------------- Cases cadeau ----------------

## Rangées de cases sur un tour (fraction de la longueur du circuit depuis la ligne).
const ROWS := [0.3, 0.7]
## Position des cases sur la largeur de la piste (mètres, négatif : à gauche).
## Elles couvrent toute la largeur : un kart passe toujours sur la case la plus proche.
const BOX_LATERALS := [-4.5, -1.5, 1.5, 4.5]
## Couleur des paquets cadeau, de gauche à droite.
const BOX_COLORS := [Color("#ff4d6d"), Color("#ffd60a"), Color("#17b169"), Color("#2d7ff9")]
## Temps avant qu'une case prise réapparaisse (s).
const BOX_RESPAWN := 2.0
## À l'approche (arrivée sur les cases dans moins de ce temps, en secondes),
## l'enfant choisit sa case avec les flèches ; le reste du temps, pilote automatique.
const APPROACH_TIME := 3.0
## Vitesse du kart sur la largeur de la piste quand il va vers sa case ou évite un piège (m/s).
const STEER_SPEED := 8.0

# ---------------- Tirage du cadeau ----------------

## Charge électrique : une chance sur deux à chaque case.
const CHARGE_CHANCE := 0.5
## Le reste est partagé entre les autres cadeaux permis, selon ces poids.
const OTHER_WEIGHTS := {OIL: 1.0, NAIL: 1.0, STORM: 1.0, ROCKET: 1.0}
## Cadeaux jamais donnés au premier (au moment où il passe sur la case).
const NOT_FOR_LEADER := [STORM, ROCKET]

# ---------------- Effets ----------------

## Huile : glissade (le kart tourne sur lui-même), vitesse multipliée par SLIP_FACTOR.
const SLIP_TIME := 1.2
const SLIP_FACTOR := 0.45
const SLIP_TURNS := 1.0
## Clou : pneu crevé, vitesse multipliée par FLAT_FACTOR.
const FLAT_TIME := 2.5
const FLAT_FACTOR := 0.3
## Tempête : pluie sur le premier, vitesse multipliée par STORM_FACTOR.
const STORM_TIME := 3.0
const STORM_FACTOR := 0.6
## Tempête : le mot à taper est flou, puis redevient net en ce temps (s).
const STORM_BLUR_TIME := 3.0
## Tempête sur un adversaire : son mot (flou) lui prend autant de secondes en plus.
const STORM_BOT_DELAY := 1.5
## Fusée : en ROCKET_TIME secondes, le kart passe devant celui qui le précède
## (de ROCKET_MARGIN mètres) ; ROCKET_FACTOR : vitesse affichée pendant le vol.
const ROCKET_TIME := 1.2
const ROCKET_MARGIN := 3.0
const ROCKET_FACTOR := 2.4
## Huile et clou sont posés à cette distance derrière le kart (m) et
## disparaissent au bout de TRAP_LIFETIME secondes si personne ne passe dessus.
const TRAP_BEHIND := 3.0
const TRAP_LIFETIME := 20.0

# ---------------- Esquive (« évite ») ----------------

## Mot à taper pour éviter une huile ou un clou (avec ou sans accent).
const DODGE_WORD := "évite"
## Temps laissé pour taper le mot : temps de réaction + temps de frappe au
## niveau du pilote (frappes par minute) × DODGE_SLACK, entre DODGE_MIN et DODGE_MAX.
## Le mot apparaît quand le kart arrivera sur le piège dans ce temps-là.
const DODGE_REACTION := 1.0
const DODGE_SLACK := 1.3
const DODGE_MIN := 2.5
const DODGE_MAX := 15.0
## Niveau de l'enfant tant qu'on ne le connaît pas (frappes par minute).
const DEFAULT_KPM := 20.0
## Bonnes frappes de la course avant d'utiliser sa vitesse du moment.
const LIVE_KPM_KEYS := 10
## Écart sur la largeur pour contourner un piège (m).
const DODGE_SWERVE := 3.2

# ---------------- Adversaires ----------------

## Délai avant qu'un adversaire utilise son cadeau (s, au hasard entre les deux).
const BOT_USE_DELAY := [1.0, 3.0]
## Un adversaire pose huile ou clou quand un kart le suit à moins de cette distance (m)…
const BOT_TRAP_RANGE := 120.0
## … ou, sinon, après l'avoir gardé ce temps-là (s) s'il est suivi.
const BOT_MAX_HOLD := 8.0
## Esquive d'un adversaire : temps de réaction (s) et vitesse de frappe
## (multiplie le temps de frappe à son niveau), au hasard entre les deux valeurs.
const BOT_DODGE_REACTION := [0.4, 1.4]
const BOT_DODGE_SPREAD := [0.8, 1.6]


## Ce cadeau peut-il être donné à ce kart ? (is_leader : premier au passage sur la case)
static func allowed(kind: String, is_leader: bool) -> bool:
	return not (is_leader and NOT_FOR_LEADER.has(kind))


## Cadeau tiré avec deux nombres entre 0 et 1 : roll décide de la charge
## électrique, roll2 choisit parmi les autres cadeaux permis.
static func pick(is_leader: bool, roll: float, roll2: float) -> String:
	if roll < CHARGE_CHANCE:
		return CHARGE
	var pool := []
	var total := 0.0
	for kind in OTHER_WEIGHTS:
		if allowed(kind, is_leader) and float(OTHER_WEIGHTS[kind]) > 0.0:
			pool.append(kind)
			total += float(OTHER_WEIGHTS[kind])
	if pool.is_empty():
		return CHARGE
	var x := roll2 * total
	for kind in pool:
		x -= float(OTHER_WEIGHTS[kind])
		if x < 0.0:
			return kind
	return pool.back()


static func random_gift(is_leader: bool) -> String:
	return pick(is_leader, randf(), randf())


## Temps laissé pour taper DODGE_WORD, d'après la vitesse de frappe (frappes par minute).
static func dodge_window(kpm: float) -> float:
	var typing := DODGE_WORD.length() * 60.0 / maxf(kpm, 1.0)
	return clampf(DODGE_REACTION + typing * DODGE_SLACK, DODGE_MIN, DODGE_MAX)


## Multiplicateur de vitesse des effets subis (huile, clou, tempête).
static func effect_factor(slip: float, flat: float, storm: float) -> float:
	var f := 1.0
	if slip > 0.0:
		f *= SLIP_FACTOR
	if flat > 0.0:
		f *= FLAT_FACTOR
	if storm > 0.0:
		f *= STORM_FACTOR
	return f


## Case la plus proche d'une position sur la largeur de la piste.
static func nearest_box(lateral: float) -> int:
	var best := 0
	for i in BOX_LATERALS.size():
		if absf(BOX_LATERALS[i] - lateral) < absf(BOX_LATERALS[best] - lateral):
			best = i
	return best
