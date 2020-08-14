package Wiki::Enemies;
use utf8;
use strict;
use warnings;

my %enemy_types = (
   1  => 'Slime',
   2  => 'Goblin',
   3  => 'Wasp',
   4  => 'Wolf',
   5  => 'Brutish Bill',
   6  => 'Satyr',
   7  => 'Dryad',
   8  => 'Elf Archer',
   9  => 'Elf Mage',
   10 => 'TREE DUDE',
   11 => 'Drunk Rat',
   12 => 'Thief',
   13 => 'Assassin',
   14 => 'Enforcer',
   15 => 'Toothy Jimmy',
   16 => 'Crab',
   17 => 'Fish',
   18 => 'Merman',
   19 => 'Mermaid',
   20 => 'Lifeguard Octavia',
   21 => 'Cactus',
   22 => 'Cobra',
   23 => 'Scorpion',
   24 => 'Mummy',
   25 => 'Dungeon Master Sphinx',
   26 => 'Zombie',
   27 => 'Vampire',
   28 => 'Eyeball',
   29 => 'Skeleton Mage',
   30 => 'Sarcophagus Sammy',
   31 => 'Water Slime',
   32 => 'Fire Slime',
   33 => 'Cube Slime',
   34 => 'Tower of Slimes',
   35 => 'Slime King',
   #36 => 'Dragon Egg',
   #37 => 'Mimic',
   #38 => 'Dragon Whelp',
   #39 => 'Dragon Defender',
   #40 => 'The Dragon',
);

my @stats = qw( HP STR INT END WIS SPD CrCh CrDmg CrRes
   DeRes PPen MPen Block Resist Dodge Shield FirStr CrArm DeAcc );
my @stat_disp = qw( HP STR INT END WIS SPD CrCh CrDmg CrRes CrArm
   DeAcc DeRes Dodge FirStr );
my @summ_disp = qw( HP S/I E/W SPD CrCh CrDmg CrRes CrArm DeAcc DeRes FirStr );

sub build {
   my ($ctx) = @_;
   my $enemies = {};
   my $stats = {};
   $ctx->for_type('AreaData', sub {
      my ($area) = @_;
      my $name = $area->{name};
      if ($name =~ /^Zone (\d+)-(\d+)/) {
         world_enemies($enemies, $1, $2, $area);
      }
      elsif ($name =~ /^Area (\d+)/) {
         world_enemies($enemies, 1, $1, $area);
      }
      elsif ($name =~ /^W(\d+) Dungeon T?(\d+)/) {
         dungeon_enemies($enemies, $stats, 'D', $1, $2, $area);
      }
      elsif ($name =~ /^W(\d+) Raid T?(\d+)/) {
         dungeon_enemies($enemies, $stats, 'R', $1, $2, $area);
      }
   });
   merge_world_enemies($enemies);
   write_enemies($enemies);
   write_summary($stats);
}

sub dungeon_enemies {
   my ($enemies, $stats, $loc, $world, $tier, $area) = @_;
   return if $world > 7 || $tier > 8;
   $tier = $world if $tier < 1;
   my $area_enemies = $area->{enemies};
   my $levels = $area->{enemy_levels};
   $stats = $stats->{$tier} ||= {};

   for my $i (0 .. $#$area_enemies) {
      my $enemy = $area_enemies->[$i];
      my $lvl = $levels->[$i];
      my $type = $enemy_types{$enemy->{type}};
      my $rec = $enemies->{$type}{$tier}{"$loc:$world:$enemy"} ||=
         { enemy=>$enemy, loc=>$loc, world=>$world, tier=>$tier,
            lvl_lo=>$lvl, lvl_hi=>$lvl };
      $rec->{lvl_lo} = $lvl if $lvl < $rec->{lvl_lo};
      $rec->{lvl_hi} = $lvl if $lvl > $rec->{lvl_hi};

      my $base = $enemy->{curve}{base};
      my $gain = $enemy->{curve}{gain};
      for my $i (0 .. $#$base) {
         my $val = $base->[$i];
         $val += $gain->[$i] * $lvl unless $i == 5;
         my $name = $stats[$i];
         if    ($name eq 'STR' || $name eq 'INT') { $name = 'S/I' }
         elsif ($name eq 'END' || $name eq 'WIS') { $name = 'E/W' }
         push @{$stats->{$name}}, $val;
      }
   }
}

sub world_enemies {
   my ($enemies, $world, $zone, $area) = @_;
   return if $world > 7;
   my $lo = $area->{level_min};
   my $hi = $area->{level_max};
   foreach my $enemy (@{$area->{enemies}}) {
      my $type = $enemy_types{$enemy->{type}};
      my $rec = $enemies->{$type}{$world}{W}{$enemy}{$zone} ||=
         { enemy=>$enemy, loc=>'W', world=>$world, lvl_lo=>$lo, lvl_hi=>$hi };
      $rec->{lvl_lo} = $lo if $lo < $rec->{lvl_lo};
      $rec->{lvl_hi} = $hi if $hi > $rec->{lvl_hi};
   }
}

