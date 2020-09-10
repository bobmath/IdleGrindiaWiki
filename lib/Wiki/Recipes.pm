package Wiki::Recipes;
use utf8;
use strict;
use warnings;

my @rarity_name = qw( None Common Uncommon Rare Epic Legendary );
my @rarity_bonus = ( 1, 1, 1.3, 1.75, 2.5, 4 );
my @currency = qw( Coin Bronze Silver Gold );
my @stats = qw( PhysDmg MagDmg HP STR INT END WIS SPD );
my @enhance = (1.42, 2.37, 4.01, 6.39, 9.77, 15.37);
my @slots = ( '1H Weapon', 'MR Weapon', 'Body', 'Feet', 'Hands', 'Head' );
my %slots = (
   '1H Weapon' => '1-H Weapons',
   'MR Weapon' => 'Magic Weapons',
   'Body' => 'Armor',
);

# source: ItemUpgradeManager.GetEnhanceCost
my %tier_mult = (
   1 => 1,
   2 => 6,
   3 => 10,
   4 => 18,
   5 => 36,
   6 => 72,
   7 => 175,
   8 => 600,
);

sub build {
   my ($ctx) = @_;
   my %recipes;
   $ctx->for_type('ItemRecipeObject', sub {
      my ($obj) = @_;
      if ($obj->{name} =~ /^(.*) Tier (\d+) (\d+)/) {
         $recipes{$2+0}{$1}{$3+0} = $obj;
      }
   });

   mkdir 'wiki/Forge';
   foreach my $tier (1 .. 7) {
      my $recipes = $recipes{$tier} or die;
      open my $OUT, '>:utf8', "wiki/Forge/Tier_${tier}_Recipes" or die;
      print $OUT "[[File:Tier $tier Items.png|160px|right]]\n",
         "These items can be crafted at the [[Forge]] ",
         "in [[Idle Grindia]].\n\n";
      show_cost($OUT, $tier, $recipes);
      for my $slot (@slots) {
         show_recipes($OUT, $tier, $recipes->{$slot}, $slots{$slot} || $slot);
      }
      show_enhance($OUT, $tier);
      close $OUT;
   }
}

sub show_cost {
   my ($OUT, $tier, $types) = @_;
   my ($first_levels, %mult);
   foreach my $type (sort keys %$types) {
      my $levels = $types->{$type};
      $first_levels ||= $levels;
      my $mult;
      foreach my $level (sort keys %$levels) {
         my $recipe = $levels->{$level};
         $mult //= $recipe->{cost_mult};
         die unless $mult == $recipe->{cost_mult};
         my $first = $first_levels->{$level};
         die unless $first->{upgrade_cost} == $recipe->{upgrade_cost};
         die unless $first->{craft_cost} == $recipe->{craft_cost};
      }
      $mult{$type} = $mult;
   }

   die unless $mult{'1H Weapon'} == 1 && $mult{'MR Weapon'} == 1;
   print $OUT "==Cost==\n",
      "The following costs are for Weapons. ",
      "They are multiplied by $mult{Body} for Body Armor, ",
      "$mult{Feet} for Feet, $mult{Hands} for Hands, ",
      "and $mult{Head} for Head.\n",
      qq[{| class="wikitable"\n],
      "|-\n",
      "! rowspan=2 | Rarity\n",
      "! colspan=1 | Base\n",
      "! colspan=2 | Good\n",
      "! colspan=2 | Great\n",
      "! colspan=2 | Master\n",
      "|-\n",
      "! Craft\n",
      "! Upgrade !! Craft\n" x 3;

   for my $level (1 .. 5) {
      my $recipe = $first_levels->{$level};
      my $upgrade = $recipe->{upgrade_cost}{costs};
      my $craft = $recipe->{craft_cost}{costs};
         print $OUT qq[|- valign="top"\n],
            qq[| $rarity_name[$level]<br>$tier-$level\n];
      for my $i (0 .. 3) {
         print $OUT "| ", format_cost($upgrade->[$i], 1), "\n" if $i;
         print $OUT "| ", format_cost($craft->[$i], 1), "\n";
      }
   }
   print $OUT qq[|}\n\n];
}

