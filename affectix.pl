#!/usr/bin/perl

use strict;
use DB_File;

# Affectix
# March, 2011
# Neal Richter nrichter@gmail.com
# A simple affective rating of text tool.
#
# Copyright (C) 2011 by J. Neal Richter
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
# Usage:
#  To Load Wordlists:
#  $find keywords/negative/ -exec ~/bin/affectix.pl add negative '{}' \;
#  $find keywords/postive -exec ~/bin/affectix.pl add postive '{}' \;
#
#  To Test:
#  $perl ~/bin/affectix.pl classify $filename
#  The label with the smallest number wins (ie the first one in the list)
#
#
# Hash with two levels of keys: $words{category}{word} gives count of
# 'word' in 'category'.  Tied to a DB_File to keep it persistent.
#
# The code skeleton and specific marked functions were taken from 
# Naive Bayesian Text Classification by John Graham-Cumming
# http://www.ddj.com/development-tools/184406064
#

my %words;
tie %words, 'DB_File', 'words.db';

#Utils
sub clean {
  my $string = shift;
  for ($string) {
    s/^\s+//;
    s/\s+$//;
    s/=/_/g;
    s/-/_/g;
  }
  return lc($string);
}

sub trim {
  my $string = shift;
  for ($string) {
    s/^\s+//;
    s/\s+$//;
  }
  return $string;
}

