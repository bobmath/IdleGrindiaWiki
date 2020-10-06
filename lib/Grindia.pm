package Grindia;
use utf8;
use strict;
use warnings;
use Grindia::Data;
use Unity::AppContext;

sub get_context {
   my ($dir) = @_;
   my $ctx = Unity::AppContext->new($dir);
   $ctx->load_bundle('library/unity default resources',
      'Resources_unity_default_resources');
   $ctx->load_bundle('resources/unity_builtin_extra',
      'Resources_unity_builtin_extra');
   $ctx->load_bundle('globalgamemanagers.assets');
   $ctx->load_bundle('globalgamemanagers');
   $ctx->load_bundle('resources.assets');
   $ctx->load_bundle('level1');
   $ctx->set_types(\%Grindia::Data::typemap);
   $ctx->set_loaders(\%Grindia::Data::loaders);
   return $ctx;
}

sub numfmt {
   my ($x) = @_;
   if (abs($x) < 99999.5) {
      my $str = sprintf '%.0f', $x;
      $str =~ s/(\d\d)(\d\d\d)$/$1,$2/;
      return $str;
   }
   else {
      my $str = sprintf '%.2e', $x;
      $str =~ s/e\+0*/e/;
      return $str;
   }
}

sub decfmt {
   my ($x) = @_;
   my $str = sprintf '%.4g', $x;
   $str =~ s/e\+0*/e/;
   $str =~ s/e-0+/e-/;
   return $str;
}

sub fortime {
   my ($t) = @_;
   return " for one timestep" unless $t;
   return "" if $t > 60*60;
   return sprintf " for %g sec", $t if $t <= 120;
   return sprintf " for %.0f min", $t/60;
}

sub timefmt {
   my ($t) = @_;
   return sprintf "%g sec", $t if $t <= 120;
   return sprintf "%.0f min", $t/60 if $t < 120*60;
   return sprintf "%.0f hr", $t/3600;
}

sub describe_attack {
   my ($att, $opponent) = @_;
   my $desc = $att->{title} || 'attack';
   my @eff;
   if (my $effects = $att->{effect}{_1}) {
      foreach my $eff (@$effects) {
         push @eff, describe_effect($eff, $opponent);
      }
   }
   my @filt;
   for (my $i = 0; $i < @eff;) {
      my $j = $i + 1;
      $j++ while $j < @eff && $eff[$i] eq $eff[$j];
      if ($j == $i+1) { push @filt, $eff[$i] }
      else { push @filt, ($j-$i) . '× ' . $eff[$i] }
      $i = $j;
   }
   if (@filt > 2) {
      $desc = join("\n** ", $desc, @filt);
   }
   elsif (@filt) {
      $desc .= ": " . join(", ", @filt);
   }
   return "* $desc\n";
}

sub describe_effect {
   my ($eff, $opponent) = @_;
   return unless ref($eff) eq 'HASH';
   my $type = $eff->{_type};
   my $what;
   if ($type =~ /^ApplyBuff/) {
      $what = describe_buff($eff->{buff}, $eff->{target}, $opponent);
      $what .= ' (unresistable)' if $eff->{target} && !$eff->{resistable};
   }
   elsif ($type =~ /^Deal(Phys|Magic)Damage/) {
      my $dmgtype = $1 eq 'Phys' ? 'Physical' : 'Magic';
      $what = "Deal ";
      if (my $mul = $eff->{eqFactor}) {
         $what .= sprintf '%g%%', $mul*100;
      }
      else {
         $what .= Grindia::numfmt($eff->{damage});
      }
      $what .= " $dmgtype Damage";
   }
   else {
      $what = $type;
   }
   $what = sprintf('%g%% chance to %s', $eff->{chance}, $what)
      if $eff->{chance} < 100;
   return $what;
}

# source: BattleDebuffIconDisplay.DebuffIcons
my %buff_icons = (
   0  => 'Debuff_Speed.png',
   1  => 'Break_Weapon.png',
   2  => 'Break_Armor.png',
   3  => 'Buff_Speed.png',
   4  => 'Stun.png',
   6  => 'Damage_Over_Time.png',
   7  => 'Damage_Over_Time.png',
   8  => 'Cure_Spell.png',
   9  => 'Heal_Over_Time.png',
   10 => 'Buff_Shield.png',
   11 => 'Buff_Counter.png',
   12 => 'Cleanse.png',
   13 => 'Dispel.png',
   14 => 'Buff_Attack.png',
   17 => 'Buff_Attack.png',
   20 => 'Buff_Attack.png',
   22 => 'Buff_Shield.png',
   23 => 'Buff_Attack.png',
   24 => 'Buff_Attack.png',
   25 => 'Buff_Attack.png',
   26 => 'Buff_Attack.png',
   29 => 'Buff_Attack.png',
   30 => 'Buff_Attack.png',
);

