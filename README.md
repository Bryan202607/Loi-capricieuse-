# Lois Capricieuses

Jeu 2D pour enfants et adultes, fait avec Godot 4.3.
Chaque jour, deux lois de la nature absurdes sont tirées au sort (« l'eau remonte », « les fruits sont timides », « monde miroir »...). Il faut rapporter 5 fruits à la cabane malgré elles.

## Parcours (v4)
- **Cinématique d'ouverture** (21 s, on peut la passer en touchant) puis **écran d'accueil** : JOUER (reprend au dernier niveau), NIVEAUX, INTRO (revoir la cinématique), SON, paramètres (son, effacer la progression).
- **160 niveaux** à la « Level Devil » (facile, normal, difficile, très difficile, **extrême dès le 100** avec 3 lois à la fois, et **les niveaux 156 à 160 sont impossibles**, même pour le robot de test) : on choisit n'importe quel niveau débloqué (étoiles et meilleur score affichés). Chaque niveau a toujours les mêmes lois ; les 6 premiers sont écrits à la main, les autres sont tirés avec une graine fixe.
- **Nuit du suspense** : quand tu rapportes tous les fruits, la nuit tombe (lueurs, lucioles, hibou, grillons, villageois qui dorment), puis le bilan, puis l'**aube** du jour suivant.
- **Sauvegarde automatique** (niveau atteint, étoiles, scores, son) dans le navigateur ou le téléphone. Bouton pause en jeu ; bouton retour Android géré.

## Pour tous les âges
- **3 langues** (français, anglais, espagnol) : choix dans Paramètres, langue du téléphone détectée au premier lancement. Pour en ajouter une : un dictionnaire dans `lang.gd`.
- **Mode détendu** (Paramètres) : 70 % de temps en plus et un bateau plus patient, pour jouer sans stress.

## Cœurs, pubs et version sans pub
- **5 cœurs** : chaque défaite en retire un ; un cœur revient toutes les **5 minutes** (même jeu fermé). Sans cœur, écran d'attente.
- **Retour en arrière de 20 s** après une défaite, contre une pub de 25 s.
- Dès la **3e défaite** sur un niveau : **passer le niveau** contre 2 pubs de 30 s (1 étoile).
- **Pub obligatoire** après chaque 3e niveau gagné (3, 6, 9...).
- **Version sans pub (1,99 $)** : plus de pub, cœurs illimités, retour en arrière gratuit, et la **solution après 5 défaites** (réservée à cette version).
- `TEST_MODE = true` dans `main.gd` : les pubs sont des écrans d'essai raccourcis et l'achat est simulé. **Avant publication** : mettre `false`, brancher AdMob et Google Play Billing, et fixer le prix 1,99 $ dans la Play Console (Google convertit en monnaie locale).
- Test : `godot --headless --path . --script tools/test_monet.gd`.

## Carte qui s'allonge (niveau 12 et plus)
À partir du niveau 12, la carte s'étend vers le nord et défile avec le joueur : plus le niveau est élevé, plus le terrain est long, avec plus de pièges (ours, fosses, pics qui surgissent), de faux fruits et de rochers qui roulent. Des flèches indiquent les fruits hors écran et la maison.

## Pièges cachés (niveau 3 et plus)
Positions fixes par niveau, jamais montrées avant une mort : pièges à ours et fosses camouflés dans l'herbe, faux fruits piégés (identiques aux vrais), chutes de pierres et foudre (une ombre ou un cercle apparaît un instant avant l'impact). Ils augmentent avec le niveau. Après une mort, le piège fatal est révélé ; avec la version sans pub, la « solution » les marque tous en rouge. Le robot de test les connaît et les évite.

## Publier sur GitHub, Vercel et Android
- Vercel : dossier `web/` (Root Directory = `web`, Framework = Other).
- GitHub Actions (`.github/workflows/build.yml`) : exporte la version web, l'APK et l'AAB, publiés dans l'onglet *Releases*. Secrets à créer : `ANDROID_KEYSTORE_BASE64` et `KEYSTORE_PASSWORD`.