sub merge_world_enemies {
   my ($enemies) = @_;
   foreach my $tier (values %$enemies) {
      foreach my $grp (values %$tier) {
         my $types = delete $grp->{W} or next;
         # merge consecutive zones
         foreach my $zones (values %$types) {
            my @zones = sort { $a <=> $b } keys %$zones;
            for (my $i = 0; $i < @zones; $i++) {
               my $zone = $zones[$i];
               my $rec = $zones->{$zone};
               $rec->{zone_lo} = $rec->{zone_hi} = $zone;
               while ($i < $#zones && $zones[$i+1] == $zones[$i]+1) {
                  $i++;
                  my $z2 = $zones[$i];
                  my $r2 = $zones->{$z2};
                  $rec->{lvl_lo} = $r2->{lvl_lo}
                     if $r2->{lvl_lo} < $rec->{lvl_lo};
                  $rec->{lvl_hi} = $r2->{lvl_hi}
                     if $r2->{lvl_hi} > $rec->{lvl_hi};
                  $rec->{zone_hi} = $z2;
               }
               $grp->{"W:$zone:$rec->{enemy}"} = $rec;
            }
         }
      }
   }
}

sub write_enemies {
   my ($enemies) = @_;
   mkdir 'wiki/Enemies';
   foreach my $type (sort keys %$enemies) {
      my $tiers = $enemies->{$type};
      my @tiers = sort { $a <=> $b } keys %$tiers;
      (my $file = $type) =~ s/\s+/_/g;
      open my $OUT, '>:utf8', "wiki/Enemies/$file" or die;
      print $OUT "[[File:$type.png|right]]\n",
         "The '''$type''' is a [[World $tiers[0]]] [[Enemy]] ",
         "in [[Idle Grindia]].{{Clear}}\n\n";
      foreach my $tier (@tiers) {
         print $OUT "==Tier $tier==\n";
         my @records = sort { $a->{lvl_lo} <=> $b->{lvl_lo}
            || $a->{lvl_hi} <=> $b->{lvl_hi} } values %{$tiers->{$tier}};
         foreach my $rec (@records) {
            write_stats($OUT, $rec);
         }
      }
      print $OUT "[[Category:Enemies]]\n";
      close $OUT;
   }
}

sub write_stats {
   my ($OUT, $rec) = @_;
   print $OUT qq[{| class="wikitable" width="100%"\n],
      qq[|-\n| colspan=3 | '''$rec->{enemy}{title}'''\n];

   my $where;
   if ($rec->{loc} eq 'W') {
      $where = "[[World $rec->{world}]] Zone $rec->{zone_lo}";
      $where .= '–' . $rec->{zone_hi}
         if $rec->{zone_hi} > $rec->{zone_lo};
   }
   else {
      my $w = $rec->{world};
      if ($rec->{loc} eq 'D') { $where = Grindia::dungeon_name($w) }
      elsif ($rec->{loc} eq 'R') { $where = Grindia::raid_name($w) }
      else { die $rec->{loc} }
      $where = "[[$where]]";
      $where .= " Tier " . $rec->{tier} if $rec->{tier} > $rec->{world};
   }
   print $OUT "| colspan=2 | $where\n";

   my $lvl = $rec->{lvl_lo};
   $lvl .= '–' . $rec->{lvl_hi} if $rec->{lvl_hi} > $rec->{lvl_lo};
   print $OUT "| colspan=2 | Lvl $lvl\n";

   my %stats;
   my $curve = $rec->{enemy}{curve};
   foreach my $i (0 .. $#stats) {
      my @vals;
      foreach my $lvl ($rec->{lvl_lo}, $rec->{lvl_hi}) {
         my $val = $curve->{base}[$i];
         $val += $curve->{gain}[$i] * $lvl unless $i == 5;
         push @vals, $i <= 5 ? Grindia::numfmt($val+1)
            : sprintf("%g", $val);
      }
      $stats{$stats[$i]} = $vals[0] eq $vals[1] ? $vals[0]
         : "$vals[0]-$vals[1]";
   }

   foreach my $row (0 .. 1) {
      my @row;
      for (my $i = $row; $i < @stat_disp; $i += 2) {
         my $stat = $stat_disp[$i];
         push @row, "$stat $stats{$stat}";
      }
      print $OUT "|-\n| ", join(" || ", @row), "\n";
   }
   print $OUT qq[|}\n];

   foreach my $att (@{$rec->{enemy}{attacks}}) {
      print $OUT Grindia::describe_attack($att, 'hero');
   }
   print $OUT "\n";
}

sub write_summary {
   my ($stats) = @_;
   open my $OUT, '>:utf8', 'wiki/Enemies/Enemies' or return;
   print $OUT "==Typical Stats==\n",
      "Based on [[Dungeons and Raids]].\n",
      qq[{| class="wikitable"\n],
      "|-\n! Tier || ", join(" || ", @summ_disp), "\n";
   for my $tier (sort { $a <=> $b } keys %$stats) {
      print $OUT "|-\n| $tier";
      for my $i (0 .. $#summ_disp) {
         my $name = $summ_disp[$i];
         my $vals = $stats->{$tier}{$name} or next;
         @$vals = sort { $a <=> $b } @$vals;
         my $val = $#$vals & 1
            ? ($vals->[($#$vals+1) >> 1] + $vals->[$#$vals >> 1]) / 2
            : $vals->[$#$vals >> 1];
         if    ($i < 4) { $val = Grindia::numfmt($val) }
         else { $val .= '%' }
         print $OUT " || $val";
      }
      print $OUT "\n";
   }
   print $OUT qq[|}\n];
   close $OUT;
}

1 # end Enemies.pm
