# BAO3-4 version finale
Boite à outils 3 réalisée dans le cadre du projet encadré INALCO-Sorbonne Nouvelle d'extraction et d'analyse morpho-synthaxique d'un fil XML RSS pour l'année 2021
LA BAO2 etant terminée (etiquetage avec treetagger et udpipe), on passe à la BAO3 (extraction de patrons)
Cette BAO3 est une BAO1, BAO2 et BAO3 ou seulement une BAO3 (voir options). Elle peut aussi servir comme outils de classification seulement  ou d'extraction de patrons à partir de treetagger ou udpipe.

La version 2 consiste en une modification en profondeur du code pour gerer les options.

La version 2.1 ne traite que les tokens originaux, ceux qui sont divisés en deux tokens par exemple dans UDPipe. Ainsi pour les DET, vous aurez par exemple les "des" mais pas les formes "de" et "les". C'est la prise en compte des lignes commencant par 4-5 ou 8-9 par exemple.

La version 3.0 integre une classification automatique des fils RSS parcourus grace à la similarité cosinus avec un taux de réussite de plus de 90%.

La version 3.1 utilise les formes lémmatisées des mots pour une précision accrue (95% de succes).

De plus, elle permet l'extraction des patrons morpho-synthaxiques également à partir du fichier de sortie XML treetagger, en plus d'UDPipe.

Le fil XML RSS du journal Le Monde sur lequel je travaille est telechargeable ici : http://www.tal.univ-paris3.fr/corpus/arborescence-filsdumonde-2020-tljours-19h.tar.gz

Vous devez telecharger l'archive de tree-tagger ici https://icampus.univ-paris3.fr/pluginfile.php/207509/course/section/77973/tree-tagger%20%281%29
et placer l'archive dezippée dans le repertoire du projet.

Vous pouvez acceder à l'aide avec l'option -h ou -help

﻿Bienvenue dans le module d'aide ! 
Il a été écrit entièrement sur Vim 8.

Avant tout, pour pouvoir exécuter le script sans erreurs, il convient d'installer un certain nombre de modules supplémentaires via CPAN.
Les commandes à effectuer sont les suivantes (valables pour perl v5.32):

sudo cpan

install Timer::Simple

install Ufal::UDPipe

install File::Remove

install Data::CosineSimilarity

install Lingua::Stem::Fr


D'autres modules seront peut-être a installer en fonction de votre version de Perl.
Ceux-la sont nécessairement à installer dans tous les cas.
Ce manuel ne peut couvrir l'ensemble des possibilités offertes par le script donc il ira au plus efficace. A vous ensuite de combiner les options entre elles pour produire le résultat souhaité.

Les options spécifiques de recherche:

-u ou --u :

