# FunKart

Jeu vidéo pédagogique permettant de prendre en main le clavier sous forme de jeu.

Une course de karts en 3D, vue à la troisième personne derrière le kart, dans
l'esprit des jeux de kart. L'enfant **ne pilote pas** : son kart roule tout
seul. La seule façon d'aller plus vite, c'est de **taper au clavier les mots
qui apparaissent à l'écran**.

![Course](docs/course.png)

| Menu et choix du pilote | Arrivée |
| --- | --- |
| ![Menu](docs/menu.png) | ![Arrivée](docs/arrivee.png) |

## Jouer

- **Windows** : télécharger `FunKart.exe` et double-cliquer dessus. Aucune
  installation n'est nécessaire. Windows peut afficher « Windows a protégé votre
  ordinateur » : cliquer sur « Informations complémentaires » puis
  « Exécuter quand même ».
- **Linux** : `FunKart.x86_64`, à rendre exécutable puis à lancer.

Les versions publiées sont sur la page **Releases** du dépôt
(https://github.com/flo91360/FunKart/releases) : télécharger
`FunKart-vX.Y.Z-Windows.zip` de la dernière version. Le numéro de version est
affiché en bas à gauche du menu du jeu.

Les versions de travail (non publiées) sont produites par GitHub à chaque
modification : onglet **Actions** → dernière exécution de « Construire le
jeu » → section **Artifacts**.

Le jeu démarre en plein écran. <kbd>F11</kbd> : basculer plein écran / fenêtre. <kbd>Échap</kbd> : pause.

## Règles

- Le kart avance en pilote automatique (pas d'accélération, de frein ni de direction).
- Régulièrement, un mot apparaît en grand en bas de l'écran.
- **Tant que le mot n'est pas entièrement tapé, le kart ralentit.**
- **Dès que le mot est tapé, le kart reçoit un turbo.**
- La lettre attendue est surlignée en jaune. Une mauvaise touche ne fait pas
  avancer le mot : le mot tremble et le jeu indique la lettre à chercher.
- Les touches maintenues enfoncées ne comptent qu'une fois (pas de répétition
  automatique).
- Majuscules et minuscules sont toujours acceptées ; les accents sont
  facultatifs par défaut (on peut taper `e` pour `é`).
- Les adversaires (Tortue, Lapin, Renard, Ours, Souris) suivent exactement les
  mêmes règles : ils « tapent » leurs mots à une vitesse en **frappes par
  minute** réglée par l'adulte.

## Profils

Chaque enfant a son **profil** (menu → « Qui joue ? » → « + Nouveau ») : son
pilote, ses réglages, ses listes de mots et son historique. Le prénom se modifie
et le profil se supprime dans les réglages. Le son, la musique et le plein
écran sont communs à tous les profils (réglages de l'ordinateur).

Au premier lancement de cette version, les réglages et l'historique de la
version précédente deviennent automatiquement un premier profil (les anciens
fichiers sont gardés sous le nom `*.old.json`).

## Listes de mots

Dans **Réglages (adulte) → Listes de mots**, on coche les listes utilisées
pendant les courses ; les mots sont tirés au hasard parmi toutes les listes
cochées. Les listes choisies sont rappelées dans le menu (« Mots : … »).

- **Listes du jeu** : Mots de base, Lettres seules, Syllabes, Mots courts,
  Animaux, Fruits et légumes, Kart et course, École. Le bouton « Voir / copier »
  permet d'en faire une copie à modifier.
- **Listes personnelles** (propres à chaque enfant) : « + Nouvelle liste »,
  puis taper ou coller les mots, un par ligne ou séparés par des espaces ou
  des virgules. Les chiffres, symboles et emojis sont ignorés, les doublons
  retirés.
- **Fichiers texte** : « Importer un fichier .txt » crée une liste à partir
  d'un fichier ; « Exporter (.txt) » l'enregistre, par exemple pour la
  copier sur un autre ordinateur.
- Les mots plus longs que le réglage « Longueur max des mots » ne sont pas
  proposés ; le nombre de mots écartés est indiqué.

## Suivi de l'enfant

Pendant la course et à l'arrivée :

- **frappes par minute** : bonnes frappes ÷ temps passé avec un mot à l'écran
  (les moments sans mot ne sont pas comptés) ;
- **précision** : bonnes frappes ÷ total des frappes ;
- nombre de mots, temps moyen par mot, erreurs, temps de course, place ;
- listes de mots utilisées (dans l'export CSV).

Chaque course est enregistrée dans l'**historique** du profil (menu →
Historique). L'export CSV (Excel ou LibreOffice) regroupe tous les profils dans
le fichier `FunKart_historique.csv` du dossier Documents.

## Réglages (menu → Réglages (adulte), propres à chaque profil)

| Réglage | Effet |
| --- | --- |
| Nombre de tours | Longueur de la course (3 par défaut) |
| Nombre d'adversaires | 0 à 5 |
| Frappes/min de chaque adversaire | Leur niveau, à régler selon l'objectif de l'enfant (préréglages disponibles) |
| Pause entre deux mots | Temps de répit après chaque mot |
| Durée d'un tour sans mot | Vitesse de base des karts |
| Ralentissement / turbo | Intensité de la pénalité et de la récompense |
| Longueur max des mots | Filtre la liste de mots |
| Taille du mot, MAJUSCULES | Lisibilité (les touches du clavier sont souvent en majuscules) |
| Accents facultatifs | Accepte `e` pour `é`, etc. |
| Lire le mot à voix haute | Synthèse vocale du système (si une voix française est installée) |
| Sons, musique, plein écran | Communs à tous les profils |
| Volumes (général, musique, effets) | Aussi réglables pendant la course : <kbd>Échap</kbd> → curseurs de volume |
| Graphismes | **Simple** (ordinateurs lents : sans ombres, moins de décor), **Normal**, **Beau** (ordinateurs récents : lumière réaliste, ombres douces, lueurs, léger flou au loin ; prend effet au prochain lancement, bouton « Relancer le jeu ») |

Avec les réglages par défaut (3 tours), une course dure environ 1 min 45 pour
un enfant à 20 frappes/min, qui arrive en moyenne 2e ou 3e contre des
adversaires réglés à 16, 20 et 24 frappes/min.

## Pour les développeurs

Le jeu est fait avec [Godot 4.4](https://godotengine.org) (gratuit et libre),
avec le moteur de rendu « Compatibilité » pour tourner sur des ordinateurs
modestes. Les modèles 3D sont assemblés à partir de formes simples et les sons
sont générés par le code : il n'y a aucun fichier 3D ou audio externe.

- Ouvrir le projet : lancer Godot 4.4 et importer `project.godot`.
- Tests (aussi lancés par GitHub à chaque modification) :
  - données et profils : `godot --headless --path . --script res://tests/test_profiles.gd`
  - une course jouée avec de vrais événements clavier :
    `godot --headless --path . --script res://tests/autoplay.gd -- --fast`
- Export : `godot --headless --export-release "Windows" build/windows/FunKart.exe`
- **Publier une version** : augmenter `config/version` dans `project.godot`
  (ex. `0.3.0`) et fusionner dans `main`. GitHub construit le jeu, lance les
  tests, puis crée automatiquement le tag `v0.3.0` et la Release avec les
  fichiers à télécharger. Une fusion sans changement de version ne publie
  rien. (Autres possibilités : onglet **Actions** → « Construire le jeu » →
  **Run workflow** sur `main` avec « publier » coché, ou pousser un tag
  `v0.3.0` correspondant à la version du projet.)

L'organisation du code et la façon de modifier le contenu (circuits,
personnages, thèmes, mots) sont décrites dans [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Archivage Google Drive

Après une fabrication réussie sur `main`, le workflow peut archiver les `.exe`
dans votre dossier Drive personnel, avec un sous-dossier par projet et version.
Configurez `GOOGLE_DRIVE_CREDENTIALS` (secret Actions) et `GOOGLE_DRIVE_FOLDER_ID`
(variable Actions) selon le [guide PlaniFiKateur](https://github.com/flo91360/PlaniFiKateur/blob/main/docs/google-drive.md).
Les anciens exécutables sont conservés. Les cartes traitées par le worker avec
le profil de ce projet augmentent automatiquement la version avant les tests.
