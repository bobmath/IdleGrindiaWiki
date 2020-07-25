package Wasm::Dump;
use strict;
use warnings;
use Encode qw( decode_utf8 );
use Wasm::Disasm;
use Unity::UnityWeb;

sub extract {
   my ($class, $file, $dir) = @_;
   $dir //= '' and $dir .= '/';
   my $wasm = bless {} => $class;
   $wasm->{dir} = $dir;
   $wasm->{file} = Unity::UnityWeb::open_gzipped($file, $dir);
   my $buf;
   read($wasm->{file}, $buf, 8) == 8 or die;
   die 'Not a wasm file' unless substr($buf, 0, 4) eq "\x00asm";

   while (defined(my $type = getc $wasm->{file})) {
      $type = ord($type);
      my $len = read_uint($wasm);
      my $end = $len + tell($wasm->{file});
      if    ($type == 1)  { typesec($wasm) }
      elsif ($type == 2)  { importsec($wasm) }
      elsif ($type == 3)  { funcsec($wasm) }
      elsif ($type == 6)  { globalsec($wasm, $end) }
      elsif ($type == 7)  { exportsec($wasm) }
      elsif ($type == 9)  { elemsec($wasm, $end) }
      elsif ($type == 10) { codesec($wasm) }
      elsif ($type == 11) { datasec($wasm, $end) }
      seek($wasm->{file}, $end, 0) or die;
   }
   close $wasm->{file};
}

sub typesec {
   my ($wasm) = @_;
   my $num = read_uint($wasm);
   my $types = $wasm->{types} ||= [];
   for my $i (1 .. $num) {
      my $t = read_type($wasm) or last;
      push @$types, $t;
   }
}

sub importsec {
   my ($wasm) = @_;
   open my $OUT, '>:utf8', $wasm->{dir} . 'import.txt' or return;
   my $num = read_uint($wasm);
   for my $i (0 .. $num-1) {
      my $name = read_str($wasm);
      $name .= '.' . read_str($wasm);
      print $OUT "import $i $name ";
      my $info = { name=>$name, import=>1 };
      my $imp = read_byte($wasm);
      if ($imp == 0) {
         $info->{type} = $wasm->{types}[read_uint($wasm)] or last;
         print $OUT "func $info->{type}{name}\n";
         push @{$wasm->{funcs}}, $info;
      }
      elsif ($imp == 1) {
         $info->{type} = read_type($wasm) or last;
         $info->{lim} = read_type($wasm) or last;
         print $OUT "table $info->{type}{name} $info->{lim}{name}\n";
         push @{$wasm->{tables}}, $info;
      }
      elsif ($imp == 2) {
         $info->{lim} = read_type($wasm) or last;
         print $OUT "mem $info->{lim}{name}\n";
         push @{$wasm->{mems}}, $info;
      }
      elsif ($imp == 3) {
         $info->{type} = read_global($wasm) or last;
         print $OUT "global $info->{type}{mut} $info->{type}{name}\n";
         push @{$wasm->{globals}}, $info;
      }
      else { last }
   }
   close $OUT;
}

sub funcsec {
   my ($wasm) = @_;
   my $num = read_uint($wasm);
   my $funcs = $wasm->{funcs} ||= [];
   my $types = $wasm->{types};
   $wasm->{firstfunc} = @$funcs;
   for my $i (1 .. $num) {
      my $type = $types->[read_uint($wasm)] or last;
      push @$funcs, { type=>$type };
   }
}

sub globalsec {
   my ($wasm, $end) = @_;
   open my $OUT, '>:utf8', $wasm->{dir} . 'global.txt' or return;
   my $num = read_uint($wasm);
   my $globals = $wasm->{globals} ||= [];
   my $start = @$globals;
   for my $i ($start .. $start+$num-1) {
      my $glob = read_global($wasm) or last;
      print $OUT "global $i $glob->{mut} $glob->{name}\nvalue ";
      my $disasm = Wasm::Disasm->new($OUT);
      $disasm->disassemble($wasm, $end) or last;
   }
   close $OUT;
}