l'option -u permet de spécifier que l'extraction des patrons utilise le fichier de sortie UDPipe.
Sinon le fichier XML treetagger sera utilisé par défaut. Faites attention aux noms des POS. Elles sont différentes entre les deux programmes (exemple : pour nom, c'est NOUN dans UDPipe et NOM dans treetaggger).
Le script affichera un message d'erreur et s’arrêtera si les POS sont invalides.
Dans tous les cas, les résultats d'extraction entre UDPipe et treetagger seront identiques.
L'option -u est utilisable pour une utilisation standard comme pour une utilisation en BAO3 uniquement.

-f ou --f :

l'option -f permet de catégoriser automatiquement les fichiers RSS à partir des datas des années précédentes et effectue un récapitulatif des résultats obtenus dans un fichier de sortie. Ce fichier contient pour chaque fichier XML RSS parcouru la catégorie identifiée en premier et la véritable catégorie à laquelle appartient le fichier XML RSS.
Vous avez à la dernière ligne de ce fichier le taux de succès de la classification via Data::CosineSimilarity.
Arguments à spécifier après l'option -f
- répertoire dans lequel se trouve les fichiers d’entraînement des années précédentes (pas de sous dossier).
Les fichiers doivent porter le nom d'une catégorie et avoir une extension .txt
Il ne doit y avoir que ces fichiers et rien d'autre dans le répertoire.
Il ne doit y avoir que ces fichiers dans le répertoire.
- nom du fichier de sortie récapitulatif (c'est a vous de choisir)
L'option -f n'est disponible que pour une utilisation standard (option -s).

-c ou --c:

l'option -c permet de lancer le script en mode classification uniquement. Option qui va plus loin que l'option -f.
L'option -c ou --c est un sous module à part entière dans le script. 
Pour cela, elle requiert 4 arguments en ligne de commande et est incompatible avec une utilisation standard (option -s).
ARGV[0] = -c (spécifie le mode de lancement du programme en mode classification uniquement)

ARGV[1] = arborescence XML dans laquelle chercher les fichiers XML

ARGV[2] = répertoire dans lequel se trouvent les fichiers des années précédentes
Ces fichiers doivent être au format txt et porter le nom d'une catégorie existante sinon ils seront ignorés.

ARGV[3] = code de la catégorie à trouver
Si le code de la catégorie n'existe pas, un message d'erreur apparaît et on met fin au script

ARGV[4] = fichier récapitulatif de sortie de la classification

Exemple de commande en mode classification:

perl bao3_regexp_classification.pl -c 2020 categorie-2017-2018-2019-sf 3476 sortie_cinema.txt

Cette commande lance le programme en mode classification uniquement sur la catégorie cinéma (3476) et génère un fichier récapitulatif
nommé sortie_cinema.txt

-d ou --d:

L'option -d permet de lancer le script en mode extraction de relation de dépendances uniquement.
L'option -d est un sous module à part entière dans le script.
Ce sous module permet l'extraction de dépendances d'une relation choisie a partir du fichier txt udpipe.
Pour cela, il requiert 4 arguments :
ARGV[0] = -d (spécifie le mode de lancement du programme en mode extraction de dépendances uniquement)

ARGV[1] = fichier de sortie udpipe au format txt

ARGV[2] = nom de la relation de dépendance

ARGV[3] = fichier de sortie récapitulatif

Exemple de commande en mode extraction de dépendances:

perl bao3_regexp_classification.pl -d fichier_udpipe.txt obj dependances_obj.txt

Cette commande lance le programme en mode extraction de dépendances uniquement pour la relation obj et écrit le résultat
dans le fichier récapitulatif dependances_obj.txt


1) Pour une recherche complète BAO1 + BAO2 + BAO3 (recherche standard):


option -s ou -standard (à spécifier en premier en argument dans la ligne de commandes)

ARGV[0] = option -s (standard BAO1 + BAO2 + BAO3)

ARGV[1] = répertoire dans lequel chercher les fichiers xml rss

ARGV[2] = code de la catégorie

ARGV[3] = modèle udpipe à utiliser

ARGV[4] = nom du fichier de sortie udpipe (.txt)

ARGV[5] = nom du fichier de sortie treetagger (sans extension)

ARGV[6] = -u (extraction a partir du fichier udpipe) (facultatif) sinon treetagger par défaut

ARGV[6] = -m (option de motif de l'extraction du patron)

ARGV[7,] = motif de l'extraction du patron (POS POS POS)

Exemple d'une utilisation standard avec extraction udpipe + classification des fils RSS:

perl bao3_regexp_classification.pl -s 2020 3476 modeles/french-gsd-ud-2.5-191206.udpipe udpipe_sortie.txt treetagger_sortie -f 
categorie-2017-2018-2019-sf sortie_verif.txt -u -m DET NOUN VERB

Dans cet exemple, le script effectue une recherche standard avec classification (résultats dans sortie_verif.txt)
et spécifie que l'extraction des patrons (ici DET NOUN VERB) utilise le fichier de sortie UDPipe.

Exemple d'une utilisation standard avec extraction à partir du fichier treetagger sans classification avec l’extraction du patron NOM-ADJ:

perl bao3_regexp_classification.pl -s 2020 3476 modeles/french-gsd-ud-2.5-191206.udpipe udpipe_sortie.txt treetagger_sortie -m NOM ADJ

Par défaut, le fichier de sortie dans lequel se trouve les patrons extraits se nomme patrons_[catégorie].txt et se situe dans le répertoire courant du script  où [catégorie] est le nom de la catégorie.
Le script produit également un fichier BAO1 dans lequel les items sont classés non pas par date de publication (défaut) mais par fichier xml.
Ce fichier se nomme bao1_regex_file.xml et est généré dans le répertoire courant du script.

2) Pour une recherche BAO3 uniquement (extraction de patrons) :


option -p ou -patrons (à spécifier en premier en argument dans la ligne de commandes)


ARGV[0] = -p (extraction de patrons uniquement)

ARGV[1] = fichier udpipe/treetagger à utiliser

ARGV[2] = nom de sortie du fichier d'extraction de patrons

ARGV[3] = -u (extraction à partir du fichier udpipe) (facultatif) sinon treetagger par défaut

ARGV[3-4] = -m (option de motif de l'extraction du patron)

ARGV[4-5+,] = motif de l'extraction du patron (POS POS POS)


La recherche de motifs POS n'est pas limitée. Vous pouvez chercher 5 POS ou plus si vous le souhaitez. Le minimum est de deux.

Exemple d'utilisation en mode BAO3 uniquement utilisant le fichier UDPipe:

perl bao3_regexp_classification.pl -p udpipe_sortie.txt extraction_patrons.txt -u -m NOUN AUX VERB

Exemple d'utilisation en mode BAO3 uniquement utilisant le fichier XML treetagger:

perl bao3_regexp_classification.pl -p treetagger_sortie.xml extraction_patrons.txt -m DET NOM ADJ

Par défaut, l'extraction des patrons utilise le fichier treetagger comme unique support(sauf option -u)


******************** IMPORTANT ********************


L'arborescence de travail doit être organisée de cette manière : 

/dossiermonprogramme/mon_script.pl (le script principal, ce script)

/dossiermonprogramme/treetagger2xml-utf8.pl (version modifiée par mes soins)

/dossiermonprogramme/tokenise-utf8.pl

/dossiermonprogramme/tree-tagger-linux-3.2

/dossiermonprogramme/tree-tagger-linux-3.2/french-utf8.par (fichier de langue treetagger a placer ici)

Pour récupérer le fichier treetagger2xml-utf8.pl modifie, vous pouvez le télécharger sur mon github :

https://github.com/OzzyProjects/BAO3
