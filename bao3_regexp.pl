#!/usr/bin/perl
use strict;
#use warnings;
use Timer::Simple; # pour le timer
use Ufal::UDPipe; # pour l'etiquetage UDPipe
use File::Remove qw(remove);
use List::MoreUtils qw(natatime);
use Getopt::Long qw(GetOptions);
use File::Basename qw(basename);

no warnings 'experimental::smartmatch';

# on ne travaille qu'en utf-8
use open qw/ :std :encoding(UTF-8)/;

# on instancie un timer commencant à 0.0s par défaut
my $t = Timer::Simple->new();
# on lance le timer
$t->start;

# on construit notre outil de gestion des options
my (@opt_p, @opt_s, $help);

Getopt::Long::Configure("ignore_case", "prefix_pattern=(--|-)");

# si une erreur se produit au moment de la recuperation des options et des arguments, on met fin au script
GetOptions("p|patrons=s{3}" => \@opt_p, "s|standard=s{6}" => \@opt_s, "h|help" => \$help) or exit_bad_usage("Nombre d'arguments ou option invalide !\n");

# lancement en version BAO3 uniquement
if (@opt_p){

	extract_patrons($opt_p[0], $opt_p[1], $opt_p[2]);

}

elsif ($help){

my $help = "\nBienvenue dans le module d'aide !\n
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
/dossiermonprogramme/tree-tagger-linux-3.2/french-utf8.par (fichier de langue treetagger à placer ici)";	
	print "$help\n";
	exit;
}

