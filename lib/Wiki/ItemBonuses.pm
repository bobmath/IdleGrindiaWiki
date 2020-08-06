package Wiki::ItemBonuses;
use strict;
use warnings;

my @statnames = ( 'HP', 'STR', 'INT', 'END', 'WIS', 'SPD',
   'Crit Chance', 'Crit Damage', 'Crit Resist', 'Crit Armor',
   'Physical Penetration', 'Magical Penetration',
   'Debuff Accuracy', 'Debuff Resist',
   'Block', 'Resist', 'Dodge', 'starting Shield', 'First Strike',
   'HP', 'STR', 'INT', 'END', 'WIS', # percentage increase
   'Physical Damage', 'Magical Damage',
   'Coins', 'Materials', 'Experience', 'Pet Experience',
);  

# source: ItemRerollManager.GetRerollCost
my %reforge_cost = (
   1 => [['Coin', 1500], ['Bronze', 250000], ['Jewel|1|1', 300]],
   2 => [['Coin', 16500], ['Silver', 275000], ['Jewel|2|1', 3300]],
   3 => [['Coin', 181500], ['Silver', 302500], ['Jewel|4|1', 4800]],
   4 => [['Coin', 1996500], ['Gold', 3327500], ['Jewel|6|1', 33300]],
   5 => [['Coin', 219615000], ['Gold', 366025000], ['Jewel|7|1', 49800]],
);
my %upgrade_cost = (
   1 => [['Jewel|2|1', 45]],
   2 => [['Jewel|3|1', 495]],
   3 => [['Jewel|5|1', 720]],
   4 => [['Jewel|7|1', 4995]],
   5 => [['Jewel|8|1', 7470]],
);
my %level_cost = (
   21 => 1.2,
   59 => 1.3,
   119 => 1.4,
   229 => 1.5,
   389 => 1.55,
   649 => 1.6,
   999 => 1.7,
);

# source: ItemRerollManager.GetUpgradeChance
my %upgrade_chance = (
   1 => 30,
   2 => 15,
   3 => 5,
   4 => 1,
   5 => 0.5,
);

sub build {
   my ($ctx) = @_;
   mkdir 'wiki/Forge';
   open my $OUT, '>:utf8', 'wiki/Forge/Item_bonuses' or die;

   print $OUT qq[{| class="wikitable"\n],
      "|-\n! Item Level || Cost Multiplier\n";
   foreach my $lvl (sort { $a <=> $b } keys %level_cost) {
      print $OUT "|-\n| ", ($lvl+1), " || ", $level_cost{$lvl}, "\n";
   }
   print $OUT qq[|}\n\n];

   $ctx->for_type('ItemFactoryBonusData', sub {
      my ($obj) = @_;
      foreach my $tier (1 .. 5) {
         print $OUT "==Tier $tier==\n";
         print $OUT "Reforge cost: ", show_cost($reforge_cost{$tier}),
            "<br>\n",
            "Upgrade cost: ", show_cost($upgrade_cost{$tier}), "<br>\n",
            "Upgrade chance: $upgrade_chance{$tier}%\n";

         my $bonuses = $obj->{"tier$tier"} or next;
         foreach my $bonus (@$bonuses) {
            my $name = $bonus->{title};
            $name =~ s/\s+/ /g;
            $name =~ s/^ //;
            $name =~ s/ $//;

            my @stats;
            my $stats = $bonus->{stats} or next;
            foreach my $i (0 .. 29) {
               my $val = $stats->[$i] or next;
               $val *= 100 if $i > 18;
               my $desc = sprintf "%+g", $val;
               $desc .= '%' if $i > 5;
               $desc .= ' ' . $statnames[$i];
               push @stats, $desc;
            }
            push @stats, '???' unless @stats;

            $stats = join(', ', @stats);
            print $OUT "* $name: $stats\n";
         }
      }
   });
   close $OUT;
}

sub show_cost {
   my ($list) = @_;
   return unless $list;
   my @out;
   foreach my $cost (@$list) {
      my $val = Grindia::numfmt($cost->[1]);
      push @out, "{{$cost->[0]|$val}}";
   }
   return join ', ', @out;
}

1 # end ItemBonuses.pm
