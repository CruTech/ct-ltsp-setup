#! /usr/bin/env perl
use strict;
use warnings;

use Try::Tiny;
use Path::Tiny;

# Add project lib to our @INC
use FindBin qw( $Bin );
use lib path($Bin)->parent->child('lib')->stringify;

use ServerSetup qw( :all );

# Logging
use Log::Any qw( $log );
use Log::Any::Adapter;
use Log::Dispatch::Config;
# use Log::Any::For::Std;
Log::Dispatch::Config->configure('./log.conf');

$log->info("Started ltsp-setup.pl\n");

my @commands = (
    # LTSP setup follwing http://wiki.ltsp.org/wiki/Installation/Ubuntu
    'add-apt-repository --yes ppa:ts.sch.gr',
    'apt update',
    install(qw(
        --install-recommends
        ltsp-server-standalone
        ltsp-client epoptes
    )),
    'gpasswd -a ${SUDO_USER:-$USER} epoptes',
    q(ltsp-build-client --purge-chroot --mount-package-cache --extra-mirror 'http://ppa.launchpad.net/ts.sch.gr/ppa/ubuntu bionic main' \
    --apt-keys '/etc/apt/trusted.gpg.d/ts_sch_gr_ubuntu_ppa.gpg' --late-packages epoptes-client),

    install_chroot('ubuntu-mate-desktop'),
    'ltsp-update-image',

    'ltsp-config dnsmasq --no-proxy-dhcp',
);

my $results = command_executor(\@commands, &default_executor_logger);

my $fail_count = 0;
my $command_count = 0;
for my $result (@$results) {
    $$fail_count += 1;
    if (is_err($result)) {
        $log->err($result->{'err'})
    }
}

$log->info("Failed execution of $fail_count of $command_count commands") if $fail_count > 0;
$log->info("Executed $command_count commands without error.") if $fail_count == 0;

$log->info("Finished ltsp-setup.pl\n");