sub exportsec {
   my ($wasm) = @_;
   open my $OUT, '>:utf8', $wasm->{dir} . 'export.txt' or return;
   my $num = read_uint($wasm);
   for my $i (0 .. $num-1) {
      my $name = read_str($wasm);
      my $exp = read_byte($wasm);
      my $idx = read_uint($wasm);
      my $what;
      if ($exp == 0) {
         $what = 'func';
         if (my $func = $wasm->{funcs}[$idx]) {
            $func->{name} ||= $name;
         }
      }
      elsif ($exp == 1) { $what = 'table' }
      elsif ($exp == 2) { $what = 'mem' }
      elsif ($exp == 3) { $what = 'global' }
      else { last }
      print $OUT "export $i $name $what $idx\n";
   }
   close $OUT;
}

sub elemsec {
   my ($wasm, $end) = @_;
   my $num_tables = read_uint($wasm);
   open my $OUT, '>:utf8', $wasm->{dir} . 'element.txt';
   for my $i (0 .. $num_tables-1) {
      my $tblidx = read_uint($wasm);
      print $OUT "table $tblidx\nbase ";
      my $disasm = Wasm::Disasm->new($OUT);
      $disasm->disassemble($wasm, $end) or last;
      my $num = read_uint($wasm);
      for my $j (0 .. $num-1) {
         my $idx = read_uint($wasm);
         my $line = "elem $j func $idx";
         if (my $func = $wasm->{funcs}[$idx]) {
            my $name = $func->{name};
            $line .= ' ' . $name if $name;
            $line .= ' ' . $func->{type}{name};
         }
         print $OUT $line, "\n";
      }
   }
   close $OUT;
}

sub codesec {
   my ($wasm) = @_;
   open my $OUT, '>:utf8', $wasm->{dir} . 'code.txt' or return;
   my $start = tell($wasm->{file});
   my $num = read_uint($wasm);
   my $first = $wasm->{firstfunc};
   for my $i ($first .. $first+$num-1) {
      my $len = read_uint($wasm);
      my $end = $len + tell($wasm->{file});
      read_code($i, $wasm, $OUT, $end, $start);
      seek($wasm->{file}, $end, 0) or die;
   }
   close $OUT;
}

sub datasec {
   my ($wasm, $end) = @_;
   open my $OUT, '>:utf8', $wasm->{dir} . 'data.txt' or return;
   my $num = read_uint($wasm);
   my %mems;
   for my $i (0 .. $num-1) {
      my $mem = read_uint($wasm);
      print $OUT "data $i mem $mem\naddr ";
      my $pos = tell($wasm->{file});
      my $addr = read_const($wasm);
      if (defined $addr) {
         print $OUT $addr, "\n";
      }
      else {
         seek($wasm->{file}, $pos, 0) or last;
         my $disasm = Wasm::Disasm->new($OUT);
         $disasm->disassemble($wasm, $end) or last;
      }
      my $len = read_uint($wasm);
      print $OUT "len $len\n";
      my $buf;
      read($wasm->{file}, $buf, $len) == $len or last;
      next unless defined $addr;
      my $data = $mems{$mem} ||= \(my $empty = '');
      my $diff = $addr - length($$data);
      $$data .= "\0" x $diff if $diff > 0;
      substr($$data, $addr, $len, $buf);
   }
   close $OUT;
   foreach my $mem (sort { $a <=> $b } keys %mems) {
      open $OUT, '>:raw', $wasm->{dir} . "mem$mem" or return;
      print $OUT ${$mems{$mem}};
      close $OUT;
   }
}

sub read_const {
   my ($wasm) = @_;
   return unless read_byte($wasm) == 0x41;
   my $val = read_int($wasm);
   return unless read_byte($wasm) == 0x0b;
   return $val;
}

sub read_global {
   my ($wasm) = @_;
   my $type = read_type($wasm) or return;
   my $mut = read_byte($wasm);
   if ($mut == 0) {
      $type->{mut} = 'const';
   }
   elsif ($mut == 1) {
      $type->{mut} = 'var';
   }
   else { return }
   return $type;
}

my %types = (
   0x40 => 'null',
   0x70 => 'funcref',
   0x7f => 'i32',
   0x7e => 'i64',
   0x7d => 'f32',
   0x7c => 'f64',
);

