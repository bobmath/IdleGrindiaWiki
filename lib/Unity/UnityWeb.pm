package Unity::UnityWeb;
use strict;
use warnings;

sub extract {
   my ($file, $dir) = @_;
   $dir //= '' and $dir .= '/';
   my $IN = open_gzipped($file, $dir);
   my $buf;
   read($IN, $buf, 20) == 20 or die;
   substr($buf, 0, 16) eq "UnityWebData1.0\0" or die 'Not a UnityWeb file';
   my $len = unpack('V', substr($buf, 16, 4)) - 20;
   read($IN, $buf, $len) == $len or die 'missing header';
   my $pos = 0;
   while ($pos < $len) {
      my ($file_off, $file_len, $name_len) =
         unpack 'V*', substr($buf, $pos, 12);
      $pos += 12;
      die 'bad header' if $pos + $name_len > $len;
      my $file_name = substr($buf, $pos, $name_len);
      $pos += $name_len;
      $file_name =~ s/[^-.\w]/_/g;
      seek($IN, $file_off, 0) or die 'bad file offset';
      copy_data($IN, $file_len, $dir . $file_name);
   }
   close $IN;
}

sub open_gzipped {
   my ($file, $dir) = @_;
   open my $IN, '<:raw', $file or die "Can't read $file: $!\n";
   my $buf;
   read($IN, $buf, 2) == 2 or die;
   if ($buf eq "\x1f\x8b") {
      require IO::Uncompress::Gunzip;
      my $out_file = $dir ? $dir . $file : $file . '.unz';
      seek($IN, 0, 0) or die;
      open my $OUT, '+>:raw', $out_file or die "Can't write $out_file: $!";
      IO::Uncompress::Gunzip::gunzip($IN, $OUT)
         or die "gunzip failed: $IO::Uncompress::GunzipGunzipError";
      close $IN;
      $IN = $OUT;
   }
   seek($IN, 0, 0) or die;
   return $IN;
}

sub copy_data {
   my ($IN, $len, $file) = @_;
   open my $OUT, '>:raw', $file or die "Can't write $file: $!\n";
   my $want = 4096;
   my $buf;
   while ($len > 0) {
      $want = $len if $want > $len;
      my $size = read($IN, $buf, $want) or die 'missing data';
      $len -= $size;
      print $OUT $buf;
   }
   close $OUT;
}

1 # end UnityWeb.pm
