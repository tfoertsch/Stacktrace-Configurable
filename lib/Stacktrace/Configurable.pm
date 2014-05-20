package Stacktrace::Configurable;

use strict;
use 5.01;
our $VERSION = '0.01';

use Stacktrace::Configurable::Frame;

use Scalar::Util qw/looks_like_number/;
use Data::Dumper ();
no warnings 'uninitialized';    ## no critic

our @attr;

BEGIN {
    @attr=(qw/format/);
    for (@attr) {
        my $attr=$_;
        no strict 'refs';
        *{__PACKAGE__.'::'.$attr}=sub : lvalue {
            my $I=$_[0];
            $I->{$attr}=$_[1] if @_>1;
            $I->{$attr}=$_[1];
        };
    }
}

sub skip_package_re {
    qr/^Stacktrace::Configurable/;
}

sub default_format {
    ('%[nr=1,s=    ==== START STACK TRACE ===]b%[nr=1,n]b'.
     '%4b[%*n] at %f line %l%[n]b'.
     '%12b%[skip_package]s %a%[nr=$,n]b'.
     '%[nr=$,s=    === END STACK TRACE ===]b%[nr=$,n]b');
}

sub get_trace {
    my $I=shift;

    my $i=1;
    my $skip_re=$I->skip_package_re;

    my @trace;
    while (my @l=do {
        package
            DB;
        @DB::args=();
        CORE::caller $i++;
    }) {
        next if !@trace and $l[0]=~$skip_re;
        push @trace, Stacktrace::Configurable::Frame->new(@l, [@DB::args]);
    }
    $I->{_stack}=\@trace;
    return $I;
}

sub new {
    my $class = shift;
    $class = ref($class)||$class;

    my $I = bless {}=>$class;
    for (my $i = 0; $i<@_; $ i+= 2) {
        my $m = $_[$i];
        $I->$m($_[$i+1]);
    }

    $I->{format} ||= 'env=STACKTRACE_CONFIG,'.$I->default_format;

    return $I;
}

sub _use_dumper {
    my $p = $_[0];
    return 0 if looks_like_number $_;
    ref and return $p->{dump} || $p->{pkg_dump}->{ref()} || do {
        my $arg = $_;
        !!map({ref($arg) =~ /$_/} @{$p->{pkg_dump_re}});
    };
    return 0;
}