sub show_recipes {
   my ($OUT, $tier, $levels, $label) = @_;
   print $OUT "==$label==\n",
      qq[{| class="wikitable"\n],
      "|-\n! Item || Base || Good || Great || Master\n";
   foreach my $level (1 .. 5) {
      my $img = $label;
      if ($img eq '1-H Weapons') {
         $img = '1H Weapon';
      }
      elsif ($img eq 'Magic Weapons') {
         $img = 'Magic Weapon';
      }
      if ($img eq 'Armor') {
         if ($level == 2 || $level == 5) {
            $img = 'Light Armor';
         }
         elsif ($level == 3) {
            $img = 'Heavy Armor';
         }
         else {
            $img = 'Medium Armor';
         }
      }
      my $recipe = $levels->{$level};
      my $name = $recipe->{items}[0]{name};
      $name =~ s/\s+/ /g;
      $name =~ s/ $//;
      print $OUT qq[|- valign="top"\n],
         qq[| align="center" | $name<br>],
         "[[File:$img $tier.png]]\n";
      for my $i (0 .. 3) {
         my $item = $recipe->{items}[$i];
         my $bonus = 1;
         $bonus = $rarity_bonus[$level] if $label =~ /Weapon/;
         print $OUT "| ", format_item($item, $bonus), "\n";
      }
   }
   print $OUT qq[|}\n\n];

   print $OUT qq[{| class="wikitable"\n],
      "|-\n! Name\n",
      "! [[File:Stars0.png]]<br>+20\n",
      "! [[File:Stars1.png]]<br>+40\n",
      "! [[File:Stars2.png]]<br>+60\n",
      "! [[File:Stars3.png]]<br>+80\n",
      "! [[File:Stars4.png]]<br>+100\n",
      "! [[File:Stars5.png]]<br>+150\n";
   foreach my $level (sort keys %$levels) {
      my $item = $levels->{$level}{items}[0];
      print $OUT "|-\n| $item->{name}";
      for my $enh (@enhance) {
         my $bonus = $enh;
         $bonus *= $rarity_bonus[$level] if $label =~ /Weapon/;
         my $text = format_item($item, $bonus);
         $text =~ s/<br>.*//;
         $text =~ s/STR$/S+I/;
         $text =~ s/Phys//;
         $text =~ s/Mag//;
         print $OUT " || $text";
      }
      print $OUT "\n";
   }
   print $OUT qq[|}\n\n];
}

sub format_item {
   my ($item, $bonus) = @_;
   my $stats = $item->{stats};
   my @out;
   for my $i (0 .. $#stats) {
      my $val = $stats->[$i] or next;
      $val = Grindia::numfmt($val * $bonus);
      push @out, "$val $stats[$i]";
   }

   my %count;
   for my $bonus (@{$item->{bonus}}) {
      $count{$bonus->{desc}}++;
   }
   for my $bonus (@{$item->{bonus}}) {
      my $name = $bonus->{desc};
      my $num = delete $count{$name} or next;
      $name =~ s/^Random\s*// unless $name eq 'Random Bonus';
      $name =~ s/^Legendary/Leg./;
      $name .= " ×$num" if $num > 1;
      push @out, $name;
   }

   return join('<br>', @out);
}

sub format_cost {
   my ($cost, $mult) = @_;
   my @cost;
   foreach my $i (0 .. 3) {
      my $val = $cost->[$i] or next;
      $val = Grindia::numfmt($val * $mult);
      push @cost, "{{$currency[$i]|$val}}";
   }
   my $i = 4;
   foreach my $world (1 .. 8) {
      foreach my $lvl (1 .. 3) {
         my $val = $cost->[$i++] or next;
         $val = Grindia::numfmt($val * $mult);
         push @cost, "{{Jewel|$world|$lvl|$val}}";
      }
   }
   return join('<br>', @cost);
}

