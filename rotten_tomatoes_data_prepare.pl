#!/usr/bin/perl

sub trim {
  my $string = shift;
  for ($string) {
    s/^\s+//;
    s/\s+$//;
  }
  return $string;
}

sub get_filename {
  my $string = shift;
  for ($string) {
    s/^\s+//;
    s/\s+$//;
    s/ /_/g;
    s/[',;:]//g;
  }
  return lc($string);
}

sub cleanup {
  my $string = shift;
  for ($string) {
    s/^\s+//;
    s/\s+$//;
    s#<[^>]*>##g; #strip HTML tags
    s/[.,;:-]/ /g; #strip punctutation
    s/[']//g;     #normalize contractions
  }
  return lc($string);
}

my $cnt = 0;
my $fresh_cnt = 0;
my $rotten_cnt = 0;

print "Recursively clearing 'FRESH' and 'ROTTEN' subdirectories ..";
system("rm -rf test/FRESH;mkdir test/FRESH");
system("rm -rf test/ROTTEN;mkdir test/ROTTEN");
print ".. Done\n";

while (<STDIN>) 
{
   $line = trim($_);

   my @values = split(/[\t]/, $line);
   $valuesSize = @values;

   if(($valuesSize > 3) && !($values[0] =~ /MovieID/))
   {
       #2 = Title, 5 = Rating, 9=Text-review
       $moviename = get_filename($values[1]);
       $rating = $values[4];
       $text = $values[8];
       $path = "test/$rating/$moviename".".txt";

       print ". $path\n";

       if(($rating =~ /FRESH/) || ($rating =~ /ROTTEN/))
       {
           open (OUTFILE, ">$path") or die "Can't open $path: $!\n";

           print OUTFILE cleanup($text);

           close OUTFILE;
       }

       if($rating =~ /FRESH/) { $fresh_cnt++; }
       elsif($rating =~ /ROTTEN/) { $rotten_cnt++; }

   }

}

$cnt = $fresh_cnt + $rotten_cnt;

print "$cnt reviews processed.\n";
print "$fresh_cnt FRESH reviews.\n";
print "$rotten_cnt ROTTEN reviews.\n";

exit; 
