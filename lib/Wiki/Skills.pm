package Wiki::Skills;
use utf8;
use strict;
use warnings;

sub build {
   my ($ctx) = @_;
   open my $OUT , '>:utf8', 'wiki/Skills' or die;

   my %skill_map = (
      '1H 01 Jumping Slash Stats' => 'Jumping Slash',
      '1H 02 First Aid Stats' => 'First Aid',
      '1H 03 Break Weapon Stats' => 'Break Weapon',
      '1H 04 Break Armor Stats' => 'Break Armor',
      'MR 01 Fireball Stats' => 'Fireball',
      'MR 02 Cure Stats' => 'Cure Spell',
      'MR 03 Ice Armor Stats' => 'Ice Armor',
      'MR 04 Thunder Armor Stats' => 'Thunder Armor',
      '01 Health Stats' => 'Vitality',
      '02 Defense Stats' => 'Survival',
      '03 Shields Stats' => 'Unstoppable',
      '04 Basic Phys Attack Stats' => 'Combat Basics',
      '05 Intermediate Phys Attack Stats' => 'Military Training',
      '06 Advanced Phys Attack Stats' => 'Bushido',
      '07 Basic Mag Attack Stats' => 'Prestidigitation',
      '08 Intermediate Mag Attack Stats' => 'Arcane Magic',
      '09 Advanced Mag Attack Stats' => 'Dark Arts',
      '01 Speed 1 Stats' => 'Walking',
      '04 Critical 1 Stats' => 'Crits',
   );

   my %active;
   $ctx->for_type('ActiveSkillData', sub {
      my ($obj) = @_;
      my $name = $skill_map{$obj->{name}} or return;
      $active{$name} = $obj;
   });

   my @statnames = ( 'HP', 'STR', 'INT', 'END', 'WIS', 'SPD',
      'Crit Chance', 'Crit Damage', 'Crit Resist', 'Crit Armor',
     'Physical Penetration', 'Magical Penetration',
     'Debuff Accuracy', 'Debuff Resist',
     'Block', 'Resist', 'Dodge', 'starting Shield', 'First Strike',
     'HP', 'STR', 'INT', 'END', 'WIS' # percentage increase
   );

   my %passive;
   $ctx->for_type('StatPassiveSkillData', sub {
      my ($obj) = @_;
      my $name = $skill_map{$obj->{name}} or return;
      $passive{$name} = $obj;
   });

   my %seen;
   $ctx->for_type('SkillMetaData', sub {
      my ($skill) = @_;
      return if $seen{$skill->{title}}++;
      print $OUT "===$skill->{title}===\n",
         "[[File:$skill->{title}.png]]\n";

      my ($levels, $bonuses);
      if (my $active = $active{$skill->{title}}) {
         print $OUT "Cooldown: $active->{cooldown} sec\n";
         $levels = [];
         foreach my $list (@{$active->{effect}{_1}}) {
            my @eff;
            foreach my $eff (@{$list->{_1}}) {
               push @eff, Grindia::describe_effect($eff, 'enemy');
            }
            push @$levels, join('; ', @eff);
         }
      }
      elsif (my $passive = $passive{$skill->{title}}) {
         $levels = [];
         foreach my $stats (@{$passive->{stats}}) {
            my @stats;
            foreach my $i (0 .. $#$stats) {
               my $val = $stats->[$i] or next;
               my $name = $statnames[$i] || "stat$i";
               if ($i > 5) {
                  $val .= '%';
               }
               else {
                  $val = Grindia::numfmt($val);
               }
               push @stats, "+$val $name";
            }
            push @$levels, join(', ', @stats);
         }
         $bonuses = [ @{$skill->{bonuses}} ];
         foreach my $bonus (@$bonuses) {
            $bonus = '' unless $bonus =~ /Physical|Magical/;
         }
      }
      else {
         $levels = $skill->{levels};
         $bonuses = $skill->{bonuses};
      }

      print $OUT "{{Clear}}\n";
      my $cost = $skill->{coins};
      my (@rows, @bonus, %bonus);
      for my $i (1 .. 15) {
         my $txt = $levels->[$i] or last;
         $txt =~ s/\s+/ /g;
         $txt =~ s/ $//;
         $txt =~ s/(\d\d) (\d\d\d)/$1,$2/;

         if ($i % 5 == 0) {
            my $bonus = $bonuses->[$i/5-1];
            if ($bonus && $bonus !~ /^Level/) {
               $bonus =~ s/\s+/ /g;
               $bonus =~ s/ $//;
               my $val;
               (my $blank = $bonus) =~ s/(\d+\.?\d*)/*/ and $val = $1;
               my $slot = $bonus{$blank};
               if (defined $slot) {
                  $bonus[$slot] =~ s/(\d+\.?\d*)/$1 + $val/e;
               }
               else {
                  $bonus{$blank} = @bonus;
                  push @bonus, $bonus;
               }
            }
         }

         $txt = join(', ', $txt, @bonus);
         my $c = Grindia::numfmt($cost);
         push @rows, "|-\n| $i || {{Coin|$c}} || $txt\n";
         $cost *= 2.1;
         if    ($i == 5)  { $cost *= 5 }
         elsif ($i == 10) { $cost *= 25 }
         elsif ($i == 15) { $cost *= 75 }
         elsif ($i == 20) { $cost *= 150 }
      }
      print $OUT qq[{| class="wikitable mw-collapsible mw-collapsed"\n],
         reverse(@rows), qq[|}\n\n];
   });
   close $OUT;
}

1 # end Skills.pm
