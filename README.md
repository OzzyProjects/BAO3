# BAO3
Boite à outils 3 réalisée dans le cadre du projet encadré INALCO-Sorbonne Nouvelle d'extraction et d'analyse morpho-synthaxique d'un fil XML RSS pour l'année 2021

Le fil XML du journal Le Monde sur lequel je travaille est telechargeable ici : http://www.tal.univ-paris3.fr/corpus/arborescence-filsdumonde-2020-tljours-19h.tar.gz

Vous pouvez acceder à l'aide avec l'option -h:

Vous devez telecharger l'archive de tree-tagger ici https://icampus.univ-paris3.fr/pluginfile.php/207509/course/section/77973/tree-tagger%20%281%29
et placer l'archive dezippée dans le repertoire du projet.

Pour une recherche BAO1 + BAO2 + BAO3 :

$ARGV[0] = repertoire dans lequel chercher les fichiers xml rss

$ARGV[1] = code de la categorie

$ARGV[2] = modele udpipe à utiliser

$ARGV[3] = nom du fichier de sortie udpipe (.txt)

$ARGV[4] = nom du fichier de sortie treetagger

$ARGV[5] = motifs pour l'extraction de patrons (forme POS-POS-POS etc...)

Exemple = perl bao3_regexp.pl 2020 3208 modeles/french-gsd-ud-2.5-191206.udpipe udpipe_sortie.txt treetagger_sortie DET-NOUN


Pour une recherche BAO3 uniquement (extraction de patrons) option -p

$ARGV[0] = -p (extraction de patrons uniquement)

$ARGV[1] = fichier udpipe à utiliser

$ARGV[2] = nom de sortie du fichier d'extraction de patrons

$ARGV[3] = motif de l'extraction POS-POS-POS (exmple DEP-NOUN-VERB, DET-NOUN, NOUN-VERB etc...)

La recherche de motifs POS n'est pas limitee. Vous pouvez chercher 6 POS si vous le souhaitez

Exemple : perl bao3_regexp.pl -p udpipe_sortie.txt extraction_patrons.txt DET-NOUN-VERB


IMPORTANT

L'arborescence doit etre la suivante :

/dossiermonprogramme/mon_script.pl (script en cours d'utilisation)

/dossiermonprogramme/treetagger2xml-utf8.pl (version modifiee)

/dossiermonprogramme/tokenise-utf8.pl

/dossiermonprogramme/tree-tagger-linux-3.2

/dossiermonprogramme/tree-tagger-linux-3.2/french-utf8.par (fichier de langue treetagger à placer ici)

Le fichier treetagger2xml-utf8.pl n'est pas original. Il a été modifié par mes soins pour les besoins de la BAO2
