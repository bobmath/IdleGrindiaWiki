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
   read_typedefs($meta, $metadir . 'names.txt');
   read_methods($meta);
   read_mem($meta, $codedir . 'mem0');
   find_typeinfo($meta);
   find_codeinfo($meta);
   get_method_idx($meta);
   read_generics($meta);
   read_nested_types($meta);
   read_interfaces($meta);
   read_properties($meta);
   get_type_names($meta);
   #get_gen_methods($meta);
   get_type_layouts($meta);
   #get_interop($meta);
   read_events($meta);
   read_defaults($meta);
   #read_usage($meta);
   #read_rgctx($meta);
   read_vtables($meta);
   #read_assemblies($meta);
   read_code($meta, $codedir);
   #annotate_code($meta, $codedir);
   write_types($meta, 'types.txt');
   write_record($metadir . 'memtables.txt', $meta->{memtables});
   write_records($metadir, 'typeinfo', $meta->{typeinfo});
   write_records($metadir, 'typedefs', $meta->{typedefs});
   write_records($metadir, 'methods', $meta->{methods});
   write_records($metadir, 'specs', $meta->{meth_specs});
}

sub write_types {
   my ($meta, $file) = @_;
   open my $OUT, '>:utf8', $file or die $!;
   foreach my $type (@{$meta->{typedefs}}) {
      print $OUT "name: $type->{name}\n";
      print $OUT "parent: $type->{parent_type}\n" if $type->{parent_type};
      if (my $interfaces = $type->{interface_offsets}) {
         print $OUT "interfaces:\n";
         foreach my $int (@$interfaces) {
            printf $OUT "  %-16s  %d\n", $int->{type}, $int->{offset};
         }
      }
      if (my $nested = $type->{nested_types}) {
         print $OUT "nested types:\n";
         print $OUT "  $_\n" foreach @$nested;
      }

      if (my $fields = $type->{fields}) {
         print $OUT "fields:\n";
         foreach my $fld (@$fields) {
            my $type = $fld->{type} // '???';
            if (defined(my $val = $fld->{default})) {
               if ($val =~ /[^-+.\w]/) {
                  $val =~ s{([\x00-\x1f\\"\x7f-\xa0])}
                     {sprintf "\\x%02x", ord($1)}eg;
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
            my $type = $meth->{return_type} // '???';
            $type .= '  static' if $meth->{static};
            $type .= '  virtual' if $meth->{virtual};
            printf $OUT "  %-16s  %s  %d\n", $meth->{name}, $type,
               $meth->{_module_idx} // -1;
            my $params = $meth->{params} or next;
            foreach my $param (@$params) {
               printf $OUT "    %-16s  %s\n", $param->{name},
                  $param->{type} // '???';
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

   my $dyncalls = $meta->{dyncalls} = {};
   open my $IN, '<:utf8', $dir . 'code.txt' or return;
   my $curr = '';
   while (<$IN>) {
      if (/^func \d+ (\S*)/) {
         $curr = $1;
         $curr =~ s/^dynCall_// or $curr = '';
      }
      elsif ($curr && /call_indirect \{\(loc0 & (\d+)\) \+ (\d+)\}/) {
         $dyncalls->{$curr} = [ @table[$2 .. $2+$1] ];
      }
      elsif ($curr && /call_indirect \{loc0 & (\d+)\}/) {
         $dyncalls->{$curr} = [ @table[0 .. $1] ];
      }
   }
}

sub annotate_code {
   my ($meta, $dir) = @_;
   my $dyncalls = $meta->{dyncalls};
   my %funcs;
   foreach my $meth (@{$meta->{methods}}) {
      if (defined(my $ptr = $meth->{method_idx})) {
         my $num = $dyncalls->{$meth->{shortsig}}[$ptr] or next;
         $meth->{method_num} = $num;
         push @{$funcs{$num}}, $meth->{fullname};
      }
      my $inst = $meth->{instants} or next;
      foreach my $sig (sort keys %$inst) {
         my $info = $inst->{$sig};
         my $num = $dyncalls->{$info->{shortsig}}[$info->{method_idx}] or next;
         $info->{method_num} = $num;
         push @{$funcs{$num}},
            $meth->{_owner} . '.' . $meth->{basename} . $sig;
      }
   }

   foreach my $type (@{$meta->{typedefs}}) {
      my $inst = $type->{instants} or next;
      foreach my $sig (sort keys %$inst) {
         my $methods = $inst->{$sig};
         foreach my $name (sort keys %{$methods}) {
            my $info = $methods->{$name};
            my $num = $dyncalls->{$info->{shortsig}}[$info->{method_idx}]
               or next;
            $info->{method_num} = $num;
            push @{$funcs{$num}}, $type->{basename} . $sig . '.' . $name;
         }
      }
   }

   foreach my $addr (keys %funcs) {
      my $names = $funcs{$addr};
      if (@$names > 2) {
         my %short;
         foreach my $name (@$names) {
            my $short = $name;
            $short =~ s/<.*>/<*>/;
            push @{$short{$short}}, $name;
         }
         if (keys(%short) < @$names) {
            @$names = ();
            while (my ($k, $v) = each %short) {
               push @$names, @$v > 1 ? $k : $v->[0];
            }
         }
      }
      @$names = sort @$names;
      if (@$names > 10) {
         splice @$names, 10;
         push @$names, '...';
      }
      $funcs{$addr} = join ', ', @$names;
   }

   print "Annotating code\n";
   open my $IN, '<:utf8', $dir . 'code.txt' or return;
   open my $OUT, '>:utf8', $dir . 'anno.txt'
      or die "Can't write ${dir}anno.txt: $!\n";
   my $lookup = $meta->{usage_lookup};
   while (<$IN>) {
      chomp;
      if (/\b(?:func|call) (\d+)/) {
         my $name = $funcs{$1};
         $_ .= ' # ' . $name if defined $name;
      }
      elsif (/\binvoke_(\w+) \((\d+)/) {
         my $addr = $dyncalls->{$1}[$2];
         $_ .= ' # ' . ($funcs{$addr} // $addr) if defined $addr;
      }
      elsif (/\bglob(\d+)\b/) {
         my $glob = $globals{$1};
         $_ .= ' # ' . $glob if defined $glob;
      }
      #while (/\bmem_i32\[(\d+)\]/g) {
      #   my $val = $lookup->{$1} or next;
      #   if ($val =~ /[\x00-\x20\x7f-\xa0]/) {
      #      $val =~ s/([\x00-\x1f\\"\x7f-\xa0])/sprintf "\\x%02x", ord($1)/eg;
      #      $val = qq["$val"];
      #   }
      #   $_ .= ' # ' . $val;
      #   last;
      #}
      print $OUT $_, "\n";
   }
   close $OUT;
   close $IN;
}

sub read_usage {
   my ($meta) = @_;
   my $table = $meta->{memtables}{meta_usages} or die;
   my $dest_max = (length($meta->{mem}) - $table->{off}) >> 2;

   my $pairs = read_records($meta, 'usage_pairs', [
      ['dest_idx', 'L'],
      ['ref_idx', 'L'] ]);
   my $usage = $meta->{meta_usage} = [];
   foreach my $pair (@$pairs) {
      my $dest = $pair->{dest_idx};
      $usage->[$dest] = $pair if $dest < $dest_max; # bogon filter
   }

   my @ptrs = unpack 'V*', substr($meta->{mem}, $table->{off}, @$usage << 2);

   my $lookup = $meta->{usage_lookup} = {};
   foreach my $pair (@$usage) {
      next unless $pair;
      decode_ref($meta, $pair);
      $pair->{ptr} = my $ptr = $ptrs[$pair->{dest_idx}];
      $lookup->{$ptr} = $pair->{ref} if $ptr;
   }

   #$meta->{usage_lists} = read_records($meta, 'usage_lists', [
   #   ['usage_start', 'l'],
   #   ['usage_count', 'l'] ]);
   #foreach my $list (@$lists) {
   #   $list->{usage} = get_slice($pairs,
   #      $list->{usage_start}, $list->{usage_count});
   #}
}

my %ref_type = (
   1 => 'type_info',
   2 => 'il2cpp_type',
   3 => 'method',
   4 => 'field',
   5 => 'string',
   6 => 'gen_method',
);

sub decode_ref {
   my ($meta, $rec) = @_;
   my $idx = $rec->{ref_idx};
   my $type = $idx >> 29;
   $rec->{ref_type} = $ref_type{$type};
   $rec->{ref_idx} = $idx &= 0x1fffffff;
   if ($type == 1 || $type == 2) {
      $rec->{ref} = $meta->{typenames}[$idx];
   }
   elsif ($type == 3) {
      $rec->{ref} = $meta->{methods}[$idx]{fullname};
   }
   elsif ($type == 4) {
      $rec->{ref} = $meta->{field_refs}[$idx]{name};
   }
   elsif ($type == 5) {
      $rec->{ref} = $meta->{ustrings}{$idx};
   }
   elsif ($type == 6) {
      my $spec = $meta->{meth_specs}[$idx] or return;
      my $ref = $spec->{class};
      $ref .= $spec->{class_sig} if $spec->{class_sig};
      $ref .= '.' . $spec->{method};
      $ref .= $spec->{method_sig} if $spec->{method_sig};
      $rec->{ref} = $ref;
   }
}

sub read_rgctx {
   my ($meta) = @_;
   my $rgctx = read_records($meta, 'rgctx', [
      ['type', 'l'], # 1=type, 2=class, 3=method
      ['index', 'l'] ]);
   foreach my $rec (@$rgctx) {
      my $type = $rec->{type};
      if ($type == 1 || $type == 2) {
         $rec->{class} = $meta->{typenames}[$rec->{index}];
      }
   }
   foreach my $type (@{$meta->{typedefs}}) {
      $type->{rgctx} = get_slice($rgctx,
         $type->{rgctx_start}, $type->{rgctx_count});
   }
   foreach my $meth (@{$meta->{methods}}) {
      $meth->{rgctx} = get_slice($rgctx,
         $meth->{rgctx_start}, $meth->{rgctx_count});
   }
}

sub read_vtables {
   my ($meta) = @_;
   my $vtables = read_records($meta, 'vtables', [
      ['ref_idx', 'L'] ]);
   foreach my $rec (@$vtables) {
      decode_ref($meta, $rec);
   }
   foreach my $type (@{$meta->{typedefs}}) {
      $type->{vtable} = get_slice($vtables,
         $type->{vtable_start}, $type->{vtable_count});
   }
}

sub read_interfaces {
   my ($meta) = @_;
   my $typenames = $meta->{typenames} or die;
   my $interface_offsets = read_records($meta, 'interface_offsets', [
      ['type_idx', 'l'],
      ['offset', 'l'] ]);
   foreach my $off (@$interface_offsets) {
      $off->{type} = $typenames->[$off->{type_idx}];
   }
   foreach my $type (@{$meta->{typedefs}}) {
      $type->{interface_offsets} = get_slice($interface_offsets,
         $type->{interface_offset_start}, $type->{interface_offset_count});
   }
}

sub get_type_layouts {
   my ($meta, $file) = @_;
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
         $val = sprintf '%.8g', unpack('f<', substr($data, $off, 4));
      }
      elsif ($type eq 'System.Double') {
         $val = unpack('d<', substr($data, $off, 8));
      }
      elsif ($type eq 'System.String') {
         my $len = unpack('V', substr($data, $off, 4));
         $val = decode_utf8(substr($data, $off+4, $len));
      }
      else {
         $type = $meta->{typeinfo}[$def->{type_idx}] or next;
         $type = $meta->{typedefs}[$type->{idx}] or next;
         my $size = $type->{size}[1] or next;
         $owner->{default_raw} = unpack 'H*', substr($data, $off, $size);
         # probably an array initializer
      }
      $owner->{default} = $val;
   }
}

sub read_methods {
   my ($meta) = @_;
   my $strings = $meta->{strings} or die;

   $meta->{methods} = my $methods = read_records($meta, 'methods', [
      ['name_off', 'l'],
      ['declaring_type_idx', 'l'],
      ['return_type_idx', 'l'],
      ['param_start', 'l'],
      ['generic_idx', 'l'],
      ['token', 'L'],
      ['flags', 'S'],
      ['iflags', 'S'],
      ['slot', 's'],
      ['param_count', 'S'] ]);

   $meta->{params} = my $params = read_records($meta, 'params', [
      ['name_off', 'l'],
      ['token', 'L'],
      ['type_idx', 'l'] ]);
   foreach my $param (@$params) {
      $param->{name} = $strings->{$param->{name_off}};
   }

   foreach my $meth (@$methods) {
      $meth->{basename} = $meth->{name} = $strings->{$meth->{name_off}};
      $meth->{params} = my $args = get_slice($params,
         $meth->{param_start}, $meth->{param_count});
      $meth->{static} = 1 if $meth->{flags} & 0x10;
      $meth->{virtual} = 1 if $meth->{flags} & 0x40;
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
      # 0x0008: no inlining
      # 0x0010: forward ref
      # 0x0020: synchronized
      # 0x0040: no optimization
      # 0x0080: preserve signature
      # 0x1000: internal call
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
      my $info = { invoker=>-1, shortsig=>-1, method_idx=>-1 };
      my $spec = {
         method => $meth->{basename},
         method_idx => $meth_idx,
         class_sig_idx => $class_sig,
         method_sig_idx => $meth_sig,
         info => $info,
         unused => 1,
      };
      push @$meth_specs, $spec;
      $spec->{class} = $meth->{_owner};
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
      $info->{method_idx} = $meth_ptrs->[$methptr_idx];
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

sub get_type_names {
   my ($meta) = @_;
   my $typeinfo = $meta->{typeinfo} or die;
   my $typedefs = $meta->{typedefs} or die;
   my $methods = $meta->{methods} or die;

   foreach my $type (@$typedefs) {
      if ((my $idx = $type->{parent_type_idx}) >= 0) {
         $type->{parent_type} = $typeinfo->[$idx]{name};
      }
      my $count = $type->{method_count} or next;
      my $start = $type->{method_start};
      my $type_idx = $type->{_num};
      my $type_name = $type->{basename};
      for my $idx ($start .. $start+$count-1) {
         my $meth = $methods->[$idx] or die;
         $meth->{_owner_idx} = $type_idx;
         $meth->{_owner} = $type_name;
         $meth->{fullname} = $type_name . '.' . $meth->{name};
      }
   }

   foreach my $fld (@{$meta->{fields}}) {
      my $info = $typeinfo->[$fld->{type_idx}] or next;
      $fld->{type} = $info->{name};
      $fld->{type_attrs} = my $attrs = $info->{attrs};
      $fld->{static} = 1 if $attrs & 0x10;
   }

   foreach my $ref (@{$meta->{field_refs}}) {
      my $info = $typeinfo->[$ref->{type_idx}] or next;
      my $type = $typedefs->[$info->{idx}] or next;
      my $field = $type->{fields}[$ref->{field_idx}] or next;
      $ref->{name} = $type->{name} . '.' . $field->{name};
   }

   foreach my $param (@{$meta->{params}}) {
      my $info = $typeinfo->[$param->{type_idx}];
      $param->{type} = $info->{name};
      $param->{type_attrs} = $info->{attrs};
      # 0x0001: in
      # 0x0002: out
      # 0x0010: optional
      # 0x1000: has default
      # 0x2000: has field marshal
   }

   $meta->{invokers} = my $invokers = {};
   foreach my $meth (@$methods) {
      $meth->{declaring_type} = $typedefs->[$meth->{declaring_type_idx}]{name};
      my $info = $typeinfo->[$meth->{return_type_idx}];
      $meth->{return_type} = $info->{name};
      $meth->{return_type_attrs} = $info->{attrs}; # always 0
      my $sig = $info->{retchar} || '?';
      $sig .= 'i' unless $meth->{static};
      if (my $args = $meth->{params}) {
         foreach my $arg (@$args) {
            $info = $typeinfo->[$arg->{type_idx}];
            $sig .= $info->{char} || '?';
         }
      }
      $sig .= 'i';
      $meth->{shortsig} = $sig;
      my $inv = $meth->{invoker_idx};
      $invokers->{$inv} = $sig if defined $inv;
   }
}

sub find_codeinfo {
   my ($meta) = @_;
   die 'missing mem' unless exists $meta->{mem};

   my $pos = index($meta->{mem}, "mscorlib.dll\0");
   die if $pos < 0;
   $pos = index($meta->{mem}, pack("V", $pos));
   die if $pos < 0 || ($pos & 3);
   $pos = index($meta->{mem}, pack("V", $pos));
   die if $pos < 0 || ($pos & 3);
   $pos = index($meta->{mem}, pack("V", $pos)) - 0x3c;
   die if $pos < 0 || ($pos & 3);

   my @tables = qw( rev_invokers gen_meth_ptrs invokers attr_gen uvc_ptrs
      interop_data windows_runtime modules );
   $meta->{memtables}{code_info} = { count => scalar(@tables),
      off => $pos };
   my @hdr = unpack("V*", substr($meta->{mem}, $pos, @tables*8));
   for my $i (0 .. $#tables) {
      $meta->{memtables}{$tables[$i]} =
         { count => $hdr[2*$i], off => $hdr[2*$i+1] };
   }
}

sub get_method_idx {
   my ($meta) = @_;
   my $memlen = length($meta->{mem}) or die;
   my $ptrs = get_ints($meta, 'modules');
   $meta->{modules} = my $mods = [];
   my @fields = qw( name_off meth_count meth_idx invoker_idx
      rev_pinv_count rev_pinv_idx rgctx_rng_count rgctx_rng_ptrs
      rgctx_count rgctx_ptrs debug_meta );
   my $j = 0;
   my $methods = $meta->{methods};
   for my $n (0 .. $#$ptrs) {
      my $ptr = $ptrs->[$n];
      die if $ptr >= $memlen || ($ptr & 3);
      my %mod;
      @mod{@fields} = unpack("V*", substr($meta->{mem}, $ptr, @fields*4));
      $mod{name} = my $name = mem_cstr($meta, $mod{name_off});
      push @$mods, \%mod;

      my @methods = unpack("V*",
         substr($meta->{mem}, $mod{meth_idx}, $mod{meth_count}*4));
      my @invokers = unpack("V*",
         substr($meta->{mem}, $mod{invoker_idx}, $mod{meth_count}*4));
      for my $i (0 .. $mod{meth_count}-1) {
         my $meth = $methods->[$j];
         $j++;
         $meth->{method_idx} = $methods[$i];
         $meth->{invoker_idx} = $invokers[$i];
         $meth->{_module_idx} = $n;
         $meth->{_module} = $name;
      }
   }
}

sub mem_cstr {
   my ($meta, $off) = @_;
   die 'bad string offset' if $off > length($meta->{mem});
   pos($meta->{mem}) = $off;
   $meta->{mem} =~ /\G(.*?)\0/s or die 'bad string';
   return $1;
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
      push @$typeinfo, $typelookup->{$ptr} =
         { idx=>$idx, flags=>$flags, ptr=>$ptr };
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

   if ($type == 0x01) { # void
      $info->{char} = 'v';
   }
   elsif ($type >= 0x02 && $type <= 0x09) { # various ints
      $info->{char} = 'i';
      $info->{primitive} = 1;
   }
   elsif ($type == 0x0a || $type == 0x0b) { # i8, u8
      $info->{char} = 'j';
      $info->{primitive} = 1;
   }
   elsif ($type == 0x0c) { # r4
      $info->{char} = 'f';
      $info->{primitive} = 1;
   }
   elsif ($type == 0x0d) { # r8
      $info->{char} = 'd';
      $info->{primitive} = 1;
   }
   elsif ($type == 0x0f) { # ptr
      $name = '*' . type_name($meta, $idx);
   }
   elsif ($type == 0x11) { # valuetype
      if ($info->{char} = val_type($meta, $info->{idx})) {
         $info->{primitive} = 1;
      }
      else {
         $info->{char} = 'i';
         $info->{retchar} = 'vi';
         $info->{offset} = 8;
      }
   }
   elsif ($type == 0x14) { # array
      $name = array_name($meta, $idx);
   }
   elsif ($type == 0x15) { # genericinst
      $name = gen_name($meta, $idx);
   }
   elsif ($type == 0x1d) { # szarray
      $name = type_name($meta, $idx) . '[]';
   }

   $name ||= "?$idx";
   if ($info->{flags} & 0x40000000) {
      $name = '&' . $name;
      $info->{char} = 'i';
      delete $info->{primitive};
   }
   $name = '!' . $name if $info->{flags} & 0x80000000;
   $info->{char} ||= 'i';
   $info->{retchar} ||= $info->{char};
   return $info->{name} = $name;
}

sub val_type {
   my ($meta, $idx) = @_;
   my $type = $meta->{typedefs}[$idx] or return;
   my $fields = $type->{fields} or return;
   my $fld_idx;
   foreach my $field (@$fields) {
      my $info = $meta->{typeinfo}[$field->{type_idx}] or next;
      next if $info->{flags} & 0x10; # static
      return if defined $fld_idx;
      $fld_idx = $field->{type_idx};
   }
   return unless defined $fld_idx;
   my $info = $meta->{typeinfo}[$fld_idx] or return;
   type_name($meta, $info->{ptr}) unless $info->{char};
   return unless $info->{primitive};
   return $info->{char};
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
   my ($meta, $file) = @_;
   my $strings = $meta->{strings} or die;

   $meta->{typedefs} = my $typedefs = read_records($meta, 'typedefs', [
      ['name_off', 'l'],
      ['namespace_off', 'l'],
      ['val_type', 'l'],
      ['ref_type', 'l'],
      ['declaring_type', 'l'],
      ['parent_type_idx', 'l'],
      ['element_type', 'l'],
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

   open my $OUT, '>:utf8', $file or die;
   foreach my $type (@$typedefs) {
      my $name = $strings->{$type->{namespace_off}};
      $name .= '.' if length($name);
      $name .= $strings->{$type->{name_off}};
      print $OUT "$name\n";
      $type->{name} = $type->{basename} = $name;
      # flags:
      # 0x000007: visibility
      # 0=notpublic, 1:public, 2:nestedpublic, 3:nestedprivate, 4:nestedfamily
      # 5=nestedassembly, 6=nested family&assembly, 7:nested fam|asm
      # 0x000008: sequential layout
      # 0x000010: explicit layout
      # 0x000020: interface
      # 0x000080: abstract
      # 0x000100: sealed
      # 0x000400: special name
      # 0x000800: runtime special name
      # 0x001000: import
      # 0x002000: serializable
      # 0x030000: string format: 0=ansi, 1=unicode, 2=auto, 3=custom
      # 0x040000: has security
      # 0x100000: class init before field init
      # 0xC00000: custom string format
   }
   close $OUT;

   $meta->{fields} = my $fields = read_records($meta, 'fields', [
      ['name_off', 'l'],
      ['type_idx', 'l'],
      ['token', 'L'] ]);
   foreach my $fld (@$fields) {
      $fld->{name} = $strings->{$fld->{name_off}};
   }

   foreach my $type (@{$meta->{typedefs}}) {
      $type->{fields} = get_slice($fields,
         $type->{field_start}, $type->{field_count});
   }

   my $field_sizes = read_records($meta, 'field_sizes', [
      ['field_idx', 'l'],
      ['type_idx', 'l'],
      ['size', 'l'] ]);
   foreach my $size (@$field_sizes) {
      my $fld = $fields->[$size->{field_idx}] or next;
      $fld->{size} = $size->{size};
   }

   $meta->{field_refs} = my $field_refs = read_records($meta, 'field_refs', [
      ['type_idx', 'l'],
      ['field_idx', 'l'] ]);
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
   my @nested;
   foreach my $type (@$typedefs) {
      $type->{nested_types} = my $nested = get_slice($nested_types,
         $type->{nested_type_start}, $type->{nested_type_count}) or next;
      push @nested, $nested;
      foreach my $id (@$nested) {
         my $ntype = $typedefs->[$id] or next;
         $ntype->{nested_in} = $type->{_num};
      }
   }
   my $seen = {};
   foreach my $nested (@nested) {
      foreach my $id (@$nested) {
         $id = nested_name($id, $typedefs, $seen);
      }
   }
}

sub nested_name {
   my ($id, $typedefs, $seen) = @_;
   return '?' unless defined $id;
   my $name = $seen->{$id};
   return $name if defined $name;
   my $type = $typedefs->[$id] or return '?';
   my $outer = $type->{nested_in};
   if (defined $outer) {
      $seen->{$id} = '?'; # avoid unterminated recursion
      $name = nested_name($outer, $typedefs, $seen);
      $type->{basename} = $name . ':' . $type->{basename};
      $type->{name} = $name . ':' . $type->{name};
   }
   return $seen->{$id} = $type->{name};
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

sub read_assemblies {
   my ($meta) = @_;
   my $strings = $meta->{strings};
   $meta->{images} = my $images = read_records($meta, 'images', [
      ['name_idx', 'l'],
      ['assembly_idx', 'l'],
      ['type_start', 'l'],
      ['type_count', 'l'],
      ['exported_type_start', 'l'],
      ['exported_type_count', 'l'],
      ['entry_point_idx', 'l'],
      ['token', 'L'],
      ['attribute_start', 'l'],
      ['attribute_count', 'l'] ]);
   foreach my $img (@$images) {
      $img->{name} = $strings->{$img->{name_idx}};
   }

   $meta->{assemblies} = my $assemblies = read_records($meta, 'assemblies', [
      ['image_idx', 'l'],
      ['token', 'L'],
      ['ref_assembly_start', 'l'],
      ['ref_assembly_count', 'l'],
      ['name_idx', 'l'],
      ['culture_idx', 'l'],
      ['hash_idx', 'l'],
      ['pubkey_idx', 'l'],
      ['hash_alg', 'l'],
      ['hash_len', 'l'],
      ['flags', 'L'],
      ['major_ver', 'l'],
      ['minor_ver', 'l'],
      ['build', 'l'],
      ['revision', 'l'],
      ['pubkey_token', 'Q'] ]);
   foreach my $ass (@$assemblies) {
      $ass->{name} = $strings->{$ass->{name_idx}};
      $ass->{culture} = $strings->{$ass->{culture_idx}};
      $ass->{hash} = $strings->{$ass->{hash_idx}};
      $ass->{pubkey} = $strings->{$ass->{pubkey_idx}};
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
      interface_offsets typedefs images assemblies usage_lists usage_pairs
      field_refs assembly_refs attribute_info attribute_types
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