sub show_enhance {
   my ($OUT, $tier) = @_;
   print $OUT "==Enhance==\n",
      "The enhancement costs shown here are for Weapons. ",
      "Body Armor cost is multiplied by 0.9, Hands and Feet by 0.3, ",
      "and Head by 0.5.\n",
      qq[{| class="wikitable"\n],
      "|-\n",
      "! Rarity\n",
      "! [[File:Stars0.png]]<br>+20\n",
      "! [[File:Stars1.png]]<br>+40\n",
      "! [[File:Stars2.png]]<br>+60\n",
      "! [[File:Stars3.png]]<br>+80\n",
      "! [[File:Stars4.png]]<br>+100\n",
      "! [[File:Stars5.png]]<br>+150\n";

   for my $rarity (1 .. 5) {
      print $OUT qq[|- valign="top"\n],
         "| $rarity_name[$rarity]<br>$tier-$rarity\n";
      # source: ItemUpgradeManager.GetEnhanceCost
      my $gem_tier = $tier;
      if ($tier == 2) {
         $gem_tier-- if $rarity <= 2;
      }
      elsif ($tier > 2) {
         $gem_tier-- if $rarity <= 1;
      }
      my $gem = 'W' . $gem_tier . 'Gem';

      for my $stars (0 .. 5) {
         my $total = {};
         my $mul = (1 + $stars/4) * $tier_mult{$tier};
         my $max = $stars < 5 ? 20 * ($stars + 1) : 150;
         for (my $enhance = 4; $enhance <= $max; $enhance += 5) {
            my $cost = enhance_cost($rarity, $enhance, $gem);
            for my $k (keys %$cost) {
               $total->{$k} += int($cost->{$k} * $mul + 0.5);
            }
         }

         my @out;
         foreach my $curr (@currency) {
            my $val = $total->{$curr} or next;
            $val = Grindia::numfmt($val);
            push @out, "{{$curr|$val}}";
         }
         foreach my $i (1 .. 8) {
            foreach my $j (1 .. 3) {
               my $val = $total->{"W${i}Gem${j}"} or next;
               $val = Grindia::numfmt($val);
               push @out, "{{Jewel|$i|$j|$val}}";
            }
         }
         print $OUT "| ", join('<br>', @out), "\n";
      }
   }

   print $OUT qq[|}\n\n[[Category:Forge]]\n];
}

