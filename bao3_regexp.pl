#!/usr/bin/perl

#use strict;
#use warnings;

#--------------------------------------------------------------------------------------------------------------------------------------------------------
# ARMANGAU Etienne
# BAO1 + BAO2 + BAO3 + extraction des patrons à partir de UDPipe ou treetagger + classification automatique des fils RSS parcourus
#--------------------------------------------------------------------------------------------------------------------------------------------------------

use Timer::Simple; # pour le timer
use Ufal::UDPipe; # pour l’étiquetage UDPipe
use File::Remove qw(remove); # pour la suppression des fichiers
use List::MoreUtils qw(natatime); # pour la recherche des patrons
use Getopt::Long qw(GetOptions); # pour la gestion des options
use File::Basename qw(basename); # pour avoir le nom du script
use Unicode::Normalize qw(normalize);
use Data::CosineSimilarity; # pour la recherche des similarités cosinus entre les textes
use Data::Dump qw(dump);
use List::MoreUtils qw(uniq);
use Thread;
use Scalar::Util qw(blessed);

# pour supprimer le warning smartmatch à cause de l'utilisation de l’opérateur ~~
no warnings 'experimental::smartmatch';
# pour les informations sur les opérations I/O (plutot que or die $! à chaque fois)
#use autodie;

# on ne travaille qu'en utf-8
use open qw/ :std :encoding(UTF-8)/;

# on instancie un timer commençant à 0.0s par défaut
my $t = Timer::Simple->new();
# on lance le timer
$t->start;

# on construit notre outil de gestion des options
my (@opt_p, @opt_s, @opt_m, $opt_patrons, @opt_filter, @opt_class, $help) = (undef) x 7;

Getopt::Long::Configure("posix_default", "ignore_case", "prefix_pattern=(--|-)", "require_order");

# si une erreur se produit au moment de la récupération des options et des arguments, on met fin au script
GetOptions("p|patrons=s{2}" => \@opt_p, "s|standard=s{5}" => \@opt_s, "f|filter=s{2}" => \@opt_filter,
"u|udpipe" => \$opt_patrons, "m|motif=s{2,}" => \@opt_m, , "c|class=s{4}" => \@opt_class, "h|help" => \$help) or exit_bad_usage("Nombre d'arguments ou option invalide !\n");

# on instancie un nouvel objet Data::CosineSimilarity
my $cosinus_similarity = Data::CosineSimilarity->new;
# filehandle du fichier de sortie récapitulatif de classification
my $filehandle = undef;
# nombre de fichiers rss traités pour une rubrique, nombre de bonnes catégories attribuées
my ($rubriques, $rubriques_okay)  = (0) x 2;

# référence anonyme à un dictionnaire qui associe chaque clé (code de la catégorie) à sa valeur (nom de la catégorie)
my $categories = {3208 => "une", 3210 => "international", 3214 => "europe", 3224 => "societe", 3232 => "idees", 3234 => "economie",
3236 => "actualite_medias", 3242 => "sport", 3244 => "planete", 3246 => "culture", 3260 => "livres", 3476 => "cinema",
3546 => "voyage", 65186 => "technologies", 8233 => "politique", "env_sciences" => "sciences"};
# /!\ avec catégorie : les 4 premiers chiffres ne fonctionnent pas pour technologies (on utilise les 5 premiers pour cette rubrique)

# partie Python ici
# on utilise Spacy pour le pré-processing (lemmes + filtrage des stop words) et écriture du résultat dans un fichier de sortie
# avec l'extension token, car le pipe Inline::Python est très long. Il n'existe pas de bons lemmatiseurs en français en Perl
use Inline Python => <<'END_OF_PYTHON';

import spacy
from spacy.lang.fr.stop_words import STOP_WORDS as fr_stop
nlp = spacy.load('fr_core_news_md')
nlp.max_length = 40000000

fr_stop = set(fr_stop)
def file_lemmatizer(file):
	with open(str(file)+'tokens', 'w',encoding='utf-8') as output:
		doc = nlp(open(file).read())
		output.write(' '.join(list(map(lambda token: token.lemma_ if token.lemma_ not in fr_stop and len(token.lemma_) >3 else "", doc))))
		return str(file)+'tokens'

def content_lemmatizer(data):
	doc = nlp(data)
	return list(map(lambda token: token.lemma_ if token.lemma_ not in fr_stop and len(token.lemma_) >3 else "", doc))
END_OF_PYTHON
# fin de la partie python

# lancement en version BAO3 uniquement
if (@opt_p and not @opt_s){

	#@opt_m est le tableau dans lequel on recupere les POS du motif à extraire
	# si opt_patrons est definie, on utilise le fichier de sortie udpipe pour l'extraction
	if ($opt_patrons){
		&extract_patrons_udpipe($opt_p[0], $opt_p[1], \@opt_m);
	}
	# sinon, on utilise celui de treetagger
	else{
		&extract_patrons_treetagger($opt_p[0], $opt_p[1], \@opt_m);
	}

}

# lancement en version classification uniquement
elsif (@opt_class and not @opt_s){

	print("Lancement en mode classification uniquement !\n");

	open $filehandle, ">:encoding(utf-8)", $opt_class[3] or die "$!\n";

	&train_cosine_similarity($opt_class[1], $opt_class[2]);

	&parcourir($opt_class[0]);

	close $filehandle;

	# on stoppe le timer
	$t->stop;
	# temps écoulé depuis le lancement du programme
	print "time so far: ", $t->elapsed, " seconds\n";

}

