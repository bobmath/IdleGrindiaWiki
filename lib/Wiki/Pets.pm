package Wiki::Pets;
use utf8;
use strict;
use warnings;

sub build {
   my ($ctx) = @_;
   open my $OUT, '>:utf8', 'wiki/Pets' or die;
   $ctx->for_type('PetsPanelDisplay', sub {
      my ($disp) = @_;

      my $meta = $disp->{pet_meta};
      my $mgr = $disp->{pet_mgr};
      my @shards = ($mgr->{unlock}, @{$mgr->{shards}});
      my $levels = $meta->{level_cap};
      print $OUT qq[{| class="wikitable"\n],
         "|-\n! Shards || Level\n";
      for my $i (0 .. 15) {
         my $sha = Grindia::numfmt($shards[$i]);
         my $lvl = Grindia::numfmt($levels->[$i]);
         print $OUT "|-\n| $sha || $lvl\n";
      }
      print $OUT qq[|}\n\n];

      print $OUT qq[{| class="wikitable"\n],
         "|-\n! Name !! Image !! Active Skill !! Passive Skill !! Source\n";
      for my $i (0 .. 15) {
         my $name = $disp->{names}[$i];
         my $active = scrub($disp->{active}[$i]);
         my $passive = scrub($disp->{passive}[$i]);
         print $OUT "|-\n| $name || [[File:$name.png|center]]\n",
            "| $active\n",
            "| $passive\n",
            "|\n";
      }
      print $OUT qq[|}\n\n];

      my $shards = $meta->{mythic_limits};
      print $OUT qq[{| class="wikitable"\n],
         "|-\n! Level || Shards Needed\n";
      for my $i (1 .. 6) {
         print $OUT "|-\n| $i || $shards->[$i-1]\n";
      }
      print $OUT qq[|}\n\n];

      print $OUT qq[{| class="wikitable"\n],
         "|-\n! Name !! Image !! Passive Skill\n";
      for my $i (0 .. 15) {
         my $name = $disp->{names}[$i];
         print $OUT qq[|-\n| $name\n| align="center" | ],
            "[[File:Mythic $name.png]]<p>[[File:Mythic $name Shard.png]] ||\n";
         for my $j (0 .. 5) {
            my $passive = scrub($disp->{mythic}[$i*6+$j], ', ');
            print $OUT "# $passive\n";
         }
      }
      print $OUT qq[|}\n\n];
   });
   close $OUT;
}

sub scrub {
   my ($str, $break) = @_;
   $break //= '<br>';
   $str =~ s/\s+/ /g;
   $str =~ s/ $//;
   $str =~ s/\\n/$break/g;
   return $str;
}

1 # end Pets.pm
