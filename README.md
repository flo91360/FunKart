# FunKart

Jeu vidéo pédagogique permettant de prendre en main le clavier sous forme de jeu.

Une course de karts où l'enfant **ne pilote pas** : son kart roule tout seul.
La seule façon d'aller plus vite, c'est de **taper au clavier les mots qui apparaissent**.

## Lancer le jeu

Aucune installation n'est nécessaire : ouvrir `index.html` dans un navigateur
récent (Chrome, Firefox, Edge). Le jeu fonctionne aussi sans connexion Internet.

## Règles (v0)

- Le kart avance en pilote automatique à une vitesse de croisière.
- Régulièrement, un mot apparaît en grand en bas de l'écran, avec son emoji
  (ex. 🍌 **banane**), et l'obstacle apparaît sur la piste devant le kart.
- **Tant que le mot n'est pas entièrement tapé, le kart ralentit.**
- **Dès que le mot est tapé, le kart reçoit un turbo** pendant quelques secondes.
- La lettre attendue est surlignée en jaune. Une mauvaise touche ne fait pas
  avancer le mot : le mot tremble et le jeu indique la lettre à chercher.
- Majuscules et minuscules sont toujours acceptées. Par défaut, les accents sont
  facultatifs : on peut taper `e` pour `é`.
- Les adversaires (🐢 Tortue, 🐰 Lapin, 🦊 Renard) suivent exactement les mêmes
  règles. Ils « tapent » leurs mots à une vitesse en **frappes par minute**
  réglée par l'adulte.
- <kbd>Échap</kbd> met le jeu en pause. Le jeu se met aussi en pause si la
  fenêtre perd le focus.

## Suivi de l'enfant

Pendant la course et à l'arrivée :

- **Frappes par minute** : nombre de bonnes frappes divisé par le temps passé
  avec un mot à l'écran (les pauses entre deux mots ne sont pas comptées) ;
- **Précision** : bonnes frappes / total des frappes ;
- nombre de mots, temps moyen par mot, nombre d'erreurs, place à l'arrivée.

Chaque course est enregistrée dans l'**historique** (menu → « Historique des
courses »), exportable en CSV (lisible dans Excel / LibreOffice). Les données
restent sur l'ordinateur, dans le navigateur.

## Réglages (menu → « Réglages (adulte) »)

| Réglage | Effet |
| --- | --- |
| Nombre de tours | Longueur de la course |
| Nombre d'adversaires | 0 à 3 |
| Frappes/min de chaque adversaire | Leur niveau, à régler selon l'objectif de l'enfant (préréglages disponibles) |
| Pause entre deux mots | Temps de répit après chaque mot |
| Durée d'un tour sans mot | Vitesse de base des karts |
| Ralentissement / turbo | Intensité de la pénalité et de la récompense |
| Longueur max des mots | Filtre la liste de mots |
| Taille du mot, MAJUSCULES | Lisibilité (les touches du clavier sont souvent en majuscules) |
| Accents facultatifs | Accepte `e` pour `é`, etc. |
| Lecture à voix haute | Le mot est lu par la synthèse vocale du navigateur |
| Liste de mots | Un mot par ligne, emoji facultatif après le mot (`banane 🍌`) |

Avec les réglages par défaut, une course de 2 tours dure environ 1 min 30 pour
un enfant à 20 frappes/min.

## Organisation du code

- `index.html`, `style.css` : écrans (menu, course, résultats)
- `js/race.js` : règles de la course (vitesse, mots, turbo, adversaires, statistiques)
- `js/track.js` : géométrie du circuit
- `js/render.js` : dessin du circuit et des karts
- `js/words.js` : liste de mots par défaut
- `js/sound.js` : sons et voix
- `js/main.js` : interface, réglages, historique
