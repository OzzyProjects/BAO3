#!/usr/bin/perl
use Unicode::String qw(utf8);
<<DOC;
Format d\'entree : un texte �tiquet� et lemmatis� par tree tagger et un format d'encodage
Format de Sortie : le m�me texte au format xml (en utf-8)
DOC


# Usage
$ChaineUsage="Usage : tt2xml.pl <Fichier> <encodage>\n";
if (@ARGV!=2) {
 die $ChaineUsage;
}

&ouvre;
#&entete;
&traitement;
#&fin;
&ferme;

##############################################################################################
# R�cup�ration des arguments et ouverture des tampons
sub ouvre {
    $FichierEntree=$ARGV[0];
    $encodage=$ARGV[1];
    open(Entree,"<:encoding($encodage)",$FichierEntree);
    $FichierSortie=$FichierEntree . ".xml";
    open(Sortie,">:encoding(utf-8)",$FichierSortie);
}

# Ent�te de document XML
sub entete {
    print Sortie "<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"no\"?>\n";
    #print Sortie "<article>\n";
}

# Traitement
sub traitement {
    while ($Ligne = <Entree>) {
	chomp($Ligne);
	next if ($Ligne=~/<?xml/);
	$Ligne=~s/\r//g;
	if (uc($encodage) ne "UTF-8") {utf8($Ligne);}
	if ($Ligne!~/\�\�\:\\�\�\:\\/) {
	# Remplacement des guillemets par <![CDATA["]]> (�vite erreur d'interpr�tation XML)
	    $Ligne=~s/([^\t]*)\t([^\t]*)\t(.*)/<element><data type=\"type\">$2<\/data><data type=\"lemma\">$3<\/data><data type=\"string\">$1<\/data><\/element>/;
	    $Ligne=~s/<unknown>/unknown/g;
	    print Sortie $Ligne,"\n";
	}
    }
}
# Fin de fichier
sub fin {
    #print Sortie "</article>\n";
}

# Fermeture des tampons
sub ferme {
    close(Entree);
    close(Sortie);
}
