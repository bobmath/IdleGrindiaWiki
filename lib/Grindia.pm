package Grindia;
use utf8;
use strict;
use warnings;
use Unity::AppContext;
use Scalar::Util qw( weaken );

my %typemap = (
   '86e34eb8ee7642b089fb98c9d81dd9b0' => 'graphic',
   '761ca81f78491542badc37f810ab3455' => 'imgtree',
   '7e050781d08ca9d10bc74beb7e91c3b5' => 'imgtree2',
);

my %loaders;

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
   $ctx->set_types(\%typemap);
   $ctx->set_loaders(\%loaders);
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

$loaders{imgtree} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   weaken($obj->{owner} = $bun->read_obj($bytes, $ctx));
   $obj->{ary1} = $bytes->read_float_array(10);
   $obj->{children} = $bun->read_obj_array($bytes, $ctx);
   weaken($obj->{parent} = $bun->read_obj($bytes, $ctx));
};

$loaders{imgtree2} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   weaken($obj->{owner} = $bun->read_obj($bytes, $ctx));
   $obj->{ary1} = $bytes->read_float_array(10);
   $obj->{children} = $bun->read_obj_array($bytes, $ctx);
   weaken($obj->{parent} = $bun->read_obj($bytes, $ctx));
   $obj->{ary2} = $bytes->read_float_array(10);
};

$loaders{graphic} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $obj->{ary} = $bun->read_obj_array($bytes, $ctx);
   $obj->{int1} = $bytes->read_int();
   $obj->{name} = $bytes->read_str();
};

$loaders{ActiveSkillData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{int1} = $bytes->read_int();
   $obj->{effect} = $bytes->read_serialized();
   $bytes->skip(32);
   $obj->{move} = $bun->read_obj($bytes, $ctx);
   $obj->{cooldown} = $bytes->read_float();
   $obj->{curr_cooldown} = $bytes->read_float();
};

$loaders{AreaData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{title} = $bytes->read_str();
   $obj->{area} = $bytes->read_int();
   $obj->{background} = $bun->read_obj($bytes, $ctx);
   $obj->{is_dungeon} = $bytes->read_int();
   $obj->{is_raid} = $bytes->read_int();
   $obj->{is_challenge} = $bytes->read_int();
   $obj->{is_infinite} = $bytes->read_int();
   $obj->{level_min} = $bytes->read_double();
   $obj->{level_max} = $bytes->read_double();
   $obj->{exp_reward} = $bytes->read_double();
   $obj->{gold_reward} = $bytes->read_double();
   $obj->{craft_reward} = $bytes->read_double();
   $obj->{jewel_drop} = $bytes->read_double();
   $obj->{enemies} = $bun->read_obj_array($bytes, $ctx);
   $obj->{enemy_levels} = $bytes->read_double_array();
   $obj->{level_step} = $bytes->read_double();
   $obj->{pool_levels} = $bytes->read_double_array();
   $obj->{spawn_pools} = $bun->read_obj_array($bytes, $ctx);
};

$loaders{ArtifactManager} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(36);
   $obj->{pieces} = $bytes->read_double_array();
   $bytes->skip(4);
   $obj->{names} = my $names = [];
   for my $i (1 .. 16) {
      push @$names , $bytes->read_str();
      $bytes->skip(276);
   }
   $obj->{stats} = my $stats = [];
   for my $i (1 .. 16) {
      push @$stats, $bun->read_obj_array($bytes, $ctx);
   }
};

$loaders{BattleMove} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{int1} = $bytes->read_int();
   $obj->{effect} = $bytes->read_serialized();
   $bytes->skip(32);
   $obj->{title} = $bytes->read_str();
   $obj->{speed} = $bytes->read_double();
};

$loaders{CraftCostComponent} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   push @{$obj->{costs}}, $bytes->read_double_array(28) for 1 .. 4;
};