sub enhance_cost {
   my ($rarity, $enhance, $gem) = @_;
   my $cost = {};
   my $extra = ($enhance % 5) == 4;
   my $mul = 1;
   if ($rarity == 1) {
      # source: ItemUpgradeManager.SetCommonEnhanceCost
      if ($enhance < 21) {
         if ($extra) {
            $mul = 1.25;
            $cost->{Silver} = 5*$enhance + 1;
            $cost->{$gem.1} = 1*$enhance + 1;
         }
      }
      elsif ($enhance < 51) {
         $mul = 1.25;
         if ($extra) {
            $mul *= 1.25;
            $cost->{Silver} = 42*$enhance + 150;
            $cost->{$gem.1} = 4*$enhance + 15;
         }
      }
      elsif ($enhance < 101) {
         $mul = 1.25;
         if ($extra) {
            $mul *= 1.25;
            $cost->{Silver} = 124*$enhance + 850;
            $cost->{$gem.1} = 11*$enhance + 85;
         }
      }
      elsif ($enhance < 151) {
         $mul = 1.5;
         if ($extra) {
            $mul *= 2;
            $cost->{Gold} = 3*254*$enhance + 2150;
            $cost->{$gem.1} = 3*23*$enhance + 215;
         }
      }
      else { die }
      $cost->{Coin} = (24*$enhance + 150) * $mul;
      $cost->{Bronze} = (151*$enhance + 1500) * $mul;
   }
   elsif ($rarity == 2) {
      # source: ItemUpgradeManager.SetUncommonEnhanceCost
      if ($enhance < 21) {
         if ($extra) {
            $mul = 1.25;
            $cost->{Silver} = 5*$enhance + 2;
            $cost->{$gem.1} = 3*$enhance + 1;
         }
      }
      elsif ($enhance < 51) {
         $mul = 1.25;
         if ($extra) {
            $mul *= 1.25;
            $cost->{Gold} = 48*$enhance + 150;
            $cost->{$gem.1} = 5*$enhance + 15;
         }
      }
      elsif ($enhance < 101) {
         $mul = 1.25;
         if ($extra) {
            $mul *= 1.25;
            $cost->{Gold} = 224*$enhance + 1850;
            $cost->{$gem.1} = 21*$enhance + 185;
         }
      }
      elsif ($enhance < 151) {
         $mul = 1.5;
         if ($extra) {
            $mul *= 2;
            $cost->{Gold} = 3*354*$enhance + 3150;
            $cost->{$gem.1} = 3*33*$enhance + 315;
         }
      }
      else { die }
      $cost->{Coin} = (2*42*$enhance + 250) * $mul;
      $cost->{Bronze} = (2*250*$enhance + 4500) * $mul;
   }
   elsif ($rarity == 3) {
      # source: ItemUpgradeManager.SetRareEnhanceCost
      if ($enhance < 21) {
         if ($extra) {
            $mul = 1.25;
            $cost->{Silver} = 5*$enhance + 3;
            $cost->{$gem.1} = 5*$enhance + 1;
         }
      }
      elsif ($enhance < 51) {
         $mul = 1.25;
         if ($extra) {
            $mul *= 1.25;
            $cost->{Gold} = 54*$enhance + 150;
            $cost->{$gem.2} = 6*$enhance + 15;
         }
      }
      elsif ($enhance < 101) {
         $mul = 1.25;
         if ($extra) {
            $mul *= 1.25;
            $cost->{Gold} = 324*$enhance + 2850;
            $cost->{$gem.2} = 31*$enhance + 285;
         }
      }
      elsif ($enhance < 151) {
         $mul = 1.5;
         if ($extra) {
            $mul *= 2;
            $cost->{Gold} = 3*654*$enhance + 6150;
            $cost->{$gem.2} = 3*63*$enhance + 615;
         }
      }
      else { die }
      $cost->{Coin} = (3*360*$enhance + 350) * $mul;
      $cost->{Bronze} = (3*1500*$enhance + 6500) * $mul;
   }
   elsif ($rarity == 4) {
      # source: ItemUpgradeManager.SetEpicEnhanceCost
      if ($enhance < 21) {
         if ($extra) {
            $mul = 1.25;
            $cost->{Gold} = 5*$enhance + 4;
            $cost->{$gem.1} = 7*$enhance + 1;
         }
      }
      elsif ($enhance < 51) {
         $mul = 1.25;
         if ($extra) {
            $mul *= 1.25;
            $cost->{Gold} = 54*$enhance + 150;
            $cost->{$gem.2} = 7*$enhance + 10;
         }
      }
      elsif ($enhance < 101) {
         $mul = 1.25;
         if ($extra) {
            $mul *= 1.25;
            $cost->{Gold} = 424*$enhance + 3850;
            $cost->{$gem.3} = 11*$enhance + 120;
         }
      }
      elsif ($enhance < 151) {
         $mul = 1.5;
         if ($extra) {
            $mul *= 2;
            $cost->{Gold} = 3*854*$enhance + 8150;
            $cost->{$gem.3} = 3*83*$enhance + 810;
         }
      }
      else { die }
      $cost->{Coin} = (4*540*$enhance + 450) * $mul;
      $cost->{Bronze} = (4*8670*$enhance + 85000) * $mul;
   }
   elsif ($rarity == 5) {
      # source: ItemUpgradeManager.SetLegendEnhanceCost
      if ($enhance < 21) {
         if ($extra) {
            $mul = 1.25;
            $cost->{Gold} = 5*$enhance + 5;
            $cost->{$gem.1} = 9*$enhance + 1;
         }
      }
      elsif ($enhance < 51) {
         $mul = 1.25;
         if ($extra) {
            $mul *= 1.25;
            $cost->{Gold} = 54*$enhance + 150;
            $cost->{$gem.2} = 8*$enhance + 15;
         }
      }
      elsif ($enhance < 101) {
         $mul = 1.25;
         if ($extra) {
            $mul *= 1.25;
            $cost->{Gold} = 524*$enhance + 4850;
            $cost->{$gem.3} = 42*$enhance + 366;
         }
      }
      elsif ($enhance < 151) {
         $mul = 1.5;
         if ($extra) {
            $mul *= 2;
            $cost->{Gold} = 3*1254*$enhance + 12150;
            $cost->{$gem.3} = 3*123*$enhance + 1210;
         }
      }
      else { die }
      $cost->{Coin} = (5*54*$enhance + 650) * $mul;
      $cost->{Silver} = (5*36*$enhance + 65) * $mul;
   }
   return $cost;
}

1 # end Recipes.pm
