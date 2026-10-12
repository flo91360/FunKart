# FunKart — consignes pour Claude

Jeu Godot 4.4 (voir README.md et docs/ARCHITECTURE.md). Textes, commentaires
et messages de commit en français.

## Avant de pousser

- `godot --headless --import`
- `godot --headless --path . --script res://tests/test_profiles.gd`
- `godot --headless --path . --script res://tests/autoplay.gd -- --fast`

## Livraison (souhait du propriétaire du dépôt)

- Chaque changement passe par une pull request vers `main`.
- Quand la CI de la pull request est verte, sans conflit ni commentaire en
  attente : la fusionner sans redemander.
- Une fonctionnalité visible pour l'enfant ou l'adulte augmente
  `config/version` dans `project.godot` (0.x.0 ; 0.x.y pour une correction).
  La fusion dans `main` publie alors automatiquement la version (tag + Release
  GitHub avec le jeu Windows) : vérifier ensuite que la Release existe.