$loaders{DailyRewardData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{unlocked} = $bytes->read_byte_array();
   $obj->{value} = $bytes->read_double_array();
   $obj->{title} = $bytes->read_str_array();
   $obj->{text} = $bytes->read_str_array();
   $obj->{hunter} = $bytes->read_double_array();
   $obj->{explorer} = $bytes->read_double_array();
   $obj->{required} = $bytes->read_int_array();
};

$loaders{DungeonMetaData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{title} = $bytes->read_str();
   $obj->{area} = $bun->read_obj($bytes, $ctx);
   $obj->{portrait} = $bun->read_obj($bytes, $ctx);
   $obj->{is_raid} = $bytes->read_int();
   $obj->{crafting_reward1} = $bytes->read_double_array();
   $obj->{crafting_reward2} = $bytes->read_double_array();
   $obj->{crafting_reward3} = $bytes->read_double_array();
   $obj->{resource_rewards} = $bytes->read_double_array();
   $obj->{accessory_level_range} = $bytes->read_double_array();
   $obj->{shard_drops} = $bytes->read_double_array();
   $obj->{artifact_drops} = $bytes->read_double_array();
   $obj->{curr_time} = $bytes->read_double();
   $obj->{last_time} = $bytes->read_double();
   $obj->{max_time} = $bytes->read_double();
   $obj->{fail_time} = $bytes->read_double();
};

$loaders{EnemyData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{title} = $bytes->read_str();
   $obj->{int1} = $bytes->read_int();
   $obj->{type} = $bytes->read_int();
   $obj->{img1} = $bun->read_obj($bytes, $ctx);
   $obj->{img2} = $bun->read_obj($bytes, $ctx);
   $obj->{curve} = $bun->read_obj($bytes, $ctx);
   $obj->{int2} = $bytes->read_int();
   $obj->{attacks} = $bun->read_obj_array($bytes, $ctx);
   $obj->{drop_types} = $bun->read_obj_array($bytes, $ctx);
   $obj->{drop_mult} = $bytes->read_float();
   $obj->{rarity_mult} = $bytes->read_float();
};

$loaders{GrowthCurve} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{base} = $bytes->read_double_array(19);
   $obj->{gain} = $bytes->read_double_array(19);
};

$loaders{InfiniteSpawnPool} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{enemies} = $bun->read_obj_array($bytes, $ctx);
};

$loaders{ItemBonusData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{unk1} = $bytes->read_int();
   $obj->{effect} = $bytes->read_serialized();
   $bytes->skip(32);
   $obj->{title} = $bytes->read_str();
   $obj->{desc} = $bytes->read_str();
   $obj->{type} = $bytes->read_int();
   # type: 0=BASE_ATTACK, 1=FLAT_STATS, 2=SPECIAL_EFFECT_AUTO_ATTACK,
   # 3=SPECIAL_EFFECT_ON_HIT, 4=SPECIAL_EFFECT_ON_START
   $obj->{power} = $bytes->read_double();
   $obj->{stats} = $bytes->read_double_array(30);
};

$loaders{ItemFactoryBonusData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(32);
   $obj->{"tier$_"} = $bun->read_obj_array($bytes, $ctx) for 1 .. 10;
   $obj->{"oldtier$_"} = $bun->read_obj_array($bytes, $ctx) for 1 .. 8;
   $obj->{"old$_"} = $bun->read_obj_array($bytes, $ctx) for 1 .. 4;
};

$loaders{ItemRarityObject} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{title} = $bytes->read_str();
   $obj->{primary_stat_bonus} = $bytes->read_double();
   $obj->{max_secondary_stats} = $bytes->read_int();
   $obj->{value} = $bytes->read_int();
};

