package Wiki::Artifacts;
use utf8;
use strict;
use warnings;

sub build {
   my ($ctx) = @_;
   open my $OUT, '>:utf8', 'wiki/Artifacts' or die;
   $ctx->for_type('ArtifactManager', sub {
      my ($obj) = @_;

      my $pieces = $obj->{pieces};
      print $OUT qq[{| class="wikitable"\n],
         "|-\n! Stars !! Pieces\n";
      foreach my $i (0 .. $#$pieces) {
         print $OUT "|-\n| $i || $pieces->[$i]\n";
      }
      print $OUT qq[|}\n\n];

      for my $i (0 .. 9) {
         print $OUT "==$obj->{names}[$i]==\n";
         my $stats = $obj->{stats}[$i];
         for my $j (0 .. 5) {
            my $info = $stats->[$j];
            my $desc = $info->{desc};
            $desc =~ s/\s+/ /g;
            $desc =~ s/ $//;
            $desc =~ s/\\n/<br>/g;
            print $OUT "* [[Stars$j.png|$j]] $desc\n",
               Grindia::describe_attack($info, 'enemy');
            ;
         }
         print $OUT "\n";
      }
   });
   close $OUT;
}

1 # end Artifacts.pm
