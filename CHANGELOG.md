# Journal des modifications

Toutes les versions publiées de FunKart, la plus récente en premier. Chaque
version correspond à un tag `vX.Y.Z` et à une Release GitHub
(https://github.com/flo91360/FunKart/releases) dont la description reprend la
section de la version.

Pour une nouvelle version : augmenter `config/version` dans `project.godot` et
ajouter ici une section `## [X.Y.Z] - AAAA-MM-JJ` décrivant ce qui change pour
l'enfant ou l'adulte. Sans section, la publication en rédige une à partir des
titres des commits.

## [0.3.0] - 2026-10-14

### Modifié

- Nouvelle direction graphique « Festival de la forêt » : prairie naturelle,
  fleurs, champignons, clôtures, fanions, ballons et montagnes enneigées.
- Karts aux carrosseries arrondies, peinture brillante, jantes et feux détaillés.
- Animaux aux yeux expressifs, avec un foulard animé et un badge étoilé.
- Interface crème et turquoise, police Nunito intégrée et mot à taper contrasté.
- Menus, classement et arrivée harmonisés avec la nouvelle ambiance.

Version expérimentale sur `test-graphic-codex`, sans fusion dans `main`.

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
