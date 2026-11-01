# Journal des modifications

Toutes les versions publiées de FunKart, la plus récente en premier. Chaque
version correspond à un tag `vX.Y.Z` et à une Release GitHub
(https://github.com/flo91360/FunKart/releases) dont la description reprend la
section de la version.

Pour une nouvelle version : augmenter `config/version` dans `project.godot` et
ajouter ici une section `## [X.Y.Z] - AAAA-MM-JJ` décrivant ce qui change pour
l'enfant ou l'adulte. Sans section, la publication en rédige une à partir des
titres des commits.

## [0.7.0] - 2026-11-01

### Ajouté

- « Réglages (adulte) » est protégé : un petit calcul (par exemple 7 × 8) est
  demandé avant d'ouvrir les réglages, pour que l'enfant ne les change pas
  seul. En cas d'erreur, un autre calcul est proposé. La protection se
  désactive dans les réglages (« Protéger les réglages (calcul) », section
  « Cet ordinateur »).

## [0.6.0] - 2026-11-01

### Ajouté

- « NOUVEAU RECORD ! » à l'arrivée quand l'enfant bat sa meilleure vitesse
  (frappes par minute), avec l'ancien record.
- Historique : courbe de progression des frappes par minute sur les 30
  dernières courses (records en doré) et record du profil.

## [0.5.0] - 2026-11-01

### Ajouté

- Adversaires automatiques (Réglages → « Adversaires automatiques ») : leur
  vitesse suit celle de l'enfant, d'après la médiane de ses frappes par
  minute sur ses 5 dernières courses. Les adversaires sont répartis autour de
  son niveau (85 %, 100 %, 115 %…), pour qu'il gagne parfois et progresse.
  Les réglages affichent le niveau actuel de l'enfant. Tant qu'il n'a pas
  encore de course, les valeurs réglées à la main servent. Désactivé par défaut.

## [0.4.0] - 2026-11-01

### Ajouté

- Statistiques par lettre : pendant la course, le jeu note pour chaque lettre
  les erreurs et le temps mis à la trouver.
- Historique : « Lettres à travailler » sur les 20 dernières courses (lettres
  souvent ratées ou cherchées longtemps), et bouton « Créer une liste
  d'entraînement » qui crée et coche une liste de mots contenant ces lettres.
- Écran d'arrivée : « Lettres à retravailler » de la course.
- Export CSV : colonne `lettres_a_travailler`.

## [0.3.0] - 2026-11-01

### Ajouté

- Clavier AZERTY à l'écran, sous le mot à taper : chaque touche a la couleur
  du doigt qui doit la taper (auriculaire, annulaire, majeur, index, pouce) et
  la touche attendue est surlignée en jaune. Les touches F et J ont leur
  repère, comme sur un vrai clavier. Pour « ê » ou « ï », les deux touches
  (accent puis lettre) sont montrées.
- Après une erreur, le jeu dit quel doigt utiliser
  (« Oups ! Cherche « f » : index gauche »).
- Réglage « Clavier à l'écran » (propre à chaque enfant, activé par défaut) :
  à décocher quand l'enfant n'en a plus besoin.

## [0.2.3] - 2026-11-01

### Modifié

- `FunKart.exe` a maintenant l'icône du jeu (au lieu de celle de Godot) et
  son numéro de version dans ses propriétés Windows (clic droit →
  Propriétés → Détails).
- Le jeu est un peu plus léger : les captures d'écran de la documentation ne
  sont plus incluses dans l'exécutable.

## [0.2.2] - 2026-11-01

### Corrigé

- Un mot avec `œ` ou `æ` (« cœur », « œuf ») se tape maintenant `oe` / `ae` :
  il n'est plus impossible à taper au clavier.
- Un mot sans aucune bonne lettre pendant 15 secondes est passé : l'enfant
  n'est plus bloqué jusqu'à l'arrivée.
- Le turbo dure toute la « Durée du turbo », même quand le mot suivant
  apparaît déjà (avant, une courte pause entre deux mots l'annulait).
- Le mot à taper ne reste plus décalé sur le côté après plusieurs erreurs
  rapprochées.
- L'historique et les profils ne peuvent plus être perdus si l'ordinateur
  s'éteint pendant un enregistrement : une copie de secours est relue.
- Un prénom vide n'est plus enregistré ; un fichier de profil modifié à la
  main avec des valeurs invalides ne fait plus planter la course.

## [0.2.1] - 2026-10-12

### Modifié

- Menu principal : le numéro de version est affiché plus discrètement en bas à
  gauche et le panneau du menu est remonté.

## [0.2.0] - 2026-10-12

### Ajouté

- Listes de mots : 8 listes livrées avec le jeu (Mots de base, Lettres seules,
  Syllabes, Mots courts, Animaux, Fruits et légumes, Kart et course, École) ;
  chaque profil coche une ou plusieurs listes.
- Listes personnelles par enfant : créer, modifier, copier une liste du jeu,
  supprimer, importer et exporter un fichier `.txt`.
- Les listes utilisées sont rappelées dans le menu et enregistrées dans
  l'historique (colonne `listes_de_mots` de l'export CSV).

## [0.1.0] - 2026-10-12

### Ajouté

- Première version publiée : course de karts en 3D où l'enfant accélère en
  tapant les mots affichés, adversaires réglables en frappes par minute,
  profils par enfant, volume et qualité des graphismes réglables.
- Numéro de version affiché dans le menu et publication automatique des
  versions sur GitHub.
