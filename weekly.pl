#!/usr/bin/perl
######################################################################
# weekly.pl - time tracking tool
# See end of file for user documentation.
# NOTE: # removed "-w" switch to avoid "uninitialized value" warnings
######################################################################

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin";
}
use tasklogs;

use Math::Round qw(nearest);

my $taskdir       = get_taskdir();
my $timesheetdir  = get_timesheetsdir();
my $logfn         = get_logfn();
my @break_aliases = get_break_aliases();

my %totals = (
    Monday    => {
                   total          => 0,
                   breaks         => 0,
                   worked         => 0,
                   rounded_total  => 0.0,
                   rounded_breaks => 0.0,
                   rounded_worked => 0.0,
                   file           => "" },
    Tuesday   => { total => 0,
                   total          => 0,
                   breaks         => 0,
                   worked         => 0,
                   rounded_total  => 0.0,
                   rounded_breaks => 0.0,
                   rounded_worked => 0.0,
                   file           => "" },
    Wednesday => { total => 0,
                   total          => 0,
                   breaks         => 0,
                   worked         => 0,
                   rounded_total  => 0.0,
                   rounded_breaks => 0.0,
                   rounded_worked => 0.0,
                   file           => "" },
    Thursday  => { total => 0,
                   total          => 0,
                   breaks         => 0,
                   worked         => 0,
                   rounded_total  => 0.0,
                   rounded_breaks => 0.0,
                   rounded_worked => 0.0,
                   file           => "" },
    Friday    => { total => 0,
                   total          => 0,
                   breaks         => 0,
                   worked         => 0,
                   rounded_total  => 0.0,
                   rounded_breaks => 0.0,
                   rounded_worked => 0.0,
                   file           => "" },
    Saturday  => { total => 0,
                   total          => 0,
                   breaks         => 0,
                   worked         => 0,
                   rounded_total  => 0.0,
                   rounded_breaks => 0.0,
                   rounded_worked => 0.0,
                   file           => "" },
    Sunday    => { total => 0,
                   total          => 0,
                   breaks         => 0,
                   worked         => 0,
                   rounded_total  => 0.0,
                   rounded_breaks => 0.0,
                   rounded_worked => 0.0,
                   file           => "" },
    Week      => { total => 0,
                   total          => 0,
                   breaks         => 0,
                   worked         => 0,
                   rounded_total  => 0.0,
                   rounded_breaks => 0.0,
                   rounded_worked => 0.0,
                   file           => "" },
);
my %tasks;
my $temp_time = 0.0;
my $temp_task = '';


# verify syntax before continuing
if ( scalar @ARGV == 0 ) {
     die &errmsg_usage( "no arguments specified" );
} elsif ( $ARGV[0] =~ /^-[cru]$/ && ! defined $ARGV[1] ) {
     die &errmsg_usage( "no week ending date specified" );
} elsif ( $ARGV[0] =~ /^-[cru]$/ && $ARGV[1] !~ /^\d{8}$/ ) {
     die &errmsg_usage( "invalid date specified" );
} elsif ( $ARGV[0] ne "--delete" && $ARGV[0] !~ /^-[cru]$/ ) {
     die &errmsg_usage( "unknown argument specified: $ARGV[0]" );
}

my $action = $ARGV[0];
my $wedate = $ARGV[1]; #week ending date

if ( defined $wedate ) {
    $outfile = "$timesheetdir$wedate.log";
}