my %formatter =
    (
     b => sub {
         my ($I, $frame, $width, $param) = @_;
         my $nr = $I->{_nr};
         $width //= 1;
         if ($param =~ s/^nr!(\d+),//) {
             return '' unless $nr == $1;
             $#{$I->{_stack}} = $1 - 1;
         } elsif ($param =~ s/^nr%(\d+)(?:=(\d+))?,//) {
             return '' unless $nr % $1 == ($2//0);
         } elsif ($param =~ s/^nr=(\d+|\$),//) {
             if ($1 eq '$') {
                 return '' unless $nr == @{$I->{_stack}};
             } else {
                 return '' unless $nr == $1;
             }
         }
         if ($param =~ s/^s=//) {
             return $param x $width;
         } else {
             return +($param eq 'n'
                      ? "\n"
                      : $param eq 't'
                      ? "\t"
                      : ' ') x $width;
         }
     },
     n => sub {    # frame number
         my ($I, $frame, $width, $param) = @_;
         if ($width eq '*') {
             $width = length '' . (0 + @{$I->{_stack}});
         } elsif ($width eq '-*') {
             $width = -length '' . (0 + @{$I->{_stack}});
         }
         return sprintf "%${width}d", $I->{_nr};
     },
     s => sub {    # subroutine
         my ($I, $frame, $width, $param) = @_;
         if (my $eval = $frame->{evaltext}) {
             return "require $eval" if $frame->{is_require};
             $eval =~ s/([\\\'])/\\$1/g;
             return "eval '$eval'";
         }
         my $s = $frame->{subroutine};

         for (split /,\s*/, $param) {
             last if s/^skip_package// and $s =~ s!^.*::!!;
         }
         return $s;
     },
     a => sub {    # args
         my ($I, $frame, $width, $param) = @_;
         return '' unless $frame->{hasargs};
         my @param = split /,\s*/, $param;
         my %p;
         for (@param) {
             ## no critic
             $p{dump} = 1,                          next if /^dump$/;
             $p{pkg_dump}->{$1} = 1,                next if m~^dump=(?!/)(.+)$~;
             push(@{$p{pkg_dump_re}}, $1),          next if m~^dump=/(.+)/$~;
             push(@param, split /,\s*/, $ENV{$1}),  next if /^env=(.+)/;
             $p{deparse} = 1,                       next if /^deparse$/;
         }
         return '('.join(', ', map {
             (!defined $_
              ? "undef"
              : _use_dumper (\%p)
              ? Data::Dumper->new([$_])->Useqq(1)->Deparse($p{deparse} || 0)
                    ->Indent(0)->Terse(1)->Dump
              : "$_");
         } @{$frame->{args}}).')';
     },
     f => sub {                # filename
         my ($I, $frame, $width, $param) = @_;
         my $fn = $frame->{filename};
         for (split /,\s*/, $param) {
             last if s/^skip_prefix=// and $fn =~ s!^\Q$_\E!!;
         }
         return substr($fn, 0, $width) . '...'
             if $width > 0 and length $fn > $width;
         return '...' . substr($fn, $width)
             if $width < 0 and length $fn > -$width;
         return $fn;
     },
     l => sub {                # linenr
         my ($I, $frame, $width, $param) = @_;
         return sprintf "%${width}d", $frame->{line};
     },
     c => sub {                # context (void/scalar/list)
         my ($I, $frame, $width, $param) = @_;
         return (!defined $frame->{wantarray}
                 ? 'void'
                 : $frame->{wantarray}
                 ? 'list'
                 : 'scalar');
     },
     p => sub {                # package
         my ($I, $frame, $width, $param) = @_;
         my $pn = $frame->{package};
         for (split /,\s*/, $param) {
             last if s/^skip_prefix=// and $pn =~ s!^\Q$_\E!!;
         }
         return substr($pn, 0, $width) . '...'
             if $width > 0 and length $pn > $width;
         return '...' . substr($pn, $width)
             if $width < 0 and length $pn > -$width;
         return $pn;
     },
    );

sub as_string {
    my $I = shift;
    my $fmt = $I->{format};

    my %seen;
    while ($fmt =~ s/^env=(\w+)(,|$)//) {
        my $var = $1;
        return '' if $ENV{$var}=~/^(?:off|no|0)$/i;

        undef $seen{$var};
        unless (length $fmt) {
            $fmt = $ENV{$var} || $I->default_format;
            $fmt =~ /^env=(\w+)(,|$)/ and exists $seen{$1} and
                $fmt = $I->default_format; # cycle detected
        }
    }

    local $@;
    local $SIG{__DIE__};

    my $s = '';
    $I->{_nr} = 0;
    for my $frame (@{$I->{_stack}}) {
        $I->{_nr}++;
        my $l = $fmt;
        $l =~ s/
                   %                         # leading %
                   (?:
                       (%)
                   |
                       (-?(?:\d+|\*))?       # width
                       (?:\[(.+?)\])?        # modifiers
                       ([bnasflcp])          # placeholder
                   )
               /$1 ? $1 : $formatter{$4}->($I, $frame, $2, $3)/gex;
        $s .= $l."\n";
    }
    chomp $s;

    return $s;
}

1;
__END__

=encoding utf-8

=head1 NAME

Stacktrace::Configurable - Blah blah blah

=head1 SYNOPSIS

  use Stacktrace::Configurable;

=head1 DESCRIPTION

Stacktrace::Configurable is

=head1 AUTHOR

Torsten Förtsch E<lt>torsten.foertsch@gmx.netE<gt>

=head1 COPYRIGHT

Copyright 2014- Torsten Förtsch

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
