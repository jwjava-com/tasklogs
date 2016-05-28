#!/usr/bin/perl -w
# vim: ts=4 sw=4 et

use Time::Local;
use English;
use Lingua::EN::Titlecase;

my $taskdir = "";
if (defined $ENV{HOME}) {
    $taskdir = $ENV{HOME} . "/tasklogs/";
} elsif (defined $ENV{HOMEDRIVE} && defined $ENV{HOMEPATH}) {
    $taskdir = $ENV{HOMEDRIVE} . $ENV{HOMEPATH} . "tasklogs\\";
} else {
    die "HOME or (HOMEDRIVE and HOMEPATH) environment variables not set\n";
}
die "$taskdir does not exist" unless ( -d $taskdir );
die "$taskdir is not accessable" unless ( -x $taskdir );
die "$taskdir is not readable" unless ( -r $taskdir );
die "$taskdir is not writable" unless ( -w $taskdir );

my $logfn = $taskdir . '.hours';
my @break_aliases = &get_break_aliases( $taskdir . '.break_aliases' );

my $option    = shift @ARGV;
my $temp_task = "";
my ($temp_time1, $temp_time2) = (0.0, 0.0);
my @tasks;
my $ctr       = 0;
my $numtasks  = 0;
my $day       = 8 * 60 * 60;
my $currtime  = timelocal( localtime(time) );
my ($totaltime, $breaktime, $worktime) = (0.0, 0.0, 0.0);
my ($total, $breaks, $worked)          = (0.0, 0.0, 0.0);
my ($mon, $mday, $year, $wday);
my $startday;
my $endday;
my @startofday;
my @endofday;
my $linenumber = 0;  # Current line number of input file
my $tc = Lingua::EN::Titlecase->new("");

# Get the current date
(undef,undef,undef,$mday,$mon,$year,$wday,undef,undef) = localtime(time);
# Adjust $mon to be in the 1-12 range
$mon++;
# Adjust $mday to be Saturday
$mday    += (6 - $wday);
# Adjust $year for years >= 2000
$year -= 100 if ( $year >= 100 );
# Adjust $mon, $mday, and $year to be 2-digit numeric strings
$mon     =  sprintf( "%2.2d", $mon );
$mday    =  sprintf( "%2.2d", $mday );
$year    =  sprintf( "%2.2d", $year );

# Check the command-line options and perform the appropriate action:
# If the option was 'end', perform the end-of-day activities, doing 'weekly'
# actions on certain days of the week.
# Otherwise, just print the 'daily' report to the screen.
if ( defined( $option ) && $option eq 'end' ) {
    my $currday = &get_currday();
    my $filename = "$taskdir.$currday";

    if ( -e $filename ) {
        # NOTE: This assumes we reached this point from a call to `task.pl quit`
        #       which outputs the end-of-day log for us.
        # Prompt the user for whether the log file looks good, if not
        # open the logfile into a text editor (e.g., vim).
        print "\n\nEdit [y|n]? ";
        my $doEdit;
        chomp( $doEdit = <STDIN> );
        if ( $doEdit eq 'Y' || $doEdit eq 'y' ) {
            system "vim $filename";
        }
    }

    # If it's the end of the week, run the weekly report then clear out the
    # end-of-day logs for the week.
    # TODO: fix this if you've worked past midnight on Friday
    if ( $wday == 5 ) {
        # Prompt the user for whether the weekly report should be ran.
        print "\n\nProcess Weekly Report [y|n]? ";
        my $doWeek;
        chomp( $doWeek = <STDIN> );
        if ( $doWeek eq 'Y' || $doWeek eq 'y' ) {
            my $weekly = $taskdir . 'weekly.pl';
            print `perl $weekly $mon$mday$year`;
            # Prompt the user for whether the daily logs should be cleared.
            print "\n\nClear Daily Logs [y|n]? ";
            my $doClear;
            chomp( $doClear = <STDIN> );
            if ( $doClear eq 'Y' || $doClear eq 'y' ) {
                print `perl $weekly clear`;
            }
        }
    }
}
else {
    if ( open( INPUT, $logfn ) ) {
        while ( <INPUT> ) {
            chomp;
            ( $temp_time, $temp_task ) = split( /\s+/, $_, 2 );
            $tasks[$ctr++] = [ $temp_time, $tc->title("$temp_task") ];
            $startday      = $temp_time if ( $linenumber == 0 );
            $linenumber++;
        }
        close( INPUT );
        $endday        = $startday;    # Store $startday in $endday for later use
        @startofday    = localtime( $startday );
        $startday      = &fmttimearr( \@startofday );
        $ctr           = 0;
        $numtasks      = scalar( @tasks );
        if ( $numtasks > 1 ) {
            while ( $ctr < $numtasks ) {
                $temp_task = $tasks[$ctr][1] unless( !defined( $tasks[$ctr][1] ) );
                $temp_time1 = $tasks[$ctr][0] unless( !defined( $tasks[$ctr][0] ) );

                if ( grep /^$temp_task/i, @break_aliases ) {
                    $temp_time2 = $tasks[$ctr+1][0] unless( !defined($tasks[$ctr+1][0]) );
                    $breaktime += $temp_time2 - $temp_time1;
                }
                else {
                    if ( defined( $tasks[$ctr+1][0] ) ) {
                        $temp_time2 = $tasks[$ctr+1][0]
                    }
                    $worktime += $temp_time2 - $temp_time1;
                }
                $ctr++;
            }
        }

        # TODO: bump all these out to a config file or array
        if ( $tasks[$numtasks-1][0] < $currtime ) {
            my $tsk = $tasks[$numtasks-1][1];
            if ( grep /^$tsk/i, @break_aliases ) {
                $breaktime += $currtime - $tasks[$numtasks-1][0];
            }
            else {
                $worktime += $currtime - $tasks[$numtasks-1][0];
            }
        }

        @endofday  = localtime( $endday + $day + $breaktime );
        $endday    = &fmttimearr( \@endofday );
        $totaltime = $worktime + $breaktime;
        &printreport( $worktime, $breaktime, $totaltime, $startday, $endday );
    } else {
        print STDERR "couldn't open file: $logfn\n";
    }
}

