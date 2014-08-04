# NAME

Stacktrace::Configurable - a configurable Perl stack trace

# SYNOPSIS

    use Stacktrace::Configurable;

    Stacktrace::Configurable->new(format=>$fmt)->get_trace->as_string;

# DESCRIPTION

The idea for `Stacktrace::Configurable` came when I needed a easily readable
stack trace in [Log::Log4perl](https://metacpan.org/pod/Log::Log4perl) output. That distribution's pattern layout
can give you a stack trace but it's not very readable. There are other
modules out there that provide a caller stack, like [Devel::StackTrace](https://metacpan.org/pod/Devel::StackTrace)
and [Carp](https://metacpan.org/pod/Carp). Choose what suits you best.

A stack trace is basically a list of stack frames starting with the place
where the [get\_trace](#obj-get_trace) method is called down to the main
program. The first element in that list is also called the topmost frame.

Each frame of the list collected by [get\_trace](#obj-get_trace) is a
[Stacktrace::Configurable::Frame](https://metacpan.org/pod/Stacktrace::Configurable::Frame) object which provides simple
accessors for the information returned by `caller`. Additionally,
a frame has a ["nr" in Stacktrace::Configurable::Frame](https://metacpan.org/pod/Stacktrace::Configurable::Frame#nr) attribute which
contains its position in the list starting from `1` (topmost).

## Constructor

The constructor `Stacktrace::Configurable->new` is called with a
list of key/value pairs as parameters. After constructing an empty object
it uses each of those keys as method name and calls it passing the
value as parameter.

Example:

    $trace=Stacktrace::Configurable->new(format=>$fmt);

## Attributes

Attributes are simple accessor methods that provide access to scalar
variables stored in the object. If called with a parameter the new value
is stored. The return value is always the new or current value.

These attributes are implemented:

- format

    the format specification, see [below](#format)

- frames

    the stack trace. It is an arrayref of [Stacktrace::Configurable::Frame](https://metacpan.org/pod/Stacktrace::Configurable::Frame)
    objects usually initialized by the [get\_trace](#obj-get_trace) method.

## Public Methods

- $obj->get\_trace

    collects the stack trace with the caller of `get_trace` as the topmost
    frame and stores it as `$obj->frames`.

    Returns the object itself to allow for chained calls like

        $obj->get_trace->as_string;

- $obj->as\_string

    formats the stack trace according to the current format and returns
    the resulting string.

## Methods interesting for subclassing

- $obj->skip\_package\_re

    returns the empty list. If overwritten by subclasses, it should return
    a regular expression matching package names which is used to skip stack
    frames from the top of the stack. `get_trace` starts to collect stack
    frames from the top of the stack. If `skip_package_re` returns a regexp,
    it drops those frames as long as their `package` matches the regexp.
    Once a non-matching package is discovered all remaining frames are
    included in the trace no matter what `package`.

    This allows you to skip frames internal to your subclass from the top
    of the stack if you are not sure of the nesting level at which
    `get_trace` is called.

- $obj->skip\_package\_number

    Similar to `skip_package_re`, only it specifies the actual nesting level.
    For the base class (`Stacktrace::Configurable`) 1 is returned.

- $obj->default\_format

    this method returns a constant that is used by the constructor to
    initialize the `format` attribute if omitted.

    The current default format is:

        'env=STACKTRACE_CONFIG,'.
        '%[nr=1,s=    ==== START STACK TRACE ===]b%[nr=1,n]b'.
        '%4b[%*n] at %f line %l%[n]b'.
        '%12b%[skip_package]s %[env=STACKTRACE_CONFIG_A]a'.
        '%[nr!STACKTRACE_CONFIG_MAX,c=%n    ... %C frames cut off]b'.
        '%[nr=$,n]b%[nr=$,s=    === END STACK TRACE ===]b%[nr=$,n]b'

- $obj->fmt\_b
- $obj->fmt\_n
- $obj->fmt\_s
- $obj->fmt\_a
- $obj->fmt\_f
- $obj->fmt\_l
- $obj->fmt\_c
- $obj->fmt\_p

    these methods format a certain portion of a stack frame. They are called
    as methods. So, the first parameter is the object itself. The following
    parameters are:

    - $frame

        the frame to format

    - $width

        the width part of the format specification

    - $param

        the param part of the format specification

    Return value: the formatted string

## Private Methods

- $obj->\_use\_dumper

## Format

The format used by [Stacktrace::Configurable](https://metacpan.org/pod/Stacktrace::Configurable) is inspired by `printf` and
[Log::Log4perl::Layout::PatternLayout](https://metacpan.org/pod/Log::Log4perl::Layout::PatternLayout).

The first format component is an optional string starting with `env=` and
ending in a comma, like

    env=STACKTRACE_CONFIG,

If this component is found `as_string` consults the specified environment
variable for instructions. If the variable is `off`, `no` or `0`, no
stack trace at all is created and `as_string` returns the empty string.

If after stripping of that first component, the format becomes the empty
string the value of the environment variable or, if also empty, the
default format is used as format specification.

The rest of the format is a string with embedded format specifications or
_fspec_. An fspec starts with a percent sign, `%`. Then follows an
optional width component, an optional parameter component and the
mandatory format letter.

The width component is just an integer number optionally prepended with
a minus sign or an asterisk (`*`). Not every fspec uses the width
component or does something useful for `*`.

The parameter component is surrounded by brackets (`[]`).

The parsing of an fspec is kept simple. So, it does not support nested
brackets or similar.

The following format letters are implemented:

- b

    Originally the name `b` was chosen because `s` was already in use. It
    stands for _blank_ or empty space. Though, it can generate arbitrary
    output and be based on conditions.

    The simplest form `%b` just outputs one space. Add a width component,
    `%20b` and you get 20 spaces.

    The parameter component is a set of 2 optional items separated by
    comma. The first item specifies a condition. The second modifies the
    string used in place of the space.

    Let's first look at examples where the condition part is omitted. The
    `n` parameter tells to use a newline instead of a space. So,
    `%20[n]b` inserts 20 newline characters. The parameter `t` does the
    same only that a tabulator character is used. `%20[t]b` results in
    20 tabs. The 3rd option is the `s=` parameter. It allows you to
    specify arbitrary strings. `%4[s=ab]b` results in

        abababab

    Now, let's look at conditional output. The `nr=` parameter matches a
    specific stack frame given by its number. It is most useful at the start
    and the end of the stack trace.

    Examples:

        %[nr=1,s=stack trace start]b

    if given at the beginning of the format, this specification prints the
    string `stack trace start` but only for the topmost frame.

        %[nr=$,s=stack trace end]b

    `nr=$` matches only for the last stack frame. So, the fspec above prints
    `stack trace end` at the end of the trace.

    The `nr!` condition also matches a specific frame given by its number.
    But in addition to generate output it cuts off the trace after the
    current frame. It is used if you want to print only the topmost N frames.
    It is often used with the empty string as what to print, like

        %[nr!10,s=]b

    This prints nothing but cuts off the stack trace after the 10th frame.

    If the part after the exclamation mark is not a number but matches `\w+`,
    it is taken as the name of an environment variable. If set and if it is a
    number, that number is taken instead of the literal number above.

    In combination with this condition there is another parameter to specify
    the string, `c=` or the cutoff message. It is printed only if there has
    been cut off at least one frame. Also, the cutoff message can contain `%n`
    and `%C` (capital C). The former is replaced by a newline, the latter by
    the number of frames cut off.

    This allows for the following pattern:

        %[nr!MAX,c=%ncutting off remaining %C frames]n

    Now, let's assume `$ENV{MAX}=4` but the actual stack is 20 frames deep.
    The specification tells to insert an additional newline for the 4th frame
    followed by the string `cutting off remaining 16 frames`.

    The last condition is `nr%N` and `nr%N=M`. It can be used to insert a
    special delimiter after every N stack frames.

        %[nr%10=1,n]b%80[nr%10=1,s==]b

    prints a delimiter consisting of a newline and 80 equal signs after
    every 10th frame.

    The condition is true if `frame_number % M == N` where N defaults to 0.

- n

    inserts the frame number. This format ignores the parameter component.
    Width can be given as positive or negative number an is interpreted just
    like in `sprintf`. If width is `*` or `-*`, the actual width is taken
    to fit the largest frame number.

    Examples:

        %n
        %4n
        %-4n
        %*n
        %-*n

- s

    inserts the subroutine. The width component is ignored and only one
    parameter is known, `skip_package`. If specified, the package where the
    function belongs to is omitted.

    Examples:

        %s                   # might print "Pack::Age::fun"
        %[skip_package]s     # prints only "fun"

- a

    inserts the subroutine arguments. The width component is ignored. The
    parameter component is a comma separated list of

    - dump

        all arguments are dumped using [Data::Dumper](https://metacpan.org/pod/Data::Dumper). The dumper object is
        configured in a way to print the whole thing in one line.

        This may cause very verbose stack traces.

    - dump=Pack::Age

        all arguments for which `ref` returns `Pack::Age` are dumped using
        [Data::Dumper](https://metacpan.org/pod/Data::Dumper).

        You can, of course, also dump simple ARRAYs, HASHes etc.

    - dump=/regexp/

        all arguments for which `ref` matches the regexp are dumped using
        [Data::Dumper](https://metacpan.org/pod/Data::Dumper).

        If multiple such parameters are given, an argument that matches at least
        one regexp is dumped.

    - deparse

        if `dump` or `dump=CODE` is also specified, the dumper object is
        configured to deparse the subroutine that is passed in the argument.

    - multiline
    - multiline=N
    - multiline=N.M

        normally, all arguments are printed in one line separated by comma and space.
        With this parameter every argument is printed on a separate line.

        A format containing `%s %[multiline]a` would for instance generate this
        output:

            main::function (
                    "param1",
                    2,
                    "p3"
                )

        The surrounding parentheses are part of the `%a` output.

        `N` and `M` are indentation specifications. `N` tells how many positions
        the closing parenthesis is indented. `M` tells how many positions further
        each parameter is indented. The default value for both is 4.

    - env=ENVVAR

        This parameter reads the environment variable `ENVVAR` and appends it to
        the parameter list.

    Examples:

        %[dump,deparse,multiline]a    # very verbose

- f

    inserts the file name. This fspec recognizes the following parameters:

    - skip\_prefix=PREFIX

        if the file name of the stack frame begins with `PREFIX`, it is cut off.

        For instance, if your personal Perl modules are installed in
        `/usr/local/perl`, then you might specify

            %[skip_prefix=/usr/local/perl/]f

    - basename

        cuts off the directory part of the file name.

        If a width component is specified and the file name is longer than the
        absolute value of the given width, then if the width is positive, the
        file name is cut at the end to meet the given width. If the width is
        negative, the file name is cut at the start to meet the width. Then
        an ellipsis (3 dots) is appended or prepended.

- l

    inserts the line number. The width component is interpreted like in
    `sprintf`.

- c

    prints the context of the subroutine call as `void`, `scalar` or `list`.

- p

    prints the package name of the stack frame.

    The `%p` fspec recognizes the `skip_prefix` parameter just like `%f`.

    The width component is also interpreted the same way as for `%f`.

Examples:

    env=T,%f(%l)   # one line of "filename.pm(23)" for each frame
                   # unless $ENV{T} is "off", "no" or "0"

    env=T,         # use the format given in $ENV{T}
                   # unless $ENV{T} is "off", "no" or "0"

## Subclassing

TODO

# AUTHOR

Torsten Förtsch <torsten.foertsch@gmx.net>

# COPYRIGHT

Copyright 2014- Torsten Förtsch

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[Carp](https://metacpan.org/pod/Carp), [Devel::StackTrace](https://metacpan.org/pod/Devel::StackTrace),
[Log::Log4perl::Layout::PatternLayout::Stacktrace](https://metacpan.org/pod/Log::Log4perl::Layout::PatternLayout::Stacktrace)
