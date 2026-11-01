# Architecture de FunKart

Le principe : **le contenu est fait de données**, modifiables dans l'éditeur
Godot ou enregistrées en JSON, et **le code est rangé par rôle**. Les futurs
éditeurs (personnages, circuits) et les profils s'appuient sur ces données.

## Dossiers

```
data/                     contenu livré avec le jeu (ressources Godot .tres)
  content.tres            catalogue : personnages, circuits, listes de mots
  characters/*.tres       un fichier par pilote (CharacterData)
  themes/*.tres           ambiances de circuit (TrackTheme)
  words/*.tres            listes de mots livrées avec le jeu (WordList)
tracks/*.tscn             circuits (scène Track + courbe Path3D)
scenes/
  main.tscn               point d'entrée : Race + Menu
  race/race.tscn          monde 3D de la course
  ui/hud.tscn             interface pendant la course
  ui/menu.tscn            menu principal (profils, pilote, réglages, historique)
  ui/results.tscn         écran d'arrivée
ui/theme.tres             thème de l'interface (couleurs, polices, boutons)
scripts/
  autoload/               services globaux
    app_settings.gd       réglages de l'ordinateur (plein écran, son) — « AppSettings »
    profiles.gd           profils, historique, export CSV, reprise des anciennes données — « Profiles »
  data/                   types de données
    profile.gd            profil d'un enfant (JSON)
    character_data.gd     pilote
    track_theme.gd        thème de circuit
    word_list.gd          liste de mots
    game_content.gd       catalogue du contenu (data/content.tres)
  race/                   la course
    race_logic.gd         règles (sans affichage, testées) : vitesse, mots, turbo, adversaires, stats
    race.gd               monde 3D : karts, caméra, couloirs, enchaînement des modes
    track.gd              construction du circuit à partir de la courbe (outil d'éditeur)
    kart.gd               karts et pilotes
    sfx.gd                sons, musique, voix
  ui/                     écrans et fenêtres
  util/mk.gd              fabrication de modèles à partir de formes simples
tests/                    tests automatiques
```

## Données de l'utilisateur

Dans le dossier utilisateur de Godot (sous Windows :
`%APPDATA%\Godot\app_userdata\FunKart`) :

```
app.json                          réglages de l'ordinateur (plein écran, volumes, graphismes) + dernier profil
override.cfg                      présent seulement en mode graphique « Beau » : demande à Godot
                                  le moteur de rendu avancé (Forward+) au démarrage
profiles/<id>/profile.json        profil (prénom, pilote, réglages, listes de mots personnelles,
                                  listes cochées)
profiles/<id>/history.json        courses de ce profil
```

