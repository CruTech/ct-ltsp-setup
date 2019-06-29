#! /usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Log::Any::Adapter ('Stdout');
use Try::Tiny;
use Path::Tiny qw( path tempdir );

use_ok('ServerSetup');
use ServerSetup qw(
    Ok
    Err
    is_err
    unwrap
    execute_cmd
    command_executor

    install
    install_chroot
    systemctl
    where

    write_file
    edit_file
);

#
# Result
#

is unwrap(Ok(1)),                               1, 'unwrap ok';

is is_err(Ok(1)),                               0, 'is_err false for Ok';
is is_err(Err('test error')),                   1, 'is_err true for Err';

dies_ok(sub { unwrap(Err('test error')) },          'unwrap err throws');
dies_ok(sub { unwrap({'not-a-result' => 'foo'}) }, 'unwrap not a result throws');

#
# Command execution
#
is is_err(execute_cmd('foo')), 1, 'Execute bogus command';
is is_err(execute_cmd(qw(perl -v))), 0, 'Execute valid command';

is is_err(command_executor([ sub { Err('test error') } ], undef)->[0]), 1, "Sub command executes and returns result (Err)";
is is_err(command_executor([ sub { Ok(1) } ], undef)->[0]),             0, "Sub command executes and returns result (Ok)";

is is_err(command_executor([ [qw(perl -v)] ], undef)->[0]),             0, "Execute cmd (ArrayRef)";
is is_err(command_executor([ [] ], undef)->[0]),                        1, "Execute cmd (ArrayRef (Empty))";
is is_err(command_executor( ['perl -v'], undef)->[0]),                  0, "Execute cmd (Str)";
is is_err(command_executor( ['foo'], undef)->[0]),                      1, "Execute cmd (Str) - Bad command";

is is_err(command_executor( [{}], undef)->[0]),                         1, "Execute cmd (HashRef)";

#
# Command macros
#
is join(' ', install('foo')->@*), 'apt-get --yes install foo', 'install macro for apt-get';

is join(' ', install_chroot('foo')->@*), 'ltsp-chroot -m apt-get --yes install foo', 'install macro for apt-get on ltsp-chroot';

is join(' ', systemctl(start => 'foo')->@*), 'systemctl start foo', 'systemctl macro';

is join(', ', where(1, 'true')), 'true', 'Values for true predicate are included';
is where(0, 'true'), (), 'Values for false predicate are ommitted';

#
# Runtime command tests
#
{
    my $temp = tempdir('ltsp-setup-temp-XXXX');
    my $in_file = $temp->child('test-in');
    my $out_file = $temp->child('test-out');

    $in_file->spew('foo');
    my $editor = edit_file(
        $in_file->stringify,
        $out_file->stringify,
        sub { shift =~ s/f/b/gmrx },
        sub { shift =~ s/o+/ar/gmrx }
    );

    is !is_err($editor->()), 1, 'Editor executed';
    is $out_file->slurp, 'bar', 'Editor edited content';

    # Write file test
    my $test_file = Path::Tiny->tempfile('test-write_file-XXXX');
    ok !is_err( write_file($test_file->stringify, sub { 'foo' })->() ), "write_file executed with Ok result";
    is $test_file->slurp, 'foo', 'Write content to file with write_file closure';
}


done_testing();

# Test that callable throws an exception when expected
sub dies_ok {
    my $test = shift;
    my $msg = shift;

    my $test_died = 0;
    try {
        $test->()
    }
    catch {
        $test_died = 1;
    };

    $test_died ? pass($msg) : fail($msg)
}