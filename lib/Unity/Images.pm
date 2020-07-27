package Unity::Images;
use strict;
use warnings;
use Image::PNG::Libpng ();
use Image::PNG::Const qw( PNG_COLOR_TYPE_GRAY PNG_COLOR_TYPE_GRAY_ALPHA
   PNG_COLOR_TYPE_RGB PNG_COLOR_TYPE_RGB_ALPHA );

my $image_guid = 'ee6c40817d2951929cdb4f5a60874f5d';
our ($seen, $dir);

sub extract {
   my ($class, $ctx, $picdir) = @_;
   $picdir //= '' and $picdir .= '/';
   local $dir = $picdir;
   local $seen = {};
   $ctx->load_bundle('sharedassets0.assets');
   $ctx->load_bundle('sharedassets1.assets');
   $ctx->set_loaders({ $image_guid => \&load_image });
   $ctx->for_type($image_guid, sub { });
}

sub load_image {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $obj->{name} = $bytes->read_str();
   $obj->{a1} = $bytes->read_int();
   $obj->{a2} = $bytes->read_int();
   $obj->{wid} = $bytes->read_int();
   $obj->{hgt} = $bytes->read_int();
   $obj->{size} = $bytes->read_int();
   $obj->{format} = $bytes->read_int();
   $obj->{mipmaps} = $bytes->read_int();
   $obj->{"b$_"} = $bytes->read_int() for 1 .. 12;
   $obj->{size2} = $bytes->read_int();
   return unless $obj->{wid} && $obj->{hgt};
   die unless $obj->{size} == $obj->{size2};
   my $fmt = $obj->{format};
   if ($fmt == 1) {
      write_png($obj, $bytes, 1, PNG_COLOR_TYPE_GRAY);
   }
   elsif ($fmt == 2) {
      write_png($obj, $bytes, 2, PNG_COLOR_TYPE_GRAY_ALPHA);
   }
   elsif ($fmt == 3) {
      write_png($obj, $bytes, 3, PNG_COLOR_TYPE_RGB);
   }
   elsif ($fmt == 4) {
      write_png($obj, $bytes, 4, PNG_COLOR_TYPE_RGB_ALPHA);
   }
   elsif ($fmt == 10) {
      convert_bc1($obj, $bytes);
   }
   elsif ($fmt == 12) {
      convert_bc3($obj, $bytes);
   }
   else {
      print "$obj->{name}: unknown format $fmt\n";
   }
}

sub write_png {
   my ($obj, $bytes, $bpp, $type) = @_;
   my $png = Image::PNG::Libpng::create_write_struct();
   $png->set_IHDR({ height=>$obj->{hgt}, width=>$obj->{wid},
      bit_depth=>8, color_type=>$type });
   my $row = $obj->{wid} * $bpp;
   my @rows;
   for (my $i = $obj->{hgt}; $i; $i--) {
      $rows[$i-1] = $bytes->read_bytes($row);
   }
   $png->set_rows(\@rows);
   my $file = filename($obj->{name}) . '.png';
   $png->write_png_file($dir . $file);
}

sub filename {
   my ($name) = @_;
   $name = 'noname' if $name eq '';
   $name =~ s/[^-.\w]+/_/g;
   $name =~ s/^\./,/;
   my $uniq = $name;
   my $num = ($seen->{lc($name)} || 0) + 1;
   $uniq .= '-' . $num if $num > 1;
   while ($seen->{lc($uniq)}) {
      $num++;
      $uniq = "$name-$num";
   }
   $seen->{lc($uniq)} = 1;
   $seen->{lc($name)} = $num;
   return $uniq;
}

