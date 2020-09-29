package Wiki::Prestige;
use utf8;
use strict;
use warnings;

sub build {
   my ($ctx) = @_;
   open my $OUT, '>:utf8', 'wiki/Prestige' or die;
   my %pages;
   $ctx->for_type('graphic', sub {
      my ($obj) = @_;
      $pages{$1} = $obj if $obj->{name} =~ /^Page (\d+) /;
   });

   my %total;
   $total{'Daily Mission resets *'} = 1;
   $total{'Max Awakening *'} = 1;
   $total{'Skill Slot *'} = 1;
   my $n = 0;
   foreach my $num (sort { $a <=> $b } keys %pages) {
      my $page = $pages{$num};
      my $root = $page->{ary}[0];
      for my $i (0 .. 4) {
         my $branch = $root->{children}[$i];
         my $twig = $branch->{children}[0]{owner};
         my $leaf = $twig->{ary}[2];
         my $str = $leaf->{str};
         $str =~ s/\s+/ /g;
         $str =~ s/\s$//;
         $str =~ s/(\d+) (\d{3})/$1$2/;
         $str =~ s/^Gold Drop /Coins Drop /;
         my $base = $str;
         if ($base =~ s/\+(\d+)(%?)/*/) {
            my $old = $total{$base};
            my $new = $total{$base} += $1;
            $new = Grindia::numfmt($new);
            $str .= " (total $new$2)" if $old;
         }
         $n++;
         print $OUT "$n $str\n";
      }
   }
   close $OUT;
}

1 # end Prestige.pm
