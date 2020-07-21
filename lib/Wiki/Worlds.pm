package Wiki::Worlds;
use utf8;
use strict;
use warnings;
use POSIX qw( ceil );

my @breakpoints = (10, 50, 100, 200, 350, 600, 900, 1500, 2500, 5000, 10000);
my @jewelmult = (1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047, 4096);
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
      my $flags = {};
      $flags->{step} = $highest <= 8 ? 1
         : $highest <= 30 ? 5
         : $highest <= 70 ? 10 : 20;

      foreach my $area (values %$areas) {
         $flags->{exp_flag} = 1 if $area->{exp_reward} != 1;
         $flags->{coin_flag} = 1 if $area->{gold_reward} != 1;
         $flags->{bar_flag} = 1 if $area->{craft_reward} != 1;
      }

      my @out;
      for my $num (1 .. $highest) {
         describe_area($num, $areas->{$num}, \@out, $flags);
      }
      print $OUT qq[{| class="wikitable"\n],
         "|-\n! Zone || Lvl || Enemies || Jewels";
      print $OUT " || Exp" if $flags->{exp_flag};
      print $OUT " || Coins" if $flags->{coin_flag};
      print $OUT " || Bars" if $flags->{bar_flag};
      print $OUT "\n";
      foreach my $row (@out) {
         my $txt = $row->{zone_lo};
         $txt .= '–' . $row->{zone_hi} if $row->{zone_hi} > $row->{zone_lo};
         $txt .= " || $row->{lvl_lo}";
         $txt .= '–' . $row->{lvl_hi} if $row->{lvl_hi} > $row->{lvl_lo};
         $txt .= " || " . $row->{txt};
         print $OUT "|-\n| $txt\n";
      }

      if (my $dung = $dungeons{$world}) {
         foreach my $type (sort keys %$dung) {
            my $area = $dung->{$type};
            my $levels = $area->{enemy_levels};
            my $lo = my $hi = $levels->[0];
            foreach my $lvl (@$levels) {
               $lo = $lvl if $lvl < $lo;
               $hi = $lvl if $lvl > $hi;
            }
            @out = ();
            describe_area(999, $dung->{$type}, \@out, $flags);
            my $row = $out[0];
            print $OUT "|-\n| $type || $lo–$hi || $row->{txt}\n";
         }
      }

      print $OUT qq[|}\n\n];
      close $OUT;
   }
}

sub describe_area {
   my ($num, $area, $out, $flags) = @_;
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

   if (my @tiers = sort { $a <=> $b } keys %tiers) {
      $txt .= 'W';
      if (@tiers > 2 && $tiers[-1] - $tiers[0] == $#tiers) {
         $txt .= "$tiers[0]–$tiers[-1]";
      }
      else {
         $txt .= join(',', @tiers);
      }
      my $lo_break = find_break($min);
      my $hi_break = find_break($max);
      $txt .= " ×" . $jewelmult[$lo_break];
      $txt .= "–" . $jewelmult[$hi_break] if $hi_break > $lo_break;
   }

   $txt .= sprintf(" || %+g%%", ($area->{exp_reward}-1)*100)
      if $flags->{exp_flag};
   $txt .= sprintf(" || %+g%%", ($area->{gold_reward}-1)*100)
      if $flags->{coin_flag};
   $txt .= sprintf(" || %+g%%", ($area->{craft_reward}-1)*100)
      if $flags->{bar_flag};

   if (($num-1)%$flags->{step} && @$out && $out->[-1]{txt} eq $txt) {
      my $prev = $out->[-1];
      $prev->{zone_hi} = $num;
      $prev->{lvl_lo} = $min if $min < $prev->{lvl_lo};
      $prev->{lvl_hi} = $max if $max > $prev->{lvl_hi};
   }
   else {
      push @$out, { zone_lo=>$num, zone_hi=>$num,
         lvl_lo=>$min, lvl_hi=>$max, txt=>$txt };
   }
}

1 # end Worlds.pm
