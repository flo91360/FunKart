# Journal des modifications

Toutes les versions publiées de FunKart, la plus récente en premier. Chaque
version correspond à un tag `vX.Y.Z` et à une Release GitHub
(https://github.com/flo91360/FunKart/releases) dont la description reprend la
section de la version.

Pour une nouvelle version : augmenter `config/version` dans `project.godot` et
ajouter ici une section `## [X.Y.Z] - AAAA-MM-JJ` décrivant ce qui change pour
l'enfant ou l'adulte. Sans section, la publication en rédige une à partir des
titres des commits.

## [0.10.1] - 2026-11-02

### Corrigé

- Le grand « ARRIVÉE ! » de fin de course n'est plus coupé par le panneau du
  mot : il se lit en entier, entre le classement et la minimap, sous les
  statistiques. Le compte à rebours suit la même règle.

## [0.10.0] - 2026-11-02

### Changé

- Tout le jeu a un nouveau look.
- Les karts sont refaits en formes lisses et détaillées : carénage arrondi,
  pontons, aileron, numéro sur le nez, phares, pneus sculptés, jantes
  chromées, volant qui tourne dans les virages, flammes du turbo.
- Les 13 animaux pilotes sont plus réalistes et plus détaillés : grands yeux
  brillants (iris, pupille, reflets), museau, truffe, moustaches, oreilles
  avec leur intérieur, crinière du lion, corne et crinière arc-en-ciel de la
  licorne, carapace de la tortue, queues… avec une combinaison de pilote, une
  écharpe et des lunettes. Ils clignent des yeux, regardent autour d'eux,
  se penchent dans les virages ; oreilles, queue et écharpe bougent avec la
  vitesse.
- Décors refaits pour les quatre circuits : collines et montagnes au loin,
  arbres en bosquets, fleurs et herbes qui ondulent au vent, rochers, nuages
  et montgolfières. La Prairie a son moulin, la Plage sa mer avec des vagues,
  des voiliers, un phare et des parasols, la Montagne ses sapins enneigés,
  ses chalets et ses bonshommes de neige, le Canyon ses mesas et ses cactus.
- Route en enrobé avec grille de départ, vibreurs en relief, barrières et
  panneaux à flèches dans les virages serrés, arche gonflable avec des feux
  qui s'allument pendant le compte à rebours, tribune avec un public
  d'animaux, drapeaux au vent.
- Nouveau ciel et nouvelle lumière : couleurs plus vives, soleil, nuages,
  brume légère au loin. En mode « Normal », des ombres douces sous les karts
  et les arbres (des couleurs plus belles qu'avec les anciennes ombres) ;
  le mode « Beau » garde les vraies ombres du soleil.
- Nouveau menu : logo animé, une carte avec le portrait de chaque pilote,
  une carte avec le tracé de chaque circuit, grand bouton « JOUER ! », et le
  kart choisi tout seul sur la grille de départ derrière le menu.
- Nouvelles polices, plus rondes et plus lisibles, livrées avec le jeu (même
  allure sur tous les ordinateurs) ; le mot à taper utilise une police faite
  pour les enfants qui apprennent à lire (Andika).
- Interface de course, écran d'arrivée et fenêtres des réglages aux
  nouvelles couleurs : boutons en relief, panneaux arrondis, minicarte plus
  lisible, traits de vitesse pendant le turbo, confettis à l'arrivée.

### Corrigé

- Le jeu téléchargé est plus léger : les captures d'écran des tests
  automatiques n'y sont plus emballées.

## [0.9.1] - 2026-11-01

### Corrigé

- Caméra de course : avec le clavier à l'écran, elle descendait au ras de la
  route (vue écrasée, kart énorme) et passait parfois sous la route. Elle
  reste maintenant derrière et au-dessus du kart, jamais à moins de 1,60 m de
  la route ou du sol, et le kart est cadré juste au-dessus du panneau du mot.
- La route ne passe plus sous l'herbe par endroits (les karts semblaient
  rouler sous le sol, surtout sur la Prairie).
- « Ralenti… » / « TURBO ! » est affiché en haut de l'écran et ne cache plus
  le kart.

## [0.9.0] - 2026-11-01

### Ajouté

- Trois nouveaux circuits, à choisir dans le menu (« Choisis ton circuit »,
  en haut à droite) : la Plage (sable, mer et dunes), la Montagne enneigée
  (neige, sapins, montées et descentes) et le Canyon (roche rouge au coucher
  du soleil). Le circuit choisi apparaît derrière le menu et est retenu pour
  chaque enfant.
- Une musique par circuit, plus longue et plus variée : chaque morceau
  enchaîne plusieurs parties (de 35 à 45 secondes avant de recommencer, au
  lieu d'une petite boucle de 6 secondes), avec batterie, basse et mélodie.

## [0.8.0] - 2026-11-01

### Ajouté

- Leçons du clavier, rangée par rangée, dans les listes de mots (Réglages →
  Listes de mots) :
  - Leçon 1 : rangée du milieu (q s d f g h j k l m), avec des exercices de
    lettres (ff, jj, fj, dk…) ;
  - Leçon 2 : + rangée du haut (a z e r t y u i o p) ;
  - Leçon 3 : + rangée du bas (w x c v b n) ;
  - Leçon 4 : les accents (é è à ç ù).
  Chaque leçon n'utilise que les rangées déjà vues, et chaque mot contient au
  moins une touche de la nouvelle rangée.

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
