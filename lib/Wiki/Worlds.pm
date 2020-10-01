package Wiki::Worlds;
use utf8;
use strict;
use warnings;
use POSIX qw( ceil );

# source: EnemySpawner.ApplyMonsterPartDrops and .GetMonsterDrops
my @breakpoints = (10, 50, 100, 200, 350, 600, 900, 1500, 2500, 5000, 10000);
my @jewelmult = (1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047, 4095);
sub find_break {
   my ($lvl) = @_;
   my $lo = 0;
   my $hi = @breakpoints;
   while ($lo < $hi) {
      my $mid = ($lo + $hi) >> 1;
      if ($breakpoints[$mid] <= $lvl) {
         $lo = $mid + 1;
      }
      else {
         $hi = $mid;
      }
   }
   return $lo;
}

sub build {
   my ($ctx) = @_;
   my (%areas, %dungeons);
   $ctx->for_type('AreaData', sub {
      my ($obj) = @_;
      my $name = $obj->{name};
      if ($name =~ /^Zone (\d+)-(\d+)/) {
         $areas{$1}{$2} = $obj;
      }
      elsif ($name =~ /^Area (\d+)/) {
         $areas{1}{$1} = $obj;
      }
      elsif ($name =~ /^W(\d+) (Dungeon|Raid) 00/) {
         $dungeons{$1}{$2} = $obj;
      }
   });

   mkdir 'wiki/Worlds';
   foreach my $world (1 .. 7) {
      my $areas = $areas{$world} or next;
      open my $OUT, '>:utf8', "wiki/Worlds/World_$world" or die;
      my $highest = 0;
      foreach my $num (keys %$areas) {
         $highest = $num if $num > $highest;
      }
      my $step = $highest <= 8 ? 1
         : $highest <= 30 ? 5
         : $highest <= 70 ? 10 : 20;

      my @out;
      for my $num (1 .. $highest) {
         describe_area($num, $areas->{$num}, \@out, $step);
      }
      print $OUT qq[{| class="wikitable"\n],
         "|-\n! Zone || Lvl || Enemies || Jewels || Exp || Coins ",
         "|| Bronze || Silver || Gold\n";
      show_areas($OUT, \@out);

      if (my $dung = $dungeons{$world}) {
         foreach my $type (sort keys %$dung) {
            my $area = $dung->{$type};
            @out = ();
            describe_area(999, $dung->{$type}, \@out, $step);
            show_areas($OUT, \@out, $type);
         }
      }

      print $OUT qq[|}\n\n];
      close $OUT;
   }
}

sub describe_area {
   my ($num, $area, $out, $step) = @_;
   return unless $area;
   my (%prefix, %tiers);
   foreach my $enemy (@{$area->{enemies}}) {
      if ($enemy->{type} % 5) {
         # if not boss
         $enemy->{title} =~ /^(\w+)/ and $prefix{$1}++;
      }
      my $tier = ceil($enemy->{type} / 5);
      $tiers{$tier}++;
   }

   my $min = $area->{level_min};
   my $max = $area->{level_max};
   my $txt = join(',', sort keys %prefix) . ' || ';

   my $levels = $area->{enemy_levels};
   if ($levels && @$levels) {
      $min = $max = $levels->[0];
      foreach my $lvl (@$levels) {
         $min = $lvl if $lvl < $min;
         $max = $lvl if $lvl > $max;
      }
   }

   if (my @tiers = sort { $a <=> $b } keys %tiers) {
      $txt .= 'W';
      if (@tiers > 2 && $tiers[-1] - $tiers[0] == $#tiers) {
         $txt .= "$tiers[0]–$tiers[-1]";
      }
      else {
         $txt .= join(',', @tiers);
      }
   }

   my $lvls = $max - $min + 1;
   my $jewels = 0;
   my $coins = 0;
   my $craft = 0;
   my $break = find_break($min);
   my %breaks;
   for my $lvl ($min .. $max) {
      $break++ if $lvl >= $breakpoints[$break];
      $breaks{$break} = 1;
      $jewels += $jewelmult[$break];
      $coins += $lvl ** 1.8;
      $craft += $lvl * $lvl;
   }
   my $exp = $craft * $area->{exp_reward};
   $coins *= $area->{gold_reward};
   $craft *= $area->{craft_reward};
   my $cmp = join ',', $txt, sort keys %breaks;

   if (($num-1)%$step && @$out && $out->[-1]{cmp} eq $cmp) {
      my $prev = $out->[-1];
      $prev->{zone_hi} = $num;
      $prev->{lvl_lo} = $min if $min < $prev->{lvl_lo};
      $prev->{lvl_hi} = $max if $max > $prev->{lvl_hi};
      $prev->{lvls} += $lvls;
      $prev->{jewels} += $jewels;
      $prev->{coins} += $coins;
      $prev->{exp} += $exp;
      $prev->{craft} += $craft;
   }
   else {
      push @$out, { zone_lo=>$num, zone_hi=>$num,
         lvls=>$lvls, lvl_lo=>$min, lvl_hi=>$max, txt=>$txt, cmp=>$cmp,
         jewels=>$jewels, coins=>$coins, exp=>$exp, craft=>$craft};
   }
}

sub show_areas {
   my ($OUT, $rows, $type) = @_;
   foreach my $row (@$rows) {
      my $zone = $type || $row->{zone_lo};
      $zone .= '–' . $row->{zone_hi} if $row->{zone_hi} > $row->{zone_lo};
      my $lvls = $row->{lvl_lo};
      $lvls .= '–' . $row->{lvl_hi} if $row->{lvl_hi} > $row->{lvl_lo};
      my $n = $row->{lvls};
      print $OUT "|-\n| $zone || $lvls || $row->{txt} ×",
         numfmt($row->{jewels} / $n), " || ",
         numfmt(52 * $row->{exp} / $n), " || ",
         numfmt(80 * $row->{coins} / $n), " || ",
         numfmt(70 * $row->{craft} / $n), " || ",
         numfmt(0.25 * $row->{craft} / $n), " || ",
         numfmt(0.0045 * $row->{craft} / $n), "\n";
   }
}

sub numfmt {
   my ($x) = @_;
   my $s = sprintf '%.4g', $x;
   $s =~ s/(e-?)\+?0*/$1/;
   return $s;
}

1 # end Worlds.pm