if ( $action eq '--delete' ) {
    clear_daily_files( %totals );
    exit;
}
elsif ( $action =~ /^-[cu]$/ ) {

    if ( -e "$outfile" ) {
        if ( $action eq '-c' ) {
            die "ERROR: File $outfile exists. Aborting.\nDid you forget the '-r' flag?\n\n";
        } elsif ( $action eq '-u' ) {
            rename $outfile, "$outfile.bak" or die "Error: $outfile.bak: $!\n";
        } else {
        }
    }

    open( OUTFILE, ">$outfile" ) or die "ERROR: Can't open: $outfile\n\n";

    # Compute the time for each day
    foreach my $day ( sort { $a cmp $b } keys %totals ) {
        if ( $day ne 'Week' && -e "$taskdir.$day" && open( INPUT, "$taskdir.$day" ) ) {
            while ( <INPUT> ) {
                $totals{$day}{file} .= $_;
                chomp;
                my $line = $_;
                $line =~ s/^\s+//;
                $line =~ s/\s+$//;
                ( $temp_time, $temp_task ) = split( /\s+/, $line, 2 );
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
        }
    }

    foreach my $day ( sort { $a cmp $b } keys %totals ) {
        $totals{$day}{rounded_total}
            = nearest( get_rounding_precision(), $totals{$day}{total} / get_seconds_conversion() );
        $totals{$day}{rounded_breaks}
            = nearest( get_rounding_precision(), $totals{$day}{breaks} / get_seconds_conversion() );
        $totals{$day}{rounded_worked}
            = nearest( get_rounding_precision(), $totals{$day}{worked} / get_seconds_conversion() );
    }

    # Output the Tasks's Totals to the week's log file.
    print  OUTFILE "========================================\n";
    print  OUTFILE "TOTALS FOR EACH TASK\n";
    print  OUTFILE "========================================\n";
    #foreach my $task ( keys %tasks ) {
    foreach my $task ( sort { $tasks{"$b"} <=> $tasks{"$a"} or lc("$a") cmp lc("$b") } keys %tasks ) {
        printf OUTFILE "%4.1f %-40.40s\n", $tasks{$task}, $task;
    }
    print  OUTFILE "\n";

    my $fmt = get_printf_fmt();
    # Output the Daily and Weekly totals to the week's log file.
    print  OUTFILE "========================================\n";
    print  OUTFILE "TOTALS FOR EACH DAY\n";
    print  OUTFILE "========================================\n";
    printf OUTFILE "$fmt %-40.40s\n", $totals{Monday}{rounded_total},  'MON total time';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Monday}{rounded_breaks}, '  - breaks/lunch';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Monday}{rounded_worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "$fmt %-40.40s\n", $totals{Tuesday}{rounded_total},  'TUE total time';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Tuesday}{rounded_breaks}, '  - breaks/lunch';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Tuesday}{rounded_worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "$fmt %-40.40s\n", $totals{Wednesday}{rounded_total},  'WED total time';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Wednesday}{rounded_breaks}, '  - breaks/lunch';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Wednesday}{rounded_worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "$fmt %-40.40s\n", $totals{Thursday}{rounded_total},  'THU total time';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Thursday}{rounded_breaks}, '  - breaks/lunch';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Thursday}{rounded_worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "$fmt %-40.40s\n", $totals{Friday}{rounded_total},  'FRI total time';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Friday}{rounded_breaks}, '  - breaks/lunch';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Friday}{rounded_worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "$fmt %-40.40s\n", $totals{Saturday}{rounded_total},  'SAT total time';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Saturday}{rounded_breaks}, '  - breaks/lunch';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Saturday}{rounded_worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "$fmt %-40.40s\n", $totals{Sunday}{rounded_total},  'SUN total time';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Sunday}{rounded_breaks}, '  - breaks/lunch';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Sunday}{rounded_worked}, '  = TIME WORKED';
    print  OUTFILE "---- -----------------------------------\n";
    printf OUTFILE "$fmt %-40.40s\n", $totals{Week}{rounded_total},  'WEEK total time';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Week}{rounded_breaks}, '   - breaks/lunch';
    printf OUTFILE "$fmt %-40.40s\n", $totals{Week}{rounded_worked}, '   = TIME WORKED';
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

if ( ! -r "$outfile" ) {
    die "ERROR: File not readable: $outfile\n\n";
}

# Display the week's report
open( WEEKFILE, "$outfile" ) or die "ERROR: Can't open $outfile\n\n";
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
weekly.pl [-c|-r|-u] YYYYMMDD
weekly.pl --delete
    -c YYYYMMDD   Create new weekly timesheet for week ending YYYYMMDD
    -u YYYYMMDD   Update existing weekly timesheet for week ending YYYYMMDD
    -r YYYYMMDD   Display existing weekly timesheet for week ending YYYYMMDD
    --delete      Delete daily log files

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

=item weekly.pl C<-c YYYYMMDD>
    create new weekly timesheet for week ending I<YYYYMMDD>

=item weekly.pl C<-u YYYYMMDD>
    update existing weekly timesheet for week ending I<YYYYMMDD>

=item weekly.pl C<-r YYYYMMDD>
    display existing weekly timesheet for week ending I<YYYYMMDD>

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

=item timesheets/C<YYYYMMDD.log>
    timesheet for week ending I<YYYYMMDD>

=item .C<day-of-week>
    end of day report for the indicated I<day-of-week> (e.g., C<.Monday>, or C<mon>)

=item .break_aliases
    optional config file, defines I<task names> treated as aliases to I<break>

=back

=head1 REQUIRED MODULES

=over

=item C<tasklogs>

=item L<Math::Round>

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
