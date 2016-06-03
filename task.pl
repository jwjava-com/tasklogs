#!/usr/bin/perl
######################################################################
# task.pl - time tracking tool
# See end of file for user documentation.
# NOTE: # removed "-w" switch to avoid "uninitialized value" warnings
# from !defined checks.
######################################################################

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin";
}
use tasklogs;

use DateTime;
use Lingua::EN::Titlecase;
use Math::Round qw(nearest);

my $tc    = Lingua::EN::Titlecase->new("");
my $logfn = get_logfn();

my ($now, $task, $prev, $then, $diff);
my %totals;

# Scan log file to build %totals, and identify most recent task.
# File format is one line for each task switch:
# time taskname
if ( -f $logfn ) {
    open INFILE, "<$logfn" or die "Error: $logfn: $!\n";
    while (<INFILE>) {
        chomp;
        ($now, $task) = split( /\s+/, $_, 2 );
        $task = $tc->title("$task");

        if ( defined $prev ) {
            $diff = $now - $then;
            $totals{"$prev"} += $diff;
        }

        $prev = $task;
        $then = $now;
    }
    close INFILE;
}

#
# Get command line arguments
#
if (  !defined( $ARGV[0] ) && !defined( $prev ) ) {
    print STDERR <<"eof";
No task specified.
Run "task.pl -?" for options.

eof
    # task (no args)
    undef $task;
    $now = time;
}
# task -?
elsif ( $ARGV[0] eq '-?' ) {
    print STDERR <<"eof";
Usage:
task.pl [-<minutesago>|+(minutestoadd)] <taskname>
task.pl quit [<day_of_week>]
\ttaskname values: user-defined-string
\tday_of_week values: full name of the day of week (e.g, Friday)
eof
    exit;
}
# task --silent
elsif ( $ARGV[0] eq '--silent' && defined( $prev ) ) {
    &update_currtask( $prev );
    exit;
}
# task -minutes taskname
elsif ( $ARGV[0] =~ /^-[\d.]+$/ ) {
    my $args = join( ' ', @ARGV );
    ($mins, $task) = split( /\s+/, $args, 2 );
    my $ago = abs $mins;
    $now = time - 60 * $ago;
}
# task +minutes taskname
elsif ( $ARGV[0] =~ /^\+[\d.]+$/ ) {
    my $args = join( ' ', @ARGV );
    ($mins, $task) = split( /\s+/, $args, 2 );
    my $add = abs $mins;
    $now = time + 60 * $add;
}
# task taskname, or task quit
else {
    if ( defined $ARGV[0] ) {
        $task = join( ' ', @ARGV );

        # warning to potential mistake (forgetting the -/+)
        if ( $ARGV[0] =~ /^[\d.]+$/ ) {
            print STDERR "Warning: You specified a number as the 1st word of the task name.\n";
            print STDERR "         Did you mean to provide a time offset instead?\n";
        }
        # prevent taskname of '-'
        elsif ( $ARGV[0] eq '-' && ! defined $ARGV[1] ) {
            die "Error: Task name of hypen not allowed\n";
        }
        # if user typed '- mins' instead of '-mins', warn, but fix for them
        elsif ( $ARGV[0] eq '-' && defined $ARGV[1] ) {
            if ( $ARGV[1] =~ /^[\d.]+$/ ) {
                print STDERR "Warning: You put a space between the minus and time offset.\n";
                print STDERR "         Assuming this was a mistake and proceeding accordingly.\n";
                $now = time - 60 * $ARGV[1];
                $task =~ s/^- \d+ //;
            } else {
                die "Error: Invalid arguments: " . join( ' ', @ARGV ) . "\n";
            }
        }
        # prevent taskname of '+'
        elsif ( $ARGV[0] eq '+' && ! defined $ARGV[1] ) {
            die "Error: Task name of plus not allowed\n";
        }
        # if user typed '+ mins' instead of '+mins', warn, but fix for them
        elsif ( $ARGV[0] eq '+' && defined $ARGV[1] ) {
            if ( $ARGV[1] =~ /^[\d.]+$/ ) {
                print STDERR "Warning: You put a space between the plus and time offset.\n";
                print STDERR "         Assuming this was a mistake and proceeding accordingly.\n";
                $now = time + 60 * $ARGV[1];
                $task =~ s/^\+ \d+ //;
            } else {
                die "Error: Invalid arguments: " . join( ' ', @ARGV ) . "\n";
            }
        }
        # task -r oldname newname
        elsif ( $ARGV[0] =~ /^-r$/ && defined $ARGV[1] && defined $ARGV[2] ) {
            die "Error: Too many parameters, task names with spaces must be quoted for rename\n" if ( defined $ARGV[3] );
            shift; # ignore '-r'
            my $oldtask = shift;
            my $newtask = shift;
            # Only need to standardize capitalization of new task for writing into file
            $nettask = $tc->title("$nettask");
            rename_task( $logfn, $oldtask, $newtask );
            exit;
        }
    } else {
        $task = undef;
    }
    $now = time;
}

