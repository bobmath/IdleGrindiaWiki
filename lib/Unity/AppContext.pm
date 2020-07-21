package Unity::AppContext;
use strict;
use warnings;
use Unity::AssetBundle;
use Carp qw( croak );

my $type_guid = 'f46e8e30ecc293493f18ab27134210ee';
my $label_guid = '0d9d880e077f33c76fc2c99bd629a50a';

sub new {
   my ($class, $dir) = @_;
   my $self = bless { } => $class;
   $self->{dir} = $dir ? $dir . '/' : '';
   $self->{bundles} = { };
   $self->{types} = { };
   $self->{load_later} = { };
   $self->{loaders} = { $type_guid=>\&read_type, $label_guid=>\&read_labels };
   return $self;
}

sub load_bundle {
   my ($self, $name, $filename) = @_;
   return unless $name;
   my $bun = $self->{bundles}{$name};
   return $bun if $bun;
   $filename = $self->{dir} . ($filename || $name);
   $self->{bundles}{$name} = $bun =
      Unity::AssetBundle->new($name, $filename, $self);
   my %types;
   $bun->for_type($self, $type_guid, sub {
      my ($obj) = @_;
      $types{$obj->{guid}} = $obj->{typename};
   });
   $self->set_types(\%types) if %types;
   return $bun;
}

sub set_types {
   my ($self, $types) = @_;
   while (my ($k, $v) = each %$types) {
      $self->{types}{$k} = $v;
   }
   foreach my $bun (values %{$self->{bundles}}) {
      $bun->set_types($types);
   }
}

sub set_loaders {
   my ($self, $loaders) = @_;
   while (my ($k, $v) = each %$loaders) {
      $self->{loaders}{$k} = $v;
   }
}

sub get_type {
   my ($self, $type) = @_;
   return unless $type;
   return $self->{types}{$type};
}

sub get_loader {
   my ($self, $type) = @_;
   return unless $type;
   return $self->{loaders}{$type};
}

sub for_type {
   my ($self, $type, $func, @args) = @_;
   foreach my $bun (values %{$self->{bundles}}) {
      $bun->for_type($self, $type, $func, @args);
   }
}

sub load_later {
   my ($self, $obj) = @_;
   # defer the load to prevent deep recursion
   my $name = $obj->{_bundle} or croak 'incomplete object';
   push @{$self->{load_later}{$name}}, $obj;
}

sub load_objects {
   my ($self) = @_;
   my $later = $self->{load_later};
   while (%$later) {
      foreach my $name (sort keys %$later) {
         my $objects = delete $later->{$name};
         my $bun = $self->{bundles}{$name} or die 'missing bundle';
         $bun->load_obj($_, $self) foreach @$objects;
      }
   }
}

sub find_labels {
   my ($self) = @_;
   foreach my $bun (values %{$self->{bundles}}) {
      $bun->for_type($self, $label_guid, sub { });
   }
}

sub read_type {
   my ($obj, $bytes, $bun, $ctx) = @_;
   $obj->{name} = $bytes->read_str();
   $obj->{unk} = $bytes->read_int();
   $obj->{guid} = $bytes->read_hex(16);
   $obj->{typename} = $bytes->read_str();
   $obj->{libname} = $bytes->read_str();
   $obj->{dllname} = $bytes->read_str();
}

sub read_labels {
   my ($obj, $bytes, $bun, $ctx) = @_;
   my $count = $bytes->read_int();
   for my $i (1 .. $count) {
      my $label = $bytes->read_str();
      my $ref = $bun->read_obj($bytes, $ctx, 1) or next;
      $ref->{_label} = $label;
   }
}

1 # end AppContext.pm
