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

sub build {
   my ($ctx) = @_;
   mkdir 'wiki/Forge';
   open my $OUT, '>:utf8', 'wiki/Forge/Item_bonuses' or die;
   my $fact = $ctx->get_objects('ItemFactoryBonusData');

   foreach my $tier (1 .. 5) {
      print $OUT "==Rank $tier==\n";
      my $bonuses = $fact->{"tier$tier"} or next;
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
   close $OUT;
}

1 # end ItemBonuses.pm
