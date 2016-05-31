#!/usr/bin/perl -w
######################################################################
# weekly.pl - time tracking tool
# See end of file for user documentation.
######################################################################
# TODO: clean up the debug statements

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin";
}
use tasklogs;

my $taskdir       = get_taskdir();
my $timesheetdir  = get_timesheetsdir();
my $logfn         = get_logfn();
my @break_aliases = get_break_aliases();

my %totals = (
    Monday    => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Tuesday   => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Wednesday => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Thursday  => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Friday    => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Saturday  => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Sunday    => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Week      => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" }
);
my %tasks;
my $temp_time = 0.0;
my $temp_task = '';

printdebug( 1, "before syntax check if" );
printdebug( 2, "argv.length=" . (scalar @ARGV) . "" );
printdebug( 2, "ARGV[0]='$ARGV[0]'" );
printdebug( 2, "ARGV[1]='$ARGV[1]'" );

# verify syntax before continuing
if ( scalar @ARGV == 0 ) {
     die &errmsg_usage( "no arguments specified" );
} elsif ( $ARGV[0] =~ /^-[cru]$/ && ! defined $ARGV[1] ) {
     die &errmsg_usage( "no week ending date specified" );
} elsif ( $ARGV[0] =~ /^-[cru]$/ && $ARGV[1] !~ /^\d{6}$/ ) {
     die &errmsg_usage( "invalid date specified" );
} elsif ( $ARGV[0] ne "--delete" && $ARGV[0] !~ /^-[cru]$/ ) {
     die &errmsg_usage( "unknown argument specified: $ARGV[0]" );
}
printdebug( 1, "after syntax check if" );

my $action = $ARGV[0];
my $wedate = $ARGV[1]; #week ending date
printdebug( 2, "action='$action'" );
printdebug( 2, "wedate='$wedate'" );

if ( defined $wedate ) {
    $outfile = "$timesheetdir$wedate.log";
}
printdebug( 2, "outfile='$outfile'" );

printdebug( 1, "before if blocks" );
if ( $action eq '--delete' ) {
    printdebug( 1, "Calling clear_daily_files()" );
    clear_daily_files( \%totals );
    printdebug( 1, "Call clear_daily_files() here skipped due to debugging" );
    exit;
}
elsif ( $action =~ /^-[cu]$/ ) {
    printdebug( 1, "in create or update block" );

    printdebug( 1, "checking existance of outfile" );
    if ( -e "$outfile" ) {
        if ( $action eq '-c' ) {
            die "ERROR: File $outfile exists. Aborting.\nDid you forget the '-r' flag?\n\n";
        } elsif ( $action eq '-u' ) {
            printdebug( 1, "outfile exists, update specified, renaming to backup file" );
            rename $outfile, "$outfile.bak" or die "Error: $outfile.bak: $!\n";
        } else {
            printdebug( 1, "outfile exists, action not -c or -u, but [$action]" );
        }
    }
    printdebug( 1, "after outfile exists check" );

    printdebug( 1, "opening outfile" );
    open( OUTFILE, ">$outfile" ) or die "ERROR: Can't open: $outfile\n\n";
    printdebug( 1, "outfile now open, if we're here we didn't die" );

    printdebug( 1, "before totalization for loop" );
    # Compute the time for each day
    foreach my $day ( sort { $a cmp $b } keys %totals ) {
        printdebug( 3, "processing day=$day" );
        if ( $day ne 'Week' && -e "$taskdir.$day" && open( INPUT, "$taskdir.$day" ) ) {
            printdebug( 4, "day file $taskdir.$day now open for input" );
            while ( <INPUT> ) {
                $totals{$day}{file} .= $_;
                chomp;
                my $line = $_;
                $line =~ s/^\s+//;
                $line =~ s/\s+$//;
                ( $temp_time, $temp_task ) = split( /\s+/, $line, 2 );
                printdebug( 5, "temp_time=[$temp_time], temp_task=[$temp_task]" );
                $temp_task =~ s/ /_/g;
                $temp_task = uc( $temp_task );
                $tasks{$temp_task} += $temp_time;
                $totals{$day}{total} += $temp_time;
                $totals{Week}{total} += $temp_time;
                if ( grep /^$temp_task/i, @break_aliases ) {
                    $totals{$day}{breaks} += $temp_time;
                    $totals{Week}{breaks} += $temp_time;
                }
                else {
                    $totals{$day}{worked} += $temp_time;
                    $totals{Week}{worked} += $temp_time;
                }
            }
            close( INPUT );
            printdebug( 4, "$day:  \tworked=[$totals{$day}{worked}], breaks=[$totals{$day}{breaks}]" );
            printdebug( 4, "Week:    \tworked=[$totals{Week}{worked}], breaks=[$totals{Week}{breaks}]" );
        }
    }
    printdebug( 1, "after totalization for loop" );

    # Output the Tasks's Totals to the week's log file.
    print  OUTFILE "========================================\n";
    print  OUTFILE "TOTALS FOR EACH TASK\n";
    print  OUTFILE "========================================\n";
    #foreach my $task ( keys %tasks ) {
    foreach my $task ( sort { $tasks{"$b"} <=> $tasks{"$a"} or lc("$a") cmp lc("$b") } keys %tasks ) {
        printf OUTFILE "%4.1f %-40.40s\n", $tasks{$task}, $task;
    }
    print  OUTFILE "\n";

    # Output the Daily and Weekly totals to the week's log file.
    print  OUTFILE "========================================\n";
    print  OUTFILE "TOTALS FOR EACH DAY\n";
    print  OUTFILE "========================================\n";
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Monday}{total},  'MON total time';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Monday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Monday}{worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Tuesday}{total},  'TUE total time';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Tuesday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Tuesday}{worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Wednesday}{total},  'WED total time';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Wednesday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Wednesday}{worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Thursday}{total},  'THU total time';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Thursday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Thursday}{worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Friday}{total},  'FRI total time';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Friday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Friday}{worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Saturday}{total},  'SAT total time';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Saturday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Saturday}{worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Sunday}{total},  'SUN total time';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Sunday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Sunday}{worked}, '  = TIME WORKED';
    print  OUTFILE "---- -----------------------------------\n";
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Week}{total},  'WEEK total time';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Week}{breaks}, '   - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $totals{Week}{worked}, '   = TIME WORKED';
    print  OUTFILE "---- -----------------------------------\n";
    print  OUTFILE "\n";
     
    # Send an exact copy of each day's log file to the week's log file.
    print  OUTFILE "========================================\n";
    print  OUTFILE "BACKUP OF DAILY LOG FILES\n";
    print  OUTFILE "========================================\n";
    print  OUTFILE "-----MON-----\n";
    print  OUTFILE $totals{Monday}{file};
    print  OUTFILE "-----TUE-----\n";
    print  OUTFILE $totals{Tuesday}{file};
    print  OUTFILE "-----WED-----\n";
    print  OUTFILE $totals{Wednesday}{file};
    print  OUTFILE "-----THU-----\n";
    print  OUTFILE $totals{Thursday}{file};
    print  OUTFILE "-----FRI-----\n";
    print  OUTFILE $totals{Friday}{file};
    print  OUTFILE "-----SAT-----\n";
    print  OUTFILE $totals{Saturday}{file};
    print  OUTFILE "-----SUN-----\n";
    print  OUTFILE $totals{Sunday}{file};

    close( OUTFILE );
    chmod( 0400, "$outfile" );
}
printdebug( 1, "after ne -v if block" );
printdebug( 2, "outfile='$outfile'" );

