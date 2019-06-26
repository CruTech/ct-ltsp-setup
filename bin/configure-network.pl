#! /usr/bin/env perl
use strict;
use warnings;

use Try::Tiny;
use Path::Tiny;

# Add project lib to our @INC
use FindBin qw( $Bin );
use lib path($Bin)->parent->child('lib')->stringify;

use ServerSetup qw( :all );

#/etc/systemd/resolved.conf set DNS option as well as in interfaces

print "configure-network.pl\n";