# menu d'aide
elsif ($help){

my $help = "\nBienvenue dans le module d'aide !\n

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
- repertoire dans lequel se trouve les fichiers d'entrainement des annees precedentes (pas de sous dossier).
Les fichiers doivent porter le nom d'une categorie et avoir une extension .txt
Il ne doit y avoir que ces fichiers et rien d'autre dans le repertoire.
Il ne doit y avoir que ces fichiers dans le repertoire.
- nom du fichier de sortie recapitulatif (c'est a vous de choisir)
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

perl bao3_regexp_classification.pl -s 2020 3476 modeles/french-gsd-ud-2.5-191206.udpipe udpipe_sortie.txt treetagger_sortie -f 
categorie-2017-2018-2019-sf sortie_verif.txt -u -m DET NOUN VERB

Dans cet exemple, le script effectue une recherche standard avec classification (resultats dans sortie_verif.txt)
et spécifie que l'extraction des patrons (ici DET NOUN VERB) utilise le fichier de sortie UDPipe.

Exemple d'une utilisation standard avec extraction treetagger sans classification:

perl bao3_regexp_classification.pl -s 2020 3476 modeles/french-gsd-ud-2.5-191206.udpipe udpipe_sortie.txt treetagger_sortie -m NOM ADJ

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

perl bao3_regexp_classification.pl -p udpipe_sortie.txt extraction_patrons.txt -u -m NOUN AUX VERB

Exemple d'utilisation en mode BAO3 uniquement utilisant le fichier XML treetagger:

perl bao3_regexp_classification.pl -p treetagger_sortie.xml extraction_patrons.txt -m DET NOM ADJ

Par defaut, l'extraction des patrons utilise le fichier treetagger comme unique support(sauf option -u)


******************** IMPORTANT ********************

L'arborescence de travail doit etre organisee de cette maniere : 

/dossiermonprogramme/mon_script.pl (le script principal)
/dossiermonprogramme/treetagger2xml-utf8.pl (version modifiee par mes soins)
/dossiermonprogramme/tokenise-utf8.pl
/dossiermonprogramme/tree-tagger-linux-3.2
/dossiermonprogramme/tree-tagger-linux-3.2/french-utf8.par (fichier de langue treetagger a placer ici)

Pour recuperer le fichier treetagger2xml-utf8.pl modifie, vous pouvez le telecharger sur mon github :

https://github.com/OzzyProjects/BAO3\n";	
	print "$help\n";
}

# lancement en version standard -s (BAO1 + BAO2 + BAO3)
elsif (@opt_s){	

	# on récupère le premier argument (répertoire)
	my $folder = $opt_s[0];
	# on récupère le second argument (code de la catégorie)
	my $code = $opt_s[1];
	# on récupère le modele à utiliser par udpipe
	my $udpipe_model = $opt_s[2];
	# on récupère le fichier de sortie de la BAO2 udpipe
	my $udpipe_file = $opt_s[3];
	# on récupère le fichier de sortie de la BAO2 treetagger
	my $treetagger_file = $opt_s[4];
	# on récupère le pattern pour la recuperation des patrons
	my $motifs_patrons = $opt_s[5];

	# si le code de la categorie est introuvable dans le dictionnaire, on met fin au script
	die "Code de categorie introuvable !\n" unless exists($categories->{$code});

	# si l'option de classification automatique a été activée, on va entrainer Cosine Similarity avec les catégories
	if (@opt_filter){

		# on ouvre le fichier de classification récapitulatif en écriture
		open $filehandle, ">:encoding(utf-8)", $opt_filter[1] or die "$!\n";
		# on lance l'entrainement des catégories
		&train_cosine_similarity($opt_filter[0], $categories->{$code});
	}

	# liste de tous les fichiers xml rss correspondant à la catégorie (référence anonyme à un array)
	my $xmls = [];

	# référence anonyme sur hash (dictionnaire) ayant pour clé le titre et la description concaténés et en valeur la date de publication
	my $items = {};
	# référence anonyme sur hash (dictionnaire) ayant pour clé le titre, la description et la date concaténés et en valeur le chemin du fichier XML
	my $items_file = {};
	# ces deux hash concernent tous les items
	
	# on ouvre les deux fichiers de sortie de la BAO1 en écriture (txt et xml)
	open my $output_xml, ">:encoding(utf-8)", "$categories->{$code}.xml" or die "$!";
	open my $output_txt, ">:encoding(utf-8)", "$categories->{$code}.txt" or die "$!";
	            
	# écriture de l'en-tete du fichier xml de sortie
	print $output_xml "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
	# écriture de la balise racine du document XML
	print $output_xml "<items>\n";

	# nom par défaut du fichier de sortie d'extraction des patrons
	my $default_patron_file = "patrons.txt";

	# on fait appel à la subroutine parcourir. recurse !
	&parcourir($folder);

	# si l'option de classification automatique a été activée
	if (@opt_filter)
	{
		# on affiche à la fin le ratio de bonnes rubriques attribuées sur le nombre total de fichiers xml rss traités (en %)
		print $filehandle "Taux de reussite : ", ($rubriques_okay/$rubriques)*100, "\n";
		# on ferme le filehandle du fichier de classification
		close $filehandle;
	}

	# on parse les fichiers xml rss
	&parsefiles;

	# on applique l’étiquetage avec udpipe et tree-tagger sur le fichier txt de sortie de la BAO1
	&etiquetage($udpipe_model, $udpipe_file, $treetagger_file);

	# on va extraire les patrons soit via le fichier udpipe soit via le fichier treetagger et les écrire dans un fichier de sortie
	# en utilisant l’opérateur ternaire
	# on passe par référence le tableau des POS @opt_m (pas le choix car plusieurs paramètres)
	$opt_patrons ? &extract_patrons_udpipe($udpipe_file, $default_patron_file, \@opt_m) : 
	&extract_patrons_treetagger($treetagger_file.".xml", $default_patron_file, \@opt_m);

#-----------------------------------------------------------------------------------------------------------------------------------------------------

	# parcours toute l'arborescence de fichiers à partir d'un répertoire
	sub parcourir{
	    
	    # on récupère l'argument de la subroutine
	    my $folder = shift @_;
	    # on supprime le / final si il existe
	    $folder =~ s/\/$//;
	    # on récupère les fichiers et dossier du répertoire
	    opendir my $dir, $folder;
	    # on liste tous les fichiers et dossiers du répertoire
	    my @files = readdir $dir;
	    # on ferme le répertoire
	    closedir $dir;
	    
	    # pour chaque élément dans mon répertoire
	    foreach my $file(@files){
	        
	        next if $file =~ /^\.\.?$/;
	        # on constitue le chemin d’aces complet du fichier/dossier
	        my $f = $folder."/".$file;
	        
	        # si c'est un dossier, on fait appel à la récursivité
	        if (-d $f){
	            &parcourir($f);
	        }
	        
	        # si c'est un fichier xml rss, on va appliquer un traitement XML::RSS
	        # on l'ajoute au tableau @$xmls
	        if ($f =~ /$code.*\.xml/){
	        	push @$xmls, $f;

	           	# si l'option de classification a été spécifiée, on va classifier chaque fichier XML à l'aide du module
	           	# CS et écrire le résultat dans le fichier récapitulatif
	           	if (@opt_filter){
	           		print $filehandle "$f\n";
	           		# on récupère le sac de mots du fichier xml
	           		my $bag_of_words = &get_bag_of_words_xml($f);
	           		# on l'ajoute dans la base de données du Data::CosineSimilarity
	           		$cosinus_similarity->add('unknown_category' => $bag_of_words);
	           		# le Data::CosineSimilarity calcule automatiquement la rubrique probable pour le fichier xml rss
	           		my ($best_label, $r) = $cosinus_similarity->best_for_label('unknown_category');
	           		print $filehandle "categorie trouvee : $best_label, categorie : $categories->{$code}\n";
	           		print("$best_label\n");
	           		# si la rubrique attribuée par le Data::CosineSimilarity est la bonne, on incrémente $rubriques_okay
	           		if ($best_label eq $categories->{$code}){
	           			$rubriques_okay++;
	           		}
	           		# un fichier xml traité de plus
					$rubriques++;
				}
	        }
	    }
	}

#-------------------------------------------------------------------------------------------------------------------------------------------------------

    # fonction qui écrit une autre BAO1 basée cette fois sur les fichiers. Les items ne sont pas triés par date mais ils le sont
    # par fichier xml dans l'ordre de parcours de l’arborescence
    # le fichier d'output est le suivant : bao1_regex_file.xml
    sub write_bao1_file{

        open my $output, ">:encoding(utf-8)", "bao1_regex_file.xml" or die "$!";
        print $output "<items>\n";
        my $global_counter = 1;
        # on restreint les valeurs (fichier xml) en supprimant les doublons avec uniq
        # pour chaque fichier xml pour éviter d'avoir plusieurs fois le même fichier et donc les mêmes items
        foreach my $value(uniq(values %$items_file)){
            print $output "<file name=\"$value\">\n";
            # on récupère la liste des items pour ce fichier en triant les valeurs associées aux clefs
            foreach my $key(grep {$items_file->{$_} eq $value} keys %$items_file){
                my @t_d = split /\|\|/, $key;
                # on écrit les données dans le fichier xml de sortie avec le nom du fichier associé pour chaque item
                print $output "<item numero=\"$global_counter\" date=\"$t_d[2]\">\n<titre>$t_d[0]</titre>\n";
                print $output "<description>$t_d[1]</description>\n</item>\n";
                $global_counter++;
            }
            print $output "</file>\n";
        }
		print $output "</items>\n";
        close $output;
    }


#-----------------------------------------------------------------------------------------------------------------------------------------------------

	# routine qui traite les fichiers xml rss récupérés
	sub parsefiles{

	    # pour chaque fichier xml rss correspondant à la catégorie
	    foreach my $file(@$xmls){
	        
	        # on ouvre en lecture le fichier xml rss
	        open my $input, "<:encoding(utf-8)","$file" or die "$!";
	        undef $/;
	        my $ligne=<$input>; # on lit intégralement (slurp mode)
	        # dans le Perl Cookbook, ils recommandent les modificateurs msx en général pour les regex

			while ($ligne=~/<item><title>(.+?)<\/title>.*?<description>(.+?)<\/description>/msgsx) {
	            # l'option s dans la recherche permet de tenir compte des \n
	            my $titre = &nettoyage($1);
	            my $description = &nettoyage($2);
	            my $date = &format_date($file);
	            # on ajoute le titre,la description et le nom du fichier concaténés dans le hash en tant que clé et ayant comme valeur la date de publication
	            # si la clé n'existe pas déja (les clés doivent etre uniques dans un hash donc on vérifie au préalable avec un test unless)
	            my $item = $titre."||".$description."||".$file;
	            my $item_file = $titre."||".$description."||".$date;
	            $items->{$item} = $date unless exists($items->{$item});
	            $items_file->{$item_file} = $file unless exists($items_file->{$item_file});
	        }
	        # on ferme le fichier xml rss
	        close $input;
	        
	    }

	    # on fait le fichier de la BAO1 avec les items triés cette fois par fichier en multi-threading
	    my $thread = Thread->create(&write_bao1_file);
	    # on laisse le thread se terminer tout seul
	    $thread->detach();
	    
	    # pour chaque clé du dictionnaire (pour chaque item unique)
	    # keys renvoie un array des clés du dictionnaire
	    my $compteur = 1;
	    foreach my $key(sort { $items->{$a} <=> $items->{$b} or $a cmp $b } keys %$items){
	        
	        # on récupère le titre et la description avec split avec comme séparateur || qui renvoie un tableau des éléments splittés
	        # $t_d[0] = titre
	        # $t_d[1] = description
	        # $t_d[2] = nom du fichier associé
	        my @t_d = split(/\|\|/, $key);
	        
	        # on écrit les données dans le fichier xml de sortie avec le nom du fichier associé pour chaque item
	        print $output_xml "<item numero=\"$compteur\" date=\"$items->{$key}\" file=\"$t_d[2]\">\n<titre>$t_d[0]</titre>\n";
	        print $output_xml "<description>$t_d[1]</description>\n</item>\n";
	        
	        # on écrit les données dans le fichier txt de sortie
	        print $output_txt "titre : $t_d[0]\n";
	        print $output_txt "description : $t_d[1]\n";
	        
	        $compteur++;
	    }
	        
	    # fin du fichier xml
	    print $output_xml "</items>\n";
	    
	    # on ferme le fichier xml de sortie de la BAO1
	    close $output_xml;
	    # on ferme le fichier txt de sortie de la BAO1
		close $output_txt;
	    
	}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

	# fonction qui récupère la date de publication à partir du chemin du fichier
	sub format_date{
		
		my $file = shift;
		$file =~ m/(\d+)\/(\d+)\/(\d+)\//;
		return $1.$2.$3;
	}

#-----------------------------------------------------------------------------------------------------------------------------------------------------	

	# etiquete le fichier txt de sortie de la BAO1 avec UDPipe et Tree-Tagger
	sub etiquetage {
		
		# on récupère le modèle à utiliser par udpipe
		my $modele = shift @_;
		# on récupère le fichier de sortie BAO2 udpipe
		my $file_output_udpipe = shift @_;
		# on récupère le fichier de sortie BAO2 treetagger
		my $file_output_treetagger = shift @_;
		
		# ********** etiquetage avec treetagger **************
		# on tokenise le fichier txt de la BAO1 en utilisant le modele francais de tokenisation
		#system("perl tokenise-utf8.pl $categories->{$code}.txt | tree-tagger-linux-3.2/bin/tree-tagger tree-tagger-linux-3.2/french-utf8.par -lemma -token -sgml > $file_output_treetagger");
		# on crée un fichier XML de sortie encodé en utf-8 à partir du fichier txt de sortie de tree-tagger
		#system("perl treetagger2xml-utf8.pl $file_output_treetagger utf-8");
		# ********** etiquetage avec treetagger **************
		
		# fichier xml de sortie temporaire
		open my $tagger_xml, ">:encoding(utf-8)", "temporaire.xml" or die "$!\n";
		
		# écriture de l'en-tête du fichier xml
		print $tagger_xml "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
		# écriture de la balise racine du document XML
		print $tagger_xml "<items>\n";
		
		# compteur d'items
		my $compteur = 1;
		# pour chaque item
		foreach my $key(sort { $items->{$a} <=> $items->{$b} or $a cmp $b } keys %$items){
			
			# on récupère le titre et la description
			my @t_d = split(m/\|\|/, $key);
			# on preetiquete le titre et la description (tokenisation)
			my $titre_etiquete = &preetiquetage($t_d[0]);
			my $description_etiquete = &preetiquetage($t_d[1]);

			# on écrit chaque item dans le fichier xml temporaire en y incluant des métadonnées (numero de l'item et date de publication)
			print $tagger_xml "<item numero=\"$compteur\" date=\"$items->{$key}\" fichier=\"$t_d[2]\"><titre>\n$titre_etiquete\n</titre><description>\n$description_etiquete\n</description></item>\n";
			# on incrémente le compteur
			$compteur++;
			
		}
		
		# on ecrit la balise racine fermante du fichier xml
		print $tagger_xml "</items>\n";
		
		close $tagger_xml;
		
		# on effectue l'etiquetage tree-tagger sur le fichier xml temporaire
		system("tree-tagger-linux-3.2/bin/tree-tagger tree-tagger-linux-3.2/french-utf8.par -lemma -token -sgml temporaire.xml > $file_output_treetagger");
		
		# on met les données obtenues en forme avec tree-tagger sous le format xml et en utf-8
		system("perl treetagger2xml-utf8.pl $file_output_treetagger utf-8");
		
		# on supprime tous les fichiers temporaires
		remove "temporaire.*";
		remove $file_output_treetagger;
		
		# on charge le modele udpipe souhaité en mémoire
		my $model = Ufal::UDPipe::Model::load($modele);
		# si le modele ne s'est pas correctement chargé en memoire, on met fin au script
		$model or die "Impossible de charger le modele : '$modele'\n";
	 
		# on instancie un nouveau tokenizer à partir du modele chargé en mémoire
		my $tokenizer = $model->newTokenizer($Ufal::UDPipe::Model::TOKENIZER_PRESEGMENTED);
		# on définit le format de données souhaité en sortie (ici CONLL-U)
		my $conllu_output = Ufal::UDPipe::OutputFormat::newOutputFormat("conllu");
		my $sentence = Ufal::UDPipe::Sentence->new();

		# on ouvre le fichier txt de la BAO1 en lecture
		open my $input, "<:encoding(utf-8)", "$categories->{$code}.txt" or die "$!";
		# on ouvre le fichier de sortie UDPipe en ecriture
		open my $output, ">:encoding(utf-8)", $file_output_udpipe or die "$!";
	 
		# on feed le tokenizer avec l'ensemble du contenu du fichier txt de sortie de la BAO1
		$tokenizer->setText(join('', <$input>));
		
		# on va tagger et parser chaque phrase
		while ($tokenizer->nextSentence($sentence)) {
			
			$model->tag($sentence, $Ufal::UDPipe::Model::DEFAULT);
			$model->parse($sentence, $Ufal::UDPipe::Model::DEFAULT);
	 
			my $conll = $conllu_output->writeSentence($sentence);
			# on écrit le résultat du traitement udpipe dans le fichier de sortie BAO2 pour chaque phrase
			print $output "$conll";

		}
		
		# on ferme les fichiers d'entrée sortie
		close $input;
		close $output;
	}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

	# fonction qui preetiquete une string en la tokenisant
	# retourne la string tokenisée
	sub preetiquetage{
		
		# on récupère la string à preetiqueter
		my $string = shift @_;
		
		# on écrit la string dans un fichier txt temporaire
		open my $output, ">:encoding(utf-8)", "temporaire.txt";
		print $output $string;
		close $output;
		
		# on tokenise le contenu de ce fichier txt temporaire dans un fichier nommé temporaire.pos
		system("perl -f tokenise-utf8.pl temporaire.txt > temporaire.pos");
		
		# on lit en slurp mode le ficher .pos qui est la string tokenisée
		open my $input, "<:encoding(utf-8)", "temporaire.pos";
		undef $/;
		my $tokenised_string = <$input>;
		close $input;
		
		# on retourne la string tokenisée
		return $tokenised_string;
	}
		
#-----------------------------------------------------------------------------------------------------------------------------------------------------

	# fonction qui va extraire les pos + mots à partir du fichier UDPipe en prenant en compte les mots séquencés en
	# deux tokens comme le DET "des" qui est séquencé en deux tokens ("de" et "les")
	# pour cela, elle récupère le pos et son tag en 2 temps, le pos et le mot étant sur deux lignes différentes
	sub extract_patrons_udpipe{

		# on récupère le fichier udpipe
		my $udfile_input = shift @_;
		# on récupère le nom du fichier d'extraction des patrons
		my $udfile_output = shift @_;
		# on récupère le motif d'extraction sous la forme d'une référence à un array
		my $patron = shift @_;
		# on crée la regex pour ce motif d'extraction
		my $patron_regexp = &create_pattern($patron, 1);
		# le pattern pour extraire le mot et son POS dans le fichier de sortie udpipe
		my $pattern = qr(^\d+\t([^\t]+)\t[^\t]+\t([^\t]+)\t);
		# pos_word = la chaine qui va contenir tous nos tokens + POS concaténés par phrase organisés selon une structure précise
		my $pos_words = undef;
		# on rétablit le séparateur d'enregistrement à '\n' pour enlever le slurp mode
		open my $patron_file, '>:encoding(utf-8)', $udfile_output or die "$!\n";
		open my $udfile, "<:encoding(utf-8)", $udfile_input or die "$!\n";

		# numéro de la ligne dans laquelle se trouve le pos
		my $target_line_number = -1;
		# numéro de la ligne courante dans la phrase
		my $current_line_number = 1;
		local $/ = "\n";
		# pour chaque ligne du fichier udpipe
		while (my $line = <$udfile>){

			# on enlève le saut de ligne final
			chomp $line;
			# on enlève les sauts de ligne et les retours charriot en fin de ligne
			$line =~ s/\r\n?//;

			# on récupère le numéro courant de la ligne dans la phrase
			$line =~ /^(\d+)/;
			$current_line_number = $1;

			# si la phrase commence par # ou qu'il s'agit d'une ligne entre la ligne du pos mal séquencé et la target_line_number, on passe à la phrase suivante
			next if $line =~ /^#/ or $current_line_number == $target_line_number - 1;

			# si la ligne n'est pas une ligne vide ou n'est pas faite uniquement que de caractères non imprimables
			if ($line !~ /^\R*$/){

				# si la ligne commence par une séquence du genre 3-4 ou 1-2, on va extraire la forme du mot et l'ajouter à pos_words
				if ($line =~ /^\d+\-\d+/){
					# on établit le numéro de la ligne à atteindre pour avoir le pos du mot (c'est n+1)
					$target_line_number = $current_line_number + 1;
					# on récupère la forme du mot qu'on ajoute à $pos_words
					$line =~ /^\d+\-\d+\t([^\t]+)/;
					$pos_words .= "$1ͱ";
				}
				# si la ligne courante est la target line, on va récupérer le POS du mot et l'ajouter à pos_words
				elsif ($current_line_number == $target_line_number){

					# on récupère le pos du mot dans le fichier udpipe à la target_line_number
					$line =~ /^\d+\t[^\t]+\t[^\t]+\t([^\t]+)\t/;
					# on ajoute à pos_words le motif formeͱpos séparé par le caractère ←
					$pos_words .= "$1←";
					# on reset la target_line_number à 0
					$target_line_number = 0;

				}
				# on récupère la forme du mot et son POS si il s'agit d'une ligne normale
				else{

				$line =~ /$pattern/;
				# on les ordonne de cette façon dans pos_words; formeͱPOS←, qu'on ajoute à la chaine pos_words
				$pos_words .= "$1ͱ$2←";
				# exemple de pos_word = leͱDET←presidentͱ$NOUN←aͱAUX←decideͱVERB← etc...
				}
				
			} 
			# si on est arrivé à la fin de notre phrase (ligne vide dans udpipe comme séparateur), il est temps de faire l'extraction des patrons
			else{

				# pos_words acquière automatiquement la valeur undef, seule valeur de retour de write_patrons pour réinitialiser 
				# cette variable pour la phrase suivante car nouveau motif				
				$pos_words = &write_patron(\$patron_file, $pos_words, $patron_regexp, $patron);	
			}	
		}

		# on ferme le fichier patron_file et le fichier UDPipe
		close $patron_file;
		close $udfile;

		# on stoppe le timer
	    $t->stop;
	    # temps écoulé depuis le lancement du programme
	    print "time so far: ", $t->elapsed, " seconds\n";
	}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

	# fonction qui va extraire les pos + mots à partir du fichier XML treetagger
	sub extract_patrons_treetagger{

		my $treetagger_input = shift @_;
		# on récupère le nom du fichier d'extraction des patrons
		my $treetagger_output = shift @_;
		# on récupère le motif d'extraction sous la forme d'une référence à un array
		my $patron = shift @_;
		# on crée la regex pour ce motif d'extraction
		my $patron_regexp = &create_pattern($patron, undef);
		# pattern d'extraction du pos et du mot dans le fichier treetagger
		my $pattern = qr(<data type="type">([A-Z]+)(?:\:{1}\w+)?</data><data type="lemma">.+</data><data type="string">(.+)</data>);
		# pos_word = la chaine qui va contenir tous nos tokens + POS concaténés par phrase organisés selon une structure precise
		my $pos_words = undef;
		# on rétablit le séparateur d'enregistrement à '\n' pour enlever le slurp mode
		open my $patron_file, '>:encoding(utf-8)', $treetagger_output or die "$!\n";
		open my $treetagger_file, "<:encoding(utf-8)", $treetagger_input or die "$!\n";
		# pour chaque ligne du fichier udpipe
		local $/ = "\n";
		while (my $line = <$treetagger_file>){

			# on enlève le saut de ligne final
			chomp $line;

			# si la ligne contient la balise </titre> ou </description>, il faut réaliser l'extraction du patron
			if ($line =~ /<\/titre>|<\/description>/){
				
			# pos_words acquière automatiquement la valeur undef, seule valeur de retour de write_patrons pour réinitialiser 
			# cette variable pour la phrase suivante car nouveau motif
			$pos_words = &write_patron(\$patron_file, $pos_words, $patron_regexp, $patron);
			}

			# si la ligne ne commence pas par la balise <élément>, on passe à la ligne suivante
			next unless $line =~ /^<element>/;

			# si la ligne matche avec notre pos_pattern, on ajoute le pos du mot et le mot à pos_words
			$line =~ /$pattern/;
			$pos_words .= "$1ͱ$2←";
		}

		# on ferme le fichier patron_file et le fichier UDPipe
		close $patron_file;
		close $treetagger_file;

		# on stoppe le timer
	    $t->stop;
	    # temps écoulé depuis le lancement du programme
	    print "time so far: ", $t->elapsed, " seconds\n";	
	}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

	# fonction qui crée un pattern de recherche à partir du modèle de POS entré
	sub create_pattern{

		my $pattern = undef;
		my $liste_patrons = shift(@_);
		# choix de la source d'extraction : undef pour treetagger, n'importe quelle valeur pour udpipe
		my $pattern_udpipe  = shift(@_);

		# si pattern_udpipe est defini, on crée le pattern pour la structure udpipe
		if (defined($pattern_udpipe)){
			# on établit la liste des POS autorisés dans UDPipe
			my @liste_autorisee_udpipe = qw(NOUN PUNCT VERB ADJ ADV ADP PROPN DET SCONJ NUM PRON AUX CCONJ);
			# si un des POS n'existe pas dans UDPpipe, on met fin au script sinon on crée la regex de recherche de patrons
			foreach my $pos (@$liste_patrons){
				die "Un des motifs de recherche n'existe pas !\n" unless ($pos ~~ @liste_autorisee_udpipe);
				# on n'interpolate pas la string (simple quote) pour éviter les soucis des caractères spéciaux ensuite à déspécialiser
				# j'ai mis l’Unicode point de l’apostrophe "française" car ça ne marchait pas sinon (U+2019)
				$pattern .= '(\w+\-?\w*(?:\x{2019}{1})?)ͱ'.$pos."←";
			}
		}
		else{

			# liste autorisée des POS pour treetagger()
			my @liste_autorisee_treetagger = qw(NOM ADJ PRP PUN NAM SENT ADV KON DET VER PRO NUM);
			foreach my $pos (@$liste_patrons){
				# si un des POS n'existe pas dans treetagger, on met fin au script sinon on crée la regex de recherche de patrons
				die "Un des motifs de recherche n'existe pas !\n" unless ($pos ~~ @liste_autorisee_treetagger);
				$pattern .= $pos.'ͱ(\w+\-?\w*(?:\x{2019}{1})?)'."←";
			}
		}

		return $pattern;
	}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

	sub write_patron{
		
		# on récupère le filehandle du fichier d'extraction des patrons pour éviter les appels de fonction en écriture récurrents
		my $file_handle_ref = shift @_;
		my $pos_words = shift @_;
		# on récupère le motif d'extraction des patrons
		my $pattern = shift @_;
		# on récupère la référence au tableau qui regroupe les différentes POS à trouver
		my $patron = shift @_;
		my @capture = ($pos_words =~ /$pattern/g);
		# on skip si @capture est vide (pas de patron correspondant)
		if (@capture == 0){
			# on quitte la subroutine et on renvoie undef pour la phrase suivante
			return undef;
		}
		# on instancie un iterateur qui va itérer par dessus x éléments en gardant les valeurs skippées des éléments dans une liste.
		# ici on calcule le x en comptant le nombre d’éléments de POS constituant le motif avec scalar.
		# c'est le rôle de la fonction natatime de List::MoreUtils
		my $it = natatime scalar(@$patron), @capture;
		while (my @vals = $it->()){
			# on écrit dans le fichier de sortie l'ensemble de la séquence qui correspond au patron recherché
			print { $$file_handle_ref } "@vals\n";
		}
		# on quitte la subroutine et on renvoie undef pour la phrase suivante
		return undef;
	}

}
else{
	print "Option inconnue ! veuillez utiliser -h ou -help.\n";
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

sub exit_bad_usage{

   	my $prog = basename($0);
   	warn(@_) if @_;
   	die "Utilisez $prog -help ou -h pour acceder a l'aide\n";
   	exit(1);
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

# fonction qui constitue un sac de mots comme dictionnaire avec en valeur l'occurrence de chaque mot
# le sac de mots est trié, on enlève les stop words, les mots de moins de 2 lettres (n'apportent rien sémantiquement)
# on récupère les forme lemmatisées des tokens et on compte les occurrences pour chaque token
# les occurrences de chaque token serviront de features pour la recherche de similarité cosinus
sub get_bag_of_words{

	my %lemmes = undef;
	# par rapport au preprocessing de Spacy (récupération des lemmes + retrait des stop words), on ne garde pas les mots qui contiennent des chiffres,
	# des signes de ponctuation ou qui sont tout simplement vides
	foreach my $lemma(grep {$_ !~ /\d+|\W+|^$/} get_lemmas_from_file(file_lemmatizer(shift))){
		# on compte l'occurrence de chaque token sous sa forme minuscule
		$lemmes{lc $lemma}++;
	}
	# on renvoie une référence du sac de mots standardisés
	return \%lemmes;
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

# fonction qui récupère le contenu d'un fichier et le séquence en mots
# ici on est au bord de l'obsfuscation mais il faut la fonction la plus rapide possible car elle est appelée très souvent
sub get_lemmas_from_file{

	# on ouvre le fichier d'input en lecteur avec l'argument de la subroutine
	open my $fh, "<:encoding(utf-8)", $_[0]  or die "$!\n";
	undef $/;
	# on lit le fichier en slurp mode, on le découpe en mots, on ferme le filehandle et on supprime le fichier d'input
	return split(/\W+/, join(" ",<$fh>)), close $fh, remove shift;
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------
# fonction get_bag_of_word pour les fichiers xml rss
sub get_bag_of_words_xml{

	my $filename = shift @_;
	# le hash sac de mots 
	my %lemmes = ();
	# on ouvre en lecture le fichier xml rss
	open my $input, "<:encoding(utf-8)","$filename" or die "$!\n";
	undef $/;
	# contenu entier du fichier xml contenant tous les titres et descriptions.
	my $file_content = undef;
	my $ligne=<$input>; # on lit intégralement (slurp mode)
	# dans le perl cookbook, ils recommandent les modificateurs msx en general pour les regexp
	while ($ligne=~/<item><title>(.+?)<\/title>.*?<description>(.+?)<\/description>/msgsx) {
	    # l'option s dans la recherche permet de tenir compte des \n
	    my $titre=&nettoyage($1);
	    my $description=&nettoyage($2);
	    $file_content .= " ".$titre." ".$description;
	}

	close $input;
	foreach my $lemma(grep {$_ !~ /\d+|\W+|^$/} split(/\W+/, join(" ", content_lemmatizer($file_content)))){
		# on compte l'occurrence de chaque token sous sa forme minuscule
		$lemmes{lc $lemma}++;
	}
	# on renvoie une référence du sac de mots standardisés
	return \%lemmes;
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

# fonction qui permet de feeder en data notre Data::CosineSimilarity pour rechercher ensuite les similarités entre les rubriques
# des années précédentes et un fichier xml rss à partir de la similarité cosinus
# cette fonction utilise des sacs de mots triés selon l'occurrence des mots et place le dictionnaire de la catégorie dans l'objet Data::CosineSimilarity
# avec pour label le nom de catégorie
# on elimine les 2 ou 3 catégories les plus proches dans CS pour obtenir un taux de réussite maximale
sub train_cosine_similarity{
	    
	# chemin du dossier dans lequel se trouve les fichiers d'entrainement (pas de récursivité)
	my $folder = shift @_;
	my $category = shift @_;
	$folder =~ s/\/$//;
	opendir my $dir, $folder;
	my @files = readdir $dir;
	closedir $dir;
	# pour chaque fichier d'entrainement (un fichier d'entrainement = les datas concaténées pour une seule catégorie)
	foreach my $file(@files){
		my $path_file = $folder."/".$file;
		if ($file =~ /\.txt/){
			# on supprime l'extension finale du fichier pour avoir la catégorie
			$file =~ s/\.txt//g;
			print("$file\n");
			# on constitue le sac de mots pour les datas du Data::CosineSimilarity
			my $bag_of_words = &get_bag_of_words($path_file);
			print(blessed($bag_of_words));
			# si la catégorie recherchée n'est ni idées, ni société, on ne prend pas en compte ces catégories dans le Data::CosineSimilarity
			if ($category ne "idees" and $category ne "societe"){
				# si la catégorie est planète ou technologies, on ne prend pas en compte économie, une,société et idées dans le Data::CosineSimilarity
				if ($category eq "planete" or $category eq "technologies"){
					if ($file !~ /economie|une|societe|idees/){
						$cosinus_similarity->add($file => $bag_of_words);
					}
				}
				# pour une, on ne prend pas en compte les rubriques économie et international du Data::CosineSimilarity
				elsif ($category eq "une"){
					if ($file !~ /economie|international/){
						$cosinus_similarity->add($file => $bag_of_words);
					}
				}
				# pour europe, on ne prend pas en compte la rubrique international dans le Data::CosineSimilarity
				elsif ($category eq "europe"){
					if ($file !~ /international/){
						$cosinus_similarity->add($file => $bag_of_words);
					}
				}
				# pour le reste des categories, on ajoute toutes les rubriques sauf idées et société dans le Data::CosineSimilarity
				else {
					if ($file !~ /idees|societe/){
	    			$cosinus_similarity->add($file => $bag_of_words);
	    			}
	    		}
	    	}
	    	else{
	    		# si la categorie recherchée est societe, on ne prend pas en compte economie et une dans le du Data::CosineSimilarity
	    		if ($category eq "societe"){
	    			if ($file !~ /economie|une/){
	    				$cosinus_similarity->add($file => $bag_of_words);
					}
	    		}
	    		# pour la categorie idees, on feed en data Data::CosineSimilarity avec toutes les categories
	    		else{
	    			$cosinus_similarity->add($file => $bag_of_words);
	    		}
	    	}			
	    }
	}
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

# fonction qui charge une liste de stopwords à partir d'un fichier (un stopword par ligne)
sub load_stopwords{

	# chemin du fichier des stopwords
	my $stopwords_file = shift;
	open my $input, '<:encoding(UTF-8)', $stopwords_file or die "$!\n";
	my @stopwords_array = ();
	# on recupere les stopwords dans un array
	@stopwords_array = <$input>;
	close $input;
	# on renvoie l'array des stopwords
	return @stopwords_array;

}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

sub nettoyage {
	# quand on lance une procédure
	# perl range les arguments de la procédure dans une liste spéciale
	# qui s'appelle @_
	my $texte=shift @_;
	$texte=~s/<!\[CDATA\[//g;
	$texte=~s/\]\]>//g;
	$texte =~s/&nbsp/ /g;
	$texte=~s/&/et/g;
	# ajout du point en fin de chaîne
	$texte=~s/$/\./g;
	$texte=~s/\.+$/\./g;
	return $texte;
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------

# un petit Just an Another Perl Hacker comme signature
@P=split//,".URRUU\c8R";@d=split//,"\n erutangiS margorP yzzO na tsuJ";sub p{
@p{"r$p","u$p"}=(P,P);pipe"r$p","u$p";++$p;($q*=2)+=$f=!fork;map{$P=$P[$f^ord
($p{$_})&6];$p{$_}=/ ^$P/ix?$P:close$_}keys%p}p;p;p;p;p;map{$p{$_}=~/^[P.]/&&
close$_}%p;wait until$?;map{/^r/&&<$_>}%p;$_=$d[$q];sleep rand(2)if/\S/;print