if ( defined $task ) {
    $task =~ s/^\s+//;
    $task =~ s/\s+$//;
    $task = $tc->title("$task");
    &update_currtask( $task );
} elsif ( defined $prev ) {
    &update_currtask( $prev );
}

#
# Show most recent task from log file.
#
if ( defined $prev ) {
    my @startofprev = localtime( $then );
    $startprev      = fmttimearr( @startofprev );

    $diff = $now - $then;
    $totals{"$prev"} += $diff;
    my $min = nearest( 0.25, $diff / get_minutes_conversion() );

    if ( ! defined $task ) {
        printf "Doing [%s], %.2f minutes, started at %s\n", $prev, $min, $startprev;
        exit;
    }
    elsif ( lc( $task ) eq lc( $prev ) ) {
        printf "Already doing [%s], %.2f minutes, started at %s\n", $prev, $min, $startprev;
        exit;
    }
    else {
        printf "Was doing [%s], %.2f minutes\n", $prev, $min;
    }
}
# If 1st run of the day (e.g., no $prev) and we gave no $task, exit
# Really we shouldn't ever reach this point, but... it's here, so (shrugs)
# aka: I don't remember from back in 1999-2004 when I first wrote this why I needed this check.
elsif ( !defined $task ) {
    exit;
}

#
# task quit: rotate log file and print report.
#
if ( $task =~ /^quit/i ) {
    my $eodref = get_endofday( $task );
    my $eod_filename = $$eodref{fn};
    die "Error: Aborting, end-of-day file [$eod_filename] already exists\n" if ( -f $eod_filename );

    open( EODFH, ">$eod_filename") or die "Error: Could not open $eod_filename for writing";

    # Standardize task quit in case day abbr given
    my $day_name = $$eodref{dt}->day_name();
    $task = "Quit " . $day_name;
    &record_task( $logfn, $task, $now, $tc );

    my %rounded;
    foreach my $tsk (keys %totals) {
        my $r = nearest( get_rounding_precision(), $totals{"$tsk"} / get_seconds_conversion() );
        $r    = abs $r if ( $r == 0 ); # get rid of annoying -0.00 values
        $tsk  = $tc->title("$tsk");
        $rounded{"$tsk"} = $r;
    }

    # TODO: move summary output to a method
    print "\nTask summary for $day_name, " . $$eodref{dt}->mdy('/') . ":";
    print "\n=============================================\n";

    my $found_zero = 0;
    foreach my $tsk (sort { $totals{"$b"} <=> $totals{"$a"} or lc("$a") cmp lc("$b") } keys %totals) {
        my $rounded_total = $rounded{"$tsk"};
        my $raw_total = $totals{"$tsk"};
        if ( $found_zero == 0 && $rounded_total == 0 ) {
            $found_zero = 1;
            print "---------------------------------------------\n";
        } elsif ( $found_zero == 1 && $rounded_total != 0 ) {
            $found_zero = 0;
            print "---------------------------------------------\n";
        }
        my $printf_fmt = get_printf_fmt();
        printf "$printf_fmt  %s\n", $rounded_total, $tsk;
        printf EODFH "%-5d  %s\n", $raw_total, $tsk;
    }

    backup_logfn( $logfn );

    # pass control to daily.pl to process end-of-day functions
    my $daily_script = get_daily_script();
    exec "perl $daily_script $task";
}
else {
    &record_task( $logfn, $task, $now, $tc );

    print "Now doing [$task]\n";
}

