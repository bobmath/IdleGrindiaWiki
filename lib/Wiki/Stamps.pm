package Wiki::Stamps;
use utf8;
use strict;
use warnings;

sub build {
   my ($ctx) = @_;
   open my $OUT, '>:utf8', 'wiki/Stamps' or die;
   print $OUT qq[{| class="wikitable"\n],
      "|-\n! Name || Cost || Effect\n";
   my $data = $ctx->get_objects('DailyRewardData');

   for my $i (0 .. $#{$data->{title}}) {
      if ($i % 5 == 0) {
         my $tier = $i / 5;
         my $txt = "Tier " . ($tier + 1);
         if (my $req = $data->{required}[$tier]) {
            $txt .= " (requires $req stamps)";
         }
         print $OUT "|-\n| colspan=3 | $txt\n";
      }
      my @cost;
      if (my $hunt = $data->{hunter}[$i]) {
         push @cost, "{{Hunter|$hunt}}";
      }
      if (my $expl = $data->{explorer}[$i]) {
         push @cost, "{{Explorer|$expl}}";
      }
      print $OUT "|-\n| ", Grindia::trim($data->{title}[$i]), "\n",
         "| @cost\n| ", Grindia::trim($data->{text}[$i]), "\n";
   }

   print $OUT qq[|}\n];
   close $OUT;
}

1 # end Enemies.pm
