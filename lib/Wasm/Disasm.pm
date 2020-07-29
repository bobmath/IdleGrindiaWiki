package Wasm::Disasm;
use strict;
use warnings;

sub new {
   my ($class, $file, $temp) = @_;
   my $self = bless {} => $class;
   $self->{temp} = $temp || 0;
   $self->{blocks} = [];
   $self->{values} = [];
   $self->{file} = $file;
   return $self;
}

sub disassemble {
   my ($self, $wasm, $end) = @_;
   while ($wasm->file_pos() < $end) {
      my $bc = $wasm->read_byte();
      if    ($bc == 0x00) { $self->stmt('unreachable') }
      elsif ($bc == 0x01) { $self->stmt('nop') }
      elsif ($bc == 0x02) { $self->block('block', $wasm) or last }
      elsif ($bc == 0x03) { $self->block('loop', $wasm) or last }
      elsif ($bc == 0x04) { $self->if_block($wasm) or last }
      elsif ($bc == 0x05) { $self->else_block() or last }
      elsif ($bc == 0x0b) { $self->end_block() and return 1 }
      elsif ($bc == 0x0c) { $self->branch($wasm) or last }
      elsif ($bc == 0x0d) { $self->branch_if($wasm) or last }
      elsif ($bc == 0x0e) { $self->br_table($wasm) or last }
      elsif ($bc == 0x0f) { $self->do_return() }
      elsif ($bc == 0x10) { $self->call($wasm) }
      elsif ($bc == 0x11) { $self->call_ind($wasm) or last }
      elsif ($bc == 0x1a) { $self->drop() }
      elsif ($bc == 0x1b) { $self->trinary() }
      elsif ($bc == 0x20) { $self->get_local($wasm) }
      elsif ($bc == 0x21) { $self->set_local($wasm) }
      elsif ($bc == 0x22) { $self->set_local($wasm, 1) }
      elsif ($bc == 0x23) { $self->get_global($wasm) }
      elsif ($bc == 0x24) { $self->set_global($wasm) }
      elsif ($bc == 0x28) { $self->load('i32', $wasm) }
      elsif ($bc == 0x29) { $self->load('i64', $wasm) }
      elsif ($bc == 0x2a) { $self->load('f32', $wasm) }
      elsif ($bc == 0x2b) { $self->load('f64', $wasm) }
      elsif ($bc == 0x2c) { $self->load('s8', $wasm) }
      elsif ($bc == 0x2d) { $self->load('u8', $wasm) }
      elsif ($bc == 0x2e) { $self->load('s16', $wasm) }
      elsif ($bc == 0x2f) { $self->load('u16', $wasm) }
      elsif ($bc == 0x30) { $self->load('s8', $wasm) }
      elsif ($bc == 0x31) { $self->load('u8', $wasm) }
      elsif ($bc == 0x32) { $self->load('s16', $wasm) }
      elsif ($bc == 0x33) { $self->load('u16', $wasm) }
      elsif ($bc == 0x34) { $self->load('s32', $wasm) }
      elsif ($bc == 0x35) { $self->load('u32', $wasm) }
      elsif ($bc == 0x36) { $self->store('i32', $wasm) }
      elsif ($bc == 0x37) { $self->store('i64', $wasm) }
      elsif ($bc == 0x38) { $self->store('f32', $wasm) }
      elsif ($bc == 0x39) { $self->store('f64', $wasm) }
      elsif ($bc == 0x3a) { $self->store('i8', $wasm) }
      elsif ($bc == 0x3b) { $self->store('i16', $wasm) }
      elsif ($bc == 0x3c) { $self->store('i8', $wasm) }
      elsif ($bc == 0x3d) { $self->store('i16', $wasm) }
      elsif ($bc == 0x3e) { $self->store('i32', $wasm) }
      elsif ($bc == 0x3f) { $self->mem_size($wasm) or last }
      elsif ($bc == 0x40) { $self->mem_grow($wasm) or last }
      elsif ($bc == 0x41) { $self->iconst($wasm) }
      elsif ($bc == 0x42) { $self->iconst($wasm) }
      elsif ($bc == 0x43) { $self->f32const($wasm) }
      elsif ($bc == 0x44) { $self->f64const($wasm) }
      elsif ($bc == 0x45) { $self->unop('!') } # i32.eqz
      elsif ($bc == 0x46) { $self->binop('==') } # i32.eq
      elsif ($bc == 0x47) { $self->binop('!=') } # i32.ne
      elsif ($bc == 0x48) { $self->binop('<') } # i32.lt_s
      elsif ($bc == 0x49) { $self->binop('<.') } # i32.lt_u
      elsif ($bc == 0x4a) { $self->binop('>') } # i32.gt_s
      elsif ($bc == 0x4b) { $self->binop('>.') } # i32.gt_u
      elsif ($bc == 0x4c) { $self->binop('<=') } # i32.le_s
      elsif ($bc == 0x4d) { $self->binop('<=.') } # i32.le_u
      elsif ($bc == 0x4e) { $self->binop('>=') } # i32.ge_s
      elsif ($bc == 0x4f) { $self->binop('>=.') } # i32.ge_u
      elsif ($bc == 0x50) { $self->unop('!') } # i64.eqz
      elsif ($bc == 0x51) { $self->binop('==') } # i64.eq
      elsif ($bc == 0x52) { $self->binop('!=') } # i64.ne
      elsif ($bc == 0x53) { $self->binop('<') } # i64.lt_s
      elsif ($bc == 0x54) { $self->binop('<.') } # i64.lt_u
      elsif ($bc == 0x55) { $self->binop('>') } # i64.gt_s
      elsif ($bc == 0x56) { $self->binop('>.') } # i64.gt_u
      elsif ($bc == 0x57) { $self->binop('<=') } # i64.le_s
      elsif ($bc == 0x58) { $self->binop('<=.') } # i64.le_u
      elsif ($bc == 0x59) { $self->binop('>=') } # i64.ge_s
      elsif ($bc == 0x5a) { $self->binop('>=.') } # i64.ge_u
      elsif ($bc == 0x5b) { $self->binop('==') } # f32.eq
      elsif ($bc == 0x5c) { $self->binop('!=') } # f32.ne
      elsif ($bc == 0x5d) { $self->binop('<') } # f32.lt
      elsif ($bc == 0x5e) { $self->binop('>') } # f32.gt
      elsif ($bc == 0x5f) { $self->binop('<=') } # f32.le
      elsif ($bc == 0x60) { $self->binop('>=') } # f32.ge
      elsif ($bc == 0x61) { $self->binop('==') } # f64.eq
      elsif ($bc == 0x62) { $self->binop('!=') } # f64.ne
      elsif ($bc == 0x63) { $self->binop('<') } # f64.lt
      elsif ($bc == 0x64) { $self->binop('>') } # f64.gt
      elsif ($bc == 0x65) { $self->binop('<=') } # f64.le
      elsif ($bc == 0x66) { $self->binop('>=') } # f64.ge
      elsif ($bc == 0x67) { $self->unop('clz') } # i32.clz
      elsif ($bc == 0x68) { $self->unop('ctz') } # i32.ctz
      elsif ($bc == 0x69) { $self->unop('popcnt') } # i32.popcnt
      elsif ($bc == 0x6a) { $self->binop('+') } # i32.add
      elsif ($bc == 0x6b) { $self->binop('-') } # i32.sub
      elsif ($bc == 0x6c) { $self->binop('*') } # i32.mul
      elsif ($bc == 0x6d) { $self->binop('/') } # i32.div_s
      elsif ($bc == 0x6e) { $self->binop('/.') } # i32.div_u
      elsif ($bc == 0x6f) { $self->binop('%') } # i32.rem_s
      elsif ($bc == 0x70) { $self->binop('%.') } # i32.rem_u
      elsif ($bc == 0x71) { $self->binop('&') } # i32.and
      elsif ($bc == 0x72) { $self->binop('|') } # i32.or
      elsif ($bc == 0x73) { $self->binop('^') } # i32.xor
      elsif ($bc == 0x74) { $self->binop('<<') } # i32.shl
      elsif ($bc == 0x75) { $self->binop('>>') } # i32.shr_s
      elsif ($bc == 0x76) { $self->binop('>>.') } # i32.shr_u
      elsif ($bc == 0x77) { $self->binop('rotl') } # i32.rotl
      elsif ($bc == 0x78) { $self->binop('rotr') } # i32.rotr
      elsif ($bc == 0x79) { $self->unop('clz') } # i64.clz
      elsif ($bc == 0x7a) { $self->unop('ctz') } # i64.ctz
      elsif ($bc == 0x7b) { $self->unop('popcnt') } # i64.popcnt
      elsif ($bc == 0x7c) { $self->binop('+') } # i64.add
      elsif ($bc == 0x7d) { $self->binop('-') } # i64.sub
      elsif ($bc == 0x7e) { $self->binop('*') } # i64.mul
      elsif ($bc == 0x7f) { $self->binop('/') } # i64.div_s
      elsif ($bc == 0x80) { $self->binop('/.') } # i64.div_u
      elsif ($bc == 0x81) { $self->binop('%') } # i64.rem_s
      elsif ($bc == 0x82) { $self->binop('%.') } # i64.rem_u
      elsif ($bc == 0x83) { $self->binop('&') } # i64.and
      elsif ($bc == 0x84) { $self->binop('|') } # i64.or
      elsif ($bc == 0x85) { $self->binop('^') } # i64.xor
      elsif ($bc == 0x86) { $self->binop('<<') } # i64.shl
      elsif ($bc == 0x87) { $self->binop('>>') } # i64.shr_s
      elsif ($bc == 0x88) { $self->binop('>>.') } # i64.shr_u
      elsif ($bc == 0x89) { $self->binop('rotl') } # i64.rotl
      elsif ($bc == 0x8a) { $self->binop('rotr') } # i64.rotr
      elsif ($bc == 0x8b) { $self->unop('abs') } # f32.abs
      elsif ($bc == 0x8c) { $self->unop('-') } # f32.neg
      elsif ($bc == 0x8d) { $self->unop('ceil') } # f32.ceil
      elsif ($bc == 0x8e) { $self->unop('floor') } # f32.floor
      elsif ($bc == 0x8f) { $self->unop('trunc') } # f32.trunc
      elsif ($bc == 0x90) { $self->unop('nearest') } # f32.nearest
      elsif ($bc == 0x91) { $self->unop('sqrt') } # f32.sqrt
      elsif ($bc == 0x92) { $self->binop('+') } # f32.add
      elsif ($bc == 0x93) { $self->binop('-') } # f32.sub
      elsif ($bc == 0x94) { $self->binop('*') } # f32.mul
      elsif ($bc == 0x95) { $self->binop('/') } # f32.div
      elsif ($bc == 0x96) { $self->binop('min') } # f32.min
      elsif ($bc == 0x97) { $self->binop('max') } # f32.max
      elsif ($bc == 0x98) { $self->binop('copysign') } # f32.copysign
      elsif ($bc == 0x99) { $self->unop('abs') } # f64.abs
      elsif ($bc == 0x9a) { $self->unop('-') } # f64.neg
      elsif ($bc == 0x9b) { $self->unop('ceil') } # f64.ceil
      elsif ($bc == 0x9c) { $self->unop('floor') } # f64.floor
      elsif ($bc == 0x9d) { $self->unop('trunc') } # f64.trunc
      elsif ($bc == 0x9e) { $self->unop('nearest') } # f64.nearest
      elsif ($bc == 0x9f) { $self->unop('sqrt') } # f64.sqrt
      elsif ($bc == 0xa0) { $self->binop('+') } # f64.add
      elsif ($bc == 0xa1) { $self->binop('-') } # f64.sub
      elsif ($bc == 0xa2) { $self->binop('*') } # f64.mul
      elsif ($bc == 0xa3) { $self->binop('/') } # f64.div
      elsif ($bc == 0xa4) { $self->binop('min') } # f64.min
      elsif ($bc == 0xa5) { $self->binop('max') } # f64.max
      elsif ($bc == 0xa6) { $self->binop('copysign') } # f64.copysign
      elsif ($bc == 0xa7) { $self->unop('i64_to_i32') } # i32.wrap_i64
      elsif ($bc == 0xa8) { $self->unop('f32_to_s32') } # i32.trunc_f32_s
      elsif ($bc == 0xa9) { $self->unop('f32_to_u32') } # i32.trunc_f32_u
      elsif ($bc == 0xaa) { $self->unop('f64_to_s32') } # i32.trunc_f64_s
      elsif ($bc == 0xab) { $self->unop('f64_to_u32') } # i32.trunc_f64_u
      elsif ($bc == 0xac) { $self->unop('s32_to_s64') } # i64.extend_i32_s
      elsif ($bc == 0xad) { $self->unop('u32_to_u64') } # i64.extend_i32_u
      elsif ($bc == 0xae) { $self->unop('f32_to_s64') } # i64.trunc_f32_s
      elsif ($bc == 0xaf) { $self->unop('f32_to_u64') } # i64.trunc_f32_u
      elsif ($bc == 0xb0) { $self->unop('f64_to_s64') } # i64.trunc_f64_s
      elsif ($bc == 0xb1) { $self->unop('f64_to_u64') } # i64.trunc_f64_u
      elsif ($bc == 0xb2) { $self->unop('s32_to_f32') } # f32.convert_i32_s
      elsif ($bc == 0xb3) { $self->unop('u32_to_f32') } # f32.convert_i32_u
      elsif ($bc == 0xb4) { $self->unop('s64_to_f32') } # f32.convert_i64_s
      elsif ($bc == 0xb5) { $self->unop('u64_to_f32') } # f32.convert_i64_u
      elsif ($bc == 0xb6) { $self->unop('f64_to_f32') } # f32.demote_f64
      elsif ($bc == 0xb7) { $self->unop('s32_to_f64') } # f64.convert_i32_s
      elsif ($bc == 0xb8) { $self->unop('u32_to_f64') } # f64.convert_i32_u
      elsif ($bc == 0xb9) { $self->unop('s64_to_f64') } # f64.convert_i64_s
      elsif ($bc == 0xba) { $self->unop('u64_to_f64') } # f64.convert_i64_u
      elsif ($bc == 0xbb) { $self->unop('f32_to_f64') } # f64.promote_f32
      elsif ($bc == 0xbc) { $self->unop('f32_to_bits') } # i32.reinterpret_f32
      elsif ($bc == 0xbd) { $self->unop('f64_to_bits') } # i64.reinterpret_f64
      elsif ($bc == 0xbe) { $self->unop('bits_to_f32') } # f32.reinterpret_i32
      elsif ($bc == 0xbf) { $self->unop('bits_to_f64') } # f64.reinterpret_i64
      else { last }
   }
   @{$self->{blocks}} = ();
   $self->stmt('err', 'all');
   return;
}

