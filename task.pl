#!/usr/bin/perl
# removed "-w" switch to avoid "uninitialized value" warnings from !defined checks
# vim: ts=4 sw=4 et

#
# task - time tracking tool
# See end of file for user documentation.
#

use POSIX qw(isdigit);
use Math::Round qw(nearest);
use Sort::Hash qw(sort_hash);
use Lingua::EN::Titlecase;
use DateTime;

# change at your own risk -- some of the other scripts might not be forgiving
my $tasklogs_dirname   = 'tasklogs';  # main directory for all tasklogs
my $tasklog_filename   = '.hours';    # task log file, stored in $tasklogs_dirname
my $tasklogs_backupdir = 'backups';   # subdirectory of $tasklogs_dirname
my $quit               = 'quit';      # pseudo-taskname used to end the day

# ====================================================================
# TODO: Set these to control output.
# #====================================================================
# By default this will output values rounded to nearest quarter hour:
my $rounding_precision = 0.25;
my $seconds_conversion = 3600; # seconds to hours
my $printf_fmt         = "%5.2f";
#
# If you need output by tenth of an hour, use these values:
# my $rounding_precision = 0.1;
# my $seconds_conversion = 3600; # seconds to hours
# my $printf_fmt         = "%5.1f";
#
# If you need output in minutes, rounded to nearest minute:
# my $rounding_precision = 1;
# my $seconds_conversion = 60; # seconds to minutes
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
\ttaskname values: 'break', 'lunch', 'sick', 'vacation', 'holiday', $quit
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
    $min = int (($diff + 30) / 60);
    if (!defined $task) {
        print "Doing [$prev], $min minutes, started at $startprev\n";
        exit;
    }
    elsif ($task eq $prev) {
        print "Already doing [$prev], $min minutes, started at $startprev\n";
        exit;
    }
    else {
        print "Was doing [$prev], $min minutes\n";
    }
}
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
if (lc("$task") eq lc("$quit")) {
    my $tz = DateTime::TimeZone->new( name => "local" );
    my $dt = DateTime->now( time_zone => $tz->name() );
    my $eod_filename = &get_endofday_filename();
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
        my $tot = $rounded{"$tsk"};
        if ( $found_zero == 0 && $tot == 0 ) {
            $found_zero = 1;
            print "------------------------------\n";
        } elsif ( $found_zero == 1 && $tot != 0 ) {
            $found_zero = 0;
            print "------------------------------\n";
        }
        printf "$printf_fmt  %s\n", $tot, $tsk;
        printf EODFH "$printf_fmt  %s\n", $tot, $tsk;
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
# Get the name of the current day
#
# TODO: pull this out into a tasklogs suite module.
#
sub get_currday_name($;) {
    my $tz = DateTime::TimeZone->new( name => "local" );
    my $dt = DateTime->now( time_zone => $tz->name() );

    return $dt->day_name();
}

######################################################################
# Get the name of the previous day
#
# TODO: pull this out into a tasklogs suite module.
#
sub get_prevday_name() {
    my $tz = DateTime::TimeZone->new( name => "local" );
    my $dt = DateTime->now( time_zone => $tz->name() );

    $dt->subtract( days => 1 );

    return $dt->day_name();
}

######################################################################
# Get the numeric YYMMDD for the current day
#
# TODO: pull this out into a tasklogs suite module.
#
sub get_currday_yymmdd() {
    my $tz = DateTime::TimeZone->new( name => "local" );
    my $dt = DateTime->now( time_zone => $tz->name() );

    return $dt->format_cldr( "yyMMdd" );
}

######################################################################
# Get the numeric YYMMDD for the previous day
#
# TODO: pull this out into a tasklogs suite module.
#
sub get_prevday_yymmdd() {
    my $tz = DateTime::TimeZone->new( name => "local" );
    my $dt = DateTime->now( time_zone => $tz->name() );

    $dt->subtract( days => 1 );

    return $dt->day();
}

######################################################################
# Get the name of the end-of-day log file
#
# TODO: pull this out into a tasklogs suite module.
#
sub get_endofday_filename() {
    my $tz = DateTime::TimeZone->new( name => "local" );
    my $dt = DateTime->now( time_zone => $tz->name() );

    my $taskdir = &get_taskdir();
    my $currday = &get_currday_name();
    my $eod     = "$taskdir.$currday";

    if ( ! -f "$eod" ) {
        my $prevday = &get_prevday_name();
        $eod = "$taskdir.$prevday";
    }

    return $eod;
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
######################################################################
__END__

=head1 NAME

B<task> - time tracking tool

=head1 SYNOPSIS

=over

=item B<task>

=item B<task> I<taskname>

=item B<task> -I<minutes> I<taskname>

=item B<task quit>

=back

=head1 DESCRIPTION

B<task> without arguments says what I<taskname> it thinks
you're working on and for how long.

Use
B<task> I<taskname>
when you start working on task I<taskname>.
Short, repeatable I<taskname>s are recommended.

If you forget to do this when you switch tasks, use
B<task> -I<minutes> I<taskname>
to indicate that you started working on task I<taskname>,
I<minutes> minutes ago.

B<task quit>
rotates its log file and prints a report,
listing total hours worked for each distinct I<taskname>.

=head1 ENVIRONMENT

B<HOME> must be set to the path of the user's home directory.

=head1 FILES

=over

=item C<$HOME/.hours>

=item C<$HOME/.hours.bak>

=back

=cut
