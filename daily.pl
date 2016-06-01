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

use DateTime;
use Lingua::EN::Titlecase;

my $option;
if ( defined $ARGV[0] ) {
    $option = join( ' ', @ARGV );
    $option =~ s/^\s+//;
    $option =~ s/\s+$//;
}

my $currtime = time;

# Check the command-line options and perform the appropriate action:
# If the option was 'quit', perform the end-of-day activities, doing 'weekly'
# actions on certain days of the week.
# Otherwise, just print the 'daily' report to the screen.
if ( defined( $option ) ) {
    if ( $option =~ /^quit/i ) {
        my $eodref = get_endofday( $option );
        my $eod_filename = $$eodref{fn};

        if ( -e $eod_filename ) {
            # NOTE: This assumes we reached this point from a call to `task.pl quit`
            #       which outputs the end-of-day log for us.
            # Prompt the user for whether the log file looks good, if not
            # open the logfile into a text editor (e.g., vim).
            print "\n\nEdit [y|n]? ";
            my $doEdit;
            chomp( $doEdit = <STDIN> );
            if ( $doEdit eq 'Y' || $doEdit eq 'y' ) {
                system "vim $eod_filename" == 0 or die "Error: vim failed: $?\n";
            }
        }

        # If we're Friday or the weekend, prompt for running the weekly report.
        if ( $$eodref{dt}->day_of_week() >= 5 ) {
            # Prompt the user for whether the weekly report should be ran.
            print "\n\nProcess Weekly Report [y|n]? ";
            my $doWeek;
            chomp( $doWeek = <STDIN> );
            if ( $doWeek eq 'Y' || $doWeek eq 'y' ) {
                my $weekly  = get_weekly_script();
                my $eow_ymd = get_endofweek_ymd( $$eodref{dt} );
                print `perl $weekly -c $eow_ymd`;

                # prevent accidentally clearing daily logs if an error happened
                die "Error: Generating weekly timesheet died unexpectedly\n" if ( $? != 0 );

                # Prompt the user for whether the daily logs should be cleared.
                print "\n\nClear Daily Logs [y|n]? ";
                my $doClear;
                chomp( $doClear = <STDIN> );
                if ( $doClear eq 'Y' || $doClear eq 'y' ) {
                    print `perl $weekly --delete`;
                }
            }
        }
    } else {
        die "Error: Invalid option: $option\n";
    }
}
else {
    my $logfn = get_logfn();

    if ( open( INPUT, $logfn ) ) {

        my $tc = Lingua::EN::Titlecase->new("");
        my $startday;
        my @tasks;
        my ($temp_task, $temp_time2) = ("", 0.0);
        my $linenumber = 0;
        while ( <INPUT> ) {
            chomp;
            ( $temp_time, $temp_task ) = split( /\s+/, $_, 2 );
            $tasks[$linenumber] = [ $temp_time, $tc->title("$temp_task") ];
            $startday      = $temp_time if ( $linenumber == 0 );
            $linenumber++;
        }
        close( INPUT );
        my $currtaskname = $temp_task;
        my $currtasktime = $temp_time;

        my @break_aliases = get_break_aliases();

        my ($breaktime, $worktime) = (0.0, 0.0);
        my $numtasks = scalar( @tasks );
        if ( $numtasks > 1 ) {
            my $ctr = 0;
            while ( $ctr < $numtasks ) {
                $temp_task  = $tasks[$ctr][1] unless( !defined( $tasks[$ctr][1] ) );
                my $temp_time1 = $tasks[$ctr][0] unless( !defined( $tasks[$ctr][0] ) );

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

        if ( $tasks[$numtasks-1][0] < $currtime ) {
            my $tsk = $tasks[$numtasks-1][1];
            if ( grep /^$tsk/i, @break_aliases ) {
                $breaktime += $currtime - $tasks[$numtasks-1][0];
            }
            else {
                $worktime += $currtime - $tasks[$numtasks-1][0];
            }
        }

        &printreport( $worktime, $breaktime, $startday, $currtaskname, $currtasktime );
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
    my $worktime     = shift || 0;
    my $breaktime    = shift || 0;
    my $startday     = shift || 0;
    my $currtaskname = shift || "";
    my $currtasktime = shift || 0;
    my $timediff     = 0;
    my $dayinsecs    = 8 * 60 * 60;

    my $totaltime = $worktime + $breaktime;

    # calculate the expected end of day and format for output
    my @endofday = localtime( $startday + $dayinsecs + $breaktime );
    my $endday   = fmttimearr( @endofday );

    # reformat for output
    my @startofday = localtime( $startday );
    $startday      = fmttimearr( @startofday );

    printf( "\n%s\n", "---------------------------------------" );
    printf( "  Current Task:  %s\n", $currtaskname );
    printf( "           for:  %4.1f %s\n", redotime( $currtime - $currtasktime ) );
    printf( "  Arrive Work:   %s\n", $startday );
    printf( "  Leave Work:    %s\n", $endday );
    printf( "  %s\n", "-----------------------------------" );
    printf( "  Worked:        %4.1f %s\n", redotime( $worktime ) );
    printf( "  Breaks:      + %4.1f %s\n", redotime( $breaktime ) );
    printf( "  Total:       = %4.1f %s\n", redotime( $totaltime ) );
    printf( "  %s\n", "-----------------------------------" );

    if ( $worktime < $dayinsecs ) {
        $timediff = $dayinsecs - $worktime;
        printf( "  Need to work:  %4.1f %s\n", redotime( $timediff ) );
    }
    else {
        $timediff = $worktime - $dayinsecs;
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

=item L<DateTime>

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
