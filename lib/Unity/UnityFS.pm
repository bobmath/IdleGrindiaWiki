package Unity::UnityFS;
use strict;
use warnings;
use Compress::LZ4 qw( lz4_uncompress );
use Unity::UnityWeb;

sub extract {
   my ($file, $dir) = @_;
   $dir //= '' and $dir .= '/';
   open my $IN, '<:raw', $file or die "Can't read $file: $!";
   my $buf;
   read($IN, $buf, 12) == 12 and
   substr($buf, 0, 8) eq "UnityFS\0" or die 'Not a UnityFS file';
   local $/ = "\0";
   <$IN>; # unity version
   <$IN>; # generator version
   read($IN, $buf, 20) == 20 or die;
   my ($file_len, $clen, $ulen, $flags) = unpack('Q>N*', $buf);
   read($IN, $buf, $clen) == $clen or die;
   my $meta = lz4_uncompress($buf, $ulen) or die;
   my $num = unpack('N', substr($meta, 16, 4));
   my $pos = 20;

   my $outfile = $file;
   $outfile =~ s{^.*/}{};
   $outfile =~ s/\.unity3d$//;
   $outfile .= '.raw';
   $outfile = $dir . $outfile;
   open my $RAW, '+>:raw', $outfile or die "Can't write $outfile: $!";

   for my $i (1 .. $num) {
      ($ulen, $clen, $flags) = unpack('NNn', substr($meta, $pos, 10));
      $pos += 10;
      read($IN, $buf, $clen) == $clen or die 'missing data';
      $flags &= 0x3f;
      if ($flags == 0) {
         print $RAW $buf;
      }
      elsif ($flags == 2 || $flags == 3) {
         my $data = lz4_uncompress($buf, $ulen);
         die 'bad data' unless defined $data;
         print $RAW $data;
      }
      else { die 'bad compression mode' }
   }
   close $IN;

   $num = unpack('N', substr($meta, $pos, 4));
   $pos += 4;
   for my $i (1 .. $num) {
      my ($off, $len, $stat) = unpack 'Q>2N', substr($meta, $pos, 20);
      pos($meta) = $pos += 20;
      $meta =~ /\G(.*?)\0/gs or die 'missing filename';
      $pos = pos($meta);
      $outfile = $1;
      $outfile =~ s/[^-.\w]/_/g;
      seek($RAW, $off, 0) or die 'missing data';
      Unity::UnityWeb::copy_data($RAW, $len, $dir . $outfile);
   }
   close $RAW;
}

1 # end UnityFS.pm