sub stmt {
   my ($self, $stmt, $touch) = @_;
   $touch ||= 'none';
   my $indent = '| ' x @{$self->{blocks}};
   my $file = $self->{file};
   foreach my $val (@{$self->{values}}) {
      next unless $val->{touch}{$touch} || $touch eq 'all';
      my $tmp = 'tmp' . $self->{temp}++;
      print $file $indent, "$tmp = $val->{val}\n";
      $val->{val} = $tmp;
      $val->{op} = 0;
      $val->{touch} = {};
   }
   print $file $indent, $stmt, "\n" if $stmt;
}

sub push_val {
   my ($self, $val, @touch) = @_;
   my %touch;
   foreach my $touch (@touch) {
      if (ref($touch) eq 'HASH') {
         $touch{$_} = 1 foreach keys %$touch;
      }
      else {
         $touch{$touch} = 1;
      }
   }
   my $op = delete $touch{op};
   push @{$self->{values}}, { val=>$val, op=>$op, touch=>\%touch };
}

sub pop_val {
   my ($self) = @_;
   return pop(@{$self->{values}}) // { val=>'?' };
}

sub unop {
   my ($self, $op) = @_;
   my $x = $self->pop_val();
   my $xv = $x->{val};
   if ($op =~ /^\w/) {
      $self->push_val("$op($xv)", $x->{touch});
   }
   else {
      $xv = "($xv)" if $x->{op};
      $self->push_val($op.$xv, $x->{touch});
   }
}

