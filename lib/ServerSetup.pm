package ServerSetup;
use strict;
use warnings;
our $VERSION = '0.0.1';

use feature qw( state );

use Type::Params qw( compile );
use Types::Standard qw( slurpy Str ArrayRef HashRef CodeRef Num Any Maybe);
use Carp;

use Log::Any qw( $log );

use Capture::Tiny ':all';
use Path::Tiny;
use Try::Tiny;

use Exporter::Shiny qw(
    execute_cmd
    command_executor
    default_executor_logger
    Ok
    Err
    unwrap
    is_err

    install
    install_chroot

    edit_file
);

#
# Result
#

# Unwrap a result object
sub unwrap {
    state $check = compile( HashRef );
    my ($result) = $check->(@_);

    return $result->{'ok'} if exists $result->{'ok'};
    croak('Unwrap exception: ' .$result->{'err'}) if exists $result->{'err'};
    croak('Unwrap called on a hash missing ok or err keys');
}

sub Ok {
    { ok => shift }
}

sub Err {
    state $check = compile( Str );
    my $msg = $check->(@_);
    { err => $msg }
}

sub is_err {
    state $check = compile( HashRef );
    my ($result) = $check->(@_);

    return 0 if exists $result->{'ok'};
    return 1 if exists $result->{'err'};
    croak('is_err called on a hash missing ok or err keys');
}

#
# Command loop executor
#

# Executes a command, logs output and returns 1 on success and 0 on error
sub execute_cmd {
    state $check = compile(slurpy ArrayRef[Str]);
    my ($cmd) = $check->(@_);

    my ($stdout, $stderr, $exit) = capture {
        system @$cmd
    };

    # Map exit code to Result
    ($exit == 0)
        ? Ok({cmd => [@$cmd], stdout => $stdout, stderr => $stderr, exit_code => $exit})
        : Err('Error executing "' . join(' ', @$cmd) . ' " stdout: "' . $stdout . '"' . ' " stderr: "' . $stderr . '"');
}

sub command_executor {
    state $check = compile(ArrayRef[Any], Maybe[CodeRef]);
    my ($command_list, $result_cb) = $check->(@_);
    my $results = [];

    my $handle_result_closure = sub {
        my $result = shift;
        push @$results, $result;
        $result_cb->($result) if $result_cb;
    };

    for my $cmd (@$command_list) {
        if (ref $cmd eq 'ARRAY') {
            $handle_result_closure->( execute_cmd(@$cmd) )
        }
        elsif (ref $cmd eq '') {
            $handle_result_closure->( execute_cmd($cmd) )
        }
        elsif (ref $cmd eq 'CODE') {
            $handle_result_closure->( $cmd->() )
        }
        else {
            $handle_result_closure->(
                Err('Unable to execute command of ref type: ' . ref($cmd))
            )
        }
    }

    $results
}

# Default logging for progressive reporting of command executor
sub default_executor_logger {
    state $check = compile( HashRef );
    my ($result) = $check->(@_);

    # Log results
    if (is_err($result)) {
        $log->err('[Err] - ' . $result->{'err'})
    }
    else {
        my ($exit, $stdout, $stderr, $cmd) = @{$result->{'ok'}}{qw(exit_code stdout stderr cmd)};
        my $status = ($exit == 0) ? 'OK' : 'Err';

        $log->info(
            sprintf('%3s |%s| stdout> %s', $status, join(' ', @$cmd), $stdout)
        ) if defined $stdout and length $stdout > 0;

        $log->err(
            sprintf('%3s %s stderr> %s', $status, join(' ', @$cmd), $stderr)
        ) if defined $stderr and length $stderr > 0;
    }
}

#
# Command macros
#

# Install package
sub install {
    state $check = compile( slurpy ArrayRef[Str] );
    my ($cmd) = $check->(@_);

    [qw(apt-get --yes install), @$cmd]
}

# install packages on ltsp chroot
sub install_chroot {
    state $check = compile( slurpy ArrayRef[Str] );
    my ($cmd) = $check->(@_);

    [qw(ltsp-chroot -m apt-get --yes install), @$cmd]
}

#
# Run time routines
#

# edit file
sub edit_file {
    state $check = compile( Str, Maybe[Str], slurpy ArrayRef[CodeRef] );
    my ($file_in, $file_out, $filters) = $check->(@_);

    $file_out = $file_in unless defined $file_out;

    sub {
        my $result;
        try {
            my $content = path($file_in)->slurp;
            # Apply filters in sequence
            for my $filter ($filters->@*) {
                $content = $filter->($content)
            }
            path($file_out)->spew( $content );
            $result = Ok($file_out);
        }
        catch {
            $result = Err("Failed edit from $file_in to $file_out: $_")
        };

        $result
    }
}

1;