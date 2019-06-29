#! /usr/bin/env perl
use strict;
use warnings;

use feature qw( unicode_strings );

use Try::Tiny;
use Path::Tiny;

# Add project lib to our @INC
use FindBin qw( $Bin );
use lib path($Bin)->parent->child('lib')->stringify;
my $project_path = path($Bin)->parent;

use ServerSetup qw( :all );

# Logging
use Log::Any qw( $log );
use Log::Any::Adapter ('Stdout');
use Log::Dispatch::Config;
Log::Dispatch::Config->configure("$project_path/log.conf");

my $is_test = @ARGV ? 1 : 0;

$log->info('Started ltsp-setup.pl' . ($is_test ? ' in test mode' : '') . "\n");

my @commands = (
    # LTSP setup follwing http://wiki.ltsp.org/wiki/Installation/Ubuntu
    'add-apt-repository --yes ppa:ts.sch.gr',
    'apt update',
    install(qw(
        --install-recommends
        ltsp-server-standalone
        epoptes
    )),
    'gpasswd -a ${SUDO_USER:-$USER} epoptes',
    q(ltsp-build-client --purge-chroot --mount-package-cache --extra-mirror 'http://ppa.launchpad.net/ts.sch.gr/ppa/ubuntu bionic main' --apt-keys '/etc/apt/trusted.gpg.d/ts_sch_gr_ubuntu_ppa.gpg' --late-packages epoptes-client),

    install_chroot(qw(
        xubuntu-desktop
        xfdesktop4
    )),
    'ltsp-update-image',

    # ltsqp dnsmasq config
    'ltsp-config dnsmasq --no-proxy-dhcp',
    # Edit the generated config
    edit_file('/etc/dnsmasq.d/ltsp-server-dnsmaq.conf', undef,
        sub { shift =~ s/dhcp-range = .+ $/dhcp-range=192.168.67.10,192.168.67.110,8h/grmx },
        \&dnsmasq_assert_gateway,
        \&dnsmasq_assert_nameserver
    ),

    # Set static IP
    write_file('/etc/netplan/50-static.yaml', \&generate_static_netplan),

    # Remove systemd-resolved
    systemctl(stop => 'systemd-resolved'),
    systemctl(disable => 'systemd-resolved'),
    'rm -v /etc/resolv.conf',
    write_file('/etc/resolv.conf', sub { 'nameserver 192.168.67.254' }),

    # ensure dnsmasq is run and will run on startup
    systemctl(enable => 'dnsmasq'),
    systemctl(start => 'dnsmasq'),
);

my $results = command_executor(\@commands, \&default_executor_logger) unless $is_test;
$log->debug(join "\n", map { ref($_) eq 'ARRAY' ? join(' ', $_->@*) : $_ } @commands) if $is_test;

my $fail_count = 0;
my $command_count = 0;
for my $result ($results->@*) {
    $fail_count += 1;
    if (is_err($result)) {
        $log->err($result->{'err'})
    }
}

$log->info("Failed execution of $fail_count of $command_count commands") if $fail_count > 0;
$log->info("Executed $command_count commands without error.") if $fail_count == 0;

$log->info("Finished ltsp-setup.pl\n");