Ce sont des fichiers JSON (lisibles, sans risque à copier d'un ordinateur à
l'autre). Chaque enregistrement (`AppSettings.write_json`) écrit d'abord un
fichier `.tmp`, garde la version précédente en `.bak` (relue si le fichier est
abîmé, par exemple après une coupure de courant) et met de côté un fichier
abîmé en `.abime` au lieu de l'écraser. Un dossier par profil laisse la place aux futurs fichiers propres à
l'enfant (personnage personnalisé, circuits créés…).

## Listes de mots

`Profile.available_lists()` réunit les listes du jeu (`data/words`,
identifiants comme `base`, `animaux`) et les listes personnelles du profil
(`Profile.word_lists`, identifiants `perso_…`). `Profile.active_lists` contient
les identifiants cochés ; `Profile.words()` donne les mots de la course (sans
doublon, liste de base par défaut). Interface : `scripts/ui/word_lists_panel.gd`
(dans les réglages) et `scripts/ui/word_list_editor.gd` (édition, import/export
.txt). `WordList.parse()` découpe un texte en mots. Les profils de la version 1
(une seule liste recopiée) sont convertis à la lecture.

## Progression et records

`scripts/data/progress.gd` (`Progress`) : meilleur score (`best_kpm()`),
nouveau record (`is_record()`, utilisé par `Race._show_results()`) et points
de la courbe (`series()`), dessinée par `scripts/ui/progress_chart.gd` dans
l'historique. Seules comptent les courses d'au moins `AutoLevel.MIN_WORDS` mots.

## Adversaires automatiques

Réglage du profil `bot_auto`. `scripts/race/auto_level.gd` (`AutoLevel`)
calcule le niveau de l'enfant (`reference_kpm()` : médiane des frappes par
minute des dernières courses de l'historique) et la vitesse des adversaires
(`bot_kpm()`, coefficients `FACTORS`), utilisée par `Race.prepare()`.

## Statistiques par lettre

`RaceLogic.stats.letters` note, pour chaque lettre attendue, `[bonnes frappes,
erreurs, temps pour la trouver, nombre de temps mesurés]` ; c'est enregistré
dans l'historique (clé `letters`). `scripts/data/letter_stats.gd`
(`LetterStats`) réunit les dernières courses, choisit les lettres à travailler
(`difficult()`) et fabrique la liste d'entraînement (`practice_words()`).

## Clavier à l'écran

`scripts/ui/keyboard_view.gd` (`KeyboardView`) dessine le clavier AZERTY sous
le mot (ajouté par `Hud`). Les rangées, les doigts et leurs couleurs sont des
constantes en tête du fichier ; `keys_for()` donne les touches d'un caractère
(deux pour « ê » : `^` puis `e`) et `finger_hint()` le doigt à utiliser,
repris dans le message d'erreur. Réglage du profil : `keyboard`.

La CI joue aussi une course dans un écran virtuel et enregistre des captures
d'écran (Artifacts « Captures » de « Construire le jeu »).

## Graphismes

Le jeu utilise par défaut le moteur de rendu « Compatibilité » (OpenGL), qui
fonctionne partout. Le mode **Beau** demande le moteur avancé « Forward+ »
(Vulkan ou Direct3D 12) : ce choix se fait au démarrage de Godot, d'où le
fichier `user://override.cfg` (réglage de projet
`application/config/project_settings_override`) et la relance du jeu. Si la
carte graphique ne le permet pas, Godot revient tout seul au rendu simple et
les réglages l'indiquent. Les effets propres à chaque niveau sont dans
`Race._apply_quality()`.

## Son

Deux bus audio, « Musique » et « Effets », sont créés au démarrage par
`AppSettings` ; leurs volumes et celui du bus principal sont enregistrés dans
`app.json`. Les curseurs (`scripts/ui/volume_sliders.gd`) sont dans le menu
pause et dans les réglages.

## Modifier le contenu dans l'éditeur Godot

- **Un circuit** : ouvrir `tracks/prairie.tscn`, sélectionner le nœud `Path`
  et déplacer les points de la courbe : la route et le décor se reconstruisent.
  Le premier point est la ligne de départ ; le dernier point se raccorde au
  premier. Les propriétés du nœud racine règlent la largeur de la route, le
  thème, la position de la tribune et la graine du décor.
- **Un nouveau circuit** : dupliquer `tracks/prairie.tscn`, modifier la courbe,
  puis l'ajouter à la liste `tracks` de `data/content.tres`.
- **Une ambiance** : dupliquer `data/themes/prairie.tres` (couleurs du sol, de
  la route, du ciel, des arbres…) et l'assigner au circuit.
- **Un pilote** : dupliquer un fichier de `data/characters/`, changer `id`,
  couleurs, oreilles…, puis l'ajouter à `characters` dans `data/content.tres`
  (`playable` : proposé à l'enfant ou adversaire).
- **L'interface** : les scènes de `scenes/ui/` et `ui/theme.tres` s'éditent
  visuellement. Les nœuds utilisés par le code ont un nom unique (`%Nom`).

## Où brancher les prochaines fonctionnalités

| Fonctionnalité | Point d'entrée |
| --- | --- |
| Barre de pouvoir | `RaceLogic` (charge à chaque mot, utilisation) + `Hud` (affichage) |
| Éditeur de personnages | `CharacterData` (to_dict/from_dict) enregistré dans le profil |
| Thèmes de circuits | `TrackTheme` (nouveaux fichiers) |
| Éditeur de circuits | `Track.smooth_curve(points)` + enregistrement des points en JSON |
