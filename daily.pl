#!/usr/bin/perl -w
######################################################################
# daily.pl - time tracking tool
# See end of file for user documentation.
######################################################################

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin";
}
use tasklogs;

use Lingua::EN::Titlecase;

my $logfn = get_logfn();
my @break_aliases = get_break_aliases();

my $option;
if ( defined $ARGV[0] ) {
    $option = join( ' ', @ARGV );
    $option =~ s/^\s+//;
    $option =~ s/\s+$//;
}

my ($temp_task, $temp_time1, $temp_time2) = ("", 0.0, 0.0);
my @tasks;
my $ctr      = 0;
my $numtasks = 0;
my $day      = 8 * 60 * 60;
my $currtime = time;
my ($totaltime, $breaktime, $worktime) = (0.0, 0.0, 0.0);
my ($total, $breaks, $worked)          = (0.0, 0.0, 0.0);
my ($mon, $mday, $year, $wday);
my ($startday, $endday, @startofday, @endofday);
my $linenumber = 0;  # Current line number of input file

my $tc = Lingua::EN::Titlecase->new("");

# Get the current date
(undef,undef,undef,$mday,$mon,$year,$wday,undef,undef) = localtime($currtime);
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
# If the option was 'quit', perform the end-of-day activities, doing 'weekly'
# actions on certain days of the week.
# Otherwise, just print the 'daily' report to the screen.

if ( defined( $option ) ) {
    if ( $option =~ /^quit/i ) {
        my $eod_filename = get_endofday_filename( $option );

        if ( -e $eod_filename ) {
            # NOTE: This assumes we reached this point from a call to `task.pl quit`
            #       which outputs the end-of-day log for us.
            # Prompt the user for whether the log file looks good, if not
            # open the logfile into a text editor (e.g., vim).
            print "\n\nEdit [y|n]? ";
            my $doEdit;
            chomp( $doEdit = <STDIN> );
            if ( $doEdit eq 'Y' || $doEdit eq 'y' ) {
                system "vim $eod_filename";
            }
        }

        # If it's the end of the week, run the weekly report then clear out the
        # end-of-day logs for the week.
        # TODO: fix this if you've worked past midnight on Friday
        if ( $wday == 5 || $wday == 6 || $wday == 0 ) {
            # Prompt the user for whether the weekly report should be ran.
            print "\n\nProcess Weekly Report [y|n]? ";
            my $doWeek;
            chomp( $doWeek = <STDIN> );
            if ( $doWeek eq 'Y' || $doWeek eq 'y' ) {
                my $weekly = get_weekly_script();
                print `perl $weekly $year$mon$mday`;
                # Prompt the user for whether the daily logs should be cleared.
                print "\n\nClear Daily Logs [y|n]? ";
                my $doClear;
                chomp( $doClear = <STDIN> );
                if ( $doClear eq 'Y' || $doClear eq 'y' ) {
                    print `perl $weekly clear`;
                }
            }
        }
    } else {
        die "Error: Invalid option: $option\n";
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
        $startday      = fmttimearr( @startofday );
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
        $endday    = fmttimearr( @endofday );
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
    printf( "           for:  %4.1f %s\n", redotime( $currtime - $temp_time ) );
    printf( "  Arrive Work:   %s\n", $startday );
    printf( "  Leave Work:    %s\n", $endday );
    printf( "  %s\n", "-----------------------------------" );
    printf( "  Worked:        %4.1f %s\n", redotime( $worktime ) );
    printf( "  Breaks:      + %4.1f %s\n", redotime( $breaktime ) );
    printf( "  Total:       = %4.1f %s\n", redotime( $totaltime ) );
    printf( "  %s\n", "-----------------------------------" );
    if ( $worktime < $day ) {
        $timediff = $day - $worktime;
        printf( "  Need to work:  %4.1f %s\n", redotime( $timediff ) );
    }
    else {
        $timediff = $worktime - $day;
        printf( "  Worked over:   %4.1f %s\n", redotime( $timediff ) );
    }
    printf( "%s\n\n", "---------------------------------------" );
}

######################################################################
# End of sub-routines ################################################
######################################################################
__END__

=pod

=head1 NAME

C<daily.pl> - daily report generator

=head1 DESCRIPTION

This program generates a daily report of time worked vs breaks taken.

=head1 SYNOPSIS

=over

=item daily.pl
    display current daily report snapshot

=item daily.pl C<quit> C<day-of-week>
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

=item .C<day-of-week>
    end of day report for the indicated I<day-of-week> (e.g., C<.Monday>)

=item .break_aliases
    optional config file, defines I<task names> treated as aliases to I<break>

=back

=head1 REQUIRED SCRIPTS

=over

=item weekly.pl
    execution is passed to C<weekly.pl> during end-of-day processing
    if day-of-week is Friday, Saturday, or Sunday

=back

=head1 REQUIRED MODULES

=over

=item C<tasklogs>

=item L<Lingua::EN::Titlecase>

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
