package Wiki::Dungeons;
use utf8;
use strict;
use warnings;

my @pet_order = ( 'Fox', 'Hare', 'Owl', 'Unicorn', 'Rat', 'Dog',
   'Turtle', 'Dolphin', 'Lizard', 'Cactus', 'Cat', 'Ghost', 'Slime Squared',
   'Slime' );
my @artifacts = qw( Bull Meteor Tree Blessing Rat City Lifeguard Bubble
   Desert Scarab );

sub build {
   my ($ctx) = @_;
   my %dungeons;
   $ctx->for_type('DungeonMetaData', sub {
      my ($obj) = @_;
      if ($obj->{name} =~ /(Dungeon|Raid) (\d+) .*?(\d+)/) {
         $dungeons{$2+0}{$1}{$3+0} = $obj if $2 <= 7 && $3 <= 8;
      }
   });

   mkdir 'wiki/Dungeons';
   my %shards;
   foreach my $world (1 .. 7) {
      my $dung = $dungeons{$world};
      foreach my $type (sort keys %$dung) {
         my $name = $type eq 'Dungeon'
            ? Grindia::dungeon_name($world)
            : Grindia::raid_name($world);
         my $shards = {};
         show_dungeon($dung->{$type}, $name, $shards);
         while (my ($id, $tiers) = each %$shards) {
            $shards{$id}{$world}{$type} = $tiers;
         }
      }
   }
   show_pets(\%shards);
}

sub show_dungeon {
   my ($tiers, $name, $shards) = @_;
   $name =~ s/\s+/_/g;
   open my $OUT, '>:utf8', "wiki/Dungeons/$name" or die;

   my @tiers = sort { $a <=> $b } keys %$tiers;
   if (@tiers > 1 && $tiers[0] == 0) {
      my $first = $tiers[0] = $tiers[1] - 1;
      $tiers->{$first} = delete $tiers->{0};
   }

   my %titles;
   foreach my $tier (@tiers) {
      my $info = $tiers->{$tier};
      $titles{$info->{title}}++;
      $info = $info->{area};
      $titles{$info->{title}}++;
   }
   print $OUT $_, "\n" foreach sort keys %titles;

   print $OUT "==Enemies==\n",
      qq[{| class="wikitable"\n];
   foreach my $tier (@tiers) {
      print $OUT "|-\n| Tier $tier\n";
      my $dung = $tiers->{$tier};
      my $area = $dung->{area};
      my $enemies = $area->{enemies};
      foreach my $i (0 .. $#$enemies) {
         my $enemy = $enemies->[$i] or next;
         my $level = $area->{enemy_levels}[$i] || 0;
         my $curve = $enemy->{curve} or next;
         my $hp = Grindia::numfmt(
            $curve->{base}[0] + $level * $curve->{gain}[0]);
         print $OUT "| $enemy->{title}<br>Level $level<br>HP $hp\n";
      }
   }
   print $OUT qq[|}\n];

   print $OUT "==Pet Shards==\n",
      qq[{| class="wikitable"\n];
   foreach my $tier (@tiers) {
      my $pets = $tiers->{$tier}{shard_drops} or next;
      my @out;
      for my $i (0 .. $#$pets) {
         my $num = $pets->[$i] or next;
         $shards->{$i}{$tier} = $num;
         my $name = $pet_order[$i] || "pet$i";
         push @out, "{{PetShard|$name|$name ×$num}}";
      }
      print $OUT "|-\n| Tier $tier\n| ", join(", ", @out), "\n";
   }
   print $OUT qq[|}\n];

   my @rows;
   foreach my $tier (@tiers) {
      my $artifacts = $tiers->{$tier}{artifact_drops} or next;
      my @out;
      for my $i (0 .. $#$artifacts) {
         my $num = $artifacts->[$i] or next;
         my $name = $artifacts[$i] || "artifact$i";
         push @out, "{{Artifact|$name|$name ×$num}}";
      }
      push @rows, "|-\n| Tier $tier\n| " . join(", ", @out) . "\n"
         if @out;
   }
   print $OUT "==Artifacts==\n",
      qq[{| class="wikitable"\n],
      @rows,
      qq[|}\n] if @rows;

   print $OUT "\n[[Category:Dungeons and Raids]]\n";
   close $OUT;
}

sub show_pets {
   my ($shards) = @_;
   open my $OUT, '>:utf8', 'wiki/Pet_Source' or die;
   foreach my $petid (sort { $a <=> $b } keys %$shards) {
      my $petname = $pet_order[$petid] || "pet$petid";
      my $worlds = $shards->{$petid};
      foreach my $world (sort { $a <=> $b } keys %$worlds) {
         my $types = $worlds->{$world};
         my @out2;
         foreach my $type (sort keys %$types) {
            my $tiers = $types->{$type};
            my @out;
            foreach my $tier (sort { $a <=> $b } keys %$tiers) {
               if (@out && $out[-1][1] == $tier-1) {
                  $out[-1][1] = $tier;
               }
               else {
                  push @out, [$tier, $tier];
               }
            }
            if (@out) {
               push @out2, $type . ' ' . join ',',
                  map { $_->[1] > $_->[0] ? "$_->[0]–$_->[1]" : $_->[0] } @out;
            }
         }
         print $OUT "$petname W$world @out2\n" if @out2;
      }
   }
   close $OUT;
}

1 # end Dungeons.pm
