package Grindia::Data;
use utf8;
use strict;
use warnings;
use Scalar::Util qw( weaken );

our %typemap = (
   '86e34eb8ee7642b089fb98c9d81dd9b0' => 'graphic',
   '761ca81f78491542badc37f810ab3455' => 'imgtree',
   '7e050781d08ca9d10bc74beb7e91c3b5' => 'imgtree2',
);

our %loaders;

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
   $obj->{ary3} = $bytes->read_int_array(3);
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
   #$obj->{unlocks} = $bun->read_obj_array($bytes, $ctx);
};

1 # end Data.pm
