#!/usr/bin/perl -w
# vim: ts=4 sw=4 et

# SYNTAX: weekly.pl (MMDDYY)
#
#         Where MMDDYY is the Saturday Week Ending Date
#
# Reads from five (5) input files:
#    .Monday, .Tuesday, .Wednesday, .Thursday, .Friday
#
# Outputs to file MMDDYY.log
######################################################################
my $DEBUG = 0;

#
# Startup initialization
#
my $taskdir = undef;
my $weekdir = undef;

if (defined $ENV{HOME}) {
    $taskdir = $ENV{HOME} . "/tasklogs/";
    $weekdir = $taskdir . "weeklogs/";
} elsif (defined $ENV{HOMEDRIVE} && defined $ENV{HOMEPATH}) {
    $taskdir = $ENV{HOMEDRIVE} . $ENV{HOMEPATH} . "tasklogs\\";
    $weekdir = $taskdir . "weeklogs\\";
} else {
    die "HOME or (HOMEDRIVE and HOMEPATH) environment variables not set\n";
}
my $logfn = $taskdir . '.hours';
my $outfile;

my $arg1 = shift @ARGV;
my $arg2 = undef;
if ( !defined( $arg1 ) ) {
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
    $arg1    = "$mon$mday$year";
    $outfile = $arg1;
} elsif ( $arg1 eq '-v' ) {
    $arg2 = shift @ARGV if ( $arg1 =~ /^-/ );
    $outfile = $arg2;
} elsif ( $arg1 eq 'clear' ) {
    # TODO: this is a bad hack, reusing this variable, so fix it at some point
    $outfile = $arg1;
} else {
    die "\nERROR: Usage:\n\nweekly.pl [-v] MMDDYY\n\tMMDDYY is Saturday week ending date\n\t-v for viewing previous weekly report\nweekly.pl clear\n\n";
}

my %time = (
    Monday    => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Tuesday   => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Wednesday => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Thursday  => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Friday    => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" },
    Week      => { total => 0.0, breaks => 0.0, worked => 0.0, file => "" }
);
my %tasks;
my $temp_time = 0.0;
my $temp_task = '';

print "DEBUG: before if blocks\n" if ( $DEBUG );
print "DEBUG: outfile='$outfile'\n" if ( $DEBUG );

