# BAO3 version 2
Boite à outils 3 réalisée dans le cadre du projet encadré INALCO-Sorbonne Nouvelle d'extraction et d'analyse morpho-synthaxique d'un fil XML RSS pour l'année 2021
LA BAO2 etant terminée (etiquetage avec treetagger et udpipe), on passe à la BAO3 (extraction de patrons)
Cette BAO3 est une BAO1, BAO2 et BAO3 ou seulement une BAO3 (voir options)
La version 2 consiste en une modification en profondeur du code pour gerer les options.

Le fil XML RSS du journal Le Monde sur lequel je travaille est telechargeable ici : http://www.tal.univ-paris3.fr/corpus/arborescence-filsdumonde-2020-tljours-19h.tar.gz

Vous devez telecharger l'archive de tree-tagger ici https://icampus.univ-paris3.fr/pluginfile.php/207509/course/section/77973/tree-tagger%20%281%29
et placer l'archive dezippée dans le repertoire du projet.

Vous pouvez acceder à l'aide avec l'option -h ou -help


Pour une recherche BAO1 + BAO2 + BAO3 :


ARGV[0] = option -s (standard BAO1 + BAO2 + BAO3)

ARGV[1] = repertoire dans lequel chercher les fichiers xml rss

ARGV[2] = code de la categorie

ARGV[3] = modele udpipe à utiliser

ARGV[4] = nom du fichier de sortie udpipe (.txt)

ARGV[5] = nom du fichier de sortie treetagger

ARGV[6] = motifs pour l'extraction de patrons (forme POS-POS-POS etc...). Les POS sont separes par des -


Exemple = perl bao3_regexp.pl -s 2020 3208 modeles/french-gsd-ud-2.5-191206.udpipe udpipe_sortie.txt treetagger_sortie DET-NOUN

Par defaut, le fichier de sortie dans lequel se trouve les patrons se nomme patrons.txt



Pour une recherche BAO3 uniquement (extraction de patrons) option -p

ARGV[0] = -p (extraction de patrons uniquement)

ARGV[1] = fichier udpipe à utiliser

ARGV[2] = nom de sortie du fichier d'extraction de patrons

ARGV[3] = motif de l'extraction POS-POS-POS (exmple DET-NOUN-VERB, DET-NOUN, NOUN-VERB etc...)

La recherche de motifs POS n'est pas limitee. Vous pouvez chercher 5 POS si vous le souhaitez. Le minumum est de deux.


Exemple : perl bao3_regexp.pl -p udpipe_sortie.txt extraction_patrons.txt DET-NOUN-AUX-VERB


IMPORTANT


L'arborescence doit etre la suivante : 

/dossiermonprogramme/mon_script.pl (script en cours d'utilisation)

/dossiermonprogramme/treetagger2xml-utf8.pl (version modifiee par mes soins)

/dossiermonprogramme/tokenise-utf8.pl

/dossiermonprogramme/tree-tagger-linux-3.2

/dossiermonprogramme/tree-tagger-linux-3.2/french-utf8.par (fichier de langue treetagger à placer ici)
