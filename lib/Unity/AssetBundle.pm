package Unity::AssetBundle;
use strict;
use warnings;
use Unity::ByteStream;
use Carp qw( croak );

sub new {
   my ($class, $name, $filename, $ctx) = @_;
   croak 'missing ctx' unless $ctx;
   my $self = bless { name=>$name } => $class;
   $filename ||= $name;
   open $self->{file}, '<:raw', $filename or croak "Can't read $filename: $!";
   read($self->{file}, my $bytes, 16);
   my ($hdr_len, $file_len, $magic, $offset) = unpack 'N*', $bytes;
   croak 'Bad bundle' if !defined($offset) || $magic != 0x15
      || $hdr_len < 19 || $offset < $hdr_len+19 || $file_len < $offset
      || $file_len < -s $self->{file};

   $bytes = Unity::ByteStream->new($self->{file}, 16, $hdr_len + 3);
   $bytes->skip(4);
   $bytes->read_cstr();
   $bytes->skip(5);

   my @types;
   my $count = $bytes->read_int();
   for my $i (1 .. $count) {
      my $type = { };
      $bytes->skip(5);
      my $kind = $bytes->read_short();
      my $guid = $bytes->read_hex(16);
      $guid = $bytes->read_hex(16) if $kind != 0xffff;
      push @types, $ctx->get_type($guid) || $guid;
   }

   $self->{objects} = {};
   $self->{bytype} = {};
   $count = $bytes->read_int();
   $bytes->pad4();
   for my $i (1 .. $count) {
      my $obj = {};
      $obj->{_bundle} = $name;
      $obj->{_num} = my $num = $bytes->read_long();
      $obj->{_pos} = $bytes->read_int() + $offset;
      $obj->{_len} = $bytes->read_int();
      my $typenum = $bytes->read_int();
      $self->{objects}{$num} = $obj;
      $obj->{_type} = my $type = $types[$typenum] or next;
      push @{$self->{bytype}{$type}}, $obj;
   }

   $count = $bytes->read_int();
   $bytes->skip($count * 12);

   $count = $bytes->read_int();
   $self->{bundles} = [$name];
   for my $i (1 .. $count) {
      $bytes->skip(21);
      push @{$self->{bundles}}, $bytes->read_cstr();
   }

   return $self;
}

sub for_type {
   my ($self, $ctx, $type, $func, @args) = @_;
   my $objects = $self->{bytype}{$type} or return;
   foreach my $obj (@$objects) {
      $self->load_obj($obj, $ctx);
      $ctx->load_objects();
      $func->($obj, @args);
   }
}

sub load_obj {
   my ($self, $obj, $ctx) = @_;
   return if $obj->{_loaded};
   $obj->{_loaded} = 1;
   my $loader = $ctx->get_loader($obj->{_type}) or return;
   my $bytes =
      Unity::ByteStream->new($self->{file}, $obj->{_pos}, $obj->{_len});
   $loader->($obj, $bytes, $self, $ctx);
}

sub set_types {
   my ($self, $types) = @_;
   my $bytype = $self->{bytype};
   while (my ($old, $new) = each %$types) {
      my $objects = delete $bytype->{$old} or next;
      die 'duplicate type' if $bytype->{$new};
      $bytype->{$new} = $objects;
      foreach my $obj (@$objects) {
         $obj->{_type} = $new;
      }
   }
}

sub read_obj {
   my ($self, $bytes, $ctx, $noload) = @_;
   croak 'missing ctx' unless $ctx;
   my $lib = $bytes->read_int();
   my $num = $bytes->read_long();
   my $bun = $ctx->load_bundle($self->{bundles}[$lib]) or return;
   my $obj = $bun->{objects}{$num} or return;
   return $obj if $noload || defined($obj->{_loaded});
   $obj->{_loaded} = 0;
   $ctx->load_later($obj);
   return $obj;
}

sub read_obj_array {
   my ($self, $bytes, $ctx, $count) = @_;
   $count //= $bytes->read_int();
   my @ary;
   push @ary, scalar($self->read_obj($bytes, $ctx)) for 1 .. $count;
   return \@ary;
}

sub close {
   my ($self) = @_;
   CORE::close $self->{file} if $self->{file};
   $self->{file} = undef;
}

1 # end AssetBundle.pm
