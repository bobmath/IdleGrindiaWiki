package Unity::Metadata;
use strict;
use warnings;
use Data::Dumper qw( Dumper );
use Encode qw( decode_utf8 );

sub extract {
   my ($class, $metafile, $codedir, $metadir) = @_;
   $codedir //= '' and $codedir .= '/';
   $metadir //= '' and $metadir .= '/';
   my $meta = {};
   read_meta($meta, $metafile);
   read_strings($meta);
   read_typedefs($meta);
   read_methods($meta);
   read_mem($meta, $codedir . 'mem0');
   find_typeinfo($meta);
   find_codeinfo($meta);
   read_generics($meta);
   read_interfaces($meta);
   read_fields($meta);
   read_events($meta);
   read_nested_types($meta);
   read_params($meta);
   read_properties($meta);
   read_defaults($meta);
   read_usage($meta);
   get_gen_methods($meta);
   get_type_layouts($meta);
   get_interop($meta);
   read_code($meta, $codedir);
   write_types($meta, 'types.txt');
   write_record($metadir . 'memtables.txt', $meta->{memtables});
   write_records($metadir, 'typeinfo', $meta->{typeinfo});
   write_records($metadir, 'typedefs', $meta->{typedefs});
   write_records($metadir, 'methods', $meta->{methods});
   write_records($metadir, 'specs', $meta->{meth_specs});
   write_records($metadir, 'usage', $meta->{usage_lists});
}

