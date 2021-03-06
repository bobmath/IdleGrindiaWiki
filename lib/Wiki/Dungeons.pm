package Wiki::Dungeons;
use utf8;
use strict;
use warnings;
use List::Util qw( max );
use Wiki::Enemies;

my @pet_order = ( 'Fox', 'Hare', 'Owl', 'Unicorn', 'Rat', 'Dog', 'Turtle',
   'Dolphin', 'Lizard', 'Cactus', 'Cat', 'Ghost', 'Slime Squared', 'Slime' );
my @artifacts = qw( Bull Meteor Tree Blessing Rat City Lifeguard Bubble
   Desert Scarab Undead Holy );
my %short = (
   'Slime Squared' => 'Slime²',
);

my @stats = (
   ['CrCh', 6],
   ['CrDmg', 7],
   ['CrRes', 8],
   ['CrArm', 17],
   ['DeAcc', 18],
   ['DeRes', 9],
   ['Dodge', 14],
   ['FirStr', 16],
);

my @resources = qw( Coin Bronze Silver Gold );
for my $i (1 .. 8) {
   for my $j (1 .. 3) {
      push @resources, "Jewel|$i|$j";
   }
}

my %difficulty = (
   9  => 'Hard Mode',
   10 => 'Extreme',
   11 => 'Savage',
   12 => 'Impossible',
);

sub build {
   my ($ctx) = @_;
   my %dungeons;
   $ctx->for_type('DungeonMetaData', sub {
      my ($obj) = @_;
      my ($type, $world, $tier) =
         $obj->{name} =~ /(Dungeon|Raid) (\d+) .*?(\d+)/ or return;
      $world += 0;
      $tier = ($tier + 0) || $world;
      return if $world > 8;
      my $levels = $obj->{area}{enemy_levels} or return;
      return if $levels->[0] > 1e6;
      $dungeons{$world}{$type}{$tier} = $obj;
   });

   mkdir 'wiki/Dungeons';
   my %shards;
   foreach my $world (1 .. 8) {
      my $dung = $dungeons{$world};
      foreach my $type (sort keys %$dung) {
         show_dungeon($world, $type, $dung->{$type}, \%shards);
      }
   }
   show_pets(\%shards);
   show_timers(\%dungeons);
}

