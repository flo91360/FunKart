# L’atelier des bois

La branche expérimentale `test-graphic-codex` explore un monde miniature
façonné comme un atelier de jouets : bois, peinture satinée, cuir, laiton,
feuillages jade et lanternes ambrées. La version 0.4.0 reprend les personnages,
les véhicules, les décors, la lumière, les caméras et l’interface.

- Treize figurines animales en salopette, avec museaux, oreilles, queues,
  marquages propres à chaque espèce, regards et clignements animés.
- Bolides rétro : pneus à flancs crème, jantes rivetées, phares ronds,
  banquette cousue, bagages, volant, roues tournantes et direction animée.
- Ateliers creusés dans des troncs, toits de feuilles, arbres ramifiés,
  champignons, sous-bois, lanternes et arche en bois à la ligne de départ.
- Menu autour du pilote sur un socle en bois et sélection par portraits 3D.
  Palette jade, crème et miel, interface de course compacte et carnet de
  résultats ; les profils, mots, réglages et historiques restent accessibles.

Les captures `menu.png`, `course.png` et `arrivee.png` sont produites dans le
jeu avec le rendu Compatibilité, sans retouche. Les règles de frappe et le
format des profils ne changent pas.

## Modèles et performances

Les GLB de `assets/models/` sont inclus dans le dépôt et dans l’exécutable.
Ils sont créés par les scripts Blender du dépôt ; aucun téléchargement de
modèle n’est nécessaire pour importer ou exporter le jeu.

Pour les régénérer avec Blender **4.3.2** :

```sh
blender --background --factory-startup --python tools/build_models.py
blender --background --factory-startup --python tools/build_scenery.py
```

Les pièces immobiles sont regroupées par matériau en conservant les pivots
animés. Les arbres et le petit sous-bois utilisent `MultiMesh`. Les portraits
sont rendus une fois à la création du menu. Le mode Simple réduit la végétation
et désactive les ombres ; le mode Normal fonctionne avec OpenGL. Le mode Beau
conserve les effets avancés du moteur Forward+.

## Validation et export

Avec Godot **4.4.1** et ses modèles d’export officiels :

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

Le fichier Windows est autonome : décompresser l’artefact **FunKart-Windows**
de GitHub Actions et lancer `FunKart.exe`. Il contient les modèles et la police.
Le moteur de rendu OpenGL a été contrôlé dans l’environnement Linux ; le
comportement sur Windows et les performances matérielles restent à tester
sur le PC destinataire.

## Police

Nunito, par les auteurs du projet Nunito, est intégrée sous licence SIL OFL 1.1
(`ui/fonts/OFL.txt`). `NunitoBold.ttf` est une instance statique de l’axe
`wght=750`, générée avec FontTools depuis le fichier variable du dépôt officiel
Google Fonts (`ofl/nunito/Nunito[wght].ttf`). La licence est également accessible
depuis le bouton Crédits du menu.

Cette version n’est pas fusionnée dans `main` et ne publie pas de Release.
