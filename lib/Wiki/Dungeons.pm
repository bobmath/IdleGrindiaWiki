package Wiki::Dungeons;
use utf8;
use strict;
use warnings;

my @pet_order = ( 'Fox', 'Hare', 'Owl', 'Unicorn', 'Rat', 'Dog', 'Turtle',
   'Dolphin', 'Lizard', 'Cactus', 'Cat', 'Ghost', 'Slime Squared', 'Slime' );
my @artifacts = qw( Bull Meteor Tree Blessing Rat City Lifeguard Bubble
   Desert Scarab Undead Holy );
my %short = (
   'Slime Squared' => 'Slime²',
);

my @resources = qw( Coin Bronze Silver Gold );
for my $i (1 .. 8) {
   for my $j (1 .. 3) {
      push @resources, "Jewel|$i|$j";
   }
}

sub build {
   my ($ctx) = @_;
   my %dungeons;
   $ctx->for_type('DungeonMetaData', sub {
      my ($obj) = @_;
      my ($type, $world, $tier) =
         $obj->{name} =~ /(Dungeon|Raid) (\d+) .*?(\d+)/ or return;
      $world += 0;
      $tier = ($tier + 0) || $world;
      return if $world > 7 || $tier > 9;
      my $levels = $obj->{area}{enemy_levels} or return;
      return if $levels->[0] > 1e5;
      $dungeons{$world}{$type}{$tier} = $obj;
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
   show_timers(\%dungeons);
}

sub show_dungeon {
   my ($tiers, $name, $shards) = @_;
   $name =~ s/\s+/_/g;
   open my $OUT, '>:utf8', "wiki/Dungeons/$name" or die;

   my @tiers = sort { $a <=> $b } keys %$tiers;
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
      my $dung = $tiers->{$tier};
      my $area = $dung->{area};
      my $enemies = $area->{enemies};
      my $levels = $area->{enemy_levels};
      print $OUT "|-\n| Tier $tier\n";
      foreach my $i (0 .. $#$enemies) {
         my $enemy = $enemies->[$i] or next;
         my $level = $levels->[$i] || 0;
         my $curve = $enemy->{curve} or next;
         my $hp = Grindia::numfmt(
            $curve->{base}[0] + $level * $curve->{gain}[0]);
         print $OUT "| $enemy->{title}<br>Level $level<br>HP $hp\n";
      }
   }
   print $OUT qq[|}\n\n];

   print $OUT "==Resources==\n",
      qq[{| class="wikitable"\n];
   foreach my $tier (@tiers) {
      my $dung = $tiers->{$tier};
      print $OUT "|-\n| Tier $tier\n";
      my @out;
      for my $i (1 .. 3) {
         my $range = $dung->{"crafting_reward$i"};
         my $lo = Grindia::numfmt($range->[0]);
         my $hi = Grindia::numfmt($range->[1]);
         $lo .= '–' . $hi if $hi ne $lo;
         push @out, "{{$resources[$i]|$lo}}";
      }
      print $OUT "| ", join("<br>", @out), "\n";
      my $rewards = $dung->{resource_rewards};
      @out = ();
      for my $i (0 .. $#$rewards) {
         my $val = $rewards->[$i] or next;
         my $lo = Grindia::numfmt($val * 0.9);
         my $hi = Grindia::numfmt($val * 1.1);
         $lo .= '–' . $hi if $hi ne $lo;
         push @out, "{{$resources[$i]|$lo}}";
      }
      print $OUT "| ", join("<br>", @out), "\n";
   }
   print $OUT qq[|}\n\n];

   print $OUT "==Pet Shards==\n",
      qq[{| class="wikitable"\n];
   foreach my $tier (@tiers) {
      my $pets = $tiers->{$tier}{shard_drops} or next;
      my @out;
      for my $i (0 .. $#$pets) {
         my $num = $pets->[$i] or next;
         $shards->{$i}{$tier} = $num;
         my $name = $pet_order[$i] || "pet$i";
         my $short = $short{$name} || $name;
         push @out, "{{PetShard|$name|$short ×$num}}";
      }
      print $OUT "|-\n| Tier $tier\n| ", join(", ", @out), "\n";
   }
   print $OUT qq[|}\n\n];

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
      qq[|}\n\n] if @rows;

   print $OUT "[[Category:Dungeons and Raids]]\n";
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

sub show_timers {
   my ($dungeons) = @_;
   open my $OUT, '>', 'wiki/Dungeons/Timers' or return;
   print $OUT qq[{| class="wikitable"\n|-\n],
      "! Tier || [[File:Clock.png]] Dungeon || [[File:Clock.png]] Raid \n";
   foreach my $tier (1 .. 9) {
      print $OUT "|-\n| $tier";
      foreach my $type (qw[ Dungeon Raid ]) {
         my $time = $dungeons->{1}{$type}{$tier}{max_time} or die;
         foreach my $world (2 .. 7) {
            my $dung = $dungeons->{$world}{$type}{$tier} or next;
            die "time different W$world T$tier $type"
               unless $dung->{max_time} == $time;
         }
         my $mins = $time / 60;
         my $hrs = int($mins / 60);
         $mins = int($mins - 60*$hrs + 0.5);
         if ($hrs) {
            $time = "$hrs hr";
            $time .= " $mins min" if $mins;
         }
         else {
            $time = "$mins min";
         }
         print $OUT " || $time";
      }
      print $OUT "\n";
   }
   print $OUT qq[|}\n];
   close $OUT;
}

1 # end Dungeons.pm
