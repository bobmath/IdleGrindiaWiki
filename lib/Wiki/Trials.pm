package Wiki::Trials;
use utf8;
use strict;
use warnings;

sub build {
   my ($ctx) = @_;
   open my $OUT, '>:utf8', 'wiki/Trials' or die;

   my @trials;
   $ctx->for_type('AreaData', sub {
      my ($obj) = @_;
      if ($obj->{name} =~ /Infinite Trial/) {
         push @trials, $obj;
      }
   });

   foreach my $area (@trials) {
      print $OUT $area->{title}, "\n",
         qq[{| class="wikitable"\n];
      my $step = $area->{level_step};
      my $pools = $area->{spawn_pools};
      my $levels = $area->{pool_levels};
      for my $i (0 .. $#$pools) {
         my $lvls = $i ? $levels->[$i-1]+$step : $step;
         $lvls .= $i < $#$pools ? '–' . $levels->[$i] : '+';
         my @enemies = map { $_->{title} } @{$pools->[$i]{enemies}};
         print $OUT "|-\n| $lvls || ", join(', ', @enemies), "\n";
      }
      print $OUT qq[|}\n\n];
   }

   close $OUT;
}

1 # end Trials.png