sub show_dungeon {
   my ($world, $what, $tiers, $shards) = @_;
   my $name = $what eq 'Dungeon' ? Grindia::dungeon_name($world)
      : Grindia::raid_name($world);
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

   foreach my $tier (@tiers) {
      my $dung = $tiers->{$tier};
      my $area = $dung->{area};
      my $enemies = $area->{enemies};
      next unless @$enemies;
      my $lbl = "Tier $tier";
      if ($tier == $tiers[0]) {
         $lbl .= ' (Story)';
      }
      elsif (my $diff = $difficulty{$tier}) {
         $lbl .= " ($diff)";
      }
      print $OUT "==$lbl==\n",
         qq[{| class="wikitable"\n],
         "|-\n",
         "! Num || Icon || Enemy || Level || HP || STR || INT || END || WIS",
         " || SPD\n";

      my $levels = $area->{enemy_levels};
      foreach my $i (0 .. $#$enemies) {
         my $enemy = $enemies->[$i] or next;
         my $type = $Wiki::Enemies::enemy_types{$enemy->{type}} or next;
         my $pic = $Wiki::Enemies::enemy_images{$type} || $type;
         my $level = $levels->[$i] || 0;
         print $OUT qq[|- align="center"\n],
            "| " , $i+1, " || [[File:$pic.png|50x30px]]",
            " || [[$type#Tier $tier|$enemy->{title}]]\n",
            "| ", Grindia::numfmt($level);
         my $base = $enemy->{curve}{base};
         my $gain = $enemy->{curve}{gain};
         for my $j (0 .. 4) {
            my $val = $base->[$j] + $gain->[$j] * $level;
            print $OUT " || ", Grindia::numfmt($val+1);
         }
         my $spd = $base->[5] + 1;
         print $OUT " || $spd\n";
      }
      print $OUT qq[|}\n\n];

      my @out;
      my $base = $enemies->[-1]{curve}{base};
      foreach my $stat (@stats) {
         push @out, "$stat->[0] $base->[$stat->[1]]";
      }
      print $OUT "'''Stats''' ", join(', ', @out), "\n\n";

      @out = ();
      for my $i (1 .. 3) {
         my $range = $dung->{"crafting_reward$i"};
         my $lo = Grindia::numfmt($range->[0]);
         my $hi = Grindia::numfmt($range->[1]);
         $lo .= '–' . $hi if $hi ne $lo;
         push @out, "{{$resources[$i]|$lo}}";
      }
      print $OUT "'''Rewards''' @out\n\n" if @out;

      my $rewards = $dung->{resource_rewards};
      @out = ();
      for my $i (0 .. $#$rewards) {
         my $val = $rewards->[$i] or next;
         my $lo = Grindia::numfmt($val * 0.9);
         my $hi = Grindia::numfmt($val * 1.1);
         $lo .= '–' . $hi if $hi ne $lo;
         push @out, "{{$resources[$i]|$lo}}";
      }
      print $OUT "'''Random Rewards''' @out\n\n" if @out;

      my $pets = $dung->{shard_drops};
      @out = ();
      for my $i (0 .. $#$pets) {
         my $num = $pets->[$i] or next;
         $shards->{$i}{$world}{$what}{$tier} = $num;
         my $name = $pet_order[$i] || "pet$i";
         my $short = $short{$name} || $name;
         push @out, "{{PetShard|$name|$short ×$num}}";
      }
      print $OUT "@out\n\n" if @out;

      my $artifacts = $dung->{artifact_drops};
      @out = ();
      for my $i (0 .. $#$artifacts) {
         my $num = $artifacts->[$i] or next;
         my $name = $artifacts[$i] || "artifact$i";
         push @out, "{{Artifact|$name|$name ×$num}}";
      }
      print $OUT "@out\n\n" if @out;

      {
         my $acc = $dung->{accessory_level_range};
         my $lo = Grindia::numfmt($acc->[0]);
         my $hi = Grindia::numfmt(max($acc->[1] * 1.3, $acc->[1] + 3));
         $lo .= '–' . $hi if $hi ne $lo;
         print $OUT "[[File:Accessory.png|Accessory]] Level $lo\n\n";
      }

      print $OUT "[[File:Clock.png|Timer]] ",
         "Win ", format_time($dung->{max_time}),
         ", Lose ", format_time($dung->{fail_time}), "\n\n";
   }

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
   open my $OUT, '>:utf8', 'wiki/Dungeons/Timers' or return;
   print $OUT qq[{| class="wikitable"\n|-\n],
      "! Tier || [[File:Clock.png]] Dungeon || [[File:Clock.png]] Raid \n";
   foreach my $tier (1 .. 12) {
      print $OUT "|-\n| $tier";
      foreach my $type (qw[ Dungeon Raid ]) {
         my $time = $dungeons->{1}{$type}{$tier}{max_time} or die;
         my $lo = my $hi = $dungeons->{1}{$type}{$tier}{max_time} or die;
         foreach my $world (2 .. 8) {
            my $dung = $dungeons->{$world}{$type}{$tier} or next;
            my $time = $dung->{max_time};
            $lo = $time if $time < $lo;
            $hi = $time if $time > $hi;
         }
         $lo = format_time($lo);
         $hi = format_time($hi);
         $lo .= ' – ' . $hi if $hi ne $lo;
         print $OUT " || $lo";
      }
      print $OUT "\n";
   }
   print $OUT qq[|}\n];
   close $OUT;
}

sub format_time {
   my ($time) = @_;
   my $mins = $time / 60;
   my $hrs = int($mins / 60);
   $mins = int($mins - 60*$hrs + 0.5);
   if ($hrs) {
      my $str = "$hrs hr";
      $str .= " $mins min" if $mins;
      return $str;
   }
   else {
      return "$mins min";
   }
}

1 # end Dungeons.pm