# lancement en version standard (BAO1 + BAO2 + BAO3)
elsif (@opt_s){

	# on recupere le premier argument (repertoire)
	my $folder = $opt_s[0];
	# on recupere le second argument (code de la catégorie)
	my $code = $opt_s[1];
	# on recupere le modele à utiliser par udpipe
	my $udpipe_model = $opt_s[2];
	# on recupere le fichier de sortie de la BAO2 udpipe
	my $udpipe_file = $opt_s[3];
	# on recupere le fichier de sortie de la BAO2 treetagger
	my $treetagger_file = $opt_s[4];
	# on recupere le pattern pour la recuperation des patrons
	my $motifs_patrons = $opt_s[5];

	# liste de tous les fichiers xml rss correspondant à la catégorie (reference anonyme à un array)
	my $xmls = [];

	# reference anonyme sur hash (dictionnaire) ayant pour clé le titre et la description concaténés et en valeur la date de publication
	my $items = {};

	# reference anonyme à un dictionnaire qui associe chaque clé (code de la categorie) à sa valeur (nom de la categorie)
	my $categories = {3208 => "une", 3210 => "international", 3214 => "europe", 3224 => "societe", 3232 => "idees", 3234 => "economie",
	3236 => "actualite_medias", 3242 => "sport", 3244 => "planete", 3246 => "culture", 3260 => "livres", 3476 => "cinema",
	3546 => "voyage", 65186 => "technologies", 8233 => "politique", "env_sciences" => "sciences"};
	# /!\ avec categorie : les 4 premiers chiffres ne fonctionnent pas

	# si le code de la categorie est introuvable dans le dictionnaire, on met fin au script
	die "Code de categorie introuvable !\n" unless exists($categories->{$code});

	# on ouvre les deux fichiers de sortie de la BAO1 en ecriture (txt et xml)
	open my $output_xml, ">:encoding(utf-8)", "$categories->{$code}.xml" or die "$!";
	open my $output_txt, ">:encoding(utf-8)", "$categories->{$code}.txt" or die "$!";
	            
	# écriture de l'en-tete du fichier xml de sortie
	print $output_xml "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
	# ecriture de la balise racine du document XML
	print $output_xml "<items>\n";

	# nom par defaut du fichier de sortie d'extraction des patrons
	my $default_udfile = "patrons.txt";

	# on fait appel à la subroutine parcourir
	&parcourir($folder);

	# on parse les fichiers xml rss
	&parsefiles;

	# on applique l'etiquetage avec udpipe et tree-tagger sur le fichier txt de sortie de la BAO1
	&etiquetage($udpipe_model, $udpipe_file, $treetagger_file);

	# on va extraire les patrons et les ecrire dans un fichier
	&extract_patrons($udpipe_file, $default_udfile, $motifs_patrons);

	# parcours toute l'arborescence de fichiers à partir d'un repertoire
	sub parcourir{
	    
	    # on recupere l'argument de la subroutine
	    my $folder = shift @_;
	    # on supprime le / final si il existe
	    $folder =~ s/\/$//;
	    # on recupere les fichiers et dossier du repertoire
	    opendir my $dir, $folder;
	    # on liste tous les fichiers et dossiers du repertoire
	    my @files = readdir $dir;
	    # on ferme le repertoire
	    closedir $dir;
	    
	    # pour chaque element dans mon repertoire
	    foreach my $file(@files){
	        
	        next if $file =~ /^\.\.?$/;
	        # on constitue le chemin d'acces complet du fichier/dossier
	        my $f = $folder."/".$file;
	        
	        # si c'est un dossier, on fait appel à la récursivité
	        if (-d $f){
	            &parcourir($f);
	        }
	        
	        # si c'est un fichier xml rss, on va appliquer un traitement XML::RSS
	        # on l'ajoute au tableau @$xmls
	        if ($f =~ /$code.*\.xml/){
	            push @$xmls, $f;
	        }
	    }
	}

	# routine qui traite les fichiers xml rss recuperes
	sub parsefiles{
	    
	    # pour chaque fichier xml rss correspondant à la catégorie
	    foreach my $file(@$xmls){
	        
	        # on ouvre en lecture le fichier xml rss
	        open my $input, "<:encoding(utf-8)","$file" or die "$!";
	        undef $/;
	        my $ligne=<$input>; # on lit intégralement (slurp mode)
	        # dans le perl cookbook, ils recommandent les modificateurs msx en general pour les regexp
			while ($ligne=~/<item><title>(.+?)<\/title>.*?<description>(.+?)<\/description>/msgsx) {
	            # l'option s dans la recherche permet de tenir compte des \n
	            my $titre=&nettoyage($1);
	            my $description=&nettoyage($2);
	            my $date = format_date($file);
	            
	            # on ajoute le titre et la description concaténés dans le hash en tant que clé et ayant comme valeur la date de publication
	            # si la clé n'existe pas déja (les clés doivent etre uniques dans un hash donc on verifie au préalable avec un test unless)
	            my $item = $titre."||".$description;
	            $items->{$item} = $date unless exists($items->{$item});

	        }
	        # on ferme le fichier xml rss
	        close $input;
	        
	    }
	    
	    # pour chaque clé du dictionnaire (pour chaque item unique)
	    # keys renvoie un array des clés du dictionnaire
	    my $compteur = 1;
	    foreach my $key(sort { $items->{$a} <=> $items->{$b} or $a cmp $b } keys %$items){
	        
	        # on recupere le titre et la description avec split avec comme séparateur || qui renvoie un tableau des elements splittés
	        # $t_d[0] = titre
	        # $t_d[1] = description
	        my @t_d = split(/\|\|/, $key);
	        
	        # on écrit les données dans le fichier xml de sortie
	        # on recupere la date de publication
	        print $output_xml "<item numero=\"$compteur\" date=\"$items->{$key}\"><titre>$t_d[0]</titre>\n";
	        print $output_xml "<description>$t_d[1]</description>\n</item>\n";
	        # on écrit les données dans le fichier txt de sortie

	        print $output_txt "$t_d[0]\n";
	        print $output_txt "$t_d[1]\n";
	        
	        $compteur++;
	    }
	        
	    # fin du fichier xml
	    print $output_xml "</items>\n";
	    
	    # on ferme le fichier xml de sortie de la BAO1
	    close $output_xml;
	    # on ferme le fichier txt de sortie de la BAO1
		close $output_txt;
	    
	}

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

	sub format_date{
		
		my $file = shift;
		$file =~ m/(\d+)\/(\d+)\/(\d+)\//;
		return $1.$2.$3;
	}
		

	# etiquete le fichier txt de sortie de la BAO1 avec UDPipe et Tree-Tagger
	sub etiquetage {
		
		# on recupere le modele à utiliser par udpipe
		my $modele = shift @_;
		# on recupere le fichier de sortie BAO2 udpipe
		my $file_output_udpipe = shift @_;
		# on recupere le fichier de sortie BAO2 treetagger
		my $file_output_treetagger = shift @_;
		
		# ********** etiquetage avec treetagger **************
		# on tokenise le fichier txt de la BAO1 en utilisant le modele francais de tokenisation
		#system("perl tokenise-utf8.pl $categories->{$code}.txt | tree-tagger-linux-3.2/bin/tree-tagger tree-tagger-linux-3.2/french-utf8.par -lemma -token -sgml > $file_output_treetagger");
		# on crée un fichier XML de sortie encodé en utf-8 à partir du fichier txt de sortie de tree-tagger
		#system("perl treetagger2xml-utf8.pl $file_output_treetagger utf-8");
		# ********** etiquetage avec treetagger **************
		
		# fichier xml de sortie temporaire
		open my $tagger_xml, ">:encoding(utf-8)", "temporaire.xml" or die "$!\n";
		
		# écriture de l'en-tete du fichier xml
		print $tagger_xml "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
		# ecriture de la balise racine du document XML
		print $tagger_xml "<items>\n";
		
		# compteur d'items
		my $compteur = 1;
		# pour chaque item
		foreach my $key(sort { $items->{$a} <=> $items->{$b} or $a cmp $b } keys %$items){
			
			# on recupere le titre et la description
			my @t_d = split(m/\|\|/, $key);
			# on preetiquete le titre et la description (tokenisation)
			my $titre_etiquete = &preetiquetage($t_d[0]);
			my $description_etiquete = &preetiquetage($t_d[1]);

			# on ecrit chaque item dans le fichier xml temporaire en y incluant des métadonnées (numero de l'item et date de publication)
			print $tagger_xml "<item numero=\"$compteur\" date=\"$items->{$key}\"><titre>\n$titre_etiquete\n</titre><description>\n$description_etiquete\n</description></item>\n";
			# on incremente le compteur
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
			# on écrit le resultat du traitement udpipe dans le fichier de sortie BAO2 pour chaque phrase
			print $output "$conll";

		}
		
		# on ferme les fichiers d'entrée sortie
		close $input;
		close $output;
	}

	# fonction qui preetiquete une string en la tokenisant
	# retourne la string tokénisée
	sub preetiquetage{
		
		# on recupere la string à preetiqueter
		my $string = shift @_;
		
		# on ecrit la string dans un fichier txt temporaire
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
		
		# on retourne la string tokénisée
		return $tokenised_string;
	}
		

	sub extract_patrons{

		# on recupere le fichier udpipe
		my $udfile_input = shift @_;
		# on recupere le nom du fichier d'extraction des patrons
		my $udfile_output = shift @_;
		# on recupere le motif d'extraction sous la forme POS-POS...
		my $patron = shift @_;
		# on crée la regexp pour ce motif d'extraction
		my $patrons = create_pattern($patron);
		# on compte le nombre d'occurences de POS dans le motif pour l'iteration au moment de la capture en comptant les '-'
		my $counter = () = $patron =~ /-/g;
		open my $patron_file, '>:encoding(utf-8)', $udfile_output or die "$!\n";
		# le pattern pour extraire le mot et son POS dans le fichier de sortie udpipe
		my $pattern = qr(^\d+\t([^\t]+)\t[^\t]+\t([^\t]+)\t);
		open my $udfile, "<:encoding(utf-8)", $udfile_input or die "$!\n";
		# pos_word = la chaine qui va contenir tous nos tokens + POS concaténés par phrase organisés selon une structure precise
		my $pos_words = undef;
		# on retablit le separateur d'enregistrement à '\n' pour enlever le slurp mode
		local $/ = "\n";
		# pour chaque ligne du fichier udpipe
		while (my $line = <$udfile>){

			# si la phrase commence par # ou 1-2 etc..., on passe à la suivante
			next if $line =~ /^(?:\d+\-\d+|#)/;

			# si la ligne n'est pas une ligne vide
			if ($line !~ /^$/){
				# on recupere la forme du mot et son POS
				$line =~ /$pattern/;
				# on les ordonne de cette facon dans pos_words; POS:forme-, qu'on ajoute à la chaine pos_words
				$pos_words .= "$2:$1-";
				
			} 
			# si on est arrivé à la fin de notre phrase (ligne vide dans udpipe comme seperateur), il est temps de faire l'extraction des patrons
			else{
				# on recupere l'ensemble des elements capturés dans @capture qui repondent au motif d'extraction
				my @capture = ($pos_words =~ /$patrons/g);
				# on skip si @capture est vide (pas de patron correspondant)
				if (@capture == 0){
					# on reset pos_words et on passe à la phrase suivante
					$pos_words = undef;
					next;
				}
				# on instancie un iterateur qui va iterer en fonction du nombre d'elements dans le motif d'extraction du patron pour avoir la sequence complete du motif
				# ici on le calcule en comptant les occurrences de '-' dans le motif d'extraction + 1. si on a 1 separateur, on a deux elements etc...
				# c'est le role de la fonction natatime de List::MoreUtils
				my $it = natatime $counter + 1, @capture;
				while (my @vals = $it->()){
					# on ecrit dans le fichier de sortie l'ensemble de la sequence qui correspond aux patrons recherches
					print $patron_file "@vals\n";
				# on reset pos_words pour la phrase suivante
				$pos_words = undef;
				}
			}	
		}
		# on ferme le fichier patron file
		close $patron_file;

		# on stoppe le timer
	    $t->stop;
	    # temps écoulé depuis le lancement du programme
	    print "time so far: ", $t->elapsed, " seconds\n";
	}

	# fonction qui crée un pattern de recherche à partir de la forme POS-POS etc...
	sub create_pattern{

		my $pattern = undef;
		# on etablit la liste des POS autorisés dans UDPipe
		my @liste_autorisee = qw(NOUN PUNCT VERB ADJ ADV ADP PROPN DET SCONJ NUM PRON AUX CCONJ);
		# on split le motif d'extraction en fonction de '-'
		my @liste_patrons = split(/-/, shift(@_));
		# si il y a plusieurs POS alors scalar(@liste_patrons) > 1
		die "Motif pour l'extraction de patrons incorrect !" unless scalar(@liste_patrons)>1;
		# si un des POS n'existe pas dans UDPpipe, on met fin au script sinon on crée la regexp d'extraction du patron
		foreach my $motif (@liste_patrons){
			die "Un des motifs de recherche n'existe pas !" unless ( $motif ~~ @liste_autorisee);
			$pattern .= $motif.":(\\w+)-";
		}

		return $pattern;
	}
}
else{
	print "Option inconnue ! veuillez utiliser -h ou -help.\n";
}

sub exit_bad_usage {

   my $prog = basename($0);
   warn(@_) if @_;
   die("Utilisez $prog -help ou -h pour acceder à l'aide\n");
   exit(1);

} 



	