sub convert_bc1 {
   my ($obj, $bytes) = @_;
   my $wid = ($obj->{wid} + 3) & ~3;
   my $hgt = ($obj->{hgt} + 3) & ~3;
   my @bmp = (0) x ($wid * $hgt * 4);

   for (my $y = 0; $y < $hgt; $y += 4) {
      for (my $x = 0; $x < $wid; $x += 4) {
         my @buf = unpack 'v*', $bytes->read_bytes(8);
         my $set = $buf[0] > $buf[1];
         my $bits = $buf[0];
         my $r0 = 255/31*(($bits >> 11) & 0x1f);
         my $g0 = 255/63*(($bits >> 5) & 0x3f);
         my $b0 = 255/31*($bits & 0x1f);
         $bits = $buf[1];
         my $r1 = 255/31*(($bits >> 11) & 0x1f);
         my $g1 = 255/63*(($bits >> 5) & 0x3f);
         my $b1 = 255/31*($bits & 0x1f);
         $bits = $buf[2] | ($buf[3] << 16);
         for my $i (0 .. 3) {
            my $p = (($y + $i) * $wid + $x) * 4;
            for my $j (0 .. 3) {
               my $b = $bits & 3;
               $bits >>= 2;
               $bmp[$p+3] = 255;
               if ($b == 0) {
                  $bmp[$p+0] = $r0;
                  $bmp[$p+1] = $g0;
                  $bmp[$p+2] = $b0;
               }
               elsif ($b == 1) {
                  $bmp[$p+0] = $r1;
                  $bmp[$p+1] = $g1;
                  $bmp[$p+2] = $b1;
               }
               elsif ($b == 2) {
                  if ($set) {
                     $bmp[$p+0] = 2/3*$r0 + 1/3*$r1;
                     $bmp[$p+1] = 2/3*$g0 + 1/3*$g1;
                     $bmp[$p+2] = 2/3*$b0 + 1/3*$b1;
                  }
                  else {
                     $bmp[$p+0] = ($r0 + $r1) * 0.5;
                     $bmp[$p+1] = ($g0 + $g1) * 0.5;
                     $bmp[$p+2] = ($b0 + $b1) * 0.5;
                  }
               }
               elsif ($b == 3) {
                  if ($set) {
                     $bmp[$p+0] = 1/3*$r0 + 2/3*$r1;
                     $bmp[$p+1] = 1/3*$g0 + 2/3*$g1;
                     $bmp[$p+2] = 1/3*$b0 + 2/3*$b1;
                  }
                  else {
                     $bmp[$p+0] = 0;
                     $bmp[$p+1] = 0;
                     $bmp[$p+2] = 0;
                     $bmp[$p+3] = 0;
                  }
               }
               $p += 4;
            }
         }
      }
   }

   my $png = Image::PNG::Libpng::create_write_struct();
   $png->set_IHDR({ height=>$obj->{hgt}, width=>$obj->{wid},
      bit_depth=>8, color_type=>PNG_COLOR_TYPE_RGB_ALPHA });
   my $row = $obj->{wid} * 4;
   my @rows;
   for (my $y = $obj->{hgt} - 1; $y >= 0; $y--) {
      my $p = $y * $wid * 4;
      push @rows, pack 'C*', map $_+0.5, @bmp[$p .. $p+$row-1];
   }
   $png->set_rows(\@rows);
   my $file = filename($obj->{name}) . '.png';
   $png->write_png_file($dir . $file);
}

