#! /usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Path::Tiny;

use ServerSetup qw(
    edit_file
    dnsmasq_assert_gateway
    dnsmasq_assert_nameserver
);

# Test environment
my $res = path('t/res');
ok $res->is_dir, "$res directory exists";

my $example = $res->child('example-dnsmasq.conf');
ok $example->is_file, "$example exists";

my $target = $res->child('target-dnsmasq.conf');
ok $target->is_file, "$target exists";

# Test rewrite functions

# Add lines where missing
my $missing_in = "Not the line we're looking for.";
is dnsmasq_assert_gateway($missing_in), "$missing_in\ndhcp-option=3,192.168.67.254", 'Add gateway line if it is missing';
is dnsmasq_assert_nameserver($missing_in), "$missing_in\ndhcp-option=6,192.168.67.254", 'Add nameserver line if it is missing';

# Assert new value
my $different_gateway = "$missing_in\ndhcp-option=3,192.168.0.1";
is dnsmasq_assert_gateway($different_gateway), "$missing_in\ndhcp-option=3,192.168.67.254", 'Replace gateway line';

my $different_nameserver = "$missing_in\ndhcp-option=6,192.168.0.1,8.8.8.8";
is dnsmasq_assert_nameserver($different_nameserver), "$missing_in\ndhcp-option=6,192.168.67.254", 'Replace nameserver line';

# test complete rewrite
is dnsmasq_assert_nameserver( dnsmasq_assert_gateway($example->slurp) ), $target->slurp, 'Rewrite from example to target';

done_testing()