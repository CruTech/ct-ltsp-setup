#! /usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Path::Tiny;

use YAML::PP qw(Load Dump);

use ServerSetup qw(
    generate_static_netplan
);

# Test environment
my $res = path('t/res');
ok $res->is_dir, "$res directory exists";

my $target = $res->child('target-netplan-static.yaml');
ok $target->is_file, "$target exists";

is_deeply Load(generate_static_netplan()), Load($target->slurp), 'Generated netplan config is equivilent to target file';

done_testing()