# Festival de la forêt

La branche expérimentale `test-graphic-codex` propose une nouvelle direction
graphique, sans changer les règles du jeu ou le format des profils.

- Palette crème, turquoise, corail et miel ; typographie arrondie.
- Karts biseautés, peinture satinée, jantes à cinq branches, feux, aileron et
  moteur détaillé. Les animaux portent un foulard animé et un badge étoilé.
- Prairie aux variations naturelles, arbres à plusieurs canopées, massifs de
  fleurs, champignons, rochers, montagnes, clôtures, ballons et fanions.
- Sélection du pilote seul dans le menu, titre du festival, classement compact,
  mini-carte arrondie et progression de frappe sous le mot.

Les décors répétitifs utilisent `MultiMesh` pour limiter les appels de dessin.
Le mode Simple réduit la végétation et désactive les ombres. Le mode Normal
fonctionne avec OpenGL ; le mode Beau conserve les effets avancés existants.

## Validation et export

Avec Godot **4.4.1** et ses modèles d'export officiels :

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/test_profiles.gd
godot --headless --path . --script res://tests/test_graphics.gd
godot --headless --path . --script res://tests/autoplay.gd -- --fast
mkdir -p build/windows
touch build/.gdignore
godot --headless --path . --export-release Windows build/windows/FunKart.exe
```

Les captures du test automatique nécessitent un écran (ou un serveur X virtuel).
Pour éviter que deux courses de test écrasent leurs données, exécuter les tests
successivement ou définir un `XDG_DATA_HOME` distinct pour chaque processus.

## Police

Nunito, par les auteurs du projet Nunito, est intégrée sous licence SIL OFL 1.1
(`ui/fonts/OFL.txt`). Le fichier `NunitoBold.ttf` est une instance statique de
l'axe `wght=750`, générée avec FontTools depuis le fichier variable du dépôt
officiel Google Fonts (`ofl/nunito/Nunito[wght].ttf`). Elle donne le même rendu
sous Windows et Linux, sans installation de police supplémentaire.

Cette version n'est pas fusionnée dans `main` et ne publie pas de Release.