printdebug( 1, "checking readability of outfile" );
if ( ! -r "$outfile" ) {
    die "ERROR: File not readable: $outfile\n\n";
}
printdebug( 1, "outfile is readable, we didn't die" );

# Display the week's report
printdebug( 1, "opening outfile: '$outfile'" );
open( WEEKFILE, "$outfile" ) or die "ERROR: Can't open $outfile\n\n";
printdebug( 1, "outfile now open, if we're here we didn't die" );
my $found_week_total = 0;
print "\n";
while ( <WEEKFILE> ) {
    $found_week_total = 1 if ( $_ =~ /WEEK total time.*/ );
    print $_;
    last if ( $found_week_total && $_ =~ /^-+/ );
}
print "\n";
close( WEEKFILE );

######################################################################
exit; # End of main script ###########################################
######################################################################

######################################################################
# Returns the error usage string
#
sub errmsg_usage($) {
    my $clarification = shift;
    return <<"eof";
    Error: $clarification
    Usage:
weekly.pl [-c|-r|-u] YYMMDD
weekly.pl --delete
    -c YYMMDD   Create new weekly timesheet for week ending YYMMDD
    -u YYMMDD   Update existing weekly timesheet for week ending YYMMDD
    -r YYMMDD   Display existing weekly timesheet for week ending YYMMDD
    --delete    Delete daily log files

eof
}

######################################################################
# End of sub-routines ################################################
######################################################################
__END__

=pod

=head1 NAME

C<weekly.pl> - weekly timesheet generator

=head1 DESCRIPTION

This program generates a weekly timesheet.

=head1 SYNOPSIS

=over

=item weekly.pl C<-c YYMMDD>
    create new weekly timesheet for week ending I<YYMMDD>

=item weekly.pl C<-u YYMMDD>
    update existing weekly timesheet for week ending I<YYMMDD>

=item weekly.pl C<-r YYMMDD>
    display existing weekly timesheet for week ending I<YYMMDD>

=item weekly.pl C<--delete>
    delete daily log files

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

=item timesheets/C<YYMMDD.log>
    timesheet for week ending I<YYMMDD>

=item .C<day-of-week>
    end of day report for the indicated I<day-of-week> (e.g., C<.Monday>, or C<mon>)

=item .break_aliases
    optional config file, defines I<task names> treated as aliases to I<break>

=back

=head1 REQUIRED MODULES

=over

=item C<tasklogs>

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