# Read a file and return a hash of the word counts in that file
# Adapted from:
# Naive Bayesian Text Classification by John Graham-Cumming
# http://www.ddj.com/development-tools/184406064
sub parse_file_text
{
    my ( $file ) = @_;
    my %word_counts;

    open FILE, "<$file";
    while ( my $line = <FILE> ) {

#       split on whitespace, punctuation, etc
        my @values = split(/[ \t\n\r,;:."'()&]/, $line);   

#       Grab all the words with between 3 and 44 letters
        foreach my $val (@values) {
            my $wrd = lc(clean($val));
            if ((length( $wrd) > 2) && (length( $wrd) < 45) && ($wrd =~ m/[A-Za-z0-9_#]/)) {
               $word_counts{lc($wrd)}++;
            }
           #else { print "Rejected: $wrd \n"; }
        }
    }
    close FILE;
    return %word_counts;
}


# Read a file and return a hash of the word counts in that file
# Adapted from:
# Naive Bayesian Text Classification by John Graham-Cumming
# http://www.ddj.com/development-tools/184406064
sub parse_file_csv
{
    my ( $file ) = @_;
    my %word_counts;


    open FILE, "<$file";
    while ( my $line = <FILE> ) {
#        print "parsing $line\n";

#       split on CSV
        my @values = split(/[,;:]/, $line);   #replace with this for whitespace /[ \t\n\r,;:]/
                                              #Prior pattern  while ( $line =~ s/([[:alpha:#]]{3,44})[ \t\n\r,;:]// ) {

#       Grab all the words with between 3 and 44 letters
        foreach my $val (@values) {
            my $wrd = lc(clean($val));
            if ((length( $wrd) > 2) && (length( $wrd) < 45) && ($wrd =~ m/[A-Za-z0-9_#]/)) {
               $word_counts{lc($wrd)}++;
            }
           #else { print "Rejected: $wrd \n"; }
        }
    }
    close FILE;
    return %word_counts;
}

# Add words from a hash to the word counts for a category
# Taken from:
# Naive Bayesian Text Classification by John Graham-Cumming
# http://www.ddj.com/development-tools/184406064
sub add_words
{
    my ( $category, %words_in_file ) = @_;

    foreach my $word (keys %words_in_file) {
        $words{"$category=$word"} += $words_in_file{$word};
    }
}

# Parse & load the data within the Subjectivity Lexicon from Janyce Wiebe
# http://www.cs.pitt.edu/~wiebe/resources.html
# This data is research/academic use only
sub parse_file_wiebe
{
    my ( $file ) = @_;

    open FILE, "<$file";
    while ( my $line = <FILE> ) {
        $line = trim($line);

        my %values =  split(/[= ]/, $line);

        #debug
        #print "parsing $line\n";
        #foreach my $k (keys %values) {
        #    print "- $k: $values{$k}\n";
        #}
        #print "word=[" . $values{"word1"} . "]\n";
        #print "type=[" . $values{"type"} . "]\n";
        #print "polarity=[" . $values{"priorpolarity"} . "]\n";

        my $word = lc($values{"word1"});
        my $type = $values{"type"};
        my $polarity = $values{"priorpolarity"};
        my $valence = 0;

        if($type =~ /^strong.*/) { $valence = 2; }
        if($type =~ /^weak.*/)   { $valence = 1; }
        if($polarity =~ /^weakneg.*/)   { $valence = 1; $polarity = "negative" }

        if ((length( $word) > 2) && (length( $word) < 45) && ($word =~ m/[A-Za-z0-9_#]/) && 
            ( ($polarity =~ /negative/) || ($polarity =~ /positive/) ) ) {
           $words{"$polarity=$word"} += $valence;
        }
        #else { print "Rejected: $word \n"; }

    }
    close FILE;
    return 1;
}
# Parse & load the data from a dump of WordNet-Affect
# http://www.cse.unt.edu/~rada/affectivetext/
# This data is research/academic use only
sub parse_file_wordnet_affect
{
    my ( $file ) = @_;
    my %word_counts;

    open FILE, "<$file";
    while ( my $line = <FILE> ) {
         $line = trim($line);

        my @values = split(/[ \t\n\r,;:]/, $line);  

        my $junk = shift(@values);  # toss the wordnet reference in first column

        foreach my $val (@values) {
            my $word = lc(clean($val));
            if ((length( $word) > 2) && (length( $word) < 45) && ($word =~ m/[A-Za-z0-9_#]/)) {
               $word_counts{lc($word)}++;
            }
            #else { print "Rejected: $word \n"; }
        }
    }
    close FILE;
    return %word_counts;
}

# Export a CSV of the model
sub model_export
{
    my ($export_file) = @_;
    print "Opening: $export_file\n";
    open(EXPCSV, ">$export_file");

    # Calculate the total number of words in each category, total categories
    # the total number of words overall

    my %categories;
    my %category_uniques;
    my $unique_words;
    my $total = 0;
    my $category;
    my $word;
    my $count;
    foreach my $entry (keys %words) {
        $entry =~ /^(.+)=(.+)$/; #category=word
        $category = $1;
        $word = $2;
        $categories{$1} += $words{$entry};
        $category_uniques{$1}++;
        $total += $words{$entry};
        $unique_words++;
    }

    print EXPCSV "#Total words: $total\n";
    print EXPCSV "#Unique words: $unique_words\n";
    print EXPCSV "#Categories:\n";
    foreach my $entry (keys %categories) {
        print EXPCSV " #- $entry: " . $categories{$entry} . " words, ". $category_uniques{$entry} . " unique words\n";
    }

    print EXPCSV "#WORD\tCATEGORY\tCOUNT\n";
    foreach my $entry (keys %words) {
        $entry =~ /^(.+)=(.+)$/; #category=word
        $category = $1;
        $word = $2;
        $count = $words{$entry};
        print EXPCSV "$word\t$category\t$count\n";
    }

    close(EXPCSV);
}

# Get the classification of a file from word counts
# Adapted from:
# Naive Bayesian Text Classification by John Graham-Cumming
sub classify_bayes
{
    my ( %words_in_file ) = @_;

    # Calculate the total number of words in each category and
    # the total number of words overall

    my %count;
    my $total = 0;
    foreach my $entry (keys %words) {
        $entry =~ /^(.+)=(.+)$/; #category=word
        $count{$1} += $words{$entry};
        #print " $1 [$entry]=$count{$1}\n";
        $total += $words{$entry};
    }

    # Run through words and calculate the probability for each category

    my %score;
    foreach my $word (sort (keys(%words_in_file))) {
        foreach my $category (keys %count) {
            if ( defined( $words{"$category=$word"} ) ) {
                #print "[$word] $category: ".$score{$category}." += log(". $words{"$category=$word"}. * 2.71" / ".$count{$category}." )\n";
                $score{$category} += log( $words{"$category=$word"} * 2.71 / $count{$category} );
            } else {
                #print "[$word] $category: ".$score{$category}." += log( 0.01 / ".$count{$category}." )\n";
                #$score{$category} += log( 0.01 / $count{$category} );
            }
        }
    }
    # Add in the probability that the text is of a specific category

    foreach my $category (keys %count) {
        #print "(pr) $category: ".$score{$category}." += log(". $count{$category}." / ".$total." )\n";
        $score{$category} += log( $count{$category} / $total );
    }

    #print the log likelyhood of the categories in sorted order
    my @score_array;
    my @class_array;

    foreach my $category (sort { $score{$b} <=> $score{$a} } keys %count) {
        print " $category $score{$category}, ";
        $score_array[@score_array] = $score{$category}; 
        $class_array[@class_array] = $category; 
    }
    print "\n";
}


sub classify_voter
{
    my ( %words_in_file ) = @_;

    # Calculate the total number of words in each category and
    # the total number of words overall

    my %count;
    my $total = 0;
    foreach my $entry (keys %words) {
        $entry =~ /^(.+)=(.+)$/; #category=word
        $count{$1} += $words{$entry};
        #print " $1 [$entry]=$count{$1}\n";
        $total += $words{$entry};
    }

    # Run through words and calculate the vote for each category

    my %score;
    foreach my $word (sort (keys(%words_in_file))) {
        foreach my $category (keys %count) {
            if ( defined( $words{"$category=$word"} ) ) {
                #print "[$word] $category: ".$score{$category}." += (". $words{"$category=$word"}. "* 2.71)". "\n";
                $score{$category} += ( $words{"$category=$word"} * 2.71 );
            } else {
                #print "[$word] $category: ".$score{$category}." += log( 0.01 / ".$count{$category}." )\n";
                #$score{$category} += log( 0.01 / $count{$category} );
            }
        }
    }
    # Add in the probability that the text is of a specific category

    foreach my $category (keys %count) {
        #print "(pr) $category: ".$score{$category}." += log(". $count{$category}." / ".$total." )\n";
        #$score{$category} += log( $count{$category} / $total );
    }

    #print the log likelyhood of the categories in sorted order
    my @score_array;
    my @class_array;

    foreach my $category (sort { $score{$b} <=> $score{$a} } keys %count) {
        print " $category $score{$category}, ";
        $score_array[@score_array] = $score{$category}; 
        $class_array[@class_array] = $category; 
    }
    print "\n";
}

# Output statistics of the model
sub model_stats
{
    # Calculate the total number of words in each category, total categories
    # the total number of words overall

    my %categories;
    my %category_uniques;
    my $unique_words;
    my $total = 0;
    foreach my $entry (keys %words) {
        $entry =~ /^(.+)=(.+)$/; #category=word
        $categories{$1} += $words{$entry};
        $category_uniques{$1}++;
        $total += $words{$entry};
        $unique_words++;
    }

    print "Total words: $total\n";
    print "Unique words: $unique_words\n";
    print "Categories:\n";
    foreach my $entry (keys %categories) {
        print " - $entry: " . $categories{$entry} . " words, ". $category_uniques{$entry} . " unique words\n";
    }
}

# Supported commands are 'add' to add words to a category and
# 'classify' to get the classification of a file

if ( ( $ARGV[0] eq 'add-generic' ) && ( $#ARGV == 2 ) ) {
    add_words( $ARGV[1], parse_file_csv( $ARGV[2] ) );
} elsif ( ( $ARGV[0] eq 'add-wordnet-affect' ) && ( $#ARGV == 2 ) ) {
    add_words( $ARGV[1], parse_file_wordnet_affect( $ARGV[2] ) );
} elsif ( ( $ARGV[0] eq 'add-wiebe' ) && ( $#ARGV == 1 ) ) {
    parse_file_wiebe( $ARGV[1] );
} elsif ( ( $ARGV[0] eq 'classify-voter' ) && ( $#ARGV == 1 ) ) {
    classify_voter( parse_file_text( $ARGV[1] ) );
} elsif ( ( $ARGV[0] eq 'classify-bayes' ) && ( $#ARGV == 1 ) ) {
    classify_bayes( parse_file_text( $ARGV[1] ) );
} elsif ( ( $ARGV[0] eq 'stats' ) ) {
    model_stats( );
} elsif ( ( $ARGV[0] eq 'export' ) && ( $#ARGV == 1 ) ) {
    model_export( $ARGV[1] );
} else {
    print <<EOUSAGE;
Usage: add-generic <category> <file> - Adds words from <file> to category <category>
       add-wordnet-affect <category> <file> - Adds words from WordNet dump <file> to category <category>
       add-wiebie <file> - Adds words from Janyce Wiebe's Subjectivity Lexicon
       classify <file>       - Outputs classification of <file>
       stats                 - Prints stats of the model
       export <file>         - Exports model to <file>
EOUSAGE
}

untie %words;



