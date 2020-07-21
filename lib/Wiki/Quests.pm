package Wiki::Quests;
use utf8;
use strict;
use warnings;

sub build {
   my ($ctx) = @_;
   open my $OUT, '>:utf8', 'wiki/Quests' or die;
   print $OUT qq[{| class="wikitable"\n];
   $ctx->for_type('TitleMetaData', sub {
      my ($obj) = @_;
      my $text = $obj->{text};
      print $OUT "|-\n",
         "| $text->[0]\n",
         "| $text->[3]\n",
         "| $text->[4]\n",
         "| {{Gem|$obj->{gems}}}\n",
   });
   print $OUT qq[|}\n];
   close $OUT;
}

1 # end Quests.pm