## Règles
- Touche l'écran : le personnage va vers l'endroit touché (le doigt peut glisser).
- La rivière est mortelle : il faut prendre le **bateau** (il fait des allers-retours et s'arrête à chaque quai ; approche-toi et tu embarques). Avec « L'eau est solide », la rivière gèle et on la traverse à pied.
- Chaque niveau : 2 lois parmi 13 (eau qui remonte, bateau fou, fruits timides/aimants/vagabonds, pieds de plume/plomb, grand sac, monde miroir, vent d'est, nuit magique, pluie glissante...).
- Le **fruit doré** (à partir du jour 2) donne +8 s. Étoiles : 3 si on finit avec beaucoup de temps restant.
- Le **village grandit** à chaque jour gagné (jusqu'à 6 habitants, une 2e maison au jour 4). La progression est sauvegardée.
- La difficulté monte doucement : de 5 à 8 fruits à rapporter.
- Après **5 défaites de suite**, la solution s'affiche (conseils + ligne jaune qui guide le joueur).
- Bouton son en haut à droite (coupe la musique et les effets).

## Graphismes et sons (tous générés, donc libres de droits)
- `python3 tools/gen_assets.py && python3 tools/gen_assets2.py` : images dans `assets/` (Pillow, numpy, scipy).
- `python3 tools/gen_sounds.py` : effets et musique dans `assets/sfx/`.

## Tests automatiques
`godot --headless --path . --script tools/test_bot.gd -- <jour> <essais>` : un robot joue toutes les paires de lois avec le guide et vérifie qu'elles sont gagnables.

## Ajouter une loi
1. Ajouter une entrée dans `laws.gd` (id, groupe, nom, description, conseil, couleur).
2. Ajouter son effet dans la fonction `apply_laws()` de `main.gd`.
3. Relancer le test du robot.

## Publier la version web (iPhone)
1. Mettre tous ces fichiers dans un dépôt GitHub (branche `main`).
2. Onglet **Actions** : le workflow « Export web » se lance tout seul et crée la branche `web`.
3. Sur Vercel : Add New > Project > choisir le dépôt, ouvrir *Settings > Git* et mettre **Production Branch = web**. Framework : Other, aucune commande de build.
4. Vercel donne l'adresse du jeu, à ouvrir dans Safari sur iPhone.

## Android / Play Store
Étape suivante : ajouter un preset Android et un second workflow qui produit le fichier AAB (avec une clé de signature stockée dans les « Secrets » GitHub).

## Idées pour la suite
- Villageois qui gardent la mémoire de tes solutions (traditions du village)
- Plus de lois, de décors et de défis (pont à construire, animaux)
- Mode coopératif : chaque joueur contrôle une loi
- Lois créées et partagées par les joueurs

## Difficulté
Le temps de chaque niveau = temps dont le robot a besoin (`levels_data.gd`, généré par `tools/calib.gd`) x une marge qui passe de 2,5 (niveau 1) à 1,1 (niveau 155). Relancer `tools/calib.gd` après tout changement de règles.

## Statistiques des joueurs (identifiant unique par téléphone)
Chaque téléphone génère un identifiant anonyme aléatoire (affiché dans Paramètres). Quand le joueur est en ligne, ses stats (niveau atteint, étoiles, score, morts, victoires, temps de jeu, langue, plateforme, dernière connexion) sont envoyées à une base Firebase Realtime Database. Le joueur peut désactiver l'envoi dans Paramètres (« STATS EN LIGNE »).

Mise en place :
1. console.firebase.google.com → créer un projet → « Realtime Database » → créer la base.
2. Onglet « Règles » : coller le contenu de `firebase_rules.json` → Publier (écriture permise, lecture publique interdite).
3. Copier l'adresse de la base (ex. `https://mon-projet-default-rtdb.firebaseio.com`) dans `STATS_URL` en haut de `main.gd`.
4. Les stats apparaissent dans l'onglet « Données » sous `players/<identifiant>` (vue propriétaire).
Pense à mentionner cette collecte dans la politique de confidentialité exigée par le Play Store.