######################################################################
# Append new task switch record to logfile.
#
sub record_task($$$$;) {
    my ($logfn, $task, $now, $tc) = @_;
    open OUTFILE, ">>$logfn" or die "Error: cannot open daily log file for writing: $logfn: $!\n";
    $task = $tc->title("$task");
    print OUTFILE "$now $task\n";
    close OUTFILE;
}

######################################################################
# Update the currtask file, if one is defined by environment variable
#
sub update_currtask($) {
    my $task = shift;

    if ( defined &get_currtask_fn() ) {
        my $currtask_fn = &get_currtask_fn();

        if ( $task =~ /^quit/i ) {
            unlink "$currtask_fn"
                or &write_currtask_file( "Quit" )
                and die "Error: cannot remove current task file $currtask_fn: $!\n";
        } else {
            &write_currtask_file( $task );
        }
    }
}

######################################################################
# Return the value of the TASKLOGS_CURRTASK_FILE env var
#
sub get_currtask_fn() {
    return $ENV{TASKLOGS_CURRTASK_FILE};
}

######################################################################
# Write out the current task to the defined current task file
#
sub write_currtask_file($) {
    my $task = shift;
    my $currtask_fn = &get_currtask_fn();
    open CURRTASK, ">$currtask_fn"
        or die "Error: cannot open current task file $currtask_fn for writing: $!\n";
    print CURRTASK "$task"; # NOTE: do not add a newline
    close CURRTASK;
}

######################################################################
exit; # End of main script ###########################################
######################################################################

__END__

=pod

=head1 NAME

C<task.pl> - time tracking tool

=head1 DESCRIPTION

This program allows tracking start times of various tasks for timesheets.

=head1 SYNOPSIS

=over

=item task.pl
    display current task

=item task.pl C<taskname>
    start new task named I<taskname>

=item task.pl C<-minutes> C<taskname>
    start new task I<minutes> ago named I<taskname>

=item task.pl C<+minutes> C<taskname>
    start new task I<minutes> from now named I<taskname>

=item task.pl C<quit> C<day-of-week>
    do end-of-day processing for I<day-of-week>

=back

=head1 FILES

=over

=item .hours
    task log for the current day

=item .hours.bak
    task log for the previous day

=item .C<day-of-week>
    end of day report for the indicated I<day-of-week> (e.g., C<.Monday>, or C<mon>)

=back

=head1 REQUIRED SCRIPTS

=over

=item daily.pl
    execution is passed to C<daily.pl> during end-of-day processing

=back

=head1 REQUIRED MODULES

=over

=item C<tasklogs>

=item L<DateTime>

=item L<Lingua::EN::Titlecase>

=item L<Math::Round>

=back

=head1 OPTIONAL ENVIRONMENT VARIABLES

=over

=item TASKLOGS_CURRTASK_FILE
    If set, `task.pl` will save the current task to this file.
    This is useful for using the current task name in other scripts.
    This file will be attempted to be removed during C<task.pl quit> processing.

=back

=head1 AUTHORS

=over

=item Jon Warren C<jon@jonwarren.info>

=back

=head1 GIT REPOSITORY

=over

=item L<https://github.com/jonwarren/tasklogs>

=back

=cut

# vim: ts=4 sw=4 et
