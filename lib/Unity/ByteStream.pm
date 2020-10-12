package Unity::ByteStream;
use strict;
use warnings;
use Carp qw( croak );
use Encode qw( decode decode_utf8 );

sub new {
   my ($class, $file, $pos, $len) = @_;
   croak 'missing len' unless defined $len;
   my $self = bless { pos=>0 } => $class;
   seek $file, $pos, 0 or croak 'seek error';
   read($file, $self->{data}, $len) == $len or croak 'eof';
   return $self;
}

sub from_string {
   my ($class, $string) = @_;
   return bless { data=>$string, pos=>0 } => $class;
}

sub pad4 {
   my ($self) = @_;
   $self->{pos} = ($self->{pos} + 3) & ~3;
}

sub skip {
   my ($self, $len) = @_;
   $self->{pos} += $len;
   croak 'eof' if $self->{pos} > length($self->{data});
}

sub read_byte {
   my ($self) = @_;
   my $val = ord substr($self->{data}, $self->{pos}, 1);
   $self->{pos}++;
   croak 'eof' if $self->{pos} > length($self->{data});
   return $val;
}

sub read_short {
   my ($self) = @_;
   my $val = unpack 'v', substr($self->{data}, $self->{pos}, 2);
   $self->{pos} += 2;
   croak 'eof' unless defined $val;
   return $val;
}

sub read_int {
   my ($self) = @_;
   my $val = unpack 'V', substr($self->{data}, $self->{pos}, 4);
   $self->{pos} += 4;
   croak 'eof' unless defined $val;
   return $val;
}

sub read_byte_array {
   my ($self, $count) = @_;
   $count //= $self->read_int();
   my @ary;
   push @ary, $self->read_byte() for 1 .. $count;
   return \@ary;
}

sub read_int_array {
   my ($self, $count) = @_;
   $count //= $self->read_int();
   my @ary;
   push @ary, $self->read_int() for 1 .. $count;
   return \@ary;
}

sub read_long {
   my ($self) = @_;
   my $val = unpack 'Q<', substr($self->{data}, $self->{pos}, 8);
   $self->{pos} += 8;
   croak 'eof' unless defined $val;
   return $val;
}

sub read_float {
   my ($self) = @_;
   my $val = unpack 'f<', substr($self->{data}, $self->{pos}, 4);
   $self->{pos} += 4;
   croak 'eof' unless defined $val;
   return $val;
}

sub read_float_array {
   my ($self, $count) = @_;
   $count //= $self->read_int();
   my @ary;
   push @ary, $self->read_float() for 1 .. $count;
   return \@ary;
}

sub read_double {
   my ($self) = @_;
   my $val = unpack 'd<', substr($self->{data}, $self->{pos}, 8);
   $self->{pos} += 8;
   croak 'eof' unless defined $val;
   return $val;
}

sub read_double_array {
   my ($self, $count) = @_;
   $count //= $self->read_int();
   my @ary;
   push @ary, $self->read_double() for 1 .. $count;
   return \@ary;
}

sub read_bytes {
   my ($self, $len) = @_;
   my $val = substr($self->{data}, $self->{pos}, $len);
   $self->{pos} += $len;
   croak 'eof' if $self->{pos} > length($self->{data});
   return $val;
}

sub read_hex {
   my ($self, $len) = @_;
   my $val = unpack 'H*', substr($self->{data}, $self->{pos}, $len);
   $self->{pos} += $len;
   croak 'eof' if $self->{pos} > length($self->{data});
   return $val;
}

sub read_cstr {
   my ($self) = @_;
   pos($self->{data}) = $self->{pos};
   $self->{data} =~ /\G(.*?)\0/ or croak 'eof';
   $self->{pos} += length($1) + 1;
   return decode_utf8($1);
}

sub read_str {
   my ($self) = @_;
   my $len = unpack 'V', substr($self->{data}, $self->{pos}, 4);
   croak 'eof' unless defined $len;
   $self->{pos} += 4;
   my $str = decode_utf8(substr($self->{data}, $self->{pos}, $len));
   $self->{pos} = ($self->{pos} + $len + 3) & ~3;
   croak 'eof' if $self->{pos} > length($self->{data});
   return $str;
}

sub read_utf16 {
   my ($self) = @_;
   my $len = unpack('V', substr($self->{data}, $self->{pos}, 4)) * 2;
   croak 'eof' unless defined $len;
   $self->{pos} += 4;
   my $str = decode('utf16-le', substr($self->{data}, $self->{pos}, $len));
   $self->{pos} += $len;
   croak 'eof' if $self->{pos} > length($self->{data});
   return $str;
}

sub read_str_array {
   my ($self, $count) = @_;
   $count //= $self->read_int();
   my @ary;
   push @ary, $self->read_str() for 1 .. $count;
   return \@ary;
}

sub read_serialized {
   my ($self) = @_;
   my $len = $self->read_int();
   my $bytes = Unity::ByteStream->from_string($self->read_bytes($len));
   $self->pad4();
   $bytes->{types} = {};
   my ($val) = eval { $bytes->deserialize() };
   warn $@ if $@;
   return $val;
}

sub deserialize {
   my ($self) = @_;
   my $type = $self->read_byte();
   return if $type == 5 || $type == 7;
   my ($val, $lbl);
   if ($type & 1) {
      $self->skip(1);
      $lbl = $self->read_utf16();
      $type++;
   }
   if ($type == 2) {
      my $kind = $self->read_byte();
      my $typename;
      if ($kind == 0x2f) {
         my $num = $self->read_int();
         $self->skip(1);
         $typename = $self->read_utf16();
         $self->{types}{$num} = $typename;
      }
      elsif ($kind == 0x30) {
         my $num = $self->read_int();
         $typename = $self->{types}{$num} or die 'missing type';
      }
      else {
         die "wut? $kind";
      }
      $self->skip(4); # obj num
      $val = { _type => $typename };
      my $i = 0;
      while (my ($v, $n) = $self->deserialize()) {
         $n //= '_' . ++$i;
         $val->{$n} = $v;
      }
   }
   elsif ($type == 6) {
      $self->skip(8); # len
      $val = [ ];
      while (my ($v) = $self->deserialize()) {
         push @$val, $v;
      }
   }
   elsif ($type == 0xa) {
      $val = $self->read_int();
   }
   elsif ($type == 0x1e) {
      $val = $self->read_long();
   }
   elsif ($type == 0x20) {
      $val = $self->read_float();
   }
   elsif ($type == 0x22) {
      $val = $self->read_double();
   }
   elsif ($type == 0x2c) {
      $val = $self->read_byte();
   }
   elsif ($type == 0x2e) {
      # null
   }
   else {
      die "unknown type: $type";
   }
   return ($val, $lbl);
}

1 # end ByteStream.pm