sub read_type {
   my ($wasm) = @_;
   my $type = read_byte($wasm);
   my $info = {};
   if ($type == 0x00) {
      $info->{type} = 'lim';
      $info->{lo} = my $lo = read_uint($wasm);
      $info->{name} = "lim $lo";
   }
   elsif ($type == 0x01) {
      $info->{type} = 'lim';
      $info->{lo} = my $lo = read_uint($wasm);
      $info->{hi} = my $hi = read_uint($wasm);
      $info->{name} = "lim $lo,$hi";
   }
   elsif ($type == 0x60) {
      $info->{type} = 'func';
      ($info->{in}, my $in) = read_type_vec($wasm) or return;
      ($info->{out}, my $out) = read_type_vec($wasm) or return;
      $info->{name} = $in . '->' . $out;
   }
   else {
      $info->{type} = $info->{name} = $types{$type};
   }
   return $info;
}

sub read_type_vec {
   my ($wasm) = @_;
   my $num = read_uint($wasm);
   my @types;
   for my $i (1 .. $num) {
      my $type = read_byte($wasm);
      $type = $types{$type} or return;
      push @types, $type;
   }
   my $str = '[' . join(',',@types) . ']';
   return (\@types, $str);
}

sub read_simple_type {
   my ($wasm) = @_;
   my $byte = getc($wasm->{file});
   die 'eof' unless defined $byte;
   return $types{ord $byte};
}

sub read_code {
   my ($func_num, $wasm, $OUT, $end, $start) = @_;
   my $line = "func $func_num";
   my $next_local = 0;
   if (my $func = $wasm->{funcs}[$func_num]) {
      my $type = $func->{type};
      if (my $in = $type->{in}) {
         $next_local = @$in;
      }
      $line .= ' ' . $func->{name} if $func->{name};
      $line .= ' ' . $type->{name};
   }
   print $OUT $line, "\n";

   my $num_locals = read_uint($wasm);
   for my $i (1 .. $num_locals) {
      my $num = read_uint($wasm);
      my $type = $types{read_byte($wasm)} or return;
      my @loc;
      for my $j (1 .. $num) {
         push @loc, "loc$next_local";
         $next_local++;
      }
      print $OUT $type, ' ', join(',', @loc), "\n";
   }

   my $disasm = Wasm::Disasm->new($OUT, $next_local);
   $disasm->disassemble($wasm, $end, $start) or warn "func $func_num\n";
   print $OUT "\n";
}

sub read_uint {
   my ($wasm) = @_;
   my $file = $wasm->{file};
   my $byte = getc $file;
   die 'eof' unless defined $byte;
   $byte = ord $byte;
   my $val = $byte & 0x7f;;
   my $bit = 0;
   while ($byte & 0x80) {
      $byte = getc $file;
      die 'eof' unless defined $byte;
      $byte = ord $byte;
      $val |= ($byte & 0x7f) << ($bit += 7);
   }
   return $val;
}

sub read_int {
   my ($wasm) = @_;
   my $file = $wasm->{file};
   my $byte = getc($file);
   die 'eof' unless defined($byte);
   $byte = ord $byte;
   my $val = $byte & 0x7f;
   my $bit = 7;
   while ($byte & 0x80) {
      $byte = getc($file);
      die 'eof' unless defined $byte;
      $byte = ord $byte;
      $val |= ($byte & 0x7f) << $bit;
      $bit += 7;
   }
   $val -= 1 << $bit if ($val & (1 << ($bit - 1)));
   return $val;
}

sub read_byte {
   my ($wasm) = @_;
   my $byte = getc $wasm->{file};
   die 'eof' unless defined $byte;
   return ord $byte;
}

sub read_str {
   my ($wasm) = @_;
   my $len = read_uint($wasm);
   my $buf;
   read($wasm->{file}, $buf, $len) == $len or die 'eof';
   return decode_utf8($buf);
}

sub read_raw {
   my ($wasm, $len) = @_;
   my $buf;
   read($wasm->{file}, $buf, $len) == $len or die 'eof';
   return $buf;
}

sub file_pos {
   my ($wasm) = @_;
   return tell($wasm->{file});
}

1 # end Wasm::Dump
