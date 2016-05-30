#!/usr/bin/perl
######################################################################
# task.pl - time tracking tool
# See end of file for user documentation.
######################################################################
# removed "-w" switch to avoid "uninitialized value" warnings from !defined checks

use Math::Round qw(nearest);
use Lingua::EN::Titlecase;
use DateTime;
use DateTime::TimeZone;
use DateTime::Format::Natural;

# change at your own risk -- some of the other scripts might not be forgiving
my $tasklogs_dirname   = 'tasklogs';  # main directory for all tasklogs
my $tasklog_filename   = '.hours';    # task log file, stored in $tasklogs_dirname
my $tasklogs_backupdir = 'backups';   # subdirectory of $tasklogs_dirname
my $quit               = 'quit';      # pseudo-taskname used to end the day

my ($TENTHS, $QUARTERS, $HALVES, $WHOLE) = (0.1, 0.25, 0.5, 1);
my ($TO_MINS, $TO_HRS) = (60, 3600);
# ====================================================================
# TODO: Set these to control output.
# #====================================================================
# By default this will output values rounded to nearest quarter hour:
my $rounding_precision = $QUARTERS;
my $seconds_conversion = $TO_HRS;
my $printf_fmt         = "%5.2f";
#
# If you need output by tenth of an hour, use these values:
# my $rounding_precision = $TENTHS;
# my $seconds_conversion = $TO_HRS;
# my $printf_fmt         = "%5.1f";
#
# If you need output in minutes, rounded to nearest minute:
# my $rounding_precision = $WHOLE;
# my $seconds_conversion = $TO_MINS;
# my $printf_fmt         = "%5.0f";
# #====================================================================

#
# Scan log file to build %totals, and identify most recent task.
# File format is one line for each task switch:
# time taskname
#
my %totals;
my ($now, $task, $prev, $then, $diff);
my $tc = Lingua::EN::Titlecase->new("");