sub convert_bc3 {
   my ($obj, $bytes) = @_;
   my $wid = ($obj->{wid} + 3) & ~3;
   my $hgt = ($obj->{hgt} + 3) & ~3;
   my @bmp = (0) x ($wid * $hgt * 4);

   for (my $y = 0; $y < $hgt; $y += 4) {
      for (my $x = 0; $x < $wid; $x += 4) {
         my @buf = unpack 'v*', $bytes->read_bytes(16);

         my $a0 = $buf[0] & 0xff;
         my $a1 = ($buf[0] >> 8) & 0xff;
         my $bits = $buf[1] | ($buf[2] << 16);
         for my $i (0 .. 3) {
            my $p = (($y + $i) * $wid + $x) * 4 + 3;
            if ($i == 2) {
               $bits = ($bits & 0xff) | ($buf[3] << 8);
            }
            for my $j (0 .. 3) {
               my $b = $bits & 7;
               $bits >>= 3;
               if    ($b == 0) { $bmp[$p] = $a0 }
               elsif ($b == 1) { $bmp[$p] = $a1 }
               elsif ($a0 > $a1) {
                  if    ($b == 2) { $bmp[$p] = 6/7*$a0 + 1/7*$a1 }
                  elsif ($b == 3) { $bmp[$p] = 5/7*$a0 + 2/7*$a1 }
                  elsif ($b == 4) { $bmp[$p] = 4/7*$a0 + 3/7*$a1 }
                  elsif ($b == 5) { $bmp[$p] = 3/7*$a0 + 4/7*$a1 }
                  elsif ($b == 6) { $bmp[$p] = 2/7*$a0 + 5/7*$a1 }
                  elsif ($b == 7) { $bmp[$p] = 1/7*$a0 + 6/7*$a1 }
               }
               else {
                  if    ($b == 2) { $bmp[$p] = 4/5*$a0 + 1/5*$a1 }
                  elsif ($b == 3) { $bmp[$p] = 3/5*$a0 + 2/5*$a1 }
                  elsif ($b == 4) { $bmp[$p] = 2/5*$a0 + 3/5*$a1 }
                  elsif ($b == 5) { $bmp[$p] = 1/5*$a0 + 4/5*$a1 }
                  elsif ($b == 6) { $bmp[$p] = 0   }
                  elsif ($b == 7) { $bmp[$p] = 255 }
               }
               $p += 4;
            }
         }

         my $set = $buf[4] > $buf[5];
         $bits = $buf[4];
         my $r0 = 255/31*(($bits >> 11) & 0x1f);
         my $g0 = 255/63*(($bits >> 5) & 0x3f);
         my $b0 = 255/31*($bits & 0x1f);
         $bits = $buf[5];
         my $r1 = 255/31*(($bits >> 11) & 0x1f);
         my $g1 = 255/63*(($bits >> 5) & 0x3f);
         my $b1 = 255/31*($bits & 0x1f);
         $bits = $buf[6] | ($buf[7] << 16);
         for my $i (0 .. 3) {
            my $p = (($y + $i) * $wid + $x) * 4;
            for my $j (0 .. 3) {
               my $b = $bits & 3;
               $bits >>= 2;
               if ($b == 0) {
                  $bmp[$p+0] = $r0;
                  $bmp[$p+1] = $g0;
                  $bmp[$p+2] = $b0;
               }
               elsif ($b == 1) {
                  $bmp[$p+0] = $r1;
                  $bmp[$p+1] = $g1;
                  $bmp[$p+2] = $b1;
               }
               elsif ($b == 2) {
                  if ($set) {
                     $bmp[$p+0] = 2/3*$r0 + 1/3*$r1;
                     $bmp[$p+1] = 2/3*$g0 + 1/3*$g1;
                     $bmp[$p+2] = 2/3*$b0 + 1/3*$b1;
                  }
                  else {
                     $bmp[$p+0] = ($r0 + $r1) * 0.5;
                     $bmp[$p+1] = ($g0 + $g1) * 0.5;
                     $bmp[$p+2] = ($b0 + $b1) * 0.5;
                  }
               }
               elsif ($b == 3) {
                  if ($set) {
                     $bmp[$p+0] = 1/3*$r0 + 2/3*$r1;
                     $bmp[$p+1] = 1/3*$g0 + 2/3*$g1;
                     $bmp[$p+2] = 1/3*$b0 + 2/3*$b1;
                  }
                  else {
                     $bmp[$p+0] = 0;
                     $bmp[$p+1] = 0;
                     $bmp[$p+2] = 0;
                  }
               }
               $p += 4;
            }
         }
      }
   }

   my $png = Image::PNG::Libpng::create_write_struct();
   $png->set_IHDR({ height=>$obj->{hgt}, width=>$obj->{wid},
      bit_depth=>8, color_type=>PNG_COLOR_TYPE_RGB_ALPHA });
   my $row = $obj->{wid} * 4;
   my @rows;
   for (my $y = $obj->{hgt} - 1; $y >= 0; $y--) {
      my $p = $y * $wid * 4;
      push @rows, pack 'C*', map $_+0.5, @bmp[$p .. $p+$row-1];
   }
   $png->set_rows(\@rows);
   my $file = filename($obj->{name}) . '.png';
   $png->write_png_file($dir . $file);
}

1 # end Images.pm
