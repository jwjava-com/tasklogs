#!C:\Perl\bin\perl.exe
# removed "-w" switch to avoid "uninitialized value" warnings from !defined checks

#
# task - time tracking tool
# See end of file for user documentation.
#

use POSIX qw(isdigit);

#
# Startup initialization
#
if (!defined $ENV{HOMEDRIVE} && !defined $ENV{HOMEPATH}) {
    die "HOMEDRIVE and HOMEPATH environment variables not set\n";
}
my $taskdir = $ENV{HOMEDRIVE} . $ENV{HOMEPATH} . "tasklogs\\";
my $logfn = $taskdir . '.hours';
my $quit = 'quit';

#
# Scan log file to build %total, and identify most recent task.
# File format is one line for each task switch:
# time taskname
#
if (-f $logfn) {
    open INFILE, "<$logfn"
        or die "$logfn: $!\n";
    while (<INFILE>) {
        ($now, $task) = split;
        if (defined $prev) {
            $diff = $now - $then;
            $total{$prev} += $diff;
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
elsif ($ARGV[0] =~ /^-\d+$/) {
    # task -minutes taskname
    my $ago = abs $ARGV[0];
    $now = time - 60 * $ago;
    $task = $ARGV[1];
}
elsif ($ARGV[0] =~ /^\+\d+$/) {
    # task +minutes taskname
    my $add = abs $ARGV[0];
    $now = time + 60 * $add;
    $task = $ARGV[1];
}
else {
    # task taskname, or task quit
    $task = $ARGV[0];
    $now = time;
}

#
# Show most recent task from log file.
#
if (defined $prev) {
    my @startofprev = localtime( $then );
    $startprev      = &fmttimearr( \@startofprev );

    $diff = $now - $then;
    $total{$prev} += $diff;
    $min = int (($diff + 30) / 60);
    if (!defined $task) {
        print STDERR "Doing $prev, $min minutes, started at $startprev\n";
        exit;
    }
    elsif ($task eq $prev) {
        print STDERR "Already doing $prev, $min minutes, started at $startprev\n";
        exit;
    }
    else {
        print STDERR "Was doing $prev, $min minutes\n";
    }
}
elsif (!defined $task) {
    exit;
}

#
# Append new task switch record to logfile.
#
open OUTFILE, ">>$logfn"
    or die "$logfn: $!\n";
print OUTFILE "$now $task\n";
close OUTFILE;

#
# task quit: rotate log file and print report.
#
if ($task eq $quit) {
    print STDERR "Task summary:\n";
    while (($task, $tot) = each %total) {
        # %f rounds to nearest
        printf "%3.1f  %s\n", $tot / 3600, $task;
    }
    rename $logfn, "$logfn.bak"
        or die "$logfn.bak: $!\n";
}
else {
    print STDERR "Now doing $task\n";
}

# Format Time Array Values as 2-digit values
#
# TODO: pull this out into a tasklogs suite module.
#
# NOTE: Copied here from daily.pl for speed of development.
#       I know it's bad, but I don't have the time to create a pm now.
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
    $timestr      = join( '/', $$timearr[4], $$timearr[3], $$timearr[5] );
    $timestr     .= ' ';
    $timestr     .= join( ':', $$timearr[2], $$timearr[1], $$timearr[0] );
    $timestr     .= " $ampm";

    return $timestr;
}

__END__

=head1 NAME

B<task> - time tracking tool

=head1 SYNOPSIS

=item B<task>

=item B<task> I<taskname>

=item B<task> -I<minutes> I<taskname>

=item B<task quit>

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

=item C<$HOME/.hours>

=item C<$HOME/.hours.bak>

=cut
