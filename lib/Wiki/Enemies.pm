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

sub build {
   my ($ctx) = @_;
   my $enemies = {};
   $ctx->for_type('AreaData', sub {
      my ($area) = @_;
      if ($area->{name} =~ /^Zone (\d+)-(\d+)/) {
         world_enemies($enemies, $1, $2, $area);
      }
      elsif ($area->{name} =~ /^Area (\d+)/) {
         world_enemies($enemies, 1, $1, $area);
      }
      elsif ($area->{name} =~ /^W(\d+) Dungeon T?(\d+)/) {
         dungeon_enemies($enemies, 'D', $1, $2, $area);
      }
      elsif ($area->{name} =~ /^W(\d+) Raid T?(\d+)/) {
         dungeon_enemies($enemies, 'R', $1, $2, $area);
      }
   });

   foreach my $grp (values %$enemies) {
      my $types = delete $grp->{W} or next;
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
               $rec->{lvl_lo} = $r2->{lvl_lo} if $r2->{lvl_lo} < $rec->{lvl_lo};
               $rec->{lvl_hi} = $r2->{lvl_hi} if $r2->{lvl_hi} > $rec->{lvl_hi};
               $rec->{zone_hi} = $z2;
            }
            $grp->{"W:$rec->{world}:$zone:$rec->{enemy}"} = $rec;
         }
      }
   }
   write_enemies($enemies);
}

sub dungeon_enemies {
   my ($enemies, $loc, $world, $tier, $area) = @_;
   return if $world > 7 || $tier > 8;
   $tier = $world if $tier < 1;
   my $area_enemies = $area->{enemies};
   my $levels = $area->{enemy_levels};
   for my $i (0 .. $#$area_enemies) {
      my $enemy = $area_enemies->[$i];
      my $lvl = $levels->[$i];
      my $type = $enemy_types{$enemy->{type}};
      my $rec = $enemies->{$type}{"$loc:$world:$tier:$enemy"} ||=
         { enemy=>$enemy, loc=>$loc, world=>$world, tier=>$tier,
            lvl_lo=>$lvl, lvl_hi=>$lvl };
      $rec->{lvl_lo} = $lvl if $lvl < $rec->{lvl_lo};
      $rec->{lvl_hi} = $lvl if $lvl > $rec->{lvl_hi};
   }
}

sub world_enemies {
   my ($enemies, $world, $zone, $area) = @_;
   return if $world > 7;
   my $lo = $area->{level_min};
   my $hi = $area->{level_max};
   foreach my $enemy (@{$area->{enemies}}) {
      my $type = $enemy_types{$enemy->{type}};
      my $rec = $enemies->{$type}{W}{"$world:$enemy"}{$zone} ||=
         { enemy=>$enemy, loc=>'W', world=>$world, lvl_lo=>$lo, lvl_hi=>$hi };
      $rec->{lvl_lo} = $lo if $lo < $rec->{lvl_lo};
      $rec->{lvl_hi} = $hi if $hi > $rec->{lvl_hi};
   }
}

sub write_enemies {
   my ($enemies) = @_;
   mkdir 'wiki/Enemies';
   foreach my $type (sort keys %$enemies) {
      my @records = sort { $a->{lvl_lo} <=> $b->{lvl_lo}
         || $a->{lvl_hi} <=> $b->{lvl_hi} } values %{$enemies->{$type}};
      (my $file = $type) =~ s/\s+/_/g;
      open my $OUT, '>:utf8', "wiki/Enemies/$file" or die;
      print $OUT "[[File:$type.png|right]]\n",
         "The '''$type''' is an [[Enemy]] in [[Idle Grindia]].{{Clear}}\n\n";
      foreach my $rec (@records) {
         print $OUT qq[{| class="wikitable" width="100%"\n],
            qq[|-\n| colspan=3 | '''$rec->{enemy}{title}'''\n];

         my $where;
         if ($rec->{loc} eq 'W') {
            $where = "[[World $rec->{world}]] Zone $rec->{zone_lo}";
            $where .= '–' . $rec->{zone_hi} if $rec->{zone_hi} > $rec->{zone_lo};
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
      print $OUT "[[Category:Enemies]]\n";
      close $OUT;
   }
}

1 # end Enemies.pm
