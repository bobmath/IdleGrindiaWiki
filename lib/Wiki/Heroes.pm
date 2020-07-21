package Wiki::Heroes;
use utf8;
use strict;
use warnings;

my %levels = (
   'Human'      => [1, 25, 100, 250, 1000],
   'Orc'        => [1, 50, 250, 500, 2500],
   'Dark Elf'   => [1, 75, 500, 1000, 5000],
   'Skeleton'   => [1, 75, 500, 1000, 5000],
   'Light Elf'  => [1, 100, 750, 1500, 7500],
   'Rat Person' => [1, 100, 750, 1500, 7500],
);

sub build {
   my ($ctx) = @_;
   open my $OUT, '>:utf8', 'wiki/Heroes';
   $ctx->for_type('RaceMetaData', sub {
      my ($hero) = @_;
      my $bonus = $hero->{bonus};
      print $OUT "==$hero->{title}==\n",
         $hero->{desc}, "\n",
         $bonus->[0], "\n";
      my $levels = $levels{$hero->{title}} || [];
      for my $i (1 .. $#$bonus) {
         my $txt = $bonus->[$i];
         $txt =~ s/\s+/ /g;
         my $lvl = $levels->[$i-1];
         $txt = "Level $lvl: $txt" if $lvl;
         print $OUT "* $txt\n";
      }
      print $OUT "\n";
   });
   close $OUT;
}

1 # end Heroes.pm
