package Stacktrace::Configurable::Frame;

use strict;
use 5.01;
our $VERSION = '0.01';

our @attr;

sub new {
    my $class=shift;
    $class=ref($class)||$class;

    my $I=bless {}=>$class;

    @{$I}{@attr} = @_;

    return $I;
}

BEGIN {
    @attr=(qw/package filename line subroutine hasargs
              wantarray evaltext is_require hints bitmask
              hinthash nr args/);
    for (@attr) {
        my $attr=$_;
        no strict 'refs';
        *{__PACKAGE__.'::'.$attr}=sub : lvalue {
            my $I=$_[0];
            $I->{$attr}=$_[1] if @_>1;
            $I->{$attr};
        };
    }
}

1;