sub binop {
   my ($self, $op) = @_;
   my $y = $self->pop_val();
   my $x = $self->pop_val();
   my $xv = $x->{val};
   my $yv = $y->{val};
   if ($op =~ /^\w/) {
      $self->push_val("$op($xv,$yv)", $x->{touch}, $y->{touch});
   }
   else {
      $xv = "($xv)" if $x->{op};
      if ($y->{op}) { $yv = "($yv)" }
      elsif ($op eq '+' && $yv =~ s/^-//) { $op = '-' }
      elsif ($op eq '-' && $yv =~ s/^-//) { $op = '+' }
      if ($xv eq '0' && $op eq '-') {
         $self->push_val("-$yv", $y->{touch});
      }
      elsif ($xv eq '0' && $op eq '+') {
         $self->push_val($yv, $y->{touch});
      }
      else {
         $self->push_val("$xv $op $yv", 'op', $x->{touch}, $y->{touch});
      }
   }
}

sub drop {
   my ($self) = @_;
   my $val = $self->pop_val()->{val};
   $self->stmt("drop $val");
}

sub trinary {
   my ($self) = @_;
   my $v = 'tri' . $self->{temp}++;
   my $c = $self->pop_val()->{val};
   my $y = $self->pop_val()->{val};
   my $x = $self->pop_val()->{val};
   $self->stmt("$v = $c ? $x : $y");
   $self->push_val($v);
}

sub iconst {
   my ($self, $wasm) = @_;
   my $val = $wasm->read_int();
   $self->push_val($val);
}

sub f32const {
   my ($self, $wasm) = @_;
   my $val = sprintf '%.8g', unpack('f', $wasm->read_raw(4));
   $self->push_val($val);
}

sub f64const {
   my ($self, $wasm) = @_;
   my $val = unpack('d', $wasm->read_raw(8));
   $self->push_val($val);
}

sub get_local {
   my ($self, $wasm) = @_;
   my $loc = 'loc' . $wasm->read_uint();
   $self->push_val($loc, $loc);
}

sub set_local {
   my ($self, $wasm, $tee) = @_;
   my $loc = 'loc' . $wasm->read_uint();
   my $val = $self->pop_val()->{val};
   $self->stmt("$loc = $val", $loc);
   $self->push_val($loc, $loc) if $tee;
}

sub set_global {
   my ($self, $wasm) = @_;
   my $num = $wasm->read_uint();
   my $val = $self->pop_val()->{val};
   my $glob = $wasm->{globals}[$num];
   my $name = ($glob && $glob->{name}) ? $glob->{name} : "glob$num";
   $self->stmt("$name = $val", $name);
}

sub get_global {
   my ($self, $wasm) = @_;
   my $num = $wasm->read_uint($wasm);
   my $glob = $wasm->{globals}[$num];
   my $name = ($glob && $glob->{name}) ? $glob->{name} : "glob$num";
   $self->push_val($name, $name, 'memglob');
}

sub branch {
   my ($self, $wasm, $if) = @_;
   my $idx = $wasm->read_uint();
   my $blocks = $self->{blocks};
   return if $idx >= @$blocks;
   my $blk = $blocks->[-1-$idx];
   $blk->{targ} = 1;
   if ($blk->{type}) {
      my $val = $self->pop_val()->{val};
      $self->stmt("$blk->{lbl} = $val");
   }
   $self->stmt("br $blk->{lbl}");
   return 1;
}

sub branch_if {
   my ($self, $wasm) = @_;
   my $idx = $wasm->read_uint();
   my $blocks = $self->{blocks};
   return if $idx >= @$blocks;
   my $blk = $blocks->[-1-$idx];
   $blk->{targ} = 1;
   my $cond = $self->pop_val()->{val};
   $self->stmt("if $cond");
   push @$blocks, { kind=>'br_if' };
   my $values = $self->{values};
   my $val;
   if ($blk->{type}) {
      $val = pop @$values;
      $self->stmt("$blk->{lbl} = $val->{val}") if $val;
   }
   $self->stmt("br $blk->{lbl}");
   push @$values, $val if $val;
   pop @$blocks;
   $self->stmt('end');
   return 1;
}

sub br_table {
   my ($self, $wasm) = @_;
   my $num = $wasm->read_uint();
   my $blocks = $self->{blocks};
   my @lbls;
   for (0 .. $num) {
      my $idx = $wasm->read_uint();
      return if $idx >= @$blocks;
      my $blk = $blocks->[-1-$idx];
      $blk->{targ} = 1;
      push @lbls, $blk->{lbl};
   }
   my $else = pop @lbls;
   my $val = $self->pop_val()->{val};
   my $stmt = "br_table {$val}";
   for my $i (0 .. $num-1) {
      $stmt .= " $i:$lbls[$i]" unless $lbls[$i] eq $else;
   }
   $stmt .= " else:$else";
   $self->stmt($stmt);
   return 1;
}

sub call {
   my ($self, $wasm) = @_;
   my $num = $wasm->read_uint();
   my $func = $wasm->{funcs}[$num];
   if (!$func) {
      $self->stmt("call $num", 'memglob');
      @{$self->{values}} = ();
      return;
   }
   $self->do_call('call', $func->{name} || $num, $func->{type});
}

sub call_ind {
   my ($self, $wasm) = @_;
   my $idx = $wasm->read_uint();
   $wasm->read_byte() == 0 or return;
   my $type = $wasm->{types}[$idx] or return '?';
   my $arg = $self->pop_val()->{val};
   $self->do_call('call_indirect', "{$arg}", $wasm->{types}[$idx]);
   return 1;
}

sub do_call {
   my ($self, $op, $name, $type) = @_;
   if (!$type || $type->{type} ne 'func') {
      $self->stmt("$op $name", 'memglob');
      @{$self->{values}} = ();
      return;
   }
   my @args;
   for my $i (0 .. $#{$type->{in}}) {
      push @args, $self->pop_val()->{val};
   }
   my @ret;
   for my $i (0 .. $#{$type->{out}}) {
      push @ret, 'ret' . $self->{temp}++;
   }
   my $stmt = '';
   $stmt .= join(',', @ret) . ' = ' if @ret;
   $stmt .= "$op $name (" . join(', ', reverse @args) . ')';
   $self->stmt($stmt, 'memglob');
   foreach my $ret (@ret) {
      $self->push_val($ret);
   }
}

sub do_return {
   my ($self) = @_;
   my $stmt = 'return';
   my $val = pop @{$self->{values}};
   $stmt .= ' ' . $val->{val} if $val;
   $self->stmt($stmt);
}

sub block {
   my ($self, $op, $wasm) = @_;
   my $type = $wasm->read_simple_type() or return;
   my $lbl = $op . $self->{temp}++;
   $self->stmt($op eq 'loop' ? "do $lbl" : $op);
   if ($type eq 'null') { $type = '' }
   else { $self->push_val($lbl) }
   push @{$self->{blocks}}, {
      kind   => $op,
      type   => $type,
      lbl    => $lbl,
      values => $self->{values},
   };
   $self->{values} = [];
   return 1;
}

sub if_block {
   my ($self, $wasm) = @_;
   my $type = $wasm->read_simple_type() or return;
   my $val = $self->pop_val()->{val};
   $self->stmt("if $val");
   my $lbl = 'if' . $self->{temp}++;
   if ($type eq 'null') { $type = '' }
   else { $self->push_val($lbl) }
   push @{$self->{blocks}}, {
      kind   => 'if',
      type   => $type,
      lbl    => $lbl,
      values => $self->{values},
   };
   $self->{values} = [];
   return 1;
}

sub else_block {
   my ($self) = @_;
   my $blocks = $self->{blocks};
   return unless @$blocks;
   my $blk = $blocks->[-1];
   return unless $blk->{kind} eq 'if';
   if ($blk->{type}) {
      my $val = $self->pop_val()->{val};
      $self->stmt("$blk->{lbl} = $val", 'all');
   }
   else { $self->stmt('', 'all') }
   pop @$blocks;
   $self->stmt('else');
   push @$blocks, $blk;
   return 1;
}

sub end_block {
   my ($self) = @_;
   my $blocks = $self->{blocks};
   if (@$blocks) {
      my $blk = $blocks->[-1];
      if ($blk->{type}) {
         my $val = $self->pop_val()->{val};
         $self->stmt("$blk->{lbl} = $val", 'all');
      }
      else {
         $self->stmt('', 'all');
      }
      pop @$blocks;
      my $end = 'end';
      $end .= ' ' . $blk->{lbl} if $blk->{targ} && $blk->{kind} ne 'loop';
      $self->stmt($end);
      $self->{values} = $blk->{values} || [];
      return;
   }
   else {
      my $val = pop @{$self->{values}};
      $self->stmt("return $val->{val}") if $val;
      $self->stmt('end', 'all');
      return 1;
   }
}

sub mem_size {
   my ($self, $wasm) = @_;
   $wasm->read_byte() == 0 or return;
   my $op = 'mem.size';
   $self->push_val($op, $op);
   return 1;
}

sub mem_grow {
   my ($self, $wasm) = @_;
   $wasm->read_byte() == 0 or return;
   my $val = $self->pop_val()->{val};
   $self->stmt("mem.grow $val", 'mem.size');
   return 1;
}

sub load {
   my ($self, $type, $wasm) = @_;
   $wasm->read_byte(); # align
   my $off = $wasm->read_uint();
   my $addr = $self->pop_val();
   my $loc = $addr->{val};
   $loc =~ s/ //g;
   if ($off) {
      $loc = $addr->{op} ? "($loc)" : $loc;
      $loc .= '+' . $off;
   }
   $self->push_val("mem_$type\[$loc]", 'mem', 'memglob', $addr->{touch});
}

sub store {
   my ($self, $type, $wasm) = @_;
   $wasm->read_byte(); # align
   my $off = $wasm->read_uint();
   my $val = $self->pop_val()->{val};
   my $addr = $self->pop_val();
   my $loc = $addr->{val};
   $loc =~ s/ //g;
   if ($off) {
      $loc = $addr->{op} ? "($loc)" : $loc;
      $loc .= '+' . $off;
   }
   $self->stmt("mem_$type\[$loc] = $val", 'mem');
}

1 # end Wasm::Disasm