sub describe_buff {
   my ($buff, $targ, $opponent) = @_;
   my $type = $buff->{type};
   my $who = $targ ? $opponent : ($opponent eq "enemy" ? "hero" : "self");
   my $whose = $targ ? " ${opponent}'s" : "";
   my $whose2 = $whose || ($opponent eq "enemy" ? " hero's" : " own");
   my $desc = '';
   if (my $icon = $buff_icons{$type}) {
      $desc = "[[File:$icon|24px]] ";
   }

   # source: BattleEffectLogic.calculateFinalStats
   if ($type == 0) {
      $desc .= "Reduce$whose2 SPD by " . decfmt($buff->{value1})
         . fortime($buff->{duration});
   }
   elsif ($type == 1) {
      $desc .= "Reduce$whose2 STR and INT by " . decfmt($buff->{value1})
         . fortime($buff->{duration});
   }
   elsif ($type == 2) {
      $desc .= "Reduce$whose2 END and WIS by " . decfmt($buff->{value1})
         . fortime($buff->{duration});
   }
   elsif ($type == 3) {
      $desc .= "Increase$whose SPD by " . decfmt($buff->{value1})
         . fortime($buff->{duration});
   }
   elsif ($type == 4) {
      $desc .= "Stun" . ($targ ? "" : " self")
         . fortime($buff->{duration});
   }
   elsif ($type == 5) {
      $desc .= "Deal " . decfmt($buff->{value1}) . " damage/sec"
         . fortime($buff->{duration});
   }
   elsif ($type == 6) {
      $desc .= "Deal " . decfmt($buff->{value1}) . " Physical damage/sec"
         . fortime($buff->{duration});
   }
   elsif ($type == 7) {
      $desc .= "Deal " . decfmt($buff->{value1}) . " Magic damage/sec"
         . fortime($buff->{duration});
   }
   elsif ($type == 8) {
      $desc .= "Heal " . decfmt($buff->{value1}) . " Health";
   }
   elsif ($type == 9) {
      $desc .= "Heal " . decfmt($buff->{value1}) . " Health/sec"
         . fortime($buff->{duration});
   }
   elsif ($type == 10) {
      $desc .= "Gain " . decfmt($buff->{value1}) . " Shield";
   }
   # type 11 PHYS_COUNTER unimplemented
   elsif ($type == 12) {
      $desc .= sprintf "Remove %g debuff%s from %s",
         $buff->{value1}, ($buff->{value1} > 1 && 's'), $who;
      $desc .= " within " . timefmt($buff->{duration}) if $buff->{duration};
   }
   elsif ($type == 13) {
      $desc .= sprintf "Remove %g buff%s from %s",
         $buff->{value1}, ($buff->{value1} > 1 && 's'), $who;
      $desc .= " within " . timefmt($buff->{duration}) if $buff->{duration};
   }
   elsif ($type == 14) {
      $desc .= "Increase$whose " . two_vals($buff, 'STR', 'INT')
         . fortime($buff->{duration});
   }
   elsif ($type == 15) {
      $desc .= sprintf "Deal %g damage per debuff (max %g)",
         $buff->{value1}, $buff->{value2};
   }
   elsif ($type == 16) {
      $desc .= "Increase $whose" . two_vals($buff, 'END', 'WIS')
         . fortime($buff->{duration});
   }
   elsif ($type == 17) {
      $desc .= "Increase$whose Crit Chance by " . decfmt($buff->{value1}) . "%"
         . fortime($buff->{duration});
   }
   elsif ($type == 18) {
      $desc .= "Increase END and WIS by " . decfmt($buff->{value1}*100) . "%"
         . fortime($buff->{duration})
         . ", then deal " . decfmt($buff->{value2}*100) . "% magic damage",
   }
   elsif ($type == 19) {
      $desc .= "Deal " . decfmt($buff->{value1}*100) . "% Magic damage/sec"
         . fortime($buff->{duration}) . ", then deal "
         . decfmt($buff->{value2}*100) . "%";
   }
   elsif ($type == 20) {
      $desc .= "Increase$whose Dodge by " . decfmt($buff->{value1}) . "%"
         . fortime($buff->{duration});
   }
   elsif ($type == 21) {
      $desc .= sprintf "Fill %g%% of%s attack bar", $buff->{value1}/10, $whose;
   }
   elsif ($type == 22) {
      $desc .= "Gain " . decfmt($buff->{value1}) . "% Shield/sec"
         . fortime($buff->{duration});
   }
   elsif ($type == 23) {
      $desc .= "Increase$whose " . two_vals($buff, 'END', 'WIS', '%')
         . fortime($buff->{duration});
   }
   elsif ($type == 24) {
      $desc .= "Increase$whose " . two_vals($buff, 'STR', 'INT', '%')
         . fortime($buff->{duration});
   }
   elsif ($type == 25) {
      $desc .= "Decrease$whose2 " . two_vals($buff, 'END', 'WIS', '%')
         . fortime($buff->{duration});
   }
   elsif ($type == 26) {
      $desc .= "Decrease$whose2 " . two_vals($buff, 'STR', 'INT', '%')
         . fortime($buff->{duration});
   }
   # type 27 SHIELD_HEAL_PERCENT unimplemented
   elsif ($type == 28) {
      $desc .= "Increase$whose Crit Damage by "
         . decfmt($buff->{value1}) . "%" . fortime($buff->{duration});
   }
   elsif ($type == 29) {
      $desc .= "Decrease$whose2 Crit Chance by "
         . decfmt($buff->{value1}) . "%" . fortime($buff->{duration});
   }
   elsif ($type == 30) {
      $desc .= "Decrease$whose2 Crit Resist by "
         . decfmt($buff->{value1}) . "%" . fortime($buff->{duration});
   }
   elsif ($type == 31) {
      $desc .= "Reduce$whose2 Healing by "
         . decfmt($buff->{value1}*100) . "%" . fortime($buff->{duration});
   }
   elsif ($type == 32) {
      $desc .= "Remove$whose2 Shield";
   }
   elsif ($type == 33) {
      $desc .= sprintf "Can't heal, gain %+g%% STR and INT",
         $buff->{value1}*100;
      $desc .= sprintf ", %+g%% Crit Chance", $buff->{value2}
         if $buff->{value2};
   }
   elsif ($type == 34) {
      $desc .= sprintf "Healing increased by %g%%, gain %g%% END and WIS",
         $buff->{value1}*100, $buff->{value2}*100;
   }
   else {
      $desc .= "apply buff $type";
   }
   return $desc;
}