my $logfn = &get_logfn();
if (-f $logfn) {
    open INFILE, "<$logfn" or die "$logfn: $!\n";
    while (<INFILE>) {
        chomp;
        ($now, $task) = split( /\s+/, $_, 2 );
        $task = $tc->title("$task");

        if (defined $prev) {
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
if (!defined($ARGV[0]) && !defined($prev)) {
    print STDERR <<"eof";
No task specified.
Run "task.pl -?" for options.

eof
    # task (no args)
    undef $task;
    $now = time;
}
elsif ($ARGV[0] eq '-?') {
    # task -?
    print STDERR <<"eof";
Usage:
task.pl [-<minutesago>|+(minutestoadd)] <taskname>
task.pl quit [<day_of_week>]
\ttaskname values: user-defined-string
\tday_of_week values: full name of the day of week (e.g, Friday)
eof
    exit;
}
# task -minutes taskname
elsif ($ARGV[0] =~ /^-[\d.]+$/) {
    my $args = join( ' ', @ARGV );
    ($mins, $task) = split( /\s+/, $args, 2 );
    my $ago = abs $mins;
    $now = time - 60 * $ago;
}
# task +minutes taskname
elsif ($ARGV[0] =~ /^\+[\d.]+$/) {
    my $args = join( ' ', @ARGV );
    ($mins, $task) = split( /\s+/, $args, 2 );
    my $add = abs $mins;
    $now = time + 60 * $add;
}
# task taskname, or task quit
else {
    if (defined $ARGV[0]) {
        # warning to potential mistake (forgetting the -/+)
        if ($ARGV[0] =~ /^[\d.]+$/) {
            print STDERR "Warning: You specified a number as the 1st word of the task name.\n";
            print STDERR "         Did you mean to provide a time offset instead?\n";
        }
        # task -r oldname newname
        elsif ($ARGV[0] =~ /^-r$/ && defined $ARGV[1] && defined $ARGV[2]) {
            die "Error: Too many parameters, task names with spaces must be quoted\n" if (defined $ARGV[3]);
            shift; # ignore '-r'
            my $oldtask = shift;
            my $newtask = shift;
            &rename_task( $logfn, $oldtask, $newtask );
            exit;
        }
        $task = join( ' ', @ARGV );
    } else {
        $task = undef;
    }
    $now = time;
}

#
# Show most recent task from log file.
#
if (defined $prev) {
    my @startofprev = localtime( $then );
    $startprev      = &fmttimearr( \@startofprev );

    $diff = $now - $then;
    $totals{"$prev"} += $diff;
    my $min = nearest( $QUARTERS, $diff / $TO_MINS );
    if (!defined $task) {
        printf "Doing [%s], %.2f minutes, started at %s\n", $prev, $min, $startprev;
        exit;
    }
    elsif (lc($task) eq lc($prev)) {
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
elsif (!defined $task) {
    exit;
}

#
# Append new task switch record to logfile.
#
open OUTFILE, ">>$logfn" or die "$logfn: $!\n";
$task = $tc->title("$task");
print OUTFILE "$now $task\n";
close OUTFILE;

#
# task quit: rotate log file and print report.
#
# TODO: move this to a sub-routine
#
if ( $task =~ /^$quit/i ) {
    my $eod_filename = &get_endofday_filename( $task );
    open( EODFH, ">$eod_filename") or die "Could not open $eod_filename for writing";

    my %rounded;
    foreach my $tsk (keys %totals) {
        my $r = nearest( $rounding_precision, $totals{"$tsk"} / $seconds_conversion );
        $r    = abs $r if ( $r == 0 ); # get rid of annoying -0.00 values
        $tsk  = $tc->title("$tsk");
        $rounded{"$tsk"} = $r;
    }

    print "\nTask summary:";
    print "\n==============================\n";

    my $found_zero = 0;
    foreach my $tsk (sort { $rounded{"$b"} <=> $rounded{"$a"} or lc("$a") cmp lc("$b") } keys %rounded) {
        my $rounded_total = $rounded{"$tsk"};
        my $raw_total     = $totals{"$tsk"};
        if ( $found_zero == 0 && $rounded_total == 0 ) {
            $found_zero = 1;
            print "------------------------------\n";
        } elsif ( $found_zero == 1 && $rounded_total != 0 ) {
            $found_zero = 0;
            print "------------------------------\n";
        }
        printf "$printf_fmt  %s\n", $rounded_total, $tsk;
        printf EODFH "$printf_fmt  %s\n", $rounded_total, $tsk;
        #printf EODFH "$printf_fmt  %s\n", $raw_total, $tsk;
    }

    &backup_logfn( $logfn );

    # pass control to daily.pl to process end-of-day functions
    my $daily_script = &get_daily_script();
    exec "perl $daily_script end";
}
else {
    print "Now doing [$task]\n";
}

######################################################################
exit; # End of main script ###########################################
######################################################################

######################################################################
# Get the daily.pl script location
#
# TODO: pull this out into a tasklogs suite module.
#
sub get_daily_script() {
    return &get_taskdir() . 'daily.pl';
}

######################################################################
# Get the name of the end-of-day log file
#
# TODO: pull this out into a tasklogs suite module.
#
sub get_endofday_filename($) {
    my $task = shift;
    my $day = undef;
    ($task, $day) = split( /\s+/, $task, 2 );
    if ( defined $day ) {
        my $tz = DateTime::TimeZone->new( name => "local" );
        my $parser = DateTime::Format::Natural->new( time_zone => $tz->name() );
        my $dt = $parser->parse_datetime($day);
        if ( $parser->success() ) {
            $day = $dt->day_name();
        } else {
            die "Could not parse provided day [$day]: " . $parser->error() . "\n";
        }
    } else {
        die "No day provided\n";
    }

    my $taskdir = &get_taskdir();
    return "$taskdir.$day";
}

######################################################################
# Backup the hours log file
#
# TODO: pull this out into a tasklogs suite module.
#
sub backup_logfn($;) {
    my $logfn = shift;
    rename $logfn, "$logfn.bak" or die "$logfn.bak: $!\n";
}

######################################################################
# Renames all tasks in $logfn named $oldtask to $newtask.
#
# TODO: pull this out into a tasklogs suite module.
#
sub rename_task($$$;) {
    my $logfn   = shift;
    my $oldtask = shift;
    my $newtask = shift;
    my $count   = 0;

    if ( -f "$logfn" ) {
        open( INFILE, "<$logfn" ) or die "Could not open $logfn for input: $!\n";
        open( OUTFILE, ">$logfn.tmp" ) or die "Could not open $logfn.tmp for output: $!\n";
        while (<INFILE>) {
            if ( $_ =~ s/$oldtask/$newtask/i ) {
                $count++;
            }
            print OUTFILE $_;
        }
        close INFILE;
        close OUTFILE;
        rename "$logfn.tmp", "$logfn" or die "Could not rename $logfn.tmp to $logfn: $!\n";
    } else {
        print STDERR "Warning: task log file $logfn not found\n";
    }

    if ( $count > 0 ) {
        print "Done: [$count] instance"
              . ($count>1?'s':'')
              . " of [$oldtask] "
              . ($count>1?'have':'has')
              . " been renamed to [$newtask].\n";
    } else {
        print "Done: No instances of [$oldtask] were found.\n";
    }
}

######################################################################
# Get the name of the tasklogs directory
#
# TODO: pull this out into a tasklogs suite module.
#
sub get_taskdir() {
    my $taskdir = "";
    # TODO: change this to something more robust for determining path separators
    if (defined $ENV{HOME}) {
        $taskdir = $ENV{HOME} . "/$tasklogs_dirname/";
    } elsif (defined $ENV{HOMEDRIVE} && defined $ENV{HOMEPATH}) {
        $taskdir = $ENV{HOMEDRIVE} . $ENV{HOMEPATH} . "$tasklogs_dirname\\";
    } else {
        die "HOME or (HOMEDRIVE and HOMEPATH) environment variables not set\n";
    }

    if ( ! -d "$taskdir" ) {
        mkdir "$taskdir" or die "$taskdir could not be created: $!";
    }
    die "$taskdir is not accessable" unless ( -x $taskdir );
    die "$taskdir is not readable"   unless ( -r $taskdir );
    die "$taskdir is not writable"   unless ( -w $taskdir );

    return $taskdir;
}

######################################################################
# Get the name of the task log file
#
# TODO: pull this out into a tasklogs suite module.
#
sub get_logfn() {
    my $taskdir = &get_taskdir();
    my $logfn = $taskdir . $tasklog_filename;
}

######################################################################
# Format Time Array Values as 2-digit values
#
# TODO: pull this out into a tasklogs suite module.
#
# NOTE: Copied here from daily.pl for speed of development.
#       I know it's bad, but I don't have the time to create a pm now.
#
sub fmttimearr( \@ ) {
    my $timearr = shift;
    my $timestr;
    my $ampm    = 'AM';

    # Adjust second and minute to be 2-digit numeric strings
    $$timearr[0]  = sprintf( "%2.2d", $$timearr[0] );
    $$timearr[1]  = sprintf( "%2.2d", $$timearr[1] );

    # Determine AM or PM and adjust hour to be w-digit numeric string
    if ( $$timearr[2] > 12 ) {
        $$timearr[2]  = sprintf( "%2.2d", $$timearr[2] - 12 );
        $ampm         = 'PM';
    }
    elsif ( $$timearr[2] == 0 ) {
        $$timearr[2]  = sprintf( "%2.2d", $$timearr[2] + 12 );
        $ampm         = 'AM';
    }
    else {
        $$timearr[2]  = sprintf( "%2.2d", $$timearr[2] );
        $ampm         = 'AM';
    }

    # Adjust month to be in the 1-12 range
    $$timearr[4]++;

    # Adjust year for years >= 2000
    $$timearr[5] -= 100 if ( $$timearr[5] >= 100 );

    # Adjust month, monthday, and year to be 2-digit numeric strings
    $$timearr[3] = sprintf( "%2.2d", $$timearr[3] );
    $$timearr[4] = sprintf( "%2.2d", $$timearr[4] );
    $$timearr[5] = sprintf( "%2.2d", $$timearr[5] );

    # Construct the formated time string
    $timestr  = join( '/', $$timearr[4], $$timearr[3], $$timearr[5] );
    $timestr .= ' ';
    $timestr .= join( ':', $$timearr[2], $$timearr[1], $$timearr[0] );
    $timestr .= " $ampm";

    return $timestr;
}

######################################################################
# End of sub-routines ################################################
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

=head1 ENVIRONMENT VARIABLES 

Environment variables are used for determining which OS path separator to use.

=over

=item HOME
    if I<HOME> is found, assume unix-like environment

=item HOMEDRIVE, HOMEPATH
    if I<HOMEDRIVE> and I<HOMEPATH> are both found, assume Windows

=back

=head1 FILES

=over

=item .hours
    task log for the current day

=item .hours.bak
    task log for the previous day

=item .C<day-of-week>
    end of day report for the indicated I<day-of-week> (e.g., C<.Monday>)

=back

=head1 REQUIRED SCRIPTS

=over

=item daily.pl
    execution is passed to C<daily.pl> during end-of-day processing

=back

=head1 REQUIRED MODULES

=over

=item L<Math::Round>

=item L<Lingua::EN::Titlecase>

=item L<DateTime>

=item L<DateTime::TimeZone>

=item L<DateTime::Format::Natural>

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