$loaders{ItemRecipeObject} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{level} = $bytes->read_int();
   $obj->{cost_mult} = $bytes->read_double();
   $obj->{craft_cost} = $bun->read_obj($bytes, $ctx);
   $obj->{upgrade_cost} = $bun->read_obj($bytes, $ctx);
   for (1 .. 4) {
      my $item = {};
      $item->{active} = $bytes->read_int();
      $item->{name} = $bytes->read_str();
      $item->{tier} = $bytes->read_int();
      $item->{level} = $bytes->read_double();
      $item->{type} = $bun->read_obj($bytes, $ctx);
      $item->{rarity} = $bun->read_obj($bytes, $ctx);
      $item->{stats} = $bytes->read_double_array(26);
      $item->{bonus} = $bun->read_obj_array($bytes, $ctx);
      $item->{ultimate} = $bytes->read_int();
      $item->{quality} = $bytes->read_int();
      $item->{enhance} = $bytes->read_double();
      $item->{awakening} = $bytes->read_int();
      $item->{awake_fail} = $bytes->read_int();
      push @{$obj->{items}}, $item;
   }
   $obj->{crafted} = $bytes->read_double_array(4);
   $obj->{enhance} = $bytes->read_double();
   $obj->{pity} = $bytes->read_double();
   $obj->{awaken} = $bytes->read_double();
   $obj->{prereq} = $bytes->read_int_array(3);
   $obj->{prereq_qual} = $bytes->read_int();
   $obj->{unlock} = $bytes->read_str();
};

$loaders{ItemTypeObject} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{title} = $bytes->read_str();
};

$loaders{PetMetaData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{curr_pet} = $bytes->read_int();
   $obj->{pet_exp} = $bytes->read_double_array();
   $obj->{pet_cap} = $bytes->read_double_array();
   $obj->{shards} = $bytes->read_double_array();
   $obj->{pet_level} = $bytes->read_double_array();
   $obj->{level_cap} = $bytes->read_double_array();
   $obj->{mythic_shards} = $bytes->read_double_array();
   $obj->{mythic_limits} = $bytes->read_double_array();
};

$loaders{PetsManager} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{curr_pets} = $bun->read_obj($bytes, $ctx);
   $obj->{unlock} = $bytes->read_double();
   $obj->{shards} = $bytes->read_double_array();
};

$loaders{PetsPanelDisplay} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{pet_meta} = $bun->read_obj($bytes, $ctx);
   $obj->{pet_mgr} = $bun->read_obj($bytes, $ctx);
   $obj->{disp_pet} = $bytes->read_int();
   $obj->{disp_list} = $bytes->read_int_array();
   $obj->{show_mythic} = $bytes->read_int();
   $obj->{refs1} = $bun->read_obj_array($bytes, $ctx, 19);
   $obj->{active} = $bytes->read_str_array();
   $obj->{passive} = $bytes->read_str_array();
   $obj->{mythic} = $bytes->read_str_array();
   $obj->{pet_img} = $bun->read_obj_array($bytes, $ctx);
   $obj->{shard_img} = $bun->read_obj_array($bytes, $ctx);
   $obj->{refs2} = $bun->read_obj_array($bytes, $ctx, 6);
   $obj->{mythic_pet_img} = $bun->read_obj_array($bytes, $ctx);
   $obj->{mythic_shard_img} = $bun->read_obj_array($bytes, $ctx);
   $obj->{names} = $bytes->read_str_array();
};

$loaders{RaceMetaData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{title} = $bytes->read_str();
   $obj->{desc} = $bytes->read_str();
   $obj->{bonus} = $bytes->read_str_array();
};

$loaders{SkillMetaData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{title} = $bytes->read_str();
   $obj->{icon_big} = $bun->read_obj($bytes, $ctx);
   $obj->{icon_smol} = $bun->read_obj($bytes, $ctx);
   $obj->{levels} = $bytes->read_str_array();
   $obj->{bonuses} = $bytes->read_str_array(5);
   $obj->{level} = $bytes->read_double();
   $obj->{time} = $bytes->read_double();
   $obj->{exp} = $bytes->read_double();
   $obj->{coins} = $bytes->read_double();
   $obj->{cooldown} = $bytes->read_float();
   $obj->{is_upgraded} = $bytes->read_int();
};

