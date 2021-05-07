# BAO3 version 3.1
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

Avant tout, pour pouvoir executer le scrit sans erreurs, il convient d'installer un certain nombre de modules supplementaires via CPAN.
Les commandes a effectuer sont les suivantes (valables pour perl v5.32):

sudo cpan

install Timer::Simple

install Ufal::UDPipe

install File::Remove

install Data::CosineSimilarity


D'autres modules seront peut-etre a installer en fonction de votre version de Perl.
Ceux-la sont necessairement à installer dans tous les cas.


Les options specifiques de recherche:

-u : l'option -u permet de specifier que l'extraction des patrons utilise le fichier de sortie UDPipe.
Sinon le fichier XML treetagger sera utilisé par defaut. Faites attention aux noms des POS. Elles
sont differentes entre les deux programmes (exemple : pour nom, c'est NOUN dans UDPipe et NOM dans treetaggger).
Le script affichera un message d'erreur et s'arretera si les POS sont invalides.
Dans tous les cas, les resultats d'extraction entre UDPipe et treetagger seront identiques.
L'option -u est utilisable pour une utilisation standard comme pour une utilisation en BAO3 uniquement.

-f : l'option -f permet de categoriser automatiquement les fichers RSS à partir des datas des années precédentes et effectue
un recapitulatif des resultats obtenus dans un fichier de sortie. Ce fichier contient pour chaque fichier XML RSS parcouru
la categorie identifiee en premier et la veritable categorie à laquelle appartient le fichier XML RSS.
Vous avez à la derniere ligne de ce fichier le taux de succes de la classification via Data::CosineSimilarity.
Arguments à spécifier apres l'option -f
- repertoire dans lequel se trouve les fichiers d'entrainement des années precédentes (pas de sous dossier).
Les fichiers doivent porter le nom d'une categorie et avoir une extension .txt
Il ne doit y avoir que ces fichiers dans le repertoire.
- nom du fichier de sortie recapitulatif (c'est à vous de choisir)
L'option -f n'est disponible que pour une utilisation stantard (option -s).



1) ******* Pour une recherche complete BAO1 + BAO2 + BAO3 (recherche standard): *******


option -s ou -standard (a specifier en premier en argument dans la ligne de commandes)


ARGV[0] = option -s (standard BAO1 + BAO2 + BAO3)

ARGV[1] = repertoire dans lequel chercher les fichiers xml rss

ARGV[2] = code de la categorie

ARGV[3] = modele udpipe à utiliser

ARGV[4] = nom du fichier de sortie udpipe (.txt)

ARGV[5] = nom du fichier de sortie treetagger (sans extension)

ARGV[6] = -u (extraction a partir du fichier udpipe) (facultatif) sinon treetagger par defaut

ARGV[6] = -m (option de motif de l'extraction du patron)

ARGV[7,] = motif de l'extraction du patron (POS POS POS)


Exemple d'une utilisation standard avec extraction udpipe + classification des fils RSS:

perl bao3_regexp.pl -s 2020 3476 modeles/french-gsd-ud-2.5-191206.udpipe udpipe_sortie.txt treetagger_sortie -f 
categorie-2017-2018-2019-sf sortie_verif.txt -u -m DET NOUN VERB

Dans cet exemple, le script effectue une recherche standard avec classification (resultats dans sortie_verif.txt)
et spécifie que l'extraction des patrons (ici DET NOUN VERB) utilise le fichier de sortie UDPipe.

Exemple d'une utilisation standard avec extraction treetagger sans classification:

perl bao3_regexp.pl -s 2020 3476 modeles/french-gsd-ud-2.5-191206.udpipe udpipe_sortie.txt treetagger_sortie -m NOM ADJ

Par defaut, le fichier de sortie dans lequel se trouve les patrons extraits se nomme patrons.txt et se situe dans le 
repertoire courant du script.




2) ******* Pour une recherche BAO3 uniquement (extraction de patrons) : *******


option -p ou -patrons (a specifier en premier en argument dans la ligne de commandes)


ARGV[0] = -p (extraction de patrons uniquement)

ARGV[1] = fichier udpipe/treetagger à utiliser

ARGV[2] = nom de sortie du fichier d'extraction de patrons

ARGV[3] = -u (extraction à partir du fichier udpipe) (facultatif) sinon treetagger par defaut

ARGV[3-4] = -m (option de motif de l'extraction du patron)

ARGV[4-5+,] = motif de l'extraction du patron (POS POS POS)


La recherche de motifs POS n'est pas limitee. Vous pouvez chercher 5 POS ou plus si vous le souhaitez. Le minumum est de deux.


Exemple d'utilisation en mode BAO3 uniquement utilisant le fichier UDPipe:
perl bao3_regexp.pl -p udpipe_sortie.txt extraction_patrons.txt -u -m NOUN AUX VERB


Exemple d'utilisation en mode BAO3 uniquement utilisant le fichier XML treetagger:
perl bao3_regexp.pl -p treetagger_sortie.xml extraction_patrons.txt -m DET NOM ADJ


Par defaut, l'extraction des patrons utilise le fichier treetagger comme unique support(sauf option -u)



******************** IMPORTANT ********************



L'arborescence de travail doit etre organisee de cette maniere : 


/dossiermonprogramme/mon_script.pl (le script principal)

/dossiermonprogramme/treetagger2xml-utf8.pl (version modifiee par mes soins)

/dossiermonprogramme/tokenise-utf8.pl

/dossiermonprogramme/tree-tagger-linux-3.2

/dossiermonprogramme/tree-tagger-linux-3.2/french-utf8.par (fichier de langue treetagger a placer ici)


Pour recuperer le fichier treetagger2xml-utf8.pl modifie, vous pouvez le telecharger sur mon github :
https://github.com/OzzyProjects/BAO3