sub two_vals {
   my ($buff, $name1, $name2, $unit) = @_;
   $unit //= '';
   my $val1 = $buff->{value1};
   my $val2 = $buff->{value2};
   if ($unit eq '%') {
      $val1 *= 100;
      $val2 *= 100;
   }
   if ($val1 == $val2) {
      return sprintf "%s and %s by %g%s", $name1, $name2, $val1, $unit;
   }
   elsif ($val1 == 0) {
      return sprintf "%s by %g%s", $name2, $val2, $unit;
   }
   elsif ($val2 == 0) {
      return sprintf "%s by %g%s", $name1, $val1, $unit;
   }
   else {
      return "%s by %g%s and %s by %g%s", $name1, $val1, $unit,
         $name2, $val2, $unit;
   }
}

sub trim {
   my ($str) = @_;
   $str =~ s/\s+/ /g;
   $str =~ s/^ //;
   $str =~ s/ $//;
   return $str;
}

my %dungeons = (
   1 => 'First Dungeon',
   2 => 'Forest Dungeon',
   3 => 'City Dungeon',
   4 => 'Seaside Dungeon',
   5 => 'Desert Dungeon',
   6 => 'Cemetery Dungeon',
   7 => 'Slime Dungeon',
);
sub dungeon_name {
   my ($num) = @_;
   return $dungeons{$num} || "Dungeon $num";
}

my %raids = (
   1 => 'Brutish Lair',
   2 => 'Tree Grove',
   3 => 'Scuzz Hideout',
   4 => 'Lifeguard Post',
   5 => 'Desert Raid',
   6 => 'Cemetery Raid',
   7 => 'Slime Raid',
);
sub raid_name {
   my ($num) = @_;
   return $raids{$num} || "Raid $num";
}

1 # end Grindia.pm