if ( $outfile eq 'clear' ) {
    print "DEBUG: in clear block\n" if ( $DEBUG );

    foreach $day ( keys %time ) {
        if ( -e "$taskdir.$day" && open( CLEAR, ">$taskdir.$day" ) ) {
            print "Clearing $taskdir.$day\n";
            close( CLEAR );
        }
    }
}
elsif ( $arg1 ne '-v' ) {
    print "DEBUG: in ne -v block\n" if ( $DEBUG );

    $outfile .= '.log';

    print "DEBUG: checking existance of outfile\n" if ( $DEBUG );
    if ( -e "$weekdir$outfile" ) {
        die "ERROR: File $weekdir$outfile exists. Aborting.\nDid you forget the '-v' flag?\n\n";
    }
    print "DEBUG: outfile doesn't exist, we didn't die\n" if ( $DEBUG );

    print "DEBUG: opening outfile\n" if ( $DEBUG );
    open( OUTFILE, ">$weekdir$outfile" ) or die "ERROR: Can't open: $weekdir$outfile\n\n";
    print "DEBUG: outfile now open, if we're here we didn't die\n" if ( $DEBUG );

    # Compute the time for each day
    foreach $day ( keys %time ) {
        if ( -e "$taskdir.$day" && open( INPUT, "$taskdir.$day" ) ) {
            while ( <INPUT> ) {
                $time{$day}{file} .= $_;
                chomp;
                ( $temp_time, $temp_task ) = split( /\s+/, $_, 2 );
                $temp_task =~ s/ /_/g;
                $temp_task = uc( $temp_task );
                $tasks{$temp_task} += $temp_time;
                $time{$day}{total} += $temp_time;
                $time{Week}{total} += $temp_time;
                if ( $temp_task =~ /break/i ||
                     $temp_task =~ /lunch/i ||
                     $temp_task =~ /sick/i ||
                     $temp_task =~ /vacation/i ||
                     $temp_task =~ /holiday/i )
                {
                    $time{$day}{breaks} += $temp_time;
                    $time{Week}{breaks} += $temp_time;
                }
                else {
                    $time{$day}{worked} += $temp_time;
                    $time{Week}{worked} += $temp_time;
                }
            }
            close( INPUT );
        }
    }

    # Output the Tasks's Totals to the week's log file.
    print  OUTFILE "========================================\n";
    print  OUTFILE "TOTALS FOR EACH TASK\n";
    print  OUTFILE "========================================\n";
    foreach $task ( keys %tasks ) {
        printf OUTFILE "%4.1f %-40.40s\n", $tasks{$task}, $task;
    }
    print  OUTFILE "\n";

    # Output the Daily and Weekly totals to the week's log file.
    print  OUTFILE "========================================\n";
    print  OUTFILE "TOTALS FOR EACH DAY\n";
    print  OUTFILE "========================================\n";
    printf OUTFILE "%4.1f %-40.40s\n", $time{Monday}{total},  'MON total time';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Monday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Monday}{worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "%4.1f %-40.40s\n", $time{Tuesday}{total},  'TUE total time';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Tuesday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Tuesday}{worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "%4.1f %-40.40s\n", $time{Wednesday}{total},  'WED total time';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Wednesday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Wednesday}{worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "%4.1f %-40.40s\n", $time{Thursday}{total},  'THU total time';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Thursday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Thursday}{worked}, '  = TIME WORKED';
    print  OUTFILE "\n";
    printf OUTFILE "%4.1f %-40.40s\n", $time{Friday}{total},  'FRI total time';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Friday}{breaks}, '  - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Friday}{worked}, '  = TIME WORKED';
    print  OUTFILE "---- -----------------------------------\n";
    printf OUTFILE "%4.1f %-40.40s\n", $time{Week}{total},  'WEEK total time';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Week}{breaks}, '   - breaks/lunch';
    printf OUTFILE "%4.1f %-40.40s\n", $time{Week}{worked}, '   = TIME WORKED';
    print  OUTFILE "---- -----------------------------------\n";
    print  OUTFILE "\n";
     
    # Send an exact copy of each day's log file to the week's log file.
    print  OUTFILE "========================================\n";
    print  OUTFILE "BACKUP OF DAILY LOG FILES\n";
    print  OUTFILE "========================================\n";
    print OUTFILE "-----MON-----\n";
    print OUTFILE $time{Monday}{file};
    print OUTFILE "-----TUE-----\n";
    print OUTFILE $time{Tuesday}{file};
    print OUTFILE "-----WED-----\n";
    print OUTFILE $time{Wednesday}{file};
    print OUTFILE "-----THU-----\n";
    print OUTFILE $time{Thursday}{file};
    print OUTFILE "-----FRI-----\n";
    print OUTFILE $time{Friday}{file};

    close( OUTFILE );
    chmod( 0444, "$weekdir$outfile" );
}

print "DEBUG: between if blocks\n" if ( $DEBUG );
print "DEBUG: outfile='$outfile'\n" if ( $DEBUG );

if ( $outfile ne 'clear' ) {
    print "DEBUG: in ne clear block\n" if ( $DEBUG );

    if ( $outfile !~ /\.log$/ ) {
        $outfile .= '.log';
    }
    print "DEBUG: after adjusting filename\n" if ( $DEBUG );
    print "DEBUG: outfile='$outfile'\n" if ( $DEBUG );

    print "DEBUG: checking readability of outfile\n" if ( $DEBUG );
    if ( ! -r "$weekdir$outfile" ) {
        die "ERROR: File not readable: $weekdir$outfile\n\n";
    }
    print "DEBUG: outfile is readable, we didn't die\n" if ( $DEBUG );

    # Display the week's report
    print "\n";
    print "DEBUG: opening outfile: '$weekdir$outfile'\n" if ( $DEBUG );
    open( WEEKFILE, "$weekdir$outfile" ) or die "ERROR: Can't open $weekdir$outfile\n\n";
    print "DEBUG: outfile now open, if we're here we didn't die\n" if ( $DEBUG );
    while ( <WEEKFILE> ) {
        print $_;
    }
    close( WEEKFILE );
    print "\n";
}

__END__

=head1 NAME

B<weekly> - weekly report generator

=head1 SYNOPSIS

=over

=item B<weekly>

=item B<weekly> MMDDYY Where is Saturday week ending date

=item B<weekly> -v for viewing previous weekly report

=item B<weekly clear>

=back

=cut