sub write_types {
   my ($meta, $file) = @_;
   open my $OUT, '>:utf8', $file or die $!;
   foreach my $type (@{$meta->{typedefs}}) {
      print $OUT "name: $type->{name}\n";
      print $OUT "parent: $type->{parent_type}\n" if $type->{parent_type};
      if (my $interfaces = $type->{interfaces}) {
         print $OUT "interface: @$interfaces\n";
      }

      if (my $fields = $type->{fields}) {
         print $OUT "fields:\n";
         foreach my $fld (@$fields) {
            my $type = $fld->{type};
            if (defined(my $val = $fld->{default})) {
               if ($val =~ /[^\x21-\x7e]/) {
                  $val =~ s/([^\x20-\x7e]|[\\"])/sprintf "\\x%02x", ord($1)/eg;
                  $val = qq["$val"];
               }
               $type .= ' = ' . $val;
            }
            $type .= '  static' if $fld->{static};
            printf $OUT "  %-16s  %s  %d\n", $fld->{name}, $type,
               $fld->{offset} // -1;
         }
      }

      if (my $props = $type->{properties}) {
         print $OUT "properties:\n";
         foreach my $prop (@$props) {
            print $OUT "  $prop->{name}\n";
         }
      }

      if (my $events = $type->{events}) {
         print $OUT "events:\n";
         foreach my $evt (@$events) {
            print $OUT "  $evt->{name}\n";
         }
      }

      my $methods = get_slice($meta->{methods},
         $type->{method_start}, $type->{method_count});
      if ($methods) {
         print $OUT "methods:\n";
         foreach my $meth (@$methods) {
            printf $OUT "  %-16s  %s  %d\n", $meth->{name},
               $meth->{return_type}, $meth->{method_num} // -1;
            my $params = $meth->{params} or next;
            foreach my $param (@$params) {
               printf $OUT "    %-16s  %s\n", $param->{name}, $param->{type};
            }
            if (my $inst = $meth->{instants}) {
               foreach my $sig (sort keys %$inst) {
                  my $info = $inst->{$sig};
                  printf $OUT "  %-16s  %d\n", $meth->{basename} . $sig,
                     $info->{method_num} // -1;
               }
            }
         }
      }

      if (my $inst = $type->{instants}) {
         foreach my $sig (sort keys %$inst) {
            print $OUT $type->{basename}, $sig, "\n";
            my $methods = $inst->{$sig};
            foreach my $name (sort keys %$methods) {
               my $info = $methods->{$name};
               printf $OUT "  %-16s  %d\n", $name,
                  $info->{method_num} // -1;
            }
         }
      }

      print $OUT "\n";
   }
   close $OUT;
}

my %globals = (
   7 => 'stack_top',
   9 => 'exception',
   12 => 'NaN',
   13 => 'Inf',
);

sub read_code {
   my ($meta, $dir) = @_;
   # track down indirect calls created by emscripten
   local $_;
   open my $TBL, '<:utf8', $dir . 'element.txt' or return;
   print "Reading code\n";
   my @table;
   while (<$TBL>) {
      /^elem \d+ func (\d+)/ or next;
      push @table, $1;
   }
   close $TBL;

   my %dyncalls;
   open my $IN, '<:utf8', $dir . 'code.txt' or return;
   my $curr = '';
   while (<$IN>) {
      if (/^func \d+ (\S*)/) {
         $curr = $1;
         $curr =~ s/^dynCall_// or $curr = '';
      }
      elsif ($curr && /call_indirect \{\(loc0 & (\d+)\) \+ (\d+)\}/) {
         $dyncalls{$curr} = [ @table[$2 .. $2+$1] ];
      }
      elsif ($curr && /call_indirect \{loc0 & (\d+)\}/) {
         $dyncalls{$curr} = [ @table[0 .. $1] ];
      }
   }

   my %funcs;
   foreach my $meth (@{$meta->{methods}}) {
      if (defined(my $ptr = $meth->{method_ptr})) {
         my $num = $dyncalls{$meth->{shortsig}}[$ptr];
         $meth->{method_num} = $num;
         $funcs{$num} = $meth->{_owner} . '.' . $meth->{name}
            if defined $num;
      }
      my $inst = $meth->{instants} or next;
      foreach my $sig (sort keys %$inst) {
         my $info = $inst->{$sig};
         my $num = $dyncalls{$info->{shortsig}}[$info->{method_ptr}];
         $info->{method_num} = $num;
         $funcs{$num} = $meth->{_owner} . '.' . $meth->{basename} . $sig
            if defined $num;
      }
   }

   foreach my $type (@{$meta->{typedefs}}) {
      my $inst = $type->{instants} or next;
      foreach my $sig (sort keys %$inst) {
         my $methods = $inst->{$sig};
         foreach my $name (sort keys %{$methods}) {
            my $info = $methods->{$name};
            my $num = $dyncalls{$info->{shortsig}}[$info->{method_ptr}];
            $info->{method_num} = $num;
            $funcs{$num} = $type->{basename} . $sig . '.' . $name
               if defined $num;
         }
      }
   }

   print "Annotating code\n";
   seek($IN, 0, 0) or die $!;
   open my $OUT, '>:utf8', $dir . 'anno.txt'
      or die "Can't write ${dir}anno.txt: $!\n";
   while (<$IN>) {
      chomp;
      if (/\b(?:func|call) (\d+)/) {
         my $name = $funcs{$1};
         $_ .= ' # ' . $name if defined $name;
      }
      elsif (/\binvoke_(\w+) \((\d+)/) {
         my $func = $dyncalls{$1}[$2];
         $_ .= ' # ' . ($funcs{$func} // $func) if defined $func;
      }
      elsif (/\bglob(\d+)\b/) {
         my $glob = $globals{$1};
         $_ .= ' # ' . $glob if defined $glob;
      }
      print $OUT $_, "\n";
   }
   close $OUT;
   close $IN;
}

my %usage_type = (
   1 => 'type_info',
   2 => 'il2cpp_type',
   3 => 'method_def',
   4 => 'field',
   5 => 'string',
   6 => 'method_ref',
);

sub read_usage {
   my ($meta) = @_;

   $meta->{usage_lists} = my $lists = read_records($meta, 'usage_lists', [
      ['usage_start', 'l'],
      ['usage_count', 'l'] ]);

   my $pairs = read_records($meta, 'usage_pairs', [
      ['dest_idx', 'l'],
      ['src_idx', 'L'] ]);
   foreach my $pair (@$pairs) {
      my $idx = $pair->{src_idx};
      my $type = $idx >> 29;
      $pair->{src_type} = $usage_type{$type};
      $pair->{src_idx} = $idx &= 0x1fffffff;
      if ($type == 1) {
         $pair->{src} = $meta->{typeinfo}[$idx]{name};
      }
      elsif ($type == 5) {
         $pair->{src} = $meta->{ustrings}{$idx};
      }
   }

   foreach my $list (@$lists) {
      $list->{usage} = get_slice($pairs,
         $list->{usage_start}, $list->{usage_count});
   }
}

sub read_interfaces {
   my ($meta) = @_;
   my $typenames = $meta->{typenames} or die;
   my $interfaces = read_types($meta, 'interfaces');
   my $interface_offsets = read_records($meta, 'interface_offsets', [
      ['type_idx', 'l'],
      ['offset', 'l'] ]);
   foreach my $off (@$interface_offsets) {
      $off->{type} = $typenames->[$off->{type_idx}];
   }
   foreach my $type (@{$meta->{typedefs}}) {
      $type->{interfaces} = get_slice($interfaces,
         $type->{interface_start}, $type->{interface_count});
      $type->{interface_offsets} = get_slice($interface_offsets,
         $type->{interface_offset_start}, $type->{interface_offset_count});
   }
}

sub get_type_layouts {
   my ($meta) = @_;
   my $len = length($meta->{mem}) or die 'missing mem';
   my $ptrs = get_ints($meta, 'typedef_sizes');
   for my $i (0 .. $#$ptrs) {
      my $ptr = $ptrs->[$i];
      next if !$ptr || $ptr >= $len;
      my $type = $meta->{typedefs}[$i] or die;
      $type->{size} = [ unpack 'l<*', substr($meta->{mem}, $ptr, 16) ];
      # 0: instance size, 1: serialized size, 2: static size
   }

   $ptrs = get_ints($meta, 'field_offsets');
   for my $i (0 .. $#$ptrs) {
      my $ptr = $ptrs->[$i];
      next if !$ptr || $ptr >= $len;
      my $type = $meta->{typedefs}[$i] or die;
      my @off = unpack 'V*',
         substr($meta->{mem}, $ptr, 4*$type->{field_count});
      for my $j (0 .. $#off) {
         my $fld = $type->{fields}[$j] or die;
         $fld->{offset} = $off[$j];
      }
   }
}

sub read_defaults {
   my ($meta) = @_;
   my $data = read_bytes($meta, 'defaults');

   my $field_defaults = read_records($meta, 'field_defaults', [
      ['field_idx', 'l'],
      ['type_idx', 'l'],
      ['data_idx', 'l'] ]);
   my $param_defaults = read_records($meta, 'param_defaults', [
      ['param_idx', 'l'],
      ['type_idx', 'l'],
      ['data_idx', 'l'] ]);

   foreach my $def (@$field_defaults, @$param_defaults) {
      my $owner;
      if (defined(my $idx = $def->{field_idx})) {
         $owner = $meta->{fields}[$idx];
      }
      elsif (defined($idx = $def->{param_idx})) {
         $owner = $meta->{params}[$idx];
      }
      die unless $owner;
      #$owner->{default_info} = $def;
      $def->{type} = my $type = $meta->{typenames}[$def->{type_idx}] or next;
      my $off = $def->{data_idx};
      next if $off < 0;
      my $val;
      if ($type eq 'System.Byte' || $type eq 'System.Boolean') {
         $val = ord(substr($data, $off, 1));
      }
      elsif ($type eq 'System.SByte') {
         $val = unpack('c', substr($data, $off, 1));
      }
      elsif ($type eq 'System.Int16') {
         $val = unpack('s<', substr($data, $off, 2));
      }
      elsif ($type eq 'System.UInt16' || $type eq 'System.Char') {
         $val = unpack('S<', substr($data, $off, 2));
      }
      elsif ($type eq 'System.Int32') {
         $val = unpack('l<', substr($data, $off, 4));
      }
      elsif ($type eq 'System.UInt32') {
         $val = unpack('L<', substr($data, $off, 4));
      }
      elsif ($type eq 'System.Int64') {
         $val = unpack('q<', substr($data, $off, 8));
      }
      elsif ($type eq 'System.UInt64') {
         $val = unpack('Q<', substr($data, $off, 8));
      }
      elsif ($type eq 'System.Single') {
         $val = unpack('f<', substr($data, $off, 4));
      }
      elsif ($type eq 'System.Double') {
         $val = unpack('d<', substr($data, $off, 8));
      }
      elsif ($type eq 'System.String') {
         my $len = unpack('V', substr($data, $off, 4));
         $val = decode_utf8(substr($data, $off+4, $len));
      }
      $owner->{default} = $val;
   }
}

sub read_methods {
   my ($meta) = @_;
   my $strings = $meta->{strings};
   $meta->{methods} = my $methods = read_records($meta, 'methods', [
      ['name_off', 'l'],
      ['declaring_type_idx', 'l'],
      ['return_type_idx', 'l'],
      ['param_start', 'l'],
      ['generic_idx', 'l'],
      ['method_idx', 'l'],
      ['invoker_idx', 'l'],
      ['delegate_idx', 'l'],
      ['rgctx_start', 'l'],
      ['rgctx_count', 'l'],
      ['token', 'L'],
      ['flags', 'S'],
      ['iflags', 'S'],
      ['slot', 's'],
      ['param_count', 'S'] ]);

   foreach my $meth (@$methods) {
      $meth->{basename} = $meth->{name} = $strings->{$meth->{name_off}};
      $meth->{declaring_type} =
         $meta->{typedefs}[$meth->{declaring_type_idx}]{name};
      $meth->{static} = 1 if $meth->{flags} & 0x10;
      # 0x0007: access
      # 0x0008: unmanaged export
      # 0x0010: static
      # 0x0020: final
      # 0x0040: virtual
      # 0x0080: hide by signature
      # 0x0100: don't reuse vtable slots
      # 0x0200: strict
      # 0x0400: abstract
      # 0x0800: special name
      # 0x1000: runtime special name
      # 0x2000: pinvoke
      # 0x4000: has security
      # 0x8000: requires security object
      # iflags:
      # 0x0003: type (0=cil, 1=native, 3=runtime)
      # 0x0004: unmanaged
      # 0x0010: forward ref
      # 0x0020: synchronized
      # 0x1000: static?
   }

   foreach my $type (@{$meta->{typedefs}}) {
      my $count = $type->{method_count} or next;
      my $start = $type->{method_start};
      my $type_idx = $type->{_num};
      my $type_name = $type->{name};
      for my $idx ($start .. $start+$count-1) {
         my $meth = $methods->[$idx] or die;
         $meth->{_owner_idx} = $type_idx;
         $meth->{_owner} = $type_name;
      }
   }
}

my %typechars = (
   'System.Int64'  => 'j',
   'System.UInt64' => 'j',
   'System.Single' => 'f',
   'System.Double' => 'd',
   'System.Void'   => 'v',
);

sub read_params {
   my ($meta) = @_;
   my $strings = $meta->{strings} or die;
   my $typenames = $meta->{typenames} or die;

   $meta->{params} = my $params = read_records($meta, 'params', [
      ['name_off', 'l'],
      ['token', 'L'],
      ['type_idx', 'l'] ]);

   foreach my $param (@$params) {
      $param->{name} = $strings->{$param->{name_off}};
      $param->{type} = $typenames->[$param->{type_idx}];
   }

   $meta->{invokers} = my $invokers = {};
   foreach my $meth (@{$meta->{methods}}) {
      $meth->{return_type} = $typenames->[$meth->{return_type_idx}];
      my $sig = $typechars{$meth->{return_type}} || 'i';
      $sig .= 'i' unless $meth->{static};
      $meth->{params} = my $args = get_slice($params,
         $meth->{param_start}, $meth->{param_count});
      foreach my $arg (@$args) {
         $sig .= $typechars{$arg->{type}} || 'i';
      }
      $sig .= 'i';
      $meth->{shortsig} = $sig;
      my $inv = $meth->{invoker_idx};
      $invokers->{$inv} = $sig if $inv >= 0;
   }
}

sub read_mem {
   my ($meta, $file) = @_;
   print "Reading mem0\n";
   open my $IN, '<:raw', $file or die "Can't read $file: $!";
   local $/ = undef;
   $meta->{mem} = <$IN>;
   close $IN;
}

sub get_gen_methods {
   my ($meta) = @_;
   my $methods = $meta->{methods} or die;
   my $geninsts = $meta->{geninsts} or die;
   my $table = $meta->{memtables}{meth_specs} or die;
   my $ptr = $table->{off};
   $meta->{meth_specs} = my $meth_specs = [];
   for my $i (1 .. $table->{count}) {
      my ($meth_idx, $class_sig, $meth_sig) =
         unpack 'l<*', substr($meta->{mem}, $ptr, 12);
      $ptr += 12;
      my $meth = $methods->[$meth_idx] or die;
      my $info = { invoker=>-1, shortsig=>-1, method_ptr=>-1 };
      my $spec = {
         method => $meth->{basename},
         method_idx => $meth_idx,
         class_sig_idx => $class_sig,
         method_sig_idx => $meth_sig,
         info => $info,
         unused => 1,
      };
      push @$meth_specs, $spec;
      if ($class_sig >= 0) {
         $spec->{class_sig} = my $sig = $geninsts->[$class_sig];
         my $type = $meta->{typedefs}[$meth->{_owner_idx}] or die;
         $type->{instants}{$sig}{$meth->{basename}} = $info;
      }
      if ($meth_sig >= 0) {
         $spec->{method_sig} = my $sig = $geninsts->[$meth_sig];
         $meth->{instants}{$sig} = $info;
      }
   }

   my $meth_ptrs = get_ints($meta, 'gen_meth_ptrs');
   $table = $meta->{memtables}{gen_meth_tbl} or die;
   $ptr = $table->{off};
   for my $i (1 .. $table->{count}) {
      my ($spec_idx, $methptr_idx, $invoker_idx) =
         unpack 'l<*', substr($meta->{mem}, $ptr, 12);
      $ptr += 12;
      my $spec = $meth_specs->[$spec_idx] or die;
      $spec->{unused} = 0;
      my $info = $spec->{info};
      $info->{method_ptr} = $meth_ptrs->[$methptr_idx];
      $info->{invoker} = $invoker_idx;
      $info->{shortsig} = $meta->{invokers}{$invoker_idx} || $invoker_idx;
   }
}

sub get_ints {
   my ($meta, $name) = @_;
   my $table = $meta->{memtables}{$name} or die;
   return [ unpack 'V*',
      substr($meta->{mem}, $table->{off}, 4*$table->{count}) ];
}

sub get_interop {
   my ($meta) = @_;
   my $table = $meta->{memtables}{interop_data} or die;
   my $typelookup = $meta->{typelookup} or die;
   my $ptr = $table->{off};
   foreach my $i (0 .. $table->{count}-1) {
      my @data = unpack 'V*', substr($meta->{mem}, $ptr, 4*7);
      $ptr += 4*7;
      my $addr = pop @data;
      my $type = $typelookup->{$addr} or next;
      $type->{interop} = \@data;
   }
}

sub find_codeinfo {
   my ($meta) = @_;
   die 'missing mem' unless exists $meta->{mem};
   my $memlen = length($meta->{mem});
   my $methods = $meta->{methods} or die 'missing methods';
   my $meth_count = 0;
   for my $meth (@$methods) {
      my $idx = $meth->{method_idx};
      $meth_count++ if $idx >= 0;
   }

   my $search = pack 'V', $meth_count;
   my (@hdr, @ptrs);
   my $pos = -1;
   SEARCH: while (1) {
      $pos = index($meta->{mem}, $search, $pos+1);
      die 'code header not found' if $pos < 0;
      next if $pos & 3;
      @hdr = unpack 'V*', substr($meta->{mem}, $pos, 4*2*7);
      for (my $j = 1; $j < 14; $j += 2) {
         my $ptr = $hdr[$j];
         next SEARCH if ($ptr & 3) || $ptr >= $memlen;
      }
      @ptrs = unpack 'V*', substr($meta->{mem}, $hdr[1], $hdr[0]*4);
      foreach my $ptr (@ptrs) {
         next SEARCH if $ptr > $meth_count;
      }
      $meta->{memtables}{code_info} = { count=>7, off=>$pos };
      last;
   }

   my @tables = qw( meth_ptrs rev_invokers gen_meth_ptrs invokers attr_gen
      uvc_ptrs interop_data );
   for my $i (0 .. 6) {
      $meta->{memtables}{$tables[$i]} =
         { count => $hdr[2*$i], off => $hdr[2*$i+1] };
   }

   foreach my $meth (@$methods) {
      my $idx = $meth->{method_idx};
      $meth->{method_ptr} = $ptrs[$idx] if $idx >= 0;
   }
}

sub find_typeinfo {
   my ($meta) = @_;
   die 'missing mem' unless exists $meta->{mem};
   my $memlen = length($meta->{mem});
   my $typedefs = $meta->{typedefs} or die 'missing typedefs';
   my $search = pack 'V', scalar @$typedefs;
   my (@hdr, @ptrs);
   my $pos = 39;
   SEARCH: while (1) {
      $pos = index($meta->{mem}, $search, $pos+1);
      die 'typeinfo not found' if $pos < 0;
      next if $pos & 3;
      @hdr = unpack 'V*', substr($meta->{mem}, $pos-40, 64);
      next unless $hdr[12] == @$typedefs;
      for (my $j = 1; $j < 16; $j += 2) {
         my $ptr = $hdr[$j];
         next SEARCH if ($ptr & 3) || $ptr >= $memlen;
      }
      @ptrs = unpack 'V*', substr($meta->{mem}, $hdr[7], $hdr[6]*4);
      foreach my $ptr (@ptrs) {
         next SEARCH if ($ptr & 3) || $ptr >= $memlen;
      }
      $meta->{memtables}{type_info} = { count=>8, off=>$pos-40 };
      last;
   }

   my @tables = qw( gen_classes gen_insts gen_meth_tbl typeinfo meth_specs
      field_offsets typedef_sizes meta_usages );
   for my $i (0 .. 7) {
      $meta->{memtables}{$tables[$i]} =
         { count => $hdr[2*$i], off => $hdr[2*$i+1] };
   }

   my @insts = unpack 'V*', substr($meta->{mem}, $hdr[3], 4*$hdr[2]);
   $meta->{genlookup} = my $genlookup = {};
   foreach my $ptr (@insts) {
      my ($argc, $argp) = unpack 'V*', substr($meta->{mem}, $ptr, 8);
      my @args = unpack 'V*', substr($meta->{mem}, $argp, $argc*4);
      $genlookup->{$ptr} = { args=>\@args };
   }
   $meta->{typeinfo} = my $typeinfo = [];
   $meta->{typelookup} = my $typelookup = {};
   foreach my $ptr (@ptrs) {
      my ($idx, $flags) = unpack 'V*', substr($meta->{mem}, $ptr, 8);
      push @$typeinfo, $typelookup->{$ptr} = { idx=>$idx, flags=>$flags };
   }
   $meta->{geninsts} = my $geninsts = [];
   foreach my $ptr (@insts) {
      push @$geninsts, scalar gen_inst($meta, $ptr);
   }
   $meta->{typenames} = my $typenames = [];
   foreach my $ptr (@ptrs) {
      push @$typenames, scalar type_name($meta, $ptr);
   }
}

sub gen_name {
   my ($meta, $ptr) = @_;
   my ($idx, $inst) = unpack 'V*', substr($meta->{mem}, $ptr, 8);
   my $type = $meta->{typedefs}[$idx];
   return ($type->{basename} || '???') . gen_inst($meta, $inst);
}

sub gen_inst {
   my ($meta, $ptr) = @_;
   my $info = $meta->{genlookup}{$ptr} or die;
   return $info->{name} if exists $info->{name};
   $info->{name} = '<?>';
   my @args = map type_name($meta, $_), @{$info->{args}};
   return $info->{name} = '<' . join(',', @args) . '>';
}

sub array_name {
   my ($meta, $ptr) = @_;
   my ($type, $rank) = unpack 'V*', substr($meta->{mem}, $ptr, 8);
   my $name = type_name($meta, $type);
   my $args = ',' x ($rank-1);
   return $name . "[$args]";
}

my %iltypes = (
   0x00 => 'end',
   0x01 => 'void',
   0x02 => 'boolean',
   0x03 => 'char',
   0x04 => 'i1',
   0x05 => 'u1',
   0x06 => 'i2',
   0x07 => 'u2',
   0x08 => 'i4',
   0x09 => 'u4',
   0x0a => 'i8',
   0x0b => 'u8',
   0x0c => 'r4',
   0x0d => 'r8',
   0x0e => 'string',
   0x0f => 'ptr',
   0x10 => 'byref',
   0x11 => 'valuetype',
   0x12 => 'class',
   0x13 => 'var',
   0x14 => 'array',
   0x15 => 'genericinst',
   0x16 => 'typedbyref',
   0x18 => 'i',
   0x19 => 'u',
   0x1b => 'fnptr',
   0x1c => 'object',
   0x1d => 'szarray',
   0x1e => 'mvar',
   0x1f => 'cmod_reqd',
   0x20 => 'cmod_opt',
   0x21 => 'internal',
   0x40 => 'modifier',
   0x41 => 'sentinel',
   0x45 => 'pinned',
   0x55 => 'enum',
);

sub type_name {
   my ($meta, $ptr) = @_;
   my $info = $meta->{typelookup}{$ptr} or return '???';
   return $info->{name} if exists $info->{name};
   my $idx = $info->{idx};
   my $type = $meta->{typedefs}[$idx];
   my $name = $info->{name} = $type->{basename} || "?$idx";
   $type = ($info->{flags} >> 16) & 0xff;
   $info->{type} = $iltypes{$type} || $type;
   $info->{attrs} = $info->{flags} & 0xffff;
   $info->{mods} = ($info->{flags} >> 24) & 0x3f;
   if ($type == 0xf) {
      $name = '*' . type_name($meta, $idx);
   }
   elsif ($type == 0x14) {
      $name = array_name($meta, $idx);
   }
   elsif ($type == 0x15) {
      $name = gen_name($meta, $idx);
   }
   elsif ($type == 0x1d) {
      $name = type_name($meta, $idx) . '[]';
   }
   $name ||= "?$idx";
   $name = '&' . $name if $info->{flags} & 0x40000000;
   $name = '!' . $name if $info->{flags} & 0x80000000;
   return $info->{name} = $name;
}

sub read_generics {
   my ($meta) = @_;
   my $strings = $meta->{strings} or die;

   my $generics = read_records($meta, 'generics', [
      ['owner', 'l'],
      ['param_count', 'l'],
      ['is_method', 'l'],
      ['param_start', 'l'] ]);

   my $gen_params = read_records($meta, 'gen_params', [
      ['owner', 'l'],
      ['name_off', 'l'],
      ['constraint_start', 's'],
      ['constraint_count', 's'],
      ['num', 's'],
      ['flags', 's'] ]);
   foreach my $param (@$gen_params) {
      $param->{name} = $strings->{$param->{name_off}};
   }

   my $constraints = read_types($meta, 'gen_constraints');
   foreach my $param (@$gen_params) {
      $param->{constraints} = get_slice($constraints,
         $param->{constraint_start}, $param->{constraint_count});
   }

   foreach my $gen (@$generics) {
      $gen->{params} = my $params = get_slice($gen_params,
         $gen->{param_start}, $gen->{param_count});
      $gen->{signature} = '<' .  join(',', map { $_->{name} } @$params) . '>';
   }

   foreach my $obj (@{$meta->{typedefs}}, @{$meta->{methods}}) {
      my $idx = $obj->{generic_idx};
      next if $idx < 0;
      $obj->{generic} = my $gen = $generics->[$idx];
      $obj->{name} .= $gen->{signature};
   }
}

sub read_typedefs {
   my ($meta) = @_;
   my $strings = $meta->{strings} or die;
   $meta->{typedefs} = my $typedefs = read_records($meta, 'typedefs', [
      ['name_off', 'l'],
      ['namespace_off', 'l'],
      ['val_type', 'l'],
      ['ref_type', 'l'],
      ['declaring_type', 'l'],
      ['parent_type_idx', 'l'],
      ['element_type', 'l'],
      ['rgctx_start', 'l'],
      ['rgctx_count', 'l'],
      ['generic_idx', 'l'],
      ['flags', 'L'],
      ['field_start', 'l'],
      ['method_start', 'l'],
      ['event_start', 'l'],
      ['property_start', 'l'],
      ['nested_type_start', 'l'],
      ['interface_start', 'l'],
      ['vtable_start', 'l'],
      ['interface_offset_start', 'l'],
      ['method_count', 'S'],
      ['property_count', 'S'],
      ['field_count', 'S'],
      ['event_count', 'S'],
      ['nested_type_count', 'S'],
      ['vtable_count', 'S'],
      ['interface_count', 'S'],
      ['interface_offset_count', 'S'],
      ['bitfield', 'L'],
      ['token', 'L'] ]);
   foreach my $type (@$typedefs) {
      $type->{name} = $strings->{$type->{namespace_off}};
      $type->{name} .= '.' if length($type->{name});
      $type->{name} .= $strings->{$type->{name_off}};
      $type->{basename} = $type->{name};
   }
}

sub read_fields {
   my ($meta) = @_;
   my $strings = $meta->{strings} or die;
   my $typeinfo = $meta->{typeinfo} or die;

   $meta->{fields} = my $fields = read_records($meta, 'fields', [
      ['name_off', 'l'],
      ['type_idx', 'l'],
      ['token', 'L'] ]);
   foreach my $fld (@$fields) {
      $fld->{name} = $strings->{$fld->{name_off}};
      my $type = $typeinfo->[$fld->{type_idx}] or next;
      $fld->{type} = $type->{name};
      $fld->{type_attrs} = my $attrs = $type->{attrs};
      $fld->{static} = 1 if $attrs & 0x10;
      # 0x0007: access
      # (1=private, 2=fam&asm, 3=assembly, 4=family, 5=fam|asm, 6=public)
      # 0x0010: static
      # 0x0020: init only
      # 0x0040: literal
      # 0x0080: no serialize
      # 0x0100: has rva
      # 0x0200: special name
      # 0x0400: special name
      # 0x1000: has marshalling info
      # 0x2000: pinvoke
      # 0x8000: has default
   }

   my $field_sizes = read_records($meta, 'field_sizes', [
      ['field_idx', 'l'],
      ['type_idx', 'l'],
      ['size', 'l'] ]);
   foreach my $size (@$field_sizes) {
      my $fld = $fields->[$size->{field_idx}] or next;
      $fld->{size} = $size->{size};
   }

   foreach my $type (@{$meta->{typedefs}}) {
      if ((my $idx = $type->{parent_type_idx}) >= 0) {
         $type->{parent_type} = $typeinfo->[$idx]{name};
      }
      $type->{fields} = get_slice($fields,
         $type->{field_start}, $type->{field_count});
   }
}

sub read_events {
   my ($meta) = @_;
   my $strings = $meta->{strings} or die;
   my $typenames = $meta->{typenames} or die;
   $meta->{events} = my $events = read_records($meta, 'events', [
      ['name_idx', 'l'],
      ['type_idx', 'l'],
      ['add_idx', 'l'],
      ['remove_idx', 'l'],
      ['raise_idx', 'l'],
      ['token', 'L'] ]);
   foreach my $event (@$events) {
      $event->{name} = $strings->{$event->{name_idx}};
      $event->{type} = $typenames->[$event->{type_idx}];
   }
   foreach my $type (@{$meta->{typedefs}}) {
      $type->{events} = get_slice($events,
         $type->{event_start}, $type->{event_count});
   }
}

sub read_nested_types {
   my ($meta) = @_;
   my $typedefs = $meta->{typedefs} or die;
   my $nested_types = read_ints($meta, 'nested_types');
   for my $idx (@$nested_types) {
      $idx = $typedefs->[$idx]{name};
   }
   foreach my $type (@$typedefs) {
      $type->{nested_types} = get_slice($nested_types,
         $type->{nested_type_start}, $type->{nested_type_count});
   }
}

sub read_properties {
   my ($meta) = @_;
   my $strings = $meta->{strings};
   my $methods = $meta->{methods} or die;
   my $properties = read_records($meta, 'properties', [
      ['name_idx', 'l'],
      ['get_method_idx', 'l'],
      ['set_method_idx', 'l'],
      ['attrs', 'L'],
      ['token', 'L'] ]);
   foreach my $prop (@$properties) {
      $prop->{name} = $strings->{$prop->{name_idx}};
   }
   foreach my $type (@{$meta->{typedefs}}) {
      $type->{properties} = my $props = get_slice($properties,
         $type->{property_start}, $type->{property_count}) or next;
      my $start = $type->{method_start};
      my $count = $type->{method_count};
      foreach my $prop (@$props) {
         foreach my $op ('get', 'set') {
            my $idx = $prop->{$op . '_method_idx'};
            next if !defined($idx) || $idx < 0 || $idx >= $count;
            my $meth = $methods->[$start + $idx] or next;
            $prop->{$op . '_method'} = $meth->{name};
         }
      }
   }
}

sub read_strings {
   my ($meta) = @_;
   my $data = read_bytes($meta, 'strings');
   $meta->{strings} = my $strings = {};
   while ($data =~ /\G(.*?)\0/gs) {
      $strings->{$-[0]} = decode_utf8($1);
   }

   local $Data::Dumper::Indent = 1;
   local $Data::Dumper::Terse = 1;
   local $Data::Dumper::Sortkeys = sub {[sort {$a<=>$b} keys %{$_[0]}]};
   open my $OUT, '>:utf8', 'meta/strings.txt';
   print $OUT Dumper($strings), "\n";
   close $OUT;

   my $ptrs = read_ints($meta, 'string_ptrs');
   $data = read_bytes($meta, 'string_data');
   $meta->{ustrings} = my $ustrings = {};
   for (my $i = 0; $i < $#$ptrs; $i += 2) {
      $ustrings->{$i>>1} =
         decode_utf8(substr($data, $ptrs->[$i+1], $ptrs->[$i]));
   }
   open $OUT, '>:utf8', 'meta/ustrings.txt';
   print $OUT Dumper($ustrings), "\n";
   close $OUT;
}

sub read_meta {
   my ($meta, $file) = @_;
   open $meta->{file}, '<:raw', $file or die "Can't read $file: $!";
   my $buf;
   read $meta->{file}, $buf, 8*34;
   my @buf = unpack 'V*', $buf;
   die 'bad magic' unless $buf[0] == 0xfab11baf;
   die 'bad version' unless $buf[1] == 0x18;

   my @tables = qw( string_ptrs string_data strings events properties methods
      param_defaults field_defaults defaults field_sizes params fields
      gen_params gen_constraints generics nested_types interfaces vtables
      interface_offsets typedefs rgctx images assemblies usage_lists
      usage_pairs field_refs assembly_refs attribute_info attribute_types
      uvcp_types uvcp_ranges windows_types exported_types );

   my %tables;
   for my $i (0 .. 32) {
      my $pos = $buf[2 + 2*$i];
      my $len = $buf[3 + 2*$i] or next;
      $tables{$tables[$i]} = { pos=>$pos, len=>$len };
   }
   $meta->{tables} = \%tables;
}

sub read_records {
   my ($meta, $file, $fields) = @_;
   print "Reading $file\n";
   my $table = $meta->{tables}{$file} or die $file;
   my $tmpl = '';
   my $len = 0;
   my (@names, @fixups);
   foreach my $field (@$fields) {
      my ($name, $type) = @$field;
      push @names, $name;
      $tmpl .= $type;
      if ($type eq 'l' || $type eq 'L') {
         $len += 4;
      }
      elsif ($type eq 's' || $type eq 'S') {
         $len += 2;
      }
      elsif ($type eq 'q' || $type eq 'Q') {
         $len += 8;
      }
      else {
         die "unknown type for $file $name: $type\n";
      }
   }
   die "no fields in $file\n" unless $len;
   my ($buf, @records);
   die "uneven length" if $table->{len} % $len;
   my $count = $table->{len} / $len;
   seek $meta->{file}, $table->{pos}, 0 or die $!;
   for my $i (0 .. $count-1) {
      read($meta->{file}, $buf, $len) == $len or die;
      my %info;
      @info{@names} = unpack $tmpl, $buf;
      $info{_num} = $i;
      push @records, \%info;
   }
   return \@records;
}

sub write_record {
   my ($file, $rec) = @_;
   open my $OUT, '>:utf8', $file or die "Can't write $file: $!\n";
   local $Data::Dumper::Indent = 1;
   local $Data::Dumper::Terse = 1;
   local $Data::Dumper::Sortkeys = 1;
   print $OUT Dumper($rec);
   close $OUT;
}

sub write_records {
   my ($dir, $name, $records) = @_;
   print "Writing $name\n";
   my $file = $dir . $name . '.txt';
   die unless $records;
   local $Data::Dumper::Indent = 1;
   local $Data::Dumper::Terse = 1;
   local $Data::Dumper::Sortkeys = 1;
   open my $OUT, '>:utf8', $file or die "Can't write $file: $!\n";
   for my $i (0 .. $#$records) {
      print $OUT $i, " ", Dumper($records->[$i]), "\n";
   }
   close $OUT;
}

sub read_types {
   my ($meta, $file) = @_;
   print "Reading $file\n";
   my $table = $meta->{tables}{$file} or die;
   my $names = $meta->{typenames} or die 'missing types';
   seek $meta->{file}, $table->{pos}, 0 or die $!;
   my $buf;
   read($meta->{file}, $buf, $table->{len}) == $table->{len} or die;
   my @ary = unpack 'V*', $buf;
   foreach my $idx (@ary) {
      $idx = $names->[$idx];
   }
   return \@ary;
}

sub read_ints {
   my ($meta, $file) = @_;
   print "Reading $file\n";
   my $table = $meta->{tables}{$file} or die;
   seek $meta->{file}, $table->{pos}, 0 or die $!;
   my $buf;
   read($meta->{file}, $buf, $table->{len}) == $table->{len} or die;
   return [ unpack 'V*', $buf ];
}

sub read_bytes {
   my ($meta, $file) = @_;
   print "Reading $file\n";
   my $table = $meta->{tables}{$file} or die;
   seek $meta->{file}, $table->{pos}, 0 or die $!;
   my $buf;
   read($meta->{file}, $buf, $table->{len}) == $table->{len} or die;
   return $buf;
}

sub get_slice {
   my ($ary, $start, $len) = @_;
   return if !$ary || $start < 0 || $len <= 0;
   return [ @{$ary}[$start .. $start+$len-1] ];
}

1 # end Metadata.pm