$loaders{StatPassiveSkillData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{count} = $bytes->read_int();
   for my $i (1 .. $obj->{count}) {
      push @{$obj->{stats}}, $bytes->read_double_array(24);
   }
};

$loaders{TextMeshProUGUI} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   weaken($obj->{owner} = $bun->read_obj($bytes, $ctx));
   $obj->{ary1} = $bytes->read_int_array(8);
   $obj->{ary2} = $bytes->read_float_array(4);
   $obj->{ary3} = $bytes->read_int_array(2);
   $obj->{str} = $bytes->read_str();
};

$loaders{TitleMetaData} = sub {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $bytes->skip(28);
   $obj->{name} = $bytes->read_str();
   $obj->{text} = $bytes->read_str_array(5);
   $obj->{progress} = $bytes->read_double();
   $obj->{reqirement} = $bytes->read_double();
   $obj->{locked} = $bytes->read_int();
   $obj->{owned} = $bytes->read_int();
   $obj->{gems} = $bytes->read_double();
   #$obj->{refs} = $bun->read_obj_array($bytes, $ctx);
};

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
   1  => 'Debuff_Attack.png',
   2  => 'Debuff_Defense.png',
   3  => 'Buff_Speed.png',
   4  => 'Stun.png',
   6  => 'Damage_Over_Time.png',
   7  => 'Damage_Over_Time.png',
   9  => 'Heal_Over_Time.png',
   10 => 'Buff_Shield.png',
   11 => 'Buff_Counter.png',
   12 => 'Cleanse.png',
   13 => 'Dispell.png',
   14 => 'Buff_Attack.png',
   17 => 'Buff_Attack.png',
   20 => 'Buff_Attack.png',
   22 => 'Buff_Shield.png',
   23 => 'Buff_Attack.png',
   24 => 'Buff_Attack.png',
   25 => 'Buff_Attack.png',
   26 => 'Buff_Attack.png',
);