######################################################################
exit; # End of main script ###########################################
######################################################################

######################################################################
# Get the name of the current day
#
# TODO: pull this out into a tasklogs suite module.
#
sub get_currday() {
    my $wday;
    my @days = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
    (undef,undef,undef,undef,undef,undef,$wday,undef,undef) = localtime(time);
    return $days[$wday];
}

######################################################################
# Returns an array of 'break' aliases.
# Attempts to read a config file, if file exists uses contents,
# otherwise uses a set of standard aliases.
#
# TODO: pull this out into a tasklogs suite module.
#
sub get_break_aliases($;) {
    my $fn = shift;
    my @aliases;
    if ( -f "$fn" ) {
        if ( open( INPUT, $fn ) ) {
            while ( <INPUT> ) {
                chomp;
                push( @aliases, $_ );
            }
            close( INPUT );
        }
    } else {
        # No break_aliases file defined, using standard values
        push( @aliases, 'Break', 'Lunch', 'Sick', 'Vacation', 'Holiday' );
    }
    return @aliases;
}

######################################################################
# Format Time Array Values as 2-digit values
#
# TODO: pull this out into a tasklogs suite module.
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
    $timestr      = join( '/', $$timearr[4], $$timearr[3], $$timearr[5] );
    $timestr     .= ' ';
    $timestr     .= join( ':', $$timearr[2], $$timearr[1], $$timearr[0] );
    $timestr     .= " $ampm";

    return $timestr;
}

######################################################################
# Redo $time as either hours, minutes, or seconds
#
sub redotime( $ ) {
    my $time = shift;
    my $desc = "";

    if ( $time > 60 * 60 ) {
        $time = $time / 60 / 60;
        $desc = 'hours';
    }
    elsif ( $time > 60 ) {
        $time = $time / 60;
        $desc = 'minutes';
    }
    else {
        $desc = 'seconds';
    }
    return ($time, $desc);
}

######################################################################
# Print the time report
#
sub printreport( $$$$$ ) {
    my $worktime  = shift || 0;
    my $breaktime = shift || 0;
    my $totaltime = shift || 0;
    my $startday  = shift || 0;
    my $endday    = shift || 0;
    my $timediff;

    printf( "\n%s\n", "---------------------------------------" );
    printf( "  Current Task:  %s\n", $temp_task );
    printf( "           for:  %4.1f %s\n", &redotime( $currtime - $temp_time ) );
    printf( "  Arrive Work:   %s\n", $startday );
    printf( "  Leave Work:    %s\n", $endday );
    printf( "  %s\n", "-----------------------------------" );
    printf( "  Worked:        %4.1f %s\n", &redotime( $worktime ) );
    printf( "  Breaks:      + %4.1f %s\n", &redotime( $breaktime ) );
    printf( "  Total:       = %4.1f %s\n", &redotime( $totaltime ) );
    printf( "  %s\n", "-----------------------------------" );
    if ( $worktime < $day ) {
        $timediff = $day - $worktime;
        printf( "  Need to work:  %4.1f %s\n", &redotime( $timediff ) );
    }
    else {
        $timediff = $worktime - $day;
        printf( "  Worked over:   %4.1f %s\n", &redotime( $timediff ) );
    }
    printf( "%s\n\n", "---------------------------------------" );
}