sub describe_buff {
   my ($buff, $targ, $opponent) = @_;
   my $type = $buff->{type};
   my $who = $targ ? $opponent : ($opponent eq "enemy" ? "hero" : "self");
   my $whose = $targ ? " ${opponent}'s" : "";
   my $whose2 = $whose || ($opponent eq "enemy" ? " hero's" : " own");
   my $time = format_time($buff->{duration});
   my $desc = '';
   if (my $icon = $buff_icons{$type}) {
      $desc = "[[File:$icon|24px]] ";
   }

   # source: BattleEffectLogic.calculateFinalStats
   if ($type == 0) {
      $desc .= sprintf "Reduce%s SPD by %g for %s",
         $whose2, $buff->{value1}, $time;
   }
   elsif ($type == 1) {
      $desc .= sprintf "Reduce%s STR and INT by %g for %s",
         $whose2, $buff->{value1}, $time;
   }
   elsif ($type == 2) {
      $desc .= sprintf "Reduce%s END and WIS by %g for %s",
         $whose2, $buff->{value1}, $time;
   }
   elsif ($type == 3) {
      $desc .= sprintf "Increase%s SPD by %g for %s",
         $whose, $buff->{value1}, $time;
   }
   elsif ($type == 4) {
      $desc .= sprintf "Stun%s for %s",
         $targ ? '' : ' self', $time;
   }
   elsif ($type == 5) {
      $desc .= sprintf "Deal %s damage/sec for %s",
         Grindia::numfmt($buff->{value1}), $time;
   }
   elsif ($type == 6) {
      $desc .= sprintf "Deal %s Physical damage/sec for %s",
         Grindia::numfmt($buff->{value1}), $time;
   }
   elsif ($type == 7) {
      $desc .= sprintf "Deal %s Magic damage/sec for %s",
         Grindia::numfmt($buff->{value1}), $time;
   }
   elsif ($type == 8) {
      $desc .= sprintf "Heal %s Health", Grindia::numfmt($buff->{value1});
   }
   elsif ($type == 9) {
      $desc .= sprintf "Heal %s Health/sec for %s",
         Grindia::numfmt($buff->{value1}), $time;
   }
   elsif ($type == 10) {
      $desc .= sprintf "Gain %g Shield", Grindia::numfmt($buff->{value1});
   }
   # type 11 PHYS_COUNTER unimplemented
   elsif ($type == 12) {
      $desc .= sprintf "Remove %g debuff%s from %s",
         $buff->{value1}, ($buff->{value1} > 1 && 's'), $who;
      $desc .= " within " . $time if $buff->{duration};
   }
   elsif ($type == 13) {
      $desc .= sprintf "Remove %g buff%s from %s",
         $buff->{value1}, ($buff->{value1} > 1 && 's'), $who;
      $desc .= " within " . $time if $buff->{duration};
   }
   elsif ($type == 14) {
      $desc .= sprintf "Increase%s %s for %s",
         $whose, two_vals($buff, 'STR', 'INT'), $time;
   }
   elsif ($type == 15) {
      $desc .= sprintf "Deal %g damage per debuff (max %g)",
         $buff->{value1}, $buff->{value2};
   }
   elsif ($type == 16) {
      $desc .= sprintf "Increase%s %s for %s",
         $whose, two_vals($buff, 'END', 'WIS'), $time;
   }
   elsif ($type == 17) {
      $desc .= sprintf "Increase%s Crit Chance by %g%% for %s",
         $whose, $buff->{value1}, $time;
   }
   elsif ($type == 18) {
      $desc .= sprintf "Increase END and WIS by %g%% for %s, "
         . "then deal %g%% magic damage",
         $buff->{value1}*100, $time, $buff->{value2}*100;
   }
   elsif ($type == 19) {
      $desc .= sprintf "Deal %g%% Magic damage/sec for %s, then deal %s%%",
         $buff->{value1}*100, $time, $buff->{value2}*100;
   }
   elsif ($type == 20) {
      $desc .= sprintf "Increase%s Dodge by %g%% for %s",
         $whose, $buff->{value1}, $time;
   }
   elsif ($type == 21) {
      $desc .= sprintf "Fill %g%% of%s attack bar", $buff->{value1}/10, $whose;
   }
   elsif ($type == 22) {
      $desc .= sprintf "Gain %g%% Shield/sec for %s",
         $buff->{value1}, $time;
   }
   elsif ($type == 23) {
      $desc .= sprintf "Increase%s %s for %s",
         $whose, two_vals($buff, 'END', 'WIS', '%'), $time;
   }
   elsif ($type == 24) {
      $desc .= sprintf "Increase%s %s for %s",
         $whose, two_vals($buff, 'STR', 'INT', '%'), $time;
   }
   elsif ($type == 25) {
      $desc .= sprintf "Decrease%s %s for %s",
         $whose2, two_vals($buff, 'END', 'WIS', '%'), $time;
   }
   elsif ($type == 26) {
      $desc .= sprintf "Decrease%s %s for %s",
         $whose2, two_vals($buff, 'STR', 'INT', '%'), $time;
   }
   # type 27 SHIELD_HEAL_PERCENT unimplemented
   elsif ($type == 28) {
      $desc .= sprintf "Increase%s Crit Damage by %g%% for %s",
         $whose, $buff->{value1}, $time;
   }
   elsif ($type == 29) {
      $desc .= sprintf "Decrease%s Crit Chance by %g%% for %s",
         $whose2, $buff->{value1}, $time;
   }
   elsif ($type == 30) {
      $desc .= sprintf "Decrease%s Crit Resist by %g%% for %s",
         $whose2, $buff->{value1}, $time;
   }
   elsif ($type == 31) {
      $desc .= sprintf "Reduce%s Healing by %g%% for %s",
         $whose2, $buff->{value1}*100, $time;
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

sub format_time {
   my ($t) = @_;
   return 'one timestep' unless $t;
   return sprintf '%g sec', $t if $t <= 120;
   return sprintf '%.0f min', $t/60 if $t <= 120*60;
   return sprintf '%.0f hr', $t/(60*60);
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
